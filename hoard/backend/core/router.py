"""Framework-free routes.

Handlers are plain functions `fn(ctx, **params)`. Params come from the query
string and the JSON body, coerced by the handler's type hints. The same table
serves FastAPI locally (backend/app.py) and Pyodide in the browser demo.

    @route("POST", "/shop/stock")
    def buy(ctx: Ctx, symbol: str, amount_cents: int) -> dict: ...
"""

import inspect
import types
import typing
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any


class ApiError(Exception):
    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


@dataclass(frozen=True)
class Route:
    method: str
    path: str
    fn: Callable[..., Any]
    params: dict[str, tuple[Any, Any]]  # name -> (type, default)


ROUTES: dict[tuple[str, str], Route] = {}


def route(method: str, path: str) -> Callable[[Callable[..., Any]], Callable[..., Any]]:
    def register(fn: Callable[..., Any]) -> Callable[..., Any]:
        hints = typing.get_type_hints(fn)
        params = {
            name: (hints.get(name, str), p.default)
            for name, p in list(inspect.signature(fn).parameters.items())[1:]
        }
        key = (method.upper(), path)
        if key in ROUTES and ROUTES[key].fn.__qualname__ != fn.__qualname__:
            raise RuntimeError(f"Route {method} {path} is registered twice.")
        ROUTES[key] = Route(method.upper(), path, fn, params)
        return fn

    return register


def _unwrap_optional(kind: Any) -> Any:
    if typing.get_origin(kind) in (typing.Union, types.UnionType):
        args = [a for a in typing.get_args(kind) if a is not type(None)]
        return args[0] if len(args) == 1 else Any
    return kind


def _coerce(name: str, value: Any, kind: Any) -> Any:
    kind = _unwrap_optional(kind)
    if value is None:
        return None
    origin = typing.get_origin(kind) or kind
    try:
        if origin is bool:
            if isinstance(value, str):
                return value.lower() in ("1", "true", "yes")
            return bool(value)
        if origin is int:
            if isinstance(value, bool) or not float(value).is_integer():
                raise ValueError
            return int(float(value))
        if origin is float:
            return float(value)
        if origin is str:
            return str(value)
        if origin in (list, dict):
            if not isinstance(value, origin):
                raise ValueError
            return value
    except (TypeError, ValueError):
        name_of = getattr(origin, "__name__", str(origin))
        raise ApiError(422, f"{name} must be {name_of}.") from None
    return value


def call(ctx: Any, method: str, path: str, query: dict | None, body: dict | None) -> Any:
    r = ROUTES.get((method.upper(), path))
    if r is None:
        raise ApiError(404, f"No route {method.upper()} {path}.")
    given = {**(query or {}), **(body or {})}
    kwargs = {}
    for name, (kind, default) in r.params.items():
        if name in given:
            kwargs[name] = _coerce(name, given[name], kind)
        elif default is inspect.Parameter.empty:
            raise ApiError(422, f"Missing {name}.")
    return r.fn(ctx, **kwargs)
