"""The rules: requirements, the Sunday check, the founding, one crew, the target and its streak.

Nothing here moves money or changes an account. Requirements read the balances
(money.budget.balances, so the game's unsettled transfers count) and the deposits that landed
(money.budget.landed_cents and landed_by_kind); they are never spent, moved or locked. Coins are
spent in one place only: build(). Nothing takes coins or money to make a build go faster.
"""

import json
import sqlite3
from dataclasses import dataclass
from datetime import date, timedelta
from functools import cached_property

from backend.core.context import Ctx
from backend.core.dates import week_start
from backend.core.router import ApiError
from backend.core.services import add_coins, away
from backend.features.buildings import catalog
from backend.money.budget import balances, landed_by_kind, landed_cents

# An old save's high-water house stage (a stage index), kept by the village before the house
# became a building. The founding builds the house up to it.
LEGACY_HOUSE_KEY = "village_house_built"
DONE_PRIORITY = 20  # the away beat plays early, with the other things that went up overnight
MAX_STREAK_WEEKS = 520


# --- small values in meta ----------------------------------------------------------------


def _meta(ctx: Ctx, key: str, default: str | None = None) -> str | None:
    return ctx.meta(f"buildings_{key}", default)


def _set(ctx: Ctx, key: str, value: object) -> None:
    ctx.set_meta(f"buildings_{key}", str(value))


def _day(value: str | None) -> date | None:
    return date.fromisoformat(value) if value else None


def founded_on(ctx: Ctx) -> date | None:
    return _day(_meta(ctx, "founded_on"))


def checked_on(ctx: Ctx) -> date | None:
    return _day(_meta(ctx, "checked_on"))


def target(ctx: Ctx) -> str | None:
    value = _meta(ctx, "target", "")
    return value if value and catalog.building(value) else None


def target_streak(ctx: Ctx) -> int:
    return int(_meta(ctx, "target_streak", "0") or 0)


def deposit_streak(ctx: Ctx) -> int:
    """Weeks in a row with a deposit into any own account, as of the last check."""
    return int(_meta(ctx, "deposit_streak", "0") or 0)


def next_check(ctx: Ctx) -> date:
    """The next Sunday the requirements are checked."""
    day = ctx.today + timedelta(days=(6 - ctx.today.weekday()) % 7)
    last = checked_on(ctx)
    return day + timedelta(days=7) if last and day <= last else day


# --- what stands, what's ready, the crew, what the game has shown --------------------------


def built(ctx: Ctx) -> dict[str, int]:
    """building_id -> its built tier (0 while nothing stands, like the lodge's overgrown plot)."""
    out = {b["id"]: 0 for b in catalog.buildings()}
    for r in ctx.conn.execute(
        "SELECT building_id, MAX(tier) AS tier FROM buildings_built GROUP BY building_id"
    ):
        if r["building_id"] in out:
            out[r["building_id"]] = min(r["tier"], catalog.max_tier(r["building_id"]))
    return out


def _add_built(ctx: Ctx, building_id: str, tier: int, day: date, via: str) -> None:
    ctx.conn.execute(
        "INSERT OR IGNORE INTO buildings_built (building_id, tier, built_on, via) "
        "VALUES (?, ?, ?, ?)",
        [building_id, tier, day.isoformat(), via],
    )


def ready(ctx: Ctx) -> dict[tuple[str, int], str]:
    """(building_id, tier) -> the check day it became ready."""
    return {
        (r["building_id"], r["tier"]): r["ready_since"]
        for r in ctx.conn.execute("SELECT * FROM buildings_ready")
    }


def open_site(ctx: Ctx) -> sqlite3.Row | None:
    """The one construction the crew is on, if any."""
    return ctx.conn.execute(
        "SELECT * FROM buildings_sites WHERE done_on IS NULL ORDER BY id LIMIT 1"
    ).fetchone()


def seen(ctx: Ctx) -> dict[str, int]:
    return {
        r["building_id"]: r["tier"]
        for r in ctx.conn.execute("SELECT building_id, tier FROM buildings_seen")
    }


def _set_seen(ctx: Ctx, building_id: str, tier: int) -> None:
    ctx.conn.execute(
        "INSERT INTO buildings_seen (building_id, tier) VALUES (?, ?) "
        "ON CONFLICT(building_id) DO UPDATE SET tier = excluded.tier",
        [building_id, tier],
    )


def last_check(ctx: Ctx) -> dict:
    """The last check's results: {building_id: {tier: {requirement id: held}}}."""
    row = ctx.conn.execute(
        "SELECT results FROM buildings_checks ORDER BY day DESC LIMIT 1"
    ).fetchone()
    return json.loads(row["results"]) if row else {}


# --- deposits and the deposit streak --------------------------------------------------------


def _first_day(ctx: Ctx) -> date | None:
    """The earliest day there is any record of money (real history, not only this save)."""
    (bank,) = ctx.conn.execute("SELECT MIN(date) FROM transactions").fetchone()
    (game,) = ctx.conn.execute("SELECT MIN(created) FROM transfers").fetchone()
    days = [date.fromisoformat(d) for d in (bank, game) if d]
    return min(days) if days else None


def completed_streak(ctx: Ctx, this_week: date) -> int:
    """Completed weeks in a row, ending the week before `this_week`, in which at least the
    streak's min_cents landed in any own account."""
    first = _first_day(ctx)
    if first is None:
        return 0
    need = catalog.streak_rules()["min_cents"]
    w, n = this_week - timedelta(days=7), 0
    while n < MAX_STREAK_WEEKS and w + timedelta(days=6) >= first:
        if landed_cents(ctx, w, w + timedelta(days=6)) < need:
            break
        n += 1
        w -= timedelta(days=7)
    return n


@dataclass
class Facts:
    """The numbers requirements are held against, for one day.

    Live facts (what the game shows between checks) count this week's deposit streak once
    something has landed this week; a check counts completed weeks only."""

    ctx: Ctx
    day: date
    built: dict[str, int]
    live: bool = True

    @cached_property
    def balances(self) -> dict[str, int]:
        return balances(self.ctx)

    @cached_property
    def streak(self) -> int:
        start = week_start(self.day)
        n = completed_streak(self.ctx, start)
        if self.live:
            need = catalog.streak_rules()["min_cents"]
            n += landed_cents(self.ctx, start, self.day) >= need
        return n


# --- requirements ---------------------------------------------------------------------------


def _row(rid: str, key: str, label: str, need: int, base: int, have: int, **more: object) -> dict:
    return {
        "id": rid,
        "key": key,
        "label": label,
        "need": need,
        "base_need": base,
        "have": have,
        "met": have >= need,
        **more,
    }


def requirement_rows(t: dict, facts: Facts, discount: float | None = None) -> list[dict]:
    """Each requirement of a tier against the facts. Only dollar requirements are discounted."""
    rows = []
    for key, value in t.get("requires", {}).items():
        if key in catalog.BALANCE_KEYS:
            base = int(value)
            need = catalog.discounted(base, discount) if discount else base
            accounts = catalog.BALANCE_KEYS[key]
            have = sum(facts.balances.get(a, 0) for a in accounts)
            rows.append(
                _row(key, key, catalog.LABELS[key], need, base, have, accounts=list(accounts))
            )
        elif key == "deposit_streak_weeks":
            n = int(value)
            rows.append(_row(key, key, catalog.LABELS[key], n, n, facts.streak))
        elif key == "land":
            n = int(value)
            rows.append(_row(key, key, catalog.LABELS[key], n, n, facts.built.get("land", 0)))
        elif key == "buildings":
            for building_id, n in value.items():
                b = catalog.building(building_id) or {"name": building_id}
                rows.append(
                    _row(
                        f"buildings.{building_id}",
                        key,
                        b["name"],
                        int(n),
                        int(n),
                        facts.built.get(building_id, 0),
                        building_id=building_id,
                    )
                )
        else:
            raise ValueError(f"Unknown requirement {key}.")
    return rows


def held(rows: list[dict]) -> bool:
    return all(r["met"] for r in rows)


def discount_for(ctx: Ctx, building_id: str, streak: int | None = None) -> float | None:
    """The target's discount while its streak is long enough, else None."""
    if target(ctx) != building_id:
        return None
    rules = catalog.streak_rules()
    weeks = target_streak(ctx) if streak is None else streak
    return rules["discount"] if weeks >= rules["discount_weeks"] else None


# --- checks: the founding and every Sunday ----------------------------------------------------


def _record_check(
    ctx: Ctx, day: date, kind: str, facts: Facts, tgt: str | None, streak: int, toward: int
) -> None:
    """Hold every tier not yet built against the facts; the ones that hold become ready."""
    results: dict[str, dict[str, dict[str, bool]]] = {}
    for b in catalog.buildings():
        bid = b["id"]
        discount = discount_for(ctx, bid, streak) if bid == tgt else None
        for n in range(facts.built[bid] + 1, len(b["tiers"]) + 1):
            rows = requirement_rows(b["tiers"][n - 1], facts, discount)
            results.setdefault(bid, {})[str(n)] = {r["id"]: r["met"] for r in rows}
            if held(rows):
                ctx.conn.execute(
                    "INSERT OR IGNORE INTO buildings_ready (building_id, tier, ready_since) "
                    "VALUES (?, ?, ?)",
                    [bid, n, day.isoformat()],
                )
    ctx.conn.execute(
        "INSERT OR REPLACE INTO buildings_checks "
        "(day, kind, deposit_streak, target, target_streak, toward_cents, results) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        [day.isoformat(), kind, facts.streak, tgt, streak, toward, json.dumps(results)],
    )
    _set(ctx, "checked_on", day.isoformat())
    _set(ctx, "deposit_streak", facts.streak)


def found(ctx: Ctx) -> None:
    """The first check on a save. Every tier whose requirements already hold is built at once,
    in order and for free: the owner saved for those before the game existed."""
    today = ctx.today
    if catalog.building("house") and ctx.meta(LEGACY_HOUSE_KEY) is not None:
        top = min(int(ctx.meta(LEGACY_HOUSE_KEY) or 0) + 1, catalog.max_tier("house"))
        for n in range(1, top + 1):
            _add_built(ctx, "house", n, today, "legacy")
    facts = Facts(ctx, today, built(ctx), live=False)
    changed = True
    while changed:  # land can open a plot for another building, so go round until nothing moves
        changed = False
        for b in catalog.buildings():
            n = facts.built[b["id"]] + 1
            while n <= len(b["tiers"]) and held(requirement_rows(b["tiers"][n - 1], facts)):
                _add_built(ctx, b["id"], n, today, "founding")
                facts.built[b["id"]] = n
                changed = True
                n += 1
    for building_id, n in facts.built.items():
        _set_seen(ctx, building_id, n)
    _set(ctx, "founded_on", today.isoformat())
    _set(ctx, "target", "")
    _set(ctx, "target_streak", 0)
    _record_check(ctx, today, "founding", facts, None, 0, 0)


def sunday_check(ctx: Ctx, day: date) -> None:
    """Sunday: the target's streak moves on the week that just ended, then every tier not yet
    built is held against the balances and the deposit streak. A broken streak only takes the
    discount away; a tier that already became ready stays ready."""
    start, end = day - timedelta(days=7), day - timedelta(days=1)
    tgt = target(ctx)
    streak, toward = target_streak(ctx), 0
    if tgt:
        nxt = catalog.tier(tgt, built(ctx)[tgt] + 1)
        landed = landed_by_kind(ctx, start, end)
        toward = sum(landed[k] for k in catalog.toward_kinds(nxt))
        streak = streak + 1 if toward >= catalog.streak_rules()["min_cents"] else 0
        _set(ctx, "target_streak", streak)
    _record_check(ctx, day, "sunday", Facts(ctx, day, built(ctx), live=False), tgt, streak, toward)


# --- the crew -----------------------------------------------------------------------------------


def _finish(ctx: Ctx, site: sqlite3.Row, beat: bool) -> None:
    bid, n = site["building_id"], site["tier"]
    day = date.fromisoformat(site["finishes"])
    _add_built(ctx, bid, n, day, "crew")
    ctx.conn.execute(
        "UPDATE buildings_sites SET done_on = ? WHERE id = ?", [day.isoformat(), site["id"]]
    )
    if not beat:
        return
    b, t = catalog.building(bid), catalog.tier(bid, n)
    assert b is not None and t is not None
    away(
        ctx,
        "building_done",
        priority=DONE_PRIORITY,
        building_id=bid,
        building=b["name"],
        tier=n,
        name=t["name"],
        look=t["changes"]["look"],
        text=t.get("line") or f"The {t['name'].lower()} is built.",
    )


def finish_due(ctx: Ctx, day: date) -> None:
    """A site is built on the first day on or after its finish date."""
    site = open_site(ctx)
    if site is not None and date.fromisoformat(site["finishes"]) <= day:
        _finish(ctx, site, beat=True)


def ensure(ctx: Ctx) -> None:
    """Found the save on first sight, and treat a finished date as built."""
    if founded_on(ctx) is None:
        found(ctx)
    finish_due(ctx, ctx.today)


def _building(building_id: str) -> dict:
    b = catalog.building(building_id)
    if b is None:
        raise ApiError(404, "No such building.")
    return b


def build(ctx: Ctx, building_id: str) -> None:
    """Start the next tier: ready at a check, the crew free, the coins there. The coins are
    spent once, now; the days can't be shortened by anything."""
    ensure(ctx)
    b = _building(building_id)
    n = built(ctx)[building_id] + 1
    t = catalog.tier(building_id, n)
    if t is None:
        raise ApiError(409, "Nothing left to build there.")
    if (building_id, n) not in ready(ctx):
        raise ApiError(409, "Not ready yet. The numbers are checked on Sunday.")
    if open_site(ctx) is not None:
        raise ApiError(409, "The crew is busy.")
    coins, days = int(t["coins"]), int(t["days"])
    if coins:
        add_coins(ctx, -coins, f"Building the {b['name'].lower()}: {t['name'].lower()}")
    finishes = ctx.today + timedelta(days=days)
    cur = ctx.conn.execute(
        "INSERT INTO buildings_sites (building_id, tier, coins, started, finishes, days) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        [building_id, n, coins, ctx.today.isoformat(), finishes.isoformat(), days],
    )
    if days == 0:
        site = ctx.conn.execute(
            "SELECT * FROM buildings_sites WHERE id = ?", [cur.lastrowid]
        ).fetchone()
        _finish(ctx, site, beat=False)


def crew_progress(ctx: Ctx, site: sqlite3.Row) -> tuple[int, float]:
    """(days done, progress 0..1) for a site's scaffolding."""
    days = int(site["days"])
    done = min(days, max(0, (ctx.today - date.fromisoformat(site["started"])).days))
    return done, (round(done / days, 4) if days else 1.0)


# --- the target ---------------------------------------------------------------------------------


def set_target(ctx: Ctx, building_id: str) -> None:
    """Plant the banner. Switching resets the streak, unless the old target is fully built."""
    ensure(ctx)
    _building(building_id)
    now = built(ctx)
    if now[building_id] >= catalog.max_tier(building_id):
        raise ApiError(409, "Nothing left to build there.")
    old = target(ctx)
    if old == building_id:
        return
    if old is None or now.get(old, 0) < catalog.max_tier(old):
        _set(ctx, "target_streak", 0)
    _set(ctx, "target", building_id)


def mark_seen(ctx: Ctx, building_id: str) -> None:
    ensure(ctx)
    _building(building_id)
    _set_seen(ctx, building_id, built(ctx)[building_id])


# --- what the tiers change ------------------------------------------------------------------------


def _built_tiers(ctx: Ctx) -> list[dict]:
    now = built(ctx)
    return [b["tiers"][n] for b in catalog.buildings() for n in range(now[b["id"]])]


def capacity(ctx: Ctx) -> int:
    """How many followers the village holds: the sum over every built tier."""
    ensure(ctx)
    return sum(int(t["changes"].get("followers", 0)) for t in _built_tiers(ctx))


def unlocks(ctx: Ctx) -> dict[str, int]:
    ensure(ctx)
    out: dict[str, int] = {}
    for t in _built_tiers(ctx):
        for key in t["changes"].get("unlocks", []):
            out[key] = out.get(key, 0) + 1
    return out


def unlocked(ctx: Ctx, key: str) -> int:
    """How many built tiers unlock `key` (arcade.flame, land.east, plot.lodge, ...)."""
    return unlocks(ctx).get(key, 0)
