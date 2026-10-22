"""Find which art-pack files the game can load, and keep the web export to those.

    python tools/asset_audit.py              # report: kept/dropped per pack, biggest files
    python tools/asset_audit.py --write      # write the exclude list into game/export_presets.cfg
    python tools/asset_audit.py --check      # exit 1 if export_presets.cfg is out of date

The packs in game/art/packs (and the older ones in game/art/placeholders) stay in the
repo whole. Only the web export is trimmed: every pack file nothing can load goes into
the Web preset's exclude_filter, so Godot leaves it out of index.pck.

What counts as loadable, conservatively:
  * every string literal in the game's scripts, scenes, resources, shaders and settings,
    in content/*.json and in the Python engine, that names a pack file, either as
    res://art/packs/... or relative to the packs folder ("ninja-adventure/...");
  * format strings ("impactMining_00%d.ogg", "Character/%s/SpriteSheet.png") keep every
    file the pattern can match;
  * a literal that names a folder or a file-name prefix keeps everything under it;
  * a bare file name or tail ("coin_05a.png", "Cat/SpriteSheet.png") that no kept file
    already ends with keeps every pack file that does;
  * kept .tres/.tscn files keep what they reference;
  * license, credit and readme files of every pack that ships anything are added with
    include_filter, so the export carries them.

build_web.py runs --write before every export, so the list can't go stale.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
PRESET = GAME / "export_presets.cfg"
TREES = ("art/packs", "art/placeholders")
# Exported with the game, but never loaded by it: tours and dev tools.
NOT_SHIPPED = re.compile(r"^(dev/|features/[^/]+/tour_[^/]*\.gd$|\.godot/)")
SCAN_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".json", ".cfg", ".godot"}
ASSET_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".webp", ".svg", ".ogg", ".mp3", ".wav", ".ttf", ".otf",
    ".fnt", ".tres", ".res", ".tscn", ".scn", ".json", ".gdshader",
}  # fmt: skip
LICENSE_NAME = re.compile(r"(licen[cs]e|credit|readme|copying|attribution)", re.I)
STRING = re.compile(r"\"((?:[^\"\\\n]|\\.)*)\"|'((?:[^'\\\n]|\\.)*)'")
FORMAT = re.compile(r"%%|%[-+ #0]*(\d*)(?:\.\d+)?([dsifxXc])|\{[^{}]*\}")
EXT_RESOURCE = re.compile(r'path="(res://[^"]+)"')
CONST_DEF = re.compile(
    r"^\s*(?:static\s+)?(?:const|var)\s+(\w+)\s*(?::\s*[\w\[\]]+)?\s*:?=\s*"
    r"(?:[\w.]+\s*\+\s*)?[\"'][^\"']*[\"']\s*(?:#.*)?$"
)
CONCAT = re.compile(r"\s*\+\s*(?:\"((?:[^\"\\\n]|\\.)*)\"|'((?:[^'\\\n]|\\.)*)')")
# Fallback when export_presets.cfg has no include_filter yet.
BASE_INCLUDE = ["demo/*.json"]


@dataclass
class Audit:
    files: dict[str, int]  # every exportable file in the audited trees -> bytes
    used: set[str] = field(default_factory=set)
    why: dict[str, str] = field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)

    def keep(self, rel: str, reason: str) -> bool:
        if rel in self.files and rel not in self.used:
            self.used.add(rel)
            self.why[rel] = reason
            return True
        return False


def tree_files() -> dict[str, int]:
    """Pack files Godot would put in the pck: imported assets and text resources."""
    out: dict[str, int] = {}
    for tree in TREES:
        for path in sorted((GAME / tree).rglob("*")):
            if not path.is_file() or path.suffix == ".import":
                continue
            rel = path.relative_to(GAME).as_posix()
            imported = path.with_name(path.name + ".import").exists()
            if imported or path.suffix in ASSET_SUFFIXES:
                out[rel] = path.stat().st_size
    return out


def pack_names() -> list[str]:
    names = []
    for tree in TREES:
        names += [p.name for p in (GAME / tree).iterdir() if p.is_dir()]
    return sorted(set(names), key=len, reverse=True)


def sources() -> list[tuple[str, Path]]:
    """Every text file that can name a pack file at run time."""
    out: list[tuple[str, Path]] = []
    for path in sorted(GAME.rglob("*")):
        rel = path.relative_to(GAME).as_posix()
        if not path.is_file() or path.suffix not in SCAN_SUFFIXES or NOT_SHIPPED.match(rel):
            continue
        if any(rel.startswith(t + "/") for t in TREES):
            continue  # pack files count only once something kept points at them
        out.append((f"game/{rel}", path))
    for path in sorted((ROOT / "content").rglob("*.json")):
        out.append((path.relative_to(ROOT).as_posix(), path))
    for path in sorted((ROOT / "backend").rglob("*.py")):
        rel = path.relative_to(ROOT)
        if "tests" in rel.parts or rel.name.startswith("test_") or rel.name == "conftest.py":
            continue
        out.append((rel.as_posix(), path))
    return out


def literals(text: str) -> list[str]:
    found = []
    for m in STRING.finditer(text):
        s = m.group(1) if m.group(1) is not None else m.group(2)
        found.append(s.replace('\\"', '"').replace("\\'", "'").replace("\\\\", "\\"))
    return found


def to_regex(s: str) -> re.Pattern[str] | None:
    """A format string as a regex over file paths, or None if it has no placeholders."""
    parts, last, has = [], 0, False
    for m in FORMAT.finditer(s):
        parts.append(re.escape(s[last : m.start()]))
        last = m.end()
        tok = m.group(0)
        if tok == "%%":
            parts.append("%")
            continue
        has = True
        kind = m.group(2) or "s"
        if kind == "d" or kind == "i":
            parts.append(r"-?\d+")
        elif kind in "xX":
            parts.append(r"[0-9a-fA-F]+")
        elif kind == "f":
            parts.append(r"-?[0-9.]+")
        else:  # %s, %c, {name}: anything, folders included
            parts.append(r".*")
    parts.append(re.escape(s[last:]))
    return re.compile("".join(parts) + "$") if has else None


def normalize(s: str, packs: list[str]) -> str | None:
    """A literal as a path relative to game/, if it points into a pack tree."""
    s = s.strip()
    if s.startswith("res://"):
        s = s[len("res://") :]
    for tree in TREES:
        if s.startswith(tree + "/"):
            return s
    for name in packs:
        if s.startswith(name + "/"):
            tree = next(t for t in TREES if (GAME / t / name).is_dir())
            return f"{tree}/{s}"
    return None


def folder_tails(line: str, scripts: dict[str, str]) -> list[str] | None:
    """For `const NAME := "pack/folder/"`, the literals every use of NAME appends to it.

    None unless the line defines a constant and every use anywhere in the shipped
    scripts is NAME + "literal"; then the folder doesn't have to ship whole.
    """
    m = CONST_DEF.match(line)
    if not m:
        return None
    name = m.group(1)
    uses = re.compile(rf"(?<![\w])(?:\w+\.)?{name}\b")
    out: list[str] = []
    for text in scripts.values():
        for u in uses.finditer(text):
            line_start = text.rfind("\n", 0, u.start()) + 1
            if CONST_DEF.match(text[line_start : text.find("\n", u.start())]):
                if text[line_start : u.start()].strip().endswith(("const", "var")):
                    continue  # a definition, not a use
            tail = CONCAT.match(text, u.end())
            if not tail:
                return None
            out.append(tail.group(1) if tail.group(1) is not None else tail.group(2))
    return out or None


def keep_path(audit: Audit, names: list[str], rel: str, where: str, s: str) -> bool:
    """Keep what one pack path names: a file, a format pattern, or a folder/prefix."""
    rx = to_regex(rel)
    if rx is not None:
        hits = [n for n in names if rx.match(n)]
        for n in hits:
            audit.keep(n, f"{where}: pattern {s!r}")
        return bool(hits)
    if rel in audit.files:
        audit.keep(rel, f"{where}: {s!r}")
        return True
    if (GAME / rel).is_file():
        return True  # a license or other file Godot doesn't export as a resource
    hits = [n for n in names if n.startswith(rel)]
    for n in hits:
        audit.keep(n, f"{where}: prefix {s!r}")
    return bool(hits)


def scan_literal(
    audit: Audit,
    names: list[str],
    packs: list[str],
    tails: list[tuple[str, str]],
    where: str,
    path: Path,
    line: str,
    s: str,
    scripts: dict[str, str],
) -> None:
    rel = normalize(s, packs)
    if rel is None:
        bare = s.strip()
        if bare in packs and not where.endswith("credits.json"):
            audit.warnings.append(f"{where}: bare pack name {s!r} (pack kept whole)")
            tree = next(t for t in TREES if (GAME / t / bare).is_dir())
            keep_path(audit, names, f"{tree}/{bare}/", where, s)
        elif path.suffix in (".gd", ".tscn", ".tres") and Path(s).suffix.lower() in ASSET_SUFFIXES:
            tails.append((where, s))
        return
    if rel.rstrip("/") in TREES:
        return  # the packs folder itself: a base for other literals
    is_folder = to_regex(rel) is None and rel not in audit.files and not (GAME / rel).is_file()
    if is_folder and path.suffix == ".gd":
        appended = folder_tails(line, scripts)
        if appended is not None and all(
            keep_path(audit, names, rel + t, where, s + " + " + repr(t)) for t in appended
        ):
            return
    if not keep_path(audit, names, rel, where, s):
        audit.warnings.append(f"{where}: {s!r} names no pack file")


def run() -> Audit:
    audit = Audit(tree_files())
    packs = pack_names()
    names = sorted(audit.files)
    tails: list[tuple[str, str]] = []
    all_sources = sources()
    scripts = {w: p.read_text(errors="replace") for w, p in all_sources if p.suffix == ".gd"}

    for where, path in all_sources:
        text = path.read_text(errors="replace")
        for line in text.splitlines():
            for s in literals(line):
                scan_literal(audit, names, packs, tails, where, path, line, s, scripts)

    # Tails like "coin_05a.png" or "Cat/SpriteSheet.png" joined to a folder constant.
    for where, s in tails:
        rx = to_regex(s)
        if rx is not None:
            body = rx.pattern.removesuffix("$")
            tail_rx = re.compile(r"(^|.*/)" + body + "$")
            hits = [n for n in names if tail_rx.match(n)]
        else:
            hits = [n for n in names if n == s or n.endswith("/" + s)]
        if hits and not any(n in audit.used for n in hits):
            for n in hits:
                audit.keep(n, f"{where}: tail {s!r}")

    # Kept scenes and resources pull in what they reference.
    todo = [n for n in audit.used if n.endswith((".tres", ".tscn"))]
    while todo:
        n = todo.pop()
        for ref in EXT_RESOURCE.findall((GAME / n).read_text(errors="replace")):
            rel = ref[len("res://") :]
            if audit.keep(rel, f"referenced by {n}") and rel.endswith((".tres", ".tscn")):
                todo.append(rel)
    return audit


def exclude_globs(audit: Audit, also_keep: list[str]) -> list[str]:
    """Few globs that drop every unused file and nothing kept.

    Godot matches export filters case-insensitively and lets * cross folders, so a
    glob "folder/abc*" is safe when no kept file or kept folder in "folder" starts
    with "abc" in any case. Each dropped file gets the shortest such prefix.
    """
    kept_children: dict[str, set[str]] = {}
    for n in set(audit.used) | set(also_keep):
        parts = n.lower().split("/")
        for i in range(1, len(parts)):
            kept_children.setdefault("/".join(parts[:i]), set()).add(parts[i])
    out: list[str] = []
    seen: set[str] = set()
    for n in sorted(set(audit.files) - audit.used - set(also_keep)):
        parts = n.split("/")
        glob = n
        for i in range(2, len(parts)):
            folder = "/".join(parts[:i])
            kept = kept_children.get(folder.lower(), set())
            name = parts[i]
            k = next(
                (
                    k
                    for k in range(1, len(name) + 1)
                    if not any(c.startswith(name[:k].lower()) for c in kept)
                ),
                None,
            )
            if k is not None:
                glob = f"{folder}/{name[:k]}*"
                break
        if glob not in seen:
            seen.add(glob)
            out.append(glob)
    return out


def license_globs(audit: Audit) -> list[str]:
    """License, credit and readme files: the trees' own and every shipping pack's."""
    out = []
    for tree in TREES:
        for path in sorted((GAME / tree).iterdir()):
            if path.is_file() and LICENSE_NAME.search(path.name) and path.suffix != ".import":
                out.append(path.relative_to(GAME).as_posix())
    shipped = {"/".join(n.split("/")[:3]) for n in audit.used}
    for pack in sorted(shipped):
        for path in sorted((GAME / pack).rglob("*")):
            if path.is_file() and LICENSE_NAME.search(path.name) and path.suffix != ".import":
                out.append(path.relative_to(GAME).as_posix())
    return out


def bad_glob(g: str) -> bool:
    return any(c in g for c in ',"\\') or g != g.strip()


def preset_field(text: str, key: str) -> re.Match[str] | None:
    """A quoted value in export_presets.cfg; generated values span many lines."""
    return re.search(rf'^{key}="((?:[^"\\]|\\.)*)"', text, re.M)


def preset_values(audit: Audit) -> dict[str, list[str]]:
    text = PRESET.read_text()
    old = {}
    for key in ("include_filter", "exclude_filter"):
        m = preset_field(text, key)
        old[key] = [f.strip() for f in (m.group(1) if m else "").split(",")]
    # Keep the hand-written entries, replace the generated ones.
    gen = tuple(f"{t}/" for t in TREES)
    include = [f for f in old["include_filter"] if f and not f.startswith(gen)] or BASE_INCLUDE
    exclude = [f for f in old["exclude_filter"] if f and not f.startswith(gen)]
    lic = license_globs(audit)
    globs = exclude_globs(audit, lic)
    for g in globs + lic:
        if bad_glob(g):
            raise SystemExit(f"can't put {g!r} in an export filter; rename the file")
    return {"include_filter": include + lic, "exclude_filter": exclude + globs}


def render(values: list[str]) -> str:
    # One entry per line keeps diffs readable; Godot splits on commas and trims.
    return ",\n".join(values)


def preset_stale(values: dict[str, list[str]]) -> list[str]:
    text = PRESET.read_text()
    stale = []
    for key, want in values.items():
        m = preset_field(text, key)
        have = [f.strip() for f in m.group(1).split(",")] if m else []
        if [f for f in have if f] != want:
            stale.append(key)
    return stale


def write_preset(values: dict[str, list[str]]) -> bool:
    """Write the filters into the Web preset. True if the file changed."""
    if not preset_stale(values):
        return False
    text = PRESET.read_text()
    for key, want in values.items():
        m = preset_field(text, key)
        line = f'{key}="{render(want)}"'
        text = text[: m.start()] + line + text[m.end() :] if m else text
    PRESET.write_text(text)
    return True


def mb(n: int) -> str:
    return f"{n / 1e6:.1f} MB"


def report(audit: Audit) -> None:
    total = sum(audit.files.values())
    kept = sum(audit.files[n] for n in audit.used)
    print(f"pack files: {len(audit.files)} ({mb(total)}); kept {len(audit.used)} ({mb(kept)})")
    by_pack: dict[str, list[int]] = {}
    for n, size in audit.files.items():
        pack = "/".join(n.split("/")[:3])
        row = by_pack.setdefault(pack, [0, 0])
        row[0] += size
        if n in audit.used:
            row[1] += size
    print(f"\n{'pack':48} {'kept':>10} {'of':>10}")
    for pack, (all_, k) in sorted(by_pack.items(), key=lambda kv: -kv[1][1]):
        print(f"{pack.split('/', 2)[2]:48} {k:>10,} {all_:>10,}")
    print("\nbiggest kept files:")
    for n in sorted(audit.used, key=lambda n: -audit.files[n])[:15]:
        print(f"  {audit.files[n]:>10,}  {n}\n              <- {audit.why[n]}")
    if audit.warnings:
        print("\nwarnings:")
        for w in audit.warnings:
            print("  " + w)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="update game/export_presets.cfg")
    ap.add_argument("--check", action="store_true", help="fail if the preset is out of date")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()
    audit = run()
    if not args.quiet:
        report(audit)
    values = preset_values(audit)
    if args.check:
        stale = preset_stale(values)
        if stale:
            print(f"export_presets.cfg is out of date ({', '.join(stale)}); run --write")
            sys.exit(1)
    elif args.write:
        changed = write_preset(values)
        print("export_presets.cfg " + ("updated" if changed else "already up to date"))


if __name__ == "__main__":
    main()
