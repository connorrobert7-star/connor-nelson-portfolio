"""The flock (Step 3): followers that are alive.

Faith comes from the days since money last landed; bellies fill only with coin food;
loyalty comes only from play. Nothing here moves money: no route calls move().

    GET  /state                -> followers: {faith, personal, holdings, cultists, mourning, ...}
    POST /followers/pet        {follower_id}            loyalty, once a day each
    POST /followers/feed       {follower_id, food}      gruel 5, stew 15, favorite 25 coins
    POST /followers/name       {name}                   one of the three offered names
    POST /followers/dress      {follower_id, item_id}   any owned hat, cloak, aura or skin
    POST /followers/collect                             the devotion on the altar, as coins

Other features can raise loyalty from play (the dungeon) with
`backend.features.followers.flock.add_loyalty(ctx, follower_id, amount)`.
"""

from datetime import date

from backend.core.context import Ctx
from backend.core.hooks import daily
from backend.core.router import route
from backend.core.state import View, section
from backend.features.followers import flock


@section(order=70)
def followers_state(ctx: Ctx, view: View) -> dict:
    return {"followers": flock.flock_state(ctx)}


@route("POST", "/followers/pet")
def post_pet(ctx: Ctx, follower_id: str) -> dict:
    return flock.pet(ctx, follower_id)


@route("POST", "/followers/feed")
def post_feed(ctx: Ctx, follower_id: str, food: str) -> dict:
    return flock.feed(ctx, follower_id, food)


@route("POST", "/followers/name")
def post_name(ctx: Ctx, name: str) -> dict:
    return flock.name_personal(ctx, name)


@route("POST", "/followers/dress")
def post_dress(ctx: Ctx, follower_id: str, item_id: str = "", slot: str = "") -> dict:
    return flock.dress(ctx, follower_id, item_id, slot)


@route("POST", "/followers/collect")
def post_collect(ctx: Ctx) -> dict:
    return flock.collect(ctx)


@daily(order=70)
def followers_day(ctx: Ctx, day: date) -> None:
    flock.daily(ctx, day)
