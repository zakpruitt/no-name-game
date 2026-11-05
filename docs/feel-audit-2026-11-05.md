# Feel audit 2, 2026-11-05 (after round 2: rounds 33-40)

What the heretic's strings look like after round 2 (`git log d864e8a..9526983`, 127 commits), judged from film.
Same method as [round 1](feel-audit-2026-11-04.md): every `training_bot.BOT_STRINGS` string (22 now: the 13 old
ones, 6 crossovers / three-element strings and 3 element-matrix routes) filmed at 12 fps from the game camera
plus a HIT frame after each contact, by `tests/string_film.gd -- --dir=feelaudit2` (windowed, chibi, default
settings, dummies gathered in a fan per string). Also: the four spar foes (`-- --spar=<kind> --to=2`, the first
three strings with a live foe) and six hero clips (`tests/heretic_shots.gd -- --clips --clips-only=Run_F,Run_Start,
Run_Stop,Death_A,Ab_Swing,Ab_AF --clips-step=0.0333 --clips-max=60`, every keyed frame from the game angle).

Sheets and crops (PIL, session scratchpad, not committed; the scripts sit beside them in `tools/`):
`C:\Users\pruit\AppData\Local\Temp\claude\29abb69cf93759cc\4d1e6fe6-6db1-483d-bc24-50973d6a09fb\scratchpad\fa2\`
- `sheets\fa2_<string>.png`: every frame, labelled (real ms, move, hits, time scale; red = HIT, amber = in a freeze)
- `sheets\fa2_keys_<string>.png`: the middle of the screen zoomed on each move's first frame, the HIT frames, the slam
- `sheets_spar\<kind>\fa2_<string>.png`: the spar films; `sheets_clips\fa2_clip_<clip>.png`: the hero clips
- `crops\fa2_NN_<item>.png`: the frames each item below is judged from (paths given as `crops\...`)

Caveats as in round 1: the grab stalls a few ms, so the film's own `[rhythm]` lines run 1.5-2x long (L3 -> EM
840 ms filmed, 541 ms headless); the numbers below are from a headless `--autotest` at the same commit. The bot
Awakens whenever the meter fills, which is usually on a breaker landing. The hero presence pass (77d9ab3..b1613f8:
white hood over a deep dark body, scarf tail, face oval) landed after the film; Run_F, Run_Stop and Ab_AF were filmed
again on it (`sheets_clips_after\`), the strings were not.

## Numbers (headless `timeout 200 godot --headless --path . -- --autotest`, dev 9526983)

```
[autotest] done ... breakers=11/11 perfect_breakers=12 strings=22/22 endings=Grounded,Collapse,Maw,Worldbreaker,Avalanche,Abyss,Meteor_Fall,Cataclysm,Flash_Freeze,Black_Ice,Eruption,Anvil moves=(all 29)
[improv] frozen_x_void=3, buried_x_water=1, airborne_x_water=1
[perf] cpu avg=0.9ms worst=34.3ms (the first L1, warmup) cpu_spikes(>8ms)=9
```

### Rhythm against the 196 / 235 / 362 ms shape

Openers sit on the shape (L1 160-237 ms), mids too (L2 232-338, EC 235-330), enders mostly (L3 357-436, VS 343,
OW 334). Hand-overs over 400 ms (the ender's 362 plus slack), longest first:

| Hand-over | ms | String |
|---|---|---|
| L3 -> EM | 541 (437 in L L L H H) | L L L H |
| EC -> DL (a dash out of a move, then Dash Stab) | 500 | L H D L H |
| XR -> DL | 498 | L H L L D L H |
| EF -> TW | 467 | line D L H D H |
| EC -> AL1 | 456 | L H L H (325 in L H L L H) |
| IP -> TW | 451 | L L H D H H L |
| DL -> EF | 422-434 | D L H H L, the matrix strings (326-342 in the plain ones) |
| XR -> XF, EM -> EV, XG -> XM | 420-422 | Fault Line, Undertow, Meltdown |

The dash hand-overs (move, dash, Dash Stab, Harpoon) are the slow family: ~500 ms into Dash Stab and ~430 ms on
to Harpoon, against 326-342 when the string starts with the dash.

### Effect coverage (`python tests/fx_coverage.py <film> --per-string --max=0.40`)

88 HIT frames, **mean 0.090, median 0.068, max 0.309, PASS** under the 0.40 budget (round 33 sleek 6 measured
0.075 / 0.25 on its own run; bot timing and the Awakening column move a number by ~0.05).

| String | max | mean | String | max | mean |
|---|---|---|---|---|---|
| L H | 0.043 | 0.038 | L H L L H (Fault Line, Cataclysm) | 0.232 | 0.125 |
| L H H (Grounded) | 0.215 | 0.107 | D L H H L (Steam Burst, Flash Freeze) | 0.141 | 0.080 |
| L L L H | 0.068 | 0.058 | D H L (Storm Pitch) | 0.139 | 0.124 |
| H H (Collapse) | 0.177 | 0.104 | alt H L H (Black Ice) | 0.192 | 0.117 |
| H L H (Maw) | 0.204 | 0.127 | line D L H H H L (Hailstorm, Meltdown, Eruption) | **0.309** | 0.116 |
| L H L H (Worldbreaker) | 0.251 | 0.098 | L L H D H H L (Impale, Backdraft, Anvil) | 0.169 | 0.106 |
| D L H | 0.036 | 0.035 | line D L H D H (frozen x dark) | 0.107 | 0.075 |
| D L H H | 0.045 | 0.041 | L H L L D L H (buried x ice) | 0.203 | 0.088 |
| D H | 0.097 | 0.097 | L H D L H (airborne x ice) | 0.073 | 0.045 |
| L L H L H (Avalanche) | 0.108 | 0.053 | freeplay | 0.304 | 0.090 |
| hold (Abyss) | 0.266 | **0.220** | L L L H H (Meteor Fall) | 0.110 | 0.080 |
| L L L | 0.073 | 0.071 | | | |

Every frame over 0.2 is a breaker landing with the Awakening column in it, except `hold`, whose Overwhelm pool
alone is 0.17-0.27.

## Round 1's top 10, re-scored

1. **Impact frame only on slams and kills: fixed.** Strings flip only on the slam; freeplay flips once in 10 s (was every ~1.2 s).
2. **One word per beat, at the blow: fixed.** One live word per frame, at the contact. Left over: the last string's word can open the next (`crops\fa2_15_carryover_start.png`: Black Ice's KLISSSH! over Hailstorm's walk-up).
3. **Hero findable: mostly.** 13 m / FOV 37 with the paper rim reads in every move frame; on breaker landings he is still under the Awakening column (new item 1).
4. **Callouts end with their string: half.** The combo / breaker names now fade (`callout_cap`); the "New combo:" banner still runs through the whole next string (new item 4).
5. **Awakened gold: half.** The swoosh and echo are thin now; the Awakening column on the landing is the biggest shape in most breaker frames (new item 1).
6. **One number per breaker: fixed** (one total: 183, 289, 480...). The `LAST n` tags were not touched and are now the loudest text (new item 2).
7. **Clear the floor between strings: fixed** on the first hit (`standing_fx`). Maw's pool still stands through the next string's walk-up (`crops\fa2_15_carryover_start.png`), which is fine.
8. **Molten Palm needs a palm: half.** The fist is bigger and inked, but `EM_SPEED` went 2.1 -> 2.8, and the clip's coil is one held drawing (new item 7).
9. **Dash Stab and Harpoon land soft: not fixed** (new item 5).
10. **Frame the breaker hang: fixed** (`LIFT_FOLLOW`, HUD lines bottom right, Meteor Fall's pull-out).

## Top 10 for round 3 (ranked)

1. **The Awakening column buries every breaker landing.** `crops\fa2_01_awaken_column.png`, `crops\fa2_01_awaken_column_hold.png`
   - See: on Cataclysm, Abyss, Eruption, Worldbreaker and Grounded the bot Awakens on the landing, and the gold column plus its ring is the biggest shape for ~0.5 s, over the pile, the total and the hero (every coverage frame over 0.2).
   - Fix: when Awakening starts within ~0.6 s of a breaker landing, hold the column until the landing clears, or draw it ink-outline only at ~0.3 alpha (`hero_awaken.gd`, `elements.comic_column`). Lane: heretic-fx.
2. **`LAST n` tags on every dummy, all the time.** `crops\fa2_02_last_tags.png`
   - See: four big gold "LAST 1103 / 884 / 1105 / 790" labels sit over the pile for whole strings; they're now the loudest text on screen, bigger than the words.
   - Fix: show it only on the dummy hit most in the string, at the number's size, fading 1 s after the string ends (`training_dummy.gd` LAST tag). Lane: training.
3. **A name callout on every move.** `crops\fa2_03_move_callouts.png`
   - See: DASH STAB, HARPOON, ICE CUBE, HAILSTORM, MELTDOWN each pop over the hero in turn, so every beat has a name plus a word plus a number on him.
   - Fix: name only enders, crossovers and a first find; mids show the word alone (`player._combo_callout`, `callout_cap.gd`). Lane: heretic-fx / hud.
4. **The "New combo:" banner outlives its string.** `crops\fa2_04_found_banner.png`
   - See: "New combo: Deep Freeze" stays at the bottom through the whole next string (Overwhelm, Abyss, 2.7 s+); on Meteor Fall "Undertow" stays through all three beats.
   - Fix: cut it when the next string starts, `FOUND_HOLD` 2.5 -> ~1.2 s real time (`hud.gd`). Lane: hud / training.
5. **Dash Stab and Harpoon still land soft.** `crops\fa2_06_dashstab_harpoon_soft.png`
   - See: the DL and EF HIT frames are at x1.00 (no freeze) while every other contact freezes x0.03; the stab hits from past the foe.
   - Fix: brake DL's lunge on a foe ahead so the stab connects with its stop; give Harpoon's catch a stop (`hero_moves.gd` `DL`, `void_grab.gd` pull). Lane: combo-rhythm.
6. **Overwhelm's pool is the last thick colour.** `crops\fa2_05_overwhelm_pool.png`
   - See: a solid violet pool with magenta blobs fills half the frame from charge to the Abyss landing (the densest string: mean 0.22).
   - Fix: the halftone ghost look the frost floor got (`halftone_floor.gdshader`), one thin ink rim, the blobs as small inked beads (`dark_fx.gd`, `floor_bind.gd`). Lane: heretic-fx.
7. **Molten Palm's coil is one held drawing.** `sheets_clips\fa2_clip_Ab_AF.png`, `crops\fa2_07_molten_palm.png`
   - See: Ab_AF holds the same coiled-claw pose for frames 8-46 of 61, then shoves in two; at `EM_SPEED` 2.8 that reads as a pause and a blink, not a palm.
   - Fix: re-key the coil to ~16 building frames (squash, claw swelling) and bring `EM_SPEED` back to ~1.8 with the same hit time (`chibi_keys.py` Ab_AF, `hero_moves.gd`). Lanes: heretic (anim), combo-rhythm.
8. **The run reads as a hood dragging a claw.** `sheets_clips\fa2_clip_Run_F.png`, `fa2_clip_Run_Start.png`, `fa2_clip_Run_Stop.png`
   - See: from the game camera the hood and the x1.35 claw are the whole silhouette; legs barely show, and Run_Stop's frames 3-5 swing the hood 90 degrees so the skid reads as a spin. After the presence pass (`sheets_clips_aftera2_clip_Run_F.png`) the deep dark body sinks into the indigo floor, so it is even more a white hood and a violet claw.
   - Fix: smaller claw swing in the runs, feet wider / lean a touch less so the legs clear the hood, keep the stop's facing (`chibi_keys.py` Locomotion, check with `hero_stride_check`). Lane: heretic (anim).
9. **Meteor Fall's beats happen at the frame edge.** `crops\fa2_10_meteor_beats.png` (and `sheets\fa2_L_L_L_H_H.png` 031-043)
   - See: beat 1 throws land on the top wall at the edge, the right-hand foe leaves the frame, beat 2's tentacles read as lines going off screen; the hero is ~70 px; press to landing ~2.8 s of film.
   - Fix: throw along `_brk_dir` towards one wall inside the x2.0 view (or shorter), and tighten `METEOR_GATHER_AT` / `METEOR_DRAG_TIME` (`void_element.gd` `meteor_wall`). Lanes: combo, camera.
10. **Dash hand-overs drag.** (rhythm table above)
    - See: a dash out of a move into Dash Stab is ~500 ms, Harpoon after it ~430, Tow Line after Harpoon / the spear 451-467, against the 362 ender shape; the improvised routes all go through it.
    - Fix: let the dash's recovery cancel into DL sooner after a move (`_post_dash_t`), and a `DL` speed for the matrix routes (`hero_moves.gd`). Lane: combo-rhythm.

Smaller things seen:
- Spar: the rogue's cult violet is the hero's claw violet, so in a pile it reads as part of him; its telegraph is an opaque red disc under him (`crops\fa2_11_rogue_spar.png`; foe lane, `telegraph` look). The warrior and shield keep to the edge in the first three strings; spar needs hands.
- The spirit echo's brown halftone fan on L2 / L3 is still about a third of the frame (`crops\fa2_12_echo_fan.png`).
- Impale's hit frame: two cubes, the tendrils, a 106 on each and the star (`crops\fa2_13_impale.png`).
- The frost spear's halftone floor is 5 m across for the whole spear string (`crops\fa2_14_frost_floor.png`).
- Updraft Lash's teal swoosh is a wide filled band, the thickest swing left (`crops\fa2_09_updraft_sheet.png`).
- Overwhelm's charge is still a thin hoop (round 1's note).
- Ab_Swing's hang puts the claw over the hood: from the camera he's a violet ball (`sheets_clips\fa2_clip_Ab_Swing.png`).
- Death_A reads (flinch, stagger, face-plant with a bounce); at the flinch the hood's open top shows as a flat lid.
- Fixed in this lane: `foe_lean.gd` asked for a zero-axis Quaternion when a rogue or minion was tipped over (128 engine errors in one rogue spar film, 11 minion; 0 after), and `heretic_shots --clips-only=Death_A,Ab_Swing` filmed nothing because neither was in `CLIP_SET`.
