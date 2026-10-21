"""What the game draws: the `buildings` section of GET /state and one entry per building.

Numbers here are live (a deposit shows at once on the signpost's lamps), but `ready` only
changes at a Sunday check. Nothing here writes anything but the founding and finished sites
(works.ensure), and nothing reads or moves money beyond the balances and landings.
"""

from backend.core.context import Ctx
from backend.core.dates import week_start
from backend.core.services import coin_balance
from backend.features.buildings import catalog, works
from backend.money.budget import landed_by_kind


class Snapshot:
    """Everything one GET /state needs, read once."""

    def __init__(self, ctx: Ctx) -> None:
        works.ensure(ctx)
        self.ctx = ctx
        self.built = works.built(ctx)
        self.ready = works.ready(ctx)
        self.seen = works.seen(ctx)
        self.site = works.open_site(ctx)
        self.coins = coin_balance(ctx)
        self.target = works.target(ctx)
        self.streak = works.target_streak(ctx)
        self.rules = catalog.streak_rules()
        self.last = works.last_check(ctx)
        self.facts = works.Facts(ctx, ctx.today, dict(self.built), live=True)

    def discount(self, building_id: str) -> float | None:
        if building_id != self.target or self.streak < self.rules["discount_weeks"]:
            return None
        return self.rules["discount"]


def _crew(snap: Snapshot) -> dict | None:
    site = snap.site
    if site is None:
        return None
    done, progress = works.crew_progress(snap.ctx, site)
    return {
        "building_id": site["building_id"],
        "tier": site["tier"],
        "started": site["started"],
        "finishes": site["finishes"],
        "days": site["days"],
        "days_done": done,
        "days_left": int(site["days"]) - done,
        "progress": progress,
    }


def _next(snap: Snapshot, b: dict, n: int) -> dict | None:
    t = catalog.tier(b["id"], n)
    if t is None:
        return None
    discount = snap.discount(b["id"])
    rows = works.requirement_rows(t, snap.facts, discount)
    at_check = snap.last.get(b["id"], {}).get(str(n), {})
    requires = [
        {k: v for k, v in r.items() if k != "met"}
        | {"met_now": r["met"], "met_at_check": bool(at_check.get(r["id"], False))}
        for r in rows
    ]
    since = snap.ready.get((b["id"], n))
    if since is None:
        why_not: str | None = "not_ready"
    elif snap.site is not None:
        why_not = "crew"
    elif snap.coins < int(t["coins"]):
        why_not = "coins"
    else:
        why_not = None
    return {
        "tier": n,
        "name": t["name"],
        "coins": int(t["coins"]),
        "days": int(t["days"]),
        "look": t["changes"]["look"],
        "followers": int(t["changes"].get("followers", 0)),
        "unlocks": list(t["changes"].get("unlocks", [])),
        "ready": since is not None,
        "ready_since": since,
        "discounted": discount is not None and catalog.has_dollars(t),
        "requires": requires,
        "can_build": why_not is None,
        "why_not": why_not,
    }


def _entry(snap: Snapshot, b: dict) -> dict:
    bid = b["id"]
    n = snap.built[bid]
    current = catalog.tier(bid, n) if n else None
    seen_n = min(snap.seen.get(bid, n), n)
    seen_t = catalog.tier(bid, seen_n) if seen_n else None
    constructing = snap.site is not None and snap.site["building_id"] == bid
    progress = works.crew_progress(snap.ctx, snap.site)[1] if constructing else 0.0
    return {
        "id": bid,
        "name": b["name"],
        "plot": b["plot"],
        "parcel": b.get("parcel"),
        "tier": n,
        "tier_name": current["name"] if current else None,
        "max_tier": len(b["tiers"]),
        "seen_tier": seen_n,
        "seen_look": seen_t["changes"]["look"] if seen_t else None,
        "look": current["changes"]["look"] if current else None,
        "followers": sum(int(t["changes"].get("followers", 0)) for t in b["tiers"][:n]),
        "target": bid == snap.target,
        "constructing": constructing,
        "progress": progress,
        "next": _next(snap, b, n + 1),
    }


def entry(ctx: Ctx, building_id: str) -> dict:
    b = catalog.building(building_id)
    if b is None:
        raise KeyError(building_id)
    return _entry(Snapshot(ctx), b)


def target(ctx: Ctx) -> dict | None:
    return _target(Snapshot(ctx))


def _target(snap: Snapshot) -> dict | None:
    if snap.target is None:
        return None
    ctx = snap.ctx
    nxt = catalog.tier(snap.target, snap.built[snap.target] + 1)
    kinds = catalog.toward_kinds(nxt)
    landed = landed_by_kind(ctx, week_start(ctx.today), ctx.today)
    return {
        "building_id": snap.target,
        "streak_weeks": snap.streak,
        "discount_weeks": snap.rules["discount_weeks"],
        "discount": snap.rules["discount"],
        "discount_active": snap.streak >= snap.rules["discount_weeks"],
        "this_week_toward_cents": sum(landed[k] for k in kinds),
        "toward": list(kinds),
    }


def section(ctx: Ctx) -> dict:
    snap = Snapshot(ctx)
    unlocks = works.unlocks(ctx)
    checked = works.checked_on(ctx)
    land = snap.built.get("land", 0)
    return {
        "checked_on": checked.isoformat() if checked else None,
        "next_check": works.next_check(ctx).isoformat(),
        "crew": _crew(snap),
        "target": _target(snap),
        "deposit_streak_weeks": works.deposit_streak(ctx),
        "deposit_streak_now": snap.facts.streak,
        "capacity": {"followers": works.capacity(ctx)},
        "unlocks": unlocks,
        "land": {
            "tier": land,
            "parcels": [k.removeprefix("land.") for k in unlocks if k.startswith("land.")],
        },
        "list": [_entry(snap, b) for b in catalog.buildings()],
    }
