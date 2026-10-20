"""Pull accounts, transactions, holdings and debts from the providers into SQLite.

Runs at most once per game day. Provider data replaces the synced tables; game
tables (transfers, coins, inventory, feature tables) are never touched.
"""

import json
from datetime import date, timedelta

from backend.core.context import Ctx
from backend.providers.fixtures import history_start


def anchor(ctx: Ctx) -> date:
    """The day this save was created. Fixture data is laid out around it."""
    value = ctx.meta("anchor")
    if value is None:
        value = ctx.today.isoformat()
        ctx.set_meta("anchor", value)
    return date.fromisoformat(value)


def run(ctx: Ctx, force: bool = False) -> None:
    if not force and ctx.meta("synced_for") == ctx.today.isoformat():
        return
    p, today, a = ctx.providers, ctx.today, anchor(ctx)
    yesterday = today - timedelta(days=1)
    conn = ctx.conn
    with conn:
        for table in ("transactions", "holdings", "debts", "accounts"):
            conn.execute(f"DELETE FROM {table}")
        accounts = p.bank.accounts(a, today)
        holdings = p.brokerage.holdings(a, today)
        accounts.append(
            {
                "id": "brk_1",
                "kind": "brokerage",
                "name": "Brokerage",
                "balance_cents": sum(h["value_cents"] for h in holdings),
            }
        )
        conn.executemany(
            "INSERT INTO accounts VALUES (?, ?, ?, ?, ?, ?)",
            [
                (
                    x["id"],
                    p.bank.name,
                    x["kind"],
                    x["name"],
                    x["balance_cents"],
                    yesterday.isoformat(),
                )
                for x in accounts
            ],
        )
        conn.executemany(
            "INSERT INTO transactions VALUES (?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    t["id"],
                    t["account_id"],
                    t["date"],
                    t["amount_cents"],
                    t["merchant"],
                    t["category"],
                    json.dumps(t),
                )
                for t in p.bank.transactions(a, history_start(a), yesterday)
            ],
        )
        conn.executemany(
            "INSERT INTO holdings VALUES (?, ?, ?, ?, ?, ?)",
            [
                (h["id"], h["account_id"], h["symbol"], h["qty"], h["value_cents"], h["as_of"])
                for h in holdings
            ],
        )
        conn.executemany(
            "INSERT INTO debts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    d["id"],
                    d["name"],
                    d["kind"],
                    d["balance_cents"],
                    d["apr"],
                    d["min_payment_cents"],
                    d.get("due_day"),
                    d.get("limit_cents"),
                )
                for d in p.bank.liabilities(a, today)
            ],
        )
        ctx.set_meta("synced_for", today.isoformat())
