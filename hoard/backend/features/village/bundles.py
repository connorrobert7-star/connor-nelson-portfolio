"""Offering tablets by the ruins, filled from real behavior.

Each bundle names a detector that counts qualifying things in the ledger and the
game's own records since the bundle epoch (the Sunday of the week before the save
began, so the first session starts with what really happened that week). Sockets
fill up to `need`. A filled socket is written down and never empties; when every
socket of a ruin's bundles is full the ruin is restored for good.

Nothing here moves money or grants coins: bundles fill from money that already
landed, and their only reward is a building. Stock buys at the shop counter never
fill a socket (no celebrations for buys).
"""

import json
from collections import Counter
from collections.abc import Callable
from datetime import date, timedelta
from functools import cache

from backend.content import CONTENT
from backend.core.context import Ctx
from backend.core.dates import week_start
from backend.money.budget import LANDING_CATEGORIES, OWN_ACCOUNTS
from backend.sync import anchor

LOAN_KINDS = {
    "LOAN_PAYMENTS_CAR_PAYMENT": "auto",
    "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT": "credit",
    "LOAN_PAYMENTS_STUDENT_LOAN_PAYMENT": "student",
}


@cache
def bundle_config() -> dict:
    return json.loads((CONTENT / "village" / "bundles.json").read_text())


def epoch(ctx: Ctx) -> date:
    return week_start(anchor(ctx) - timedelta(days=7))


def _marks(items: list | tuple) -> str:
    return ",".join("?" * len(items))


def _weeks(ctx: Ctx, since: date, complete_only: bool) -> list[tuple[date, date]]:
    """Sunday-to-Saturday weeks from `since`. A week is complete once its Saturday has synced."""
    out = []
    start = week_start(since)
    while start <= ctx.today:
        end = start + timedelta(days=6)
        if not complete_only or end < ctx.today:
            out.append((start, end))
        start += timedelta(days=7)
    return out


def _spent(ctx: Ctx, systems: tuple[str, ...], start: date, end: date) -> int:
    cats = ctx.cmap.categories_for(*systems)
    (total,) = ctx.conn.execute(
        f"""SELECT COALESCE(SUM(amount_cents), 0) FROM transactions
            WHERE category IN ({_marks(cats)}) AND date BETWEEN ? AND ?""",
        [*cats, start.isoformat(), end.isoformat()],
    ).fetchone()
    return total


def _not_a_stock_buy(ctx: Ctx) -> str:
    """SQL that leaves out transfers paying for shares at the shop counter."""
    has_orders = ctx.conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'orders'"
    ).fetchone()
    return " AND id NOT IN (SELECT transfer_id FROM orders)" if has_orders else ""


def _landings(ctx: Ctx, start: date, end: date) -> tuple[int, int]:
    """(count, cents) of money that landed in own accounts between start and end, inclusive:
    the game's transfers (not stock buys) and the bank's savings and investment transfers."""
    game = ctx.conn.execute(
        f"""SELECT COUNT(*), COALESCE(SUM(amount_cents), 0) FROM transfers
            WHERE status != 'failed' AND to_account IN ({_marks(OWN_ACCOUNTS)})
              AND created BETWEEN ? AND ?{_not_a_stock_buy(ctx)}""",
        [*OWN_ACCOUNTS, start.isoformat(), end.isoformat()],
    ).fetchone()
    bank = ctx.conn.execute(
        f"""SELECT COUNT(*), COALESCE(SUM(amount_cents), 0) FROM transactions
            WHERE amount_cents > 0 AND category IN ({_marks(LANDING_CATEGORIES)})
              AND date BETWEEN ? AND ?""",
        [*LANDING_CATEGORIES, start.isoformat(), end.isoformat()],
    ).fetchone()
    return game[0] + bank[0], game[1] + bank[1]


# --- detectors: each returns how many qualifying things happened since `since` ---------


def groceries_under_budget(ctx: Ctx, since: date, bundle: dict) -> int:
    """Complete weeks with groceries at or under the weekly budget."""
    budget = ctx.cmap.systems["crops"]["budget_cents"]
    return sum(
        1
        for start, end in _weeks(ctx, since, complete_only=True)
        if _spent(ctx, ("crops",), start, end) <= budget
    )


def no_spend_week(ctx: Ctx, since: date, bundle: dict) -> int:
    """Complete weeks with nothing spent at the tavern or the market."""
    return sum(
        1
        for start, end in _weeks(ctx, since, complete_only=True)
        if _spent(ctx, ("tavern", "market"), start, end) == 0
    )


def deposits(ctx: Ctx, since: date, bundle: dict) -> int:
    """Each time money landed in an own account: game transfers and the bank's own."""
    return _landings(ctx, since, ctx.today)[0]


def week_landed(ctx: Ctx, since: date, bundle: dict) -> int:
    """Weeks (this one included, as it goes) where at least `cents` landed in own accounts."""
    need = int(bundle["cents"])
    return sum(
        1
        for start, end in _weeks(ctx, since, complete_only=False)
        if _landings(ctx, start, end)[1] >= need
    )


def debt_payment(ctx: Ctx, since: date, bundle: dict) -> int:
    """Payments made at the gate, plus bank loan payments above the minimum."""
    debts = {r["id"]: dict(r) for r in ctx.conn.execute("SELECT * FROM debts")}
    count = 0
    if debts:
        (count,) = ctx.conn.execute(
            f"""SELECT COUNT(*) FROM transfers WHERE status != 'failed'
                AND to_account IN ({_marks(list(debts))}) AND created >= ?""",
            [*debts, since.isoformat()],
        ).fetchone()
    minimums = {d["kind"]: d["min_payment_cents"] for d in debts.values()}
    for r in ctx.conn.execute(
        "SELECT category, amount_cents FROM transactions "
        "WHERE category LIKE 'LOAN_PAYMENTS%' AND amount_cents > 0 AND date >= ?",
        [since.isoformat()],
    ):
        minimum = minimums.get(LOAN_KINDS.get(r["category"], ""), 0)
        if r["amount_cents"] > minimum:
            count += 1
    return count


def three_flames_day(ctx: Ctx, since: date, bundle: dict) -> int:
    """Days where every lantern flame was burned on minigame runs.

    A run is a game event of a flame type, or a coin payout whose reason names a
    minigame (content/village/bundles.json lists both, so the arcade's own wording
    can be matched without touching code)."""
    cfg = bundle_config()
    per_day: Counter[str] = Counter()
    kinds = list(cfg.get("flame_events", []))
    if kinds:
        for r in ctx.conn.execute(
            f"SELECT ts FROM events WHERE type IN ({_marks(kinds)}) AND ts >= ?",
            [*kinds, since.isoformat()],
        ):
            per_day[r["ts"][:10]] += 1
    reasons = [s.lower() for s in cfg.get("flame_coin_reasons", [])]
    coin_days: Counter[str] = Counter()
    for r in ctx.conn.execute(
        "SELECT reason, created FROM coin_ledger WHERE delta > 0 AND created >= ?",
        [since.isoformat()],
    ):
        text = r["reason"].lower()
        if any(text.startswith(s) or f" {s}" in text for s in reasons):
            coin_days[r["created"][:10]] += 1
    days = set(per_day) | set(coin_days)
    need = int(cfg.get("flames_per_day", 3))
    return sum(1 for d in days if max(per_day[d], coin_days[d]) >= need)


DETECTORS: dict[str, Callable[[Ctx, date, dict], int]] = {
    "groceries_under_budget": groceries_under_budget,
    "no_spend_week": no_spend_week,
    "deposits": deposits,
    "week_landed": week_landed,
    "debt_payment": debt_payment,
    "three_flames_day": three_flames_day,
}


# --- progress, persistence ------------------------------------------------------------


def detected(ctx: Ctx) -> dict[str, int]:
    since = epoch(ctx)
    out = {}
    for ruin in bundle_config()["ruins"]:
        for b in ruin["bundles"]:
            out[b["id"]] = min(int(b["need"]), DETECTORS[b["detector"]](ctx, since, b))
    return out


def _stored(ctx: Ctx) -> dict[str, dict[int, bool]]:
    out: dict[str, dict[int, bool]] = {}
    for r in ctx.conn.execute("SELECT bundle_id, socket, shown FROM village_fill"):
        out.setdefault(r["bundle_id"], {})[r["socket"]] = bool(r["shown"])
    return out


def _restored(ctx: Ctx) -> dict[str, dict]:
    return {
        r["ruin_id"]: dict(r)
        for r in ctx.conn.execute("SELECT ruin_id, restored_on, shown FROM village_restored")
    }


def ruins_state(ctx: Ctx) -> list[dict]:
    found = detected(ctx)
    stored = _stored(ctx)
    restored = _restored(ctx)
    ruins = []
    for ruin in bundle_config()["ruins"]:
        bundles = []
        for b in ruin["bundles"]:
            kept = stored.get(b["id"], {})
            filled = max(found[b["id"]], len(kept))
            sockets = [
                {"filled": i < filled, "new": i < filled and not kept.get(i, False)}
                for i in range(int(b["need"]))
            ]
            bundles.append(
                {
                    "id": b["id"],
                    "detector": b["detector"],
                    "need": int(b["need"]),
                    "filled": filled,
                    "complete": filled >= int(b["need"]),
                    "icon": b["icon"],
                    "sockets": sockets,
                    **({"cents": b["cents"]} if "cents" in b else {}),
                }
            )
        row = restored.get(ruin["id"])
        complete = all(b["complete"] for b in bundles)
        ruins.append(
            {
                "id": ruin["id"],
                "name": ruin["name"],
                "opens": ruin["opens"],
                "bundles": bundles,
                "sockets_filled": sum(b["filled"] for b in bundles),
                "sockets_total": sum(b["need"] for b in bundles),
                "restored": bool(row) or complete,
                "restored_on": row["restored_on"] if row else None,
                "fresh": (row is None and complete) or (row is not None and not row["shown"]),
            }
        )
    return ruins


def sync(ctx: Ctx) -> list[dict]:
    """Write down every socket that has filled, and restore ruins whose tablets are full.
    Returns the ruins restored by this call."""
    newly = []
    for ruin in ruins_state(ctx):
        for b in ruin["bundles"]:
            for i, s in enumerate(b["sockets"]):
                if s["filled"]:
                    ctx.conn.execute(
                        "INSERT OR IGNORE INTO village_fill (bundle_id, socket, filled_on) "
                        "VALUES (?, ?, ?)",
                        [b["id"], i, ctx.today.isoformat()],
                    )
        if ruin["restored"] and ruin["restored_on"] is None:
            ctx.conn.execute(
                "INSERT INTO village_restored (ruin_id, restored_on) VALUES (?, ?)",
                [ruin["id"], ctx.today.isoformat()],
            )
            newly.append(ruin)
    return newly


def mark_seen(ctx: Ctx) -> None:
    ctx.conn.execute("UPDATE village_fill SET shown = 1")
    ctx.conn.execute("UPDATE village_restored SET shown = 1")
