"""Rebuild the wiki in docs/wiki/.

    python tools/wiki.py           export the tuning tables (data.js) and check notes
    python tools/wiki.py --shots   also re-capture screenshots into docs/wiki/img/

Screenshots come from the autotest and test scripts (they never touch save
data); each run in SHOTS is windowed and takes ~20s. Open docs/wiki/index.html
in a browser to read the result.
"""
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIKI = os.path.join(ROOT, "docs", "wiki")
USER = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Awaken")
NOISE = ("RID", "PagedAllocator", "Leaked instance", "instance_notify", "utilities.cpp",
         "ObjectDB instances", "resources still in use", "at: cleanup", "at: clear")

# Godot runs for --shots: (arguments after --path ., screenshots it should produce).
SHOTS = [
    (["--", "--autotest"], ["autotest_callout", "autotest_reward", "autotest_summary", "autotest_slam"]),
    (["--", "--autotest", "--start-awakened"], ["autotest_finisher"]),
    (["--", "--autotest", "--start-awakened", "--ascend=earth"], ["autotest_trinity"]),
    (["--", "--autotest", "--upgrades=shatter,quake", "--start-room=3"], ["autotest_shatter"]),
    (["--", "--autotest", "--start-room=3", "--twist=splitting"], ["autotest_split"]),
    (["--", "--autotest", "--start-room=8", "--boss-enraged"], ["autotest_spikes"]),
    (["--", "--autotest", "--start-room=8", "--boss-enraged", "--boss-attack=cage"], ["autotest_cage"]),
    (["--", "--autotest", "--start-rest"], ["autotest_camp"]),
    (["--", "--autotest", "--start-shrine"], ["autotest_shrine_room"]),
    (["-s", "tests/menu_check.gd"], ["menu_title", "menu_path", "menu_pause", "menu_altar"]),
    (["-s", "tests/enemy_lineup.gd"], ["enemy_lineup"]),
    (["--", "--autotest", "--level=6"], ["autotest_ascend"]),
    (["-s", "tests/hero_preview.gd"], ["hero_preview"]),
    (["-s", "tests/element_preview.gd"], ["element_sheet", "element_ult_sheet"]),
    (["--", "--autotest", "--start-awakened", "--ascend=wind"], ["autotest_ult", "autotest_cast"]),
]


def godot(args, headless=False):
    cmd = ["godot"] + (["--headless"] if headless else []) + ["--path", ROOT] + args
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=240, encoding="utf-8", errors="replace")
    lines = [l for l in (out.stdout + out.stderr).splitlines() if l.strip() and not any(n in l for n in NOISE)]
    errors = [l for l in lines if "ERROR" in l or "SCRIPT" in l]
    return lines, errors


def load_js(name, var):
    s = open(os.path.join(WIKI, name), encoding="utf-8").read()
    s = s[s.rindex("window.%s =" % var) + len("window.%s =" % var):].strip().rstrip(";")
    return json.loads(s)


def check_notes():
    data, notes = load_js("data.js", "WIKI"), load_js("notes.js", "NOTES")
    missing = []
    for m in data["moves"]:
        if m not in notes["moves"]:
            missing.append("moves." + m)
    for section, ids in (("enemies", data["enemies"]), ("boss_attacks", data["boss"]["attacks"]),
                         ("twists", data["twists"]), ("ascendancy", data["ascendancy"])):
        missing += ["%s.%s" % (section, i) for i in ids if i not in notes[section]]
    stale = [i for i in notes["moves"] if i not in data["moves"]]
    for s in notes["screens"]:
        if not os.path.exists(os.path.join(WIKI, "img", s["img"] + ".jpg")):
            missing.append("img/%s.jpg (screens)" % s["img"])
    if missing:
        print("[wiki] needs notes (docs/wiki/notes.js):", ", ".join(missing))
    if stale:
        print("[wiki] notes for ids no longer in the game:", ", ".join(stale))
    if not missing and not stale:
        print("[wiki] notes cover every id")


def shots():
    ffmpeg = shutil.which("ffmpeg") or r"C:\ffmpeg\bin\ffmpeg.exe"
    os.makedirs(os.path.join(WIKI, "img"), exist_ok=True)
    for args, names in SHOTS:
        start = time.time()
        print("[wiki] godot", " ".join(args))
        _, errors = godot(args)
        for e in errors:
            print("   ", e)
        for n in names:
            src = os.path.join(USER, n + ".png")
            if not os.path.exists(src) or os.path.getmtime(src) < start:
                print("    missing or stale:", n)
                continue
            dst = os.path.join(WIKI, "img", n + ".jpg")
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", src, "-vf", "scale=960:-2", "-q:v", "4", dst], check=True)


def main():
    lines, errors = godot(["-s", "tools/wiki_data.gd"], headless=True)
    print("\n".join(l for l in lines if l.startswith("[wiki]")))
    for e in errors:
        print("   ", e)
    if "--shots" in sys.argv:
        shots()
    check_notes()
    print("[wiki] open", os.path.join(WIKI, "index.html"))


if __name__ == "__main__":
    main()
