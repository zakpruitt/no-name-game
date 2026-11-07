# The dash counter: Backlash and Ricochet

Kit grammar slot 9 (`docs/characters/kit-grammar.md` section 4), round 49. Smash-style: a counter that, pressed
as a strike is about to land, cancels it and answers harder.

## What it does

- **Trigger.** Space while a foe's strike is coming: its windup's last `WINDOW` (0.25 s) before contact, up to the
  strike frame, and the dash aimed within `ARC` (60 deg) of the attacker, the attacker within its strike's reach
  plus `REACH_PAD` (1.2 m). A dash with nothing coming, aimed away, or from behind is the plain dash: pressing it
  costs nothing.
- **Backlash** (KRRAK-SNAP!), every counter: the dash becomes the counter. He stops, turns to the attacker and is
  untouchable through the strike (`END` + `INVULN_PAD`, 0.67 s). A hitstop (`STOP` 0.1 s, 0.16 on a perfect, at
  x0.04), the drawn **parry flash** (violet: the tentacle curled round the weapon, a clash star, ink splatter), the
  attacker staggered (its strike is off) and **marked** (Reap's mark, `dark_fx.mark`). Then the tentacle wraps it
  (`WRAP` 0.1 s), swings it up over him (`LIFT` 0.26 s, 1.9 m) and slams it down 1.7 m in front of him (`SLAM`
  0.38 s) for `DAMAGE` 18, with a whip-crack arc and a brush ring; he is free at `END` 0.52 s. +6 Awakening.
- **Perfect counter:** pressed in the last `PERFECT` (0.1 s). Backlash plays the same, +10 Awakening, then the
  **counter breaker window** opens (one ending, violet, the shared window rhythm: `hero_leap` with
  `VOID_ELEMENT.BREAKERS.CB`): he leaps with the tentacle on the attacker alone.
- **Ricochet** (KA-SPLATT!), H in that window: the attacker is hurled at 24 m/s into the nearer of the nearest
  living foe and the nearest wall or pillar within 10 m of it, for 30 (x1.5 on the window's own PERFECT), x2.5 on a
  wall (75; the foe it hits takes thrown_foe's 0.7 of it), and is bound where it lands (`floor_bind`, 1.6 s, violet
  tendrils). Neither in reach: it flies 7 m along his aim and lands. The landing is a breaker landing like the
  others: `breakers_landed` goes up, so `impact_frame` fires the breaker spectacle (dark family) and a wall splat in
  the next second gets its drawn wall star.
- **Every spar foe's windup is counterable** (spar audit 2026-11-07, `tests/spar_check.gd`): the telegraph shows
  before the window opens for minion 0.35 s, rogue 0.25 s (its windup 0.45 to 0.5 s for this), shield 0.45 s, warrior
  0.55 s; `WINDOW` stays one 0.25 s for all of them. `--spar=archer|mage` shoot bolts to parry. A foe a hold has (a
  carry, a bind, a cube, a hook) never strikes (`enemy.held()`), so nothing needs countering mid-hold.
- **Bolts** (`projectile.gd`) count too: a bolt inside the window and in his way, the dash aimed at it, is parried
  back at its shooter (x1.6 speed, x2 damage, hits foes only). No Backlash or window: the shooter is far off.

Best situation (kit-grammar "every combo needs a best situation"): Ricochet wants a wall or a crowd near the
attacker; in the open it only lands for its base.

**Gallows** (round 53, `env_flourish.gd`; the `gallows` Kit upgrade, on in the training room with pieces): with an
empty hook whose point is within `GALLOWS_REACH` 10 m of the attacker, Ricochet takes it there over any foe or wall
(the counter window brackets the hook, env_target CTX `gallows`; a wall or pillar the cursor chose wins). It flies
over the other foes, splats on the hook's wall at x2.5 x `GALLOWS_MULT` 1.3 (146 against the wall's 112), then
hangs under the hook bound for 2.5 s, the hook swinging with it ("SHNK-CLANK!"); any hit on it is a Snap and drops it.
Details in [env-pieces.md](env-pieces.md).

## Files

- `scripts/counter.gd`: static functions over the hero (the hero_*.gd pattern).
  - `find(hero, dir)`: the strike or bolt a dash along `dir` would counter now (`{foe, t, bolt, perfect}`).
  - `try_start()` (from `player._start_dash`), `start()` (the parry), `tick()` (State.DASH while `hero._counter`
    is set: wrap, lift, slam), `_slam()`, `_window()` (the leap), `cut()` (from `player._set_state` leaving DASH).
  - `ricochet()` (from `void_element.breaker_impact` on `counter`), `ricochet_target()`, `_ricochet_hit()` (bind).
  - `hint()`: the combo guide's SPACE Backlash row (and Ricochet next on a perfect), from `combo_guide._process`; no rows
    while Backlash plays (it takes no input).
- `scripts/counter_fx.gd`: `parry()` and `snap()`, the two designed sheets (`DESIGNED.extra_sheets`), prewarmed from
  `elements.prewarm`; classic flares and rings under `--fx=classic`. A perfect adds designed_breaker's speed lines.
- `tools/vfx_gen/gen_counter.py`: `parry_flash` (384 px, 3x2) and `snap_arc` (320 px, 3x2), void palette row.
- `scripts/enemy.gd`: `strike_in()` (game s until a melee windup's strike, slowed by a chill; -1 when none),
  `strike_reach()`.
- `scripts/player.gd`: `_counter`, `counters`, `counter_perfects`; the hooks in `_start_dash`, `_state_dash`,
  `_set_state`.
- `scripts/void_element.gd`: `BREAKERS.CB` (Ricochet) and the `counter` branch in `breaker_impact()`.
  `scripts/void_grab.gd` `seize()`: `only` (the entry's held foe, set by counter.gd, big or not).
- `scripts/training_dummy.gd`: the swinging dummy (below). `scripts/game.gd` `dummies_swing` (Settings "Dummies
  swing", saved under `[training]` only when on), `scripts/menu_screen.gd` the row.
- `scripts/move_list.gd`: Backlash and Ricochet rows (DARK). `scripts/comic_fx.gd`: Ricochet's word.
- `scripts/training_bot.gd`: the `counter` token and the `["counter", "D"]` string; `[counter] counters= perfect=
  ricochet=` at the end.

## The swinging dummy

The dummies never attack unless they swing: Settings "Dummies swing", `--swing` for one run, or
`training_dummy.swings` (the bot's `counter` string sets it on the first dummy for that string only, so the rest of
the bot's strings are not interrupted). A dummy at home with him in front of it (`SWING_RANGE` 2.8 m, `SWING_ARC`
60 deg) for `SWING_BEAT` 0.5 s winds up through `enemy._state_windup` (the telegraph ring fills over `SWING_WINDUP`
0.7 s), the bag rocking back `SWING_LEAN` 0.42 rad, and strikes for `SWING_DAMAGE` 4 (a spar foe's third of 12),
the bag snapping forward; again every `SWING_EVERY` 1.4 s while he stays. `--spar=` foes are counterable as they are
(every melee windup reports `strike_in()`).

## Invariants

- A dash that finds nothing is exactly the old dash (`try_start` returns false before any state changes).
- The attacker carries `thrown_foe.FLYING` while the tentacle has it (nothing else moves it); the slam or `cut()`
  takes it off, so Ricochet's throw (which refuses a flying foe) can take it.
- `CB` keeps the shared window rhythm (rhythm_check walks every BREAKERS entry).

## Tests

- `godot --headless --path . -s tests/counter_check.gd` (in `agent.sh check`): the swing hurts 4, the window's
  timing (none at 0.5 s, a counter at 0.2, a perfect at 0.06), not aimed (away, 80 deg) vs 45 deg, the guide's hint,
  a plain dash with nothing coming, i-frames, the stagger and mark, the lift and slam, no window on a plain counter,
  the perfect's window holding the attacker alone with one ending, Ricochet landing and binding, a parried bolt.
- Autotest: the last string `counter D` lands Ricochet (`breakers=` and `endings_n=` count CB).
- `counter_check` `_gallows` (round 53): in the room with pieces, the window brackets the pillar's hook, Ricochet hangs
  the dummy on it (bound, the hook swinging, up under its point), the splat x1.30 the same counter's with the flourish
  off, a hit on it a Snap that lets it go, the hook empty again; a pillar the cursor chose wins over the hook. Bot
  string `hook counter D` in the room with pieces.
- Film: `godot --path . -s tests/string_film.gd -- --from=N --to=N --dir=counter` (N = the counter string's index).

## Tuning

`counter.gd`: `WINDOW`, `PERFECT`, `ARC`, `REACH_PAD`, `STOP` / `PERFECT_STOP`, `WRAP` / `LIFT` / `SLAM` / `END`,
`LIFT_Y`, `SLAM_AHEAD`, `DAMAGE`, `RICOCHET_*`, `BIND_TIME`; `BREAKERS.CB.damage`. `counter_fx.gd`: `PARRY_SIZE`,
`PERFECT_SIZE`, `PARRY_TIMES`, `SNAP_SIZE`. `training_dummy.gd`: `SWING_*`.

Round 54 cool pass 3 (combo-cool3): the parry is sharper and lands like a hit, window timings unchanged. A `parry_glint`
flick over the clash in real time (`counter_fx.glint`, `GLINT_*`), the attacker's weapon knocked out of its grip and
spinning off on an arc away from him to clatter down (`counter_fx.blade_off`, `parry_blade` sheet, `BLADE_*`), a
harder camera punch (`counter.PUNCH` 0.86 / `PUNCH_PERFECT` 0.78) and a `camera_rig.jolt` along the blow (`JOLT*`;
existing camera APIs only). Ricochet's throw draws the dark comet trail behind the hurled attacker
(`RICOCHET_TRAIL` 0.6 s, `mid_beats.trail`). Counters for checks: `counter_fx.glints` / `blades` (cool3_check).
