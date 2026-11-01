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
- `scripts/player.gd` — hero state machine; moves live in the `MOVES` table (timings are fractions of anim length); `COMBOS` names the combos (name, input, tier): landing one plays `combo_<tier>` and shows the name above the hero, and the pause menu lists them as MOVES
- `scripts/enemy.gd` — skeleton AI: spawn → chase → telegraphed windup → strike; poise, launch/juggle
- `scripts/main.gd` — builds arena from KayKit pieces, run of rooms (`RUN_LENGTH`, `path_options()`, `ENEMY_TYPES`, `wave_composition()` are the tuning data), autotest bot
- `scripts/upgrades.gd` — combo-slot upgrade data (`Upgrades.ALL`, per-level numbers in each `lv`); effects are implemented in `player.gd` by id; `Upgrades.SYNERGIES` boosts tagged powers once two are owned (applied in `player.upg()`). `reward_screen.gd` offers 3 between rooms; `run_summary.gd` ends the run
- Power paths: each power has a `path` (`Upgrades.PATHS`: light/heavy/dash/awaken/soul, colour + key + mastery numbers); fusions add a second `fusion` path and are only offered once both are owned. Icons: `python tools/gen_power_icons.py` → `assets/icons/powers/<id>.svg` (then `--import`), drawn by `scripts/power_icon.gd` (`PowerIcon`). Check: `godot --path . -s tests/power_check.gd` (PASS/FAIL, headless works; windowed renders `user://power_cards.png`, `power_build.png`, `power_hud.png`). See `docs/features/powers.md`
- `scripts/run_map.gd` — `RunMap`: the run's map, generated once per run from `main.run_rng` (`LANES`, `WEIGHTS`, `KINDS`, `TRIALS` are the tuning data; no two fightless rooms linked, a rest before the boss); `map_screen.gd` draws it and takes the pick between rooms (pause menu → Map shows it read-only). Vaults (`main._vault`, `vault_prop.gd`) offer 3 powers of one path; trials are smaller fights with a condition that pays a fusion (`Upgrades.roll_fusion`). Check: `godot --headless --path . -s tests/map_check.gd` (500 seeds, PASS/FAIL; windowed renders `user://map_check.png`); autotest saves `autotest_map.png`. See `docs/features/run-map.md`
- `scripts/ascendancy.gd` — `Ascendancy.PATHS` (wind/earth/water): picked at hero level 6 (`Game.LEVEL_XP`, XP = enemy bones) on `ascend_menu.gd`; reshapes Awakening (colour, passive, finisher replacing Cataclysm). Effects (lightning, Tempest, magma, Volcano, chill/freeze, Glacier) live here; enemies get `chill()`/`freeze()`
- `scripts/elements.gd` — the shaman's elements (spirit before an Ascendancy, then wind/earth/water): `CASTS` gives every move an element cast (bolt, pillar, vortex, fissure, nova) fired from `player._cast()`; `LOOK` is each element's palette; also the orbiting motes and the ultimates' effects. `prewarm()` draws every material once at load (first-use shader hitches). `player.ULTIMATES` (SKY = Awakened L H H, RUSH = Awakened Dash L H, plus AF) run in `State.ULT`; each adds `ULT_CHAIN_BONUS`, all three in one Awakening fire `TRINITY`. HUD banner via `Game.ultimate`, camera push-in via `camera_rig.punch()`
- `scripts/hero_look.gd` — the shaman's look on the KayKit Barbarian: recoloured texture (`tools/gen_shaman_texture.gd` `RECOLOR`, per palette swatch), feathers/necklace on bones, axe runes. Close-up check: `godot --path . -s tests/hero_preview.gd` → `user://hero_preview.png`
- `scripts/boss.gd` — Bone Warden boss (extends enemy.gd); attack tuning in its `ATTACKS` table, fought in the last room (`main.RUN_LENGTH`)
- `scripts/altar.gd` — bone altar: banked bones and permanent boons (`BOONS`, `user://altar.cfg`), bought from the title screen, applied in `main._apply_altar()`; disabled in the autotest
- `scripts/records.gd` — saved run records (`user://records.cfg`), shown on the title screen and flagged on the run summary
- `scripts/spike_trap.gd` — floor spike hazard used by `main.LAYOUTS`
- `scripts/projectile.gd` — enemy bolts; i-frames pass through, perfect dodge still triggers
- `assets/sfx/` — synthesized placeholder sounds; regenerate with `python tools/gen_sfx.py`, play with `Game.sfx("name")`
- `assets/music/` — synthesized ambient + combat loops; regenerate with `python tools/gen_music.py`. `Game` plays them in sync and fades the combat layer by style rank (`MUSIC_RANK_LEVEL`)
- `scripts/combo_guide.gd` — the combo guide beside the hero mid-string: reads `player.combo_options()` (rows built from `player.route()`, the one routing function `_next_move` also uses) and `combo_window()` every frame; toggle `Game.combo_guide` (Settings)
- `scripts/hud.gd` (+ `enemy_bars.gd` health bars, `threat_arrows.gd`), `scripts/camera_rig.gd`, `scripts/fx.gd` (damage numbers, sparks, rings, flash)
- `assets/kaykit/` — CC0 models (see CREDITS.md). `vendor_src/` holds the full packs; it's gitignored and `.gdignore`d — copy pieces into `assets/` to use them.

## Workflow
- Headless check (compile + 12s bot playthrough): `godot --headless --path . -- --autotest`
- Visual check (screenshots to `%APPDATA%/Godot/app_userdata/Awaken/autotest_*.png`): `godot --path . -- --autotest`
- Effect preview (isolated, screenshot to `user://fx_preview.png`): `godot --path . -s tests/fx_preview.gd`
- Autotest also saves `autotest_hit.png` ~0.2s after the first big hit, for checking impact VFX, and prints a `[perf]` line (avg/worst frame ms, spikes >25ms with timestamps, max enemies/draw calls); measure perf windowed, not headless
- Menu check (title + pause + settings + run map screenshots to `user://menu_*.png`): `godot --path . -s tests/menu_check.gd`
- Enemy lineup (one of each `ENEMY_TYPES` in a row, `user://enemy_lineup.png`): `godot --path . -s tests/enemy_lineup.gd`
- Occlusion check (hero parked behind a pillar, `user://occlusion_check.png`): `godot --path . -s tests/occlusion_check.gd`
- After adding assets **or a new `class_name`**: `godot --headless --import --path .` (registers global classes)
- `-- --autotest --all-upgrades` starts with every upgrade to exercise all effects (`--max-upgrades`: all at max level; `--upgrades=quake,bone_breaker` for specific ones); `--start-room=N` skips ahead (8 = boss; add `--boss-enraged` for phase 2 → `autotest_spikes.png`; `--boss-attack=cage` forces one `ATTACKS` key → `autotest_cage.png`), `--twist=volatile` makes it an elite room with that twist (`--twist=volatile,hasted` for two; `--twist=splitting` → `autotest_split.png`), `--altar=hardened:3,scavenger:1` applies bone altar boons without saving, `--low-hp` starts at 15% HP (`autotest_lowhp.png`), `--reduce-flashing` turns that setting on without saving, `--start-rest` opens on a camp with 30 bones (`autotest_camp.png`), `--start-shrine` on a shrine with 30 bones (`autotest_shrine_room.png`, `autotest_shrine.png`; `--shrine-trade=vow|melt` forces and takes that rotating trade), `--start-vault=light` opens on a vault of that path (`autotest_vault_room.png`), `--start-trial=untouched|swift|stylish` on a trial (prints `[autotest] trial=... met|failed`), `--start-awakened` starts with a full meter (bot lands Cataclysm → `autotest_finisher.png`). The first synergy saves `autotest_synergy.png`; the first Ground Breaker saves `autotest_breaker.png` (+ `autotest_fault.png` with Fault Line) and the first charged slam `autotest_slam.png`, the first Shatter `autotest_shatter.png`. Autotest also saves `autotest_summary.png`
- `--seed=N` repeats a run's doors, twists, spawn order and reward offers (`main.run_rng`; combat itself still varies with timing); the autotest line prints `seed=`; `--daily` seeds from today's date like the title's "Daily run" (`main.daily_seed()`)
- Elements: `godot --path . -s tests/element_preview.gd` renders every cast and ultimate impact per element (`user://element_*.png`, 2x2 sheets `element_sheet.png` / `element_ult_sheet.png`; `-- --only=earth` for one); `godot --headless --path . -s tests/ult_check.gd` checks casts, ultimate routing/damage/chain and the Trinity for every element (PASS/FAIL). Autotest prints `casts= ults= chain= impacts= trinity=` and saves `autotest_cast.png` / `autotest_ult.png` / `autotest_trinity.png` (with `--start-awakened` the bot lands all three ultimates and the Trinity)
- Combo guide: `godot --path . -s tests/guide_check.gd` checks every guide row and follow-up against the real routing (PASS/FAIL, headless works) and renders six states to `user://guide_sheet.png`; autotest prints `guide=` and saves `autotest_guide.png`
- Levels/Ascendancy: `--level=N` starts at hero level N (6 opens the Ascendancy choice at the first clear → `autotest_ascend.png`), `--ascend=wind|earth|water` starts ascended; `godot --headless --path . -s tests/ascend_check.gd` checks every element effect (PASS/FAIL)
- Room pacing (`-- --autotest --pace`, with `--start-room=N` / `--twist=X` / `--seed=N`): ends at the first room clear and prints `[autotest] cleared room=N kind=... time=`
- Room tour (`-- --autotest --tour`): forced doors fight → rest → shrine → elite → boss, fights wiped after 1.5s; camp buys its first offer and the shrine takes its rotating trade; prints `[tour] PASS/FAIL rooms=... trades=...` (~16s, works headless)
- Wiki (`docs/wiki/index.html`, open from disk): `python tools/wiki.py` regenerates `data.js` from the tuning tables (`tools/wiki_data.gd`) and flags ids missing from the hand-written `notes.js`; `--shots` re-captures `img/` (~4 min). Skills in `.claude/skills/`: `update-wiki` (refresh it), `roadmap-item` (one change end to end: build, verify, ROADMAP, commit)
- **Feature docs:** `docs/features/` has a technical write-up per feature (how it works, files, invariants, tuning, tests); see its README for the index and the template. Read the relevant one before changing a feature, and add or update one in the same commit when you build or change a feature
- Scenes are mostly built in code; keep `.tscn` files minimal unless the user wants editor-authored scenes.
- KayKit models face +Z; facing yaw = `atan2(dir.x, dir.z)`. Characters share one rig, so any KayKit animation works on any character.
