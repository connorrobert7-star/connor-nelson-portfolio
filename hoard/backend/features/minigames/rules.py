"""The arcade's rules: lantern flames, coin pay and caps, the week's dungeon omens, the bag.

Nothing here moves money or reads a dollar amount. Coins are earned by play only. The
week reaches the dungeon as yes/no facts (the tavern was packed, money landed), never
scaled by dollars, and the dungeon pays a fixed amount per room whatever the omens say.
"""

import json
import random
from datetime import date, timedelta
from functools import cache

from backend.content import CONTENT
from backend.core.context import Ctx
from backend.core.dates import week_start
from backend.core.router import ApiError
from backend.features import buildings
from backend.features.week.reactions import village_reactions
from backend.money.budget import landed_cents

GAMES = ("mine", "fishing", "dungeon")
ROOMS = 4  # three rooms and the boss
MAX_STREAK_WEEKS = 104


@cache
def content(name: str) -> dict:
    return json.loads((CONTENT / "minigames" / f"{name}.json").read_text())


def catalog() -> dict:
    return {
        "games": content("games"),
        "ores": content("ores"),
        "fish": content("fish"),
        "dungeon": content("dungeon"),
        "items": content("items")["items"],
    }


def item(item_id: str) -> dict | None:
    return next((i for i in content("items")["items"] if i["id"] == item_id), None)


# --- the lantern -----------------------------------------------------------------------


def flames_per_day(ctx: Ctx) -> int:
    """Full-pay flames a day: the content's base, plus one for each built arcade tier that
    unlocks a flame (the Neon hall, the Grand arcade). Built tiers never unbuild."""
    return int(content("games")["flames_per_day"]) + buildings.unlocked(ctx, "arcade.flame")


def flames_used(ctx: Ctx, day: date | None = None) -> int:
    """Full-pay runs finished on `day` (today by default). The village's bundle reads this."""
    (n,) = ctx.conn.execute(
        "SELECT COUNT(*) FROM minigames_runs WHERE finished = 1 AND full = 1 AND day = ?",
        [(day or ctx.today).isoformat()],
    ).fetchone()
    return n


def flames_left(ctx: Ctx) -> int:
    return max(0, flames_per_day(ctx) - flames_used(ctx))


# --- the real week, as yes/no facts ------------------------------------------------------


def kept_week_streak(ctx: Ctx) -> int:
    """Weeks in a row (Sunday to Saturday) with money landed in an own account. This week
    counts once something has landed; until then the streak runs to last week."""
    start = week_start(ctx.today)
    streak = 1 if landed_cents(ctx, start, ctx.today) > 0 else 0
    ws = start - timedelta(days=7)
    for _ in range(MAX_STREAK_WEEKS):
        if landed_cents(ctx, ws, ws + timedelta(days=6)) <= 0:
            break
        streak += 1
        ws -= timedelta(days=7)
    return streak


def week_facts(ctx: Ctx) -> dict:
    r = village_reactions(ctx.conn, ctx.cmap, ctx.today)
    return {
        "tavern": r["tavern"]["state"],
        "crops": r["crops"]["state"],
        "river": r["drains"]["river"],
        "landed": landed_cents(ctx, ctx.today - timedelta(days=7), ctx.today) > 0,
        "streak": kept_week_streak(ctx),
    }


IDOL_ORDER = {"chips": 0, "mult": 1, "mult_per_follower": 2, "xmult": 3}


def dungeon_modifiers(facts: dict, depth: int = 0) -> dict:
    """The week's omens for the dungeon. Pure: the same facts always give the same run.

    Omens change how the run plays (speed, health, a leech, a buff, one more follower) and
    which idols sit on the door's shelf. They never change the coins a room pays.
    """
    d = content("dungeon")
    om = d["omens"]
    omens: list[str] = []
    enemy_speed = 1.0
    party_hp = 1.0
    if facts["tavern"] == "packed":
        omens.append("packed")
        enemy_speed = om["packed"]["enemy_speed"]
    if facts["crops"] in ("wilting", "withered"):
        omens.append(facts["crops"])
        party_hp = om[facts["crops"]]["party_hp"]
    leech = facts["river"] == "low"
    if leech:
        omens.append("leech")
    buff = bool(facts["landed"])
    if buff:
        omens.append("landed")
    streak = max(0, int(facts["streak"]))
    extra = streak >= d["streak_for_follower"]
    if extra:
        omens.append("streak")

    spec = d["idols"]
    idols = [{"id": "bell", "kind": "mult", "value": spec["bell"]["value"], "week": False}]
    if facts["crops"] in ("bumper", "healthy"):
        idols.append(
            {"id": "green_fields", "kind": "chips", "value": spec["green_fields"]["value"]}
        )
    if facts["tavern"] == "quiet":
        idols.append({"id": "quiet_tavern", "kind": "mult", "value": spec["quiet_tavern"]["value"]})
    if facts["river"] == "high":
        idols.append(
            {"id": "high_river", "kind": "mult_per_follower", "value": spec["high_river"]["value"]}
        )
    if buff:
        idols.append({"id": "lit_shrine", "kind": "xmult", "value": spec["lit_shrine"]["value"]})
    if streak >= 1:
        value = min(spec["streak"]["max"], round(1 + spec["streak"]["per_week"] * streak, 2))
        idols.append({"id": "streak", "kind": "xmult", "value": value})
    for idol in idols:
        idol.setdefault("week", True)
    idols.sort(key=lambda i: IDOL_ORDER[i["kind"]])

    depth = max(0, min(int(depth), d["max_depth"]))
    growth = d["depth_growth"] ** depth
    return {
        "omens": omens,
        "enemy_speed": enemy_speed,
        "party_hp": party_hp,
        "leech": leech,
        "buff": buff,
        "extra_follower": extra,
        "followers": 3 if extra else 2,
        "idols": idols,
        "depth": depth,
        "targets": [round(t * growth) for t in d["targets"]],
        "base_mult": d["base_mult"],
    }


def depth(ctx: Ctx) -> int:
    return int(ctx.meta("minigames_depth", "0") or 0)


def set_depth(ctx: Ctx, value: int) -> int:
    value = max(0, min(value, content("dungeon")["max_depth"]))
    ctx.set_meta("minigames_depth", str(value))
    return value


# --- pay -------------------------------------------------------------------------------


def _count(value: object, what: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int | float) or value != int(value):
        raise ApiError(422, f"{what} must be a whole number.")
    if value < 0:
        raise ApiError(422, f"{what} can't be negative.")
    return int(value)


def score_run(game: str, result: dict) -> tuple[int, int]:
    """(base coins before caps, score for the cabinet) from what the run reports."""
    if not isinstance(result, dict):
        raise ApiError(422, "result must be an object.")
    limits = content("games")["games"][game]
    if game == "mine":
        values = {o["id"]: o["coins"] for o in content("ores")["ores"]}
        ore = result.get("ore", {})
        if not isinstance(ore, dict):
            raise ApiError(422, "ore must be an object.")
        counts = {}
        for k, v in ore.items():
            if k not in values:
                raise ApiError(422, f"No ore called {k}.")
            counts[k] = _count(v, k)
        if sum(counts.values()) > limits["max_ore"]:
            raise ApiError(422, "That's more ore than one run can dig.")
        base = sum(values[k] * n for k, n in counts.items())
        base += min(base, _count(result.get("fever", 0), "fever"))
        return base, min(_count(result.get("depth", 0), "depth"), 999)
    if game == "fishing":
        values = {f["id"]: f["coins"] for f in content("fish")["fish"]}
        caught = result.get("caught", [])
        if not isinstance(caught, list):
            raise ApiError(422, "caught must be a list.")
        if len(caught) > limits["max_fish"]:
            raise ApiError(422, "That's more fish than one run can land.")
        for f in caught:
            if f not in values:
                raise ApiError(422, f"No fish called {f}.")
        return sum(values[f] for f in caught), len(caught)
    rooms = min(_count(result.get("rooms_cleared", 0), "rooms_cleared"), ROOMS)
    base = sum(content("dungeon")["room_coins"][:rooms])
    return base, min(_count(result.get("best_cascade", 0), "best_cascade"), 10**12)


def payout(game: str, base: int, full: bool) -> int:
    """Coins for a run: at least the game's minimum once anything was earned, never over its
    cap, and a quarter of that once the day's flames are spent."""
    if base <= 0:
        return 0
    g = content("games")["games"][game]
    coins = min(g["cap"], max(g["min_coins"], base))
    if not full:
        coins = max(1, round(coins * content("games")["spent_flame_rate"]))
    return coins


# --- the bag ---------------------------------------------------------------------------


def draw_from_bag(ctx: Ctx) -> dict:
    """The next cosmetic from the dungeon's shuffle bag: every item once before any repeats."""
    row = ctx.conn.execute(
        "SELECT pos, item_id FROM minigames_bag WHERE drawn = 0 ORDER BY pos LIMIT 1"
    ).fetchone()
    if row is None:
        cycle = int(ctx.meta("minigames_bag_cycle", "0") or 0) + 1
        ctx.set_meta("minigames_bag_cycle", str(cycle))
        ids = [i["id"] for i in content("items")["items"]]
        random.Random(f"minigames-bag:{cycle}:{ctx.today.isoformat()}").shuffle(ids)
        ctx.conn.execute("DELETE FROM minigames_bag")
        ctx.conn.executemany(
            "INSERT INTO minigames_bag (pos, cycle, item_id) VALUES (?, ?, ?)",
            [(i, cycle, item_id) for i, item_id in enumerate(ids)],
        )
        row = ctx.conn.execute(
            "SELECT pos, item_id FROM minigames_bag WHERE drawn = 0 ORDER BY pos LIMIT 1"
        ).fetchone()
    ctx.conn.execute("UPDATE minigames_bag SET drawn = 1 WHERE pos = ?", [row["pos"]])
    found = item(row["item_id"])
    assert found is not None
    return found


def relic_waiting(ctx: Ctx) -> bool:
    """The dungeon boss holds one cosmetic a day until someone takes it."""
    (n,) = ctx.conn.execute(
        "SELECT COUNT(*) FROM minigames_runs WHERE game = 'dungeon' AND day = ? "
        "AND item_id IS NOT NULL",
        [ctx.today.isoformat()],
    ).fetchone()
    return n == 0


def bests(ctx: Ctx) -> dict:
    out = {}
    for game in GAMES:
        (best,) = ctx.conn.execute(
            "SELECT COALESCE(MAX(score), 0) FROM minigames_runs WHERE game = ? AND finished = 1",
            [game],
        ).fetchone()
        out[game] = best
    return out


def run_seed(ctx: Ctx, game: str) -> int:
    if game == "dungeon":
        key = f"{ctx.today.isoformat()}:dungeon"  # the daily dungeon: one layout a day
    else:
        (n,) = ctx.conn.execute("SELECT COUNT(*) FROM minigames_runs").fetchone()
        key = f"{ctx.today.isoformat()}:{game}:{n}"
    return random.Random(key).randrange(1, 2**31 - 1)
