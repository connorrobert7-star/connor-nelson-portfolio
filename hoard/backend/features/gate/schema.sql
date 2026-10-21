-- The gate: every debt is a boss whose HP is its real balance.

-- Each boss the gate has seen. max_hp grows if the balance ever grows past it.
CREATE TABLE IF NOT EXISTS gate_bosses (
    debt_id      TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    kind         TEXT NOT NULL,
    max_hp_cents INTEGER NOT NULL,
    first_seen   TEXT NOT NULL
);

-- Interest: the boss heals once a month on its due day. Display only: HP is always
-- the balance the bank reports (which already includes the interest).
CREATE TABLE IF NOT EXISTS gate_heals (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    debt_id      TEXT NOT NULL,
    month        TEXT NOT NULL,           -- YYYY-MM
    day          TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,
    shown        INTEGER NOT NULL DEFAULT 0,
    UNIQUE (debt_id, month)
);

-- Payments the bank made on its own (LOAN_PAYMENTS_* transactions), each queued once
-- as an auto-attack for the while-you-were-out scene.
CREATE TABLE IF NOT EXISTS gate_bank_hits (
    txn_id       TEXT PRIMARY KEY,
    debt_id      TEXT NOT NULL,
    day          TEXT NOT NULL,
    amount_cents INTEGER NOT NULL
);

-- A boss that reached zero. Its unique drop is granted once, here.
CREATE TABLE IF NOT EXISTS gate_kills (
    debt_id      TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    kind         TEXT NOT NULL,
    max_hp_cents INTEGER NOT NULL,
    item_id      TEXT,
    day          TEXT NOT NULL,
    shown        INTEGER NOT NULL DEFAULT 0
);
