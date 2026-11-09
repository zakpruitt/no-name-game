---
name: godot-headless-test
description: Write, fix or read a headless Godot SceneTree test for Awaken (`tests/*_check.gd`, run with `godot --headless --path . -s tests/<name>.gd`) and diagnose `bash tools/agent.sh check` failures. Covers the `-s` script's relation to the `Game` autoload, asserting "no engine errors", stepping time by hand, proving a test fails on the old value, the stand-in Foe world, timing flakes and the `[autotest] done` counters. Use when adding a PASS/FAIL check, when a check FAILs or prints SCRIPT ERROR, when a test passes with broken code, or when a tuning change needs a regression guard.
---

# Headless tests in Awaken

One test = one Godot boot: `timeout 180 godot --headless --path . -s tests/<name>.gd`. It must print `PASS` and no
`] FAIL` / `: FAIL` / `SCRIPT ERROR`; `agent.sh check` greps exactly that (so use `[name] FAIL ...` lines, not a new
format). `bash tools/agent.sh check` runs its whole list then the autotest twice (~15 min); `check --quick` runs
only the autotest. Never run a check in the background while you keep editing scripts: Godot loads each script
when the run reaches it, so a half-done edit fails the later tests of that run.

## The `-s` script and the `Game` autoload
- A `-s` SceneTree script compiles before the autoloads exist. Never `preload` (or name a `class_name` of) a script
  that mentions `Game`: it fails with "Identifier not found: Game" and floods errors. Reach the autoload with
  `get_root().get_node("Game")` and `load("res://scripts/x.gd")` inside functions, at runtime.
- The same rule makes `godot --check-only -s <script>` useless here: every script that names an autoload fails the
  same way. Find parse errors with the real checks (`guide_check` loads main and every `hero_*.gd` in ~20 s, the
  quickest whole-game compile) and dead names with `python -I tools/dead_refs.py`.
- A parse error in any script the main scene preloads breaks the autoload chain (`void_element.gd` -> `game.gd`):
  every test then fails with "Failed to load script game.gd" and `--autotest` hangs until `timeout`. Warnings are
  errors: `var n := d.get(k, 0)` (a Variant inferred) is such a parse error; type it `var n: int = ...`.
- A `const X := preload(...)` that closes a cycle leaks at exit ("N ObjectDB instances were leaked"); `load()` it in
  the function that needs it. Compare a check's tail against dev before blaming your test.

## Asserting
- **A test must fail on the old value.** Flip the constant back (copy the file aside first: `git checkout <file>`
  also drops your uncommitted edits), run, see FAIL, flip it forward. A sabotage edit that silently matched
  nothing (CRLF: see `windows-patching`) has made a check "pass" on broken code before.
- **Read a game constant without preloading:**
  `load("res://scripts/player.gd").get_script_constant_map().get("NAME", old)`, with the old behaviour as the
  default, fails before the change lands and passes after.
- **"No engine errors":** a `class Catch extends Logger` added with `OS.add_logger`, counting `_log_error` calls.
  Engine errors with no GDScript backtrace reach it too ("Parameter material is null" from a foe freed mid-tween,
  a typed pool array holding a freed node). `fx_free_check` and `rooms_check` have the pattern; run `fx_free_check`
  on every new pooled effect.
- **Step time by hand, not by the wall clock.** Headless, a frame and the engine delta disagree (two frames in one
  ms); a test that drives motion by real time reads phantom overshoots. Turn processing off (`set_process(false)`),
  call `_process(1.0 / 60)` yourself, and check it still fails on an injected fault. Timers run long windowed too.
- `Game` owns `Engine.time_scale` (`_update_hitstop` sets it every frame): to slow the game from a test append a long
  stop (`game._stops.append([now_ms + 120000, 0, 0.06])`) and end it with `game.end_slowmo()`.
- Sample `last_squash` / `last_ink` on foes, not `model.scale` (tweens run on idle frames). Set the fields a guard
  reads (`awakened`, `_state_t`) yourself: headless input is a frame or three late, and the game resets some each tick.
- Bisect a stray error with early `return`s down the test body, one run per marker, not by disabling features.

## The stand-in Foe world
Tests that don't need `main.tscn` build their own floor and spawn a stand-in `class Foe extends CharacterBody3D`
with `_foe()` / `_settle()` / `_until()` / `_wall()` / `_check()` helpers. The reference copy is `tests/void_arm_check.gd`'s
`Foe` (top of the file); copy from there until a shared `tests/support/stand_in.gd` exists, and don't fork its
fields (`last_hit_ms`, `frozen_t`, `is_airborne()` reading y) without a reason. Default facing is +Z (toward the
camera) and the dummies sit at -Z: face him at a foe (`hero._face(to)`) before a throw, or "missing damage" is a facing bug.
Keep scratch SceneTrees (`tests/_<lane>_*.gd`) out of the commit and delete their `.uid` files; a check that greps
the source (`comic_check` scans `_play("clip")`) must scan every file after a split, or it passes while covering less.

## Timing flakes and the counters
- `RETRY` in `agent.sh` reruns `rhythm_check`, `ice_block_check` and `cool_pass_check` once on a FAIL. A FAIL on
  both runs is real. A new assertion on a ~25 ms gap is quantised to the 16.7 ms step: take a mean of several runs
  with a margin (`rhythm_check` `HIT_CONFIRM_RUNS`) rather than widening the gameplay constant.
- Autotest counters: `hits=` / `max_combo=` and the `[rhythm]` ms vary a little run to run. For "identical
  behaviour" compare `breakers=`, `strings=`, `endings_n=`, `moves=`, `casts=`, every `[improv]` cell, `[kit]` and
  `[env]` against a dev run (`agent.sh check` asserts `N/N` on breakers, strings, endings, kit slots and pieces).
- A `[rhythm]` beat that jumps in passing and failing runs alike is a clue, not the bug; a breaker that drops out
  "sometimes" can be the Awakening meter running out mid-string. Trace per frame into a buffered log and diff against
  a detached worktree of the old base (`git worktree add --detach`) before reading diffs.
- Bash's 120 s tool timeout: run a full autotest with `run_in_background`, never chained after another check.
