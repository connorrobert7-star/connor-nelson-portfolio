"""The counted loads behind every machine: the belt and box for cases, a scratch book for
each price, the wheel's wedges and the claw's heap.

Each load is filled and shuffled once, when it loads, and stored. A pull takes the next
one, so the counts the dealer says are read from the database and are always true, and
the odds are exact. Nothing here moves money; callers pay through money/transfer.py first.
"""

import json
import random
from collections import Counter

from backend.core.context import Ctx
from backend.features.casino.catalog import RANK, TIERS, ids_of_tier, machines

# Every load and every roll draws from this. The game uses the system's secure source;
# tests call seed() so a run can be repeated.
RNG: random.Random = random.SystemRandom()


def seed(value: int | None) -> None:
    """Make every load and roll repeatable (tests). None goes back to the secure source."""
    global RNG
    RNG = random.SystemRandom() if value is None else random.Random(value)


def pick_item(tier: str) -> str:
    """A random item of the tier. The tier was decided by a load, never here."""
    return RNG.choice(ids_of_tier(tier))


def _deck(counts: dict[str, int]) -> list[str]:
    deck = [t for t in TIERS for _ in range(counts.get(t, 0))]
    RNG.shuffle(deck)
    return deck


def _count(deck: list[str], tiers: list[str]) -> dict[str, int]:
    c = Counter(deck)
    return {t: c.get(t, 0) for t in tiers}


# --- The belt -------------------------------------------------------------------------


def load_belt(ctx: Ctx) -> None:
    shells = _deck(machines()["belt"]["shells"])
    ctx.conn.execute(
        """INSERT INTO casino_belt (id, shells, pos, loads, loaded_on) VALUES (1, ?, 0, 1, ?)
           ON CONFLICT(id) DO UPDATE SET shells = excluded.shells, pos = 0,
             loads = loads + 1, loaded_on = excluded.loaded_on""",
        [json.dumps(shells), ctx.today.isoformat()],
    )


def _belt(ctx: Ctx) -> tuple[list[str], int]:
    row = ctx.conn.execute("SELECT shells, pos FROM casino_belt WHERE id = 1").fetchone()
    if row is None:
        load_belt(ctx)
        return _belt(ctx)
    return json.loads(row["shells"]), row["pos"]


def belt_left(ctx: Ctx) -> dict[str, int]:
    shells, pos = _belt(ctx)
    return _count(shells[pos:], list(machines()["belt"]["shells"]))


def _fire_belt(ctx: Ctx) -> str:
    shells, pos = _belt(ctx)
    tier = shells[pos]
    if tier == machines()["belt"]["reloads_on"] or pos + 1 >= len(shells):
        load_belt(ctx)
    else:
        ctx.conn.execute("UPDATE casino_belt SET pos = ? WHERE id = 1", [pos + 1])
    return tier


# --- The box --------------------------------------------------------------------------


def load_box(ctx: Ctx) -> None:
    cfg = machines()["box"]
    holes = sorted(RNG.sample(range(cfg["size"]), cfg["specials"]))
    specials = [
        {"hole": h, "tier": "mythic" if RNG.randrange(cfg["mythic_one_in"]) == 0 else "legendary"}
        for h in holes
    ]
    ctx.conn.execute(
        """INSERT INTO casino_box (id, specials, used, loads, loaded_on) VALUES (1, ?, 0, 1, ?)
           ON CONFLICT(id) DO UPDATE SET specials = excluded.specials, used = 0,
             loads = loads + 1, loaded_on = excluded.loaded_on""",
        [json.dumps(specials), ctx.today.isoformat()],
    )


def _box(ctx: Ctx) -> tuple[list[dict], int]:
    row = ctx.conn.execute("SELECT specials, used FROM casino_box WHERE id = 1").fetchone()
    if row is None:
        load_box(ctx)
        return _box(ctx)
    return json.loads(row["specials"]), row["used"]


def box_public(ctx: Ctx) -> dict:
    """What the room shows: holes used, the announced specials still unfired, and the
    gold tell. The tell is always true: when it's on, the next case is that special."""
    specials, used = _box(ctx)
    unfired = [s for s in specials if s["hole"] >= used]
    nxt = next((s for s in unfired if s["hole"] == used), None)
    return {
        "size": machines()["box"]["size"],
        "used": used,
        "specials": sorted((s["tier"] for s in unfired), key=RANK.__getitem__),
        "next_is_special": nxt is not None,
        "next_tier": nxt["tier"] if nxt else None,
    }


def fire_case(ctx: Ctx) -> tuple[str, str]:
    """One case: the box uses a hole; a special hole fires instead of the belt.

    Returns (tier, "box" | "belt"). An epic or better comes within 25 cases and a
    legendary or better within 100, every time, because both loads are finite.
    """
    specials, used = _box(ctx)
    hit = next((s for s in specials if s["hole"] == used), None)
    used += 1
    if used < machines()["box"]["size"] and any(s["hole"] >= used for s in specials):
        ctx.conn.execute("UPDATE casino_box SET used = ? WHERE id = 1", [used])
    else:
        load_box(ctx)
    if hit:
        return hit["tier"], "box"
    return _fire_belt(ctx), "belt"


def case_loads(ctx: Ctx) -> Counter:
    """Every shell still in the belt and every unfired special in the box, by tier."""
    shells, pos = _belt(ctx)
    specials, used = _box(ctx)
    return Counter(shells[pos:]) + Counter(s["tier"] for s in specials if s["hole"] >= used)


# --- Scratch books --------------------------------------------------------------------


def _book_counts(price_cents: int) -> dict[str, int]:
    return next(b["book"] for b in machines()["scratch"] if b["price_cents"] == price_cents)


def load_book(ctx: Ctx, price_cents: int) -> None:
    tickets = _deck(_book_counts(price_cents))
    ctx.conn.execute(
        """INSERT INTO casino_books (price_cents, tickets, pos, loads, loaded_on)
           VALUES (?, ?, 0, 1, ?)
           ON CONFLICT(price_cents) DO UPDATE SET tickets = excluded.tickets, pos = 0,
             loads = loads + 1, loaded_on = excluded.loaded_on""",
        [price_cents, json.dumps(tickets), ctx.today.isoformat()],
    )


def _book(ctx: Ctx, price_cents: int) -> tuple[list[str], int]:
    row = ctx.conn.execute(
        "SELECT tickets, pos FROM casino_books WHERE price_cents = ?", [price_cents]
    ).fetchone()
    if row is None:
        load_book(ctx, price_cents)
        return _book(ctx, price_cents)
    return json.loads(row["tickets"]), row["pos"]


def book_left(ctx: Ctx, price_cents: int) -> dict[str, int]:
    tickets, pos = _book(ctx, price_cents)
    return _count(tickets[pos:], list(_book_counts(price_cents)))


def draw_ticket(ctx: Ctx, price_cents: int) -> str:
    tickets, pos = _book(ctx, price_cents)
    tier = tickets[pos]
    if pos + 1 >= len(tickets):
        load_book(ctx, price_cents)
    else:
        ctx.conn.execute(
            "UPDATE casino_books SET pos = ? WHERE price_cents = ?", [pos + 1, price_cents]
        )
    return tier


# --- The wheel ------------------------------------------------------------------------


def wheel(ctx: Ctx) -> list[dict]:
    rows = ctx.conn.execute("SELECT * FROM casino_wheel ORDER BY wedge_index").fetchall()
    if not rows:
        ctx.conn.executemany(
            "INSERT INTO casino_wheel (wedge_index, tier, taken) VALUES (?, ?, 0)",
            list(enumerate(machines()["wheel"]["wedges"])),
        )
        return wheel(ctx)
    return [dict(r) for r in rows]


def spin(ctx: Ctx) -> tuple[int, str, bool]:
    """Land on one wedge still on the wheel. Returns (wedge_index, tier, reset)."""
    open_wedges = [w for w in wheel(ctx) if not w["taken"]]
    won = RNG.choice(open_wedges)
    reset = won["tier"] == machines()["wheel"]["resets_on"] or len(open_wedges) == 1
    if reset:
        ctx.conn.execute("UPDATE casino_wheel SET taken = 0")
    else:
        ctx.conn.execute(
            "UPDATE casino_wheel SET taken = 1 WHERE wedge_index = ?", [won["wedge_index"]]
        )
    return won["wedge_index"], won["tier"], reset


# --- The claw -------------------------------------------------------------------------


def load_heap(ctx: Ctx) -> None:
    cfg = machines()["claw"]
    tiers = _deck(cfg["heap"])
    ctx.conn.execute("DELETE FROM casino_claw_heap")
    ctx.conn.executemany(
        "INSERT INTO casino_claw_heap (slot_index, tier, x, y, taken) VALUES (?, ?, ?, ?, 0)",
        [(i, t, x, y) for i, (t, (x, y)) in enumerate(zip(tiers, cfg["spots"], strict=True))],
    )


def heap(ctx: Ctx) -> list[dict]:
    """What's still in the glass."""
    rows = ctx.conn.execute("SELECT * FROM casino_claw_heap ORDER BY slot_index").fetchall()
    if not rows:
        load_heap(ctx)
        return heap(ctx)
    return [
        {"slot_index": r["slot_index"], "tier": r["tier"], "x": r["x"], "y": r["y"]}
        for r in rows
        if not r["taken"]
    ]


def _nearest(pile: list[dict], drop_x: float) -> dict:
    """The piece nearest where the claw dropped (topmost on a tie), after a small wobble."""
    wobble = machines()["claw"]["wobble"]
    target = min(1.0, max(0.0, drop_x + RNG.uniform(-wobble, wobble)))
    return min(pile, key=lambda p: (abs(p["x"] - target), p["y"]))


def touch(ctx: Ctx, drop_x: float) -> tuple[int, str]:
    """A blank grab: the claw closes on the nearest piece and slips. The piece stays in the
    heap, so the load is untouched. Returns (slot_index, tier)."""
    got = _nearest(heap(ctx), drop_x)
    return got["slot_index"], got["tier"]


def grab(ctx: Ctx, drop_x: float) -> tuple[int, str]:
    """The claw takes the piece nearest where it dropped (topmost on a tie), after a small
    wobble. A hit's grab always holds. Returns (slot_index, tier)."""
    pile = heap(ctx)
    got = _nearest(pile, drop_x)
    if len(pile) == 1:
        load_heap(ctx)
    else:
        ctx.conn.execute(
            "UPDATE casino_claw_heap SET taken = 1 WHERE slot_index = ?", [got["slot_index"]]
        )
    return got["slot_index"], got["tier"]
