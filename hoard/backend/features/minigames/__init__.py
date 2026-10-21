"""The arcade: the mine, fishing and the daily dungeon. Two-minute coin games.

    POST /minigames/start  {game}            -> {run_id, seed, flames_left, full, modifiers}
    POST /minigames/finish {run_id, result}  -> {coins, items, flames_left, full, score, best}
    GET  /minigames/catalog                  -> the content the game draws from

Coins only. Nothing in this feature moves money (test_minigames checks it never imports
or calls the transfer module), and the week reaches the dungeon as yes/no omens.
"""

import json

from backend.core.context import Ctx
from backend.core.router import ApiError, route
from backend.core.services import add_coins, grant_item
from backend.core.state import View, section
from backend.features.minigames import rules
from backend.features.minigames.rules import GAMES


@section(order=55)
def minigames_state(ctx: Ctx, view: View) -> dict:
    facts = rules.week_facts(ctx)
    mods = rules.dungeon_modifiers(facts, rules.depth(ctx))
    (runs, coins) = ctx.conn.execute(
        "SELECT COUNT(*), COALESCE(SUM(coins), 0) FROM minigames_runs "
        "WHERE finished = 1 AND day = ?",
        [ctx.today.isoformat()],
    ).fetchone()
    return {
        "minigames": {
            "flames": {
                "max": rules.flames_per_day(),
                "left": rules.flames_left(ctx),
                "used_today": rules.flames_used(ctx),
            },
            "best": rules.bests(ctx),
            "today": {"runs": runs, "coins": coins},
            "depth": mods["depth"],
            "omens": mods["omens"],
            "relic_waiting": rules.relic_waiting(ctx),
        }
    }


@route("GET", "/minigames/catalog")
def get_catalog(ctx: Ctx) -> dict:
    return rules.catalog()


@route("POST", "/minigames/start")
def start(ctx: Ctx, game: str) -> dict:
    if game not in GAMES:
        raise ApiError(404, f"No game called {game}.")
    left = rules.flames_left(ctx)
    modifiers: dict = {}
    if game == "dungeon":
        modifiers = rules.dungeon_modifiers(rules.week_facts(ctx), rules.depth(ctx))
        modifiers["relic"] = rules.relic_waiting(ctx)
    seed = rules.run_seed(ctx, game)
    cur = ctx.conn.execute(
        "INSERT INTO minigames_runs (game, day, seed, modifiers) VALUES (?, ?, ?, ?)",
        [game, ctx.today.isoformat(), seed, json.dumps(modifiers)],
    )
    return {
        "run_id": cur.lastrowid,
        "game": game,
        "seed": seed,
        "flames_left": left,
        "full": left > 0,
        "modifiers": modifiers,
    }


@route("POST", "/minigames/finish")
def finish(ctx: Ctx, run_id: int, result: dict) -> dict:
    run = ctx.conn.execute("SELECT * FROM minigames_runs WHERE id = ?", [run_id]).fetchone()
    if run is None:
        raise ApiError(404, "No such run.")
    if run["finished"]:
        raise ApiError(409, "That run is already counted.")
    if run["day"] != ctx.today.isoformat():
        raise ApiError(409, "That run belongs to another day.")
    game = run["game"]
    base, score = rules.score_run(game, result)
    full = base > 0 and rules.flames_left(ctx) > 0
    coins = rules.payout(game, base, full)
    if coins:
        add_coins(ctx, coins, f"Arcade: {game}")

    items: list[dict] = []
    depth = None
    if game == "dungeon":
        boss_down = int(result.get("rooms_cleared", 0)) >= rules.ROOMS
        if boss_down and rules.relic_waiting(ctx):
            won = rules.draw_from_bag(ctx)
            grant_item(ctx, won["id"], "minigames_dungeon")
            ctx.events[-1].update(name=won["name"], tier=won["tier"])
            items.append(won)
        broke_all = boss_down and int(result.get("doors_broken", 0)) >= rules.ROOMS
        depth = rules.set_depth(ctx, rules.depth(ctx) + (1 if broke_all else -1))

    ctx.conn.execute(
        "UPDATE minigames_runs SET finished = 1, full = ?, score = ?, coins = ?, result = ?, "
        "item_id = ? WHERE id = ?",
        [
            int(full),
            score,
            coins,
            json.dumps(result),
            items[0]["id"] if items else None,
            run_id,
        ],
    )
    ctx.conn.execute(
        "INSERT INTO events (ts, type, payload) VALUES (?, ?, ?)",
        [
            ctx.today.isoformat(),
            "minigame_run",
            json.dumps({"game": game, "coins": coins, "full": full, "score": score}),
        ],
    )
    out = {
        "run_id": run_id,
        "game": game,
        "coins": coins,
        "base": base,
        "full": full,
        "items": items,
        "score": score,
        "flames_left": rules.flames_left(ctx),
        "best": rules.bests(ctx),
    }
    if depth is not None:
        out["depth"] = depth
    return out
