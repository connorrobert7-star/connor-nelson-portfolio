-- The flock. Faith is never stored: it is read from the last day money landed.

-- One row per named follower: the personal follower and one per holding.
-- Cultists are nameless and not stored.
CREATE TABLE IF NOT EXISTS followers_flock (
    id             TEXT PRIMARY KEY,          -- 'personal' or 'hold_<SYMBOL>'
    kind           TEXT NOT NULL,             -- personal | holding
    symbol         TEXT,
    name           TEXT,                      -- NULL for the personal follower until the rite
    belly          INTEGER NOT NULL,          -- 0-100, drains daily, refilled only with coin food
    loyalty        INTEGER NOT NULL DEFAULT 0, -- 0-99 toward the next level, from play only
    level          INTEGER NOT NULL DEFAULT 1,
    stage          INTEGER NOT NULL DEFAULT 0, -- personal growth stage, never goes down
    favorite_food  TEXT NOT NULL,
    favorite_thing TEXT NOT NULL,
    petted_on      TEXT,
    fed_on         TEXT,
    created        TEXT NOT NULL
);

-- What each follower wears: any owned item whose catalog slot is hat, cloak, aura or follower_skin.
CREATE TABLE IF NOT EXISTS followers_wear (
    follower_id TEXT NOT NULL,
    slot        TEXT NOT NULL,
    item_id     TEXT NOT NULL,
    since       TEXT NOT NULL,
    PRIMARY KEY (follower_id, slot)
);

-- The week's extra as first seen each game day, so a past week can be judged later.
CREATE TABLE IF NOT EXISTS followers_days (
    day         TEXT PRIMARY KEY,
    extra_cents INTEGER NOT NULL
);

-- The Grave of Weeks: one candle for every missed week (extra above 0 and nothing landed).
CREATE TABLE IF NOT EXISTS followers_graves (
    week_start  TEXT PRIMARY KEY,
    mourned_on  TEXT NOT NULL,                -- the Monday the flock put on veils
    extra_cents INTEGER NOT NULL
);

-- Holding sizes, set once a week from that week's holdings and never in between.
CREATE TABLE IF NOT EXISTS followers_sizes (
    week_start  TEXT NOT NULL,
    symbol      TEXT NOT NULL,
    value_cents INTEGER NOT NULL,
    share       REAL NOT NULL,
    PRIMARY KEY (week_start, symbol)
);
