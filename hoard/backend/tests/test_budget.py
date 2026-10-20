from datetime import date

from backend.core.dates import add_month, is_monthly_on, week_start
from backend.money.budget import FLOOR_CENTS, balances, compute_extra, hourly_rate_cents
from backend.money.transfer import move


def test_dates():
    assert add_month(date(2026, 1, 31)) == date(2026, 2, 28)
    assert add_month(date(2026, 12, 15)) == date(2027, 1, 15)
    assert week_start(date(2026, 10, 20)) == date(2026, 10, 18)
    assert is_monthly_on(date(2026, 2, 28), 31)


def test_extra_formula(ctx):
    e = compute_extra(ctx)
    assert e["extra_cents"] == (
        e["checking_cents"]
        - e["bills_due_cents"]
        - FLOOR_CENTS
        - e["avg_weekly_food_transport_cents"]
    )
    assert e["bills_due_cents"] == sum(b["amount_cents"] for b in e["bills"])


def test_rent_is_a_bill_due_within_14_days(ctx):
    bills = compute_extra(ctx)["bills"]
    assert any(
        b["merchant"] == "Maple Court Apartments" and b["due"] == "2026-11-01" for b in bills
    )
    assert all(b["due"] <= "2026-11-03" for b in bills)


def test_hourly_rate_from_paychecks(ctx):
    # Two $2,100 paychecks in four weeks, 40 hours a week.
    assert hourly_rate_cents(ctx) == 2_625


def test_game_transfers_change_effective_balances_only(ctx):
    before_rows = [tuple(r) for r in ctx.conn.execute("SELECT * FROM accounts")]
    before = balances(ctx)
    move(ctx, "chk_1", "debt_card", 5_000, "test", {"type": "test"})
    after = balances(ctx)
    assert after["chk_1"] == before["chk_1"] - 5_000
    assert after["debt_card"] == before["debt_card"] - 5_000
    assert [tuple(r) for r in ctx.conn.execute("SELECT * FROM accounts")] == before_rows
