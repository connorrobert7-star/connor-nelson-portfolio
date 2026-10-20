from backend.features.week.reactions import crops_state


def test_crops_thresholds():
    assert [crops_state(r) for r in (0.5, 0.9, 1.2, 1.6)] == [
        "bumper",
        "healthy",
        "wilting",
        "withered",
    ]


def test_last_week_story(state):
    assert state["window"] == {"start": "2026-10-13", "end": "2026-10-19", "weeks_ago": 0}
    assert state["crops"]["spent_cents"] == 15_005
    assert state["crops"]["state"] == "wilting"
    assert state["tavern"]["spent_cents"] == 3_040
    assert state["tavern"]["visits"] == 3
    assert state["tavern"]["state"] == "quiet"
    assert [d["merchant"] for d in state["drains"]["drains"] if d["new"]] == ["StreamBox+"]
    assert state["drains"]["river"] == "low"
    assert state["shrine"]["state"] == "glowing"


def test_old_weeks_have_no_false_new_drains(engine):
    for weeks_ago in range(1, 12):
        status, s = engine.handle("GET", "/state", {"weeks_ago": weeks_ago})
        assert status == 200
        assert [d["merchant"] for d in s["drains"]["drains"] if d["new"]] == []


def test_ledger_totals_match(state):
    week = state["week"]
    total = sum(t["amount_cents"] for t in week["transactions"])
    assert total == week["out_cents"] - week["in_cents"] == sum(week["by_system"].values())
