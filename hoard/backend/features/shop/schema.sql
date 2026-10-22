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

-- The owner's pick at Marlo's counter: what the pot buys on its next hit (docs/POT.md).
-- One row or none. The game never writes it on its own: no default, no random pick.
CREATE TABLE IF NOT EXISTS shop_pick (
    id        INTEGER PRIMARY KEY CHECK (id = 1),
    symbol    TEXT NOT NULL,
    picked_on TEXT NOT NULL
);
