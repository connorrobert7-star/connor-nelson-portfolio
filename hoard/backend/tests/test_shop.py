import pytest

from backend.core.router import ApiError
from backend.features.shop.shop import buy_stock, hours_of_work, shop_state
from backend.features.villagers.lines import village_dialogue, work_time
from backend.money.budget import compute_extra
from backend.money.transfer import PER_DAY_CAP_CENTS, TransferRefused


def test_hours_of_work():
    assert hours_of_work(5_250, 2_625) == 2.0
    assert work_time(1_799, 3_062) == "35 minutes of work"
    assert work_time(3_062, 3_062) == "1 hour of work"


def test_buy_records_simulated_transfer_and_lowers_extra(ctx):
    before = compute_extra(ctx)["extra_cents"]
    order = buy_stock(ctx, "VTI", 10_000)
    assert order["status"] == "simulated"
    assert compute_extra(ctx)["extra_cents"] == before - 10_000
    t = ctx.conn.execute("SELECT * FROM transfers").fetchone()
    assert (t["from_account"], t["to_account"], t["status"]) == ("chk_1", "brk_1", "simulated")
    assert (
        ctx.conn.execute("SELECT type FROM events WHERE id = ?", [t["event_id"]]).fetchone()[0]
        == "shop_buy_stock"
    )
    assert shop_state(ctx)["stocks"][0]["owned_qty"] > 42.5


def test_daily_cap(ctx):
    buy_stock(ctx, "VTI", PER_DAY_CAP_CENTS)
    with pytest.raises(TransferRefused, match="today"):
        buy_stock(ctx, "VTI", 100)
    assert shop_state(ctx)["can_spend_cents"] == 0


def test_refusals(ctx):
    with pytest.raises(ApiError):
        buy_stock(ctx, "DOGE", 1_000)
    ctx.conn.execute("UPDATE accounts SET balance_cents = 0 WHERE kind = 'checking'")
    with pytest.raises(ApiError, match="extra"):
        buy_stock(ctx, "VTI", 1_000)
    assert ctx.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0] == 0


def test_shop_buy_endpoint(client):
    r = client.post("/shop/stock", json={"symbol": "MSFT", "amount_cents": 2_500})
    assert r.status_code == 200, r.json()
    assert r.json()["_events"][0]["kind"] == "money_moved"
    assert client.get("/state").json()["shop"]["recent_orders"][0]["symbol"] == "MSFT"
    assert (
        client.post("/shop/stock", json={"symbol": "NOPE", "amount_cents": 2_500}).status_code
        == 409
    )
    assert client.post("/shop/stock", json={"symbol": "VTI", "amount_cents": 0}).status_code == 422


def test_dialogue_is_plain(state):
    for npc_id in ("shopkeeper", "tavern_keeper", "farmer", "shrine_keeper"):
        lines = state["dialogue"][npc_id]["lines"]
        assert lines and not any("!" in line for line in lines)
    assert any("StreamBox+" in line for line in state["dialogue"]["shrine_keeper"]["lines"])


def test_village_dialogue_handles_no_extra():
    s = {
        "extra": {"extra_cents": -100},
        "shop": {"hourly_rate_cents": 3_000, "can_spend_cents": 0},
        "tavern": {"spent_cents": 0, "budget_cents": 8_000, "visits": 0, "state": "quiet"},
        "crops": {"spent_cents": 0, "budget_cents": 12_000, "state": "bumper"},
        "shrine": {"saved_cents": 0},
        "drains": {"drains": [], "monthly_cents": 0, "budget_cents": 7_500},
    }
    assert "Come back next week" in village_dialogue(s)["shopkeeper"]["lines"][1]
