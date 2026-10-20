"""The only place money moves. Every move is capped and logged.

Phases 0 to 3 never call a bank: transfers are written with status 'simulated'.
Phase 4 swaps the body of `move` for a Plaid Transfer and keeps the caps.
"""

import json
import sqlite3
from datetime import date

from backend.money.budget import week_start

PER_TRANSFER_CAP_CENTS = 50_000
PER_DAY_CAP_CENTS = 50_000
PER_WEEK_CAP_CENTS = 100_000


class TransferRefused(Exception):
    pass


def _moved_since(conn: sqlite3.Connection, since: date) -> int:
    (total,) = conn.execute(
        """SELECT COALESCE(SUM(amount_cents), 0) FROM transfers
           WHERE status != 'failed' AND created >= ?""",
        [since.isoformat()],
    ).fetchone()
    return total


def move(
    conn: sqlite3.Connection,
    today: date,
    from_account: str,
    to_account: str,
    amount_cents: int,
    reason: str,
    event: dict,
) -> int:
    """Record a transfer and the game event that caused it. Returns the transfer id."""
    if amount_cents <= 0:
        raise TransferRefused("Amount must be more than zero.")
    if amount_cents > PER_TRANSFER_CAP_CENTS:
        raise TransferRefused("Over the per-transfer cap.")
    if _moved_since(conn, today) + amount_cents > PER_DAY_CAP_CENTS:
        raise TransferRefused("Over today's transfer cap.")
    if _moved_since(conn, week_start(today)) + amount_cents > PER_WEEK_CAP_CENTS:
        raise TransferRefused("Over this week's transfer cap.")

    cur = conn.execute(
        "INSERT INTO events (ts, type, payload) VALUES (?, ?, ?)",
        [today.isoformat(), event["type"], json.dumps(event)],
    )
    cur = conn.execute(
        """INSERT INTO transfers
           (from_account, to_account, amount_cents, reason, event_id, status, created)
           VALUES (?, ?, ?, ?, ?, 'simulated', ?)""",
        [from_account, to_account, amount_cents, reason, cur.lastrowid, today.isoformat()],
    )
    return cur.lastrowid


def caps_remaining(conn: sqlite3.Connection, today: date) -> int:
    day_left = PER_DAY_CAP_CENTS - _moved_since(conn, today)
    week_left = PER_WEEK_CAP_CENTS - _moved_since(conn, week_start(today))
    return max(0, min(PER_TRANSFER_CAP_CENTS, day_left, week_left))
