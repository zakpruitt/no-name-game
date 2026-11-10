#!/usr/bin/env python3
"""Meshy characters into the game, one command each. See docs/features/meshy-foes.md.

    python tools/meshy/meshy.py build <kind>            # tools/meshy/foes/<kind>/ -> assets/comic/<kind>.glb
    python tools/meshy/meshy.py build <kind> --raw --stills=12   # stills of the whole library clips, no GLB:
                                                        # read the seconds for `start` / `end` off them
    python tools/meshy/meshy.py library <clips.glb>...  # add Meshy animation files to the shared clip library
    python tools/meshy/meshy.py clips                   # list the library and what the game clips map to

`build` reads tools/meshy/foes/<kind>/foe.json and rigged.glb (Meshy's auto-rig download), puts the
shared clips on it, writes the GLB, a sheet of stills (tools/meshy/out/<kind>_sheet.png) and prints
the numbers for the kind's row in scripts/enemy_types.gd. Then run `godot --headless --import --path .`.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LIB = os.path.join(HERE, "library")
OUT = os.path.join(HERE, "out")
BLENDERS = [
    os.environ.get("BLENDER", ""),
    r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    "blender",
]
ATTACK_CLIP_FPS = 24.0  # scripts/enemy.gd: `attack_hit` is a frame at this rate
BAR_GAP = 0.3  # m over the head top for the health bar (scripts/enemy_types.gd `bar_height`)


def blender(*args):
    exe = next(b for b in BLENDERS if b and (os.path.isfile(b) or b == "blender"))
    script = os.path.join(HERE, "blend_meshy.py")
    run = subprocess.run([exe, "-b", "--python-exit-code", "1", "--python", script, "--", *args],
                         capture_output=True, text=True)
    lines = [ln for ln in run.stdout.splitlines() if ln.startswith(("CLIP", "BUILT"))]
    if run.returncode != 0 or not lines:
        sys.stdout.write(run.stdout[-4000:])
        sys.stderr.write(run.stderr[-4000:])
        raise SystemExit("blender failed")
    return lines


def load_map():
    with open(os.path.join(HERE, "clips.json")) as f:
        return json.load(f)


def cmd_library(files):
    for ln in blender("library", LIB, *[os.path.abspath(f) for f in files]):
        print(ln)


def cmd_clips():
    have = sorted(f[:-5] for f in os.listdir(LIB) if f.endswith(".json"))
    print("library (%d): %s" % (len(have), ", ".join(have)))
    for clip, spec in load_map()["clips"].items():
        print("  %-26s <- %s%s" % (clip, spec["from"], "" if spec["from"] in have else "   MISSING"))


def cmd_build(kind, stills=5, raw=False):
    src = os.path.join(HERE, "foes", kind)
    with open(os.path.join(src, "foe.json")) as f:
        foe = json.load(f)
    table = load_map()
    clips = {}
    for clip, spec in table["clips"].items():
        spec = dict(spec)
        spec.update(foe.get("clips", {}).get(clip, {}))
        if raw:  # the whole library clip, untrimmed and unretimed, to choose trims from
            spec = {k: v for k, v in spec.items() if k not in ("start", "end", "seconds", "hit")}
        if clip in foe.get("skip", []):
            continue
        spec["file"] = os.path.join(LIB, spec["from"] + ".json")
        if not os.path.isfile(spec["file"]):
            raise SystemExit("clip %s wants %s, which is not in the library (meshy.py clips)" % (clip, spec["from"]))
        clips[clip] = spec
    os.makedirs(OUT, exist_ok=True)
    sheet_dir = os.path.join(OUT, kind + "_stills")
    job = {
        "kind": kind,
        "rig": os.path.join(src, "rigged.glb"),
        "height": foe["height"],
        "material": foe.get("material", table["material"]),
        "clips": clips,
        "out": os.path.join(ROOT, "assets", "comic", kind + ".glb"),
        "report": os.path.join(OUT, kind + "_report.json"),
        "sheet_dir": sheet_dir,
        "stills": stills,
    }
    if raw:
        job["out"] = os.path.join(OUT, kind + "_raw.glb")
    job_path = os.path.join(OUT, kind + "_job.json")
    with open(job_path, "w") as f:
        json.dump(job, f, indent=1)
    blender("build", job_path)
    with open(job["report"]) as f:
        rep = json.load(f)
    sheet = contact_sheet(kind, sheet_dir, list(clips), stills)
    print("%s: %d tris, %.2f m, %d clips, %d KB -> assets/comic/%s.glb" % (
        kind, rep["tris"], rep["height"], len(rep["clips"]), rep["bytes"] // 1024, kind))
    for clip, info in rep["clips"].items():
        hit = "  hit %.2f s" % info["hit_seconds"] if "hit_seconds" in info else ""
        print("  %-26s %-28s %5.2f s%s" % (clip, info["from"], info["seconds"], hit))
    row = ['"bar_height": %.2f' % (rep.get("head_top", rep["height"]) + BAR_GAP)]
    chop = rep["clips"].get("1H_Melee_Attack_Chop", {})
    if "hit_seconds" in chop:
        row.append('"attack_hit": %.1f' % (chop["hit_seconds"] * ATTACK_CLIP_FPS))
    print("enemy_types.gd row values: " + ", ".join(row))
    print("run_foot_speed: add the row with 0.0, import, then tests/foe_stride_check.gd prints the number to copy")
    if sheet:
        print("stills: " + sheet)


def contact_sheet(kind, sheet_dir, clips, stills):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return sheet_dir
    cell = 360
    sheet = Image.new("RGB", (cell * stills, (cell + 22) * len(clips)), (20, 18, 34))
    draw = ImageDraw.Draw(sheet)
    for r, clip in enumerate(clips):
        draw.text((6, r * (cell + 22) + 4), clip, fill=(255, 255, 255))
        for s in range(stills):
            p = os.path.join(sheet_dir, "%s_%d.png" % (clip, s))
            if os.path.isfile(p):
                sheet.paste(Image.open(p).convert("RGB"), (s * cell, r * (cell + 22) + 22))
    out = os.path.join(OUT, kind + "_sheet.png")
    sheet.save(out)
    return out


def main():
    args = sys.argv[1:]
    stills = next((int(a.split("=")[1]) for a in args if a.startswith("--stills=")), 5)
    raw = "--raw" in args
    args = [a for a in args if not a.startswith("--")]
    if len(args) >= 2 and args[0] == "build":
        for kind in args[1:]:
            cmd_build(kind, stills, raw)
    elif len(args) >= 2 and args[0] == "library":
        cmd_library(args[1:])
    elif args == ["clips"]:
        cmd_clips()
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
