"""The pot (docs/POT.md): runs of lamps with exactly one hit, the pot as cash already in the
Brokerage, a hit that buys the owner's pick through place_order, and the refusals."""

from collections import Counter

import pytest

import backend.money.transfer as transfer
from backend.core.router import ROUTES
from backend.core.services import coin_balance
from backend.features.casino import catalog, loads, machines, pot
from backend.features.casino.catalog import TIERS
from backend.features.shop import shop
from backend.money.budget import balances
from backend.providers import NotConfigured

OWN = ("chk_1", "sav_1", "brk_1")
LOAD_TABLES = ("casino_books", "casino_wheel", "casino_claw_heap", "casino_belt", "casino_box")
WATCHED = (
    *LOAD_TABLES,
    "casino_runs",
    "casino_pot",
    "casino_pot_buys",
    "casino_grants",
    "transfers",
    "events",
    "inventory",
    "coin_ledger",
    "orders",
    "shop_pick",
)
# The pot machines: run key, route, body, exact price.
POT = {
    "scratch_100": ("/casino/scratch", {"price_cents": 100}, 100),
    "scratch_200": ("/casino/scratch", {"price_cents": 200}, 200),
    "scratch_500": ("/casino/scratch", {"price_cents": 500}, 500),
    "wheel": ("/casino/wheel", {}, 500),
    "claw": ("/casino/claw", {"drop_x": 0.5}, 500),
}


@pytest.fixture(autouse=True)
def seeded():
    loads.seed(20261022)
    yield
    loads.seed(None)


@pytest.fixture
def unlimited(monkeypatch):
    monkeypatch.setattr(transfer, "PER_DAY_CAP_CENTS", 10**12)
    monkeypatch.setattr(transfer, "PER_WEEK_CAP_CENTS", 10**12)
    monkeypatch.setattr(machines, "compute_extra", lambda ctx: {"extra_cents": 10**12})


def snapshot(conn) -> dict:
    return {t: [tuple(r) for r in conn.execute(f"SELECT * FROM {t} ORDER BY 1")] for t in WATCHED}


def pull(ctx, key: str) -> dict:
    if key.startswith("scratch_"):
        return machines.scratch(ctx, int(key.split("_")[1]))
    if key == "wheel":
        return machines.spin_wheel(ctx)
    return machines.drop_claw(ctx, 0.5)


def cosmetic_loads(conn) -> dict:
    return {
        t: [tuple(r) for r in conn.execute(f"SELECT * FROM {t} ORDER BY 1")] for t in LOAD_TABLES
    }


# --- Content ------------------------------------------------------------------------------


def test_the_runs_are_the_contract():
    cfg = catalog.machines()["pot"]
    assert cfg["to_account"] == "brk_1"
    assert cfg["runs"] == {
        "scratch_100": 8,
        "scratch_200": 6,
        "scratch_500": 5,
        "wheel": 6,
        "claw": 6,
    }
    assert {k: pot.average_one_in(n) for k, n in cfg["runs"].items()} == {
        "scratch_100": 4.5,
        "scratch_200": 3.5,
        "scratch_500": 3.0,
        "wheel": 3.5,
        "claw": 3.5,
    }


# --- Runs ---------------------------------------------------------------------------------


@pytest.mark.parametrize("key", list(POT))
def test_a_run_holds_exactly_one_hit_and_it_comes_within_size(ctx, key):
    size = catalog.machines()["pot"]["runs"][key]
    for _ in range(300):
        assert pot.run_public(ctx, key) == {
            "size": size,
            "left": size,
            "average_one_in": (size + 1) / 2,
        }
        hits = []
        for n in range(size):
            before = pot.run_public(ctx, key)
            assert before["left"] == size - n  # the chance now is exactly 1 / left
            hits.append(pot.next_lamp(ctx, key))
            if hits[-1]:
                break
        assert hits.count(True) == 1 and hits[-1] is True
        assert len(hits) <= size


@pytest.mark.parametrize("key", list(POT))
def test_100k_pulls_hit_at_two_over_size_plus_one(ctx, key):
    size = catalog.machines()["pot"]["runs"][key]
    n = 100_000
    hits = sum(pot.next_lamp(ctx, key) for _ in range(n))
    rate = hits / n
    assert abs(rate - 2 / (size + 1)) <= 0.006, (key, rate)


def test_production_draws_runs_from_the_secure_source(ctx):
    import random

    loads.seed(None)
    assert isinstance(loads.RNG, random.SystemRandom)
    pot.load_run(ctx, "wheel")  # draws from loads.RNG, the same source as the belt
    assert 0 <= ctx.conn.execute("SELECT hit_at FROM casino_runs").fetchone()[0] < 6


# --- Money --------------------------------------------------------------------------------


@pytest.mark.parametrize("key", list(POT))
def test_every_pull_moves_exactly_its_price_into_the_brokerage_hit_or_blank(engine, key):
    path, body, price = POT[key]
    engine.handle("POST", "/shop/pick", body={"symbol": "VXUS"})
    seen = set()
    for _ in range(12):
        with engine.conn:
            ctx = engine.ctx()
            before, coins = balances(ctx), coin_balance(ctx)
        status, out = engine.handle("POST", path, body=body)
        assert status == 200, out
        assert out["money"] == {"amount_cents": price, "to_account": "brk_1", "status": "simulated"}
        seen.add(out["hit"])
        with engine.conn:
            ctx = engine.ctx()
            after = balances(ctx)
            assert coin_balance(ctx) == coins
        assert after["brk_1"] == before["brk_1"] + price
        assert after["chk_1"] == before["chk_1"] - price
        assert after["sav_1"] == before["sav_1"]
        assert sum(after[a] for a in OWN) == sum(before[a] for a in OWN)
    assert seen == {True, False}
    assert engine.conn.execute("SELECT COUNT(*) FROM coin_ledger").fetchone()[0] == 0


def test_a_blank_grants_nothing_and_leaves_the_cosmetic_loads_alone(ctx, unlimited):
    shop.set_pick(ctx, "VTI")
    machines.room_state(ctx)  # load every machine
    blanks: Counter = Counter()
    for _ in range(200):
        for key in POT:
            loaded = cosmetic_loads(ctx.conn)
            n_items = ctx.conn.execute("SELECT COUNT(*) FROM inventory").fetchone()[0]
            n_events = len(ctx.events)
            out = pull(ctx, key)
            if out["hit"]:
                continue
            blanks[key] += 1
            assert out["item"] is None and out["inventory_id"] is None
            assert cosmetic_loads(ctx.conn) == loaded, key
            assert ctx.conn.execute("SELECT COUNT(*) FROM inventory").fetchone()[0] == n_items
            assert [e["kind"] for e in ctx.events[n_events:]] == ["money_moved"]
    assert all(blanks[k] > 50 for k in POT), blanks


def test_the_blanks_look_like_blanks(ctx, unlimited):
    shop.set_pick(ctx, "VTI")
    duds = set()
    for _ in range(300):
        for key in POT:
            out = pull(ctx, key)
            if key.startswith("scratch_"):
                assert len(out["symbols"]) == 9
                shown = Counter(s for s in out["symbols"] if s != machines.DUD)
                left = out["book"]["left"]
                if out["hit"]:
                    assert shown[out["tier"]] >= 3
                else:
                    # No tier three times, and only tiers still in the book.
                    assert all(n <= 2 for n in shown.values()), out["symbols"]
                    assert all(left[t] > 0 for t in shown), (out["symbols"], left)
            elif key == "wheel":
                if out["hit"]:
                    assert out["dud_index"] is None and out["wedge_index"] is not None
                else:
                    assert out["wedge_index"] is None and out["tier"] is None
                    assert 0 <= out["dud_index"] < 12
                    duds.add(out["dud_index"])
            else:
                g = out["grabbed"]
                assert g["held"] is out["hit"]
                still = {p["slot_index"] for p in out["heap"]}
                if not out["hit"]:
                    assert g["slot_index"] in still  # it slipped: the piece stays
    assert len(duds) > 6


def test_the_pot_is_the_sum_of_blank_prices_since_the_last_hit(ctx, unlimited):
    shop.set_pick(ctx, "SCHD")
    expected = 0
    buys = 0
    order = list(POT) * 60
    loads.RNG.shuffle(order)
    for key in order:
        price = POT[key][2]
        out = pull(ctx, key)
        p = out["pot"]
        assert p["before_cents"] == expected and p["added_cents"] == price
        if out["hit"]:
            buys += 1
            assert p["total_cents"] == 0
            assert p["bought"]["amount_cents"] == expected + price
            expected = 0
        else:
            expected += price
            assert p["total_cents"] == expected
        assert pot.total_cents(ctx) == expected
        assert machines.room_state(ctx)["pot"]["total_cents"] == expected
    assert buys > 50
    assert ctx.conn.execute("SELECT COUNT(*) FROM casino_pot_buys").fetchone()[0] == buys


def test_a_hit_buys_the_pick_once_with_pot_plus_price_through_place_order(ctx, unlimited):
    calls = []
    real = ctx.providers.brokerage.place_order

    def recording(symbol: str, amount_cents: int) -> dict:
        calls.append((symbol, amount_cents))
        return real(symbol, amount_cents)

    ctx.providers.brokerage.place_order = recording
    shop.set_pick(ctx, "AAPL")
    hits = 0
    while hits < 12:
        n_orders = ctx.conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0]
        n_calls = len(calls)
        pot_before = pot.total_cents(ctx)
        out = pull(ctx, "wheel" if hits % 2 else "scratch_200")
        price = out["money"]["amount_cents"]
        if not out["hit"]:
            assert len(calls) == n_calls
            assert ctx.conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0] == n_orders
            continue
        hits += 1
        amount = pot_before + price
        assert calls[n_calls:] == [("AAPL", amount)]
        rows = ctx.conn.execute("SELECT * FROM orders WHERE id > ?", [n_orders]).fetchall()
        assert len(rows) == 1
        o = rows[0]
        weekly = shop.price_cents(ctx, "AAPL")
        assert (o["symbol"], o["amount_cents"], o["price_cents"]) == ("AAPL", amount, weekly)
        assert o["qty"] == pytest.approx(amount / weekly)
        transfer_id = ctx.conn.execute("SELECT MAX(id) FROM transfers").fetchone()[0]
        assert o["transfer_id"] == transfer_id  # the winning pull's own transfer
        buy = ctx.conn.execute("SELECT * FROM casino_pot_buys ORDER BY id DESC").fetchone()
        assert (buy["symbol"], buy["amount_cents"], buy["order_id"]) == ("AAPL", amount, o["id"])
        assert buy["status"] == "simulated"
        b = out["pot"]["bought"]
        assert b["symbol"] == "AAPL" and b["amount_cents"] == amount
        assert b["price_cents"] == weekly and b["status"] == "simulated"
        assert b["pick"]["symbol"] == "AAPL" and b["pick"]["creature"]
        assert out["item"] is not None and out["tier"] in TIERS
        assert out["run"]["left"] == out["run"]["size"]  # a fresh run after a hit


def test_the_pick_can_change_and_applies_to_the_next_hit(ctx, unlimited):
    shop.set_pick(ctx, "VTI")
    bought = []
    while len(bought) < 2:
        out = pull(ctx, "claw")
        if out["hit"]:
            bought.append(out["pot"]["bought"]["symbol"])
            shop.set_pick(ctx, "BND")
    assert bought == ["VTI", "BND"]


def test_the_real_brokerage_refuses_the_whole_pull(engine, monkeypatch):
    engine.handle("POST", "/shop/pick", body={"symbol": "VTI"})
    engine.handle("GET", "/state")

    def not_yet(symbol: str, amount_cents: int) -> dict:
        raise NotConfigured("SnapTradeBrokerage.place_order is not written yet (trading).")

    monkeypatch.setattr(engine.providers.brokerage, "place_order", not_yet)
    refused = 0
    for _ in range(10):
        before = snapshot(engine.conn)
        status, out = engine.handle("POST", "/casino/scratch", body={"price_cents": 500})
        if status == 200:
            assert not out["hit"]
            continue
        refused += 1
        assert status == 503, out
        assert snapshot(engine.conn) == before  # rolled back: no money, no lamp, no pot change
    assert refused > 0


# --- Refusals -----------------------------------------------------------------------------


@pytest.mark.parametrize("key", list(POT))
def test_no_pick_means_409_and_nothing_moved(engine, key):
    path, body, _ = POT[key]
    engine.handle("GET", "/state")
    before = snapshot(engine.conn)
    for b in (body, {**body, "to_account": "brk_1"}):
        status, out = engine.handle("POST", path, body=b)
        assert (status, out) == (409, {"detail": "Pick a stock at Marlo's counter first."})
        assert snapshot(engine.conn) == before


@pytest.mark.parametrize("key", list(POT))
def test_a_non_brokerage_account_means_422_and_nothing_moved(engine, key):
    path, body, _ = POT[key]
    engine.handle("POST", "/shop/pick", body={"symbol": "VTI"})
    engine.handle("GET", "/state")
    before = snapshot(engine.conn)
    for account in ("sav_1", "chk_1", "debt_card", ""):
        status, out = engine.handle("POST", path, body={**body, "to_account": account})
        assert status == 422, (account, out)
        assert snapshot(engine.conn) == before


def test_the_game_never_picks(state):
    assert state["shop"]["pick"] is None
    assert state["casino"]["pot"]["pick"] is None
    assert state["casino"]["pot"]["total_cents"] == 0 and state["casino"]["pot"]["buys"] == 0


def test_the_pick_route(client):
    out = client.post("/shop/pick", json={"symbol": "NOPE"})
    assert out.status_code == 409
    out = client.post("/shop/pick", json={"symbol": "VXUS"})
    assert out.status_code == 200
    pick = out.json()["pick"]
    assert pick["symbol"] == "VXUS" and pick["name"] and pick["creature"] == "parrot"
    assert pick["look"]["sheet"].startswith("res://art/packs/")
    state = client.get("/state").json()
    assert state["shop"]["pick"]["symbol"] == "VXUS"
    assert state["casino"]["pot"]["pick"]["symbol"] == "VXUS"
    line = state["casino"]["dealer"]["before"]["wheel"]["brk_1"]
    assert line == "Five to the Brokerage. Six lamps. One lights."
    assert state["casino"]["runs"]["scratch_100"] == {"size": 8, "left": 8, "average_one_in": 4.5}


def test_nothing_sells_or_lowers_a_balance_and_no_pot_route_grants_coins(engine, monkeypatch):
    monkeypatch.setattr(transfer, "PER_DAY_CAP_CENTS", 10**12)
    monkeypatch.setattr(transfer, "PER_WEEK_CAP_CENTS", 10**12)
    monkeypatch.setattr(machines, "compute_extra", lambda ctx: {"extra_cents": 10**12})
    pot_routes = {("POST", p) for p, _, _ in POT.values()} | {("POST", "/shop/pick")}
    assert pot_routes <= set(ROUTES)
    engine.handle("POST", "/shop/pick", body={"symbol": "MSFT"})
    for i in range(80):
        key = list(POT)[i % len(POT)]
        path, body, price = POT[key]
        with engine.conn:
            ctx = engine.ctx()
            before, coins = balances(ctx), coin_balance(ctx)
        status, out = engine.handle("POST", path, body=body)
        assert status == 200, out
        with engine.conn:
            ctx = engine.ctx()
            after = balances(ctx)
            assert coin_balance(ctx) == coins
        for acct in before:
            if acct != "chk_1":
                assert after[acct] >= before[acct], (key, acct)
        assert after["chk_1"] == before["chk_1"] - price
        assert not [e for e in out["_events"] if e["kind"] == "coins"]
    rows = engine.conn.execute("SELECT amount_cents, qty FROM orders").fetchall()
    assert rows and all(r["amount_cents"] > 0 and r["qty"] > 0 for r in rows)
    assert engine.conn.execute("SELECT COUNT(*) FROM coin_ledger").fetchone()[0] == 0


def test_the_dealer_names_the_run_and_the_pot(ctx, unlimited):
    shop.set_pick(ctx, "VTI")
    while True:
        out = pull(ctx, "scratch_100")
        if not out["hit"]:
            break
    left = out["run"]["left"]
    words = machines.dealer.words(left).capitalize()
    assert out["dealer"]["line"].startswith(f"{words} lamps. One lights.") or left == 1
    assert out["dealer"]["line"].endswith("in the pot.")
    room = machines.room_state(ctx)
    said = room["dealer"]["before"]["scratch"]["100"]["brk_1"]
    assert said.startswith("One to the Brokerage.") and "in the pot." in said
    assert "!" not in said
