"""content/buildings.json: the buildings, their tiers, what each tier asks and what it changes."""

import json
from functools import cache

from backend.content import CONTENT

PATH = CONTENT / "buildings.json"

# Dollar requirements: the own accounts whose balances each one sums.
BALANCE_KEYS: dict[str, tuple[str, ...]] = {
    "savings_cents": ("sav_1", "sav_2"),
    "house_fund_cents": ("sav_1",),
    "emergency_cents": ("sav_2",),
    "brokerage_cents": ("brk_1",),
}
# Which deposits count toward a dollar requirement (for the target's streak).
DEPOSIT_KIND = {
    "savings_cents": "savings",
    "house_fund_cents": "savings",
    "emergency_cents": "savings",
    "brokerage_cents": "brokerage",
}
ANY_DEPOSIT = ("savings", "brokerage")
REQUIREMENT_KEYS = (*BALANCE_KEYS, "deposit_streak_weeks", "land", "buildings")
LABELS = {
    "savings_cents": "Savings",
    "house_fund_cents": "House Fund",
    "emergency_cents": "Emergency Fund",
    "brokerage_cents": "Brokerage",
    "deposit_streak_weeks": "Weeks in a row",
    "land": "Land",
}


@cache
def content() -> dict:
    return json.loads(PATH.read_text())


def buildings() -> list[dict]:
    return content()["buildings"]


def building(building_id: str) -> dict | None:
    return next((b for b in buildings() if b["id"] == building_id), None)


def tier(building_id: str, n: int) -> dict | None:
    """Tier n (numbered from 1) of a building, or None past its last tier."""
    b = building(building_id)
    if b is None or n < 1 or n > len(b["tiers"]):
        return None
    return b["tiers"][n - 1]


def max_tier(building_id: str) -> int:
    b = building(building_id)
    return len(b["tiers"]) if b else 0


def streak_rules() -> dict:
    s = content().get("streak", {})
    return {
        "discount_weeks": int(s.get("discount_weeks", 6)),
        "discount": float(s.get("discount", 0.2)),
        "min_cents": int(s.get("min_cents", 1)),
    }


def has_dollars(t: dict) -> bool:
    return any(k in BALANCE_KEYS for k in t.get("requires", {}))


def toward_kinds(t: dict | None) -> tuple[str, ...]:
    """The deposit kinds that count toward a tier: the accounts its dollar requirements name.
    A tier with no dollar requirement (or no tier at all) takes any deposit."""
    if t is None:
        return ANY_DEPOSIT
    kinds = {DEPOSIT_KIND[k] for k in t.get("requires", {}) if k in DEPOSIT_KIND}
    return tuple(k for k in ANY_DEPOSIT if k in kinds) or ANY_DEPOSIT


def discounted(base_cents: int, discount: float) -> int:
    """A dollar requirement after the discount, rounded to whole dollars."""
    return round(base_cents * (1 - discount) / 100) * 100
