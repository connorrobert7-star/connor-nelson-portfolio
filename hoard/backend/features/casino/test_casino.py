import json
import random
import struct
from collections import Counter
from datetime import date, timedelta
from pathlib import Path

import pytest

import backend.money.transfer as transfer
from backend.core.router import ROUTES, ApiError
from backend.core.services import coin_balance, grant_item
from backend.features.casino import catalog, dealer, draw, loads, machines
from backend.features.casino.catalog import RANK, SLOTS, TARGET_PCT, TIERS
from backend.money.budget import balances

GAME = Path(__file__).resolve().parents[3] / "game"
OWN = ("chk_1", "sav_1", "brk_1")
CASINO_TABLES = (
    "casino_belt",
    "casino_box",
    "casino_books",
    "casino_wheel",
    "casino_claw_heap",
    "casino_draw",
    "casino_equipped",
    "casino_grants",
)
WATCHED = (*CASINO_TABLES, "transfers", "events", "inventory", "coin_ledger", "notifications")

# Every paid machine: route, body (without to_account), exact price.
PAID = {
    "case_10": ("/casino/case", {"case_id": "case_10"}, 1_000),
    "case_20": ("/casino/case", {"case_id": "case_20"}, 2_000),
    "case_50": ("/casino/case", {"case_id": "case_50"}, 5_000),
    "scratch_1": ("/casino/scratch", {"price_cents": 100}, 100),
    "scratch_2": ("/casino/scratch", {"price_cents": 200}, 200),
    "scratch_5": ("/casino/scratch", {"price_cents": 500}, 500),
    "wheel": ("/casino/wheel", {}, 500),
    "claw": ("/casino/claw", {"drop_x": 0.5}, 500),
}


@pytest.fixture(autouse=True)
def seeded():
    loads.seed(20261020)
    yield
    loads.seed(None)


@pytest.fixture
def unlimited(monkeypatch):
    """Lift extra and the caps so a test can pull thousands of times."""
    monkeypatch.setattr(transfer, "PER_DAY_CAP_CENTS", 10**12)
    monkeypatch.setattr(transfer, "PER_WEEK_CAP_CENTS", 10**12)
    monkeypatch.setattr(machines, "compute_extra", lambda ctx: {"extra_cents": 10**12})


def snapshot(conn) -> dict:
    return {t: [tuple(r) for r in conn.execute(f"SELECT * FROM {t} ORDER BY 1")] for t in WATCHED}


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        head = f.read(24)
    assert head[:8] == b"\x89PNG\r\n\x1a\n", path
    return struct.unpack(">II", head[16:24])


# --- Content --------------------------------------------------------------------------


def test_catalog_has_sixty_cosmetics_in_two_sets_and_five_tiers():
    items = catalog.items()
    assert len(items) >= 60
    assert len({i["id"] for i in items}) == len(items)
    set_ids = {s["id"] for s in catalog.sets()}
    assert len(set_ids) == 2
    for s in set_ids:
        assert {i["tier"] for i in items if i["set"] == s} == set(TIERS)
    for i in items:
        assert set(i) == {"id", "name", "tier", "set", "slot", "icon"}
        assert i["tier"] in TIERS and i["set"] in set_ids and i["slot"] in SLOTS
        assert "!" not in i["name"] and "$" not in i["name"]
    assert {i["slot"] for i in items} == set(SLOTS)


def test_every_icon_is_a_real_cell_of_a_pack_sheet():
    for i in catalog.items():
        sheet = i["icon"]["sheet"]
        assert sheet.startswith("res://art/packs/"), sheet
        path = GAME / sheet.removeprefix("res://")
        assert path.is_file(), sheet
        x, y, w, h = i["icon"]["rect"]
        width, height = png_size(path)
        assert w > 0 and h > 0 and x + w <= width and y + h <= height, (i["id"], width, height)


def test_catalog_route(client):
    body = client.get("/casino/catalog").json()
    assert len(body["items"]) >= 60
    assert [t["id"] for t in body["tiers"]] == list(TIERS)
    assert body["tiers"][4]["color"] == "#ff2e3a"
    assert len(body["sets"]) == 2
    assert [s["id"] for s in body["trophies"]] == ["gate", "minigames", "followers"]


def test_trophy_shelves_are_the_other_catalogs():
    shelves = catalog.trophy_shelves()
    assert [s["name"] for s in shelves] == ["Trophies of the Gate", "The Undercroft", "The Flock"]
    casino_ids = set(catalog.items_by_id())
    for shelf in shelves:
        raw = json.loads((GAME.parent / "content" / shelf["id"] / "items.json").read_text())
        assert [i["id"] for i in shelf["items"]] == [i["id"] for i in raw["items"]]
        for i in shelf["items"]:
            assert set(i) == {*catalog.SHAPE, "shelf"} and i["shelf"] == shelf["id"]
            assert i["id"] not in casino_ids
            assert i["tier"] in TIERS and i["slot"] in SLOTS, i["id"]
            sheet = GAME / i["icon"]["sheet"].removeprefix("res://")
            x, y, w, h = i["icon"]["rect"]
            width, height = png_size(sheet)
            assert w > 0 and h > 0 and x + w <= width and y + h <= height, i["id"]
    assert catalog.wearable("gate_maw_mask")["shelf"] == "gate"
    assert catalog.wearable("hollow_ash_cowl")["set"] == "hollow_choir"
    assert catalog.wearable("nope") is None


def test_machines_are_the_contract():
    m = catalog.machines()
    assert [c["price_cents"] for c in m["cases"]] == [1_000, 2_000, 5_000]
    assert m["belt"]["shells"] == {"common": 18, "rare": 6, "epic": 1}
    assert m["box"] == {"size": 100, "specials": 2, "mythic_one_in": 4}
    assert {b["price_cents"]: b["book"] for b in m["scratch"]} == {
        100: {"common": 16, "rare": 4},
        200: {"common": 14, "rare": 5, "epic": 1},
        500: {"common": 12, "rare": 5, "epic": 2, "legendary": 1},
    }
    assert Counter(m["wheel"]["wedges"]) == {"common": 7, "rare": 3, "epic": 1, "legendary": 1}
    assert m["claw"]["heap"] == {"common": 10, "rare": 4, "epic": 1}
    assert len(m["claw"]["spots"]) == 15
    assert set(m["destinations"]) == {"sav_1", "brk_1"}
    # Nothing but cases ever pays out mythic.
    for b in m["scratch"]:
        assert "mythic" not in b["book"]
    assert "mythic" not in m["wheel"]["wedges"] and "mythic" not in m["claw"]["heap"]
    assert "mythic" not in m["draw"]["prizes"]


# --- The odds -------------------------------------------------------------------------


def test_100k_cases_hit_the_target_rates_and_the_pity_always_holds(ctx):
    n = 100_000
    counts: Counter = Counter()
    last_epic = last_gold = -1
    worst_epic = worst_gold = 0
    for i in range(n):
        tier, source = loads.fire_case(ctx)
        counts[tier] += 1
        assert source == ("box" if tier in ("legendary", "mythic") else "belt")
        if RANK[tier] >= RANK["epic"]:
            worst_epic, last_epic = max(worst_epic, i - last_epic), i
        if RANK[tier] >= RANK["legendary"]:
            worst_gold, last_gold = max(worst_gold, i - last_gold), i
    worst_epic = max(worst_epic, n - 1 - last_epic)  # the open stretch at the end
    worst_gold = max(worst_gold, n - 1 - last_gold)
    pct = {t: 100 * counts[t] / n for t in TIERS}
    tolerance = {"common": 1.0, "rare": 0.8, "epic": 0.4, "legendary": 0.3, "mythic": 0.2}
    for t in TIERS:
        assert abs(pct[t] - TARGET_PCT[t]) <= tolerance[t], (t, pct)
    assert worst_epic <= 25, worst_epic
    assert worst_gold <= 100, worst_gold


def test_the_counts_and_the_gold_tell_are_always_true(ctx):
    for _ in range(400):
        left = loads.belt_left(ctx)
        box = loads.box_public(ctx)
        assert sum(left.values()) >= 1 and left["epic"] == 1
        assert 1 <= len(box["specials"]) <= 2
        tier, source = loads.fire_case(ctx)
        if box["next_is_special"]:
            assert (tier, source) == (box["next_tier"], "box")
        else:
            assert source == "belt" and left[tier] > 0


def test_the_belt_and_box_wait_across_days(engine):
    engine.handle("POST", "/casino/case", body={"case_id": "case_10", "to_account": "sav_1"})
    before = engine.handle("GET", "/state")[1]["casino"]
    engine.handle("POST", "/clock/advance", body={"days": 3})
    after = engine.handle("GET", "/state")[1]["casino"]
    assert after["belt"] == before["belt"] and after["box"] == before["box"]
    assert before["box"]["used"] == 1


def test_production_uses_the_secure_source():
    loads.seed(None)
    assert isinstance(loads.RNG, random.SystemRandom)
    loads.seed(5)
    assert type(loads.RNG) is random.Random


# --- Money, every machine -------------------------------------------------------------


@pytest.mark.parametrize("to_account", ["sav_1", "brk_1"])
@pytest.mark.parametrize("machine", list(PAID))
def test_every_machine_moves_the_exact_price_into_an_own_account(engine, machine, to_account):
    path, body, price = PAID[machine]
    engine.handle("GET", "/state")
    with engine.conn:
        ctx = engine.ctx()
        before, coins = balances(ctx), coin_balance(ctx)
    n_transfers = engine.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0]
    n_inventory = engine.conn.execute("SELECT COUNT(*) FROM inventory").fetchone()[0]

    status, out = engine.handle("POST", path, body={**body, "to_account": to_account})

    assert status == 200, out
    assert out["money"] == {"amount_cents": price, "to_account": to_account, "status": "simulated"}
    kinds = [e["kind"] for e in out["_events"]]
    assert kinds == ["money_moved", "item"]
    item_event = out["_events"][1]
    assert item_event["item_id"] == out["item"]["id"]
    assert item_event["name"] == out["item"]["name"] and item_event["tier"] == out["item"]["tier"]

    rows = engine.conn.execute("SELECT * FROM transfers ORDER BY id").fetchall()
    assert len(rows) == n_transfers + 1
    t = rows[-1]
    assert (t["from_account"], t["to_account"], t["amount_cents"]) == ("chk_1", to_account, price)
    event_type = engine.conn.execute(
        "SELECT type FROM events WHERE id = ?", [t["event_id"]]
    ).fetchone()[0]
    assert event_type == f"casino_{path.rsplit('/', 1)[1]}"
    grant = engine.conn.execute("SELECT * FROM casino_grants ORDER BY id DESC").fetchone()
    assert grant["transfer_id"] == t["id"] and grant["item_id"] == out["item"]["id"]
    assert engine.conn.execute("SELECT COUNT(*) FROM inventory").fetchone()[0] == n_inventory + 1

    with engine.conn:
        ctx = engine.ctx()
        after, coins_after = balances(ctx), coin_balance(ctx)
    assert after[to_account] == before[to_account] + price
    assert after["chk_1"] == before["chk_1"] - price
    assert sum(after[a] for a in OWN) == sum(before[a] for a in OWN)
    for acct in before:
        if acct != "chk_1":
            assert after[acct] >= before[acct], acct
    assert coins_after == coins
    assert engine.conn.execute("SELECT COUNT(*) FROM coin_ledger").fetchone()[0] == 0


@pytest.mark.parametrize("machine", list(PAID))
def test_not_this_week_when_extra_falls_short(engine, machine):
    path, body, _ = PAID[machine]
    engine.handle("GET", "/state")
    with engine.conn:
        engine.conn.execute("UPDATE accounts SET balance_cents = 0 WHERE kind = 'checking'")
    before = snapshot(engine.conn)
    status, out = engine.handle("POST", path, body={**body, "to_account": "sav_1"})
    assert (status, out) == (409, {"detail": "Not this week."})
    assert snapshot(engine.conn) == before
    casino = engine.handle("GET", "/state")[1]["casino"]
    assert casino["can_spend_cents"] == 0
    assert casino["dealer"]["line"] == "Not this week."
    assert not any(c["affordable"] for c in casino["cases"])


@pytest.mark.parametrize("machine", list(PAID))
def test_not_this_week_when_the_caps_fall_short(engine, machine):
    path, body, price = PAID[machine]
    # Fill today's cap at the shop, leaving less than any machine costs.
    status, _ = engine.handle(
        "POST",
        "/shop/stock",
        body={"symbol": "VTI", "amount_cents": transfer.PER_DAY_CAP_CENTS - 50},
    )
    assert status == 200
    engine.handle("GET", "/state")
    before = snapshot(engine.conn)
    status, out = engine.handle("POST", path, body={**body, "to_account": "brk_1"})
    assert (status, out) == (409, {"detail": "Not this week."})
    assert snapshot(engine.conn) == before


def test_bad_destination_or_machine_moves_nothing(engine):
    engine.handle("GET", "/state")
    before = snapshot(engine.conn)
    for path, body in [
        ("/casino/case", {"case_id": "case_20", "to_account": "chk_1"}),
        ("/casino/case", {"case_id": "case_20", "to_account": "debt_card"}),
        ("/casino/case", {"case_id": "case_99", "to_account": "sav_1"}),
        ("/casino/scratch", {"price_cents": 300, "to_account": "sav_1"}),
        ("/casino/claw", {"drop_x": 1.5, "to_account": "sav_1"}),
        ("/casino/wheel", {}),
    ]:
        status, _ = engine.handle("POST", path, body=body)
        assert status == 422, (path, body)
    assert snapshot(engine.conn) == before


def test_the_money_moves_before_anything_is_rolled(ctx, monkeypatch):
    machines.room_state(ctx)  # load every machine
    before = snapshot(ctx.conn)

    def refuse(*args):
        raise transfer.TransferRefused("The bank said no.")

    monkeypatch.setattr(ctx.providers.transfers, "submit", refuse)
    for call in (
        lambda: machines.open_case(ctx, "case_10", "sav_1"),
        lambda: machines.scratch(ctx, 100, "sav_1"),
        lambda: machines.spin_wheel(ctx, "sav_1"),
        lambda: machines.drop_claw(ctx, "sav_1", 0.3),
    ):
        with pytest.raises(transfer.TransferRefused):
            call()
        assert snapshot(ctx.conn) == before


def _fail_transfers(monkeypatch, providers) -> None:
    monkeypatch.setattr(providers.transfers, "submit", lambda *args: {"status": "failed"})


@pytest.mark.parametrize("machine", list(PAID))
def test_a_failed_transfer_grants_nothing_and_rolls_nothing(engine, machine, monkeypatch):
    path, body, _ = PAID[machine]
    engine.handle("GET", "/state")  # load every machine
    before = snapshot(engine.conn)
    _fail_transfers(monkeypatch, engine.providers)
    for _ in range(3):  # failed pulls are never free pulls
        status, out = engine.handle("POST", path, body={**body, "to_account": "sav_1"})
        assert (status, out) == (409, {"detail": "Not this week."})
        assert snapshot(engine.conn) == before


def test_a_failed_transfer_stops_before_any_load_is_touched(ctx, monkeypatch):
    """Even without the request rollback, nothing is fired, drawn, spun, grabbed or granted."""
    machines.room_state(ctx)  # load every machine
    loaded = ("inventory", *CASINO_TABLES)
    before = {t: v for t, v in snapshot(ctx.conn).items() if t in loaded}
    _fail_transfers(monkeypatch, ctx.providers)
    for call in (
        lambda: machines.open_case(ctx, "case_10", "sav_1"),
        lambda: machines.scratch(ctx, 100, "sav_1"),
        lambda: machines.spin_wheel(ctx, "sav_1"),
        lambda: machines.drop_claw(ctx, "sav_1", 0.3),
    ):
        with pytest.raises(ApiError) as refused:
            call()
        assert (refused.value.status, refused.value.message) == (409, "Not this week.")
        assert {t: v for t, v in snapshot(ctx.conn).items() if t in loaded} == before
        assert not [e for e in ctx.events if e.get("kind") == "item"]


FREE_ROUTES = {("GET", "/casino/catalog"), ("POST", "/casino/tradeup"), ("POST", "/casino/equip")}


def test_no_route_moves_money_without_a_logged_grant_or_lowers_a_balance(engine):
    casino_routes = {k for k in ROUTES if k[1].startswith("/casino/")}
    paid_routes = {("POST", p) for p, _, _ in PAID.values()}
    assert casino_routes == paid_routes | FREE_ROUTES, "add new casino routes to this test"

    # Something to trade up and equip, granted the plain way (no money).
    with engine.conn:
        ctx = engine.ctx()
        commons = [grant_item(ctx, "hollow_ash_cowl", via="test") for _ in range(11)]
    calls = [(p, {**b, "to_account": "sav_1"}) for p, b, _ in PAID.values()]
    calls += [
        ("/casino/catalog", None),
        ("/casino/tradeup", {"inventory_ids": commons[:10]}),
        ("/casino/equip", {"item_id": "hollow_ash_cowl"}),
    ]
    for path, body in calls:
        method = "GET" if body is None else "POST"
        engine.handle("GET", "/state")
        with engine.conn:
            ctx = engine.ctx()
            before = balances(ctx)
            coins = coin_balance(ctx)
        n_t = engine.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0]
        status, out = engine.handle(method, path, body=body)
        assert status == 200, (path, out)
        new_transfers = engine.conn.execute(
            "SELECT id, amount_cents FROM transfers WHERE id > ?", [n_t]
        ).fetchall()
        for t in new_transfers:
            linked = engine.conn.execute(
                "SELECT inventory_id FROM casino_grants WHERE transfer_id = ?", [t["id"]]
            ).fetchall()
            assert len(linked) == 1, path
            assert engine.conn.execute(
                "SELECT 1 FROM inventory WHERE id = ?", [linked[0]["inventory_id"]]
            ).fetchone()
        if (method, path) in FREE_ROUTES:
            assert not new_transfers, path
        else:
            assert len(new_transfers) == 1, path
        with engine.conn:
            ctx = engine.ctx()
            after = balances(ctx)
            assert coin_balance(ctx) == coins
        moved = sum(t["amount_cents"] for t in new_transfers)
        assert sum(after[a] for a in OWN) == sum(before[a] for a in OWN)
        assert after["chk_1"] == before["chk_1"] - moved
        for acct in before:
            if acct != "chk_1":
                assert after[acct] >= before[acct], (path, acct)


# --- The reel -------------------------------------------------------------------------


def test_the_reel_only_shows_tiers_still_in_the_loads(ctx, unlimited):
    radius = catalog.machines()["reel"]["quiet_radius"]
    staged_kinds: Counter = Counter()
    for pull in range(1_500):
        before = loads.case_loads(ctx)
        public = loads.belt_left(ctx), loads.box_public(ctx)
        assert before == Counter(public[0]) + Counter(public[1]["specials"])
        out = machines.open_case(ctx, "case_10", "sav_1")
        reel, win, tier = out["reel"], out["winner_index"], out["shell"]["tier"]
        assert len(reel) == 45 and win == 38
        assert reel[win] == {"item_id": out["item"]["id"], "tier": tier}
        present = {t for t, n in before.items() if n > 0}
        still = before.copy()
        still[tier] -= 1
        for i, card in enumerate(reel):
            assert card["tier"] in present, (pull, i, card, before)
            assert catalog.item(card["item_id"])["tier"] == card["tier"]
        kind, near_tier, near_i = out["near_miss"], out["near_miss_tier"], out["near_miss_index"]
        staged_kinds[kind] += 1
        if kind:
            assert still[near_tier] > 0, (pull, near_tier, before, tier)
            assert RANK[near_tier] > RANK[tier] and tier != "mythic"
            assert reel[near_i]["tier"] == near_tier
            offset = near_i - win
            assert {"short": offset == 1, "fell": offset == -1, "tease": -4 <= offset <= -2}[kind]
        else:
            assert near_tier is None and near_i is None
        quiet = {t for t in ("common", "rare") if t in present} or {min(present, key=RANK.get)}
        for i in range(win - radius, win + radius + 1):
            if i not in (win, near_i):
                assert reel[i]["tier"] in quiet, (pull, i, reel[i])
        if pull == 0 and tier in ("common", "rare"):
            assert kind == "short"
    assert staged_kinds["short"] and staged_kinds["fell"] and staged_kinds["tease"]
    assert staged_kinds[None] > 500


def test_the_reel_never_teases_a_tier_that_is_gone():
    # The belt's last shell is the epic; the box holds one red. No grey, blue or gold left.
    for _ in range(300):
        out = machines.build_reel("ember_bonfire", Counter({"epic": 1, "mythic": 1}), False)
        assert {c["tier"] for c in out["reel"]} <= {"epic", "mythic"}
        assert out["near_miss_tier"] is None
        out = machines.build_reel("ember_ginger", Counter({"common": 9, "mythic": 1}), True)
        assert {c["tier"] for c in out["reel"]} <= {"common", "mythic"}
        assert out["near_miss"] is None


# --- Scratch, wheel, claw -------------------------------------------------------------


@pytest.mark.parametrize("price", [100, 200, 500])
def test_a_scratch_book_pays_exactly_its_stated_contents(ctx, price):
    stated = catalog.book(price)["book"]
    got: Counter = Counter()
    for n in range(20):
        left = loads.book_left(ctx, price)
        assert sum(left.values()) == 20 - n
        out = machines.scratch(ctx, price, "sav_1")
        tier, symbols = out["tier"], out["symbols"]
        got[tier] += 1
        assert out["item"]["tier"] == tier
        assert len(symbols) == 9 and set(symbols) <= set(stated)
        shown = Counter(symbols)
        assert max((t for t in shown if shown[t] >= 3), key=RANK.get) == tier
        for t in shown:
            if RANK[t] > RANK[tier]:
                assert shown[t] <= 2 and left[t] > 0
    assert got == Counter(stated)
    assert loads.book_left(ctx, price) == stated  # a fresh book


def test_the_wheel_takes_wedges_off_until_it_resets(ctx):
    wedges = catalog.machines()["wheel"]["wedges"]
    for _ in range(3):
        taken = set()
        while True:
            out = machines.spin_wheel(ctx, "brk_1")
            i = out["wedge_index"]
            assert i not in taken and out["tier"] == wedges[i] == out["item"]["tier"]
            taken.add(i)
            if out["reset"]:
                assert out["tier"] == "legendary" or len(taken) == 12
                assert not any(w["taken"] for w in out["wedges"])
                break
            assert out["tier"] != "legendary"
            assert {j for j, w in enumerate(out["wedges"]) if w["taken"]} == taken


def test_the_claw_grabs_near_the_drop_and_empties_the_heap(ctx):
    got: Counter = Counter()
    for n in range(15):
        pile = loads.heap(ctx)
        assert len(pile) == 15 - n
        drop = pile[n % len(pile)]["x"]
        out = machines.drop_claw(ctx, "sav_1", drop)
        grabbed = next(p for p in pile if p["slot_index"] == out["grabbed"]["slot_index"])
        assert grabbed["tier"] == out["grabbed"]["tier"] == out["item"]["tier"]
        assert abs(grabbed["x"] - drop) <= 2 * catalog.machines()["claw"]["wobble"] + 1e-9
        got[grabbed["tier"]] += 1
    assert got == Counter(catalog.machines()["claw"]["heap"])
    assert len(loads.heap(ctx)) == 15


# --- Trade-ups and the book -------------------------------------------------------------


def _give(ctx, item_id: str, n: int) -> list[int]:
    return [grant_item(ctx, item_id, via="test") for _ in range(n)]


def test_ten_of_a_tier_trade_up_to_one_of_the_next(ctx):
    for tier, nxt in (("common", "rare"), ("rare", "epic"), ("epic", "legendary")):
        ids = _give(ctx, catalog.ids_of_tier(tier)[0], 6) + _give(
            ctx, catalog.ids_of_tier(tier)[1], 4
        )
        n_before = ctx.conn.execute("SELECT COUNT(*) FROM inventory").fetchone()[0]
        out = machines.trade_up(ctx, ids)
        assert out["item"]["tier"] == nxt
        assert ctx.conn.execute("SELECT COUNT(*) FROM inventory").fetchone()[0] == n_before - 9
        assert not ctx.conn.execute(
            f"SELECT 1 FROM inventory WHERE id IN ({','.join('?' * 10)})", ids
        ).fetchone()
    assert ctx.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0] == 0
    assert coin_balance(ctx) == 0


def test_trade_up_refusals(ctx):
    legendary = _give(ctx, catalog.ids_of_tier("legendary")[0], 10)
    mythic = _give(ctx, catalog.ids_of_tier("mythic")[0], 10)
    commons = _give(ctx, catalog.ids_of_tier("common")[0], 9)
    rare = _give(ctx, catalog.ids_of_tier("rare")[0], 1)
    stranger = _give(ctx, "not_a_casino_piece", 1)
    for ids, status in [
        (legendary, 409),  # gold can't trade up: red only comes from the box
        (mythic, 409),
        (commons + rare, 409),  # mixed colors
        (commons, 422),  # nine
        (commons + commons[:1], 422),  # the same piece twice
        (commons + [999_999], 409),  # not yours
        (commons + stranger, 409),  # not a casino piece
        (["a"] * 10, 422),
    ]:
        with pytest.raises(ApiError) as err:
            machines.trade_up(ctx, ids)
        assert err.value.status == status, ids
        assert "!" not in err.value.message
    assert ctx.conn.execute("SELECT COUNT(*) FROM inventory").fetchone()[0] == 31
    assert not catalog.TRADE_UP.get("legendary")
    assert "mythic" not in catalog.TRADE_UP.values()


def test_equip_from_the_book(client):
    assert client.post("/casino/equip", json={"item_id": "hollow_crown"}).status_code == 409
    assert client.post("/casino/equip", json={"item_id": "nope"}).status_code == 422
    r = client.post("/casino/case", json={"case_id": "case_10", "to_account": "sav_1"}).json()
    item = r["item"]
    out = client.post("/casino/equip", json={"item_id": item["id"]}).json()
    assert out == {"equipped": {item["slot"]: item["id"]}}
    casino = client.get("/state").json()["casino"]
    assert casino["equipped"] == {item["slot"]: item["id"]}
    assert casino["owned"] == {item["id"]: 1}
    assert casino["inventory"] == [{"inventory_id": r["inventory_id"], "item_id": item["id"]}]


def test_equip_replaces_the_slot_and_trading_away_unequips(ctx):
    hats = [i["id"] for i in catalog.items() if i["slot"] == "hat" and i["tier"] == "common"]
    first = _give(ctx, hats[0], 10)
    _give(ctx, hats[1], 1)
    assert machines.equip(ctx, hats[0]) == {"equipped": {"hat": hats[0]}}
    assert machines.equip(ctx, hats[1]) == {"equipped": {"hat": hats[1]}}
    machines.equip(ctx, hats[0])
    flagged = ctx.conn.execute("SELECT item_id FROM inventory WHERE equipped = 1").fetchall()
    assert [r["item_id"] for r in flagged] == [hats[0]]
    machines.trade_up(ctx, first)
    assert machines.equipped(ctx) == {}


def test_trophies_show_in_the_book_and_can_be_worn_but_never_pressed(client, engine):
    with engine.conn:
        ctx = engine.ctx()
        mask = grant_item(ctx, "gate_maw_mask", via="gate:debt_card")
        hood = _give(ctx, "minigames_moth_hood", 10)
    casino = client.get("/state").json()["casino"]
    assert casino["trophies"] == {"gate_maw_mask": 1, "minigames_moth_hood": 10}
    assert casino["owned"] == {} and casino["inventory"] == []
    assert client.post("/casino/equip", json={"item_id": "followers_hood_gilt"}).status_code == 409
    out = client.post("/casino/equip", json={"item_id": "gate_maw_mask"}).json()
    assert out == {"equipped": {"hat": "gate_maw_mask"}}
    flagged = engine.conn.execute("SELECT id FROM inventory WHERE equipped = 1").fetchall()
    assert [r["id"] for r in flagged] == [mask]
    # Trophies don't go in the press, even ten of one color.
    r = client.post("/casino/tradeup", json={"inventory_ids": hood})
    assert r.status_code == 409 and r.json()["detail"] == "Only casino pieces go in the hopper."
    casino = client.get("/state").json()["casino"]
    assert casino["equipped"] == {"hat": "gate_maw_mask"}
    assert casino["trophies"]["minigames_moth_hood"] == 10


# --- The weekly draw ------------------------------------------------------------------


def test_entries_count_every_five_dollars_that_landed(engine):
    this_week = date(2026, 10, 18)  # TODAY's week (Sunday start)
    for path, body in [
        ("/casino/case", {"case_id": "case_10", "to_account": "sav_1"}),
        ("/casino/wheel", {"to_account": "brk_1"}),
        ("/casino/scratch", {"price_cents": 100, "to_account": "sav_1"}),
        ("/casino/scratch", {"price_cents": 100, "to_account": "brk_1"}),
        ("/shop/stock", {"symbol": "VTI", "amount_cents": 2_500}),
    ]:
        assert engine.handle("POST", path, body=body)[0] == 200
    # $10 + $5 + $1 + $1 + $25 = $42 landed this week: eight entries.
    state = engine.handle("GET", "/state")[1]["casino"]["draw"]
    assert state["week_start"] == this_week.isoformat()
    assert state["entries"] == 8 and state["tickets_total"] == 100
    assert state["draws_on"] == "2026-10-25" and state["last"] is None
    # Last week the bank moved $200 to savings and $150 to the brokerage on payday.
    with engine.conn:
        ctx = engine.ctx()
        assert draw.entries(ctx, this_week - timedelta(days=7)) == 70


def test_the_sunday_draw_grants_cosmetics_only(engine):
    for _ in range(3):
        engine.handle("POST", "/casino/case", body={"case_id": "case_50", "to_account": "sav_1"})
    engine.handle("GET", "/state")
    n_transfers = engine.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0]
    n_items = engine.conn.execute("SELECT COUNT(*) FROM inventory").fetchone()[0]

    engine.handle("POST", "/clock/advance", body={"days": 1})
    engine.handle("GET", "/state")
    assert engine.conn.execute("SELECT COUNT(*) FROM casino_draw").fetchone()[0] == 0
    engine.handle("POST", "/clock/advance", body={"days": 5})  # Monday the 26th
    status, state = engine.handle("GET", "/state")
    assert status == 200

    row = engine.conn.execute("SELECT * FROM casino_draw").fetchone()
    assert row["week_start"] == "2026-10-18" and row["drawn_on"] == "2026-10-25"
    assert row["entries"] == 30 and row["tickets_total"] == 100
    drawn, won = json.loads(row["drawn"]), json.loads(row["won"])
    prizes = catalog.machines()["draw"]["prizes"]
    assert len(set(drawn)) == 10 and all(0 <= t < 100 for t in drawn)
    expected = [prizes[i] for i, t in enumerate(drawn) if t < 30]
    assert [catalog.item(i)["tier"] for i in won] == expected
    assert engine.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0] == n_transfers
    assert engine.conn.execute("SELECT COUNT(*) FROM inventory").fetchone()[0] == n_items + len(won)
    # The bank's own days went by, but the draw moved nothing and paid no coins.
    assert engine.conn.execute("SELECT COUNT(*) FROM coin_ledger").fetchone()[0] == 0
    assert state["casino"]["draw"]["last"]["week"] == "2026-10-18"
    assert state["casino"]["draw"]["last"]["won"] == won
    note = [n for n in state["notifications"] if n["kind"] == "casino_draw"]
    assert len(note) == 1 and "!" not in note[0]["text"]


def test_a_full_house_of_tickets_wins_every_prize_in_order(ctx, monkeypatch):
    monkeypatch.setattr(draw, "entries", lambda ctx, start: 250)
    week = date(2026, 10, 11)
    out = draw.run_draw(ctx, week)
    tiers = [catalog.item(i)["tier"] for i in out["won"]]
    assert tiers == catalog.machines()["draw"]["prizes"]
    assert tiers[0] == "legendary" and "mythic" not in tiers
    again = draw.run_draw(ctx, week)
    assert again == out
    granted = ctx.conn.execute(
        "SELECT COUNT(*) FROM casino_grants WHERE machine = 'draw'"
    ).fetchone()[0]
    assert granted == 10
    assert ctx.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0] == 0


# --- What the room shows --------------------------------------------------------------


def test_state_section_is_the_contract(state):
    c = state["casino"]
    for key in (
        "can_spend_cents",
        "destinations",
        "cases",
        "belt",
        "box",
        "scratch",
        "wheel",
        "claw",
        "draw",
        "owned",
        "inventory",
        "equipped",
        "dealer",
    ):
        assert key in c, key
    assert c["can_spend_cents"] == min(state["extra"]["extra_cents"], state["caps_remaining_cents"])
    assert [d["id"] for d in c["destinations"]] == ["sav_1", "brk_1"]
    assert c["destinations"][0]["name"] == "House Fund"
    assert c["destinations"][0]["balance_cents"] == state["balances"]["sav_1"]
    assert c["belt"] == {"size": 25, "left": {"common": 18, "rare": 6, "epic": 1}}
    assert c["box"]["size"] == 100 and c["box"]["used"] == 0 and len(c["box"]["specials"]) == 2
    assert [b["size"] for b in c["scratch"]] == [20, 20, 20]
    assert len(c["wheel"]["wedges"]) == 12 and len(c["claw"]["heap"]) == 15
    for p in c["claw"]["heap"]:
        assert 0 <= p["x"] <= 1 and 0 <= p["y"] <= 1
    assert c["dealer"]["name"] == "Vex"
    if c["box"]["next_is_special"]:
        assert c["dealer"]["line"] == dealer.tell_line(c["box"]["next_tier"])
    else:
        assert c["dealer"]["line"].startswith("A new box.")


def test_the_dealer_states_the_exact_odds_before_every_pull(state):
    d = state["casino"]["dealer"]
    assert d["before"]["case"]["case_20"]["sav_1"] == (
        "Twenty to the House Fund. Twenty-five shells. Six blue. One purple."
    )
    assert d["before"]["scratch"]["100"]["brk_1"] == (
        "One to the Brokerage. Twenty in the book. Four blue."
    )
    assert d["before"]["wheel"]["sav_1"].endswith(
        "Twelve wedges. Three blue. One purple. One gold."
    )
    assert d["before"]["claw"]["sav_1"].endswith("Fifteen in the heap. Four blue. One purple.")
    lines = [d["line"]]
    for machine in d["before"].values():
        for v in machine.values():
            lines += list(v.values()) if isinstance(v, dict) else [v]
    assert len(lines) == 1 + 6 + 6 + 2 + 2
    assert not any("!" in line for line in lines)
    assert state["dialogue"]["croupier"]["name"] == "Vex"
    assert not any("!" in line for line in state["dialogue"]["croupier"]["lines"])


def test_dealer_words():
    assert dealer.words(25) == "twenty-five" and dealer.words(100) == "one hundred"
    assert dealer.belt_line({"common": 0, "rare": 0, "epic": 1}) == "One shell. One purple."
    assert dealer.box_line(["legendary", "legendary"], fresh=True) == "A new box. Two gold."
    assert dealer.box_line(["legendary", "mythic"]) == "One gold. One red."
    assert dealer.tell_line("mythic") == "Red in the chamber."
    assert dealer.money_line(5_000, "Brokerage") == "Fifty to the Brokerage."


def test_the_tell_shows_in_the_room(ctx):
    for _ in range(300):
        box = loads.box_public(ctx)
        if box["next_is_special"]:
            room = machines.room_state(ctx)
            line = dealer.tell_line(box["next_tier"])
            assert room["dealer"]["line"] == line
            assert room["dealer"]["before"]["case"]["case_10"]["sav_1"].endswith(line)
            return
        loads.fire_case(ctx)
    pytest.fail("no special came up in 300 cases")
