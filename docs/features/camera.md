# Camera: distance, aim, fight framing, hand-tune flags

## What it does

The training camera looks down at the hero from 53 degrees, far enough out that the four dummies and a foe
thrown off them stay in frame through a string, and close enough that the chibi reads (about 140 px tall at
1080p). It aims at his chest rather than his feet so the pile in front of him sits mid-screen instead of
under the HUD. When a throw or breaker spreads the foes he is hitting, it eases out and leans towards them,
then drifts back slowly once they go quiet. In Meteor Fall's beats (the throw into the walls and the drag into
the pile) it pulls out further and faster, then comes back in for the dive. Hits, enders, hangs and freezes still nudge it
(`impact-feedback.md` has the per-hit feel).

## Files

- `scripts/camera_rig.gd`: everything here. `cam_overrides()` (flags), `_frame_fight()` (framing),
  `_process()` (follow, lift, every nudge, final position), `punch()` / `kick()` / `hit_zoom()` / `roll()` /
  `fov_punch()` (called by game.gd, player.gd, hero_leap.gd, hero_awaken.gd, impact_frame.gd).
- `tests/camera_feel_check.gd`: the numbers below (headless, PASS/FAIL).

## How it works

1. The follow point chases the hero (`follow_speed`), raised `AIM_HEIGHT` (0.8 m), plus the hang lift
   (`LIFT_FOLLOW` of his model's height while in State.LEAP) and the framing lean.
2. `_frame_fight()` collects foes in `"enemies"` with `last_hit_ms` within `FRAME_HIT_MS` and `FRAME_RANGE`
   of him. The lean is `FRAME_LEAN` of the way to the middle of their box (heads counted as floor that far
   up-screen), capped at `FRAME_LEAN_MAX`. The zoom-out is solved in camera space at the rest distance: a point
   at side offset `s` and depth offset `z` fits `|ndc| <= FRAME_SAFE` once `f >= (|s| / (FRAME_SAFE * tan(half
   fov)) - z) / dist`; the largest `f` over feet and `FRAME_HEAD` of every foe and the hero, capped at
   `frame_max`. In a hang only the lean applies, except in the beats (below).
3. `_frame` eases out at `FRAME_OUT` and back at `FRAME_BACK` (real time, measured with `Time.get_ticks_usec()`);
   the lean likewise.
3b. **Breaker hang pull-out.** While the hero's `_brk_phase` is `BEATS_PHASE` (3: Meteor Fall between the press
   and the dive) the framing counts foes hit in the last `HANG_FRAME_HIT_MS` within `HANG_FRAME_RANGE`, leans up to
   `HANG_LEAN_MAX`, and solves the same fit. The hang push-in and the focus punch (`squeeze` = `(1 - HANG_ZOOM *
   _hang) * _zoom`) hold until the foes need more room than they leave: `_frame_to = max(1, min(need, frame_max *
   HANG_FRAME_GAIN) / squeeze)`, so the cap is on the distance seen. In a hang `_frame` and the lean ease at
   `HANG_FRAME_OUT` / `HANG_FRAME_BACK`; on the dive (phase 1) `_frame_to` is 1 again, under the dive's own
   `punch()`. The rise and the timing window (phase 0) keep the push-in.
4. `camera.position = offset * _frame * _zoom * (1 - _hit_zoom) * (1 - HANG_ZOOM * _hang) + _kick`, with
   `offset = VIEW_DIR * dist`; `camera.fov = fov - _fov`.

## Invariants

- Every metre-sized nudge is scaled by `dist / REF_DIST` (kicks, `KICK_MAX`, the shake offset), so the same
  blow moves the frame as far at any distance. Fractional ones (push-ins, hang) scale on their own.
- `punch()` deepens the callers' zooms by `PUNCH_GAIN` (their numbers were tuned at 12.5 m); callers still pass
  the old values.
- A fan of dummies 2.2-3.2 m in front of him fits at rest: the framing never moves the camera in a normal string.
- The camera reads the hero's `state`, `model` and `_brk_phase` (no calls from hero_leap.gd); a breaker that wants
  the pull-out runs its beats in phase 3.
- Shot tests copy the rest view from `camera_rig.rest_view(args)` (`load()` it: a `-s` script can't preload a file
  that names Game), so their sheets match the game camera and its `--cam-*` flags.
- Game reads `camera_rig.global_position` for the blow direction on screen (`hit_dir_screen`): the aim height
  shifts it up the same for both points, so the direction is unchanged.

## Tuning

| Constant | Value | Changes |
|---|---|---|
| `DIST`, `FOV`, `VIEW_DIR` | 13 m, 37 deg, (0, 0.8, 0.6) | rest distance and lens; +1 m is about -10 px hero, +13% floor |
| `AIM_HEIGHT` | 0.8 m | where the screen centre sits on him |
| `FRAME_MAX`, `FRAME_SAFE`, `FRAME_HEAD` | 1.25, (0.8, 0.72), 1.6 m | how far out, how much of the screen, foe height |
| `FRAME_HIT_MS`, `FRAME_RANGE` | 2200 ms, 11 m | which foes count as the fight |
| `FRAME_OUT`, `FRAME_BACK` | 2.5, 0.6 /s | ease out, slow return |
| `FRAME_LEAN`, `FRAME_LEAN_MAX` | 0.6, 2.5 m | lean towards the fight |
| `HANG_ZOOM` | 0.16 | breaker hang push-in (0.12 at 12.5 m) |
| `HANG_FRAME_GAIN` | 1.6 | beats cap: `frame_max` x this (x2.0, 26 m, hero ~70 px; an uncapped two-wall throw wants ~x3.5) |
| `HANG_FRAME_OUT`, `HANG_FRAME_BACK` | 12, 4 /s | beats ease out (90% in 0.19 s; the throw is ~0.28 s), dive return |
| `HANG_FRAME_RANGE`, `HANG_FRAME_HIT_MS`, `HANG_LEAN_MAX` | 22 m, 4000 ms, 5 m | who counts in the beats, lean |
| `PUNCH_GAIN`, `HIT_ZOOM`, `HIT_ZOOM_MAX` | 1.25, 0.014, 0.07 | enders / per-hit push-in at the wider distance |

Measured at 1080p (16:9, `camera_feel_check`): round 28 (0, 13, 9.5) FOV 42: 105 px, 396 m2 of floor;
round 32 (0, 10, 7.5) FOV 36: 167 px, 166 m2; round 36 13 m FOV 37 aimed 0.8 m up: 140 px, 222 m2 (+34%),
and at full framing (x1.25) about 112 px.

**By hand:** `godot --path . -- --cam-dist=15 --cam-fov=38 --cam-frame=1.3` (`--cam-frame=1` turns the framing
off). The rig prints `[camera] dist= fov= frame_max=` when a flag is given.

## Testing

- `godot --headless --path . -s tests/camera_feel_check.gd`: hero px and floor area vs round 32, aim at his
  chest, flag parsing, `PUNCH_GAIN`, a foe hit 9 m out pulls the camera out (capped) and on screen, a dummy in
  front doesn't, the slow return; the hang pull-out (window keeps the push-in, beats go past `FRAME_MAX` fast with a
  foe 12 m out on screen, the dive returns slower); plus the per-hit feel.
- Meteor Fall: `timeout 300 godot --path . -s tests/string_film.gd -- --from=11` films L L L H H (+ H) onwards; the
  beats are the INDEX lines with `brk=3`.
- Look: `timeout 300 godot --path . -s tests/string_film.gd` and compare a string's sheet before / after (the
  film folders keep stale frames past the current count: read only the frames INDEX.txt lists).
