"""The flock: Faith, bellies, loyalty, the personal follower, holdings, mourning.

Followers never move money and never look at prices. Faith is read from the last
day money landed; bellies fill only with coin food; loyalty comes only from play.
The backend picks every follower's pose and bubble; the game only draws them.
"""

import json
import math
import random
import sqlite3
from datetime import date, timedelta
from functools import cache

from backend.content import CONTENT
from backend.core.context import Ctx
from backend.core.dates import week_start
from backend.core.router import ApiError
from backend.core.services import add_coins, away, grant_item
from backend.features import buildings
from backend.features.week.reactions import village_reactions
from backend.money.budget import (
    LANDING_CATEGORIES,
    compute_extra,
    landed_cents,
    last_landing_day,
)
from backend.sync import anchor

FEATURE = "followers"
PERSONAL = "personal"

# Faith bands by days since money last landed (fervent 0-2, content 3-6, doubting 7-13).
BANDS = ((2, "fervent"), (6, "content"), (13, "doubting"))
MOURNING_BAND = "mourning"

# The personal follower grows at these kept-week totals and never shrinks.
STAGE_WEEKS = (1, 2, 4, 8, 13, 26, 52)

FULL = 100
NEW_BELLY = 60
BELLY_DRAIN_PER_DAY = 50  # 100 to 0 in two days: one visit a day keeps them fed
HUNGRY_BELOW = 30
WEEK_HUNGRY_BELOW = 70  # groceries over budget: they grumble unless well fed

PET_LOYALTY = 20
LEVEL_LOYALTY = 100

GIANT_SHARE = 0.40
GIANT_SCALE = 2.2

WEAR_SLOTS = ("hat", "cloak", "aura", "follower_skin")

# Devotion: tending the flock piles coins up on the altar. It is the flock's, not each
# follower's: the first loyalty earned by play each day puts the day's share on the altar and
# the rest of the day adds nothing, so a flock of one and a flock of ten (more holdings) earn
# the same coins a day. Money never buys coins.
DEVOTION_START = 30
DEVOTION_DAILY_CAP = 60
DEVOTION_PILE_CAP = 150

# "While you were out" beats this feature queues. Lower plays first. The other features'
# beats slot between: builds (village) about 20, gate hits about 30.
PRIORITY = {"landed": 10, "mourning": 40, "grew": 45, "resized": 48, "poses": 50, "hug": 60}


# --- content -----------------------------------------------------------------------


@cache
def _content(name: str) -> dict:
    return json.loads((CONTENT / FEATURE / f"{name}.json").read_text())


def foods() -> list[dict]:
    return _content("foods")["foods"]


def food(food_id: str) -> dict | None:
    return next((f for f in foods() if f["id"] == food_id), None)


def favorite_foods() -> dict[str, dict]:
    return {f["id"]: f for f in _content("foods")["favorites"]}


def things() -> list[str]:
    return _content("foods")["things"]


def poses() -> dict:
    return _content("poses")


def stages() -> list[dict]:
    return _content("names")["stages"]


@cache
def catalog() -> dict[str, dict]:
    """Every cosmetic in every feature's catalog (content/<id>/items.json), by id."""
    out: dict[str, dict] = {}
    for path in sorted(CONTENT.glob("*/items.json")):
        raw = json.loads(path.read_text())
        for item in raw if isinstance(raw, list) else raw.get("items", []):
            out[item["id"]] = item
    return out


def own_catalog() -> list[dict]:
    return _content("items")["items"]


def creature_look(symbol: str, kind: str, market_creature: str = "") -> dict:
    c = _content("creatures")
    name = market_creature if market_creature in c["creatures"] else ""
    name = name or c["symbols"].get(symbol) or c["kinds"].get(kind) or c["default"]
    col, row = c["creatures"][name]
    return {"creature": name, "sheet": c["sheet"], "rect": [col * 16, row * 16, 16, 16]}


# --- small helpers -------------------------------------------------------------------


def _rng(ctx: Ctx, *parts: object) -> random.Random:
    return random.Random("|".join(["followers", anchor(ctx).isoformat(), *map(str, parts)]))


def _iso(d: date | None) -> str | None:
    return d.isoformat() if d else None


def _meta_int(ctx: Ctx, key: str, default: int) -> int:
    return int(ctx.meta(f"followers_{key}", str(default)))


def _set_meta(ctx: Ctx, key: str, value: object) -> None:
    ctx.set_meta(f"followers_{key}", str(value))


# --- Faith ----------------------------------------------------------------------------


def days_since_landing(ctx: Ctx) -> int:
    """Days since money last landed in an own account. A new save starts at day 0."""
    last = last_landing_day(ctx) or anchor(ctx)
    return max(0, (ctx.today - last).days)


def band_for(days: int) -> str:
    for limit, name in BANDS:
        if days <= limit:
            return name
    return MOURNING_BAND


# --- the week ------------------------------------------------------------------------


def record_extra(ctx: Ctx, day: date) -> None:
    """Remember the week's extra as first seen on a day, to judge that week later."""
    ctx.conn.execute(
        "INSERT OR IGNORE INTO followers_days (day, extra_cents) VALUES (?, ?)",
        [day.isoformat(), compute_extra(ctx)["extra_cents"]],
    )


def _extras(ctx: Ctx, start: date, end: date) -> list[int]:
    return [
        r["extra_cents"]
        for r in ctx.conn.execute(
            "SELECT extra_cents FROM followers_days WHERE day BETWEEN ? AND ?",
            [start.isoformat(), end.isoformat()],
        )
    ]


def week_kept(ctx: Ctx, start: date) -> bool:
    """A kept week: money landed in an own account during it (since this save began), or
    a finished lean week, one whose extra was never above 0. Lean weeks never count against."""
    end = start + timedelta(days=6)
    lo, hi = max(start, anchor(ctx)), min(end, ctx.today)
    if lo <= hi and landed_cents(ctx, lo, hi) > 0:
        return True
    if end >= ctx.today:
        return False
    extras = _extras(ctx, start, end)
    return bool(extras) and all(e <= 0 for e in extras)


def kept_weeks(ctx: Ctx) -> int:
    count, w = 0, week_start(anchor(ctx))
    while w <= ctx.today:
        count += week_kept(ctx, w)
        w += timedelta(days=7)
    return count


def streak(ctx: Ctx) -> int:
    """Kept weeks in a row, ending this week if it is already kept, else last week."""
    w = week_start(ctx.today)
    if not week_kept(ctx, w):
        w -= timedelta(days=7)
    first, n = week_start(anchor(ctx)), 0
    while w >= first and week_kept(ctx, w):
        n += 1
        w -= timedelta(days=7)
    return n


def stage_for(kept: int) -> int:
    return sum(1 for weeks in STAGE_WEEKS if kept >= weeks)


def week_reactions(ctx: Ctx) -> set[str]:
    """The week's spending, as the flock wears it: hungry, lazy, chant."""
    r = village_reactions(ctx.conn, ctx.cmap, ctx.today)
    out = set()
    if r["crops"]["state"] in ("wilting", "withered"):
        out.add("hungry")
    if r["tavern"]["state"] == "packed":
        out.add("lazy")
    if band_for(days_since_landing(ctx)) == "fervent":
        out.add("chant")
    return out


# --- mourning and the Grave of Weeks -------------------------------------------------


def missed_week(ctx: Ctx, start: date) -> tuple[bool, int]:
    """(missed, extra): a week with extra above 0 in which nothing landed."""
    end = start + timedelta(days=6)
    if landed_cents(ctx, start, end) > 0:
        return False, 0
    extras = _extras(ctx, start, end)
    extra = max(extras) if extras else compute_extra(ctx)["extra_cents"]
    return extra > 0, extra


def check_missed_week(ctx: Ctx, day: date) -> dict | None:
    """On a Monday, mourn the week that ended on Saturday if it was missed."""
    if day.weekday() != 0:
        return None
    start = week_start(day) - timedelta(days=7)
    if start < week_start(anchor(ctx)):
        return None
    missed, extra = missed_week(ctx, start)
    if not missed:
        return None
    cur = ctx.conn.execute(
        "INSERT OR IGNORE INTO followers_graves (week_start, mourned_on, extra_cents) "
        "VALUES (?, ?, ?)",
        [start.isoformat(), day.isoformat(), extra],
    )
    if cur.rowcount == 0:
        return None
    return {"week_start": start.isoformat(), "week_end": (start + timedelta(days=6)).isoformat()}


def graves(ctx: Ctx) -> list[dict]:
    """Every missed week's candle. The next deposit after a week plants a flower beside it."""
    last = last_landing_day(ctx)
    out = []
    for r in ctx.conn.execute("SELECT * FROM followers_graves ORDER BY week_start"):
        start = date.fromisoformat(r["week_start"])
        end = start + timedelta(days=6)
        out.append(
            {
                "week_start": start.isoformat(),
                "week_end": end.isoformat(),
                "mourned_on": r["mourned_on"],
                "flower": last is not None and last > end,
            }
        )
    return out


def mourning(ctx: Ctx) -> dict | None:
    """The grave being mourned right now: from its Monday until money lands or a week passes."""
    for g in reversed(graves(ctx)):
        mourned = date.fromisoformat(g["mourned_on"])
        if mourned <= ctx.today < mourned + timedelta(days=7) and not g["flower"]:
            return g
    return None


# --- holdings ----------------------------------------------------------------------------


def _holding_values(ctx: Ctx) -> dict[str, int]:
    """Value per symbol: the synced holdings plus shop orders that haven't reached the bank."""
    values: dict[str, int] = {}
    for r in ctx.conn.execute("SELECT symbol, SUM(value_cents) AS v FROM holdings GROUP BY symbol"):
        values[r["symbol"]] = r["v"]
    try:
        rows = ctx.conn.execute(
            """SELECT o.symbol, SUM(o.amount_cents) AS v FROM orders o
               JOIN transfers t ON t.id = o.transfer_id
               WHERE t.status IN ('simulated', 'pending') GROUP BY o.symbol"""
        ).fetchall()
    except sqlite3.OperationalError:  # no shop in this build
        rows = []
    for r in rows:
        values[r["symbol"]] = values.get(r["symbol"], 0) + r["v"]
    return {s: v for s, v in values.items() if v > 0}


def snapshot_sizes(ctx: Ctx, week: date) -> bool:
    """Size the holding followers for a week. Returns False if that week is already sized."""
    if ctx.conn.execute(
        "SELECT 1 FROM followers_sizes WHERE week_start = ? LIMIT 1", [week.isoformat()]
    ).fetchone():
        return False
    values = _holding_values(ctx)
    total = sum(values.values())
    ctx.conn.executemany(
        "INSERT INTO followers_sizes (week_start, symbol, value_cents, share) VALUES (?, ?, ?, ?)",
        [(week.isoformat(), s, v, v / total) for s, v in sorted(values.items())],
    )
    return True


def sizes(ctx: Ctx, week: date | None = None) -> dict[str, float]:
    """symbol -> portfolio share, fixed for the week (Sunday to Saturday)."""
    week = week or week_start(ctx.today)
    snapshot_sizes(ctx, week)
    return {
        r["symbol"]: r["share"]
        for r in ctx.conn.execute(
            "SELECT symbol, share FROM followers_sizes WHERE week_start = ? ORDER BY symbol",
            [week.isoformat()],
        )
    }


def cultists(band: str, capacity: int) -> int:
    """Nameless cultists for a Faith band: the band's share of the village's follower
    capacity. At the founding capacity the counts are content's (12, 8, 4, 2)."""
    look = poses()
    at = int(look.get("cultists_at_capacity", 12)) or 1
    return round(look["bands"][band]["cultists"] * max(0, capacity) / at)


def scale_for(share: float) -> float:
    return GIANT_SCALE if share > GIANT_SHARE else round(0.7 + 1.3 * math.sqrt(share), 3)


# --- rows ----------------------------------------------------------------------------------


def ensure(ctx: Ctx, fid: str, kind: str, symbol: str | None = None) -> sqlite3.Row:
    row = ctx.conn.execute("SELECT * FROM followers_flock WHERE id = ?", [fid]).fetchone()
    if row:
        return row
    rng = _rng(ctx, fid)
    # Favorites are spread around the flock so watching them tells them apart.
    taken = {r[0] for r in ctx.conn.execute("SELECT favorite_food FROM followers_flock")}
    dishes = sorted(set(favorite_foods()) - taken) or sorted(favorite_foods())
    ctx.conn.execute(
        """INSERT INTO followers_flock
           (id, kind, symbol, name, belly, favorite_food, favorite_thing, created)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        [
            fid,
            kind,
            symbol,
            symbol if kind == "holding" else None,
            NEW_BELLY,
            rng.choice(dishes),
            rng.choice(things()),
            ctx.today.isoformat(),
        ],
    )
    return ctx.conn.execute("SELECT * FROM followers_flock WHERE id = ?", [fid]).fetchone()


def holding_rows(ctx: Ctx) -> list[tuple[sqlite3.Row, float]]:
    """This week's holding followers with their share, biggest first."""
    shares = sizes(ctx)
    rows = [(ensure(ctx, f"hold_{s}", "holding", s), share) for s, share in shares.items()]
    return sorted(rows, key=lambda t: (-t[1], t[0]["symbol"]))


def hatched(ctx: Ctx) -> bool:
    """The egg cracks when the first money lands in this save."""
    last = last_landing_day(ctx)
    row = ensure(ctx, PERSONAL, "personal")
    return row["stage"] > 0 or (last is not None and last >= anchor(ctx))


def personal_stage(ctx: Ctx) -> tuple[int, int]:
    """(stage, kept weeks). The stored stage is a high-water mark, so it never goes down."""
    row = ensure(ctx, PERSONAL, "personal")
    if not hatched(ctx):
        return row["stage"], 0
    kept = kept_weeks(ctx)
    return max(row["stage"], stage_for(kept)), kept


def store_stage(ctx: Ctx, stage: int) -> int:
    """Save a new high-water stage. Returns the stage it grew from."""
    row = ensure(ctx, PERSONAL, "personal")
    if stage > row["stage"]:
        ctx.conn.execute("UPDATE followers_flock SET stage = ? WHERE id = ?", [stage, PERSONAL])
    return row["stage"]


def offered_names(ctx: Ctx) -> list[str]:
    return _rng(ctx, "names").sample(_content("names")["personal"], 3)


def follower(ctx: Ctx, fid: str) -> sqlite3.Row:
    """A follower the owner can see right now, or a 404."""
    if fid == PERSONAL:
        return ensure(ctx, PERSONAL, "personal")
    if fid.startswith("hold_") and fid[5:] in sizes(ctx):
        return ensure(ctx, fid, "holding", fid[5:])
    raise ApiError(404, "No such follower.")


# --- loyalty and devotion ----------------------------------------------------------------


def devotion(ctx: Ctx) -> int:
    return _meta_int(ctx, "devotion", DEVOTION_START)


def add_devotion(ctx: Ctx, amount: int) -> int:
    """The first loyalty earned by play each day puts the day's share (DEVOTION_DAILY_CAP) on
    the altar; later loyalty that day adds nothing. How many followers there are, or how much
    they are tended, never changes the coins a day."""
    today = ctx.today.isoformat()
    if amount <= 0 or ctx.meta("followers_devotion_on") == today:
        return 0
    add = max(0, min(DEVOTION_DAILY_CAP, DEVOTION_PILE_CAP - devotion(ctx)))
    _set_meta(ctx, "devotion_on", today)
    _set_meta(ctx, "devotion_today", add)
    _set_meta(ctx, "devotion", devotion(ctx) + add)
    return add


def _draw_cosmetic(ctx: Ctx) -> str:
    """The flock's own shuffle bag: every item once before any repeats. Cosmetic only."""
    bag = json.loads(ctx.meta("followers_bag", "[]"))
    if not bag:
        rounds = _meta_int(ctx, "bag_rounds", 0)
        bag = [i["id"] for i in own_catalog()]
        _rng(ctx, "bag", rounds).shuffle(bag)
        _set_meta(ctx, "bag_rounds", rounds + 1)
    item_id = bag.pop(0)
    ctx.set_meta("followers_bag", json.dumps(bag))
    return item_id


def add_loyalty(ctx: Ctx, fid: str, amount: int) -> dict:
    """Raise a follower's loyalty from play (petting, feeding, dungeon runs).

    A full bar is a level: a body mark and a cosmetic from the flock's bag. The loyalty
    also piles up as devotion on the altar. No money is read or moved."""
    row = follower(ctx, fid)
    loyalty, level = row["loyalty"] + max(0, amount), row["level"]
    items = []
    while loyalty >= LEVEL_LOYALTY:
        loyalty -= LEVEL_LOYALTY
        level += 1
        item_id = _draw_cosmetic(ctx)
        grant_item(ctx, item_id, via="followers_loyalty")
        item = catalog().get(item_id, {})
        ctx.events[-1].update(name=item.get("name", item_id), tier=item.get("tier", "common"))
        items.append(item_id)
    ctx.conn.execute(
        "UPDATE followers_flock SET loyalty = ?, level = ? WHERE id = ?", [loyalty, level, fid]
    )
    if level > row["level"]:
        ctx.emit("follower_level", follower_id=fid, level=level)
    devotion_added = add_devotion(ctx, amount)
    return {
        "loyalty": loyalty,
        "level": level,
        "level_up": level > row["level"],
        "items": items,
        "devotion_added": devotion_added,
    }


# --- what each follower looks like right now --------------------------------------------


def _wearing(ctx: Ctx) -> dict[str, dict[str, dict]]:
    out: dict[str, dict[str, dict]] = {}
    cat = catalog()
    for r in ctx.conn.execute("SELECT follower_id, slot, item_id FROM followers_wear"):
        item = cat.get(r["item_id"])
        if item:
            out.setdefault(r["follower_id"], {})[r["slot"]] = _item_view(item)
    return out


def _item_view(item: dict) -> dict:
    return {k: item.get(k) for k in ("id", "name", "tier", "slot", "set", "icon")}


def wearables(ctx: Ctx) -> list[dict]:
    """Owned cosmetics a follower can wear, from any feature's catalog."""
    cat = catalog()
    worn: dict[str, list[str]] = {}
    for r in ctx.conn.execute("SELECT follower_id, item_id FROM followers_wear ORDER BY since"):
        worn.setdefault(r["item_id"], []).append(r["follower_id"])
    out = []
    for r in ctx.conn.execute(
        "SELECT item_id, COUNT(*) AS n, MIN(id) AS first FROM inventory "
        "GROUP BY item_id ORDER BY first"
    ):
        item = cat.get(r["item_id"])
        if item and item.get("slot") in WEAR_SLOTS:
            out.append({**_item_view(item), "count": r["n"], "worn_by": worn.get(item["id"], [])})
    return out


def _pose(
    *, egg: bool, veiled: bool, starving: bool, hungry: bool, lazy: bool, band: str
) -> tuple[str, str]:
    """(pose, bubble) in priority order: the egg, grief, an empty belly, sleep, the band."""
    if egg:
        return "egg", ""
    if veiled:
        return "veiled", "crying"
    if starving:
        return "flat", "drool"
    if hungry:
        return "hungry", "drool"
    if lazy:
        return "sleep", "sleepy"
    return {"fervent": ("chant", "lit"), "content": ("idle", ""), "doubting": ("droop", "sweat")}[
        band
    ]


def _follower_view(
    ctx: Ctx, row: sqlite3.Row, *, band: str, reactions: set[str], veiled: bool, egg: bool = False
) -> dict:
    today = ctx.today.isoformat()
    belly = row["belly"]
    petted, fed = row["petted_on"] == today, row["fed_on"] == today
    hungry = not egg and (
        belly < HUNGRY_BELOW or ("hungry" in reactions and belly < WEEK_HUNGRY_BELOW)
    )
    starving = not egg and belly <= 0
    lazy = not egg and "lazy" in reactions and not petted
    pose, bubble = _pose(
        egg=egg, veiled=veiled, starving=starving, hungry=hungry, lazy=lazy, band=band
    )
    if bubble == "" and (petted or fed):
        bubble = "love"
    fav = favorite_foods()[row["favorite_food"]]
    return {
        "id": row["id"],
        "kind": row["kind"],
        "name": row["name"],
        "belly": belly,
        "loyalty": row["loyalty"],
        "level": row["level"],
        "petted_today": petted,
        "fed_today": fed,
        "hungry": hungry,
        "starving": starving,
        "lazy": lazy,
        "veiled": veiled,
        "pose": pose,
        "bubble": bubble,
        "favorite_food": {"id": fav["id"], "name": fav["name"], "icon": fav["icon"]},
        "favorite_thing": row["favorite_thing"],
    }


def flock_state(ctx: Ctx) -> dict:
    record_extra(ctx, ctx.today)
    days = days_since_landing(ctx)
    band = band_for(days)
    reactions = week_reactions(ctx)
    grave = mourning(ctx)
    veiled = grave is not None or band == MOURNING_BAND
    wearing = _wearing(ctx)
    look = poses()
    capacity = buildings.capacity(ctx)

    # The personal follower.
    is_hatched = hatched(ctx)
    stage, kept = personal_stage(ctx)
    store_stage(ctx, stage)
    row = ensure(ctx, PERSONAL, "personal")
    personal = _follower_view(
        ctx, row, band=band, reactions=reactions, veiled=veiled, egg=not is_hatched
    )
    named = row["name"] is not None
    if is_hatched and not named:
        personal["bubble"] = "question"
    next_weeks = next((w for w in STAGE_WEEKS if w > kept), None)
    personal |= {
        "hatched": is_hatched,
        "named": named,
        "offered_names": offered_names(ctx) if is_hatched and not named else [],
        "stage": stage,
        "stage_name": stages()[stage]["name"],
        "kept_weeks": kept,
        "next_stage_weeks": next_weeks,
        "streak": streak(ctx) if is_hatched else 0,
        "look": {"kind": "lamb", "stage": stage},
        "wearing": wearing.get(PERSONAL, {}),
    }

    # One follower per holding, sized by this week's share.
    market = {t["symbol"]: t for t in ctx.providers.market.catalog()}
    holdings = []
    giant = None
    for hrow, share in holding_rows(ctx):
        symbol = hrow["symbol"]
        ticker = market.get(symbol, {})
        is_giant = share > GIANT_SHARE
        giant = giant or (symbol if is_giant else None)
        view = _follower_view(ctx, hrow, band=band, reactions=reactions, veiled=veiled)
        holdings.append(
            view
            | {
                "symbol": symbol,
                "share": round(share, 4),
                "scale": scale_for(share),
                "giant": is_giant,
                "look": creature_look(symbol, ticker.get("kind", ""), ticker.get("creature", "")),
                "wearing": wearing.get(hrow["id"], {}),
            }
        )

    cultist_pose, cultist_bubble = _pose(
        egg=False,
        veiled=veiled,
        starving=False,
        hungry="hungry" in reactions,
        lazy="lazy" in reactions,
        band=band,
    )
    return {
        "faith": {
            "band": band,
            "days_since_landing": days,
            "glow": look["bands"][band]["glow"],
            "last_landing_day": _iso(last_landing_day(ctx)),
        },
        "personal": personal,
        "holdings": holdings,
        "giant": giant,
        "cultists": cultists(band, capacity),
        "capacity": capacity,
        "cultist_pose": cultist_pose,
        "cultist_bubble": cultist_bubble,
        "mourning": grave is not None,
        "mourning_week": grave,
        "graves": graves(ctx),
        "reactions": sorted(reactions),
        "foods": foods(),
        "wearables": wearables(ctx),
        "devotion": {"amount": devotion(ctx), "daily_cap": DEVOTION_DAILY_CAP},
        "poses": look["poses"],
        "bubbles": look["bubbles"],
        "bands": look["bands"],
    }


# --- actions ------------------------------------------------------------------------------


def pet(ctx: Ctx, fid: str) -> dict:
    row = follower(ctx, fid)
    if row["petted_on"] == ctx.today.isoformat():
        return {"follower_id": fid, "gained": 0, "loyalty": row["loyalty"], "level": row["level"]}
    ctx.conn.execute(
        "UPDATE followers_flock SET petted_on = ? WHERE id = ?", [ctx.today.isoformat(), fid]
    )
    return {"follower_id": fid, "gained": PET_LOYALTY, **add_loyalty(ctx, fid, PET_LOYALTY)}


def feed(ctx: Ctx, fid: str, food_id: str) -> dict:
    """Coins only. A full follower shakes its head and nothing is spent."""
    row = follower(ctx, fid)
    f = food(food_id)
    if f is None:
        raise ApiError(404, "No such food.")
    if fid == PERSONAL and not hatched(ctx):
        raise ApiError(409, "The egg doesn't eat yet.")
    if row["belly"] >= FULL:
        return {"follower_id": fid, "full": True, "belly": row["belly"], "spent": 0}
    add_coins(ctx, -f["price"], f"Fed {row['name'] or 'the hatchling'} {f['name'].lower()}")
    belly = min(FULL, row["belly"] + f["belly"])
    ctx.conn.execute(
        "UPDATE followers_flock SET belly = ?, fed_on = ? WHERE id = ?",
        [belly, ctx.today.isoformat(), fid],
    )
    favorite = favorite_foods()[row["favorite_food"]] if food_id == "favorite" else None
    return {
        "follower_id": fid,
        "full": False,
        "belly": belly,
        "spent": f["price"],
        "ate": favorite["id"] if favorite else food_id,
        **add_loyalty(ctx, fid, f["loyalty"]),
    }


def name_personal(ctx: Ctx, name: str) -> dict:
    row = ensure(ctx, PERSONAL, "personal")
    if not hatched(ctx):
        raise ApiError(409, "The egg hasn't hatched.")
    if row["name"] is not None:
        raise ApiError(409, f"Already named {row['name']}.")
    if name not in offered_names(ctx):
        raise ApiError(422, "Pick one of the three names.")
    ctx.conn.execute("UPDATE followers_flock SET name = ? WHERE id = ?", [name, PERSONAL])
    return {"follower_id": PERSONAL, "name": name}


def dress(ctx: Ctx, fid: str, item_id: str, slot: str = "") -> dict:
    """Put an owned cosmetic on a follower. An empty item_id takes off what's in `slot`."""
    follower(ctx, fid)
    if not item_id:
        if slot not in WEAR_SLOTS:
            raise ApiError(422, "slot must be hat, cloak, aura or follower_skin.")
        ctx.conn.execute(
            "DELETE FROM followers_wear WHERE follower_id = ? AND slot = ?", [fid, slot]
        )
        return {"follower_id": fid, "slot": slot, "item_id": None}
    item = catalog().get(item_id)
    if item is None or item.get("slot") not in WEAR_SLOTS:
        raise ApiError(409, "That can't be worn.")
    (owned,) = ctx.conn.execute(
        "SELECT COUNT(*) FROM inventory WHERE item_id = ?", [item_id]
    ).fetchone()
    if owned == 0:
        raise ApiError(409, "You don't have that.")
    slot = item["slot"]
    ctx.conn.execute("DELETE FROM followers_wear WHERE follower_id = ? AND slot = ?", [fid, slot])
    # Each copy is worn by one follower at a time: the longest-worn copy moves over.
    wearers = ctx.conn.execute(
        "SELECT follower_id FROM followers_wear WHERE item_id = ? ORDER BY since", [item_id]
    ).fetchall()
    for w in wearers[: max(0, len(wearers) - owned + 1)]:
        ctx.conn.execute(
            "DELETE FROM followers_wear WHERE follower_id = ? AND item_id = ?",
            [w["follower_id"], item_id],
        )
    ctx.conn.execute(
        "INSERT INTO followers_wear (follower_id, slot, item_id, since) VALUES (?, ?, ?, ?)",
        [fid, slot, item_id, ctx.today.isoformat()],
    )
    return {"follower_id": fid, "slot": slot, "item_id": item_id}


def collect(ctx: Ctx) -> dict:
    amount = devotion(ctx)
    if amount > 0:
        add_coins(ctx, amount, "Devotion from the flock")
        _set_meta(ctx, "devotion", 0)
    return {"coins": amount}


# --- while you were out ---------------------------------------------------------------------


def beat(ctx: Ctx, kind: str, mode: str = "new", **payload: object) -> None:
    """Queue a beat. 'replace' keeps one unseen beat of the kind (the oldest `from_stage`
    survives, so a hatch is still shown as a hatch); 'sum' adds amount_cents."""
    if mode != "new":
        row = ctx.conn.execute(
            "SELECT id, payload FROM away_events WHERE kind = ? AND shown = 0 "
            "ORDER BY id DESC LIMIT 1",
            [kind],
        ).fetchone()
        if row:
            old = json.loads(row["payload"] or "{}")
            if mode == "sum":
                total = int(old.get("amount_cents", 0)) + int(str(payload.get("amount_cents", 0)))
                since = old.get("since", old.get("day"))
                payload = {**old, **payload, "amount_cents": total, "since": since}
            elif "from_stage" in old:
                payload = {**payload, "from_stage": old["from_stage"]}
            ctx.conn.execute(
                "UPDATE away_events SET payload = ?, day = ? WHERE id = ?",
                [json.dumps(payload), ctx.today.isoformat(), row["id"]],
            )
            return
    away(ctx, kind, PRIORITY[kind], **payload)


def bank_landed(ctx: Ctx, day: date) -> int:
    """Savings and investment transfers the bank made on a day (they land overnight)."""
    (total,) = ctx.conn.execute(
        f"""SELECT COALESCE(SUM(amount_cents), 0) FROM transactions
            WHERE category IN ({",".join("?" * len(LANDING_CATEGORIES))})
              AND amount_cents > 0 AND date = ?""",
        [*LANDING_CATEGORIES, day.isoformat()],
    ).fetchone()
    return total


def daily(ctx: Ctx, day: date) -> None:
    """One game day passing: bellies drain, the week is judged, and the beats queue up."""
    record_extra(ctx, day)
    egg = not hatched(ctx)

    # Money the bank moved yesterday lands overnight.
    landed = bank_landed(ctx, day - timedelta(days=1))
    if landed:
        beat(ctx, "landed", "sum", amount_cents=landed, day=(day - timedelta(days=1)).isoformat())

    # Bellies drain. The egg doesn't eat.
    ctx.conn.execute(
        "UPDATE followers_flock SET belly = MAX(0, belly - ?) WHERE kind = 'holding' OR ?",
        [BELLY_DRAIN_PER_DAY, 0 if egg else 1],
    )

    # Monday: a missed week is mourned.
    grave = check_missed_week(ctx, day)
    if grave:
        beat(ctx, "mourning", **grave)

    # Sunday: holding followers are resized, quietly, once.
    if day.weekday() == 6:
        before = sizes(ctx, day - timedelta(days=7))
        if snapshot_sizes(ctx, day):
            after = sizes(ctx, day)
            if {s: scale_for(v) for s, v in before.items()} != {
                s: scale_for(v) for s, v in after.items()
            }:
                giant = next((s for s, v in after.items() if v > GIANT_SHARE), None)
                beat(ctx, "resized", "replace", giant=giant, symbols=sorted(after))

    # The personal follower grows with kept weeks.
    stage, kept = personal_stage(ctx)
    grew_from = store_stage(ctx, stage)
    personal = ensure(ctx, PERSONAL, "personal")
    if stage > grew_from:
        beat(
            ctx,
            "grew",
            "replace",
            stage=stage,
            from_stage=grew_from,
            kept_weeks=kept,
            name=personal["name"],
        )

    # How the flock looks this morning, and the hello.
    holdings = holding_rows(ctx)
    bellies = [r["belly"] for r, _ in holdings] + ([] if egg else [personal["belly"]])
    reactions = week_reactions(ctx)
    beat(
        ctx,
        "poses",
        "replace",
        band=band_for(days_since_landing(ctx)),
        reactions=sorted(reactions),
        hungry=sum(1 for b in bellies if b < HUNGRY_BELOW),
        starving=sum(1 for b in bellies if b <= 0),
        mourning=mourning(ctx) is not None,
    )
    beat(ctx, "hug", "replace", name=personal["name"], stage=stage, egg=egg)
