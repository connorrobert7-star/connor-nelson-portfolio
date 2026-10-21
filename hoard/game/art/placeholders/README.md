# Placeholders for manual-download packs

Some packs Hoard builds against can't be committed to this public repo, because their
licenses forbid redistribution or commercial use. Each one gets a folder here, with
stand-ins that use the real pack's file names, image sizes and frame layout.

    python tools/art/placeholders.py            # write the stand-ins (run once after cloning)
    python tools/art/placeholders.py --status   # which files are still stand-ins

The layout comes from `tools/art/placeholder_specs.json`. Every folder's README.md (written by
the script) links the pack and says which files to copy in. Download the pack, copy its
files over the stand-ins with the same names, and reopen Godot. The script never overwrites
a real file: stand-in PNGs carry a `hoard-placeholder` text chunk and anything without it
counts as real.

Everything in this folder except this README and `.gitignore` is git-ignored, so the real
files stay on your machine. The full list, with links and licenses, is in docs/ASSETS.md.
