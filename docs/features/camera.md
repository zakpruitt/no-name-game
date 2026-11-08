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
   at `HANG_SETTLE` (3 /s). The dive (Meteor Fall can cover 12 m in 0.4 s, 17 m in ~0.57 s onto a fresh wall splat since round 42 e) is the normal exponential follow at
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
| `FRAME_CUE`, `FRAME_CUE_OUT` | meta, 7 /s | a foe a move is about to strike counts for the framing until the meta's real ms, and the view eases out fast (feel audit 3: Short Circuit's targets, `void_element.SC_CUE_MS` 900; its far arc landed at ndc 1.47, now 1.06) |
| `FRAME_CUE_LEAN_MAX` | 3.5 m | the lean's cap while a cued foe is in the fight (`FRAME_LEAN_MAX` 1.5 otherwise): Slapshot's cubes sliding 8-10 m up-screen hit the wall on the top edge at 1.5 (round 47, `void_element.SLIDE_CUE_MS` 1400) |
| `FRAME_CUE_RANGE` | 17 m | how far out a cued foe still counts (Molten Palm carries a foe ~9.5 m to the back wall); in a hang only cued foes count (feel audit 3 item 6) |
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

Round 42 e: `camera_feel_check`'s dive failed every run (0.21 m over) because it moved the hero by the wall clock
while the rig follows with the engine's frame delta; headless the two disagree. The check now steps the rig by
hand at 1/60 s (24 steps for the 0.4 s dive), and an injected lean jump mid-dive still fails it. The Molten Palm
films (`string_film --layout=wall|stray`) keep hero and target in frame through the hang and the dive; the wall
splat itself sits ~9.5 m up-screen, at the top edge for a beat (the hang turns the fight framing off).

## Meteor splat framing (feel audit 3 item 6, 2026-11-06)

The wall splat sat in the top-left corner, half off frame, through Undertow and the whole Meteor Fall hang: the hang
turned the fight framing off. Now Molten Palm cues a foe it carries to a wall (`void_element.PALM_CUE_MS` 2600 real
ms, `FRAME_CUE`), and `_frame_fight()` still runs in a hang for cued foes only (a foe merely hit keeps him centred,
as the calm pass wants; `camera_feel_check`'s 12 m hang foe is hit, not cued, and still sees no lean). Cued foes
count out to `FRAME_CUE_RANGE` and ease at `FRAME_CUE_OUT` with the `FRAME_CUE_LEAN_MAX` lean, also in the hang. Film
(L L L H H, frames 036-046 of `string_film -- --from=11 --to=11`): the splatted dummy and its ring sit whole inside
the frame through the hang and the dive; for ~0.25 s after the splat (Undertow's start) it is still at the edge while
the view eases out.

## Breaker landing jolt (round 48, breaker-spectacle lane)

`camera_rig.jolt(amount, hz, decay, axis)` is a damped cosine shake along a screen axis, in metres at `REF_DIST`
scaled by the distance, capped at `JOLT_MAX` 0.9, and added to `h_offset` / `v_offset` on real time. It is separate
from `trauma`, so the noise shake and the jolt stack. `designed_breaker.landing()` calls it with the family's `FEEL`
(storm 22 Hz sideways, magma 9 Hz down, ice 15 Hz short, dark 6.5 Hz slow), together with an FOV snap
(`fov_punch`, `FOV_ENDER` x1.2-1.6) and `Game.slam_stop()`. That last one is two stacked hitstops: a crunch freeze at
`CRUNCH_SCALE` 0.02, then a slow tail at the family's `tail_scale` (clamped 0.1-0.49 so the hitstop check reads it as
slow-mo, not a freeze), with the total capped at `SLAM_STOP_MAX` 0.25 real s. Check: `tests/camera_feel_check.gd`, `tests/hitstop_check.gd`.

## Hang framing (round 54, camera-hang lane)

Feel audit 6 item 10: the hang framing left the pile at the frame's edge (Meteor Fall, Black Ice, Maw) and Cold Front's
hoist under the banner. Each fix so far was a per-move cue. Now one rule runs for every breaker, from the leap to its
payoff.

**The scene** (`_scene_tick()`).
- A leap (State.LEAP) starts a scene. Each frame of the hang adds the foes the tentacles hold (`_void.held_foes()`)
  and the foes within `HANG_ZONE_R` (5 m) of the landing zone (`_brk_zone`).
- The landing (`breakers_landed` going up) adds the foes within `HANG_ZONE_R` of him, and every foe hit from 60 ms
  before to 200 ms after the landing (`HANG_LAND_HIT_MS`), however far: Short Circuit's arc, Ricochet's bounce.
- A cued foe (`FRAME_CUE`) joins the scene and keeps it on. A miss or a dash out ends the scene.
- The scene runs `HANG_AFTER_MS` 1300 past the landing, longer while a cue runs, up to `HANG_AFTER_MAX_MS` 2600.
- Its structures are the indicator's pick (as of the leap, kept for the scene: Collapse spits into it after the landing) and any cued room piece (`"env"` group, `FRAME_CUE`).

**The framing** (`_frame_scene()`).
- The scene takes the actors (feet and `FRAME_HEAD`), him (feet and his hang height), the dive's landing spot and the
  structures, and fits them inside `HANG_SAFE`: (0.82 sideways, 0.5 up, 0.8 down) of the half-screen. Up is kept
  short so the top banner stays clear.
- It **zooms out first**, up to `HANG_CAP` x1.4. Only what the zoom can't hold is leaned for, and then by the least
  lean that fits. `_best_lean()` sweeps x then z twice, coarse (±6 m by 0.5) then fine (±0.5 by 0.1), and a tie goes
  to the smaller lean. A binary search then scales that lean down to the least that still fits.
- Fallbacks, in order:
  - Nothing fits: the box grows to `HANG_SAFE_FULL` (0.8 up), and the banner dodges.
  - Still nothing fits: the structure is dropped, foes first.
  - Still too wide, or a lean or follow still on its way: the cap becomes `HANG_CAP_WIDE` x1.55, after the landing
    only (never during the rise).
- The zoom it asks for is also checked against where the view centres now: the current eased `_lean`, and, after the
  landing, the lagging follow point. Without that, a lean still on its way home put the pile off the bottom while the
  zoom came in.
- The scene's lean comes home at `HANG_SETTLE`.
- **Push-ins are clamped.** `_squeeze()` and the per-hit push-in and FOV kick can't go deeper than the scene's actors
  allow (`camera.position` takes `max(push, need / (frame * narrow))`). The landing's punch still plays when the scene
  has room.

**Measured** (the lane's scratch probe, deleted before landing; it drove the bot like `string_film`, plain room, every bot string, 1920x1080). The number is the worst
actor's |ndc|, the larger of x and y over feet and +1.6 m. Landing is the first 150 ms; payoff is 150-1400 ms.

| Ending (plain) | String | Landing before | after | Payoff before | after |
|---|---|---|---|---|---|
| Grounded | `L H H` | 0.54 | 0.28 | 0.62 | 0.40 |
| Collapse | `H H` | 1.02 | 0.70 | 0.98 | 0.71 |
| Maw | `H L H` | 0.91 | 0.34 | 0.87 | 0.41 |
| Worldbreaker | `L H L H` | 0.71 | 0.36 | 0.71 | 0.42 |
| Shatterstorm | `D L H` | 0.82 | 0.47 | 0.78 | 0.53 |
| Avalanche | `L L H L H` | 1.12 | 0.68 | 1.11 | 0.62 |
| Abyss | `hold` | 0.56 | 0.47 | 0.81 | 0.59 |
| Meteor Fall | `L L L H H` | 0.56 | 0.28 | 0.69 | 0.30 |
| Cataclysm | `L H L L H` | 0.73 | 0.40 | 0.72 | 0.44 |
| Flash Freeze | `D L H H L` | 0.61 | 0.68 | 0.67 | 0.58 |
| Black Ice | `alt H L H` | 0.97 | 0.44 | 0.93 | 0.51 |
| Eruption | `line D L H H H L` | 0.71 | 0.81 | 0.91 | 0.77 |
| Anvil | `L L H D H H L` | 0.68 | 0.32 | 0.71 | 0.37 |
| Shatterstorm | `face L H L L D L H` | 1.15 | 0.51 | 1.01 | 0.47 |
| Shatterstorm | `face L H D L H` | 0.83 | 0.46 | 0.84 | 0.47 |
| Short Circuit | `spread far alt L H H` | 1.37 | 0.98 | 1.21 | 0.70 |
| Shatterstorm | `ring D L H` | 0.80 | 0.67 | 0.78 | 0.62 |
| Slapshot | `wall alt D L H` | 0.57 | 0.46 | 0.61 | 0.56 |
| Meteor Shower | `spread alt L L L H H` | 1.21 | 0.74 | 1.18 | 0.82 |
| Pinwheel | `wall alt L L H D H H L` | 1.02 | 0.75 | 0.93 | 0.61 |
| Hellseam | `wall spread L L L H L` | 0.64 | 0.45 | 0.67 | 0.46 |
| Cold Front | `alt L H L H` | 3.32 | 0.96 | 3.05 | 0.87 |
| Tempest | `alt L H L L H` | 1.27 | 0.56 | 1.08 | 0.58 |
| Ricochet | `counter D` | 1.14 | 0.79 | 1.18 | 0.82 |
| Collapse | `pillar H hold` | 0.35 | 0.28 | 0.68 | 0.58 |
| Uproot | `pillar alt hold` | 1.29 | 0.62 | 1.35 | 0.59 |
| Avalanche | `wall L L H L H` | 0.80 | 0.60 | 0.83 | 0.65 |
| Pinwheel | `wall alt D H H` | 0.84 | 0.67 | 0.95 | 0.62 |
| Eruption | `wall D L H H H L` | 0.84 | 0.68 | 0.79 | 0.65 |
before_final_pieces.txt [hang] banners=36 dodged=18 late_adds=82 folded=15
after14_pieces.txt [hang] banners=36 dodged=13 late_adds=82 folded=14

Pieces room, the strings only it has:

| Ending (pieces) | String | Landing before | after | Payoff before | after |
|---|---|---|---|---|---|
| Ricochet | `counter D` | 1.85 | 0.81 | 1.84 | 1.41 |
| Meteor Fall | `keg L L L H H` | 0.64 | 0.51 | 0.58 | 0.48 |
| Slapshot | `grate alt L L H wait D L H` | 1.47 | 0.80 | 1.39 | 0.80 |
| Short Circuit | `grate alt L H H` | 0.50 | 0.39 | 0.47 | 0.38 |
| Short Circuit | `torch alt L H H` | 1.59 | 1.07 | 1.39 | 0.75 |
| Ricochet | `hook counter D` | 0.95 | 0.46 | 1.72 | 1.20 |
| Slapshot | `pool alt D L H` | 0.61 | 0.45 | 0.92 | 0.86 |
| Hellseam | `brazier L L L H L` | 0.57 | 0.50 | 0.55 | 0.46 |

The before column comes from the dev rig with the same probe and actor set. Most of the large before numbers are foes
the hang never framed (the hang kept him centred).

`camera_feel_check` plays one string per ending in the real training room and holds the worst actor inside 0.9 at the
landing and over the payoff. The landing is measured from the frame after it, because the landing's own frame has the
camera from before the hit. Cold Front's bar is 1.0: its hoisted cube sits ~8 m down-screen of where the dive lands
and 2.8 m up, and the scene wants x1.7, past `HANG_CAP_WIDE`. It lands at 0.89-0.96 for the landing's first frames.

**Banner dodges.** The banner dodged 11 of 29 banners in the plain room and 13 of 36 in the pieces room (before:
cued endings only).

**Zak's calls.**
- The banner move. `designed_breaker.Screen.CALL_MOVE` is "cut" (round 53: it jumps to the bottom with a pop).
  `-- --banner=slide` plays the alternative: two frames on twos down the screen (20% at alpha 0.4, then 80% at 0.65),
  then whole at the bottom with the pop. On film at 800x450 (`camhang_slide_*`, Maw H L H 030-032, Flash Freeze D L H H L 033-036), the slide's middle frame is a faded banner lying over the pile, which is the ghost round 53 removed. The cut reads cleaner, so it stays. Clip: `awaken-combo-clips/43 Camera Banner move *`.
- Cold Front's cube: give it `HANG_CAP_WIDE` x1.7, or let its dive land nearer the cube.
- The pieces room: Ricochet onto the gallows hook (payoff 1.2-1.4: the hook 10 m off is cued high) and Short Circuit's
  torch arc (landing 1.07, the first frame) are still past 0.9.

| Constant | Value | What |
|---|---|---|
| `HANG_CAP`, `HANG_CAP_WIDE` | 1.4, 1.55 | zoom-out cap for a scene; the last tier, after the landing |
| `HANG_SAFE`, `HANG_SAFE_FULL` | (0.82, 0.5, 0.8), (0.82, 0.8, 0.8) | box (sides, up, down) of the half-screen |
| `HANG_ZONE_R` | 5 m | foes round the zone and the landing count |
| `HANG_LAND_HIT_MS` | (60, 200) | a foe hit this long before / after the landing counts |
| `HANG_AFTER_MS`, `HANG_AFTER_MAX_MS` | 1300, 2600 | how long a scene runs past the landing, with cues |
| `HANG_LEAN_STEPS`, `HANG_LEAN_MAX` | 7, 6 m | lean binary search steps, the lean's reach |

## Landing punch (round 56, feel-audit6 lane)

Feel audit 2026-11-07c item 1: half the endings never punched in at the landing. The hang scene had zoomed out to fit
the pile (x1.4-1.55), and the scene's framing held the view there or widened it (Maw 1.40 -> 1.47, Eruption 1.37 ->
1.41, Cold Front 1.49 -> 1.53). Only the close endings, whose own push is tighter, punched (x0.78-0.89).

**The punch** (`_land_punch()`, called from `_frame_scene()` once the hang is over).
- At the landing (`_scene_tick`, `breakers_landed` going up) the rig notes the view it had: `_land_from`, the camera
  distance over the offset's.
- For `LAND_EASE_MS` 330 after the landing, the scene's need is lowered to at most `LAND_PUNCH` x0.85 of that view. It
  holds `LAND_HOLD_MS` 50, then eases (smoothstep) back to the scene's own need.
- It never goes tighter than the scene's actors allow in `LAND_SAFE` (0.86 sideways, 0.62 up, 0.86 down), a looser box
  than `HANG_SAFE`. The box is checked against the lean, the lean it is heading to and the follow point, so the punch
  never crops the pile.
- A scene that already asks for less than the punch (the close endings) is left alone.

Numbers (view size over rest at +30 ms, before -> after): Maw 1.40 -> 1.23, Black Ice 1.40 -> 1.23, Eruption 1.40 ->
1.20, Ricochet 1.25 -> 1.17, Tempest 1.39 -> 1.30, Cold Front 1.52 -> 1.13 (at +100 ms). Each is back on the scene's
framing by +300-450 ms.

Still wide (their actors fill `LAND_SAFE`): Avalanche, Slapshot, Meteor Shower, Pinwheel, Short Circuit, Uproot.
Punching them would crop part of the pile for 0.3 s; that is Zak's call.

`tests/camera_feel_check.gd` (`PUNCH_ENDINGS`): Maw, Black Ice, Ricochet and Eruption. The view in the landing's first
150 ms must be at most `PUNCH_BAR` x0.95 of the landing frame's. Now x0.88-0.89; the old rig gave x0.94-1.01.

| Constant | Value | What |
|---|---|---|
| `LAND_PUNCH` | 0.85 | the punch, as a share of the view at the landing |
| `LAND_SAFE` | (0.86, 0.62, 0.86) | the box the actors must stay in through the punch |
| `LAND_HOLD_MS`, `LAND_EASE_MS` | 50, 330 | hold, then ease out to the scene by |
