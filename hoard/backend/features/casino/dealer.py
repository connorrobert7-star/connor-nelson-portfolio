"""What Vex says. Counts only, in words, about eight words a line, no exclamation points.

The counts are the exact odds of the next pull: the belt and box are drawn without
replacement, and when a box special is next the tell says so.
"""

from backend.features.casino.catalog import RANK, WORDS

NAME = "Vex"
NOT_THIS_WEEK = "Not this week."

_ONES = (
    "zero one two three four five six seven eight nine ten eleven twelve thirteen "
    "fourteen fifteen sixteen seventeen eighteen nineteen"
).split()
_TENS = "zero ten twenty thirty forty fifty sixty seventy eighty ninety".split()


def words(n: int) -> str:
    """0 to 999 in words: 25 -> 'twenty-five'."""
    if n < 20:
        return _ONES[n]
    if n < 100:
        tens, ones = divmod(n, 10)
        return _TENS[tens] + (f"-{_ONES[ones]}" if ones else "")
    hundreds, rest = divmod(n, 100)
    return f"{_ONES[hundreds]} hundred" + (f" {words(rest)}" if rest else "")


def cap(text: str) -> str:
    return text[:1].upper() + text[1:]


def _plural(n: int, one: str, many: str) -> str:
    return f"{cap(words(n))} {one if n == 1 else many}."


def _colors(left: dict[str, int]) -> str:
    """'Four blue. One purple.' for every tier above grey that's still in."""
    return " ".join(
        f"{cap(words(n))} {WORDS[t]}."
        for t, n in sorted(left.items(), key=lambda kv: RANK[kv[0]])
        if t != "common" and n > 0
    )


def belt_line(left: dict[str, int]) -> str:
    total = sum(left.values())
    return f"{_plural(total, 'shell', 'shells')} {_colors(left)}".strip()


def box_line(specials: list[str], fresh: bool = False) -> str:
    """'A new box. Two gold.' or 'One gold. One red.'"""
    counts = {t: specials.count(t) for t in ("legendary", "mythic")}
    said = _colors(counts)
    return f"A new box. {said}" if fresh else said


def tell_line(tier: str) -> str:
    return f"{cap(WORDS[tier])} in the chamber."


def case_odds(belt_left: dict[str, int], box: dict) -> str:
    if box["next_is_special"]:
        return tell_line(box["next_tier"])
    return belt_line(belt_left)


def counted_line(left: dict[str, int], one: str, many: str) -> str:
    """'Twenty in the book. Four blue.' / 'Twelve wedges. One purple. One gold.'"""
    total = sum(left.values())
    head = f"{cap(words(total))} {many}." if one == many else _plural(total, one, many)
    return f"{head} {_colors(left)}".strip()


def money_line(price_cents: int, account_name: str) -> str:
    """'Twenty to the House Fund.' Whole dollars, said plainly."""
    dollars, cents = divmod(price_cents, 100)
    amount = cap(words(dollars)) if not cents else f"${price_cents / 100:,.2f}"
    return f"{amount} to the {account_name}."


def now_line(can_spend_cents: int, cheapest_cents: int, belt_left: dict, box: dict) -> str:
    """What he says right now, with nothing pulled yet."""
    if can_spend_cents < cheapest_cents:
        return NOT_THIS_WEEK
    if box["next_is_special"]:
        return tell_line(box["next_tier"])
    if box["used"] == 0:
        return box_line(box["specials"], fresh=True)
    return belt_line(belt_left)
