# Combo breakers

## What it does

A combo breaker is a timed finisher hanging off a combo ender. When the ender connects
(`_connected`; a whiff just plays out), the heretic leaps up and back with his tentacles on
what the string hit, a timing cue rings the landing, and the game drops into slow motion.
Right click (or L, for a breaker with an `alt`) inside the window dives him onto the zone and
slams what he holds; within `perfect` of the sweet spot it's a PERFECT (frame freeze, x`perfect_mult`,
more Awakening). Too early locks it out; no press floats him down; a dash in the hang calls
it off.

Which enders have breakers, and what each slam does, is the heretic's kit:
`VOID_ELEMENT.BREAKERS`, described in [void-element.md](void-element.md) (Grounded, Worldbreaker /
Cold Front, Avalanche, Meteor Fall, Collapse, Maw, Abyss). This doc is the shared machinery.

### Movement in the strings

Moves can leave the floor (`MOVES` keys, `player._hop()`; only the model lifts, the body stays):
- `hop` = [start, end, height]: an arc between those fractions of the move (L2, L3, EC, DL).
  A move started in the air comes down by its first hit (`land` overrides).
- `air`: holds the height the move started at; `climb` adds metres by its first hit (AL1
  climbs off Updraft Lash, IJ vaults 2.4 m onto the frost spear). The climb stops at `AIR_MAX_HEIGHT`.
- Landing from a hop is a slam that grows with the fall (`_land_slam()`, `SLAM_FULL_HEIGHT`,
  `SLAM_SCALE`); a move that starts in the air deals +`PLUNGE_PER_M` per metre (`plunge_mult()`).
- Moves started in the air home in on the nearest airborne foe (`_air_home()`, `AIR_HOME_RANGE`, `AIR_HOME_MAX`).
- Air dash: dashing out of `AIR_DASH_FROM` (AL1) at least `AIR_DASH_MIN` up keeps his height, once
  per trip up (`AIR_DASHES`), and cuts with a spectral axe (`_air_dash_cut()`, [spirit-casts.md](spirit-casts.md)).

## Files

- `scripts/void_element.gd`: `BREAKERS` (per breaker keys over the shared `_WINDOW` defaults, merged by
  `entry()`), `breaker_impact()` (each slam's effect), `breaker_element()`.
- `scripts/player.gd`:
  - `_breaker_for(id)`: the merged entry when the move has one; `_do_hit` starts the leap at the entry's `leap`.
  - `_start_leap()`: state `LEAP`, the zone `zone` m ahead (`_clear_ahead`), `void_grab.seize()`, `_brk_aim()`
    (`at_spot` breakers land `short` of `void_grab.dark_spot`; Meteor Fall on the held foe).
  - `_state_leap()`: phase 0 rise / hang / cue / window / press, phase 1 dive (comet trail `_comet()`),
    phase 2 float down. `_breaker_pressed()` (heavy, L for `alt`, or the bot at `sweet`).
  - `_start_dive()`, `_breaker_impact()`, `_breaker_callout()`, `_leap_dash_out()`, `_end_leap()`.
  - `breaker_window()`: what the prompt reads. `breakers_landed`, `breaker_perfects`: the autotest's counts.
- `scripts/breaker_cue.gd`: the floor cue: a target ring and a closing ring that meet at `sweet`; `lock()`, `hit(perfect)`.
- `scripts/breaker_prompt.gd`: the timing circle up and to his left (the combo guide is on his right; `OFFSET`),
  filling to the sweet spot with the button(s) and the breaker's name; on the player's own CanvasLayer.
- `scripts/comic_comet.gd`: the inked dive streak and landing star (`beat()` from `player._comet()`; the comet hangs off the model as the `comic_comet` meta).
- `scripts/breaker_quake.gd`: the barbaric look: `war_cry()` as the window opens, `crater()` on landing (not for
  `press` / `at_spot` breakers, which have their own), the element vents.

## How it works

1. The ender's hit lands with `_connected` and the move reaches `leap`: `_start_leap(id, entry)`.
2. Phase 0: he rises `height` m over `rise` s, hopping `back` m; at `cue` s the cue spawns on the zone.
   At `open` the window opens: `Game.hitstop()` at `BREAKER_FOCUS` time scale, camera push to
   `BREAKER_FOCUS_ZOOM`, heartbeat and war cry.
3. Presses: one in the first `BREAKER_SPILL` s is the ender's own mash (ignored); one within
   `BREAKER_EARLY` before `open` is held and fires as it opens; earlier locks it out (`_brk_ended = "lock"`).
4. A press in `open..close` is the dive: `alt` merges over the entry, the slam's set-up runs (cubes freeze,
   the maw opens, the abyss sinks, the press aims the crush), a PERFECT freezes `BREAKER_PERFECT_STOP`.
5. The dive takes `dive` s; `_breaker_impact()` calls `VOID_ELEMENT.breaker_impact()` with what the tentacles hold,
   cracks the floor, shakes, adds `awaken` / `awaken_perfect`, names the breaker and ends the leap.
6. No press by `close`: `_brk_ended = "miss"`, the held foes drop, he floats down over `fall` s.

### Look

The breaker draws flat and inked: the cue is always `crisp` (a paper target ring that turns gold in the
window and a fat closing ring in the breaker's colour, each between two ink bands, rebuilt every frame so
the band keeps its width as it closes), the war cry is radial speed strokes round him and one inked hoop
under him (no shell, no glow dots, no smoke), and the dive is `scripts/comic_comet.gd`: one fat streak back
along his path (ink, element colour, hot core, at least `MIN_TAIL` m long because a tentacle breaker barely
moves him) that ends, when `comet()` stops being called, in a held-frame impact star at his feet
(`STAR_HOLD` steps). `Fx.ring` there is an inked floor hoop on twos.

## Invariants

- `leap` must be at or before the move's `cancel`, or the next input wins first.
- Every breaker is a tentacle breaker (`_WINDOW.tentacle`): `seize` / `seized_tick` / `release_seized` /
  `slam_seized` in `void_grab.gd` must all see the same held set.
- The autotest bot never dashes out of a hang (its dodge presses would throw the breakers away) and presses at `sweet`.

## Tuning

- `VOID_ELEMENT._WINDOW`: `rise`, `height`, `back`, `zone`, `cue`, `open`, `sweet`, `close`, `perfect`, `dive`,
  `perfect_mult`, `fall`. Per breaker overrides in `BREAKERS` (`damage`, `leap`, `awaken`, `awaken_perfect`, `height`, `short`, ...).
- `player.BREAKER_FOCUS` (0.6), `BREAKER_FOCUS_ZOOM` (0.86), `BREAKER_PERFECT_STOP` (0.07), `BREAKER_SPILL` (0.12), `BREAKER_EARLY` (0.08).

## Extending

New breaker: add the ender to `VOID_ELEMENT.BREAKERS` (`names.spirit`, `erupt`, the keys its slam reads), add its
slam to `breaker_impact()`, add a row to `scripts/move_list.gd`, and put a string that reaches it in `main.BOT_STRINGS`
so the autotest lands it.

## Testing

- `godot --headless --path . -s tests/void_arm_check.gd`: the breakers' timing, holds and slams (PASS/FAIL).
- `godot --headless --path . -s tests/prompt_follow_check.gd`: the prompt stays on the hero.
- `godot --headless --path . -- --autotest`: prints `[autotest] combo_breaker #N <id> perfect=` per breaker and
  `breakers= perfect_breakers=` on the done line.
- Windowed: `godot --path . -s tests/breaker_prompt_preview.gd` → `user://breaker_prompt.png`; `tests/element_shots.gd`
  for each slam.

## Gotchas / open questions

- Tuned headless and in stills; the window's length and the slam's weight still want a hand play-test.
