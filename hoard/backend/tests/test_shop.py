import pytest

from backend.content import category_map
from backend.game.dialogue import village_dialogue, work_time
from backend.game.shop import buy_stock, hours_of_work, shop_state
from backend.money.budget import compute_extra
from backend.money.transfer import PER_DAY_CAP_CENTS, TransferRefused
from backend.tests.conftest import TODAY


def test_hours_of_work():
    assert hours_of_work(6_125, 3_062) == 2.0
    assert work_time(1_799, 3_062) == "35 minutes of work"
    assert work_time(3_062, 3_062) == "1 hour of work"


def test_hourly_rate_from_paychecks(conn):
    # Two $2,450 paychecks in four weeks over 160 hours.
    assert shop_state(conn, TODAY, category_map())["hourly_rate_cents"] == 3_062


def test_buy_records_simulated_transfer_and_lowers_extra(conn):
    cmap = category_map()
    before = compute_extra(conn, TODAY, cmap)["extra_cents"]
    order = buy_stock(conn, TODAY, cmap, "VTI", 10_000)
    assert order["status"] == "simulated"
    assert order["qty"] == pytest.approx(10_000 / 28_310, abs=1e-4)
    assert compute_extra(conn, TODAY, cmap)["extra_cents"] == before - 10_000
    t = conn.execute("SELECT * FROM transfers").fetchone()
    assert (t["from_account"], t["to_account"], t["status"]) == ("chk_1", "brk_1", "simulated")
    event = conn.execute("SELECT * FROM events WHERE id = ?", [t["event_id"]]).fetchone()
    assert event["type"] == "shop_buy_stock"


def test_buy_never_touches_real_balances(conn):
    before = [tuple(r) for r in conn.execute("SELECT * FROM accounts")]
    buy_stock(conn, TODAY, category_map(), "AAPL", 5_000)
    assert [tuple(r) for r in conn.execute("SELECT * FROM accounts")] == before


def test_daily_cap(conn):
    buy_stock(conn, TODAY, category_map(), "VTI", PER_DAY_CAP_CENTS)
    with pytest.raises(TransferRefused, match="today"):
        buy_stock(conn, TODAY, category_map(), "VTI", 100)
    assert shop_state(conn, TODAY, category_map())["can_spend_cents"] == 0


def test_refusals(conn):
    with pytest.raises(TransferRefused):
        buy_stock(conn, TODAY, category_map(), "DOGE", 1_000)
    conn.execute("UPDATE accounts SET balance_cents = 0 WHERE kind = 'checking'")
    with pytest.raises(TransferRefused, match="extra"):
        buy_stock(conn, TODAY, category_map(), "VTI", 1_000)
    assert conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0] == 0


def test_shop_buy_endpoint(client):
    r = client.post("/shop/stock", json={"symbol": "MSFT", "amount_cents": 2_500})
    assert r.status_code == 200
    assert client.get("/state").json()["shop"]["recent_orders"][0]["symbol"] == "MSFT"
    assert (
        client.post("/shop/stock", json={"symbol": "NOPE", "amount_cents": 2_500}).status_code
        == 409
    )
    assert client.post("/shop/stock", json={"symbol": "VTI", "amount_cents": 0}).status_code == 422


def test_dialogue_is_plain(client):
    dialogue = client.get("/state").json()["dialogue"]
    assert set(dialogue) == {"shopkeeper", "tavern_keeper", "farmer", "shrine_keeper"}
    for npc in dialogue.values():
        assert npc["lines"]
        assert not any("!" in line for line in npc["lines"])


def test_dialogue_mentions_new_drain(client):
    lines = client.get("/state").json()["dialogue"]["shrine_keeper"]["lines"]
    assert any("StreamBox+" in line for line in lines)


def test_village_dialogue_handles_no_extra():
    state = {
        "extra": {"extra_cents": -100},
        "shop": {"hourly_rate_cents": 3_000, "can_spend_cents": 0},
        "tavern": {"spent_cents": 0, "budget_cents": 8_000, "visits": 0, "state": "quiet"},
        "crops": {"spent_cents": 0, "budget_cents": 12_000, "state": "bumper"},
        "shrine": {"saved_cents": 0},
        "drains": {"drains": [], "monthly_cents": 0, "budget_cents": 7_500},
    }
    assert "Come back next week" in village_dialogue(state)["shopkeeper"]["lines"][1]
