/**
 * Parsing and validating the model's recipe JSON.
 *
 * The model is told to return bare JSON and mostly does, but "mostly" is not a
 * contract. It wraps output in ``` fences, prefixes "Here's a recipe you might
 * like:", returns instructions as an array of steps, or invents a category that
 * is not in the enum. All of that is recoverable without a round trip, and this
 * module recovers what it can and produces a precise complaint about what it
 * cannot -- that complaint becomes the corrective retry message.
 *
 * The split matters: extractJson() deals with the text being wrapped, and
 * validateGeneratedRecipe() deals with the shape being wrong. They fail
 * differently and the retry message differs accordingly.
 */

import { PANTRY_CATEGORIES, type PantryCategory } from './units/types.ts';

export interface GeneratedIngredient {
  name: string;
  display_name: string;
  quantity: number | string;
  unit: string;
  category: PantryCategory;
  likely_already_have: boolean;
}

export interface GeneratedRecipe {
  title: string;
  servings: number;
  prep_minutes: number | null;
  cuisine_tags: string[];
  instructions: string;
  ingredients: GeneratedIngredient[];
}

export class RecipeParseError extends Error {
  override readonly name = 'RecipeParseError';
  /** Field-level problems, phrased so they can be handed back to the model. */
  readonly issues: string[];
  readonly rawText: string;

  constructor(message: string, issues: string[], rawText: string) {
    super(message);
    this.issues = issues;
    this.rawText = rawText;
  }

  /** The corrective message for the single retry. */
  correctionPrompt(): string {
    return (
      'Your previous response could not be used:\n' +
      this.issues.map((issue) => `- ${issue}`).join('\n') +
      '\n\nReturn the corrected recipe as a single raw JSON object. ' +
      'No markdown code fences, no explanation before or after, no trailing commas. ' +
      'Start your response with { and end it with }.'
    );
  }
}

/**
 * Pull a JSON object out of whatever the model actually said.
 *
 * Scans for the first `{` and walks to its matching `}` while tracking string
 * literals, so trailing prose ("Enjoy!") and braces inside ingredient names do
 * not break the extraction.
 */
export function extractJson(raw: string): unknown {
  const text = raw.replace(/^﻿/, '').trim();
  if (text === '') {
    throw new RecipeParseError('The model returned an empty response.', ['The response was empty.'], raw);
  }

  const candidates: string[] = [];

  // A fenced block, with or without a language tag.
  const fence = /```(?:json|JSON)?\s*\n?([\s\S]*?)```/.exec(text);
  if (fence?.[1]) candidates.push(fence[1].trim());

  const balanced = extractBalancedObject(text);
  if (balanced) candidates.push(balanced);

  candidates.push(text);

  for (const candidate of candidates) {
    try {
      const parsed: unknown = JSON.parse(candidate);
      if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) return parsed;
    } catch {
      // Try the next candidate.
    }
  }

  throw new RecipeParseError(
    'The model response did not contain a parseable JSON object.',
    ['The response was not valid JSON. It may have contained prose, fences, or a trailing comma.'],
    raw,
  );
}

function extractBalancedObject(text: string): string | null {
  const start = text.indexOf('{');
  if (start === -1) return null;

  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let i = start; i < text.length; i += 1) {
    const char = text[i];

    if (escaped) {
      escaped = false;
      continue;
    }
    if (char === '\\') {
      if (inString) escaped = true;
      continue;
    }
    if (char === '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;

    if (char === '{') depth += 1;
    else if (char === '}') {
      depth -= 1;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  return null;
}

// --- validation ------------------------------------------------------------

function asTrimmedString(value: unknown): string | null {
  return typeof value === 'string' && value.trim() !== '' ? value.trim() : null;
}

function asPositiveInt(value: unknown): number | null {
  const numeric = typeof value === 'number' ? value : typeof value === 'string' ? Number(value) : NaN;
  if (!Number.isFinite(numeric) || numeric <= 0) return null;
  return Math.round(numeric);
}

/**
 * Instructions arrive as a string, an array of steps, or an array of
 * {step, text} objects depending on the model's mood. All three are usable.
 */
function normalizeInstructions(value: unknown): string | null {
  if (typeof value === 'string') return asTrimmedString(value);

  if (Array.isArray(value)) {
    const steps = value
      .map((entry, index) => {
        if (typeof entry === 'string') return `${index + 1}. ${entry.trim()}`;
        if (entry !== null && typeof entry === 'object') {
          const record = entry as Record<string, unknown>;
          const text = asTrimmedString(record.text ?? record.step ?? record.instruction);
          if (text) return `${index + 1}. ${text}`;
        }
        return null;
      })
      .filter((step): step is string => step !== null);
    return steps.length > 0 ? steps.join('\n') : null;
  }

  return null;
}

function normalizeCategory(value: unknown, issues: string[], ingredientName: string): PantryCategory {
  const raw = typeof value === 'string' ? value.trim().toLowerCase().replace(/[\s-]+/g, '_') : '';
  if ((PANTRY_CATEGORIES as readonly string[]).includes(raw)) return raw as PantryCategory;

  // Recoverable: 'other' is always a valid category, and the conversion layer
  // handles an unknown category by falling back to universal unit arithmetic.
  // Worth noting, not worth a round trip.
  issues.push(
    `Ingredient "${ingredientName}" had category "${String(value)}", which is not one of: ` +
      `${PANTRY_CATEGORIES.join(', ')}. Treated as "other".`,
  );
  return 'other';
}

export interface ValidationResult {
  recipe: GeneratedRecipe;
  /** Problems that were recovered from. Worth logging, not worth a retry. */
  warnings: string[];
}

/**
 * Validate the parsed object into a GeneratedRecipe.
 *
 * Throws RecipeParseError only for problems that make the recipe unusable --
 * a missing title, no ingredients, an ingredient with no name. Everything else
 * is coerced and reported as a warning, because a retry costs a second API call
 * and several seconds of the user waiting.
 */
export function validateGeneratedRecipe(value: unknown, rawText = ''): ValidationResult {
  const fatal: string[] = [];
  const warnings: string[] = [];

  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new RecipeParseError(
      'The recipe must be a JSON object.',
      ['The top level of the response must be a JSON object, not an array or a primitive.'],
      rawText,
    );
  }
  const record = value as Record<string, unknown>;

  const title = asTrimmedString(record.title);
  if (!title) fatal.push('"title" is required and must be a non-empty string.');

  const servings = asPositiveInt(record.servings);
  if (servings === null) fatal.push('"servings" is required and must be a positive number.');

  const instructions = normalizeInstructions(record.instructions);
  if (!instructions) {
    fatal.push('"instructions" is required and must be a non-empty string (or an array of steps).');
  }

  let prepMinutes: number | null = null;
  const rawPrep = record.prep_minutes ?? record.estimated_prep_minutes;
  if (rawPrep !== undefined && rawPrep !== null) {
    const numeric = typeof rawPrep === 'number' ? rawPrep : Number(rawPrep);
    if (Number.isFinite(numeric) && numeric >= 0) prepMinutes = Math.round(numeric);
    else warnings.push(`"prep_minutes" was ${String(rawPrep)}, which is not a duration. Dropped.`);
  }

  let cuisineTags: string[] = [];
  if (Array.isArray(record.cuisine_tags)) {
    cuisineTags = record.cuisine_tags
      .map((tag) => asTrimmedString(tag))
      .filter((tag): tag is string => tag !== null)
      .map((tag) => tag.toLowerCase());
  } else if (record.cuisine_tags !== undefined && record.cuisine_tags !== null) {
    warnings.push('"cuisine_tags" was not an array. Dropped.');
  }

  const ingredients: GeneratedIngredient[] = [];
  if (!Array.isArray(record.ingredients) || record.ingredients.length === 0) {
    fatal.push('"ingredients" is required and must be a non-empty array.');
  } else {
    for (const [index, entry] of record.ingredients.entries()) {
      if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) {
        warnings.push(`Ingredient ${index + 1} was not an object. Skipped.`);
        continue;
      }
      const item = entry as Record<string, unknown>;
      const name = asTrimmedString(item.name) ?? asTrimmedString(item.display_name);
      if (!name) {
        warnings.push(`Ingredient ${index + 1} had no name. Skipped.`);
        continue;
      }

      ingredients.push({
        name: name.toLowerCase(),
        display_name: asTrimmedString(item.display_name) ?? name,
        quantity:
          typeof item.quantity === 'number' || typeof item.quantity === 'string' ? item.quantity : 1,
        unit: typeof item.unit === 'string' ? item.unit.trim() : '',
        category: normalizeCategory(item.category, warnings, name),
        // Whatever the model guessed here is overwritten from the database.
        // It cannot know what is in the fridge; it is only asked so the shape
        // stays stable.
        likely_already_have: item.likely_already_have === true,
      });
    }

    if (ingredients.length === 0) {
      fatal.push('None of the entries in "ingredients" had a usable name.');
    }
  }

  if (fatal.length > 0) {
    throw new RecipeParseError('The recipe JSON was missing required fields.', fatal, rawText);
  }

  return {
    recipe: {
      title: title as string,
      servings: servings as number,
      prep_minutes: prepMinutes,
      cuisine_tags: cuisineTags,
      instructions: instructions as string,
      ingredients,
    },
    warnings,
  };
}

/** Parse and validate in one step. */
export function parseRecipeResponse(rawText: string): ValidationResult {
  return validateGeneratedRecipe(extractJson(rawText), rawText);
}
