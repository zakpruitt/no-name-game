# Cleanup audit: reduce Awaken to the heretic combat system + training

Zak's call: "reduce the game to JUST the heretic combat system; remove the
roguelike layer; keep the training ground." This is the map for that cut,
written against `dev` at `88686e3` (agent/hero-base landed). **Nothing is
deleted by this document.** It classifies every script, test, tool and
feature doc, says where the seams are in the tangled files, and gives an
ordered plan a single agent can run as commits, each leaving `--training`
playable and the remaining checks green.

Line counts are `wc -l` on that commit. Verify anything here with grep
before cutting: the branch moved while this was written.

> **Status at landing (dev `4929c88`):** the strip agent has already run
> what is step 1, most of step 2 and step 5 below (`499138a` drops the wiki
> and the power icon tool; `4929c88` cuts the run down to the training room:
> altar, camp, shrine, vault, records, run map, run summary, title screen,
> spike traps, bone pickups, `map_check`, `menu_check` are gone and foe
> types moved to `scripts/enemy_types.gd`). Read the plan from step 3 on;
> the line counts describe `88686e3`, the commit this was written against.

## Target state

- Boot straight into Training (title → Training is the only menu path that
  survives; the pause menu keeps Settings, Moves, Restart training, Quit).
- Defaults: `Game.comic_style = true`, `Game.heretic = true`; `--comic` and
  `--heretic` become no-ops; the KayKit hero fallback (`ComicLook.hero_kind()`)
  goes.
- Routing: `player._routed()` becomes `void_route()` plus the
  `VOID_ELEMENT.vaults()` spear check. `route()` (the KayKit tables) goes.
- Enemies stay as they are (the dummies extend `enemy.gd`; the autotest bot
  fights them in the training room).
- Checks that remain: `void_arm_check`, `move_list_check`, `guide_check`,
  `training_check` (including `_spear_by_hand`), `comic_check`, the autotest
  (`-- --autotest`, which then runs in the training room), and
  `tests/element_shots.gd` as the look check.

## Classes used below

| Class | Meaning |
|---|---|
| **KEEP** | the heretic hero, his elements and breakers, the training room, enemies and their reactions, shared fx / camera / game plumbing |
| **DROP** | the roguelike layer: run map, rooms and doors, rewards, powers / paths / fusions, altar, records, shrine, camp, vault, trials, daily runs, boss room, wiki, every menu past title → training |
| **TANGLED** | KEEP code that depends on DROP code, with the seam named |
| **OLD HERO: decide** | the KayKit shaman's own path: `route()`, `BREAKERS` on LH/LLH/LPL/DH/LHH, `hero_look.gd` dressing, Ascendancy forms. Not used by the heretic; not part of the roguelike either |

Two questions for Zak are at the end: Awakening and Ascendancy are neither
clearly heretic nor clearly roguelike.

## Scripts (`scripts/`, 69 files, 20 745 lines)

### KEEP (32 files, 8 023 lines)

| File | Lines | Why |
|---|---|---|
| `void_element.gd` | 859 | the heretic's elements, strings and breakers |
| `void_grab.gd` | 813 | the tentacle: grab, swing, slam, carry |
| `void_arm.gd` | 55 | weapon shapes on the arm |
| `void_tendril.gd` | 98 | the tendril mesh |
| `thrown_foe.gd` | 213 | ice cubes, thrown foes |
| `floor_bind.gd` | 119 | Undertow / Overwhelm pins (uses `RITE.well`) |
| `frost_spear.gd` | 187 | the planted spear |
| `dark_fx.gd` | 542 | dark element effects |
| `heretic_rig.gd` | 259 | tentacle sway, weapon changes |
| `heretic_form_fx.gd` | 240 | weapon-change burst |
| `comic_look.gd` | 543 | the art style (TANGLED on `hero_kind()`: see below) |
| `comic_fx.gd` | 159 | words on hits |
| `comic_axe_aura.gd` | 183 | element on the axes (uses `hero_look._drip`: see hero_look) |
| `comic_drag_mark.gd` | 153 | floor marks |
| `enemy.gd` | 961 | every foe and the dummies (TANGLED on bones / elite: see below) |
| `training_dummy.gd` | 63 | the dummies |
| `fx.gd` | 597 | shared effects |
| `camera_rig.gd` | 65 | camera |
| `weapon_trail.gd` | 100 | the ribbon on the weapon |
| `projectile.gd` | 121 | archer / necromancer bolts (enemies stay) |
| `bone_cage.gd` | 190 | necromancer cage (enemies stay) |
| `bone_spike.gd` | 76 | enemy spike attack |
| `enemy_bars.gd`, `threat_arrows.gd` | 63 + 56 | HUD parts for foes |
| `breaker_cue.gd`, `breaker_prompt.gd`, `breaker_quake.gd` | 103 + 166 + 220 | the heretic's breaker window (`State.LEAP` is driven by `VOID_ELEMENT.BREAKERS` via `_breaker_for`) |
| `spirit_echo.gd` | 153 | live: `ELEMENTS.CASTS` fires `echo` on L1 / L2 / AL2 (`player._cast`); also `ghost()` is the base of every spectral mesh |
| `spirit_tomahawk.gd` | 99 | live: `CASTS.DL` is a tomahawk |
| `move_list.gd` | 151 | the pause menu's MOVES panel (`sections_for(player)`; the KayKit rows go with `route()`) |
| `combo_guide.gd` | 276 | next-input hints (reads `player.combo_options()`) |
| `menu_screen.gd` | 151 | the menu base class (pause, title) |

### TANGLED (10 files, 8 408 lines; what to cut is in "Seams")

| File | Lines | Depends on DROP through |
|---|---|---|
| `player.gd` | 3 480 | `has_upgrade()` / `upg()` (74 lines of hooks through the hit code), the power effects (`_shatter` … `_static_trap`, `_effective_move`), levels (`_on_level_up`), rewards, `ascend()` / rites, `ULTIMATES`, the KayKit `route()` and `BREAKERS` |
| `main.gd` | 1 803 | everything from `_start_map()` to `_end_run()` plus the room-tour / bot paths; training needs `_ready` (arena, hero, camera, HUD), `_build_environment`, `_build_arena`, `_apply_layout(0)`, `_model`, `_start_training` and friends |
| `game.gd` | 519 | bones, XP / levels, hints, `skip_title`, the run reset; the rest (hitstop, shake, slowmo, combo, style rank, Awakening meter, sfx, music, settings, input map) is KEEP |
| `hud.gd` | 463 | bones label, XP bar, level label, route strip, power strip, boss bar, `set_room` / `set_route` / `set_upgrades` |
| `pause_menu.gd` | 299 | `_build_powers` / `_path_header` / `_power_row` (105 lines), `_show_map`, Map item; `_open_training`'s "Pick a power", "Ascend" items |
| `title_screen.gd` | 106 | Start run, Daily run, Altar, recent runs (records); only "Training" stays, and the target state skips the title altogether |
| `elements.gd` | 860 | KEEP: `fissure`, `nova`, `pillar`, `spikes`, `storm_strike`, `LOOK`, `funnel` / `swirl_mat` / `crescent` / `piece` / `_mi` / `_fade_free` (air_gust), `prewarm`, `Orbit`; `CASTS` entries for dead kinds and `prewarm`'s Ascendancy draws go |
| `element_rite.gd` | 404 | KEEP `arc` (void_element), `geyser` (void_element), `well` (floor_bind, 11 lines); the priming / set-off system (`prime_foe`, `set_off`, `_marked`, `_freeze`, `_encase`, `HEAVIES`, `NAMES`) is only reached with `ascendancy != ""` |
| `ascendancy.gd` | 293 | KEEP `enemies_near` (22 call sites in void scripts), `color`, `glow_mat`, `magma_pool` (void); `lightning`, `chill_hit`, `glacier`, `PATHS` are the Ascendancy paths |
| `comic_look.gd` | (counted KEEP) | `hero_kind()` KayKit fallback only (`infuse_axes` / `hero_blades` are the comic hero's: KEEP) |
| `air_gust.gd` | 181 | used by the KayKit air string (`AH` Updraft, Gale Waltz, Stormfall `comet`) and by `_state_leap`'s dive trail (`comet`) for every breaker: keep `comet`, the rest goes with `route()` |

### DROP (18 files, 2 824 lines)

| File | Lines | Layer |
|---|---|---|
| `run_map.gd` | 281 | run map |
| `map_screen.gd` | 591 | run map UI |
| `upgrades.gd` | 381 | powers / paths / fusions |
| `reward_screen.gd` | 288 | rewards between rooms (also `train_power`) |
| `power_icon.gd` | 84 | power icons (HUD strip, cards) |
| `run_summary.gd` | 113 | end of run |
| `records.gd` | 98 | saved runs |
| `altar.gd`, `altar_menu.gd` | 82 + 26 | bone altar |
| `camp.gd` | 34 | rest room |
| `shrine.gd`, `shrine_prop.gd` | 54 + 60 | shrine |
| `vault_prop.gd` | 64 | vault |
| `spike_trap.gd` | 92 | `main.LAYOUTS` hazard (layout 0, training, has none: check `LAYOUTS[0]`) |
| `boss.gd` | 443 | the Bone Warden, last room only (`main._spawn_boss`); `ENEMY_TYPES` stays |
| `bone_pickup.gd` | 62 | bones currency |
| `ascend_menu.gd` | 30 | Ascendancy pick (see question 2) |
| `fire_wave.gd` | 41 | only fired by the `ember_cleave` power and Cataclysm |

### OLD HERO: decide (9 files, 1 490 lines, plus the player.gd parts under "Seams" and most of air_gust.gd)

| File | Lines | Used by |
|---|---|---|
| `hero_look.gd` | 618 | KayKit dressing, kit, coats, Ascendancy forms. `comic_axe_aura.gd` still calls `HERO_LOOK._drip()` (motes off a coated blade): move those 30 lines into `comic_axe_aura.gd` before deleting |
| `ascend_aura.gd` | 115 | the Ascendancy aura (`player.ascend`) |
| `spirit_cleave.gd` | 129 | `CASTS.L3` (in `VOID_ELEMENT.NO_CAST`: never fires for the heretic) |
| `spirit_avatar.gd` | 128 | `CASTS.CH` (unreachable: heavy from neutral is `OW` for the heretic), `_breaker_ancestor`, `_sky_ancestor`; `slam_fx()` is shared by cleave / guillotine only |
| `spirit_crown.gd` | 93 | `CASTS.LH` (KayKit launcher) |
| `spirit_rift.gd` | 94 | `CASTS.LLH`, `_dash_wake` (Flurry breaker), `_rush_blades` (ultimate) |
| `spirit_wheel.gd` | 78 | `CASTS.H` / `DH` (KayKit heavies), `_juggle` (Charged Slam breaker) |
| `spirit_guillotine.gd` | 116 | `CASTS.LHH`, `_volley_raise` (Spike breaker), `_axe_fall` (Cataclysm / Trinity) |
| `breaker_spike.gd` | 143 | `_throw_spike` (Ground Breaker, KayKit LLH) |
| `air_gust.gd` (part) | ~150 of 181 | `gust`, `cloud`, `vanish`, `wind_blade`, `_helix`, `_blades`: the KayKit air string. `comet` (7 lines) is live for every breaker dive |

`tools/gen_shaman_texture.gd` (50) and `assets/hero/shaman_texture.png` go
with `hero_look.gd`; `tests/hero_preview.gd`, `hero_dump.gd`,
`trail_preview.gd` and `tools/render_hero.py` render the KayKit hero.

## Tests (`tests/`, 28 files, 5 069 lines)

| Test | Lines | Class | Note |
|---|---|---|---|
| `void_arm_check.gd` | 1 031 | KEEP | the heretic's check; add `--heretic` as the default once the flag is gone |
| `training_check.gd` | 92 | TANGLED | checks "Pick a power", Fill Awakening, Ascend on the training pause menu: rewrite to the surviving items (+ `_spear_by_hand`) |
| `move_list_check.gd` | 171 | KEEP | walks `MOVE_LIST` rows through routing; the KayKit rows go with `route()` |
| `guide_check.gd` | 156 | KEEP | combo guide against routing |
| `comic_check.gd` | 566 | TANGLED | loads `shrine_prop.gd`, `vault_prop.gd`, `boss.gd`, `hero_look.gd`: drop those cases |
| `element_shots.gd` | 158 | KEEP | the look check |
| `heretic_shots.gd` | 202 | KEEP | heretic pictures |
| `comic_shots.gd` | 324 | TANGLED | captures shrine / vault / records: trim |
| `comic_preview.gd` | 73 | KEEP | |
| `fx_preview.gd`, `telegraph_preview.gd`, `enemy_lineup.gd`, `occlusion_check.gd`, `menu_check.gd` | 165 + 38 + 34 + 16 + 77 | KEEP / trim | `menu_check` captures the run map and altar: trim to title + pause + settings |
| `breaker_prompt_preview.gd`, `prompt_follow_check.gd` | 46 + 65 | KEEP | the breaker widget (heretic breakers use it) |
| `cast_dump.gd` | 336 | OLD HERO | dumps every spirit cast / breaker / rite; keep only if the spirit scripts stay (echo + tomahawk cases would survive) |
| `breaker_check.gd` | 174 | OLD HERO | `player.BREAKERS` (KayKit) |
| `hop_check.gd` | 234 | OLD HERO | KayKit hops / air string |
| `ult_check.gd` | 91 | OPEN | ultimates (question 1) |
| `ascend_check.gd`, `rite_check.gd` | 86 + 92 | OPEN | Ascendancy (question 2) |
| `hero_preview.gd`, `hero_dump.gd`, `trail_preview.gd` | 46 + 69 + 85 | OLD HERO | KayKit hero renders |
| `element_preview.gd` | 119 | OLD HERO | every cast per element |
| `map_check.gd` | 224 | DROP | run map |
| `power_check.gd` | 299 | DROP | powers |

## Tools (`tools/`, 10 files, 1 111 lines)

| Tool | Lines | Class |
|---|---|---|
| `agent.sh` | 112 | KEEP; its `tests=(...)` list changes at every step below |
| `comic_glb.py`, `gen_engine_api.py`, `gen_sfx.py`, `gen_music.py` | 73 + 41 + 173 + 163 | KEEP |
| `meshy_rig/*.py` | (Blender) | KEEP (heretic pipeline) |
| `wiki.py`, `wiki_data.gd` | 108 + 140 | DROP (reads `Upgrades`, `altar.gd`, `map_screen.gd`); `docs/wiki/` and `.github/workflows/wiki.yml` go with them |
| `gen_power_icons.py` | 132 | DROP |
| `gen_shaman_texture.gd`, `render_hero.py` | 50 + 119 | OLD HERO |

## Feature docs (`docs/features/`)

| Doc | Class |
|---|---|
| `heretic-hero.md`, `void-arm.md`, `void-element.md`, `meshy-pipeline.md`, `training.md`, `comic-style.md`, `combo-guide.md` | KEEP (training.md and comic-style.md lose their powers / Ascendancy / KayKit paragraphs) |
| `powers.md`, `run-map.md` | DROP |
| `combo-breakers.md`, `spirit-casts.md` | OLD HERO (the heretic's breakers are documented in void-element.md) |
| `element-rites.md` | OPEN (question 2); `arc` / `geyser` / `well` need a home in void-element.md either way |

`CLAUDE.md` and `ROADMAP.md`: rewrite the Layout section at the end (step 9).

## Dependency sketch

```
training room ──> main.gd {_ready, _build_environment, _build_arena, _apply_layout(0),
                           _model, _start_training.._hits_text, restart_training}
                 ──> player.gd ──> void_element/void_grab/void_arm/void_tendril
                 │                 ──> dark_fx, floor_bind (RITE.well), frost_spear, thrown_foe
                 │                 ──> heretic_rig, heretic_form_fx, comic_look, comic_axe_aura
                 │                 ──> breaker_cue/prompt/quake (State.LEAP)
                 │                 ──> elements {fissure nova pillar spikes storm_strike LOOK prewarm}
                 │                 ──> element_rite {arc geyser well}   ascendancy {enemies_near color glow_mat magma_pool}
                 │                 ──> spirit_echo (L1/L2/AL2), spirit_tomahawk (DL), air_gust.comet
                 │                 ──> fx, weapon_trail, camera_rig, game
                 ──> enemy.gd ──> projectile, bone_cage, bone_spike, comic_fx, fx
                 ──> hud ──> enemy_bars, threat_arrows, combo_guide
                 ──> pause_menu ──> menu_screen, move_list
                 ──> training_dummy (extends enemy)

DROP cluster:  run_map ─ map_screen ─ main {_start_map.._end_run, bot/tour} ─ reward_screen ─ upgrades
               ─ power_icon ─ run_summary ─ records ─ altar(+menu) ─ camp ─ shrine(+prop) ─ vault_prop
               ─ boss ─ bone_pickup ─ spike_trap ─ fire_wave ─ title_screen(run items) ─ hud(xp/bones/route/powers)
               ─ game(xp/bones/hints) ─ player {upg/has_upgrade, power effects, _on_level_up}
               ─ wiki (tools/wiki*.py, docs/wiki, workflow) ─ tests {map_check, power_check}

OLD HERO cluster: player {route(), BREAKERS, _juggle, _throw_spike, _volley_raise, _fan_release,
               _dash_wake, _breaker_ancestor, air string, hops, _cast cases for dead kinds, ULTIMATES?}
               ─ hero_look (+ascend_aura) ─ spirit_{cleave,avatar,crown,rift,wheel,guillotine} ─ breaker_spike
               ─ air_gust (all but comet) ─ tests {breaker_check, hop_check, cast_dump, hero_*, trail_preview,
               element_preview} ─ tools {gen_shaman_texture, render_hero}
```

## Seams (exactly what to cut in the tangled files)

### `player.gd` (3 480 lines)

1. **Powers** (~560 lines): `has_upgrade` (2667), `upg` (2673),
   `_synergy_burst`, `remove_upgrade`, `_refresh_masteries`, `_mastery`,
   `_awaken_len`, `_base_anim_mult`, `_proc`, `add_upgrade` (2667–2746, 80
   lines), the power effects `_shatter`, `_crack_line`, `_fault_line`,
   `_fault_glow`, `_quake`, `_effective_move`, `_chain_spark`,
   `_thousand_cuts`, `_slipstream`, `_shockstep`, `_spike`, `_rebound`,
   `_razor_gale`, `_eye_of_storm`, `_static_trap` (2826–3079, 254 lines),
   `_riposte` (3394), `heal`'s power branches, and the 74 `has_upgrade(` /
   `upg(` call lines threaded through `_do_hit` (2024, 137 lines),
   `take_hit`, `_start_dash`, `_perfect_dodge`, `_on_enemy_killed`,
   `_on_combo_changed`, `_state_attack`. Each call site reduces to its
   non-power branch (grep `upg(` and `has_upgrade(`, delete the `if`
   or replace the multiplier with 1.0). `upgrades`, `masteries`,
   `synergies`, `power_procs` vars and the `Upgrades` references in
   `_combo_callout` go. Own commit (step 4).
2. **Levels / rewards**: `_on_level_up` (2747, 10 lines), the
   `Game.leveled_up` connect in `_ready`.
3. **KayKit routing** (OLD HERO, ~700 lines): `route` (1704, 39),
   `chain_after`'s KayKit branch, `_option`'s `"CH"` fallback, `MOVES`
   entries the void tables don't name, `BREAKERS` const and `_juggle`
   (1301), `_breaker_ancestor` (1328), `_volley_raise` (1343),
   `_throw_spike` (1402), `_fan_release` (1533), `_dash_wake` (1554),
   `_drop_wheel`, the `hop` / `weave` / air string: `_hop` (937),
   `_weave` (974), `_land_slam` (991), `_plunge_axes` (1006),
   `_stormfall` (1018), `_air_dash_cut` (1678), `_can_air_dash`,
   `dash_light`, `_air_home` (1997), `AIR_*` / `STORMFALL_FROM` consts,
   the `AIR_GUST.gust/cloud/vanish/wind_blade` calls in `_start_attack`
   and `_physics_process`. `_routed` (1648) then returns `void_route`
   directly. `State.LEAP`, `_start_leap`, `_state_leap`, `_start_dive`,
   `_breaker_impact`, `_breaker_pressed`, `_breaker_callout`,
   `_leap_dash_out`, `_end_leap`, `breaker_window`, `_breaker_prompt`,
   `_breaker_for`, `_brk_*` stay: the heretic's breakers run through them
   (`_breaker_for` reads `VOID_ELEMENT.BREAKERS`).
4. **Spirit casts**: `_cast` (2244, 111 lines) keeps the `echo` and
   `tomahawk` branches; `_spirit`, `_cast_grow`, `_cast_power`,
   `_cast_hit`, `_cast_target` stay. `_axe_fall` (3352) goes with
   Cataclysm.
5. **Ultimates** (OPEN, question 1): `ULTIMATES`, `_ult_mult`, `_ult_begin`,
   `_ult_landed`, `_start_ult`, `_state_ult`, `_state_sky`,
   `_sky_ancestor`, `_rush_blades`, `_state_rush`, `_ult_impact`,
   `_end_ult`, `_trinity`, `_finisher`, `_cataclysm`, `_fire_vortex`,
   `_fire_mat` (2398–2666 and 3253–3393, ~400 lines).
6. **Ascendancy** (OPEN, question 2): `ascend` (3146, 31), `_rite_set_off`,
   `_rite_wells`, `_rite_callout` (3177–3234, 58), the `rite` branch at the
   top of `_do_hit` (2037, 2090), `_asc_aura`, `_form`, `_coats`,
   `HERO_LOOK.*` calls in `_ready` / `_set_awakened` (go with hero_look
   regardless), `_path`, `element()` returns `"spirit"` only.

### `main.gd` (1 803 lines)

- KEEP: lines 1–290 minus the run tables (`RUN_LENGTH`, `ELITE_TWISTS`,
  `DOUBLE_TWIST_ROOM`, `LAYOUTS` beyond index 0, `BOSS_SPEC`,
  `path_options`, `wave_composition`, `elite_count`, `daily_seed`),
  `_ready` (291–472: drop the seed / daily / records / altar / title /
  map parts, ~60 lines; keep arena, hero, camera, HUD, prewarm, pause menu,
  then `_start_training()`), `_start_training` … `restart_training`
  (473–556, minus `train_power` and `train_ascend`), `_model` /
  `_set_model` (997–1009), `_spawn` (935) if the autotest keeps spawning
  foes in the room, `_on_enemy_died`'s combat parts, `_build_environment`
  … `_apply_layout` (1247–1402), `_fade_occluders`, `_process` minus the
  room / trial / hint parts, `_sample_perf`, `_autotest_finish` (trim the
  printed counters), `_snap`, `_bot_threatened`, `_drive_bot` (1702, 103:
  route it through `void_route` names).
- DROP (~900 lines): `_start_map` … `_twist_text` (557–934),
  `_any_fuse_lit` … `_split` (969–1133: `_spawn_boss`, `_reinforce`,
  `_raise`, `_split` are room mechanics; keep `_raise` only if the
  necromancer's raise should still work in training), `_offer_ascendancy`
  … `_end_run` (1134–1246), `_check_hints` (1498), `_drive_tour`,
  `_autotest_pick` … `_autotest_path` (1597–1656), `_bot_escape_cage`
  if the cage is not spawned in training.

### `game.gd` (519 lines)

- DROP: `bones`, `bones_total`, `add_bones`, `bones_changed` (~15 lines);
  `xp`, `level`, `LEVEL_XP`, `LEVEL_MAX`, `add_xp`, `_emit_level`,
  `level_changed`, `leveled_up` (~30); `HINTS`, `hint*`, `save_hints`,
  `_hints_seen` (~40); `skip_title`, `awaken_locked`,
  `awakening_gain_mult` if the altar's boons were their only writers
  (grep). `reset()` loses the run fields. ~110 lines.

### `hud.gd` (463 lines)

- DROP: `bones_label`, `xp_fill`, `level_label`, `_on_level`, `route_strip`,
  `set_route`, `_draw_route`, `power_strip`, `set_upgrades`, `POWER_ICON`,
  `set_room` (keep `wave_label` for "TRAINING"), `show_boss` and the boss
  bar, `_run_info`. ~130 lines. `set_trial` stays (training's string text).

### `pause_menu.gd` (299 lines)

- DROP: `_build_powers`, `_path_header`, `_power_row` (109–213, 105
  lines), `_show_map` and the Map item (52, 285), `_run_info` (95).
  `_open_training` keeps Fill Awakening (question 1) and Restart training.

### `title_screen.gd` (106 lines)

- Target state boots into Training, so the whole file can go once
  `main._ready` no longer awaits `title.started`. If a title stays, it is
  "Training / Settings / Quit": drop `daily`, `replay`, `build_recent`,
  `RECORDS`, `ALTAR_MENU` (~60 lines).

### `elements.gd` (860 lines)

- `CASTS`: keep `L1`, `L2`, `AL2` (echo) and `DL` (tomahawk); `AL1` and
  `L3` are in `VOID_ELEMENT.NO_CAST`; the rest name KayKit moves. The
  header comment lists every kind: trim with it.
- `prewarm` (72, 63 lines): draws each cast kind and `Ascendancy` effects
  once; remove the draws for deleted scripts.
- `lightning_fx` and `storm_strike` are live (breaker_quake.gd,
  void_element.gd). `vortex`, `sky_impact`, `meteor`, `rush_step`,
  `rush_wake`, `wave_wall` are only called from player.gd's ultimates /
  KayKit casts (question 1; grep before cutting).

### `element_rite.gd` (404 lines)

- Keep `well` (47), `arc` (162, 32 lines; `_thunder`, `_zap`, `_flat` with
  it) and `geyser` (240, 166 lines, `_lava_mat`); `floor_bind` calls
  `well`, `void_element` calls `arc` and `geyser`. If question 2 is
  "remove Ascendancy", `prime_foe`, `set_off`, `_marked`, `_freeze`,
  `_encase`, `HEAVIES`, `NAMES`, `WELL_RADIUS`'s priming use go (~100
  lines) and the three survivors move into `void_element.gd` or a
  `scripts/void_rites.gd`.

### `ascendancy.gd` (293 lines)

- Keep `enemies_near` (39), `color` (35), `glow_mat` (48), `magma_pool`
  (164, 87 lines). Move them (to `elements.gd`, which already holds the
  shared element helpers, or `void_element.gd`) before deleting the file:
  22 `Ascendancy.enemies_near` call sites in the void scripts, plus
  `elements.prewarm` and the spirit scripts. `lightning`, `chill_hit`,
  `glacier`, `PATHS` are the paths (question 2).

### `enemy.gd` (961 lines)

- `bones` / `ELITE_BONES_MULT` / `BONE` drops in `_die` (bone_pickup),
  `elite` and `_build_elite_aura` (elite rooms; 30 lines), `volatile`
  (elite twist, `_volatile_pop` / `_blast`, ~60 lines). Keep `elite` if
  the training room should be able to spawn one. Everything else (chase,
  windup, strike, poise, launch, chill / freeze for ice, `take_hit`,
  `rip_shield`, dummies) is KEEP.

### `comic_look.gd` (543 lines)

- `hero_kind()` (252): returns heretic always; drop the KayKit branch.
  `infuse_axes` and `hero_blades` are called from `player._ready` /
  `_coat_axes` for the comic hero: KEEP.

## Open questions for Zak

1. **Awakening and the ultimates.** Q still fills and activates the meter
   (the heretic's breakers feed it, `Game.add_awakening`), the HUD shows
   it, and training's "Fill Awakening" exercises it, but `void_route` has
   no ultimates: `ULTIMATES` (SKY / RUSH / AF / Cataclysm / Trinity) are
   only reachable through `route()`. Keep the meter and its
   transformation (speed / damage / super armour, `_set_awakened`) with
   no finisher, or drop Awakening entirely (`try_awaken`, `_set_awakened`,
   `_finisher`, `_cataclysm`, the HUD meter, `Game.awakening`,
   `RANK_AWAKEN_MULT`, `ult_check.gd`: ~550 lines)? The plan below
   assumes **keep the meter, drop the ultimates**.
2. **Ascendancy.** `ascend_menu.gd`, `Ascendancy.PATHS`, `player.ascend()`,
   the element rites' priming, `hero_look.FORMS`, `ascend_aura.gd`,
   `ascend_check.gd`, `rite_check.gd`. The heretic's elements come from
   his weapon count, not a path, and `element()` can return `"spirit"`
   forever. Drop, or keep as a later "form" system? The plan assumes
   **drop**, moving `arc` / `geyser` / `well` / `enemies_near` /
   `magma_pool` first.

## Ordered deletion plan

Each step is one commit (or two where noted) on top of `dev`. After each:
`timeout 180 godot --headless --path . -- --autotest --training` has no
SCRIPT ERROR / Parse Error, and every test still in `tools/agent.sh`'s
`tests=(...)` passes (edit that list in the same commit). Estimates are
lines removed net.

| # | Commit | Removes | Tests / tools / docs that go with it | Est. lines |
|---|---|---|---|---|
| 1 | `chore: boot into training; comic and heretic on by default` | `title_screen.gd` run items (or the file), `Game.skip_title`, `--comic` / `--heretic` parsing becomes constant true, `ComicLook.hero_kind()` KayKit branch, `main._ready`'s title / seed / daily block | `menu_check.gd` trimmed; `comic_check.gd`'s fallback cases; `void_arm_check` runs as heretic by default (its 10 "by design" fails become passes or are removed) | 150 |
| 2 | `chore: remove the run map, rooms and run flow` | `run_map.gd`, `map_screen.gd`, `main._start_map` … `_end_run`, `_drive_tour`, `_autotest_*` room helpers, run tables, `run_summary.gd`, `records.gd`, `camp.gd`, `shrine.gd`, `shrine_prop.gd`, `vault_prop.gd`, `altar.gd`, `altar_menu.gd`, `spike_trap.gd`, `boss.gd`, `bone_pickup.gd`, `Game` bones / hints, `hud` bones / route / boss bar, `pause_menu._show_map` | delete `map_check.gd`; trim `comic_check.gd`, `comic_shots.gd`, `enemy_lineup.gd` (warden row); delete `docs/features/run-map.md`; `agent.sh` list loses `map_check` | 2 900 |
| 3 | `chore: remove powers, rewards and levels` | `upgrades.gd`, `reward_screen.gd`, `power_icon.gd`, `main.train_power` / `_offer_reward` / `_take_reward` / rerolls, `Game` xp / level, `hud` xp / level / power strip, `pause_menu._build_powers` …, `fire_wave.gd`, `assets/icons/powers/` | delete `power_check.gd`, `tools/gen_power_icons.py`; `training_check.gd` loses the power-pick case; `docs/features/powers.md`; `agent.sh` loses `power_check` | 1 300 |
| 4 | `refactor(player): strip the power hooks from the hit code` | the 74 `has_upgrade` / `upg` lines, the 15 power-effect functions, `add_upgrade` … `_proc`, `_riposte`, `upgrades` / `masteries` / `synergies` vars | `move_list_check` and `guide_check` still pass (no routing change) | 600 |
| 5 | `chore: remove the wiki` | `docs/wiki/`, `tools/wiki.py`, `tools/wiki_data.gd`, `.github/workflows/wiki.yml`, the `update-wiki` skill in `.claude/skills/` | CLAUDE.md wiki line | 250 + generated |
| 6 | `refactor: move the shared element helpers out of ascendancy.gd and element_rite.gd` | `enemies_near`, `color`, `glow_mat`, `magma_pool` → `elements.gd`; `arc`, `geyser`, `well` → `void_element.gd` (or `void_rites.gd`); update the 22 + 3 call sites | `void_arm_check`, `training_check` prove the moves; `rite_check` still passes at this step | 0 (moves) |
| 7 | `chore: remove the Ascendancy paths` (question 2) | `ascendancy.gd`, `ascend_menu.gd`, `ascend_aura.gd`, `element_rite.gd`'s priming, `player.ascend` / `_rite_*`, `main.train_ascend` / `_offer_ascendancy`, `Game.LEVEL_XP` leftovers, `elements.prewarm`'s Ascendancy draws, `hero_look.FORMS` (goes with hero_look anyway) | delete `ascend_check.gd`, `rite_check.gd`, `docs/features/element-rites.md` (fold `arc` / `geyser` into void-element.md); `training_check` loses the Ascend case; `agent.sh` loses both | 700 |
| 8 | `chore: remove the KayKit hero path` (OLD HERO; split in two: routing, then visuals) | 8a `player.route()`, `BREAKERS`, the breaker bodies listed under seam 3, hops / air string, `MOVES` rows nobody routes to, `move_list.gd`'s KayKit sections, `_cast`'s dead kinds; 8b `hero_look.gd` (+ `_drip` moved into `comic_axe_aura.gd` first), `spirit_cleave/avatar/crown/rift/wheel/guillotine.gd`, `breaker_spike.gd`, `air_gust.gd` minus `comet`, `assets/hero/`, `tools/gen_shaman_texture.gd`, `tools/render_hero.py`, `elements.CASTS` dead rows + prewarm draws | delete `breaker_check.gd`, `hop_check.gd`, `hero_preview.gd`, `hero_dump.gd`, `trail_preview.gd`, `element_preview.gd`, `cast_dump.gd` (or trim to echo / tomahawk), `prompt_follow_check` stays; `docs/features/combo-breakers.md`, `spirit-casts.md`; `.claude/skills/combo-breaker`, `spirit-cast`, `combo-feel`, `headless-render` (rewrite for element_shots); `agent.sh` loses `breaker_check`, `hop_check` | 2 600 |
| 9 | `chore: remove the ultimates` (question 1) | seam 5 in player.gd, `Game.ultimate` signal + HUD banner, `elements.sky_impact` / `meteor` / `rush_*` / `wave_wall` if unreferenced, `ascend_check` already gone | delete `ult_check.gd`; `agent.sh` loses it | 550 |
| 10 | `docs: rewrite CLAUDE.md and ROADMAP.md for the heretic-only game` | the Layout and Workflow sections; `docs/features/README.md` index; `training.md`, `comic-style.md` paragraphs | | 150 (docs) |

Running total: about **9 000 of 20 700 script lines** and 12 of 28 tests
go. What remains is the heretic (void_*, dark_fx, floor_bind, frost_spear,
thrown_foe, heretic_*), the comic style, enemies, the training room, the
breaker window, two spirit casts, and the fx / camera / game plumbing:
roughly 11 500 lines.

## Order rationale

- Steps 1–3 take out whole files whose only callers are each other or
  `main.gd`; each is a clean compile after the `main.gd` edits.
- Step 4 is the only edit threaded through combat code; it goes after the
  power data is gone so every remaining `upg(` reference is a compile
  error pointing at the next line to cut.
- Step 6 before 7 and 8 keeps `void_arm_check` green while the files it
  reaches through are deleted.
- Steps 7 and 9 wait for Zak's answers; nothing earlier depends on them.
