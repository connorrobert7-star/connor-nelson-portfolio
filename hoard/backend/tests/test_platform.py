from datetime import date, timedelta

from backend.conftest import TODAY
from backend.core.engine import Engine
from backend.core.router import ROUTES
from backend.providers import load
from backend.providers.fixtures import FixtureBank, history_start


def test_fixture_bank_is_deterministic():
    bank = FixtureBank()
    a = bank.transactions(TODAY, history_start(TODAY), TODAY)
    b = bank.transactions(TODAY, history_start(TODAY), TODAY)
    assert a == b and len(a) > 100


def test_history_ends_yesterday(ctx):
    first, last = ctx.conn.execute("SELECT MIN(date), MAX(date) FROM transactions").fetchone()
    assert date.fromisoformat(last) <= TODAY - timedelta(days=1)
    assert (TODAY - date.fromisoformat(first)).days >= 88


def test_state_has_platform_sections(state):
    for key in (
        "today",
        "demo",
        "life",
        "coins",
        "extra",
        "balances",
        "debts",
        "holdings",
        "notifications",
    ):
        assert key in state
    assert state["demo"] is True
    assert len(state["debts"]) == 3
    assert {a["kind"] for a in state["accounts"]} == {"checking", "savings", "brokerage"}


def test_life_clock(state):
    life = state["life"]
    assert 1 <= life["level"] <= 100
    assert life["death_age_years"] > life["age_years"]
    assert life["days_left"] > 0
    assert 0 <= life["level_progress"] < 1


def test_clock_advance_moves_days_and_runs_sync(engine):
    engine.handle("POST", "/clock/advance", body={"days": 7})
    status, s = engine.handle("GET", "/state")
    assert s["today"] == (TODAY + timedelta(days=7)).isoformat()
    assert s["window"]["end"] == (TODAY + timedelta(days=6)).isoformat()
    assert engine.handle("POST", "/clock/advance", body={"days": 30})[0] == 422


def test_clock_only_moves_in_demo(monkeypatch):
    engine = Engine(":memory:", TODAY)
    monkeypatch.setattr(engine.providers.transfers, "simulated", False)
    assert engine.handle("POST", "/clock/advance", body={"days": 1})[0] == 403


def test_unknown_route_and_bad_params(engine):
    assert engine.handle("GET", "/nope")[0] == 404
    assert engine.handle("POST", "/shop/stock", body={"symbol": "VTI"})[0] == 422
    assert (
        engine.handle("POST", "/shop/stock", body={"symbol": "VTI", "amount_cents": 2.5})[0] == 422
    )


def test_errors_roll_back(engine):
    engine.handle("POST", "/shop/stock", body={"symbol": "NOPE", "amount_cents": 100})
    assert engine.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0] == 0


def test_handle_json_round_trip(engine):
    import json

    out = json.loads(engine.handle_json("GET", "/health", "{}", "{}"))
    assert out["status"] == 200 and out["body"]["ok"] is True


def test_save_export_import(engine):
    engine.handle("POST", "/shop/stock", body={"symbol": "VTI", "amount_cents": 2_500})
    data = engine.export_db()
    other = Engine(":memory:", TODAY)
    other.import_db(data)
    assert other.conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0] == 1


def test_real_providers_need_keys():
    import pytest

    from backend.providers import NotConfigured

    for var, value in [
        ("HOARD_BANK", "plaid"),
        ("HOARD_BROKERAGE", "snaptrade"),
        ("HOARD_MARKET", "alpaca"),
        ("HOARD_TRANSFERS", "plaid_transfer"),
        ("HOARD_ADVISOR", "claude"),
        ("HOARD_CREDIT", "bureau"),
    ]:
        with pytest.raises(NotConfigured):
            load({var: value})


def test_every_route_documents_itself():
    for method, path in ROUTES:
        assert path.startswith("/"), path
        assert method in ("GET", "POST"), method


def test_emergency_fund_account(state):
    ids = {a["id"]: a for a in state["accounts"]}
    assert ids["sav_2"]["kind"] == "savings" and ids["sav_2"]["name"] == "Emergency Fund"
    assert state["house"]["name"] == "House Fund"


def test_landed_cents_counts_bank_and_game_transfers(ctx):
    from backend.money.budget import landed_cents, last_landing_day
    from backend.money.transfer import move

    week_start = TODAY - timedelta(days=7)
    before = landed_cents(ctx, week_start, TODAY)
    assert before == 20_000 + 15_000  # the scripted payday's savings and brokerage transfers
    move(ctx, "chk_1", "sav_2", 2_000, "test", {"type": "test"})
    assert landed_cents(ctx, week_start, TODAY) == before + 2_000
    assert last_landing_day(ctx) == TODAY


def test_away_queue(engine):
    from backend.core.services import away

    with engine.conn:
        away(engine.ctx(), "test_beat", priority=10, text="hello")
    status, s = engine.handle("GET", "/state")
    assert [a["kind"] for a in s["away"]] == ["test_beat"]
    engine.handle("POST", "/away/seen", body={"ids": [s["away"][0]["id"]]})
    assert engine.handle("GET", "/state")[1]["away"] == []
