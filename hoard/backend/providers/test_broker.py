"""The broker slot: sizing, the paper/live switch, moomoo's order flow against a fake OpenD,
and the rule that nothing here can sell."""

import sys
import types
from datetime import datetime
from decimal import Decimal
from pathlib import Path

import pytest

from backend.providers import NotConfigured, live, load_broker
from backend.providers.broker import NEW_YORK, FixtureBroker, share_count, us_market_open
from backend.providers.fixtures import FixtureMarket

PROVIDERS = Path(__file__).resolve().parent


# --- sizing ------------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("cents", "price", "qty"),
    [
        (500, "283.10", "0.017"),  # 0.01766 -> 0.017, never 0.018
        (500, "5.00", "1.000"),
        (500, "4.99", "1.002"),  # 1.002004 -> 1.002
        (500, "0.333", "15.015"),
        (100, "200000", "0.000"),  # too small to send
        (2000, "123.456", "0.162"),
    ],
)
def test_share_count_is_three_decimals_rounded_down(cents, price, qty):
    got = share_count(cents, price)
    assert got == Decimal(qty)
    assert got * Decimal(price) <= Decimal(cents) / 100


def test_share_count_never_rounds_up_over_many_prices():
    """Real quotes have cents (or four decimals under $1): the count never costs more than
    the pull at the quote, and one more thousandth would."""
    prices = [Decimal(i) / 100 for i in range(100, 200_000, 37)]
    prices += [Decimal(i) / 10_000 for i in range(1, 10_000, 13)]
    for price in prices:
        for cents in (100, 200, 500, 1000, 2000, 5000):
            qty = share_count(cents, price)
            assert qty * price <= Decimal(cents) / 100
            assert (qty + Decimal("0.001")) * price > Decimal(cents) / 100


def test_market_hours():
    assert us_market_open(datetime(2026, 10, 21, 10, 0, tzinfo=NEW_YORK))
    assert not us_market_open(datetime(2026, 10, 21, 9, 29, tzinfo=NEW_YORK))
    assert not us_market_open(datetime(2026, 10, 21, 16, 0, tzinfo=NEW_YORK))
    assert not us_market_open(datetime(2026, 10, 24, 11, 0, tzinfo=NEW_YORK))  # Saturday


# --- the switch ------------------------------------------------------------------------------


def test_paper_unless_hoard_live_is_exactly_one():
    assert not live({})
    assert not live({"HOARD_LIVE": "0"})
    assert not live({"HOARD_LIVE": "true"})
    assert live({"HOARD_LIVE": "1"})
    keys = {"HOARD_BROKER": "moomoo", "MOOMOO_TRADE_PASSWORD": "x"}
    assert load_broker(keys).paper
    assert not load_broker({**keys, "HOARD_LIVE": "1"}).paper


def test_demo_broker_fills_and_keeps_the_leftover_as_cash():
    b = FixtureBroker(FixtureMarket(), cash_cents=1000)
    rec = b.buy("VTI", 500, "t")
    assert rec["status"] == "filled"
    assert rec["filled_cents"] <= 500
    assert rec["leftover_cents"] == 500 - rec["filled_cents"]
    assert b.cash_cents() == 1000 - rec["filled_cents"]


def test_alpaca_is_a_stub_with_the_same_interface(monkeypatch):
    monkeypatch.setenv("ALPACA_KEY_ID", "k")
    monkeypatch.setenv("ALPACA_SECRET_KEY", "s")
    b = load_broker({"HOARD_BROKER": "alpaca"})
    assert b.paper
    for method in ("cash_cents", "market_open", "buy", "order", "positions"):
        assert callable(getattr(b, method))
    with pytest.raises(NotConfigured):
        b.buy("VTI", 500, "t")


def test_nothing_in_the_broker_slot_can_sell():
    for path in ("broker.py", "moomoo.py", "real.py", "base.py"):
        text = (PROVIDERS / path).read_text()
        assert "TrdSide.SELL" not in text
        assert "def sell" not in text
        assert '"side": "sell"' not in text


# --- moomoo against a fake OpenD -----------------------------------------------------------------


class Frame:
    """Just enough of a pandas DataFrame for the provider."""

    def __init__(self, rows: list[dict]) -> None:
        self.rows = rows

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, column):
        return Column([r[column] for r in self.rows])

    def iterrows(self):
        return enumerate(self.rows)


class Column(list):
    @property
    def iloc(self):
        return self


def fake_moomoo(fills: list[str], placed: list[dict]):
    m = types.SimpleNamespace(RET_OK=0)
    m.TrdEnv = types.SimpleNamespace(SIMULATE="SIMULATE", REAL="REAL")
    m.TrdMarket = types.SimpleNamespace(US="US")
    m.SecurityFirm = types.SimpleNamespace(FUTUINC="FUTUINC")
    m.TrdSide = types.SimpleNamespace(BUY="BUY")
    m.OrderType = types.SimpleNamespace(MARKET="MARKET")
    m.TimeInForce = types.SimpleNamespace(DAY="DAY")
    statuses = iter(fills)

    class Quote:
        def __init__(self, **_):
            pass

        def get_market_snapshot(self, codes):
            return 0, Frame([{"code": codes[0], "last_price": 283.1}])

        def get_global_state(self):
            return 0, {"market_us": "MORNING"}

        def close(self):
            pass

    class Trade:
        def __init__(self, **_):
            self.status = "SUBMITTED"

        def get_acc_list(self):
            return 0, Frame(
                [
                    {"acc_id": 1, "trd_env": "REAL", "trdmarket_auth": "['US']"},
                    {
                        "acc_id": 7,
                        "trd_env": "SIMULATE",
                        "trdmarket_auth": "['US']",
                        "sim_acc_type": "OPTION",
                    },
                    {
                        "acc_id": 8,
                        "trd_env": "SIMULATE",
                        "trdmarket_auth": "['US']",
                        "sim_acc_type": "STOCK",
                    },
                ]
            )

        def place_order(self, **kw):
            placed.append(kw)
            return 0, Frame([{"order_id": "42"}])

        def order_list_query(self, **kw):
            status = next(statuses, "FILLED_ALL")
            dealt = 0.017 if status in ("FILLED_ALL", "FILLED_PART") else 0
            row = {
                "order_status": status,
                "dealt_qty": dealt,
                "dealt_avg_price": 283.2,
                "last_err_msg": "",
                "code": "US.VTI",
                "qty": 0.017,
                "price": 283.1,
            }
            return 0, Frame([row])

        def close(self):
            pass

    m.OpenQuoteContext = Quote
    m.OpenSecTradeContext = Trade
    return m


def test_moomoo_buys_a_share_count_on_paper_and_reports_the_fill(monkeypatch):
    placed: list[dict] = []
    monkeypatch.setitem(sys.modules, "moomoo", fake_moomoo(["SUBMITTED", "FILLED_ALL"], placed))
    from backend.providers.moomoo import MoomooBroker

    b = MoomooBroker(paper=True, wait_seconds=5)
    rec = b.buy("VTI", 500, "casino scratch 1")
    assert placed[0]["trd_side"] == "BUY"
    assert placed[0]["trd_env"] == "SIMULATE"
    assert placed[0]["order_type"] == "MARKET"
    assert placed[0]["acc_id"] == 8  # the paper stock account, not options or real
    assert placed[0]["code"] == "US.VTI"
    assert placed[0]["qty"] == 0.017
    assert rec["status"] == "filled"
    assert rec["target_cents"] == 500
    assert rec["filled_cents"] == 481  # 0.017 x 283.20 = 4.8144
    assert rec["leftover_cents"] == 19
    assert rec["qty_sent"] == "0.017"


def test_moomoo_never_pretends_an_open_order_filled(monkeypatch):
    placed: list[dict] = []
    stuck = ["SUBMITTED"] * 100
    monkeypatch.setitem(sys.modules, "moomoo", fake_moomoo(stuck, placed))
    from backend.providers.moomoo import MoomooBroker

    rec = MoomooBroker(paper=True, wait_seconds=0).buy("VTI", 500, "t")
    assert rec["status"] == "open"
    assert rec["filled_cents"] == 0
    assert rec["leftover_cents"] == 0


def test_moomoo_reports_a_rejection(monkeypatch):
    placed: list[dict] = []
    monkeypatch.setitem(sys.modules, "moomoo", fake_moomoo(["FAILED"], placed))
    from backend.providers.moomoo import MoomooBroker

    rec = MoomooBroker(paper=True, wait_seconds=0).buy("VTI", 500, "t")
    assert rec["status"] == "rejected"
    assert "FAILED" in rec["message"]
