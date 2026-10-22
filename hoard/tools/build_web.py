"""Build the browser demo: Godot web export + the Python engine under Pyodide.

    python tools/build_web.py --godot GODOT_BINARY --pyodide PYODIDE_DIR [--out export/artifact]

--pyodide is a folder with pyodide.js, pyodide.asm.js, pyodide.asm.wasm,
python_stdlib.zip, pyodide-lock.json and sqlite3-1.0.0.zip (from the
pyodide-core-0.26.4 release plus sqlite3 from the full release).

Output is one page (index.html) plus binaries renamed to .wasm and gzipped,
because the artifact host only serves web file types. web/bridge.js maps the
runtime's requests back onto them.

Before exporting, tools/asset_audit.py rewrites the Web preset's filters so the
pck carries only the art-pack files the game can load (plus their licenses).
"""

import argparse
import gzip
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import asset_audit  # noqa: E402

PART_BYTES = 14 * 1024 * 1024
WEB = ROOT / "web"
GODOT_EXPORT = ROOT / "export" / "web"

INTRO = (
    "<p>A village that runs on your money: your spending grows or rots the crops, "
    "your debts wait at the gate as bosses, your holdings live in the village as "
    "creatures, and the clock in the corner counts down to level 100. "
    "Everything you put in lands in savings or investments, never lost to the game.</p>"
)

# request path suffix -> (published file, gzip it, content type)
BINARIES = {
    "index.wasm": ("engine.gz.wasm", "export:index.wasm", True, "application/wasm"),
    "index.pck": ("game-pck.wasm", "export:index.pck", True, "application/octet-stream"),
    "py/pyodide.asm.wasm": ("py-asm.gz.wasm", "py:pyodide.asm.wasm", True, "application/wasm"),
    "py/python_stdlib.zip": ("py-stdlib.gz.wasm", "py:python_stdlib.zip", True, "application/zip"),
    "py/sqlite3-1.0.0.zip": ("py-sqlite3.gz.wasm", "py:sqlite3-1.0.0.zip", True, "application/zip"),
    "py/pyodide-lock.json": ("py-lock.json", "py:pyodide-lock.json", False, "application/json"),
}


def python_bundle() -> dict[str, str]:
    files: dict[str, str] = {}
    for path in sorted((ROOT / "backend").rglob("*")):
        rel = path.relative_to(ROOT)
        if path.is_dir() or "__pycache__" in rel.parts or "tests" in rel.parts:
            continue
        if rel.name in ("app.py", "conftest.py") or rel.name.startswith("test_"):
            continue
        if path.suffix not in (".py", ".sql"):
            continue
        files[str(rel)] = path.read_text()
    for path in sorted((ROOT / "content").rglob("*.json")):
        files[str(path.relative_to(ROOT))] = path.read_text()
    return files


def inline(js: str) -> str:
    return js.replace("</script", "<\\/script")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", required=True)
    ap.add_argument("--pyodide", required=True, type=Path)
    ap.add_argument("--out", type=Path, default=ROOT / "export" / "artifact")
    ap.add_argument("--skip-export", action="store_true")
    ap.add_argument(
        "--godot-out",
        type=Path,
        default=GODOT_EXPORT,
        help="where Godot writes its export (default export/web)",
    )
    ap.add_argument("--all-assets", action="store_true", help="ship every pack file, untrimmed")
    args = ap.parse_args()
    godot_export: Path = args.godot_out.resolve()

    if not args.skip_export:
        audit = asset_audit.run()
        values = asset_audit.preset_values(audit)
        changed = asset_audit.write_preset(values)
        if args.all_assets:  # this export only; the preset on disk stays trimmed
            untrimmed = dict(values)
            untrimmed["exclude_filter"] = [
                f for f in values["exclude_filter"] if not f.startswith(asset_audit.TREES)
            ]
            asset_audit.write_preset(untrimmed)
        kept = sum(audit.files[n] for n in audit.used)
        print(
            f"art packs: shipping {len(audit.used)} of {len(audit.files)} files "
            f"({kept / 1e6:.1f} of {sum(audit.files.values()) / 1e6:.1f} MB)"
            + ("; export_presets.cfg updated" if changed else "")
        )
        for w in audit.warnings:
            print("  audit: " + w)
        godot_export.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(
            [
                args.godot,
                "--headless",
                "--path",
                str(ROOT / "game"),
                "--export-release",
                "Web",
                str(godot_export / "index.html"),
            ],
            check=False,
        )
        if args.all_assets:
            asset_audit.write_preset(values)
        result.check_returncode()

    out: Path = args.out
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    sources = {"export": godot_export, "py": args.pyodide}
    files = {}
    for suffix, (name, src, gz, ctype) in BINARIES.items():
        where, fname = src.split(":")
        data = (sources[where] / fname).read_bytes()
        blob = gzip.compress(data, 9, mtime=0) if gz else data
        # The host takes binaries up to 15 MB, so big ones ship in parts that
        # web/bridge.js joins back together.
        parts = [blob[i : i + PART_BYTES] for i in range(0, len(blob), PART_BYTES)] or [b""]
        if len(parts) == 1:
            (out / name).write_bytes(blob)
            files[suffix] = {"file": name, "gz": gz, "type": ctype}
            continue
        stem = name.removesuffix(".wasm")
        names = [f"{stem}.{i}.wasm" for i in range(len(parts))]
        for part_name, part in zip(names, parts, strict=True):
            (out / part_name).write_bytes(part)
        files[suffix] = {"parts": names, "gz": gz, "type": ctype}
    shutil.copy(godot_export / "index.audio.worklet.js", out / "index.audio.worklet.js")
    (out / "hoard-py.json").write_text(json.dumps(python_bundle()))

    config = {
        "args": [],
        "canvasResizePolicy": 2,
        "ensureCrossOriginIsolationHeaders": False,
        "executable": "index",
        "experimentalVK": False,
        "fileSizes": {
            "index.pck": (godot_export / "index.pck").stat().st_size,
            "index.wasm": (godot_export / "index.wasm").stat().st_size,
        },
        "focusCanvas": True,
        "gdextensionLibs": [],
    }
    page = (WEB / "shell.html").read_text()
    for marker, value in {
        "<!--INTRO-->": INTRO,
        "/*FILES*/{}": json.dumps(files),
        "/*GODOT_CONFIG*/{}": json.dumps(config),
        "/*PYODIDE_JS*/": inline((args.pyodide / "pyodide.js").read_text()),
        "/*PYODIDE_ASM_JS*/": inline((args.pyodide / "pyodide.asm.js").read_text()),
        "/*BRIDGE_JS*/": inline((WEB / "bridge.js").read_text()),
        "/*GODOT_JS*/": inline((godot_export / "index.js").read_text()),
    }.items():
        assert marker in page, marker
        page = page.replace(marker, value)
    (out / "index.html").write_text(page)
    total = 0
    for f in sorted(out.iterdir()):
        total += f.stat().st_size
        print(f"{f.stat().st_size:>10,}  {f.name}")
    print(f"{total:>10,}  total download ({total / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
