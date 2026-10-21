"""Placeholders for the art packs that must be downloaded by hand.

    python tools/art/placeholders.py                 # write any missing placeholders
    python tools/art/placeholders.py --force         # rewrite every placeholder (never real files)
    python tools/art/placeholders.py --status        # which files are still placeholders
    python tools/art/placeholders.py --scan SLUG DIR # re-measure SLUG's layout from real files

Some packs Hoard builds against can't live in this public repo (their licenses forbid
redistribution or commercial use). For each one, tools/art/placeholder_specs.json records
the real pack's file names, image sizes and where each frame or tile sits. This script
draws a stand-in with the same name and size into game/art/placeholders/<slug>/: one flat
muted silhouette per frame with a 1px neutral outline, so scenes, atlases and frame counts
work before the real files exist. Download the pack from the link in docs/ASSETS.md and
copy its files over the placeholders. The folder is git-ignored, so neither the stand-ins
nor the real files are ever committed.

Real files are never overwritten: every placeholder PNG carries a "hoard-placeholder" text
chunk, and a file without it is treated as the real thing.
"""

from __future__ import annotations

import argparse
import filecmp
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo

ROOT = Path(__file__).resolve().parents[2]
SPECS = Path(__file__).resolve().parent / "placeholder_specs.json"
OUT = ROOT / "game" / "art" / "placeholders"
MARK = "hoard-placeholder"

# Muted fills from the master palette in docs/ASSETS.md. No rarity color appears here.
FILLS = {
    "tile": (0x4A, 0x51, 0x60),  # iron
    "prop": (0x6B, 0x58, 0x78),  # mauve
    "actor": (0x82, 0x63, 0x4C),  # oak
    "fx": (0x8E, 0x7D, 0x99),  # haze
    "ui": (0x3A, 0x2A, 0x45),  # shadow
}
OUTLINE = (0xB9, 0xA7, 0xC4)  # muted lavender-grey, not a rarity color
ALPHA_MIN = 8


# ------------------------------------------------------------------------------ measuring


def _alpha(img: Image.Image) -> Image.Image:
    return img.convert("RGBA").getchannel("A").point(lambda a: 255 if a >= ALPHA_MIN else 0)


def _bbox(mask: Image.Image, x: int, y: int, w: int, h: int) -> list[int] | None:
    box = mask.crop((x, y, x + w, y + h)).getbbox()
    if box is None:
        return None
    return [x + box[0], y + box[1], box[2] - box[0], box[3] - box[1]]


def boxes_grid(mask: Image.Image, cw: int, ch: int) -> list[list[int]]:
    """One box per non-empty cell: the bounding box of its opaque pixels."""
    out = []
    for y in range(0, mask.height - ch + 1, ch):
        for x in range(0, mask.width - cw + 1, cw):
            b = _bbox(mask, x, y, cw, ch)
            if b:
                out.append(b)
    return out


def _runs(filled: list[bool]) -> list[tuple[int, int]]:
    runs, start = [], None
    for i, v in enumerate([*filled, False]):
        if v and start is None:
            start = i
        elif not v and start is not None:
            runs.append((start, i))
            start = None
    return runs


def _rows(mask: Image.Image) -> list[bool]:
    return [mask.crop((0, y, mask.width, y + 1)).getbbox() is not None for y in range(mask.height)]


def _cols(mask: Image.Image) -> list[bool]:
    return [mask.crop((x, 0, x + 1, mask.height)).getbbox() is not None for x in range(mask.width)]


def boxes_xycut(mask: Image.Image, depth: int = 0) -> list[list[int]]:
    """Cut on fully transparent rows and columns, recursively: one box per island."""
    tight = mask.getbbox()
    if tight is None:
        return []
    ox, oy = tight[0], tight[1]
    m = mask.crop(tight)
    rows, cols = _runs(_rows(m)), _runs(_cols(m))
    if depth >= 6 or (len(rows) == 1 and len(cols) == 1):
        return [[ox, oy, m.width, m.height]]
    out: list[list[int]] = []
    if len(rows) > 1:
        parts = [(0, y0, m.width, y1) for y0, y1 in rows]
    else:
        parts = [(x0, 0, x1, m.height) for x0, x1 in cols]
    for x0, y0, x1, y1 in parts:
        for b in boxes_xycut(m.crop((x0, y0, x1, y1)), depth + 1):
            out.append([ox + x0 + b[0], oy + y0 + b[1], b[2], b[3]])
    return out


def measure(path: Path, method: str, cell: list[int] | None) -> dict:
    img = Image.open(path)
    mask = _alpha(img)
    if method == "grid":
        boxes = boxes_grid(mask, cell[0], cell[1]) if cell else []
    elif method == "whole":
        b = mask.getbbox()
        boxes = [[b[0], b[1], b[2] - b[0], b[3] - b[1]]] if b else []
    else:
        boxes = boxes_xycut(mask)
    return {"size": list(img.size), "boxes": boxes}


# ------------------------------------------------------------------------------ drawing


def is_placeholder(path: Path, entry: dict) -> bool:
    """True when path is missing or still holds the stand-in this script wrote."""
    if not path.exists():
        return True
    if entry.get("copy_of"):
        return filecmp.cmp(path, ROOT / entry["copy_of"], shallow=False)
    try:
        return MARK in Image.open(path).text  # type: ignore[attr-defined]
    except Exception:
        return False


def draw(entry: dict, fill: tuple[int, int, int]) -> Image.Image:
    w, h = entry["size"]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x, y, bw, bh in entry["boxes"]:
        if bw <= 0 or bh <= 0:
            continue
        x1, y1 = x + bw - 1, y + bh - 1
        if bw < 3 or bh < 3:
            d.rectangle((x, y, x1, y1), fill=fill + (255,))
            continue
        r = 0 if min(bw, bh) < 6 else (1 if min(bw, bh) < 16 else 2)
        d.rounded_rectangle((x, y, x1, y1), radius=r, fill=fill + (255,), outline=OUTLINE + (255,))
    return img


def write_png(img: Image.Image, path: Path, slug: str) -> None:
    meta = PngInfo()
    meta.add_text(MARK, f"{slug}: stand-in, replace with the real file (see docs/ASSETS.md)")
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, pnginfo=meta, optimize=True)


def write_side_files(pack: dict, entry: dict, target: Path) -> None:
    """Frame maps and anchor files some packs ship next to their sheets (facts only)."""
    if entry.get("frame_map"):
        fm = entry["frame_map"]
        cw, ch = fm["cell"]
        cols = entry["size"][0] // cw
        lines = [
            f"{fm['prefix']}/frame{i:04d}.png = {(i % cols) * cw} {(i // cols) * ch} {cw} {ch}"
            for i in range(fm["frames"])
        ]
        (target.parent / fm["file"]).write_text("\n".join(lines) + "\n")
    if entry.get("anchor"):
        a = entry["anchor"]
        data = {
            "placeholder": True,
            "id": a["id"],
            "frameWidth": a["cell"][0],
            "frameHeight": a["cell"][1],
            "states": {
                "on": {
                    "frames": a["frames"],
                    "durationsMs": [a["ms"]] * a["frames"],
                    "loop": a["loop"],
                }
            },
            "files": {"on": target.name},
        }
        (target.parent / f"{a['id']}.anchor.json").write_text(json.dumps(data, indent=2) + "\n")


def readme(pack: dict) -> str:
    files = "\n".join(
        f"- `{e['path']}` ({e['size'][0]}x{e['size'][1]})" if e.get("size") else f"- `{e['path']}`"
        for e in pack["files"]
    )
    return (
        f"# {pack['name']} (placeholder)\n\n"
        f"Stand-ins drawn by `tools/art/placeholders.py`. Same file names and sizes as the real\n"
        f"pack, one flat silhouette per frame or tile.\n\n"
        f"- Get it: {pack['page']}\n- License: {pack['license']}\n- Author: {pack['author']}\n\n"
        f"## Drop-in\n\n{pack['drop']}\n\n"
        f"This folder is git-ignored. The license does not allow the real files in the public\n"
        f"repo, so keep them local.\n\n## Files\n\n{files}\n"
    )


def generate(specs: dict, force: bool) -> tuple[int, int]:
    made = kept = 0
    for pack in specs["packs"]:
        base = OUT / pack["slug"]
        base.mkdir(parents=True, exist_ok=True)
        (base / "README.md").write_text(readme(pack))
        fill = FILLS.get(pack.get("kind", "prop"), FILLS["prop"])
        for entry in pack["files"]:
            target = base / entry["path"]
            if target.exists() and not is_placeholder(target, entry):
                kept += 1
                continue
            if target.exists() and not force:
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            if entry.get("copy_of"):
                shutil.copyfile(ROOT / entry["copy_of"], target)
            else:
                write_png(draw(entry, FILLS.get(entry.get("kind", ""), fill)), target, pack["slug"])
                write_side_files(pack, entry, target)
            made += 1
    return made, kept


def scan(specs: dict, slug: str, src: Path) -> None:
    pack = next(p for p in specs["packs"] if p["slug"] == slug)
    for entry in pack["files"]:
        if entry.get("copy_of"):
            continue
        real = src / entry["path"]
        if not real.exists():
            print(f"missing: {real}", file=sys.stderr)
            continue
        entry.update(measure(real, entry.get("method", "xycut"), entry.get("cell")))


def status(specs: dict) -> None:
    for pack in specs["packs"]:
        base = OUT / pack["slug"]
        real = sum(1 for e in pack["files"] if not is_placeholder(base / e["path"], e))
        print(f"{pack['slug']:36s} {real:4d} real / {len(pack['files']):4d} files")


def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--status", action="store_true")
    ap.add_argument("--scan", nargs=2, metavar=("SLUG", "DIR"))
    args = ap.parse_args()
    specs = json.loads(SPECS.read_text())
    if args.status:
        status(specs)
        return
    if args.scan:
        scan(specs, args.scan[0], Path(args.scan[1]))
        SPECS.write_text(json.dumps(specs, separators=(",", ":")) + "\n")
        print(f"updated {SPECS.name} for {args.scan[0]}")
        return
    made, kept = generate(specs, args.force)
    print(f"placeholders written: {made}, real files kept: {kept}")


if __name__ == "__main__":
    main()
