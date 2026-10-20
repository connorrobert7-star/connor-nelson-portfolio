"""/state is composed of sections that features contribute.

    @section(order=20)
    def crops(ctx: Ctx, view: View) -> dict:
        return {"crops": {...}}

Sections run in order and their dicts are merged at the top level. Finalizers
run afterwards with the whole state, for things that read across features
(villager lines, quests, notifications).
"""

from collections.abc import Callable
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class View:
    weeks_ago: int = 0


SECTIONS: list[tuple[int, str, Callable[..., dict]]] = []
FINALIZERS: list[tuple[int, str, Callable[..., dict | None]]] = []


def _register(table: list, order: int) -> Callable:
    def deco(fn: Callable) -> Callable:
        name = f"{fn.__module__}.{fn.__qualname__}"
        if all(existing != name for _, existing, _ in table):
            table.append((order, name, fn))
            table.sort(key=lambda t: (t[0], t[1]))
        return fn

    return deco


def section(order: int = 50) -> Callable:
    return _register(SECTIONS, order)


def finalizer(order: int = 50) -> Callable:
    return _register(FINALIZERS, order)


def compose(ctx: Any, view: View) -> dict:
    state: dict = {}
    for _, name, fn in SECTIONS:
        part = fn(ctx, view)
        clash = state.keys() & part.keys()
        if clash:
            raise RuntimeError(f"State keys {sorted(clash)} from {name} are already taken.")
        state.update(part)
    for _, _, fn in FINALIZERS:
        part = fn(ctx, state)
        if part:
            state.update(part)
    return state
