"""Day-one broker check: one paper order for about $5, through OpenD, and exactly what happened.

    pip install moomoo-api
    python tools/broker_check.py                 # $5 of VTI, paper
    python tools/broker_check.py --symbol AAPL --dollars 5

Always paper (TrdEnv.SIMULATE), whatever HOARD_LIVE says. Run it with OpenD open and logged
in, during regular US hours (moomoo's paper trading doesn't fill pre-market or after hours).
It uses the game's own MoomooBroker, so a pass here means the game's orders will work.
"""

import argparse
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from backend.envfile import load_env  # noqa: E402
from backend.providers.broker import BrokerError, share_count  # noqa: E402
from backend.providers.moomoo import MoomooBroker  # noqa: E402


def dollars(cents: int) -> str:
    return f"-${-cents / 100:,.2f}" if cents < 0 else f"${cents / 100:,.2f}"


def main() -> int:
    load_env()
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--symbol", default="VTI", help="a fractional-eligible US stock or ETF")
    ap.add_argument("--dollars", type=float, default=5.0)
    ap.add_argument("--wait", type=float, default=60.0, help="seconds to wait for the fill")
    ap.add_argument("--anyway", action="store_true", help="place it even if the market is shut")
    args = ap.parse_args()
    target = round(args.dollars * 100)
    broker = MoomooBroker(paper=True, wait_seconds=args.wait)
    print(f"Broker check: PAPER ONLY, OpenD at {broker.host}:{broker.port}")
    try:
        is_open = broker.market_open()
        print(f"  US market open now: {'yes' if is_open else 'no'}")
        cash_before = broker.cash_cents()
        print(f"  Paper cash before:  {dollars(cash_before)}")
        quote = broker.quote(args.symbol)
        qty = share_count(target, quote)
        print(f"  Quote {args.symbol}:        ${quote}")
        print(
            f"  Target:             {dollars(target)}  ->  {qty} shares (3 decimals, rounded down)"
        )
        if not is_open and not args.anyway:
            print("\nThe US market is closed. moomoo paper trading only fills 9:30 to 16:00 ET")
            print("on trading days. Run this again then (or add --anyway to see what it says).")
            return 2
        started = time.monotonic()
        rec = broker.buy(args.symbol, target, "hoard broker_check")
        took = time.monotonic() - started
    except BrokerError as e:
        print(f"\nSTOPPED: {e}")
        print("Check: OpenD is open and logged in, the API port matches MOOMOO_PORT (11111 by")
        print("default), and `pip install moomoo-api` ran in this Python.")
        return 1
    print(f"\n  Order id:           {rec['order_id'] or '(none)'}")
    print(f"  Status:             {rec['status']}  ({rec['message'] or 'no message'})")
    print(f"  Shares sent:        {rec['qty_sent']}")
    print(f"  Shares filled:      {rec['filled_qty']}")
    print(f"  Average fill price: ${rec['avg_price']}")
    print(f"  Dollar target:      {dollars(rec['target_cents'])}")
    print(f"  Actual fill:        {dollars(rec['filled_cents'])}")
    print(f"  Left as cash:       {dollars(rec['leftover_cents'])}")
    print(f"  Seconds to answer:  {took:.1f}")
    try:
        print(f"  Paper cash after:   {dollars(broker.cash_cents())}")
    except BrokerError as e:
        print(f"  Paper cash after:   (couldn't read: {e})")
    if rec["status"] == "filled":
        print("\nPASS: moomoo filled a fractional paper order. The game can trade through it.")
        return 0
    if rec["status"] == "open":
        print("\nNOT FILLED YET: the order was accepted but hadn't filled. Check it in the moomoo")
        print("app (Paper Trading > Orders) and tell Claude what it shows.")
        return 3
    print("\nFAILED: moomoo didn't take the fractional order. Stop here and tell Claude the")
    print("Status line above. Alpaca (dollar-amount orders) is the fallback.")
    return 4


if __name__ == "__main__":
    sys.exit(main())
