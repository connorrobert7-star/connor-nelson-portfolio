# Hoard: Phase 0

A cozy village that reacts to your spending. This is Phase 0 from the design doc.
It runs on fake data only and moves no money.

## What's in it
- **Backend** (`backend/`): FastAPI + SQLite. On startup it loads 90 days of fake
  transactions, three accounts (checking, House Fund savings, brokerage), five
  holdings and one car loan from `backend/fixtures/`. Dates are shifted so the
  fixtures end yesterday, so "last week" is always the seven days ending yesterday.
  - `GET /state?weeks_ago=0`: the whole village state for one week (0 to 11).
  - `GET /extra`: checking minus bills due in 14 days, minus the $500 floor, minus
    average weekly food and transport. Capped by the $60 weekly case cap.
- **Game** (`game/`): Godot 4.3, one village scene. A tilemap, a leader you can
  walk, a shrine, a shop door, a house plot, a notice board, and three spending
  reactions:
  - **Crops**: groceries against a $120/week budget. Bumper, healthy, wilting, withered.
  - **Tavern**: eating out against $80/week. Quiet with a coin, or packed with
    sleepy regulars.
  - **Drains**: one named drain per subscription in the last 30 days. Total over
    $75 lowers the river. A subscription that first appeared this week is marked new.
  - The shrine glows if money went to savings that week.

The fake "last week" has a story built in: groceries over budget, a quiet tavern,
a new StreamBox+ subscription, and a payday transfer to the House Fund.

## Run it
```sh
cd hoard
pip install -r backend/requirements.txt
uvicorn backend.app:app --reload        # http://127.0.0.1:8000/state
```
Then open `game/project.godot` in Godot 4.3+ and press F5.

| Key | Action |
| --- | --- |
| WASD / arrows | Walk |
| `[` / `]` | Earlier / later week |

Walk up to any building and a panel shows its numbers. Set `HOARD_BACKEND` to
point the game at another host, or `HOARD_TODAY=2026-10-20` to pin the backend's date.

## Tests
```sh
pytest backend/ && ruff check .
```
