"""Extra for the week: the only number the shop is allowed to spend from.

extra = checking balance
        - bills due in the next 14 days
        - floor
        - average weekly spend on food and transport
"""

import calendar
import sqlite3
from datetime import date, timedelta

from backend.content import CategoryMap

FLOOR_CENTS = 50_000
WEEKLY_CASE_CAP_CENTS = 6_000
BILL_HORIZON_DAYS = 14
AVERAGE_WEEKS = 4


def add_month(d: date) -> date:
    year, month = (d.year + 1, 1) if d.month == 12 else (d.year, d.month + 1)
    return date(year, month, min(d.day, calendar.monthrange(year, month)[1]))


def week_start(today: date) -> date:
    """Weeks run Sunday to Saturday."""
    return today - timedelta(days=(today.weekday() + 1) % 7)


def _in(categories: list[str]) -> str:
    return ",".join("?" * len(categories))


def upcoming_bills(conn: sqlite3.Connection, today: date, cmap: CategoryMap) -> list[dict]:
    """Project each recurring bill one month past its latest charge."""
    cats = cmap.bill_categories()
    rows = conn.execute(
        f"""SELECT merchant, category, date, amount_cents FROM transactions t
            WHERE category IN ({_in(cats)}) AND amount_cents > 0
              AND date = (SELECT MAX(date) FROM transactions
                          WHERE merchant = t.merchant AND amount_cents > 0)
            ORDER BY merchant""",
        cats,
    ).fetchall()
    horizon = today + timedelta(days=BILL_HORIZON_DAYS)
    bills = []
    for r in rows:
        due = add_month(date.fromisoformat(r["date"]))
        while due < today:
            due = add_month(due)
        if due <= horizon:
            bills.append(
                {
                    "merchant": r["merchant"],
                    "due": due.isoformat(),
                    "amount_cents": r["amount_cents"],
                    "system": cmap.system_for(r["category"]),
                }
            )
    return sorted(bills, key=lambda b: b["due"])


def average_weekly_food_and_transport(
    conn: sqlite3.Connection, today: date, cmap: CategoryMap
) -> int:
    cats = cmap.categories_for("crops", "tavern", "roads")
    start = today - timedelta(days=7 * AVERAGE_WEEKS)
    (total,) = conn.execute(
        f"""SELECT COALESCE(SUM(amount_cents), 0) FROM transactions
            WHERE category IN ({_in(cats)}) AND date >= ? AND date < ?""",
        [*cats, start.isoformat(), today.isoformat()],
    ).fetchone()
    return round(total / AVERAGE_WEEKS)


def compute_extra(conn: sqlite3.Connection, today: date, cmap: CategoryMap) -> dict:
    (checking,) = conn.execute(
        "SELECT COALESCE(SUM(balance_cents), 0) FROM accounts WHERE kind = 'checking'"
    ).fetchone()
    bills = upcoming_bills(conn, today, cmap)
    bills_due = sum(b["amount_cents"] for b in bills)
    food_transport = average_weekly_food_and_transport(conn, today, cmap)
    extra = checking - bills_due - FLOOR_CENTS - food_transport

    (cap_used,) = conn.execute(
        "SELECT COALESCE(SUM(amount_cents), 0) FROM cases_opened WHERE opened_at >= ?",
        [week_start(today).isoformat()],
    ).fetchone()
    cap_remaining = max(0, WEEKLY_CASE_CAP_CENTS - cap_used)

    return {
        "extra_cents": extra,
        "spendable_cents": max(0, min(extra, cap_remaining)),
        "checking_cents": checking,
        "bills_due_cents": bills_due,
        "bills": bills,
        "floor_cents": FLOOR_CENTS,
        "avg_weekly_food_transport_cents": food_transport,
        "weekly_cap_cents": WEEKLY_CASE_CAP_CENTS,
        "cap_used_cents": cap_used,
        "cap_remaining_cents": cap_remaining,
        "week_start": week_start(today).isoformat(),
    }
