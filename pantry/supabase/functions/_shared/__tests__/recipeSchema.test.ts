import { describe, expect, it } from 'vitest';
import {
  RecipeParseError,
  extractJson,
  parseRecipeResponse,
  validateGeneratedRecipe,
} from '../recipeSchema.ts';

const VALID = {
  title: 'Garlic Chicken and Rice',
  servings: 2,
  prep_minutes: 30,
  cuisine_tags: ['asian'],
  instructions: 'Cook the chicken. Add the rice.',
  ingredients: [
    { name: 'chicken breast', display_name: 'Chicken breast', quantity: 2, unit: '', category: 'meat', likely_already_have: false },
    { name: 'rice', display_name: 'Jasmine rice', quantity: 1, unit: 'cup', category: 'pantry_dry', likely_already_have: true },
  ],
};

describe('extractJson - getting JSON out of whatever the model said', () => {
  it('parses a bare object', () => {
    expect(extractJson('{"a":1}')).toEqual({ a: 1 });
  });

  it('strips ```json fences', () => {
    expect(extractJson('```json\n{"a":1}\n```')).toEqual({ a: 1 });
  });

  it('strips bare ``` fences', () => {
    expect(extractJson('```\n{"a":1}\n```')).toEqual({ a: 1 });
  });

  it('ignores a preamble', () => {
    expect(extractJson('Here is a recipe you might like:\n\n{"a":1}')).toEqual({ a: 1 });
  });

  it('ignores trailing prose', () => {
    expect(extractJson('{"a":1}\n\nEnjoy your meal!')).toEqual({ a: 1 });
  });

  it('survives braces inside string values', () => {
    // A naive lastIndexOf('}') would cut this in the wrong place.
    const raw = 'Sure!\n{"title":"Rice {with} braces","note":"a } here"}\nDone.';
    expect(extractJson(raw)).toEqual({ title: 'Rice {with} braces', note: 'a } here' });
  });

  it('survives escaped quotes inside strings', () => {
    expect(extractJson(String.raw`{"title":"He said \"hi\""}`)).toEqual({ title: 'He said "hi"' });
  });

  it('handles a leading byte order mark', () => {
    expect(extractJson('﻿{"a":1}')).toEqual({ a: 1 });
  });

  it('recovers the object when the model wraps it in an array', () => {
    // Models sometimes return [{...}] despite being told to return an object.
    // Pulling the first object out beats burning a corrective retry; if it is
    // not actually a recipe, validation rejects it a moment later.
    expect(extractJson('[{"a":1}]')).toEqual({ a: 1 });
  });

  it('rejects an empty response', () => {
    expect(() => extractJson('   ')).toThrow(RecipeParseError);
  });

  it('rejects prose with no JSON at all', () => {
    expect(() => extractJson('I cannot help with that.')).toThrow(RecipeParseError);
  });
});

describe('validateGeneratedRecipe - fatal vs recoverable', () => {
  it('accepts a well-formed recipe', () => {
    const { recipe, warnings } = validateGeneratedRecipe(VALID);
    expect(recipe.title).toBe('Garlic Chicken and Rice');
    expect(recipe.servings).toBe(2);
    expect(recipe.ingredients).toHaveLength(2);
    expect(warnings).toEqual([]);
  });

  it.each([
    ['title', { ...VALID, title: '' }],
    ['servings', { ...VALID, servings: 0 }],
    ['instructions', { ...VALID, instructions: '' }],
    ['ingredients', { ...VALID, ingredients: [] }],
  ])('throws when %s is unusable', (_field, payload) => {
    expect(() => validateGeneratedRecipe(payload)).toThrow(RecipeParseError);
  });

  it('rejects a top-level array as a recipe', () => {
    expect(() => validateGeneratedRecipe([VALID])).toThrow(RecipeParseError);
  });

  it('coerces a numeric string servings rather than failing', () => {
    expect(validateGeneratedRecipe({ ...VALID, servings: '4' }).recipe.servings).toBe(4);
  });

  it('accepts instructions as an array of steps', () => {
    const { recipe } = validateGeneratedRecipe({
      ...VALID,
      instructions: ['Chop the garlic', 'Fry it'],
    });
    expect(recipe.instructions).toBe('1. Chop the garlic\n2. Fry it');
  });

  it('accepts instructions as an array of step objects', () => {
    const { recipe } = validateGeneratedRecipe({
      ...VALID,
      instructions: [{ step: 1, text: 'Chop' }, { step: 2, text: 'Fry' }],
    });
    expect(recipe.instructions).toBe('1. Chop\n2. Fry');
  });

  it('downgrades an invented category to "other" instead of retrying', () => {
    // A round trip costs a second API call and several seconds of waiting; the
    // conversion layer copes with 'other' perfectly well.
    const { recipe, warnings } = validateGeneratedRecipe({
      ...VALID,
      ingredients: [{ ...VALID.ingredients[0], category: 'poultry' }],
    });
    expect(recipe.ingredients[0]?.category).toBe('other');
    expect(warnings.join(' ')).toMatch(/poultry/);
  });

  it('normalizes category spelling variants', () => {
    const { recipe, warnings } = validateGeneratedRecipe({
      ...VALID,
      ingredients: [{ ...VALID.ingredients[0], category: 'Pantry Dry' }],
    });
    expect(recipe.ingredients[0]?.category).toBe('pantry_dry');
    expect(warnings).toEqual([]);
  });

  it('skips a nameless ingredient but keeps the rest', () => {
    const { recipe, warnings } = validateGeneratedRecipe({
      ...VALID,
      ingredients: [VALID.ingredients[0], { quantity: 1, unit: 'cup' }],
    });
    expect(recipe.ingredients).toHaveLength(1);
    expect(warnings.join(' ')).toMatch(/no name/i);
  });

  it('throws when every ingredient is unusable', () => {
    expect(() =>
      validateGeneratedRecipe({ ...VALID, ingredients: [{ quantity: 1 }, 'salt'] }),
    ).toThrow(RecipeParseError);
  });

  it('drops a junk prep_minutes with a warning rather than failing', () => {
    const { recipe, warnings } = validateGeneratedRecipe({ ...VALID, prep_minutes: 'about half an hour' });
    expect(recipe.prep_minutes).toBeNull();
    expect(warnings.join(' ')).toMatch(/prep_minutes/);
  });

  it('accepts estimated_prep_minutes as an alias', () => {
    const { prep_minutes: _dropped, ...rest } = VALID;
    expect(validateGeneratedRecipe({ ...rest, estimated_prep_minutes: 25 }).recipe.prep_minutes).toBe(25);
  });

  it('lowercases ingredient names for the pantry join key', () => {
    const { recipe } = validateGeneratedRecipe({
      ...VALID,
      ingredients: [{ ...VALID.ingredients[0], name: 'Chicken Breast' }],
    });
    expect(recipe.ingredients[0]?.name).toBe('chicken breast');
  });
});

describe('RecipeParseError.correctionPrompt', () => {
  it('names the problems and restates the format rule', () => {
    try {
      validateGeneratedRecipe({ ...VALID, title: '', servings: -1 });
      expect.unreachable('should have thrown');
    } catch (error) {
      expect(error).toBeInstanceOf(RecipeParseError);
      const prompt = (error as RecipeParseError).correctionPrompt();
      expect(prompt).toMatch(/"title"/);
      expect(prompt).toMatch(/"servings"/);
      expect(prompt).toMatch(/no markdown code fences/i);
    }
  });
});

describe('parseRecipeResponse - the real-world shapes end to end', () => {
  it('handles a fenced recipe with a preamble', () => {
    const raw = `Sure! Here's something light:\n\n\`\`\`json\n${JSON.stringify(VALID)}\n\`\`\`\n\nEnjoy!`;
    const { recipe } = parseRecipeResponse(raw);
    expect(recipe.title).toBe('Garlic Chicken and Rice');
    expect(recipe.ingredients).toHaveLength(2);
  });

  it('reports a truncated response as unparseable rather than half-parsing it', () => {
    const truncated = '{"title":"Half a recipe","servings":2,"ingredients":[{"name":"rice"';
    expect(() => parseRecipeResponse(truncated)).toThrow(RecipeParseError);
  });
});
