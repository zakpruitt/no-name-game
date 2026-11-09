# The effects language

Zak, 2026-11-07: "I want a big effort on improving effects to look modern and cohesive. It's fine for them to look
cartoony, but I want them to be extremely polished and great looking." The quality bar is three effects he called out:
**Avalanche** ("fantastic"), **the air twister** and **the lime lightning**. Standing verdicts: effects are authored
designs, never primitive assemblies ("does a paused frame look drawn?"); no spiky ice crystals; see-through ice blocks
are loved; clean simple shapes beat busy clusters.

This page is the contract every fx lane is held to. It names the beat, the stepping, the palette and ink, the shapes
per element, a ten-item checklist, and an audit of every effect script against it, judged from film (lane fx-modern,
`string_film.gd -- --kit=full --dir=fxm_before`, every bot string, 12 fps from the game camera). Shared code:
`scripts/fx_beat.gd` (timing, stepping, ink widths, the pooled `stamp()`), `tools/vfx_gen/vfxlib.py`
`cluster_angles()` (radial layouts), `scripts/fx_palette.gd` (tones), `shaders/designed_fx.gdshaderinc` (ramp + erosion).

## 1. The beat

Every effect is three beats. The numbers are `FX_BEAT` constants; a lane that needs other numbers writes why next to them.

| Beat | Length | Clock | What the drawing does |
|---|---|---|---|
| Anticipation | `ANTIC_S` 33-120 ms (one 30 Hz frame for a hit; up to 0.12 s for a wind-up, or it never reaches a 12 fps film frame) | real time (`real_until = 1`) | A pinched, smaller, hotter drawing: a glint, a pull-in, a leader. Never just the peak at 50% scale. |
| Hit (peak) | `PEAK_S` 70-120 ms, plus whatever the hitstop holds | game time: the hitstop freezes it | The biggest, fullest drawing with the one hot area. `PEAK_POP` 0.12 overshoot on the step in, settling over two steps (`SETTLE` 1.15, 1.0). |
| Dissipate | `DISSIPATE_S` 180-450 ms | game time, capped in real time | The shape breaks in an order (hollow from the centre for stars, edge clumps for splashes, tail first for strokes, plate by plate for floors) through `erode` with a burn line, starting at `ERODE_FROM` 45-60% of the life. Never a plain alpha fade or a scale to zero. |

- **Stepping: on twos.** Drawings change at `STEPS_PER_S` 12 (`STEP_S` 1/12 s); `FX_BEAT.step(t)` / `on_twos(t)`
  for hand-driven shapes. Position may follow its owner every frame (a crawl riding a foe, a trail's head); the
  drawing on it still steps on twos. Only the anticipation and a white-hot flash flicker on ones (`ONES_S`).
- **Frame-time arrays:** `FX_BEAT.HIT` (every-hit), `BEAT` (a move's or breaker's beat), `FLOOR` (spreads that
  linger); `times_for(base, life)` stretches the tail only.
- **Life caps (real s):** `LIFE_HIT` 0.45, `LIFE_BEAT` 0.9, `LIFE_STANDING` 1.6 and a standing effect also fades when
  the next string's first hit lands (`standing_fx`). Slow motion must never hold a look past its cap.
- **Impact frame** (the screen negative, `impact_frame.gd`): only on a breaker landing and a kill, at most one per
  900 ms. Anything that must be seen on a landing starts after it (`designed_breaker.BEAT_S` 0.11 s).
- **Words:** one on the page at a time, hot red-yellow in every element (never element-coloured), placed round the
  contact point, never over the callout. Short word on a light, long heavy word on an ender, the name banner only on a
  named combo / breaker. A word is part of the peak beat: it appears with the peak, not the anticipation.

## 2. Palette, ink, fills, glow

- **Palette:** one five-tone row per element (`fx_palette.ELEMENTS`, `AIR`, `DUST`; rows in `DESIGNED.ROWS`): ink,
  deep, body, light, hot. A sheet stores tone, not colour, so one drawing serves every element. No hard-coded colours
  in an effect script (grep for `Color(` in a new effect: every one must come from `PAL.of()`). Rock and debris are
  the `dust` row (stone), never the magma row: magma is only what glows.
- **One hot area per effect** (the core, the bolt's centre line, the crack's heart). Two hot areas read as two effects.
- **Flat fills per shape: at most three** (body, a light shape offset up-left, the hot core) plus the ink. Deep is for
  the shadow side / back face only (`back_shade`, `FRONT_FACING`). No gradients across a shape; the ramp's bands
  are hard (anti-aliased over one texel).
- **Ink weight at the game camera (1080p, `PAL.PX_PER_M` 48 px a metre):** `FX_BEAT.INK_PX` 2 px round any effect
  shape (`PAL.LINE` 0.035 m for runtime-built strips), `INK_PX_BIG` 3 px round breaker-size shapes, blocks and words
  (`PAL.TEXT_INK_PX`). Never an ink hull (a black copy 1.2-2x behind a shape): an outline strip or the sheet's own
  rim. In a sheet: ink px in the sheet = screen px x (sheet px / (quad m x 48)); a 384 px sheet on a 4 m quad needs
  `SHEET_INK_PX` ~4.5 px for 2 px on screen.
- **Halftone:** the comic print, for big shapes only: the outer band of a breaker burst (`gen_spectacle.halftone`),
  see-through fills (ghost axe, ice block facets: `ghost_halftone`, `ice_facet`, ~95 cells a screen height) and the
  impact-frame negative. Never on every-hit effects (it turns to grey speckle at 0.5 m).
- **Glow is drawn, not blended:** a glow is the hot and light bands inside the shape (hot core, light rim) plus the
  burn line on erosion (`burn_hot` 1 for magma and lightning, 0 for ink and ice). Additive blending only for a small hot
  core (< 0.3 m); big additive shapes wash out on the light floor. No soft sprites (`Fx.flare`, soft dots) on comic
  effects.
- **See-through for volumes:** a body that is a volume (ice block, twister, ghost axe) is see-through with a lit rim
  and the far side a band darker, never an opaque slab.

## 3. Shape language per element

| Element (palette row) | Shapes | Never | Current best (the reference) |
|---|---|---|---|
| **Air** (`air`: pale white-mint, slate ink) | Fat calligraphic ribbons tapering both ends into a curled hook; spiral curls; scalloped puff clouds; carried leaves / paper / pebbles to show force; helix bands round a volume, far half a band darker | Jagged edges, zigzags, the lightning's lime, soft glow, closed rings | **The air twister** (`designed_twister.gd`: Updraft Lash, Fault Line gales; `air_ribbon` / `air_swirl` / `air_wisp` / `air_debris`). L_H_H frame 018: three ribbons, curls, debris, foe inside the column |
| **Lightning** (`wind`: electric lime round a white-hot core) | Jagged zigzags with uneven segments and short forks; a fat white-hot core in a lime rim; straight-sided spiky stars at the strike; crawling arcs; the strike held white-hot on one drawing, then a dimmer afterimage | Smooth curves, round blobs, curls (air), thin hairlines with no core, scribble webs | **The lime lightning** (`designed_strike.gd` Grounded's sky strike, `live_current.gd` Galvanize along the tentacles, `bolt_strip`). spread_H_L_L_wait_L_H 022: a thick lime bolt down each tentacle, white core, small forks |
| **Ice** (`water`) | Straight edges only: faceted see-through blocks (one cel tone per face, lit rim, one specular stripe, hull ink), hex floor plates, straight forked floor cracks with a lit edge, cold mist puffs; the break drops whole facets | Spiky crystals, shard sprays, icicle fans, hairline blue rays, curves, drips | **Avalanche** (`avalanche_topple.gd` + the fitted `ice_facet` blocks + `avalanche_spill`): hold frame 000, the see-through tower toppling with the foes inside |
| **Magma** (`earth`) | Fat round-tipped tongues, teardrop globs with the point behind the motion, drips with fat heads, dark crust plates with hot cracks; burns away hot | Straight edges, thin lines, spikes, carrots (tapered straight wedges) | Meteor Fall's landing crust and crown (`designed_fx.meteor`, `magma_crust`): L_L_L_H_H 062 crust plates under the pile |
| **Dark** (`void`: violet body, pink light) | Ink tendrils: tapered curling strokes with a fat base, suckers, splatter dots, negative-space holes, ink pools with curling arms; the tentacle itself (`void_tendril`) | Hard geometry, corners, uniform widths, spike urchins, evenly spaced arms | The tentacle (`void_tendril.gd` + `shaders/tentacle*.gdshader`) and Overwhelm's ink pool (`dark_fx`, designed pool): hold 039 |
| Neutral hit (`hit`), spirit, gold | Lopsided star with concave sides, two long spikes on a diagonal, hollowing from the middle; speed wedges fanned along the blow | Round blobs, symmetrical flowers | `hit_spark` (every hit) |
| Dust / stone (`dust`) | Round lumps, a curl line, flat bottom; rocks as chunky inked stone in dust tones | Spikes, magma colours on rock | `dust_puff` |

Bursts and rays in every element: a radial layout is **clustered**, never an even ring: `vfxlib.cluster_angles(n,
seed, clusters=3)` gives three uneven fans with clear gaps, longest in each fan's middle. An even ring of wedges reads as
a sawblade, a gear or a sea urchin (the round-48 landing rays; see the audit).

## 4. The cohesion checklist

An effect passes when every answer is yes. Judge it from film at the game camera (`string_film.gd -- --dir=<you>`,
contact sheets of HIT frames + every second frame), never from code or a close-up.

1. **Drawn:** a paused frame looks drawn by hand (an authored sheet, a drawn strip on a mesh, or a faceted cel mesh), not
   a tweened primitive (fan, ring, quad, cone, sphere) in flat colour.
2. **Beat:** it has an anticipation drawing, a peak that holds through the hitstop, and a dissolve that breaks the shape
   in an order (erosion with a burn line), within `FX_BEAT` ranges.
3. **On twos:** its drawings change at 12 Hz (`FX_BEAT.STEP_S`); nothing boils every frame.
4. **Palette:** only its element row's tones, one hot area; no hard-coded colours; rock in stone tones.
5. **Ink:** outer edges inked at 2 px (3 px breaker-size) at the game camera; no ink hulls; glow drawn as bands.
6. **Shape language:** uses its element's shapes and none of its "never" (section 3).
7. **Composition:** simple (at most ~5 major shapes), asymmetric; radial layouts clustered with gaps; no even rings,
   spokes, gears, dashed circles or busy shard clusters.
8. **Clearance:** never over the hero; big shapes stand behind the pile (depth tested) or beside it; nothing covers a
   foe's face past the peak.
9. **Life:** within `LIFE_HIT` / `LIFE_BEAT` / `LIFE_STANDING`; standing looks fade on the next string; slow motion does
   not stretch it past the cap.
10. **Cost:** shared material (no per-effect compile), prewarmed, and pooled (`FX_BEAT.stamp`) or capped per frame
    when spawned per hit.

## 5. Audit (2026-11-07, every effect script, from film)

Score = checklist items passed (of 10). Evidence = `fxm_before/<string>/<frame>`. "Not isolated" = the effect is in
the film but under others in every frame, scored from what shows plus its code. Scripts whose look is fully handed to a
designed drawer in designed mode are scored as that drawer.

| Script | What it draws (designed mode) | Evidence | Fails | Score |
|---|---|---|---|---|
| `avalanche_topple.gd` (+ `ice_facet` blocks) | Avalanche's toppling see-through tower, spill | hold 000-008 | 7 (the ice floor spread's hairlines under it are `designed_breaker`'s) | 10 |
| `designed_twister.gd` | the air twister | L_H_H 016-018, line_D_L_H_H_H_L 036 | - | 10 |
| `designed_strike.gd` | Grounded's sky strike | L_H_H 029-030 | - | 10 |
| `live_current.gd` | lightning along the tentacles (Live Wire, Galvanize) | spread_H_L_L_wait_L_H 022, L_H_H 021 | - | 10 |
| `comic_bolt.gd` | every bolt / arc (designed `bolt_strip`) | D_L_H_H 002, D_H_L 026 | - | 10 |
| `designed_elements.gd` | magma fist / fissure / spurts / pool, fireball, ice blocks and spear, frost floor | L_L_L_H_H 042-058, D_L_H_H 034 | 7 (Undertow's pools under four foes at once read as four blobs) | 9 |
| `designed_fx.gd` | hit star, impact streaks, slash, meteor, splat, ice break, bolts, dust, gust | every sheet | 7 (impact streaks launched straight up read as a comb of parallel bars: D_L_H_H 034, spread 013) | 9 |
| `designed_ink.gd` | tentacle skin, ground stamps, hit pops, trail | every sheet | - | 10 |
| `designed_finish.gd` | Awakening, halos, daze, combo burst, echo axe, form pop, Rockslide / Steam Burst / Eruption / Anvil | L_H_L_L_H 013, H_H 000 | 4, 6, 7 (Rockslide's boulder is a flat orange blob under three straight bars in the magma row: rock should be stone; combo burst is an even ring of 14 wedges) | 7 |
| `designed_polish.gd` | dive trails, chip sprays, state tells, Reap's mark, ink tear, drag line, improv payoffs, soul | H_H 011, face_* | - | 10 |
| `designed_breaker.gd` | every breaker landing: burst, rays, floor spread, after-beats, banner | L_H_H 033, H_H 032, hold 052, L_L_L_H_H 062, L_H_L_L_H 026, D_H_L 000, line_D_L_H_H_H_L 004 | 6, 7, 8 (rays: 26 tapered wedges in an even ring on every landing, carrots / sawblade, and in the void row an urchin; ice floor cracks: hairline blue rays round a flat blue splat; storm floor arcs: a dark green scribble web). After fx-modern (rays clustered, none on dark): 6 (the floor spreads) | 5 -> 8 |
| `breaker_quake.gd` | the war cry (12 polygon strokes in an even ring + a hoop) and the crater's vent stars | H_H 020-026 (violet wedges round him in every hang), L_L_L_H_H 046-054 | 1, 2, 6, 7, 10. After fx-modern (drawn `war_cry` sheet, pooled stamp): - | 4 -> 10 |
| `comic_backdraft.gd` | Backdraft's blast (8 polygon wind strokes in a ring) and haul ribbon | L_L_H_D_H_H_L 039-040 (a cluster of sharp pale-blue spikes over the spear) | 1, 2, 6, 7. After fx-modern (blast = `DESIGNED.wind_burst`): - | 5 -> 9 |
| `comic_hail.gd` | Hailstorm's lift: polygon helix bands + chips | line_D_L_H_H_H_L 035-038 (not isolated: under the twister) | 1, 2 | 7 |
| `comic_arc.gd` | Storm Pitch's forks riding the thrown foe | D_H_L 024-028 | 1, 2 (flat polygon zigzags; the jumps are designed bolts) | 7 |
| `comic_anvil.gd`, `comic_steam.gd` (`comic_erupt.gd`, `comic_boulder.gd`: deleted 2026-11-08) | crossover drawers handed to `designed_finish` | L_L_H_D_H_H_L 052, line_D_L_H_H_H_L 056 | as designed_finish | 7 |
| `comic_fault.gd` | Fault Line ground and gales (designed twister + bolts) | L_H_L_L_H 018-022 | - | 9 |
| `comic_freeze_over.gd`, `comic_melt.gd`, `comic_rip.gd`, `comic_impale.gd` | designed in fx-polygons | L_L_H_D_H_H_L 034-035, line 039 | 7 (Impale's floor plates + frost shell + hit stars stack busy) | 8 |
| `comic_improv.gd`, `comic_state_tell.gd` | payoffs and state tells (designed_polish sheets) | face_L_H_L_L_D_L_H, face_L_H_D_L_H | - | 9 |
| `comic_pop.gd` | the old flat drawer; designed mode still uses its radial `strokes` (war cry, `Fx.combo_pop` fallbacks) and vent stars | H_H 024 | 1, 7 | 5 |
| `comic_comet.gd` | dive trails (designed_polish) + a landing star | L_H_H 024 | - | 9 |
| `comic_crack.gd` | `Fx.scorch` floor cracks (crater, lava well) | L_L_L_H_H 050 (not isolated) | 1 | 8 |
| `comic_dust.gd`, `comic_drag_mark.gd` | locomotion puffs, drag line (designed sheets) | every sheet | - | 10 |
| `comic_fist.gd`, `comic_gale.gd` (`comic_geyser.gd`: deleted 2026-11-08) | handed to designed_elements / twister | L_L_L_H_H 042 | - | 10 |
| `comic_axe_aura.gd` | off (no subject) | - | - | n/a |
| `dark_fx.gd` | dark element: pools, vortex, claw strokes, Reap crescent, spouts | H_H 011, hold 039 | 7 (Overwhelm's pool + reel + vortex overlap) | 9 |
| `frost_spear.gd`, `frost_shell.gd`, `frost_wall.gd` | the spear, shells, wall (faceted meshes, frost marks) | L_L_H_D_H_H_L 024-027 | - | 10 |
| `heretic_form_fx.gd` | weapon-change pop (designed_finish) | D_L_H_H 024 | - | 10 |
| `spirit_echo.gd`, `claw_lash.gd` | the echo's drawn axe, Dash Stab's lash | L_H_H 010 | - | 10 |
| `mid_beats.gd` | Singularity reel, Reap hook, spear spread, fuse, boulder drop, globs | H_H 016-020, L_H_L_L_H 013 | 4, 6 (the boulder: see designed_finish) | 8 |
| `abyss_rise.gd`, `collapse_spit.gd`, `eruption_hurl.gd`, `tentacle_haul.gd` | the cool-pass endings | hold 052-056, H_H 030-034, line 056 | (their landings carry designed_breaker's rays) | 9 |
| `lava_leash.gd`, `counter_fx.gd`, `breaker_alt_fx.gd`, `slapshot_fx.gd` | Lava Leash seams, parry, Meteor Shower / Pinwheel / Tempest, Slapshot | not in the default kit's film (spar / alt endings) | not judged | - |
| `awaken_flourish.gd` | Awakening (designed_finish) | H_H 000 (gold flame crown) | - | 10 |
| `breaker_cue.gd` | the closing timing ring (brush stamp) | L_H_H 021, hold 042 | 7 (a closed dashed ring: allowed as a UI cue, kept quiet) | 9 |
| `floor_bind.gd` | gameplay only (tentacles via void_tendril) | - | - | n/a |

### The conversion queue (worst first)

Ordered by how often each is on screen times how badly it fails. A sheet preview (`gen_spectacle.py slam_ink
slam_star --preview=<dir>`) cleared the landing bursts: `slam_ink` is a fair ink splat and `slam_star` a lopsided star;
the "urchin" on Abyss was the rays in the void row. So the bursts left the queue and the list below is the one Part 2
worked from.

1. **Breaker landing rays** (`designed_breaker` `slam_rays`): every breaker ending, an even ring of 26 tapered
   carrots in the element's light tone. **Converted (fx-modern):** three uneven fans of 13 lines (`cluster_angles`), the
   longest and fattest in each fan's middle; none on dark landings (their splat has arms).
2. **War cry** (`breaker_quake.war_cry`): every breaker hang, 12 polygon wedges in an even ring round the hero.
   **Converted:** the drawn `war_cry` sheet (three fans of strokes, fat round inner ends round a clear middle, hot inner
   third at the peak), `designed_breaker.war_cry()` through `FX_BEAT.stamp` (pooled, real time so the hang's slow
   motion can't hold it), the hoop kept as the ink stamp.
3. **Backdraft's blast** (`comic_backdraft.blast`): 8 ink polygon wedges in an even ring over the spear's break.
   **Converted:** the air language's `DESIGNED.wind_burst` (floor swirl and gusts over the heads). The refilm showed the
   spiky pale-blue cluster on that frame was not the blast: it is the water-row hit pops (`designed_ink.pop`, `pop_ice`)
   and impact streaks on four skewered foes in one frame, one set per foe. That stack is now queue item 9.
4. **Rockslide's boulder** (`rock_boulder` in the magma row, `mid_beats.boulder_drop`): a flat orange blob under three
   straight bars. -> a stone boulder in the dust row with magma only in its cracks, drawn speed lines tapered.
5. **Ice floor spread** (`floor_cracks` in the water row on ice landings: Black Ice, Flash Freeze, Avalanche): hairline
   blue rays round a flat blue splat. -> hex plates and a few straight lit cracks (the `frost_mark` language).
6. **Storm floor spread** (`floor_arcs`): a dark green scribble web. -> fewer, fatter zigzags with a white core.
7. **The last polygon riders** (`comic_hail.ride`, `comic_arc.ride`): flat polygons. -> designed strips (air ribbon
   helix, `bolt_strip` forks).
8. **Even rings left elsewhere:** the combo burst (`combo_burst`, 14 wedges on every named combo) and `comic_pop`'s
   radial `strokes` still used by `Fx.combo_pop` fallbacks. -> `cluster_angles`.

9. **Crowd ice hits** (Backdraft / Impale on four skewered foes, L_L_H_D_H_H_L 039 before, fxm_bd 029 after): a pop
   and a streak fan per foe in the water row stack into a cluster of crystals (breaks the "no spiky ice" verdict). ->
   one pop at the batch's middle, the rest mist; no water streaks on a crowd hit.

Also noted, not queued: impact streaks thrown straight up read as a comb (`designed_fx.streaks`: a vertical blow could
use a gust or skip, as ice already does); the combo burst's even ring (`combo_burst`) wants `cluster_angles` too.

## 6. Decisions made in this lane (Zak can overturn)

- The rays drop from the dark family: its ink splat already has arms, and rays plus arms made the urchin.
- The war cry runs on real time (`WAR_CRY_TIMES`, 0.44 s): it fires as the hang's slow motion starts, and on game time
  it stood for seconds.
- Rock is stone (dust row), not magma; magma is only what glows.
- The breaker cue's closed ring stays: it is a timing cue (UI), quiet by design (round 45), not an effect.
- `FX_BEAT.stamp` pools by sheet and parent (12 spare nodes a sheet); standing effects are not pooled.

## 7. Gotchas

- **Effects on a breaker's landing frame are hidden by the impact frame** (two inked flash frames). Delay what must
  be seen (Short Circuit's arcs: `create_timer` 0.12 s) past it; a kill under a breaker's impact frame is invisible too.
- **An anticipation shorter than ~0.09 s never lands on a 12 fps film frame**, so it is never seen: hold it longer or
  show it with motion that lasts (debris dragging in).
- **An effect's tween on scaled time outlives its string.** Hitstop and breaker slow motion stretch any
  `create_tween()` on a node (the combo callout hung 1-1.5 s into the next string): `set_ignore_time_scale(true)`
  for UI, or cut it when the next string starts (`standing_fx.watch` sees a string's first move as "no chain and not
  attacking last frame, attacking now").
- **Ink drawn into a strip texture must be sized for the screen, not the sheet:** a strip seen at ~48 px/m needs ~13 px
  of ink in the sheet (`gen_cohesion.INK_PX`) or it vanishes; ink that must hold at any width goes in the shader, in
  metres. A hoop of many dashes reads as a gizmo; 3-5 broken brush arcs read as a drawn stamp.
- **A "white-hot" shift that lifts every tone burns the shape flat white:** lift one band and a bit (`heat` 0.35) so a
  saturated rim stays. The soft VFX textures (`Fx.TEX` dot / scorch / star) fill under half their quad: a decal sized
  "radius" reads half that; a cartoony hard shape wants a flat mesh.
- **Floor stamps under a foe hide behind it from the high camera:** test them by a foe, not on open floor. Density is
  judged on film (`python tests/fx_coverage.py --per-string`), and every HIT frame over 0.2 so far was a breaker
  landing with the Awakening column: compare with and without it.
- **A smear built from the last pose draws a slab when the pose jumps** (coil to lash): guard on tip speed, a still
  root and a same-direction middle (`void_tendril._lashing`). Route a new look by shape (a bolt falling > 3 m is a sky
  strike) inside your own function, not by editing every caller; register a lane's sheets through
  `DESIGNED.extra_sheets`; per-frame caps key on `Engine.get_process_frames()`.
- **A gameplay check that counts an old drawer's nodes fails when the designed look replaces it** (fx_sleek_check's
  geyser `.width`): put the designed node in the group and give it the value as a meta
  (`get_meta("width", get("width"))`), so the check still guards the size.
- `billboard_mode` drops a node's scale unless `billboard_keep_scale = true`; a hand-wound fan can be back-facing
  (set `cull_mode = CULL_DISABLED`); `_ready` runs inside `add_child`, before the caller sets `global_position`, so
  anything spawned at "its own position" there lands at the origin (`call_deferred` or position first).
- A sheet redraw previews without touching the worktree: every `tools/vfx_gen/gen_*.py` takes `--out=<dir> --preview=<dir>`;
  a regenerated sheet is not in the game until `godot --headless --import --path .` runs.
