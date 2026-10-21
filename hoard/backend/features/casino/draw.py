"""The weekly draw. Every $5 that landed in the owner's own accounts during the week is a
ticket: the game's transfers into the House Fund and the Brokerage, plus the bank's own
savings and investment transfers. The village holds 100 tickets in all; the cultists
hold the rest. On Sunday ten are drawn, and each of the owner's that comes up grants a
cosmetic, the first draws the best. Cosmetics only: nothing here moves or pays money.
"""

import json
from datetime import date, timedelta

from backend.core.context import Ctx
from backend.core.dates import week_start
from backend.core.services import notify
from backend.features.casino import catalog, loads
from backend.features.casino.machines import grant

SUNDAY = 6  # date.weekday()


def _in(n: int) -> str:
    return ",".join("?" * n)


def landed_cents(ctx: Ctx, start: date) -> int:
    """Money that landed in an own account (savings or brokerage) in the week from start."""
    end = (start + timedelta(days=6)).isoformat()
    own = [
        r["id"]
        for r in ctx.conn.execute("SELECT id FROM accounts WHERE kind IN ('savings', 'brokerage')")
    ]
    cats = ctx.cmap.categories_for("shrine", "followers")
    total = 0
    if own:
        (game,) = ctx.conn.execute(
            f"""SELECT COALESCE(SUM(amount_cents), 0) FROM transfers
                WHERE status != 'failed' AND to_account IN ({_in(len(own))})
                  AND created >= ? AND created <= ?""",
            [*own, start.isoformat(), end],
        ).fetchone()
        total += game
    if cats:
        (bank,) = ctx.conn.execute(
            f"""SELECT COALESCE(SUM(amount_cents), 0) FROM transactions
                WHERE category IN ({_in(len(cats))}) AND amount_cents > 0
                  AND date >= ? AND date <= ?""",
            [*cats, start.isoformat(), end],
        ).fetchone()
        total += bank
    return total


def entries(ctx: Ctx, start: date) -> int:
    return landed_cents(ctx, start) // catalog.machines()["draw"]["cents_per_entry"]


def tickets_total(n_entries: int) -> int:
    return max(catalog.machines()["draw"]["village_tickets"], n_entries)


def run_draw(ctx: Ctx, start: date) -> dict:
    """Draw the week that began on `start`, on the Sunday after it. Runs once per week; a
    second call returns the stored result."""
    row = ctx.conn.execute(
        "SELECT * FROM casino_draw WHERE week_start = ?", [start.isoformat()]
    ).fetchone()
    if row:
        return {"week": row["week_start"], "won": json.loads(row["won"])}
    cfg = catalog.machines()["draw"]
    mine = entries(ctx, start)
    total = tickets_total(mine)
    drawn = loads.RNG.sample(range(total), len(cfg["prizes"]))
    won = []
    for ticket, tier in zip(drawn, cfg["prizes"], strict=True):
        if ticket < mine:  # the owner holds tickets 0 .. mine - 1
            item_id = loads.pick_item(tier)
            grant(ctx, item_id, "draw", None)
            won.append(item_id)
    ctx.conn.execute(
        """INSERT INTO casino_draw (week_start, entries, tickets_total, drawn, won, drawn_on)
           VALUES (?, ?, ?, ?, ?, ?)""",
        [
            start.isoformat(),
            mine,
            total,
            json.dumps(drawn),
            json.dumps(won),
            (start + timedelta(days=7)).isoformat(),
        ],
    )
    if mine:
        came_up = len(won)
        text = (
            f"The weekly draw: {came_up} of your {mine} tickets came up."
            if came_up
            else f"The weekly draw: none of your {mine} tickets came up this time."
        )
        notify(ctx, "casino_draw", text, week=start.isoformat(), won=won)
    return {"week": start.isoformat(), "won": won}


def on_day(ctx: Ctx, day: date) -> None:
    """Sunday: draw the week that just ended (weeks run Sunday to Saturday)."""
    if day.weekday() == SUNDAY:
        run_draw(ctx, day - timedelta(days=7))


def draw_state(ctx: Ctx) -> dict:
    start = week_start(ctx.today)
    mine = entries(ctx, start)
    last = ctx.conn.execute(
        "SELECT week_start, entries, won FROM casino_draw ORDER BY week_start DESC LIMIT 1"
    ).fetchone()
    return {
        "week_start": start.isoformat(),
        "entries": mine,
        "tickets_total": tickets_total(mine),
        "draws_on": (start + timedelta(days=7)).isoformat(),
        "prizes": list(catalog.machines()["draw"]["prizes"]),
        "last": (
            {"week": last["week_start"], "entries": last["entries"], "won": json.loads(last["won"])}
            if last
            else None
        ),
    }
