"""The machines: cases, scratch books, the wheel, the claw, the trade-up hopper, and the
collection book's equip.

Every paid pull goes the same way, in one request:
  1. check the price against the week's extra and the transfer caps ("Not this week."),
  2. move() the exact price from checking into the owner's House Fund or Brokerage,
  3. only then take the next shell, ticket, wedge or heap piece and grant a cosmetic.
If the transfer comes back 'failed', the pull is refused ("Not this week.") before step 3.
Money is never random. The price lands in full every time; only the cosmetic varies.
"""

from collections import Counter

from backend.core.context import Ctx
from backend.core.router import ApiError
from backend.core.services import grant_item
from backend.features.casino import catalog, dealer, loads
from backend.features.casino.catalog import RANK, TIERS, TRADE_UP, machines
from backend.money.budget import balances, compute_extra
from backend.money.transfer import caps_remaining, move

CHECKING = "chk_1"


# --- Money ----------------------------------------------------------------------------


def destinations() -> list[str]:
    return list(machines()["destinations"])


def can_spend_cents(ctx: Ctx) -> int:
    return max(0, min(compute_extra(ctx)["extra_cents"], caps_remaining(ctx)))


def account_name(ctx: Ctx, account_id: str) -> str:
    row = ctx.conn.execute("SELECT name FROM accounts WHERE id = ?", [account_id]).fetchone()
    return row["name"] if row else account_id


def pay(
    ctx: Ctx, machine: str, price_cents: int, to_account: str, what: str, detail: dict
) -> tuple[dict, int]:
    """Move exactly price_cents into the owner's own account, or refuse with nothing moved."""
    if to_account not in destinations():
        raise ApiError(422, "The money goes to the House Fund or the Brokerage.")
    if price_cents > compute_extra(ctx)["extra_cents"] or price_cents > caps_remaining(ctx):
        raise ApiError(409, dealer.NOT_THIS_WEEK)
    transfer_id = move(
        ctx,
        CHECKING,
        to_account,
        price_cents,
        reason=f"Casino: {what}",
        event={
            "type": f"casino_{machine}",
            "amount_cents": price_cents,
            "to_account": to_account,
            **detail,
        },
    )
    (status,) = ctx.conn.execute(
        "SELECT status FROM transfers WHERE id = ?", [transfer_id]
    ).fetchone()
    if status == "failed":
        # No money landed, so nothing is rolled or granted. Raising rolls the whole
        # request back (the transfer row included), the same as any other refusal.
        raise ApiError(409, dealer.NOT_THIS_WEEK)
    money = {"amount_cents": price_cents, "to_account": to_account, "status": status}
    return money, transfer_id


def dollars(cents: int) -> str:
    return f"${cents // 100}" if cents % 100 == 0 else f"${cents / 100:,.2f}"


# --- Granting -------------------------------------------------------------------------


def grant(ctx: Ctx, item_id: str, machine: str, transfer_id: int | None) -> int:
    """Put the item in the inventory, log it, and tell the game its name and tier."""
    item = catalog.item(item_id)
    assert item is not None, item_id
    inventory_id = grant_item(ctx, item_id, via=f"casino_{machine}")
    for event in reversed(ctx.events):
        if event.get("kind") == "item" and event.get("item_id") == item_id:
            event.update(name=item["name"], tier=item["tier"])
            break
    ctx.conn.execute(
        """INSERT INTO casino_grants
           (machine, tier, item_id, inventory_id, transfer_id, created)
           VALUES (?, ?, ?, ?, ?, ?)""",
        [machine, item["tier"], item_id, inventory_id, transfer_id, ctx.today.isoformat()],
    )
    return inventory_id


# --- The reel -------------------------------------------------------------------------


def _weighted(tiers: list[str]) -> str:
    weights = machines()["reel"]["filler_weights"]
    return loads.RNG.choices(tiers, weights=[weights[t] for t in tiers])[0]


def _stage(tier: str, still: set[str], first_pull: bool) -> tuple[str | None, str | None]:
    """Pick a near-miss, only with a tier that is really still in the loads."""
    nm = machines()["reel"]["near_miss"]
    if tier in ("common", "rare"):
        target = next((t for t in ("legendary", "epic") if t in still), None)
        if target is None:
            return None, None
        if first_pull:
            return "short", target
        roll, edge = loads.RNG.random(), 0.0
        for kind in ("fell", "short", "tease"):
            edge += nm["low"][kind]
            if roll < edge:
                return kind, target
        return None, None
    rule = nm.get(tier)
    if rule and rule["tier"] in still and loads.RNG.random() < rule["chance"]:
        return loads.RNG.choice(["fell", "short"]), rule["tier"]
    return None, None


def build_reel(winner_id: str, before: Counter, first_pull: bool) -> dict:
    """The strip the case reel scrolls, built around the winner.

    `before` is what was in the belt and box when the case was pulled. Filler only uses
    tiers that were in there, the cards in view when the reel stops (quiet_radius either
    side) are the plainest tiers in there, and a staged near-miss only uses a tier still
    in there after this pull, so every near-miss is honest.
    """
    cfg = machines()["reel"]
    size, win, radius = cfg["size"], cfg["winner_index"], cfg["quiet_radius"]
    tier = catalog.item(winner_id)["tier"]
    present = [t for t in TIERS if before.get(t, 0) > 0]
    after = before.copy()
    after[tier] -= 1
    still = {t for t in TIERS if after.get(t, 0) > 0}
    kind, near_tier = _stage(tier, still, first_pull)

    cards: list[str | None] = [None] * size
    cards[win] = tier
    near_index = None
    if kind:
        if kind == "short":
            near_index = win + 1
        elif kind == "fell":
            near_index = win - 1
        else:
            lo, hi = cfg["near_miss"]["tease_before"]
            near_index = win - loads.RNG.randint(lo, hi)
        cards[near_index] = near_tier
    quiet = [t for t in ("common", "rare") if t in present] or present[:1]
    for i in range(size):
        if cards[i] is None:
            cards[i] = _weighted(quiet if abs(i - win) <= radius else present)

    reel = [
        {"item_id": winner_id if i == win else loads.pick_item(t), "tier": t}
        for i, t in enumerate(cards)
    ]
    return {
        "reel": reel,
        "winner_index": win,
        "near_miss": kind,
        "near_miss_tier": near_tier,
        "near_miss_index": near_index,
    }


# --- Paid machines --------------------------------------------------------------------


def open_case(ctx: Ctx, case_id: str, to_account: str) -> dict:
    case = catalog.case(case_id)
    if case is None:
        raise ApiError(422, "There's no case like that on the shelf.")
    price = case["price_cents"]
    money, transfer_id = pay(
        ctx, "case", price, to_account, f"{dollars(price)} case", {"case_id": case_id}
    )
    first_pull = (
        ctx.conn.execute("SELECT COUNT(*) FROM casino_grants WHERE machine = 'case'").fetchone()[0]
        == 0
    )
    before = loads.case_loads(ctx)
    tier, source = loads.fire_case(ctx)
    item_id = loads.pick_item(tier)
    inventory_id = grant(ctx, item_id, "case", transfer_id)
    reel = build_reel(item_id, before, first_pull)
    belt, box = loads.belt_left(ctx), loads.box_public(ctx)
    return {
        "money": money,
        "shell": {"tier": tier, "source": source},
        "item": catalog.item(item_id),
        "inventory_id": inventory_id,
        **reel,
        "belt": {"size": sum(machines()["belt"]["shells"].values()), "left": belt},
        "box": box,
        "dealer": {"name": dealer.NAME, "line": dealer.case_odds(belt, box)},
    }


def scratch_symbols(tier: str, before: dict[str, int], book_tiers: list[str]) -> list[str]:
    """Nine symbols. The prize tier shows three times; every higher tier shows at most twice,
    and only if it's still in the book; lower tiers fill the rest. So the best tier that
    shows three times is always the prize."""
    cells = [tier] * 3
    for t in TIERS:
        if RANK[t] > RANK[tier] and before.get(t, 0) > 0:
            cells += [t] * loads.RNG.randint(0, 2)
    lower = [t for t in book_tiers if RANK[t] < RANK[tier]]
    while len(cells) < 9:
        cells.append(loads.RNG.choice(lower) if lower else tier)
    loads.RNG.shuffle(cells)
    return cells


def scratch(ctx: Ctx, price_cents: int, to_account: str) -> dict:
    book = catalog.book(price_cents)
    if book is None:
        raise ApiError(422, "There's no book at that price.")
    money, transfer_id = pay(
        ctx,
        "scratch",
        price_cents,
        to_account,
        f"{dollars(price_cents)} scratch ticket",
        {"price_cents": price_cents},
    )
    before = loads.book_left(ctx, price_cents)
    tier = loads.draw_ticket(ctx, price_cents)
    item_id = loads.pick_item(tier)
    inventory_id = grant(ctx, item_id, "scratch", transfer_id)
    left = loads.book_left(ctx, price_cents)
    return {
        "money": money,
        "item": catalog.item(item_id),
        "inventory_id": inventory_id,
        "tier": tier,
        "symbols": scratch_symbols(tier, before, [t for t, n in book["book"].items() if n]),
        "book": {"price_cents": price_cents, "size": sum(book["book"].values()), "left": left},
        "dealer": {
            "name": dealer.NAME,
            "line": dealer.counted_line(left, "in the book", "in the book"),
        },
    }


def spin_wheel(ctx: Ctx, to_account: str) -> dict:
    price = machines()["wheel"]["price_cents"]
    money, transfer_id = pay(ctx, "wheel", price, to_account, "the wheel", {})
    wedge_index, tier, reset = loads.spin(ctx)
    item_id = loads.pick_item(tier)
    inventory_id = grant(ctx, item_id, "wheel", transfer_id)
    wedges = wheel_state(ctx)["wedges"]
    return {
        "money": money,
        "wedge_index": wedge_index,
        "tier": tier,
        "item": catalog.item(item_id),
        "inventory_id": inventory_id,
        "reset": reset,
        "wedges": wedges,
        "dealer": {"name": dealer.NAME, "line": _wheel_line(wedges)},
    }


def drop_claw(ctx: Ctx, to_account: str, drop_x: float) -> dict:
    if not 0.0 <= drop_x <= 1.0:
        raise ApiError(422, "drop_x must be 0 to 1.")
    price = machines()["claw"]["price_cents"]
    money, transfer_id = pay(ctx, "claw", price, to_account, "the claw", {"drop_x": drop_x})
    slot_index, tier = loads.grab(ctx, drop_x)
    item_id = loads.pick_item(tier)
    inventory_id = grant(ctx, item_id, "claw", transfer_id)
    pile = loads.heap(ctx)
    return {
        "money": money,
        "grabbed": {"slot_index": slot_index, "tier": tier},
        "item": catalog.item(item_id),
        "inventory_id": inventory_id,
        "heap": pile,
        "dealer": {"name": dealer.NAME, "line": _claw_line(pile)},
    }


# --- Free machines: no money moves -----------------------------------------------------


def trade_up(ctx: Ctx, inventory_ids: list) -> dict:
    """Ten owned items of one tier become one random item of the next tier."""
    try:
        ids = sorted({int(i) for i in inventory_ids})
    except (TypeError, ValueError):
        raise ApiError(422, "inventory_ids must be numbers.") from None
    if len(ids) != 10 or len(inventory_ids) != 10:
        raise ApiError(422, "The hopper takes ten different pieces.")
    rows = ctx.conn.execute(
        f"SELECT id, item_id FROM inventory WHERE id IN ({','.join('?' * len(ids))})", ids
    ).fetchall()
    if len(rows) != 10:
        raise ApiError(409, "Some of those aren't yours.")
    pieces = [catalog.item(r["item_id"]) for r in rows]
    if any(p is None for p in pieces):
        raise ApiError(409, "Only casino pieces go in the hopper.")
    tiers = {p["tier"] for p in pieces}
    if len(tiers) != 1:
        raise ApiError(409, "All ten have to be the same color.")
    (tier,) = tiers
    if tier not in TRADE_UP:
        raise ApiError(409, "Gold and red don't go any higher.")
    ctx.conn.execute(f"DELETE FROM inventory WHERE id IN ({','.join('?' * len(ids))})", ids)
    item_id = loads.pick_item(TRADE_UP[tier])
    inventory_id = grant(ctx, item_id, "tradeup", None)
    sync_equipped(ctx)
    return {"item": catalog.item(item_id), "inventory_id": inventory_id, "consumed": ids}


def owned(ctx: Ctx) -> Counter:
    known = catalog.items_by_id()
    return Counter(
        r["item_id"]
        for r in ctx.conn.execute("SELECT item_id FROM inventory")
        if r["item_id"] in known
    )


def owned_trophies(ctx: Ctx) -> Counter:
    """The other features' cosmetics the owner holds (the book's trophy shelves)."""
    known = catalog.trophies_by_id()
    return Counter(
        r["item_id"]
        for r in ctx.conn.execute("SELECT item_id FROM inventory")
        if r["item_id"] in known
    )


def equipped(ctx: Ctx) -> dict[str, str]:
    return {
        r["slot"]: r["item_id"]
        for r in ctx.conn.execute("SELECT slot, item_id FROM casino_equipped ORDER BY slot")
    }


def sync_equipped(ctx: Ctx) -> None:
    """Drop anything no longer owned, and mirror the slots onto inventory.equipped."""
    have = owned(ctx) + owned_trophies(ctx)
    for slot, item_id in equipped(ctx).items():
        if not have[item_id]:
            ctx.conn.execute("DELETE FROM casino_equipped WHERE slot = ?", [slot])
    ids = [*catalog.items_by_id(), *catalog.trophies_by_id()]
    ctx.conn.execute(
        f"UPDATE inventory SET equipped = 0 WHERE item_id IN ({','.join('?' * len(ids))})", ids
    )
    for item_id in equipped(ctx).values():
        ctx.conn.execute(
            """UPDATE inventory SET equipped = 1
               WHERE id = (SELECT MIN(id) FROM inventory WHERE item_id = ?)""",
            [item_id],
        )


def equip(ctx: Ctx, item_id: str) -> dict:
    piece = catalog.wearable(item_id)
    if piece is None:
        raise ApiError(422, "There's no piece like that.")
    if not (owned(ctx) + owned_trophies(ctx))[item_id]:
        raise ApiError(409, "You don't have that one yet.")
    ctx.conn.execute(
        """INSERT INTO casino_equipped (slot, item_id) VALUES (?, ?)
           ON CONFLICT(slot) DO UPDATE SET item_id = excluded.item_id""",
        [piece["slot"], item_id],
    )
    sync_equipped(ctx)
    return {"equipped": equipped(ctx)}


def unequip(ctx: Ctx, item_id: str) -> dict:
    """Take a worn piece off: its slot goes empty. Taking off what isn't worn changes nothing."""
    piece = catalog.wearable(item_id)
    if piece is None:
        raise ApiError(422, "There's no piece like that.")
    ctx.conn.execute(
        "DELETE FROM casino_equipped WHERE slot = ? AND item_id = ?", [piece["slot"], item_id]
    )
    sync_equipped(ctx)
    return {"equipped": equipped(ctx)}


# --- What the room shows --------------------------------------------------------------


def wheel_state(ctx: Ctx) -> dict:
    return {
        "price_cents": machines()["wheel"]["price_cents"],
        "wedges": [{"tier": w["tier"], "taken": bool(w["taken"])} for w in loads.wheel(ctx)],
    }


def _wheel_line(wedges: list[dict]) -> str:
    left = Counter(w["tier"] for w in wedges if not w["taken"])
    return dealer.counted_line(dict(left), "wedge", "wedges")


def _claw_line(pile: list[dict]) -> str:
    return dealer.counted_line(dict(Counter(p["tier"] for p in pile)), "in the heap", "in the heap")


def cheapest_cents() -> int:
    m = machines()
    prices = [c["price_cents"] for c in m["cases"]]
    prices += [b["price_cents"] for b in m["scratch"]]
    prices += [m["wheel"]["price_cents"], m["claw"]["price_cents"]]
    return min(prices)


def room_state(ctx: Ctx) -> dict:
    """The casino section of GET /state (without the weekly draw, added by the caller)."""
    m = machines()
    can = can_spend_cents(ctx)
    current = balances(ctx)
    dests = [
        {"id": a, "name": account_name(ctx, a), "balance_cents": current.get(a, 0)}
        for a in destinations()
    ]
    belt = loads.belt_left(ctx)
    box = loads.box_public(ctx)
    books = [
        {
            "price_cents": b["price_cents"],
            "size": sum(b["book"].values()),
            "left": loads.book_left(ctx, b["price_cents"]),
        }
        for b in m["scratch"]
    ]
    wheel = wheel_state(ctx)
    pile = loads.heap(ctx)
    have = owned(ctx)
    known = catalog.items_by_id()
    inventory = [
        {"inventory_id": r["id"], "item_id": r["item_id"]}
        for r in ctx.conn.execute("SELECT id, item_id FROM inventory ORDER BY id")
        if r["item_id"] in known
    ]

    case_odds = dealer.case_odds(belt, box)
    before: dict = {"case": {}, "scratch": {}, "wheel": {}, "claw": {}}
    wheel_line, claw_line = _wheel_line(wheel["wedges"]), _claw_line(pile)
    for d in dests:
        for c in m["cases"]:
            before["case"].setdefault(c["id"], {})[d["id"]] = (
                f"{dealer.money_line(c['price_cents'], d['name'])} {case_odds}"
            )
        for b in books:
            odds = dealer.counted_line(b["left"], "in the book", "in the book")
            before["scratch"].setdefault(str(b["price_cents"]), {})[d["id"]] = (
                f"{dealer.money_line(b['price_cents'], d['name'])} {odds}"
            )
        before["wheel"][d["id"]] = (
            f"{dealer.money_line(wheel['price_cents'], d['name'])} {wheel_line}"
        )
        before["claw"][d["id"]] = (
            f"{dealer.money_line(m['claw']['price_cents'], d['name'])} {claw_line}"
        )
    line = dealer.now_line(can, cheapest_cents(), belt, box)

    return {
        "can_spend_cents": can,
        "destinations": dests,
        "cases": [
            {"id": c["id"], "price_cents": c["price_cents"], "affordable": c["price_cents"] <= can}
            for c in m["cases"]
        ],
        "belt": {"size": sum(m["belt"]["shells"].values()), "left": belt},
        "box": box,
        "scratch": books,
        "wheel": wheel,
        "claw": {"price_cents": m["claw"]["price_cents"], "heap": pile},
        "owned": dict(sorted(have.items())),
        "trophies": dict(sorted(owned_trophies(ctx).items())),
        "inventory": inventory,
        "equipped": equipped(ctx),
        "dealer": {"name": dealer.NAME, "line": line, "before": before},
    }
