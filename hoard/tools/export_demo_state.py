"""Snapshot /state for every week into game/demo/ for the web build.

    python tools/export_demo_state.py [YYYY-MM-DD]

A browser build can't reach a backend on your machine, so the web demo reads
these files instead. Desktop builds always talk to the live backend.
"""

import json
import sys
from datetime import date
from pathlib import Path

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from backend.app import HISTORY_WEEKS, create_app  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "game" / "demo"


def main() -> None:
    today = date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else date.today()
    OUT.mkdir(exist_ok=True)
    with TestClient(create_app(":memory:", today)) as client:
        for weeks_ago in range(HISTORY_WEEKS):
            state = client.get("/state", params={"weeks_ago": weeks_ago}).json()
            (OUT / f"state_{weeks_ago}.json").write_text(json.dumps(state))


if __name__ == "__main__":
    main()
