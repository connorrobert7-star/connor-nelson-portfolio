-- The casino's counted loads and what it has handed out. Loads are filled and shuffled
-- from a secure source when they load; a pull only reads the next one.

-- The case belt: 25 shells in a hidden order, fired one per case (unless the box fires).
CREATE TABLE IF NOT EXISTS casino_belt (
    id        INTEGER PRIMARY KEY CHECK (id = 1),
    shells    TEXT NOT NULL,             -- JSON list of tiers, in firing order
    pos       INTEGER NOT NULL,          -- shells fired from this belt
    loads     INTEGER NOT NULL,          -- belts loaded so far
    loaded_on TEXT NOT NULL
);

-- The box on the wall: 100 holes, two of them special (legendary, or mythic one in four).
CREATE TABLE IF NOT EXISTS casino_box (
    id        INTEGER PRIMARY KEY CHECK (id = 1),
    specials  TEXT NOT NULL,             -- JSON [{hole, tier, fired}]
    used      INTEGER NOT NULL,          -- holes used, one per case
    loads     INTEGER NOT NULL,
    loaded_on TEXT NOT NULL
);

-- One scratch book per price: 20 tickets with stated contents.
CREATE TABLE IF NOT EXISTS casino_books (
    price_cents INTEGER PRIMARY KEY,
    tickets     TEXT NOT NULL,           -- JSON list of tiers, in order
    pos         INTEGER NOT NULL,
    loads       INTEGER NOT NULL,
    loaded_on   TEXT NOT NULL
);

-- The prize wheel. A won wedge stays off until the wheel resets.
CREATE TABLE IF NOT EXISTS casino_wheel (
    wedge_index INTEGER PRIMARY KEY,
    tier        TEXT NOT NULL,
    taken       INTEGER NOT NULL DEFAULT 0
);

-- The claw machine's heap, at fixed spots across the glass (x, y in 0..1).
CREATE TABLE IF NOT EXISTS casino_claw_heap (
    slot_index INTEGER PRIMARY KEY,
    tier       TEXT NOT NULL,
    x          REAL NOT NULL,
    y          REAL NOT NULL,
    taken      INTEGER NOT NULL DEFAULT 0
);

-- The Sunday draw, one row per week (week_start is the Sunday the week began).
CREATE TABLE IF NOT EXISTS casino_draw (
    week_start    TEXT PRIMARY KEY,
    entries       INTEGER NOT NULL,      -- the owner's tickets: every $5 that landed that week
    tickets_total INTEGER NOT NULL,
    drawn         TEXT NOT NULL,         -- JSON ticket numbers, in draw order
    won           TEXT NOT NULL,         -- JSON item ids the owner won
    drawn_on      TEXT NOT NULL
);

-- What the leader wears, one item per slot.
CREATE TABLE IF NOT EXISTS casino_equipped (
    slot    TEXT PRIMARY KEY,
    item_id TEXT NOT NULL
);

-- Every item the casino handed out, and the transfer that paid for it (null for the
-- trade-up and the draw, which move no money).
CREATE TABLE IF NOT EXISTS casino_grants (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    machine      TEXT NOT NULL,          -- case | scratch | wheel | claw | tradeup | draw
    tier         TEXT NOT NULL,
    item_id      TEXT NOT NULL,
    inventory_id INTEGER NOT NULL,
    transfer_id  INTEGER REFERENCES transfers(id),
    created      TEXT NOT NULL
);

-- The pot machines' runs (docs/POT.md): `size` lamps, exactly one of them the hit, at a
-- position drawn when the run loads. Each pull uses the next lamp; a hit loads a fresh run.
CREATE TABLE IF NOT EXISTS casino_runs (
    machine   TEXT PRIMARY KEY,          -- scratch_100 | scratch_200 | scratch_500 | wheel | claw
    size      INTEGER NOT NULL,
    hit_at    INTEGER NOT NULL,          -- the lamp (from 0) that hits
    pos       INTEGER NOT NULL,          -- lamps used so far
    loads     INTEGER NOT NULL,
    loaded_on TEXT NOT NULL
);

-- The pot: a tally of blank pulls' prices, cash that already landed in the Brokerage
-- through move(). It never moves money itself.
CREATE TABLE IF NOT EXISTS casino_pot (
    id          INTEGER PRIMARY KEY CHECK (id = 1),
    total_cents INTEGER NOT NULL
);

-- Every hit's buy: the whole pot plus the winning pull, spent on the owner's pick at the
-- weekly price through the brokerage's place_order. Nothing here ever sells.
CREATE TABLE IF NOT EXISTS casino_pot_buys (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    machine      TEXT NOT NULL,          -- the run that hit
    symbol       TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,       -- pot before the hit + the winning pull's price
    price_cents  INTEGER NOT NULL,       -- this week's price, never a live one
    qty          REAL NOT NULL,
    status       TEXT NOT NULL,          -- what place_order said (simulated in the demo)
    order_id     INTEGER NOT NULL REFERENCES orders(id),
    transfer_id  INTEGER NOT NULL REFERENCES transfers(id),
    created      TEXT NOT NULL
);
