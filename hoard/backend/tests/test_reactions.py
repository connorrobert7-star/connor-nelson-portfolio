from backend.content import category_map
from backend.game.reactions import crops_state, village_reactions
from backend.tests.conftest import TODAY


def test_crops_thresholds():
    assert [crops_state(r) for r in (0.5, 0.9, 1.2, 1.6)] == [
        "bumper",
        "healthy",
        "wilting",
        "withered",
    ]


def test_last_week_story(conn):
    v = village_reactions(conn, category_map(), TODAY)
    assert v["window"] == {"start": "2026-10-13", "end": "2026-10-19", "weeks_ago": 0}
    assert v["crops"]["spent_cents"] == 15005
    assert v["crops"]["state"] == "wilting"
    assert v["tavern"] == {
        "spent_cents": 3040,
        "budget_cents": 8000,
        "ratio": 0.38,
        "visits": 3,
        "state": "quiet",
    }
    new = [d["merchant"] for d in v["drains"]["drains"] if d["new"]]
    assert new == ["StreamBox+"]
    assert v["drains"]["river"] == "low"
    assert v["shrine"]["state"] == "glowing"


def test_old_weeks_have_no_false_new_drains(conn):
    for weeks_ago in range(12):
        v = village_reactions(conn, category_map(), TODAY, weeks_ago)
        new = [d["merchant"] for d in v["drains"]["drains"] if d["new"]]
        assert new == ([] if weeks_ago else ["StreamBox+"])


def test_ledger_totals_match(conn):
    week = village_reactions(conn, category_map(), TODAY)["week"]
    total = sum(t["amount_cents"] for t in week["transactions"])
    assert total == week["out_cents"] - week["in_cents"]
    assert total == sum(week["by_system"].values())
