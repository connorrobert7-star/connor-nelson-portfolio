"""The machines: cases, scratch books, the wheel, the claw, the trade-up hopper, and the
collection book's equip.

Every paid pull goes the same way, in one request:
  1. check the price against the week's extra and the transfer caps ("Not this week."),
  2. move() the exact price from checking into the owner's House Fund or Brokerage,
  3. only then take the next shell, ticket, wedge or heap piece and grant a cosmetic.
If the transfer comes back 'failed', the pull is refused ("Not this week.") before step 3.
Money is never random. The price lands in full every time; only the cosmetic varies.

The scratch books, the wheel and the claw are pot machines (docs/POT.md): they pay into the
Brokerage only, refuse without a pick at Marlo's counter, and step a run of lamps. A blank
grants nothing and leaves the cosmetic loads alone; its price waits in the pot. A hit buys
the pick with the pot plus its own price, then grants a cosmetic from the machine's load.
"""

from collections import Counter

from backend.core.context import Ctx
from backend.core.router import ApiError
from backend.core.services import grant_item
from backend.features.casino import catalog, dealer, loads, pot
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


DUD = "dud"


def blank_symbols(left: dict[str, int]) -> list[str]:
    """A blank ticket: nine symbols with no tier three times. Only tiers still in the book
    show (once or twice each), so nothing teases a tier that's gone; duds fill the rest."""
    cells: list[str] = []
    for t in TIERS:
        if left.get(t, 0) > 0:
            cells += [t] * loads.RNG.randint(1, 2)
    cells = cells[:9] + [DUD] * max(0, 9 - len(cells))
    loads.RNG.shuffle(cells)
    return cells


def _pot_line(pot_out: dict, run: dict) -> str:
    """What Vex says after a pot pull: the buy on a hit, the run and the pot on a blank."""
    bought = pot_out.get("bought")
    head = dealer.bought_line(bought["amount_cents"], bought["symbol"]) if bought else ""
    tail = "" if bought else dealer.pot_line(pot_out["total_cents"])
    return " ".join(p for p in (head, dealer.run_line(run["left"]), tail) if p)


def _pot_pull(
    ctx: Ctx,
    key: str,
    machine: str,
    price_cents: int,
    to_account: str | None,
    what: str,
    detail: dict,
) -> tuple[dict, int, dict]:
    """A pot machine's money, in order: the refusals (account, pick), then move() the exact
    price into the Brokerage, then the next lamp. On a hit the pot buys the pick; on a blank
    the price waits in the pot. Returns (money, transfer_id, pot)."""
    symbol = pot.check(ctx, to_account)
    money, transfer_id = pay(ctx, machine, price_cents, pot.account(), what, detail)
    if pot.next_lamp(ctx, key):
        return money, transfer_id, pot.buy(ctx, key, symbol, price_cents, transfer_id)
    return money, transfer_id, pot.add_blank(ctx, price_cents)


def scratch(ctx: Ctx, price_cents: int, to_account: str | None = None) -> dict:
    book = catalog.book(price_cents)
    if book is None:
        raise ApiError(422, "There's no book at that price.")
    key = pot.scratch_key(price_cents)
    money, transfer_id, pot_out = _pot_pull(
        ctx,
        key,
        "scratch",
        price_cents,
        to_account,
        f"{dollars(price_cents)} scratch ticket",
        {"price_cents": price_cents},
    )
    hit = "bought" in pot_out
    out: dict = {"money": money, "hit": hit, "item": None, "tier": None, "inventory_id": None}
    if hit:
        before = loads.book_left(ctx, price_cents)
        tier = loads.draw_ticket(ctx, price_cents)
        item_id = loads.pick_item(tier)
        out.update(
            item=catalog.item(item_id),
            inventory_id=grant(ctx, item_id, "scratch", transfer_id),
            tier=tier,
            symbols=scratch_symbols(tier, before, [t for t, n in book["book"].items() if n]),
        )
    else:
        out["symbols"] = blank_symbols(loads.book_left(ctx, price_cents))
    left = loads.book_left(ctx, price_cents)
    run = pot.run_public(ctx, key)
    return {
        **out,
        "run": run,
        "pot": pot_out,
        "book": {"price_cents": price_cents, "size": sum(book["book"].values()), "left": left},
        "dealer": {"name": dealer.NAME, "line": _pot_line(pot_out, run)},
    }


def spin_wheel(ctx: Ctx, to_account: str | None = None) -> dict:
    cfg = machines()["wheel"]
    money, transfer_id, pot_out = _pot_pull(
        ctx, "wheel", "wheel", cfg["price_cents"], to_account, "the wheel", {}
    )
    hit = "bought" in pot_out
    out: dict = {
        "money": money,
        "hit": hit,
        "wedge_index": None,
        "dud_index": None,
        "tier": None,
        "item": None,
        "inventory_id": None,
        "reset": False,
    }
    if hit:
        wedge_index, tier, reset = loads.spin(ctx)
        item_id = loads.pick_item(tier)
        out.update(
            wedge_index=wedge_index,
            tier=tier,
            item=catalog.item(item_id),
            inventory_id=grant(ctx, item_id, "wheel", transfer_id),
            reset=reset,
        )
    else:
        # A dud sliver between two wedges. Which one is cosmetic; the blank was the run's.
        out["dud_index"] = loads.RNG.randrange(cfg["dud_slivers"])
    wedges = wheel_state(ctx)["wedges"]
    run = pot.run_public(ctx, "wheel")
    return {
        **out,
        "wedges": wedges,
        "run": run,
        "pot": pot_out,
        "dealer": {"name": dealer.NAME, "line": _pot_line(pot_out, run)},
    }


def drop_claw(ctx: Ctx, drop_x: float, to_account: str | None = None) -> dict:
    if not 0.0 <= drop_x <= 1.0:
        raise ApiError(422, "drop_x must be 0 to 1.")
    price = machines()["claw"]["price_cents"]
    money, transfer_id, pot_out = _pot_pull(
        ctx, "claw", "claw", price, to_account, "the claw", {"drop_x": drop_x}
    )
    hit = "bought" in pot_out
    out: dict = {"money": money, "hit": hit, "item": None, "inventory_id": None}
    if hit:
        slot_index, tier = loads.grab(ctx, drop_x)
        item_id = loads.pick_item(tier)
        out.update(
            item=catalog.item(item_id),
            inventory_id=grant(ctx, item_id, "claw", transfer_id),
        )
    else:
        slot_index, tier = loads.touch(ctx, drop_x)
    run = pot.run_public(ctx, "claw")
    return {
        **out,
        "grabbed": {"slot_index": slot_index, "tier": tier, "held": hit},
        "heap": loads.heap(ctx),
        "run": run,
        "pot": pot_out,
        "dealer": {"name": dealer.NAME, "line": _pot_line(pot_out, run)},
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
    for d in dests:
        for c in m["cases"]:
            before["case"].setdefault(c["id"], {})[d["id"]] = (
                f"{dealer.money_line(c['price_cents'], d['name'])} {case_odds}"
            )
    # The pot machines pay into the Brokerage only; he names the run and the pot.
    pot_now = pot.pot_state(ctx)
    runs = pot.runs_state(ctx)
    brk = pot.account()
    brk_name = account_name(ctx, brk)

    def pot_said(key: str, price: int) -> str:
        money = dealer.money_line(price, brk_name)
        return dealer.pot_before(
            money, runs[key]["left"], pot_now["total_cents"], pot_now["pick"] is not None
        )

    for b in books:
        key = pot.scratch_key(b["price_cents"])
        before["scratch"][str(b["price_cents"])] = {brk: pot_said(key, b["price_cents"])}
    before["wheel"] = {brk: pot_said("wheel", wheel["price_cents"])}
    before["claw"] = {brk: pot_said("claw", m["claw"]["price_cents"])}
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
        "pot": pot_now,
        "runs": runs,
        "owned": dict(sorted(have.items())),
        "trophies": dict(sorted(owned_trophies(ctx).items())),
        "inventory": inventory,
        "equipped": equipped(ctx),
        "dealer": {"name": dealer.NAME, "line": line, "before": before},
    }
