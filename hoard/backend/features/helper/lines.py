"""What Pip says: content/helper/lines.json filled from the owner's own numbers.

Every number in a line comes from /state (the wall, the debts, the holdings, the casino's
belt, the buildings' signs) or from plain arithmetic on a stated assumption (a flat 7% a
year). Nothing here reads a live price, names a ticker, or says anything is going up.

The advisor slot can write the teaching lines instead: if the provider has
`helper_lines(topic_id, facts) -> list[str]`, its lines are used when every one of them
passes fits(); otherwise the content file's lines are used.
"""

import json
import re
from functools import cache
from typing import Any

from backend.content import CONTENT

# A bubble shows at most two lines of about 34 characters.
MAX_CHARS = 62
# A debt at or above this APR is "high-rate": paying it beats an assumed market return.
HIGH_APR = 8.0
INDEX_KINDS = ("index", "bond")
METAL_KINDS = ("metal", "gold", "silver", "commodity")
CRYPTO_KINDS = ("crypto",)
WEEKS_PER_YEAR = 52
# Words that would turn a line into a nudge or a momentum signal.
BANNED = (
    "going up",
    "go up",
    "will rise",
    "will grow",
    "good buy",
    "worth buying",
    "should buy",
    "buy now",
    "you should",
    "hot pick",
    "today's price",
    "price today",
)
# Vex's words for the belt's shells, by tier.
SHELL_WORDS = {"rare": "blue", "epic": "purple", "legendary": "gold", "mythic": "red"}


@cache
def content() -> dict:
    return json.loads((CONTENT / "helper" / "lines.json").read_text())


def dollars(cents: int | float) -> str:
    return f"${cents / 100:,.2f}"


def whole_dollars(cents: int | float) -> str:
    return f"${round(cents / 100):,}"


def weekly_growth_cents(weekly_cents: int, rate: float, years: int) -> int:
    """$X put in at the end of every week, growing at `rate` a year compounded weekly."""
    i = rate / WEEKS_PER_YEAR
    n = years * WEEKS_PER_YEAR
    return round(weekly_cents * ((1 + i) ** n - 1) / i)


def tickers(state: dict) -> set[str]:
    symbols = {s["symbol"] for s in state.get("shop", {}).get("stocks", [])}
    symbols |= {h["symbol"] for h in state.get("holdings", [])}
    market = CONTENT / "market.json"
    if market.exists():
        raw = json.loads(market.read_text())
        rows = raw.get("tickers", raw.get("stocks", [])) if isinstance(raw, dict) else raw
        for r in rows if isinstance(rows, list) else []:
            if isinstance(r, dict) and r.get("symbol"):
                symbols.add(str(r["symbol"]))
    return symbols


def fits(text: str, symbols: set[str]) -> bool:
    """One bubble's worth, plain, with no ticker and nothing that pushes a buy."""
    if not text or len(text) > MAX_CHARS or "!" in text:
        return False
    low = text.lower()
    if any(b in low for b in BANNED):
        return False
    words = set(re.findall(r"[A-Za-z]+", text))
    return not (words & symbols)


# --- the numbers ---------------------------------------------------------------------


def _share(part: int, whole: int) -> str:
    return f"{round(100 * part / whole)}%" if whole > 0 else "0%"


def _kind_cents(state: dict) -> tuple[dict[str, int], int]:
    kinds = {s["symbol"]: s.get("kind", "stock") for s in state.get("shop", {}).get("stocks", [])}
    by_kind: dict[str, int] = {}
    total = 0
    for h in state.get("holdings", []):
        cents = int(h.get("value_cents", 0))
        kind = str(h.get("kind") or kinds.get(h["symbol"], "stock"))
        by_kind[kind] = by_kind.get(kind, 0) + cents
        total += cents
    return by_kind, total


def _brokerage_cents(state: dict) -> int:
    balances = state.get("balances", {})
    ids = [a["id"] for a in state.get("accounts", []) if a.get("kind") == "brokerage"]
    if ids:
        return sum(int(balances.get(i, 0)) for i in ids)
    return _kind_cents(state)[1]


def top_debt(state: dict) -> dict | None:
    debts = [d for d in state.get("debts", []) if int(d.get("balance_cents", 0)) > 0]
    return max(debts, key=lambda d: float(d.get("apr", 0))) if debts else None


def _weekday_date(iso: str) -> str:
    from datetime import date

    d = date.fromisoformat(iso)
    return f"{d.strftime('%A')}, {d.strftime('%b')} {d.day}"


def belt_odds(state: dict) -> str:
    left = state.get("casino", {}).get("belt", {}).get("left", {})
    total = sum(int(n) for n in left.values())
    specials = [
        f"{int(left[t])} {word}" for t, word in SHELL_WORDS.items() if int(left.get(t, 0)) > 0
    ]
    if not specials:
        return f"{total} shells. All plain."
    return f"{total} shells. {', '.join(specials)}. The rest plain."


def facts(state: dict, cfg: dict) -> dict[str, Any]:
    rate = float(cfg.get("assumed_rate", 0.07))
    fee = float(cfg.get("fee_rate", 0.01))
    wall = state.get("village", {}).get("wall", {})
    ef_balance = int(wall.get("balance_cents", state.get("balances", {}).get("sav_2", 0)))
    monthly = int(wall.get("monthly_expenses_cents", 0))
    target_months = int(wall.get("months", 3))
    by_kind, held = _kind_cents(state)
    brokerage = _brokerage_cents(state)
    grow_30 = weekly_growth_cents(500, rate, 30)
    debt = top_debt(state)
    streak = int(state.get("buildings", {}).get("deposit_streak_weeks", 0))
    next_check = state.get("buildings", {}).get("next_check")
    out: dict[str, Any] = {
        "ef_balance": dollars(ef_balance),
        "ef_months": f"{ef_balance / monthly:.1f}" if monthly > 0 else "0.0",
        "ef_target_months": str(target_months),
        "ef_target": dollars(monthly * target_months),
        "ef_full": monthly > 0 and ef_balance >= monthly * target_months,
        "high_apr": f"{HIGH_APR:g}%",
        "flat_100": dollars(round(10_000 * rate)),
        "brokerage": dollars(brokerage),
        "index_share": _share(sum(by_kind.get(k, 0) for k in INDEX_KINDS), held),
        "metals_cents": sum(by_kind.get(k, 0) for k in METAL_KINDS),
        "metals_share": _share(sum(by_kind.get(k, 0) for k in METAL_KINDS), held),
        "crypto_cents": sum(by_kind.get(k, 0) for k in CRYPTO_KINDS),
        "crypto_share": _share(sum(by_kind.get(k, 0) for k in CRYPTO_KINDS), held),
        "grow_10": whole_dollars(weekly_growth_cents(500, rate, 10)),
        "put_10": whole_dollars(500 * WEEKS_PER_YEAR * 10),
        "grow_30": whole_dollars(grow_30),
        "put_30": whole_dollars(500 * WEEKS_PER_YEAR * 30),
        "fee_year": dollars(round(brokerage * fee)),
        "fee_30": whole_dollars(grow_30 - weekly_growth_cents(500, rate - fee, 30)),
        "streak_line": cfg["streak"][
            "none" if streak <= 0 else "one" if streak == 1 else "many"
        ].format(streak=streak),
        "holdings_count": str(len(state.get("holdings", []))),
        "can_spend": dollars(int(state.get("casino", {}).get("can_spend_cents", 0))),
        "belt_odds": belt_odds(state),
        "next_check": _weekday_date(next_check) if next_check else "on Sunday",
        "debt": None,
    }
    if debt and float(debt.get("apr", 0)) >= HIGH_APR:
        apr = float(debt["apr"])
        out |= {
            "debt": debt["id"],
            "debt_name": str(debt.get("name", "debt")).lower(),
            "debt_apr": f"{apr:g}%",
            "debt_balance": dollars(int(debt["balance_cents"])),
            "debt_save_100": dollars(round(100 * apr)),
        }
    return out


def topic_variant(topic_id: str, f: dict) -> str:
    match topic_id:
        case "emergency_fund":
            return "full" if f["ef_full"] else "short"
        case "high_rate_debt":
            return "debt" if f["debt"] else "none"
        case "gold_silver":
            return "some" if f["metals_cents"] > 0 else "none"
        case "bitcoin":
            return "some" if f["crypto_cents"] > 0 else "none"
    return "any"


# --- the signs --------------------------------------------------------------------


def need_line(req: dict) -> str:
    key = str(req.get("key", ""))
    need, have = req.get("need", 0), req.get("have", 0)
    if key.endswith("_cents"):
        return f"{req.get('label', 'This')} at {dollars(int(need))}. You have {dollars(int(have))}."
    if key == "deposit_streak_weeks":
        return f"Deposits {int(need)} weeks in a row. You're at {int(have)}."
    if key == "land":
        return f"{int(need)} pieces of land open. You have {int(have)}."
    return f"{req.get('label', 'This')} at {need}. You have {have}."


def sign_needs(state: dict) -> dict[str, str]:
    """For each building with a sign up: the first lamp still dark (or the first lamp)."""
    out = {}
    for b in state.get("buildings", {}).get("list", []):
        nxt = b.get("next")
        if not isinstance(nxt, dict) or b.get("constructing") or not nxt.get("requires"):
            continue
        reqs = nxt["requires"]
        dark = [r for r in reqs if not r.get("met_now")]
        out[b["id"]] = need_line((dark or reqs)[0])
    return out


# --- composing ----------------------------------------------------------------------


def fill(text: str, f: dict) -> str:
    return text.format(**{k: v for k, v in f.items() if isinstance(v, str)})


def beat_lines(beat: dict, f: dict) -> list[dict]:
    out = []
    for item in beat["lines"]:
        who, text = ("pip", item) if isinstance(item, str) else (item["who"], item["text"])
        out.append({"who": who, "text": fill(text, f)})
    return out


def topic_lines(advisor: Any, topic: dict, f: dict, symbols: set[str]) -> list[str]:
    variant = topic_variant(topic["id"], f)
    written = getattr(advisor, "helper_lines", None)
    if callable(written):
        try:
            lines = [str(x) for x in written(topic["id"], {**f, "variant": variant})]
        except Exception:
            lines = []
        if lines and all(fits(x, symbols) for x in lines):
            return lines
    variants = topic["variants"]
    template = variants.get(variant) or next(iter(variants.values()))
    return [fill(t, f) for t in template]
