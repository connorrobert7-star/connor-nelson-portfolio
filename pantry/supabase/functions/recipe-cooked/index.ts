/**
 * POST /recipe-cooked
 *
 * Body: { recipe_id, servings_made, substitutions?: [{ skipped_ingredient, used_instead }] }
 *
 * This is the step that makes the whole project work. Everything downstream --
 * the expiry digest, the leftovers suggestions, the restock list -- is only as
 * good as the depletion done here.
 *
 * Rules, all from the spec:
 *   - scale each quantity by servings_made / recipe.servings
 *   - convert through toCanonical() before any arithmetic
 *   - when several lots of the same item exist, deplete the one expiring
 *     soonest first (FEFO)
 *   - staples are skipped entirely
 *   - clamp at zero and FLAG the discrepancy; never go negative and never
 *     silently floor it, because drift is real information
 */

import { applyDepletion } from '../_shared/consumption.ts';
import { loadActivePantry, serviceClient, type PantryItemRow } from '../_shared/db.ts';
import { badRequest, ok, readJsonBody, serveHandler } from '../_shared/http.ts';
import { coverageForIngredient } from '../_shared/pantryDiff.ts';
import { loadRecipe, readStoredIngredients } from '../_shared/recipes.ts';
import { addToRestockList } from '../_shared/restock.ts';
import type { GeneratedIngredient } from '../_shared/recipeSchema.ts';
import { normalizeItemName } from '../_shared/units/itemNames.ts';
import { requireUuid } from '../_shared/validation.ts';

interface Substitution {
  skipped: string;
  usedInstead: string | null;
}

function parseSubstitutions(value: unknown): Substitution[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw badRequest('"substitutions" must be an array.');

  return value.map((entry, index) => {
    if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) {
      throw badRequest(`substitutions[${index}] must be an object.`);
    }
    const item = entry as Record<string, unknown>;
    const skipped = typeof item.skipped_ingredient === 'string' ? item.skipped_ingredient.trim() : '';
    if (skipped === '') {
      throw badRequest(`substitutions[${index}].skipped_ingredient is required.`);
    }
    const usedInstead = typeof item.used_instead === 'string' ? item.used_instead.trim() : '';
    return { skipped, usedInstead: usedInstead === '' ? null : usedInstead };
  });
}

export const handler = serveHandler(async (request: Request): Promise<Response> => {
  const body = await readJsonBody(request);
  const recipeId = requireUuid(body, 'recipe_id');

  const servingsMade = Number(body.servings_made);
  if (!Number.isFinite(servingsMade) || servingsMade <= 0 || servingsMade > 100) {
    throw badRequest('"servings_made" must be a number between 1 and 100.');
  }

  const substitutions = parseSubstitutions(body.substitutions);

  const client = serviceClient();
  const recipe = await loadRecipe(client, recipeId);
  const ingredients = readStoredIngredients(recipe);

  if (ingredients.length === 0) {
    throw badRequest(`Recipe ${recipeId} has no usable ingredient list to deplete from.`);
  }

  const scale = servingsMade / recipe.servings;
  const pantry = await loadActivePantry(client);

  // Substitutions: what was skipped is not depleted, and what replaced it is
  // depleted in its place, at the same quantity and unit.
  const skippedNames = new Set(substitutions.map((s) => normalizeItemName(s.skipped)));
  const effective: GeneratedIngredient[] = [];

  for (const ingredient of ingredients) {
    const normalized = normalizeItemName(ingredient.name);
    if (!skippedNames.has(normalized)) {
      effective.push(ingredient);
      continue;
    }
    const substitution = substitutions.find((s) => normalizeItemName(s.skipped) === normalized);
    if (substitution?.usedInstead) {
      effective.push({
        ...ingredient,
        name: substitution.usedInstead,
        display_name: substitution.usedInstead,
      });
    }
  }

  // A live view of remaining amounts, so two ingredients matching the same lot
  // (say "rice" and "jasmine rice") cannot both spend it.
  const lotState = new Map<string, PantryItemRow>(pantry.map((row) => [row.id, row]));

  const results: Array<Record<string, unknown>> = [];
  const drift: Array<Record<string, unknown>> = [];

  for (const ingredient of effective) {
    const coverage = coverageForIngredient(
      ingredient,
      [...lotState.values()].filter((row) => row.depleted_at === null),
      { scale },
    );

    if (coverage.isStaple) {
      results.push({
        name: coverage.normalizedName,
        display_name: ingredient.display_name,
        outcome: 'skipped_staple',
        required_canonical: coverage.requiredCanonical,
      });
      continue;
    }

    let outstanding = coverage.requiredCanonical;
    const depletedFrom: Array<Record<string, unknown>> = [];

    // matchedLots is already ordered soonest-expiring first (FEFO).
    for (const lot of coverage.matchedLots) {
      if (outstanding <= 0) break;
      const current = lotState.get(lot.id) ?? lot;
      if (current.depleted_at !== null) continue;

      const applied = await applyDepletion(client, current, outstanding, {
        reason: 'recipe_cooked',
        recipeId,
        notes: `Cooked "${recipe.title}" (${servingsMade} of ${recipe.servings} servings).`,
      });

      lotState.set(lot.id, applied.item);
      if (applied.applied > 0) {
        outstanding = Number((outstanding - applied.applied).toFixed(4));
        depletedFrom.push({
          pantry_item_id: lot.id,
          display_name: lot.display_name,
          amount: applied.applied,
          unit: coverage.canonicalUnit,
          now_depleted: applied.depleted,
          expiry_used: lot.estimated_expiry,
        });
      }
      if (applied.applied === 0) break;
    }

    const shortfall = Number(Math.max(0, outstanding).toFixed(4));

    if (shortfall > 0) {
      // Drift: the recipe used more than the pantry says existed. Surfaced,
      // recorded, and turned into a restock row rather than floored away.
      drift.push({
        name: coverage.normalizedName,
        display_name: ingredient.display_name,
        required_canonical: coverage.requiredCanonical,
        found_canonical: Number((coverage.requiredCanonical - shortfall).toFixed(4)),
        shortfall_canonical: shortfall,
        canonical_unit: coverage.canonicalUnit,
      });

      await addToRestockList(client, {
        name: coverage.normalizedName,
        displayName: ingredient.display_name,
        pantryItemId: coverage.matchedLots[0]?.id ?? null,
        suggestedQuantityCanonical: Math.max(shortfall, coverage.requiredCanonical),
        suggestedCanonicalUnit: coverage.canonicalUnit,
        reason: 'recipe_shortfall',
        triggeringRecipeId: recipeId,
      });
    }

    results.push({
      name: coverage.normalizedName,
      display_name: ingredient.display_name,
      outcome: depletedFrom.length === 0 ? 'nothing_on_hand' : shortfall > 0 ? 'partially_depleted' : 'depleted',
      required_canonical: coverage.requiredCanonical,
      canonical_unit: coverage.canonicalUnit,
      shortfall_canonical: shortfall,
      depleted_from: depletedFrom,
    });
  }

  const { error: recipeError } = await client
    .from('recipes')
    .update({ was_cooked: true })
    .eq('id', recipeId);
  if (recipeError) {
    throw new Error(`Depletion succeeded but marking the recipe cooked failed: ${recipeError.message}`);
  }

  return ok({
    recipe_id: recipeId,
    title: recipe.title,
    servings_made: servingsMade,
    scale: Number(scale.toFixed(4)),
    ingredients: results,
    // Non-empty means the pantry data has drifted from reality.
    drift,
    substitutions_applied: substitutions,
  });
});

const denoGlobal = (globalThis as { Deno?: { serve?: (h: (r: Request) => Promise<Response>) => unknown } }).Deno;
if (denoGlobal?.serve) denoGlobal.serve(handler);
