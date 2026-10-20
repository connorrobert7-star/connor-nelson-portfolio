"""Choose which implementation fills each slot.

    HOARD_BANK=fixture|plaid
    HOARD_BROKERAGE=fixture|snaptrade
    HOARD_MARKET=fixture|alpaca
    HOARD_TRANSFERS=simulated|plaid_transfer
    HOARD_ADVISOR=fixture|claude
    HOARD_CREDIT=fixture|bureau
    HOARD_LIFE_TABLE=us   (CDC NCHS United States Life Tables, 2024)

Everything defaults to the demo. The game is in demo mode whenever transfers are
simulated, and only demo mode can move the clock forward.
"""

import os
from collections.abc import Mapping
from dataclasses import dataclass

from backend.providers.base import (
    AdvisorProvider,
    BankProvider,
    BrokerageProvider,
    CreditProvider,
    LifeTableProvider,
    MarketDataProvider,
    NotConfigured,
    TransferProvider,
)


@dataclass
class Providers:
    bank: BankProvider
    brokerage: BrokerageProvider
    market: MarketDataProvider
    transfers: TransferProvider
    advisor: AdvisorProvider
    credit: CreditProvider
    life: LifeTableProvider

    @property
    def demo(self) -> bool:
        return self.transfers.simulated

    def names(self) -> dict[str, str]:
        return {slot: getattr(self, slot).name for slot in self.__dataclass_fields__}


def load(env: Mapping[str, str] = os.environ) -> Providers:
    from backend.providers import fixtures, real

    market = {"fixture": fixtures.FixtureMarket, "alpaca": real.AlpacaMarket}[
        env.get("HOARD_MARKET", "fixture")
    ]()
    bank = {"fixture": fixtures.FixtureBank, "plaid": real.PlaidBank}[
        env.get("HOARD_BANK", "fixture")
    ]()
    brokerage_kind = env.get("HOARD_BROKERAGE", "fixture")
    brokerage = (
        fixtures.FixtureBrokerage(market, bank)
        if brokerage_kind == "fixture"
        else {"snaptrade": real.SnapTradeBrokerage}[brokerage_kind]()
    )
    transfers = {"simulated": fixtures.SimulatedTransfers, "plaid_transfer": real.PlaidTransfers}[
        env.get("HOARD_TRANSFERS", "simulated")
    ]()
    advisor = {"fixture": fixtures.FixtureAdvisor, "claude": real.ClaudeAdvisor}[
        env.get("HOARD_ADVISOR", "fixture")
    ]()
    credit = {"fixture": fixtures.FixtureCredit, "bureau": real.BureauCredit}[
        env.get("HOARD_CREDIT", "fixture")
    ]()
    life = {"us": fixtures.UsLifeTable}[env.get("HOARD_LIFE_TABLE", "us")]()
    return Providers(bank, brokerage, market, transfers, advisor, credit, life)


__all__ = ["NotConfigured", "Providers", "load"]
