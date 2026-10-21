-- The village hub: offering-tablet sockets and restored ruins. Once a socket fills or a
-- ruin is restored it stays that way, even if the ledger that filled it later changes.

CREATE TABLE IF NOT EXISTS village_fill (
    bundle_id TEXT NOT NULL,
    socket    INTEGER NOT NULL,
    filled_on TEXT NOT NULL,
    shown     INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (bundle_id, socket)
);

CREATE TABLE IF NOT EXISTS village_restored (
    ruin_id     TEXT PRIMARY KEY,
    restored_on TEXT NOT NULL,
    shown       INTEGER NOT NULL DEFAULT 0
);
