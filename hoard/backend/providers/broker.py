"""Shared pieces for the broker slot: order sizing, market hours, the order record, and
the demo broker.

Sizing rule (the owner's): for a $5 pull, divide by the quote and send the share count
to three decimals, never rounded up. Whatever the fill costs, the rest stays as cash.
"""

from datetime import datetime, time, timedelta, tzinfo
from decimal import ROUND_DOWN, ROUND_HALF_EVEN, Decimal
from functools import cache
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

OPEN, CLOSE = time(9, 30), time(16, 0)
QTY_STEP = Decimal("0.001")
CENT = Decimal("0.01")


class _Eastern(tzinfo):
    """US Eastern time by the current DST rule, for Pythons without tzdata (the browser demo).
    Daylight time runs from 2:00 on the second Sunday of March to 2:00 on the first Sunday
    of November."""

    @staticmethod
    def _sunday(year: int, month: int, nth: int) -> datetime:
        first = datetime(year, month, 1)
        return first + timedelta(days=(6 - first.weekday()) % 7 + 7 * (nth - 1), hours=2)

    def dst(self, dt: datetime | None) -> timedelta:
        if dt is None:
            return timedelta(0)
        naive = dt.replace(tzinfo=None)
        start, end = self._sunday(dt.year, 3, 2), self._sunday(dt.year, 11, 1)
        return timedelta(hours=1) if start <= naive < end else timedelta(0)

    def utcoffset(self, dt: datetime | None) -> timedelta:
        return timedelta(hours=-5) + self.dst(dt)

    def tzname(self, dt: datetime | None) -> str:
        return "EDT" if self.dst(dt) else "EST"

    def fromutc(self, dt: datetime) -> datetime:
        standard = dt + timedelta(hours=-5)
        return standard + self.dst(standard.replace(tzinfo=self))


@cache
def new_york() -> tzinfo:
    try:
        return ZoneInfo("America/New_York")
    except ZoneInfoNotFoundError:
        return _Eastern()


class BrokerError(RuntimeError):
    """The broker couldn't be reached or refused the request. Nothing was bought."""


def share_count(amount_cents: int, price: Decimal | float | str) -> Decimal:
    """Shares to send for amount_cents at price dollars: three decimals, rounded down."""
    price = Decimal(str(price))
    if price <= 0 or amount_cents <= 0:
        return Decimal("0.000")
    return (Decimal(amount_cents) / 100 / price).quantize(QTY_STEP, rounding=ROUND_DOWN)


def to_cents(dollars: Decimal | float | str) -> int:
    return int((Decimal(str(dollars)) * 100).quantize(Decimal(1), rounding=ROUND_HALF_EVEN))


def us_market_open(now: datetime | None = None) -> bool:
    """Regular US hours on a weekday. Holidays come from the broker when it can tell."""
    now = (now or datetime.now(new_york())).astimezone(new_york())
    return now.weekday() < 5 and OPEN <= now.time() < CLOSE


def order_record(
    *,
    order_id: str,
    symbol: str,
    target_cents: int,
    qty_sent: Decimal,
    quote: Decimal,
    status: str,
    filled_qty: Decimal = Decimal(0),
    avg_price: Decimal = Decimal(0),
    message: str = "",
) -> dict:
    """The one shape every broker returns. Dollar target and actual fill side by side."""
    filled = (filled_qty * avg_price).quantize(CENT, rounding=ROUND_HALF_EVEN)
    filled_cents = to_cents(filled)
    return {
        "order_id": str(order_id),
        "symbol": symbol,
        "target_cents": target_cents,
        "qty_sent": str(qty_sent),
        "quote_cents": to_cents(quote),
        "status": status,
        "filled_qty": str(filled_qty),
        "avg_price": str(avg_price),
        "filled_cents": filled_cents,
        "leftover_cents": (
            target_cents - filled_cents if target_cents and status in ("filled", "partial") else 0
        ),
        "message": message,
    }


class FixtureBroker:
    """The demo broker: fills at once at the fixture market's weekly price. No network."""

    name = "fixture"
    paper = True

    def __init__(self, market, cash_cents: int = 25_000) -> None:
        self.market = market
        self._cash = cash_cents
        self._orders: dict[str, dict] = {}
        self._positions: dict[str, Decimal] = {}

    def cash_cents(self) -> int:
        return self._cash

    def market_open(self) -> bool:
        return True

    def _price(self, symbol: str) -> Decimal:
        from datetime import date

        from backend.core.dates import week_start

        today = date.today()
        return Decimal(self.market.weekly_price_cents(symbol, week_start(today), today)) / 100

    def buy(self, symbol: str, amount_cents: int, ref: str) -> dict:
        price = self._price(symbol)
        qty = share_count(amount_cents, price)
        oid = f"fx-{len(self._orders) + 1}"
        if qty <= 0:
            rec = order_record(
                order_id=oid,
                symbol=symbol,
                target_cents=amount_cents,
                qty_sent=qty,
                quote=price,
                status="rejected",
                message="Too small for one thousandth of a share.",
            )
        else:
            rec = order_record(
                order_id=oid,
                symbol=symbol,
                target_cents=amount_cents,
                qty_sent=qty,
                quote=price,
                status="filled",
                filled_qty=qty,
                avg_price=price,
            )
            self._cash -= rec["filled_cents"]
            self._positions[symbol] = self._positions.get(symbol, Decimal(0)) + qty
        self._orders[oid] = rec
        return rec

    def order(self, order_id: str) -> dict:
        return self._orders[order_id]

    def positions(self) -> list[dict]:
        return [
            {"symbol": s, "qty": str(q), "value_cents": to_cents(q * self._price(s))}
            for s, q in self._positions.items()
        ]
