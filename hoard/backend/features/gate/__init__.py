"""The gate (Step 2): each debt is a boss outside the village, smallest first.

HP is the real balance. Payments are attacks that do exactly their dollars of damage,
moved through money.transfer.move() after the extra and caps check. Interest heals each
boss once a month (shown, never added). The bank's own payments play as auto-attacks in
the while-you-were-out queue. A kill drops a cosmetic only that boss carries, once.
No coins are earned or spent here.
"""

from datetime import date

from backend.core.context import Ctx
from backend.core.hooks import daily
from backend.core.router import route
from backend.core.state import View, section
from backend.features.gate import gate


@section(order=64)
def gate_section(ctx: Ctx, view: View) -> dict:
    return {"gate": gate.gate_state(ctx)}


@route("POST", "/gate/attack")
def post_attack(ctx: Ctx, debt_id: str, amount_cents: int) -> dict:
    return gate.attack(ctx, debt_id, amount_cents)


@route("POST", "/gate/seen")
def post_seen(ctx: Ctx, heals: list | None = None, kills: list | None = None) -> dict:
    """The heal telegraphs and death sequences the game has played."""
    return gate.mark_seen(ctx, heals or [], kills or [])


@route("GET", "/gate/catalog")
def get_catalog(ctx: Ctx) -> dict:
    return {"items": gate.catalog(), "sets": gate.items_file()["sets"]}


@daily(order=64)
def gate_day(ctx: Ctx, day: date) -> None:
    gate.register(ctx)
    gate.bank_hits(ctx, day)
    gate.heal_day(ctx, day)
    gate.bank_kills(ctx)
