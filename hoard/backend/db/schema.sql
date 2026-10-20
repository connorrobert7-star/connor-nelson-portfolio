-- Hoard core tables. Money is stored as integer cents everywhere.
-- Transaction amounts follow Plaid's sign: positive = money out, negative = money in.

CREATE TABLE IF NOT EXISTS accounts (
    id            TEXT PRIMARY KEY,
    source        TEXT NOT NULL,          -- fixture | plaid | snaptrade | manual
    kind          TEXT NOT NULL,          -- checking | savings | brokerage
    name          TEXT NOT NULL,
    balance_cents INTEGER NOT NULL,
    last_sync     TEXT
);

CREATE TABLE IF NOT EXISTS transactions (
    id           TEXT PRIMARY KEY,
    account_id   TEXT NOT NULL REFERENCES accounts(id),
    date         TEXT NOT NULL,           -- ISO date
    amount_cents INTEGER NOT NULL,
    merchant     TEXT NOT NULL,
    category     TEXT NOT NULL,           -- Plaid detailed personal_finance_category
    raw          TEXT
);
CREATE INDEX IF NOT EXISTS transactions_date ON transactions(date);

CREATE TABLE IF NOT EXISTS holdings (
    id          TEXT PRIMARY KEY,
    account_id  TEXT NOT NULL REFERENCES accounts(id),
    symbol      TEXT NOT NULL,
    qty         REAL NOT NULL,
    value_cents INTEGER NOT NULL,
    as_of       TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS goals (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    target_cents INTEGER NOT NULL,
    account_id   TEXT REFERENCES accounts(id),
    building_id  TEXT,
    stage        INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS debts (
    id                TEXT PRIMARY KEY,
    name              TEXT NOT NULL,
    balance_cents     INTEGER NOT NULL,
    apr               REAL NOT NULL,
    min_payment_cents INTEGER NOT NULL,
    boss_id           TEXT
);

CREATE TABLE IF NOT EXISTS transfers (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    from_account TEXT NOT NULL,
    to_account   TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,
    reason       TEXT NOT NULL,
    event_id     INTEGER REFERENCES events(id),
    status       TEXT NOT NULL,           -- simulated | pending | settled | failed
    created      TEXT NOT NULL,
    settled      TEXT
);

CREATE TABLE IF NOT EXISTS items (
    id           TEXT PRIMARY KEY,
    kind         TEXT NOT NULL,
    tier         TEXT NOT NULL,
    set_id       TEXT,
    owned        INTEGER NOT NULL DEFAULT 0,
    obtained_via TEXT,
    obtained_at  TEXT
);

CREATE TABLE IF NOT EXISTS cases_opened (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    case_type         TEXT NOT NULL,
    amount_cents      INTEGER NOT NULL,
    result_item       TEXT REFERENCES items(id),
    pity_counter_epic INTEGER NOT NULL,
    pity_counter_leg  INTEGER NOT NULL,
    opened_at         TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS draws (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    week         TEXT NOT NULL,
    entries      INTEGER NOT NULL,
    winners_json TEXT
);

CREATE TABLE IF NOT EXISTS rules (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    trigger      TEXT NOT NULL,
    condition    TEXT,
    action       TEXT NOT NULL,
    amount_cents INTEGER,
    to_account   TEXT,
    enabled      INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS pledges (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    week        TEXT NOT NULL,
    text        TEXT NOT NULL,
    kept        INTEGER,
    coins_delta INTEGER NOT NULL DEFAULT 0
);

-- Everything the village reacts to.
CREATE TABLE IF NOT EXISTS events (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    ts      TEXT NOT NULL,
    type    TEXT NOT NULL,
    payload TEXT
);
