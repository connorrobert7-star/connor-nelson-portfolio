from datetime import date, timedelta

import pytest

from backend.conftest import TODAY
from backend.core.engine import Engine
from backend.core.services import add_coins
from backend.features.village import bundles, house, wall
from backend.money.transfer import move

HOUSE = house.house_config()


def _village(engine: Engine) -> dict:
    status, body = engine.handle("GET", "/state")
    assert status == 200, body
    return body["village"]


def _bundle(bundle_id: str) -> dict:
    for ruin in bundles.bundle_config()["ruins"]:
        for b in ruin["bundles"]:
            if b["id"] == bundle_id:
                return b
    raise KeyError(bundle_id)


def _txn(ctx, day: date, cents: int, category: str, merchant: str = "Test") -> None:
    n = ctx.conn.execute("SELECT COUNT(*) FROM transactions").fetchone()[0]
    ctx.conn.execute(
        "INSERT INTO transactions VALUES (?, 'chk_1', ?, ?, ?, ?, '{}')",
        [f"t_{n}", day.isoformat(), cents, merchant, category],
    )


@pytest.fixture
def later() -> tuple[Engine, object]:
    """A save three weeks in, with the ledger since the bundle epoch cleared for hand-made rows."""
    engine = Engine(":memory:", TODAY)
    engine.handle("GET", "/state")
    engine.handle("POST", "/clock/advance", body={"days": 7})
    engine.handle("POST", "/clock/advance", body={"days": 7})
    ctx = engine.ctx()
    ctx.conn.execute("DELETE FROM transactions WHERE date >= ?", [bundles.epoch(ctx).isoformat()])
    return engine, ctx


# --- the house ------------------------------------------------------------------------


def test_house_stage_thresholds():
    stages = HOUSE["stages"]
    assert [s["id"] for s in stages] == [
        "plot",
        "foundation",
        "frame",
        "walls",
        "roof",
        "interior",
        "finished",
    ]
    assert stages[-1]["at_cents"] == HOUSE["goal_cents"] == 4_000_000
    for i, s in enumerate(stages):
        assert house.stage_index(stages, s["at_cents"]) == i
        if i:
            assert house.stage_index(stages, s["at_cents"] - 1) == i - 1
    assert house.stage_index(stages, 0) == 0
    assert house.stage_index(stages, 10**9) == len(stages) - 1


def test_house_fill_rows_and_gap():
    view = house.house_view(HOUSE, 1_000_000, built=0, seen=3)
    assert view["stage"]["id"] == "walls" and view["next"]["id"] == "roof"
    assert view["next"]["to_go_cents"] == 280_000
    assert view["fill"] == pytest.approx(0.5)
    assert view["rows"] == 16
    done = house.house_view(HOUSE, 4_500_000, built=0, seen=6)
    assert done["done"] and done["next"] is None and done["rows"] == done["rows_total"]


def test_house_never_unbuilds():
    view = house.house_view(HOUSE, 500_000, built=4, seen=4)
    assert view["stage"]["id"] == "roof"
    assert view["fill"] == 0.0 and view["next"]["to_go_cents"] == 2_240_000 - 500_000


def test_demo_house_opens_on_walls(engine):
    h = _village(engine)["house"]
    assert h["balance_cents"] == 845_000
    assert h["stage"]["id"] == "walls" and h["next"]["to_go_cents"] == 435_000
    assert not h["building"]


def test_house_stage_crossing_builds_once(engine):
    _village(engine)
    with engine.conn:
        engine.conn.execute("UPDATE accounts SET balance_cents = 1300000 WHERE id = 'sav_1'")
    h = _village(engine)["house"]
    assert h["stage"]["id"] == "roof" and h["building"] and h["seen_index"] == 3
    status, body = engine.handle("POST", "/village/seen", body={"parts": ["house"]})
    assert status == 200 and not body["village"]["house"]["building"]
    # The money leaves again: the roof stays on.
    with engine.conn:
        engine.conn.execute("UPDATE accounts SET balance_cents = 900000 WHERE id = 'sav_1'")
    h = _village(engine)["house"]
    assert h["stage"]["id"] == "roof" and h["balance_cents"] == 900_000


def test_overnight_stage_queues_an_away_beat(engine):
    _village(engine)
    with engine.conn:
        engine.conn.execute("UPDATE accounts SET balance_cents = 1300000 WHERE id = 'sav_1'")
    with engine.conn:
        house_ctx = engine.ctx()
        from backend.features.village import village_day

        village_day(house_ctx, house_ctx.today)
    beats = [a for a in engine.handle("GET", "/state")[1]["away"] if a["kind"] == "house_stage"]
    assert [b["payload"]["stage"] for b in beats] == ["roof"]
    assert "!" not in beats[0]["payload"]["text"]


# --- the wall ------------------------------------------------------------------------


def test_wall_height_math():
    w = wall.wall_math(balance_cents=150_000, monthly_cents=100_000, months=3, courses=12)
    assert w["target_cents"] == 300_000
    assert w["courses"] == 6 and w["months_covered"] == 1.5 and not w["full"]
    assert [m["course"] for m in w["marks"]] == [4, 8, 12]
    assert [m["cents"] for m in w["marks"]] == [100_000, 200_000, 300_000]
    assert wall.wall_math(299_999, 100_000, 3, 12)["courses"] == 11
    full = wall.wall_math(300_000, 100_000, 3, 12)
    assert full["courses"] == 12 and full["full"]
    assert wall.wall_math(900_000, 100_000, 3, 12)["courses"] == 12
    assert wall.wall_math(0, 100_000, 3, 12)["courses"] == 0
    assert wall.wall_math(5_000, 0, 3, 12)["full"]


def test_monthly_expenses_skip_money_moved_to_own_accounts(ctx):
    before = wall.monthly_expenses_cents(ctx, 90)
    yesterday = TODAY - timedelta(days=1)
    _txn(ctx, yesterday, 500_000, "TRANSFER_OUT_SAVINGS")
    _txn(ctx, yesterday, 500_000, "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS")
    assert wall.monthly_expenses_cents(ctx, 90) == before
    _txn(ctx, yesterday, 90_000, "FOOD_AND_DRINK_GROCERIES")
    assert wall.monthly_expenses_cents(ctx, 90) == pytest.approx(
        before + 90_000 * 30.4375 / 90, abs=1
    )


def test_demo_wall(engine):
    w = _village(engine)["wall"]
    assert w["balance_cents"] == 180_000
    assert w["target_cents"] == w["monthly_expenses_cents"] * 3
    assert 0 < w["courses"] < 12 and not w["full"]


def test_bricks_fall_when_money_leaves_and_show_once(engine):
    _village(engine)
    with engine.conn:
        engine.conn.execute("UPDATE accounts SET balance_cents = 30000 WHERE id = 'sav_2'")
    w = _village(engine)["wall"]
    assert w["fell_cents"] == 150_000 and w["seen_courses"] > w["courses"]
    engine.handle("POST", "/village/seen", body={"parts": ["wall"]})
    w = _village(engine)["wall"]
    assert w["fell_cents"] == 0 and w["seen_courses"] == w["courses"]


def test_money_into_the_wall_raises_it(engine):
    _village(engine)
    with engine.conn:
        move(engine.ctx(), "chk_1", "sav_2", 40_000, "test", {"type": "test"})
    w = _village(engine)["wall"]
    assert w["balance_cents"] == 220_000 and w["rose_cents"] == 40_000


# --- the bundle detectors --------------------------------------------------------------


def test_epoch_is_the_sunday_of_the_week_before(ctx):
    e = bundles.epoch(ctx)
    assert e == date(2026, 10, 11) and e.weekday() == 6


def test_groceries_under_budget(later):
    _, ctx = later
    e = bundles.epoch(ctx)
    _txn(ctx, e + timedelta(days=1), 10_000, "FOOD_AND_DRINK_GROCERIES")
    _txn(ctx, e + timedelta(days=8), 15_000, "FOOD_AND_DRINK_GROCERIES")
    # Week three has no groceries at all, which is under budget too. Week four isn't over.
    assert bundles.groceries_under_budget(ctx, e, _bundle("granary_larder")) == 2


def test_no_spend_week(later):
    _, ctx = later
    e = bundles.epoch(ctx)
    _txn(ctx, e + timedelta(days=2), 500, "FOOD_AND_DRINK_COFFEE")
    _txn(ctx, e + timedelta(days=16), 100, "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES")
    _txn(ctx, e + timedelta(days=9), 30_000, "FOOD_AND_DRINK_GROCERIES")  # groceries don't count
    assert bundles.no_spend_week(ctx, e, _bundle("granary_hearth")) == 1


def test_five_deposits(later):
    _, ctx = later
    e = bundles.epoch(ctx)
    b = _bundle("bell_deposits")
    assert bundles.deposits(ctx, e, b) == 0
    _txn(ctx, e + timedelta(days=3), 20_000, "TRANSFER_OUT_SAVINGS")
    _txn(ctx, e + timedelta(days=3), 15_000, "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS")
    move(ctx, "chk_1", "sav_1", 2_000, "case", {"type": "test"})
    move(ctx, "chk_1", "sav_2", 1_000, "brick", {"type": "test"})
    move(ctx, "chk_1", "debt_card", 2_500, "gate", {"type": "test"})  # a payment, not a deposit
    assert bundles.deposits(ctx, e, b) == 4
    move(ctx, "chk_1", "brk_1", 500, "case", {"type": "test"})
    assert bundles.deposits(ctx, e, b) == 5


def test_stock_buys_never_fill_a_socket(later):
    engine, ctx = later
    e = bundles.epoch(ctx)
    from backend.features.shop.shop import buy_stock

    buy_stock(ctx, "VTI", 25_000)
    assert bundles.deposits(ctx, e, _bundle("bell_deposits")) == 0
    assert bundles.week_landed(ctx, e, _bundle("bell_big_week")) == 0


def test_a_250_week(later):
    _, ctx = later
    e = bundles.epoch(ctx)
    b = _bundle("bell_big_week")
    _txn(ctx, e + timedelta(days=1), 20_000, "TRANSFER_OUT_SAVINGS")
    _txn(ctx, e + timedelta(days=9), 12_000, "TRANSFER_OUT_SAVINGS")
    _txn(ctx, e + timedelta(days=12), 13_000, "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS")
    assert bundles.week_landed(ctx, e, b) == 1
    # This week counts as it goes.
    move(ctx, "chk_1", "sav_1", 25_000, "case", {"type": "test"})
    assert bundles.week_landed(ctx, e, b) == 2


def test_debt_payment(later):
    _, ctx = later
    e = bundles.epoch(ctx)
    b = _bundle("ossuary_blow")
    _txn(ctx, e + timedelta(days=1), 28_500, "LOAN_PAYMENTS_CAR_PAYMENT")  # the minimum
    assert bundles.debt_payment(ctx, e, b) == 0
    _txn(ctx, e + timedelta(days=2), 40_000, "LOAN_PAYMENTS_CAR_PAYMENT")  # above it
    assert bundles.debt_payment(ctx, e, b) == 1
    move(ctx, "chk_1", "debt_card", 2_500, "gate", {"type": "gate_attack"})
    assert bundles.debt_payment(ctx, e, b) == 2


def test_three_flames_in_a_day(later):
    _, ctx = later
    e = bundles.epoch(ctx)
    b = _bundle("ossuary_flames")
    for _ in range(2):
        add_coins(ctx, 40, "minigames: mine run")
    add_coins(ctx, 500, "Shrine devotion")  # not a minigame
    assert bundles.three_flames_day(ctx, e, b) == 0
    add_coins(ctx, 30, "Fishing run")
    assert bundles.three_flames_day(ctx, e, b) == 1
    for _ in range(3):
        ctx.conn.execute(
            "INSERT INTO events (ts, type, payload) VALUES (?, 'minigames_flame', '{}')",
            [(ctx.today - timedelta(days=2)).isoformat()],
        )
    assert bundles.three_flames_day(ctx, e, b) == 2


# --- tablets and ruins -------------------------------------------------------------------


def test_demo_tablets_start_with_this_weeks_progress(engine):
    ruins = {r["id"]: r for r in _village(engine)["ruins"]}
    assert set(ruins) == {"granary", "ossuary", "bell_tower"}
    bell = {b["id"]: b for b in ruins["bell_tower"]["bundles"]}
    assert bell["bell_deposits"]["filled"] == 2  # the payday's two transfers
    assert bell["bell_big_week"]["complete"]  # $350 landed that week
    assert not any(r["restored"] for r in ruins.values())
    for r in ruins.values():
        for b in r["bundles"]:
            assert b["icon"]["sheet"].startswith("res://art/packs/")
            assert len(b["sockets"]) == b["need"]


def _restore_ossuary(engine: Engine) -> None:
    with engine.conn:
        ctx = engine.ctx()
        move(ctx, "chk_1", "debt_card", 2_500, "gate", {"type": "gate_attack"})
        for _ in range(3):
            add_coins(ctx, 20, "minigames: dungeon run")


def test_full_tablet_restores_the_ruin_and_it_persists(engine):
    _restore_ossuary(engine)
    v = _village(engine)
    oss = next(r for r in v["ruins"] if r["id"] == "ossuary")
    assert oss["restored"] and oss["fresh"] and v["opens"]["trophies"]
    assert all(s["new"] for b in oss["bundles"] for s in b["sockets"])
    status, body = engine.handle("POST", "/village/seen", body={})
    assert status == 200
    oss = next(r for r in body["village"]["ruins"] if r["id"] == "ossuary")
    assert oss["restored"] and not oss["fresh"] and oss["restored_on"] == TODAY.isoformat()
    assert not any(s["new"] for b in oss["bundles"] for s in b["sockets"])
    # The records that filled it go away; the ruin stays restored and the sockets stay full.
    with engine.conn:
        engine.conn.execute("DELETE FROM transfers")
        engine.conn.execute("DELETE FROM coin_ledger")
    oss = next(r for r in _village(engine)["ruins"] if r["id"] == "ossuary")
    assert oss["restored"] and oss["sockets_filled"] == oss["sockets_total"]


def test_restored_overnight_queues_a_beat(engine):
    _village(engine)
    _restore_ossuary(engine)
    engine.handle("POST", "/clock/advance", body={"days": 1})
    s = engine.handle("GET", "/state")[1]
    beats = [a for a in s["away"] if a["kind"] == "ruin_restored"]
    assert [b["payload"]["ruin"] for b in beats] == ["ossuary"]
    assert engine.conn.execute("SELECT COUNT(*) FROM village_restored").fetchone()[0] == 1
    ruin = next(r for r in s["village"]["ruins"] if r["id"] == "ossuary")
    assert ruin["fresh"]  # the village still plays its own cutscene on the next visit


def test_ossuary_shows_owned_trophies(engine, monkeypatch):
    from backend.features import village as feature

    monkeypatch.setattr(
        feature,
        "_catalog",
        lambda: {
            "casino_a": {"id": "casino_a", "name": "Bone crown", "tier": "legendary", "icon": {}},
            "casino_b": {"id": "casino_b", "name": "Grey hood", "tier": "common", "icon": {}},
        },
    )
    _restore_ossuary(engine)
    with engine.conn:
        ctx = engine.ctx()
        from backend.core.services import grant_item

        grant_item(ctx, "casino_b", "test")
        grant_item(ctx, "casino_a", "test")
        grant_item(ctx, "unknown_item", "test")
    trophies = _village(engine)["trophies"]
    assert [t["item_id"] for t in trophies] == ["casino_a", "casino_b"]


def test_stats_numbers(engine):
    stats = _village(engine)["stats"]
    assert stats["days_since_landing"] == 4 and stats["faith_band"] == "content"


# --- the money rules ---------------------------------------------------------------------


def test_village_never_moves_money_or_grants_coins(engine):
    def snapshot() -> tuple:
        c = engine.conn
        return (
            c.execute("SELECT COUNT(*) FROM transfers").fetchone()[0],
            c.execute("SELECT COUNT(*), COALESCE(SUM(delta), 0) FROM coin_ledger").fetchone()[:],
            c.execute("SELECT COUNT(*) FROM events").fetchone()[0],
        )

    _village(engine)
    before = snapshot()
    balances = engine.handle("GET", "/state")[1]["balances"]
    for _ in range(3):
        status, body = engine.handle("POST", "/village/seen", body={})
        assert status == 200
        assert not [e for e in body.get("_events", []) if e["kind"] in ("money_moved", "coins")]
    assert snapshot() == before
    assert engine.handle("GET", "/state")[1]["balances"] == balances
    # Days pass: the daily hook writes sockets and beats but never money or coins.
    for _ in range(3):
        engine.handle("POST", "/clock/advance", body={"days": 7})
        engine.handle("GET", "/state")
    assert engine.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0] == before[0]
    assert engine.conn.execute("SELECT COUNT(*) FROM coin_ledger").fetchone()[0] == before[1][0]


def test_village_routes():
    from backend.core.router import ROUTES

    village_routes = [k for k in ROUTES if k[1].startswith("/village")]
    assert village_routes == [("POST", "/village/seen")]
