"""The casino's static data: the cosmetics (content/casino/items.json) and the machines
(content/casino/machines.json)."""

import json
from functools import cache

from backend.content import CONTENT

TIERS = ("common", "rare", "epic", "legendary", "mythic")
RANK = {t: i for i, t in enumerate(TIERS)}
COLORS = {
    "common": "#9aa0a6",
    "rare": "#3d8bff",
    "epic": "#a347ff",
    "legendary": "#ffb627",
    "mythic": "#ff2e3a",
}
WORDS = {"common": "grey", "rare": "blue", "epic": "purple", "legendary": "gold", "mythic": "red"}
# What the belt and box average out to, in percent (docs/CASINO.md).
TARGET_PCT = {"common": 67.0, "rare": 22.0, "epic": 7.5, "legendary": 2.2, "mythic": 0.7}
SLOTS = ("hat", "cloak", "aura", "charm", "follower_skin")
# Trade-ups go one tier up. Legendary stops there: mythic only comes from the box.
TRADE_UP = {"common": "rare", "rare": "epic", "epic": "legendary"}

DIR = CONTENT / "casino"


@cache
def _items_file() -> dict:
    return json.loads((DIR / "items.json").read_text())


@cache
def machines() -> dict:
    return json.loads((DIR / "machines.json").read_text())


@cache
def items_by_id() -> dict[str, dict]:
    return {i["id"]: i for i in _items_file()["items"]}


def items() -> list[dict]:
    return list(items_by_id().values())


def item(item_id: str) -> dict | None:
    return items_by_id().get(item_id)


@cache
def _of_tier(tier: str) -> tuple[str, ...]:
    return tuple(i["id"] for i in _items_file()["items"] if i["tier"] == tier)


def ids_of_tier(tier: str) -> tuple[str, ...]:
    return _of_tier(tier)


def sets() -> list[dict]:
    return _items_file()["sets"]


def tiers() -> list[dict]:
    return [
        {"id": t, "word": WORDS[t], "color": COLORS[t], "target_pct": TARGET_PCT[t]} for t in TIERS
    ]


def case(case_id: str) -> dict | None:
    return next((c for c in machines()["cases"] if c["id"] == case_id), None)


def book(price_cents: int) -> dict | None:
    return next((b for b in machines()["scratch"] if b["price_cents"] == price_cents), None)
