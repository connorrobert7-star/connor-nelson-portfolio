"""The life clock: age, predicted death, and the life level.

Level 1 is birth and level 100 is the predicted day of death, from the life table
provider's remaining life expectancy at the player's current age. Every level is
1% of a whole life.
"""

from datetime import date, timedelta

from backend.core.context import Ctx

DAYS_PER_YEAR = 365.2425


def life_clock(ctx: Ctx) -> dict:
    birth = date.fromisoformat(ctx.profile["birth_date"])
    sex = ctx.profile.get("sex", "average")
    age_years = (ctx.today - birth).days / DAYS_PER_YEAR
    remaining = ctx.providers.life.remaining_years(age_years, sex)
    death_age = age_years + remaining
    death_day = ctx.today + timedelta(days=round(remaining * DAYS_PER_YEAR))
    progress = age_years / death_age * 100
    level = min(100, int(progress) + 1)
    level_days = death_age * DAYS_PER_YEAR / 100
    return {
        "birth_date": birth.isoformat(),
        "sex": sex,
        "age_years": round(age_years, 3),
        "death_age_years": round(death_age, 2),
        "death_date": death_day.isoformat(),
        "days_left": (death_day - ctx.today).days,
        "weeks_left": (death_day - ctx.today).days // 7,
        "level": level,
        "level_progress": round(progress % 1, 4),
        "days_per_level": round(level_days, 1),
        "source": ctx.providers.life.name,
    }


def life_minutes(cents: int, hourly_cents: int) -> float:
    """How many minutes of work (and so of life) a price costs."""
    return round(cents / hourly_cents * 60, 1) if hourly_cents > 0 else 0.0
