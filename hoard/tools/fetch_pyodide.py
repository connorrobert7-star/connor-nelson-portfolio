"""Download the Pyodide 0.26.4 runtime the browser demo needs into a folder.

    python tools/fetch_pyodide.py /path/to/pyodide-dir

Fetches pyodide-core from the GitHub release, then pulls sqlite3-1.0.0.zip out of
the full release (about 300 MB streamed, only that one file is kept).
"""

import io
import sys
import tarfile
import urllib.request
from pathlib import Path

RELEASE = "https://github.com/pyodide/pyodide/releases/download/0.26.4"
CORE = [
    "pyodide.js",
    "pyodide.asm.js",
    "pyodide.asm.wasm",
    "python_stdlib.zip",
    "pyodide-lock.json",
]


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(f"{RELEASE}/pyodide-core-0.26.4.tar.bz2") as r:
        with tarfile.open(fileobj=io.BytesIO(r.read()), mode="r:bz2") as tar:
            for name in CORE:
                (out / name).write_bytes(tar.extractfile(f"pyodide/{name}").read())
    with urllib.request.urlopen(f"{RELEASE}/pyodide-0.26.4.tar.bz2") as r:
        with tarfile.open(fileobj=r, mode="r|bz2") as tar:
            for member in tar:
                if member.name == "pyodide/sqlite3-1.0.0.zip":
                    (out / "sqlite3-1.0.0.zip").write_bytes(tar.extractfile(member).read())
                    break
    print("\n".join(sorted(p.name for p in out.iterdir())))


if __name__ == "__main__":
    main()
