/**
 * Prompt construction for recipe generation.
 *
 * Split deliberately: the system prompt is stable across every request (role,
 * output schema, rules) and the user prompt carries everything volatile (the
 * craving, the current pantry). That ordering is also what prompt caching wants
 * -- stable prefix first -- so if this ever runs hot the cache works without
 * restructuring.
 */

import type { PantryItemRow, PreferencesRow } from './db.ts';
import { PANTRY_CATEGORIES } from './units/types.ts';

export function buildSystemPrompt(): string {
  return `You are a cooking assistant for one person. You suggest a single recipe that fits what they feel like eating and makes good use of what they already have.

OUTPUT FORMAT -- this is not negotiable:
Return a single raw JSON object and nothing else. No markdown code fences. No explanation before or after. Your first character must be { and your last must be }.

The object must have exactly this shape:
{
  "title": string,
  "servings": number,
  "prep_minutes": number,
  "cuisine_tags": string[],
  "instructions": string,
  "ingredients": [
    {
      "name": string,
      "display_name": string,
      "quantity": number,
      "unit": string,
      "category": string,
      "likely_already_have": boolean
    }
  ]
}

Field rules:
- "name" is the bare product as you would find it in a shop: "chicken breast", "cilantro", "olive oil". No quantities, no descriptors, no preparation. Not "2 cups of chopped fresh cilantro" -- just "cilantro". This name is matched against a pantry database and against a grocery catalogue, so extra words make it fail to match.
- "display_name" is how it should read in a recipe: "fresh cilantro, chopped".
- "quantity" is a number. Use decimals, not fractions: 0.5, not "1/2".
- "unit" is a single unit word: "g", "cup", "tbsp", "clove", "bunch", "can", "lb". Leave it as "" for whole countable things ("2 eggs" is quantity 2, unit "").
- "category" is exactly one of: ${PANTRY_CATEGORIES.join(', ')}.
- "likely_already_have" is your guess only; it is overwritten from the real pantry database afterwards. Do not agonise over it.
- "instructions" is the full method as one string, with numbered steps separated by newlines.

Cooking rules:
- Prefer recipes that use up what is already in the pantry, especially items marked as expiring soon.
- Pay attention to HOW MUCH of each pantry item is left. If there is half a bunch of cilantro, do not write a recipe needing a whole one.
- Never include anything the person dislikes.
- Respect the dietary notes absolutely.
- Assume salt, pepper, oil and common spices are always available; still list them as ingredients.
- Be realistic about quantities for the stated number of servings.`;
}

/** Human-readable pantry line for one lot, including how much is left. */
function describeLot(row: PantryItemRow, today: Date): string {
  const remaining = Number(row.canonical_quantity_remaining);
  const original = Number(row.canonical_quantity_original);
  const percent = original > 0 ? Math.round((remaining / original) * 100) : 100;

  const parts = [`${row.display_name}: ${formatAmount(remaining, row.canonical_unit)} left`];

  if (percent < 95 && original > 0) {
    parts.push(`(about ${percent}% of the ${formatAmount(original, row.canonical_unit)} bought)`);
  }
  if (row.is_staple) parts.push('(staple -- always available)');

  if (row.estimated_expiry) {
    const days = daysUntil(row.estimated_expiry, today);
    if (days !== null) {
      if (days < 0) parts.push('(ESTIMATED past its best already)');
      else if (days <= 3) parts.push(`(USE SOON -- estimated ~${days}d left)`);
      else parts.push(`(estimated ~${days}d left)`);
    }
  }

  return `- ${parts.join(' ')}`;
}

function formatAmount(value: number, unit: string): string {
  if (unit === 'count') {
    const rounded = Math.round(value * 10) / 10;
    return `${rounded} ${rounded === 1 ? 'item' : 'items'}`;
  }
  return `${Math.round(value)} ${unit}`;
}

function daysUntil(isoDate: string, today: Date): number | null {
  const target = new Date(`${isoDate}T00:00:00Z`);
  if (Number.isNaN(target.getTime())) return null;
  const start = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
  return Math.round((target.getTime() - start) / 86_400_000);
}

export interface UserPromptArgs {
  craving: string;
  servings: number;
  mustUse: string[];
  pantry: PantryItemRow[];
  preferences: PreferencesRow;
  today?: Date;
}

export function buildUserPrompt(args: UserPromptArgs): string {
  const today = args.today ?? new Date();
  const sections: string[] = [];

  sections.push(`I feel like eating: ${args.craving}`);
  sections.push(`Servings: ${args.servings}`);

  if (args.preferences.dislikes.length > 0) {
    sections.push(`I dislike (never include these): ${args.preferences.dislikes.join(', ')}`);
  }
  if (args.preferences.dietary_notes.trim() !== '') {
    sections.push(`Dietary notes (absolute): ${args.preferences.dietary_notes.trim()}`);
  }
  if (args.preferences.spice_tolerance.trim() !== '') {
    sections.push(`Spice tolerance: ${args.preferences.spice_tolerance.trim()}`);
  }

  if (args.mustUse.length > 0) {
    // Phase 5's leftovers flow depends on this being obeyed, so it is stated as
    // a hard requirement rather than a preference.
    sections.push(
      `HARD REQUIREMENT -- the recipe must use all of these, and use meaningful ` +
        `amounts of them, because they are about to go bad: ${args.mustUse.join(', ')}`,
    );
  }

  if (args.pantry.length === 0) {
    sections.push('My pantry is empty, so assume I am buying everything.');
  } else {
    const lines = args.pantry.map((row) => describeLot(row, today));
    sections.push(`What I have at home right now (amounts are estimates):\n${lines.join('\n')}`);
  }

  sections.push('Return only the JSON object.');
  return sections.join('\n\n');
}
