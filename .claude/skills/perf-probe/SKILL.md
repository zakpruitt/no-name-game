---
name: perf-probe
description: Read Awaken's `[perf]` line and hunt a frame hitch or a slow effect: what the wall `avg` hides on this 60 fps-capped machine, `cpu` / `cpu_spikes` / `gpu`, `print` as a frame spike, scripts and materials Godot frees and rebuilds (warmup.gd, `--collect-shaders`, `elements.prewarm`), CPU skinning, a per-function timing pass, and how to stop a Godot run safely. Use when a frame spikes, an effect hitches on first or every use, the autotest's `[perf]` line changes, a new material or effect script is added, or someone is about to kill Godot processes.
---

# Perf probes

Measure windowed: `godot --path . -- --autotest` prints `[perf]` at the end (headless numbers are not the player's).
Only when Zak allows a windowed run; otherwise reason from the headless `[perf]` cpu numbers and the spike lines.

## Reading `[perf]`
- **The wall `avg` lies here.** Zak's machine caps at 60 fps even with `--disable-vsync` (an empty project measures
  16.67 ms), so `avg` sits at ~16.4-16.7 ms whatever the game costs. Read `cpu avg/worst` (every node's process and
  physics work from `perf_probe.gd` plus the render submit), `cpu_spikes` and `gpu`. A spike is a frame over 25 ms
  wall or 8 ms cpu; spike lines name the move and the pipeline compile count.
- **GPU numbers with another app on the GPU are noise** (a game at 98% GPU made `gpu avg` 20-30 ms). For one layer's
  cost, toggle it every 20 frames while the bot plays and compare medians: outside load hits both halves alike.
- **The dev checkout can be mid-import** (another lane just landed GLBs): a run there can show 400-800 ms frames and
  0 hits. Measure a baseline in your own worktree (`git checkout <base> -- scripts tests`, run, restore).

## What costs frames
- **`print` costs 2-10 ms with stdout piped** (every agent run): one print in a hit path is a frame spike. Buffer bot
  and debug lines (`player.bot_log`, `_rhythm_log`) and print them at the end.
- **Godot frees what nothing holds.** A `load("res://scripts/x.gd")` script and a StandardMaterial3D's generated shader
  are freed when their last user goes and rebuilt (10-20 ms) on the next use, so an effect that loads a script or
  makes a fresh material each time hitches every time. `scripts/warmup.gd` holds every script and built-in material
  shader (`warmup_shaders.gd` lists the signatures): after adding an effect material rerun
  `godot --path . -- --autotest --collect-shaders` and commit the list. `--collect-shaders` sees only
  StandardMaterial3D / ParticleProcessMaterial: a ShaderMaterial (`ghost_halftone`, `halftone_floor`) must be drawn in
  `elements.prewarm()` at real size (a sub-pixel draw can skip the compile).
- **`bake_mesh_from_current_skeleton_pose` is CPU skinning** (~18 ms on the hero). For a posed copy share the mesh and
  skin with a new Skeleton3D holding the global poses (`Fx.afterimage` does).
- **Per-breaker effect builds** run 5-9 ms (pops, geysers, craters 1-2.5 ms each): pool nodes (`FX_BEAT.stamp` pools
  by sheet) rather than build per landing; cap per-frame spawns keyed on `Engine.get_process_frames()`.
- **A stiff spring in a modifier diverges on a frame spike** (a 0.5 s delta sent a lean to NaN and the hero vanished;
  headless never spikes, so no check saw it). Cap and sub-step the delta, reset non-finite state, and test the function
  with a 0.5 s delta (`tests/lean_spike_check.gd`).
- **Viewport readbacks** (`get_texture().get_image()`) stall ~100 ms each: never in play, and in a film take them
  while the bot walks between strings.

## Finding the hitch
- **Per-function timing without the profiler:** a Python pass (see `windows-patching`) that renames each top-level
  `func f` to `__pc_f` and adds a wrapper summing `Time.get_ticks_usec()` deltas into `Engine.get_meta("pc")`,
  printed on spike frames, found every hitch in two runs. Revert with `git checkout -- scripts/` (after committing
  your real work); never commit it.
- Per-frame probes of game state belong in a scratch SceneTree (see `film-and-judge`), buffered, printed at the end.

## Stopping Godot
- **Never `taskkill` all Godot** (`taskkill /IM godot*`): other agents' runs die with yours, and it is refused. Stop
  your own background command with TaskStop or kill its PID, and always wrap a run in `timeout N` (a parse error
  makes `--autotest` hang with no `done` line). TaskStop on a shell does not stop its Godot child: wait for the window
  to go before rerunning a film into the same folder.
