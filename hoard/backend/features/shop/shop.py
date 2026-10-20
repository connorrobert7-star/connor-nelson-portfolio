"""The shop counter: real tickers at weekly prices, paid for from extra."""

from backend.core.context import Ctx
from backend.core.dates import week_start
from backend.core.router import ApiError
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


def shop_state(ctx: Ctx) -> dict:
    hourly = hourly_rate_cents(ctx)
    can_spend = can_spend_cents(ctx)
    owned = owned_qty(ctx)
    stocks = []
    for t in ctx.providers.market.catalog():
        price = price_cents(ctx, t["symbol"])
        stocks.append(
            {
                "symbol": t["symbol"],
                "name": t["name"],
                "kind": t["kind"],
                "risk": t.get("risk", ""),
                "price_cents": price,
                "price_hours": hours_of_work(price, hourly),
                "owned_qty": round(owned.get(t["symbol"], 0.0), 4),
            }
        )
    return {
        "hourly_rate_cents": hourly,
        "can_spend_cents": can_spend,
        "stocks": stocks,
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
