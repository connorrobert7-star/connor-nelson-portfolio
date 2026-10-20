from datetime import date

import pytest
from fastapi.testclient import TestClient

from backend.app import create_app
from backend.core.engine import Engine

TODAY = date(2026, 10, 20)


@pytest.fixture
def engine() -> Engine:
    return Engine(":memory:", TODAY)


@pytest.fixture
def ctx(engine: Engine):
    """A request context with the morning sync done. Writes are not auto-committed."""
    return engine.ctx()


@pytest.fixture
def state(engine: Engine) -> dict:
    status, body = engine.handle("GET", "/state")
    assert status == 200, body
    return body


@pytest.fixture
def client(engine: Engine):
    with TestClient(create_app(engine)) as c:
        yield c
