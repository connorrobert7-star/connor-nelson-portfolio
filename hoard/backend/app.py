"""FastAPI routes the game talks to. Phase 0: fixtures only, nothing moves money.

    uvicorn backend.app:app --reload

HOARD_TODAY=YYYY-MM-DD pins the date; HOARD_DB sets the SQLite path.
"""

import os
from contextlib import asynccontextmanager
from datetime import date
from pathlib import Path

from fastapi import FastAPI, HTTPException, Query

from backend import db
from backend.content import category_map
from backend.game.reactions import village_reactions
from backend.money.budget import compute_extra
from backend.sync.fixtures import sync_from_fixtures

DEFAULT_DB = Path(__file__).resolve().parent / "db" / "hoard.sqlite3"
HISTORY_WEEKS = 12  # 90 days of fixtures covers 12 full weeks


def create_app(db_path: str | Path | None = None, today: date | None = None) -> FastAPI:
    def current_day() -> date:
        if today:
            return today
        pinned = os.environ.get("HOARD_TODAY")
        return date.fromisoformat(pinned) if pinned else date.today()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        conn = db.connect(db_path or os.environ.get("HOARD_DB", DEFAULT_DB))
        sync_from_fixtures(conn, current_day())
        app.state.conn = conn
        yield
        conn.close()

    app = FastAPI(title="Hoard", lifespan=lifespan)

    @app.get("/state")
    def state(weeks_ago: int = Query(0, ge=0)) -> dict:
        if weeks_ago >= HISTORY_WEEKS:
            raise HTTPException(404, f"Only {HISTORY_WEEKS} weeks of history.")
        conn, cmap, day = app.state.conn, category_map(), current_day()
        house = conn.execute(
            "SELECT name, balance_cents FROM accounts WHERE kind = 'savings'"
        ).fetchone()
        return {
            "today": day.isoformat(),
            "history_weeks": HISTORY_WEEKS,
            "coins": 0,
            "extra": compute_extra(conn, day, cmap),
            "accounts": [dict(r) for r in conn.execute("SELECT * FROM accounts")],
            "holdings": [dict(r) for r in conn.execute("SELECT * FROM holdings")],
            "debts": [dict(r) for r in conn.execute("SELECT * FROM debts")],
            "house": {"name": house["name"], "balance_cents": house["balance_cents"]},
            "systems": {name: s["label"] for name, s in cmap.systems.items()},
            **village_reactions(conn, cmap, day, weeks_ago),
        }

    @app.get("/extra")
    def extra() -> dict:
        return compute_extra(app.state.conn, current_day(), category_map())

    return app


app = create_app()
