# Camera: distance, aim, fight framing, hand-tune flags

## What it does

The training camera looks down at the hero from 53 degrees, far enough out that the four dummies and a foe
thrown off them stay in frame through a string, and close enough that the chibi reads (about 140 px tall at
1080p). It aims at his chest rather than his feet so the pile in front of him sits mid-screen instead of
under the HUD. When a throw or breaker spreads the foes he is hitting, it eases out and leans towards them,
then drifts back slowly once they go quiet. Hits, enders, hangs and freezes still nudge it
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
   `frame_max`. In a hang only the lean applies.
3. `_frame` eases out at `FRAME_OUT` and back at `FRAME_BACK` (real time); the lean likewise.
4. `camera.position = offset * _frame * _zoom * (1 - _hit_zoom) * (1 - HANG_ZOOM * _hang) + _kick`, with
   `offset = VIEW_DIR * dist`; `camera.fov = fov - _fov`.

## Invariants

- Every metre-sized nudge is scaled by `dist / REF_DIST` (kicks, `KICK_MAX`, the shake offset), so the same
  blow moves the frame as far at any distance. Fractional ones (push-ins, hang) scale on their own.
- `punch()` deepens the callers' zooms by `PUNCH_GAIN` (their numbers were tuned at 12.5 m); callers still pass
  the old values.
- A fan of dummies 2.2-3.2 m in front of him fits at rest: the framing never moves the camera in a normal string.
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
| `PUNCH_GAIN`, `HIT_ZOOM`, `HIT_ZOOM_MAX` | 1.25, 0.014, 0.07 | enders / per-hit push-in at the wider distance |

Measured at 1080p (16:9, `camera_feel_check`): round 28 (0, 13, 9.5) FOV 42: 105 px, 396 m2 of floor;
round 32 (0, 10, 7.5) FOV 36: 167 px, 166 m2; round 36 13 m FOV 37 aimed 0.8 m up: 140 px, 222 m2 (+34%),
and at full framing (x1.25) about 112 px.

**By hand:** `godot --path . -- --cam-dist=15 --cam-fov=38 --cam-frame=1.3` (`--cam-frame=1` turns the framing
off). The rig prints `[camera] dist= fov= frame_max=` when a flag is given.

## Testing

- `godot --headless --path . -s tests/camera_feel_check.gd`: hero px and floor area vs round 32, aim at his
  chest, flag parsing, `PUNCH_GAIN`, a foe hit 9 m out pulls the camera out (capped) and on screen, a dummy in
  front doesn't, the slow return; plus the per-hit feel.
- Look: `timeout 300 godot --path . -s tests/string_film.gd` and compare a string's sheet before / after (the
  film folders keep stale frames past the current count: read only the frames INDEX.txt lists).
