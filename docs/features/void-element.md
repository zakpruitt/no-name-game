# Right click on the void arm: the tentacle, the elements and breakers

## What it does

For the comic hero (`player._void` isn't null) there are two attack buttons and no E. L is the weapon, and the count picks the element: axe storm, spear ice, hammer magma. Right click (H in the tables and the game's combo text) is the tentacle, which does that element's thing. H again goes further, and H in the slow-motion window is the breaker.

Each element treats foes differently, so lift-and-slam belongs to the storm alone:

- **Storm goes up and through:** foes go in the air and lightning runs along the tentacles.
- **Ice turns foes into objects:** they get skewered, thrown and shattered.
- **Magma goes down and apart:** they get shoved, dragged under and ripped open.
- **Dark pulls in and swallows:** no weapon first. They get dragged to one spot and something eats them.

These are the hero's only heavies and breakers: the KayKit hero's `route()`, `BREAKERS` and `H` were removed in round 28.

## The kit

### Storm

| Input | Id | Name | Effect |
|---|---|---|---|
| L H | `EC` | Updraft Lash | The tentacle sweeps under them (`void_grab._tick_sweep`), a gale pulls them together and throws them up, and he rises after them. The kit's only knock-up |
| L H L | `AL1` | Air Slash | Up after them with the axe |
| L H H | `EE` | Live Wire | A tentacle on each, up to `SEIZE_MAX`, with lightning through all of them. The window opens |
| L H L H | `EW` | Live Wire | The same from the air, with two endings |

Live Wire is the hang itself: `void_grab.seized_tick` jolts every `WIRE_STEP`, so the lightning does its damage whether or not the press comes. Big foes can't be held, but the lightning still finds them (`reachable()`).

**The tentacle conducts (round 44, `scripts/live_current.gd`).** Each jolt is a pulse that leaves his claw and runs
out along every tentacle's own drawn curve (`void_tendril.points()`, the designed spine) at `LIVE_CURRENT.SPEED` (34 m/s, game time, so
the window's slow motion and each zap's hit stop hold it): a hot yellow knot at its head, the authored bolt strip
(`designed_fx` "bolt_strip", tiled along the curve) lit behind it, the tentacle's own body flickering storm-light
on twos while it carries the charge (`void_tendril.electrify()`). A held foe is zapped on the frame its pulse arrives
(`void_element.jolt()` through `zap_hit()`: the number and a flash, no hit star or speed strokes; two short forks
crackle off its chest instead), nearer foes first. When every tentacle has delivered, arcs (`comic_bolt`) jump on,
nearest first, `JUMP_STEP` apart, to everyone in reach no tentacle holds (heavies, past `SEIZE_MAX`). The first pulse
waits `WIRE_START` 0.12 s, until the tentacles have landed, while the charge gathers at his claw (a star swelling,
four spikes drawn in): the anticipation. Only the first pulse freezes (`LIVE_CURRENT.ZAP_STOP` 0.035 s); later ones take `ZAP_STOP_AFTER` 0.012 s (feel audit 3: a freeze each flicked the hang x0.03 / x1.0 frame to frame). `WIRE_STEP` 0.1, `WIRE_DAMAGE` 4.5 (was 0.08 / 0.09 / 3.5: about the same
damage before a sweet-spot press). The dive ends the current (`finish()`): a late pulse mustn't hit what he throws.
Every jolt leaves the foe **charged** for `ELEMENT_HOLD` (round 44; so do Grounded, Storm Pitch, Galvanize, Fault
Line and Cataclysm): the element matrix's charged rule ([element-matrix.md](element-matrix.md), round 49) pays it with any other
element: the hit arcs on through every other charged foe near it. Overload (storm), Superconduct (ice), Arc Flash
(magma) and Conduct (dark) are upgrades now (`Kit.has()`), played in the rule's place when on.

### Ice

| Input | Id | Name | Effect |
|---|---|---|---|
| L L H | `IP` | Frost Spear | Plants the spear ahead of him (`frost_spear.gd`). Frost spreads out from it and only slows. One at a time; it melts after `LIFE` |
| Dash L H H | `EA` | Ice Cube | Freezes the nearest foe and bowls it (`pierce`): whatever it passes takes the hit and freezes |
| L L H L | `IJ` | Vault | Up over the spear (`run_to_spear`) |
| L L H L H | `IS` | Deep Freeze | Comes down on the spear and it goes off: everyone on the frost takes a hit and freezes into a cube (`_deep_freeze`). The window opens |
| Dash L H | `EF` | Harpoon | Round 47: a tentacle to every foe within `HARPOON_REACH` 8 m of him, all round (nearest first, `HARPOON_MAX` 5; Galvanize's reach), each reaching, latching (`HARPOON_DAMAGE` 10), carried in a quick curve round him and set down frozen in a cube in one rank across his aim (`harpoon_slots()`: `HARPOON_SET` 2.6 m ahead, `HARPOON_GAP` 0.15 m between the ice, short of walls by `HARPOON_WALL`; spaced by each foe's fitted ice, `ice_radius()`: fx-ice2's `fit_block` makes a dummy's block ~1.05 m round and 2.2 m tall), `harpoon_gather.gd`. Big ones freeze where they stand. H off it is Ice Cube; a pause opens the window (Shatterstorm / Slapshot) |

### Magma

| Input | Id | Name | Effect |
|---|---|---|---|
| L L L H | `EM` | Molten Palm | The arm swells into a fist (`_tick_palm`) and shoves the crowd `PALM_SHOVE` 6 m back through lava. A wall within `PALM_WALL_REACH` 10.5 m behind a foe and it carries that one all the way there (round 42 e, `thrown_foe.clear_from()`), so the training room's back wall is in reach from the dummies. The wall splats them (`quiet`, `wall_mult` `PALM_WALL_MULT` 2.5, and marks `last_wall_ms`): the set-up for Meteor Fall |
| L L L H H | `EV` | Undertow | Lava wells and tendrils out of the floor drag foes waist-deep (`floor_bind.gd`, `sink` moves `enemy.model`, not the body). It follows those Molten Palm just shoved (`shoved`, `UNDERTOW_CHASE`), taking hold where they land. Big foes are only slowed. The window opens |

### Dark

Right click with no weapon first. Dark gathers foes and swallows them, and the tentacle only starts it off. `dark_fx.gd` holds the things it makes, in flat ink and violet.

| Input | Id | Name | Effect |
|---|---|---|---|
| H | `GR` | Grab | Yanks a foe to him. Something too big drags him to it. Never goes for a pillar: that's R |
| H H | `VS` | Singularity | Heaves what it holds overhead and slams it, and a black hole opens there (`dark_fx.Hole`). It drags small foes in and slows big ones, burning all of them. The window opens |
| H L | `VR` | Reap | A crescent of darkness through everyone in front of him. It marks them (`dark_fx.mark`) |
| H L H | `VD` | Black Tide | A pool opens ahead and everyone marked is dragged across the floor into it, however far off. With nobody marked it takes who's near. Big foes hold their ground. The window opens |
| hold H | `OW` | Overwhelm | A black pool under the nearest foe in the cone, with tendrils piling on (`floor_bind.gd`). Works on big foes, which it slows instead of pinning. The window opens |
| Dash H | `TW` | Tow Line | Latches onto foes along the dash, then yanks them into each other |
| H during a swing | | Snatch | Takes a foe on the way past and carries it (`_carry_pick`, `_tick_carry`, `_drop_carry`) |

### Crossovers (round 34)

Strings that change element on the way, where the second element cashes in what the first set up. Each is a
new move id (`X*`) reached off a move that used to restart the chain (`LIGHT_AFTER` / `AFTER`), on a tentacle
clip with its `*_HIT` contact frame, with the arm's shape in `VOID_ELEMENT.FORM_OF`.

| Input | Id | Name | Elements | Payoff |
|---|---|---|---|---|
| L H L L | `XR` | Rockslide | storm into earth | Off the air slash he comes down with the hammer (plunge) and everyone within `ROCKSLIDE_RADIUS` of the blow is driven into the floor together (`ROCKSLIDE_DOWN`, pulled `ROCKSLIDE_IN` towards it: craters). Foes the gale had in the air take `ROCKSLIDE_AIR_MULT`; they go in `void_grab.buried` (Fault Line's) and are marked buried |
| L H L L H | `XF` | Fault Line | earth into storm | Cracks run to everyone in `FAULT_REACH` and the gale comes up out of each, launching them; Rockslide's `buried` take `FAULT_BURIED_MULT`. The window opens |
| L H L L H, H in window | `XF` | Cataclysm | storm + earth | Held in the hang (no `wire` since round 37's review: Live Wire's bolts on every foe made it a wall of effects; `damage` 46 for the lost jolts), then down into the floor: a crater (`CATACLYSM_DOWN`), a sky strike and the earth under each |
| Dash L H H L | `XS` | Steam Burst | ice into magma | The molten fist goes at the frozen: every foe in a cube or frozen within `STEAM_REACH` goes off (the cube Ice Cube is still bowling too: `THROWN.cut`, so the bot's string steams every run) in steam (`STEAM_DAMAGE` times the ice's `FREEZE_BREAK`, launched), scalding anyone within `STEAM_SPLASH`. Nobody frozen: a small shove. The window opens |
| Dash L H H L, H in window | `XS` | Flash Freeze | magma into ice | The steam freezes on the held foes as he dives (`refreeze`: `freeze_seized()`), and the landing shatters it again |
| H L L | `XC` | Galvanize | dark into storm | Round 44 b, an event in three beats. Reach out: a tentacle whips out to everyone within `GALV_REACH` 8 m round him and to the Reap marked within `GALV_MARK_REACH` 11 m (`GALV_LINKS` 6, the marked first past the cap), nearest first, `GALV_STAGGER` 0.035 s apart. Charge: the claw crackles and the tentacles light out from it, held `GALV_HOLD` 0.07 s in half-speed slow motion. Discharge: one fat pulse (`GALV_FAT` 1.8) takes `GALV_TOGETHER` 0.07 s down every tentacle, so all are hit on the same frame: a real hit each (star, flash, number, a `GALV_STUN` 0.45 s stagger) for `GALV_DAMAGE` 7 x (1 + `GALV_LINK_BONUS` 0.3 per other link), x`GALV_MARK_MULT` 1.25 on the marked, a hit stop of `GALV_STOP` 0.045 + 0.015 per other link (max 0.13) and the word BZZRAKK! on that frame, sized 0.4 + 0.05 per other link; then arcs jump on, chained, to up to `GALV_JUMPS` 4 foes within `GALV_JUMP` 3.5 m of a zapped one (`GALV_JUMP_DAMAGE` 6). **Best situation: a spread-out crowd.** Updraft Lash and Molten Palm want them bunched; Galvanize hits them where they stand, and the more it links the harder each zap (1 linked 7, 3 linked 11.2 each, 5 linked 15.4 each). Off Reap it is the other choice to Black Tide (H L H), which drags the marked together. No breaker |
| L L L H L | `XL` | Lava Leash | magma into dark | Round 49 (dark-magma lane), the sixth crossover. Off Molten Palm (EM's L, `LIGHT_AFTER`): a tentacle goes to every foe the palm hit (`palm_fresh`) within `LEASH_REACH` 17 m, wherever the palm sent it (the wall too; `LEASH_MAX` 6, nearest first; nobody hit: whoever is in the palm's strip), latches (`LEASH_DAMAGE` 6, `thrown_foe.cut()` ends the palm's shove) and drags it back along the floor through a lava seam into a pile `LEASH_PILE` 2.1 m ahead of him (`leash_slots()`: one on the middle, more round it `LEASH_RING` 0.62 m out in the order they stand across his aim, so no two drags cross). Each pays by the metre on arrival (`leash_drag_damage()`: `LEASH_PER_M` 1.8 a metre to `LEASH_DRAG_CAP` 12, x`LEASH_WALL_MULT` 1.6 torn off a wall, `wall_fresh`). When the last lands the seam erupts under the pile: `leash_erupt_damage()` (`LEASH_ERUPT` 8 each, +`LEASH_PILE_PER` 0.2 per other one), molten, bound (`floor_bind`, `LEASH_BIND_TIME` 1.6 s, `LEASH_TICK` 1.5 a tick, sunk `LEASH_SINK`), the word SHLURK-FWOOM! sized by the pile. Gameplay in `void_element._lava_leash`, the beats in `scripts/lava_leash.gd`. **Best situation: the palm's foes at mixed ranges, one on a wall** (Galvanize wants a spread crowd nobody has marked; Black Tide the marked anywhere). `tests/lava_leash_check.gd` plays all three in each: wall_mixed Lava Leash 103 / Galvanize 42 / Black Tide 72; spread_round (six 7 m round him, unmarked) 36 / 130 / 0; marked_far (four marked 8-10 m off, no palm) 0 / 67 / 96. The window: Hellseam |
| Dash H L | `XT` | Storm Pitch (kit upgrade `storm_pitch`, round 49: off the base kit) | dark into storm | Whoever Tow Line bunched (`PITCH_GRAB` round `PITCH_AHEAD`) is cut off its tether (`thrown_foe.cut()`) and hurled on along his aim, fanned `PITCH_SPREAD`; in flight lightning jumps from each to anyone it passes (`thrown_foe` `zap`: `ZAP_STEP`, `ZAP_REACH`, `ZAP_MAX`) and it bursts in wind where it lands. Big foes stay and take the jolt |
| H L H, L in window | `VD`, its `alt` | Black Ice | dark into ice | The press freezes the pool with everyone in it (`freeze_pool()`, instead of the jaws), and the landing shatters it (`_black_ice`: `BLACK_ICE_DOWN`, x `FREEZE_BREAK`) |
| L L L H L, H in window | `XL` | Hellseam | magma + dark | One ending. No tentacle hold (`no_hold`: the leash's own tentacles keep the pile through the hang), the leap at `LEAP_AFTER_LEASH` (after the pile's burst), he dives on the pile (`at_spot`, `dark_spot`). The landing (`_hellseam`): everyone within `HELLSEAM_PILE_R` 2.6 m of the pile takes `HELLSEAM_DAMAGE` 40 x (1 + `HELLSEAM_PER_M` 0.04 per metre the leash dragged it, `LEASH_META`), driven into the floor (`HELLSEAM_DOWN`), molten; then the eruption runs back out along every seam (`lava_leash.seams()`), a geyser every `HELLSEAM_STEP` 1.5 m from the pile end out (`HELLSEAM_DELAY` 0.12 s + `HELLSEAM_RUN` 0.025 s a metre), and anyone standing on one takes `HELLSEAM_SEAM` 0.5 of it and goes up. Word KRAKA-FWOOOM! |

Their looks (round 37) are their own flat drawers, below.

#### Crossover looks (round 37)

All on `scripts/comic_flat.gd`: a Node3D that rebuilds two meshes on twos, `screen` (camera-facing, heretic_form_fx's
material, no depth test) and `floor` (flat, comic_crack's depth-tested material, so foes stand on it; its vertex
colours go through `srgb_to_linear()` or the palette washes out pale). `real_time` runs it on wall time (breaker
hangs, hit stops); `_follow()` runs every frame for an effect that rides something, kept untyped and checked with
`is_instance_valid`. Palettes from `fx_palette.gd`, thin `PAL.LINE` ink, gone in under 0.6 s unless held.

| Move | Look | Script, call |
|---|---|---|
| Rockslide | One boulder (7-sided, earth body to deep, a lit facet, two ink cracks) on the hammer's spot, squashed over a hot star with three fall strokes, holds 2 steps, splits into 4 chunks; a hot crack dent under each foe driven down. 0.55 s | `comic_boulder.gd` `spawn(parent, spot, foe_spots)` in `_rockslide` (with `Fx.scorch`) |
| Fault Line | One jagged crack per foe from 0.55 m out of his feet, nearest first `STAGGER` 0.06 s apart at `RUN` 30 m/s on real time; ink edge, earth body, hot core line while it runs; a hot splat and `comic_gale` (2.4 m) where it arrives. No foes: one crack 4 m ahead | `comic_fault.gd` `spawn(parent, at, spots)` |
| Cataclysm | `big`: the same cracks fatter (0.34 m) and slower (22 m/s, game time, so they wait out the impact frame) out of his landing, a `comic_bolt` sky strike (0.3 m, star 0.8) where each arrives. No per-foe geyser, spikes or hammer burst | `comic_fault.gd` `spawn(..., true)` in `_cataclysm` |
| Steam Burst | Nine puffs, six in a ring round the frozen foe's body and three over its head, every puff's ink first then every fill (only the cloud's outer edge is inked), white to blue-grey, rising and swelling; a magma star and paper strokes on the first frame. 0.55 s | `comic_steam.gd` `spawn(parent, spot)` per frozen foe |
| Flash Freeze | A see-through crystal shell (`SHELL` 0.88 x 1.5 m) climbs each held foe from its feet (half, then 1.1 overshoot), light rim inside thin ink, three ice tips and a glint, riding the foe, 0.5 s real time | `comic_freeze_over.gd` `foe(parent, e)` from `hero_leap._start_dive` (`refreeze`) |
| Black Ice | The pool freezes over from the middle (0.45, 0.8, 1.0 of `MAW_RADIUS` + 0.3 in three steps): a two-ring mosaic of plates on shared edges, ink between, glint lines, lifted 0.06 m over the dark pool; held (real time, 2.2 s at most) until the landing's `shatter()` throws the plates up as inked chips | `comic_freeze_over.gd` `pool()` in `freeze_pool`, `shatter(parent, spot, r)` in `_black_ice` |
| Galvanize | His own tentacles whip out one by one (`stagger`), the claw charge, the held beat (`hold`: the strip lit out from his claw, the tentacles brightening), one fat pulse landing on all at once (`together`, `fat`), two forks and a real hit pop on each, the word on that frame (`ComicFx.say`, `LATE_WORDS`), the arcs on, the tentacles snap back. The bolt is drawn by `live_current._trail_strip`, `_head`, `_claw` and `_pop` | `live_current.gd` `start(hero, links, true)` in `_galvanize` |
| Lava Leash | Designed only (`tools/vfx_gen/gen_leash.py`): the tentacles (`void_tendril`, one per foe, `STAGGER` 0.03 s apart) whip out to each, latch, and drag it in (a pow ease, `DRAG_EASE`: slow off the wall, a slam into the pile, `HOP` at the middle), washed in lava as they go (`electrify(HEAT, LAVA)`); behind each a `lava_seam` ribbon (crusted inked banks, lava body, hot core, crust rafts, a popping bubble; `designed_drag.gdshader`, cools and erodes from its old end over `SEAM_LIFE` 2.2 s) and a magma spurt where it was torn away. The eruption: Undertow's designed pool under the pile and the `leash_burst` sprite (a slit, a fan of five tongues, globs, a crust mound; `BURST_SIZE` 4.4 m). The tentacles hold the pile through the leap and let go when he lands. Hellseam's seam geysers are `designed_elements.geyser` | `lava_leash.gd` `start(hero, grabs, pile)` in `_lava_leash` |
| Storm Pitch | Three inked zigzag forks crackle off each thrown foe's chest, new each step, with two pale speed strokes behind it, for its flight + 0.1 s; the jolts it throws (`thrown_foe._zap`) and the axe's chain at the throw are thin `comic_bolt`s (0.18 m, star 0.42) | `comic_arc.gd` `ride(parent, e, flight)` in `_pitch`, `jump(parent, a, b)` |
| Hailstorm | A tight whirlwind under each frozen foe, four inked wind bands from the floor to its feet every step (so it stretches as the foe climbs), wider than the cube (1.05 m), three inked hail chips whirling round it; rides the foe, 0.5 s | `comic_hail.gd` `ride(parent, e)` in `_hailstorm` (was a full wind pillar each) |
| Meltdown | One fat inked crescent (earth, hot leading edge) sweeping down round him, 0.25 s; per foe hit: the ice bursting off as four inked chips and a small star, three flame tongues streaming up off it while it falls, a hot splat with four cracks where it lands, cooling. Held in the hang (not down in `FALL_MAX` 0.3 s): no splat, it just goes | `comic_melt.gd` `swing(parent, at, fwd)`, `foe(parent, e, frozen)` in `_meltdown` (was shards, an earth burst and a scorch each) |
| Eruption | Nearest first 0.05 s apart: a jagged hot break in the floor under each foe (bigger and with a hot star for the `molten`), three pointed rock slabs leaning out of it and three lava blobs off the top, sinking and cooling by 0.5 s; game time, so the hit stop holds it past the impact frame | `comic_erupt.gd` `spawn(parent, at, spots, hots)` in `_eruption` (was a geyser and five spikes each and a 3.5 m scorch) |
| Impale | Eight ice spikes race out of the spear's foot across the floor (0.35 s); each foe gets a crystal stake from the spear's foot up through its chest and out past it once its throw lands, an ice star where it goes in, 0.45 s | `comic_impale.gd` `burst(parent, spot, r)`, `stake(parent, spot, e, flight)` in `_impale` (was frost_ring's torus) |
| Backdraft | Eight inked wind strokes burst off the spear round a small star (0.3 s); per foe a see-through wind ribbon towards his hand (at most `RIBBON_MAX` 2.6 m of it, bowed 0.12) with three speed strokes, and the ice cracking off the skewered; rides the foe, 0.45 s | `comic_backdraft.gd` `blast(parent, spot)`, `haul(parent, e, hand, skewered)` in `_backdraft` (was a wind pillar and a lightning arc each) |
| Anvil | Per crater, nearest first 0.04 s apart: three fat down strokes over it on the first two steps, an inked dent (hot then deep earth) with five cracks, two rubble chips; 0.5 s, game time | `comic_anvil.gd` `spawn(parent, at, spots)` in `_anvil` (was three earth spikes each) |
| Tow Line's air rip | A jagged inked void tear across the airborne foe's chest, a small star, four ink drops flicked away from him; rides it, 0.3 s | `comic_rip.gd` `spawn(parent, e, at)` in `fire()` `TW` |

Words (`ComicFx.MOVE_WORDS` / `BREAKER_WORDS`): XR KRUNCH!, XF SKRRRAK!, XS PSSHHHH!, XT ZZWANNG!, Cataclysm
KRAKA-DOOM!, Flash Freeze FSSHINK!, Black Ice KLISSSH!; second pass XG WHIRRRL!, XM SIZZ-BLAM!, XK KSHUNK!,
XW FWHOOOM!, Eruption BLOOORRM!, Anvil KLANNNG!; round 49 XL SHLURK-FWOOM! (said by the move on the eruption,
`LATE_WORDS`), Hellseam KRAKA-FWOOOM!.

**State tells** (`scripts/comic_state_tell.gd`): a foe carrying an improvising state shows it until the state goes
(`ELEMENT_HOLD`, real time, fading over its last 0.4 s; gone at once when a payoff spends it). `enemy._physics_process`
calls `STATE_TELL.sync(self)` (three `has_meta` calls when it carries none); one tell node per foe, a child of the
foe, draws every state it has and is out of `standing_fx` (it is meant to outlast the next string's first hit):
molten is a see-through halftone glow over its lower body (earth dots, hot in the middle, pulsing on twos, an ember
now and then), buried an inked crack ring on the floor round its feet (earth deep), skewered an ice stake stuck
through its chest.

### Three-element strings (round 34, second pass)

Two longer strings hand over twice, and each hand-over pays only for what the element before it left. Both end in
a breaker window.

| Input | Id | Name | Elements | Payoff |
|---|---|---|---|---|
| Dash L H H H | `XG` | Hailstorm | ice into storm | A whirlwind under every frozen foe within `HAIL_REACH` (Ice Cube's bowl too: `THROWN.cut`) carries it up at `HAIL_LAUNCH`, still in its ice (`freeze_aloft()`: `enemy.freeze()` staggers, which would drop it), and he climbs 2 m after them (`air`, `climb`). The warm only stagger up (`HAIL_WARM_*`) |
| Dash L H H H L | `XM` | Meltdown | storm into magma, in the air | The molten hammer up there with them: everyone airborne or frozen within `MELT_REACH`, the ice bursting off (x `FREEZE_BREAK`), those in the air x`MELT_AIR_MULT`, all driven down burning (`MELT_DOWN`: craters) and `molten`. The window opens, from his height (`height` 3) |
| Dash L H H H L, H in window | `XM` | Eruption | magma | The floor goes up under everyone near (`under()` earth, `ERUPT_LAUNCH`), the `molten` x`ERUPT_MOLTEN_MULT` |
| (L L H,) Dash H H | `XK` | Impale | dark into ice | Whoever Tow Line bunched (`IMPALE_GRAB` round him) is cut off its tether and thrown onto the frost spear, frozen in a cube and `skewered`, in a ring `IMPALE_RING` round it. Onto a spear already standing it's x`IMPALE_SPEAR_MULT`; with none it plants one where Tow Line bunched them |
| (L L H,) Dash H H L | `XW` | Backdraft | ice into storm | The gale off the axe blows the spear apart and hauls everyone within `BACKDRAFT_REACH` of it back to him and up (`BACKDRAFT_PULL`, `BACKDRAFT_LAUNCH`); the skewered (still frozen: x `FREEZE_BREAK`) take all of it, anyone else 0.6. The window opens |
| (L L H,) Dash H H L, H in window | `XW` | Anvil | earth | The hammer drives everyone held into the floor, a crater each (`ANVIL_DOWN`, x`ANVIL_AIR_MULT`); anyone near still in the air comes down with them, the rest are thrown clear |
| (L L H,) Dash H H L, L in window | `XW`, its `alt` | Pinwheel | wind | Breaker pairs. The dive is a whirl where he hangs (`pinwheel`, `PINWHEEL_DIVE` 0.42 s): `void_grab.seized_tick` swings the held kebab `PINWHEEL_TURNS` 1.25 round him out to `PINWHEEL_R` 2.3 m at his chest (`PINWHEEL_Y`), he spins with it and a twister stands round them (`breaker_alt_fx.pinwheel_ring`). On landing each is hurled (`thrown_foe`, wind, `PINWHEEL_SPEED` 24 m/s) at the nearest wall or pillar within `PINWHEEL_REACH` 10 m (`pinwheel_target()`: 32 flat rays past the foes) for `PINWHEEL_DAMAGE` 20 x `PINWHEEL_WALL_MULT` 4 = 80 each (ground stamp, gust, KRAK-THOOM!, a stop each: `pinwheel_wall`); no wall in reach, they fly `PINWHEEL_OPEN` 7 m out along the swing and land for 20. Anyone else in the whirl takes `PINWHEEL_SWEEP` 0.5 and is blown clear. Best by a wall or pillar (80 vs Anvil's 44 x 1.4 = 62 a foe); in the open Anvil wins |

With the spear standing, presses off `NO_VAULT` moves (TW, XK, XW, XT) go on down their own string instead of up
the spear (`vaults()`), so L L H, Dash H H L is 8 presses with the breaker.

### Improvising: dash routes out of the crossovers

A crossover's state outlasts its string by `ELEMENT_HOLD` (2 s): the ice (`FREEZE_TIME` is `ELEMENT_HOLD`, was 1.8)
and the metas `mark(e, "buried" | "molten" | "skewered")` (real time; `marked()`, `unmark()`). Every payoff reads
the state, never the route, so a dash cancel and any move of the paying element cash it in:

| State | Paid by (any route) | How |
|---|---|---|
| frozen | magma: Molten Palm (L L L H, Dash L L L H), Steam Burst, Meltdown | Molten Palm with anyone frozen in its strip goes off as Steam Burst (`fire()` "EM", `_frozen_ahead()`) |
| buried (Rockslide) | storm: Updraft Lash, Storm Pitch (Dash H L) | the storm move's hit again on top, x`FAULT_BURIED_MULT` in all (`_cash_buried()`), once |
| airborne | dark: Tow Line (Dash H) | ripped out of the air: an extra `TOW_AIR_MULT - 1` of Tow Line's damage on the way in |

So, crossover by crossover: Rockslide, dash, H L (Storm Pitch throws the buried up crackling, x2); Fault Line,
Steam Burst, Flash Freeze, Hailstorm, Backdraft (all launch), dash out of the hang or the move, H (Tow Line rips
them out of the air); Ice Cube, Impale, Hailstorm (ice left on them), dash, L L L H (Molten Palm steams them) or
L H H L off the dash for Steam Burst; Meltdown's `molten` lasts for Eruption only. Black Ice, Cataclysm, Meteor
Fall, Eruption and Anvil end in craters: nothing to carry.

Third pass: every other state x element cell paid something too, through `improvise()` at the top of `fire()`.
Round 49 (kit grammar section 3) collapsed that grid into **one rule per state**, any element's hit: frozen Shatter
(x1.6, the ice gone), charged Arc (on through every other charged foe), molten Burst (x1.5, a burn round it), bound
Snap (x1.5 unblockable, the hold ends), airborne Juggle (kept up), buried Crater (x1.5 back into the floor). The old
cells (Gale Lift, Shard Cut, Frozen In, Swallowed, Firestorm, Quench, Flare-up, Smother, Ice Spreads, Torn Off,
Freeze Aloft, Meteor Spike, Torn Loose, Frozen in the Dark and the four charged ones) are Kit upgrades. The tables are
[element-matrix.md](element-matrix.md). The "bound" state is `floor_bind.holds()`.

#### Third pass: air timing and fixes (round 34, filmed `string_film -- --from=17`)

- **Meltdown** met the cubes on their way up: `HAIL_LAUNCH` 12 had a foe still rising at 7 m/s past him (peak 5.3 m,
  his climb stops at 2.8); now 9 (peak ~3 m, into its apex hang by the slam), and Meltdown plays at
  `hero_moves.MELT_SPEED` 1.5 (XG -> XM beat 467 -> 413-419 ms).
- **Backdraft's pull-back** never showed: Anvil leaps ~0.25 s after Backdraft's hit, before the gale's knockback has
  moved anyone (the foe's hit freeze), so the tentacles lifted them where they stood. Anvil's entry has
  `reel` (`ANVIL_REEL` 0.65 of the way to `ANVIL_REEL_GAP` in front of him, `void_grab.seize()`): the haul up is the
  kebab coming back. Round 4: hauled to one point they landed in one pile (0.08 m apart); the reel now fans
  them across his aim, `ANVIL_SPREAD` 1.5 m between neighbours in the order they stand, held there and kept
  through the dive (the seized entry's `fan`), so each gets its own crater.
- **Rockslide -> Fault Line:** Rockslide's stop is `ROCKSLIDE_STOP` 0.07 (was 0.1; with its tier-2 ender stop it was
  150 ms of the beat) and its hit-confirm cancel `ROCKSLIDE_CONFIRM` 0.8 of the way back (a move's `confirm`
  overrides `CANCEL_ON_HIT`); the contact frame is unchanged. Fault Line's beat 393 -> 310-325 ms.
- **Range-0 moves** no longer run `_do_hit`'s melee loop: `range` 0 still caught a foe standing on him with a
  0-damage hit that broke its ice before `fire()` read it.
- **The bot's Hailstorm string** is `line D L H H H L`: `line` stands the dummies in a column
  (`training_bot.BOT_LINE_FROM` 5 m out, `BOT_LINE_GAP` 1.6) past where the dash and Dash Stab carry him, so Harpoon
  reels three in and Hailstorm lifts them all (it lifted one).

### Breakers (`VOID_ELEMENT.BREAKERS`)

| Input | Off | Name | Ending |
|---|---|---|---|
| L H H, H in window | `EE` | Grounded | Slammed down, with lightning under each |
| L H L H, H in window | `EW` | Worldbreaker | Slammed down, with magma erupting under each |
| L H L H, L in window | `EW`, its `alt` | Cold Front | Frozen solid and hurled at other foes as ice cubes |
| L H L L H, L in window | `XF`, its `alt` | Tempest | Breaker pairs. He lands as for Cataclysm, and a twister (`breaker_alt_fx.twister`, the designed one, 5.5 m) goes up `TEMPEST_OUT` 1.4 m past the held pile's middle and takes everyone not big within `TEMPEST_REACH` 7 m (`tempest_riders()`, nearest first, `TEMPEST_MAX` 8) up its column: a game-time tween spirals each in to `TEMPEST_R` 1.1 m and up to `TEMPEST_HIGH` 2.4 m (+0.55 for every other, so they stack), FLYING meta on, after the landing's freeze. From `TEMPEST_FIRST` 0.42 s a bolt out of the sky blasts each out in turn (`TEMPEST_STEP` 0.09, `comic_bolt`), `TEMPEST_DAMAGE` 20 x (1 + `TEMPEST_PER` 0.5 per other foe in the column), charged, thrown clear and up (`TEMPEST_THROW`, `TEMPEST_LAUNCH`). Big ones stay down and take `TEMPEST_BIG` 0.6 of a blast. The best situation is a crowd: one foe 20 vs Cataclysm's 46, two 2 x 30 vs 92, four 4 x 50 = 200 vs 184, five 5 x 60 vs 230 |
| L L H L H, H in window | `IS` | Avalanche | A tentacle on every cube (`seize`, `press`). The press lifts them all and slams them together in the middle of where they stood (`aim_crush`, `crush_point`), landing on the frame he does, and he lands `short` of the pile. One cube comes down where it was. Anyone else within `CRUSH_RADIUS` takes `PRESS_NO_CUBE` of it. Elites in cubes go too; bosses never get a cube. Dedicated shatter damage is still to come; for now each takes the breaker's damage |
| H H, H in window | `VS` | Collapse | He comes down at the hole (`at_spot`, `short`), it falls in on itself, and everyone near is thrown clear |
| H L H, H in window | `VD` | Maw | He lands short of the pool and jaws of darkness shut on everyone in it |
| hold H, H in window | `OW` | Abyss | They sink through the floor (`ABYSS_SINK`) as he comes down, then black spikes throw them back up |
| L L L H H, H in window | `EV` | Meteor Fall | He goes up (`height` 3.6) holding nobody (`no_hold`); Undertow keeps them pinned in the lava. The floor cue sits on the group he will hit, and the press dive-bombs it as the meteor (`_dive`, `meteor_shell`): `meteor_spot()` / pure `meteor_target()` groups the living foes this string's Molten Palm hit (meta `last_palm_ms`, fresh for `METEOR_PALM_FRESH_MS` 4 s; nobody else draws the dive, however many they are) within `METEOR_REACH` (12 m) by `METEOR_PILE_R` (3 m) round each, scores a group one a foe and `METEOR_WALL_WEIGHT` (1.5) a foe splatted on a wall in the last `METEOR_SPLAT_FRESH_MS` (3 s, `thrown_foe` meta `last_wall_ms`), picks the best (the nearer on a tie) and lands on its middle; nobody in reach: `zone` ahead of him. The dive takes 0.3 s, longer for a far group (`METEOR_DIVE_SPEED` 30 m/s flat: 12 m in 0.4 s). The landing (`_meteor_landing`) lets Undertow go and craters everyone in `METEOR_PILE_R` (`METEOR_DOWN`): x`METEOR_HEAVY_MULT` 1.5 on big ones, x`METEOR_SPLAT_MULT` 1.3 on those fresh off a wall splat, shields off, rim geysers round him. The play: Molten Palm punches a group into a wall (x2.5), Meteor Fall drops on that group, not on a stray |
| L L L H H, L in window | `EV`, its `alt` | Meteor Shower | Breaker pairs. He comes down where he hangs (`shower`: `hero_leap._aim` puts the zone under him, no fireball round him) and a fireball falls out of the sky onto every foe this string's Molten Palm hit, wherever it is (`shower_targets()`: `palm_fresh`, within `METEOR_SPLAT_REACH`, nearest first, `SHOWER_MAX` 6), one after another on real time (`SHOWER_DELAY` 0.12 past the impact frame, `SHOWER_STEP` 0.08, each `SHOWER_FALL` 0.24 from 7 m up, slanting in from his side: `breaker_alt_fx.meteor_drop`, the designed fireball at 0.55 size and a small designed meteor landing). Each is `SHOWER_DAMAGE` 30 into the floor on its foe alone, and leaves it molten; the last lets Undertow go. The best situation: the palm scattered them (four apart: 4 x 30 against Meteor Fall's 60 on the one it dives on); a pile at a wall is Meteor Fall's (3 x 60 x 1.3 against 3 x 30) |

| Dash L H, a pause, H in window | `EF` | Shatterstorm | Round 47. Harpoon's breaker comes on a pause: its `leap` (`LEAP_AFTER_HARPOON` 0.36) is after the move's cancel (0.16), so H in between is still Ice Cube and only no press leaps (`hero_input.cancel_point` lets a leap after the cancel wait). Its entry is marked `pause`, so Harpoon stays a mid for the callout (`callout_cap.names_move`: no name over him). A tentacle holds each cube of the row through the hang (`hold_cubes`, `void_grab.harpooned`; the hang first sets down anyone still carried, `harpoon_gather.finish_now()`, and re-ices a cube a stray hit broke, e.g. Dash Stab's delayed lash or the Awakening's burst) and he lands just behind it (`zone` 0.6). Thunder (`elements.storm_strike`, the sky strike) crashes on each cube in turn from the middle out (`SHATTER_DELAY` 0.12 past the impact frame, `SHATTER_STEP` 0.06), `SHATTER_DAMAGE` 30 each (x `FREEZE_BREAK` on the ice), and charges them. Good anywhere |
| Dash L H, a pause, L in window | `EF`, its `alt` | Slapshot | Molten Palm's fist (`_fist`, a tentacle behind it: `slapshot_fx.cord`) goes out to the row and punches every cube along his aim, steam where magma meets ice (`slapshot_fx.punch`, three clouds at most). Each slides (`thrown_foe` `slide`, `SLIDE_SPEED` 20 m/s, `SLIDE_SPIN` 2 rad/s, no splash) with a frost streak behind it (`slapshot_fx.trail`). A wall within `SLIDE_REACH` 10 m: it shatters there at full speed for `SLIDE_DAMAGE` 14 x `SLIDE_WALL_MULT` 4.5 = 63 (`slapshot_fx.wall`: big ice shatter, ground stamp, KER-SMASH!, a hit stop each; it stops when the face of its fitted ice meets the wall: `wall_gap` from `ice_radius()`); no wall: it slows to `SLIDE_END` 0.3 of its speed and bursts for 14. The best situation: the row aimed at a wall (63 vs Shatterstorm's 30 vs 14 in the open). The sliding cubes are cued for the camera (`FRAME_CUE`, `SLIDE_CUE_MS`) |

`alt` is merged over the breaker when the press was L (`_brk_alt`, `_start_dive`). The prompt shows both buttons and both names when a breaker has one (`breaker_window().alt_name`).

### Thrown foes (`scripts/thrown_foe.gd`)

`launch()` flies a foe at a spot, and its `opts` set what kind of flight it is:

| Option | Effect |
|---|---|
| `el` | What it bursts in (dark moves use `void`) |
| `pierce` | Runs through foes, hitting each once |
| `quiet` | Stops at the end instead of bursting, unless a wall stops it first |
| `solid` false | Ignores other foes |
| `tether` | Draws a tentacle to it |
| `wall_mult` | A wall splat's damage (a splat also sets the foe's `last_wall_ms` meta, `WALL_META`: Meteor Fall goes for those) |
| `slide` | On the floor; short of a wall it slows to `SLIDE_END` of its speed before it stops and bursts (Slapshot) |
| `splash` false | Its burst leaves the neighbours alone (a row of cubes each bursting into the next re-froze the shattered) |
| `spin` | Its cube's turn rate (`CUBE_SPIN` by default) |
| `on_burst` | Told (foe, walled, dir) as it bursts: the wall hit's look |

`VOID_ELEMENT.cube_target()` picks the spot for Cold Front: the nearest foe it wasn't holding, then another it was, then straight out. `cube_on()` is the look: a box for his throws, leaving the plain ice cylinder for other freezes (in the comic style both are `thrown_foe.comic_cube()`: flat two-tone ice, a pale 42% top and 15% blue sides with a white glint and the ink edge, so the foe shows inside; `enemy.freeze()` calls `thrown_foe.comic_ice()` for its cylinder). `encase()` freezes a foe and puts it in the box.

On the bench: Puppet, Knot, Maw, Meat shield, Hanging up.

## Look

Judged from the game camera with `tests/element_shots.gd`. Every element effect on this hero is flat
camera-facing geometry in layers (ink, one element colour, one light tone, a hot yellow-orange star for
impacts), redrawn on twos, peaking on its first frame and gone in about a third of a second. They share
`heretic_form_fx.material()` (unshaded vertex colour, no depth test), prewarmed in `elements.prewarm()`,
and each has a public `tick(delta)` and a local `RandomNumberGenerator`.
Round 32 (feel audit 2026-11-04): words sit at the blow, one at a time; the impact frame only flips on breaker
landings and kills; the hero's paper rim (`heretic_rig._add_rim`) draws over these effects. Still open:
standing element effects outliving the string (pools, geysers, crack, frost disc) and Molten Palm's small fist.

| Effect | Script | Used by |
|---|---|---|
| Lightning bolt: a fat zigzag, new each step, with forks; an impact star when it comes from the sky | `scripts/comic_bolt.gd` | `element_rite.arc()` (Live Wire, the rite's thunder), `elements.storm_strike("wind")` (Grounded, wind thrown foes) |
| Lava geyser: an overshooting column, a splash star, inked blobs off the top | `scripts/comic_geyser.gd` | `element_rite.geyser()` (Meteor Fall, Worldbreaker, Magma Burst) at 0.7 of the asked height and 0.75 of the radius wide |
| Whirlwind: five fat wind bands round a funnel, spinning in held frames | `scripts/comic_gale.gd` | `elements.pillar("wind")` with the comic style (Updraft Lash) |
| Frost: inked cracks, a ring of ice teeth and plates, bare floor between, depth tested | `frost_spear.frost_mesh()` | the Frost Spear |
| Ice spikes: flat two-tone ice with the ink hull, 1.35x chunkier, overshooting, no dots or dust | `elements.comic_ice()` | `spikes()` and `nova()` with the comic style (Cold Front, Harpoon, Deep Freeze) |
| The black hole: Black Tide's churning ink at `Hole.VIEW_R` 2.6 m, so the pile on it can't hide it; Collapse is a held-frame `Splat` | `dark_fx.Hole` | Singularity, Collapse; `dark_fx.burst()` is a small splat and ink debris |
| Ink burst: 5-7 flat tentacles out of a blob, ink edge, violet body, hot core line, narrowing in 4 segments and curling, five held frames | `dark_fx.Splat` | `dark_fx.burst()` (Tow Line landing, GR, Overwhelm), Collapse, Maw |
| The void tentacle out of his hand (grabs, Harpoon, Tow Line ropes, the R swing): a flat camera-facing ribbon in the splat's layers (ink edge, violet body, hot core line), 0.52 m wide at the hand tapering to 0.26 in four segments, sagging 5% of its length, its whip stepped on twos while the ends follow every frame; depth tested so a coil goes behind what it holds (a 0.17 m shaded tube read as a pink thread) | `scripts/void_tendril.gd` | `void_grab.gd`, `thrown_foe.gd` (tether), `floor_bind.gd` |
| Damage numbers: one per foe, hits within `MERGE_S` 0.32 s add in and pop it (1.5, 1.18, 1); Bangers, ink with a red print offset, big hits hot yellow in orange and ink; drift off the pile's middle on twos, and each step a number overlapping his combo-name callout (both lines, so PERFECT counts), a live word or the breaker prompt steps aside the shorter way (`dodge()`, `ComicFx.text_blocks()`, the rects the words already avoid) | `scripts/comic_number.gd` | `Fx.damage_number` (the foe passes itself) |
| Hit flash: the foe's own outline goes paper then the hero's colour for half the flash each, no overlay | `Fx.flash_tint`, `Fx.flash` | every hit on a foe with its own ink (`Fx.outline_own`) |
| Bursts and burns: `Fx.burst` is 2-6 two-tone chips (smoke draws nothing); `Fx.scorch` is an inked splat with jagged cracks out to 0.8 of its radius, hot for two steps, then a darker tone, shrinking at the end; depth tested | `comic_pop.gd`, `scripts/comic_crack.gd` | floor_bind ticks, wells, rites, Molten Palm, geysers |
| Hit flourishes: a hot inked impact star, fat paper speed strokes along the blow, two-tone element chips, a halo in his colour behind the star from chain tier 1, radial strokes round him for a named combo, a held kill star with bone chips; no flares, dot sprays, smoke or soft rings | `scripts/comic_pop.gd` | `Fx.hit_spark`, `impact`, `chain_spark`, `element_hit`, `combo_pop`, `death`, `shards`, `ring` with the comic style; `Fx.dust` draws nothing |
| Breaker dive: a fat inked comet streak with a hot core, ending in a held impact star; the cue is crisp inked bands | `scripts/comic_comet.gd`, `breaker_cue.gd` | `hero_leap._comet()`, every breaker (see combo-breakers.md) |
| Molten Palm's fist: flat, wider than long, four fat knuckles glowing molten, stretched in flight, squashed with a star on arrival | `scripts/comic_fist.gd` | the one-line hook at the top of `void_element._fist()` |
| Abyss spikes: flat inked violet spikes round a hot core, 1.3x the asked height, coming up `SPOUT_DELAY` 0.12 s late so the impact frame doesn't swallow them; spouts asked for together keep `SPOUT_SPACING` 2 m apart, at most `SPOUT_MAX` 3 | `dark_fx.Spout` | `dark_fx.spout()` |
| Dash Stab's lash: the claw whips the tentacle's inked ribbon out 8 m ahead and snaps it back (it replaced the shaman's spirit tomahawk, whose flat cyan axe was also the "cyan slab" over Ice Cube frames) | `scripts/claw_lash.gd` | `player._cast` ("lash") |
| Words: each signature move says its own word on its first hit (`ComicFx.MOVE_WORDS`, sized by its combo tier), each breaker its own on landing (`BREAKER_WORDS`, `BREAKER_SCALE`); every word goes beside the hero towards the hit, in the direction with most room from the foes, the hero, the other words, his combo-name callout and the breaker prompt (`_place`, all as screen rects) | `scripts/comic_fx.gd` | it watches the hero's `_move_id`, `_hits_done`, `breakers_landed` (read only) |

Sizes that read at the game camera (about 50 px a metre at 1080p): bolts 0.26-0.4 m for the colour band
with ink twice that, a 1.1 m impact star, geyser columns 0.7 m across and 2.2 m tall, wind bands 0.32 m.
Five geysers at 1.35 m wide walled off the whole landing; a 6 m frost disc at 30% washed out the frame.
A hit star at 0.45 m (big 0.65) reads on each foe in a crowd; chain halos at 0.7 m with a ring were a cyan
thicket over a four-foe pile, so they stay at 0.32-0.5 m and last two steps.

## Files

| File | Role |
|---|---|
| `scripts/void_element.gd` | Routing tables (`AFTER`, `AIR_FROM`, `CHAIN`), `BREAKERS`, `fire()`, `zap()`, `breaker_impact()`, `cube_target()`, all tuning |
| `scripts/thrown_foe.gd` | A thrown foe, its cube |
| `scripts/floor_bind.gd` | Tendrils out of the floor holding foes: Undertow and Overwhelm |
| `scripts/frost_spear.gd` | The planted spear, its frost and `frost_ring()` |
| `scripts/comic_bolt.gd`, `comic_geyser.gd`, `comic_gale.gd`, `comic_pop.gd`, `comic_comet.gd`, `comic_fist.gd` | The flat comic bolt, geyser, whirlwind, hit flourishes, dive comet and palm fist (see "Look") |
| `scripts/dark_fx.gd` | The dark element's things in the world: `Hole`, `Mark`, `Pool`, `Maw`, `Splat`, `ink_drops()`, `spout()`, `reap()`, `burst()` |
| `shaders/dark_ink.gdshader` | Churning floor ink (spiral streaks, wobbling rim, stepped time, `open`, `erode`) |
| `scripts/hero_moves.gd` | `MOVES` and `COMBOS` rows, `void_route()` |
| `scripts/hero_leap.gd` | `entry_for()` (`player._breaker_for()`), `_pressed()`, State.LEAP's `tick()` |
| `scripts/void_grab.gd` | `reachable()`, `seize()`, `seized_tick()`, `slam_seized()`, `freeze_seized()`, `held_foes()`, `release_seized()`, `_tick_sweep()` |
| `scripts/breaker_prompt.gd` | Shows both buttons and names when a breaker has an `alt` |
| `scripts/comic_look.gd` | `HERO_MOVE_FORMS`: which weapon each move forms |
| `scripts/move_list.gd` | `VOID_SECTIONS`, `VOID_ONLY` |

## Invariants

- `player._breaker_for()` (`hero_leap.entry_for()`) reads only `VOID_ELEMENT.BREAKERS`; the shared leap / window / dive machinery is in [combo-breakers.md](combo-breakers.md).
- A breaker entry is `_WINDOW` merged with its row (`entry()`).
- `leap` must be at or before the move's `cancel`.
- Every exit from the hang lets go: no press, dash out and `_end_leap` all call `release_seized()`. The tendrils stay in `_spare` for the next one.
- `_end_leap` clears `_buffered` for this hero, or the press that dove him would also start a move.
- Damage comes from `fire()`. The move's own blow in `MOVES` is small or none, and `fire()` returning above 0 counts as connecting.
- `fire()` runs once per move, on its first hit.
- A tentacle breaker rises from the height he's at (`_brk_y0`), so one off the air string doesn't pop to the floor.
- Re-stagger held foes every `RESTAGGER`, not every frame: each stagger flashes them white. It must stay under the 0.4 s a hit's stagger lasts, or a zapped foe wakes up in the tentacle's grip.
- A freed foe can reach `thrown_foe.launch()` and `remove_cube()` through a delayed call, so those arguments stay untyped: a typed argument errors before the validity check runs.
- These moves skip `_swoosh` and the weapon trail. All of them land on him and hid what the tentacle was doing.
- `AL1` and `L3` skip their casts for him (`NO_CAST`): their giant axes stood in front of the tentacle move that follows.
- His element and tentacle moves skip `Fx.combo_pop` entirely, and `ComicFx` spaces words by `WORD_GAP_HERETIC_MS` for him, since these moves hit whole crowds at once.
- Maw is the test of the new effect style: the jaws rise during the dive (`hero_leap._start_dive`) and `bite()` snaps them shut on impact, so the breaker's hitstop holds the shut frame. Its hit goes through `enemy.burn_hit(damage, true)`, one word for the bite, and `Splat` and `ink_drops` in place of gold sparks. A foe killed by it still gets the normal death effect.
- On this hero a style rank climb is a thin `hoop_run`, not the soft ring and star, which sat on him and fought his effects.
- While the frost spear stands, either button vaults (`vaults()`, from `hero_moves.routed`), not only during the plant's animation: that ends before the frost has finished spreading, so a player watching it got a plain slice. `tests/void_arm_check.gd` `_spear_by_hand` plays this with real button presses.
- Black Tide's flight is capped at `TIDE_ARRIVE`: far foes fly faster, so an early Maw press can't bite before they reach the pool.
- Damage that ticks on a whole crowd (`dark_fx.Hole`, `floor_bind.gd`) goes through `enemy.burn_hit`: the damage and number with no sparks, word or flash, which buried the thing holding them.
- Tentacle breakers (and every comic hero) use the `crisp` version of `breaker_cue.gd`, flat inked bands, since they land right on that spot.
- A breaker's cue, prompt and war cry come in `_brk_color()`, what it lands in, not his axe's teal. Tentacle breakers also skip the war cry's bubble: it hid him and filled the floor.
- Tentacle breakers skip the `Fx.combo_pop` on landing, and his element moves skip the `_land_slam` ring. Avalanche also skips the crater: its ice buried the cubes as they left.
- `cube_on()` hides the plain ice cylinder every time, even on a foe already in a cube: `enemy.freeze()` shows it again on each refreeze, and `seize()` refreezes the cubes for Avalanche's window.
- Nothing else may move a foe in flight: check `thrown_foe.flying()`.
- A lava well outlasts the Undertow that made it and goes on burning whoever stands in it.
- New moves go in `VOID_ONLY`, or `move_list_check` expects `route()` to reach them.
- Clips come straight from `MOVES.anim`, as with `GR` and `VS`, so hit fractions are frame / frames of that clip.
- **Timing contract (round 30, `tests/rhythm_check.gd`).** A press is held `player.BUFFER_MS` (300) and fires on the first frame
  past `player.cancel_point()` (`hero_input.cancel_point()`): the move's `cancel` on a whiff, `CANCEL_ON_HIT` (0.5) of the way back to its last hit once it
  connected (`fire()` above 0 counts), never before `HIT_CONFIRM_MIN` (0.03 s) after it or before the breaker's `leap`. A dash
  cancels every one of these moves once its first hit is out (or `DASH_CANCEL_WHIFF` into a whiff), and a breaker's hang
  too. The breaker windows share one rhythm off the rise (`BREAKER_HANG`, `BREAKER_TO_SWEET`, `BREAKER_TO_CLOSE`; see
  [combo-breakers.md](combo-breakers.md)). Molten Palm plays at `player.EM_SPEED` (2.1): its palm lands 471 ms in.

## Tuning

Damage: `CUTTER_DAMAGE`, `WIRE_DAMAGE`, each breaker's `damage` (times `perfect_mult` 1.5 and the chain's `_cast_power()`), `thrown_foe.OTHER_MULT` and `SPLASH_MULT`. Timing: `_WINDOW` (`perfect`, `rise`; `open` / `sweet` / `close` follow the rise through `BREAKER_HANG` / `BREAKER_TO_SWEET` / `BREAKER_TO_CLOSE`), `WIRE_START`, `WIRE_STEP`. The hold: `SEIZE_RANGE`, `SEIZE_MAX`, `SEIZE_LIFT`. The throw: `thrown_foe.SPEED`, `SPLASH`, `CUBE_HIGH`, `CUBE_SEEK`. Each move's reach, damage and time are constants at the top of `void_element.gd`, named after it (`REAP_`, `TIDE_`, `COLLAPSE_`, `MAW_`, `ABYSS_`, `HARPOON_`, `SPEAR_`, `DEEP_FREEZE_`, `PRESS_`, `PALM_`, `UNDERTOW_`, `FLAIL_`, `OVERWHELM_`, `TOW_`). R with nothing to latch onto: `void_grab.SKY_MIN`, `SKY_MAX`.

## Not done

- Clips are borrowed from other moves, so the poses are approximate until the VFX update.
- Heavy foes aren't lifted. Their answers are the lightning, Meteor Fall and Overwhelm.
- Still soft on this hero: the dive comet and breaker cue discs, the orange hit flares and chain dots on every foe, `Fx.shards` smoke, Molten Palm's fist, the Undertow smoke and the scorch decals (see "Look").
- The storm, ice and magma strings and R have been played by hand. The dark string has not.
- Molten Palm's fist is a rough lump until the VFX update.

## Checks

`godot --headless --path . -s tests/void_arm_check.gd` covers the three-element strings and the improvised payoffs
(`_three_elements`), routing, each move hurting a foe, each breaker holding and hurting a foe and letting go, both window endings, a missed window, cubes hitting foes and walls, the ice strings including the spear, the magma strings, the dark string and its breakers, and the snatch (PASS/FAIL, stand-in foes, in `agent.sh check`).

`godot --path . -s tests/element_shots.gd` is windowed. It films each string against real foes at the game camera, through the hang and the slam, and R's swing, to `user://element_shots/`.
