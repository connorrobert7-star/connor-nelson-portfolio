"""Extra for the week: the only money the game is ever allowed to move.

extra = checking balance (after game transfers that haven't reached the bank)
        - bills due in the next 14 days
        - floor
        - average weekly spend on food and transport
"""

from datetime import date, timedelta

from backend.core.context import Ctx
from backend.core.dates import add_month, week_start

FLOOR_CENTS = 50_000
# The player's own accounts money can land in: House Fund, Emergency Fund (the wall), Brokerage.
OWN_ACCOUNTS = ("sav_1", "sav_2", "brk_1")
LANDING_CATEGORIES = ("TRANSFER_OUT_SAVINGS", "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS")
BILL_HORIZON_DAYS = 14
AVERAGE_WEEKS = 4
UNSETTLED = ("simulated", "pending")

__all__ = ["add_month", "week_start"]


def _in(items: list[str]) -> str:
    return ",".join("?" * len(items))


def balances(ctx: Ctx) -> dict[str, int]:
    """Account and debt balances after the game's own transfers.

    Simulated transfers never reach a bank, and pending ones haven't yet, so both
    are applied here. Settled transfers are already in the provider's numbers.
    """
    out = {
        r["id"]: r["balance_cents"]
        for r in ctx.conn.execute("SELECT id, balance_cents FROM accounts")
    }
    out |= {
        r["id"]: r["balance_cents"] for r in ctx.conn.execute("SELECT id, balance_cents FROM debts")
    }
    debt_ids = {r["id"] for r in ctx.conn.execute("SELECT id FROM debts")}
    for t in ctx.conn.execute(
        "SELECT from_account, to_account, amount_cents FROM transfers "
        f"WHERE status IN ({_in(list(UNSETTLED))})",
        UNSETTLED,
    ):
        out[t["from_account"]] = out.get(t["from_account"], 0) - t["amount_cents"]
        if t["to_account"] in debt_ids:
            out[t["to_account"]] = max(0, out[t["to_account"]] - t["amount_cents"])
        else:
            out[t["to_account"]] = out.get(t["to_account"], 0) + t["amount_cents"]
    return out


def upcoming_bills(ctx: Ctx) -> list[dict]:
    """Project each recurring bill one month past its latest charge."""
    cats = ctx.cmap.bill_categories()
    rows = ctx.conn.execute(
        f"""SELECT merchant, category, date, amount_cents FROM transactions t
            WHERE category IN ({_in(cats)}) AND amount_cents > 0
              AND date = (SELECT MAX(date) FROM transactions
                          WHERE merchant = t.merchant AND amount_cents > 0)
            ORDER BY merchant""",
        cats,
    ).fetchall()
    horizon = ctx.today + timedelta(days=BILL_HORIZON_DAYS)
    bills = []
    for r in rows:
        due = add_month(date.fromisoformat(r["date"]))
        while due < ctx.today:
            due = add_month(due)
        if due <= horizon:
            bills.append(
                {
                    "merchant": r["merchant"],
                    "due": due.isoformat(),
                    "amount_cents": r["amount_cents"],
                    "system": ctx.cmap.system_for(r["category"]),
                }
            )
    return sorted(bills, key=lambda b: (b["due"], b["merchant"]))


def average_weekly(ctx: Ctx, *systems: str) -> int:
    cats = ctx.cmap.categories_for(*systems)
    start = ctx.today - timedelta(days=7 * AVERAGE_WEEKS)
    (total,) = ctx.conn.execute(
        f"""SELECT COALESCE(SUM(amount_cents), 0) FROM transactions
            WHERE category IN ({_in(cats)}) AND date >= ? AND date < ?""",
        [*cats, start.isoformat(), ctx.today.isoformat()],
    ).fetchone()
    return round(total / AVERAGE_WEEKS)


def hourly_rate_cents(ctx: Ctx) -> int:
    """Take-home pay per hour worked, from the last four weeks of income."""
    income = -average_weekly(ctx, "income")
    return round(income / ctx.profile.get("work_hours_per_week", 40))


def compute_extra(ctx: Ctx) -> dict:
    current = balances(ctx)
    checking = sum(
        current[r["id"]]
        for r in ctx.conn.execute("SELECT id FROM accounts WHERE kind = 'checking'")
    )
    bills = upcoming_bills(ctx)
    bills_due = sum(b["amount_cents"] for b in bills)
    food_transport = average_weekly(ctx, "crops", "tavern", "roads")
    return {
        "extra_cents": checking - bills_due - FLOOR_CENTS - food_transport,
        "checking_cents": checking,
        "bills_due_cents": bills_due,
        "bills": bills,
        "floor_cents": FLOOR_CENTS,
        "avg_weekly_food_transport_cents": food_transport,
        "week_start": week_start(ctx.today).isoformat(),
    }


def landed_cents(ctx: Ctx, start: date, end: date) -> int:
    """Money that landed in the player's own accounts between start and end (inclusive):
    the game's own transfers plus the bank's savings and investment transfers."""
    (game,) = ctx.conn.execute(
        f"""SELECT COALESCE(SUM(amount_cents), 0) FROM transfers
            WHERE status != 'failed' AND to_account IN ({_in(list(OWN_ACCOUNTS))})
              AND created BETWEEN ? AND ?""",
        [*OWN_ACCOUNTS, start.isoformat(), end.isoformat()],
    ).fetchone()
    (bank,) = ctx.conn.execute(
        f"""SELECT COALESCE(SUM(amount_cents), 0) FROM transactions
            WHERE category IN ({_in(list(LANDING_CATEGORIES))}) AND amount_cents > 0
              AND date BETWEEN ? AND ?""",
        [*LANDING_CATEGORIES, start.isoformat(), end.isoformat()],
    ).fetchone()
    return game + bank


def last_landing_day(ctx: Ctx) -> date | None:
    """The last day money landed in an own account, or None if it never has."""
    (game,) = ctx.conn.execute(
        f"SELECT MAX(created) FROM transfers WHERE status != 'failed' "
        f"AND to_account IN ({_in(list(OWN_ACCOUNTS))})",
        OWN_ACCOUNTS,
    ).fetchone()
    (bank,) = ctx.conn.execute(
        f"SELECT MAX(date) FROM transactions WHERE amount_cents > 0 "
        f"AND category IN ({_in(list(LANDING_CATEGORIES))})",
        LANDING_CATEGORIES,
    ).fetchone()
    days = [date.fromisoformat(d) for d in (game, bank) if d]
    return max(days) if days else None
