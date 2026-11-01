"""Dump the Godot class reference for the installed engine into docs/engine_api/.

Runs `godot --doctool` into a temp dir and flattens it so every class is
docs/engine_api/<ClassName>.xml (core, modules like GDScript/CSG/GridMap, and
platform singletons alike). Rerun after upgrading Godot.

    python tools/gen_engine_api.py [godot_exe]
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "engine_api"


def main() -> None:
    godot = sys.argv[1] if len(sys.argv) > 1 else "godot"
    version = subprocess.run([godot, "--version"], capture_output=True, text=True, check=True).stdout.strip()
    with tempfile.TemporaryDirectory() as tmp:
        # Run outside the project so only engine classes are dumped.
        subprocess.run([godot, "--headless", "--doctool", tmp], cwd=tmp, check=True)
        files = sorted(Path(tmp).rglob("*.xml"))
        names = [f.name for f in files]
        dupes = {n for n in names if names.count(n) > 1}
        if dupes:
            sys.exit(f"duplicate class files, cannot flatten: {sorted(dupes)}")
        if OUT.exists():
            shutil.rmtree(OUT)
        OUT.mkdir(parents=True)
        for f in files:
            shutil.copy2(f, OUT / f.name)
    (OUT / ".gdignore").write_text("")
    (OUT / "VERSION").write_text(version + "\n")
    print(f"{len(files)} classes -> {OUT.relative_to(ROOT)} (Godot {version})")


if __name__ == "__main__":
    main()
