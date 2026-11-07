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
- **Impact frame.** Saved for slams and kills (feel audit 2026-11-04 item 1:
  on every ender it flipped about every 1.2 s): a combo breaker's landing
  (`impact_frame` watches the hero's `breakers_landed`, `slam()`), kills, and
  hitstops of `IMPACT_STOP` 0.3 s or more (above every ender's ~0.23 s and
  Awakening's 0.25 s: the last kill's slow motion), at most one per
  `IMPACT_GAP_MS` 900 so a string flips once. These flip the 3D view for a few real
  frames into a high-contrast negative with a dark vignette, then fade. With
  `Game.reduce_flashing` the negative and the kill frames are dropped and only
  a soft vignette pulse remains. The vignette leans with the last heavy blow
  (`Game.last_hit_dir`, set by `camera_rig.kick`; its middle moves
  `DIR_SHIFT` back against it, so the ink piles up where the blow went) and
  its ink takes a dark tone of his element (`Game.hero_hit_color()`).
- **FOV punch.** Enders (`camera_rig.punch`), frames that fire on a freeze and
  kills narrow the view a few degrees on top of the push-in (`fov_punch`,
  `FOV_ENDER` 2.5, `FOV_KILL` 1.5, capped at `FOV_MAX` 5), springing back.
- **The trail swells.** Deep in a chain and right after a heavy hit the
  weapon ribbon reaches further, lives longer and fills out.

- **Comic hit readouts** (round 29, `Game.comic_style`). Damage numbers are
  one inked number per foe (`scripts/comic_number.gd`): a hit within
  `MERGE_S` of that foe's last adds into it, and it pops again. It steps
  aside off the combo-name callout (and its PERFECT line), live words and the
  breaker prompt (`ComicNumber.dodge`, `ComicFx.text_blocks`). A foe's hit
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
4. `impact_frame.flash(strength, kill, blow, element)` records the start tick; `current()`
   is the strength for `IMPACT_HOLD` then a linear fade over `IMPACT_FADE`;
   `_process` pushes it to the shader and hides the rect at 0. Frames closer
   than `IMPACT_GAP_MS` to the last are dropped. The shader reads the screen
   (`hint_screen_texture`), maps luminance to ink/paper through a smoothstep,
   mixes that in by `strength * invert`, and darkens the edges by `strength`
   towards `tint`, round a middle shifted by `dir`. The hero kicks the camera
   just after the `Game.hitstop` that fired the frame, so through
   `IMPACT_HOLD` the frame re-reads `Game.hit_dir_screen()` once a newer kick
   lands (`lean`).
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
| `IMPACT_STOP` 0.3, `IMPACT_FULL_STOP` 0.5, `IMPACT_MIN` 0.45, `IMPACT_KILL` 0.4, `IMPACT_SLAM` 0.85, `IMPACT_SLAM_PERFECT` 1.0 | impact_frame.gd | which stops flash and how hard; breaker landings |
| `IMPACT_HOLD` 0.05, `IMPACT_FADE` 0.09, `IMPACT_GAP_MS` 900, `REDUCED_SCALE` 0.45 | impact_frame.gd | frame timing, rate limit, reduce-flashing strength |
| `DIR_SHIFT` 0.2, `TINT_MIX` 0.5, `TINT_DARK` 0.5 | impact_frame.gd | how far the vignette leans; how much of his colour its ink takes |
| `FOV_ENDER` 2.5, `FOV_KILL` 1.5, `FOV_MAX` 5, `FOV_RETURN` 6 | camera_rig.gd | FOV punch (degrees) on enders / big freezes, kills, cap, spring |
| `CHAIN_GROW` 0.1, `HIT_GROW` 0.25, `LIFE_GROW` 0.6 | weapon_trail.gd | ribbon swell per tier / per hit weight / its life |

## Testing

- `godot --headless --path . -s tests/hitstop_check.gd`: shape, opener, flat
  focus, overlap, `end_slowmo`.
- `godot --headless --path . -s tests/camera_feel_check.gd`: push-in cap and
  spring, roll sides and cap, kick cancel and spring, the Game hooks, shake 0,
  FOV punch (ender, cap, spring, kill), the blow's screen direction and the
  frame leaning with a kick after it fired.
- `godot --headless --path . -s tests/impact_frame_check.gd`: hold/fade
  timing, strengths, gap, focus exclusion, kills, reduce flashing, the lean
  and tint (and plain centred ink without them).
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

## Camera and readability (round 32, feel audit 2026-11-04)

- Training camera `camera_rig.offset` (0, 10, 7.5), `FOV` 36 (was (0, 13, 9.5), 42): the chibi is about twice
  the size on screen. In a breaker hang (`State.LEAP`) the camera pushes in `HANG_ZOOM` 0.12 and its follow
  point rises with his model (`LIFT_FOLLOW` 0.75, `LIFT_MAX` 4 m), easing back after the slam.
  Round 36 moved it out again (13 m, FOV 37, aimed at his chest, fight framing, `HANG_ZOOM` 0.16): see `camera.md`.
- The hero has a paper rim past his ink (`heretic_rig._add_rim`, `shaders/hero_rim.gdshader`), drawn after
  the effects at render_priority 100, so his silhouette shows through bolts, rings and words.
- Words: one live at a time, never the same generic word twice in a row, placed round the contact point
  (`ComicFx.SPOT_RINGS` 12 / 55 px, `SPOT_ENOUGH` 24).
- Awakened: the swoosh draws only its inked outer band (`Fx.AWAKEN_SWOOSH_BAND` 0.72), the second ender arc is
  dropped, and the weapon trail's swell caps at `AWAKEN_SWELL_MAX` 0.12 (`SWELL_MAX` 0.35 otherwise) at
  `AWAKEN_ALPHA` 0.6.


## Round 51: weight climbs through the string (fluidity lane)

`hero_moves.hit_stop()` / `cam_tier()` (called from `player._do_hit`): the opener keeps `HITSTOP_OPENER` 0.8; a mid
holds at most `MID_STOP_MAX` 0.09 s (`BIG_MID_STOP_MAX` 0.1 for a `big` move) however high its tier, and its camera
punch is tier 1 at most; an ender (`is_ender`: a BREAKERS leap, `CHAIN_ENDERS` L3, a tier-3 combo) holds at least
`ENDER_STOP_MIN` 0.11 with its full tier punch. Before, Rockslide / Hailstorm / Molten Palm froze 0.12-0.145 s,
longer than the breaker leaps. A spirit echo cast landing more than `CAST_STOP_GAP_MS` 90 ms after the last stop
takes `spirit_echo.CAST_STOP` 0.03 s, so a whiffed blade's cast is not a contact at x1.00. See
`docs/feel-audit-2026-11-07.md`.
