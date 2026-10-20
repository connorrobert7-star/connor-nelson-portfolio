-- Hoard platform tables. Features add their own in backend/features/<id>/schema.sql.
-- Money is integer cents everywhere. Transaction amounts follow Plaid's sign:
-- positive = money out, negative = money in.

CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Synced from providers. Replaced on every sync.
CREATE TABLE IF NOT EXISTS accounts (
    id            TEXT PRIMARY KEY,
    source        TEXT NOT NULL,
    kind          TEXT NOT NULL,          -- checking | savings | brokerage
    name          TEXT NOT NULL,
    balance_cents INTEGER NOT NULL,
    last_sync     TEXT
);

CREATE TABLE IF NOT EXISTS transactions (
    id           TEXT PRIMARY KEY,
    account_id   TEXT NOT NULL,
    date         TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,
    merchant     TEXT NOT NULL,
    category     TEXT NOT NULL,
    raw          TEXT
);
CREATE INDEX IF NOT EXISTS transactions_date ON transactions(date);
CREATE INDEX IF NOT EXISTS transactions_merchant ON transactions(merchant);

CREATE TABLE IF NOT EXISTS holdings (
    id          TEXT PRIMARY KEY,
    account_id  TEXT NOT NULL,
    symbol      TEXT NOT NULL,
    qty         REAL NOT NULL,
    value_cents INTEGER NOT NULL,
    as_of       TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS debts (
    id                TEXT PRIMARY KEY,
    name              TEXT NOT NULL,
    kind              TEXT NOT NULL,      -- credit | auto | student | other
    balance_cents     INTEGER NOT NULL,
    apr               REAL NOT NULL,
    min_payment_cents INTEGER NOT NULL,
    due_day           INTEGER,
    limit_cents       INTEGER
);

-- Game-made money moves. Never replaced by sync.
CREATE TABLE IF NOT EXISTS transfers (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    from_account TEXT NOT NULL,
    to_account   TEXT NOT NULL,           -- an account id or a debt id
    amount_cents INTEGER NOT NULL,
    reason       TEXT NOT NULL,
    event_id     INTEGER,
    status       TEXT NOT NULL,           -- simulated | pending | settled | failed
    created      TEXT NOT NULL,
    settled      TEXT
);

-- Every game event that caused a money move, and anything else worth a log line.
CREATE TABLE IF NOT EXISTS events (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    ts      TEXT NOT NULL,
    type    TEXT NOT NULL,
    payload TEXT
);

-- Soft currency. Earned by playing; money can never buy coins.
CREATE TABLE IF NOT EXISTS coin_ledger (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    delta   INTEGER NOT NULL,
    reason  TEXT NOT NULL,
    created TEXT NOT NULL
);

-- Cosmetics and collectibles. item_id points into a feature's catalog.
CREATE TABLE IF NOT EXISTS inventory (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id      TEXT NOT NULL,
    obtained_via TEXT NOT NULL,
    obtained_at  TEXT NOT NULL,
    equipped     INTEGER NOT NULL DEFAULT 0
);

-- Things to tell the player next time they look (level ups, settled transfers, boss kills).
CREATE TABLE IF NOT EXISTS notifications (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    created TEXT NOT NULL,
    kind    TEXT NOT NULL,
    text    TEXT NOT NULL,
    data    TEXT,
    seen    INTEGER NOT NULL DEFAULT 0
);
