"""Everything a handler needs for one request."""

import sqlite3
from dataclasses import dataclass, field
from datetime import date
from typing import Any

from backend.content import CategoryMap


@dataclass
class Ctx:
    conn: sqlite3.Connection
    today: date
    cmap: CategoryMap
    providers: Any  # backend.providers.Providers
    profile: dict
    events: list[dict] = field(default_factory=list)

    @property
    def demo(self) -> bool:
        return self.providers.demo

    def meta(self, key: str, default: str | None = None) -> str | None:
        row = self.conn.execute("SELECT value FROM meta WHERE key = ?", [key]).fetchone()
        return row["value"] if row else default

    def set_meta(self, key: str, value: str) -> None:
        self.conn.execute(
            "INSERT INTO meta (key, value) VALUES (?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            [key, value],
        )

    def emit(self, kind: str, **data: Any) -> None:
        """Something the game should celebrate or show right after this request."""
        self.events.append({"kind": kind, **data})
