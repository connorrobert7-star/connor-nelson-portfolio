"""Pip, the owner's familiar: a short opening on a new save, then ideas on tap.

state.helper carries what Pip can say right now, already filled from the owner's numbers:
the opening beats not seen yet (each tied to a place the owner walks to), and the queue of
teaching topics not heard yet. The game shows them as speech bubbles and reports back with
POST /helper/seen, so nothing is said twice. Progress lives in meta:

    helper_opening       "on" for a new save until every beat is seen or skipped; else "done"
    helper_beats_seen    JSON list of opening beat ids
    helper_topics_seen   JSON list of topic ids

Pip teaches ideas. He never names a ticker, never says anything is going up or worth
buying, never reads a live price, and never moves money.
"""

import json

from backend.core.context import Ctx
from backend.core.router import ApiError, route
from backend.core.state import finalizer
from backend.features.helper import lines as L

OPENING_KEY = "helper_opening"
BEATS_KEY = "helper_beats_seen"
TOPICS_KEY = "helper_topics_seen"


def _seen(ctx: Ctx, key: str) -> list[str]:
    try:
        raw = json.loads(ctx.meta(key) or "[]")
    except ValueError:
        raw = []
    return [str(x) for x in raw] if isinstance(raw, list) else []


def _add_seen(ctx: Ctx, key: str, ids: list[str]) -> list[str]:
    seen = _seen(ctx, key)
    seen += [i for i in ids if i not in seen]
    ctx.set_meta(key, json.dumps(seen))
    return seen


def _played_before(ctx: Ctx) -> bool:
    """A save that already has play in it (from before Pip existed) skips the opening."""
    for table in ("transfers", "inventory", "coin_ledger"):
        if ctx.conn.execute(f"SELECT 1 FROM {table} LIMIT 1").fetchone():
            return True
    return False


def opening_status(ctx: Ctx) -> str:
    status = ctx.meta(OPENING_KEY)
    if status is None:
        status = "done" if _played_before(ctx) else "on"
        ctx.set_meta(OPENING_KEY, status)
    return status


def helper_state(ctx: Ctx, state: dict) -> dict:
    cfg = L.content()
    f = L.facts(state, cfg)
    symbols = L.tickers(state)
    beats_seen = set(_seen(ctx, BEATS_KEY))
    beats = []
    if opening_status(ctx) == "on":
        needs = L.sign_needs(state)
        for beat in cfg["opening"]:
            if beat["id"] in beats_seen:
                continue
            if beat["id"] == "sign" and not needs:
                continue  # no sign is up anywhere: nothing to point at
            entry = {"id": beat["id"], "place": beat["place"], "near": beat["near"]}
            if beat["id"] == "sign":
                entry["by_building"] = {
                    b: L.beat_lines(beat, {**f, "sign_need": need}) for b, need in needs.items()
                }
                entry["lines"] = next(iter(entry["by_building"].values()))
            else:
                entry["lines"] = L.beat_lines(beat, f)
            beats.append(entry)
    topics_seen = set(_seen(ctx, TOPICS_KEY))
    queue = [
        {"id": t["id"], "lines": L.topic_lines(ctx.providers.advisor, t, f, symbols)}
        for t in cfg["topics"]
        if t["id"] not in topics_seen
    ]
    return {
        "name": cfg["name"],
        "opening": {
            "active": bool(beats),
            "beats": beats,
            "end": [{"who": "pip", "text": t} for t in cfg["end"]],
            "skip": [{"who": "pip", "text": t} for t in cfg["skip"]],
        },
        "queue": queue,
        "rest": list(cfg["rest"]),
    }


@finalizer(order=80)
def helper(ctx: Ctx, state: dict) -> dict:
    return {"helper": helper_state(ctx, state)}


@route("POST", "/helper/seen")
def post_seen(ctx: Ctx, beat: str = "", topic: str = "") -> dict:
    """The game has shown an opening beat or a topic. Neither is said again."""
    cfg = L.content()
    if beat:
        if beat not in {b["id"] for b in cfg["opening"]}:
            raise ApiError(422, f"No opening beat {beat}.")
        seen = _add_seen(ctx, BEATS_KEY, [beat])
        if all(b["id"] in seen for b in cfg["opening"]):
            ctx.set_meta(OPENING_KEY, "done")
    if topic:
        if topic not in {t["id"] for t in cfg["topics"]}:
            raise ApiError(422, f"No topic {topic}.")
        _add_seen(ctx, TOPICS_KEY, [topic])
    return {"beats_seen": _seen(ctx, BEATS_KEY), "topics_seen": _seen(ctx, TOPICS_KEY)}


@route("POST", "/helper/skip")
def post_skip(ctx: Ctx) -> dict:
    """Two taps on Pip: the opening is over for good."""
    _add_seen(ctx, BEATS_KEY, [b["id"] for b in L.content()["opening"]])
    ctx.set_meta(OPENING_KEY, "done")
    return {"opening": "done"}


@route("POST", "/helper/reset")
def post_reset(ctx: Ctx) -> dict:
    """Demo only: hear the opening and every topic again."""
    if not ctx.demo:
        raise ApiError(403, "Only the demo can replay the opening.")
    ctx.set_meta(OPENING_KEY, "on")
    ctx.set_meta(BEATS_KEY, "[]")
    ctx.set_meta(TOPICS_KEY, "[]")
    return {"opening": "on"}
