"""Sprites for the flock, cut and grown from the packs.

    python tools/art/followers.py

Writes game/features/followers/art/:
- lamb_stages.png: the personal follower (megowhat's Little Lamb, CC0) at its seven growth
  stages. Rows are stages 1-7, columns are frames: front x3, blink, facing right, facing left.
  Each cell is 56x56 with the feet on the bottom row. Stage 7 wears a crown.
- egg.png: the egg before the first deposit, 3 frames (whole, cracked, splitting), 16x20.
- veil.png: the mourning veil laid over a follower's head, 20x14.
The packs stay untouched; everything here is generated.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from palette import CREAM, GAME, INK, LEGENDARY, MUTED, NIGHT  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

PACKS = GAME / "art" / "packs"
OUT = GAME / "features" / "followers" / "art"

STAGE_SIZES = (22, 26, 30, 34, 38, 44, 50)  # the lamb's height in px at stages 1-7
CELL = 56
OUTLINE = (*INK, 255)


def _eye_mask(frame: Image.Image) -> list[tuple[int, int]]:
    """The blue irises and their dark pupils and glints, found by color."""
    px = frame.load()
    blue = set()
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = px[x, y]
            if a and b > 150 and r < 120:
                blue.add((x, y))
    eye = set(blue)
    # Grow into the dark pupil and white glint pixels the iris surrounds.
    for _ in range(3):
        for x, y in list(eye):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                r, g, b, a = px[p]
                dark = r < 70 and g < 70 and b < 90
                glint = r > 220 and g > 220 and b > 220
                if a and (dark or glint) and p not in eye:
                    near_blue = sum((p[0] + i, p[1] + j) in blue for i in (-2, 2) for j in (-2, 2))
                    if near_blue:
                        eye.add(p)
    return sorted(eye)


def close_eyes(frame: Image.Image) -> Image.Image:
    """A blink: lids in the face's own color with a dark lash across the middle."""
    out = frame.copy()
    px = out.load()
    eye = _eye_mask(frame)
    if not eye:
        return out
    face = (232, 160, 72, 255)
    for x, y in eye:
        px[x, y] = face
    # One lash per eye: split the mask into left and right halves.
    mid_x = (min(x for x, _ in eye) + max(x for x, _ in eye)) // 2
    d = ImageDraw.Draw(out)
    for side in ([p for p in eye if p[0] < mid_x], [p for p in eye if p[0] >= mid_x]):
        if not side:
            continue
        x0, x1 = min(x for x, _ in side), max(x for x, _ in side)
        y = (min(y for _, y in side) + max(y for _, y in side)) // 2 + 1
        d.line([(x0, y), (x1, y)], fill=OUTLINE, width=2)
        d.line([(x0, y - 1), (x0 - 1, y - 2)], fill=OUTLINE, width=1)
    return out


def shrink(im: Image.Image, size: int) -> Image.Image:
    """Downscale with premultiplied alpha, then snap alpha so it reads as pixel art."""
    small = im.convert("RGBa").resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
    px = small.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a > 110 else (0, 0, 0, 0)
    return small


def outline(im: Image.Image) -> Image.Image:
    """A 1px ink outline so a cream lamb still reads on the dark floor."""
    out = Image.new("RGBA", im.size)
    src = im.load()
    dst = out.load()
    for y in range(im.height):
        for x in range(im.width):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < im.width and 0 <= ny < im.height and src[nx, ny][3]:
                    dst[x, y] = OUTLINE
                    break
    out.alpha_composite(im)
    return out


def crown(size: int) -> Image.Image:
    w = max(11, size // 3) | 1
    im = Image.new("RGBA", (w, 7))
    d = ImageDraw.Draw(im)
    gold, dark = (*LEGENDARY, 255), (*NIGHT, 255)
    d.rectangle([0, 3, w - 1, 6], fill=gold, outline=dark)
    for i, x in enumerate((0, w // 2, w - 1)):
        d.line([(x, 0), (x, 3)], fill=gold)
        d.point((x, 0), fill=(*CREAM, 255) if i == 1 else gold)
    d.point((w // 2, 5), fill=(*CREAM, 255))
    return im


def lamb_stages() -> None:
    sheet = Image.open(PACKS / "megowhat-little-lamb" / "lamb64x64.png").convert("RGBA")
    front = [sheet.crop((i * 64, 0, i * 64 + 64, 64)) for i in range(3)]
    frames = [*front, close_eyes(front[1]), sheet.crop((0, 64, 64, 128))]
    frames.append(sheet.crop((0, 128, 64, 192)))
    out = Image.new("RGBA", (CELL * len(frames), CELL * len(STAGE_SIZES)))
    for s, size in enumerate(STAGE_SIZES):
        for i, frame in enumerate(frames):
            small = outline(shrink(frame, size))
            x, y = i * CELL + (CELL - size) // 2, s * CELL + CELL - size
            out.alpha_composite(small, (x, y))
            if s == len(STAGE_SIZES) - 1:
                c = crown(size)
                out.alpha_composite(c, (x + size // 2 - c.width // 2, y - 4))
    out.save(OUT / "lamb_stages.png")


def egg() -> None:
    """A speckled egg with one lidded eye on its shell: 3 frames, the last one splitting."""
    w, h = 16, 20
    out = Image.new("RGBA", (w * 3, h))
    for f in range(3):
        im = Image.new("RGBA", (w, h))
        d = ImageDraw.Draw(im)
        d.ellipse([2, 3, 13, 19], fill=(*CREAM, 255), outline=(*INK, 255))
        d.ellipse([3, 4, 8, 12], fill=(255, 251, 240, 255))  # shine
        d.arc([4, 10, 13, 18], 0, 120, fill=(*MUTED, 255))  # shade
        for x, y in ((5, 14), (10, 7), (11, 13), (7, 17), (9, 11)):
            d.point((x, y), fill=(*MUTED, 255))
        # The eye: a sleepy lid, open a crack.
        d.line([(6, 10), (9, 10)], fill=(*INK, 255))
        d.point((7, 11), fill=(*INK, 255))
        if f >= 1:
            d.line([(4, 8), (6, 10), (5, 12), (7, 14)], fill=(*INK, 255))
        if f == 2:
            d.line([(7, 14), (10, 12), (12, 14)], fill=(*INK, 255))
            d.line([(9, 4), (10, 6), (12, 7)], fill=(*INK, 255))
        out.alpha_composite(im, (f * w, 0))
    out.save(OUT / "egg.png")


def veil() -> None:
    """Black lace laid over a follower's head for the week of mourning."""
    w, h = 20, 14
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    lace = (*NIGHT, 225)
    d.pieslice([1, 0, w - 2, 14], 180, 360, fill=lace)
    d.polygon([(1, 7), (w - 2, 7), (w - 1, 13), (14, 11), (10, 13), (6, 11), (0, 13)], fill=lace)
    for x in range(1, w - 1, 3):
        d.point((x, 12 if x % 2 else 11), fill=(*MUTED, 255))
    d.arc([1, 0, w - 2, 14], 200, 340, fill=(*MUTED, 200))
    im.save(OUT / "veil.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    lamb_stages()
    egg()
    veil()
    print("wrote", ", ".join(sorted(p.name for p in OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
