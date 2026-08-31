# Pantry

A personal, single-user grocery agent. You say what you feel like eating; it
finds a recipe, checks what you already have, fills an Instacart cart with only
the missing ingredients, and then tracks what you bought so it can tell you what
is about to go bad and what to cook to use it up.

**Status: Phase 1 complete.** Schema, seed data, and the unit conversion engine.
Nothing calls Anthropic or Instacart yet.

## Two things about this project that shape everything else

**The Instacart API cannot place an order.** It builds a hosted recipe page and
returns a URL; checkout happens when you open that URL on Instacart Marketplace
yourself. The app's job ends at "here's your filled cart, tap to review and
check out". Because of that, the pantry cannot be written at cart-creation time
— there is an explicit confirmation step (Phase 4), and only a confirmed order
writes rows into `pantry_items`.

**Buying is not consuming.** Ordering adds an item at full quantity. The
quantity only goes down when you mark a recipe cooked, adjust it by hand, or
throw something out.

## Layout

```
supabase/migrations/   numbered SQL migrations, applied in order
supabase/seed.sql      generated from the datasets below; do not edit by hand
src/units/             the conversion engine
src/data/shelfLife.ts  shelf-life reference dataset
scripts/seed.ts        idempotent seeder
```

## Phase 1: what is here

### Schema (`supabase/migrations/`)

Twelve migrations covering `pantry_items`, `unit_conversions`, `restock_list`,
`consumption_events`, `shelf_life_reference`, `recipes`, `orders`,
`preferences`, and a `logs` table that Phase 3 will write to. Foreign keys,
partial indexes on the columns that actually get filtered, and RLS enabled and
forced on every table.

RLS is not doing multi-tenant work here — there is one user. It exists because
the anon key ships inside the Expo bundle and must be assumed public. No policy
grants `anon` anything, so with RLS on it reads zero rows and writes nothing.
All real access goes through Edge Functions holding the service role key.

A few constraints are worth knowing about because they will reject bad writes:

| Constraint | What it stops |
|---|---|
| `pantry_items_remaining_within_original` | remaining exceeding what was bought |
| `canonical_quantity_remaining >= 0` | going negative instead of flagging drift |
| `pantry_items_name_check` | a non-lowercase join key |
| `pantry_items_discarded_implies_depleted` | discarded but still "in stock" |
| `restock_one_pending_per_name_idx` | two pending restock rows for the same item |
| `orders_confirmed_at_matches_status` | a "purchased" order with no confirm time |
| `consumption_events_canonical_amount_check` | a zero-amount event |
| `shelf_life_one_default_per_category_idx` | two category defaults disagreeing |

`restock_one_pending_per_name_idx` is the one that makes the daily low-stock
sweep idempotent by construction rather than by application discipline.

### The conversion engine (`src/units/`)

Everything that touches a number goes through `toCanonical()` first. There are
exactly three canonical units — `g`, `ml`, `count` — and every item resolves to
exactly one of them, so that "1 lb chicken breast" and "2 chicken breasts" can
actually be subtracted from each other.

```ts
import { toCanonical } from './src/units/index.js';

toCanonical('cilantro', 1, 'bunch');
// { canonicalQuantity: 45, canonicalUnit: 'g', confidence: 'low', ... }

toCanonical('chicken breast', 1, 'lb');
// { canonicalQuantity: 453.59, canonicalUnit: 'g', confidence: 'high', ... }
```

Resolution order, most specific first:

1. **item rule** — "1 bunch of cilantro is 45 g"
2. **item density** — "1 cup of flour is 120 g, so 1 pint is 240 g"
3. **universal arithmetic** — "1 lb is 453.59 g", but *only* if it lands on the
   unit this item is measured in. A cup of spinach is 30 g of spinach, not
   236 ml of spinach; letting volume math answer for a weight-measured item is
   the bug that turns a pantry into fiction.
4. **category fallback** — forced to `low` confidence, always
5. **category density**
6. **unresolved** — recorded as a raw count with a warning naming the missing
   `unit_conversions` row

`toCanonical()` never throws. It is fed LLM output and scraped web pages, so
every input path ends in a usable number plus an honest confidence and a list of
warnings.

Three details that took the most care:

- **Word-boundary matching.** `egg` must not match `eggplant`; `pea` must not
  match `peach`. Both are real entries in the dataset.
- **Name normalization is asymmetric on purpose.** `chopped` is noise and gets
  stripped, so "finely chopped fresh cilantro, divided" and "1 bunch cilantro"
  collapse to one key. `ground` is not noise — ground beef and beef keep for
  different lengths of time and are not substitutes — so it stays. When unsure,
  the word is kept: a false non-match shows up as "you need to buy this", which
  is visible; a false match silently decrements the wrong thing.
- **Bare `oz` is ambiguous.** On an item measured by volume it is read as fluid
  ounces (a 16 oz bottle of olive oil is 16 fluid ounces), with a warning.

The dataset lives in `src/units/conversionData.ts` and is the single source of
truth; `unit_conversions` in Postgres is a projection of it, so the table stays
inspectable and hand-editable without silently diverging from the code.

### Shelf-life data (`src/data/shelfLife.ts`)

164 rows: a default per category plus item-specific patterns that beat it.
**Every number is an estimate.** They are typical best-quality windows, and real
food ignores them constantly. Nothing derived from this table may be phrased as
if the app knows when something actually expires — the UI must mark every date
as an estimate.

## Running it

```bash
npm install
npm test          # 70 tests, no database needed
npm run typecheck
```

### Applying the schema

Point `supabase/migrations/` at your project however you normally do (the
Supabase CLI, or paste each file into the SQL editor in numeric order).

Then seed:

```bash
cp .env.example .env.local     # fill in SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY
npm run seed
```

Other modes:

```bash
npm run seed:dry    # build and validate everything, touch nothing
npm run seed:sql    # regenerate supabase/seed.sql instead of connecting
```

The seeder is safe to re-run. Every seeded row carries a stable `seed_key` and
the upsert targets that column, so re-running updates the rows the script owns
and leaves anything you added by hand (`seed_key` null) completely alone. It
also will not reset the `preferences` row once it exists.

### What you should see

```
Built 918 unit conversions and 164 shelf-life rows.
```

and, in the database:

| table | rows |
|---|---|
| `unit_conversions` | 918 |
| `shelf_life_reference` | 164 |
| `preferences` | 1 |

Running `npm run seed` a second time leaves those counts unchanged.

Worth poking at in the table editor:

```sql
-- the same unit meaning different things for different foods
select item_name_pattern, from_unit, multiplier, to_canonical_unit, confidence
from unit_conversions
where from_unit = 'cup' and item_name_pattern in ('flour','rice','sugar','spinach','cilantro');

-- everything the engine knows about garlic
select from_unit, multiplier, to_canonical_unit, confidence, notes
from unit_conversions where item_name_pattern = 'garlic';
```

## Next: Phase 2

Recipe generation and ingredient parsing — a `POST /recipe-suggest` Edge
Function that loads preferences and the current pantry (with remaining
quantities, not just presence), calls Claude for a strict-JSON recipe, and
cross-references the result against `pantry_items` in canonical units to produce
the three-way have-enough / have-some / have-none split.
