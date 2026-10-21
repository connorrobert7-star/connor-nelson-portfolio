"""Arcade cabinets for the minigames feature: the one thing no pack has.

    python tools/art/minigames.py

Writes game/features/minigames/art/cabinet.png: three 32x48 cabinets side by side
(mine, fishing, dungeon), each trimmed in its own neon color. The screens are left dark;
the game plays pack sprites on them. Everything else in the arcade comes from the packs.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from palette import INK, NIGHT, PANEL, PINK, TEAL, new, save, shade, speckle  # noqa: E402

AMBER = (255, 154, 60)
TRIMS = [AMBER, TEAL, PINK]
W, H = 32, 48


def cabinet(d, ox: int, trim: tuple[int, int, int], seed: int) -> None:
    body = PANEL
    dark = shade(PANEL, 0.6)
    light = shade(PANEL, 1.35)
    # Side panels lean in toward the top, like a real upright.
    outline = [(ox + 2, 47), (ox + 2, 10), (ox + 5, 2), (ox + 26, 2), (ox + 29, 10), (ox + 29, 47)]
    d.polygon(outline, fill=body)
    d.line([(ox + 2, 47), (ox + 2, 10), (ox + 5, 2)], fill=light)
    d.line([(ox + 29, 10), (ox + 29, 47)], fill=dark)
    # Marquee: a lit band in the cabinet's color.
    d.rectangle((ox + 5, 3, ox + 26, 9), fill=shade(trim, 0.45))
    d.rectangle((ox + 6, 4, ox + 25, 8), fill=shade(trim, 0.8))
    d.line([(ox + 6, 4), (ox + 25, 4)], fill=shade(trim, 1.25))
    # Screen bezel and a black screen.
    d.rectangle((ox + 5, 11, ox + 26, 29), fill=INK)
    d.rectangle((ox + 6, 12, ox + 25, 28), fill=NIGHT)
    d.line([(ox + 5, 29), (ox + 26, 29)], fill=dark)
    # Control deck: tilted slab, a stick and two buttons.
    d.polygon([(ox + 3, 31), (ox + 28, 31), (ox + 30, 35), (ox + 1, 35)], fill=light)
    d.line([(ox + 1, 35), (ox + 30, 35)], fill=dark)
    d.line([(ox + 9, 30), (ox + 9, 33)], fill=INK)
    d.rectangle((ox + 8, 29, ox + 10, 30), fill=shade(trim, 1.1))
    d.rectangle((ox + 17, 32, ox + 18, 33), fill=trim)
    d.rectangle((ox + 21, 32, ox + 22, 33), fill=shade(trim, 0.7))
    # Lower cabinet with a coin door.
    d.rectangle((ox + 4, 36, ox + 27, 46), fill=dark)
    d.rectangle((ox + 12, 38, ox + 19, 44), fill=INK)
    d.rectangle((ox + 14, 40, ox + 14, 42), fill=shade(trim, 1.1))
    d.rectangle((ox + 17, 40, ox + 17, 42), fill=shade(trim, 1.1))
    # Neon piping up both sides.
    for x in (ox + 3, ox + 28):
        d.line([(x, 12), (x, 46)], fill=shade(trim, 0.9))
    speckle(d, (ox + 5, 37, ox + 26, 45), [shade(dark, 0.8), shade(dark, 1.2)], 18, seed)
    # Feet.
    d.rectangle((ox + 3, 47, ox + 6, 47), fill=INK)
    d.rectangle((ox + 25, 47, ox + 28, 47), fill=INK)


def main() -> None:
    img, d = new(W * 3, H)
    for i, trim in enumerate(TRIMS):
        cabinet(d, i * W, trim, seed=i + 7)
    print(save(img, "minigames", "cabinet"))


if __name__ == "__main__":
    main()
