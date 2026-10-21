"""The flock: Faith, bellies, kept weeks, growth, holdings, mourning, and the away beats."""

from datetime import date, timedelta

import pytest

from backend.core.engine import Engine
from backend.core.services import add_coins, coin_balance, grant_item
from backend.features.followers import flock
from backend.money.budget import balances, compute_extra
from backend.money.transfer import move

# TODAY is Tuesday 2026-10-20. The bank's last payday transfer landed Friday 2026-10-16
# (4 days ago); the next lands Friday 2026-10-30. Weeks run Sunday to Saturday.
MONDAY = date(2026, 10, 26)


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


def deposit(engine: Engine, cents: int = 2_000, to: str = "sav_1") -> None:
    """Money landing the way a casino case or a gate payment would move it."""
    ctx = engine.ctx()
    move(ctx, "chk_1", to, cents, reason="Test deposit", event={"type": "test"})
    engine.conn.commit()


def give_coins(engine: Engine, n: int) -> None:
    ctx = engine.ctx()
    add_coins(ctx, n, "test")
    engine.conn.commit()


def follower(state: dict, fid: str) -> dict:
    f = state["followers"]
    if fid == "personal":
        return f["personal"]
    return next(h for h in f["holdings"] if h["id"] == fid)


def transfers(engine: Engine) -> int:
    return engine.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0]


# --- Faith ---------------------------------------------------------------------------------


def test_faith_bands_follow_days_since_landing():
    assert [flock.band_for(d) for d in (0, 1, 2)] == ["fervent"] * 3
    assert [flock.band_for(d) for d in (3, 6)] == ["content"] * 2
    assert [flock.band_for(d) for d in (7, 13)] == ["doubting"] * 2
    assert [flock.band_for(d) for d in (14, 40)] == ["mourning"] * 2


def test_faith_in_state_moves_only_when_money_lands(engine):
    faith = get(engine)["followers"]["faith"]
    assert faith == faith | {"band": "content", "days_since_landing": 4}
    s = advance(engine, 3)
    assert s["followers"]["faith"]["band"] == "doubting"
    assert s["followers"]["cultists"] < 8
    deposit(engine)
    s = get(engine)
    assert s["followers"]["faith"]["band"] == "fervent"
    assert s["followers"]["faith"]["days_since_landing"] == 0
    assert s["followers"]["cultist_pose"] in ("chant", "hungry", "sleep")


# --- bellies and food --------------------------------------------------------------------------


def test_bellies_drain_daily_and_never_go_below_zero(engine):
    s = get(engine)
    assert follower(s, "hold_VTI")["belly"] == flock.NEW_BELLY
    s = advance(engine, 1)
    assert follower(s, "hold_VTI")["belly"] == flock.NEW_BELLY - flock.BELLY_DRAIN_PER_DAY
    assert follower(s, "personal")["belly"] == flock.NEW_BELLY  # the egg doesn't eat
    s = advance(engine, 2)
    vti = follower(s, "hold_VTI")
    assert vti["belly"] == 0 and vti["starving"] and vti["pose"] == "flat"


def test_food_costs_coins_only(engine):
    get(engine)
    before_money = (balances(engine.ctx()), compute_extra(engine.ctx())["extra_cents"])
    status, body = post(engine, "/followers/feed", follower_id="hold_MSFT", food="stew")
    assert status == 409 and "coins" in body["detail"]
    assert follower(get(engine), "hold_MSFT")["belly"] == flock.NEW_BELLY

    give_coins(engine, 40)
    status, body = post(engine, "/followers/feed", follower_id="hold_MSFT", food="stew")
    assert status == 200 and body["spent"] == 15 and body["belly"] == 100
    assert [e for e in body["_events"] if e["kind"] == "coins"][0]["delta"] == -15
    assert coin_balance(engine.ctx()) == 25
    s = get(engine)
    assert follower(s, "hold_MSFT")["fed_today"] and not follower(s, "hold_MSFT")["hungry"]

    # Full: a head shake, and nothing is spent.
    status, body = post(engine, "/followers/feed", follower_id="hold_MSFT", food="gruel")
    assert status == 200 and body["full"] and body["spent"] == 0
    assert coin_balance(engine.ctx()) == 25

    # The favorite is the follower's own dish.
    status, body = post(engine, "/followers/feed", follower_id="hold_VTI", food="favorite")
    assert status == 200 and body["ate"] == follower(s, "hold_VTI")["favorite_food"]["id"]
    assert coin_balance(engine.ctx()) == 0

    assert transfers(engine) == 0
    assert (balances(engine.ctx()), compute_extra(engine.ctx())["extra_cents"]) == before_money


def test_the_egg_does_not_eat_and_unknown_things_404(engine):
    give_coins(engine, 100)
    assert post(engine, "/followers/feed", follower_id="personal", food="gruel")[0] == 409
    assert post(engine, "/followers/feed", follower_id="hold_VTI", food="cake")[0] == 404
    assert post(engine, "/followers/feed", follower_id="hold_NOPE", food="gruel")[0] == 404
    assert coin_balance(engine.ctx()) == 100


def test_a_deposit_never_fills_a_belly(engine):
    advance(engine, 1)
    before = follower(get(engine), "hold_VTI")["belly"]
    deposit(engine, 5_000)
    assert follower(get(engine), "hold_VTI")["belly"] == before


# --- loyalty, petting, devotion -------------------------------------------------------------


def test_petting_is_loyalty_once_a_day_and_levels_drop_a_cosmetic(engine):
    get(engine)
    status, body = post(engine, "/followers/pet", follower_id="hold_SCHD")
    assert status == 200 and body["gained"] == flock.PET_LOYALTY
    status, body = post(engine, "/followers/pet", follower_id="hold_SCHD")
    assert body["gained"] == 0
    for _ in range(4):
        advance(engine, 1)
        status, body = post(engine, "/followers/pet", follower_id="hold_SCHD")
    assert body["level_up"] and body["level"] == 2 and len(body["items"]) == 1
    item = [e for e in body["_events"] if e["kind"] == "item"][0]
    assert item["item_id"].startswith("followers_") and item["name"] and item["tier"]
    assert transfers(engine) == 0


def test_devotion_piles_up_from_play_and_is_capped_per_day(engine):
    s = get(engine)
    assert s["followers"]["devotion"]["amount"] == flock.DEVOTION_START
    for fid in ("hold_VTI", "hold_MSFT", "hold_SCHD", "hold_AAPL", "hold_VXUS"):
        post(engine, "/followers/pet", follower_id=fid)
    pile = get(engine)["followers"]["devotion"]["amount"]
    assert pile == flock.DEVOTION_START + flock.DEVOTION_DAILY_CAP
    status, body = post(engine, "/followers/collect")
    assert status == 200 and body["coins"] == pile and coin_balance(engine.ctx()) == pile
    assert get(engine)["followers"]["devotion"]["amount"] == 0
    assert transfers(engine) == 0


def test_lazy_followers_wake_when_petted(engine, monkeypatch):
    monkeypatch.setattr(flock, "week_reactions", lambda ctx: {"lazy"})
    s = get(engine)
    assert follower(s, "hold_AAPL")["pose"] == "sleep"
    post(engine, "/followers/pet", follower_id="hold_AAPL")
    assert follower(get(engine), "hold_AAPL")["pose"] != "sleep"


# --- no money moves -------------------------------------------------------------------------


def test_no_follower_route_moves_money(engine):
    deposit(engine)  # hatch the egg so every route can run
    give_coins(engine, 500)
    ctx = engine.ctx()
    grant_item(ctx, "followers_hood_tide", via="test")
    engine.conn.commit()
    s = get(engine)
    money_before = (transfers(engine), balances(engine.ctx()))
    name = s["followers"]["personal"]["offered_names"][0]
    calls = [
        ("/followers/pet", {"follower_id": "personal"}),
        ("/followers/feed", {"follower_id": "personal", "food": "stew"}),
        ("/followers/feed", {"follower_id": "hold_VTI", "food": "favorite"}),
        ("/followers/name", {"name": name}),
        ("/followers/dress", {"follower_id": "hold_VTI", "item_id": "followers_hood_tide"}),
        ("/followers/collect", {}),
    ]
    for path, body in calls:
        status, out = post(engine, path, **body)
        assert status == 200, (path, out)
        assert not [e for e in out.get("_events", []) if e["kind"] == "money_moved"]
    assert (transfers(engine), balances(engine.ctx())) == money_before


# --- the personal follower ---------------------------------------------------------------------


def test_egg_hatches_on_the_first_deposit_and_takes_one_of_three_names(engine):
    s = get(engine)
    p = s["followers"]["personal"]
    assert p["pose"] == "egg" and not p["hatched"] and p["offered_names"] == []
    assert post(engine, "/followers/name", name="Mote")[0] == 409
    deposit(engine)
    p = get(engine)["followers"]["personal"]
    assert p["hatched"] and p["stage"] == 1 and len(p["offered_names"]) == 3
    assert p["bubble"] == "question"
    assert post(engine, "/followers/name", name="Not Offered")[0] == 422
    chosen = p["offered_names"][1]
    assert post(engine, "/followers/name", name=chosen)[0] == 200
    p = get(engine)["followers"]["personal"]
    assert p["name"] == chosen and p["named"] and p["offered_names"] == []
    assert post(engine, "/followers/name", name="Mote")[0] == 409


def test_kept_weeks_count_weeks_money_landed_in_this_save(engine):
    s = get(engine)
    assert s["followers"]["personal"]["kept_weeks"] == 0
    deposit(engine)
    assert get(engine)["followers"]["personal"]["kept_weeks"] == 1
    deposit(engine)  # a second deposit in the same week is still one week
    assert get(engine)["followers"]["personal"]["kept_weeks"] == 1
    s = advance(engine, 7)  # next week: nothing has landed yet
    assert s["followers"]["personal"]["kept_weeks"] == 1
    deposit(engine, 1_000, to="brk_1")
    p = get(engine)["followers"]["personal"]
    assert p["kept_weeks"] == 2 and p["stage"] == 2 and p["streak"] == 2


def test_a_lean_week_counts_as_kept(engine):
    get(engine)
    ctx = engine.ctx()
    week = date(2026, 10, 18)
    ctx.conn.executemany(
        "INSERT OR REPLACE INTO followers_days (day, extra_cents) VALUES (?, -500)",
        [[(week + timedelta(days=i)).isoformat()] for i in range(7)],
    )
    engine.conn.commit()
    assert flock.week_kept(engine.ctx(), week) is False  # still open
    advance(engine, 5)  # Sunday 10-25: the lean week is finished
    assert flock.week_kept(engine.ctx(), week) is True
    assert flock.missed_week(engine.ctx(), week)[0] is False


def test_growth_stages_never_shrink(engine):
    assert [flock.stage_for(k) for k in (0, 1, 2, 3, 4, 8, 12, 13, 26, 52, 99)] == [
        0,
        1,
        2,
        2,
        3,
        4,
        4,
        5,
        6,
        7,
        7,
    ]
    deposit(engine)
    advance(engine, 7)
    deposit(engine)
    assert get(engine)["followers"]["personal"]["stage"] == 2
    # The money that grew it fails to settle: the follower keeps its size.
    engine.conn.execute("UPDATE transfers SET status = 'failed'")
    engine.conn.commit()
    p = get(engine)["followers"]["personal"]
    assert p["stage"] == 2 and p["hatched"] and p["pose"] != "egg"


# --- holdings ---------------------------------------------------------------------------------


def test_holding_followers_are_sized_by_share_and_over_40_percent_is_a_giant(engine):
    s = get(engine)
    holdings = s["followers"]["holdings"]
    assert {h["symbol"] for h in holdings} == {r["symbol"] for r in s["holdings"]}
    assert sum(h["share"] for h in holdings) == pytest.approx(1.0, abs=0.001)
    assert [h["share"] for h in holdings] == sorted((h["share"] for h in holdings), reverse=True)
    for h in holdings:
        assert h["scale"] == pytest.approx(0.7 + 1.3 * h["share"] ** 0.5, abs=0.01)
        assert not h["giant"]
    assert s["followers"]["giant"] is None

    # Holdings move mid-week: nothing changes until Sunday.
    engine.conn.execute("UPDATE holdings SET value_cents = value_cents * 4 WHERE symbol = 'VTI'")
    engine.conn.commit()
    assert follower(get(engine), "hold_VTI")["giant"] is False

    # A new week's sizes come from that week's holdings (here, the test's own).
    ctx = engine.ctx()
    ctx.conn.execute("DELETE FROM followers_sizes")
    ctx.conn.execute("UPDATE holdings SET value_cents = value_cents * 4 WHERE symbol = 'VTI'")
    engine.conn.commit()
    s = get(engine)
    vti = follower(s, "hold_VTI")
    assert vti["giant"] and vti["scale"] == flock.GIANT_SCALE and vti["share"] > 0.4
    assert s["followers"]["giant"] == "VTI"
    assert sum(h["giant"] for h in s["followers"]["holdings"]) == 1


def test_holdings_resize_once_on_sunday_with_a_quiet_beat(engine):
    get(engine)
    week = date(2026, 10, 25)
    assert not engine.conn.execute(
        "SELECT 1 FROM followers_sizes WHERE week_start = ?", [week.isoformat()]
    ).fetchone()
    s = advance(engine, 5)
    assert engine.conn.execute(
        "SELECT COUNT(*) FROM followers_sizes WHERE week_start = ?", [week.isoformat()]
    ).fetchone()[0] == len(s["followers"]["holdings"])


# --- mourning ---------------------------------------------------------------------------------


def test_a_missed_week_is_mourned_on_monday(engine):
    get(engine)
    s = advance(engine, 5)  # Sunday 10-25: the week is over but nobody mourns on Sunday
    assert not s["followers"]["mourning"] and s["followers"]["graves"] == []
    s = advance(engine, 1)  # Monday 10-26
    f = s["followers"]
    assert f["mourning"] and f["mourning_week"]["week_start"] == "2026-10-18"
    assert [g["week_start"] for g in f["graves"]] == ["2026-10-18"]
    assert all(h["veiled"] and h["pose"] == "veiled" for h in f["holdings"])
    assert f["cultist_pose"] == "veiled"
    assert "mourning" in [a["kind"] for a in s["away"]]

    # Money lands: the veils come off and a flower grows by the candle.
    deposit(engine)
    f = get(engine)["followers"]
    assert not f["mourning"] and f["graves"][0]["flower"]
    assert not any(h["veiled"] for h in f["holdings"])


def test_no_mourning_when_money_landed_that_week(engine):
    deposit(engine)  # Tuesday 10-20, inside the week of 10-18
    s = advance(engine, 6)
    assert not s["followers"]["mourning"] and s["followers"]["graves"] == []


def test_no_mourning_for_a_week_without_extra(engine):
    get(engine)
    engine.conn.executemany(
        "INSERT OR REPLACE INTO followers_days (day, extra_cents) VALUES (?, 0)",
        [[(date(2026, 10, 18) + timedelta(days=i)).isoformat()] for i in range(7)],
    )
    engine.conn.commit()
    s = advance(engine, 6)
    assert not s["followers"]["mourning"] and s["followers"]["graves"] == []


def test_mourning_lifts_by_itself_the_next_monday(engine):
    get(engine)
    advance(engine, 6)
    deposit(engine)  # Monday 10-26: the new week is kept, the old one still has its candle
    s = advance(engine, 7)
    assert not s["followers"]["mourning"]
    assert [g["week_start"] for g in s["followers"]["graves"]] == ["2026-10-18"]


# --- while you were out --------------------------------------------------------------------------


def test_away_beats_queue_once_per_kind_while_away(engine):
    get(engine)
    s = advance(engine, 2)
    kinds = [a["kind"] for a in s["away"]]
    assert kinds.count("poses") == 1 and kinds.count("hug") == 1
    assert kinds.index("poses") < kinds.index("hug")  # lower priority numbers play first
    poses = next(a for a in s["away"] if a["kind"] == "poses")["payload"]
    assert poses["hungry"] >= 1 and poses["band"] == "content"


def test_bank_payday_lands_overnight_and_hatches_the_egg(engine):
    get(engine)
    s = advance(engine, 11)  # Saturday 10-31: the Friday payday moved $350 to savings
    beats = {a["kind"]: a for a in s["away"]}
    assert beats["landed"]["payload"]["amount_cents"] == 35_000
    assert beats["landed"]["priority"] < beats["mourning"]["priority"]
    assert beats["grew"]["payload"] == beats["grew"]["payload"] | {"stage": 1, "from_stage": 0}
    assert s["followers"]["personal"]["hatched"]
    ids = [a["id"] for a in s["away"]]
    assert post(engine, "/away/seen", ids=ids)[0] == 200
    assert get(engine)["away"] == []


# --- dressing -----------------------------------------------------------------------------------


def test_followers_wear_owned_items_from_any_catalog(engine):
    get(engine)
    assert (
        post(engine, "/followers/dress", follower_id="hold_VTI", item_id="followers_hood_tide")[0]
        == 409
    )
    ctx = engine.ctx()
    grant_item(ctx, "followers_hood_tide", via="test")
    grant_item(ctx, "followers_charm_heart", via="test")
    engine.conn.commit()
    status, body = post(
        engine, "/followers/dress", follower_id="hold_VTI", item_id="followers_hood_tide"
    )
    assert status == 200 and body["slot"] == "hat"
    post(engine, "/followers/dress", follower_id="hold_VTI", item_id="followers_charm_heart")
    s = get(engine)
    assert set(follower(s, "hold_VTI")["wearing"]) == {"hat", "aura"}
    wearable = {w["id"]: w for w in s["followers"]["wearables"]}
    assert wearable["followers_hood_tide"]["worn_by"] == ["hold_VTI"]

    # One copy, one wearer: the hood moves over.
    post(engine, "/followers/dress", follower_id="hold_MSFT", item_id="followers_hood_tide")
    s = get(engine)
    assert "hat" not in follower(s, "hold_VTI")["wearing"]
    assert follower(s, "hold_MSFT")["wearing"]["hat"]["id"] == "followers_hood_tide"

    # Taking it off.
    post(engine, "/followers/dress", follower_id="hold_MSFT", item_id="", slot="hat")
    assert follower(get(engine), "hold_MSFT")["wearing"] == {}
    assert (
        post(engine, "/followers/dress", follower_id="hold_MSFT", item_id="", slot="shoes")[0]
        == 422
    )
