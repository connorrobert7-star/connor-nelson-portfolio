"""The week in the village: crops, tavern, drains, shrine, and the ledger."""

from backend.core.context import Ctx
from backend.core.state import View, section
from backend.features.week.reactions import village_reactions


@section(order=20)
def week_state(ctx: Ctx, view: View) -> dict:
    house = ctx.conn.execute(
        "SELECT name, balance_cents FROM accounts WHERE kind = 'savings'"
    ).fetchone()
    return {
        "systems": {name: s["label"] for name, s in ctx.cmap.systems.items()},
        "house": {"name": house["name"], "balance_cents": house["balance_cents"]},
        **village_reactions(ctx.conn, ctx.cmap, ctx.today, view.weeks_ago),
    }
