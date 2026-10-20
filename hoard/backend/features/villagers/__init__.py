"""What Wren, Odo, Bess and Marlo say, from the week's numbers."""

from backend.core.context import Ctx
from backend.core.state import finalizer
from backend.features.villagers.lines import village_dialogue


@finalizer(order=50)
def dialogue(ctx: Ctx, state: dict) -> dict:
    lines = village_dialogue(state)
    return {"dialogue": {**state.get("dialogue", {}), **lines}}
