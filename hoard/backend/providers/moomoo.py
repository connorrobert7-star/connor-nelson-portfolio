"""moomoo through OpenD, the local gateway app the owner runs (default 127.0.0.1:11111).

    pip install moomoo-api        (imported lazily, so the demo never needs it)

Env: MOOMOO_HOST, MOOMOO_PORT, MOOMOO_ACC_ID (optional), MOOMOO_TRADE_PASSWORD (live only;
the GUI OpenD can unlock trading instead). Paper unless HOARD_LIVE=1.

moomoo takes a share count, not dollars: buy() reads a quote, sends the count to three
decimals rounded down (backend.providers.broker.share_count), and reports the dollar target
next to the actual fill. It only ever sends TrdSide.BUY.
"""

import os
import time
from decimal import Decimal

from backend.providers.broker import BrokerError, order_record, share_count, us_market_open

FILLED = {"FILLED_ALL": "filled"}
PARTIAL = {"FILLED_PART": "partial", "CANCELLED_PART": "partial"}
DEAD = {"SUBMIT_FAILED", "FAILED", "DISABLED", "DELETED", "CANCELLED_ALL", "TIMEOUT"}


def _api():
    try:
        import moomoo
    except ImportError as e:  # pragma: no cover - depends on the owner's machine
        raise BrokerError("Install the moomoo API first: pip install moomoo-api") from e
    return moomoo


def _first(df, column: str, default=None):
    try:
        return df[column].iloc[0]
    except (KeyError, IndexError, AttributeError):
        return default


class MoomooBroker:
    name = "moomoo"

    def __init__(self, paper: bool = True, wait_seconds: float = 8.0) -> None:
        self.paper = paper
        self.wait_seconds = wait_seconds
        self.host = os.environ.get("MOOMOO_HOST", "127.0.0.1")
        self.port = int(os.environ.get("MOOMOO_PORT", "11111"))
        self._acc_id = int(os.environ.get("MOOMOO_ACC_ID", "0") or 0)

    # --- connections ---------------------------------------------------------------

    @property
    def env(self):
        m = _api()
        return m.TrdEnv.SIMULATE if self.paper else m.TrdEnv.REAL

    def _quote_ctx(self):
        m = _api()
        try:
            return m.OpenQuoteContext(host=self.host, port=self.port)
        except Exception as e:  # noqa: BLE001 - the SDK raises plain exceptions
            raise BrokerError(f"Can't reach OpenD at {self.host}:{self.port} ({e}).") from e

    def _trade_ctx(self):
        m = _api()
        try:
            ctx = m.OpenSecTradeContext(
                filter_trdmarket=m.TrdMarket.US,
                host=self.host,
                port=self.port,
                security_firm=m.SecurityFirm.FUTUINC,
            )
        except Exception as e:  # noqa: BLE001
            raise BrokerError(f"Can't reach OpenD at {self.host}:{self.port} ({e}).") from e
        if not self.paper:
            password = os.environ.get("MOOMOO_TRADE_PASSWORD")
            if password:
                ret, data = ctx.unlock_trade(password)
                if ret != m.RET_OK:
                    ctx.close()
                    raise BrokerError(f"moomoo wouldn't unlock live trading: {data}")
        return ctx

    def account_id(self, ctx) -> int:
        """MOOMOO_ACC_ID if set, else the first US stock account for this environment."""
        if self._acc_id:
            return self._acc_id
        m = _api()
        ret, df = ctx.get_acc_list()
        if ret != m.RET_OK:
            raise BrokerError(f"moomoo wouldn't list accounts: {df}")
        want = "SIMULATE" if self.paper else "REAL"
        for _, row in df.iterrows():
            if str(row.get("trd_env")) != want:
                continue
            if "US" not in str(row.get("trdmarket_auth", "")):
                continue
            if self.paper and str(row.get("sim_acc_type", "STOCK")) not in ("STOCK", "N/A", ""):
                continue
            self._acc_id = int(row["acc_id"])
            return self._acc_id
        raise BrokerError(f"No {want.lower()} US stock account on this moomoo login.")

    # --- reads -----------------------------------------------------------------------

    def quote(self, symbol: str) -> Decimal:
        """Last price, only to size an order. Never shown in the game."""
        m = _api()
        ctx = self._quote_ctx()
        try:
            ret, df = ctx.get_market_snapshot([f"US.{symbol}"])
        finally:
            ctx.close()
        if ret != m.RET_OK:
            raise BrokerError(f"No quote for {symbol}: {df}")
        price = _first(df, "last_price")
        if not price:
            raise BrokerError(f"No quote for {symbol}.")
        return Decimal(str(price))

    def cash_cents(self) -> int:
        m = _api()
        ctx = self._trade_ctx()
        try:
            ret, df = ctx.accinfo_query(trd_env=self.env, acc_id=self.account_id(ctx))
        finally:
            ctx.close()
        if ret != m.RET_OK:
            raise BrokerError(f"moomoo wouldn't show the cash: {df}")
        for column in ("us_cash", "usd_cash", "cash"):
            value = _first(df, column)
            if value not in (None, "N/A"):
                return int((Decimal(str(value)) * 100).to_integral_value())
        raise BrokerError("moomoo's account info had no cash field.")

    def market_open(self) -> bool:
        m = _api()
        ctx = self._quote_ctx()
        try:
            ret, data = ctx.get_global_state()
        finally:
            ctx.close()
        if ret == m.RET_OK and isinstance(data, dict) and data.get("market_us"):
            return str(data["market_us"]) in ("MORNING", "AFTERNOON")
        return us_market_open()

    def positions(self) -> list[dict]:
        m = _api()
        ctx = self._trade_ctx()
        try:
            ret, df = ctx.position_list_query(trd_env=self.env, acc_id=self.account_id(ctx))
        finally:
            ctx.close()
        if ret != m.RET_OK:
            raise BrokerError(f"moomoo wouldn't list positions: {df}")
        return [
            {
                "symbol": str(row["code"]).removeprefix("US."),
                "qty": str(row["qty"]),
                "value_cents": int(Decimal(str(row.get("market_val", 0))) * 100),
            }
            for _, row in df.iterrows()
        ]

    # --- the one write -------------------------------------------------------------------

    def buy(self, symbol: str, amount_cents: int, ref: str) -> dict:
        m = _api()
        price = self.quote(symbol)
        qty = share_count(amount_cents, price)
        base = {"symbol": symbol, "target_cents": amount_cents, "qty_sent": qty, "quote": price}
        if qty <= 0:
            return order_record(
                order_id="", status="rejected", message="Less than 0.001 share.", **base
            )
        ctx = self._trade_ctx()
        try:
            acc_id = self.account_id(ctx)
            ret, df = ctx.place_order(
                price=float(price),
                qty=float(qty),
                code=f"US.{symbol}",
                trd_side=m.TrdSide.BUY,
                order_type=m.OrderType.MARKET,
                trd_env=self.env,
                acc_id=acc_id,
                remark=ref[:64],
                time_in_force=m.TimeInForce.DAY,
            )
            if ret != m.RET_OK:
                return order_record(order_id="", status="rejected", message=str(df), **base)
            order_id = str(_first(df, "order_id"))
            return self._wait(ctx, acc_id, order_id, base)
        finally:
            ctx.close()

    def order(self, order_id: str) -> dict:
        ctx = self._trade_ctx()
        try:
            acc_id = self.account_id(ctx)
            return self._read(ctx, acc_id, order_id, None)
        finally:
            ctx.close()

    def _wait(self, ctx, acc_id: int, order_id: str, base: dict) -> dict:
        deadline = time.monotonic() + self.wait_seconds
        rec = self._read(ctx, acc_id, order_id, base)
        while rec["status"] == "open" and time.monotonic() < deadline:
            time.sleep(0.5)
            rec = self._read(ctx, acc_id, order_id, base)
        return rec

    def _read(self, ctx, acc_id: int, order_id: str, base: dict | None) -> dict:
        m = _api()
        ret, df = ctx.order_list_query(order_id=order_id, trd_env=self.env, acc_id=acc_id)
        if ret != m.RET_OK or len(df) == 0:
            raise BrokerError(f"moomoo lost order {order_id}: {df}")
        raw = str(_first(df, "order_status"))
        status = FILLED.get(raw) or PARTIAL.get(raw) or ("rejected" if raw in DEAD else "open")
        if base is None:
            base = {
                "symbol": str(_first(df, "code")).removeprefix("US."),
                "target_cents": 0,
                "qty_sent": Decimal(str(_first(df, "qty", 0))),
                "quote": Decimal(str(_first(df, "price", 0))),
            }
        return order_record(
            order_id=order_id,
            status=status,
            filled_qty=Decimal(str(_first(df, "dealt_qty", 0) or 0)),
            avg_price=Decimal(str(_first(df, "dealt_avg_price", 0) or 0)),
            message=f"{raw} {_first(df, 'last_err_msg', '') or ''}".strip(),
            **base,
        )
