"""Turn a week of transactions into what the village looks like.

Reactions are small, daily, and reversible. The game renders the states named
here; it never decides them itself.
"""

import sqlite3
from datetime import date, timedelta

from backend.content import CategoryMap

DRAIN_LOOKBACK_DAYS = 30


def week_window(today: date, weeks_ago: int) -> tuple[date, date]:
    """The seven days ending yesterday, or that many weeks before."""
    end = today - timedelta(days=1 + 7 * weeks_ago)
    return end - timedelta(days=6), end


def _rows(conn: sqlite3.Connection, start: date, end: date) -> list[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM transactions WHERE date BETWEEN ? AND ? ORDER BY date, merchant",
        [start.isoformat(), end.isoformat()],
    ).fetchall()


def _ratio(spent: int, budget: int) -> float:
    return round(spent / budget, 3) if budget else 0.0


def crops_state(ratio: float) -> str:
    if ratio <= 0.75:
        return "bumper"
    if ratio <= 1.0:
        return "healthy"
    if ratio <= 1.3:
        return "wilting"
    return "withered"


def week_ledger(conn: sqlite3.Connection, cmap: CategoryMap, start: date, end: date) -> dict:
    by_system: dict[str, int] = {}
    ledger = []
    for r in _rows(conn, start, end):
        system = cmap.system_for(r["category"]) or "other"
        by_system[system] = by_system.get(system, 0) + r["amount_cents"]
        ledger.append(
            {
                "date": r["date"],
                "merchant": r["merchant"],
                "amount_cents": r["amount_cents"],
                "system": system,
            }
        )
    money_in = -sum(t["amount_cents"] for t in ledger if t["amount_cents"] < 0)
    money_out = sum(t["amount_cents"] for t in ledger if t["amount_cents"] > 0)
    return {
        "by_system": by_system,
        "transactions": ledger,
        "in_cents": money_in,
        "out_cents": money_out,
    }


def _crops(cmap: CategoryMap, by_system: dict[str, int]) -> dict:
    budget = cmap.systems["crops"]["budget_cents"]
    spent = by_system.get("crops", 0)
    ratio = _ratio(spent, budget)
    return {
        "spent_cents": spent,
        "budget_cents": budget,
        "ratio": ratio,
        "state": crops_state(ratio),
    }


def _tavern(cmap: CategoryMap, ledger: list[dict], by_system: dict[str, int]) -> dict:
    budget = cmap.systems["tavern"]["budget_cents"]
    spent = by_system.get("tavern", 0)
    return {
        "spent_cents": spent,
        "budget_cents": budget,
        "ratio": _ratio(spent, budget),
        "visits": sum(1 for t in ledger if t["system"] == "tavern"),
        "state": "packed" if spent > budget else "quiet",
    }


def _drains(conn: sqlite3.Connection, cmap: CategoryMap, start: date, end: date) -> dict:
    """One drain per subscription charged in the 30 days up to the end of the week."""
    cats = cmap.categories_for("drains")
    lookback = end - timedelta(days=DRAIN_LOOKBACK_DAYS - 1)
    rows = conn.execute(
        f"""SELECT merchant,
                   MAX(date) AS last_charged,
                   (SELECT MIN(date) FROM transactions f WHERE f.merchant = t.merchant
                      AND f.amount_cents > 0) AS first_charged,
                   SUM(amount_cents) AS amount_cents
            FROM transactions t
            WHERE category IN ({",".join("?" * len(cats))}) AND amount_cents > 0
              AND date BETWEEN ? AND ?
            GROUP BY merchant ORDER BY first_charged, merchant""",
        [*cats, lookback.isoformat(), end.isoformat()],
    ).fetchall()
    # A subscription is only "new" if there is a month of history before it.
    (history_start,) = conn.execute("SELECT MIN(date) FROM transactions").fetchone()
    known_since = (date.fromisoformat(history_start) + timedelta(days=31)).isoformat()
    drains = [
        {
            "merchant": r["merchant"],
            "amount_cents": r["amount_cents"],
            "last_charged": r["last_charged"],
            "charged_this_week": r["last_charged"] >= start.isoformat(),
            "new": r["first_charged"] >= max(start.isoformat(), known_since),
        }
        for r in rows
    ]
    budget = cmap.systems["drains"]["budget_cents"]
    total = sum(d["amount_cents"] for d in drains)
    return {
        "drains": drains,
        "monthly_cents": total,
        "budget_cents": budget,
        "ratio": _ratio(total, budget),
        "river": "low" if total > budget else "high",
    }


def village_reactions(
    conn: sqlite3.Connection, cmap: CategoryMap, today: date, weeks_ago: int = 0
) -> dict:
    start, end = week_window(today, weeks_ago)
    week = week_ledger(conn, cmap, start, end)
    by_system = week["by_system"]
    saved = by_system.get("shrine", 0)
    return {
        "window": {"start": start.isoformat(), "end": end.isoformat(), "weeks_ago": weeks_ago},
        "week": week,
        "crops": _crops(cmap, by_system),
        "tavern": _tavern(cmap, week["transactions"], by_system),
        "drains": _drains(conn, cmap, start, end),
        "shrine": {"saved_cents": saved, "state": "glowing" if saved > 0 else "dim"},
    }
