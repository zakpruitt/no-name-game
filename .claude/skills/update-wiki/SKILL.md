---
name: update-wiki
description: Refresh the Awaken wiki in docs/wiki/ (index.html + generated data.js + notes.js + screenshots) after game changes. Use when asked to update, refresh or rebuild the wiki/field guide, when a feature, move, enemy, power, twist or menu was added or changed, or at the end of a roadmap round.
---

# Update the wiki

The wiki is `docs/wiki/index.html`. Open it in a browser straight from disk; it needs no server.

| File | Contents | Who writes it |
|---|---|---|
| `data.js` | Every number. | **Generated** by `tools/wiki_data.gd` from the game's tuning tables. Never edit by hand. |
| `notes.js` | What things *do*: move/enemy/boss-attack/twist notes keyed by game id, plus the "Screens to review" list. | Hand-written, strict JSON after `window.NOTES =`. |
| `index.html` | Prose sections and the renderer. | Hand-written. Tables are built in JS from the two files above. |
| `img/*.jpg` | 960px screenshots. | `python tools/wiki.py --shots`. |

`docs/.gdignore` keeps Godot from importing any of this.

## Steps

1. **Regenerate the data.** Run `python tools/wiki.py` from the repo root, which takes about 10s.
   - The output lists ids that have no note (`needs notes ...`) and notes whose ids no longer exist. Fix both in `notes.js`.
   - A missing note also shows on the page as a red *needs a note*.
2. **Re-capture screenshots** if anything visual changed: `python tools/wiki.py --shots`, about 4 minutes, windowed.
   - It runs the autotest variants in `SHOTS` and converts the PNGs from `%APPDATA%/Godot/app_userdata/Awaken/` into `img/`. It never touches save data.
   - `missing or stale: X` means that run didn't produce shot X. Find which run does (see CLAUDE.md's autotest flags) and fix `SHOTS`. Don't ignore it.
   - Look at the new images before committing.
3. **Fix the prose.** If a mechanic was added or changed in a way the tables don't cover (a new room kind, menu, control, flag or system), edit the matching section in `index.html`.
   - Prefer pulling numbers from `D.*` in the render script over typing them into prose, so they can't go stale.
   - New tuning tables the wiki should show: export them in `tools/wiki_data.gd`, then render them in `index.html`.
4. **Screens to review.** For a notable new visual:
   - add a `screens` entry in `notes.js` (`img` = the user:// PNG name without the extension);
   - add its run to `SHOTS` in `tools/wiki.py`;
   - drop review questions that have been answered.
5. **Check the render.** Screenshot the page with headless Edge and look at it:
   `"/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" --headless=new --disable-gpu --window-size=1280,7000 --virtual-time-budget=4000 --screenshot=<scratchpad>/wiki.png "file:///C:/Users/pruit/Desktop/dev/awaken/docs/wiki/index.html"`
   Crop it with ffmpeg into readable chunks.
6. **Commit** on `dev`: `docs: update wiki` (or fold it into the feature's commit). No Co-Authored-By or "Generated with" trailers. Never push.

## Gotchas
- `data.js` records the commit it was built from. Regenerate after committing game changes, not before, or the header shows the previous commit.
- Godot prints leak warnings at exit from `wiki_data.gd`; `wiki.py` filters them. A real `SCRIPT ERROR` is printed and must be fixed.
- `notes.js` must stay strict JSON (double quotes, no trailing commas, no comments inside the object), or `wiki.py` fails to parse it.
