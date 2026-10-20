# Hoard

A cozy village that reacts to your spending. Phase 0 from the design doc plus
walk-in buildings, villagers you can talk to, and a shop that sells real tickers.
It runs on fake data only; shop buys are simulated and move no money.

## What's in it
- **Backend** (`backend/`): FastAPI + SQLite. On startup it loads 90 days of fake
  transactions, three accounts (checking, House Fund savings, brokerage), five
  holdings and one car loan from `backend/fixtures/`. Dates are shifted so the
  fixtures end yesterday, so "last week" is always the seven days ending yesterday.
  - `GET /state?weeks_ago=0`: the whole village state for one week (0 to 11).
  - `GET /extra`: checking minus bills due in 14 days, minus the $500 floor, minus
    average weekly food and transport, minus shop buys this week.
  - `POST /shop/stock {symbol, amount_cents}`: buys from extra through
    `money/transfer.py`, which caps every move ($500 a transfer, $500 a day,
    $1,000 a week) and logs it with the game event that caused it. Written as
    `simulated` until real accounts are connected.
- **Game** (`game/`): Godot 4.3, one village scene. A tilemap, a leader you can
  walk, a shrine, a shop door, a house plot, a notice board, and three spending
  reactions:
  - **Crops**: groceries against a $120/week budget. Bumper, healthy, wilting, withered.
  - **Tavern**: eating out against $80/week. Quiet with a coin, or packed with
    sleepy regulars.
  - **Drains**: one named drain per subscription in the last 30 days. Total over
    $75 lowers the river. A subscription that first appeared this week is marked new.
  - The shrine glows if money went to savings that week.
- **Places and people**: walk into the shop and the tavern. Talk to Wren by the
  fields, Odo at the shrine, Bess behind the bar, and Marlo at the shop counter.
  Their lines come from the week's numbers. Every price also shows as hours of
  work, from your take-home pay over the last four weeks.
- **The shop**: one shelf per stock at last Sunday's price. Talk to Marlo or walk
  up to a shelf to buy $25, $50, $100 or $250 worth.

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
| E / Space / Enter | Talk, look, choose |
| Esc | Back out of a menu |
| `[` / `]` | Earlier / later week |

Walk up to any building and a panel shows its numbers. Set `HOARD_BACKEND` to
point the game at another host, or `HOARD_TODAY=2026-10-20` to pin the backend's date.

## Tests
```sh
pytest backend/ && ruff check .
```
