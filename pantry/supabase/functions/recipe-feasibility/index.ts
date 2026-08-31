/**
 * GET /recipe-feasibility/:recipe_id?servings=N
 * POST /recipe-feasibility  { recipe_id, servings? }
 *
 * "Can I actually make this right now?" -- callable at any time, not just at
 * generation. The pantry changes underneath saved recipes, so this must be hit
 * every time a recipe is opened rather than trusting anything stored.
 *
 * Shortfalls come back in purchase units, never grams.
 */

import { loadActivePantry, serviceClient } from '../_shared/db.ts';
import { summarizeFeasibility } from '../_shared/feasibility.ts';
import { CORS_HEADERS, badRequest, errorResponse, ok } from '../_shared/http.ts';
import { diffAgainstPantry } from '../_shared/pantryDiff.ts';
import { loadRecipe, readStoredIngredients } from '../_shared/recipes.ts';
import { addToRestockList } from '../_shared/restock.ts';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Accept the id from the path (GET) or the body (POST). */
async function readParams(request: Request): Promise<{ recipeId: string; servings: number | null }> {
  const url = new URL(request.url);

  if (request.method === 'POST') {
    let body: Record<string, unknown> = {};
    try {
      body = (await request.json()) as Record<string, unknown>;
    } catch {
      throw badRequest('Request body is not valid JSON.');
    }
    const recipeId = typeof body.recipe_id === 'string' ? body.recipe_id : '';
    if (!UUID_RE.test(recipeId)) throw badRequest('"recipe_id" must be a UUID.');
    return { recipeId, servings: parseServings(body.servings) };
  }

  // /functions/v1/recipe-feasibility/<uuid>
  const tail = url.pathname.split('/').filter(Boolean).pop() ?? '';
  const recipeId = UUID_RE.test(tail) ? tail : (url.searchParams.get('recipe_id') ?? '');
  if (!UUID_RE.test(recipeId)) {
    throw badRequest('Provide the recipe id in the path (/recipe-feasibility/<uuid>) or as ?recipe_id=.');
  }
  return { recipeId, servings: parseServings(url.searchParams.get('servings')) };
}

function parseServings(value: unknown): number | null {
  if (value === undefined || value === null || value === '') return null;
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric <= 0 || numeric > 100) {
    throw badRequest('"servings" must be a number between 1 and 100.');
  }
  return Math.round(numeric);
}

async function handleRequest(request: Request): Promise<Response> {
  if (request.method !== 'GET' && request.method !== 'POST') {
    throw badRequest(`Expected GET or POST, got ${request.method}.`);
  }

  const { recipeId, servings } = await readParams(request);
  const client = serviceClient();

  const recipe = await loadRecipe(client, recipeId);
  const ingredients = readStoredIngredients(recipe);
  const effectiveServings = servings ?? recipe.servings;
  const scale = effectiveServings / recipe.servings;

  const pantry = await loadActivePantry(client);
  const diff = diffAgainstPantry(ingredients, pantry, { scale });
  const report = summarizeFeasibility(diff, effectiveServings);

  // Anything short or missing becomes a restock row, so the next cart already
  // knows you wanted more rice for that stir-fry. Deduplicated by name, so
  // opening the same recipe repeatedly does not pile up rows.
  const restock = [];
  for (const entry of diff.needToBuy) {
    const suggested = entry.shortfallCanonical > 0 ? entry.shortfallCanonical : entry.requiredCanonical;
    restock.push(
      await addToRestockList(client, {
        name: entry.normalizedName,
        displayName: entry.ingredient.display_name,
        pantryItemId: entry.matchedLots[0]?.id ?? null,
        suggestedQuantityCanonical: suggested,
        suggestedCanonicalUnit: entry.canonicalUnit,
        reason: 'recipe_shortfall',
        triggeringRecipeId: recipeId,
      }),
    );
  }

  return ok({
    recipe: { id: recipe.id, title: recipe.title, servings: recipe.servings },
    ...report,
    restock_updates: restock,
    warnings: diff.coverage.flatMap((entry) => entry.warnings),
  });
}

export const handler = async (request: Request): Promise<Response> => {
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: { ...CORS_HEADERS, 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS' },
    });
  }
  try {
    return await handleRequest(request);
  } catch (error) {
    return errorResponse(error);
  }
};

const denoGlobal = (globalThis as { Deno?: { serve?: (h: (r: Request) => Promise<Response>) => unknown } }).Deno;
if (denoGlobal?.serve) denoGlobal.serve(handler);
