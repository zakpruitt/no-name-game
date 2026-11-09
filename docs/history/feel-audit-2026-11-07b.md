# Feel audit 6, 2026-11-07b (feel-audit5 lane: both rooms, the banner, frost marks, Tow Line, perf)

Zak's brief:
- film everything in both rooms
- rank the top 10
- fix the top of the list within the kit grammar
- measure perf windowed
- a hand-feel pass
- clips

## Method

- Films: windowed `tests/string_film.gd -- --tail=1300`. The tail films the after-beat past each string; the first pass without it cut off every banner and payoff.
  - Plain room: `--from=0 --to=15 --dir=fa5_a`, `--from=16 --to=31` (`fa5_b`), `--from=32 --to=41` (`fa5_c`).
  - Pieces room: `--from=42 --kit=full --room=pieces` (`fa5r_p`), filmed after the fixes only.
- Sheets: one PIL sheet per string, labelled from INDEX.txt (frame, real ms, move, state, scale, breaker window). I read every sheet.
- Coverage: `python tests/fx_coverage.py <film> --per-string` on each film.
- Frame references are `string frame`.
  - They point at the before films (dev fe17173) unless marked after.
  - After means the `fa5r_*` films, made on this lane rebased on ac8720b.
- Perf:
  - windowed `--autotest`, plain and `--kit=full --room=pieces`
  - the `[perf]` lines before and after
  - a `--collect-shaders` run in each room
- The films and sheets are in the session scratchpad, not committed.
- Clips: `Desktop\awaken-combo-clips\42 Audit5 *`.

## Ranked list (before)

| # | What | Frames | Status |
|---|---|---|---|
| 1 | The breaker banner slides from the top to the bottom across the middle of the frame, over the pile it should clear | Flash Freeze D_L_H_H_L 046, Abyss hold 034-035, Shatterstorm D_L_H 027, Avalanche L_L_H_L_H 041-042, Uproot pillar_alt_hold 029, Eruption line_D_L_H_H_H_L 044 | fixed |
| 2 | A ghost ink outline of the breaker callout (FLASH FREEZE / PERFECT) stays at the top once the banner is low. Cause: `Label3D.modulate` does not fade `outline_modulate` | D_L_H_H_L 047-048 | fixed |
| 3 | Frost marks read as spoked crystal stars (art direction: no crystals) | Cold Front alt_L_H_L_H 030-036, frost spear L_L_H_L_H 015-021, Deep Freeze's ring 024 | fixed |
| 4 | `wall D L H H H L` never plays Eruption. Impale's spear (5 s) is still standing, so Dash L H vaults (IJ) instead of Harpoon | wall_D_L_H_H_H_L: DL, IJ, IS, L1 | fixed |
| 5 | The first ice block of a session costs a 44-48 ms CPU frame windowed. `designed_elements.model_points` reads skinned vertices back from the GPU (44 ms windowed, 5.7 ms headless) | autotest `spike 63.9ms at t=20.86 cpu=47.5 move=EF` | fixed |
| 6 | Black Ice's wall skid plays under the banner at the top-left edge | alt_H_L_H 032-036 | banner fixed; framing open |
| 7 | Tow Line's foe pick only shows in its ~0.15 s start-up (Zak's open call from round 52) | D_H 004 | fixed |
| 8 | Maw's KONK heap sits under the MAW banner and its PERFECT tag | H_L_H 034-039 | fixed |
| 9 | The picked foe's bracket sits on the breaker prompt circle and its chips at 800x450 | hold 026 | fixed |
| 10 | Clutter and framing, see the list below | see below | open |

Item 10:
- Collapse's spits fly off the bottom-right edge (H_H 030-036).
- Hang framing puts the pile at the frame's edge (Meteor Fall L_L_L_H_H 027-038, Black Ice 015-023, Maw 019-024).
- Damage numbers stack (Cold Front 034 "146209").
- Pillar rubble lingers (H_L_H 003-018).
- Eruption's banner shows no total.

Dropped: Uproot's banner over the pillar. The flourish lane already fixed it in `f758dec` (the banner drops off a cued piece).

## Fixes (batch 1, six commits)

- **The banner cuts** (`designed_breaker.Screen._callout_tick`).
  - When a cued foe or piece is under the banner, it now jumps to `CALL_Y_LOW` with a pop (`_pop = 1.0`).
  - It used to slide at `CALL_SLIDE` 14/s; that constant is deleted.
  - After: D_L_H_H_L goes from top at 031 to bottom at 032. Avalanche L_L_H_L_H goes from 039 to 040. Nothing crosses the middle.
- **The outline fades with the text** (`callout_cap.watch`).
  - After the cap's own fade, `outline_modulate.a` follows `modulate.a`.
  - After: the top band is clean in D_L_H_H_L 042-047.
- **Maw and Black Ice cue the frame.**
  - `void_element.MAW_CUE_MS` 1000 is set on each hoisted foe.
  - `BLACK_ICE_CUE_MS` 1100 is set when the skid finds a wall.
  - The camera frames them and the banner dodges.
  - After, Maw: H_L_H 034-040 have the banner low, under the heap.
  - After, Black Ice: at alt_H_L_H 032 the banner is low while the skid plays top-left.
- **The foe bracket clears the prompt** (`env_target._draw_foe`).
  - In a breaker's leap, the check is whether the prompt circle is within `FOE_IN_PROMPT` 1.8 m of the picked foe.
  - When it is, the bracket goes up to `FOE_LIFT_Y` 2.5 m and is scaled to `FOE_LIFT_SIZE` 0.7.
- **Tow Line's pick opens in the dash** (`env_target._tow_dash_ctx`).
  - The same `tow:` context now also exists in DASH.
  - It shows once a right click is buffered or the cursor is on a foe (`need_choice`). A plain dash draws nothing.
  - It uses the same key, so the lock carries into the move. `_end` counts it as taken once Tow Line hits.
  - `tests/env_target_check.gd` covers four cases:
    - a plain dash shows no bracket
    - a buffered heavy puts the bracket on the default foe
    - the cursor on another foe makes it the chosen one
    - the lock carries into ATTACK
  - The bot does not buffer early. So the after film (D_H) shows the same start-up bracket as before.
- **Anvil and Pinwheel melt the spear** (`void_element.breaker_impact`).
  - After, `wall D L H H H L` plays DL, EF, EA, XG, XM, then Eruption by the wall (wall_D_L_H_H_H_L after 035-047).
- **The frost mark is rime** (`gen_elements.py ice_mark`, `assets/vfx/designed/ice_mark.png`).
  - It is an uneven 17-corner patch with a broken lit edge.
  - It has three jagged crack chords from rim to rim and round frost beads.
  - Nothing comes out of its middle.
  - Crop: `42 Audit5 Frost mark crop` (L_L_H_L_H 014 before / after).
- **The first ice block's spike** (`designed_elements.prime_fit`, deferred from `enemy._ready`).
  - The model's skinned points are now read at spawn.
  - A scratch probe measured the first block at 0.1 ms after the fix (43.7 ms before).
  - `--collect-shaders` found two new material shader signatures. They are added to `warmup_shaders.gd` (30 in all).
- **Dead code** (`python tools/dead_refs.py`):
  - `comic_freeze_over.foe()` and its shell: SHELL, SHELL_POINTS, TIPS, FOE_LIFE, `mode`, `target`, `_shape`, `_tips`, `_follow`, `_draw_shell`
  - `designed_elements.frost_floor`, `frost_step`, `FROST_BOIL`, `_unit_plane`
  - `designed_fx.ICE_TIMES`
  - `harpoon_gather.carrying`
  - in `void_element`: CRUSH_RING, CRUSH_CUBE_WIDTH, ABYSS_LAUNCH, MAGMA_RADIUS / DAMAGE / LAUNCH / WELLS / WELL_R, CUBE_FOE_GAP, BLACK_ICE_DOWN
  - Left in place:
    - `env_piece.RUBBLE_LANDING_R` (the flourish lane's file)
    - the prince constants (paused work)
    - `void_element.improv_state` (named in docs and tests)
  - The autotest's `strings=` and `breakers=` lines still match: 42/42 and 15/15, and 50/50 in the pieces room.

## Perf (windowed, this machine caps at 60 fps)

| Run | wall worst | spikes >25 ms | cpu avg / worst | cpu spikes >8 ms | gpu avg / worst |
|---|---|---|---|---|---|
| plain before | 63.9 | 40/10206 | 1.5 / 47.5 | 2 (L1 t=1.24 34.0, EF t=20.86 47.5) | 0.7 / 1.2 |
| plain after | 57.5 | 38/10154 | 1.5 / 33.4 | 1 (L1 t=1.24) | 0.7 / 1.3 |
| pieces before | 64.6 | 46/11629 | 1.5 / 48.0 | 2 (L1, EF t=20.96 48.0) | 0.7 / 1.2 |
| pieces after (`pieces=9/9`, 50 strings) | 57.5 | 46/12261 | 1.6 / 33.3 | 1 (L1 t=1.24) | 0.7 / 1.2 |

- The other wall spikes are ~34 ms with cpu 1.2-2.7 ms and gpu 0.6 ms. They are display frame misses, not work.
- No spike line lines up with a pipeline compile.
  - The pipeline counts do climb in play: canvas 4 -> 9, surface 127 -> 138, draw 0 -> 3.
  - The frames where they climb have cpu ~1.4 ms.
- One CPU spike is left: the first L1 hit (t=1.24, cpu 33 ms). Feel audit 2 named it the warmup frame. I did not chase it.
- I found no per-frame mesh bake and no print in play.

## Hand-feel pass

- Hitstop escalation:
  - Unchanged since fluidity's `0645b1a`: `git log -p` of the hang and stop constants is empty.
  - The sheets show the climb. Opener stops are x0.03 for one frame, mids for two, and enders get the hang and the white panel.
  - `hitstop_check` passes.
- No hang got longer. No hang constant moved, and leap-to-landing runs 638-1147 ms across the 15 breakers.
- Dash cancels connect: `input_snap_check` passes (every route step and dash cancel).
- The counter window reads:
  - the red tell at counter_D 023
  - the bracket on the hook in the pieces room (hook_counter_D after 023-030)
- Awakening feels faster.
  - Headless, `--start-awakened` against plain: the weapon beats are 18-24% shorter.
  - Examples: L H EC 285 -> 229 ms, L L L H L2 283 -> 220, L3 400 -> 319, EM 368 -> 312.
  - Later strings are confounded because the meter runs out.

## Coverage

From `fx_coverage --per-string`, on HIT frames:
- Plain room: mean 0.080-0.083, before and after.
- Film c's max rose from 0.186 to 0.305, because `wall D L H H H L` now plays Eruption.
- Pieces room: mean 0.097, max 0.313.

## Not verified / open for Zak

- The Tow Line dash pick is proved by `env_target_check` only. There is no film of it, because the bot presses H after the dash.
- Black Ice's skid still plays at the top-left edge (alt_H_L_H after 032-041). The cue moved the banner but barely moved the camera. Hang framing in general (item 10) is the next item.
- Cold Front's hoisted blocks still rise under the top banner (alt_L_H_L_H after 030-032). Cold Front has no cue.
- Item 10, round 54 (camera-hang lane): the hang framing, Black Ice's skid, Cold Front's hoist, stacked damage numbers, Collapse's spits, the pillar rubble and Eruption's banner total are done (see camera.md "Hang framing" and combo-breakers.md round 54). Still open: Cold Front's cube can't fit at x1.55, and its top still rises under the banner for ~0.3 s.
- The first-L1 33 ms CPU frame.
