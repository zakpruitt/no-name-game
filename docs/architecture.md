# Architecture: how Awaken's code works

The map of the code for whoever works on it next (person or agent). `CLAUDE.md` is the short index;
`docs/features/*.md` go deep on one feature each. This file is the middle: the shape of the whole, the data
flow of a hit, and the patterns every file follows. Written 2026-11-08 against the cleanup3 branch.

## 1. What runs

One scene, `scenes/main.tscn`, holds one node with `scripts/main.gd`. Everything else is built in code at
`_ready`: the room, the hero, the camera rig, the HUD, four training dummies, an optional spar foe, and the
autotest bot when `--autotest` is on the command line. One autoload, `Game` (`scripts/game.gd`), carries the
global combat state. There is no title screen, no run, no save beyond `user://settings.cfg`.

```
Game (autoload)         hitstop / time scale, combo count + style rank, Awakening meter, sfx + music,
                        settings, the input map (bound in code), the impact frame CanvasLayer
main.gd                 builds the room (rooms.gd data -> env_piece.gd nodes, env_target.gd structures),
                        spawns player / camera_rig / hud / dummies / spar / bot, shows string damage
player.gd               the heretic: state machine + fields; the work lives in static-function files:
  hero_moves.gd           MOVES, COMBOS, routing (void_route), hops / air / plunge, the guide's rows
  hero_input.gd           press buffer (two slots), cancel points, hit-confirm, dash cancel, aim
  hero_leap.gd            breakers: leap, hang, window, press, dive, impact
  hero_awaken.gd          the Awakening buff and drain
  hero_fx.gd              swoosh, spirit casts, combo callout, ender camera kick, rank-up, last kill
  counter.gd              the dash counter (Backlash) and Ricochet
void_element.gd         right click: every element move, crossover, breaker landing and the state matrix
void_grab.gd/arm/tendril  the tentacle: grab, hold, swing (R), the arm's weapon shapes, the ribbon
thrown_foe / floor_bind / frost_spear   foe states that outlive a move: flying, bound, the planted spear
enemy.gd                foe AI + hit reactions; training_dummy.gd extends it (never dies, walks home)
spar.gd / enemy_types.gd   one live foe of a kind (--spar=), the kinds' data
camera_rig.gd           distance, aim, fight framing, hit zoom / kick / roll, breaker hang framing
hud.gd, combo_guide.gd, breaker_prompt.gd, pause_menu.gd, move_list.gd   the UI
designed_*.gd           the effects: authored flipbook sheets (assets/vfx/designed) on quads and strips
fx.gd, elements.gd, fx_palette.gd, fx_beat.gd, comic_*.gd, dark_fx.gd   effect dispatch, palettes, timing,
                        per-move looks (gameplay-fused ones: harpoon_gather, lava_leash, collapse_spit, ...)
```

Line counts after the cleanup are in `docs/cleanup-2026-11-08.md`.

## 2. The pattern: a node and its static-function files

`player.gd` declares every field of the hero (state, timers, the move playing, the press buffer, breaker
state, counters the HUD and bot read) and runs the state machine in `_physics_process`:

```gdscript
match state:
    State.MOVE: _state_move(delta)
    State.ATTACK: _state_attack(delta)
    State.DASH: _state_dash(delta)
    State.LEAP: HERO_LEAP.tick(self, delta)
    State.SWING: _void.travel_tick(delta)
```

Each job is a `RefCounted` file of `static func f(hero: CharacterBody3D, ...)` that reads and writes the
hero's fields through the argument (`hero._move`, `hero._buffered`). Other scripts and the checks call them
through the hero's preload constants: `hero.HERO_INPUT.cancel_point(hero)`, `hero.HERO_MOVES.void_route(...)`.
`void_element.gd` is the same pattern for right click, and `foes.gd` holds the shared foe queries
(`FOES.near()`, `flat()`, `sorted_near()`).

Why: the checks, the bot and void_grab read ~60 hero fields directly, so the state stays on the node and
the logic moves out by subject. The helper files never preload `player.gd`, so there is no preload cycle;
they reach the enum through the instance (`hero.State.LEAP`).

The same shape repeats for foes: `enemy.gd` is the node, `foe_lean.gd` a modifier, `thrown_foe.gd` /
`floor_bind.gd` nodes attached while a state lasts, with `static` entry points (`THROWN.launch(e, ...)`,
`BIND.holds(e)`).

## 3. Data tables, not code paths

Tuning lives in dictionaries with one-line comments, and code reads them:

- `hero_moves.MOVES[id]`: `anim`, `damage`, `range`/`arc`, `hits` (fractions of the clip), `cancel`, `end`,
  `lunge`/`decay`, `knockback`, `launch`, `stop` (hitstop), `shake`, `big`, `hop [start, end, height]`,
  `air`, `climb`, `speed`, `confirm`, `brake`, `thrust`. Timings are fractions of the animation's length,
  so a `speed` change keeps everything in sync. `effective_move()` returns a retimed copy per press.
- `hero_moves.COMBOS[id]`: `name`, `input`, `tier` (1 string, 2 heavy route, 3 finisher).
- `void_element.AFTER` / `LIGHT_AFTER` / `DASH_MOVE` / `CHAIN` / `ELEMENT_OF` / `FORM_OF`: the routing
  tables. `AFTER[from]` is what right click does off `from`; `LIGHT_AFTER[from]` where L goes when it does
  not continue the axe chain; `ELEMENT_OF[id]` the element a tentacle move swings.
- `void_element.BREAKERS[id]`: a breaker per ender (`erupt`, `damage`, `leap`, `awaken`, `names`, the flag its
  landing reads, an optional `alt` second ending). `entry(id)` merges it over `_WINDOW` defaults (cached).
- `void_element.RULES` / `IMPROV` / `IMPROV_UPGRADE`: the element matrix (section 6).
- `kit_slots.HERETIC`: the kit grammar's card: slot -> move id + input; `KitSlots.open(id)` gates demoted
  moves behind `Kit.has()` (`--kit=full`).
- `enemy_types.TYPES`: a foe kind's model, hp, speed, attack kind and timings.
- `rooms.ROOM_DEFS` / `env_piece.PIECES`: the room as data: placements, each noun's shared rule and states.
- `fx_palette.PAL`: five tones per element for the drawn effects; `designed_*.SHEETS`: sheet name -> columns,
  frame times.

`tests/move_list_check.gd`, `guide_check.gd` and `kit_check.gd` walk these tables against `void_route()` so
the pause menu, the combo guide and the card can never disagree with the routing.

## 4. One hit, end to end

1. **Press.** `hero_input.read_input` puts "light" / "heavy" into the two-slot buffer (`_buffered`,
   `_queued`, `BUFFER_MS` 300). Dash and R have their own timers.
2. **Routing.** In MOVE, or in ATTACK once `progress()` passes `cancel_point()` (the table's `cancel`, pulled
   back toward the last hit once the move connected: hit-confirm), `_start_attack(_next_move(kind))`.
   `_next_move` is `hero_moves.routed()`: the frost-spear vault check, then the pure `void_route(kind, from,
   attacking, chain, post_dash)`. The combo guide calls the same function with made-up states to look one
   press ahead, so what it shows is always a real route.
3. **The move.** `_start_attack` copies the MOVES entry (`effective_move`), sets `_anim_mult`, aims (soft
   lock-on, mouse steer), tells the tentacle (`_void.on_move`) and plays the clip. `_state_attack` lunges,
   hops (`hero_moves.hop`), and fires `_do_hit()` as `progress()` crosses each `hits[i]`.
4. **The hit.** `_do_hit` swooshes, then for every living foe in `range`/`arc`: `e.take_hit(dmg, kb, launch,
   big)`, `Game.register_hit(move_id)`. On the move's first active frame it also fires the spirit cast
   (`hero_fx.cast`) and, for a tentacle move, `VOID_ELEMENT.fire(hero, id, fwd)`, which does the element's
   thing (an ice cube, a gale, the magma palm, a grab) and returns how many it touched.
5. **Feel.** If anything connected: the combo callout, the hit sound, `Game.hitstop(hero_moves.hit_stop(...))`
   (opener snappier, mids capped, enders longer), `Game.shake`, and for enders a camera push
   (`hero_fx.camera_hit`). `Game.hitstop` scales `Engine.time_scale` through `_stops` with an eased tail,
   raises `hit_weight` (the trail swells), and fires the impact frame.
6. **The foe.** `enemy.take_hit` applies poise, launch and knockback, then `_hit_reaction`: squash per kind,
   lean along the knockback, tint flash, crowd hits staggered `WAVE_STEP` apart; juggles hang at the apex and
   tumble, slams crater. The dummies do all of that and never die.
7. **The combo.** `Game.register_hit` bumps `combo_count` (2.2 s timeout), adds style (variety over
   repetition), feeds the Awakening meter by rank, and emits `combo_changed` for the HUD, the rank-up burst and
   the music layer.
8. **The breaker.** If the move is an ender with a `BREAKERS` entry and it connected, at `leap` the hero
   hands off to `hero_leap.start`: he rises with the tentacles on what the string hit (`void_grab.seize`), a
   cue rings the landing, the window opens in slow motion (`open`..`close` after take-off), right click dives
   (L takes `alt`), and the landing calls `void_element.breaker_impact(hero, b)`, which reads the entry's flag
   (`collapse`, `maw`, `meteor`, `cubes`, ...) and runs that ending. Perfect within `perfect` of `sweet`.
   `breaker_prompt.gd` draws the window from `player.breaker_window()`.

## 5. The tentacle

`void_arm.gd` owns the arm's weapon shapes (hand, axe, spear, hammer: `ComicLook.HERO_FORMS`) and swaps them
with an inked burst; `heretic_rig.gd` sways the tentacle and the skirt springs each frame as a skeleton
modifier. `void_grab.gd` is the gameplay: the grab (`GR`), the hold during a breaker (`seize`, with per-breaker
hold styles), the slam (`VS`), and R's swing on a pillar (`traverse`, State.SWING). `void_tendril.gd` draws
each tentacle as a ribbon strip with the designed skin shader.

## 6. Elements, crossovers and the matrix

L picks the weapon and its element (axe storm, spear ice, hammer magma; no weapon is dark); right click has
the tentacle do that element's thing. Strings that change element on the way are crossovers (`X*` ids:
Rockslide, Fault Line, Steam Burst, Storm Pitch, Galvanize, Hailstorm, Meltdown, Impale, Backdraft, Lava
Leash): the second move pays off what the first set up by reading the foe's state, never by routing on it.

States are metas on the foe with a real-time expiry (`mark(e, "buried")`, `ELEMENT_HOLD`): frozen, charged,
molten, bound, airborne, buried. `void_element.RULES` gives each state one payoff any element's hit cashes
(Shatter, Arc, Burst, Snap, Juggle, Crater); `improvise()` runs at the top of `fire()`, finds foes in the
move's own hit shape (`improv_reach`) in a paying state, and pays before the move body runs. The old
per-cell table (`IMPROV`) survives as Kit upgrades behind `--kit=full`.

## 7. The room and its structures

`main._build_arena` lays floor, walls and the near-edge rubble, then places the room's pieces from
`rooms.ROOM_DEFS[Game.room]` through `env_piece.place`. `env_target.gd` registers walls, pillars and torches as
structures and, during a move that can use one (Pinwheel, Slapshot, Ricochet, Collapse, Meteor Fall, Molten
Palm, Lava Leash, the pillar slam), picks one (`pick()` / `chosen()`), draws the bracket indicator, and lets the
cursor or right stick override. `env_piece.gd` gives each noun a shared rule and states (a keg bursts, a pool
freezes into a rink, a brazier spills); `env_flourish.gd` adds the heretic's flourishes on them (gallows, ice
rink, brazier spill) as Kit upgrades.

## 8. Effects

Every effect is a designed flipbook sheet since round 43: `python tools/vfx_gen/gen_*.py` draws PNG strips
into `assets/vfx/designed/`, `designed_fx.spawn(parent, sheet, at, size, element, frame_times)` plays one on a
camera-facing quad through `shaders/designed_*.gdshader` (palette ramp from `fx_palette`, erosion with a burn
line), and `designed_ink` / `designed_finish` / `designed_elements` / `designed_polish` / `designed_breaker` hold
the families (ground stamps and the tentacle skin; the Awakening and chain halos; ice and magma base moves;
the last polygon conversions; breaker landings and the banner). `fx.gd` is the dispatch layer the game calls
(`Fx.flash`, `Fx.outline`, `Fx.ring` -> `designed_ink.shock`), `fx_beat.gd` the shared timing (on-twos
stepping, beat frame times) and the pooled `stamp()`. The rules every effect is held to are in
`docs/features/fx-language.md`.

Per-move scripts that move foes (`harpoon_gather`, `lava_leash`, `collapse_spit`, `avalanche_topple`,
`abyss_rise`, `eruption_hurl`, `frost_shell`, `tentacle_haul`, `live_current`, `mid_beats`) are gameplay fused
with look: their `on_*` callbacks are the damage. They share the tentacle-choreography shape (a list of
per-foe grabs with a `t0`, the FLYING meta while they carry a foe, `_exit_tree` lets go).

## 9. Time

`Game` owns `Engine.time_scale`. Hitstop (`hitstop(duration, scale)`), breaker slow motion and training's
slow motion (`Game.slow`, T) all go through `_stops`; the slowest live stop wins each frame and eases back over
its tail. Anything that must run in real time (element state expiries, the impact frame, the hold timers)
reads `Time.get_ticks_msec()`; tweens on nodes run on scaled time, so a tween started in a hitstop outlives
its string unless it is on a real-time clock.

## 10. Testing

Everything is headless and scriptable: `bash tools/agent.sh check` runs every `tests/*_check.gd` (PASS/FAIL
SceneTree scripts) and the autotest twice (`--autotest`, and `--autotest --kit=full --room=pieces`), asserting
that every breaker, string, ending, kit slot and room verb landed. The bot (`training_bot.gd`) plays
`BOT_STRINGS` from fixed spots so runs are repeatable; its `[rhythm]` lines are the ms between hits that feel
tuning reads. Windowed tools (`string_film`, `element_shots`, `foe_shots`, `heretic_shots`) film the game
camera into `user://` for judging feel and look. See the `godot-headless-test` and `film-and-judge` skills.

## 11. Conventions

- Typed GDScript; warnings are errors (a `Variant` inferred from a Dictionary `get()` is a parse error that
  breaks the whole autoload chain).
- Scenes built in code; `.tscn` stays minimal. After adding assets or a `class_name`:
  `godot --headless --import --path .`.
- Tuning numbers in the tables with a one-line comment that says what the number does, not its history.
- A feature's doc in `docs/features/` changes in the same commit as the feature.
- Several agents work in parallel worktrees (`docs/agents.md`); land by fast-forward after the checks.
- Models face +Z; facing yaw is `atan2(dir.x, dir.z)`.
