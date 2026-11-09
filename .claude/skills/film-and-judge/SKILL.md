---
name: film-and-judge
description: Judge Awaken's combat feel or look from film and sheets rather than guesses: `tests/string_film.gd` (every bot string at 12 fps with HIT frames), `tests/element_shots.gd`, `tests/foe_shots.gd`, `tests/heretic_shots.gd`, `python tests/fx_coverage.py` and contact sheets, plus the headless probes that give the number before a film does. Use when asked to audit feel, judge an effect or model "on screen", film a before/after, read a `[rhythm]` beat, or when a windowed run is needed and Zak has allowed one.
---

# Film and judge

Windowed Godot steals focus: only open it when Zak has said so. Until then read the autotest's `[rhythm]` lines
(headless) and probe with a scratch SceneTree; the film is for before / after. Hold the land lock
(`../land.lock`, see `land-worktree`) through any windowed run, and wait on it before starting one.

## Filming
- `timeout 300 godot --path . -s tests/string_film.gd -- --dir=<lane>_before` films every `BOT_STRINGS` string at
  12 fps from the game camera into `user://<lane>_before/<string>/NNN.png` + INDEX.txt (real ms, move, hits done,
  `Engine.time_scale`), with a frame marked HIT the first drawn frame after each hit or slam. `--from=N --to=N` films
  a range (~40 s a string), `--spar=<kind>` with a live foe, `--tail=MS` the after-beat, `--room=<name> --showcase`
  a room's set pieces. **Always your own `--dir=`**: `user://` is shared by every worktree, so copy the folder to
  your scratchpad at once (other lanes' runs overwrite it, and a TaskStop'd shell leaves its Godot writing).
- A film can stop early (`strings=4/19` on a busy machine) and still print `done`: count the folders. Folders keep
  stale higher-numbered frames from longer runs: build sheets from the frames INDEX.txt lists.
- One move / effect: `tests/element_shots.gd -- --only=<combo>` (~20 s), `tests/improv_shots.gd --alone --dir=`,
  or a scratch SceneTree (`tests/_<lane>_shots.gd`, never committed) that loads `main.tscn`, spawns the effect by
  `get_nodes_in_group("enemies")` and saves 6-8 frames 83 ms apart: a 4x2 sheet in 15 s. Stub a suspect effect with
  an early `return` and reshoot to learn which effect is the clutter. Take the others out of the `"enemies"` group to
  film one foe in a crowd.
- Models: `heretic_shots.gd -- --clips --clips-step=0.0333 --clips-only=Ab_L1,Ab_L3` films a clip frame by frame
  (unknown names are skipped silently: count files per clip); `foe_shots.gd -- --clip=run --frames=6 --only=a,b`
  films foes at the game camera (`--only=<one>` zooms closer than `--only=<three>`: keep the same set for before /
  after). Set `rig._blink_t = -100` before a face shot or every deterministic run catches the same blink.
- Before / after of a model: `git checkout <base> -- <glb> <scripts>`, `godot --headless --import --path .`, shoot
  into a tag, `git checkout HEAD -- ...`, `--import` again; a regenerated sheet or swapped GLB is not in the game until
  imported (an unimported sheet draws as a solid cream square, no error).
- HUD text: `string_film` frames are 800x450 (half size); set its `SIZE` to the window for a text judgement, film
  into your `--dir`, then restore the test.

## Reading
- **HIT frames are the blow**; contact holds almost never land on a 12 fps beat. Read `time_scale` on the label:
  x0.03 is a freeze, x0.6 the breaker focus, x0.05 a slam; a HIT at x1.00 is a whiff, not a missing stop.
  Compare HIT frames by move and time scale, never by frame number (the first string stutters on shader compiles).
- **Contact sheets first.** A 30-line PIL script tiling each string's HIT frames plus every third frame at
  400x225, labelled from INDEX.txt, gives one image per string; read for what repeats across sheets (same landing,
  same star colour, a counter that never drops): that is the design's weakness, not one move's.
- **Zoom before judging the hero** (crop the middle 60% at 600 px); judge breaker beats that use the room on the
  full sheet. Read the next string's first second too: carry-over effects (a 5 s frost spear) are most of the clutter,
  and a `--from=N` film misses N-1's carry-over.
- Read the `scale=` column down a hang before judging its effects (per-pulse freezes alternate x0.03 / x1.0). Words
  with no attack on screen mean a standing source is hitting (`hits=` while he stands). The bot presses Awaken the
  frame the meter fills, often on a perfect landing: read the Awakening column as its own layer.
- Take `[rhythm]` from a headless `--autotest`, never from a film's frame times (L3 -> EM 840 ms filmed vs 541
  headless). Judge a hero's look in the play camera's film, not close-ups (the camera sees the top and back of the hood).
- `grep -c ERROR` every film log: spar and windowed films catch engine errors no check covers.
- Density has a number: `python tests/fx_coverage.py <film dir> --per-string --max=0.40` scores each HIT frame's
  effect-coloured share; quote per-string numbers, and compare landings with and without the Awakening column.

## Probe before you film
A scratch `-s` SceneTree that instances main, drives the bot (`_bot_string = N`) or `Input.action_press`es a plan,
sets the root to `Vector2i(1920, 1080)` (headless honours it) and prints a field every few physics frames (the rig's
`_frame` / `_frame_to`, the worst foe's NDC, hero height, each foe's y / frozen / airborne, `lean`, `speed_scale`)
gives the number in one 20 s run. Measure screen size with a 1920x1080 `SubViewport` (the headless root is 64x64).
Count what you judge (a `rings=N` column in a scratch copy of string_film) so "still reads as circles" becomes a number.
