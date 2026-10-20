"""FastAPI adapter. All logic lives in the engine; this only forwards requests.

    uvicorn backend.app:app --reload

HOARD_DB sets the save file, HOARD_TODAY pins the date, HOARD_* picks providers
(see backend/providers/__init__.py).
"""

import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from backend.core.engine import Engine

DEFAULT_DB = Path(__file__).resolve().parent / "db" / "hoard.sqlite3"


def create_app(engine: Engine | None = None) -> FastAPI:
    app = FastAPI(title="Hoard")
    app.state.engine = engine

    def get_engine() -> Engine:
        if app.state.engine is None:
            app.state.engine = Engine(os.environ.get("HOARD_DB", DEFAULT_DB))
        return app.state.engine

    @app.api_route("/{path:path}", methods=["GET", "POST"])
    async def forward(path: str, request: Request) -> JSONResponse:
        body = await request.json() if request.method == "POST" and await request.body() else {}
        status, payload = get_engine().handle(
            request.method, "/" + path, dict(request.query_params), body
        )
        return JSONResponse(payload, status_code=status)

    return app


app = create_app()
