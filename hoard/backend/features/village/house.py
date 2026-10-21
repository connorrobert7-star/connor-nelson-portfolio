"""The house: the House Fund's building, in stages toward the down payment.

The house is one of the buildings (backend/features/buildings): each stage is a tier whose
requirement is a House Fund balance, checked at the Sunday sync, and then costs coins and real
days to build. A built stage never unbuilds. The next stage's outline still fills in rows up to
the true balance (against its requirement after any streak discount), so every deposit shows on
the house the next time you look.
"""

import json
from functools import cache

from backend.content import CONTENT
from backend.core.context import Ctx
from backend.features import buildings
from backend.money.budget import balances

BUILDING = "house"
REQUIREMENT = "house_fund_cents"


@cache
def house_config() -> dict:
    return json.loads((CONTENT / "village" / "house.json").read_text())


def house_view(
    cfg: dict,
    balance_cents: int,
    built: int,
    seen: int,
    need_cents: int | None = None,
    constructing: bool = False,
    progress: float = 0.0,
) -> dict:
    """Everything the game draws for the house. `built` and `seen` are stage indexes (the
    building's tier minus one); `need_cents` is the next stage's requirement after any discount."""
    stages = cfg["stages"]
    index = max(0, min(built, len(stages) - 1))
    stage = stages[index]
    nxt = stages[index + 1] if index + 1 < len(stages) else None
    fill = 1.0
    need = None
    if nxt:
        need = nxt["at_cents"] if need_cents is None else need_cents
        span = need - stage["at_cents"]
        if span > 0:
            fill = min(1.0, max(0.0, (balance_cents - stage["at_cents"]) / span))
        else:
            fill = 1.0 if balance_cents >= need else 0.0
    rows_total = int(cfg.get("rows", 32))
    return {
        "account": cfg["account"],
        "balance_cents": balance_cents,
        "goal_cents": cfg["goal_cents"],
        "goal_name": cfg["goal_name"],
        "stages": [{"id": s["id"], "name": s["name"], "at_cents": s["at_cents"]} for s in stages],
        "index": index,
        "stage": {"id": stage["id"], "name": stage["name"], "at_cents": stage["at_cents"]},
        "next": (
            {
                "id": nxt["id"],
                "name": nxt["name"],
                "at_cents": need,
                "base_cents": nxt["at_cents"],
                "to_go_cents": max(0, (need or 0) - balance_cents),
            }
            if nxt
            else None
        ),
        "fill": round(fill, 4),
        "rows": int(rows_total * fill) if nxt else rows_total,
        "rows_total": rows_total,
        "seen_index": max(0, min(seen, index)),
        "building": index > seen,
        "done": nxt is None,
        "constructing": constructing,
        "progress": progress,
    }


def house_state(ctx: Ctx) -> dict:
    cfg = house_config()
    entry = buildings.entry(ctx, BUILDING)
    rows = entry["next"]["requires"] if entry["next"] else []
    need = next((r["need"] for r in rows if r["key"] == REQUIREMENT), None)
    return house_view(
        cfg,
        balances(ctx).get(cfg["account"], 0),
        built=entry["tier"] - 1,
        seen=entry["seen_tier"] - 1,
        need_cents=need,
        constructing=entry["constructing"],
        progress=entry["progress"],
    )
