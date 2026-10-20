"""Phase 0 sync: load fixtures into SQLite instead of calling Plaid or SnapTrade.

Fixture dates are shifted so the fixture end date lands on yesterday, as if
the overnight sync just ran. The fixture tables are wiped and reloaded each time.
"""

import json
import sqlite3
from datetime import date, timedelta
from pathlib import Path

FIXTURES = Path(__file__).resolve().parent.parent / "fixtures"


def _cents(dollars: float) -> int:
    return round(dollars * 100)


def _load(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text())


def sync_from_fixtures(conn: sqlite3.Connection, today: date) -> None:
    txns = _load("fake_transactions.json")
    accounts = _load("fake_accounts.json")
    holdings = _load("fake_holdings.json")

    shift = (today - timedelta(days=1)) - date.fromisoformat(txns["end_date"])

    def moved(iso: str) -> str:
        return (date.fromisoformat(iso) + shift).isoformat()

    synced = (today - timedelta(days=1)).isoformat()
    with conn:
        for table in ("transactions", "holdings", "debts", "accounts"):
            conn.execute(f"DELETE FROM {table}")
        conn.executemany(
            "INSERT INTO accounts VALUES (?, 'fixture', ?, ?, ?, ?)",
            [
                (a["id"], a["kind"], a["name"], _cents(a["balance"]), synced)
                for a in accounts["accounts"]
            ],
        )
        conn.executemany(
            "INSERT INTO debts VALUES (?, ?, ?, ?, ?, NULL)",
            [
                (d["id"], d["name"], _cents(d["balance"]), d["apr"], _cents(d["min_payment"]))
                for d in accounts["debts"]
            ],
        )
        conn.executemany(
            "INSERT INTO transactions VALUES (?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    t["id"],
                    t["account_id"],
                    moved(t["date"]),
                    _cents(t["amount"]),
                    t["merchant"],
                    t["category"],
                    json.dumps(t),
                )
                for t in txns["transactions"]
            ],
        )
        conn.executemany(
            "INSERT INTO holdings VALUES (?, ?, ?, ?, ?, ?)",
            [
                (
                    h["id"],
                    h["account_id"],
                    h["symbol"],
                    h["qty"],
                    _cents(h["value"]),
                    moved(holdings["as_of"]),
                )
                for h in holdings["holdings"]
            ],
        )
