from datetime import date, timedelta

from backend.core.engine import Engine
from backend.core.router import ROUTES
from backend.providers import load
from backend.providers.fixtures import FixtureBank, history_start
from backend.tests.conftest import TODAY


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
