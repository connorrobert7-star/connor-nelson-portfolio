"""Placeholder pixel art for Phase 0. Replace with Aseprite art later.

    python tools/art/core.py

Writes PNGs into game/art/. Muted palette on purpose: rarity colors are the only
loud colors in the game, and Phase 0 has none.
"""

import random
from pathlib import Path

from PIL import Image, ImageDraw

ART = Path(__file__).resolve().parents[2] / "game" / "art"

INK = (43, 38, 34)
GRASS = (111, 143, 78)
GRASS_D = (94, 125, 66)
GRASS_L = (132, 163, 92)
PATH = (200, 180, 138)
PATH_D = (176, 156, 114)
WATER = (79, 127, 154)
WATER_L = (109, 155, 179)
WATER_D = (62, 106, 132)
MUD = (138, 122, 90)
MUD_D = (116, 101, 72)
SOIL = (122, 90, 60)
SOIL_D = (95, 68, 48)
TRUNK = (91, 64, 48)
LEAF = (63, 107, 58)
LEAF_L = (79, 127, 69)
LEAF_D = (47, 85, 48)
WOOD = (139, 99, 64)
WOOD_D = (110, 76, 48)
ROOF = (154, 91, 69)
ROOF_D = (125, 70, 54)
STONE = (154, 154, 142)
STONE_D = (125, 125, 114)
CREAM = (232, 220, 192)
GLOW = (243, 227, 160)
CLOAK = (88, 78, 110)
CLOAK_D = (68, 60, 88)
SKIN = (238, 214, 190)
WHITE = (250, 246, 236)
CROP = (98, 150, 70)
CROP_L = (130, 176, 88)
PRODUCE = (214, 150, 72)
WILT = (176, 168, 86)
WILT_D = (150, 138, 70)
DEAD = (128, 100, 64)
DEAD_D = (104, 80, 52)


def new(w: int, h: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def speckle(d: ImageDraw.ImageDraw, x0: int, colors: list, n: int, seed: int) -> None:
    rng = random.Random(seed)
    for _ in range(n):
        d.point((x0 + rng.randrange(16), rng.randrange(16)), fill=rng.choice(colors))


def tiles() -> Image.Image:
    # 0 grass, 1 grass tuft, 2 path, 3 water, 4 low water (mud), 5 soil, 6 tree, 7 stone,
    # 8 wood floor, 9 wall face, 10 wall top, 11 door mat, 12 counter, 13 table, 14 rug
    img, d = new(16 * 15, 16)
    d.rectangle((0, 0, 15, 15), fill=GRASS)
    speckle(d, 0, [GRASS_D, GRASS_L], 14, 1)
    d.rectangle((16, 0, 31, 15), fill=GRASS)
    speckle(d, 16, [GRASS_D], 8, 2)
    for x, y in ((19, 9), (24, 4), (27, 11)):
        d.line((x, y, x, y + 3), fill=GRASS_L)
        d.line((x + 1, y + 1, x + 1, y + 3), fill=GRASS_D)
    d.rectangle((32, 0, 47, 15), fill=PATH)
    speckle(d, 32, [PATH_D], 12, 3)
    d.rectangle((48, 0, 63, 15), fill=WATER)
    for y in (3, 10):
        d.line((50, y, 54, y), fill=WATER_L)
        d.line((57, y + 3, 61, y + 3), fill=WATER_L)
    d.line((48, 15, 63, 15), fill=WATER_D)
    d.rectangle((64, 0, 79, 15), fill=MUD)
    speckle(d, 64, [MUD_D], 16, 4)
    d.rectangle((64, 12, 79, 15), fill=WATER_D)
    d.rectangle((80, 0, 95, 15), fill=SOIL)
    for y in (2, 7, 12):
        d.line((80, y, 95, y), fill=SOIL_D)
    d.rectangle((96, 0, 111, 15), fill=GRASS)
    d.ellipse((97, 0, 110, 11), fill=LEAF_D)
    d.ellipse((98, 0, 109, 9), fill=LEAF)
    d.ellipse((100, 1, 105, 5), fill=LEAF_L)
    d.rectangle((103, 11, 104, 15), fill=TRUNK)
    d.rectangle((112, 0, 127, 15), fill=STONE)
    d.line((112, 7, 127, 7), fill=STONE_D)
    d.line((119, 0, 119, 7), fill=STONE_D)
    d.line((115, 8, 115, 15), fill=STONE_D)
    d.line((124, 8, 124, 15), fill=STONE_D)
    x = 128
    d.rectangle((x, 0, x + 15, 15), fill=WOOD)
    for y in (3, 7, 11, 15):
        d.line((x, y, x + 15, y), fill=WOOD_D)
    d.point((x + 5, 1), fill=WOOD_D)
    d.point((x + 11, 9), fill=WOOD_D)
    x = 144
    d.rectangle((x, 0, x + 15, 15), fill=CREAM)
    d.rectangle((x, 0, x + 15, 2), fill=WOOD_D)
    d.rectangle((x, 13, x + 15, 15), fill=WOOD_D)
    speckle(d, x, [(220, 206, 176)], 10, 7)
    x = 160
    d.rectangle((x, 0, x + 15, 15), fill=INK)
    d.line((x, 15, x + 15, 15), fill=WOOD_D)
    x = 176
    d.rectangle((x, 0, x + 15, 15), fill=WOOD)
    d.rectangle((x + 1, 2, x + 14, 15), fill=ROOF_D)
    for y in (5, 9, 13):
        d.line((x + 2, y, x + 13, y), fill=ROOF)
    x = 192
    d.rectangle((x, 0, x + 15, 15), fill=WOOD)
    d.rectangle((x, 0, x + 15, 9), fill=WOOD_D)
    d.line((x, 9, x + 15, 9), fill=INK)
    d.line((x, 1, x + 15, 1), fill=PATH)
    x = 208
    d.rectangle((x, 0, x + 15, 15), fill=WOOD)
    for y in (3, 7, 11, 15):
        d.line((x, y, x + 15, y), fill=WOOD_D)
    d.ellipse((x + 1, 1, x + 14, 12), fill=WOOD_D, outline=INK)
    d.rectangle((x + 7, 12, x + 8, 15), fill=INK)
    x = 224
    d.rectangle((x, 0, x + 15, 15), fill=ROOF_D)
    d.rectangle((x + 2, 2, x + 13, 13), outline=PRODUCE)
    d.rectangle((x + 5, 5, x + 10, 10), fill=ROOF)
    return img


def crops() -> Image.Image:
    # 0 bumper, 1 healthy, 2 wilting, 3 withered
    img, d = new(64, 16)
    plants = [
        (CROP, CROP_L, PRODUCE),
        (CROP, CROP_L, None),
        (WILT, WILT_D, None),
        (DEAD, DEAD_D, None),
    ]
    for i, (main, light, fruit) in enumerate(plants):
        x = i * 16
        if i < 2:
            h = 11 if fruit else 9
            d.line((x + 8, 15, x + 8, 15 - h), fill=main)
            d.ellipse((x + 3, 15 - h, x + 8, 15 - h + 4), fill=light)
            d.ellipse((x + 8, 14 - h + 3, x + 13, 14 - h + 7), fill=main)
            d.ellipse((x + 4, 9, x + 8, 12), fill=main)
            if fruit:
                d.ellipse((x + 9, 9, x + 13, 13), fill=PRODUCE)
                d.ellipse((x + 2, 12, x + 5, 15), fill=PRODUCE)
        elif i == 2:
            d.line((x + 8, 15, x + 8, 9), fill=main)
            d.line((x + 8, 9, x + 11, 11), fill=main)
            d.line((x + 8, 11, x + 4, 13), fill=light)
            d.line((x + 11, 11, x + 12, 13), fill=light)
        else:
            d.line((x + 8, 15, x + 7, 11), fill=main)
            d.line((x + 7, 11, x + 4, 13), fill=light)
            d.line((x + 9, 15, x + 12, 14), fill=light)
    return img


def leader() -> Image.Image:
    # 32x32 frames: down0 down1 up0 up1 side0 side1
    img, d = new(32 * 6, 32)
    for f in range(6):
        x = f * 32
        bob = f % 2
        facing = ("down", "up", "side")[f // 2]
        d.ellipse((x + 9, 27, x + 23, 31), fill=(0, 0, 0, 60))
        # cloak
        d.polygon(
            [(x + 10, 29 - bob), (x + 22, 29 - bob), (x + 20, 17), (x + 12, 17)],
            fill=CLOAK,
            outline=INK,
        )
        d.line((x + 16, 19, x + 16, 28 - bob), fill=CLOAK_D)
        # feet
        d.rectangle((x + 12, 29 - bob, x + 14, 30), fill=INK)
        d.rectangle((x + 18, 29 - (1 - bob), x + 20, 30), fill=INK)
        # head
        d.ellipse((x + 8, 3 - bob, x + 24, 19 - bob), fill=SKIN, outline=INK)
        # hair tuft
        d.arc((x + 8, 3 - bob, x + 24, 19 - bob), 200, 340, fill=WOOD_D, width=3)
        if facing == "down":
            for ex in (11, 18):
                d.ellipse((x + ex, 9 - bob, x + ex + 3, 14 - bob), fill=INK)
                d.point((x + ex + 1, 10 - bob), fill=WHITE)
            d.point((x + 16, 16 - bob), fill=ROOF_D)
        elif facing == "up":
            d.ellipse((x + 9, 4 - bob, x + 23, 15 - bob), fill=WOOD_D)
        else:
            d.ellipse((x + 18, 9 - bob, x + 21, 14 - bob), fill=INK)
            d.point((x + 19, 10 - bob), fill=WHITE)
            d.arc((x + 8, 3 - bob, x + 24, 19 - bob), 160, 260, fill=WOOD_D, width=4)
    return img


NPCS = [
    # name, body, body dark, hair, hat
    ("marlo", (92, 120, 84), (70, 96, 64), (120, 110, 100), None),
    ("bess", (150, 82, 70), (120, 62, 52), (90, 58, 40), "bun"),
    ("wren", (96, 112, 140), (74, 88, 112), (170, 120, 70), "straw"),
    ("odo", (226, 218, 198), (196, 186, 162), (226, 218, 198), "hood"),
]


def npcs() -> Image.Image:
    # 32x32 frames, one per villager, all facing down.
    img, d = new(32 * len(NPCS), 32)
    for i, (_, body, body_d, hair, hat) in enumerate(NPCS):
        x = i * 32
        d.ellipse((x + 9, 27, x + 23, 31), fill=(0, 0, 0, 60))
        d.polygon([(x + 9, 30), (x + 23, 30), (x + 21, 17), (x + 11, 17)], fill=body, outline=INK)
        d.line((x + 16, 19, x + 16, 29), fill=body_d)
        if i == 0:  # shop apron
            d.rectangle((x + 13, 20, x + 19, 29), fill=CREAM, outline=INK)
        d.ellipse((x + 8, 3, x + 24, 19), fill=SKIN, outline=INK)
        if hat == "hood":
            d.arc((x + 6, 1, x + 26, 21), 180, 360, fill=body, width=4)
            d.line((x + 7, 11, x + 7, 18), fill=body, width=2)
            d.line((x + 25, 11, x + 25, 18), fill=body, width=2)
        else:
            d.arc((x + 8, 3, x + 24, 19), 200, 340, fill=hair, width=3)
        if hat == "bun":
            d.ellipse((x + 13, 0, x + 19, 5), fill=hair, outline=INK)
        if hat == "straw":
            d.ellipse((x + 4, 4, x + 28, 9), fill=PATH, outline=INK)
            d.ellipse((x + 10, 0, x + 22, 7), fill=PATH, outline=INK)
            d.line((x + 10, 6, x + 22, 6), fill=ROOF)
        for ex in (11, 18):
            d.ellipse((x + ex, 9, x + ex + 3, 14), fill=INK)
            d.point((x + ex + 1, 10), fill=WHITE)
        d.point((x + 16, 16), fill=ROOF_D)
    return img


def shelf() -> Image.Image:
    # 16x32 shelf against the back wall.
    img, d = new(16, 32)
    d.rectangle((0, 0, 15, 31), fill=WOOD_D, outline=INK)
    for y in (9, 19, 29):
        d.line((1, y, 14, y), fill=WOOD)
    rng = random.Random(11)
    for y in (2, 12, 22):
        x = 2
        while x < 13:
            w = rng.choice((2, 3, 4))
            c = rng.choice([CREAM, STONE, PATH, ROOF, WATER_L])
            d.rectangle((x, y + rng.choice((0, 1, 2)), min(x + w - 1, 13), y + 6), fill=c)
            x += w + 1
    return img


def fireplace() -> Image.Image:
    img, d = new(32, 32)
    d.rectangle((0, 4, 31, 31), fill=STONE, outline=INK)
    d.rectangle((0, 4, 31, 8), fill=STONE_D, outline=INK)
    d.rectangle((7, 14, 24, 31), fill=INK)
    d.polygon([(10, 31), (16, 17), (22, 31)], fill=PRODUCE)
    d.polygon([(13, 31), (16, 23), (19, 31)], fill=GLOW)
    return img


def villager() -> Image.Image:
    # 16x16 frames: awake, asleep
    img, d = new(32, 16)
    for f in range(2):
        x = f * 16
        d.ellipse((x + 2, 12, x + 13, 15), fill=(0, 0, 0, 50))
        d.ellipse((x + 2, 3, x + 13, 14), fill=CREAM, outline=INK)
        d.polygon([(x + 3, 6), (x + 2, 1), (x + 6, 4)], fill=CREAM, outline=INK)
        d.polygon([(x + 12, 6), (x + 13, 1), (x + 9, 4)], fill=CREAM, outline=INK)
        if f == 0:
            d.rectangle((x + 5, 7, x + 6, 9), fill=INK)
            d.rectangle((x + 9, 7, x + 10, 9), fill=INK)
        else:
            d.line((x + 5, 9, x + 6, 9), fill=INK)
            d.line((x + 9, 9, x + 10, 9), fill=INK)
    return img


def tavern() -> Image.Image:
    img, d = new(64, 48)
    d.rectangle((4, 18, 59, 47), fill=WOOD, outline=INK)
    for y in range(22, 47, 5):
        d.line((5, y, 58, y), fill=WOOD_D)
    d.polygon([(0, 20), (32, 2), (63, 20)], fill=ROOF, outline=INK)
    d.line((8, 16, 56, 16), fill=ROOF_D)
    d.rectangle((26, 30, 37, 47), fill=WOOD_D, outline=INK)
    d.point((35, 39), fill=GLOW)
    for wx in (10, 44):
        d.rectangle((wx, 26, wx + 9, 34), fill=GLOW, outline=INK)
        d.line((wx + 4, 26, wx + 4, 34), fill=INK)
    # hanging mug sign
    d.line((42, 20, 52, 20), fill=INK)
    d.rectangle((45, 21, 51, 27), fill=CREAM, outline=INK)
    d.rectangle((47, 22, 49, 26), fill=PRODUCE)
    return img


def shop() -> Image.Image:
    img, d = new(48, 48)
    d.rectangle((3, 16, 44, 47), fill=CREAM, outline=INK)
    d.polygon([(0, 18), (24, 4), (47, 18)], fill=STONE_D, outline=INK)
    # awning stripes, muted
    for i in range(6):
        d.rectangle((4 + i * 7, 18, 10 + i * 7, 22), fill=ROOF if i % 2 else CREAM, outline=INK)
    d.rectangle((18, 30, 29, 47), fill=WOOD, outline=INK)
    d.point((27, 39), fill=INK)
    d.rectangle((6, 28, 14, 36), fill=WATER_L, outline=INK)
    d.rectangle((33, 28, 41, 36), fill=WATER_L, outline=INK)
    return img


def shrine() -> Image.Image:
    # 32x48 frames: dim, glowing
    img, d = new(64, 48)
    for f in range(2):
        x = f * 32
        if f:
            d.ellipse((x + 2, 4, x + 29, 31), fill=(*GLOW, 90))
            d.ellipse((x + 7, 9, x + 24, 26), fill=(*GLOW, 140))
        d.rectangle((x + 6, 38, x + 25, 47), fill=STONE, outline=INK)
        d.rectangle((x + 10, 16, x + 21, 38), fill=STONE, outline=INK)
        d.line((x + 11, 30, x + 20, 30), fill=STONE_D)
        d.ellipse((x + 9, 6, x + 22, 19), fill=GLOW if f else STONE_D, outline=INK)
        d.ellipse((x + 13, 10, x + 18, 15), fill=WHITE if f else STONE)
    return img


def house_plot() -> Image.Image:
    img, d = new(48, 48)
    d.rectangle((4, 8, 43, 43), fill=SOIL)
    speckle(d, 8, [SOIL_D], 20, 5)
    speckle(d, 24, [SOIL_D], 20, 6)
    d.rectangle((10, 16, 37, 37), outline=STONE)
    d.rectangle((11, 17, 36, 36), outline=STONE_D)
    for px, py in ((3, 6), (44, 6), (3, 42), (44, 42)):
        d.rectangle((px - 1, py - 3, px, py + 3), fill=WOOD, outline=INK)
    d.line((4, 5, 43, 5), fill=CREAM)
    d.line((4, 41, 43, 41), fill=CREAM)
    d.line((3, 6, 3, 41), fill=CREAM)
    d.line((44, 6, 44, 41), fill=CREAM)
    return img


def drain() -> Image.Image:
    # 16x16 frames: dry, dripping. Pipe sticks out of the bank into the river above.
    img, d = new(32, 16)
    for f in range(2):
        x = f * 16
        d.rectangle((x + 4, 0, x + 11, 9), fill=STONE_D, outline=INK)
        d.rectangle((x + 5, 1, x + 10, 3), fill=INK)
        d.rectangle((x + 3, 8, x + 12, 12), fill=STONE, outline=INK)
        if f:
            d.line((x + 7, 0, x + 7, 0), fill=WATER_L)
            d.point((x + 8, 2), fill=WATER_L)
    return img


def sign() -> Image.Image:
    img, d = new(16, 16)
    d.rectangle((7, 9, 8, 15), fill=WOOD_D)
    d.rectangle((1, 1, 14, 10), fill=WOOD, outline=INK)
    for y in (4, 7):
        d.line((3, y, 12, y), fill=CREAM)
    return img


def coin() -> Image.Image:
    img, d = new(8, 8)
    d.ellipse((0, 0, 7, 7), fill=GLOW, outline=INK)
    d.line((3, 2, 3, 5), fill=PRODUCE)
    return img


def main() -> None:
    ART.mkdir(parents=True, exist_ok=True)
    for name, fn in [
        ("tiles", tiles),
        ("crops", crops),
        ("leader", leader),
        ("villager", villager),
        ("tavern", tavern),
        ("shop", shop),
        ("shrine", shrine),
        ("house_plot", house_plot),
        ("drain", drain),
        ("sign", sign),
        ("npcs", npcs),
        ("shelf", shelf),
        ("fireplace", fireplace),
        ("coin", coin),
    ]:
        fn().save(ART / f"{name}.png")


if __name__ == "__main__":
    main()
