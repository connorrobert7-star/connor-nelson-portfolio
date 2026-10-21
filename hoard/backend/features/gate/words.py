"""Dollar amounts the way a boss says them out loud: 4120 -> "Forty-one twenty"."""

ONES = [
    "zero",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "ten",
    "eleven",
    "twelve",
    "thirteen",
    "fourteen",
    "fifteen",
    "sixteen",
    "seventeen",
    "eighteen",
    "nineteen",
]
TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]


def number(n: int) -> str:
    """Plain words for 0 to 999,999."""
    if n < 20:
        return ONES[n]
    if n < 100:
        tens, ones = divmod(n, 10)
        return TENS[tens] + (f"-{ONES[ones]}" if ones else "")
    if n < 1000:
        hundreds, rest = divmod(n, 100)
        return f"{ONES[hundreds]} hundred" + (f" {number(rest)}" if rest else "")
    thousands, rest = divmod(n, 1000)
    return f"{number(thousands)} thousand" + (f" {number(rest)}" if rest else "")


def _pair(n: int) -> str:
    """Two digits as said in a price: 5 -> "oh five", 20 -> "twenty"."""
    return f"oh {ONES[n]}" if n < 10 else number(n)


def say_money(cents: int) -> str:
    dollars, rest = divmod(abs(cents), 100)
    if dollars == 0:
        words = f"{number(rest)} cents"
    else:
        if dollars < 100 or dollars >= 10_000:
            head = number(dollars)
        elif dollars % 100 == 0:
            head = f"{number(dollars // 100)} hundred"
        else:
            head = f"{number(dollars // 100)} {_pair(dollars % 100)}"
        if rest:
            words = f"{head} {_pair(rest)}"
        else:
            words = f"{head} dollar" + ("" if dollars == 1 else "s")
    return words[0].upper() + words[1:]
