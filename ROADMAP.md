# Roadmap

The live list is `## Now`: `### Open items` an agent can pick up (top first), `### Zak's calls` decisions only he
can make. Each line keeps the wording of the round that raised it, with `(round N)` so it can be traced in
`docs/history/roadmap-rounds.md`, the full round-by-round record as it stood on 2026-11-08. Check items off here
with a one-line note, add follow-ups as new `- [ ]` lines, and add one line per finished round under `## History`.
Never start tower defense or licensed IP.

## Now

### Open items

- [ ] Chibi: the spear change's star still touches the hood from the game camera (round 29)
- [ ] Next: the Live Wire's comic_gale coil and the breaker cue still read loud in the storm frames; Dash Stab's spirit tomahawk is a shaman leftover on the heretic (worth a real heretic look or dropping); the damage numbers dodge text but not each other (round 29 heretic effects)
- [ ] Next (round 2, not started; stopped for review): `STRING_RESET_MS` (~150) in `hero_input.gd`: a press buffered more than that before a named ender's cancel that would open a new string (L1 / GR) is dropped, so mashing L3 doesn't spill into L1; assert in rhythm_check (must fail without it) (round 30)
- [ ] Next: dash out of a breaker hang keeps momentum: rhythm_check comparing its distance with a standing dash (`hero_leap._dash_out` zeroes velocity, then `_start_dash` sets dash speed: likely already equal, assert it) (round 30)
- [ ] Next (feel-audit 4): the combo-name / breaker callout tweens (`player._combo_callout`, `hero_leap._callout`) on `set_ignore_time_scale(true)`, cut when a new string starts (from MOVE with the chain reset); hud `FOUND_HOLD` 2.5 -> ~1.5 s (round 30)
- [ ] Next (feel-audit 9): Dash Stab carries him through a pile 2.2 m off (`DL` lunge 16, decay 3): brake the lunge near a foe ahead before the hit so the stab connects with its 0.07 freeze; give Harpoon's catch (`void_grab` pull) a hitstop (round 30)
- [ ] Next: the per-breaker effect build itself is 5-9 ms (comic_pop, geysers, craters each 1-2.5 ms): pool comic_pop nodes; `main._fade_occluders` walks the props' children every frame (cheap now, cache it if props grow) (round 31)
- [ ] 5. The flat gold axe over Awakened L2 / L3 is the spirit cast echo (`elements.CASTS` echo), not the swoosh: thin it or ink it while Awakened (round 32)
- [ ] 8. Molten Palm needs a palm: `comic_fist.gd` bigger than his head, knuckles forward (round 32)
- [ ] 4 / 9. Callouts end with their string; Dash Stab and Harpoon land soft (combo-rhythm lane) (round 32)
- [ ] Round 4 follow-ups: Meteor Fall's landing is still five flame geysers plus the column over the pile (the cracks now reach out but the geysers carry it); the frost zone plus Deep Freeze's rings, ropes and cubes over a crowd; the spirit echo's 3 m halftone fans on L2 / L3 cover a third of the frame; Undertow's magma crack web stands about 2 s; burn ticks show a number with no star (by design, a tick) (round 33)
- [ ] Round 6 densest left: Worldbreaker (L H L H) 0.25: three earth spikes a foe in cream and orange plus three rim geysers and the Awakening column; Grounded 0.22: the crater's green spark bursts and the column; the Awakening column is the biggest shape in most breaker HIT frames when the bot Awakens on the landing (round 33)
- [ ] The timing window before the press still pushes in on foes Undertow spread off screen (Meteor Fall's string): pull out there too, or leave the window tight? Tried in cleanup round 2 and not landed (stop-point): running the framing in the window and capping at `frame_max` also undid most of the push-in for a single foe 2 m ahead (x1.18, the head out of the 72% box), so the box test needs the hang's lift or a rest-distance test first; measure `_frame_to` per breaker in the window before choosing (round 36)
- [ ] The guide's mix / pay tags are plain text (a small element chip in the fx palette would read faster) (round 34)
- [ ] The combo guide's mix / pay tags are plain text: a small element chip (dot in the element's palette) before each (`combo_guide.gd`); left out at the demo stop-point (effects lane) (round 41)
- [ ] Hailstorm only ever lifts one foe in the bot's string (the cube Ice Cube bowls); the dummies Ice Cube passes aren't frozen, so the whirlwinds read as one (combo lane: freeze the bowl's victims, or film on a pile of frozen foes) (round 37)
- [ ] Eruption's landing still has the breaker's big brown crater under him for 0.6 s+, which outlasts the slabs (breaker_quake's crater; comic_erupt was removed 2026-11-08, so a designed break would be new) (round 37)
- [ ] Impale's hit is the busiest frame of the string: two cubes, the tentacles, a hit star and a number on each, KSHUNK! and the stakes; the stakes read only in the scratch shot (round 37)
- [ ] Matrix tells: Meteor Spike's falling line and Firestorm's ember line hide under Molten Palm's / Updraft Lash's own stars when the move plays; Swallowed's jaws sit under the crater squash for their first two steps (try starting them a step late) (round 37)
- [ ] The cult's void violet is also the hero's claw and void effect colour: mid-string a rogue or mage is the hardest foe to pick out; try a colder indigo or a pale rim for the cult (round 39)
- [ ] The shield's black rim merges with its ink line on the dark floor and reads as a thicker outline more than a rim; try an iron rim if it should read as metal (round 39)
- [ ] He is still smaller than the warrior at the game camera (183 vs 209 px, 17.7k vs 28.4k px): the 2.05 m cap leaves a bigger bake or a hero `model_scale` as the next lever (round 40)
- [ ] The scarf tail reads from the side and behind; from the front the hood hides it, and its flutter is unplayed (round 40)
- [ ] Round-3 lineup before / after (`foe_shots -- --tag=`) and the four-string film (`string_film -- --to=3`): cut at Zak's stop-point before the demo (round 40)
- [ ] 10b. Tow Line off a dash out of a move (EF / IP -> TW 457-526 ms): hand it over early without shortening its line (the frozen x dark cell went 3 -> 0 when tried) (combo-rhythm) (round 41)
- [ ] 10c. L3 -> EM 527-544 ms and Molten Palm's two-speed retime (item 7's combo side), Meteor Fall's throw sized to `camera_rig`'s frame cap (item 9's combo side): left out at Zak's demo stop (combo-rhythm) (round 41)
- [ ] 6. Overwhelm's pool is the last thick colour (hold: mean coverage 0.22): the halftone floor look, one thin rim (heretic-fx) (round 41)
- [ ] 7. Molten Palm's coil is one held drawing (Ab_AF frames 8-46 of 61) and a blink at `EM_SPEED` 2.8: re-key a building ~16-frame coil, `EM_SPEED` ~1.8 (heretic anim, combo-rhythm) (round 41)
- [ ] 8. The run reads as a hood dragging a claw, Run_Stop as a spin: smaller claw swing, legs clear of the hood, keep the stop's facing (heretic anim) (round 41)
- [ ] 9. Meteor Fall's beats happen at the frame edge (throws off the top and right, tentacles leaving the screen): throw along `_brk_dir` inside the x2.0 view, a tighter gather (combo, camera) (round 41)
- [ ] Overwhelm's pool (item 6): halftone it like the frost floor (`halftone_floor.gdshader`), a thin ink rim, fade with the hold (`dark_fx.Pool`); left out at Zak's demo stop-point (effects lane) (round 41)
- [ ] Film the round 41 effects lane after (`string_film`, `fx_coverage.py --per-string`) against the audit's 0.090 mean / 0.309 max; the lane landed on headless checks only at the demo stop-point (round 41)
- [ ] 1. Training drills with live foes that each ask one question (shield wall, back line, rush, bomb squad, against the wall): nothing in the room asks for one move over another (round 42 design review)
- [ ] 2. A wall rule for every big knockback (splat + bounce; pillars count) and walls in reach (smaller room or inner walls): Molten Palm's wall drive can't be found in a 32 m room (round 42 design review)
- [ ] 3. Breakers with different end states (stun, bounce up, stay frozen, throw to walls, execute one): nine breakers end in the same crater (round 42 design review)
- [ ] 4. Name each foe's answer in code and on screen (Triple Chop breaks shields, throw a lit bomber, Black Tide pulls the back line, Overwhelm holds the heavy): the hooks exist in `enemy.gd`, nothing teaches them (round 42 design review)
- [ ] 5. Split the overlaps: rename the air Live Wire, Steam Burst as the room-wide frozen cash-out, Black Ice leaves them frozen (setup) and Maw is the payoff (round 42 design review)
- [ ] 6. Make the element matrix uneven (a few big cells, the rest small) and teach it as two rules (the element decides what happens, the state how much) (round 42 design review)
- [ ] 7. Combo counter and rank react: drop on a hit or a pause, grade by wall splats, matrix cells, PERFECTs and guard breaks (418 HITS SSS all session now) (round 42 design review)
- [ ] 8. A counter window after a perfect dodge (next string's first hit crits): the dash is the only defence and pays nothing past survival (round 42 design review)
- [ ] 9. Tint the dummies away from the hero's cream and colour hit stars by element: the hero and the element are lost in piles (round 42 design review)
- [ ] 10. One element ink shape per breaker impact frame, smaller per-hit numbers on lights: numbers are the loudest thing on screen (round 42 design review)
- [ ] The splat lands at the top edge of the frame for a beat (the hang turns the fight framing off): a camera follow-up (round 42 e)
- [ ] The wall splat lands at the top edge of the frame (round 42 e's camera follow-up): mostly off screen in the film (round 43 b)
- [ ] The combo-name callout still overlaps the top of the circle in the hang (round 43)
- [ ] Still drawn as polygons: dark pools / Singularity vortex, the Reap crescent, comic_axe_aura, chain halos, daze stars, comic_dust, the dash streak, combo pop strokes, kills, the Awakening, the spirit echo ghost (round 44 fx-cohesion)
- [ ] Still the old look: `comic_axe_aura` storm sparks and the axe's own glow material (`P_GlowWind`, still green), `comic_arc`'s speed strokes, the dash streak in storm (round 44 fx-air)
- [ ] Still polygons: `comic_axe_aura`, chain halos, daze stars, combo pop strokes, the Awakening, the spirit echo ghost (round 45 fx-cohesion2)
- [ ] Galvanize's tentacles not filmed (no bot string in the film range); it shares Live Wire's code (round 44 b fx-air)
- [ ] Short Circuit's far arcs land off the game camera at 10 m: read from the test and the [improv] line, not seen (round 44 b combo-lightning)
- [ ] fx-air2 to polish the bolt look (`live_current._trail_strip`, `_head`, `_claw`, `_pop`) (round 44 b combo-lightning)
- [ ] Item 7: L3 -> Molten Palm 538 ms (re-key Ab_AF's coil, then `EM_SPEED`; heretic anim + combo-rhythm) (round 46 feel-audit3)
- [ ] Still polygons: the breaker dive trail in the other elements (`comic_comet.gd`), the tentacle's lava / ice skins (round 46 fx-elements)
- [ ] `hero_fx.rank_up`, `callout_cap`, `comic_fault` ground, freeze-over, melt, impale, rip, improv tells (round 46 fx-finish)
- [ ] Live Wire's hang with a far foe: the current runs off frame (cue Short Circuit's targets in the hang? Zak's call) (round 47 c)
- [ ] Ice Cube pressed during Harpoon's gather finds nobody (the tentacles still carry them): combo-harpoon lane (round 47 c)
- [ ] Trace the purple radial wedges round the hero on some breaker leaps; check the drag mark on film (round 47 d)
- [ ] Shatterstorm and Slapshot's banner shows the name only: their damage lands later, through the blocks. (round 48 b)
- [ ] Wall-splat stars are not clearly verified on film: the palm's splat sits at the frame's edge. (round 48 b)
- [ ] Open: hang framing at the frame edge (Meteor Fall, Black Ice, Maw), Cold Front's hoist under the banner, stacked damage numbers, Collapse's spits off the edge, Eruption's banner without a total, the first-L1 33 ms frame (round 53 feel-audit5)
- [ ] Open: Rockslide, Deep Freeze, Overwhelm, Meltdown still 2/4; Short Circuit's loop needs foes past the held (round 54 cool pass 3)
- [ ] Open: Overwhelm's pool reads busy behind the slam; Rockslide's boulder small at the camera's distance; Dash Stab's catch and Black Tide's drag need foes spread out (the bot's dummies stand close) (round 55 cool pass 4)
- [ ] Open: mid name callouts stacked over their beat words; Cataclysm's pile under the top banner for ~0.5 s; the parried cleaver lying ~2 s; Collapse's stray pebbles (round 56 feel-audit6)

### Zak's calls

- [ ] Guide feel pass by hand: placement next to the hero vs. the fight, whether the follow-up hint is too much once the moves are learned (round 19)
- [ ] Hand play-test: breaker windows and dive speeds, the timing circle's spacing (`breaker_prompt.OFFSET`), the air dash / homing / height cap, Flurry's afterimages (windowed only) (round 25)
- [ ] Hand play-test the feel numbers (ease curve, roll, impact frame strength, swell): all judged headless or from stills (round 27)
- [ ] Zak: play the chibi; keep it as the default or flip `Game.HERO_DEFAULT` back to "heretic" (round 29)
- [ ] Chibi: play the keyed clips and judge the on-twos stepping in motion; the fidgets and 2H_Melee_Idle are still the shaman's (Death_A and Ab_Swing keyed in round 35 c) (round 29)
- [ ] Zak: play `--spar=minion|rogue|shield|warrior` and judge the masses, the fast chibi runs (clip up to 3x) and the hit squint in motion (round 29)
- [ ] Next: judge the new L3 / Molten Palm speeds and the hit-confirm by hand; breaker count still varies 5-7 between autotest runs (foe placement); the void moves' raw `MOVES` hits (GR 0.24 vs its clip's contact 0.32, VS 0.39 vs 0.41) were left as tuned (round 30)
- [ ] Next (feel-audit 8): try `EM_SPEED` 1.8 (wind-up 467 -> ~545 ms); Zak judges by hand (round 30)
- [ ] By hand: the void moves now hit 1-2 frames earlier on their keyed contact (GR 146 -> 137 ms, VS 352 -> 333 ms): does the grab's snap and the slam read sharper? The claw lash on Dash Stab replaces the tomahawk: does it read as his move at the game camera (no windowed look taken yet)? (round 30)
- [ ] By hand: do the strafe / back one-shots read in play with mouse aim, and is the guard skid's 3 s (`READY_HOLD`) the right window? (round 35)
- [ ] By hand: is 13 m far enough? Try `--cam-dist=14` / `15` and `--cam-frame=1` (framing off) and say which (round 36)
- [ ] By hand: is x2.0 too far for the beats (the hero ~70 px for ~0.6 s), or still too close (a throw to both side walls wants ~x3.5; the corner foe can sit at the edge)? `--cam-frame=` scales it (round 36)
- [ ] By hand: does the sleeker look still hit hard enough? Thin lines lean on the hitstop and the impact frame now (round 33)
- [ ] By hand: Dash Stab at `DASH_STAB_CANCEL` 0.5 covers half the dash's ground before the lunge: check the spacing into a pile; the "+ payoff" tag's reach is read from where he faces before the press, so an aimed press can still pay where the tag didn't show (round 34)
- [ ] Matrix tells by hand: whether the payoff word over the move's word reads in fast strings, and the 12 cells the bot never reaches (round 37)
- [ ] By hand: `--spar=minion|rogue|shield|warrior` and judge the new runs in motion (turning, the speed ramp, circling at 0.4 of move speed at clip 0.35-0.5) (round 38)
- [ ] By hand: spar the rogue and minion for the start / stop / lean feel (`TURN_LEAN`, `RUN_START_BELOW`); the warrior's overhead tell is small from the game camera (the helmet covers the hands) (round 38)
- [ ] By hand: whether the squint / grin on attacks reads in play or flickers across fast strings (round 40)
- [ ] By hand: whether the pulled face oval draws over the claw in VS / lift poses in play (it hides with the mouth when the claw covers it) (round 40)
- [ ] Zak picks which second endings to build (the proposal table); items / mechanics to nudge LMB vs RMB (round 43)
- [ ] Zak's call on the look, then the conversion list in the doc, most seen first (element_hit chips, the axe ribbon, comic_dust, the breaker and crossover effects, the dark element's ink tendrils) (round 43 b)
- [ ] Zak's call on the look (clips `awaken-combo-clips/21 Cohesion ...`) (round 44 fx-cohesion)
- [ ] Zak plays it: seen in stills and films from the game camera only (round 44 hero model v2)
- [ ] Zak: horn tips crimson or violet, the Awakened edge strength, whether to re-key the hood squash for v2 (round 44 hero model v2)
- [ ] Zak's call on the look (clips `awaken-combo-clips/19 Air ...`) (round 44 fx-air)
- [ ] Zak plays Galvanize and the four cells by hand (round 44 combo-lightning)
- [ ] Zak's call on the cue (cream with an accent vs the ending's colour all round) (round 45 fx-cohesion2)
- [ ] Zak's call on the look (clips `awaken-combo-clips/19 Air f..` onward) (round 44 b fx-air)
- [ ] Zak plays Galvanize and Short Circuit by hand (round 44 b combo-lightning)
- [ ] Zak plays Live Wire / Short Circuit / Galvanize by hand after these (round 46 feel-audit3)
- [ ] Zak's call: the fireball stands behind him (he reads in front) rather than wrapping him; the ice block is see-through (round 46 fx-elements)
- [ ] Zak: is the Awakening crown big enough (5.4 m), and should the echo axe stay or go entirely? (round 46 fx-finish)
- [ ] Weapons held out past 1.2 m still poke out of a spar foe's block (by design); the skewered stake tell stays (round 47 fx-ice2)
- [ ] Zak: is a dummy's block (2.2 m across) too big now it holds the arms? (round 47 fx-ice2)
- [ ] Zak's call: the endings sit behind a pause (Ice Cube keeps its line), not on Harpoon outright; hand-play the gather's speed and whether a wall past ~10 m (the slide's reach) should still count (round 47 b)
- [ ] Zak's call: Pinwheel's wall splat lands on the top edge of the frame under the breaker callout banner (camera lean cap 3.5 m); Meteor Fall and Meteor Shower share the magma colour, so the prompt's two chips are both orange (round 48)
- [ ] Zak: Cold Front's and Flash Freeze's small blue spoked stars (existing ice hit pops, in the before film too) may read as crystals (round 48 b)
- [ ] Zak's call: the bot turns swinging on for its counter string only; bolts get no Backlash or window; the counter window keeps the shared breaker rhythm; `--spar=` foes are counterable by design (melee windups) but not filmed (round 49 counter)
- [ ] Zak: Reap fills the mark slot at H L (the grammar says H; his H alone is the grab). Impale (Dash H H) has no window (round 49 kit-slots)
- [ ] Zak's call: the tentacles glow pink-orange in the lava (purple washed with `electrify`); the move's clip plays at 0.95 (was 1.1 in the first cut) so the pile's burst shows before his leap; Hellseam's far seam ends sit under the ending banner when the palm sent them to the back wall (round 49 dark-magma)
- [ ] Zak: Backdraft's MOVES note says "Ice into storm" and `ELEMENT_OF.XW` is wind, while its card slot is dark x ice (round 49 wiki)
- [ ] Zak's call: Collapse's x1.6 into a structure; the pillar slam on a held H; the palm's too-far bracket; Meteor Fall's cursor only takes a structure with palm foes on it; Dash H H then a pause is now Pinwheel / Anvil, so a slow Dash H H L leaps instead of Backdraft (round 50)
- [ ] Zak's call: the dash hand-overs (Rockslide -> Dash Stab 385 ms) are over the 330 mid target because of the dash itself; a shorter dash would change movement everywhere (round 51 fluidity)
- [ ] Zak's call: torches_conduct is always on (the proposal had it a run upgrade); Slapshot into the Frost Wall is x5.7 the open; the breaker banner covers Uproot's fall line (round 52 env-pieces2)
- [ ] Zak's call: Tow Line's pick window is the move's start-up (~0.15 s): hover the foe before the press (round 52 cool pass 2)
- [ ] Zak's call: which flourishes go in the base kit (recommendation: gallows); the extra x1.25 on Hellseam's pile; a spilled brazier rebuilds lit (round 53 env-flourish)
- [ ] Zak's call: Frost Spear plants ahead of his facing, so after a turning L2 it can land away from the crowd (the bot film); plant toward the nearest group by default? (round 54 cool pass 3)
- [ ] Zak's call: the banner move (cut kept); Cold Front's cube needs x1.7; the gallows Ricochet payoff (1.2-1.4) (round 54 camera-hang)
- [ ] Open (Zak): his hurt's dash-out at 0.12 s; a bot token to counter a live foe; the shield letting control moves through; the live foe in the string films' gather; a kill hidden under a breaker's impact frame (round 56 spar-feel)
- [ ] Zak's call: punch the wide endings too (Avalanche, Slapshot, Meteor Shower, Pinwheel, Short Circuit, Uproot) even if it crops the pile for 0.3 s (round 56 feel-audit6)
- [ ] Zak's call: hazards that hurt the hero in harder rooms; the item kinds that write to a room (lore doc); whether the new rooms' showcases join the autotest (a `BOT_STRINGS` entry with `room`, training_bot's lane) (round 57 rooms)
- [ ] Zak's call: the gallows splat kills any real foe (cap it to hang alive?); grabbing a foe out of Ricochet's throw; the spar foe's 3x hp; his hurt kept at 0.35 / 0.12 (a mid-string hurt still resets the string) (round 57 spar2)
- [ ] Zak's call: a dash through the spear shattering it (left out: Tow Line's dash runs through it on the Impale route) (ice-staff, 2026-11-07)

Cleanup 2026-11-08: see docs/cleanup-2026-11-08.md

## History

One line per completed round; the full text of every round is `docs/history/roadmap-rounds.md`.

- Rounds 1 (the four original lists): combat feel (trails, sparks, hitstop, dash i-frames), skeleton enemies (mage, rogue, archer), the roguelike layer (upgrades, rewards, rooms) and polish (occluder fade, toon outline).
- Round 2-16: healing, more upgrades, branching paths, spawn pacing, settings, bones, hints, build view, bomber, altar, shrine, synergies, run summary, daily runs, boss slam readability, bot cage escape, replay, Shatter, Volatile tune, combo callouts.
- Round 17 shaman rework: short Awakening, hero levels, Ascendancies.
- Round 18 elemental shaman: elemental casts and Awakened ultimates.
- Round 19 combo guide: the next-input rows beside the hero.
- Round 20 power paths: powers by button, path colours, icons.
- Round 21 run map and Round 22 map polish: the whole run laid out, vaults, trials.
- Round 23 combos: Flurry, Cyclone, combos landed.
- Round 24 training: the training room and dummies.
- Round 25 combo breakers: timed finishers on enders, the timing circle, strings that move.
- Round 26 comic art style: toon and emit shaders, comic hero and enemies behind `--comic`.
- Round 27 combat feel loop: hitstop shape, camera hit feel, impact frame, trail swell.
- Round 28 strip to the heretic: the game boots into training; runs, rooms, rewards and title screen removed.
- Round 29 assets: the heretic GLB audited, refined, the chibi heretic as the default, its keyed clips.
- Round 29 heretic effects: flat inked storm, ice, magma and dark effects.
- Round 30 combo rhythm: hits on the contact pose, `BUFFER_MS` 300, hit-confirm, the timing contract.
- Round 31 perf and cleanup: the `[perf]` line measures cost, GPU-skinned afterimages, player.gd split into `hero_*.gd`.
- Round 32 feel audit fixes: impact frame only on slams and kills, the first audit's top 10.
- Round 35 hero locomotion: feet locked to the floor, start / stop / turns / guard.
- Round 36 camera distance: 13 m at FOV 37, aimed 0.8 m up.
- Round 33 FX sleek: one palette per element, thin lines, the floor cleared between strings.
- Round 34 multi-element combos: crossovers, three-element strings, the element matrix, reach and the last beats.
- Round 37 crossover FX: a flat comic drawer per crossover.
- Round 38 foe locomotion: runs keyed per kind's speed, attacks, turn lean.
- Round 39 foe models, chibi pass 2: one signature prop per foe, refine pass.
- Round 40 hero model, chibi pass 2: repainted texture, face and attitude from the game camera.
- Round 41 feel audit 2: 22 strings filmed, items fixed, the demo stop-point.
- Round 42 design review: combos, effects and designs against "every combo has a best situation".
- Round 42 b / d second hero (dragon prince): ideation and a first slice (removed in the 2026-11-08 cleanup).
- Round 42 c Meteor dive: Meteor Fall dives on the group Molten Palm set up.
- Round 42 e: Molten Palm reaches the wall; the Flash Freeze regression (the meter mid-move).
- Round 43 breaker choice indicator: the prompt shows every ending.
- Round 43 b designed effects pilot: authored flipbooks instead of polygons.
- Round 44 fx-cohesion, fx-air, combo-lightning, hero model v2: tentacle skin and stamps, air vs lightning, Galvanize, a hand-built body on the rig.
- Round 45 fx-cohesion2 and Round 44 b (fx-air round 2, combo-lightning second pass): floor stamps, sky strike, Short Circuit.
- Round 46 feel-audit3, fx-elements, fx-finish: the whole game on film, designed ice and magma, the Awakening and flourishes drawn.
- Round 47 fx-ice2, combo-harpoon2, feel-polish, fx-polygons: ice blocks that fit, Harpoon gathers, audit 3's items, the last polygons drawn.
- Round 48 breaker-pairs and breaker-spectacle: second endings where compelling, every landing a comic beat.
- Round 49 counter, matrix, kit-slots, dark-magma, wiki: the dash counter, six rules, the slot table, Lava Leash / Hellseam, the field guide.
- Round 50 environment: structure targeting, an easier Pinwheel, environmental beats.
- Round 51 env-pieces and fluidity: pieces as data and the heretic's verbs; every hand-over snappy.
- Round 51 cool pass: Collapse, Avalanche, Abyss rebuilt; foe picks.
- Round 52 env-pieces2 and cool pass 2: readability, torches conduct; the 1/4 and 2/4 endings, Collapse readable.
- Round 53 env-flourish and feel-audit5: gallows, ice rink, brazier spill; both rooms filmed with the after-beat.
- Round 54 cool pass 3 and camera-hang: the mids, the 3/4 endings, the parry; hang framing and clutter.
- Round 55 cool pass 4: the last 2/4 mids, the picks on film.
- Round 56 spar-feel and feel-audit6: every string filmed on each spar foe; the landing punch, the banner over piles.
- Round 57 rooms: rooms as data, the flooded cistern and the forge hall.
- Round 57 spar2: the counter and the holds in real play.
- Ice-staff (2026-11-07): Frost Spear on purpose only; the two-slot press buffer.
