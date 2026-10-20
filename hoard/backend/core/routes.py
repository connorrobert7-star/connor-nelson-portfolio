"""Platform routes and the platform part of /state."""

from datetime import date

from backend.core.context import Ctx
from backend.core.life import life_clock
from backend.core.router import ApiError, route
from backend.core.services import coin_balance, unseen_notifications
from backend.core.state import View, compose, section
from backend.money.budget import balances, compute_extra, hourly_rate_cents
from backend.money.transfer import caps_remaining
from backend.sync import anchor

MAX_ADVANCE_DAYS = 7


def history_weeks(ctx: Ctx) -> int:
    (first,) = ctx.conn.execute("SELECT MIN(date) FROM transactions").fetchone()
    if first is None:
        return 1
    return max(1, (ctx.today - date.fromisoformat(first)).days // 7)


@section(order=0)
def platform(ctx: Ctx, view: View) -> dict:
    return {
        "today": ctx.today.isoformat(),
        "anchor": anchor(ctx).isoformat(),
        "demo": ctx.demo,
        "providers": ctx.providers.names(),
        "history_weeks": history_weeks(ctx),
        "coins": coin_balance(ctx),
        "life": life_clock(ctx),
        "profile": {"name": ctx.profile.get("name", "You")},
        "extra": compute_extra(ctx),
        "caps_remaining_cents": caps_remaining(ctx),
        "hourly_rate_cents": hourly_rate_cents(ctx),
        "accounts": [dict(r) for r in ctx.conn.execute("SELECT * FROM accounts ORDER BY id")],
        "balances": balances(ctx),
        "holdings": [dict(r) for r in ctx.conn.execute("SELECT * FROM holdings ORDER BY symbol")],
        "debts": [dict(r) for r in ctx.conn.execute("SELECT * FROM debts ORDER BY balance_cents")],
        "notifications": unseen_notifications(ctx),
    }


@route("GET", "/state")
def get_state(ctx: Ctx, weeks_ago: int = 0) -> dict:
    if weeks_ago < 0:
        raise ApiError(422, "weeks_ago can't be negative.")
    if weeks_ago >= history_weeks(ctx):
        raise ApiError(404, f"Only {history_weeks(ctx)} weeks of history.")
    return compose(ctx, View(weeks_ago=weeks_ago))


@route("GET", "/extra")
def get_extra(ctx: Ctx) -> dict:
    return compute_extra(ctx)


@route("GET", "/health")
def health(ctx: Ctx) -> dict:
    return {"ok": True, "today": ctx.today.isoformat(), "demo": ctx.demo}


@route("POST", "/clock/advance")
def advance(ctx: Ctx, days: int = 1) -> dict:
    """Demo only: let a day (or a week) pass. Real mode follows the real calendar."""
    if not ctx.demo:
        raise ApiError(403, "The clock only moves in demo mode.")
    if not 1 <= days <= MAX_ADVANCE_DAYS:
        raise ApiError(422, f"days must be 1 to {MAX_ADVANCE_DAYS}.")
    offset = int(ctx.meta("clock_offset", "0")) + days
    ctx.set_meta("clock_offset", str(offset))
    return {"clock_offset": offset}


@route("POST", "/notifications/seen")
def notifications_seen(ctx: Ctx, ids: list) -> dict:
    ctx.conn.executemany("UPDATE notifications SET seen = 1 WHERE id = ?", [[int(i)] for i in ids])
    return {"seen": len(ids)}
