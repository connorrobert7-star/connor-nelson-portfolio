from datetime import date

from backend.content import category_map
from backend.money.budget import FLOOR_CENTS, add_month, compute_extra, week_start
from backend.tests.conftest import TODAY


def test_add_month_clamps():
    assert add_month(date(2026, 1, 31)) == date(2026, 2, 28)
    assert add_month(date(2026, 12, 15)) == date(2027, 1, 15)


def test_week_starts_sunday():
    assert week_start(date(2026, 10, 20)) == date(2026, 10, 18)
    assert week_start(date(2026, 10, 18)) == date(2026, 10, 18)


def test_extra_formula(conn):
    e = compute_extra(conn, TODAY, category_map())
    assert e["extra_cents"] == (
        e["checking_cents"]
        - e["bills_due_cents"]
        - FLOOR_CENTS
        - e["avg_weekly_food_transport_cents"]
    )
    assert e["bills_due_cents"] == sum(b["amount_cents"] for b in e["bills"])
    assert e["spendable_cents"] == min(e["extra_cents"], e["cap_remaining_cents"])


def test_rent_is_a_bill_due_within_14_days(conn):
    bills = compute_extra(conn, TODAY, category_map())["bills"]
    rent = [b for b in bills if b["merchant"] == "Maple Court Apartments"]
    assert rent and rent[0]["due"] == "2026-11-01"
    assert all(b["due"] <= "2026-11-03" for b in bills)


def test_spendable_never_negative(conn):
    conn.execute("UPDATE accounts SET balance_cents = 0 WHERE kind = 'checking'")
    e = compute_extra(conn, TODAY, category_map())
    assert e["extra_cents"] < 0
    assert e["spendable_cents"] == 0
