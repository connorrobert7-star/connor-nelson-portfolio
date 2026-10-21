"""The gate: every debt is a boss outside the village, smallest first.

HP is the real balance (`balances(ctx)[debt_id]`, after the game's own transfers).
A payment is the owner's attack: exactly its dollars of damage, moved through
`move()` after the extra and caps check. Interest is the boss healing once a month on
its due day; the bank's balance already includes it, so the heal is shown and never
added again. The game never changes HP any other way.
"""

import json
from datetime import date, timedelta
from functools import cache

from backend.content import CONTENT
from backend.core.context import Ctx
from backend.core.dates import add_month, is_monthly_on
from backend.core.router import ApiError
from backend.core.services import away, grant_item
from backend.money.budget import balances, compute_extra, hourly_rate_cents
from backend.money.transfer import caps_remaining, move
from backend.sync import anchor

from .words import say_money

FROM_ACCOUNT = "chk_1"
FALLBACK_DUE_DAY = 1  # the statement date when the bank doesn't give one
BANK_WATERMARK = "gate_bank_after"


@cache
def bosses_file() -> dict:
    return json.loads((CONTENT / "gate" / "bosses.json").read_text())


@cache
def items_file() -> dict:
    return json.loads((CONTENT / "gate" / "items.json").read_text())


def catalog() -> list[dict]:
    return items_file()["items"]


def item(item_id: str) -> dict | None:
    return next((i for i in catalog() if i["id"] == item_id), None)


def kind_info(kind: str) -> dict:
    kinds = bosses_file()["kinds"]
    return kinds.get(kind, kinds["other"])


def boss_name(debt: dict) -> str:
    return kind_info(debt["kind"])["name"]


def heal_cents(hp_cents: int, apr: float) -> int:
    """One month of interest: the boss heals by exactly this on its due day."""
    return round(hp_cents * apr / 1200)


def heal_line(kind: str, amount_cents: int) -> str:
    return kind_info(kind)["lines"]["heal"].replace("{amount}", say_money(amount_cents))


def next_heal_day(today: date, due_day: int | None) -> date:
    due = due_day or FALLBACK_DUE_DAY
    # From the last day of last month, add_month lands on this month's due day.
    d = add_month(today.replace(day=1) - timedelta(days=1), day=due)
    if d < today:
        d = add_month(d, day=due)
    return d


def can_spend(ctx: Ctx) -> int:
    return max(0, min(compute_extra(ctx)["extra_cents"], caps_remaining(ctx)))


# --- bosses -----------------------------------------------------------------------


def debts(ctx: Ctx) -> list[dict]:
    return [dict(r) for r in ctx.conn.execute("SELECT * FROM debts ORDER BY id")]


def register(ctx: Ctx) -> None:
    """Remember every boss the gate has seen, and the most HP each has had."""
    bal = balances(ctx)
    for d in debts(ctx):
        hp = bal.get(d["id"], d["balance_cents"])
        ctx.conn.execute(
            """INSERT INTO gate_bosses (debt_id, name, kind, max_hp_cents, first_seen)
               VALUES (?, ?, ?, ?, ?)
               ON CONFLICT(debt_id) DO UPDATE SET
                 max_hp_cents = MAX(max_hp_cents, excluded.max_hp_cents),
                 name = excluded.name, kind = excluded.kind""",
            [d["id"], boss_name(d), d["kind"], max(hp, 1), ctx.today.isoformat()],
        )


def _granted_drops(ctx: Ctx) -> set[str]:
    return {
        r["item_id"]
        for r in ctx.conn.execute("SELECT item_id FROM gate_kills WHERE item_id IS NOT NULL")
    }


def drop_for(ctx: Ctx, kind: str) -> dict | None:
    """The cosmetic a boss of this kind drops: its own, or a spare if that's gone."""
    granted = _granted_drops(ctx)
    for source in (kind, "spare"):
        for it in catalog():
            if it["drops_from"] == source and it["id"] not in granted:
                return it
    return None


def amounts(hp_cents: int, min_payment_cents: int, spend_cents: int, hourly: int) -> list[dict]:
    """The coin-stacks: the minimum payment, the fixed amounts, and the rest when it's less."""
    picks: dict[int, str] = {}
    if min_payment_cents > 0:
        picks[min_payment_cents] = "min"
    for a in bosses_file()["amounts_cents"]:
        picks.setdefault(a, "fixed")
    kept = {a: k for a, k in picks.items() if a < hp_cents}
    if hp_cents > 0 and len(kept) < len(picks):
        kept[hp_cents] = "finish"
    return [
        {
            "amount_cents": a,
            "kind": kept[a],
            "affordable": a <= spend_cents,
            "hours": round(a / hourly, 1) if hourly > 0 else None,
        }
        for a in sorted(kept)
    ]


def _unshown_heal(ctx: Ctx, debt_id: str, kind: str) -> dict | None:
    r = ctx.conn.execute(
        "SELECT * FROM gate_heals WHERE debt_id = ? AND shown = 0 ORDER BY id DESC LIMIT 1",
        [debt_id],
    ).fetchone()
    if r is None:
        return None
    return {
        "id": r["id"],
        "amount_cents": r["amount_cents"],
        "day": r["day"],
        "line": heal_line(kind, r["amount_cents"]),
    }


def _kill_row(ctx: Ctx, debt_id: str) -> dict | None:
    r = ctx.conn.execute("SELECT * FROM gate_kills WHERE debt_id = ?", [debt_id]).fetchone()
    return dict(r) if r else None


def _public_item(it: dict | None) -> dict | None:
    if it is None:
        return None
    return {k: it[k] for k in ("id", "name", "tier", "set", "slot", "icon")}


def gate_state(ctx: Ctx) -> dict:
    register(ctx)
    sync_seen(ctx)
    bal = balances(ctx)
    spend = can_spend(ctx)
    hourly = hourly_rate_cents(ctx)
    maxes = {r["debt_id"]: dict(r) for r in ctx.conn.execute("SELECT * FROM gate_bosses")}
    out = []
    live_ids = set()
    for d in debts(ctx):
        live_ids.add(d["id"])
        hp = max(0, bal.get(d["id"], d["balance_cents"]))
        info = kind_info(d["kind"])
        kill = _kill_row(ctx, d["id"])
        drop = item(kill["item_id"]) if kill and kill["item_id"] else None
        heal_on = next_heal_day(ctx.today, d["due_day"])
        out.append(
            {
                "debt_id": d["id"],
                "debt_name": d["name"],
                "name": info["name"],
                "kind": d["kind"],
                "hp_cents": hp,
                "max_hp_cents": max(hp, maxes.get(d["id"], {}).get("max_hp_cents", hp), 1),
                "apr": d["apr"],
                "due_day": d["due_day"],
                "min_payment_cents": d["min_payment_cents"],
                "next_heal_cents": heal_cents(hp, d["apr"]) if hp > 0 else 0,
                "next_heal_on": heal_on.isoformat(),
                "days_to_heal": (heal_on - ctx.today).days,
                "defeated": hp == 0,
                "amounts": amounts(hp, d["min_payment_cents"], spend, hourly) if hp > 0 else [],
                "heal": _unshown_heal(ctx, d["id"], d["kind"]) if hp > 0 else None,
                "kill": {"day": kill["day"], "shown": bool(kill["shown"])} if kill else None,
                "drop": _public_item(drop or (drop_for(ctx, d["kind"]) if hp > 0 else None)),
                "look": info["look"],
                "lines": {**info["lines"], "refuse": bosses_file()["refuse_line"]},
            }
        )
    # Bosses the bank stopped reporting after they were paid off stay as defeated.
    for k in ctx.conn.execute("SELECT * FROM gate_kills ORDER BY day"):
        if k["debt_id"] in live_ids:
            continue
        info = kind_info(k["kind"])
        out.append(
            {
                "debt_id": k["debt_id"],
                "debt_name": k["name"],
                "name": info["name"],
                "kind": k["kind"],
                "hp_cents": 0,
                "max_hp_cents": k["max_hp_cents"],
                "apr": 0.0,
                "due_day": None,
                "min_payment_cents": 0,
                "next_heal_cents": 0,
                "next_heal_on": None,
                "days_to_heal": None,
                "defeated": True,
                "amounts": [],
                "heal": None,
                "kill": {"day": k["day"], "shown": bool(k["shown"])},
                "drop": _public_item(item(k["item_id"]) if k["item_id"] else None),
                "look": info["look"],
                "lines": {**info["lines"], "refuse": bosses_file()["refuse_line"]},
            }
        )
    out.sort(key=lambda b: (b["defeated"], b["hp_cents"], b["debt_id"]))
    return {
        "bosses": out,
        "can_spend_cents": spend,
        "amounts": bosses_file()["amounts_cents"],
        "refuse_line": bosses_file()["refuse_line"],
    }


# --- the fight ----------------------------------------------------------------------


def kill(ctx: Ctx, debt: dict, via: str) -> dict | None:
    """The boss is down. Grant its drop exactly once. Returns the item, if any."""
    if _kill_row(ctx, debt["id"]) is not None:
        return None
    max_row = ctx.conn.execute(
        "SELECT max_hp_cents FROM gate_bosses WHERE debt_id = ?", [debt["id"]]
    ).fetchone()
    drop = drop_for(ctx, debt["kind"])
    ctx.conn.execute(
        """INSERT INTO gate_kills (debt_id, name, kind, max_hp_cents, item_id, day, shown)
           VALUES (?, ?, ?, ?, ?, ?, 0)""",
        [
            debt["id"],
            debt["name"],
            debt["kind"],
            max_row["max_hp_cents"] if max_row else 1,
            drop["id"] if drop else None,
            ctx.today.isoformat(),
        ],
    )
    if drop:
        grant_item(ctx, drop["id"], via=f"gate:{debt['id']}")
        ctx.events[-1].update(name=drop["name"], tier=drop["tier"])
    if via == "bank":
        away(
            ctx,
            "gate_kill",
            priority=20,
            debt_id=debt["id"],
            name=boss_name(debt),
            item_id=drop["id"] if drop else None,
        )
    return drop


def attack(ctx: Ctx, debt_id: str, amount_cents: int) -> dict:
    debt = next((d for d in debts(ctx) if d["id"] == debt_id), None)
    if debt is None:
        raise ApiError(404, "Nothing by that name outside the gate.")
    register(ctx)
    hp = max(0, balances(ctx).get(debt_id, debt["balance_cents"]))
    if hp == 0:
        raise ApiError(409, "It's already down.")
    if amount_cents <= 0:
        raise ApiError(422, "Pick a stack first.")
    if amount_cents > hp:
        raise ApiError(409, "That's more than it owes.")
    if amount_cents > compute_extra(ctx)["extra_cents"] or amount_cents > caps_remaining(ctx):
        raise ApiError(409, bosses_file()["refuse_line"])
    name = boss_name(debt)
    transfer_id = move(
        ctx,
        FROM_ACCOUNT,
        debt_id,
        amount_cents,
        reason=f"Payment to {debt['name']}",
        event={"type": "gate_attack", "debt_id": debt_id, "amount_cents": amount_cents},
    )
    status = ctx.conn.execute(
        "SELECT status FROM transfers WHERE id = ?", [transfer_id]
    ).fetchone()["status"]
    after = max(0, balances(ctx)[debt_id])
    drop = kill(ctx, debt, via="attack") if after == 0 else None
    if after == 0:
        ctx.conn.execute("UPDATE gate_kills SET shown = 1 WHERE debt_id = ?", [debt_id])
    return {
        "money": {"amount_cents": amount_cents, "to_account": debt_id, "status": status},
        "debt_id": debt_id,
        "name": name,
        "damage_cents": amount_cents,
        "hp_before_cents": hp,
        "hp_cents": after,
        "killed": after == 0,
        "drop": _public_item(drop),
    }


def _heal_ids(values: list) -> list[int]:
    out = []
    for v in values:
        try:
            if isinstance(v, bool) or not float(v).is_integer():
                raise ValueError
            n = int(float(v))
        except (TypeError, ValueError, OverflowError):
            raise ApiError(422, "heals must be beat ids.") from None
        if not 0 < n < 2**63:
            raise ApiError(422, "heals must be beat ids.")
        out.append(n)
    return out


def _kill_ids(values: list) -> list[str]:
    if not all(isinstance(v, str) for v in values):
        raise ApiError(422, "kills must be boss ids.")
    return list(values)


# An away beat for a heal: by its id, or (older rows) by its boss and amount.
_HEAL_BEAT = """away_events.kind = 'gate_heal' AND (
    json_extract(away_events.payload, '$.heal_id') = gate_heals.id
    OR (json_extract(away_events.payload, '$.heal_id') IS NULL
        AND json_extract(away_events.payload, '$.debt_id') = gate_heals.debt_id
        AND json_extract(away_events.payload, '$.amount_cents') = gate_heals.amount_cents))"""
_KILL_BEAT = """away_events.kind = 'gate_kill'
    AND json_extract(away_events.payload, '$.debt_id') = gate_kills.debt_id"""


def sync_seen(ctx: Ctx) -> None:
    """One beat, two places: a heal or a bank kill the while-you-were-out scene already
    played is shown here too, and one the gate played is gone from that queue."""
    ctx.conn.execute(
        f"""UPDATE gate_heals SET shown = 1 WHERE shown = 0 AND EXISTS
            (SELECT 1 FROM away_events WHERE away_events.shown = 1 AND {_HEAL_BEAT})"""
    )
    ctx.conn.execute(
        f"""UPDATE gate_kills SET shown = 1 WHERE shown = 0 AND EXISTS
            (SELECT 1 FROM away_events WHERE away_events.shown = 1 AND {_KILL_BEAT})"""
    )
    ctx.conn.execute(
        f"""UPDATE away_events SET shown = 1 WHERE shown = 0 AND (
              EXISTS (SELECT 1 FROM gate_heals WHERE gate_heals.shown = 1 AND {_HEAL_BEAT})
              OR EXISTS (SELECT 1 FROM gate_kills WHERE gate_kills.shown = 1 AND {_KILL_BEAT}))"""
    )


def mark_seen(ctx: Ctx, heals: list, kills: list) -> dict:
    """Unknown or already-seen ids are a no-op; ids that aren't ids are a 422."""
    heal_ids = _heal_ids(heals)
    kill_ids = _kill_ids(kills)
    seen = 0
    for i in heal_ids:
        seen += ctx.conn.execute(
            "UPDATE gate_heals SET shown = 1 WHERE id = ? AND shown = 0", [i]
        ).rowcount
    for k in kill_ids:
        seen += ctx.conn.execute(
            "UPDATE gate_kills SET shown = 1 WHERE debt_id = ? AND shown = 0", [k]
        ).rowcount
    sync_seen(ctx)
    return {"seen": seen}


# --- once a day -----------------------------------------------------------------------


def heal_day(ctx: Ctx, day: date) -> None:
    """Interest: each boss heals once a month, on its due day. Shown, never added."""
    bal = balances(ctx)
    for d in debts(ctx):
        hp = max(0, bal.get(d["id"], d["balance_cents"]))
        if hp == 0 or not is_monthly_on(day, d["due_day"] or FALLBACK_DUE_DAY):
            continue
        amount = heal_cents(hp, d["apr"])
        if amount <= 0:
            continue
        cur = ctx.conn.execute(
            """INSERT OR IGNORE INTO gate_heals (debt_id, month, day, amount_cents)
               VALUES (?, ?, ?, ?)""",
            [d["id"], day.isoformat()[:7], day.isoformat(), amount],
        )
        if cur.rowcount:
            away(
                ctx,
                "gate_heal",
                priority=45,
                heal_id=cur.lastrowid,
                debt_id=d["id"],
                name=boss_name(d),
                amount_cents=amount,
                line=heal_line(d["kind"], amount),
            )


def bank_hits(ctx: Ctx, day: date) -> None:
    """Payments the bank made on its own play as auto-attacks while you were out."""
    after = ctx.meta(BANK_WATERMARK)
    if after is None:
        after = (anchor(ctx) - timedelta(days=1)).isoformat()
    until = (day - timedelta(days=1)).isoformat()
    kinds = bosses_file()["kind_for_category"]
    by_kind: dict[str, dict] = {}
    for d in debts(ctx):
        by_kind.setdefault(d["kind"], d)
    rows = ctx.conn.execute(
        """SELECT id, date, amount_cents, merchant, category FROM transactions
           WHERE category LIKE 'LOAN_PAYMENTS_%' AND amount_cents > 0
             AND date > ? AND date <= ? ORDER BY date, id""",
        [after, until],
    ).fetchall()
    bal = balances(ctx)
    for r in rows:
        debt = by_kind.get(kinds.get(r["category"], "other"))
        if debt is None:
            continue
        cur = ctx.conn.execute(
            "INSERT OR IGNORE INTO gate_bank_hits (txn_id, debt_id, day, amount_cents) "
            "VALUES (?, ?, ?, ?)",
            [r["id"], debt["id"], r["date"], r["amount_cents"]],
        )
        if cur.rowcount and bal.get(debt["id"], debt["balance_cents"]) > 0:
            away(
                ctx,
                "gate_hit",
                priority=30,
                debt_id=debt["id"],
                name=boss_name(debt),
                amount_cents=r["amount_cents"],
                day=r["date"],
                by="bank",
            )
    if until > after:
        ctx.set_meta(BANK_WATERMARK, until)


def bank_kills(ctx: Ctx) -> None:
    """A boss the bank's own payments finished off still dies, and still drops."""
    bal = balances(ctx)
    live = {d["id"]: d for d in debts(ctx)}
    for d in live.values():
        if bal.get(d["id"], d["balance_cents"]) <= 0:
            kill(ctx, d, via="bank")
    for r in ctx.conn.execute("SELECT * FROM gate_bosses").fetchall():
        if r["debt_id"] not in live:
            kill(
                ctx,
                {"id": r["debt_id"], "name": r["name"], "kind": r["kind"]},
                via="bank",
            )
