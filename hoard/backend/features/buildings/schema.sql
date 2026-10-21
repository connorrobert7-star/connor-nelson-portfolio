-- Buildings worth saving for (docs/BUILDINGS.md). Nothing here holds money: requirements are
-- read from the balances at each Sunday check and are never spent, moved or locked.
-- Small values (the target, its streak, the last check day) live in meta as buildings_*.

-- Every tier that stands. A built tier never unbuilds, whatever the balances do later.
CREATE TABLE IF NOT EXISTS buildings_built (
    building_id TEXT NOT NULL,
    tier        INTEGER NOT NULL,
    built_on    TEXT NOT NULL,
    via         TEXT NOT NULL,           -- founding | legacy | crew
    PRIMARY KEY (building_id, tier)
);

-- Tiers whose requirements all held at a Sunday check (or the founding). Ready stays ready
-- until the tier is built, even if a balance drops or the streak discount goes away.
CREATE TABLE IF NOT EXISTS buildings_ready (
    building_id TEXT NOT NULL,
    tier        INTEGER NOT NULL,
    ready_since TEXT NOT NULL,
    PRIMARY KEY (building_id, tier)
);

-- Construction sites. One crew: at most one row has done_on NULL at a time.
CREATE TABLE IF NOT EXISTS buildings_sites (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    building_id TEXT NOT NULL,
    tier        INTEGER NOT NULL,
    coins       INTEGER NOT NULL,        -- what the build cost, spent once when it started
    started     TEXT NOT NULL,
    finishes    TEXT NOT NULL,           -- started + days; built on the first day >= this
    days        INTEGER NOT NULL,
    done_on     TEXT
);

-- The tier the game last played the reveal for, per building.
CREATE TABLE IF NOT EXISTS buildings_seen (
    building_id TEXT PRIMARY KEY,
    tier        INTEGER NOT NULL
);

-- One row per check: the founding and every Sunday. `results` is JSON
-- {building_id: {tier: {requirement: held}}} for every tier not yet built.
CREATE TABLE IF NOT EXISTS buildings_checks (
    day            TEXT PRIMARY KEY,
    kind           TEXT NOT NULL,        -- founding | sunday
    deposit_streak INTEGER NOT NULL,
    target         TEXT,
    target_streak  INTEGER NOT NULL,
    toward_cents   INTEGER NOT NULL,     -- deposits toward the target in the week that ended
    results        TEXT NOT NULL
);
