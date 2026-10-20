# Hoard
Village sim that runs on real money. Godot 4 game + FastAPI backend.

## Rules that never change
- Money is never random. Only cosmetics are random.
- The game never reduces a real balance for any reason.
- No live prices. Holdings update weekly.
- Stocks are bought only at the shop counter, at weekly prices, from extra. No trade
  buttons on the map, no celebrations for buys, no nudges to buy. (Changed Oct 2026:
  real stock picks at the counter are allowed; they're simulated until Phase 4.)
- All money moves go through backend/money/transfer.py and are capped and logged.
- Phases 0 to 2 use fixtures only. Do not add Plaid calls before Phase 3.

## Style
- GDScript, typed. Python 3.12, type hints, ruff.
- Pixel art 16x16 base, 32x32 for followers and the leader.
- Plain language in all in-game text. No exclamation points in the sermon.
- Money is integer cents in the DB and the API. The game only formats it.
- Transaction amounts use Plaid's sign: positive = money out.
- The backend decides every reaction state and writes every line villagers say
  (backend/game/dialogue.py); the game only draws it.
- Every price in the shop also shows as hours of work.

## Run
- backend: uvicorn backend.app:app --reload   (from hoard/)
- game: open game/project.godot in Godot 4.3+
- tests: pytest backend/
- regenerate fixtures: python -m backend.fixtures.generate
- regenerate placeholder art: python tools/make_art.py
- screenshot walk-through: godot --path game res://tour.tscn -- <out_dir>
