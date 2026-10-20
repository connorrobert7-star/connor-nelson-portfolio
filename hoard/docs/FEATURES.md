# Building a Hoard feature

A feature is one self-contained system (the casino, the gate bosses, the creature pens).
It owns four folders and touches nothing else:

| Folder | What goes in it |
| --- | --- |
| `backend/features/<id>/` | `__init__.py` (routes, state section, daily hooks), more modules, `schema.sql`, tests in `test_<id>.py` |
| `content/<id>/` | Data files: catalogs, odds, lines, quests. JSON. |
| `game/features/<id>/` | `feature.gd`, levels/rooms, overlays, `art/` (generated), `tour_<id>.gd` |
| `tools/art/<id>.py` | Generates `game/features/<id>/art/*.png` |

The orchestrator owns the platform (`backend/core`, `backend/money`, `backend/providers`,
`game/scripts`, the village map, `game/features/manifest.gd`). If you need a platform
change, say so in your report instead of editing it.

## The rules that never bend

1. Money is never random and never goes down because of the game. Only cosmetics are
   random. A $20 case moves exactly $20 into the player's own savings or brokerage.
2. Real money only moves from the week's extra, only through `backend/money/transfer.py`
   `move()`, which caps and logs it. Check `compute_extra(ctx)` (and `caps_remaining(ctx)`)
   before calling it. In the demo the transfer provider marks moves `simulated`.
3. No cash prizes, no loot that affects money, nothing that refills or unlocks for money
   unless that money lands in the player's own account.
4. Coins are earned by playing. No route may turn money into coins.
5. Stock picks are allowed at a counter, at weekly prices; recommendations show demo past
   returns, projections and stories, and the player always chooses. No countdown pressure
   on real money.
6. Penalties never touch real money. Bad weeks cost coins or cosmetics at most, and always
   come with a way back.
7. Plain language in all in-game text. No exclamation points in the weekly sermon.

## Backend

```python
# backend/features/casino/__init__.py
from backend.core.context import Ctx
from backend.core.hooks import daily
from backend.core.router import ApiError, route
from backend.core.services import add_coins, grant_item, notify
from backend.core.state import View, finalizer, section
from backend.money.budget import compute_extra
from backend.money.transfer import caps_remaining, move


@section(order=60)            # adds keys to GET /state; keys must be unique across features
def casino_state(ctx: Ctx, view: View) -> dict:
    return {"casino": {...}}


@finalizer(order=60)          # runs after every section, sees the whole state
def casino_lines(ctx: Ctx, state: dict) -> dict:
    return {"dialogue": {**state.get("dialogue", {}), "croupier": {"name": "Vex", "lines": [...]}}}


@route("POST", "/casino/case")  # params come from the JSON body / query, coerced by type hints
def open_case(ctx: Ctx, case_id: str, to_account: str) -> dict:
    if price > compute_extra(ctx)["extra_cents"]:
        raise ApiError(409, "That's more than your extra this week.")
    move(ctx, "chk_1", to_account, price, reason="Case: ...", event={"type": "case_open", ...})
    ...
    ctx.emit("reveal", text="Legendary", sound="reveal_legendary")   # toasts in the game
    return {...}


@daily(order=60)              # once per game day, oldest first, after the morning sync
def tick(ctx: Ctx, day) -> None: ...
```

- `ctx.conn` is SQLite (rows are `sqlite3.Row`), `ctx.today` the game date (the demo clock can
  move it forward with `POST /clock/advance`), `ctx.cmap` the category map, `ctx.profile`,
  `ctx.providers` (bank, brokerage, market, transfers, advisor, credit, life), `ctx.meta()`/
  `ctx.set_meta()` for small key/values (prefix keys with your feature id).
- Each request is one transaction; raising rolls it back. Raise `ApiError(status, message)`
  with a message the player can read.
- Tables go in `backend/features/<id>/schema.sql` with `CREATE TABLE IF NOT EXISTS`, names
  prefixed with the feature id.
- Platform state you can read: `today`, `demo`, `life` (level 1-100, age, death date),
  `coins`, `extra`, `caps_remaining_cents`, `hourly_rate_cents`, `accounts`, `balances`
  (after game transfers), `holdings`, `debts`, plus the `week`, `crops`, `tavern`, `drains`,
  `shrine`, `shop` sections.
- Helpers: `money.budget.balances/compute_extra/hourly_rate_cents/average_weekly`,
  `core.services.add_coins/coin_balance/grant_item/owned_items/notify`,
  `core.life.life_clock/life_minutes`, `core.dates.week_start/add_month`,
  `sync.anchor(ctx)` (the save's first day; fixture data is laid out around it).
- Account ids: `chk_1` checking, `sav_1` House Fund savings, `brk_1` brokerage. Debt ids come
  from `state.debts` (`debt_card`, `debt_car`, `debt_student` in the demo). A transfer to a
  debt id is a payment.
- Tests: `backend/features/<id>/test_<id>.py`, using the `engine`, `ctx`, `state` and
  `client` fixtures from `backend/conftest.py` (pytest finds them automatically; `TODAY`
  is 2026-10-20, the scripted week). Run `pytest backend/` and
  `ruff check . && ruff format --check .` from `hoard/`.

## Godot

```gdscript
# game/features/casino/feature.gd
extends HoardFeature

func id() -> String: return "casino"
func levels() -> Dictionary: return {"casino": CasinoRoom}
func npcs() -> Dictionary: return {"croupier": {"texture": preload("res://features/casino/art/croupier.png"), "frame": 0, "hframes": 1}}
func plot_id() -> String: return "casino"          # a reserved plot in scripts/village.gd PLOTS
func door_level() -> String: return "casino"       # the plot's door leads into this level
func build_village(village: Level, plot: Rect2i) -> void: ...   # once: sprites, block(), add_npc(), add_zone()
func dress_village(village: Level, plot: Rect2i) -> void: ...   # every state change: add to village.dynamic
```

- Levels extend `Level` (outdoor) or `Room` (16x11 interior, door in the bottom wall at
  x 7-8, arrive at `Room.ENTRANCE`). Fill `map` in `_init()`, call `super.build()` first in
  `build()`, place things, and redraw state-driven parts in `dress()`.
  `Room.LEGEND`: `W` wall top, `w` wall face, `f` floor, `c` counter, `t` table, `r` rug, `d` door.
- Helpers on `Level`: `place(texture, footprint, hframes)`, `block(rect)`,
  `add_npc(id, tile, talk_from, action)`, `add_interactable(pos, label_fn, action_fn)`,
  `add_zone(rect, text_fn, grow)`, `add_door(tile, level_id, spawn)`, `feet_at(tile)`,
  `tile_center(tile)`, `small_label(text, pos)`, static `c(cents)` and `hours(h)`.
- Talking: `var d: Dialogue = main.dialogue; d.open(npc_id, name); await d.say([...]);
  var i: int = await d.ask(prompt, options, disabled); d.close()`. `ask` returns -1 on Esc.
- Overlays (case reels, minigames, books): extend `Overlay`, build the UI in code, call
  `close(result)`. Open with `var result = await main.open_overlay(MyOverlay.new())`.
  Overlays render at 480x270 with `canvas_items` stretch; keep fonts 6-10 px.
- Backend calls: `await Game.call_api("GET"/"POST", path, body, query)` returns
  `[data, error]`; `await Game.act(path, body)` posts then refreshes `Game.state`.
  Response `_events` fire `Game.event_fired`; the HUD toasts `coins`, `money_moved`, `item`
  and anything with a `text` field.
- Juice: `Sfx.play(name)` (names in `scripts/sfx.gd`), `main.toast(text, color, sound)`,
  `main.shake(strength)`, colors from `Palette` (rarity colors only for rarity).
- Never keep your own copy of money in GDScript. Read it from `Game.state`.

## Art

`tools/art/<id>.py` writes PNGs with `from palette import *` (see `tools/art/palette.py`).
16x16 tiles and props, 32x32 characters and creatures. Vibrant and strange on a dark
ground: Cult of the Lamb's big eyes, Webkinz softness, a little wrong. After generating,
run `godot --headless --path game --import` so `.import` files exist, and commit both.

## Checking your work

```sh
cd hoard
pytest backend/ && ruff check . && ruff format --check .
python tools/art/<id>.py
godot --headless --path game --import            # must print no SCRIPT ERROR
uvicorn backend.app:app --port 8000 &            # HOARD_TODAY=2026-10-20 for the scripted week
xvfb-run -a godot --path game --rendering-driver opengl3 res://dev/tour.tscn -- /tmp/shots res://features/<id>/tour_<id>.gd
```

A tour script (`game/features/<id>/tour_<id>.gd`) has `func run(kit: TourKit) -> void`
and uses `kit.stand()`, `kit.interact()`, `kit.read_on()`, `kit.choose()`, `kit.press()`,
`kit.hold()`, `kit.key()`, `kit.go_to()`, `kit.overlay()`, `kit.shot()` and
`kit.check(ok, what)`. It must play the feature through the real UI and check what the
player would see. Look at your screenshots before you call it done.
