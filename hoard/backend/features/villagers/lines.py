"""What the villagers say. Built from the week's numbers, in plain language.

No exclamation points, no nudges to buy or trade. Characters notice; they don't push.
"""


def dollars(cents: int) -> str:
    return f"${cents / 100:,.2f}"


def work_time(cents: int, hourly_cents: int) -> str:
    if hourly_cents <= 0:
        return "an unknown amount of work"
    minutes = round(cents / hourly_cents * 60)
    if minutes < 60:
        return f"{minutes} minutes of work"
    hours = minutes / 60
    return f"{hours:.1f} hours of work" if hours != 1 else "1 hour of work"


def _shopkeeper(extra: dict, shop: dict) -> list[str]:
    hourly = shop["hourly_rate_cents"]
    can = shop["can_spend_cents"]
    lines = ["Welcome in. Everything on these shelves is a real share, at last Sunday's price."]
    if can > 0:
        lines.append(
            f"You've got {dollars(can)} you can put in this week. "
            f"At {dollars(hourly)} an hour, that's {work_time(can, hourly)}."
        )
        if can < extra["extra_cents"]:
            lines.append("That's as much as the daily transfer cap allows. The rest keeps.")
    else:
        lines.append(
            "Nothing extra this week once bills and the floor are covered. Come back next week."
        )
    lines.append("Whatever you buy goes straight to the brokerage. I just keep the counter.")
    return lines


def _tavern_keeper(tavern: dict, hourly: int) -> list[str]:
    spent, budget, visits = tavern["spent_cents"], tavern["budget_cents"], tavern["visits"]
    if tavern["state"] == "packed":
        opener = f"Busy week. You were in {visits} times and spent {dollars(spent)}."
        close = (
            f"That's over your {dollars(budget)} budget. The regulars will sleep it off tomorrow."
        )
    else:
        opener = f"Quiet week. {visits} visits, {dollars(spent)} all told."
        close = f"Under your {dollars(budget)} budget. A few coins trickle in when it's like this."
    return [opener, f"That came to {work_time(spent, hourly)}.", close]


def _farmer(crops: dict, hourly: int) -> list[str]:
    spent, budget = crops["spent_cents"], crops["budget_cents"]
    state_line = {
        "bumper": "Best harvest in a while. Groceries came in well under.",
        "healthy": "Crops are doing fine. Groceries came in under budget.",
        "wilting": "Some of the crops are wilting. Groceries ran over.",
        "withered": "Rough week out here. Groceries ran well over.",
    }[crops["state"]]
    return [
        state_line,
        f"{dollars(spent)} on groceries against {dollars(budget)}. "
        f"That's {work_time(spent, hourly)}.",
        "It all grows back. One good week and the field recovers.",
    ]


def _shrine_keeper(shrine: dict, drains: dict, hourly: int) -> list[str]:
    lines = []
    if shrine["saved_cents"] > 0:
        lines.append(f"You moved {dollars(shrine['saved_cents'])} to savings. The shrine noticed.")
    else:
        lines.append("Nothing went to savings this week. The shrine is dim, but it'll keep.")
    for d in drains["drains"]:
        if d["new"]:
            lines.append(
                f"A new drain opened on the river: {d['merchant']}, {dollars(d['amount_cents'])}. "
                f"That's {work_time(d['amount_cents'], hourly)} a month."
            )
    lines.append(
        f"All the drains together take {dollars(drains['monthly_cents'])} a month, "
        f"against {dollars(drains['budget_cents'])}."
    )
    return lines


def village_dialogue(state: dict) -> dict:
    hourly = state["shop"]["hourly_rate_cents"]
    return {
        "shopkeeper": {"name": "Marlo", "lines": _shopkeeper(state["extra"], state["shop"])},
        "tavern_keeper": {"name": "Bess", "lines": _tavern_keeper(state["tavern"], hourly)},
        "farmer": {"name": "Wren", "lines": _farmer(state["crops"], hourly)},
        "shrine_keeper": {
            "name": "Odo",
            "lines": _shrine_keeper(state["shrine"], state["drains"], hourly),
        },
    }
