# Feel audit, 2026-11-04 (after rounds 27-31)

What the heretic's strings look like after the overnight loop, judged from film, not from the code.
Every string the autotest bot knows (`training_bot.BOT_STRINGS`: 13 strings, all 21 moves, the 7 breakers)
was filmed at 12 fps from the game camera, plus an extra frame the first drawn frame after each hit, by
`tests/string_film.gd` (windowed; chibi heretic, default settings, the bot pressing as soon as
`combo_window()` allows and hitting every breaker's sweet spot). Each string starts with him in the middle
of the room and the four dummies in a fan 2.2-3.2 m in front of him. The bot fills and fires Awakening when
the meter is full, so from L L L H on most strings play Awakened (gold).

Sheets (PIL, in the session scratchpad, not committed; rerun the film and the two scripts beside them to
rebuild): `C:\Users\pruit\AppData\Local\Temp\claude\29abb69cf93759cc\4d1e6fe6-6db1-483d-bc24-50973d6a09fb\scratchpad\audit\sheets\`
- `feelaudit_<string>.png`: every frame, labelled with real ms, the move, hits done and `Engine.time_scale`
  (red label = the HIT frame, amber = a frame inside a freeze)
- `feelaudit_keys_<string>.png`: the middle of the screen zoomed on each move's first frame, the hit frames
  and the slam
- `feelaudit_freeplay.png`: 10 s of the bot chaining strings after the pass, as one long strip

Caveats: a frame grab stalls a few ms, so freezes and slow motion in the film run a touch long; read
the `[rhythm]` lines below for timing. Stills show a beat, not the motion between beats, so "stepping in
motion" and the feel of the ease curves still need hands.

## Numbers (windowed `timeout 120 godot --path . -- --autotest`, dev 738a619)

```
[autotest] combo_breaker #1 EE perfect=true
[autotest] combo_breaker #2 VS perfect=true
[autotest] combo_breaker #3 VD perfect=true
[autotest] combo_breaker #4 EW perfect=true
[autotest] combo_breaker #5 IS perfect=true
[autotest] combo_breaker #6 OW perfect=true
[autotest] combo_breaker #7 EV perfect=true
[rhythm] L H: L1->EC gap=233 ms | beats L1 214, EC 289 ms
[rhythm] L H H: L1->EC gap=294 ms, EC->EE gap=423 ms | beats L1 210, EC 364, EE 295 ms
[rhythm] L L L H: L1->L2 gap=251 ms, L2->L3 gap=300 ms, L3->EM gap=516 ms | beats L1 202, L2 299, L3 417, EM 634 ms
[rhythm] H H: GR->VS gap=250 ms | beats GR 152, VS 470 ms
[rhythm] H L H: GR->VR gap=217 ms, VR->VD gap=367 ms | beats GR 119, VR 303, VD 285 ms
[rhythm] L H L H: L1->EC gap=233 ms, EC->AL1 gap=334 ms, AL1->EW gap=249 ms | beats L1 168, EC 270, AL1 298, EW 199 ms
[rhythm] D L H: DL->EF gap=355 ms | beats DL 166, EF 400 ms
[rhythm] D L H H: DL->EF gap=334 ms, EF->EA gap=383 ms | beats DL 184, EF 417, EA 235 ms
[rhythm] D H: one move | beats TW 102 ms
[rhythm] L L H L H: L1->L2 gap=283 ms, L2->IP gap=317 ms, IP->IJ gap=500 ms, IJ->IS gap=283 ms | beats L1 202, L2 334, IP 400, IJ 348, IS 405 ms
[rhythm] hold: one move | beats OW 287 ms
[rhythm] L L L H H: L1->L2 gap=233 ms, L2->L3 gap=267 ms, L3->EM gap=450 ms, EM->EV gap=550 ms | beats L1 169, L2 250, L3 367, EM 534, EV 298 ms
[rhythm] L L L: L1->L2 gap=234 ms, L2->L3 gap=266 ms | beats L1 171, L2 249, L3 366 ms
[autotest] done player_hp=100 max_combo=233 hits=263 awakening=17 rank=SSS perfect=0 air=1 guide=13 casts=13 breakers=7 perfect_breakers=7 strings=13/13 moves=L1,EC,EE,L2,L3,EM,GR,VS,VR,VD,AL1,EW,DL,EF,EA,TW,IP,IJ,IS,OW,EV
[perf] avg=16.5ms worst=25.5ms spikes(>25ms)=1/1671 cpu avg=1.3ms worst=8.6ms cpu_spikes(>8ms)=1 gpu avg=0.6ms worst=1.1ms max_enemies=4 max_draw_calls=683 max_nodes=848
```
(The run before it: `cpu worst=8.0ms cpu_spikes(>8ms)=0`, 0 wall spikes. The one cpu spike is EV's breaker
frame, as in round 31.) `[training] strings=1`: the bot's 0.35 s gap never lets the combo drop, so the whole
31 s run counts as one string and the dummies' `LAST n` tags never split per string.

## What reads across every string

- **The hero is small and often lost.** At the game camera (`camera_rig.offset` (0, 13, 9.5), FOV 42) the
  1.85 m chibi is a white hood about 40 px tall in a 900 px frame. Mid-string the combo guide rows sit
  right beside him, over the pile; in every breaker hang and slam he is under the bolts, rings and words,
  and in five of seven slams there is no frame where he can be found.
- **Contact holds are there and read as beats.** L1 / L2 freeze one or two frames (x0.03), L3 and EM three,
  breaker slams three to four at x0.05 with the impact frame. The freeze lands on a frame where the blade
  is in the pile, which is round 30's contact-frame work showing.
- **The impact frame has stopped being special.** It flips the screen to the paper negative on L3, EM, VS,
  VD, EA, TW, OW, IS and EV as well as every breaker slam. L L L H H flips four times in 1.5 s.
- **Words pile up, repeat and sit away from the hit.** Three to four words are live at once, the same word
  is often on screen twice or three times (THOOOM! x3 in H L H, VRRRSH! x3 in L H L H), and `_place` puts
  them 2-4 m from the contact in empty floor, so they read as captions, not as the sound of a blow.
- **Text from the last string stays into the next.** The combo-name callout ("Grounded PERFECT", "Molten
  Palm", "Maw PERFECT") hangs over the hero for the first 1-1.5 s of the next string: its tween runs on game
  time, which hitstop and the breaker's slow motion stretch. The "New combo:" banner stays 2 s or more.
- **Numbers.** One inked number per foe is clean on single hits. On breakers four equal big numbers
  (157 / 157 / 157 / 157 on Collapse, 139 x3 on Abyss) plus four `LAST n` tags make a block of numerals
  over the pile.
- **Awakened swings are gold sheets.** Once Awakened, L2 / L3 / EC's crescents (swoosh plus the swollen
  weapon trail in `AWAKEN_COLOR` at chain tier 3) are opaque gold shapes four to five times his height,
  covering him and the pile for about 300 ms per swing.
- **Ground effects carry over.** Maw / Abyss's black pool, Meteor Fall's geysers and Undertow's crack splat
  are still under the pile for the first 1-1.5 s of the next string, so the next string's own effect has
  to fight them.

## Per string

**L H (Slice > Updraft Lash)** — `feelaudit_L_H.png`, `feelaudit_keys_L_H.png`. The cyan L1 crescent and
the green gale bands read well and the EC freeze lands with the tentacle in the pile. The lift does not
read from this camera: the dummies stay on the floor inside the gale and nothing goes up. FWOOSH! and WHAK!
sit up and left of him while the guide rows cover the right-hand dummy; recovery is a clean 300 ms stand.

**L H H (> Live Wire, Grounded)** — `feelaudit_L_H_H.png`. The hang is the best-reading breaker set-up: fat
green zigzags over a held pile, numbers growing on each foe. But FWOOSH! / KRAK! / THOK! from EC are still
up when ZZZAKT! arrives, so four words share the hang, and the hero is invisible inside the bolts. The slam
is three negative frames, then a gold sky strike so wide that the "Grounded PERFECT" callout behind it
cannot be read; the yellow ring runs off the screen.

**L L L H (Triple Chop > Molten Palm)** — `feelaudit_L_L_L_H.png`. L1 / L2 / L3 rise in weight the way round
30 meant, and L3's longer hold with its negative frame gives the string an ending even before the palm.
Molten Palm itself is the weak beat: the 2.1x wind-up is gone in four frames, and the shove reads as a
small magenta smear and an orange crack star, not a huge open palm. KA-POW! lands up and right with nothing
under it.

**H H (Grab > Singularity, Collapse)** — `feelaudit_H_H.png`. GR's grab reaches 9 m, so in the fan it often
takes a foe at the top edge of the frame and the rope reads as a line leaving the screen. Singularity's ink
hole is a strong, clear shape. The Collapse slam is a negative full of four "157"s and SHLUMPF!; once the
colours come back the callout, the burst star, the numbers and the word all sit on the same pile.

**H L H (Grab > Reap > Black Tide, Maw)** — `feelaudit_H_L_H.png`. Reap's magenta crescent and the Black Tide
pool read well and quickly (beats 303 / 285 ms). Words are the problem here: THOOOM! three times plus SHUNK!
and SPLOOSH!, all below the hero where nothing happens. The Maw spike is a good silhouette, but its slam is
a negative with the pile half off the top of the frame.

**L H L H (Slice > Updraft Lash > Air Slash > Live Wire, Worldbreaker)** — `feelaudit_L_H_L_H.png`. The most
motion of any string: hop, air slash, the dive. Played Awakened, every swing is a gold sheet and the hop is
hard to see under it; the previous string's Maw pool is still under the pile. Worldbreaker's landing
(KRAKATHOOM!, 232) is one of the best single frames in the set once the negative clears.

**D L H (Dash Stab > Harpoon)** — `feelaudit_D_L_H.png`. With the dummies 2.2 m away the dash stab carries
him through and past them; the visible damage is the spirit tomahawk's (no freeze on the "hit" frame) and in
all three filmed runs the bot's H never started Harpoon (it does in the autotest, where the foes start
further off). The dash smear itself reads well.

**D L H H (> Ice Cube)** — `feelaudit_D_L_H_H.png`. Harpoon's purple line reads as a pull, but its first
frame after contact shows no freeze (x1.00), so it lands soft next to the other hits. The cube is small at
this camera, a pale blue block nearly hidden under the `LAST n` tags; KLONK! and SMASH! are well placed.

**D H (Tow Line)** — `feelaudit_D_H.png`. Fast and clear: a 102-175 ms beat, the dark tendrils whip on twos
and YOINK! is beside him. The negative fires on a tier-2 combo that has no slam, which makes it read bigger
than it is; the tow itself (foes coming to him) is not visible in the stills.

**L L H L H (> Frost Spear > Vault > Deep Freeze, Avalanche)** — `feelaudit_L_L_H_L_H.png`. The longest
string (about 3.7 s) and the best-paced breaker: the frost spear's ice-teeth disc builds over five frames,
the vault and dive read, the cubes drop. The ice disc is bright and 4-5 m wide and fills the frame for about
a second; Avalanche's slam is three negative frames then a gold column.

**hold (Overwhelm, Abyss)** — `feelaudit_hold.png`. The charge is a thin yellow hoop round him that reads as
"waiting", not as power gathering. The slam's purple pool and Abyss's violet spikes are among the clearest
dark shapes; the numbers (131 / 139 / 139 / 139) again stack into a block.

**L L L H H (> Undertow, Meteor Fall)** — `feelaudit_L_L_L_H_H.png`. Undertow's lava ring and Meteor Fall's
geysers are bold and the foes show between the tongues. But this string flips the impact frame four times
(L3, EM, EV, slam), and during the hang the hero rises into the top fifth of the screen under the HUD's
TRAINING / THIS STRING lines because the camera does not lift with the leap. Recovery after the slam is
about 0.5 s of standing in the geysers.

**L L L (Triple Chop)** — `feelaudit_L_L_L.png`. Clean rhythm (171 / 249 / 366 ms). Awakened, the L3 chop is
a flat gold axe shape three times his size that covers him for three frames; un-Awakened (earlier runs) it
reads as a good heavy ender. It also starts inside the last string's Meteor geysers.

**Free play** — `feelaudit_freeplay.png`. Ten seconds of the bot chaining L H, L H H, L L L H, H H, H L H.
There is never a quiet frame: every string starts under the last one's callout, words and ground effect,
the screen flips negative about every 1.2 s, and the hero is findable in maybe a third of the frames.

## Top 10 to fix next (ranked)

1. **Save the impact frame for slams and kills.** It fires on any freeze of 0.1 s or more, which now includes
   L3, EM, VS, VD, EA, TW, OW, IS and EV (with `ENDER_HITSTOP`), so it flips about every 1.2 s in play. Raise
   `IMPACT_STOP` above the enders' stops or gate it to breaker landings and kills, and keep `IMPACT_GAP_MS`
   from letting a string flip twice. `scripts/impact_frame.gd` (`IMPACT_STOP`, `IMPACT_GAP_MS`),
   `player.gd` `ENDER_HITSTOP`. Lane: feel (impact-feedback).
2. **One word per beat, at the blow.** Replace the live word instead of adding one, never show the same word
   twice, and place it at the contact (the near ring) rather than in clear floor 2-4 m off. `scripts/comic_fx.gd`
   (`WORD_GAP_HERETIC_MS` 240, `POOL` 6, `WORD_FRAMES` 20, `SPOT_RINGS`, `_place`). Lane: heretic-fx.
3. **Make the hero findable.** Try a closer training camera (`camera_rig.offset` (0, 13, 9.5) toward
   (0, 10, 7.5), or `FOV` 42 toward 36), push in through a breaker hang, and move the combo guide off the
   pile side (`combo_guide.gd` offset). A bright rim or ink pass on the hero over effects would help the
   slams. `scripts/camera_rig.gd`, `scripts/combo_guide.gd`, `heretic_rig.gd`. Lanes: feel (camera), heretic.
4. **Callouts end with their string.** The combo-name / PERFECT callout tween runs on scaled time, so freezes
   and breaker slow motion stretch it into the next string; make it ignore time scale and cut it when a new
   string starts, and shorten the "New combo:" banner. `scripts/player.gd` `_combo_callout` (`_callout_tw`),
   `scripts/hud.gd` `FOUND_HOLD` (2.5 s). Lane: split-player (owns player.gd now) / combo.
5. **Tame the Awakened gold.** At chain tier 3 the swoosh and the swollen trail in `AWAKEN_COLOR` are opaque
   gold sheets 4-5x his height. Cap the swell (`weapon_trail.gd` `CHAIN_GROW` / `HIT_GROW`), drop the
   second ender arc while Awakened (`player._swoosh`), or ink the gold as an outline. Lanes: feel (trail),
   heretic-fx.
6. **One number per breaker.** On a breaker show the total once (or the biggest foe's) instead of four equal
   numbers, have numbers dodge each other (round 29's open item), and show `LAST n` only on the dummy hit
   most. `scripts/comic_number.gd` (`dodge`), `scripts/training_dummy.gd` (LAST tag). Lanes: heretic-fx,
   training.
7. **Clear the floor between strings.** Maw / Abyss pools, Meteor geysers, Undertow's crack and the frost
   spear's ice disc outlive the string by 1-1.5 s. Shorten them, or fade any standing element effect when the
   next string's first hit lands. `scripts/dark_fx.gd`, `scripts/comic_geyser.gd`, `scripts/comic_crack.gd`,
   `frost_spear.frost_mesh()`. Lane: heretic-fx.
8. **Molten Palm needs a palm.** At `EM_SPEED` 2.1 the wind-up is four frames and the shove reads as a small
   magenta smear. Scale `comic_fist.gd` up (it should be bigger than his head, by the art direction), hold the
   chibi's Ab_AF extended drawing one more frame, and try `EM_SPEED` 1.8 by hand. `scripts/comic_fist.gd`,
   `hero_moves.gd` `EM_SPEED`, `tools/meshy_rig/chibi_keys.py` Ab_AF. Lanes: heretic-fx, combo-rhythm, heretic.
9. **Dash Stab and Harpoon land soft.** On a pile 2.2 m off, DL's lunge carries him through the foes (the
   damage is the tomahawk's, no freeze) and the bot's Harpoon never started in three films; Harpoon's own
   contact shows no freeze on its first frame. Check DL's `lunge` / `decay` against close foes and give the
   harpoon's catch its stop (`void_grab.gd` hitstop on the pull). `hero_moves.gd` MOVES `DL` / `EF`,
   `scripts/void_grab.gd`. Lane: combo-rhythm.
10. **Frame the breaker hang.** In Live Wire, Undertow and Avalanche hangs he rises into the top fifth of the
    screen under the HUD's training lines; let the camera target follow the leap height and move the
    TRAINING / THIS STRING lines out of the way. `scripts/camera_rig.gd` (target y), `hero_leap.gd`,
    `scripts/hud.gd`. Lanes: feel (camera), training.

Smaller things seen: Updraft Lash's lift doesn't read from this camera (the foes stay down in the gale);
Overwhelm's charge is a thin hoop; GR's 9 m reach grabs foes at the frame edge; the Grounded sky strike hides
its own callout.
