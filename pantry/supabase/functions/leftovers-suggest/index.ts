/**
 * POST /leftovers-suggest
 *
 * The payoff feature. "Tomorrow's digest tells me the remaining half-bunch of
 * cilantro is about to go; I tap through and get two options, ranked by how
 * much at-risk food each one clears."
 *
 * Body: { count?: number (2-3), craving?: string }
 *
 * Ranks the pantry by waste urgency, generates several candidate recipes with
 * different at-risk items pinned as must_use, then ranks the RESULTS by how
 * much at-risk food each actually consumes -- because what the model was asked
 * to use and what it used are not the same thing.
 */

import { anthropicClient, generateRecipe } from '../_shared/anthropic.ts';
import { loadActivePantry, loadPreferences, serviceClient } from '../_shared/db.ts';
import { badRequest, ok, readJsonBody, serveHandler } from '../_shared/http.ts';
import { describeAmount, describeDaysUntil } from '../_shared/humanize.ts';
import { writeLog } from '../_shared/logging.ts';
import { applyCoverageToIngredients, diffAgainstPantry } from '../_shared/pantryDiff.ts';
import { buildSystemPrompt, buildUserPrompt } from '../_shared/prompts.ts';
import { rankByWasteUrgency, type WasteScore } from '../_shared/wasteScore.ts';
import { normalizeItemName } from '../_shared/units/itemNames.ts';

/** How many at-risk items to consider when building the must_use sets. */
const CANDIDATE_POOL = 5;

/**
 * Build several must_use sets from the ranked at-risk items.
 *
 * They overlap on the most urgent item but differ below it, which is what stops
 * the three suggestions coming back as three versions of the same dish.
 */
function buildMustUseSets(ranked: WasteScore[], count: number): string[][] {
  const names = ranked.slice(0, CANDIDATE_POOL).map((entry) => entry.item.display_name);
  if (names.length === 0) return [];

  const sets: string[][] = [];
  // Prefer recipes that clear several at-risk items at once, so the first set
  // is the greediest.
  sets.push(names.slice(0, Math.min(3, names.length)));
  if (names.length >= 2) sets.push([names[0] as string, ...names.slice(3, 5)].filter(Boolean));
  if (names.length >= 2) sets.push(names.slice(1, 3));

  const unique = sets
    .map((set) => [...new Set(set)])
    .filter((set) => set.length > 0)
    .filter((set, index, all) => all.findIndex((other) => other.join('|') === set.join('|')) === index);

  return unique.slice(0, count);
}

export const handler = serveHandler(async (request: Request): Promise<Response> => {
  const body = await readJsonBody(request).catch(() => ({}) as Record<string, unknown>);

  let count = 2;
  if (body.count !== undefined && body.count !== null) {
    const numeric = Number(body.count);
    if (!Number.isFinite(numeric) || numeric < 1 || numeric > 3) {
      throw badRequest('"count" must be between 1 and 3.');
    }
    count = Math.round(numeric);
  }

  const craving =
    typeof body.craving === 'string' && body.craving.trim() !== ''
      ? body.craving.trim()
      : 'something that uses up what is about to go bad';

  const client = serviceClient();
  const [preferences, pantry] = await Promise.all([loadPreferences(client), loadActivePantry(client)]);

  const today = new Date();
  const ranked = rankByWasteUrgency(pantry, today);

  if (ranked.length === 0) {
    return ok({
      at_risk: [],
      options: [],
      message: 'Nothing in the pantry is at risk right now.',
    });
  }

  const atRisk = ranked.slice(0, CANDIDATE_POOL).map((entry) => ({
    name: entry.item.name,
    display_name: entry.item.display_name,
    score: entry.score,
    days_left: entry.daysLeft,
    expires: describeDaysUntil(entry.daysLeft),
    remaining: describeAmount(Number(entry.item.canonical_quantity_remaining), entry.item.canonical_unit, {
      purchaseQuantity: entry.item.purchase_quantity,
      purchaseUnit: entry.item.purchase_unit,
      canonicalOriginal: entry.item.canonical_quantity_original,
    }),
    reason: entry.reason,
  }));

  const mustUseSets = buildMustUseSets(ranked, count);
  const systemPrompt = buildSystemPrompt();
  const anthropic = anthropicClient();

  // Run the candidates concurrently; one failing must not lose the others.
  const settled = await Promise.allSettled(
    mustUseSets.map((mustUse) =>
      generateRecipe(anthropic, {
        systemPrompt,
        userPrompt: buildUserPrompt({
          craving,
          servings: preferences.default_servings,
          mustUse,
          pantry,
          preferences,
          today,
        }),
      }),
    ),
  );

  const scoreByName = new Map(ranked.map((entry) => [entry.item.name, entry]));
  const options = [];
  const failures: string[] = [];

  for (const [index, outcome] of settled.entries()) {
    if (outcome.status === 'rejected') {
      const message = outcome.reason instanceof Error ? outcome.reason.message : String(outcome.reason);
      failures.push(message);
      await writeLog(client, {
        source: 'anthropic',
        event: 'leftovers.generate.failed',
        requestBody: { must_use: mustUseSets[index] },
        errorMessage: message,
      });
      continue;
    }

    const { recipe } = outcome.value;
    const diff = diffAgainstPantry(recipe.ingredients, pantry);

    // Rank by what the recipe ACTUALLY clears, not by what it was asked to use.
    let clearedScore = 0;
    const uses: Array<{ display_name: string; amount: string; proportion_of_remaining: number }> = [];

    for (const entry of diff.coverage) {
      const scored = scoreByName.get(normalizeItemName(entry.ingredient.name)) ?? scoreByName.get(entry.normalizedName);
      if (!scored) continue;

      const remaining = Number(scored.item.canonical_quantity_remaining);
      if (!(remaining > 0) || entry.canonicalUnit !== scored.item.canonical_unit) continue;

      const used = Math.min(entry.requiredCanonical, remaining);
      const proportion = used / remaining;
      clearedScore += scored.score * proportion;

      uses.push({
        display_name: scored.item.display_name,
        amount: describeAmount(used, entry.canonicalUnit, {
          purchaseQuantity: scored.item.purchase_quantity,
          purchaseUnit: scored.item.purchase_unit,
          canonicalOriginal: scored.item.canonical_quantity_original,
        }),
        proportion_of_remaining: Number(proportion.toFixed(3)),
      });
    }

    // Saved to `recipes`, which the spec defines as "everything I've been
    // shown". It also gives the client a recipe_id to cook or cart the option
    // with -- without one, a suggestion is a dead end.
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
      .select('id')
      .single();

    if (insertError) {
      failures.push(`Generated "${recipe.title}" but could not save it: ${insertError.message}`);
      continue;
    }

    options.push({
      id: (stored as { id: string }).id,
      requested_must_use: mustUseSets[index] ?? [],
      title: recipe.title,
      servings: recipe.servings,
      prep_minutes: recipe.prep_minutes,
      cuisine_tags: recipe.cuisine_tags,
      instructions: recipe.instructions,
      ingredients: applyCoverageToIngredients(diff),
      at_risk_cleared_score: Number(clearedScore.toFixed(4)),
      // "uses your spinach, half the feta, and the last 2 eggs"
      uses_up: uses,
      summary:
        uses.length > 0
          ? `Uses ${uses.map((use) => `${use.amount} of your ${use.display_name}`).join(', ')}.`
          : 'Does not actually use anything that is at risk.',
      need_to_buy: diff.needToBuy.length,
    });
  }

  options.sort((a, b) => b.at_risk_cleared_score - a.at_risk_cleared_score);

  if (options.length === 0) {
    throw new Error(
      `Could not generate any leftovers suggestions. Last error: ${failures[0] ?? 'unknown'}`,
    );
  }

  return ok({
    at_risk: atRisk,
    options,
    generation_failures: failures,
  });
});

const denoGlobal = (globalThis as { Deno?: { serve?: (h: (r: Request) => Promise<Response>) => unknown } }).Deno;
if (denoGlobal?.serve) denoGlobal.serve(handler);
