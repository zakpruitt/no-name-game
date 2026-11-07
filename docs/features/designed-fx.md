# Designed effects (round 43 b pilot)

Zak, after round 42: "the effects are not really effects, they're just polygons you're putting together. I'd like
them to actually be designs, still stylistic." Every effect before this round was assembled at runtime from
primitive shapes (fans, rings, quads, cones) in flat or gradient vertex colours. This round builds the pipeline a
stylised action game uses instead (authored flipbooks with a hard peak frame and a dissolve, strip textures on
shaped meshes, shader erosion, a palette ramp per element) and proves it on a pilot set. The rest of the game's
effects stay on their old code paths until Zak has judged the look; the conversion list at the end orders them.

## What it does

- **Hit spark** (every hit on a foe, `Fx.hit_spark`): a lopsided inked impact star, its two long spikes on a
  diagonal. Frame 0 is a pinched glint (anticipation), frame 1 the peak with a hot core, frame 2 the core punches
  out to an inked ring, then the hole eats the star from the middle until only its spikes are left, thinning out.
- **Impact streaks** (the directional half, `Fx.impact`): a fan of manga speed wedges thrown along the knockback,
  turned on screen to the blow's direction.
- **Slash** (every melee swing, `Fx.swoosh`): the same arc mesh as before, but the colour is an authored brush
  stroke (pointed hooked head, banded blade light, dry-brush bristle tail) that slides along the arc; its four
  drawn variants boil on twos; erosion takes the tail first.
- **Meteor Fall's landing** (`void_element._meteor_landing`): a crown of magma tongues thrown up behind the pile
  (depth tested, so the foes stay in front), globs flung off the tips that turn to falling teardrops, a crust
  closing over it; a lumpy lava wave rolling out on the floor; three small crowns round the rim; a cracked crust
  left on the floor that cools (hot cracks, dark plates) and breaks up plate by plate. It replaces the rim
  geysers, the per-foe spikes and shards and the scorch.
- **Molten Palm's wall splat** (`thrown_foe._burst` on a wall with the palm's earth): a fat splat on the wall with
  splash arms, drips that run down with round heads, crust cracks spreading as it cools.
- **Ice shatter** (a frozen foe shattered, `enemy._thaw`, and the ice cube bursting, `thrown_foe._burst` with
  water): the block cracks (frame 0), then a hot star and two-tone faceted shards with a specular stripe each fly
  out and turn, with four-point glints. Straight edges only.
- **Lightning** (`comic_bolt.spawn`: Grounded's strikes out of the sky and every arc between foes): an authored
  branching bolt strip on a camera-facing ribbon, its zigzag repeated along long bolts so it keeps its drawn
  proportions, re-jagged on twos; a strike lands in a spiky storm burst with zigzag arcs crawling out.
- **Dust puff** (`Fx.dust` calls of 8 motes or more: landings, slams, skids): a lumpy cartoon cloud with a curl
  line, lit top and shaded bottom, swelling, then holes eat it.
- **Air twister** (fx-air lane; every `comic_gale.spawn`: Updraft Lash's whirlwind, Fault Line's gales, Hailstorm's
  miss; `scripts/designed_twister.gd`): a volume, not a spring. A floor swirl (`air_swirl`: frame 0 pulls in, three
  hooked spiral arms with grit, breaking into curls), three fat calligraphic wind ribbons on depth-tested helix bands
  that widen upward (`air_ribbon` on `designed_ribbon_depth`: the lifted foes sit inside the column, the far half of
  each band one cel band darker), each turning on twos with its stroke running head first; cloud wisps flung off the
  top (`air_wisp`); leaves, paper scraps and pebbles spiralling up through it (`air_debris`, dust palette). The peak
  overshoots, the dissolve swaps the ribbons to their broken-into-curls row and erodes them tail first.
- **Air gust** (`DESIGNED.gust`; a storm blow's directional half instead of the lime impact wedges, at most two a
  beat): a puff bursting where the wind starts and two curled ribbons streaming along the blow, turned to it on
  screen. Storm swings (`Fx.swoosh` in the storm element) draw their stroke in the air row.
- **Lightning palette** (fx-air): the storm row is electric lime round a white-hot core (bolt_strip and storm_burst
  redrawn with a saturated rim, a light band and a fat hot core). Air and lightning no longer share one green. For
  other lanes: `DESIGNED.bolt_path(parent, points, width)` runs lightning along a polyline (one bolt a leg) and
  `DESIGNED.zap(parent, at, size)` is a small electric pop on a foe.
- **Sky strike** (fx-air round 2; `scripts/designed_strike.gd`): `DESIGNED.bolt` hands any bolt falling more than
  `STRIKE_DROP` (3 m) to it, so Grounded's strikes (`elements._strike_bolt`) and Cataclysm's (`comic_fault`) share it.
  One authored moment in beats: a thin dim leader on a kinked path (`LEADER_S` real s); the main bolt `MAIN_W` x
  fatter, burned white-hot (the ribbon's `heat` uniform) and frozen on one drawing for `HOLD_GAME` game s (a hitstop
  holds it) and at least `HOLD_REAL` real s, then cooling and boiling on twos as it erodes; a forked afterimage a band
  dimmer, off to one side, eroding; a jagged scorched star on the floor (`strike_scorch`, white-hot cooling to dark,
  breaking up, real time); small arcs crawling on each struck foe (`DESIGNED.crawl`, `arc_crawl`, riding the foe).
- **Crawling arcs** (`DESIGNED.crawl(parent, foe, size)`): a few frames of short zigzags crawling round a foe's body,
  following it as it flies; once per foe at a time. The sky strike's struck foes and the tentacle's zapped ones
  (`live_current._pop`).
- **Tentacle lightning** (`live_current.gd`, combo-lightning's; look only): the conducted strip is `TRAIL_W` 0.28 and
  flashes `TRAIL_HEAT` hotter every other step, so the bolt on the tentacle crackles white-hot.

**Toggle:** on by default. `--fx=classic` (after `--`, e.g. `godot --path . -- --fx=classic`, or
`tests/string_film.gd -- --fx=classic --dir=x`) plays the old polygon effects from the same build, for before /
after films. In code, `DESIGNED.enabled = false`.

## Files

| File | Role |
|---|---|
| `tools/vfx_gen/vfxlib.py` | The drawing kit: curves (`catmull`, `wobble_ring`, `star`, `stroke`, `jag_path`), `Frame` (paint at 4x, `fill(mask, tone, ink=px)` inks each shape over what is beneath it), `erode_field` (edge / centre / tail dissolve orders), `pack`, `preview` |
| `tools/vfx_gen/air_sheets.py` | The air family (`air_ribbon`, `air_swirl`, `air_wisp`, `air_gust`, `air_debris`) and its shapes (`curl` hooks, `ribbon` calligraphic strokes with a lit and a shadow edge, scalloped `puff` clouds); `gen_designed.SHEETS` imports them |
| `tools/vfx_gen/storm_sheets.py` | Lightning payoffs: `strike_scorch` (floor) and `arc_crawl` (sprite), played through the storm row |
| `scripts/designed_strike.gd` | The sky strike node (leader, held white-hot main bolt, forked afterimage, scorch, crawls) |
| `scripts/designed_twister.gd` | The air twister node (bands, swirl, wisps, debris, its timeline); `comic_gale.spawn` hands over to it when designed effects are on |
| `shaders/designed_ribbon_depth.gdshader` | The ribbon shader with the depth test on, and the back face one cel band darker (`back_shade`): bands wrapped round a volume |
| `tools/vfx_gen/gen_designed.py` | One function per sheet (`hit_spark`, `impact_streaks`, `slash_strip`, `magma_burst`, `magma_wave`, `magma_crust`, `magma_splat`, `ice_shatter`, `bolt_strip`, `storm_burst`, `dust_puff`) and `SHEETS` (frame px, columns, count, preview palette, erode mode) |
| `assets/vfx/designed/*.png` | The sheets (lossless, mipmapped, `detect_3d` off in their `.import`: VRAM compression would smear the packed channels) |
| `shaders/designed_fx.gdshaderinc` | Shared: the palette ramp (`ramp()`: five hard cel bands) and erosion with a burn line (`designed()`) |
| `shaders/designed_sprite.gdshader` | Camera-facing flipbook quad, no depth test (over the pile, like the flat comic effects), screen-plane `spin` / `flip`, `anchor` pivot for sheets drawn on a ground line |
| `shaders/designed_sprite_depth.gdshader` | The same with the depth test on (the meteor crown: foes in front of it stay in front) |
| `shaders/designed_ground.gdshader` | Flipbook flat on the floor, depth tested (lava wave, crust) |
| `shaders/designed_ribbon.gdshader` | A strip texture along a shaped mesh: `head` / `span` slide a stroke along it (slash), `tiles` / `scroll` repeat it (bolts); rows are boil frames |
| `scripts/designed_fx.gd` | `DESIGNED.on()`, the palette texture, one cached `ShaderMaterial` per sheet, the timeline node (per-frame holds, erosion share, real-time anticipation), and the effects: `hit`, `streaks`, `slash`, `meteor`, `wall_splat`, `ice_shatter`, `bolt`, `dust`, `prewarm` |
| Call sites | `fx.gd` (`hit_spark`, `_flush_crowd_stars`, `impact`, `swoosh`, `dust`), `void_element._meteor_landing`, `thrown_foe._burst`, `enemy._thaw`, `comic_bolt.spawn`, `elements.prewarm`. Each branches on `DESIGNED.on()` and keeps the old path |

## How it works

### The sheet format
A sheet texel is **(tone, erode order, boil, cover)**, not a colour:

- **R tone**: 0 ink, 0.25 deep, 0.5 body, 0.75 light, 1.0 hot. The shader maps it through the element's five tones
  (`fx_palette.ELEMENTS`, one row each in `DESIGNED.palette()`), with hard band edges anti-aliased over one texel.
  One drawing therefore serves every element (the hit star is hot orange on a plain hit, green on storm, gold
  Awakened), and the palette stays the one fx_palette already defines.
- **G erode order**: the order the shape dissolves in (low first). `erode_field()` writes it from the frame's own
  silhouette: `edge` eats from the outline in clumps, `center` hollows the middle first (impact stars), `tail` runs
  along the strip (strokes go tail first); `magma_crust` writes its own (plate by plate, the cracks last).
- **B boil**: noise that wobbles the erosion edge a little.
- **A cover**: the silhouette.

### The timeline
`DESIGNED.spawn()` makes one node per effect with `times` (seconds per frame) and `erode_span` (shares of its life
when the shader's `erode` runs 0 to 1). The shape of every timeline: frame 0 is the anticipation (one 30 Hz frame),
frame 1 is the peak and holds longest, the rest run on twos (1/12 s); erosion takes the last 40-55% of the life,
so the stepped frames dissolve smoothly between steps with an ink (or, for magma, hot) burn line. `real_until = 1`
plays the anticipation in real time, so the peak lands on the hit's first frame and holds through the hitstop
(the rest runs on game time and stretches with it). Lingering floor effects (`magma_crust`) are `real_time` and
`standing` (they fade when the next string's first hit lands, `standing_fx`).

### Materials and cost
One `ShaderMaterial` per sheet, shared by every instance; per-instance values (frame, erode, alpha, palette row,
spin, flip, head, span, tiles, scroll) are `instance uniform`s. Nothing compiles per effect; `elements.prewarm`
draws each material once at real size (`DESIGNED.prewarm`). A sprite is one quad; the slash and bolt build one
small strip mesh each (as the old swoosh and bolt did). Textures load through `preload` in `SHEETS`, so they are
resident from the first frame.

## Shape language per element

| Element | Shapes | Never |
|---|---|---|
| Neutral hit | Lopsided star with concave sides, two long spikes on a diagonal; hollows from the middle; speed wedges fanned along the blow | Round blobs, symmetrical flowers |
| Magma (earth) | Thick blobby tongues with round tips, teardrop globs (pointed tail behind the motion), drips with fat heads, dark crust plates with hot cracks; burns away hot | Straight edges, thin lines |
| Ice (water) | Hexagonal block, faceted shards (lit facet, shadow facet, one specular stripe), four-point glints, straight cracks | Curves, drips, soft edges |
| Air (the storm element's wind: gales, gusts, slashes; `air` palette row, `fx_palette.AIR`) | Fat calligraphic ribbons tapering at both ends into a curled hook (ukiyo-e / Wind Waker wind), spiral curls, puffy scalloped cloud wisps, bent speed lines, things carried in it (leaves, paper scraps, pebbles) to show direction and force. Pale white-mint, one cool shadow tone, slate ink | Jagged edges, zigzags, the lightning's lime, soft glow |
| Lightning (the storm element's bolts and storm hit sparks; `wind` palette row, electric lime) | Jagged branching zigzags with uneven segments and forks, spiky stars with straight sides, crawling arcs; a saturated rim round a fat white-hot core | Smooth curves, round blobs, curls (those are air) |
| Dust | Round lumps, a curl line, flat bottom | Spikes |
| Dark (void) | Ink tendrils and smears: tapered curling strokes, splatter dots, negative-space holes (`pop_dark`); the tentacle: a smooth tapered spine, a fat base, suckers, a claw tip, a paper rim like the hero's | Hard geometry, corners, uniform widths |
| Ground stamps | A few broken brush arcs a ring, fat at the front and dragged thin behind, a hot streak, splatter flung outward; erodes from the outline | Thin even hoops, dashed circles of many equal pieces, rings nested on one spot |

## Authoring a new effect

1. **Design it on paper first**: name its anticipation, peak and dissolve, and its element's shapes (table above).
   Size it against the game camera (about 48 px a metre at 1080p; a foe is ~1.3 m tall). Effects sit beside the
   hit, never cover the hero or the foe's face for long.
2. **Draw it**: add `def my_fx(i, n, size)` to `gen_designed.py` returning `Frame.finish()` for frame `i` of `n`, and
   a `SHEETS` row. Paint back to front with `f.poly(points, TONE, ink=px)` / `f.fill(mask, ...)`; cut holes with
   `f.cut()`. Every frame should be a good drawing when paused: change the silhouette between frames (not just the
   size), keep one hot area, ink every outer edge.
3. **Look at the sheet**: `python tools/vfx_gen/gen_designed.py my_fx --preview=<dir>` writes the sheet and
   `<dir>/my_fx_preview.png` (through the palette at erode 0 / 0.4 / 0.7) in a few seconds.
4. **Import**: `godot --headless --import --path .`, then in the new `.png.import` set `mipmaps/generate=true` and
   `detect_3d/compress_to=0`, delete its `.godot/imported/my_fx.png-*` and import again.
5. **Play it**: add the sheet to `designed_fx.SHEETS` (grid, frames, kind, anchor, burn), a timeline const and a
   static function; call it from the effect's call site behind `if DESIGNED.on():`, keeping the old path.
6. **Film it** windowed from the game camera (see Testing), read the frames, fix the worst thing, repeat (at least
   three rounds). Check coverage with `tests/fx_coverage.py` and that `fx_free_check` passes.

## Tuning

- Sizes (`designed_fx.gd`): `HIT_SIZE` (the quad for `Fx.HIT_STAR`), `STREAK_SIZE` / `STREAK_BACK`, `SLASH_SPAN` /
  `SLASH_INNER` / `SLASH_INNER_LINES`, `METEOR_BURST` / `METEOR_BACK` / `METEOR_WAVE` / `METEOR_CRUST` /
  `METEOR_SPLASH`, `SPLAT_SIZE`, `ICE_SIZE`, `STRIKE_BURST`, `BOLT_TILE`, `DUST_SIZE`, `GROUND_LIFT`.
- Timing: the `*_TIMES` arrays (seconds per frame) and each call's erode span.
- `Fx.DUST_MIN`: the smallest `Fx.dust` call that draws a puff.
- Shapes: the sheet functions; rerun the generator.
- Air twister (`designed_twister.gd`): `HEIGHT_SEEN` (of the asked height), `BANDS`, `BAND_W`, `BAND_Y`, `BAND_RISE`,
  `SWEEP`, `RADIUS_FOOT` / `RADIUS_FLARE` (the profile), `FLARE_OUT` (how far a band leans out: the high camera sees
  more of a leaning band), `TURN`, `PEAK_SCALE`, `ANTIC` / `ANTIC_SCALE`, `DISSOLVE`, `SWIRL_SIZE`, `WISPS` /
  `WISP_SIZE` / `WISP_SPEED`, `DEBRIS` / `DEBRIS_SIZE` / `DEBRIS_SPIN`. Gust: `GUST_SIZE`, `GUST_BACK`, `GUST_MAX` a beat.
  Round 2: `ANTIC` 0.12 (0.05 never reached a 12 fps film frame), `DRAG` / `DRAG_FROM` (the debris drags in along the
  floor before it lifts: the anticipation), `MIN_HEIGHT` / `MIN_RADIUS` (Fault Line's small gales grow to read).
  Storm Pitch's `wind_burst`: `BURST_SWIRL`, `BURST_UP` / `BURST_GUST` (gusts over the pile's heads, the first
  trailing the throw). Backdraft's haul drops `HAUL_GUST` gusts behind the foe (`comic_backdraft.gd`).
- Sky strike (`designed_strike.gd`): `LEADER_S` / `LEADER_W` / `LEADER_HEAT` / `LEADER_SWAY`, `MAIN_W`, `HOLD_GAME` /
  `HOLD_REAL` / `HOLD_HEAT` (0.5 burned it all white; 0.35 keeps a thin lime rim), `MAIN_FADE`, `AFTER_LIFE` /
  `AFTER_HEAT` / `AFTER_SHIFT`, `FORKS` / `FORK_LEN`, `SCORCH_SIZE` (2.0 hid under the struck foe) / `SCORCH_TIMES`,
  `CRAWL_REACH`; `designed_fx`: `STRIKE_DROP`, `CRAWL_SIZE` / `CRAWL_UP` / `CRAWL_TIMES`. The ribbon shader's `heat`
  shifts every coloured tone (never the ink) up or down the ramp: > 0 white-hot, < 0 an afterimage.

## Testing

- `tests/fx_free_check.gd` (in `agent.sh check`): the effects free cleanly mid-hit.
- Film: `tests/string_film.gd -- --dir=<name>` (designed) and `-- --fx=classic --dir=<name>` (before), windowed;
  `--from=11 --to=11 --layout=wall` puts the dummies by the back wall for Molten Palm's splat and Meteor Fall.
  Coverage: `python tests/fx_coverage.py <film> --per-string --max=0.40`.
- Close look at one effect: a scratch SceneTree that loads `main.tscn`, holds a long hitstop stop at 0.06
  (`game._stops.append([now + 120000, 0, 0.06])`, since `Game` resets `Engine.time_scale` every frame), sets
  `DESIGNED.game_time_only = true` (readbacks stall ~100 ms each, which real-time steps would skip through), spawns
  the effect by a dummy and grabs a frame every 33 ms of game time.

## Gotchas

- After regenerating a sheet run `godot --headless --import --path .`: a film run does not reimport, and plays the old
  texture.
- A vertical band (a ring round a column) is foreshortened to ~60% from the 53-degree camera and reads thin: lean its
  top edge out (`FLARE_OUT`) rather than only making it taller.
- Floor quads must sit at `GROUND_LIFT` (0.065 m): the floor stones reach 0.05 m, and at 0.03 m only the grooves
  between stones showed the effect.
- A node with no `times` (the ribbons, driven by their own tween) must not run the timeline, or it frees itself
  on its first frame (`_life` 0).
- The game's camera pulls out in a fight: an effect that reads at the scratch shot's close framing is about half
  that size in `string_film`. Judge sizes in the film.
- `Game` sets `Engine.time_scale` every frame from its stops: setting it from a test does nothing.
- A floor stamp under a foe hides behind its body from the high camera: size it so the tips reach well past the foe
  (the strike scorch needed 3.4 m for ~1 m tips).
- An array literal indexed inline (`[0.0, 2.2][k]`) has no inferred type: write `var a: float = ...`, or the
  whole `designed_fx` chain fails to compile and every effect after it errors.
- A billboard drawn without the depth test covers the pile; a big one (the meteor crown) uses the depth-tested
  variant, stood behind the pile.

## Conversion list (remaining polygon effects, most seen first)

Converted in the pilot: hit star, impact strokes, swing swoosh, Meteor Fall landing, Molten Palm wall splat, ice
shatter / cube burst, every lightning bolt and arc (Grounded, Live Wire, Storm Pitch's zaps, Cataclysm's strikes,
since they all draw through `comic_bolt.spawn`), the `Fx.dust` puff. fx-air lane: every `comic_gale` (Updraft Lash's
whirlwind, Fault Line's gales) as the designed twister, storm blows' streaks as air gusts, storm swings in the air
row, Storm Pitch's landing in wind.

Converted in round 46 (fx-elements): Molten Palm's fist and fissure, the lava spurts and geysers (`rim_geyser` too),
Undertow's lava pool, Meteor Fall's fireball in flight, the ice spikes (so nova and Worldbreaker's ice), the frost
spear's floor and Deep Freeze's burst, the ice block and frozen foe's ice and the frost spear as faceted meshes. See
"Round 46: ice and magma" below.

Converted in round 46 (fx-finish): the Awakening (`awaken_flourish`, which `Fx.awaken_burst` calls in comic style),
chain halos, daze stars, `Fx.combo_pop` strokes, the spirit echo's ghost axe, the weapon-change burst, the axe aura
(off), `comic_boulder`, `comic_steam`, `comic_erupt`, `comic_anvil`. See "Round 46: the finish" below.

Converted in round 44 (fx-cohesion): the tentacle (every reach, grab, coil, lash), every floor hoop (`Fx.ring`,
`thin_hoop`, `hoop_run`, the comic_pop ring; three deleted), the breaker cue's rings, the element chips (one pop a
hit in the element's shape, crowd caps), the axe ribbon.

Converted in fx-polygons (round 47 d): the breaker dive trails, `Fx.burst` chips (so `hero_fx.rank_up`), `comic_fault`'s ground, `comic_freeze_over`'s pool and break, `comic_melt`, `comic_rip`, the `comic_improv` payoffs, the state tells, Reap's mark, `Fx.soul`, the last-kill flare, `comic_drag_mark`, the claw lash's turn flare. See "fx-polygons" below; the numbered list is the older one, kept for history.

1. Every hit: `Fx.chain_spark` halos past 10 / 20 / 35 hits (capped to one a frame, still polygons), the foe's
   `daze` stars. (The element chips are done.)
2. Every swing: (the axe ribbon is done) the axe's element aura (`comic_axe_aura.gd`), the floor drag line (`comic_drag_mark.gd`), the spirit
   echo's ghost axes (`spirit_echo.gd`), Dash Stab's claw lash (`claw_lash.gd`).
3. Every dash and step: `comic_dust.gd` (run start, skid, dodge puffs: reuse `dust_puff`), `Fx.dash_streak`, the
   comic afterimage, the perfect-dodge flare.
4. Every named combo: `Fx.combo_pop` strokes, the weapon-change burst (`heretic_form_fx.gd`), `callout_cap.gd`.
5. Element moves (every right click): storm's Updraft Lash pillar / gale (`comic_gale.gd`, `elements.pillar`),
   the dark element's splats and ink tendrils (`dark_fx.gd`), the floor bind (`floor_bind.gd`). (Ice and magma are
   done: round 46.)
6. Breakers: the dive trail (`comic_comet.gd`, every element), floor cracks (`comic_crack.gd`, also `Fx.scorch` in comic style), the war cry and crater
   (`breaker_quake.gd`), `comic_hail`, `comic_rip`, `comic_anvil`, `comic_impale`,
   `comic_erupt`.
7. Crossovers: `comic_boulder`, `comic_fault` (its strikes are already designed bolts), `comic_steam`,
   `comic_freeze_over`, `comic_melt`, `comic_backdraft`, `comic_arc` (its jumps are already designed bolts).
8. Element-matrix payoffs (`comic_improv.gd`) and the state tells on foes (`comic_state_tell.gd`).
9. Kills: `Fx.death` (flash, shock ring, shards), `Fx.soul`, `hero_fx.last_kill` rings.
10. Awakening: `Fx.awaken_burst` (beam, shockwaves, motes), `awaken_flourish.gd`, `hero_fx.rank_up`.

## Round 44: cohesion (fx-cohesion lane)

Zak, round 44: "really focus on a refinement of the art style and effects. They look weird to me." The pilot left
the screen in two styles: authored flipbooks next to runtime polygon assemblies. This round converts the most-seen
polygon effects, judged by "does a paused frame look drawn?" and "does the whole frame look like one artist drew
it?". Sheets: `tools/vfx_gen/gen_cohesion.py` (its own module, so the storm lane and this one add sheets side by
side); runtime: `scripts/designed_ink.gd` (registers its sprite sheets in `DESIGNED.extra_sheets`).

### The tentacle (`void_tendril.gd`)

The hero's signature weapon, so the best-drawn thing on screen. It was three flat vertex-colour ribbons (ink,
violet, hot line) with a uniform taper and a polygon coil that started at the foe's centre, so the reach met the
coil in a corner and two stacked turns read as pipes from above.

- **Spine:** Catmull-Rom through the wave and the coil (`spine_designed`, `SMOOTH` samples a segment). The reach
  aims at the point where its line touches the coil's circle on a tangent, so the coil carries on from it with no
  corner; the coil spirals down and in (`WRAP_TURNS` 1.35, `COIL_OUT` past the foe's radius so its front shows over
  the body) and ends in the claw, flicked out past it (`CLAW_HOOK`).
- **Width:** a fat base out of the hand (`ROOT_W`, a `BASE_BULB` swell), tapering to the claw's point; a living
  swell runs along it on twos (`SWELL`, `SWELL_WAVE`).
- **Skin:** `shaders/tentacle.gdshader` lays `tentacle_skin` (back shadow with wrinkle ticks, a light belly with a
  row of suckers, a hot highlight dash; three boils) along the ribbon, advancing by arc length over the local width
  so the pattern keeps its proportions and gets denser to the tip. The ink line is the shader's, a fixed 0.06 m
  (brushed by a slow wobble), with the hero's own paper rim outside it, so the tentacle and the hero read as one
  drawing. The last `claw_m` before the end is the light claw tip with an ink seam.
- **Smear:** a fast lash (`_lashing`: the tip moved more than `SMEAR_MIN` but less than `SMEAR_MAX` in a frame, the
  root stayed put, the middle went the same way, the length held) draws `tentacle_smear` between the last pose and
  this one for `SMEAR_HOLD`: a solid front band and three echo strokes behind it (the classic multiple-image smear).
  A jump to a new pose (from a coil to a lash) never smears: that drew a blocky sheet across the room.
- **For other lanes:** `points()` (the last drawn world polyline, root to tip), `tip()`, `electrify(amount, color)`
  (washes the body, not the ink). Pinning cords (`line`) stay one thin inked line.

### Ground stamps (the floor hoops)

Thin flat circles on the floor (`Fx.ring`, `thin_hoop`, `dark_fx.hoop_run`, every `comic_pop` ring, the breaker
cue) read as debug gizmos, often three or four overlapping. Decided per use:

| Use | Now |
|---|---|
| Rank-up hoop round the hero (`hero_fx.rank_up`, the blue / green ring on most strings) | Deleted: the HUD's rank and the burst carry it |
| Hop landing ring (`hero_moves.land_slam`) | Deleted: the designed dust puff carries it |
| Crater dust hoop (`Fx.crater`, one per foe driven down) | Deleted: the dent and the puff carry it |
| Every other ring (`comic_pop` "ring", so `Fx.ring`, `thin_hoop`, war cry, landings, last kill, perfect dodge, nova, `hoop_run`) | A designed **shock stamp** (`designed_ink.shock`) |
| Breaker cue (`breaker_cue.gd`) | Same radii, timing and colours, drawn as brush strips |

- **Shock stamp:** `stamp_shock` laid round an annulus (`designed_ink.annulus`), 3-5 tiles a ring
  (`shock_tiles`), so a ring is a few big broken brush arcs (fat at the front, dragged thin behind, a hot streak, a
  split in the tail, a chip in the gap, splatter off the outside), turned at random, racing out from
  `SHOCK_FROM` on twos and eroding from the outline. A dashed hoop of many tiles still read as a gizmo. Real-time
  cap `SHOCK_LIFE_MAX` so slow motion never holds one.
- **Breaker cue:** the target ring is a ring of brush dashes (`stamp_cue` rows 0-1, boiling on twos), the closing
  ring one fat brush line (rows 2-3; with two endings it alternates the two colours in `DASHES` pieces). The colours
  still mean what they meant (paper, gold in the window, grey locked, the ending's colour) through the stamp
  shader's `tint` / `tint2`.
- `shaders/designed_stamp.gdshader`: the strip round the circle (`tiles`, `scroll`), palette row or a tint ramp
  (ink, 0.55, 0.8, the colour, whitened), erosion with an ink burn line, no depth test (like the old hoops).

### Hit pops (every element hit)

Every hit threw the hit star plus a cluster of element chips (`Fx.element_hit`) on each foe, then numbers and a
word; with four foes it was noise. Now one designed pop a hit in the element's shape (`designed_ink.pop`):
`pop_storm` (jagged straight-sided star with uneven spikes, forked sparks off the long tips, breaking into zigzag
shards), `pop_magma` (blobby splash with round-tipped tongues and teardrop globs, a hole opening in it), `pop_ice`
(faceted shards with a lit facet and a specular stripe, a four-point glint), `pop_dark` (an ink blot with curling
tapered strokes, a negative-space hole, splatter dots). The plain hit, spirit and gold keep the pilot's hit star.
`Fx.element_hit` draws nothing more when designed. Crowd caps (one clear focal effect a beat): `POP_FULL` (2) full
pops and `POP_SMALL` (2) at `POP_SMALL_K` a frame, the rest none; impact streaks `STREAKS_A_FRAME` (1); the chain
halo once a frame (`once_a_frame`).

### The weapon trail (`weapon_trail.gd`)

The axe ribbon was a soft see-through gradient crescent next to the designed slash. Designed, it lays the same
`slash_strip` along the ribbon (`shaders/weapon_trail_designed.gdshader`: the stroke's head at the blade, its tail
the oldest sample, eroding first; boils on twos; palette row from the trail colour's nearest element).

### Files (round 44)

| File | Role |
|---|---|
| `tools/vfx_gen/gen_cohesion.py` | `tentacle_skin`, `tentacle_smear`, `stamp_shock`, `stamp_cue`, `pop_storm`, `pop_magma`, `pop_ice`, `pop_dark` |
| `scripts/designed_ink.gd` | `prewarm`, the shock stamp (`shock`, `Shock`, `annulus`, `tiles_for`, `shock_tiles`, `stamp_material`), the hit pops (`pop`, `pop_share`, `streaks_ok`, `once_a_frame`) |
| `shaders/tentacle.gdshader`, `tentacle_smear.gdshader` | The tentacle's skin and smear |
| `shaders/designed_stamp.gdshader` | A strip round an annulus on the floor, palette or tint |
| `shaders/weapon_trail_designed.gdshader` | The slash stroke along the swing ribbon |
| Call sites | `void_tendril.gd`, `comic_pop.spawn` (every ring), `dark_fx.hoop_run`, `breaker_cue._draw_designed`, `Fx.hit_spark` / `_flush_crowd_stars` / `impact` / `element_hit` / `chain_spark` / `crater`, `hero_fx.rank_up`, `hero_moves.land_slam`, `weapon_trail._init`, `elements.prewarm` |

Strip sheets are drawn at about 280 px a metre but seen at about 48: an ink line that reads as 2 px on screen is
about 10 px in the strip (`INK_PX`). The tentacle draws its ink in the shader in metres instead, so the thin tip
keeps its line.

## Round 45: one ring, quieter cue, dark conversions (fx-cohesion2 lane)

The orchestrator's review of round 44: the floor still read as circles (in Live Wire's hang the cue's thick closing
ring, a second green stamp and the dashed target were all on screen), and after fx-air turned storm electric lime the
cue's ring was the loudest thing in the frame.

**Floor marks: one at a time.**
- A ground stamp is never a closed circle: `stamp_shock` draws one arc a tile over less than half of it (3-5 tiles, so
  about 45% of the circle), fat near its front and dragged out concave to a hair. Its ink is its own tapered stroke:
  a uniform `grow` turned the thin ends into ink dots.
- Lives are 0.15-0.25 s (`SHOCK_LIFE`, real cap 0.35 s): a shock line is an accent, not a lingering ring.
- `designed_ink.shock()` drops a second shock within `SHOCK_APART` (5 m) of a live one, and draws none while a breaker
  cue is closing (`cue_on()` / `cue_live()`; the cue's `closing()`); a shock still running when a cue appears goes.
  The press's snap is the one ring a press leaves (the closing ring hides on the press).
- Ring-like floor marks per filmed frame (scratch `_fxcoh_film.gd` counts live shocks and the cue's two rings):

  | String | round 44 max / mean / frames with 2+ / shocks during the cue | round 45 |
  |---|---|---|
  | Live Wire (L_H_H) | 4 / 0.81 / 11 / 4 | 3 / 0.68 / 10 / 2 (the press snap only) |
  | Singularity / Collapse (H_H) | 5 / 1.53 / 14 / 8 | 3 / 0.60 / 8 / 2 |
  | Reap / Black Tide (H_L_H) | 4 / 0.92 / 12 / 4 | 3 / 0.53 / 7 / 2 |

  "2+" frames now are the cue itself (target + closing) and, for a frame or two, its fading target with the press snap.

**The breaker cue, quieter.** Same timing, same colour meanings. The target is a thin solid brush line (0.17 m; paper,
gold in the window, grey when locked). The closing ring is long broken cream dashes (0.2 m, six tiles of three
dashes) with every third tile in the ending's colour (`accent_every` in `designed_stamp.gdshader`); two endings still
alternate their colours tile by tile.

**Dark, in the Dark shape language.**
- Pools (`dark_fx.Pool`): `dark_pool`, an authored floor decal (an ink well, a violet body with negative-space holes,
  tapered arms curling out with drops flung past their tips, a light rim so it lifts off the indigo floor), boiling on
  twos (`designed_ink.floor_loop()`), eroding away at the pool's end. The group and timings are untouched.
- The Singularity (`dark_fx.Hole`): `dark_vortex`, five curling arms swirling into an ink hole with a hot lip, spun by
  the hole's `_spin`. Its rim arcs, edge hoop and the inward hoop every 0.45 s are gone in designed mode (the pull,
  ticks and collapse are untouched).
- Reap: the designed brush slash in the dark palette at 0.6 of the reach (the full 6.5 m arc's band was a 2 m slab).

**Locomotion and kills.** `comic_dust` puffs are one drawn `dust_puff` each (skid marks stay); the dash streak is
drawn speed strokes thrown back off the kick-off in his colour (once a frame); `Fx.death` is a held big hit star, a
burst of strokes along the blow and a dust puff where he drops (the loose bone chips are gone).

Still polygons: `comic_axe_aura`'s blade tongues (not converted this round; it has no void look of its own, so the
"purple crescent" named in round 44's list still needs pinning down in a film), chain halos and daze stars, combo pop
strokes, the Awakening, the spirit echo ghost.

## Round 46: ice and magma base moves (fx-elements lane)

Zak: "the effects are not really effects, they're just polygons you're putting together." The ice and magma right
clicks were the last runtime polygon assemblies in the element moves. Sheets: `python tools/vfx_gen/gen_elements.py
[names] [--preview=<dir>]` (imports vfxlib; about 70 s for all eight). Runtime: `scripts/designed_elements.gd`,
registered into `DESIGNED.extra_sheets` the first time anything spawns (`register()`), prewarmed from
`elements.prewarm`. Every swap is behind `DESIGNED.on()`; `--fx=classic` plays the old polygons.

| Sheet | Size, frames | Kind | Plays as |
|---|---|---|---|
| `magma_fist` | 256, 8 | sprite (over the pile) | Molten Palm's fist (`comic_fist.gd` keeps its node, flight and timing): wind-up white-hot, flight boiling on twos with tongues trailing, squashed impact with a splash crown held while the fist holds, cooling into crust and breaking into globs (`FIST_DISSOLVE` 0.22 s) |
| `magma_crack` | 256, 4 | ground | the fissure's seam, one tile a step turned along the line, crust plates on its banks |
| `magma_spurt` | 256, 7 | sprite_depth | lava spikes (`elements.spikes("earth")`): one drawn cluster of fat tongues, thrown up, slumping and crusting; a spurt every other fissure step |
| `magma_geyser` | 384, 8 | sprite_depth | `elements.geyser` / `rim_geyser` (Worldbreaker's pile): the floor splits hot, a lumpy column punches up with a splash crown spilling over, drops fall, the column slumps into a crusted mound |
| `magma_pool` | 384, 6 | ground | Undertow's lava well (`Well._comic_mark`, was an `Fx.scorch`): a hot crack opens into a round pool with crust rafts and popping domes, crusting over in `WELL_COMIC_SHOW` |
| `magma_meteor` | 384, 5 | sprite_depth | Meteor Fall's fireball in flight (`void_element.meteor_shell`, was cones and spheres): a crusted molten ball with a white-hot bow and fat tongues streaming back, ignite frame then boiling on twos in real time, turned to the dive on screen and stood `METEOR_BACK` behind him from the camera so he reads in front |
| `ice_frost` | 512, 4 | ground | the frost spear's floor (frames 1-3 boil slowly: the glints move), Deep Freeze's burst and every frost mark (frame 0 only, the cracks racing out) |

Not flipbooks: the ice block round a frozen or cubed foe (`thrown_foe.comic_cube`, so `comic_ice` too) and the frost
spear are faceted meshes (`ice_block()`, `spear()`): a clean hex prism (fx-ice2 took its crown crystals off and fits it
to the foe, see "fx-ice2" below), the spear a violet faceted shaft with one slim ice point. `shaders/ice_facet.gdshader` paints each face one flat cel tone by how it faces the camera
(lit / body / shadow), a light rim band, one hot specular stripe on lit faces and a straight ink crack on some; the
`ghost_ink` hull inks the silhouette. See-through in the middle so the foe inside shows.

**Tuning.** `FIST_SIZE` 2.5 m, `SPURT_SIZE` 2.2, `ICE_SPIKE_SIZE` 2.5, `SPIKE_TOWARD_CAM` 0.35 m (stood towards the
camera so the floor doesn't clip the plate), `CRACK_SIZE` 2.1, `METEOR_SIZE` 4.6 / `METEOR_BACK` 0.9 /
`METEOR_IGNITE` 0.06 s, `GEYSER_QUAD` 1.5 (quad side per metre of column), `POOL_QUAD` 2.25 (per metre of the well's
radius: 2.6 merged a pile's pools into one orange slab), `FACET_INK_PX` 3, ice_facet `fill_alpha` 0.42 (the crystal
sizes `ICE_SPIKE_SIZE` / `BLOCK_CROWN` went with fx-ice2).

**Gotchas.**
- Small sprites need fat ink in the sheet: a 256 sheet seen at 0.3-0.45 of its size needs 5-6 px of ink, a 384 floor
  pool 7 px; 3.5 px vanished at the game camera.
- A shape cut on the ground line draws a straight edge (the geyser's first foot was a half dome): draw the whole round
  puddle and let the anchor stand it on the floor.
- Ice erosion has to break along straight lines: `facet_order()` gives each Voronoi cell one random erode order, so
  the dissolve drops whole facets instead of eating a blob.
- `sprite` / `sprite_depth`: flip mirrors x before the spin, so a sheet drawn pointing +x flying left is `spin = a +
  PI, flip = -1` (`aim_sprite`), or its lit top ends up underneath. `anchor` is the pivot, so a sheet whose subject is
  off-centre (the meteor's ball sits right of the middle, its tongues streaming left) turns round the subject.
- Facet meshes: Godot's front faces wind clockwise, and the ice_facet contract is COLOR.rgb = the flat face normal
  (* 0.5 + 0.5), COLOR.a = a per-face seed, NORMAL = corner normals (only the ink hull uses them), UV 0..1 per face.
  Its instance uniforms must be ghost_ink's (alpha, fade_height, local_fade) in that order or the hull pass breaks.
- `DESIGNED.spawn`'s `pop` only acts on frame changes and only above 0; to grow a single-frame decal (Deep Freeze's
  cracks) tween its scale on twos with an ignore-time-scale tween.
- Bubbles drawn as a light ring round a dark middle read as eyes on the pool; draw them as lit domes.

Still polygons in this lane: the breaker dive trail (`comic_comet.gd`, every element: water's drawn crystal trail went
with fx-ice2), the Harpoon's line (it is the tentacle: designed in round 44), the tentacle's own lava / ice skins.

## fx-ice2: no crystals, a block that fits (round 47)

Zak, after playing round 46: "the ice is also a big improvement, but there are times these crystals manifest that look
awful. get rid of the crystals. i love the new ice block, ensure they're covering the whole character model tho. the
dummies part of them clip out."

**What went, what took its place** (designed mode; `--fx=classic` keeps its own polygons):

| Was | Now |
|---|---|
| `ice_spike` crystal clusters out of the floor: every water `elements.spikes` (the nova, Deep Freeze's ring, Worldbreaker's ice, `storm_strike` in water) and Harpoon's line (`elements.fissure` in water) | `designed_elements.frost_mark`: a new `ice_mark` ground sheet (2x2, `gen_elements.py ice_mark`): a pale hexagonal rime with seven fat straight inked cracks, hot on its first two frames, glinting, then eroding; and a low puff of cold mist (`dust_puff` in water's tones, 0.7 of its size). Harpoon's line is a crack every step with mist on every other one (the first try used `ice_frost` frame 0's cracks: too thin to read on the line) |
| the block's three crown crystals (`BLOCK_CROWN`) | nothing: a clean prism, top a little narrower (`BLOCK_TAPER` 0.94) |
| the frost spear's ring of six crystals and its crystal head; a burst of `ice_shatter` shards where it goes in | the faceted violet shaft with one slim four-sided ice point; a `frost_mark` where it goes in |
| the frost floor's hexagonal ice plates (read as crystal cubes on the floor) | gone from `ice_frost` frames 1-3 (`gen_elements.py ice_frost`); its cracks, toothed edge and glints stay |
| the ice dive's crystal trail (`ice_trail` on `comic_comet`, Avalanche) | the inked comet streak every other element dives with, in water's colour |
| Flash Freeze's crystal shell climbing each held foe (`comic_freeze_over.foe`) | the ice block itself (`void_grab.freeze_seized` cubes them) and a `frost_mark` under each |
| Impale's eight floor spikes and its crystal stake (`comic_impale`) | Deep Freeze's crack burst out to the ring and a `frost_mark` at the spear; a water hit star where each lands on it |
| the every-hit ice pop (`pop_ice`, a cluster of faceted shards) | redrawn shard-free (`gen_cohesion.py pop_ice`): a glint, a thin hex ring opening with short straight rays off its corners, a glint in its middle |
| the improv tells' ice tips (Frozen In, Ice Spreads, Freeze Aloft's ring of spikes in the air; `comic_improv._tip`) | none drawn; Ice Spreads with nobody to spread to makes a `frost_mark`, Freeze Aloft a water hit star (its block is the read) |

The `ice_spike` and `ice_trail` sheets and their generators are deleted; `ice_mark` is new. Kept on purpose (fx-ice3 later made it shard-free, see below): `ice_shatter` (the block
breaking into shards is debris from a break, not crystals growing), the skewered state's stake (`comic_state_tell`,
the only tell for Backdraft), Black Ice's floor plates and the axe aura's shards (already off in designed mode).

**The block fits the foe** (`designed_elements.fit_block(foe, ice)`, called by `thrown_foe.cube_on` and every
`enemy.freeze`; `ice_block(r, high)` is unchanged for other callers):
- `model_points(foe)`: each skinned mesh's vertices are sorted to their main bone and only the extreme ones along 14
  directions are kept, once per mesh (`_boxes_of`, in the bone's rest space; about 5 ms the first time a kind freezes,
  then cached), and a freeze moves those by the bones' current poses: 0.3-0.8 ms a foe. The model is taken standing upright at its own `model_scale` (a hit's squash is
  gone in a beat).
- `block_fit(points)`: the block centres on the body (the points within `FIT_CORE` 0.75 m of the foe's middle), its
  radius encloses every point round that axis (a circle, so the cube may spin in flight without a corner swinging onto
  him), narrowing with the taper, plus `FIT_MARGIN` 0.08 m, capped at `FIT_R_MAX` 1.2 m (weapons held out past it poke
  out: a sword at arm's length made a 3 m slab); its height runs from the floor to `FIT_TOP` 0.1 m over the head.
  Sizes round up to `BLOCK_STEP` 5 cm so fitted blocks share meshes.
- Each block gets a random turn, so a row of frozen foes is a row of blocks, not one slab.
- Frozen foes hold still: `enemy._clip_speed` holds the clip at 0 while `frozen_t` runs (also for `freeze_aloft`,
  which sets `frozen_t` by hand) and gives it back at the thaw; `enemy.freeze` stands the model upright (a hit's lean
  tween is cut) and the dummy's bag spring stays upright while frozen (`training_dummy._bag_step`), so the wobble can't
  swing it out.

Measured (`tests/ice_block_check.gd`, every kind hit and encased, its CPU-skinned vertices checked against the prism
for a second): the dummy's block is 1.05 m round and 2.2 m tall (it was 0.75 x 1.5, and the bag's arms, head and
squash poked out); the spar kinds come out at 1.2-1.3 m with weapon tips 0.2-0.7 m out (warrior, rogue, archer,
shield, necromancer). Every body vertex is in.


**fx-ice3 (follow-up, the crystals film still showed).** Clip 26 (Harpoon Slapshot) still had two crystal shapes:
- Dash Stab's hit fanned big cyan faceted blades round him: the weapon ribbon (`weapon_trail.gd`, the slash_strip
  brush in water's palette) dragged along the 16 m/s lunge, plus the two swing arcs (`hero_fx.swoosh`). A thrust has
  no arc: `"thrust": true` on DL (`hero_moves.gd`) turns off its weapon ribbon (`player.gd`) and its swing arcs in
  designed mode. The claw lash, the hit pop and the streaks carry it.
- Each latched foe stood a fan of ice-blue spikes: the latch's hit has no knockback, so `Fx.impact`'s
  `impact_streaks` were thrown straight up in water's palette. `designed_fx.streaks` now draws no water streaks on a
  blow under half horizontal (the pop carries the latch).
- `ice_shatter` is shard-free: a frozen foe thawed by a hit, a cube bursting and Slapshot's wall smash were all faceted
  shards. Now it's the ice pop's ring opening round a glint (`ICE_BREAK_POP` 0.75 of `ICE_SIZE`) in a puff of cold
  mist (`dust_puff` in water, `ICE_BREAK_MIST` 0.7). The `ice_shatter` sheet is still registered but nothing draws it.
- Harpoon's set (`void_element._harpoon` `on_set`) leaves a `frost_mark` under each block, not ice chips
  (`Fx.shards`).
- `pop_ice` lost the short rays off its hex ring's corners (they read as a snowflake).

Clips: `awaken-combo-clips/25 Ice fx-ice3 *` (strings 6, 7, 27, 28 before / after, and full-size crops).


## Round 46: the finish (fx-finish lane)

Zak: the effects "look weird" and are "just polygons". This lane took the most-seen polygon effects outside the
ICE / MAGMA base moves (fx-elements' lane) and made them authored sheets. Sheets: `python tools/vfx_gen/gen_finish.py
[names] [--preview=<dir>]`; runtime: `scripts/designed_finish.gd` (registers its sheets in `DESIGNED.extra_sheets`,
`prewarm()` from `elements.prewarm`). Everything is behind `DESIGNED.on()`; `--fx=classic` plays the old drawers.

**The Awakening** (`awaken_flourish._show` -> `designed_finish.awaken`): an authored gold event, not a beam and rings.
- Anticipation (`awaken_gather`, 0.27 s real): long straight ink focus lines pulled in to him, a gold ring tightening.
- Held peak (`awaken_crown`, sprite_depth stood 0.55 m behind him from the camera, following him): a radial crown of
  seven fat S-curved gold flame tongues, one inked union with side flicks, hot cores, held two frames, then licking up
  and eroding. It never covers him: he stands in front of it (depth tested).
- `awaken_floor` (ground): a sunburst of three wedge clusters with gaps (a full ring read as a sawblade), eroding out.
- The waiting logic (`awaken_flourish` waits for the activation) is untouched; `hero_fx.rank_up` is not converted.

**Every hit.** `Fx.chain_spark` halos are `chain_halo` (a four-point inked sparkle, three tiers by size and frame band,
element-coloured via `PAL.nearest`); `Fx.daze` stars are two `daze_star` quads (depth tested) orbiting on the old ring,
boiling on twos; `Fx.combo_pop`'s strokes are `combo_burst` (fat-at-the-root focus lines round an open middle, so the
hero shows through, scaled by tier).

**Every swing.** The spirit echo's 3 m halftone axe is gone in designed mode: `echo_axe` is a drawn bearded axe head
(lit edge band, hot glint, a haft stub, two edge echoes behind it) flown along the arc's outer edge at 0.82 of the
radius, turned along the screen tangent. Hits are unchanged. `comic_axe_aura`'s tongues and drip motes are off in
designed mode: on the v2 hero the blade they coat is hidden most of the time, so they read as cyan dots round him (the
drag mark still runs).

**Every named combo.** The weapon change burst (`heretic_form_fx.spawn`) is `designed_ink`'s element pop at 1.1 m in the
form's element (axe wind, spear water, hammer earth, hand void), still in group `heretic_form_fx`.

**Crossovers / breakers.** Rockslide's boulder (`rock_boulder`: drops stretched, lands squashed on a hot star, cracks
open, chunks fly), Steam Burst's cloud (`steam_cloud`: inked cumulus, depth tested 0.55 m behind the foe so he shows),
Eruption's landing (a `magma_burst` per foe, nearest first) and Anvil's (an earth `strike_scorch` + dust per foe).

| Sheet | Grid | Kind | Used by |
|---|---|---|---|
| `awaken_gather` | 3x2 | sprite | Awakening anticipation |
| `awaken_crown` | 4x2 | sprite_depth, anchor (0, -0.35) | Awakening peak |
| `awaken_floor` | 3x2 | ground | Awakening sunburst |
| `chain_halo` | 4x3 | sprite | `Fx.chain_spark` |
| `daze_star` | 4x1 | sprite_depth | `Fx.daze` |
| `combo_burst` | 3x2 | sprite | `Fx.combo_pop` |
| `echo_axe` | 4x1 | sprite | `spirit_echo.gd` |
| `rock_boulder` | 4x2 | sprite | `comic_boulder.gd` |
| `steam_cloud` | 3x2 | sprite_depth | `comic_steam.gd` |

Lessons:
- A sprite_depth billboard leans into the floor: its lower part is clipped by the ground. Draw the roots above the
  ground line in the sheet (the crown's lip sits at 0.83 of the frame) and lift the anchor.
- Depth-tested and stood behind the subject (towards the camera's far side) is how a big effect sits round a hero or foe
  without covering him: the crown, the steam cloud, the daze stars.
- Movie Maker (`--write-movie f.png --fixed-fps 24`) films a scratch scene frame for frame at 24 fps, about 10x faster
  than viewport readbacks; set `DESIGNED.game_time_only` so real-time timelines follow the fixed clock.

Still polygons: `hero_fx.rank_up`, `callout_cap`, `comic_fault`'s ground, `comic_freeze_over`, `comic_melt`,
`comic_impale`, `comic_rip`, the `comic_improv` tells, kills' `Fx.soul` and `last_kill` rings, `comic_drag_mark`,
Dash Stab's claw lash.

## Feel audit 4 (feel-polish, 2026-11-06)

- Frost spear: no `ice_frost` floor in designed mode (its disc of cracks grew to ~5 m under the dummies). The plant is
  a ground stamp, `designed_ink.shock` 1.25 m (`frost_spear.STAMP_R`) and `frost_mark` at `STAMP_MARK` 1.5 (~2.5 m).
  `designed_elements.frost_floor` / `frost_step` have no caller now. Deep Freeze's `frost_burst` is unchanged.
- Spirit echo: drawn at `designed_finish.ECHO_DRAW` 0.62 of the cast's reach (the hit reach is unchanged), the axe
  head `ECHO_SIZE` 1.4 m, the line `echo_line()` a thin void-ink `slash` (`ECHO_LINE_INNER` 0.94 of its radius in),
  both on real time for `ECHO_REAL` 0.2 s (`designed_fx.slash(..., real)`), so neither hangs through the hitstop into
  the next move. See `docs/feel-audit-2026-11-06b.md`.

## fx-polygons: the last runtime polygons (round 47 d)

Zak, after fx-ice3: wind and electricity "phenomenal", the see-through ice block loved, no spiky crystals anywhere,
"keep improving ... focus on improving effects". This lane drew the polygon assemblies still on film in the 32 bot
strings. Sheets: `python tools/vfx_gen/gen_polygons.py` (previews with `--preview`); code: `scripts/designed_polish.gd`
(registered as extra sheets, prewarmed in `elements.prewarm`). Every swap is behind `DESIGNED.on()`; `--fx=classic`
plays the old look.

| Effect | Was | Now |
|---|---|---|
| Breaker dive trail (`comic_comet.gd`) | flat tapered polygon ribbon per element | earth / water / fire: `dive_trail` brush comet strip; void: `dive_ink` smear; storm: the lime `bolt_strip` zigzag, tiled and scrolled. Landing: `INK.pop` + `INK.shock` |
| `Fx.burst` in comic style (rank-up, many hits) | polygon shard fan | `chip_spray` drawn chips flying out along the burst's direction |
| State tells (`comic_state_tell.gd`) | buried: polygon rubble; skewered: flat plates; molten: polygon flames; charged: polygon sparks | `tell_buried` stone crust ring (dust row), `tell_pinned` frost rime with cracks and glints (no crystals), `tell_molten` flame licks stood behind the foe, `arc_crawl` crawling arcs |
| Reap's mark (`dark_fx.Mark`) | three pink flat crescents | `tell_marked`: three curling violet ink claw strokes with splatter, spinning |
| Fault Line ground (`comic_fault.gd`) | polygon crack lines | `magma_crack` tiles every 0.75 m, a pop on arrival, `magma_burst` on Cataclysm |
| Flash Freeze / Black Ice pool (`comic_freeze_over.gd`) | polygon ice plates | `tell_pinned` rime loop on the floor; break: `ice_shatter` ring + `frost_mark` |
| Meltdown (`comic_melt.gd`) | polygon slash, shell, splash | designed slash arc, `ice_shatter`, the `meteor_shell` fireball, `magma_burst` + `magma_crack` landing |
| Tow Line (`comic_rip.gd`) | polygon tear | `ink_tear` following the foe |
| Element payoffs (`comic_improv.gd`) | polygon tells per cell | per-cell designed combos of existing sheets (shatter, gust, streaks, frost mark, fissure, crawl, steam, pop, shock) |
| Drag mark (`comic_drag_mark.gd`) | flat polygon strip | `drag_line` strip through `designed_drag.gdshader` (UV in metres, erodes by age) |
| `Fx.soul`, last-kill rings, claw lash turn flare | polygon wisps / extra flare | `air_wisp` spirit wisps rising; a gold `hit` flare on the last kill (the designed rings stay); `DESIGNED.hit` on the lash turn |

Coverage (`tests/fx_coverage.py`, full 32-string film): mean 0.081 -> 0.079, max 0.195 -> 0.210 (budget 0.40).
Clips: `awaken-combo-clips/27 Polygons *` (before / after contact sheets).

Still polygons: `callout_cap` (a HUD-like word cap, not an effect drawing), `comic_axe_aura` (off in designed), the
purple radial wedges round the hero on some breaker leaps (seen on film, source not traced), `Fx.chain_spark` halos past
the caps. Unverified on film: the drag mark (no frame caught it clearly) and the claw lash's turn flare.

## Breaker spectacle (round 48, breaker-spectacle lane)

Every breaker landing is one shared comic beat in the element's shape language. Code: `scripts/designed_breaker.gd`; screen shader: `shaders/designed_canvas.gdshader` (a designed sheet on a canvas item, with the five tones as uniforms and a `band` sub-rect). Sheets: `python tools/vfx_gen/gen_spectacle.py` (`--out=` for a preview dir; slow, ~5 min). See `docs/features/combo-breakers.md` "Round 48" for the beats.

| Sheet | Kind | What |
|---|---|---|
| `slam_star` | sprite_depth | storm: a spiky lightning star with zigzag arcs, halftone body |
| `slam_magma` | sprite_depth | magma: a lumpy blast with ember blobs |
| `slam_frost` | sprite_depth | ice: a wavy frost cloud with halftone dots and thin cold glints (no crystals) |
| `slam_ink` | sprite_depth | dark: an ink splash with drips and tendrils |
| `slam_rays` | sprite | radial speed lines with a clear middle |
| `floor_arcs` / `floor_cracks` / `floor_splat` | ground | the floor-wide spread: arcs, cracks, an ink splat |
| `wall_star` | sprite | the drawn impact star on a wall splat |
| `smoke_curl` | sprite_depth | the after-beat's curl (dust / water / void rows: smoke, mist, wisps) |
| `hang_focus` | screen | the hang's focus lines |
| `callout_panel` | screen | the callout banner (drawn across y 0.27-0.71 of the frame) |

Coverage (`tests/fx_coverage.py`, the full 32-string film): per HIT frame, mean 0.063-0.081 -> 0.070-0.088 and max 0.171 -> 0.327 over the three ranges. The landing's frames +1..+10, which the tool does not score, have a mean peak of 0.123 -> 0.187 and a max of 0.179 -> 0.327 (Meteor Shower). Budget 0.40. Maw's ink splat was 0.409 at full size, so the dark floor splat is drawn at 0.72 (`LOOK.dark.floor_size`).
Clips: `awaken-combo-clips/30 Spectacle *`.

## Lava Leash (round 49, dark-magma lane)

`python tools/vfx_gen/gen_leash.py [names] [--preview=<dir>]` (in the style of gen_elements, whose `tear`, `tongue`
and `voronoi` it imports). Registered by `scripts/lava_leash.gd` (`SHEETS`, `register()` into
`designed_fx.extra_sheets`), drawn once at load by `lava_leash.prewarm()` from `elements.prewarm`.

| Sheet | Kind | What |
|---|---|---|
| `lava_seam` | ribbon (1x4) | the seam each dragged foe leaves: crusted inked banks with crack joins, the lava body, a lit band and hot core, crust rafts, a popping bubble, drips; drawn as one ImmediateMesh strip with `shaders/designed_drag.gdshader` (COLOR.r = age, UV.x = distance / `SEAM_TILE`), cooling and eroding from its old end |
| `leash_burst` | sprite_depth (4x2, 7 frames) | the eruption under the pile: a slit, a fan of five tongues, globs, a crust mound; tongues clamped above the ground line, `BURST_SIZE` 4.4 m, stood 0.5 m behind the pile from the camera so the foes read in front |

The tentacles are `void_tendril` washed with `electrify(HEAT, LAVA)` as they drag; the pool under the pile and
Hellseam's seam geysers are `designed_elements` (`pool`, `geyser`). No polygons, no crystals. Headless or `--fx=classic`
draws no seam (the gameplay is the same).

## Round 51 cool pass (combo-cool lane)

`python tools/vfx_gen/gen_cool.py [names] [--preview=<dir>]` (gen_elements' helpers; its own `_tentacle` with suckers and a
lit band, `_curl_path`, rounded ice `_block`s). Each sheet is registered by the script that plays it (`register()` into
`designed_fx.extra_sheets`) and drawn once at load from `elements.prewarm`.

| Sheet | Kind | Played by | What |
|---|---|---|---|
| `void_spit` | sprite_depth (4x2, 7 frames) | `collapse_spit.gd` | the hole's mouth, tentacles bursting up out of it and falling back, stood 0.4 m behind the hole from the camera |
| `avalanche_spill` | ground (3x2, 6 frames) | `avalanche_topple.gd` | the snow fan the toppled tower's cubes slide out on, blocks tumbling in it, laid along the fall (+u) |
| `abyss_column` | sprite_depth (4x2, 7 frames) | `abyss_rise.gd` | the floor tearing, three braided tentacles rising to a grabbing hand, holding, whipping down, the knot and splash, the hole closing; the foe is carried at the hand (`APEX`) |

No polygons, no crystals (the ice is rounded blocks in snow).

## Round 52 cool pass (combo-cool2 lane)

`python tools/vfx_gen/gen_cool2.py [names] [--preview=<dir>]` (gen_elements' `tear` / `tongue`, and gen_cool's
`erupt_chain` drawing, which round 51 left unused). Each sheet is registered by the script that plays it (`register()`
into `designed_fx.extra_sheets`) and drawn once at load from `elements.prewarm`. No polygons, no crystals: the frost is
rounded rime lumps, steam is lumpy puffs, magma is tongues and globs, the dark is ink.

| Sheet | Kind | Played by | What |
|---|---|---|---|
| `erupt_chain` | ribbon strip (1x4) | `eruption_hurl.gd` | Eruption's fuse: the crusted lava crack that races along the floor from the landing to each burning foe; one ImmediateMesh strip on `shaders/designed_drag.gdshader` (COLOR.r = age, UV.x = metres / `FUSE_TILE`), cooling from its old end |
| `erupt_drip` | sprite_depth (4x2, 7 frames) | `eruption_hurl.gd` | a burning foe splatted up the wall: the splat, three streams running down (the foe slides down the middle one), the pool at the foot with licks, crusting; stood `DRIP_OUT` out of the wall face, `DRIP_SIZE` 3.6 m |
| `steam_shell` | sprite_depth (3x2, 6 frames) | `frost_shell.gd` | Flash Freeze's steam rolling over a foe: puffs at its feet, billowing round it, curling over, drawn in tight with a rime of rounded frost lumps, thinning to a cold floor mist; stood 0.4 m toward the camera so it rolls over the ice block |
| `spit_burst` | sprite (3x2, 6 frames) | `collapse_spit.gd` | Collapse's spit as a beat of its own: three fat ink tongues splaying up out of the mouth, a ring of teardrop globs flung and falling, the puddle; `BURST_SIZE` 3.4 m over the hole, a pop on frame 0 |

Flash Freeze's shell is the fitted ice block (`void_element.encase`, fx-ice2's `fit_block`), its break `designed_fx.ice_shatter`
and the frost line between shells `designed_elements.fissure(..., "water")` (floor cracks and mist). Eruption's geyser is
`designed_elements.geyser`, the pool under a foe that slid down `designed_elements.pool`, the wall beat
`breaker_alt_fx.cool_wall`. Collapse's spit trail is the dark breaker dive's ink comet (`comic_comet.gd`) fed on the foe.

## Feel audit 2026-11-07b (feel-audit5 lane)

- `ice_mark` redrawn (`gen_elements.py ice_mark`): an uneven 17-corner patch of rime (alpha 0.3) with a broken lit
  edge, three jagged crack chords rim to rim (one fork each, a hot core on frame 1) and round frost beads, no glints
  and nothing radiating from its middle. It read as a spoked crystal star on every water hit (Cold Front, the frost
  spear, Deep Freeze's ring).
- Deleted, nothing called them: `comic_freeze_over.foe()` (the crystal shell; only `pool` / `shatter` remain),
  `designed_elements.frost_floor` / `frost_step` / `FROST_BOIL`, `designed_fx.ICE_TIMES`, `harpoon_gather.carrying`.
  `ice_frost` stays (Deep Freeze's `frost_burst`).
- `designed_elements.prime_fit(foe)` reads a foe model's skinned vertices at spawn (`enemy._ready`, deferred): the first
  ice block read them back from the GPU mid-fight, a 44 ms frame windowed.

## Round 54 cool pass 3 (combo-cool3 lane)

`python tools/vfx_gen/gen_cool3.py [names] [--preview=<dir>]` (gen_counter's `blade` / `curl_path` / `polar` /
`tentacle`). Registered by the scripts that play them and drawn once at load from `elements.prewarm`
(`mid_beats.prewarm`, `counter_fx.prewarm_cool3`). No crystals.

| Sheet | Kind | Played by | What |
|---|---|---|---|
| `parry_glint` | sprite (2x2, 4 frames) | `counter_fx.glint` | Backlash's "tink": a hard four-point flick of light over the clash, `GLINT_SIZE` 2.4 m (x1.35 on a perfect), real time so the parry's hitstop does not hold it |
| `parry_blade` | sprite (4x1, 4 frames) | `counter_fx.blade_off` | the attacker's cleaver knocked out of its grip: a quarter turn a frame with a smear, carried on a real-time arc `BLADE_UP` 2.6 m up and `BLADE_OUT` 3.4 m away from him, spun, a dust puff where it clatters down (dust palette row) |
| `reap_hook` | sprite (3x2, 5 frames) | `mid_beats.hook` | Reap's barbed ink hook biting the far foe: thrown in, the barbs closing, the bite, the ink running off; follows the foe while it is yanked |

The rest of the round's beats reuse sheets that exist: Singularity's reel is `void_tendril` tentacles from the hole;
Frost Spear's spread is `designed_elements.fissure(..., "water")` and `frost_mark`; Steam Burst's fuse an earth
fissure into `steam_shell`; Hailstorm's gale `designed_twister`; Cold Front's bowl, Ricochet's throw and Reap's yank
the dark comet trail (`comic_comet.beat`, `mid_beats.trail`); the endings' second beats `comic_bolt`, `comic_fault`,
`storm_strike` and `designed_elements.geyser`.
