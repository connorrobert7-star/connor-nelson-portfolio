/**
 * Loading a stored recipe back into the shape the rest of the code works with.
 *
 * ingredients_json is jsonb with no database-level shape check (the LLM output
 * schema moves too fast for that to be anything but an obstacle), so it is
 * validated on the way back out instead.
 */

import type { RecipeRow, SupabaseClient } from './db.ts';
import { notFound } from './http.ts';
import type { GeneratedIngredient } from './recipeSchema.ts';
import { PANTRY_CATEGORIES, type PantryCategory } from './units/types.ts';

export async function loadRecipe(client: SupabaseClient, recipeId: string): Promise<RecipeRow> {
  const { data, error } = await client.from('recipes').select('*').eq('id', recipeId).maybeSingle();
  if (error) throw new Error(`Failed to load recipe ${recipeId}: ${error.message}`);
  if (!data) throw notFound(`No recipe with id ${recipeId}.`);
  return data as RecipeRow;
}

/** Coerce stored ingredients back into GeneratedIngredient, skipping junk. */
export function readStoredIngredients(recipe: RecipeRow): GeneratedIngredient[] {
  const raw = recipe.ingredients_json;
  if (!Array.isArray(raw)) return [];

  const ingredients: GeneratedIngredient[] = [];
  for (const entry of raw) {
    if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) continue;
    const item = entry as Record<string, unknown>;
    const name = typeof item.name === 'string' ? item.name.trim() : '';
    if (name === '') continue;

    const category =
      typeof item.category === 'string' && (PANTRY_CATEGORIES as readonly string[]).includes(item.category)
        ? (item.category as PantryCategory)
        : 'other';

    ingredients.push({
      name,
      display_name: typeof item.display_name === 'string' && item.display_name.trim() !== '' ? item.display_name.trim() : name,
      quantity: typeof item.quantity === 'number' || typeof item.quantity === 'string' ? item.quantity : 1,
      unit: typeof item.unit === 'string' ? item.unit : '',
      category,
      likely_already_have: item.likely_already_have === true,
    });
  }
  return ingredients;
}
