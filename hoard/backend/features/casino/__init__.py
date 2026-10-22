"""The casino, the front door. Cases on a counted belt and box, scratch books, the prize
wheel, the claw (the pot machines, docs/POT.md), the trade-up hopper, the collection book,
and the Sunday draw.

Every machine costs real dollars that land, in full, in the owner's own House Fund or
Brokerage through money/transfer.py; only the cosmetic that comes out is random. The
build contract is docs/CASINO.md.
"""

from datetime import date

from backend.core.context import Ctx
from backend.core.hooks import daily
from backend.core.router import route
from backend.core.state import View, finalizer, section
from backend.features.casino import catalog, dealer, draw, machines


@section(order=60)
def casino_section(ctx: Ctx, view: View) -> dict:
    return {"casino": {**machines.room_state(ctx), "draw": draw.draw_state(ctx)}}


@finalizer(order=60)
def croupier_lines(ctx: Ctx, state: dict) -> dict:
    """Vex in the dialogue table, so talking to him reads the same counts as the room."""
    casino = state["casino"]
    lines = [casino["dealer"]["line"]]
    box = casino["box"]
    if not box["next_is_special"] and box["specials"]:
        lines.append(dealer.box_line(box["specials"], fresh=box["used"] == 0))
    lines = list(dict.fromkeys(lines))
    croupier = {"name": dealer.NAME, "lines": lines}
    return {"dialogue": {**state.get("dialogue", {}), "croupier": croupier}}


@route("GET", "/casino/catalog")
def get_catalog(ctx: Ctx) -> dict:
    return {
        "items": catalog.items(),
        "sets": catalog.sets(),
        "tiers": catalog.tiers(),
        "trophies": catalog.trophy_shelves(),
    }


@route("POST", "/casino/case")
def post_case(ctx: Ctx, case_id: str, to_account: str) -> dict:
    return machines.open_case(ctx, case_id, to_account)


# The pot machines (docs/POT.md) always pay into the Brokerage; to_account is optional and
# anything else is refused.


@route("POST", "/casino/scratch")
def post_scratch(ctx: Ctx, price_cents: int, to_account: str | None = None) -> dict:
    return machines.scratch(ctx, price_cents, to_account)


@route("POST", "/casino/wheel")
def post_wheel(ctx: Ctx, to_account: str | None = None) -> dict:
    return machines.spin_wheel(ctx, to_account)


@route("POST", "/casino/claw")
def post_claw(ctx: Ctx, drop_x: float, to_account: str | None = None) -> dict:
    return machines.drop_claw(ctx, drop_x, to_account)


@route("POST", "/casino/tradeup")
def post_tradeup(ctx: Ctx, inventory_ids: list) -> dict:
    return machines.trade_up(ctx, inventory_ids)


@route("POST", "/casino/equip")
def post_equip(ctx: Ctx, item_id: str) -> dict:
    return machines.equip(ctx, item_id)


@route("POST", "/casino/unequip")
def post_unequip(ctx: Ctx, item_id: str) -> dict:
    return machines.unequip(ctx, item_id)


@daily(order=60)
def sunday_draw(ctx: Ctx, day: date) -> None:
    draw.on_day(ctx, day)
