import calendar
from datetime import date, timedelta


def add_month(d: date, day: int | None = None) -> date:
    """Same day next month, clamped to the month's end. `day` overrides the day."""
    year, month = (d.year + 1, 1) if d.month == 12 else (d.year, d.month + 1)
    return date(year, month, min(day or d.day, calendar.monthrange(year, month)[1]))


def week_start(d: date) -> date:
    """Weeks run Sunday to Saturday."""
    return d - timedelta(days=(d.weekday() + 1) % 7)


def is_monthly_on(d: date, day: int) -> bool:
    """True if d is the `day`-th of its month, or the month's last day when it's shorter."""
    return d.day == min(day, calendar.monthrange(d.year, d.month)[1])
