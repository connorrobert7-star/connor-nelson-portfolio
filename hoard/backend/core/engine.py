"""One save: a SQLite database plus the providers. Every request goes through handle().

FastAPI (backend/app.py) and the browser demo (Pyodide) both call handle(); there
is no other way in.
"""

import importlib
import json
import os
import pkgutil
from datetime import date, timedelta
from pathlib import Path

from backend import db, sync
from backend.content import category_map, load_profile
from backend.core import router
from backend.core.context import Ctx
from backend.core.hooks import run_days
from backend.core.services import NotEnoughCoins
from backend.money.transfer import TransferRefused
from backend.providers import NotConfigured, Providers
from backend.providers import load as load_providers

FEATURES_DIR = Path(__file__).resolve().parent.parent / "features"


def load_features() -> list[str]:
    import backend.core.routes  # noqa: F401  platform routes and sections
    import backend.features as pkg

    names = sorted(m.name for m in pkgutil.iter_modules(pkg.__path__) if m.ispkg)
    for name in names:
        importlib.import_module(f"backend.features.{name}")
    return names


class Engine:
    def __init__(
        self,
        db_path: str | Path = ":memory:",
        today: date | None = None,
        providers: Providers | None = None,
        profile: dict | None = None,
    ) -> None:
        self.features = load_features()
        self.schemas = sorted(FEATURES_DIR.glob("*/schema.sql"))
        self.conn = db.connect(db_path, self.schemas)
        self.base_today = today
        self.providers = providers or load_providers()
        self.profile = profile or load_profile()

    def base_day(self) -> date:
        if self.base_today:
            return self.base_today
        pinned = os.environ.get("HOARD_TODAY")
        return date.fromisoformat(pinned) if pinned else date.today()

    def ctx(self) -> Ctx:
        row = self.conn.execute("SELECT value FROM meta WHERE key = 'clock_offset'").fetchone()
        offset = int(row["value"]) if row else 0
        ctx = Ctx(
            conn=self.conn,
            today=self.base_day() + timedelta(days=offset),
            cmap=category_map(),
            providers=self.providers,
            profile=self.profile,
        )
        sync.run(ctx)
        run_days(ctx)
        return ctx

    def handle(
        self, method: str, path: str, query: dict | None = None, body: dict | None = None
    ) -> tuple[int, dict]:
        try:
            with self.conn:  # one transaction per request; any error rolls it back
                ctx = self.ctx()
                result = router.call(ctx, method, path, query, body)
        except router.ApiError as e:
            return e.status, {"detail": e.message}
        except (TransferRefused, NotEnoughCoins) as e:
            return 409, {"detail": str(e)}
        except NotConfigured as e:
            return 503, {"detail": str(e)}
        if not isinstance(result, dict):
            result = {"result": result}
        if ctx.events:
            result = {**result, "_events": ctx.events}
        return 200, result

    def handle_json(
        self, method: str, path: str, query_json: str = "{}", body_json: str = "{}"
    ) -> str:
        """For the browser bridge: JSON strings in, '{"status": n, "body": {...}}' out."""
        status, body = self.handle(
            method, path, json.loads(query_json or "{}"), json.loads(body_json or "{}")
        )
        return json.dumps({"status": status, "body": body})

    def export_db(self) -> bytes:
        return self.conn.serialize()

    def import_db(self, data: bytes) -> bool:
        """Load a save. One from an older build gets the tables added since and a fresh sync.
        If it still can't produce the state, it is dropped and the village starts fresh.
        Returns whether the save was kept."""
        fresh = self.conn.serialize()
        try:
            self.conn.deserialize(data)
            db.apply_schema(self.conn, self.schemas)
            with self.conn:
                self.conn.execute("DELETE FROM meta WHERE key = 'synced_for'")
            status, _ = self.handle("GET", "/state")
        except Exception:
            status = 500
        if status == 200:
            return True
        self.conn.deserialize(fresh)
        return False
