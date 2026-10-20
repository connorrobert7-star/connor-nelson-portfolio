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
    """Holdings, read only. Real: SnapTrade (Fidelity)."""

    name: str

    def holdings(self, anchor: date, today: date) -> list[dict]:
        """[{id, account_id, symbol, qty, value_cents, as_of}] priced at the weekly close."""
        ...


class MarketDataProvider(Protocol):
    """Weekly prices and history. Never live prices. Real: Alpaca market data or similar."""

    name: str

    def catalog(self) -> list[dict]:
        """[{symbol, name, kind, risk, creature, story, dividend_yield, annual_returns}]"""
        ...

    def weekly_price_cents(self, symbol: str, week_start: date, anchor: date) -> int: ...


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
    """Remaining life expectancy by age. Default: SSA period life table."""

    name: str

    def remaining_years(self, age_years: float, sex: str) -> float: ...
