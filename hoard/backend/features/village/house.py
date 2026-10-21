"""The house: built in stages as the House Fund grows toward the down payment.

The stage follows the real balance, but a built stage never unbuilds: the highest
stage ever reached is kept in meta. The next stage's outline fills in rows up to
the true balance, so every deposit shows on the house the next time you look.
"""

import json
from functools import cache

from backend.content import CONTENT
from backend.core.context import Ctx
from backend.money.budget import balances

BUILT_KEY = "village_house_built"
SEEN_KEY = "village_house_seen"


@cache
def house_config() -> dict:
    return json.loads((CONTENT / "village" / "house.json").read_text())


def stage_index(stages: list[dict], balance_cents: int) -> int:
    """The last stage whose threshold the balance has reached."""
    index = 0
    for i, stage in enumerate(stages):
        if balance_cents >= stage["at_cents"]:
            index = i
    return index


def house_view(cfg: dict, balance_cents: int, built: int, seen: int) -> dict:
    """Everything the game draws for the house, from the balance and the high-water stage."""
    stages = cfg["stages"]
    index = max(stage_index(stages, balance_cents), built)
    stage = stages[index]
    nxt = stages[index + 1] if index + 1 < len(stages) else None
    fill = 1.0
    if nxt:
        span = nxt["at_cents"] - stage["at_cents"]
        fill = min(1.0, max(0.0, (balance_cents - stage["at_cents"]) / span))
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
                "at_cents": nxt["at_cents"],
                "to_go_cents": max(0, nxt["at_cents"] - balance_cents),
            }
            if nxt
            else None
        ),
        "fill": round(fill, 4),
        "rows": int(rows_total * fill) if nxt else rows_total,
        "rows_total": rows_total,
        "seen_index": min(seen, index),
        "building": index > seen,
        "done": nxt is None,
    }


def house_balance(ctx: Ctx) -> int:
    return balances(ctx).get(house_config()["account"], 0)


def house_state(ctx: Ctx) -> dict:
    cfg = house_config()
    balance = house_balance(ctx)
    built = int(ctx.meta(BUILT_KEY) or 0)
    current = max(built, stage_index(cfg["stages"], balance))
    seen = int(ctx.meta(SEEN_KEY) or current)
    return house_view(cfg, balance, built, seen)


def record_built(ctx: Ctx) -> tuple[int, int]:
    """Keep the high-water stage. Returns (stage before, stage now)."""
    cfg = house_config()
    before = int(ctx.meta(BUILT_KEY) or 0)
    now = max(before, stage_index(cfg["stages"], house_balance(ctx)))
    ctx.set_meta(BUILT_KEY, str(now))
    return before, now
