# Piece 1: buildings worth saving for (build contract)

Source: `docs/DESIGN_NOTES.md` (October 21, 2026, piece 1). Rules: `CLAUDE.md`, `docs/FEATURES.md`.
No text panels, everything by click or tap, packs keep their colors. Numbers live on things.

## The rule, in one line

Balance thresholds unlock a tier. Coins build it. Real days finish it. Money never buys coins, and
nothing here moves money. A broken streak costs the discount and nothing else.

## Words

- **Building**: a place in the village with tiers. Tier 1 is what stands on day one (for the house,
  tier 1 is the empty plot). `land` is a building too: its tiers are parcels of the island.
- **Requirements**: balances the owner must hold, read from `money.budget.balances(ctx)` (so game
  transfers that haven't settled count), plus deposit streaks and other buildings' tiers. They are
  never spent, moved or locked.
- **The Sunday check**: requirements are only checked at the Sunday sync (a `@daily` hook on days
  where `day.weekday() == 6`), plus once when a save first meets this feature (the founding). A tier
  whose requirements all hold at a check becomes **ready** and stays ready until it is built.
  Between checks the game still shows the live numbers (so a deposit shows at once), but readiness
  only flips on Sunday.
- **Week**: Sunday to Saturday (`core.dates.week_start`). The Sunday check reads the week that just
  ended.
- **Deposit**: money that landed in an own account (`money.budget.landed_cents` and its parts: the
  game's transfers to `sav_1`, `sav_2`, `brk_1`, plus the bank's `TRANSFER_OUT_SAVINGS` and
  `TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS`). A week counts when at least
  `streak.min_cents` landed (content, default 1 cent: any deposit).

## Requirements (keys in `content/buildings.json`)

| Key | Holds when | Discountable |
| --- | --- | --- |
| `savings_cents` | `sav_1 + sav_2 >= n` | yes |
| `house_fund_cents` | `sav_1 >= n` | yes |
| `emergency_cents` | `sav_2 >= n` | yes |
| `brokerage_cents` | `brk_1 >= n` | yes |
| `deposit_streak_weeks` | the last `n` completed weeks each had a deposit into any own account (real history, not only since the save began) | no |
| `land` | land is built to tier `>= n` | no |
| `buildings` | `{building_id: tier}`: each is built to at least that tier | no |

"Toward" a building (for the target streak): the accounts its next tier's dollar requirements name
(`savings_cents` and `house_fund_cents` and `emergency_cents` read savings deposits;
`brokerage_cents` reads brokerage deposits). A tier with no dollar requirement takes any deposit.
Savings deposits are game transfers to `sav_1`/`sav_2` plus bank `TRANSFER_OUT_SAVINGS`; brokerage
deposits are game transfers to `brk_1` plus bank `TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS`.

## Construction

- `POST /buildings/build {building_id}` starts the next tier when it is ready, the crew is free, and
  the coins are there. It spends the tier's `coins` (`add_coins(ctx, -coins, ...)`, refusal 409
  "Needs N coins.") and records `started = today`, `finishes = today + days`.
- One crew: one construction at a time across the whole village (land included). Refusal 409
  "The crew is busy." while another site is up.
- A tier with `days: 0` is built at once. Otherwise it is built on the first day `>= finishes`
  (a `@daily` hook finishes it and queues an away beat `building_done`; `/state` also treats a
  finished date as built, so nothing waits on a hook).
- `progress = days_done / days` for the scaffolding. Nothing speeds it up: no route takes coins or
  money to shorten it.
- Built tiers never unbuild, whatever the balances do later.
- **The founding** (first check on a save): every tier whose requirements already hold is built at
  once, in order, for free (the owner saved for those before the game existed). Each building's
  `seen_tier` starts at its built tier so nothing replays. From then on every tier costs coins and
  days. An old save's house keeps its high-water stage (`village_house_built` meta) as built.

## The target and the streak discount

- `POST /buildings/target {building_id}` plants the banner on one building (any building that has
  a next tier). Switching to a different building resets the streak to 0, unless the old target is
  fully built.
- At each Sunday check: if a deposit toward the target landed in the week that ended, the streak
  goes up by one; if not, it goes to 0. That is the only consequence of a missed week.
- While the streak is at least `streak.discount_weeks` (6), the target's dollar requirements are
  multiplied by `1 - streak.discount` (0.8), rounded to whole dollars. Weeks and building
  requirements are not discounted. The discount applies at the Sunday check (and in the live
  numbers shown). If the streak breaks, the discount is gone; a tier that already became ready
  stays ready.

## Effects ("what each tier changes")

Each tier has `changes: {look, followers, unlocks}`:

- `look`: what to draw. Either a pack sprite `{sheet: "res://art/packs/...png", rect: [x, y, w, h],
  scale?, glow?: "#rrggbb", extras?: [...]}` or a custom drawer `{drawer: "house", stage: "<id>"}` /
  `{drawer: "land", parcel: "<id>"}` / `{drawer: "facade", id: "<plot id>", level: n}`.
- `followers`: how many followers this tier adds to the village's capacity. Capacity is the sum over
  built tiers. The flock's cultists scale with it (`followers.cultists` uses band shares of the
  free capacity; at the starting capacity the counts equal today's).
- `unlocks`: keys other features read through `buildings.unlocked(ctx, key) -> int` (a count):
  - `arcade.flame`: one more full-pay lantern flame a day (`minigames.rules.flames_per_day(ctx)`).
  - `land.<parcel>`: that parcel of the island opens (walkable, built on).
  - `plot.<building_id>`: that building's plot appears (the lodge's plot is on the east reach).

## The buildings (day-one values; tune in content, not code)

Coins earned by play are about 300 to 500 a day. The demo save holds $8,450 in the House Fund,
$1,800 in the Emergency Fund (savings $10,250 together), $32,880 in the Brokerage, and the bank
makes a deposit every other week, so a 2-week streak needs one deposit from the game.

| Building | Tier | Name | Requires | Coins | Days | Followers | Unlocks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| land | 1 | Home shore | | 0 | 0 | 8 | land.home, land.commons |
| land | 2 | East reach | savings $10,000, 2-week streak | 500 | 2 | 4 | land.east, plot.lodge |
| land | 3 | South meadow | savings $15,000, brokerage $40,000, 6-week streak | 1,500 | 4 | 4 | land.south |
| land | 4 | North cliffs | savings $30,000, brokerage $60,000, 13-week streak | 4,000 | 7 | 6 | land.north |
| house | 1 | Plot | | 0 | 0 | 0 | |
| house | 2 | Foundation | House Fund $1,000 | 100 | 1 | 0 | |
| house | 3 | Frame | House Fund $3,200 | 250 | 2 | 0 | |
| house | 4 | Walls | House Fund $7,200 | 500 | 3 | 0 | |
| house | 5 | Roof | House Fund $12,800 | 900 | 4 | 1 | |
| house | 6 | Interior | House Fund $22,400 | 1,500 | 5 | 1 | |
| house | 7 | Finished | House Fund $40,000 | 2,500 | 7 | 2 | |
| shrine | 1 | Altar | | 0 | 0 | 4 | |
| shrine | 2 | Chapel | savings $2,000, brokerage $1,000, 4-week streak | 600 | 3 | 6 | |
| shrine | 3 | Temple | savings $8,000, brokerage $20,000, 8-week streak | 1,800 | 5 | 8 | |
| shrine | 4 | Cathedral | savings $20,000, brokerage $50,000, 13-week streak | 4,500 | 7 | 10 | |
| arcade | 1 | Arcade | | 0 | 0 | 0 | |
| arcade | 2 | Neon hall | brokerage $35,000 | 500 | 2 | 0 | arcade.flame |
| arcade | 3 | Grand arcade | brokerage $50,000, savings $15,000 | 2,000 | 5 | 0 | arcade.flame |
| tavern | 1 | Tavern | | 0 | 0 | 0 | |
| tavern | 2 | Inn | Emergency Fund $3,000, 2-week streak | 400 | 2 | 4 | |
| tavern | 3 | Lodge house | Emergency Fund $6,000, savings $12,000 | 1,500 | 4 | 6 | |
| lodge | 1 | Bunkhouse | land 2, savings $10,000 | 800 | 3 | 8 | |
| lodge | 2 | Longhouse | land 3, savings $18,000, brokerage $40,000 | 2,500 | 5 | 10 | |
| lodge | 3 | Great hall | land 4, savings $30,000, brokerage $60,000, 13-week streak | 6,000 | 7 | 14 | |

The house's tiers are its existing stages: the old automatic house becomes a building like the
others (its stage thresholds are now requirements, and each stage costs coins and days).
`village.house` keeps its shape for the drawing (`index` is now the built stage, `fill`/`rows`
still fill toward the next stage's requirement, `building` still means a stage the game hasn't
played yet), plus `constructing` and `progress`.

The lodge has no tier 0 standing: until land tier 2 its plot is overgrown. Its tier 1 is a real
construction like any other.

## API (`backend/features/buildings/`)

| Route | Body | Returns |
| --- | --- | --- |
| `POST /buildings/build` | `building_id` | `{building: <entry>, coins}` (409 not ready / crew busy / coins) |
| `POST /buildings/target` | `building_id` | `{target}` (409 nothing left to build there) |
| `POST /buildings/seen` | `building_id` | `{building: <entry>}`: the game played the finished beat |

`GET /state` gets a `buildings` section:

```
buildings: {
  checked_on: "2026-10-18" | null,        # the last Sunday check (or the founding day)
  next_check: "2026-10-25",
  crew: {building_id, tier, started, finishes, days, days_done, progress} | null,
  target: {building_id, streak_weeks, discount_weeks: 6, discount: 0.2, discount_active,
           this_week_toward_cents} | null,  # deposits toward it so far this week
  deposit_streak_weeks: n,                 # any own account, real history, as of the last check
  capacity: {followers: n},
  unlocks: {key: count},
  land: {tier, parcels: ["home", "commons", ...]},
  list: [
    {id, name, plot, tier, max_tier, seen_tier, look, followers,
     constructing: bool, progress: 0..1,
     next: {tier, name, coins, days, look, ready, ready_since,
            discounted: bool,
            requires: [{key, label, need, base_need, have, met_now, met_at_check}],
            can_build: bool, why_not: "ready" | "not_ready" | "crew" | "coins" | null} | null}
  ]
}
```

`have` is the live value (cents, or weeks, or tier). `need` is after the discount; `base_need`
before it. Every route and the section emit nothing that moves money. Tests (in the feature folder)
cover: requirements never spend or move money; readiness flips only at a Sunday check (or the
founding); construction spends coins exactly once and finishes after exactly `days`; one crew; no
speed-up exists; the streak grows, resets on a missed week, and resets on a switch; the discount is
exactly 20% of the dollar requirements at 6 weeks and gone after a miss; a ready tier stays ready;
built tiers never unbuild; the founding builds what already holds; `content/buildings.json`
validates (every requirement key known, tiers numbered from 1, every look's sheet exists and every
rect fits inside it); the flock's devotion (petting coins) is the same for a flock of one and a
flock of ten (money never buys coins).

## Godot

- The island is about twice the size it was: the old village (`home`) plus open `commons` for the
  villagers to roam from day one, and three gated parcels (`east`, `south`, `north`) that open with
  land tiers 2 to 4. A gated parcel reads as land you don't have yet (overgrowth, fog, a rope line,
  a survey stake), never as a wall of text.
- Each building stands on its plot in its current tier's look. Next to it, a signpost shows the
  next tier: one lamp per requirement with an account icon and the painted number (lit when it held
  at the last check, flickering when it holds now but Sunday hasn't come, dark when not), and the
  ghost of the next look. When the tier is ready, a stake shows the coin price; tap the building to
  build (hold to commit, coins fly from the purse to the site). While building: scaffolding that
  rises with `progress`, cultists hammering, tally marks for days left. When finished: the reveal
  plays once, then `POST /buildings/seen`.
- The target is a banner. Tap a building's flagpole to plant it there. The streak is pennants on the
  pole (up to 6); at 6 the sign's numbers drop to the discounted ones with the old ones struck
  through, and the banner glows. A broken streak takes the pennants down and nothing else.
- The flock grows with capacity: more cultists in the village and the shrine.
- Every action by tap or click. No new panels: the stats ledger stone is still the only table.
