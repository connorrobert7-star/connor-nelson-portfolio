-- 0004_recipes.sql
-- Every recipe that has been shown, whether cooked or not.

create table recipes (
  id                     uuid primary key default gen_random_uuid(),
  title                  text not null,
  source                 recipe_source not null,
  source_url             text,
  instructions           text not null,
  -- Structured parsed ingredient list. Shape is enforced in application code
  -- (see src/units/types.ts RecipeIngredient), not here, because the LLM output
  -- schema will keep moving and a jsonb check constraint would fight every change.
  ingredients_json       jsonb not null default '[]'::jsonb,
  servings               integer not null check (servings > 0),
  estimated_prep_minutes integer check (estimated_prep_minutes >= 0),
  cuisine_tags           text[] not null default '{}',
  was_cooked             boolean not null default false,
  my_rating              integer check (my_rating between 1 and 5),
  created_at             timestamptz not null default now(),

  constraint recipes_ingredients_is_array check (jsonb_typeof(ingredients_json) = 'array')
);

create index recipes_created_at_idx on recipes (created_at desc);
create index recipes_was_cooked_idx on recipes (was_cooked) where was_cooked = true;
create index recipes_cuisine_tags_idx on recipes using gin (cuisine_tags);
