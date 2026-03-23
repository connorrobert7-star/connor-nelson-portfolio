import { createClient, SupabaseClient } from "@supabase/supabase-js";

export type Story = {
  id: string;
  headline: string;
  dek: string | null;
  body: string;
  source_url: string;
  source_platform: string;
  category: "subcultures" | "small-town" | "micro-celebrity";
  audience_size_estimate: number | null;
  documentary_score: number;
  found_at: string;
  embedding: number[] | null;
  created_at: string;
};

let _supabase: SupabaseClient | null = null;

export function getSupabase(): SupabaseClient {
  if (!_supabase) {
    _supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY!
    );
  }
  return _supabase;
}

export const supabase = new Proxy({} as SupabaseClient, {
  get(_target, prop) {
    return (getSupabase() as unknown as Record<string | symbol, unknown>)[prop];
  },
});
