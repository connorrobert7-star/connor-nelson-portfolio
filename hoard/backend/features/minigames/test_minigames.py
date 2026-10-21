import ast
from datetime import timedelta
from pathlib import Path

import pytest

from backend.conftest import TODAY
from backend.features.minigames import rules
from backend.features.minigames.sim import simulate_dungeon

HERE = Path(__file__).parent

SAVER = {"tavern": "quiet", "crops": "bumper", "river": "high", "landed": True, "streak": 6}
SPENDER = {"tavern": "packed", "crops": "withered", "river": "low", "landed": False, "streak": 0}


def start(engine, game: str) -> dict:
    status, body = engine.handle("POST", "/minigames/start", body={"game": game})
    assert status == 200, body
    return body


def finish(engine, run_id: int, result: dict) -> tuple[int, dict]:
    return engine.handle("POST", "/minigames/finish", body={"run_id": run_id, "result": result})


def play(engine, game: str, result: dict) -> dict:
    run = start(engine, game)
    status, body = finish(engine, run["run_id"], result)
    assert status == 200, body
    return body


BIG_MINE = {"ore": {"copper": 40, "silver": 30, "gold": 20, "gem": 10}, "fever": 500, "depth": 30}
SMALL_MINE = {"ore": {"copper": 3, "silver": 1}, "depth": 2}


# --- coins and caps -------------------------------------------------------------------


def test_state_section(state):
    mg = state["minigames"]
    assert mg["flames"] == {"max": 3, "left": 3, "used_today": 0}
    assert mg["best"] == {"mine": 0, "fishing": 0, "dungeon": 0}
    assert mg["relic_waiting"] is True
    # The scripted week: quiet tavern, wilting crops, a new subscription, a payday.
    assert mg["omens"] == ["wilting", "leech", "landed"]


def test_catalog_has_everything_the_game_draws(engine):
    status, cat = engine.handle("GET", "/minigames/catalog")
    assert status == 200
    assert len(cat["items"]) >= 10
    assert {o["id"] for o in cat["ores"]["ores"]} == {"copper", "silver", "gold", "gem"}
    assert len(cat["fish"]["fish"]) >= 10
    assert len(cat["dungeon"]["rooms"]) == 4


def test_items_share_the_cosmetic_shape():
    game_dir = Path(__file__).resolve().parents[3] / "game"
    ids = set()
    for it in rules.content("items")["items"]:
        assert set(it) == {"id", "name", "tier", "set", "slot", "icon"}
        assert it["id"].startswith("minigames_")
        assert it["tier"] in ("common", "rare", "epic", "legendary", "mythic")
        assert it["slot"] in ("hat", "cloak", "aura", "charm", "follower_skin")
        sheet = it["icon"]["sheet"]
        assert (game_dir / sheet.removeprefix("res://")).exists(), sheet
        assert len(it["icon"]["rect"]) == 4
        ids.add(it["id"])
    assert len(ids) >= 10


def test_every_sheet_in_the_content_exists():
    game_dir = Path(__file__).resolve().parents[3] / "game"

    def walk(node):
        if isinstance(node, dict):
            for v in node.values():
                yield from walk(v)
        elif isinstance(node, list):
            for v in node:
                yield from walk(v)
        elif isinstance(node, str) and node.startswith("res://"):
            yield node

    for name in ("ores", "fish", "dungeon", "items"):
        for path in walk(rules.content(name)):
            assert (game_dir / path.removeprefix("res://")).exists(), path


def test_mine_pays_ore_values_and_caps_per_game(engine):
    small = play(engine, "mine", SMALL_MINE)
    assert small["base"] == 3 * 1 + 1 * 2
    assert small["coins"] == 5  # every run that earned anything pays the minimum
    big = play(engine, "mine", BIG_MINE)
    assert big["base"] > 120 and big["coins"] == 120
    assert big["full"] is True


def test_fishing_and_dungeon_caps(engine):
    fish = play(engine, "fishing", {"caught": ["old_coil"] * 24})
    assert fish["coins"] == 120
    dungeon = play(engine, "dungeon", {"rooms_cleared": 4, "doors_broken": 4})
    assert dungeon["coins"] == sum(rules.content("dungeon")["room_coins"])
    assert dungeon["coins"] <= rules.content("games")["games"]["dungeon"]["cap"]


def test_impossible_results_are_refused(engine):
    run = start(engine, "mine")
    assert finish(engine, run["run_id"], {"ore": {"copper": 500}})[0] == 422
    assert finish(engine, run["run_id"], {"ore": {"mithril": 1}})[0] == 422
    assert finish(engine, run["run_id"], {"ore": {"copper": -3}})[0] == 422
    assert finish(engine, run["run_id"], {"ore": {"copper": 1.5}})[0] == 422
    run = start(engine, "fishing")
    assert finish(engine, run["run_id"], {"caught": ["boot"]})[0] == 422
    assert finish(engine, run["run_id"], {"caught": ["minnow"] * 25})[0] == 422
    assert engine.handle("POST", "/minigames/start", body={"game": "slots"})[0] == 404
    assert finish(engine, 9999, {})[0] == 404


def test_a_run_counts_once(engine):
    run = start(engine, "mine")
    assert finish(engine, run["run_id"], SMALL_MINE)[0] == 200
    assert finish(engine, run["run_id"], SMALL_MINE)[0] == 409


def test_coins_land_in_the_purse(engine, state):
    before = state["coins"]
    paid = play(engine, "mine", BIG_MINE)
    after = engine.handle("GET", "/state")[1]
    assert after["coins"] == before + paid["coins"]
    assert after["minigames"]["today"] == {"runs": 1, "coins": paid["coins"]}
    assert after["minigames"]["best"]["mine"] == 30


# --- the lantern ----------------------------------------------------------------------


def test_three_flames_then_a_quarter(engine):
    paid = [play(engine, "mine", BIG_MINE) for _ in range(5)]
    assert [p["full"] for p in paid] == [True, True, True, False, False]
    assert [p["coins"] for p in paid] == [120, 120, 120, 30, 30]
    assert [p["flames_left"] for p in paid] == [2, 1, 0, 0, 0]
    assert rules.flames_used(engine.ctx()) == 3


def test_flames_are_shared_across_games(engine):
    play(engine, "mine", SMALL_MINE)
    play(engine, "fishing", {"caught": ["minnow"]})
    play(engine, "dungeon", {"rooms_cleared": 1})
    assert play(engine, "fishing", {"caught": ["minnow"] * 4})["full"] is False


def test_an_empty_run_burns_no_flame(engine):
    empty = play(engine, "mine", {"ore": {}})
    assert empty["coins"] == 0 and empty["full"] is False and empty["flames_left"] == 3


def test_flames_refill_at_the_day_line(engine):
    for _ in range(3):
        play(engine, "mine", SMALL_MINE)
    assert engine.handle("GET", "/state")[1]["minigames"]["flames"]["left"] == 0
    engine.handle("POST", "/clock/advance", body={"days": 1})
    s = engine.handle("GET", "/state")[1]
    assert s["minigames"]["flames"] == {"max": 3, "left": 3, "used_today": 0}
    assert play(engine, "mine", SMALL_MINE)["full"] is True


def test_yesterdays_run_cannot_be_finished_today(engine):
    run = start(engine, "mine")
    engine.handle("POST", "/clock/advance", body={"days": 1})
    assert finish(engine, run["run_id"], SMALL_MINE)[0] == 409


# --- modifiers from the real week -----------------------------------------------------


def test_modifiers_mapping_bad_week():
    m = rules.dungeon_modifiers(SPENDER)
    assert m["omens"] == ["packed", "withered", "leech"]
    assert m["enemy_speed"] > 1.0
    assert m["party_hp"] < 1.0
    assert m["leech"] is True and m["buff"] is False
    assert m["followers"] == 2 and m["extra_follower"] is False
    assert [i["id"] for i in m["idols"]] == ["bell"]  # a broke week still plays


def test_modifiers_mapping_good_week():
    m = rules.dungeon_modifiers(SAVER)
    assert m["omens"] == ["landed", "streak"]
    assert m["enemy_speed"] == 1.0 and m["party_hp"] == 1.0
    assert m["leech"] is False and m["buff"] is True
    assert m["followers"] == 3 and m["extra_follower"] is True
    ids = [i["id"] for i in m["idols"]]
    assert ids == ["green_fields", "bell", "quiet_tavern", "high_river", "lit_shrine", "streak"]
    streak = next(i for i in m["idols"] if i["id"] == "streak")
    assert streak["value"] == 2.2


def test_modifiers_each_fact_alone():
    plain = {"tavern": "quiet", "crops": "healthy", "river": "high", "landed": False, "streak": 0}
    assert rules.dungeon_modifiers(plain)["omens"] == []
    assert rules.dungeon_modifiers({**plain, "tavern": "packed"})["omens"] == ["packed"]
    assert rules.dungeon_modifiers({**plain, "crops": "wilting"})["party_hp"] == 0.75
    assert rules.dungeon_modifiers({**plain, "crops": "withered"})["party_hp"] == 0.6
    assert rules.dungeon_modifiers({**plain, "river": "low"})["leech"] is True
    assert rules.dungeon_modifiers({**plain, "landed": True})["buff"] is True
    assert rules.dungeon_modifiers({**plain, "streak": 1})["extra_follower"] is False
    assert rules.dungeon_modifiers({**plain, "streak": 2})["extra_follower"] is True
    assert (
        next(
            i
            for i in rules.dungeon_modifiers({**plain, "streak": 40})["idols"]
            if i["id"] == "streak"
        )["value"]
        == 3
    )  # capped


def test_modifiers_never_read_dollars():
    """Omens are yes/no facts: a $1 week and a $10,000 week deal the same dungeon."""
    assert rules.dungeon_modifiers({**SAVER, "landed": 1}) == rules.dungeon_modifiers(
        {**SAVER, "landed": 1_000_000}
    )


def test_depth_raises_targets_not_pay():
    d0 = rules.dungeon_modifiers(SAVER, 0)
    d3 = rules.dungeon_modifiers(SAVER, 3)
    assert d3["targets"][0] == round(d0["targets"][0] * 1.7**3)
    assert rules.payout("dungeon", 40, True) == rules.payout("dungeon", 40, True)


def test_depth_ladder(engine):
    out = play(engine, "dungeon", {"rooms_cleared": 4, "doors_broken": 4})
    assert out["depth"] == 1
    out = play(engine, "dungeon", {"rooms_cleared": 4, "doors_broken": 2})
    assert out["depth"] == 0
    assert play(engine, "dungeon", {"rooms_cleared": 2})["depth"] == 0  # never below zero


def test_start_returns_the_week_for_the_dungeon(engine):
    run = start(engine, "dungeon")
    m = run["modifiers"]
    assert m["omens"] == ["wilting", "leech", "landed"]
    assert m["relic"] is True and m["targets"][0] == 220
    assert start(engine, "dungeon")["seed"] == run["seed"]  # one layout a day
    assert start(engine, "mine")["modifiers"] == {}


def test_kept_week_streak(ctx):
    from backend.money.transfer import move

    # The scripted history: a payday transfer landed last week, none the week before.
    assert rules.kept_week_streak(ctx) == 1
    move(ctx, "chk_1", "sav_1", 500, "test", {"type": "test"})
    assert rules.kept_week_streak(ctx) == 2  # this week counts once something lands


def test_coin_parity_saver_and_spender_earn_the_same():
    """Fixed pay per room: the week's omens change the fight, never the coins. A hands-off
    run with every bad omen still clears all four rooms inside the fight clock."""
    limit = rules.content("dungeon")["fight_seconds"]
    monthly = {}
    for name, facts in (("saver", SAVER), ("spender", SPENDER)):
        run = simulate_dungeon(rules.dungeon_modifiers(facts))
        assert run["rooms_cleared"] == rules.ROOMS, (name, run)
        assert run["fight_seconds"] < limit * 0.9, (name, run)
        base, _ = rules.score_run("dungeon", {"rooms_cleared": run["rooms_cleared"]})
        monthly[name] = 30 * rules.payout("dungeon", base, True)
    assert monthly["saver"] == monthly["spender"]


def test_good_weeks_break_doors_bad_weeks_still_open_them():
    """The cascade is the spectacle: a saver's shelf beats the carved number by a mile."""

    def cascade(mods: dict, chips: int) -> float:
        mult = mods["base_mult"]
        for idol in mods["idols"]:
            if idol["kind"] == "chips":
                chips += idol["value"]
            elif idol["kind"] == "mult":
                mult += idol["value"]
            elif idol["kind"] == "mult_per_follower":
                mult += idol["value"] * mods["followers"]
            else:
                mult *= idol["value"]
        return chips * mult

    good = rules.dungeon_modifiers(SAVER)
    run = simulate_dungeon(good)
    assert cascade(good, run["chips"][0]) > 10 * good["targets"][0]


# --- the shuffle bag ------------------------------------------------------------------


def test_shuffle_bag_no_repeats_until_the_set_is_done(ctx):
    catalog = {i["id"] for i in rules.content("items")["items"]}
    first = [rules.draw_from_bag(ctx)["id"] for _ in catalog]
    assert set(first) == catalog and len(first) == len(set(first))
    second = [rules.draw_from_bag(ctx)["id"] for _ in catalog]
    assert set(second) == catalog
    assert ctx.meta("minigames_bag_cycle") == "2"


def test_the_boss_drops_one_cosmetic_a_day(engine):
    first = play(engine, "dungeon", {"rooms_cleared": 4, "doors_broken": 4})
    assert len(first["items"]) == 1
    it = first["items"][0]
    assert it["id"].startswith("minigames_")
    owned = [r["item_id"] for r in engine.conn.execute("SELECT item_id FROM inventory")]
    assert owned == [it["id"]]
    assert play(engine, "dungeon", {"rooms_cleared": 4, "doors_broken": 4})["items"] == []
    assert engine.handle("GET", "/state")[1]["minigames"]["relic_waiting"] is False
    assert play(engine, "dungeon", {"rooms_cleared": 3})["items"] == []
    engine.handle("POST", "/clock/advance", body={"days": 1})
    again = play(engine, "dungeon", {"rooms_cleared": 4})
    assert len(again["items"]) == 1 and again["items"][0]["id"] != it["id"]


def test_item_event_names_the_cosmetic(engine):
    run = start(engine, "dungeon")
    status, body = finish(engine, run["run_id"], {"rooms_cleared": 4, "doors_broken": 4})
    items = [e for e in body["_events"] if e["kind"] == "item"]
    assert items and items[0]["name"] == body["items"][0]["name"]
    assert items[0]["tier"] == body["items"][0]["tier"]


def test_no_boss_no_cosmetic(engine):
    assert play(engine, "dungeon", {"rooms_cleared": 3})["items"] == []
    assert play(engine, "mine", BIG_MINE)["items"] == []
    assert play(engine, "fishing", {"caught": ["old_coil"]})["items"] == []


# --- no money moves, anywhere ----------------------------------------------------------


def _money(engine) -> tuple:
    transfers = engine.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0]
    s = engine.handle("GET", "/state")[1]
    return transfers, s["balances"], s["extra"]["extra_cents"], s["caps_remaining_cents"]


def test_no_money_moves_in_any_game(engine):
    before = _money(engine)
    for _ in range(3):
        for game, result in (
            ("mine", BIG_MINE),
            ("fishing", {"caught": ["old_coil", "minnow"]}),
            ("dungeon", {"rooms_cleared": 4, "doors_broken": 4}),
        ):
            body = play(engine, game, result)
            assert all(e["kind"] != "money_moved" for e in body.get("_events", []))
    engine.handle("GET", "/minigames/catalog")
    assert _money(engine) == before


def test_minigames_never_touch_the_transfer_module():
    sources = [p for p in HERE.glob("*.py") if not p.name.startswith("test_")]
    assert len(sources) >= 3
    for path in sources:
        tree = ast.parse(path.read_text())
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom):
                assert node.module != "backend.money.transfer", path
                assert "move" not in {a.name for a in node.names}, path
            if isinstance(node, ast.Import):
                assert all("transfer" not in a.name for a in node.names), path
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                assert node.func.id != "move", path


def test_money_never_buys_coins_here(engine):
    """Landing money changes the omens, never the coins a run pays."""
    from backend.money.transfer import move

    plain = play(engine, "mine", BIG_MINE)["coins"]
    with engine.conn:
        move(engine.ctx(), "chk_1", "sav_1", 2_000, "test", {"type": "test"})
    assert play(engine, "mine", BIG_MINE)["coins"] == plain


@pytest.mark.parametrize("days", [1, 7])
def test_state_survives_the_clock(engine, days):
    engine.handle("POST", "/clock/advance", body={"days": days})
    s = engine.handle("GET", "/state")[1]
    assert s["today"] == (TODAY + timedelta(days=days)).isoformat()
    assert s["minigames"]["flames"]["left"] == 3
