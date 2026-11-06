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

**Toggle:** on by default. `--fx=classic` (after `--`, e.g. `godot --path . -- --fx=classic`, or
`tests/string_film.gd -- --fx=classic --dir=x`) plays the old polygon effects from the same build, for before /
after films. In code, `DESIGNED.enabled = false`.

## Files

| File | Role |
|---|---|
| `tools/vfx_gen/vfxlib.py` | The drawing kit: curves (`catmull`, `wobble_ring`, `star`, `stroke`, `jag_path`), `Frame` (paint at 4x, `fill(mask, tone, ink=px)` inks each shape over what is beneath it), `erode_field` (edge / centre / tail dissolve orders), `pack`, `preview` |
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
| Storm (wind) | Jagged branching zigzags with uneven segments and forks, spiky stars with straight sides, crawling arcs | Smooth curves, round blobs |
| Dust | Round lumps, a curl line, flat bottom | Spikes |
| Dark (void, not converted yet) | Ink tendrils and smears: tapered curling strokes, splatter dots, negative-space holes | Hard geometry |

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

- Floor quads must sit at `GROUND_LIFT` (0.065 m): the floor stones reach 0.05 m, and at 0.03 m only the grooves
  between stones showed the effect.
- A node with no `times` (the ribbons, driven by their own tween) must not run the timeline, or it frees itself
  on its first frame (`_life` 0).
- The game's camera pulls out in a fight: an effect that reads at the scratch shot's close framing is about half
  that size in `string_film`. Judge sizes in the film.
- `Game` sets `Engine.time_scale` every frame from its stops: setting it from a test does nothing.
- A billboard drawn without the depth test covers the pile; a big one (the meteor crown) uses the depth-tested
  variant, stood behind the pile.

## Conversion list (remaining polygon effects, most seen first)

Converted in the pilot: hit star, impact strokes, swing swoosh, Meteor Fall landing, Molten Palm wall splat, ice
shatter / cube burst, every lightning bolt and arc (Grounded, Live Wire, Storm Pitch's zaps, Cataclysm's strikes,
since they all draw through `comic_bolt.spawn`), the `Fx.dust` puff.

1. Every hit: `Fx.element_hit` chips (`comic_pop` chips), `Fx.chain_spark` halos past 10 / 20 / 35 hits, the foe's
   `daze` stars.
2. Every swing: the axe ribbon (`weapon_trail.gd` + `shaders/weapon_trail.gdshader`: a strip texture like the
   slash), the axe's element aura (`comic_axe_aura.gd`), the floor drag line (`comic_drag_mark.gd`), the spirit
   echo's ghost axes (`spirit_echo.gd`), Dash Stab's claw lash (`claw_lash.gd`).
3. Every dash and step: `comic_dust.gd` (run start, skid, dodge puffs: reuse `dust_puff`), `Fx.dash_streak`, the
   comic afterimage, the perfect-dodge flare.
4. Every named combo: `Fx.combo_pop` strokes, the weapon-change burst (`heretic_form_fx.gd`), `callout_cap.gd`.
5. Element moves (every right click): storm's Updraft Lash pillar / gale (`comic_gale.gd`, `elements.pillar`),
   Molten Palm's fist and fissure (`comic_fist.gd`, `elements.fissure`), lava geysers (`comic_geyser.gd`,
   `rim_geyser`), ice spikes and nova (`elements.spikes` / `nova`), Harpoon, the frost spear and its floor
   (`frost_spear.gd`), the ice cube block itself (`thrown_foe.comic_cube`) and the frozen foe's ice
   (`enemy.freeze` -> `thrown_foe.comic_ice`), the dark element (`dark_fx.gd`: tendrils, pools, splats; ink
   tendrils and smears), the floor bind (`floor_bind.gd`).
6. Breakers: the dive trail (`comic_comet.gd`), Meteor Fall's fireball shell (`void_element.meteor_shell`, cones and
   spheres), floor cracks (`comic_crack.gd`, also `Fx.scorch` in comic style), the war cry and crater
   (`breaker_quake.gd`), `Fx.ring` / `thin_hoop`, `comic_hail`, `comic_rip`, `comic_anvil`, `comic_impale`,
   `comic_erupt`.
7. Crossovers: `comic_boulder`, `comic_fault` (its strikes are already designed bolts), `comic_steam`,
   `comic_freeze_over`, `comic_melt`, `comic_backdraft`, `comic_arc` (its jumps are already designed bolts).
8. Element-matrix payoffs (`comic_improv.gd`) and the state tells on foes (`comic_state_tell.gd`).
9. Kills: `Fx.death` (flash, shock ring, shards), `Fx.soul`, `hero_fx.last_kill` rings.
10. Awakening: `Fx.awaken_burst` (beam, shockwaves, motes), `awaken_flourish.gd`, `hero_fx.rank_up`.
