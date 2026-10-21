# Step 1: the casino (build contract)

The casino is the front door: a new session opens in it (`Main.START_LEVEL`). Design source:
`docs/INFLUENCES.md` sections 2 (CS:GO), 10 (Buckshot Roulette), "The first five minutes" and
"Decisions" 5, 6, 8, 21, 22. Art: `docs/ASSETS.md` (packs keep their own colors; rarity reads through
glow, outline, flash and beams). No text panels. Everything works by click or tap.

## Money, every machine

1. Check `amount <= compute_extra(ctx)["extra_cents"]` and `amount <= caps_remaining(ctx)`. If not,
   `raise ApiError(409, "Not this week.")`. In the room: the lamp over the slot clicks off and the dealer
   says it. Nothing else changes.
2. `move(ctx, "chk_1", to_account, amount, reason=..., event={...})` with `to_account` in
   `{"sav_1", "brk_1"}` (House Fund, Brokerage). Exact amounts only. Then roll the cosmetic.
3. The response always carries `money: {amount_cents, to_account, status}` so the game plays the
   money-landing beat (motes to the jar, chant) before anything random.

## The loads (pity you can see)

- **Belt**: 25 shells, 18 common, 6 rare, 1 epic, drawn without replacement. When the epic fires,
  a fresh belt loads. So an epic or better comes within 25 cases, always.
- **Box**: 100 holes with 2 hidden special holes, each legendary, or mythic one time in four. Each case
  uses one hole; when a special hole comes up, it fires instead of the belt (the belt doesn't advance).
  When both specials have fired, a fresh box loads. So a legendary or better within 100, always.
- The dealer's counts are public: belt counts left by tier, box holes used, specials announced
  ("Two gold" / "One gold. One red"), and `next_is_special` (the gold tell, always true).
- Target averages: about 67 / 22 / 7.5 / 2.2 / 0.7 percent. A test fires 100,000 cases and checks the
  rates and the two guarantees.
- Reel filler is drawn only from tiers still in the loads, so near-misses are honest.
- Scratch books, the wheel and the claw run their own counted loads (below). Nothing touches the belt
  except cases.

## Content

`content/casino/items.json`: at least 60 cosmetics in two sets, five tiers.
Each: `{id, name, tier, set, slot, icon: {sheet: "res://art/packs/...png", rect: [x, y, w, h]}}`.
Slots: `hat`, `cloak`, `aura`, `charm`, `follower_skin`. Icons come from the packs (Kyrise RPG icons,
Shikashi icons, Shattered Pixel Dungeon items, DawnLike), never a missing file.
`content/casino/machines.json`: case prices (1000, 2000, 5000), scratch prices (100, 200, 500) with
book contents, wheel price and wedges, claw price and heap size.

## API (`backend/features/casino/`)

| Route | Body | Returns |
| --- | --- | --- |
| `GET /casino/catalog` | | `{items, sets, tiers, trophies: [{id, name, items}]}` (static) |
| `POST /casino/case` | `case_id, to_account` | `{money, shell: {tier, source: "belt"\|"box"}, item, reel: [{item_id, tier}], winner_index, near_miss_tier}` |
| `POST /casino/scratch` | `price_cents, to_account` | `{money, item, tier, symbols: [9 tier strings]}` |
| `POST /casino/wheel` | `to_account` | `{money, wedge_index, item}` |
| `POST /casino/claw` | `to_account, drop_x` (0 to 1) | `{money, grabbed: {slot_index, tier}, item}` |
| `POST /casino/tradeup` | `inventory_ids` (10 ids, same tier, not legendary or mythic) | `{item}` |
| `POST /casino/equip` | `item_id` (a casino piece or a trophy) | `{equipped: {slot: item_id}}` |

`reel` is about 45 cards with the winner at `winner_index` (about 38). Every route that grants an item
also emits `ctx.emit("item", item_id=..., name=..., tier=...)`.

`GET /state` gets a `casino` section:

```
casino: {
  can_spend_cents, destinations: [{id, name, balance_cents}],
  cases: [{id, price_cents}],
  belt: {size: 25, left: {common, rare, epic}},
  box: {size: 100, used, specials: ["legendary", ...] (announced, still unfired), next_is_special},
  scratch: [{price_cents, size: 20, left: {tier: n}}],
  wheel: {price_cents, wedges: [{tier, taken}]},          # 12 wedges; taken ones are off until it resets
  claw: {price_cents, heap: [{slot_index, tier, x, y}]},  # x, y in 0..1 across the glass
  draw: {week_start, entries, tickets_total, draws_on, last: {week, won: [item_id]} | null},
  owned: {item_id: count}, inventory: [{inventory_id, item_id}], equipped: {slot: item_id},
  trophies: {item_id: count},                            # owned pieces from the trophy shelves
  dealer: {name: "Vex", line: "Twenty-five shells. One purple."}   # what he says right now
}
```

- **Scratch books**: 20 tickets each with stated contents ($1: 16 common, 4 rare. $2: 14 common, 5 rare,
  1 epic. $5: 12 common, 5 rare, 2 epic, 1 legendary). A fresh book loads when one runs out.
- **Wheel**: $5, 12 wedges (7 common, 3 rare, 1 epic, 1 legendary). A won wedge comes off until the
  wheel resets, which happens when the legendary is won or all wedges are gone.
- **Claw**: $5, a heap of 15 (10 common, 4 rare, 1 epic) at fixed spots. The server picks the heap item
  nearest `drop_x` (with a small seeded wobble). Every grab wins something. A fresh heap when empty.
- **Weekly draw**: entries = every $5 that landed in an own account this week (game transfers plus the
  bank's savings and investment transfers). The village holds 100 tickets in total; the cultists hold the
  rest. On Sunday (a `@daily` hook) ten tickets are drawn; each of the owner's that wins grants a
  cosmetic (first draws are the best tier). Cosmetics only.
- **Trade-up**: ten owned items of one tier (common, rare or epic) become one random item of the next
  tier. Legendary can't be traded up, so mythic only comes from the box.
- **Trophy shelves**: the other features' cosmetics (`content/gate`, `content/minigames`,
  `content/followers` `items.json`) get their own spreads at the back of the book, one per file, in the
  same shape. Owned ones show in color and can be worn; missing ones are silhouettes. They never go in
  the press.

## Godot (`game/features/casino/`)

| File | What | Owner |
| --- | --- | --- |
| `feature.gd`, `casino_room.gd` | the room (start level), dealer Vex with speech bubble, belt peg rack and box grid on the wall, case shelf, machines, chanting followers at the back, door to the village | room builder |
| `case_overlay.gd` | pick destination, hold the bill 0.45 s, money lands (motes, chant), then the CS:GO reel and the reveal; legendary and mythic cutscenes | reel builder |
| `casino_fx.gd` | shared juice: `burst`, `flash`, `hit_stop`, `zoom`, `money_landed`, rarity glow | reel builder (stub ready) |
| `scratch_overlay.gd`, `wheel_overlay.gd`, `claw_overlay.gd` | the three side machines | machines builder |
| `book_overlay.gd`, `draw_overlay.gd` | collection book (silhouettes, equip, trade-up) and the weekly draw drum | book builder |

Overlay constructors: `CaseOverlay.new(case_id: String)`, `ScratchOverlay.new()`, `WheelOverlay.new()`,
`ClawOverlay.new()`, `BookOverlay.new()`, `DrawOverlay.new()`. Each calls the API itself, plays its moment,
and closes with the API result (or null if backed out). Stubs exist so every builder's checkout compiles.
