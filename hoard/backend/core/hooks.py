"""Things that happen when a game day passes: hunger, streaks, the Sunday draw.

    @daily(order=50)
    def feed_followers(ctx: Ctx, day: date) -> None: ...

Hooks run once for every day between the last processed day and today, oldest
first, right after the morning sync. They also run in real mode as real days pass.
"""

from collections.abc import Callable
from datetime import date, timedelta

DAILY: list[tuple[int, str, Callable]] = []


def daily(order: int = 50) -> Callable:
    def deco(fn: Callable) -> Callable:
        name = f"{fn.__module__}.{fn.__qualname__}"
        if all(existing != name for _, existing, _ in DAILY):
            DAILY.append((order, name, fn))
            DAILY.sort(key=lambda t: (t[0], t[1]))
        return fn

    return deco


def run_days(ctx) -> None:
    last = ctx.meta("last_day")
    if last is None:
        ctx.set_meta("last_day", ctx.today.isoformat())
        return
    day = date.fromisoformat(last) + timedelta(days=1)
    while day <= ctx.today:
        for _, _, fn in DAILY:
            fn(ctx, day)
        ctx.set_meta("last_day", day.isoformat())
        day += timedelta(days=1)
