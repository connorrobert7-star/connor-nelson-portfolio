"""Shared palette and drawing helpers for every feature's art script.

    import sys; sys.path.insert(0, str(Path(__file__).parent))  # when run directly
    from palette import *

Values match game/scripts/palette.gd. Rarity colors are only for rarity.
Sprites: 16x16 tiles and props, 32x32 characters and creatures, transparent PNG.
"""

import random
from pathlib import Path

from PIL import Image, ImageDraw

GAME = Path(__file__).resolve().parents[2] / "game"


def hex_rgb(h: str) -> tuple[int, int, int]:
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


NIGHT = hex_rgb("120c18")
INK = hex_rgb("1d1424")
PANEL = hex_rgb("2a1d33")
CREAM = hex_rgb("f6ead2")
MUTED = hex_rgb("b9a7c4")
BLOOD = hex_rgb("e0304e")
BILE = hex_rgb("b6e04a")
GLOW = hex_rgb("ffd166")
TEAL = hex_rgb("2ec4b6")
PINK = hex_rgb("ff6fb5")
SKIN = hex_rgb("eed6be")
WHITE = hex_rgb("faf6ec")

COMMON = hex_rgb("9aa0a6")
RARE = hex_rgb("3d8bff")
EPIC = hex_rgb("a347ff")
LEGENDARY = hex_rgb("ffb627")
MYTHIC = hex_rgb("ff2e3a")
RARITY = {"common": COMMON, "rare": RARE, "epic": EPIC, "legendary": LEGENDARY, "mythic": MYTHIC}


def new(w: int, h: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def shade(c: tuple[int, int, int], f: float) -> tuple[int, int, int]:
    """f < 1 darkens, f > 1 lightens."""
    return tuple(max(0, min(255, round(v * f))) for v in c)  # type: ignore[return-value]


def speckle(d: ImageDraw.ImageDraw, box: tuple[int, int, int, int], colors: list, n: int, seed: int) -> None:
    rng = random.Random(seed)
    x0, y0, x1, y1 = box
    for _ in range(n):
        d.point((rng.randint(x0, x1), rng.randint(y0, y1)), fill=rng.choice(colors))


def eyes(d: ImageDraw.ImageDraw, x: int, y: int, gap: int = 7, size: int = 3) -> None:
    """Cult of the Lamb-style big round eyes with a highlight."""
    for ex in (x, x + gap):
        d.ellipse((ex, y, ex + size, y + size + 1), fill=INK)
        d.point((ex + 1, y + 1), fill=WHITE)


def save(img: Image.Image, feature_id: str, name: str) -> Path:
    out = GAME / "features" / feature_id / "art"
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"{name}.png"
    img.save(path)
    return path
