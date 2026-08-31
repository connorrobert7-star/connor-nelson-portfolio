/**
 * Environment access.
 *
 * Reads from Deno (Edge Functions) or Node (tests, scripts) without importing
 * either runtime's types, so this module compiles under tsc with Node types and
 * still works when Supabase runs it under Deno.
 */

interface EnvSource {
  get(key: string): string | undefined;
}

function envSource(): EnvSource {
  const deno = (globalThis as { Deno?: { env?: EnvSource } }).Deno;
  if (deno?.env) return deno.env;

  const node = (globalThis as { process?: { env?: Record<string, string | undefined> } }).process;
  if (node?.env) {
    const table = node.env;
    return { get: (key) => table[key] };
  }

  return { get: () => undefined };
}

export function optionalEnv(key: string): string | undefined {
  const value = envSource().get(key);
  return value === undefined || value.trim() === '' ? undefined : value.trim();
}

/**
 * Throws with a message naming the variable and where to get it. A function
 * that fails at startup with a clear reason beats one that fails on the first
 * request with "undefined is not a string".
 */
export function requireEnv(key: string): string {
  const value = optionalEnv(key);
  if (value === undefined) {
    throw new ConfigurationError(
      `${key} is not set. See .env.example for what it is and where to get it. ` +
        'For a deployed Edge Function, set it with: supabase secrets set ' +
        `${key}=...`,
    );
  }
  return value;
}

/** Missing or malformed configuration, as distinct from a bad request. */
export class ConfigurationError extends Error {
  override readonly name = 'ConfigurationError';
}
