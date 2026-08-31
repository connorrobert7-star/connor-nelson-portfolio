/**
 * POST /recipe-suggest
 *
 * Body: { craving: string, servings?: number, must_use?: string[] }
 *
 * Generates a recipe with Claude, then decides from the DATABASE -- not from
 * the model's guess -- what is already in the pantry, in three states:
 * have enough, have some but not enough, have none.
 *
 * The recipe is stored with its own ingredient requirements only, never with
 * the coverage snapshot: the pantry changes underneath saved recipes, so
 * coverage is recomputed on demand (Phase 5's /recipe-feasibility) rather than
 * frozen at generation time.
 */

import { anthropicClient, generateRecipe } from '../_shared/anthropic.ts';
import { loadActivePantry, loadPreferences, serviceClient } from '../_shared/db.ts';
import { badRequest, ok, readJsonBody, serveHandler } from '../_shared/http.ts';
import { writeLog } from '../_shared/logging.ts';
import { applyCoverageToIngredients, diffAgainstPantry } from '../_shared/pantryDiff.ts';
import { buildSystemPrompt, buildUserPrompt } from '../_shared/prompts.ts';
import { normalizeItemName } from '../_shared/units/itemNames.ts';
import { patternMatchesName } from '../_shared/units/toCanonical.ts';

interface RecipeSuggestRequest {
  craving: string;
  servings: number | undefined;
  mustUse: string[];
}

function parseRequest(body: Record<string, unknown>): RecipeSuggestRequest {
  const craving = typeof body.craving === 'string' ? body.craving.trim() : '';
  if (craving === '') {
    throw badRequest('"craving" is required and must be a non-empty string.');
  }
  if (craving.length > 2000) {
    throw badRequest('"craving" is unreasonably long (max 2000 characters).');
  }

  let servings: number | undefined;
  if (body.servings !== undefined && body.servings !== null) {
    const numeric = Number(body.servings);
    if (!Number.isFinite(numeric) || numeric <= 0 || numeric > 50) {
      throw badRequest('"servings" must be a number between 1 and 50.');
    }
    servings = Math.round(numeric);
  }

  let mustUse: string[] = [];
  if (body.must_use !== undefined && body.must_use !== null) {
    if (!Array.isArray(body.must_use)) {
      throw badRequest('"must_use" must be an array of strings.');
    }
    mustUse = body.must_use
      .map((entry) => (typeof entry === 'string' ? entry.trim() : ''))
      .filter((entry) => entry !== '');
  }

  return { craving, servings, mustUse };
}

/**
 * The must_use contract is only worth anything if it is checked. The model is
 * told it is a hard requirement, but "told" is not "did".
 */
function findIgnoredMustUse(mustUse: string[], ingredientNames: string[]): string[] {
  const normalizedIngredients = ingredientNames.map((name) => normalizeItemName(name));
  return mustUse.filter((wanted) => {
    const target = normalizeItemName(wanted);
    if (target === '') return false;
    return !normalizedIngredients.some(
      (name) => name === target || patternMatchesName(name, target) || patternMatchesName(target, name),
    );
  });
}

export const handler = serveHandler(async (request: Request): Promise<Response> => {
  const body = await readJsonBody(request);
  const { craving, servings, mustUse } = parseRequest(body);

  const client = serviceClient();
  const [preferences, pantry] = await Promise.all([
    loadPreferences(client),
    loadActivePantry(client),
  ]);

  const effectiveServings = servings ?? preferences.default_servings;

  const systemPrompt = buildSystemPrompt();
  const userPrompt = buildUserPrompt({
    craving,
    servings: effectiveServings,
    mustUse,
    pantry,
    preferences,
  });

  let generated;
  try {
    generated = await generateRecipe(anthropicClient(), { systemPrompt, userPrompt });
  } catch (error) {
    await writeLog(client, {
      source: 'anthropic',
      event: 'recipe.generate',
      requestBody: { craving, servings: effectiveServings, must_use: mustUse },
      errorMessage: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }

  const { recipe, warnings, attempts, model } = generated;

  if (attempts > 1 || warnings.length > 0) {
    // Not a failure, but worth a record: a rising rate here means the prompt
    // needs work.
    await writeLog(client, {
      source: 'anthropic',
      level: 'warn',
      event: 'recipe.generate.recovered',
      requestBody: { craving, attempts, model },
      responseBody: { warnings },
    });
  }

  const ignoredMustUse = findIgnoredMustUse(mustUse, recipe.ingredients.map((i) => i.name));

  // Coverage is computed against the pantry as it is right now, and returned
  // but NOT stored -- see the note at the top of this file.
  const diff = diffAgainstPantry(recipe.ingredients, pantry);

  const { data: stored, error: insertError } = await client
    .from('recipes')
    .insert({
      title: recipe.title,
      source: 'llm_generated',
      instructions: recipe.instructions,
      ingredients_json: recipe.ingredients,
      servings: recipe.servings,
      estimated_prep_minutes: recipe.prep_minutes,
      cuisine_tags: recipe.cuisine_tags,
    })
    .select()
    .single();

  if (insertError) {
    throw new Error(`Failed to save the recipe: ${insertError.message}`);
  }

  return ok({
    recipe: {
      id: stored.id,
      title: recipe.title,
      servings: recipe.servings,
      prep_minutes: recipe.prep_minutes,
      cuisine_tags: recipe.cuisine_tags,
      instructions: recipe.instructions,
      ingredients: applyCoverageToIngredients(diff),
    },
    summary: {
      have_enough: diff.haveEnough.length,
      have_some: diff.haveSome.length,
      have_none: diff.haveNone.length,
      need_to_buy: diff.needToBuy.length,
    },
    warnings: [
      ...warnings,
      ...(ignoredMustUse.length > 0
        ? [`The recipe does not appear to use: ${ignoredMustUse.join(', ')}.`]
        : []),
      ...diff.coverage.flatMap((entry) => entry.warnings),
    ],
    meta: { model, attempts },
  });
});

// Deno.serve is the Edge Function entrypoint. Guarded so this module can be
// imported by the Node test runner without starting a server.
const denoGlobal = (globalThis as { Deno?: { serve?: (h: (r: Request) => Promise<Response>) => unknown } }).Deno;
if (denoGlobal?.serve) denoGlobal.serve(handler);
