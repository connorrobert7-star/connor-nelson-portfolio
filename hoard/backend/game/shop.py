"""The shop counter: stocks at weekly prices, paid for from extra."""

import sqlite3
from datetime import date

from backend.content import CategoryMap, stock_catalog
from backend.money.budget import compute_extra, hourly_rate_cents
from backend.money.transfer import TransferRefused, caps_remaining, move

CHECKING = "chk_1"
BROKERAGE = "brk_1"
AMOUNTS_CENTS = [2_500, 5_000, 10_000, 25_000]


def hours_of_work(amount_cents: int, hourly_cents: int) -> float:
    return round(amount_cents / hourly_cents, 1) if hourly_cents else 0.0


def shop_state(conn: sqlite3.Connection, today: date, cmap: CategoryMap) -> dict:
    hourly = hourly_rate_cents(conn, today, cmap)
    extra = compute_extra(conn, today, cmap)["extra_cents"]
    can_spend = max(0, min(extra, caps_remaining(conn, today)))
    owned = {
        r["symbol"]: r["qty"]
        for r in conn.execute(
            """SELECT symbol, SUM(qty) AS qty FROM (
                 SELECT symbol, qty FROM holdings
                 UNION ALL SELECT symbol, qty FROM orders)
               GROUP BY symbol"""
        )
    }
    stocks = [
        {
            "symbol": s["symbol"],
            "name": s["name"],
            "kind": s["kind"],
            "price_cents": s["price_cents"],
            "price_hours": hours_of_work(s["price_cents"], hourly),
            "owned_qty": round(owned.get(s["symbol"], 0.0), 4),
        }
        for s in stock_catalog().values()
    ]
    amounts = [
        {"amount_cents": a, "hours": hours_of_work(a, hourly), "affordable": a <= can_spend}
        for a in AMOUNTS_CENTS
    ]
    orders = [
        dict(r)
        for r in conn.execute(
            "SELECT symbol, amount_cents, qty, created FROM orders ORDER BY id DESC LIMIT 5"
        )
    ]
    return {
        "hourly_rate_cents": hourly,
        "can_spend_cents": can_spend,
        "stocks": stocks,
        "amounts": amounts,
        "recent_orders": orders,
    }


def buy_stock(
    conn: sqlite3.Connection, today: date, cmap: CategoryMap, symbol: str, amount_cents: int
) -> dict:
    stock = stock_catalog().get(symbol)
    if stock is None:
        raise TransferRefused(f"The shop doesn't carry {symbol}.")
    if amount_cents > compute_extra(conn, today, cmap)["extra_cents"]:
        raise TransferRefused("That's more than your extra this week.")
    qty = amount_cents / stock["price_cents"]
    with conn:
        transfer_id = move(
            conn,
            today,
            CHECKING,
            BROKERAGE,
            amount_cents,
            reason=f"Shop: buy {symbol}",
            event={"type": "shop_buy_stock", "symbol": symbol, "amount_cents": amount_cents},
        )
        conn.execute(
            """INSERT INTO orders (symbol, amount_cents, price_cents, qty, transfer_id, created)
               VALUES (?, ?, ?, ?, ?, ?)""",
            [symbol, amount_cents, stock["price_cents"], qty, transfer_id, today.isoformat()],
        )
    return {
        "symbol": symbol,
        "amount_cents": amount_cents,
        "qty": round(qty, 4),
        "hours": hours_of_work(amount_cents, hourly_rate_cents(conn, today, cmap)),
        "status": "simulated",
    }
