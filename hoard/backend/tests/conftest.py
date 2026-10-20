from datetime import date

import pytest
from fastapi.testclient import TestClient

from backend import db
from backend.app import create_app
from backend.sync.fixtures import sync_from_fixtures

TODAY = date(2026, 10, 20)


@pytest.fixture
def conn():
    c = db.connect(":memory:")
    sync_from_fixtures(c, TODAY)
    yield c
    c.close()


@pytest.fixture
def client():
    with TestClient(create_app(":memory:", TODAY)) as c:
        yield c
