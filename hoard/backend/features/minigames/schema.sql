-- The arcade: one row per minigame run, and the dungeon's cosmetic shuffle bag.

CREATE TABLE IF NOT EXISTS minigames_runs (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    game      TEXT NOT NULL,              -- mine | fishing | dungeon
    day       TEXT NOT NULL,
    seed      INTEGER NOT NULL,
    modifiers TEXT,
    finished  INTEGER NOT NULL DEFAULT 0,
    full      INTEGER NOT NULL DEFAULT 0, -- 1 if this run burned a lantern flame (full coins)
    score     INTEGER NOT NULL DEFAULT 0,
    coins     INTEGER NOT NULL DEFAULT 0,
    result    TEXT,
    item_id   TEXT
);
CREATE INDEX IF NOT EXISTS minigames_runs_day ON minigames_runs(day, game);

-- Draw order for the current cycle of the dungeon's cosmetic bag. No repeats until the set is done.
CREATE TABLE IF NOT EXISTS minigames_bag (
    pos     INTEGER PRIMARY KEY,
    cycle   INTEGER NOT NULL,
    item_id TEXT NOT NULL,
    drawn   INTEGER NOT NULL DEFAULT 0
);
