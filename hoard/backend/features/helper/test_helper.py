"""Pip's lines: the numbers match the state, nothing pushes a ticker, nothing repeats."""

import re

from backend.core.engine import Engine
from backend.features.helper import lines as L


def _state(engine: Engine) -> dict:
    status, body = engine.handle("GET", "/state")
    assert status == 200, body
    return body


def _all_lines(h: dict) -> list[str]:
    out = [line["text"] for b in h["opening"]["beats"] for line in b["lines"]]
    for b in h["opening"]["beats"]:
        for lines in b.get("by_building", {}).values():
            out += [line["text"] for line in lines]
    out += [line["text"] for line in h["opening"]["end"] + h["opening"]["skip"]]
    out += [t for topic in h["queue"] for t in topic["lines"]]
    return out + h["rest"]


def _topic(h: dict, topic_id: str) -> list[str]:
    return next(t["lines"] for t in h["queue"] if t["id"] == topic_id)


def _beat(h: dict, beat_id: str) -> dict:
    return next(b for b in h["opening"]["beats"] if b["id"] == beat_id)


def test_new_save_starts_the_opening(state: dict) -> None:
    h = state["helper"]
    assert h["name"] == "Pip"
    assert h["opening"]["active"]
    ids = [b["id"] for b in h["opening"]["beats"]]
    assert ids[:3] == ["meet", "case", "book"]
    assert {"village", "sign", "arcade", "gate", "shrine"} <= set(ids)
    assert [t["id"] for t in h["queue"]][:2] == ["emergency_fund", "high_rate_debt"]


def test_emergency_fund_numbers_match_the_wall(engine: Engine) -> None:
    s = _state(engine)
    wall = s["village"]["wall"]
    lines = " ".join(_topic(s["helper"], "emergency_fund"))
    assert L.dollars(wall["balance_cents"]) in lines
    months = wall["balance_cents"] / wall["monthly_expenses_cents"]
    assert f"{months:.1f} months" in lines
    assert L.dollars(wall["monthly_expenses_cents"] * wall["months"]) in lines
    # Fill the fund past three months: the line changes with it.
    engine.conn.execute("UPDATE accounts SET balance_cents = 2000000 WHERE id = 'sav_2'")
    s = _state(engine)
    wall = s["village"]["wall"]
    lines = " ".join(_topic(s["helper"], "emergency_fund"))
    assert "$20,000.00" in lines
    assert f"{2000000 / wall['monthly_expenses_cents']:.1f} months" in lines
    assert "past 3 months" in lines


def test_debt_numbers_match_the_card(state: dict) -> None:
    card = max(state["debts"], key=lambda d: d["apr"])
    lines = " ".join(_topic(state["helper"], "high_rate_debt"))
    assert f"{card['apr']:g}%" in lines
    assert L.dollars(card["balance_cents"]) in lines
    # $100 at the card's APR, for a year: exact cents.
    assert L.dollars(round(100 * card["apr"])) in lines
    assert "$7.00" in lines and "assumed 7%" in lines


def test_no_high_rate_debt_says_so(state: dict) -> None:
    # The sync rewrites debts from the bank every request, so the state is changed here.
    low = {**state, "debts": [{**d, "apr": 5.0} for d in state["debts"]]}
    topic = next(t for t in L.content()["topics"] if t["id"] == "high_rate_debt")
    lines = " ".join(L.topic_lines(None, topic, L.facts(low, L.content()), set()))
    assert "None of your debts" in lines and "8%" in lines


def test_brokerage_and_compounding_numbers(state: dict) -> None:
    h = state["helper"]
    held = sum(x["value_cents"] for x in state["holdings"])
    index = {s["symbol"] for s in state["shop"]["stocks"] if s["kind"] in ("index", "bond")}
    in_index = sum(x["value_cents"] for x in state["holdings"] if x["symbol"] in index)
    assert f"{round(100 * in_index / held)}%" in " ".join(_topic(h, "index_fund"))
    # $5 a week at a flat 7%, compounded weekly, worked out here on its own.
    i, n30 = 0.07 / 52, 30 * 52
    grow30 = 500 * ((1 + i) ** n30 - 1) / i
    grow10 = 500 * ((1 + i) ** 520 - 1) / i
    comp = " ".join(_topic(h, "compounding"))
    assert f"${round(grow10 / 100):,}" in comp and "$2,600" in comp
    assert f"${round(grow30 / 100):,}" in comp and "$7,800" in comp
    assert "assumption" in comp
    fees = " ".join(_topic(h, "fees"))
    brokerage = state["balances"]["brk_1"]
    assert L.dollars(round(brokerage * 0.01)) in fees


def test_opening_beats_use_the_owner_numbers(state: dict) -> None:
    h = state["helper"]
    case = _beat(h, "case")
    vex = [line["text"] for line in case["lines"] if line["who"] == "vex"]
    left = state["casino"]["belt"]["left"]
    assert vex == [L.belt_odds(state)]
    assert vex[0].startswith(f"{sum(left.values())} shells.")
    assert f"{left['rare']} blue" in vex[0]
    assert L.dollars(state["casino"]["can_spend_cents"]) in case["lines"][-1]["text"]
    sign = _beat(h, "sign")
    arcade = next(b for b in state["buildings"]["list"] if b["id"] == "arcade")
    req = arcade["next"]["requires"][0]
    text = sign["by_building"]["arcade"][1]["text"]
    assert L.dollars(req["need"]) in text and L.dollars(req["have"]) in text
    assert "Sunday" in sign["lines"][2]["text"]
    shrine = " ".join(line["text"] for line in _beat(h, "shrine")["lines"])
    assert f"You hold {len(state['holdings'])} now" in shrine


def test_no_line_names_a_ticker_or_pushes_a_buy(state: dict) -> None:
    symbols = L.tickers(state)
    assert {"VTI", "AAPL"} <= symbols
    for text in _all_lines(state["helper"]):
        assert L.fits(text, symbols), text
        assert not set(re.findall(r"[A-Za-z]+", text)) & symbols, text
        assert "!" not in text


def test_fits_catches_tickers_and_nudges() -> None:
    symbols = {"VTI", "NVDA"}
    assert not L.fits("Put it all in NVDA.", symbols)
    assert not L.fits("This one is going up.", symbols)
    assert not L.fits("Worth buying soon", symbols)
    assert not L.fits("Look at that!", symbols)
    assert not L.fits("x" * (L.MAX_CHARS + 1), symbols)
    assert L.fits("An index fund owns a little of many companies.", symbols)


def test_seen_topics_and_beats_never_repeat(engine: Engine) -> None:
    h = _state(engine)["helper"]
    first = h["queue"][0]["id"]
    status, _ = engine.handle("POST", "/helper/seen", body={"topic": first})
    assert status == 200
    status, _ = engine.handle("POST", "/helper/seen", body={"beat": "meet"})
    assert status == 200
    h = _state(engine)["helper"]
    assert first not in [t["id"] for t in h["queue"]]
    assert "meet" not in [b["id"] for b in h["opening"]["beats"]]
    # Every topic heard: the queue is empty and the rest line is not a topic line.
    topic_lines = {t for topic in h["queue"] for t in topic["lines"]}
    for topic in h["queue"]:
        engine.handle("POST", "/helper/seen", body={"topic": topic["id"]})
    h = _state(engine)["helper"]
    assert h["queue"] == []
    assert not set(h["rest"]) & topic_lines


def test_every_beat_seen_ends_the_opening(engine: Engine) -> None:
    for beat in [b["id"] for b in _state(engine)["helper"]["opening"]["beats"]]:
        engine.handle("POST", "/helper/seen", body={"beat": beat})
    h = _state(engine)["helper"]
    assert not h["opening"]["active"] and h["opening"]["beats"] == []
    assert engine.ctx().meta("helper_opening") == "done"


def test_skip_ends_the_opening_for_good(engine: Engine) -> None:
    status, _ = engine.handle("POST", "/helper/skip")
    assert status == 200
    h = _state(engine)["helper"]
    assert not h["opening"]["active"]
    assert h["queue"], "skipping the tour keeps the topics"


def test_unknown_ids_are_refused(engine: Engine) -> None:
    assert engine.handle("POST", "/helper/seen", body={"beat": "nope"})[0] == 422
    assert engine.handle("POST", "/helper/seen", body={"topic": "nope"})[0] == 422


def test_a_save_with_play_in_it_skips_the_opening(engine: Engine) -> None:
    engine.conn.execute(
        "INSERT INTO coin_ledger (delta, reason, created) VALUES (5, 'test', '2026-10-19')"
    )
    assert not _state(engine)["helper"]["opening"]["active"]


def test_reset_replays_in_the_demo(engine: Engine) -> None:
    engine.handle("POST", "/helper/skip")
    assert engine.handle("POST", "/helper/reset")[0] == 200
    assert _state(engine)["helper"]["opening"]["active"]


def test_advisor_lines_are_used_only_when_they_pass(engine: Engine) -> None:
    class Writer:
        name = "test"

        def __init__(self, lines: list[str]) -> None:
            self.lines = lines

        def helper_lines(self, topic_id: str, facts: dict) -> list[str]:
            return self.lines

    engine.providers.advisor = Writer(["Owning many companies spreads the risk."])
    assert _topic(_state(engine)["helper"], "index_fund") == [
        "Owning many companies spreads the risk."
    ]
    engine.providers.advisor = Writer(["VTI is going up, buy it now!"])
    assert _topic(_state(engine)["helper"], "index_fund")[0].startswith("An index fund")
