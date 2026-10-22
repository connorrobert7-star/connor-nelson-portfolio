"""The shop counter: real tickers at weekly prices, paid for from extra, and the pick the
pot buys on its next hit (docs/POT.md)."""

from backend.core.context import Ctx
from backend.core.dates import week_start
from backend.core.router import ApiError
from backend.features.followers.flock import creature_look
from backend.money.budget import compute_extra, hourly_rate_cents
from backend.money.transfer import caps_remaining, move
from backend.sync import anchor

CHECKING = "chk_1"
BROKERAGE = "brk_1"
AMOUNTS_CENTS = [2_500, 5_000, 10_000, 25_000]


def hours_of_work(amount_cents: int, hourly_cents: int) -> float:
    return round(amount_cents / hourly_cents, 1) if hourly_cents else 0.0


def price_cents(ctx: Ctx, symbol: str) -> int:
    return ctx.providers.market.weekly_price_cents(symbol, week_start(ctx.today), anchor(ctx))


def owned_qty(ctx: Ctx) -> dict[str, float]:
    return {
        r["symbol"]: r["qty"]
        for r in ctx.conn.execute(
            """SELECT symbol, SUM(qty) AS qty FROM (
                 SELECT symbol, qty FROM holdings
                 UNION ALL SELECT symbol, qty FROM orders WHERE transfer_id IN
                   (SELECT id FROM transfers WHERE status IN ('simulated', 'pending')))
               GROUP BY symbol"""
        )
    }


def can_spend_cents(ctx: Ctx) -> int:
    return max(0, min(compute_extra(ctx)["extra_cents"], caps_remaining(ctx)))


# --- The pick ---------------------------------------------------------------------------


def _ticker(ctx: Ctx, symbol: str) -> dict | None:
    return next((t for t in ctx.providers.market.catalog() if t["symbol"] == symbol), None)


def pick_info(ctx: Ctx, symbol: str) -> dict | None:
    """{symbol, name, creature, look} for a symbol the shop carries."""
    t = _ticker(ctx, symbol)
    if t is None:
        return None
    look = creature_look(symbol, t.get("kind", ""), t.get("creature", ""))
    return {
        "symbol": symbol,
        "name": t["name"],
        "creature": look["creature"],
        "look": {"sheet": look["sheet"], "rect": look["rect"]},
    }


def pot_symbol(ctx: Ctx) -> str | None:
    """What the pot buys on its next hit: the owner's pick at the counter, or nothing.

    The one place that decides it, so a target-mix rule (docs/DESIGN_NOTES.md, October 22)
    can replace the single pick later. The game never picks: no default, no random pick."""
    row = ctx.conn.execute("SELECT symbol FROM shop_pick WHERE id = 1").fetchone()
    if row is None or _ticker(ctx, row["symbol"]) is None:
        return None
    return row["symbol"]


def pick(ctx: Ctx) -> dict | None:
    symbol = pot_symbol(ctx)
    return pick_info(ctx, symbol) if symbol else None


def set_pick(ctx: Ctx, symbol: str) -> dict:
    """Pin a stock at the counter. Moves no money; applies to the pot's next hit."""
    info = pick_info(ctx, symbol)
    if info is None:
        raise ApiError(409, f"The shop doesn't carry {symbol}.")
    ctx.conn.execute(
        """INSERT INTO shop_pick (id, symbol, picked_on) VALUES (1, ?, ?)
           ON CONFLICT(id) DO UPDATE SET symbol = excluded.symbol,
             picked_on = excluded.picked_on""",
        [symbol, ctx.today.isoformat()],
    )
    return {"pick": info}


# --- The counter ------------------------------------------------------------------------


def shop_state(ctx: Ctx) -> dict:
    hourly = hourly_rate_cents(ctx)
    can_spend = can_spend_cents(ctx)
    owned = owned_qty(ctx)
    stocks = []
    for t in ctx.providers.market.catalog():
        price = price_cents(ctx, t["symbol"])
        info = pick_info(ctx, t["symbol"]) or {}
        stocks.append(
            {
                "symbol": t["symbol"],
                "name": t["name"],
                "kind": t["kind"],
                "risk": t.get("risk", ""),
                "price_cents": price,
                "price_hours": hours_of_work(price, hourly),
                "owned_qty": round(owned.get(t["symbol"], 0.0), 4),
                "creature": info.get("creature", ""),
                "look": info.get("look"),
            }
        )
    return {
        "hourly_rate_cents": hourly,
        "can_spend_cents": can_spend,
        "stocks": stocks,
        "pick": pick(ctx),
        "amounts": [
            {"amount_cents": a, "hours": hours_of_work(a, hourly), "affordable": a <= can_spend}
            for a in AMOUNTS_CENTS
        ],
        "recent_orders": [
            dict(r)
            for r in ctx.conn.execute(
                "SELECT symbol, amount_cents, qty, created FROM orders ORDER BY id DESC LIMIT 5"
            )
        ],
    }


def buy_stock(ctx: Ctx, symbol: str, amount_cents: int) -> dict:
    if symbol not in {t["symbol"] for t in ctx.providers.market.catalog()}:
        raise ApiError(409, f"The shop doesn't carry {symbol}.")
    if amount_cents <= 0:
        raise ApiError(422, "Amount must be more than zero.")
    if amount_cents > compute_extra(ctx)["extra_cents"]:
        raise ApiError(409, "That's more than your extra this week.")
    price = price_cents(ctx, symbol)
    qty = amount_cents / price
    transfer_id = move(
        ctx,
        CHECKING,
        BROKERAGE,
        amount_cents,
        reason=f"Shop: buy {symbol}",
        event={"type": "shop_buy_stock", "symbol": symbol, "amount_cents": amount_cents},
    )
    ctx.conn.execute(
        """INSERT INTO orders (symbol, amount_cents, price_cents, qty, transfer_id, created)
           VALUES (?, ?, ?, ?, ?, ?)""",
        [symbol, amount_cents, price, qty, transfer_id, ctx.today.isoformat()],
    )
    status = ctx.conn.execute(
        "SELECT status FROM transfers WHERE id = ?", [transfer_id]
    ).fetchone()[0]
    return {
        "symbol": symbol,
        "amount_cents": amount_cents,
        "qty": round(qty, 4),
        "hours": hours_of_work(amount_cents, hourly_rate_cents(ctx)),
        "status": status,
    }
