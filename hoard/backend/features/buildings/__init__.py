"""Buildings worth saving for (docs/BUILDINGS.md).

Balance thresholds unlock a tier, coins build it, real days finish it. Requirements are held,
never spent: they are checked at the Sunday sync (and once at the founding). Nothing here moves
money; coins are spent only by POST /buildings/build. A broken target streak costs the
discount and nothing else.

    GET  /state             -> buildings: {checked_on, next_check, crew, target, capacity, list...}
    POST /buildings/build   {building_id}   start the next tier (ready, crew free, coins there)
    POST /buildings/target  {building_id}   plant the banner (streak resets on a switch)
    POST /buildings/seen    {building_id}   the game played the finished beat

Other features read the village through `capacity(ctx)` (followers it holds) and
`unlocked(ctx, key)` (how many built tiers unlock a key such as "arcade.flame").
"""

from datetime import date

from backend.core.context import Ctx
from backend.core.hooks import daily
from backend.core.router import route
from backend.core.services import coin_balance
from backend.core.state import View, section
from backend.features.buildings import view, works
from backend.features.buildings.view import entry
from backend.features.buildings.works import capacity, unlocked, unlocks

__all__ = ["capacity", "entry", "mark_seen", "unlocked", "unlocks"]


def mark_seen(ctx: Ctx, building_id: str) -> None:
    works.mark_seen(ctx, building_id)


@section(order=65)
def buildings_state(ctx: Ctx, v: View) -> dict:
    return {"buildings": view.section(ctx)}


@route("POST", "/buildings/build")
def post_build(ctx: Ctx, building_id: str) -> dict:
    works.build(ctx, building_id)
    return {"building": entry(ctx, building_id), "coins": coin_balance(ctx)}


@route("POST", "/buildings/target")
def post_target(ctx: Ctx, building_id: str) -> dict:
    works.set_target(ctx, building_id)
    return {"target": view.target(ctx)}


@route("POST", "/buildings/seen")
def post_seen(ctx: Ctx, building_id: str) -> dict:
    works.mark_seen(ctx, building_id)
    return {"building": entry(ctx, building_id)}


@daily(order=65)
def buildings_day(ctx: Ctx, day: date) -> None:
    """Sites finish on their day; Sunday is the check. Runs before the village's hook."""
    founded = works.founded_on(ctx)
    if founded is None:
        works.found(ctx)
        return
    if day <= founded:
        return
    works.finish_due(ctx, day)
    if day.weekday() == 6:
        works.sunday_check(ctx, day)
