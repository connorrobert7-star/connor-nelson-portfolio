"""The pot (docs/POT.md): runs of lamps on the scratch books, the wheel and the claw, and
one pot of blank pulls' dollars that a hit spends on the owner's pick.

Every pull at a pot machine moves its exact price into the Brokerage first (machines.pay).
This module only keeps the tally: a blank adds its price to the pot; a hit adds its own
price and buys the owner's pick with all of it, at this week's price, through the
brokerage's place_order. The pot never moves money, never lowers a balance and never sells.
The game never picks: without a pick at Marlo's counter the machines refuse before any money
moves.
"""

from backend.core.context import Ctx
from backend.core.router import ApiError
from backend.features.casino import dealer, loads
from backend.features.casino.catalog import machines
from backend.features.shop.shop import pick_info, pot_symbol, price_cents

NO_PICK = dealer.NO_PICK
WRONG_ACCOUNT = "These machines pay into the Brokerage."


def config() -> dict:
    return machines()["pot"]


def account() -> str:
    return config()["to_account"]


def run_keys() -> list[str]:
    return list(config()["runs"])


def scratch_key(price_cents: int) -> str:
    return f"scratch_{price_cents}"


# --- Before any money moves -------------------------------------------------------------


def check(ctx: Ctx, to_account: str | None) -> str:
    """The pot machines' refusals, before move(): a body naming any account but the
    Brokerage is 422; no pick at the counter is 409. Returns the symbol a hit would buy."""
    if to_account is not None and to_account != account():
        raise ApiError(422, WRONG_ACCOUNT)
    symbol = pot_symbol(ctx)
    if symbol is None:
        raise ApiError(409, NO_PICK)
    return symbol


# --- Runs -------------------------------------------------------------------------------


def load_run(ctx: Ctx, key: str) -> None:
    size = config()["runs"][key]
    ctx.conn.execute(
        """INSERT INTO casino_runs (machine, size, hit_at, pos, loads, loaded_on)
           VALUES (?, ?, ?, 0, 1, ?)
           ON CONFLICT(machine) DO UPDATE SET size = excluded.size, hit_at = excluded.hit_at,
             pos = 0, loads = loads + 1, loaded_on = excluded.loaded_on""",
        [key, size, loads.RNG.randrange(size), ctx.today.isoformat()],
    )


def _run(ctx: Ctx, key: str) -> tuple[int, int, int]:
    row = ctx.conn.execute(
        "SELECT size, hit_at, pos FROM casino_runs WHERE machine = ?", [key]
    ).fetchone()
    if row is None:
        load_run(ctx, key)
        return _run(ctx, key)
    return row["size"], row["hit_at"], row["pos"]


def average_one_in(size: int) -> float:
    """A hit comes once every (size + 1) / 2 pulls on average."""
    return (size + 1) / 2


def run_public(ctx: Ctx, key: str) -> dict:
    """What the machine shows: the run's size and the lamps still lit. The chance on the
    next pull is exactly 1 / left, and a hit always comes within `left` pulls."""
    size, _, pos = _run(ctx, key)
    return {"size": size, "left": size - pos, "average_one_in": average_one_in(size)}


def next_lamp(ctx: Ctx, key: str) -> bool:
    """Use the next lamp of the run. True on the hit (and a fresh run loads)."""
    _, hit_at, pos = _run(ctx, key)
    if pos == hit_at:
        load_run(ctx, key)
        return True
    ctx.conn.execute("UPDATE casino_runs SET pos = ? WHERE machine = ?", [pos + 1, key])
    return False


def runs_state(ctx: Ctx) -> dict:
    return {key: run_public(ctx, key) for key in run_keys()}


# --- The pot ----------------------------------------------------------------------------


def total_cents(ctx: Ctx) -> int:
    row = ctx.conn.execute("SELECT total_cents FROM casino_pot WHERE id = 1").fetchone()
    return row["total_cents"] if row else 0


def _set_total(ctx: Ctx, cents: int) -> None:
    ctx.conn.execute(
        """INSERT INTO casino_pot (id, total_cents) VALUES (1, ?)
           ON CONFLICT(id) DO UPDATE SET total_cents = excluded.total_cents""",
        [cents],
    )


def add_blank(ctx: Ctx, pull_cents: int) -> dict:
    """A blank pull: its price, already in the Brokerage, waits in the pot."""
    before = total_cents(ctx)
    _set_total(ctx, before + pull_cents)
    return {"before_cents": before, "added_cents": pull_cents, "total_cents": before + pull_cents}


def buy(ctx: Ctx, key: str, symbol: str, pull_cents: int, transfer_id: int) -> dict:
    """A hit: the pot plus the winning pull's own price buys the pick at this week's price.

    The cash is already in the Brokerage (every pull landed there through move()), so this
    only places the order and records it. place_order raising (NotConfigured in real mode)
    refuses the whole pull, and the request rolls back with nothing moved."""
    before = total_cents(ctx)
    amount = before + pull_cents
    price = price_cents(ctx, symbol)
    qty = amount / price
    placed = ctx.providers.brokerage.place_order(symbol, amount)
    status = placed.get("status", "simulated")
    order_id = ctx.conn.execute(
        """INSERT INTO orders (symbol, amount_cents, price_cents, qty, transfer_id, created)
           VALUES (?, ?, ?, ?, ?, ?)""",
        [symbol, amount, price, qty, transfer_id, ctx.today.isoformat()],
    ).lastrowid
    ctx.conn.execute(
        """INSERT INTO casino_pot_buys
           (machine, symbol, amount_cents, price_cents, qty, status, order_id, transfer_id,
            created)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        [key, symbol, amount, price, qty, status, order_id, transfer_id, ctx.today.isoformat()],
    )
    _set_total(ctx, 0)
    bought = {
        "symbol": symbol,
        "amount_cents": amount,
        "price_cents": price,
        "qty": round(qty, 6),
        "status": status,
        "pick": pick_info(ctx, symbol),
    }
    return {"before_cents": before, "added_cents": pull_cents, "total_cents": 0, "bought": bought}


def last_buy(ctx: Ctx) -> dict | None:
    row = ctx.conn.execute(
        """SELECT machine, symbol, amount_cents, price_cents, qty, status, created
           FROM casino_pot_buys ORDER BY id DESC LIMIT 1"""
    ).fetchone()
    if row is None:
        return None
    return {**dict(row), "qty": round(row["qty"], 6)}


def pot_state(ctx: Ctx) -> dict:
    symbol = pot_symbol(ctx)
    buys, bought = ctx.conn.execute(
        "SELECT COUNT(*), COALESCE(SUM(amount_cents), 0) FROM casino_pot_buys"
    ).fetchone()
    return {
        "total_cents": total_cents(ctx),
        "pick": pick_info(ctx, symbol) if symbol else None,
        "last_buy": last_buy(ctx),
        "buys": buys,
        "bought_cents": bought,
        "to_account": account(),
    }
