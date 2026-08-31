# Pantry

A personal, single-user grocery agent. You say what you feel like eating; it
finds a recipe, checks what you already have, fills an Instacart cart with only
the missing ingredients, and then tracks what you bought so it can tell you what
is about to go bad and what to cook to use it up.

**Status: Phases 1, 2, 4 and 5 complete.** Phase 3 (Instacart) is deliberately
not built yet — it needs a Developer Platform key and a docs check first.

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
supabase/migrations/            numbered SQL migrations, applied in order
supabase/seed.sql               generated; do not edit by hand
supabase/functions/<name>/      one Edge Function per directory
supabase/functions/_shared/     everything the functions share
supabase/functions/_shared/units/       the conversion engine
supabase/functions/_shared/data/        shelf-life reference dataset
scripts/seed.ts                 idempotent seeder
```

Shared code lives under `_shared/` rather than a top-level `src/` because that
is the only place the Edge Function bundler can reach it. Relative imports carry
`.ts` extensions, which Deno needs and which `allowImportingTsExtensions` makes
work under tsc, vitest and tsx too.

## Endpoints

| Endpoint | Phase | What it does |
|---|---|---|
| `POST /recipe-suggest` | 2 | Generate a recipe and diff it against the pantry |
| `POST /order-confirm` | 4 | The only path that writes bought goods into the pantry |
| `POST /order-abandon` | 4 | Nothing was bought; restores restock rows |
| `POST /pantry-edit` | 4 | Manual add / update / delete |
| `POST /recipe-cooked` | 5 | FEFO depletion — the step everything else depends on |
| `GET /recipe-feasibility/:id` | 5 | Can I make this right now? |
| `POST /low-stock-check` | 5 | Idempotent daily sweep |
| `POST /pantry-reconcile` | 5 | Drift correction |
| `POST /leftovers-suggest` | 5 | Recipes ranked by at-risk food cleared |

`POST /cart-create` (Phase 3) is not built yet.

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

## Phases 2, 4 and 5: what is here

### The three-way diff (Phase 2)

Recipe requirements are compared against the pantry in canonical units, and the
answer has three states, not two:

- **have enough** — do not buy it
- **have some** — buy it anyway, and say how short you are
- **have none** — buy it

Being told "you have rice" when you have 80 g and need 200 g is worse than being
told nothing, because you skip it at the shop and find out mid-recipe. Partial
coverage still goes in the cart.

The model's own `likely_already_have` guess is always overwritten from the
database. It cannot know what is in the fridge.

Lots measured in a different canonical unit are never counted: 12 eggs by count
cannot satisfy 200 g of egg. That is flagged rather than silently mixed.

### Depletion (Phase 5)

`/recipe-cooked` is the step that makes the digest and the leftovers
suggestions possible. Scale by servings, convert through `toCanonical()`,
deplete the soonest-expiring lot first, and:

- staples are skipped entirely — "a pinch of salt" decrements nothing
- anything at or below 5% of the original is treated as gone
- **drift is never floored away.** Using more than the pantry says existed is
  real information: it is clamped at zero, recorded on the consumption event as
  a shortfall, returned in the response, and turned into a restock row

Every change to a remaining quantity goes through one module (`consumption.ts`)
and writes a `consumption_events` row. Nothing else touches that column.

### Shortfalls in purchase units

Grams are right for arithmetic and wrong for a shopping list. `/recipe-feasibility`
returns "about another half a bunch", never "47 g short". The conversion back is
derived per lot from what was actually recorded at purchase time, so it stays
self-consistent even where the conversion data is imperfect.

### Waste urgency

`/leftovers-suggest` ranks the pantry by how much would be wasted if nothing
changed — urgency decaying with days left, weighted by how much is left. A
nearly-full bag of spinach expiring in two days far outranks a nearly-empty jar
of mustard expiring in three months.

The scoring function is pure and its weights are exposed
(`DEFAULT_WEIGHTS` in `_shared/wasteScore.ts`) because the weighting is a matter
of taste and will want tuning. Candidate recipes are ranked by what they
**actually** clear, not by what the model was asked to use.

## Next: Phase 3 (Instacart)

Blocked on an Instacart Developer Platform API key. Before any of it is written,
the current docs get fetched and the endpoint path, request schema, field names
and valid units list get confirmed — the spec's description is directionally
right but flagged as possibly stale.
