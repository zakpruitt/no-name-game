# Camera: distance, aim, fight framing, hand-tune flags

## What it does

The training camera looks down at the hero from 53 degrees, far enough out that the four dummies and a foe
thrown off them stay in frame through a string, and close enough that the chibi reads (about 140 px tall at
1080p). It aims at his chest rather than his feet so the pile in front of him sits mid-screen instead of
under the HUD. When a throw or breaker spreads the foes he is hitting, it eases out and leans towards them,
then drifts back slowly once they go quiet. In a breaker hang it keeps him centred, and on a long dive (Meteor
Fall onto a group up to 12 m off) it follows him there smoothly. Hits, enders, hangs and freezes still nudge it
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
   `frame_max`. In a hang he stays centred (no lean, no framing).
3. `_frame` eases out at `FRAME_OUT` and back at `FRAME_BACK` (real time, measured with `Time.get_ticks_usec()`);
   the lean likewise.
3b. **Breaker hangs.** In State.LEAP `_frame_fight()` returns at once: `_frame` and the lean settle back to 1 / none
   at `HANG_SETTLE` (3 /s). The dive (Meteor Fall can cover 12 m in 0.4 s) is the normal exponential follow at
   `follow_speed` (x3 under the dive's `punch()`), so the camera trails him in and never snaps or runs ahead.
   (Round 36's `HANG_FRAME_*` / `BEATS_PHASE` pull-out was for Meteor Fall's wall throw and gather; both went in
   round 42.)
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
| `FRAME_LEAN`, `FRAME_LEAN_MAX`, `FRAME_LEAN_RAMP` | 0.6, 1.5 m, 0.25 | lean towards the fight, only as the fight needs room (none while it fits at rest) |
| `HANG_ZOOM` | 0.16 | breaker hang push-in (0.12 at 12.5 m) |
| `HANG_FRAME_GAIN` | 1.3 | beats cap: `frame_max` x this (x1.625, 21 m; was x2.0; an uncapped two-wall throw wants ~x3.5) |
| `HANG_FRAME_OUT`, `HANG_FRAME_BACK` | 5, 3 /s | beats ease out (~70% in 0.25 s), dive return |
| `HANG_FRAME_RANGE`, `HANG_FRAME_HIT_MS`, `HANG_LEAN_MAX` | 22 m, 4000 ms, 2.5 m | who counts in the beats, lean |
| `PUNCH_GAIN`, `HIT_ZOOM`, `HIT_ZOOM_MAX` | 1.25, 0.014, 0.07 | enders / per-hit push-in at the wider distance |

Measured at 1080p (16:9, `camera_feel_check`): round 28 (0, 13, 9.5) FOV 42: 105 px, 396 m2 of floor;
round 32 (0, 10, 7.5) FOV 36: 167 px, 166 m2; round 36 13 m FOV 37 aimed 0.8 m up: 140 px, 222 m2 (+34%),
and at full framing (x1.25) about 112 px.

**By hand:** `godot --path . -- --cam-dist=15 --cam-fov=38 --cam-frame=1.3` (`--cam-frame=1` turns the framing
off). The rig prints `[camera] dist= fov= frame_max=` when a flag is given.

## Testing

- `godot --headless --path . -s tests/camera_feel_check.gd`: hero px and floor area vs round 32, aim at his
  chest, flag parsing, `PUNCH_GAIN`, a foe hit 9 m out pulls the camera out (capped) and on screen, a dummy in
  front doesn't, the slow return; the hang (a foe hit 12 m out: the window keeps the push-in and no lean) and a 12 m dive
  (no frame moves the camera further than he moved, never ahead of him, caught up 0.8 s after he lands); plus the
  per-hit feel.
- Meteor Fall: `timeout 300 godot --path . -s tests/string_film.gd -- --from=11` films L L L H H (+ H) onwards; the
  dive is the INDEX lines with `brk=1`.
- Look: `timeout 300 godot --path . -s tests/string_film.gd` and compare a string's sheet before / after (the
  film folders keep stale frames past the current count: read only the frames INDEX.txt lists).

## Calm pass (2026-11-05)

Zak, after playing: "the camera is all messed up, especially during the special moves; weird how it frames the
player". A breaker stacked the hang push-in, the focus punch x `PUNCH_GAIN`, the per-hit push-in and a lean of up
to 2.5 m, then Meteor Fall's x2.0 pull-out in 0.19 s. Now: no lean in a hang outside Meteor Fall's beats; the lean
in normal play fades in only as the fight needs room (`FRAME_LEAN_RAMP`); the hang and a punch don't multiply
(`_squeeze()` takes the deeper), no punch goes below `PUNCH_MIN` 0.8, `HANG_ZOOM` 0.16 -> 0.06, the per-hit push-in
fades out in a hang; the beats pull out to x1.625 at 5 /s. Lesson: each camera behaviour was judged alone on film;
judge them stacked, in one special, before landing another.

## Meteor dive (round 42)

Meteor Fall lost its wall throw and gather (combo lane), so the beats' pull-out (`HANG_FRAME_GAIN` / `_RANGE` /
`_HIT_MS` / `_OUT` / `_BACK`, `HANG_LEAN_MAX`, `BEATS_PHASE`) went with them. A hang now always keeps him centred,
settling at `HANG_SETTLE` (the old `HANG_FRAME_BACK` 3 /s, the rate a hang came back in at before). The calm pass
(`_squeeze()`, `PUNCH_MIN`, the lean ramp) is unchanged.
