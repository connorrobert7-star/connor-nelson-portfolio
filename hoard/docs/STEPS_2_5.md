# Steps 2 to 5: build contract

The owner asked for Steps 2 to 5 in one pass, on top of Step 1 (the casino, `docs/CASINO.md`). Design
source: `docs/INFLUENCES.md` (especially "How they combine" and "Decisions where the studies overlap").
Rules: `CLAUDE.md` and `docs/FEATURES.md`. No text panels, everything by click or tap, packs keep their
own colors, rarity reads through glow and light.

Four features are built in parallel, each fully (backend, content, Godot, art from packs, tests, tour).
Step 4 (juice everywhere) and the cross-feature wiring happen after they merge with the casino.

## Platform pieces you can rely on

- Own accounts: `sav_1` House Fund, `sav_2` Emergency Fund (the wall), `brk_1` Brokerage
  (`money.budget.OWN_ACCOUNTS`). Debt ids from `state.debts` (`debt_card`, `debt_car`, `debt_student`).
- `money.budget.landed_cents(ctx, start, end)`: money that landed in own accounts (game transfers and
  bank savings/investment transfers). `last_landing_day(ctx)`. `/state` has `last_landing_day`.
- `core.services.away(ctx, kind, priority, **payload)` queues a "while you were out" beat; `/state`
  has `away` (unseen, ordered); `POST /away/seen {ids}`.
- `add_coins`, `coin_balance`, `grant_item`, `owned_items`, `notify`, `@daily` hooks, the demo clock.
- Godot: `Level` tap-to-walk/tap-to-use, `SpeechBubble`, `Overlay`, `Sfx.play_path`, `main.toast/shake`,
  `CasinoFx` (burst, flash, hit_stop, zoom, money_landed, float_text) once the casino merges (a copy of
  its API is in `docs/CASINO.md`; until then call your own small helpers).
- Cosmetic catalogs share one item shape: `{id, name, tier, set, slot, icon: {sheet, rect}}`. Each
  feature keeps its own catalog file in `content/<id>/items.json`; ids are prefixed with the feature id.

## Coins (one economy)

Earned by play only: minigame runs, the dungeon, follower loyalty. Spent on: pity rerolls and extra
wheel spins (casino, wired after merge), follower food, and nothing that moves money. Money never buys
coins. Targets for a day of play: about 300 to 500 coins. Prices: gruel 5, stew 15, favorite food 25,
pity reroll 120, extra wheel spin 80.

## A. `minigames` (Step 2): the arcade

- Level `arcade` (door from the village plot `arcade`): a dark arcade with three cabinets: Mine, Fishing,
  Dungeon. Each opens an Overlay. Two minutes each, fast, loud.
- Lantern: 3 flames a day give full coins; later runs pay 25%. Flames refill at the day line.
- `POST /minigames/start {game}` -> `{run_id, seed, flames_left, modifiers}`;
  `POST /minigames/finish {run_id, result}` -> `{coins, items}`. The server caps coins per game.
- **Mine**: tap or click to swing; ore pops out with a crunch; dig deeper by clearing a layer; deeper
  layers have better ore (copper, silver, gold, gem); a 2-minute timer; Coin Fever when you chain hits.
- **Fishing**: cast with a tap, wait for a bite, then a timing bar: hold to keep the marker in the moving
  zone until the catch meter fills. Rarer fish have twitchier zones. Each fish is worth coins.
- **Dungeon** (daily): three rooms and a boss, Shattered Pixel Dungeon pacing, the leader plus two
  followers auto-fight while the player taps targets and uses one item. Each door scores a Balatro-style
  cascade (chips x mult) against a carved target. Modifiers come from the real week, shown as omens on
  the stairs (no text): tavern `packed` -> enemies faster; crops `wilting`/`withered` -> less HP;
  drains `river: low` -> a leech enemy appears; money landed this week -> start with a buff; a kept
  week streak -> an extra follower. Pays coins per room and one cosmetic from its own shuffle bag
  (`content/minigames/items.json`, at least 10 items) on the boss.

## B. `gate` (Step 2): the debt bosses

- Level `gate` (village plot `gate`, the edge of the map): each debt is a boss outside the gate, smallest
  first. HP is the real balance (`state.balances[debt_id]`), shown as a bar and a number on the boss.
- A real fight: the boss idles, telegraphs, roars. The player attacks by paying: tap the boss, pick an
  amount (the minimum payment, $25, $50, $100, $250) from little coin-stacks, hold to strike. The payment
  is `move(ctx, "chk_1", debt_id, amount, ...)` after the extra and caps check (refusal: the gate stays
  shut, "Not this week."). Damage equals the dollars exactly, with hit stop, a damage number and shake.
- Interest is the boss healing exactly once a month on its due day (`@daily`): it telegraphs, says the
  amount, and heals by `round(balance * apr / 1200)`. In demo mode the fixture balance already includes
  interest, so the heal is shown, not added again.
- Payments the bank made since the last visit (`LOAN_PAYMENTS_*` transactions) play as auto-attacks in
  the while-you-were-out queue (`away(ctx, "gate_hit", ...)`).
- Killing a boss (balance 0): a death sequence and a cosmetic only that boss drops
  (`content/gate/items.json`, one per debt kind plus a few spares), granted once.
- `GET /state` -> `gate: {bosses: [{debt_id, name, kind, hp_cents, max_hp_cents, apr, due_day,
  next_heal_cents, defeated}], can_spend_cents, amounts}`; `POST /gate/attack {debt_id, amount_cents}`.

## C. `followers` (Step 3): the flock

- Followers: the personal follower (an egg until a deposit lands in this save, then a tap-only naming
  rite, seven growth stages by kept weeks: 1, 2, 4, 8, 13, 26, 52); one holding follower per held stock
  (its creature from `content/market.json`, sized weekly by portfolio share; over 40% it is visibly huge
  and the others stare at it); nameless cultists to fill the risers.
- Meters, shown on bodies and never as bars: **Faith** (cult-wide, from days since `last_landing_day`:
  fervent 0-2 days, content 3-6, doubting 7-13, mourning 14+), **Belly** per follower (drains daily,
  refilled only with coin food), **Loyalty** per follower (from play: feeding, petting, dungeon runs).
- The week's reactions show on them: crops over budget -> hungry poses and growling; tavern packed ->
  lazy, sleeping; money landed -> they run to the shrine and chant. A missed week (extra above 0 and
  nothing landed) -> mourning on Monday: veils, a dirge, a candle on the Grave of Weeks.
- They wear the skins the owner wins: `POST /followers/dress {follower_id, item_id}` (any owned item
  from any catalog with slot hat, cloak, aura or follower_skin).
- `POST /followers/feed {follower_id, food}` (coins), `POST /followers/pet {follower_id}` (loyalty, once
  a day each), `POST /followers/name {name}` (choose from three offered names).
- "While you were out": an Overlay that plays the `away` queue in priority order (money that landed,
  builds, gate hits, mourning, followers' poses, the personal follower's hug), 12 s or less, every beat
  tappable, then marks them seen. Daily hooks queue the beats.
- `GET /state` -> `followers: {faith: {band, days_since_landing}, personal: {...}, holdings: [...],
  cultists: n, mourning: bool, foods: [...]}`.
- Godot: a reusable `Flock` node any level can place (`Flock.new(filter, rect)`): followers idle-animate
  (bob, blink, look around), show mood from across the room (posture, aura, sweat drops, zzz), wear
  equipped items, react to taps (hop, purr), and chant on `money_moved` events. Level `shrine` (village
  plot `shrine`): the altar, the feeding bowl, the Grave of Weeks, the full flock.

## D. `village` (Step 5): the hub

- Rework `game/scripts/village.gd` (owned by this feature for this step) into a hub you pass through:
  plots with doors to `casino`, `arcade`, `gate`, `shrine`; the house plot; the wall. Cut every walk-up
  text panel (`add_zone`). Numbers live on things (a painted number on the house sign, the wall's
  height marks, prices on doors' lamps).
- The house builds in stages as the House Fund grows toward its target (`content/village/house.json`,
  a $40,000 down payment in the demo): foundation, frame, walls, roof, interior, finished, with a
  building animation when a stage is crossed (queued as an away beat if it happened while away).
- The wall is the Emergency Fund (`sav_2`): its height is the fund against 3 months of expenses
  (average monthly outflow from transactions); a full wall glows. When money leaves it, bricks fall
  (shown, never caused by the game).
- Savings bundles, Stardew style: stone tablets with sockets by ruined buildings. Bundles fill from real
  behavior: no-spend week (a week with no tavern or market spending), five deposits, a $250 week,
  groceries under budget twice, a debt payment, three minigame flames in a day. A full tablet restores
  its building (the granary sells favorite foods; the ossuary shows trophies; the bell tower rings on
  paydays). `backend/features/village`: bundle progress from the ledger and events.
- One stats screen: an Overlay with the real numbers (balances, extra, bills, debts, the life clock,
  this week's ledger), opened by tapping the ledger stone in the square. It is the only place with a
  table of numbers.

## After the merge (orchestrator)

Casino plot and door in the village, the flock in the casino's risers and the shrine, coin sinks in the
casino (rerolls, extra spins), gate and dungeon cosmetics in the collection book, Step 4 juice across
every scene, the full playtest, the web build.
