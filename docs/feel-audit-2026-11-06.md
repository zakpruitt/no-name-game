# Feel audit 3, 2026-11-06 (after rounds 44-45: hero model v2, designed fx, combo lightning)

What the heretic's strings look like on dev 2eb7f53, judged from film. Nothing in rounds 44-45 was played by hand:
the new hero mesh (same rig, smaller axe, damped hood squash), the redrawn tentacle, designed hit pops with crowd
caps, ground stamps, the quieter breaker cue, the air twister and lime lightning, sky strikes, kills / dust / dash
streaks, and the new combat (Live Wire's pulses down the tentacles, Galvanize, the charged state and its four
payoffs, Short Circuit). Same method as [audit 2](feel-audit-2026-11-05.md): every `training_bot.BOT_STRINGS` string
(30 now) plus 10 s of free play, filmed windowed at 12 fps from the game camera with a HIT frame after each
contact (`tests/string_film.gd -- --dir=feel3_all --from=0 --to=9`, `--dir=feel3_b --from=10 --to=19`,
`--dir=feel3_c --from=20`; 30/30 strings, 0 ERROR lines), and a headless `--autotest` for the numbers.

Sheets and crops (PIL, session scratchpad, not committed):
`C:\Users\pruit\AppData\Local\Temp\claude\29abb69cf93759cc\2f628767-f80e-409f-a781-d2c9e22989d6\scratchpad\`
- `feel3_all\<string>\NNN.png` + `INDEX.txt`: the film (frame numbers below are these)
- `sheets\<string>.png`: every frame, labelled (real ms, move, state, time scale, breaker phase; red = HIT, amber = in a stop)
- `crops\fa3_NN_<item>.png`: the frames each item is judged from

The film runs 1.5-2x slow round the grab and the frame grabs (Galvanize's reach-to-burst is ~670 ms of film, its
first-hit beat 246-316 ms headless); read the numbers from the autotest.

## Numbers (headless `godot --headless --path . -- --autotest`, dev 2eb7f53)

```
[autotest] done ... breakers=11/11 perfect_breakers=13 strings=30/30 endings=Grounded,Collapse,Maw,Worldbreaker,Avalanche,Abyss,Meteor_Fall,Cataclysm,Flash_Freeze,Black_Ice,Eruption,Anvil,Short_Circuit
[improv] frozen_x_void=1, buried_x_water=2, airborne_x_water=1, molten_x_wind=2, bound_x_wind=1, charged_x_wind=1, charged_x_void=3, charged_x_earth=3, charged_x_water=4
```

Hand-overs over 400 ms (the ender shape is 362), longest first: L3 -> EM 538 (L L L H and L L L H H; 435 in the
`out face` string), EM -> EV 532, IP -> TW 518 (the dash out of Frost Spear), EF -> TW 449, VR -> XC 428-434 on
the spread strings, XR -> DL 400. Galvanize frees him quickly: the bot's next press after `wait` comes 462-649 ms
after XC starts, and in the Overload film the L1 after it starts before the discharge lands (frame 019-021), so the
payoff never locks him.

Effect coverage (`python tests/fx_coverage.py feel3_all --per-string --max=0.40`): 138 HIT frames, **mean 0.072,
median 0.067, max 0.224, PASS** (audit 2: 0.090 / 0.068 / 0.309). No string over 0.23. The density problem has
moved off the HIT frames into the hang frames, where text and rings stack (items 1, 3).

## Audit 2's top 10, re-scored

1. **Awakening column on breaker landings: fixed.** No column in any landing frame; the impact frame reads clean (L_H_L_H 038-040).
2. **`LAST n` tags: fixed.** Gone from the pile.
3. **A name on every move: fixed** for mids. Enders and crossovers still go up, and in a hang they sit on him (new item 3).
4. **"New combo:" banner: fixed** to its string (fades by the next string's first hit).
5. **Dash Stab and Harpoon soft: fixed.** DL and EF HIT frames freeze x0.03 (line_D_L_H_H_H_L 018, 023).
6. **Overwhelm's pool: fixed** (hold: thin dark pool, max 0.097).
7. **Molten Palm's coil / L3 -> EM: open.** 538 ms headless (new item 7).
8. **The run: not judged** (no clip film this round).
9. **Meteor Fall at the frame edge: half.** The beats are gone; the wall splat still goes to the top-left corner (new item 6).
10. **Dash hand-overs: mostly fixed** (DL -> EF 283 everywhere); IP -> TW 518 and EF -> TW 449 remain.

## Top 10 (ranked)

1. **Live Wire's hang stutters and buries him.** `crops\fa3_01_livewire_hang.png` (L_H_H 018-028, L_H_L_H 027-036, spread_far_alt_L_H_H 020-030)
   - See: through the whole hang the time scale alternates x0.03 / x1.0 / x0.03 frame to frame (L_H_H 018 x0.03, 019 x1.0, 020 x0.03, 021 x1.0 ... then the window's x0.6 with x0.03 cut into it, L_H_L_H 030-035). Every pulse is its own freeze, so the hang reads as a stalling engine, not current; the 35 ms stops add ~35% to the hang's real length. On top of him at the same time: the LIVE WIRE name (item 3), the breaker prompt circle, the "SHORT CIRCUIT or GROUNDED" line, the ZZZAKT! word, a climbing number per foe, the pulse forks and the crawling arcs on each held foe.
   - Cause: `live_current._run` calls `Game.hitstop(ZAP_STOP)` (0.035 s) on the first foe of every pulse, every `WIRE_STEP` 0.1 s, `WIRE_STEP` 0.1 game s apart.
   - Fix: the first pulse keeps its stop (the hang's "it connected"); later pulses a hair-stop (`ZAP_STOP_AFTER` ~0.012 s) so the jolts read as rhythm in the slow motion, not stalls. Owner: this lane (timing constants in `live_current.gd`).
2. **The combo guide sits on the pile in every string that faces right.** `crops\fa3_02_guide_on_pile.png` (L_H_H 007-017, L_L_L_H_H 011-034, H_L_H 009-021, every sheet)
   - See: the LMB / RMB / SPACE rows are drawn across the dummies he is hitting, under the hit star and the number.
   - Cause: a bug. `combo_guide._draw` picks the side away from the pile (feel audit 1's fix), then its right-edge hysteresis branch `elif _side < 0.0 and at.x < screen.x - EDGE - 80.0: _side = 1.0` runs whenever he is not near the right edge and sends every left choice back to the right. The pile choice has never held.
   - Fix: keep the pile's choice in its own field and let each edge override it with its own slack (`combo_guide.guide_side()`). Owner: this lane.
3. **Ender and crossover names sit on him in the hang.** `crops\fa3_03_hang_name_meltdown.png` (line_D_L_H_H_H_L 037-044 MELTDOWN, L_H_H 019-030 LIVE WIRE, L_L_H_L_H 021-031 DEEP FREEZE, H_L_H 022-030 BLACK TIDE, L_L_L_H_H 035-042 UNDERTOW)
   - See: the hang lifts his model ~2 m, so the name placed 2.9 m over his feet lands on his chest, inside the prompt circle, for the whole hang. The hero in the hang is a hood behind a word.
   - Cause: `hero_fx.combo_callout` places the label at `position.y` 2.9 on the body, and the leap lifts `model`, not the body; `callout_cap` moves only breaker names to the top band.
   - Fix: while he is in State.LEAP, a named callout goes to the top band too (`callout_cap._place`, where the breaker's name replaces it on landing). Owner: this lane (`callout_cap.gd` words).
4. **Words with nothing doing them: the lava well's burn is a full hit every tick.** `crops\fa3_04_well_words.png` (spread_H_L_L 000-029: 2.4 s of RRAAAH! / VRRRSH! / THOOOM! and hit stars on two dummies while he stands; the hit count climbs 149 -> 175)
   - See: after any magma string with Undertow, the dummies take a star, a word and a "6" every 0.5 s for 4 s, into the next string's walk-up; Undertow's lava look is gone after 0.9 s (`WELL_COMIC_SHOW`), so nothing on screen does it.
   - Cause: `elements.Well` ticks with `take_hit(...)`, not `burn_hit()` (the quiet hit floor_bind's own ticks use).
   - Fix: tick with `burn_hit` (pose hold, number, no star or word). Same damage. Owner: this lane (hit reactions).
5. **Short Circuit's payoff happens off screen.** `crops\fa3_05_short_circuit_offscreen.png` (spread_far_alt_L_H_H 025-037)
   - See: the "far" foe the move is for stands left of the frame; Live Wire's arc to it is a lime line running off the left edge for the whole hang, and after the landing the Short Circuit arcs go to the edge (034-037). The best situation of the move is the part you can't see.
   - Cause: the camera's fight framing is off in a hang (calm pass), and after the landing the landing punch narrows the view while `_frame` eases out at `FRAME_OUT` 2.5 /s, slower than `SC_DELAY` 0.12 s + `SC_STEP` 0.06 s per arc.
   - Fix: let a foe zapped in the hang count for the framing the moment he lands (ease out faster for ~0.5 s after a landing that has foes outside the safe box), or let `_frame_fight` zoom out (no lean) in a hang for foes hit by the current. Owner: camera (this lane); judge stacked with the punch.
6. **Meteor Fall's wall splat is in the top-left corner.** `crops\fa3_06_meteor_corner.png` (L_L_L_H_H 029-046)
   - See: Molten Palm carries the foe to the top-left wall; Undertow's pull, the dive target and the "SKRAAK!" sit at the corner with the foe half off frame for ~0.8 s, the hero ~70 px at the other end.
   - Cause: the hang keeps him centred (no framing), and the palm's carry is along his aim to the room's wall ~9.5 m up-screen (camera.md "Meteor dive").
   - Fix: same as 5 (count the splatted foe for framing in the hang), or shorten the carry so the splat lands inside the x1.25 view. Owner: camera / combo lane.
7. **L3 -> Molten Palm is still the slowest hand-over.** (rhythm above: 538 ms, EM -> EV 532)
   - See: the L L L strings into magma pause on the third chop before the palm; it reads as the string ending, then a second string.
   - Cause: Ab_AF's coil is one held drawing at `EM_SPEED` 2.8 (audit 2 item 7).
   - Fix: re-key the coil (anim), then `EM_SPEED` down with the same hit time. Owner: heretic anim + combo-rhythm (needs a drawing).
8. **The frost spear's halftone floor is still 5 m across.** `crops\fa3_08_spear_floor.png` (L_L_H_L_H 018-020)
   - See: a pale blue halftone disc with cracks fills a third of the frame for the spear's beat, over the dummies' feet.
   - Fix: the ground-stamp language (3-5 broken brush arcs, `designed_ink.shock`) at ~2.5 m. Owner: fx-elements (`frost_spear`).
9. **The spirit echo's brown halftone fan on L2 / L3.** (L_L_H_L_H 006-010, L_H_L_H 018-021, out_face 013-019)
   - See: the brown halftone ghost-axe fan is still the biggest shape on L2 / L3 / Air Slash, larger than the axe arc it echoes, and its brown sits under the gold arc.
   - Fix: half the size, ink line only, gone by the hit. Owner: fx-finish (spirit echo).
10. **The landing number and word at the top edge on H L H.** (H_L_H 034-037, L_H_L_H 000)
    - See: Maw drags the pile up-screen, so the 509 / 535 total and MAW PERFECT sit at the top edge, half cut, beside the breaker name in the top band.
    - Fix: `ComicNumber` keeps a total inside the page margin (`_on_page` like the words). Owner: this lane (`comic_number.gd`), small.

Smaller things seen:
- Galvanize: reach -> charge -> burst reads as three beats and never locks him (the next press lands before the burst, Overload 019-023). Its GALVANIZE name sits on him through the charge (item 3's rule out of the hang; left).
- Spear vault (IJ) hits at x1.00: the only contact without a stop (L_L_H_L_H 016).
- Updraft Lash's air twister swirl (pale blue S-curls) is the biggest shape of the L H strings for ~0.3 s (L_H_H 014-020); fine as a beat, but with Live Wire's hang straight after, it is still on screen under the prompt.
- The "line" strings' walk-up puts the column at the top-left edge for ~1 s before the dash (bot setup, not play).
- No old green: the storm lime is consistent (axe edge, pulses, arcs, Short Circuit). No pose pops seen on the v2 mesh at 12 fps; the smaller axe meets the dummies on every L HIT frame.

## Fixed in this lane (before / after from film)

Before / after sheets and clips: `C:\Users\pruit\Desktop\awaken-combo-clips\24 Feel *`.
1. Live Wire's later pulses take `ZAP_STOP_AFTER` 0.012 s (first pulse keeps 0.035). L_H_H after: the hang reads
   x0.03 on the first pulse, then a steady x1.0 / x0.6; the landing comes at 2232 ms of film (was 2320).
2. `combo_guide.guide_side()`: the rows sit on his left, off the pile, in every right-facing string (L_H_H after 007-017).
3. `callout_cap`: while his model is lifted (`HANG_LIFT` 0.6 m) a named callout goes to the top band (L_H_H after 018-028:
   LIVE WIRE above the pile, then GROUNDED PERFECT in the same place).
4. The lava well ticks with `burn_hit`: the walk-up into spread_H_L_L has numbers only, no stars or words.
5. `camera_rig.FRAME_CUE`: Short Circuit cues its targets at the landing (`SC_CUE_MS` 900) and the view eases out at
   `FRAME_CUE_OUT` 7 /s; the far foe is in frame as the arc lands (headless probe: worst foe NDC at the far arc 1.47 -> 1.06).
10. `comic_number.dodge` keeps a number inside `PAGE_MARGIN` (2% / 4%) of the screen: Maw's total sits whole below the
   top edge (H_L_H after 034-040; windowed only, the 64 px headless root is skipped).
