# Impact feedback: hitstop shape, camera hit feel, impact frame, trail swell

Added in Round 27. Hero-agnostic layers of hit feedback that live in `Game`,
the camera rig, a screen-space CanvasLayer and the weapon trail. None of them
touch `player.gd` or `enemy.gd`: they hang off the calls those already make
(`Game.hitstop`, `Game.shake`, `Game.register_hit`, `Game.enemy_killed`).

## What it does

- **Hitstop has a shape.** A hit still freezes the game at its time scale, but
  instead of snapping back to full speed it eases up over the tail of the
  stop. A string's first hit is a shorter snap. Slow motion (the last kill's
  0.2, Cataclysm's 0.15) eases out over a longer tail. The combo breaker
  window (0.6) stays flat so its timing reads true. Overlapping stops each
  keep their own shape and the slowest wins, so a 0.03 hit inside the kill
  slow motion no longer holds everything at 0.03 for the rest of it.
- **The camera answers every hit.** Each hit pushes it in a hair, more as the
  chain climbs past `Fx.CHAIN_TIERS`, capped so a crowd hit doesn't dive.
  Heavy hits (shake past `ROLL_SHAKE`) roll it a touch, alternating sides.
  Kicks, the push-in and the roll chase targets that spring back in real
  time, so several hits in one frame blend instead of jittering.
- **Impact frame.** Big hits (a hitstop of `IMPACT_STOP` or more: enders,
  slams, breakers, the last kill) and kills flip the 3D view for a few real
  frames into a high-contrast negative with a dark vignette, then fade. With
  `Game.reduce_flashing` the negative and the kill frames are dropped and only
  a soft vignette pulse remains.
- **The trail swells.** Deep in a chain and right after a heavy hit the
  weapon ribbon reaches further, lives longer and fills out.

- **Comic hit readouts** (round 29, `Game.comic_style`). Damage numbers are
  one inked number per foe (`scripts/comic_number.gd`): a hit within
  `MERGE_S` of that foe's last adds into it, and it pops again. A foe's hit
  flash recolours its own ink (paper, then the hero's colour) instead of an
  overlay, which read as a soft blob over a crowd being zapped. The
  training readout is unchanged: it counts the hit signal, not the numbers.
  A flash outlives nothing: `Fx._overlay` takes its overlay off when the foe
  leaves the tree mid-flash, and the ink flash stops (`tests/fx_free_check.gd`).

## Files

- `scripts/game.gd`: `hitstop()` (shape + opener + `hit_weight`),
  `_update_hitstop()` (per-frame scale from the live stops), `end_slowmo()`,
  `shake()` (also rolls the camera), `register_hit()` (also pushes it in),
  `impact` (the impact frame), `hit_weight`.
- `scripts/camera_rig.gd`: `hit_zoom()`, `roll()`, `kick()`, `_process()`.
  Public API (`punch`, `kick`, `add_trauma`) unchanged.
- `scripts/impact_frame.gd`: the CanvasLayer (layer -1, under every HUD
  layer) with one screen-reading ColorRect; `flash()`, `on_hitstop()`,
  `current()`.
- `scripts/weapon_trail.gd` + `shaders/weapon_trail.gdshader`: `swell()`,
  per-sample life and swell, `UV2.x` in the shader.
- `tests/hitstop_check.gd`, `tests/camera_feel_check.gd`,
  `tests/impact_frame_check.gd`, `tests/trail_check.gd` (headless PASS/FAIL);
  `tests/impact_preview.gd` and `tests/trail_preview.gd -- --swell`
  (windowed looks).

## How it works

1. A hit calls `Game.hitstop(duration, time_scale)`. The impact frame is
   offered the raw duration first (`impact.on_hitstop`), then the opener
   discount applies (`combo_count <= 1` and a freeze: `HITSTOP_OPENER`), the
   hit weight is raised (`duration / HIT_WEIGHT_STOP`, freezes only), and the
   stop is appended to `_stops` as `[end_ms, ramp_ms, scale]` where `ramp_ms`
   is `HITSTOP_EASE` (freeze, scale < `SLOWMO_SCALE`) or `SLOWMO_EASE` (slow
   motion) of the duration, or 0 at or above `HITSTOP_FLAT_SCALE`. The time
   scale drops at once.
2. Every frame `_update_hitstop()` walks the stops: a stop inside its ramp
   contributes `lerp(scale, 1, ease(progress, HITSTOP_EASE_CURVE))`, a stop in
   its body contributes its scale, finished stops drop off; the minimum is
   the frame's `Engine.time_scale`. `end_slowmo()` clears them all. The hit
   weight decays by real ticks (process delta is time-scaled).
3. `Game.register_hit` calls `camera_rig.hit_zoom(1 + HIT_ZOOM_TIER * tier)`;
   `Game.shake(amount)` calls `camera_rig.roll(amount * ROLL_DEG)` from
   `ROLL_SHAKE` up. The rig's `_process` decays each target
   (`KICK_RETURN`, `HIT_ZOOM_RETURN`, `ROLL_RETURN`) and chases it with the
   value (`NUDGE_FOLLOW`), all in real time (`delta / time_scale`), then sets
   `camera.position = offset * _zoom * (1 - _hit_zoom) + _kick` and adds
   `_roll` to the trauma roll.
4. `impact_frame.flash(strength, kill)` records the start tick; `current()`
   is the strength for `IMPACT_HOLD` then a linear fade over `IMPACT_FADE`;
   `_process` pushes it to the shader and hides the rect at 0. Frames closer
   than `IMPACT_GAP_MS` to the last are dropped. The shader reads the screen
   (`hint_screen_texture`), maps luminance to ink/paper through a smoothstep,
   mixes that in by `strength * invert`, and darkens the edges by `strength`.
5. `weapon_trail._process` samples a new point with `swell()` =
   `CHAIN_GROW * tier + HIT_GROW * Game.hit_weight`: the tip is stretched by
   `1 + swell`, the life by `1 + LIFE_GROW * swell`, and `UV2.x = swell` goes
   to the shader (fuller crescent, wider hot edge, slower erosion).

## Invariants

- `Game.hitstop()` keeps its two-argument API; callers never see the shape.
- A stop never shortens another: the slowest live stop wins each frame.
- Breaker focus (`BREAKER_FOCUS` = 0.6 >= `HITSTOP_FLAT_SCALE`) must stay
  flat: the breaker window's real length is `window / focus`, so a ramp would
  end the slow motion before the window closes.
- The impact frame fires on the raw stop length, before the opener discount,
  so a big move's opening hit still gets its frame.
- Shader parameters can't be read back headless (no compile): tests read
  `impact_frame._invert`, not the material.
- The screen-shake setting at 0 switches the push-in and the roll off too.
- The trail's samples keep the swell they were drawn with (per-sample life
  and swell in `_points`), so a chain ending mid-swing doesn't snap the ribbon.

## Tuning

| Constant | Where | Changes |
|---|---|---|
| `HITSTOP_EASE` 0.3 / `SLOWMO_EASE` 0.45 | game.gd | fraction of a freeze / slow motion spent ramping back |
| `HITSTOP_EASE_CURVE` 0.45 | game.gd | `ease()` curve of the ramp (< 1 = ease-out) |
| `HITSTOP_OPENER` 0.8 | game.gd | how long a string's first freeze is, relative |
| `SLOWMO_SCALE` 0.1 / `HITSTOP_FLAT_SCALE` 0.5 | game.gd | freeze / slow motion / flat bands by time scale |
| `HIT_WEIGHT_STOP` 0.12 / `HIT_WEIGHT_DECAY` 4 | game.gd | a full-weight hit's stop; weight lost per real second |
| `HIT_ZOOM` 0.012, `HIT_ZOOM_TIER` 0.5, `HIT_ZOOM_MAX` 0.06, `HIT_ZOOM_RETURN` 7 | camera_rig.gd | push-in per hit, per tier, cap, spring |
| `ROLL_DEG` 2.2, `ROLL_SHAKE` 0.3, `ROLL_MAX` 2.5, `ROLL_RETURN` 9 | camera_rig.gd | heavy-hit roll |
| `NUDGE_FOLLOW` 40, `KICK_RETURN` 12 | camera_rig.gd | how fast nudges reach their targets / kicks spring back |
| `IMPACT_STOP` 0.1, `IMPACT_FULL_STOP` 0.25, `IMPACT_MIN` 0.45, `IMPACT_KILL` 0.4 | impact_frame.gd | which stops flash and how hard |
| `IMPACT_HOLD` 0.05, `IMPACT_FADE` 0.09, `IMPACT_GAP_MS` 240, `REDUCED_SCALE` 0.45 | impact_frame.gd | frame timing, rate limit, reduce-flashing strength |
| `CHAIN_GROW` 0.1, `HIT_GROW` 0.25, `LIFE_GROW` 0.6 | weapon_trail.gd | ribbon swell per tier / per hit weight / its life |

## Testing

- `godot --headless --path . -s tests/hitstop_check.gd`: shape, opener, flat
  focus, overlap, `end_slowmo`.
- `godot --headless --path . -s tests/camera_feel_check.gd`: push-in cap and
  spring, roll sides and cap, kick cancel and spring, the Game hooks, shake 0.
- `godot --headless --path . -s tests/impact_frame_check.gd`: hold/fade
  timing, strengths, gap, focus exclusion, kills, reduce flashing.
- `godot --headless --path . -s tests/trail_check.gd`: reach and life by
  tier and weight, old samples kept, weight decay.
- Looks (windowed): `godot --path . -s tests/impact_preview.gd` ->
  `user://impact_preview.png` (plain / full / mid-fade / reduced);
  `godot --path . -s tests/trail_preview.gd -- --swell` -> `user://trail_preview.png`.
- `-- --autotest` runs all of it under the bot.

## Gotchas / open questions

- Headless timers drift from real time; the checks wait on
  `Time.get_ticks_msec()`, which is what the stops use.
- `Game._process` zeroes `combo_count` when `_combo_timer` is 0, so a test
  that sets `combo_count` by hand must also set `_combo_timer` (or call
  `register_hit`).
- The impact frame's full negative is stark; `IMPACT_MIN` keeps enders mild
  and only quarter-second stops hit full strength. Judge it windowed.
- Feel numbers (ease curve, roll degrees, swell) are first guesses; none of
  it has been hand play-tested yet.
