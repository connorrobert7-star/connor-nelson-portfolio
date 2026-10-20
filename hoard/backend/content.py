import json
from dataclasses import dataclass
from functools import cache
from pathlib import Path

CONTENT = Path(__file__).resolve().parent.parent / "content"


@dataclass(frozen=True)
class CategoryMap:
    systems: dict[str, dict]
    categories: dict[str, str]

    def system_for(self, category: str) -> str | None:
        return self.categories.get(category)

    def categories_for(self, *systems: str) -> list[str]:
        return [c for c, s in self.categories.items() if s in systems]

    def bill_categories(self) -> list[str]:
        bills = [name for name, s in self.systems.items() if s.get("bill")]
        return self.categories_for(*bills)


@cache
def category_map() -> CategoryMap:
    raw = json.loads((CONTENT / "categories.json").read_text())
    return CategoryMap(systems=raw["systems"], categories=raw["categories"])


@cache
def stock_catalog() -> dict[str, dict]:
    raw = json.loads((CONTENT / "stocks.json").read_text())
    return {
        s["symbol"]: {
            "symbol": s["symbol"],
            "name": s["name"],
            "kind": s["kind"],
            "price_cents": round(s["price"] * 100),
        }
        for s in raw["stocks"]
    }
