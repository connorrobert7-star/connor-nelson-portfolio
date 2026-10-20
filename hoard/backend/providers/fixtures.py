"""Demo implementations of every provider.

Deterministic: the same date always produces the same data, so the demo clock
can move forward forever. `anchor` is the day the save was created. The week
before it is scripted so the village opens on a known story: groceries over
budget, a quiet tavern, a new StreamBox+ subscription, and a payday transfer to
savings. Every other day is seeded-random, with each week leaning thrifty,
normal or splurgy.
"""

import json
import math
import random
import statistics
from datetime import date, timedelta
from functools import cache

from backend.content import CONTENT
from backend.core.dates import is_monthly_on, week_start

HISTORY_DAYS = 90
OPENING_CHECKING_CENTS = 100_000
OPENING_SAVINGS_CENTS = 705_000
CARD_LIMIT_CENTS = 320_000

MONTHLY_BILLS: dict[int, list[tuple[str, int, str]]] = {
    1: [
        ("Maple Court Apartments", 165_000, "RENT_AND_UTILITIES_RENT"),
        ("Iron Gym", 4_000, "PERSONAL_CARE_GYMS_AND_FITNESS_CENTERS"),
    ],
    3: [("Netflix", 1_549, "ENTERTAINMENT_TV_AND_MOVIES")],
    5: [("Student loan payment", 16_200, "LOAN_PAYMENTS_STUDENT_LOAN_PAYMENT")],
    8: [("Mobile Co", 4_500, "RENT_AND_UTILITIES_TELEPHONE")],
    9: [("Spotify", 1_199, "ENTERTAINMENT_MUSIC_AND_AUDIO")],
    12: [("Car loan payment", 28_500, "LOAN_PAYMENTS_CAR_PAYMENT")],
    20: [("Fibernet", 6_500, "RENT_AND_UTILITIES_INTERNET_AND_CABLE")],
    22: [("Credit card payment", 3_500, "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT")],
}

# Days before the anchor -> purchases. The scripted week.
SCRIPTED: dict[int, list[tuple[str, int, str]]] = {
    -7: [("Green Basket Market", 6_120, "FOOD_AND_DRINK_GROCERIES")],
    -6: [("Blue Door Cafe", 575, "FOOD_AND_DRINK_COFFEE")],
    -5: [("Fuel Stop", 4_130, "TRANSPORTATION_GAS")],
    -4: [("Green Basket Market", 5_275, "FOOD_AND_DRINK_GROCERIES")],
    -3: [
        ("Taqueria Sol", 1_840, "FOOD_AND_DRINK_RESTAURANT"),
        ("Amazon", 2_399, "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"),
    ],
    -2: [
        ("Blue Door Cafe", 625, "FOOD_AND_DRINK_COFFEE"),
        ("Corner Grocer", 3_610, "FOOD_AND_DRINK_GROCERIES"),
    ],
    -1: [],
}
NEW_SUBSCRIPTION = ("StreamBox+", 1_799, "ENTERTAINMENT_TV_AND_MOVIES", -6)
PAYDAY_OFFSET = -4  # a payday falls 4 days before the anchor, then every 14 days

GROCERS = ["Green Basket Market", "Corner Grocer", "Hilltop Foods"]
RESTAURANTS = [
    ("Taqueria Sol", "FOOD_AND_DRINK_RESTAURANT"),
    ("Noodle House", "FOOD_AND_DRINK_RESTAURANT"),
    ("DoorDash", "FOOD_AND_DRINK_RESTAURANT"),
    ("Burger Barn", "FOOD_AND_DRINK_FAST_FOOD"),
]
MOODS = [("thrifty", 0.65), ("normal", 1.0), ("normal", 1.0), ("splurge", 1.4)]

DEBTS = [
    # id, name, kind, opening balance at history start, apr, min payment, due day
    ("debt_card", "Credit card", "credit", 129_000, 24.9, 3_500, 22),
    ("debt_car", "Car loan", "auto", 740_000, 6.9, 28_500, 12),
    ("debt_student", "Student loan", "student", 1_460_000, 5.5, 16_200, 5),
]


def _rng(*parts: object) -> random.Random:
    return random.Random("hoard|" + "|".join(str(p) for p in parts))


def _cents(lo: float, hi: float, rng: random.Random) -> int:
    return round(rng.uniform(lo, hi) * 100)


def history_start(anchor: date) -> date:
    return anchor - timedelta(days=HISTORY_DAYS)


def week_mood(d: date) -> tuple[str, float]:
    return _rng("mood", week_start(d)).choice(MOODS)


def day_purchases(anchor: date, d: date) -> list[tuple[str, int, str]]:
    out: list[tuple[str, int, str]] = []
    for day, bills in MONTHLY_BILLS.items():
        if is_monthly_on(d, day):
            out.extend(bills)
    if d.day == 15:
        out.append(
            (
                "City Power",
                _cents(78, 112, _rng("power", d)),
                "RENT_AND_UTILITIES_GAS_AND_ELECTRICITY",
            )
        )
    merchant, cents, category, offset = NEW_SUBSCRIPTION
    first = anchor + timedelta(days=offset)
    if d >= first and is_monthly_on(d, first.day):
        out.append((merchant, cents, category))
    if (d - (anchor + timedelta(days=PAYDAY_OFFSET))).days % 14 == 0:
        out.append(("Acme Corp Payroll", -210_000, "INCOME_WAGES"))
        out.append(("Transfer to House Fund", 20_000, "TRANSFER_OUT_SAVINGS"))
        out.append(
            ("Transfer to Brokerage", 15_000, "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS")
        )
    offset_days = (d - anchor).days
    if offset_days in SCRIPTED:
        out.extend(SCRIPTED[offset_days])
        return out
    rng = _rng("day", d)
    _, m = week_mood(d)
    if rng.random() < 0.33 * m:
        out.append((rng.choice(GROCERS), _cents(22, 70 * m, rng), "FOOD_AND_DRINK_GROCERIES"))
    if rng.random() < 0.28 * m:
        merchant, category = rng.choice(RESTAURANTS)
        out.append((merchant, _cents(12, 42 * m, rng), category))
    if rng.random() < 0.35 * m:
        out.append(("Blue Door Cafe", _cents(4.5, 7, rng), "FOOD_AND_DRINK_COFFEE"))
    if d.weekday() == 5 and rng.random() < 0.8:
        out.append(("Fuel Stop", _cents(32, 48, rng), "TRANSPORTATION_GAS"))
    if rng.random() < 0.1 * m:
        out.append(("Amazon", _cents(9, 60 * m, rng), "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"))
    return out


class FixtureBank:
    name = "fixture"

    def transactions(self, anchor: date, start: date, end: date) -> list[dict]:
        out = []
        d = max(start, history_start(anchor))
        while d <= end:
            for i, (merchant, cents, category) in enumerate(day_purchases(anchor, d)):
                out.append(
                    {
                        "id": f"txn_{d.isoformat()}_{i}",
                        "account_id": "chk_1",
                        "date": d.isoformat(),
                        "amount_cents": cents,
                        "merchant": merchant,
                        "category": category,
                    }
                )
            d += timedelta(days=1)
        return out

    def accounts(self, anchor: date, today: date) -> list[dict]:
        txns = self.transactions(anchor, history_start(anchor), today - timedelta(days=1))
        spent = sum(t["amount_cents"] for t in txns)
        saved = sum(t["amount_cents"] for t in txns if t["category"] == "TRANSFER_OUT_SAVINGS")
        return [
            {
                "id": "chk_1",
                "kind": "checking",
                "name": "Everyday Checking",
                "balance_cents": OPENING_CHECKING_CENTS - spent,
            },
            {
                "id": "sav_1",
                "kind": "savings",
                "name": "House Fund",
                "balance_cents": OPENING_SAVINGS_CENTS + saved,
            },
        ]

    def liabilities(self, anchor: date, today: date) -> list[dict]:
        out = []
        for debt_id, name, kind, opening, apr, min_pay, due_day in DEBTS:
            balance = opening
            d = history_start(anchor)
            while d < today:
                if is_monthly_on(d, due_day):
                    balance = max(0, round(balance * (1 + apr / 1200)) - min_pay)
                d += timedelta(days=1)
            row = {
                "id": debt_id,
                "name": name,
                "kind": kind,
                "balance_cents": balance,
                "apr": apr,
                "min_payment_cents": min_pay,
                "due_day": due_day,
            }
            if kind == "credit":
                row["limit_cents"] = CARD_LIMIT_CENTS
            out.append(row)
        return out


@cache
def _market_file() -> dict:
    return json.loads((CONTENT / "market.json").read_text())


class FixtureMarket:
    name = "fixture"

    def catalog(self) -> list[dict]:
        return _market_file()["tickers"]

    def _ticker(self, symbol: str) -> dict:
        for t in self.catalog():
            if t["symbol"] == symbol:
                return t
        raise KeyError(symbol)

    def weekly_price_cents(self, symbol: str, week: date, anchor: date) -> int:
        t = self._ticker(symbol)
        returns = t["annual_returns"]
        mu = math.log1p(statistics.mean(returns)) / 52
        sigma = statistics.pstdev(returns) / math.sqrt(52)
        steps = (week_start(week) - week_start(anchor)).days // 7
        log_price = math.log(t["price_cents"])
        for i in range(min(0, steps), max(0, steps)):
            step = mu + sigma * _rng("price", symbol, i).gauss(0, 1)
            log_price += step if steps > 0 else -step
        return max(1, round(math.exp(log_price)))


BASE_HOLDINGS = [("VTI", 42.5), ("VXUS", 61.0), ("AAPL", 18.0), ("MSFT", 14.0), ("SCHD", 192.0)]


class FixtureBrokerage:
    name = "fixture"

    def __init__(self, market: FixtureMarket, bank: FixtureBank) -> None:
        self.market = market
        self.bank = bank

    def holdings(self, anchor: date, today: date) -> list[dict]:
        qty = dict(BASE_HOLDINGS)
        for t in self.bank.transactions(anchor, history_start(anchor), today - timedelta(days=1)):
            if t["category"] == "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS":
                price = self.market.weekly_price_cents("VTI", date.fromisoformat(t["date"]), anchor)
                qty["VTI"] += t["amount_cents"] / price
        week = week_start(today)
        return [
            {
                "id": f"hld_{symbol}",
                "account_id": "brk_1",
                "symbol": symbol,
                "qty": round(q, 6),
                "value_cents": round(q * self.market.weekly_price_cents(symbol, week, anchor)),
                "as_of": week.isoformat(),
            }
            for symbol, q in qty.items()
        ]


class SimulatedTransfers:
    name = "simulated"
    simulated = True

    def submit(self, from_account: str, to_account: str, amount_cents: int, reason: str) -> dict:
        return {"status": "simulated"}


class FixtureAdvisor:
    name = "fixture"

    def money_ideas(self, facts: dict) -> list[dict]:
        return []

    def stock_story(self, ticker: dict, facts: dict) -> str:
        return ticker.get("story", "")


class FixtureCredit:
    """A simple scoring model over the player's own numbers. Not a real FICO score."""

    name = "fixture"

    def report(self, anchor: date, today: date, facts: dict) -> dict:
        utilization = facts.get("utilization", 0.4)
        on_time = facts.get("on_time_rate", 0.97)
        age_years = facts.get("oldest_account_years", 5.2)
        inquiries = facts.get("hard_inquiries", 2)
        score = (
            720
            - round(max(0.0, utilization - 0.1) * 220)
            - round((1 - on_time) * 900)
            + round(min(age_years, 15) * 4)
            - inquiries * 6
        )
        score = max(300, min(850, score))
        history = []
        month = date(today.year, today.month, 1)
        for i in range(11, -1, -1):
            m = month
            for _ in range(i):
                m = (m - timedelta(days=1)).replace(day=1)
            drift = round(_rng("credit", m).uniform(-9, 9)) + i * 2
            history.append({"month": m.isoformat()[:7], "score": max(300, min(850, score - drift))})
        history[-1]["score"] = score
        return {
            "score": score,
            "history": history,
            "factors": {
                "utilization": round(utilization, 3),
                "on_time_rate": on_time,
                "oldest_account_years": age_years,
                "hard_inquiries": inquiries,
            },
        }


@cache
def _life_file() -> dict:
    return json.loads((CONTENT / "life_table.json").read_text())


class SsaLifeTable:
    name = "ssa"

    def remaining_years(self, age_years: float, sex: str) -> float:
        table = _life_file()
        if sex in ("male", "female"):
            series = table[sex]
        else:
            series = [(m + f) / 2 for m, f in zip(table["male"], table["female"], strict=True)]
        lo = max(0, min(len(series) - 1, int(age_years)))
        hi = min(len(series) - 1, lo + 1)
        frac = age_years - lo
        return series[lo] * (1 - frac) + series[hi] * frac
