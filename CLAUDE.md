# Awaken

Fast-paced 3D combo roguelike hack and slash. Godot 4.7, GDScript. Original
characters only (no licensed IP in the repo).

## Design pillars
1. **Combat feel first.** Light/heavy strings, dash cancels out of anything,
   hitstop + shake + knockback + flash on every hit. Tune before adding content.
2. **Awakening.** Style rank (variety > mashing) fills the meter; activating
   transforms the hero (moveset/speed/damage, super armor, cinematic burst).
3. **Combo-slot upgrades (roguelike hook, not built yet).** Run rewards attach
   to specific moves ("3rd light hit releases a fire wave"), so each run builds
   a different combo string.
4. Tower defense is parked. If it returns, it's a room type, not a mode.

## Layout
- `scripts/game.gd` — autoload `Game`: hitstop, shake, combo/style rank, Awakening meter, input map (bound in code)
- `scripts/player.gd` — hero state machine; moves live in the `MOVES` table (timings are fractions of anim length)
- `scripts/enemy.gd` — skeleton AI: spawn → chase → telegraphed windup → strike; poise, launch/juggle
- `scripts/main.gd` — builds arena from KayKit pieces, run of rooms (`RUN_LENGTH`, `path_options()`, `ENEMY_TYPES`, `wave_composition()` are the tuning data), autotest bot
- `scripts/upgrades.gd` — combo-slot upgrade data (`Upgrades.ALL`, per-level numbers in each `lv`); effects are implemented in `player.gd` by id. `reward_screen.gd` offers 3 between rooms; `run_summary.gd` ends the run
- `scripts/boss.gd` — Bone Warden boss (extends enemy.gd); attack tuning in its `ATTACKS` table, fought in the last room (`main.RUN_LENGTH`)
- `scripts/altar.gd` — bone altar: banked bones and permanent boons (`BOONS`, `user://altar.cfg`), bought from the title screen, applied in `main._apply_altar()`; disabled in the autotest
- `scripts/records.gd` — saved run records (`user://records.cfg`), shown on the title screen and flagged on the run summary
- `scripts/spike_trap.gd` — floor spike hazard used by `main.LAYOUTS`
- `scripts/projectile.gd` — enemy bolts; i-frames pass through, perfect dodge still triggers
- `assets/sfx/` — synthesized placeholder sounds; regenerate with `python tools/gen_sfx.py`, play with `Game.sfx("name")`
- `assets/music/` — synthesized ambient + combat loops; regenerate with `python tools/gen_music.py`. `Game` plays them in sync and fades the combat layer by style rank (`MUSIC_RANK_LEVEL`)
- `scripts/hud.gd` (+ `enemy_bars.gd` health bars, `threat_arrows.gd`), `scripts/camera_rig.gd`, `scripts/fx.gd` (damage numbers, sparks, rings, flash)
- `assets/kaykit/` — CC0 models (see CREDITS.md). `vendor_src/` holds the full packs; it's gitignored and `.gdignore`d — copy pieces into `assets/` to use them.

## Workflow
- Headless check (compile + 12s bot playthrough): `godot --headless --path . -- --autotest`
- Visual check (screenshots to `%APPDATA%/Godot/app_userdata/Awaken/autotest_*.png`): `godot --path . -- --autotest`
- Effect preview (isolated, screenshot to `user://fx_preview.png`): `godot --path . -s tests/fx_preview.gd`
- Autotest also saves `autotest_hit.png` ~0.2s after the first big hit, for checking impact VFX, and prints a `[perf]` line (avg/worst frame ms, spikes >25ms with timestamps, max enemies/draw calls); measure perf windowed, not headless
- Menu check (title + pause + settings + elite door screenshots to `user://menu_*.png`): `godot --path . -s tests/menu_check.gd`
- Enemy lineup (one of each `ENEMY_TYPES` in a row, `user://enemy_lineup.png`): `godot --path . -s tests/enemy_lineup.gd`
- Occlusion check (hero parked behind a pillar, `user://occlusion_check.png`): `godot --path . -s tests/occlusion_check.gd`
- After adding assets **or a new `class_name`**: `godot --headless --import --path .` (registers global classes)
- `-- --autotest --all-upgrades` starts with every upgrade to exercise all effects (`--max-upgrades`: all at max level; `--upgrades=quake,bone_breaker` for specific ones); `--start-room=N` skips ahead (8 = boss; add `--boss-enraged` for phase 2 → `autotest_spikes.png`), `--twist=volatile` makes it an elite room with that twist (`--twist=volatile,hasted` for two), `--altar=hardened:3,scavenger:1` applies bone altar boons without saving, `--low-hp` starts at 15% HP (`autotest_lowhp.png`), `--start-rest` opens on a camp with 30 bones (`autotest_camp.png`), `--start-shrine` on a shrine with 30 bones (`autotest_shrine_room.png`, `autotest_shrine.png`), `--start-awakened` starts with a full meter (bot lands Cataclysm → `autotest_finisher.png`). The first Ground Breaker saves `autotest_breaker.png` (+ `autotest_fault.png` with Fault Line) and the first charged slam `autotest_slam.png`. Autotest also saves `autotest_summary.png`
- Scenes are mostly built in code; keep `.tscn` files minimal unless the user wants editor-authored scenes.
- KayKit models face +Z; facing yaw = `atan2(dir.x, dir.z)`. Characters share one rig, so any KayKit animation works on any character.
