-- 0001_enums.sql
-- Shared enum types. Every downstream table depends on these, so this runs first.
--
-- NOTE ON CANONICAL UNITS: there are exactly three (g, ml, count) and that is
-- deliberate. All pantry arithmetic happens in canonical units; purchase units
-- ("1 bunch", "1 lb") and recipe units ("2 tbsp", "3 cloves") are only ever
-- display/input forms that get converted at the boundary. Do not add a fourth.

create extension if not exists pgcrypto;

create type pantry_category as enum (
  'produce',
  'dairy',
  'meat',
  'seafood',
  'frozen',
  'pantry_dry',
  'canned',
  'condiment',
  'spice',
  'bakery',
  'beverage',
  'other'
);

create type canonical_unit as enum ('g', 'ml', 'count');

create type confidence_level as enum ('high', 'medium', 'low');

create type pantry_source as enum ('instacart_order', 'manual_entry', 'receipt_scan');

create type restock_reason as enum ('ran_out', 'running_low', 'recipe_shortfall', 'manual_add');

create type restock_status as enum ('pending', 'added_to_cart', 'dismissed');

create type consumption_reason as enum (
  'recipe_cooked',
  'manual_adjustment',
  'discarded_expired',
  'reconciliation'
);

create type recipe_source as enum ('llm_generated', 'web');

create type order_status as enum ('cart_created', 'confirmed_purchased', 'abandoned');

create type storage_location as enum ('refrigerated', 'pantry', 'frozen');
