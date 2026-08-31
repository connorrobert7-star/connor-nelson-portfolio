/**
 * Quantity parsing.
 *
 * Recipes are written by humans and by an LLM imitating humans, so quantities
 * arrive as "2", "1 1/2", "1½", "2-3", "a couple of", "half". All of it has to
 * land on a number before any conversion can happen, and the parse itself
 * carries a confidence: "2" is exact, "a few" is not, and that distinction has
 * to survive into the pantry row.
 */

import type { Confidence } from './types.ts';

export interface ParsedQuantity {
  value: number;
  confidence: Confidence;
  warnings: string[];
}

const UNICODE_FRACTIONS: Record<string, number> = {
  '½': 0.5,
  '⅓': 1 / 3,
  '⅔': 2 / 3,
  '¼': 0.25,
  '¾': 0.75,
  '⅕': 0.2,
  '⅖': 0.4,
  '⅗': 0.6,
  '⅘': 0.8,
  '⅙': 1 / 6,
  '⅚': 5 / 6,
  '⅐': 1 / 7,
  '⅛': 0.125,
  '⅜': 0.375,
  '⅝': 0.625,
  '⅞': 0.875,
  '⅑': 1 / 9,
  '⅒': 0.1,
};

/** Exact-valued words. Parsing these keeps full confidence. */
const EXACT_WORDS: Record<string, number> = {
  a: 1,
  an: 1,
  one: 1,
  two: 2,
  three: 3,
  four: 4,
  five: 5,
  six: 6,
  seven: 7,
  eight: 8,
  nine: 9,
  ten: 10,
  eleven: 11,
  twelve: 12,
  dozen: 12,
  half: 0.5,
  quarter: 0.25,
  third: 1 / 3,
};

/**
 * Deliberately vague words. They get a number so the pipeline can proceed, but
 * confidence drops to low and never recovers.
 */
const VAGUE_WORDS: Record<string, number> = {
  couple: 2,
  few: 3,
  several: 3,
  some: 1,
  many: 4,
};

/** Turn "1½" into "1 ½" and "½" into a parseable token. */
function expandUnicodeFractions(input: string): string {
  let out = '';
  for (const char of input) {
    const value = UNICODE_FRACTIONS[char];
    out += value === undefined ? char : ` ${value} `;
  }
  return out;
}

function parseNumericToken(token: string): number | null {
  // "1/2" or "3/4"
  const fraction = /^(\d+)\s*\/\s*(\d+)$/.exec(token);
  if (fraction) {
    const numerator = Number(fraction[1]);
    const denominator = Number(fraction[2]);
    if (denominator === 0) return null;
    return numerator / denominator;
  }
  if (/^\d*\.?\d+$/.test(token)) {
    const value = Number(token);
    return Number.isFinite(value) ? value : null;
  }
  return null;
}

/**
 * Parse a free-text or numeric quantity.
 *
 * Ranges ("2-3 cloves") collapse to their midpoint at medium confidence: the
 * midpoint is the least-wrong single number, and pretending it was exact would
 * launder a guess into the pantry as fact.
 */
export function parseQuantity(input: number | string | null | undefined): ParsedQuantity {
  const warnings: string[] = [];

  if (input === null || input === undefined || input === '') {
    // An ingredient with no stated quantity is one of the thing ("salt to taste",
    // "1 onion" written as "onion"). Assume one, but say so.
    return { value: 1, confidence: 'low', warnings: ['No quantity given; assumed 1.'] };
  }

  if (typeof input === 'number') {
    if (!Number.isFinite(input) || input <= 0) {
      return {
        value: 1,
        confidence: 'low',
        warnings: [`Quantity ${input} is not a usable positive number; assumed 1.`],
      };
    }
    return { value: input, confidence: 'high', warnings };
  }

  const normalized = expandUnicodeFractions(input)
    .toLowerCase()
    .replace(/[,]/g, '')
    .replace(/\bof\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (normalized === '') {
    return { value: 1, confidence: 'low', warnings: ['Empty quantity; assumed 1.'] };
  }

  // Range: "2-3", "2 to 3". Take the midpoint.
  const range = /^(\d*\.?\d+(?:\s*\/\s*\d+)?)\s*(?:-|–|—|to)\s*(\d*\.?\d+(?:\s*\/\s*\d+)?)$/.exec(
    normalized,
  );
  if (range) {
    const low = parseNumericToken(range[1] ?? '');
    const high = parseNumericToken(range[2] ?? '');
    if (low !== null && high !== null) {
      return {
        value: (low + high) / 2,
        confidence: 'medium',
        warnings: [`Range ${range[1]}-${range[2]} collapsed to its midpoint.`],
      };
    }
  }

  // Mixed numbers and word/numeric sequences: "1 1/2", "1 0.5", "two".
  const tokens = normalized.split(' ').filter(Boolean);
  let total = 0;
  let sawNumber = false;
  let confidence: Confidence = 'high';

  for (const token of tokens) {
    // "a" in "a couple" is an article, not a quantity. Only a lone "a" means one.
    if ((token === 'a' || token === 'an') && tokens.length > 1) continue;

    const numeric = parseNumericToken(token);
    if (numeric !== null) {
      total += numeric;
      sawNumber = true;
      continue;
    }
    const exact = EXACT_WORDS[token];
    if (exact !== undefined) {
      total += exact;
      sawNumber = true;
      continue;
    }
    const vague = VAGUE_WORDS[token];
    if (vague !== undefined) {
      total += vague;
      sawNumber = true;
      confidence = 'low';
      warnings.push(`"${token}" is approximate; treated as ${vague}.`);
      continue;
    }
    // Unrecognized token (e.g. "about", "large"). Ignore it but note it.
    if (token !== 'about' && token !== 'approximately' && token !== '~') {
      warnings.push(`Ignored unrecognized quantity token "${token}".`);
    }
  }

  if (!sawNumber || total <= 0) {
    return {
      value: 1,
      confidence: 'low',
      warnings: [...warnings, `Could not parse quantity "${input}"; assumed 1.`],
    };
  }

  return { value: total, confidence, warnings };
}
