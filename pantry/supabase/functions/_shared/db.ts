/**
 * Supabase client and row types.
 *
 * Edge Functions run with the service role key, which bypasses RLS. That is the
 * intended design (see migration 0012): the anon key in the Expo bundle can do
 * nothing, and all real access is mediated here.
 */

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { requireEnv } from './env.ts';
import type { CanonicalUnit, Confidence, PantryCategory } from './units/types.ts';

export type { SupabaseClient };

export function serviceClient(): SupabaseClient {
  return createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

// --- row types -------------------------------------------------------------
// Hand-written rather than generated, because `supabase gen types` needs a live
// project and this has to compile without one. Keep in step with the migrations.

export interface PantryItemRow {
  id: string;
  name: string;
  display_name: string;
  category: PantryCategory;
  purchase_quantity: number | null;
  purchase_unit: string | null;
  canonical_quantity_original: number;
  canonical_quantity_remaining: number;
  canonical_unit: CanonicalUnit;
  quantity_confidence: Confidence;
  acquired_at: string;
  storage_location: 'refrigerated' | 'pantry' | 'frozen';
  estimated_expiry: string | null;
  expiry_confidence: Confidence;
  source: 'instacart_order' | 'manual_entry' | 'receipt_scan';
  order_id: string | null;
  is_staple: boolean;
  depleted_at: string | null;
  discarded: boolean;
  low_stock_threshold_canonical: number | null;
  typical_purchase_canonical: number | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface PreferencesRow {
  id: number;
  dislikes: string[];
  dietary_notes: string;
  default_servings: number;
  default_store_zip: string | null;
  spice_tolerance: string;
}

export interface RecipeRow {
  id: string;
  title: string;
  source: 'llm_generated' | 'web';
  source_url: string | null;
  instructions: string;
  ingredients_json: unknown;
  servings: number;
  estimated_prep_minutes: number | null;
  cuisine_tags: string[];
  was_cooked: boolean;
  my_rating: number | null;
  created_at: string;
}

/**
 * Everything currently in the pantry.
 *
 * Deliberately includes `canonical_quantity_remaining` for every row: the model
 * has to be told HOW MUCH of each thing is on hand, not just that it exists.
 * "Half a bunch of cilantro" and "a full bunch" lead to different recipes.
 */
export async function loadActivePantry(client: SupabaseClient): Promise<PantryItemRow[]> {
  const { data, error } = await client
    .from('pantry_items')
    .select('*')
    .is('depleted_at', null)
    .order('estimated_expiry', { ascending: true, nullsFirst: false });

  if (error) throw new Error(`Failed to load pantry_items: ${error.message}`);
  return (data ?? []) as PantryItemRow[];
}

/** The single preferences row, creating it on first use if it is missing. */
export async function loadPreferences(client: SupabaseClient): Promise<PreferencesRow> {
  const { data, error } = await client.from('preferences').select('*').eq('id', 1).maybeSingle();
  if (error) throw new Error(`Failed to load preferences: ${error.message}`);
  if (data) return data as PreferencesRow;

  const { data: created, error: insertError } = await client
    .from('preferences')
    .insert({ id: 1 })
    .select()
    .single();
  if (insertError) throw new Error(`Failed to create the preferences row: ${insertError.message}`);
  return created as PreferencesRow;
}
