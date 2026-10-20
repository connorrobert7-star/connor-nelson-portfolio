from datetime import date, timedelta

from backend import db
from backend.sync.fixtures import sync_from_fixtures


def test_fixture_shape(conn):
    assert conn.execute("SELECT COUNT(*) FROM accounts").fetchone()[0] == 3
    assert conn.execute("SELECT COUNT(*) FROM holdings").fetchone()[0] == 5
    assert conn.execute("SELECT COUNT(*) FROM debts").fetchone()[0] == 1
    first, last = conn.execute("SELECT MIN(date), MAX(date) FROM transactions").fetchone()
    span = date.fromisoformat(last) - date.fromisoformat(first)
    assert span.days >= 88


def test_dates_rebase_to_yesterday():
    today = date(2027, 3, 1)
    c = db.connect(":memory:")
    sync_from_fixtures(c, today)
    (last,) = c.execute("SELECT MAX(date) FROM transactions").fetchone()
    assert date.fromisoformat(last) <= today - timedelta(days=1)
    assert date.fromisoformat(last) >= today - timedelta(days=2)


def test_resync_is_idempotent(conn):
    before = conn.execute("SELECT COUNT(*), SUM(amount_cents) FROM transactions").fetchone()
    sync_from_fixtures(conn, date(2026, 10, 20))
    after = conn.execute("SELECT COUNT(*), SUM(amount_cents) FROM transactions").fetchone()
    assert tuple(before) == tuple(after)
