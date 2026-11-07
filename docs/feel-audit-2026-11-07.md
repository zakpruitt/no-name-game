# Feel audit 5, 2026-11-07 (fluidity lane: hand-overs, contacts, eaten presses, hit weight)

Zak: "work in a loop increasing combat fluidity, ensure everything is snappy and very fun." This lane measured every
bot string first, ranked what is slow or dead, and fixed the top of the list in two batches.

Method: headless `--autotest` (its `[rhythm]` lines give each hand-over's "beats": the previous move's first hit to
this move's first hit, real ms) and `tests/rhythm_check.gd`; windowed `tests/string_film.gd` for all 39 strings
(`--from=0 --to=12 --dir=flu0_a`, `--from=13 --to=25 --dir=flu0_b`, `--from=26 --dir=flu0_c` before; `flu1_*` after
batch 2), one PIL sheet per string labelled from INDEX.txt (frame, real ms, move, time scale). Frame references below
are `film0` (before, dev b7affe1) and `film1` (after, this lane), as `string frame@ms`. Film grabs stall a few ms
each, so film gaps run 10-20 ms over the bot's beats; the numbers are the bot's. Films and sheets are in the session
scratchpad (`scratchpad\flu\`), not committed. Clips for Zak: `Desktop\awaken-combo-clips\35 Fluidity *`.

Targets: mid -> mid under 330 ms, mid -> ender under 380 ms, no contact at x1.00, no press eaten by a carry or a
gather, a dash cancel out of anything connects on the next press.

## Ranked list (before)

Hand-overs over 380 ms, then the worst under it (bot beats, worst run):

| # | Hand-over | Beats | Film (film0) | Cause |
|---|---|---|---|---|
| 1 | L3 -> Molten Palm (L L L H) | 402-535 | L_L_L_H 023@1764 -> 030@2315: four near-identical coil frames 026-029 | Ab_AF's coil was f1-f50 of 99 (the palm 350 ms in at EM_SPEED); L3's recovery waited for CANCEL_ON_HIT 0.5 |
| 2 | Vault -> Deep Freeze (L L H L H) | 453 | L_L_H_L_H 015@1055 -> 020@1429 | IJ's cancel late in the vault, IS's wind-up slower than its peers |
| 3 | L2 -> L3 (Triple Chop) | 331-436 | L_L_L 007 -> 012 | L3_SPEED 1.3: the chop 380 ms in |
| 4 | Rockslide -> dash -> Dash Stab | 435 | face_L_H_L_L_D_L_H 024@1727 -> 030@2144 | Rockslide's wind-up at speed 1.2, the stab at 1.0 |
| 5 | Hailstorm -> Meltdown | 434 | line_D_L_H_H_H_L 031@2321 -> 036@2671 | Hailstorm's cancel at CANCEL_ON_HIT 0.5 |
| 6 | Harpoon -> dash -> Tow Line | 386 (gap 483) | line_D_L_H_D_H 021@1655 -> 027@2088 | a heavy out of a dash waited for the whole dash |
| 7 | Ice Cube -> Hailstorm | 367 | line_D_L_H_H_H_L 027 -> 031 | Ice Cube's cancel at 0.5, Hailstorm at speed 1.2 |
| 8 | Updraft Lash -> Rockslide, Frost Spear -> Tow Line | 366 | | |
| 9 | Dash Stab -> Harpoon | 353 | | LLH_SPEED 1.6 |
| 10 | grab -> Reap / Vortex | 337-355 | | Reap at speed 1.2 |

Contacts at x1.00 (a HIT frame with the scale still 1.00 and the combo going up):

- **Ice Cube on Harpoon strings**: D_L_H_H 024, line_D_L_H_H_H_L 027. Ice Cube pressed during Harpoon's carry: the
  row was still flying on the tentacles, the bowl found nobody standing, the latch hits played at x1.00.
- **The spirit echo's casts where the blade whiffed** (spread and wall layouts): spread_alt_L_L_L_H_H 017 / 020 /
  025, wall_spread_L_L_L_H_L 010 / 014 / 020, wall_alt_L_L_H_D_H_H_L 015 / 019, spread_far_alt_L_H_H 011. The echo's
  cast hit a far foe with no stop of its own.

Eaten presses (found writing `tests/input_snap_check.gd`; the bot times its presses, so its films don't show them):

- **H in Impale's pause window, pressed before the leap**, went to GR (a grab: H after Dash H H routes there) and
  ended the string; **L in Harpoon's window** went to L3 (Triple Chop's hammer). The documented route is Backdraft /
  Ice Cube once the window opens, and a player presses early.
- **Every press made during a breaker's dive was cleared on landing** (`hero_leap._end` set `_buffered = ""`), so a
  player starting the next string mid-dive got nothing.
- **Pinwheel's 0.42 s whirl** is longer than `BUFFER_MS` 300: a press early in it expired before the landing.

Hit weight: the named mids froze as long as or longer than the enders (Rockslide 0.12 s, Hailstorm 0.13, Molten Palm
0.145 with their tier stop added, against Live Wire / Eruption 0.10 and Lava Leash 0.09), so the string's weight did
not climb, and every mid took its tier's full camera punch.

Hitches: none on the 39 films beyond the above (the coil hold is #1; Ice Cube waiting on the carry is the contact
above). Autotest `[improv] frozen` lines: 3.

## Fixes

Batch 1 (commits `d43d625` anim, `5f7d71f` combat, `027176f` input):

1. **Molten Palm's coil re-keyed** (`tools/meshy_rig/clip_warp.py`, new: retimes one clip inside an exported GLB, no
   blend needed). Ab_AF drawings 19, 35, 39 dropped (repeat shakes and charges), the rest remapped
   `1:1,7:6,13:11,25:16,31:21,43:25,47:29,50:32`; the palm lands on f32 of 81 (was f50 of 99), everything after it
   unchanged. The same keys are in `chibi_keys.py` (`CLIPS["Ab_AF"]`, `PUNCH`) so a full re-key reproduces it. The
   round-28 heretic.glb took the same map (`--linear`). `void_element.AF_HIT` 32/81, and `AF_K` 99/81 rescales every
   fraction tied to the old length (`LEAP_AFTER_PALM`, `EM_CANCEL`, `EM_END`). Plus L3: `L3_SPEED` 1.3 -> 1.6,
   `L3_CANCEL` 0.7, `L3_END` 1.02, `L3_CONFIRM` 0.8.
   L3 -> EM **535 -> 369 ms**; film1 L_L_L_H 020@1587 -> 025@1971: draw 022, charge 023-024, palm 025.
   L2 -> L3 **436 -> 373** (380 after batch 2 on the out_face string).
2. **Vault -> Deep Freeze**: `VAULT_CANCEL` 0.25, `DEEP_FREEZE_SPEED` 1.35. **453 -> 370 ms** (film1 L_L_H_L_H
   016@1127 -> 021@1466).
3. **Rockslide -> Dash Stab**: `ROCKSLIDE_SPEED` 1.35, `DASH_STAB_SPEED` 1.15. **435 -> 386 ms** (film1
   face_L_H_L_L_D_L_H 022@1667 -> 026@2000).
4. **Hailstorm -> Meltdown**: `HAIL_CONFIRM` 0.8, `MELT_SPEED` 1.65. **434 -> 351 ms**.
5. **Harpoon -> dash -> Tow Line**: a heavy buffered in a dash out of a move hands over at
   `hero_input.TOW_LINE_CANCEL` 0.7 of the dash. **386 -> 346 ms** (Frost Spear -> Tow Line 366 -> 303).
6. **Ice Cube sets the row down**: `_ice_cube` calls `harpoon_gather.finish_now()` if the gather is still carrying,
   then bowls. film1 D_L_H_H and line_D_L_H_H_H_L: Ice Cube's HIT frames at x0.03.
7. **The echo's cast stop**: a cast that lands more than `spirit_echo.CAST_STOP_GAP_MS` after the last stop ended
   takes `CAST_STOP` 0.03 s (inside or just after the blade's stop it adds nothing, so beats do not move). Batch 2
   lowered the gap 150 -> 90 ms: on film1 wall_alt_L_L_H_D_H_H_L 018, L2's cast 118 ms after L1's stop still played
   at x1.00.
8. **Hit weight escalates** (`hero_moves.hit_stop` / `cam_tier`): opener `HITSTOP_OPENER` 0.8 as before; a mid holds
   at most `MID_STOP_MAX` 0.09 s (`BIG_MID_STOP_MAX` 0.1 for a `big` move); an ender (a breaker leap, Triple Chop's
   L3, a tier-3) at least `ENDER_STOP_MIN` 0.11; a mid's camera punch is tier 1 at most, an ender's its full tier.
   No hang got longer (the caps only shorten mids; the enders that rose were already at 0.1).
9. **No press eaten** (`hero_input.held_for_window`, `hero_leap`): a press of a pause window's button whose route
   would not continue the string (a grab, a chain light) is held into the window and dives on that button's ending
   as it opens; a dive press is dropped when the dive starts, not when it lands; a press in a dive longer than the
   buffer is kept to the landing.

Batch 2 (commit `0645b1a`, plus the cast gap):

10. `LLH_SPEED` 1.75 took Dash Stab -> Harpoon 353 -> 345, but Harpoon then set its row down without ice blocks
    (`ice_block_check`), so it is back at 1.6 (353 ms; not investigated further). `ICE_CUBE_CONFIRM` 0.8 + `HAIL_SPEED` 1.35: Ice Cube ->
    Hailstorm **367 -> 319**, Hailstorm -> Meltdown 351 -> 343. `REAP_SPEED` 1.35: grab -> Reap **337 -> 317**.
    Autotest `[improv] frozen` lines 3 -> 0 (the autotest only reports these; not gated).

## After (bot beats, worst run, batch 2)

| Hand-over | Before | After | Target |
|---|---|---|---|
| L3 -> Molten Palm | 535 | 373 | ender 380 |
| L2 -> L3 | 436 | 380 | ender 380 |
| Vault -> Deep Freeze | 453 | 370 | ender 380 |
| Rockslide -> dash -> Dash Stab | 435 | 385 | mid 330 (a dash between) |
| Impale -> Pinwheel (XK -> XW) | 385 | 385 | window -> ending |
| Hailstorm -> Meltdown | 434 | 343 | ender 380 |
| Harpoon -> dash -> Tow Line | 386 | 345 | mid 330 (a dash between) |
| Dash Stab -> Harpoon | 353 | 353 | mid 330 (line layout; 270-333 elsewhere) |
| Frost Spear -> Tow Line | 366 | 317 | |
| Updraft Lash -> Rockslide | 366 | 332 | |
| Ice Cube -> Hailstorm | 367 | 319 | |
| grab -> Reap | 337 | 317 | |

Contacts at x1.00 on film1: the Ice Cube ones are gone. What the scan still flags is not a contact: the L3 HIT frames
on the spread / wall layouts are blade whiffs (the combo does not go up), and L1's HIT frames there show the stop on
the next grab 12 ms later. One was real (wall_alt 018), fixed by the 90 ms gap but not re-filmed.

## Checks

`tests/input_snap_check.gd` (new, in `agent.sh check`): steps the real hero at 240 Hz and presses at every ms within
10 ms of each boundary (every 16 ms between) through every move's route step, whiffed and connected, light and heavy;
every dash cancel; every breaker window (ignored / lock / held / dive / miss / alt per `BREAKER_SPILL` /
`BREAKER_EARLY`); and a press anywhere in a dive. It fails on the old code (H off Impale -> GR; dive presses). About
66 s. rhythm_check, hitstop_check, camera_feel_check and kit_check PASS; autotest breakers 15/15, strings 39/39,
endings_n 21/21.

## Open, for Zak

- The dash hand-overs (Rockslide -> Dash Stab 385, Harpoon -> Tow Line 345, Dash Stab -> Harpoon 353 on the line)
  stay over the 330 mid target, because the dash's own travel is in the beat. Getting them shorter needs a shorter
  dash, which changes movement everywhere.
- Impale -> Pinwheel 385: that time is the window's hang, which belongs to the ending, not the hand-over; left.
- Awakening was not re-timed: its anim_mult already speeds every move, and the one Awakened film
  (`out_face ... wait L H`) shows no stall of its own. Not checked on film beyond that string.
- The cast gap change (150 -> 90 ms) was checked by the snap and rhythm checks, not re-filmed.
