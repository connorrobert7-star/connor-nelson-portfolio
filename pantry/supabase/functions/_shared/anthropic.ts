/**
 * The Claude call for recipe generation.
 *
 * Model is claude-sonnet-4-6 per the project spec, overridable with
 * ANTHROPIC_MODEL. Adaptive thinking is on: it costs little at this size and
 * the model is being asked to reason about quantities and substitutions.
 *
 * Retry policy: exactly one corrective retry, and only for a response that
 * could not be parsed or validated. The retry sends the model its own broken
 * output plus a precise list of what was wrong. Transport failures are not
 * retried here -- the SDK already retries those.
 */

import Anthropic from '@anthropic-ai/sdk';
import { requireEnv, optionalEnv } from './env.ts';
import { HttpError } from './http.ts';
import {
  RecipeParseError,
  parseRecipeResponse,
  type ValidationResult,
} from './recipeSchema.ts';

export const DEFAULT_MODEL = 'claude-sonnet-4-6';

export interface GenerateRecipeArgs {
  systemPrompt: string;
  userPrompt: string;
  maxTokens?: number;
}

export interface GenerateRecipeResult extends ValidationResult {
  /** How many model calls it took. 2 means the first response was unusable. */
  attempts: number;
  rawResponses: string[];
  model: string;
}

function textFromMessage(message: Anthropic.Message): string {
  return message.content
    .filter((block): block is Anthropic.TextBlock => block.type === 'text')
    .map((block) => block.text)
    .join('\n')
    .trim();
}

export function anthropicClient(): Anthropic {
  return new Anthropic({ apiKey: requireEnv('ANTHROPIC_API_KEY') });
}

export async function generateRecipe(
  client: Anthropic,
  args: GenerateRecipeArgs,
): Promise<GenerateRecipeResult> {
  const model = optionalEnv('ANTHROPIC_MODEL') ?? DEFAULT_MODEL;
  const maxTokens = args.maxTokens ?? 8000;

  const messages: Anthropic.MessageParam[] = [{ role: 'user', content: args.userPrompt }];
  const rawResponses: string[] = [];
  let lastParseError: RecipeParseError | null = null;

  // Two attempts maximum: the original, and one correction.
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    let message: Anthropic.Message;
    try {
      message = await client.messages.create({
        model,
        max_tokens: maxTokens,
        thinking: { type: 'adaptive' },
        system: args.systemPrompt,
        messages,
      });
    } catch (error) {
      throw translateAnthropicError(error);
    }

    if (message.stop_reason === 'refusal') {
      throw new HttpError(
        'upstream_error',
        'Claude declined to generate this recipe. Try rephrasing the craving.',
        { stopDetails: message.stop_details },
      );
    }

    const text = textFromMessage(message);
    rawResponses.push(text);

    if (message.stop_reason === 'max_tokens') {
      // The JSON is truncated; parsing it is pointless. Say so precisely so the
      // retry produces something shorter.
      lastParseError = new RecipeParseError(
        'The response was cut off before the JSON finished.',
        [`The response hit the ${maxTokens} token limit and the JSON was incomplete. Be more concise.`],
        text,
      );
    } else {
      try {
        const result = parseRecipeResponse(text);
        return { ...result, attempts: attempt, rawResponses, model };
      } catch (error) {
        if (!(error instanceof RecipeParseError)) throw error;
        lastParseError = error;
      }
    }

    if (attempt === 1) {
      // Hand the model its own output back with the specific complaint. This is
      // far more effective than repeating the original prompt.
      messages.push({ role: 'assistant', content: text || '(empty response)' });
      messages.push({ role: 'user', content: lastParseError.correctionPrompt() });
    }
  }

  throw new HttpError(
    'upstream_error',
    'Claude returned a recipe that could not be parsed, twice.',
    { issues: lastParseError?.issues ?? [], lastResponse: lastParseError?.rawText.slice(0, 2000) },
  );
}

function translateAnthropicError(error: unknown): Error {
  if (error instanceof Anthropic.AuthenticationError) {
    return new HttpError('configuration_error', 'ANTHROPIC_API_KEY was rejected. Check the key.');
  }
  if (error instanceof Anthropic.RateLimitError) {
    return new HttpError('upstream_error', 'Rate limited by the Anthropic API. Try again shortly.');
  }
  if (error instanceof Anthropic.APIConnectionTimeoutError) {
    return new HttpError('upstream_timeout', 'The Anthropic API timed out.');
  }
  if (error instanceof Anthropic.APIConnectionError) {
    return new HttpError('upstream_error', 'Could not reach the Anthropic API.');
  }
  if (error instanceof Anthropic.APIError) {
    return new HttpError('upstream_error', `Anthropic API error ${error.status}: ${error.message}`);
  }
  return error instanceof Error ? error : new Error(String(error));
}
