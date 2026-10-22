"""The slots where real services plug in.

Every provider has a fixture implementation that the demo runs on, and a stub
for the real service. Pick implementations with environment variables (see
providers/__init__.py). Money amounts are integer cents. Transaction amounts use
Plaid's sign: positive = money out of the account.
"""

from datetime import date
from typing import Protocol


class NotConfigured(RuntimeError):
    """A real provider was selected but its keys or setup are missing."""


class BankProvider(Protocol):
    """Checking/savings accounts, transactions, and debts. Real: Plaid."""

    name: str

    def accounts(self, anchor: date, today: date) -> list[dict]:
        """[{id, kind: checking|savings|credit|loan, name, balance_cents, limit_cents?}]"""
        ...

    def transactions(self, anchor: date, start: date, end: date) -> list[dict]:
        """[{id, account_id, date, amount_cents, merchant, category}], start..end inclusive.
        category is Plaid's detailed personal_finance_category."""
        ...

    def liabilities(self, anchor: date, today: date) -> list[dict]:
        """[{id, name, kind, balance_cents, apr, min_payment_cents, due_day, limit_cents?}]"""
        ...


class BrokerageProvider(Protocol):
    """Holdings, and the pot's buys. Real: SnapTrade (Fidelity).

    Never sells. place_order spends cash that already landed in the brokerage."""

    name: str

    def holdings(self, anchor: date, today: date) -> list[dict]:
        """[{id, account_id, symbol, qty, value_cents, as_of}] priced at the weekly close."""
        ...

    def place_order(self, symbol: str, amount_cents: int) -> dict:
        """Buy amount_cents of symbol from brokerage cash (the pot, docs/POT.md).
        Returns {status: simulated|pending|filled, order_id?}. Raises NotConfigured when
        trading isn't written yet, which refuses the whole pull."""
        ...


class MarketDataProvider(Protocol):
    """Weekly prices and history. Never live prices. Real: Alpaca market data or similar."""

    name: str

    def catalog(self) -> list[dict]:
        """[{symbol, name, kind, risk, creature, story, dividend_yield, annual_returns}]"""
        ...

    def weekly_price_cents(self, symbol: str, week_start: date, anchor: date) -> int: ...


class BrokerProvider(Protocol):
    """Buys from cash already in the brokerage, one market order per pull. Never sells.

    Real: moomoo through OpenD (share counts), Alpaca (dollar amounts). Paper unless
    HOARD_LIVE=1. Quotes are only used here to size an order; the game never shows them.
    """

    name: str
    paper: bool

    def cash_cents(self) -> int:
        """Settled cash available to buy with."""
        ...

    def market_open(self) -> bool:
        """True during regular US hours (9:30 to 16:00 ET on a trading day)."""
        ...

    def buy(self, symbol: str, amount_cents: int, ref: str) -> dict:
        """Place a market buy for about amount_cents of symbol and wait briefly for the fill.

        Returns {order_id, symbol, target_cents, qty_sent, quote_cents, status, filled_qty,
        avg_price, filled_cents, leftover_cents, message}. status is one of filled, partial,
        open (sent, not filled yet) or rejected. Never pretends an order filled."""
        ...

    def order(self, order_id: str) -> dict:
        """The same shape as buy(), read again (for orders that were still open)."""
        ...

    def positions(self) -> list[dict]:
        """[{symbol, qty, value_cents}]"""
        ...


class TransferProvider(Protocol):
    """Moves money between the player's own accounts. Real: Plaid Transfer."""

    name: str
    simulated: bool

    def submit(self, from_account: str, to_account: str, amount_cents: int, reason: str) -> dict:
        """Returns {status: simulated|pending|failed, external_id?}."""
        ...


class AdvisorProvider(Protocol):
    """Writes money ideas and investment stories. Real: Claude API."""

    name: str

    def money_ideas(self, facts: dict) -> list[dict]:
        """[{title, why, steps: [str], yearly_value_cents, effort: low|medium|high}]"""
        ...

    def stock_story(self, ticker: dict, facts: dict) -> str: ...


class CreditProvider(Protocol):
    """Credit score and the factors behind it. Real: a bureau or aggregator API."""

    name: str

    def report(self, anchor: date, today: date, facts: dict) -> dict:
        """{score, history: [{month, score}], factors: {...}}"""
        ...


class LifeTableProvider(Protocol):
    """Remaining life expectancy by age. Default: CDC NCHS United States Life Tables, 2024."""

    name: str

    def remaining_years(self, age_years: float, sex: str) -> float: ...
