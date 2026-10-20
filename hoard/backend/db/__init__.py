import sqlite3
from collections.abc import Iterable
from pathlib import Path

SCHEMA = Path(__file__).with_name("schema.sql")


def connect(path: str | Path, extra_schemas: Iterable[Path] = ()) -> sqlite3.Connection:
    conn = sqlite3.connect(path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA.read_text())
    for schema in extra_schemas:
        conn.executescript(schema.read_text())
    return conn
