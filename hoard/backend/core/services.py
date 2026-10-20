"""Shared game services: coins, inventory, notifications.

Coins are earned by playing and spent on play. No route may turn money into
coins; tests/test_rules.py checks that no money-moving route grants coins.
"""

import json

from backend.core.context import Ctx


class NotEnoughCoins(Exception):
    pass


def coin_balance(ctx: Ctx) -> int:
    (total,) = ctx.conn.execute("SELECT COALESCE(SUM(delta), 0) FROM coin_ledger").fetchone()
    return total


def add_coins(ctx: Ctx, delta: int, reason: str) -> int:
    """Add (or with a negative delta, spend) coins. Never goes below zero."""
    if delta < 0 and coin_balance(ctx) + delta < 0:
        raise NotEnoughCoins(f"Needs {-delta} coins.")
    ctx.conn.execute(
        "INSERT INTO coin_ledger (delta, reason, created) VALUES (?, ?, ?)",
        [delta, reason, ctx.today.isoformat()],
    )
    if delta:
        ctx.emit("coins", delta=delta, reason=reason)
    return coin_balance(ctx)


def grant_item(ctx: Ctx, item_id: str, via: str) -> int:
    cur = ctx.conn.execute(
        "INSERT INTO inventory (item_id, obtained_via, obtained_at) VALUES (?, ?, ?)",
        [item_id, via, ctx.today.isoformat()],
    )
    ctx.emit("item", item_id=item_id, via=via)
    return cur.lastrowid


def owned_items(ctx: Ctx) -> list[dict]:
    return [dict(r) for r in ctx.conn.execute("SELECT * FROM inventory ORDER BY id")]


def notify(ctx: Ctx, kind: str, text: str, **data: object) -> None:
    ctx.conn.execute(
        "INSERT INTO notifications (created, kind, text, data) VALUES (?, ?, ?, ?)",
        [ctx.today.isoformat(), kind, text, json.dumps(data)],
    )


def unseen_notifications(ctx: Ctx) -> list[dict]:
    return [
        {**dict(r), "data": json.loads(r["data"] or "{}")}
        for r in ctx.conn.execute("SELECT * FROM notifications WHERE seen = 0 ORDER BY id")
    ]
