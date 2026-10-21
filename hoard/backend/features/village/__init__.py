"""The village hub: the house, the wall, the offering tablets and the ruins they restore.

GET /state gets a `village` section. POST /village/seen is sent after the game has
played what changed (a house stage going up, bricks falling, sockets filling, a ruin
restored), so each of those plays once. The house is a building now (its stages are
built with coins and days once the House Fund holds them at a Sunday check; see
backend/features/buildings); a finished stage queues the buildings' `building_done` beat.
A daily hook writes down filled sockets and restored ruins and queues their overnight
beats for the "while you were out" scene. Nothing here moves money or grants coins.
"""

import json
from datetime import date, timedelta
from functools import cache

from backend.content import CONTENT
from backend.core.context import Ctx
from backend.core.hooks import daily
from backend.core.router import route
from backend.core.services import away, owned_items
from backend.core.state import View, section
from backend.features import buildings
from backend.features.village import bundles, house, wall
from backend.money.budget import landed_cents, last_landing_day

TIER_RANK = {"common": 0, "rare": 1, "epic": 2, "legendary": 3, "mythic": 4}
TROPHY_SLOTS = 6
FAITH_BANDS = ((2, "fervent"), (6, "content"), (13, "doubting"))


@cache
def _catalog() -> dict[str, dict]:
    """Every cosmetic from every feature's content/<id>/items.json, by id."""
    items: dict[str, dict] = {}
    for path in sorted(CONTENT.glob("*/items.json")):
        data = json.loads(path.read_text())
        for item in data.get("items", []) if isinstance(data, dict) else data:
            if isinstance(item, dict) and "id" in item:
                items[item["id"]] = item
    return items


def trophies(ctx: Ctx) -> list[dict]:
    """The rarest things the player owns, for the Ossuary's shelves."""
    catalog = _catalog()
    seen: set[str] = set()
    found = []
    for row in reversed(owned_items(ctx)):
        item = catalog.get(row["item_id"])
        if item is None or item["id"] in seen:
            continue
        seen.add(item["id"])
        found.append(item)
    found.sort(key=lambda i: -TIER_RANK.get(i.get("tier", "common"), 0))
    return [
        {"item_id": i["id"], "name": i["name"], "tier": i.get("tier"), "icon": i.get("icon")}
        for i in found[:TROPHY_SLOTS]
    ]


def faith_band(days: int | None) -> str:
    if days is None:
        return "doubting"
    for limit, band in FAITH_BANDS:
        if days <= limit:
            return band
    return "mourning"


def _payday(ctx: Ctx) -> bool:
    """Money came in or landed yesterday or today."""
    since = ctx.today - timedelta(days=1)
    cats = ctx.cmap.categories_for("income")
    (income,) = ctx.conn.execute(
        f"""SELECT COUNT(*) FROM transactions WHERE amount_cents < 0 AND date >= ?
            AND category IN ({",".join("?" * len(cats))})""",
        [since.isoformat(), *cats],
    ).fetchone()
    return income > 0 or landed_cents(ctx, since, ctx.today) > 0


def _init(ctx: Ctx) -> None:
    """First look at a save: the wall as it stands counts as already seen. (The house's
    first look is the buildings feature's founding.)"""
    if ctx.meta(wall.SEEN_KEY) is None:
        ctx.set_meta(
            wall.SEEN_KEY, str(wall.wall_state(ctx, bundles.bundle_config())["balance_cents"])
        )


def village(ctx: Ctx) -> dict:
    _init(ctx)
    ruins = bundles.ruins_state(ctx)
    last = last_landing_day(ctx)
    days = (ctx.today - last).days if last else None
    restored = {r["id"]: r["restored"] for r in ruins}
    return {
        "house": house.house_state(ctx),
        "wall": wall.wall_state(ctx, bundles.bundle_config()),
        "ruins": ruins,
        "epoch": bundles.epoch(ctx).isoformat(),
        "opens": {r["opens"]: r["restored"] for r in ruins},
        "trophies": trophies(ctx) if restored.get("ossuary") else [],
        "bell_rings": bool(restored.get("bell_tower")) and _payday(ctx),
        "stats": {
            "days_since_landing": days,
            "faith_band": faith_band(days),
        },
    }


@section(order=70)
def village_state(ctx: Ctx, view: View) -> dict:
    return {"village": village(ctx)}


@route("POST", "/village/seen")
def village_seen(ctx: Ctx, parts: list | None = None) -> dict:
    """The game has played what changed. `parts` picks house, wall, bundles (default all)."""
    _init(ctx)
    which = set(parts or ("house", "wall", "bundles"))
    if "house" in which:
        buildings.mark_seen(ctx, house.BUILDING)
    if "wall" in which:
        balance = wall.wall_state(ctx, bundles.bundle_config())["balance_cents"]
        ctx.set_meta(wall.SEEN_KEY, str(balance))
    if "bundles" in which:
        bundles.sync(ctx)
        bundles.mark_seen(ctx)
    return {"village": village(ctx)}


@daily(order=70)
def village_day(ctx: Ctx, day: date) -> None:
    """Overnight: write down sockets and restore ruins. (House stages finish in the
    buildings feature's hook, which queues their beat.)"""
    _init(ctx)
    for ruin in bundles.sync(ctx):
        away(
            ctx,
            "ruin_restored",
            priority=22,
            ruin=ruin["id"],
            name=ruin["name"],
            text=f"The {ruin['name']} is standing again.",
        )
