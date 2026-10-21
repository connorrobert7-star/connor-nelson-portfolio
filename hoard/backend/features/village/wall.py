"""The wall: the Emergency Fund (sav_2) against three months of expenses.

Expenses are the average monthly outflow in the ledger: every charge except money
moved into the player's own accounts. The wall's height is the fund against
`wall_months` of them, in stone courses; a full wall glows. When money leaves the
fund the courses drop and the bricks fall, which the game shows once. The game
never takes money out of the fund.
"""

from datetime import date, timedelta

from backend.core.context import Ctx
from backend.money.budget import LANDING_CATEGORIES, balances

ACCOUNT = "sav_2"
SEEN_KEY = "village_wall_seen"
DAYS_PER_MONTH = 30.4375


def monthly_expenses_cents(ctx: Ctx, window_days: int) -> int:
    """Average monthly outflow over the last `window_days` of history (or all of it, if shorter)."""
    (first,) = ctx.conn.execute("SELECT MIN(date) FROM transactions").fetchone()
    if first is None:
        return 0
    start = max(date.fromisoformat(first), ctx.today - timedelta(days=window_days))
    days = max(1, (ctx.today - start).days)
    marks = ",".join("?" * len(LANDING_CATEGORIES))
    (total,) = ctx.conn.execute(
        f"""SELECT COALESCE(SUM(amount_cents), 0) FROM transactions
            WHERE amount_cents > 0 AND category NOT IN ({marks}) AND date >= ? AND date < ?""",
        [*LANDING_CATEGORIES, start.isoformat(), ctx.today.isoformat()],
    ).fetchone()
    return round(total * DAYS_PER_MONTH / days)


def wall_math(balance_cents: int, monthly_cents: int, months: int, courses: int) -> dict:
    """Height of the wall in courses, and the painted marks for each month covered."""
    target = monthly_cents * months
    if target <= 0:
        return {
            "target_cents": 0,
            "courses": courses if balance_cents > 0 else 0,
            "months_covered": 0.0,
            "full": balance_cents > 0,
            "marks": [],
        }
    built = min(courses, (balance_cents * courses) // target) if balance_cents > 0 else 0
    per_month = courses // months
    return {
        "target_cents": target,
        "courses": int(built),
        "months_covered": round(balance_cents / monthly_cents, 2),
        "full": balance_cents >= target,
        "marks": [
            {"months": m, "cents": monthly_cents * m, "course": per_month * m}
            for m in range(1, months + 1)
        ],
    }


def wall_state(ctx: Ctx, cfg: dict) -> dict:
    months = int(cfg.get("wall_months", 3))
    courses = int(cfg.get("wall_courses", 12))
    balance = balances(ctx).get(ACCOUNT, 0)
    monthly = monthly_expenses_cents(ctx, int(cfg.get("expense_window_days", 90)))
    math = wall_math(balance, monthly, months, courses)
    seen = int(ctx.meta(SEEN_KEY) or balance)
    seen_math = wall_math(seen, monthly, months, courses)
    return {
        "account": ACCOUNT,
        "balance_cents": balance,
        "monthly_expenses_cents": monthly,
        "months": months,
        "courses_total": courses,
        **math,
        "seen_cents": seen,
        "seen_courses": seen_math["courses"],
        "fell_cents": max(0, seen - balance),
        "rose_cents": max(0, balance - seen),
    }
