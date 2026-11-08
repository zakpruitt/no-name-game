# Feel audit 7, 2026-11-07c (feel-audit6 lane: the landing punch, the banner over piles, the round 55 leftovers, perf)

Zak's brief:
- film everything windowed in both rooms
- rank the top 10, with frame references
- fix the top of the list in batches, plus the decided items:
  - Cold Front's dive nearer the hoisted cube
  - a bigger Rockslide boulder
  - Overwhelm's pool thins during the haul
  - Deep Freeze's pending blocks pop as a fast wave when Avalanche opens
  - bot strings with spread foes for Dash Stab's catch and Black Tide's long haul
  - a post-landing zoom-out: punch in at the landing, ease out to the scene over 0.3 s
- perf windowed in both rooms, with `--collect-shaders`
- a hand-feel pass
- clips

## Method

- Films: windowed `tests/string_film.gd -- --tail=1300 --dir=<name>`.
  - Before (dev fe38240):
    - plain room: `--from=0 --to=15` (`fa6_a`), `--from=16 --to=31` (`fa6_b`), `--from=32 --to=42` (`fa6_c`)
    - pieces room: `--from=44 --kit=full --room=pieces` (`fa6_p`)
  - After (dev e6290b0): `fa6r_a`, `fa6r_b`, `fa6r_c` (`--to=44`: the two new bot strings), and `fa6r_p` (`--from=46`).
- Sheets: one sheet per string, every second frame, labelled from INDEX.txt (frame, real ms, move, state, time scale, breaker window). I read every sheet.
- Coverage: `python tests/fx_coverage.py <film> --per-string`.
- Frame references are `string frame`, in the before films unless marked after.
- Camera numbers: a scratch probe (not committed) plays each breaker on three dummies and logs the visible view size (`camera.position.length() * tan(fov / 2)`) relative to the rest view, from 200 ms before to 1200 ms after the landing. The raw camera distance overstates the zoom-out, because the FOV kick and the push compensate each other.
- The films, sheets and probe logs are in the session scratchpad, not committed.
- Clips: `Desktop\awaken-combo-clips\46 Audit6 *`.

## Ranked list (before)

| # | What | Frames | Status |
|---|---|---|---|
| 1 | Half the endings never punch in at the landing. Their view stays at x1.37-1.53 of rest, or widens. The close endings (Grounded, Collapse, Cataclysm, Shatterstorm, Hellseam, Worldbreaker) punch to x0.78-0.89 | probe: Maw 1.40 -> 1.47, Black Ice 1.40 -> 1.44, Eruption 1.37 -> 1.41, Uproot 1.38 -> 1.51, Cold Front 1.49 -> 1.53, Short Circuit 1.13 -> 1.38 | fixed for 6, see below |
| 2 | Piles stand under the top banner. The banner dodged only cued foes and pieces | keg_L_L_L_H_H 050-070 (KA-BLOOOM! behind the banner); Cataclysm L_H_L_L_H 034-042; Ricochet counter_D 044 | mostly fixed |
| 3 | Cold Front: the dive lands off to the side, the top cube rises under the banner, then the cut puts the banner on the bottom cube. The scene needs x1.7 | alt_L_H_L_H 030-034 | fixed |
| 4 | Deep Freeze's last blocks pop on one frame at Avalanche's leap. Their timers run on game time, so the hitstops stretched the wave past the window | L_L_H_L_H 026 -> 027 | fixed |
| 5 | Regression: the Eruption and Ricochet banners show no total, and the beats' damage numbers float up over the banner | line_D_L_H_H_H_L 040-048, wall_D_L_H_H_H_L 048-056, counter_D 042-052 | fixed |
| 6 | Overwhelm: the pool and its binds stay busy behind the slam | hold 022-030 | fixed |
| 7 | Rockslide's boulder is a small blob at the top edge | L_H_L_L_H 016-018 | fixed |
| 8 | Name callouts and beat words stack | FAULT LINE + KRUNCH! (L_H_L_L_H 021-024), BLACK TIDE + SPLOOSH! (H_L_H 019-021), MELTDOWN + SIZZ-BLAM! (line 027-028), Collapse's -FTOOO! on the banner's PERFECT (H_H 028), BLAMM + PERFECT (spread_alt 038-040) | words off the banner fixed; the name callout pairs open |
| 9 | Dash Stab's catch and Black Tide's long haul are never filmed: the bot's dummies stand close | (no string) | fixed (bot strings) |
| 10 | Leftovers, see below | see below | open |

Item 10:
- The second ending's structure bracket sits at the top-left edge through the hang (L_L_H_L_H 027-037, H_L_H 017-024, L_H_L_H 023-029).
- The parried cleaver lies on the floor for about 2 s (counter_D 032-052).
- Beige pebbles from Collapse's pillar hit fly into the next string (H_H 040 -> H_L_H 002-020). I did not find their source.
- The banner is empty on the impact frame (every breaker's HIT frame). Minor: it fills on the next frame.

## Fixes (batch 1, six commits, landed as e6290b0)

- **The landing punch** (`camera_rig._land_punch`, item 1 and decided item f).
  - At the landing the rig notes the view it had (`_land_from`).
  - Through the hang scene's first `LAND_EASE_MS` 330 ms it asks for at most `LAND_PUNCH` x0.85 of that view. It holds that for `LAND_HOLD_MS` 50 ms, then eases (smoothstep) out to what the scene needs.
  - It never punches tighter than the scene's actors allow in a loose box, `LAND_SAFE` (0.86 sideways, 0.62 up, 0.86 down). It checks that box against the current lean, the lean it is heading to, and the follow point. A punch never crops the pile.
  - The probe, view at +30 ms (before -> after):
    - Maw 1.40 -> 1.23
    - Black Ice 1.40 -> 1.23
    - Eruption 1.40 -> 1.20
    - Ricochet 1.25 -> 1.17
    - Tempest 1.39 -> 1.30
    - Cold Front 1.52 -> 1.13 (at +100 ms)
    - Anvil 1.01 -> 0.96 (lowest)
    - Abyss 0.92 -> 0.89 (lowest)
  - Each one is back on the scene's own framing by +300-450 ms.
  - The close endings are unchanged: their own push is already tighter.
  - `camera_feel_check` now proves it on Maw, Black Ice, Ricochet and Eruption: the view in the first 150 ms is at most x0.95 of the landing frame's.
    - New code: x0.88, 0.88, 0.89, 0.88.
    - Old rig: x1.00, 1.00, 0.94, 1.01, so 3 FAIL.
  - Film after: Maw H_L_H 028 (the heap fills the frame), then out to the scene by 032. Meteor Fall L_L_L_H_H 042.
  - Still wide, because their actors already fill the loose box: Avalanche, Slapshot, Meteor Shower, Pinwheel, Short Circuit and Uproot (1.3-1.46). They would only punch if the punch could crop part of the pile for 0.3 s. That is a call for Zak.
- **Cold Front's dive** (`hero_leap._cold_zone`, item 3 and decided item a).
  - When the breaker has cubes, the dive's landing zone, the cue and the facing move `COLD_DIVE_TOWARD` (1.0, all the way) to the middle of the held foes' flat bounding box.
  - `camera_feel_check`: Cold Front's worst actor at the landing went 0.89-0.96 -> 0.77, and at the payoff -> 0.85.
  - Film after: alt_L_H_L_H 028-040. All four cubes are on screen, with the banner low and clear of them from 028. Before: the top cube was under the banner at 030-034.
- **The banner dodges the pile** (`designed_breaker.Screen._callout_tick` / `_foe_under`, item 2).
  - Any foe in the hang scene (`camera_rig._actors`, feet to `ACTOR_HEAD` 1.8 m) now counts, not only cued ones.
  - The banner only drops if the low spot is clearer than the top.
  - After: keg_L_L_L_H_H 048-056. The banner is low and KA-BLOOOM! reads at the top (before: 050-070 behind the banner).
  - After: Cataclysm L_H_L_L_H. The banner drops at 042 (before: it stayed over the pile to the end).
- **The banner counts again** (`comic_number.add`, item 5).
  - A new breaker's banner restarts its total even if the last breaker's count had not run out. Eruption and Ricochet came right after another ending in the same string, so they showed no total.
  - After: Eruption wall_D_L_H_H_H_L 048-060 counts 484 -> 624 -> 796.
  - After: Ricochet counter_D 054-062: the banner is low, clear of the pile, and counts 105 -> 111.
- **Words and numbers stay off the banner** (`comic_number.banner_rect`, `comic_fx._text_blocks`, part of items 5 and 8).
  - The open banner, plus `BANNER_TAG_H` 0.6 of its height for the PERFECT tag, is a text block. Beat words and damage numbers are placed clear of it.
  - After: no stray number on the Eruption banner (wall 048-060).
- **Deep Freeze flushes as a wave** (`void_element.deep_freeze_flush`, `void_grab.seize`, item 4 and decided item d).
  - When Avalanche's window opens, the blocks still to pop are popped `DF_FLUSH_STEP` 0.035 s apart. The steps use real-time timers, so the hitstops can't stretch them.
  - The flush pops have no stop of their own (the leap is already in hitstop).
  - Avalanche takes them as cubes without encasing them a second time.
  - `cool4_check` `_flush_wave`: the flush returns the pending foes, none freezes on the flush frame, all freeze within 0.3 s on at least 3 different frames. It FAILs (4) on the old code.
  - The wave is too fast to see at 12 fps (L_L_H_L_H after 026-030).
- **Overwhelm's pool thins** (`dark_fx` pool `thin()`, `designed_ink.FloorLoop.set_alpha`, item 6 and decided item c).
  - During the haul the pool fades to `OW_POOL_THIN` 0.2 alpha and shrinks to `POOL_THIN_SIZE` 0.7. It waits out the pool's own open first, so the two tweens don't fight.
  - It holds through `OW_HOLD + OW_DOWN + OW_POOL_AFTER` 0.15 s and comes back over `OW_POOL_BACK` 0.3 s.
  - `cool4_check`: the scale ratio after 0.2 s is below 0.8, and the pool is whole again 0.45 s later.
  - Film after: hold 022-025.
- **Rockslide's boulder** (`mid_beats.DROP_SIZE` 1.6 -> 2.4, `DROP_HIGH` 0.75 -> 1.05, dust `DROP_DUST` 2.4; `void_element.ROCKSLIDE_DROP_Y` 3.2 -> 2.7, so it starts on screen; item 7 and decided item b).
  - Film after: L_H_L_L_H 016-018.
- **Bot strings for the spread catches** (`training_bot`, item 9 and decided item e).
  - `stab D L`, slot `dash_l`: a foe 4 m behind, the dummies spread (`BOT_SPOT_LAYOUTS.stab`).
  - `tide H L H`, slot `sig_drag`: three foes 5-9 m out (`tide`).
  - After: stab_D_L 020-028 (the lash catches the one behind and reels it in), tide_H_L_H 010-016 (the tentacles haul the two marked foes in from 5 m; the far one at the top right is not marked and stays out).
  - `AUTOTEST_MAX` 180 -> 195 s. The room with pieces now plays 53 strings, and the 53rd ran out of time (`strings=52/53` on the first land attempt). Wall time is 219 s, inside agent.sh's 300.

## Perf (windowed, this machine caps at 60 fps)

| Run | wall worst | spikes >25 ms | cpu avg / worst | cpu spikes >8 ms | gpu avg / worst |
|---|---|---|---|---|---|
| plain before (fe38240, 43 strings) | 58.8 | 39/10678 | 1.7 / 34.3 | 1 (L1 t=1.23) | 0.7 / 1.7 |
| plain after (e6290b0, 45 strings) | 59.0 | 39/10967 | 1.7 / 34.9 | 1 (L1 t=1.24) | 0.7 / 1.2 |
| pieces before (51 strings) | 56.5 | 47/12709 | 1.8 / 33.0 | 1 (L1 t=1.24) | 0.7 / 1.2 |
| pieces after (53 strings) | 58.3 | 47/13127 | 1.8 / 33.8 | 1 (L1 t=1.24) | 0.7 / 1.2 |

- Nothing new. The one CPU spike is still the first L1 hit (feel audit 2's warmup frame). The other wall spikes are ~34 ms frames with cpu 1.3-1.8 ms and gpu 0.7 ms: display misses, not work.
- `breakers=15/15` in both rooms. `strings=45/45` and `53/53`.
- `endings_n`: plain 22/22. Pieces 21/22 windowed, both before and after: Anvil is the one missed, windowed only. The headless run that `agent.sh` uses gives 22/22.
- `--collect-shaders` in each room found no new signature: `warmup_shaders.gd` is unchanged. The scan slows the frames, so the pieces run reached only 49 of its 53 strings before `AUTOTEST_MAX`. The perf run above played all 53 with no CPU spike after the first L1.
- The pieces "before" run started while I was making the first edits. Its log ends before any edited script runs, so I take it as a clean baseline.

## Hand-feel pass

- Hitstop escalation is unchanged: no hang or stop constant moved. `hitstop_check` passes. The new flush pops have no stop, and the mid stops (0.035-0.08 s) stay under the landing stops (0.12-0.18 s).
- No hang got longer. The punch changes only the camera; no `MOVES` timing or hang constant moved, and `rhythm_check` passes.
- Dash cancels: `input_snap_check` passes (every route step and dash cancel).
- The counter window: `counter_check` passes. The spar-feel lane owns counter.gd against real strikes.
- Awakening is faster. I ran it headless, `--autotest --start-awakened` against plain, at `ANIM_MULT` 1.3.
  - Inside the 8 s meter (the first three strings), the weapon beats are 12-24% shorter: L H's EC 285 -> 216 ms, L H H's EC 333 -> 270, L L L H's L2 282 -> 214, L3 401 -> 331, EM 354 -> 305.
  - From the fourth string on the meter has run out, and the beats are confounded. H H's GR is 120 -> 155 and VS 353 -> 421, because the runs differ in combo and state, not in speed.
  - This matches feel audit 6 (18-24%).

## Coverage

From `fx_coverage --per-string`, on HIT frames (budget 0.40):

| Film | before mean / max | after mean / max |
|---|---|---|
| plain a (0-15) | 0.074 / 0.237 | 0.075 / 0.238 |
| plain b (16-31) | 0.085 / 0.262 | 0.083 / 0.306 |
| plain c (32-44) | 0.074 / 0.264 | 0.077 / 0.223 |
| pieces | 0.091 / 0.284 | 0.086 / 0.273 |

- b's max moved to `line_out_face_D_L_H_H_H_L_D_wait_L_H` (0.306).
- c's max is Eruption by the wall (0.264 -> 0.223). It still plays: DL, EF, EA, XG, XM, then Eruption.

## Clips

`Desktop\awaken-combo-clips\`, before left, after right, half speed, aligned on the leap:
- `46 Audit6 Landing punch - Maw punches in on the heap, then eases out`
- `46 Audit6 Landing punch - Meteor Fall`
- `46 Audit6 Cold Front - the dive lands by the cubes, the banner off the top cube`
- `46 Audit6 Eruption - the banner counts again, beat numbers kept off it`
- `46 Audit6 Overwhelm - the pool thins during the haul`
- `46 Audit6 Rockslide - a bigger boulder`
- `46 Audit6 Keg Meteor Fall - the banner drops off the pile, KA-BLOOOM reads`
- `46 Audit6 Avalanche - the last Deep Freeze blocks pop as the window opens` (the wave is faster than 12 fps; cool4_check is the proof)
- After only: `46 Audit6 Bot - Dash Stab, the lash catches the foe behind`, `46 Audit6 Bot - Black Tide hauls in spread foes`

## Not verified / open for Zak

- **Zak's call:** should the wide endings punch too? Avalanche, Slapshot, Meteor Shower, Pinwheel, Short Circuit and Uproot fill the punch's safe box already. A punch would crop part of their pile for 0.3 s.
- The Deep Freeze flush wave is proved by `cool4_check` only. At 12 fps the film can't resolve 0.035 s steps.
- Item 8: a mid's name callout still stacks over its beat word (FAULT LINE + KRUNCH! L_H_L_L_H after 025-027, BLACK TIDE + SPLOOSH! H_L_H after 021-023). The banner's own words are fixed.
- Cataclysm: the banner stays over the airborne pile from 034 to 040 and drops at 042 (before: never). The dodge reads foes at 1.8 m, and these are thrown higher.
- Keg Meteor Fall after: the low banner touches the bottom of the pile (048-052). The pile fills the frame top to bottom at that zoom.
- Item 10 leftovers: the structure bracket at the top-left edge, the parried cleaver (spar-feel's counter.gd), Collapse's pebbles, the empty banner on the impact frame.
