"""The only place money moves. Every move is capped and logged.

The transfer provider decides what actually happens: the demo's provider
records 'simulated'; Plaid Transfer will record 'pending' until it settles.
Callers check the amount against extra (or a feature's own cap) first.
"""

import json

from backend.core.context import Ctx
from backend.core.dates import week_start

PER_TRANSFER_CAP_CENTS = 50_000
PER_DAY_CAP_CENTS = 50_000
PER_WEEK_CAP_CENTS = 100_000


class TransferRefused(Exception):
    pass


def _moved_since(ctx: Ctx, since: str) -> int:
    (total,) = ctx.conn.execute(
        "SELECT COALESCE(SUM(amount_cents), 0) FROM transfers "
        "WHERE status != 'failed' AND created >= ?",
        [since],
    ).fetchone()
    return total


def caps_remaining(ctx: Ctx) -> int:
    day_left = PER_DAY_CAP_CENTS - _moved_since(ctx, ctx.today.isoformat())
    week_left = PER_WEEK_CAP_CENTS - _moved_since(ctx, week_start(ctx.today).isoformat())
    return max(0, min(PER_TRANSFER_CAP_CENTS, day_left, week_left))


def move(
    ctx: Ctx, from_account: str, to_account: str, amount_cents: int, reason: str, event: dict
) -> int:
    """Record a transfer and the game event that caused it. Returns the transfer id."""
    if amount_cents <= 0:
        raise TransferRefused("Amount must be more than zero.")
    if amount_cents > PER_TRANSFER_CAP_CENTS:
        raise TransferRefused("Over the per-transfer cap.")
    if _moved_since(ctx, ctx.today.isoformat()) + amount_cents > PER_DAY_CAP_CENTS:
        raise TransferRefused("Over today's transfer cap.")
    if _moved_since(ctx, week_start(ctx.today).isoformat()) + amount_cents > PER_WEEK_CAP_CENTS:
        raise TransferRefused("Over this week's transfer cap.")
    result = ctx.providers.transfers.submit(from_account, to_account, amount_cents, reason)
    cur = ctx.conn.execute(
        "INSERT INTO events (ts, type, payload) VALUES (?, ?, ?)",
        [ctx.today.isoformat(), event["type"], json.dumps(event)],
    )
    cur = ctx.conn.execute(
        """INSERT INTO transfers
           (from_account, to_account, amount_cents, reason, event_id, status, created)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        [
            from_account,
            to_account,
            amount_cents,
            reason,
            cur.lastrowid,
            result["status"],
            ctx.today.isoformat(),
        ],
    )
    ctx.emit(
        "money_moved",
        amount_cents=amount_cents,
        to_account=to_account,
        status=result["status"],
        reason=reason,
    )
    return cur.lastrowid
