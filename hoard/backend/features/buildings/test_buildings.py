"""Buildings worth saving for: the contract in docs/BUILDINGS.md.

TODAY is Tuesday 2026-10-20. Weeks run Sunday to Saturday; the Sundays ahead are 10-25, 11-01,
11-08, ... The bank's payday lands $200 in the House Fund and $150 in the Brokerage every other
Friday (10-16, 10-30, 11-13, 11-27), so the weeks of 10-11, 10-25, 11-08 and 11-22 have a bank
deposit and the weeks of 10-18, 11-01, 11-15 and 11-29 don't.
"""

import ast
import json
import re
import struct
from datetime import date, timedelta
from pathlib import Path

import pytest

from backend.conftest import TODAY
from backend.core.engine import Engine
from backend.core.router import ROUTES
from backend.core.services import add_coins, coin_balance
from backend.features import buildings
from backend.features.buildings import buildings_day, catalog, works
from backend.features.followers import flock
from backend.features.minigames import rules as minigames
from backend.features.village import house
from backend.money.budget import balances, landed_by_kind, landed_cents
from backend.money.transfer import move

HERE = Path(__file__).parent
GAME = HERE.parents[2] / "game"
SUNDAY = date(2026, 10, 25)


# --- helpers ---------------------------------------------------------------------------------


def get(engine: Engine) -> dict:
    status, body = engine.handle("GET", "/state")
    assert status == 200, body
    return body


def post(engine: Engine, path: str, **body) -> tuple[int, dict]:
    return engine.handle("POST", path, body=body)


def advance(engine: Engine, days: int) -> dict:
    while days > 0:
        step = min(7, days)
        assert post(engine, "/clock/advance", days=step)[0] == 200
        days -= step
    return get(engine)


def entry(state: dict, building_id: str) -> dict:
    return next(b for b in state["buildings"]["list"] if b["id"] == building_id)


def req(e: dict, key: str) -> dict:
    return next(r for r in e["next"]["requires"] if r["key"] == key)


def hold(engine: Engine, monkeypatch, **cents: int) -> None:
    """From the next sync on, the bank and the brokerage report these balances."""
    held = {**getattr(engine, "_held", {}), **cents}
    engine._held = held  # type: ignore[attr-defined]
    bank, broker = engine.providers.bank, engine.providers.brokerage
    real_accounts, real_holdings = type(bank).accounts, type(broker).holdings

    def accounts(anchor: date, today: date) -> list[dict]:
        out = real_accounts(bank, anchor, today)
        for a in out:
            a["balance_cents"] = held.get(a["id"], a["balance_cents"])
        return out

    def holdings(anchor: date, today: date) -> list[dict]:
        out = real_holdings(broker, anchor, today)
        if "brk_1" not in held:
            return out
        if held["brk_1"] == 0:
            return []
        out[0]["value_cents"] += held["brk_1"] - sum(h["value_cents"] for h in out)
        return out

    monkeypatch.setattr(bank, "accounts", accounts)
    monkeypatch.setattr(broker, "holdings", holdings)
    with engine.conn:
        engine.conn.execute("DELETE FROM meta WHERE key = 'synced_for'")


def deposit(engine: Engine, cents: int = 100, to: str = "brk_1") -> None:
    ctx = engine.ctx()
    move(ctx, "chk_1", to, cents, reason="Test deposit", event={"type": "test"})
    engine.conn.commit()


def give_coins(engine: Engine, n: int) -> None:
    add_coins(engine.ctx(), n, "test")
    engine.conn.commit()


def spent(engine: Engine) -> list[tuple[int, str]]:
    return [
        (r["delta"], r["reason"])
        for r in engine.conn.execute("SELECT delta, reason FROM coin_ledger WHERE delta < 0")
    ]


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        head = f.read(24)
    assert head[:8] == b"\x89PNG\r\n\x1a\n", path
    return struct.unpack(">II", head[16:24])


# --- content -----------------------------------------------------------------------------------

# The contract table (docs/BUILDINGS.md): building | tier | name | requires (dollars; sav = savings,
# fund = House Fund, emerg = Emergency Fund, brk = brokerage, weeks = deposit streak) | coins |
# days | followers | unlocks.
CONTRACT_TABLE = """
land   | 1 | Home shore   |                                |    0 | 0 |  8 | land.home land.commons
land   | 2 | East reach   | sav 10000, weeks 2             |  500 | 2 |  4 | land.east plot.lodge
land   | 3 | South meadow | sav 15000, brk 40000, weeks 6  | 1500 | 4 |  4 | land.south
land   | 4 | North cliffs | sav 30000, brk 60000, weeks 13 | 4000 | 7 |  6 | land.north
house  | 1 | Plot         |                                |    0 | 0 |  0 |
house  | 2 | Foundation   | fund 1000                      |  100 | 1 |  0 |
house  | 3 | Frame        | fund 3200                      |  250 | 2 |  0 |
house  | 4 | Walls        | fund 7200                      |  500 | 3 |  0 |
house  | 5 | Roof         | fund 12800                     |  900 | 4 |  1 |
house  | 6 | Interior     | fund 22400                     | 1500 | 5 |  1 |
house  | 7 | Finished     | fund 40000                     | 2500 | 7 |  2 |
shrine | 1 | Altar        |                                |    0 | 0 |  4 |
shrine | 2 | Chapel       | sav 2000, brk 1000, weeks 4    |  600 | 3 |  6 |
shrine | 3 | Temple       | sav 8000, brk 20000, weeks 8   | 1800 | 5 |  8 |
shrine | 4 | Cathedral    | sav 20000, brk 50000, weeks 13 | 4500 | 7 | 10 |
arcade | 1 | Arcade       |                                |    0 | 0 |  0 |
arcade | 2 | Neon hall    | brk 35000                      |  500 | 2 |  0 | arcade.flame
arcade | 3 | Grand arcade | brk 50000, sav 15000           | 2000 | 5 |  0 | arcade.flame
tavern | 1 | Tavern       |                                |    0 | 0 |  0 |
tavern | 2 | Inn          | emerg 3000, weeks 2            |  400 | 2 |  4 |
tavern | 3 | Lodge house  | emerg 6000, sav 12000          | 1500 | 4 |  6 |
lodge  | 1 | Bunkhouse    | land 2, sav 10000              |  800 | 3 |  8 |
lodge  | 2 | Longhouse    | land 3, sav 18000, brk 40000   | 2500 | 5 | 10 |
lodge  | 3 | Great hall   | land 4, sav 30000, brk 60000, weeks 13 | 6000 | 7 | 14 |
"""
WORDS = {
    "sav": ("savings_cents", 100),
    "fund": ("house_fund_cents", 100),
    "emerg": ("emergency_cents", 100),
    "brk": ("brokerage_cents", 100),
    "weeks": ("deposit_streak_weeks", 1),
    "land": ("land", 1),
}


def _contract() -> dict[str, list[tuple]]:
    out: dict[str, list[tuple]] = {}
    for line in CONTRACT_TABLE.strip().splitlines():
        bid, tier, name, requires, coins, days, followers, unlocks = (
            c.strip() for c in line.split("|")
        )
        need = {}
        for part in filter(None, (p.strip() for p in requires.split(","))):
            word, n = part.split()
            key, unit = WORDS[word]
            need[key] = int(n) * unit
        row = (int(tier), name, need, int(coins), int(days), int(followers), unlocks.split())
        out.setdefault(bid, []).append(row)
    return out


def test_content_is_the_contract_table():
    contract = _contract()
    assert [b["id"] for b in catalog.buildings()] == list(contract)
    for bid, rows in contract.items():
        tiers = catalog.building(bid)["tiers"]
        assert len(tiers) == len(rows), bid
        for t, (n, name, requires, coins, days, followers, unlocks) in zip(
            tiers, rows, strict=True
        ):
            assert t["tier"] == n and t["name"] == name, (bid, n)
            assert t["requires"] == requires, (bid, n)
            assert (t["coins"], t["days"]) == (coins, days), (bid, n)
            assert t["changes"]["followers"] == followers, (bid, n)
            assert t["changes"]["unlocks"] == unlocks, (bid, n)
    assert catalog.streak_rules() == {"discount_weeks": 6, "discount": 0.2, "min_cents": 1}


def _looks(t: dict) -> list[dict]:
    look = t["changes"]["look"]
    return [look, *look.get("extras", [])] if "sheet" in look else []


def test_content_validates():
    raw = json.loads(catalog.PATH.read_text())
    ids = [b["id"] for b in raw["buildings"]]
    assert len(ids) == len(set(ids))
    house_stages = [s["id"] for s in house.house_config()["stages"]]
    parcels = {"home", "commons", "east", "south", "north"}
    for b in raw["buildings"]:
        assert set(b) <= {"id", "name", "plot", "parcel", "tiers"}, b["id"]
        assert [t["tier"] for t in b["tiers"]] == list(range(1, len(b["tiers"]) + 1)), b["id"]
        for t in b["tiers"]:
            where = (b["id"], t["tier"])
            assert set(t) <= {"tier", "name", "requires", "coins", "days", "changes", "line"}
            assert "!" not in t["name"] + t.get("line", ""), where
            assert isinstance(t["coins"], int) and t["coins"] >= 0, where
            assert isinstance(t["days"], int) and t["days"] >= 0, where
            for key, value in t["requires"].items():
                assert key in catalog.REQUIREMENT_KEYS, where
                if key == "buildings":
                    for other, n in value.items():
                        assert 1 <= n <= catalog.max_tier(other), where
                elif key == "land":
                    assert 1 <= value <= catalog.max_tier("land"), where
                else:
                    assert isinstance(value, int) and value > 0, where
            changes = t["changes"]
            assert set(changes) == {"look", "followers", "unlocks"}, where
            assert isinstance(changes["followers"], int) and changes["followers"] >= 0
            for key in changes["unlocks"]:
                kind, _, name = key.partition(".")
                assert (
                    (kind, name) == ("arcade", "flame")
                    or (kind == "land" and name in parcels)
                    or (kind == "plot" and catalog.building(name))
                ), (where, key)
            look = changes["look"]
            if "drawer" in look:
                drawer = look["drawer"]
                if drawer == "house":
                    assert look["stage"] in house_stages, where
                elif drawer == "land":
                    assert look["parcel"] in parcels, where
                else:
                    assert drawer == "facade" and look["id"] == b["plot"], where
                    assert look["level"] == t["tier"] == 1, where
            for sprite in _looks(t):
                assert set(sprite) <= {"sheet", "rect", "scale", "glow", "extras", "at", "flip"}
                assert sprite["sheet"].startswith("res://art/packs/"), where
                path = GAME / sprite["sheet"].removeprefix("res://")
                assert path.exists(), (where, path)
                x, y, w, h = sprite["rect"]
                width, height = png_size(path)
                assert w > 0 and h > 0 and x + w <= width and y + h <= height, (where, sprite)
                assert 0.5 <= sprite.get("scale", 1) <= 3, where
                if "glow" in sprite:
                    assert re.fullmatch(r"#[0-9a-f]{6}", sprite["glow"]), where
    # Every tier 1 that stands on day one is free; the lodge's plot is overgrown until land 2.
    for b in raw["buildings"]:
        first = b["tiers"][0]
        if b["id"] == "lodge":
            assert first["requires"]["land"] == 2 and first["days"] > 0
        else:
            assert first["requires"] == {} and first["coins"] == 0 and first["days"] == 0
    land_2 = catalog.tier("land", 2)
    assert "plot.lodge" in land_2["changes"]["unlocks"]


def test_looks_grow_grander_per_tier():
    for b in catalog.buildings():
        sizes = []
        for t in b["tiers"]:
            look = t["changes"]["look"]
            if "sheet" in look:
                w, h = look["rect"][2:]
                s = look.get("scale", 1)
                sizes.append(
                    w * h * s * s + sum(e["rect"][2] * e["rect"][3] for e in look.get("extras", []))
                )
        assert sizes == sorted(sizes), b["id"]


def test_discount_math():
    assert catalog.discounted(200_000, 0.2) == 160_000
    assert catalog.discounted(3_500_000, 0.2) == 2_800_000
    assert catalog.discounted(123_456, 0.2) == 98_800  # whole dollars
    assert catalog.toward_kinds(catalog.tier("arcade", 2)) == ("brokerage",)
    assert catalog.toward_kinds(catalog.tier("house", 2)) == ("savings",)
    assert catalog.toward_kinds(catalog.tier("shrine", 2)) == ("savings", "brokerage")
    assert catalog.toward_kinds(None) == ("savings", "brokerage")


# --- the founding ------------------------------------------------------------------------------


def test_demo_founding(engine):
    s = get(engine)
    b = s["buildings"]
    assert b["checked_on"] == TODAY.isoformat() and b["next_check"] == SUNDAY.isoformat()
    assert {e["id"]: e["tier"] for e in b["list"]} == {
        "land": 1,
        "house": 4,
        "shrine": 1,
        "arcade": 1,
        "tavern": 1,
        "lodge": 0,
    }
    assert all(e["seen_tier"] == e["tier"] for e in b["list"])
    assert b["capacity"] == {"followers": 12}
    assert b["land"] == {"tier": 1, "parcels": ["home", "commons"]}
    assert b["deposit_streak_weeks"] == 1  # the payday of 10-16; nothing the week before
    assert b["crew"] is None and b["target"] is None
    assert not any(e["next"]["ready"] for e in b["list"] if e["next"])
    lodge = entry(s, "lodge")
    assert lodge["look"] is None and lodge["next"]["name"] == "Bunkhouse"
    assert req(lodge, "land") | {"have": 1, "met_now": False} == req(lodge, "land")
    # Nothing was paid for: the founding is free.
    assert coin_balance(engine.ctx()) == 0 and spent(engine) == []
    assert not [a for a in s["away"] if a["kind"] == "building_done"]


def test_founding_builds_everything_that_already_holds(engine, monkeypatch):
    hold(engine, monkeypatch, sav_1=1_500_000, sav_2=400_000, brk_1=5_500_000)
    with engine.conn:  # an older deposit (the week of 10-04) makes the real streak three weeks
        engine.conn.execute(
            "INSERT INTO transfers (from_account, to_account, amount_cents, reason, status, "
            "created) VALUES ('chk_1', 'brk_1', 1000, 'old', 'settled', '2026-10-06')"
        )
    s = get(engine)
    b = s["buildings"]
    assert {e["id"]: e["tier"] for e in b["list"]} == {
        "land": 2,  # savings and a 2-week streak
        "house": 5,  # the roof: the House Fund holds $15,000
        "shrine": 1,  # the chapel wants four weeks in a row
        "arcade": 3,  # both arcade tiers hold
        "tavern": 2,  # the inn: the Emergency Fund holds $4,000 and two weeks
        "lodge": 1,  # land 2 was built a moment before, so the bunkhouse holds too
    }
    assert b["deposit_streak_weeks"] == 3
    assert all(e["seen_tier"] == e["tier"] for e in b["list"])
    assert b["capacity"]["followers"] == 8 + 4 + 1 + 4 + 4 + 8
    assert b["unlocks"]["arcade.flame"] == 2 and b["unlocks"]["plot.lodge"] == 1
    assert s["minigames"]["flames"]["max"] == 5
    assert spent(engine) == [] and coin_balance(engine.ctx()) == 0
    vias = {r[0] for r in engine.conn.execute("SELECT via FROM buildings_built")}
    assert vias == {"founding"}


def test_deposit_streak_reads_real_history(engine):
    get(engine)
    ctx = engine.ctx()
    assert works.completed_streak(ctx, date(2026, 10, 18)) == 1
    ctx.conn.execute(
        "INSERT INTO transfers (from_account, to_account, amount_cents, reason, status, created) "
        "VALUES ('chk_1', 'sav_2', 500, 'old', 'settled', '2026-10-06')"
    )
    # 10-11 (payday), 10-04 (the old transfer), 09-27 (the payday of 10-02), then a gap.
    assert works.completed_streak(ctx, date(2026, 10, 18)) == 3
    # Live, this week counts once something lands in it.
    facts = works.Facts(ctx, ctx.today, works.built(ctx), live=True)
    assert facts.streak == 3
    move(ctx, "chk_1", "sav_1", 100, "test", {"type": "test"})
    assert works.Facts(ctx, ctx.today, works.built(ctx), live=True).streak == 4
    assert works.Facts(ctx, ctx.today, works.built(ctx), live=False).streak == 3


def test_landed_by_kind_adds_up_to_landed_cents(ctx):
    start, end = TODAY - timedelta(days=7), TODAY
    move(ctx, "chk_1", "sav_2", 2_000, "test", {"type": "test"})
    move(ctx, "chk_1", "brk_1", 700, "test", {"type": "test"})
    move(ctx, "chk_1", "debt_card", 900, "test", {"type": "test"})  # a payment, not a deposit
    kinds = landed_by_kind(ctx, start, end)
    assert kinds == {"savings": 20_000 + 2_000, "brokerage": 15_000 + 700}
    assert sum(kinds.values()) == landed_cents(ctx, start, end)


# --- readiness, construction, one crew -----------------------------------------------------------


def test_readiness_flips_only_at_a_sunday_check(engine, monkeypatch):
    get(engine)
    hold(engine, monkeypatch, brk_1=3_600_000)  # the Neon hall's line is $35,000
    give_coins(engine, 5_000)
    for day in range(5):  # Tuesday to Saturday: it holds, but Sunday hasn't come
        s = get(engine) if day == 0 else advance(engine, 1)
        arcade = entry(s, "arcade")
        brokerage = req(arcade, "brokerage_cents")
        assert brokerage["met_now"] and not brokerage["met_at_check"], s["today"]
        assert not arcade["next"]["ready"] and arcade["next"]["why_not"] == "not_ready"
        status, body = post(engine, "/buildings/build", building_id="arcade")
        assert status == 409 and "Sunday" in body["detail"]
    s = advance(engine, 1)
    assert s["today"] == SUNDAY.isoformat() and s["buildings"]["checked_on"] == s["today"]
    arcade = entry(s, "arcade")
    assert arcade["next"]["ready"] and arcade["next"]["ready_since"] == SUNDAY.isoformat()
    assert req(arcade, "brokerage_cents")["met_at_check"]
    assert arcade["next"]["can_build"] and arcade["next"]["why_not"] is None
    assert s["buildings"]["next_check"] == "2026-11-01"


def test_construction_spends_coins_once_and_takes_exactly_the_days(engine, monkeypatch):
    get(engine)
    hold(engine, monkeypatch, brk_1=3_600_000, sav_1=1_300_000)
    s = advance(engine, 5)  # Sunday: the Neon hall and the roof are both ready
    assert entry(s, "arcade")["next"]["ready"] and entry(s, "house")["next"]["ready"]
    assert s["minigames"]["flames"]["max"] == 3

    # Not enough coins: refused, nothing starts.
    give_coins(engine, 300)
    assert entry(get(engine), "arcade")["next"]["why_not"] == "coins"
    status, body = post(engine, "/buildings/build", building_id="arcade")
    assert status == 409 and body["detail"] == "Needs 500 coins."
    assert engine.conn.execute("SELECT COUNT(*) FROM buildings_sites").fetchone()[0] == 0

    give_coins(engine, 400)
    status, body = post(engine, "/buildings/build", building_id="arcade")
    assert status == 200, body
    assert body["coins"] == 200 and body["building"]["constructing"]
    assert [e["delta"] for e in body["_events"] if e["kind"] == "coins"] == [-500]
    assert not [e for e in body["_events"] if e["kind"] == "money_moved"]
    s = get(engine)
    crew = s["buildings"]["crew"]
    assert crew == {
        "building_id": "arcade",
        "tier": 2,
        "started": "2026-10-25",
        "finishes": "2026-10-27",
        "days": 2,
        "days_done": 0,
        "days_left": 2,
        "progress": 0.0,
    }
    assert entry(s, "arcade")["tier"] == 1

    # One crew: the roof waits, and the same site can't be paid for twice.
    give_coins(engine, 2_000)
    for bid in ("house", "arcade"):
        status, body = post(engine, "/buildings/build", building_id=bid)
        assert status == 409 and body["detail"] == "The crew is busy."
    assert entry(get(engine), "house")["next"]["why_not"] == "crew"

    s = advance(engine, 1)  # Monday: halfway
    arcade = entry(s, "arcade")
    assert arcade["tier"] == 1 and arcade["constructing"] and arcade["progress"] == 0.5
    assert s["buildings"]["crew"]["days_left"] == 1
    assert s["minigames"]["flames"]["max"] == 3

    s = advance(engine, 1)  # Tuesday: exactly two days later it stands
    arcade = entry(s, "arcade")
    assert arcade["tier"] == 2 and not arcade["constructing"] and s["buildings"]["crew"] is None
    assert arcade["seen_tier"] == 1 and arcade["look"]["glow"]
    beats = [a for a in s["away"] if a["kind"] == "building_done"]
    assert [(b["payload"]["building_id"], b["payload"]["tier"]) for b in beats] == [("arcade", 2)]
    assert beats[0]["payload"]["text"] == "The neon hall is built."
    assert s["minigames"]["flames"] == {"max": 4, "left": 4, "used_today": 0}
    assert spent(engine) == [(-500, "Building the arcade: neon hall")]

    status, body = post(engine, "/buildings/seen", building_id="arcade")
    assert status == 200 and body["building"]["seen_tier"] == 2

    # The crew is free again: the roof starts.
    status, body = post(engine, "/buildings/build", building_id="house")
    assert status == 200 and get(engine)["village"]["house"]["constructing"]
    assert [d for d, _ in spent(engine)] == [-500, -900]


def test_a_zero_day_tier_is_built_at_once(engine, monkeypatch):
    raw = json.loads(catalog.PATH.read_text())
    raw["buildings"][3]["tiers"][1]["days"] = 0  # the Neon hall, for this test only
    monkeypatch.setattr(catalog, "content", lambda: raw)
    get(engine)
    hold(engine, monkeypatch, brk_1=3_600_000)
    advance(engine, 5)
    give_coins(engine, 500)
    status, body = post(engine, "/buildings/build", building_id="arcade")
    assert status == 200 and body["building"]["tier"] == 2 and not body["building"]["constructing"]
    s = get(engine)
    assert s["buildings"]["crew"] is None
    assert not [a for a in s["away"] if a["kind"] == "building_done"]  # the owner watched it


def test_a_ready_tier_stays_ready_and_built_tiers_never_unbuild(engine, monkeypatch):
    get(engine)
    hold(engine, monkeypatch, sav_1=1_300_000, brk_1=3_600_000)
    advance(engine, 5)  # Sunday 10-25: both ready
    give_coins(engine, 500)
    assert post(engine, "/buildings/build", building_id="arcade")[0] == 200
    hold(engine, monkeypatch, sav_1=100_000, brk_1=0)  # the money leaves
    s = advance(engine, 7)  # Sunday 11-01: the check finds nothing
    house_entry = entry(s, "house")
    assert house_entry["next"]["ready"] and house_entry["next"]["ready_since"] == "2026-10-25"
    fund = req(house_entry, "house_fund_cents")
    assert not fund["met_now"] and not fund["met_at_check"]
    arcade = entry(s, "arcade")
    assert arcade["tier"] == 2 and not req(arcade, "brokerage_cents")["met_now"]
    assert s["minigames"]["flames"]["max"] == 4
    give_coins(engine, 900)
    assert post(engine, "/buildings/build", building_id="house")[0] == 200


def test_no_route_speeds_anything_up():
    routes = sorted(k for k in ROUTES if k[1].startswith("/buildings"))
    assert routes == [
        ("POST", "/buildings/build"),
        ("POST", "/buildings/seen"),
        ("POST", "/buildings/target"),
    ]
    for key in routes:
        assert list(ROUTES[key].params) == ["building_id"], key


def test_unknown_buildings_and_finished_ones(engine):
    get(engine)
    for path in ("/buildings/build", "/buildings/target", "/buildings/seen"):
        status, body = post(engine, path, building_id="castle")
        assert status == 404 and body["detail"] == "No such building."
    with engine.conn:
        engine.conn.executemany(
            "INSERT INTO buildings_built (building_id, tier, built_on, via) "
            "VALUES ('arcade', ?, '2026-10-20', 'test')",
            [[2], [3]],
        )
    s = get(engine)
    assert entry(s, "arcade")["next"] is None
    for path in ("/buildings/build", "/buildings/target"):
        status, body = post(engine, path, building_id="arcade")
        assert status == 409 and body["detail"] == "Nothing left to build there."


# --- the target and the streak discount -----------------------------------------------------------


def test_streak_grows_and_a_missed_week_resets_it(engine):
    get(engine)
    status, body = post(engine, "/buildings/target", building_id="arcade")
    assert status == 200 and body["target"]["building_id"] == "arcade"
    assert body["target"]["streak_weeks"] == 0 and body["target"]["toward"] == ["brokerage"]
    deposit(engine, 300, "brk_1")
    t = get(engine)["buildings"]["target"]
    assert t["this_week_toward_cents"] == 300 and t["streak_weeks"] == 0
    deposit(engine, 500, "sav_1")  # savings don't count toward the arcade
    assert get(engine)["buildings"]["target"]["this_week_toward_cents"] == 300

    s = advance(engine, 5)  # Sunday 10-25
    assert s["buildings"]["target"]["streak_weeks"] == 1
    assert entry(s, "arcade")["target"]
    s = advance(engine, 7)  # 11-01: the bank's payday put $150 in the Brokerage on 10-30
    assert s["buildings"]["target"]["streak_weeks"] == 2
    deposit(engine, 500, "sav_2")  # only savings this week
    s = advance(engine, 7)  # 11-08: missed
    t = s["buildings"]["target"]
    assert t["streak_weeks"] == 0 and not t["discount_active"]
    row = engine.conn.execute(
        "SELECT target, target_streak, toward_cents FROM buildings_checks WHERE day = '2026-11-08'"
    ).fetchone()
    assert tuple(row) == ("arcade", 0, 0)


def test_switching_target_resets_the_streak_unless_the_old_one_is_finished(engine):
    get(engine)
    post(engine, "/buildings/target", building_id="arcade")
    deposit(engine, 300, "brk_1")
    advance(engine, 5)
    assert get(engine)["buildings"]["target"]["streak_weeks"] == 1
    post(engine, "/buildings/target", building_id="arcade")  # the same banner: nothing changes
    assert get(engine)["buildings"]["target"]["streak_weeks"] == 1
    status, body = post(engine, "/buildings/target", building_id="shrine")
    assert (
        status == 200
        and body["target"] | {"building_id": "shrine", "streak_weeks": 0} == (body["target"])
    )
    assert body["target"]["toward"] == ["savings", "brokerage"]

    # Grow it again, finish the shrine, and move the banner: the streak comes along.
    advance(engine, 7)  # 11-01: the payday counts toward the shrine
    assert get(engine)["buildings"]["target"]["streak_weeks"] == 1
    with engine.conn:
        engine.conn.executemany(
            "INSERT INTO buildings_built (building_id, tier, built_on, via) "
            "VALUES ('shrine', ?, '2026-11-01', 'test')",
            [[2], [3], [4]],
        )
    status, body = post(engine, "/buildings/target", building_id="tavern")
    assert status == 200 and body["target"]["streak_weeks"] == 1


def test_the_discount_is_twenty_percent_of_the_dollars_at_six_weeks(engine, monkeypatch):
    get(engine)
    hold(engine, monkeypatch, brk_1=3_000_000)  # between $28,000 (discounted) and $35,000
    post(engine, "/buildings/target", building_id="arcade")
    deposit(engine, 100, "brk_1")  # the week of 10-18
    no_bank_deposit = {date(2026, 11, 1), date(2026, 11, 15)}
    s = advance(engine, 5)
    for weeks in range(1, 7):
        t = s["buildings"]["target"]
        arcade = entry(s, "arcade")
        assert t["streak_weeks"] == weeks, s["today"]
        brokerage = req(arcade, "brokerage_cents")
        if weeks < 6:
            assert not t["discount_active"] and not arcade["next"]["discounted"]
            assert brokerage["need"] == brokerage["base_need"] == 3_500_000
            assert not arcade["next"]["ready"]
            if date.fromisoformat(s["today"]) in no_bank_deposit:
                deposit(engine, 100, "brk_1")
            s = advance(engine, 7)
    # Sunday 11-29: six weeks in a row.
    assert s["today"] == "2026-11-29"
    t = s["buildings"]["target"]
    arcade = entry(s, "arcade")
    brokerage = req(arcade, "brokerage_cents")
    assert t["discount_active"] and t["discount"] == 0.2 and t["discount_weeks"] == 6
    assert arcade["next"]["discounted"]
    assert brokerage["base_need"] == 3_500_000 and brokerage["need"] == 2_800_000
    assert brokerage["need"] == brokerage["base_need"] * 4 // 5
    assert arcade["next"]["ready"] and arcade["next"]["ready_since"] == "2026-11-29"
    # Only the target is discounted.
    shrine = entry(s, "shrine")
    assert not shrine["next"]["discounted"]
    assert req(shrine, "savings_cents")["need"] == 200_000

    # A week with nothing toward it: the discount is gone, the tier stays ready.
    s = advance(engine, 7)
    t = s["buildings"]["target"]
    arcade = entry(s, "arcade")
    assert t["streak_weeks"] == 0 and not t["discount_active"]
    assert not arcade["next"]["discounted"]
    assert req(arcade, "brokerage_cents")["need"] == 3_500_000
    assert arcade["next"]["ready"]


def test_weeks_and_buildings_are_never_discounted(engine):
    get(engine)
    ctx = engine.ctx()
    facts = works.Facts(ctx, ctx.today, works.built(ctx))
    rows = works.requirement_rows(catalog.tier("lodge", 3), facts, 0.2)
    by_key = {r["key"]: r for r in rows}
    assert by_key["land"]["need"] == 4 and by_key["deposit_streak_weeks"]["need"] == 13
    assert by_key["savings_cents"]["need"] == 2_400_000
    assert by_key["brokerage_cents"]["need"] == 4_800_000
    other = works.requirement_rows({"requires": {"buildings": {"shrine": 3}}}, facts, 0.2)
    assert other[0] | {"need": 3, "base_need": 3, "have": 1, "met": False} == other[0]


# --- money never moves, coins only at the build ---------------------------------------------


def test_the_feature_never_touches_the_transfer_module_or_accounts():
    for path in HERE.glob("*.py"):
        if path.name.startswith("test_"):
            continue
        source = path.read_text()
        tree = ast.parse(source)
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom):
                assert node.module != "backend.money.transfer", path
            if isinstance(node, ast.Import):
                assert all("transfer" not in a.name for a in node.names), path
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                assert node.func.id != "move", path
        for table in ("transfers", "accounts", "holdings", "debts", "transactions"):
            assert not re.search(rf"(INSERT|UPDATE|DELETE)[^\"']*\b{table}\b", source, re.I), (
                path,
                table,
            )


def test_coins_are_spent_only_by_the_build_route():
    calls = []
    for path in HERE.glob("*.py"):
        if path.name.startswith("test_"):
            continue
        tree = ast.parse(path.read_text())
        for fn in ast.walk(tree):
            if isinstance(fn, ast.FunctionDef):
                for node in ast.walk(fn):
                    if isinstance(node, ast.Call) and getattr(node.func, "id", "") == "add_coins":
                        calls.append((path.name, fn.name))
    assert calls == [("works.py", "build")]


def test_no_route_or_hook_moves_money(engine, monkeypatch):
    get(engine)
    hold(engine, monkeypatch, brk_1=3_600_000)
    get(engine)

    def money() -> tuple:
        c = engine.conn
        return (
            [tuple(r) for r in c.execute("SELECT * FROM transfers ORDER BY id")],
            [tuple(r) for r in c.execute("SELECT * FROM accounts ORDER BY id")],
            [tuple(r) for r in c.execute("SELECT * FROM holdings ORDER BY id")],
            balances(engine.ctx()),
        )

    before = money()
    give_coins(engine, 1_000)
    calls = [
        ("/buildings/target", "arcade"),
        ("/buildings/seen", "house"),
        ("/buildings/build", "arcade"),  # refused: not ready yet
    ]
    for path, bid in calls:
        status, body = post(engine, path, building_id=bid)
        assert not [e for e in body.get("_events", []) if e["kind"] == "money_moved"]
    assert money() == before
    coins_before = coin_balance(engine.ctx())

    # The hooks themselves, on a Sunday and on a finishing day, in one request each.
    for day in (SUNDAY, SUNDAY + timedelta(days=1)):
        with engine.conn:
            ctx = engine.ctx()
            snapshot = money()
            buildings_day(ctx, day)
            assert not [e for e in ctx.events if e["kind"] in ("money_moved", "coins")]
            assert money() == snapshot
    assert coin_balance(engine.ctx()) == coins_before
    assert entry(get(engine), "arcade")["next"]["ready"]  # the Sunday hook did run


# --- what tiers change: flames, followers ---------------------------------------------------


def _build_directly(engine: Engine, bid: str, *tiers: int) -> None:
    with engine.conn:
        engine.conn.executemany(
            "INSERT INTO buildings_built (building_id, tier, built_on, via) "
            "VALUES (?, ?, '2026-10-20', 'test')",
            [[bid, t] for t in tiers],
        )


def test_arcade_tiers_add_lantern_flames(engine):
    get(engine)
    ctx = engine.ctx()
    assert minigames.flames_per_day(ctx) == 3 and buildings.unlocked(ctx, "arcade.flame") == 0
    _build_directly(engine, "arcade", 2)
    assert minigames.flames_per_day(engine.ctx()) == 4
    _build_directly(engine, "arcade", 3)
    assert get(engine)["minigames"]["flames"]["max"] == 5


def test_cultists_scale_with_follower_capacity(engine):
    assert [flock.cultists(b, 12) for b in ("fervent", "content", "doubting", "mourning")] == [
        12,
        8,
        4,
        2,
    ]
    assert [flock.cultists(b, 24) for b in ("fervent", "content", "doubting", "mourning")] == [
        24,
        16,
        8,
        4,
    ]
    s = get(engine)
    assert s["followers"]["capacity"] == 12 and s["followers"]["cultists"] == 8  # content
    _build_directly(engine, "shrine", 2)  # the chapel holds six more
    s = get(engine)
    assert s["buildings"]["capacity"]["followers"] == 18
    assert s["followers"]["capacity"] == 18 and s["followers"]["cultists"] == 12


def _flock_engine(monkeypatch, symbols: list[str]) -> Engine:
    engine = Engine(":memory:", TODAY)
    broker = engine.providers.brokerage
    real = type(broker).holdings

    def holdings(anchor: date, today: date) -> list[dict]:
        base = {h["symbol"]: h for h in real(broker, anchor, today)}
        vti = base["VTI"]
        return [
            {**vti, "id": f"hld_{s}", "symbol": s, "value_cents": 100_000 + i}
            for i, s in enumerate(symbols)
        ]

    monkeypatch.setattr(broker, "holdings", holdings)
    return engine


def test_devotion_is_the_same_for_a_flock_of_one_and_a_flock_of_ten(monkeypatch):
    """Holdings are money; followers come from holdings. Money never buys coins, so ten
    followers to pet earn exactly what one does."""
    tickers = ["VTI", "VOO", "VXUS", "SCHD", "BND", "AAPL", "MSFT", "NVDA", "AMZN"]
    earned = []
    for symbols in ([], tickers):
        engine = _flock_engine(monkeypatch, symbols)
        s = get(engine)
        ids = ["personal"] + [h["id"] for h in s["followers"]["holdings"]]
        assert len(ids) == 1 + len(symbols)
        coins = []
        for _ in range(3):
            for fid in ids:
                assert post(engine, "/followers/pet", follower_id=fid)[0] == 200
            status, body = post(engine, "/followers/collect")
            coins.append(body["coins"])
            advance(engine, 1)
        earned.append(coins)
    one, ten = earned
    assert (
        one
        == ten
        == [flock.DEVOTION_START + flock.DEVOTION_DAILY_CAP] + [flock.DEVOTION_DAILY_CAP] * 2
    )


@pytest.mark.parametrize("weekday", range(7))
def test_next_check_is_the_coming_sunday(engine, weekday):
    get(engine)
    s = advance(engine, (weekday - TODAY.weekday()) % 7 or 7)
    today = date.fromisoformat(s["today"])
    nxt = date.fromisoformat(s["buildings"]["next_check"])
    assert nxt.weekday() == 6 and 0 < (nxt - today).days <= 7
