import { describe, expect, it } from 'vitest';
import { normalizeItemName, parseIngredientText } from '../units/itemNames.js';

describe('normalizeItemName', () => {
  it('strips prep words so a recipe ingredient matches a pantry lot', () => {
    // This is the whole point: these three have to collapse to one key or the
    // pantry diff will report a shortfall for something already in the fridge.
    expect(normalizeItemName('finely chopped fresh cilantro, divided')).toBe('cilantro');
    expect(normalizeItemName('Cilantro')).toBe('cilantro');
    expect(normalizeItemName('fresh cilantro leaves')).toBe('cilantro leaf');
  });

  it('singularizes the head noun only', () => {
    expect(normalizeItemName('chicken breasts')).toBe('chicken breast');
    expect(normalizeItemName('black beans')).toBe('black bean');
    expect(normalizeItemName('tomatoes')).toBe('tomato');
    expect(normalizeItemName('potatoes')).toBe('potato');
  });

  it('drops size adjectives and parentheticals', () => {
    expect(normalizeItemName('2 large eggs (about 100g)')).toBe('egg');
    expect(normalizeItemName('1 medium yellow onion')).toBe('yellow onion');
  });

  it('keeps words that change what the product actually is', () => {
    // ground beef and beef are not the same thing: different shelf life,
    // not substitutable. Stripping "ground" would silently merge them.
    expect(normalizeItemName('ground beef')).toBe('ground beef');
    expect(normalizeItemName('dried oregano')).toBe('dried oregano');
    expect(normalizeItemName('frozen peas')).toBe('frozen pea');
    expect(normalizeItemName('whole milk')).toBe('whole milk');
  });

  it('drops "whole" when it is a quantity word rather than an identity word', () => {
    expect(normalizeItemName('whole onion')).toBe('onion');
    expect(normalizeItemName('whole wheat flour')).toBe('whole wheat flour');
  });

  it('strips packaging and marketing noise', () => {
    expect(normalizeItemName('extra virgin olive oil')).toBe('olive oil');
    expect(normalizeItemName('boneless skinless chicken breasts')).toBe('chicken breast');
    expect(normalizeItemName('organic free-range large eggs')).toBe('egg');
  });

  it('handles empty and junk input without throwing', () => {
    expect(normalizeItemName('')).toBe('');
    expect(normalizeItemName(null)).toBe('');
    expect(normalizeItemName('   ,,,  ')).toBe('');
  });
});

describe('parseIngredientText', () => {
  const cases: Array<[string, { quantity: string; unit: string; name: string }]> = [
    ['1 bunch cilantro', { quantity: '1', unit: 'bunch', name: 'cilantro' }],
    ['2 cloves garlic', { quantity: '2', unit: 'cloves', name: 'garlic' }],
    ['1 lb chicken breast', { quantity: '1', unit: 'lb', name: 'chicken breast' }],
    ['1/2 cup flour', { quantity: '1/2', unit: 'cup', name: 'flour' }],
    ['3 tbsp olive oil', { quantity: '3', unit: 'tbsp', name: 'olive oil' }],
    ['1 can black beans', { quantity: '1', unit: 'can', name: 'black beans' }],
    ['a pinch of salt', { quantity: 'a', unit: 'pinch', name: 'salt' }],
    ['1 head of lettuce', { quantity: '1', unit: 'head', name: 'lettuce' }],
    ['2 large eggs', { quantity: '2', unit: 'large', name: 'eggs' }],
  ];

  it.each(cases)('splits %s', (input, expected) => {
    expect(parseIngredientText(input)).toEqual(expected);
  });

  it('does not mistake the item for a unit when nothing follows it', () => {
    // "2 eggs" is two eggs, not two egg-units of nothing.
    expect(parseIngredientText('2 eggs')).toEqual({ quantity: '2', unit: '', name: 'eggs' });
    expect(parseIngredientText('2 chicken breasts')).toEqual({
      quantity: '2',
      unit: '',
      name: 'chicken breasts',
    });
  });
});
