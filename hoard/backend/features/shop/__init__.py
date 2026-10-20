"""Marlo's shop: stocks at the counter."""

from backend.core.context import Ctx
from backend.core.router import route
from backend.core.state import View, section
from backend.features.shop.shop import buy_stock, shop_state


@section(order=30)
def shop_section(ctx: Ctx, view: View) -> dict:
    return {"shop": shop_state(ctx)}


@route("POST", "/shop/stock")
def post_stock(ctx: Ctx, symbol: str, amount_cents: int) -> dict:
    return buy_stock(ctx, symbol, amount_cents)
