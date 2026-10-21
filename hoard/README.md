# Hoard

A private village game that runs on the owner's real money. Every pull at a machine is a real
order from cash already in the brokerage. The village (buildings, the flock, the gate) grows from
real balances. It never sells, never picks a stock, never lowers a balance, and coins and money
never convert either way. Design and rules: `docs/DESIGN_NOTES.md`, `CLAUDE.md`, `docs/*.md`.

> ## ⚠️ PAPER FIRST. AT LEAST ONE FULL WEEK ON PAPER BEFORE ANY LIVE KEYS.
>
> Every order goes to the broker's **paper** account unless `HOARD_LIVE=1` is in `.env`.
> Real keys alone do **not** make it live. Run on paper for a week, check every fill against
> the moomoo app, and only then add `HOARD_LIVE=1`.

## Run the demo (fake money, no keys)

```sh
cd hoard
pip install fastapi uvicorn pytest httpx ruff
uvicorn backend.app:app --reload        # http://127.0.0.1:8000/state
```

Open `game/project.godot` in Godot 4.3 and press F5. Everything is tap or click. In the demo,
"next day" in the top right lets a day pass. The browser build (`tools/build_web.py`) runs the
same Python engine in the page.

## Day one: the broker check (moomoo paper)

The game trades through moomoo's OpenAPI, which talks to a small gateway app, **OpenD**, that you
run on your own computer. Do this once:

1. **Paper account.** In the moomoo app, open **Paper Trading** and make sure there is a US stock
   paper account with cash in it (you can reset it to its starting cash there).
2. **Install OpenD.** Download the GUI version for your computer from
   <https://www.moomoo.com/download/OpenAPI>, install it, and open it.
3. **Log in to OpenD** with your moomoo login. Leave the API listen address at `127.0.0.1` and the
   port at `11111` (the defaults). If OpenD asks you to agree to the OpenAPI terms or finish a
   short questionnaire, do that; moomoo asks once before the API works.
4. **Install the Python library** (same Python you run Hoard with):
   ```sh
   pip install moomoo-api
   ```
5. **Run the check during US market hours** (9:30 to 16:00 Eastern on a trading day; moomoo's
   paper trading doesn't fill before or after hours):
   ```sh
   cd hoard
   python tools/broker_check.py              # about $5 of VTI, paper
   python tools/broker_check.py --symbol AAPL
   ```
   It connects to OpenD, reads a quote only to size the order, sends the share count to three
   decimals (rounded down, never up), waits for the fill, and prints the dollar target next to the
   actual fill and what's left as cash. It is always paper, whatever `.env` says.

   - **PASS**: moomoo filled a fractional paper order. Tell Claude; the game's orders use the same
     code.
   - **FAILED**: moomoo didn't take the fractional order. Stop and tell Claude the Status line.
     Alpaca (dollar-amount orders) is the fallback.
   - **STOPPED**: OpenD isn't reachable or the library isn't installed; the message says which.
   - If it says there's **no quote** for the symbol, check the API quote permissions for US stocks
     in the moomoo app, or try another symbol.

## `.env` keys

Put these in `hoard/.env` (never committed; `.gitignore` has `.env*`). Values already set in the
shell win over the file. Anything left out falls back to the demo.

| Key | What it does |
| --- | --- |
| `HOARD_LIVE` | `1` sends real-money orders. Anything else, or missing, means **paper**, even with real keys. |
| `HOARD_BROKER` | `fixture` (demo, default), `moomoo`, or `alpaca`. Where every pull's order goes. |
| `MOOMOO_HOST` | OpenD address. Default `127.0.0.1`. |
| `MOOMOO_PORT` | OpenD API port. Default `11111`. |
| `MOOMOO_ACC_ID` | Optional. Pick one moomoo account by id; otherwise the first US stock account for paper or live. |
| `MOOMOO_TRADE_PASSWORD` | Live only: unlocks trading. The GUI OpenD can unlock it with its own button instead. |
| `ALPACA_KEY_ID`, `ALPACA_SECRET_KEY` | Alpaca, the fallback broker (dollar-amount orders, paper unless `HOARD_LIVE=1`). The trading side is a stub for now. |
| `HOARD_MARKET` | `fixture` or `alpaca`: weekly prices for the counter (never live prices in the game). |
| `HOARD_BROKERAGE` | `fixture` or `snaptrade`: Fidelity holdings, **read only**, for the followers view. |
| `SNAPTRADE_CLIENT_ID`, `SNAPTRADE_CONSUMER_KEY`, `SNAPTRADE_USER_ID`, `SNAPTRADE_USER_SECRET` | SnapTrade, for reading Fidelity. |
| `HOARD_BANK` | `fixture` or `plaid`: bank accounts, transactions and debts, **read only**. |
| `PLAID_CLIENT_ID`, `PLAID_SECRET`, `PLAID_ACCESS_TOKEN`, `PLAID_ENV` | Plaid, read only. The game never moves bank money; you fund the brokerage yourself with a standing deposit on payday. |
| `HOUSE_FUND` | `bank` (default): count what lands in savings each week and celebrate it. `brokerage:SYMBOL`: every House Fund purchase is an instant order for that symbol. (Coming next; not wired yet.) |
| `HOARD_ADVISOR`, `ANTHROPIC_API_KEY` | `fixture` or `claude`: plain-language stories and money ideas. |
| `HOARD_CREDIT`, `CREDIT_API_KEY` | `fixture` or `bureau`: the credit report. |
| `HOARD_DB` | The save file. Default `backend/db/hoard.sqlite3`. |
| `HOARD_TODAY` | Pin the date (demo and tests), e.g. `2026-10-20`. |

The money rules hold in every mode: the caps in `backend/money/transfer.py` ($500 an order,
$500 a day, $1,000 a week), buy orders only, only from your watchlist, only cash that is already in
the brokerage.

## Tests

```sh
cd hoard
python -m pytest backend -q && ruff check backend && ruff format --check backend
```

The broker tests run moomoo's order flow against a fake OpenD, so they need neither the library
nor a login.
