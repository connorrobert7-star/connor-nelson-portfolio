def test_state(client):
    s = client.get("/state").json()
    assert s["coins"] == 0
    assert {"crops", "tavern", "drains", "shrine", "extra", "week", "house"} <= s.keys()
    assert len(s["accounts"]) == 3 and len(s["holdings"]) == 5 and len(s["debts"]) == 1


def test_state_weeks_ago(client):
    assert client.get("/state", params={"weeks_ago": 3}).json()["window"]["weeks_ago"] == 3
    assert client.get("/state", params={"weeks_ago": 12}).status_code == 404
    assert client.get("/state", params={"weeks_ago": -1}).status_code == 422


def test_extra(client):
    e = client.get("/extra").json()
    assert e["spendable_cents"] >= 0
    assert e["weekly_cap_cents"] == 6000


def test_reading_state_never_changes_balances(client):
    before = client.get("/state").json()["accounts"]
    for w in range(12):
        client.get("/state", params={"weeks_ago": w})
    client.get("/extra")
    assert client.get("/state").json()["accounts"] == before
