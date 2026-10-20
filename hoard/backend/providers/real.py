"""Stubs for the real services. Each raises NotConfigured until it is filled in.

To plug one in: implement the methods from providers/base.py, read keys from the
environment (never from the game), and select it with the matching HOARD_* variable.
Nothing outside backend/providers/ needs to change.
"""

import os
from datetime import date

from backend.providers.base import NotConfigured


def _need(*keys: str) -> None:
    missing = [k for k in keys if not os.environ.get(k)]
    if missing:
        raise NotConfigured(f"Set {', '.join(missing)} to use this provider.")


class PlaidBank:
    """Plaid: /accounts/get, /transactions/sync (cursor), /liabilities/get.
    Env: PLAID_CLIENT_ID, PLAID_SECRET, PLAID_ACCESS_TOKEN, PLAID_ENV."""

    name = "plaid"

    def __init__(self) -> None:
        _need("PLAID_CLIENT_ID", "PLAID_SECRET", "PLAID_ACCESS_TOKEN")

    def accounts(self, anchor: date, today: date) -> list[dict]:
        raise NotConfigured("PlaidBank.accounts is not written yet.")

    def transactions(self, anchor: date, start: date, end: date) -> list[dict]:
        raise NotConfigured("PlaidBank.transactions is not written yet.")

    def liabilities(self, anchor: date, today: date) -> list[dict]:
        raise NotConfigured("PlaidBank.liabilities is not written yet.")


class SnapTradeBrokerage:
    """SnapTrade: list holdings for the connected Fidelity account, weekly.
    Env: SNAPTRADE_CLIENT_ID, SNAPTRADE_CONSUMER_KEY, SNAPTRADE_USER_ID, SNAPTRADE_USER_SECRET."""

    name = "snaptrade"

    def __init__(self) -> None:
        _need("SNAPTRADE_CLIENT_ID", "SNAPTRADE_CONSUMER_KEY", "SNAPTRADE_USER_ID")

    def holdings(self, anchor: date, today: date) -> list[dict]:
        raise NotConfigured("SnapTradeBrokerage.holdings is not written yet.")


class AlpacaMarket:
    """Alpaca market data: weekly bars for the catalog symbols. Never live quotes in game.
    Env: ALPACA_KEY_ID, ALPACA_SECRET_KEY."""

    name = "alpaca"

    def __init__(self) -> None:
        _need("ALPACA_KEY_ID", "ALPACA_SECRET_KEY")

    def catalog(self) -> list[dict]:
        raise NotConfigured("AlpacaMarket.catalog is not written yet.")

    def weekly_price_cents(self, symbol: str, week_start: date, anchor: date) -> int:
        raise NotConfigured("AlpacaMarket.weekly_price_cents is not written yet.")


class PlaidTransfers:
    """Plaid Transfer: ACH between the player's own linked accounts. Starts as 'pending'.
    Env: PLAID_CLIENT_ID, PLAID_SECRET, PLAID_TRANSFER_ACCESS_TOKEN."""

    name = "plaid_transfer"
    simulated = False

    def __init__(self) -> None:
        _need("PLAID_CLIENT_ID", "PLAID_SECRET", "PLAID_TRANSFER_ACCESS_TOKEN")

    def submit(self, from_account: str, to_account: str, amount_cents: int, reason: str) -> dict:
        raise NotConfigured("PlaidTransfers.submit is not written yet.")


class ClaudeAdvisor:
    """Claude API: money ideas and stock stories from the player's numbers.
    Env: ANTHROPIC_API_KEY."""

    name = "claude"

    def __init__(self) -> None:
        _need("ANTHROPIC_API_KEY")

    def money_ideas(self, facts: dict) -> list[dict]:
        raise NotConfigured("ClaudeAdvisor.money_ideas is not written yet.")

    def stock_story(self, ticker: dict, facts: dict) -> str:
        raise NotConfigured("ClaudeAdvisor.stock_story is not written yet.")


class BureauCredit:
    """A credit bureau or aggregator API for the real score and factors.
    Env: CREDIT_API_KEY."""

    name = "bureau"

    def __init__(self) -> None:
        _need("CREDIT_API_KEY")

    def report(self, anchor: date, today: date, facts: dict) -> dict:
        raise NotConfigured("BureauCredit.report is not written yet.")
