-- Stock buys from the shop counter.
CREATE TABLE IF NOT EXISTS orders (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol       TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,
    price_cents  INTEGER NOT NULL,
    qty          REAL NOT NULL,
    transfer_id  INTEGER NOT NULL REFERENCES transfers(id),
    created      TEXT NOT NULL
);
