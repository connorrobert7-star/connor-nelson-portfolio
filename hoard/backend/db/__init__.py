import sqlite3
from collections.abc import Iterable
from pathlib import Path

SCHEMA = Path(__file__).with_name("schema.sql")


def connect(path: str | Path, extra_schemas: Iterable[Path] = ()) -> sqlite3.Connection:
    conn = sqlite3.connect(path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    apply_schema(conn, extra_schemas)
    return conn


def apply_schema(conn: sqlite3.Connection, extra_schemas: Iterable[Path] = ()) -> None:
    """Create any missing tables. Safe on an existing save: every statement is IF NOT EXISTS."""
    conn.executescript(SCHEMA.read_text())
    for schema in extra_schemas:
        conn.executescript(schema.read_text())
