# Awaken

Fast-paced 3D combo hack and slash. Godot 4.7, GDScript. Original characters only (no licensed IP in the repo).

The game today is the heretic's combat in a training room: his strings, their timed breakers, the element
matrix and the dash counter, against dummies and an optional live spar foe. No run, no title screen; it boots
straight into training. `docs/architecture.md` explains how the code fits together; read it once.

## Design pillars
1. **Combat feel first.** Light / right-click strings, dash cancels out of anything, hitstop + shake +
   knockback + flash on every hit. Tune before adding content.
2. **Combos are the game.** Every string has a name, a guide row and (for the enders) a timed breaker; the
   weapon a light forms decides what the tentacle's right click does.
3. **Awakening.** Style rank (variety > mashing) fills the meter; activating it powers the hero up.
4. **Chibi but badass** (`docs/features/art-direction.md`), in the comic style.

## Map (one line per family; the feature doc has the rest)
| Family | Files | Doc |
|---|---|---|
| Global state | `scripts/game.gd` (autoload `Game`: hitstop and time scale, combo / style rank, Awakening meter, sfx, music, settings, input map), `impact_frame.gd` | `features/impact-feedback.md` |
| The room | `scripts/main.gd` (builds everything in code), `rooms.gd`, `env_piece.gd`, `env_target.gd`, `env_flourish.gd`, `frost_wall.gd`, `training_dummy.gd`, `spar.gd` | `features/training.md`, `rooms.md`, `env-pieces.md`, `environment.md` |
| The hero | `scripts/player.gd` (node, state machine, fields) + static-function files `hero_moves.gd` (MOVES, COMBOS, `void_route()`), `hero_input.gd`, `hero_leap.gd`, `hero_awaken.gd`, `hero_fx.gd`, `counter.gd` / `counter_fx.gd`, `kit_slots.gd` / `kit.gd`, `heretic_rig.gd` | `features/heretic-hero.md`, `combo-breakers.md`, `counter.md`, `kit-slots.md` |
| Right click | `scripts/void_element.gd` (every element move, crossover, breaker landing, the matrix), `void_grab.gd` / `void_arm.gd` / `void_tendril.gd` (the tentacle), `thrown_foe.gd`, `floor_bind.gd`, `frost_spear.gd`, `foes.gd` (shared foe queries), the per-ending scripts (`harpoon_gather`, `lava_leash`, `collapse_spit`, `avalanche_topple`, `abyss_rise`, `eruption_hurl`, `frost_shell`, `tentacle_haul`, `live_current`, `mid_beats`, `breaker_alt_fx`) | `features/void-element.md`, `void-arm.md`, `element-matrix.md` |
| Foes | `scripts/enemy.gd` (AI + hit reactions), `enemy_types.gd`, `foe_lean.gd`, `projectile.gd`, `enemy_bars.gd`, `threat_arrows.gd` | `features/enemy-hit-reactions.md` |
| UI | `scripts/hud.gd`, `hud_ink.gd`, `combo_guide.gd`, `move_list.gd`, `breaker_prompt.gd`, `breaker_cue.gd`, `pause_menu.gd`, `menu_screen.gd` | `features/combo-guide.md` |
| Effects | `scripts/designed_*.gd` (authored flipbook sheets, the only effects), `fx.gd` (dispatch), `fx_palette.gd`, `fx_beat.gd`, `elements.gd`, `dark_fx.gd`, `comic_*.gd`, `spirit_echo.gd`, `claw_lash.gd`, `standing_fx.gd`, `shaders/`, sheets from `tools/vfx_gen/gen_*.py` into `assets/vfx/designed/` | `features/fx-language.md` (read before any effect), `designed-fx.md`, `spirit-casts.md` |
| Look | `scripts/comic_look.gd`, `comic_fx.gd`, `camera_rig.gd`, `weapon_trail.gd`, `assets/comic/` (GLBs), `tools/comic_art/`, `tools/hero_build/`, `tools/meshy_rig/`, `tools/meshy/` (new foes: Meshy model + shared clips, one command) | `features/comic-style.md`, `camera.md`, `heretic-hero.md`, `meshy-foes.md`, `meshy-pipeline.md`, `art-direction.md` |
| Dev only | `scripts/training_bot.gd` (`--autotest`), `perf_probe.gd`, `warmup.gd` / `warmup_shaders.gd`, `tools/agent.sh`, `tools/dead_refs.py`, `tools/wiki.py` (`docs/wiki/`) | `docs/agents.md`, `features/wiki.md` |

## Rules
- Typed GDScript; warnings are errors. A `Variant` inferred from a Dictionary `get()` is a parse error, and a parse
  error in any script the main scene preloads breaks every check. `static func` files reach the hero through their
  `hero` argument (the `void_element.gd` pattern, `docs/architecture.md` section 2).
- Scenes are built in code; keep `.tscn` minimal. After adding assets or a `class_name`: `godot --headless --import --path .`.
- Tuning numbers live in the tables (`MOVES`, `COMBOS`, `BREAKERS`, `RULES`, `TYPES`, `ROOM_DEFS`, `PAL`) with a one-line
  comment saying what the number does, not its history. History goes in git and `docs/history/`.
- Every move and combo has a row in `scripts/move_list.gd` and a bot string in `training_bot.BOT_STRINGS`; the checks
  walk them against `void_route()`.
- Update the feature doc in `docs/features/` in the same commit as the feature (template in its README).
- Effects are held to `docs/features/fx-language.md`; use `fx_beat.gd` timings and `designed_fx.spawn`, never a new
  timing constant or a runtime polygon.
- Headless unless Zak says windowed; wrap every Godot run in `timeout N`; never kill all Godot processes.
- `user://` is shared by every worktree: film into your own `--dir=` and copy shots out at once.
- Edit CRLF `.gd` files with the Edit tool or a Python patch written with the Write tool (`windows-patching` skill);
  never `sed -i`, never code in a heredoc.
- Several agents work at once, one git worktree each (`docs/agents.md`); commit on `agent/<name>`, land with
  `bash tools/agent.sh land`, never commit in another checkout.
- Engine API: grep `docs/engine_api/<Class>.xml` before using a 4.7 method you are not sure of.
- Models face +Z; facing yaw is `atan2(dir.x, dir.z)`.

## Commands
| What | Command |
|---|---|
| All checks (every `tests/*_check.gd`, then the autotest plain and with `--kit=full --room=pieces`) | `bash tools/agent.sh check` (`--quick`: autotest only; `--only=<name,...>`) |
| One check | `godot --headless --path . -s tests/<name>_check.gd` |
| Autotest (the bot plays every string; asserts `breakers=N/N strings=N/N endings_n=N/N`, `[kit]`, `[env]`, `[improv]`) | `godot --headless --path . -- --autotest [--kit=full] [--room=pieces] [--spar=<kind>] [--start-awakened]` |
| Film every string (windowed) | `godot --path . -s tests/string_film.gd -- --dir=<name> [--from=N --to=N] [--spar=<kind>]` |
| Looks (windowed) | `tests/element_shots.gd [-- --only=<combo>]`, `tests/heretic_shots.gd`, `tests/foe_shots.gd`, `tests/comic_shots.gd`, `tests/improv_shots.gd`, `tests/piece_shots.gd` |
| Dead names | `python -I tools/dead_refs.py [--docs]` |
| New worktree / land / remove | `bash tools/agent.sh new <name>` / `land` / `remove <name>` |
| New foe from a Meshy rig (`meshy-foe` skill) | `python tools/meshy/meshy.py build <kind>` |
| Regenerate | sheets `python tools/vfx_gen/gen_<family>.py`, sfx `tools/gen_sfx.py`, music `tools/gen_music.py`, wiki `tools/wiki.py`, engine API `tools/gen_engine_api.py` |
| Flags | `--cam-dist= --cam-fov= --cam-frame=` (camera.md), `--swing`, `--bag-*=` (training.md), `--room=plain|pieces|cistern|forge`, `--hero=chibi|v3|heretic` |

## Skills (`.claude/skills/`)
`roadmap-item` (one change end to end), `combo-feel` (strings, routing, rhythm), `combo-breaker` (timed finishers),
`spirit-cast` (spectral axes), `godot-headless-test` (writing and reading the checks), `film-and-judge` (feel and look
from film), `land-worktree` (worktrees, rebase, land, locks), `windows-patching` (CRLF edits from a shell),
`perf-probe` (`[perf]` lines, hitches, shader warmup), `bot-strings` (`BOT_STRINGS` and the autotest counters),
`meshy-foe` (a new foe or standard-bodied character through Meshy: 26 credits, no hand rigging).

## Where things are written down
`docs/architecture.md` (how the code works), `docs/features/` (one doc per feature), `docs/agents.md` (the worktree
protocol), `ROADMAP.md` (`## Now`: open items and Zak's calls), `docs/history/` (every past audit, round list and
the 2026-11-08 cleanup report), `docs/characters/` (design docs), `CREDITS.md` (CC0 sources). `docs/wiki/design/` (HTML drafts for Zak's review:
the roguelike direction, the small base kit, Techniques / Gear / Boons, the run and its ten-slice build order;
proposals until Zak answers the hub's decisions, so do not build from them unasked).
