from datetime import timedelta

from backend.conftest import TODAY
from backend.core.services import coin_balance
from backend.features.gate import gate
from backend.features.gate.words import say_money
from backend.money.budget import balances


def _state(engine) -> dict:
    status, body = engine.handle("GET", "/state")
    assert status == 200, body
    return body


def _boss(state: dict, debt_id: str) -> dict:
    return next(b for b in state["gate"]["bosses"] if b["debt_id"] == debt_id)


def _attack(engine, debt_id: str, amount_cents: int) -> tuple[int, dict]:
    return engine.handle(
        "POST", "/gate/attack", body={"debt_id": debt_id, "amount_cents": amount_cents}
    )


def _transfers(engine) -> list[dict]:
    return [dict(r) for r in engine.conn.execute("SELECT * FROM transfers ORDER BY id")]


def _advance(engine, days: int) -> dict:
    while days > 0:
        step = min(7, days)
        assert engine.handle("POST", "/clock/advance", body={"days": step})[0] == 200
        days -= step
    return _state(engine)


def _set_hp(engine, debt_id: str, cents: int) -> None:
    """Stand-in for a nearly paid-off debt. The sync replaces it the next morning."""
    with engine.conn:
        engine.conn.execute("UPDATE debts SET balance_cents = ? WHERE id = ?", [cents, debt_id])


def test_bosses_are_debts_smallest_first_with_real_hp(state):
    bosses = state["gate"]["bosses"]
    assert [b["debt_id"] for b in bosses] == ["debt_card", "debt_car", "debt_student"]
    for b in bosses:
        assert b["hp_cents"] == state["balances"][b["debt_id"]]
        assert b["max_hp_cents"] >= b["hp_cents"]
        assert b["next_heal_cents"] == round(b["hp_cents"] * b["apr"] / 1200)
        assert not b["defeated"]
        assert b["look"]["idle"] and b["lines"]["idle"]
        assert b["drop"]["tier"] in ("epic", "legendary")
    names = {b["kind"]: b["name"] for b in bosses}
    assert names == {
        "credit": "The Revolving Maw",
        "auto": "The Axle Ogre",
        "student": "The Bursar",
    }
    assert state["gate"]["can_spend_cents"] == min(
        state["extra"]["extra_cents"], state["caps_remaining_cents"]
    )


def test_stacks_are_minimum_and_fixed_amounts(state):
    card = _boss(state, "debt_card")
    stacks = [(a["amount_cents"], a["kind"]) for a in card["amounts"]]
    assert stacks == [
        (2500, "fixed"),
        (3500, "min"),
        (5000, "fixed"),
        (10000, "fixed"),
        (25000, "fixed"),
    ]
    assert all(a["affordable"] for a in card["amounts"])


def test_attack_moves_exactly_the_amount_to_the_debt(engine):
    before = _state(engine)
    status, res = _attack(engine, "debt_card", 5000)
    assert status == 200, res
    moved = _transfers(engine)
    assert len(moved) == 1
    t = moved[0]
    assert (t["from_account"], t["to_account"], t["amount_cents"]) == ("chk_1", "debt_card", 5000)
    assert res["money"] == {"amount_cents": 5000, "to_account": "debt_card", "status": "simulated"}
    after = _state(engine)
    assert after["balances"]["debt_card"] == before["balances"]["debt_card"] - 5000
    assert after["balances"]["chk_1"] == before["balances"]["chk_1"] - 5000
    for other in ("debt_car", "debt_student", "sav_1", "sav_2"):
        assert after["balances"][other] == before["balances"][other]
    event = engine.conn.execute("SELECT * FROM events WHERE id = ?", [t["event_id"]]).fetchone()
    assert event["type"] == "gate_attack"


def test_damage_equals_dollars(engine):
    for amount in (2500, 3500, 5000, 10000):
        hp = _boss(_state(engine), "debt_card")["hp_cents"]
        status, res = _attack(engine, "debt_card", amount)
        assert status == 200, res
        assert res["damage_cents"] == amount
        assert res["hp_before_cents"] == hp
        assert res["hp_cents"] == hp - amount
        assert _boss(_state(engine), "debt_card")["hp_cents"] == hp - amount


def test_refusal_changes_nothing(engine):
    before = _state(engine)
    extra = before["extra"]["extra_cents"]

    def snapshot() -> tuple:
        return (
            engine.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0],
            engine.conn.execute("SELECT COUNT(*) FROM events").fetchone()[0],
            engine.conn.execute("SELECT COUNT(*) FROM inventory").fetchone()[0],
            _state(engine)["balances"],
        )

    start = snapshot()
    # Over the per-transfer cap.
    status, res = _attack(engine, "debt_car", 50_100)
    assert status == 409 and res["detail"] == "Not this week."
    # Over the week's extra.
    with engine.conn:
        engine.conn.execute("UPDATE accounts SET balance_cents = 0 WHERE id = 'chk_1'")
    status, res = _attack(engine, "debt_card", 2500)
    assert status == 409 and res["detail"] == "Not this week.", (res, extra)
    checking = next(a for a in before["accounts"] if a["id"] == "chk_1")
    with engine.conn:
        engine.conn.execute(
            "UPDATE accounts SET balance_cents = ? WHERE id = 'chk_1'", [checking["balance_cents"]]
        )
    assert snapshot() == start
    # Today's cap used up, then one more.
    assert _attack(engine, "debt_car", 25_000)[0] == 200
    assert _attack(engine, "debt_car", 25_000)[0] == 200
    mid = snapshot()
    status, res = _attack(engine, "debt_card", 2500)
    assert status == 409 and res["detail"] == "Not this week."
    assert snapshot() == mid
    assert start[0] == 0 and mid[0] == 2
    # Bad requests change nothing either.
    assert _attack(engine, "debt_nope", 2500)[0] == 404
    assert _attack(engine, "debt_card", 0)[0] == 422
    assert _attack(engine, "debt_card", 10_000_000)[0] == 409
    assert snapshot() == mid


def test_no_coins_for_money(engine):
    coins = coin_balance(engine.ctx())
    status, res = _attack(engine, "debt_card", 2500)
    assert status == 200
    assert all(e["kind"] != "coins" for e in res.get("_events", []))
    assert coin_balance(engine.ctx()) == coins
    assert engine.conn.execute("SELECT COUNT(*) FROM coin_ledger").fetchone()[0] == 0


def test_heal_once_a_month_on_the_due_day(engine):
    s0 = _state(engine)
    card = _boss(s0, "debt_card")
    assert card["next_heal_on"] == "2026-10-22" and card["days_to_heal"] == 2
    s = _advance(engine, 3)  # through Oct 22, the card's due day
    heals = engine.conn.execute("SELECT * FROM gate_heals ORDER BY id").fetchall()
    assert [(h["debt_id"], h["month"], h["day"]) for h in heals] == [
        ("debt_card", "2026-10", "2026-10-22")
    ]
    card = _boss(s, "debt_card")
    assert card["heal"]["amount_cents"] == heals[0]["amount_cents"] > 0
    assert card["heal"]["line"] == "Interest. " + say_money(heals[0]["amount_cents"]) + "."
    assert [a["kind"] for a in s["away"]].count("gate_heal") == 1
    # Shown, never added: HP is still exactly the bank's balance.
    for b in s["gate"]["bosses"]:
        assert b["hp_cents"] == s["balances"][b["debt_id"]]
    # Seen once, then gone; more days in the same month add no second heal.
    engine.handle("POST", "/gate/seen", body={"heals": [card["heal"]["id"]]})
    s = _advance(engine, 7)
    assert _boss(s, "debt_card")["heal"] is None
    rows = engine.conn.execute("SELECT debt_id, month FROM gate_heals").fetchall()
    assert [tuple(r) for r in rows if r[0] == "debt_card"] == [("debt_card", "2026-10")]
    # Next month heals again, once.
    _advance(engine, 28)
    rows = engine.conn.execute(
        "SELECT month FROM gate_heals WHERE debt_id = 'debt_card' ORDER BY month"
    ).fetchall()
    assert [r[0] for r in rows] == ["2026-10", "2026-11"]
    assert engine.conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0] == 0


def test_heal_is_shown_not_added_in_demo(engine):
    s = _advance(engine, 3)
    assert s["demo"] is True
    ctx = engine.ctx()
    for b in s["gate"]["bosses"]:
        assert b["hp_cents"] == balances(ctx)[b["debt_id"]]


def test_heal_day_is_idempotent(engine):
    ctx = engine.ctx()
    day = TODAY + timedelta(days=2)
    gate.heal_day(ctx, day)
    gate.heal_day(ctx, day)
    rows = ctx.conn.execute("SELECT * FROM gate_heals").fetchall()
    assert len(rows) == 1 and rows[0]["debt_id"] == "debt_card"


def test_bank_payments_queue_auto_attacks_once(engine):
    _state(engine)
    s = _advance(engine, 3)  # the bank pays the card's minimum on Oct 22
    hits = [a for a in s["away"] if a["kind"] == "gate_hit"]
    assert [(h["payload"]["debt_id"], h["payload"]["amount_cents"]) for h in hits] == [
        ("debt_card", 3500)
    ]
    assert hits[0]["payload"]["by"] == "bank"
    s = _advance(engine, 4)
    hits = [a for a in s["away"] if a["kind"] == "gate_hit"]
    assert len(hits) == 1
    # The history before the save started is never replayed.
    assert all(h["payload"]["day"] >= TODAY.isoformat() for h in hits)


def test_kill_grants_the_unique_drop_once(engine):
    _state(engine)
    _set_hp(engine, "debt_card", 2500)
    s = _state(engine)
    card = _boss(s, "debt_card")
    assert card["drop"]["id"] == "gate_maw_mask"
    assert [(a["amount_cents"], a["kind"]) for a in card["amounts"]] == [(2500, "finish")]
    status, res = _attack(engine, "debt_card", 2500)
    assert status == 200, res
    assert res["killed"] is True and res["hp_cents"] == 0
    assert res["drop"]["id"] == "gate_maw_mask" and res["drop"]["tier"] == "legendary"
    items = [e for e in res["_events"] if e["kind"] == "item"]
    assert items == [
        {
            "kind": "item",
            "item_id": "gate_maw_mask",
            "via": "gate:debt_card",
            "name": "Maw Mask",
            "tier": "legendary",
        }
    ]
    # Again: nothing more to hit, nothing more to drop, even after the daily hooks.
    assert _attack(engine, "debt_card", 2500)[0] == 409
    gate.bank_kills(engine.ctx())
    s = _state(engine)
    owned = engine.conn.execute(
        "SELECT COUNT(*) FROM inventory WHERE item_id = 'gate_maw_mask'"
    ).fetchone()[0]
    assert owned == 1
    card = _boss(s, "debt_card")
    assert card["defeated"] and card["drop"]["id"] == "gate_maw_mask"
    assert card["kill"]["shown"] is True
    # The next morning's sync brings the fixture balance back; the drop is still not regranted.
    _advance(engine, 1)
    assert engine.conn.execute("SELECT COUNT(*) FROM inventory").fetchone()[0] == 1


def test_bank_kill_drops_once_and_queues_a_beat(engine):
    _state(engine)
    _set_hp(engine, "debt_car", 0)
    ctx = engine.ctx()
    gate.bank_kills(ctx)
    gate.bank_kills(ctx)
    rows = ctx.conn.execute("SELECT item_id FROM inventory").fetchall()
    assert [r[0] for r in rows] == ["gate_title_key"]
    beats = [a for a in ctx.conn.execute("SELECT kind FROM away_events")]
    assert [b[0] for b in beats] == ["gate_kill"]


def test_no_auto_attack_on_a_paid_off_boss(engine):
    _state(engine)
    ctx = engine.ctx()
    ctx.conn.execute("UPDATE debts SET balance_cents = 0 WHERE id = 'debt_card'")
    ctx.conn.execute(
        "INSERT INTO transactions VALUES ('t_late', 'chk_1', ?, 3500, 'Card', "
        "'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT', '{}')",
        [TODAY.isoformat()],
    )
    gate.bank_hits(ctx, TODAY + timedelta(days=1))
    kinds = [r[0] for r in ctx.conn.execute("SELECT kind FROM away_events")]
    assert "gate_hit" not in kinds


def test_second_boss_of_a_kind_gets_a_spare(engine):
    ctx = engine.ctx()
    first = gate.kill(ctx, {"id": "debt_card", "name": "Card", "kind": "credit"}, via="attack")
    second = gate.kill(ctx, {"id": "debt_card2", "name": "Card 2", "kind": "credit"}, via="attack")
    assert first["id"] == "gate_maw_mask"
    assert second["drops_from"] == "spare"


def test_catalog_items_have_the_shared_shape():
    items = gate.catalog()
    kinds = {i["drops_from"] for i in items}
    assert {"credit", "auto", "student", "other", "spare"} <= kinds
    for i in items:
        assert i["id"].startswith("gate_")
        assert set(i) >= {"id", "name", "tier", "set", "slot", "icon"}
        assert i["slot"] in ("hat", "cloak", "aura", "charm", "follower_skin")
        assert i["icon"]["sheet"].startswith("res://art/packs/")
        assert len(i["icon"]["rect"]) == 4


def test_money_in_words():
    assert say_money(4120) == "Forty-one twenty"
    assert say_money(2624) == "Twenty-six twenty-four"
    assert say_money(305) == "Three oh five"
    assert say_money(120000) == "Twelve hundred dollars"
    assert say_money(99) == "Ninety-nine cents"


def test_seen_takes_bad_input_cleanly(engine):
    s = _advance(engine, 3)
    heal = _boss(s, "debt_card")["heal"]
    for body in (
        {"heals": ["abc"]},
        {"heals": [None]},
        {"heals": [[1]]},
        {"heals": [{"id": 1}]},
        {"heals": [1.5]},
        {"heals": [10**30]},
        {"heals": [True]},
        {"kills": [{"debt_id": "debt_card"}]},
        {"kills": [7]},
        {"heals": "1"},
        {"kills": "debt_card"},
    ):
        status, res = engine.handle("POST", "/gate/seen", body=body)
        assert status == 422, (body, status, res)
    # Nothing was marked by the bad calls.
    assert _boss(_state(engine), "debt_card")["heal"]["id"] == heal["id"]
    # Empty, unknown and already-seen ids are a no-op.
    assert engine.handle("POST", "/gate/seen", body={})[0] == 200
    assert engine.handle("POST", "/gate/seen", body={"heals": [], "kills": []})[0] == 200
    status, res = engine.handle("POST", "/gate/seen", body={"heals": [999], "kills": ["nope"]})
    assert status == 200 and res["seen"] == 0
    status, res = engine.handle("POST", "/gate/seen", body={"heals": [heal["id"]]})
    assert status == 200 and res["seen"] == 1
    status, res = engine.handle("POST", "/gate/seen", body={"heals": [heal["id"], heal["id"]]})
    assert status == 200 and res["seen"] == 0


def test_heal_plays_once_across_the_gate_and_the_away_scene(engine):
    # Played at the gate: gone from the away queue too.
    s = _advance(engine, 3)
    heal = _boss(s, "debt_card")["heal"]
    beats = [a for a in s["away"] if a["kind"] == "gate_heal"]
    assert len(beats) == 1 and beats[0]["payload"]["heal_id"] == heal["id"]
    engine.handle("POST", "/gate/seen", body={"heals": [heal["id"]]})
    s = _state(engine)
    assert _boss(s, "debt_card")["heal"] is None
    assert not [a for a in s["away"] if a["kind"] == "gate_heal"]
    # Next month, played in the away scene first: the gate doesn't play it again.
    s = _advance(engine, 31)
    beats = [a for a in s["away"] if a["kind"] == "gate_heal"]
    assert _boss(s, "debt_card")["heal"] is not None and beats
    engine.handle("POST", "/away/seen", body={"ids": [a["id"] for a in s["away"]]})
    assert _boss(_state(engine), "debt_card")["heal"] is None


def test_bank_kill_plays_once_across_the_gate_and_the_away_scene(engine):
    _state(engine)
    _set_hp(engine, "debt_car", 0)
    gate.bank_kills(engine.ctx())
    s = _state(engine)
    assert _boss(s, "debt_car")["kill"]["shown"] is False
    beat = next(a for a in s["away"] if a["kind"] == "gate_kill")
    engine.handle("POST", "/away/seen", body={"ids": [beat["id"]]})
    assert _boss(_state(engine), "debt_car")["kill"]["shown"] is True
    # And the other way round.
    _set_hp(engine, "debt_card", 0)
    gate.bank_kills(engine.ctx())
    engine.handle("POST", "/gate/seen", body={"kills": ["debt_card"]})
    s = _state(engine)
    assert _boss(s, "debt_card")["kill"]["shown"] is True
    assert not [a for a in s["away"] if a["kind"] == "gate_kill"]
