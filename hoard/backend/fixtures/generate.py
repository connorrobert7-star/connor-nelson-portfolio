"""Regenerate the Phase 0 fixtures: 90 days of fake transactions, three accounts,
five holdings, one debt.

    python -m backend.fixtures.generate

Output is deterministic. Days before the final week are seeded-random so paging
back through weeks shows variety. The final week is scripted so the village has
a known story: groceries over budget (crops wilt), restaurants under (tavern is
quiet), a new streaming subscription (a new drain), and a payday transfer to
savings (the shrine glows).
"""

import json
import random
from datetime import date, timedelta
from pathlib import Path

HERE = Path(__file__).parent
END = date(2026, 10, 19)  # loader shifts this to "yesterday"
START = END - timedelta(days=89)
LAST_WEEK = END - timedelta(days=6)
PAYDAY = date(2026, 10, 16)  # a Friday; paychecks every 14 days

MONTHLY = {
    1: [
        ("Maple Court Apartments", 1650.00, "RENT_AND_UTILITIES_RENT"),
        ("Iron Gym", 40.00, "PERSONAL_CARE_GYMS_AND_FITNESS_CENTERS"),
    ],
    3: [("Netflix", 15.49, "ENTERTAINMENT_TV_AND_MOVIES")],
    8: [("Mobile Co", 45.00, "RENT_AND_UTILITIES_TELEPHONE")],
    9: [("Spotify", 11.99, "ENTERTAINMENT_MUSIC_AND_AUDIO")],
    12: [("Car loan payment", 285.00, "LOAN_PAYMENTS_CAR_PAYMENT")],
    20: [("Fibernet", 65.00, "RENT_AND_UTILITIES_INTERNET_AND_CABLE")],
}

SCRIPTED_LAST_WEEK = [
    (date(2026, 10, 13), "Green Basket Market", 61.20, "FOOD_AND_DRINK_GROCERIES"),
    (date(2026, 10, 14), "Blue Door Cafe", 5.75, "FOOD_AND_DRINK_COFFEE"),
    (date(2026, 10, 14), "StreamBox+", 17.99, "ENTERTAINMENT_TV_AND_MOVIES"),
    (date(2026, 10, 15), "Fuel Stop", 41.30, "TRANSPORTATION_GAS"),
    (date(2026, 10, 16), "Green Basket Market", 52.75, "FOOD_AND_DRINK_GROCERIES"),
    (date(2026, 10, 17), "Taqueria Sol", 18.40, "FOOD_AND_DRINK_RESTAURANT"),
    (date(2026, 10, 17), "Amazon", 23.99, "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"),
    (date(2026, 10, 18), "Blue Door Cafe", 6.25, "FOOD_AND_DRINK_COFFEE"),
    (date(2026, 10, 18), "Corner Grocer", 36.10, "FOOD_AND_DRINK_GROCERIES"),
]

GROCERS = ["Green Basket Market", "Corner Grocer", "Hilltop Foods"]
RESTAURANTS = [
    ("Taqueria Sol", "FOOD_AND_DRINK_RESTAURANT"),
    ("Noodle House", "FOOD_AND_DRINK_RESTAURANT"),
    ("DoorDash", "FOOD_AND_DRINK_RESTAURANT"),
    ("Burger Barn", "FOOD_AND_DRINK_FAST_FOOD"),
]


def transactions() -> list[dict]:
    rng = random.Random(7)
    out: list[tuple[date, str, float, str]] = []
    day = START
    while day <= END:
        for merchant, amount, category in MONTHLY.get(day.day, []):
            out.append((day, merchant, amount, category))
        if day.day == 15:
            out.append(
                (
                    day,
                    "City Power",
                    round(rng.uniform(78, 112), 2),
                    "RENT_AND_UTILITIES_GAS_AND_ELECTRICITY",
                )
            )
        if (PAYDAY - day).days % 14 == 0:
            out.append((day, "Acme Corp Payroll", -2450.00, "INCOME_WAGES"))
            out.append((day, "Transfer to House Fund", 200.00, "TRANSFER_OUT_SAVINGS"))
            out.append(
                (
                    day,
                    "Transfer to Brokerage",
                    150.00,
                    "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS",
                )
            )
        if day < LAST_WEEK:
            if rng.random() < 0.33:
                out.append(
                    (
                        day,
                        rng.choice(GROCERS),
                        round(rng.uniform(22, 70), 2),
                        "FOOD_AND_DRINK_GROCERIES",
                    )
                )
            if rng.random() < 0.28:
                merchant, category = rng.choice(RESTAURANTS)
                out.append((day, merchant, round(rng.uniform(12, 42), 2), category))
            if rng.random() < 0.35:
                out.append(
                    (day, "Blue Door Cafe", round(rng.uniform(4.5, 7), 2), "FOOD_AND_DRINK_COFFEE")
                )
            if day.weekday() == 5 and rng.random() < 0.8:
                out.append((day, "Fuel Stop", round(rng.uniform(32, 48), 2), "TRANSPORTATION_GAS"))
            if rng.random() < 0.1:
                out.append(
                    (
                        day,
                        "Amazon",
                        round(rng.uniform(9, 60), 2),
                        "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES",
                    )
                )
        day += timedelta(days=1)
    out.extend(SCRIPTED_LAST_WEEK)
    out.sort(key=lambda t: (t[0], t[1]))
    return [
        {
            "id": f"txn_{i:04d}",
            "account_id": "chk_1",
            "date": d.isoformat(),
            "amount": amount,
            "merchant": merchant,
            "category": category,
        }
        for i, (d, merchant, amount, category) in enumerate(out)
    ]


ACCOUNTS = [
    {"id": "chk_1", "kind": "checking", "name": "Everyday Checking", "balance": 3412.18},
    {"id": "sav_1", "kind": "savings", "name": "House Fund", "balance": 8250.00},
    {"id": "brk_1", "kind": "brokerage", "name": "Brokerage", "balance": 31840.40},
]

HOLDINGS = [
    {"id": "hld_1", "account_id": "brk_1", "symbol": "VTI", "qty": 42.5, "value": 12031.75},
    {"id": "hld_2", "account_id": "brk_1", "symbol": "VXUS", "qty": 61.0, "value": 4026.00},
    {"id": "hld_3", "account_id": "brk_1", "symbol": "AAPL", "qty": 18.0, "value": 4154.40},
    {"id": "hld_4", "account_id": "brk_1", "symbol": "MSFT", "qty": 14.0, "value": 6342.00},
    {"id": "hld_5", "account_id": "brk_1", "symbol": "SCHD", "qty": 192.0, "value": 5286.25},
]

DEBTS = [
    {"id": "debt_1", "name": "Car loan", "balance": 6840.00, "apr": 6.9, "min_payment": 285.00},
]


def main() -> None:
    as_of = END - timedelta(days=(END.weekday() + 1) % 7)  # most recent Sunday
    files = {
        "fake_transactions.json": {"end_date": END.isoformat(), "transactions": transactions()},
        "fake_accounts.json": {"accounts": ACCOUNTS, "debts": DEBTS},
        "fake_holdings.json": {"as_of": as_of.isoformat(), "holdings": HOLDINGS},
    }
    for name, body in files.items():
        (HERE / name).write_text(json.dumps(body, indent=1) + "\n")


if __name__ == "__main__":
    main()
