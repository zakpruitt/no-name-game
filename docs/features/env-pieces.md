# Environment pieces: the room as data, and the heretic's own verbs on it

Round 51 (env-pieces lane). Zak: the environment should be "a big part of what you can do", with "environmental
aspects only they can use". This builds items 0-4 of the proposal's build order
([environment-per-character.md](../design/environment-per-character.md) section 5). The world behind it is in
[environment-lore.md](../design/environment-lore.md).

## What it does

- **Pieces are nouns everyone shares; verbs are per element.** A room is built from fourteen pieces
  (`env_piece.gd` `PIECES`). Every piece has one shared rule any hit triggers (a thrown foe breaks a crate for
  anyone). The exclusive verbs come from the element that hits it (`EXCLUSIVE`): a pillar answers to the dark, a
  barrel to magma, a grate to storm and ice. The structure indicator marks a piece for a verb only when the hero has
  that element (`usable()`), so the prince sees a grate as floor.
- **Room: plain / with pieces.** Settings "Room (on restart)" (saved), or `--room=plain|pieces` for one run. Plain is
  today's arena, unchanged, so every bot string and film plays the same; the autotest plays plain unless
  `--room=pieces` is given. With pieces, the training room adds one of each piece the heretic or everyone uses, each
  by a dummy and makes the banners live. Both training rooms rebuild every used-up piece `REBUILD_S` 6 s later with
  a dust pop (so a pillar Uproot tore out of the plain room comes back too).
- **Rebuild is per room** (round 52): each room's rules sit beside its entries (round 57: `rooms.gd` `ROOM_DEFS`,
  which folded in round 52's `ROOM_RULES`; every training room rebuilds); any other room is a real room (`REAL_ROOM`,
  `rebuild: false`): what is used up stays gone for the fight, so Uproot costs the pillar and its swing anchor.
  `rooms.rebuild(room)` is what `main._build_arena` passes to `EnvPiece.begin()`. No run builds real rooms yet.
- **More rooms** (round 57, rooms lane): the flooded cistern and the forge hall, Settings and `--room=cistern|forge`,
  each with a combo only it makes possible; rooms are wholly data now. See [rooms.md](rooms.md).

### The pieces

| Piece | Shared rule (anyone) | States | In the game | Art |
|---|---|---|---|---|
| wall | a thrown foe splats on it at the throw's `wall_mult`; the wall endings aim at it | none | yes (main.gd's walls) | `wall` |
| pillar | a wall for splats, the R anchor, the pillar slam, shakes on landings | whole / cracked / toppled | yes, both rooms | `pillar_decorated` |
| torch | swings when a foe splats on the wall under it | lit / out / conducting | yes, both rooms | `torch_mounted` |
| barrel | a thrown foe breaks it: a splat at half the wall's mult (at least x1), staves fly | whole / burning / gone | with pieces | `barrel_large` |
| crate | a thrown foe, a breaker landing within 1.5 m, or a burst keg breaks it | whole / gone | with pieces | `crates_stacked` |
| chest | heavy: a wall for splats, never breaks | shut / open | a look (the corner) | `chest_gold` |
| banner | a foe splatted within 1.4 m of it tears it down | hanging / torn / burning | live with pieces | `banner_patternA_red` |
| grate | floor to anyone without storm or ice | cold / live / frosted | with pieces | `floor_tile_big_grate` |
| spikes | a thrown foe that comes down on it takes x1.5 | up / down | with pieces | `floor_tile_big_spikes` |
| rubble | a breaker landing on it throws three chunks, 6 to everyone within 2 m | none | with pieces | `floor_tile_large_rocks` |
| brazier | lit; magma by an out one lights it (brazier_spill, round 53) | lit / out / spilled | with pieces | `brazier`, `brazier_spilled` |
| pool | water; ice by it freezes it (ice_rink, round 53) | water / frozen / live / steam | with pieces | `pool` |
| hook | a wall for everyone; Ricochet hangs a foe on it (gallows, round 53) | empty / hung | with pieces (two) | `hook_chain` |
| ledge | (data) a raised ledge 1.2 m up, its face a wall | none | a look, with pieces (box collider) | `ledge` |

**Art.** Every piece uses the comic dungeon kit (`assets/comic/dungeon/`). The brazier, pool, hook and ledge (env-art
lane) have no KayKit twin: one Blender script each in `tools/comic_art/` (`env_brazier.py`, `env_hook.py`,
`env_pool.py`, `env_ledge.py`, helpers in `env_extra.py`; run `blender -b -P tools/comic_art/env_<name>.py`, outputs
and `_game` / `_side` renders in the worktree's gitignored `vendor_src/env_art/out/`, then `python tools/comic_glb.py
--env vendor_src/env_art/out <names>`). `comic_check` measures them against their own sizes (`COMIC_ONLY`) and the
nodes the rules will reach for. Their rules are still data, so they stand in the room with pieces uncounted. What the
later lanes get:

| Model | Size (m, x / up / z) | Tris | Nodes | For |
|---|---|---|---|---|
| `brazier` | 1.4 / 1.37 / 1.5 | 1.8k | `brazier` (bowl, three legs, rim teeth, skull), `brazier_coals` (glowing, `comic_ember`), `brazier_ash` (the same coals dark, just under them: hide `brazier_coals` for "out"), `brazier_flame` (the flame cap; a designed effect may replace it) | brazier_spill, Kindle, torches_conduct |
| `brazier_spilled` | 2.1 / 1.6 / 2.2 | 2.0k | the bowl on its side, the coals in a ~2 m patch toward +Z at yaw 0 (turn it to the throw), `brazier_coals`, `brazier_flame` | the spilled state: swap the model |
| `pool` | 4 / 0.18 / 4 (a floor tile) | 1.0k | `pool` (flagstones, kerb), `pool_water` (the surface at y 0.075 and its ripple lines, `comic_water` / `comic_water_hi`) | ice_rink: give `pool_water` `designed_elements.facet_material()` or hide it under an ice slab |
| `hook_chain` | 0.9 / 2.6 / 0.75 | 1.4k | `hook_chain` (plate, bracket), `hook_swing` (chain, hook, red rag; origin at the bracket's eye, so it swings like the torch) | gallows: mounted 3.4 m up on a wall face, the hook's point ~1.1 m off the floor |
| `ledge` | 8.1 / 1.38 / 2.06 | 1.7k | `ledge` (one node: stone courses, a 0.55 m step along the front, coping, a red runner with a skull clasp) | High Ground: its back on a wall, the step side out |

### The training room with pieces

`rooms.gd` `ROOMS.training_pieces`, each `count`ed for the autotest:

| Piece | At | By |
|---|---|---|
| rubble | tile (-2, -6) | under the dummy at (-1.6, -4.5), where most breakers land |
| spikes | tile (-10, -2) | the keg corner: Molten Palm's carry comes down on it |
| barrel | (-11.2, -2) | the back of the spikes |
| crate | (-11, 1) | beside the barrel |
| grate | tile (6, -2) | under the dummy at (4.2, -3.2) |
| pool | tile (2, -6) | under the dummy at (1.6, -4.5) (counted, round 53: ice_rink) |
| brazier | (-5.8, -5.2) | behind the dummy at (-4.2, -3.2) (counted, round 53: brazier_spill) |
| hook | (-4, 3.4, -15.5) on the back wall | between a banner and a torch; a side wall shows it edge-on to the camera (not counted: ~11 m from the dummies, past `GALLOWS_REACH`) |
| hook | (7.47, 3.85, -7.47), yaw -45, on the face of the pillar at (8, -8) | toward the dummies, its point ~1.65 m up, the hung foe's feet ~0.85 m off the floor (counted, round 53: gallows) |
| ledge | (14.5, -4), yaw -90, on the right wall | level with the dummies, out of the bot's lanes (not counted) |
| torch | the back wall's middle one, (-2, 2.4, -15.5) | counted in this room only (`count_in_pieces`): torches conduct |

## The heretic's verbs

### Uproot (dark on a pillar; Overwhelm's LMB ending)

Overwhelm (hold H) pins one big foe; the window offers RMB **Abyss** (it sinks and spikes throw it up) or LMB
**Uproot** (`BREAKERS.OW.alt`, `void_element.gd`). With a pillar within `UPROOT_REACH` 6 m of the pinned foe (the
indicator's bracket marks it during the hang, env_target context `uproot`), the dive does not sink him: a tentacle
lashes round the pillar and tears it out of the floor (`breaker_alt_fx.uproot_tear`), and on landing it comes down
along the line pillar to foe (`uproot_club`, carried in when the foe is further than its 4 m length). The foe takes
`UPROOT_DAMAGE` 70 x `UPROOT_HEAVY` 1.25 and stays buried, foes along the fall line (`UPROOT_LINE_R` 1.5 m) take x0.6.
The pillar stays down as two rubble heaps, out of the swing anchors and the structure list, "KRR-RACK-THOOM!", until
the training rebuild. With no pillar near, Uproot is a short slam (`UPROOT_OPEN` 22), so Abyss is the open-floor ending.

| Case (cool_pass_check `_uproot_pair`, one big foe and one on the line; Abyss as rebuilt by the cool pass) | Abyss | Uproot |
|---|---|---|
| a pillar within reach | 170 | 244 |
| open floor | 197 | 71 |

Look: the tentacle is `void_tendril` (the sheet tendril), the chunks and dust are the designed sheets
(`DESIGNED.dust`, `env_target._chunk`), the pillar is the comic `pillar_decorated` itself; no polygons. Bot string:
`pillar alt hold` (slot `sig_pin`, the plain room).

Readability (round 52): on film the pillar lying on the foe was lost under the tentacle and the landing's effects. Now
the club has three beats (`breaker_alt_fx.uproot_club`): the tentacle hauls it up to `UPROOT_HOLD_LIFT` 1.4 m,
leaning `UPROOT_HOLD_LEAN` back, and holds it `UPROOT_HOLD` 0.16 real s as a flat silhouette in the void's light
(`Fx.flash_tint`; an ink one read as nothing on the dark floor); its drop shadow (a soft ink oval, the dash streak's material, `UPROOT_SHADOW_W` 1.9 m across the
fall line) is on the floor from the hold and darkens as it falls; the tentacle lets go as the fall starts, so the
pillar comes down in the clear, and a white flash marks the landing. The club starts two frames after the dive lands
(the landing frame took 250-320 ms to draw on film, and the first real-time step after it swallowed the whole hold).
Its hit comes `UPROOT_HOLD` and those two frames later than before; the damage is the same (244 / 71, cool_pass_check).
Still hard to read on film: the camera frames the dummies low and the breaker banner ("UPROOT n",
`designed_breaker.Screen`, not this lane's) sits over the fall line in the hold; decision for Zak / the spectacle
lane: move the banner off the pillar's line for Uproot, or frame the pillar.

### Powder Keg (magma on a barrel)

Any magma hit on a barrel sets it burning: Molten Palm's carry (the barrel is a collider on the walls' layer, so the
carry stops on it and the splat is magma), a molten foe splatted on it, or magma reaching a foe within `KEG_CATCH`
1.2 m of it (`void_element.mark(e, "molten")` calls `env_piece.marked`). During the wind-up the structure indicator
brackets the barrel when it is along his facing within the palm's reach (env_target context `keg`). Burning, the
designed `tell_molten` licks it with "FSSSS!"; `KEG_FUSE` 1.2 s later it bursts by the molten rule: `KEG_DAMAGE` 30
(the Burst rule's x1.5 on 20, x his damage mult) to everyone within `KEG_R` 3 m, knockback, all left molten, crates
in it broken and other barrels catching (a chain), "KA-BLOOOM!" over the designed meteor burst and stave chips. The
barrel is used up (rebuilt in training). Bot string: `keg L L L H H` (slot `big_3`, the room with pieces): the palm
carries the dummies over the spikes into the barrel and the crate, Undertow pins them, and Meteor Fall dives on the
pile as the keg goes.

The word waits its turn (round 52): ComicFx shows one word at a time (`replace`), so Meteor Fall's word, landing as
the keg went, wiped "KA-BLOOOM!" in the same beat. `_keg_word` holds it while he is in a breaker's leap and until
`KEG_WORD_GAP_MS` 450 after the last word (at most `KEG_WORD_WAIT` 1.2 real s), `KEG_WORD_UP` 2.8 m over the barrel.

### Frost Wall (ice on a grate)

Frost Spear (L L H) planted on a grate, or within `REACH` 1 m of one, raises a real wall of ice `WIDTH` 6 m wide on the
grate's far side from him, square to his line (round 52: it was 4 m along the grate's edge on the axis he was most
along, and a diagonal Harpoon row's ends flew past it; now it follows his angle) (`scripts/frost_wall.gd`, `frost_spear.frost_wall()`), for `LIFE` 6 s. The spear goes into the wall: it
melts `SPENT_INTO_WALL` 0.35 s after, so there is no vault onto it (the wall is the payoff on a grate). It is a StaticBody3D on the
walls' layer, so `thrown_foe.clear_from` stops on it, and env_target knows it as a wall (`add_wall_id`, id
`frost_wall`): every wall ending gets a wall in the open (Slapshot aims at it from the cursor's pick, Pinwheel and
Ricochet see it, a splat on it carries the wall mark for Meteor Fall). One splat shatters it `SHATTER_AFTER` 0.25 s
later (so the rest of a volley lands) with the designed `ice_shatter`; otherwise it melts. The grate reads frosted
while it stands. Look: three faceted `designed_elements.ice_block` meshes squashed to `THICK` 0.7 m, rising with a
back-ease, a `frost_mark` and dust at its foot, "KRRSSHK!"; no crystals. Shatter (round 52, the proposal's x1.6): an ice cube (a frozen foe
flying, or any `water` throw) splatting on it pays `SHATTER_MULT` 1.6 on the wall's mult; the rest of a volley inside
`SHATTER_AFTER` gets it too. Four blocks (`BLOCKS`), the middle two taller. Bot string: `grate alt L L H wait D L H` (the room with pieces): Harpoon's row is punched into the wall.

| Case (env_breaker_check, three cubes, a 4 m grate edge) | Damage |
|---|---|
| Slapshot into the Frost Wall | 362 (round 51: 153 at 4 m wide and x1; the 6 m wall stops all three cubes, x1.6 each) |
| Slapshot in the open | 63 |

Decision for Zak: 362 is x5.7 the open and x1.6 a real wall's Slapshot. It needs a spear planted on a grate first, so
it is the setup's payoff; if it reads too strong, `SHATTER_MULT` is the knob.

### Live Floor (storm on a grate)

A storm hit that charges a foe standing on a grate (Live Wire's jolts, Grounded, Galvanize: `void_element.mark(e,
"charged")` calls `env_piece.marked`) makes the grate live for `LIVE_S` 4 s (more storm on it refreshes it). Live, it
charges everyone on it every `LIVE_TICK` 0.5 s, four designed `arc_crawl` loops run over the tile with "BZZZT!", and
Short Circuit treats it as a source: its reach is measured from the grate too (foes within `SC_REACH` 12 m of a live
grate are in the arcs), and an arc may start from the grate itself. Readability (round 52): the four middle crawls sat under the pile; now `LIVE_EDGE_CRAWLS` 8 more, `LIVE_EDGE_SIZE`
2.4, stand on the tile's edge (corners and edge middles), and every tick `_live_rim` runs a lime bolt (`bolt_path`,
`LIVE_RIM_W` 0.3) round the tile's four edges, so the square reads live from the camera past the foes on it.
Then it goes cold. Bot string: `grate alt L H H`
(slot `big_1`, the room with pieces): Live Wire's jolts on the dummy on the grate make it live, and Short Circuit
lands.

| Case (env_breaker_check: Short Circuit, a foe 20 m off, a grate 14 m out) | Damage to the far foe |
|---|---|
| the grate live | 25 |
| the grate cold | 0 |

### Torches conduct (storm on a lit torch; round 52, build order item 5)

A storm hit that charges a foe within `CONDUCT_REACH` 3.5 m (flat) of a lit torch (`void_element.mark(e, "charged")`
calls `env_piece.marked`, then `conduct_near`) makes the nearest torch conduct (`hit(torch, "wind", foe, "element")`,
verb `conduct`, state `conducting` for `CONDUCT_S` 3 s after the last storm by it). The current runs along the wall:
`torch_chain()` is the torch, then every lit torch within `CONDUCT_LINK` 8.5 m of one already in (the training room's
three, 8 m apart, are one chain). A lime `bolt_path` runs from the charged foe to the torch's flame and on from torch
to torch, each flares (a storm star, an `arc_crawl` on the flame while it conducts, "ZZRAK!", a scale pop), and each
torch zaps the foes within `CONDUCT_REACH` of it (not the source, not flying) for `CONDUCT_DAMAGE` 8 x his damage
mult, with a bolt from its flame, and charges them. One relay per torch per `CONDUCT_CD` 0.45 real s (Live Wire jolts
every 0.1 s). Live Wire's jolts, Galvanize's zaps and Short Circuit's arcs all charge, so all three relay; the relay's
own charges don't relay again (`_relaying`). Short Circuit also takes conducting torches as sources (an arc may start
from a flame) and reaches `CONDUCT_REACH` round each (`void_element._short_circuit`).

The indicator: in the storm windows (a breaker with `wire` or Short Circuit as its `alt`: Live Wire's, Worldbreaker's)
and during Live Wire and Galvanize themselves, env_target's context `conduct` (mode `torch`, `_conduct_ctx`) brackets
the conducting torch nearest him, on its flame (`TORCH_BRACKET_*`, no floor ring); the others show their crawl.

It is an element verb (`EXCLUSIVE.wind.torch`), always on for the heretic, not the proposal's `Kit.has()` upgrade
(decision for Zak: gate it behind a run upgrade later). Bot string: `torch alt L H H` (slot `big_1`, the room with
pieces, layout `torch`): three dummies under the back wall's middle torch, the fourth ~10 m off under the torch at
(-10, 2.4, -15.5), past the tentacles' `SEIZE_RANGE` 8; Live Wire's jolts make the middle torch conduct, the current
runs the wall to the far dummy, and Short Circuit's arcs come out of the torches' flames. The autotest
counts `conduct=3`.

| Case (env_piece_check `_conduct`) | The foe 8 m along the wall |
|---|---|
| storm on a foe under the middle torch | 8 (`CONDUCT_DAMAGE`), charged |
| the torches out | 0 |

## The heretic's flourishes (round 53, env-flourish; proposal build order items 6-8)

Three verbs on the pieces that had only a look, in `scripts/env_flourish.gd` (static functions over the nodes, like
`void_element.gd`, plus two small nodes: `Hang` and `RinkWatch`). Each is a `Kit.has()` upgrade (`kit.gd`
`UPGRADES`: `gallows`, `ice_rink`, `brazier_spill`) and also plays in any room whose `rooms.gd` `ROOM_RULES` has
`flourishes: true` (only the training room with pieces), so all three are there to practise. `env_flourish.on(id)`
is the gate. The plain room is unchanged: its rule is false and it has no hook, pool or brazier.

### Gallows (dark on a hook; the counter's Ricochet)

A perfect counter's Ricochet (counter.gd `ricochet_target`) takes the attacker to an empty hook whose point is within
`GALLOWS_REACH` 10 m (flat) of it, over any nearer foe or wall. The throw flies over the other foes (`solid: false`)
and, when the hook is on a wall or pillar face, splats on it at `RICOCHET_WALL_MULT` x `GALLOWS_MULT` 1.3. Then
`env_flourish.hang()` hoists it up under the hook's point (`hook_point()`, the bottom of `hook_swing`'s mesh): the
foe is bound (`floor_bind` meta `x_bound`) for `GALLOWS_HANG` 2.5 s, staggered, and `hook_swing` swings (a damped
`GALLOWS_SWING` 0.45 rad) with the foe tilting under it. Any hit on the hung foe is a Snap (void_element `_pay` "snap",
counted in `improv_paid["bound"]`): the matrix's own Snap for an element hit, or the Hang's when the hit was dark or
a melee swing the matrix wouldn't pay. The Snap, the time running out, another move taking it, or its death lets it
drop; the hook swings down to rest over `GALLOWS_SETTLE` 1.4 s and is empty again. Word "SHNK-CLANK!", a void hit and
dust on the hook. The hook and the foe are camera-cued (`frame_cue_ms`) for `GALLOWS_CUE_MS` 2.8 s.

The indicator: env_target CTX `gallows` (mode `hook`) brackets the hook during the counter window. The cursor can
choose a wall or pillar instead (kinds hook / wall / pillar): `ENV.chosen(hero, "gallows")` wins over the hook.
A pillar Uproot tears out takes its hook with it (`topple`).

| Case (counter_check `_gallows`, the room with pieces) | The attacker's splat |
|---|---|
| Ricochet onto the pillar's hook (gallows) | 146 (x1.30), then hung 2.5 s, every hit a Snap |
| the same counter, the flourish off: onto the pillar | 112 (`RICOCHET_WALL_MULT` 2.5), bound 1.6 s |
| Ricochet in the open | 45 |

Bot string: `hook counter D` (slot `counter`, the room with pieces, layout `hook`): the swinging dummy between him and
the pillar's hook, ~5 m from its point.

### Ice Rink (ice by the pool)

The pool's watch (`RinkWatch`, a child of the pool, polls every `RINK_POLL` 0.1 s): a foe newly frozen (in a cube or
`frozen_t`) within `RINK_NEAR` 1 m of the tile, or a Frost Spear planted within it, freezes the pool for `RINK_S` 6 s
(renewed by more ice). `pool_water` hides and a 4 x 4 pane mesh in `designed_elements.facet_material("water")` (the
ice block's facets, no crystals) scales in over it, with a frost burst in the middle and four frost marks spreading to
the corners, "KRRRIK!". While frozen, `rink_glint` (`tools/vfx_gen/gen_flourish.py`) glints come and go on it.

On the frozen pool:
- A cube's flight (thrown_foe: `slide`, an ice throw, or a foe in its cube) whose line crosses it goes `RINK_EXTRA`
  6 m further and never slows (`_rink`), so Slapshot (10 m `SLIDE_REACH`), Avalanche's topple and Ice Cube's bowl
  reach walls they can't in the open.
- A foe knocked onto it (hit in the last `RINK_KNOCKED_MS` 0.7 s, moving over 1 m/s) is encased and slides on at its
  speed (at least `RINK_SLIDE_MIN` 4 m/s) until it leaves the tile, "SKRRRT!".

| Case (env_breaker_check `_ice_rink`: a wall 14 m ahead) | Three cubes | The furthest cube |
|---|---|---|
| Slapshot over the frozen pool | 153 (all shatter on the wall) | 13.5 m (on the wall) |
| Slapshot in the open | 63 | 11.4 m (short) |

Bot string: `pool alt D L H` (slot `dash_ender_l`, layout `pool`): Harpoon's cubes on the pool freeze it, and
Slapshot punches the row over the ice into the back wall ~11 m off.

### Brazier Spill (magma by the brazier; Lava Leash)

The brazier is lit when placed (coals and flame; `out` shows its ash). Lava Leash's seam (`lava_leash._seam_add`
calls `leash_seam`) passing within `SPILL_NEAR` 1.5 m of a lit brazier tips it in: its parts hide and
`brazier_spilled` takes their place, its coals turned to face the seam. The coals run the seam on `SPILL_EXTEND` 2 m
(a fissure), leave a molten patch (`SPILL_PATCH_R` 1.1 m, everyone in it molten every 0.5 s for `SPILL_PATCH_S` 4 s), and
for `SPILL_FRESH_MS` 4.5 s Hellseam erupts along the coals too and hits x `SPILL_HELLSEAM` 1.25 (the proposal's
number). "KLANG-FWOOM!", dust, chips, a magma pool. Any magma on a foe within `LIGHT_NEAR` 1.5 m of an out brazier
lights it ("FWUMP!"). The spilled brazier is used up and rebuilds lit with the training room's rebuild.

The indicator: env_target CTX `brazier` brackets the lit brazier the leash's seams will tip, through Lava Leash's
reach beat (`leash_brazier()`: the grabs on their way, or before them Molten Palm's foes toward the pile).

| Case (lava_leash_check `_brazier_spill`) | |
|---|---|
| Hellseam's pile hit with a fresh spill / none | 58 / 46 (x1.25) |
| a foe at the spilled coals' end, Hellseam with a fresh spill / none | 25 / 0 |
| a foe in the coals' patch | molten |

Bot string: `brazier L L L H L` (slot `cross_dark_magma`, layout `brazier`): Molten Palm carries the dummies past the
lit brazier and the leash drags them back over it.

### The banner and the cued pieces

`designed_breaker` `Screen._foe_under` (the breaker name banner drops to `CALL_Y_LOW` off a cued foe) also checks the
room's pieces with a fresh `frame_cue_ms` (`_piece_under`, points up the piece's own axis, so a pillar falling too):
Uproot's pillar (`UPROOT_CUE_MS` 2.2 s from the dive), a hook with a foe hung on it, a spilled brazier.

## Files

- `scripts/env_piece.gd`: `PIECES`, `EXCLUSIVE`, `BUILT`, `HERO_ELEMENTS`, `RULES_BY_ELEMENT`; `place()`, `hit()`,
  `near()`, `under()`, `gap()`, `usable()`, `struck()` (the piece a throw stopped on), `splat_mult()`, `landing()`
  (a breaker came down), `wall_splat()` (banners), `use_up()`, `rebuild()`, `report()` (the `[env]` line's
  `pieces=N/N` and the verbs). Static counters `counted`, `touched`, `verbs`, reset by `begin()`.
- `scripts/rooms.gd`: `PILLARS` (main.PILLARS is it), `ROOMS.training` (today's pillars, torches, banners, corner
  clutter), `ROOMS.training_pieces`, `layout(room)`, `floor_spots(room)`.
- `scripts/main.gd` `_build_arena`: the floor tiles (skipping a floor piece's tile; random grates only in the plain
  room), the walls, the edge rubble, then `ENV_PIECE.place()` for each `ROOMS.layout(Game.room)` entry.
- `scripts/env_target.gd`: `add_pillar()` returns its id, `add_prop(node, tag, r)` (a structure of its own kind),
  `add_wall_id()`, `remove(id)`. With no `kinds`, picks see only walls and pillars, so a barrel never becomes
  Pinwheel's wall.
- `scripts/thrown_foe.gd`: `_aim` finds the piece a walled flight will stop on (`_piece`); `_burst` pays its
  `splat_mult`, calls `hit(piece, el, hero, "throw")`, tears banners, and x1.5 on spikes.
- `scripts/void_element.gd` `breaker_impact`: `ENV_PIECE.landing(hero, at)` first. Uproot: `OW.alt`, `UPROOT_*`,
  `uproot_pillar()`, `uproot_target()`, `uproot_dive()` (from `hero_leap._start_dive`), `_uproot()`, `_uproot_hit()`.
- `scripts/env_piece.gd` Powder Keg: `KEG_*`, `_keg()`, `_keg_burst()`, `marked()`, `molten_near()`;
  `void_element.mark` calls `marked()`; `thrown_foe._burst` hits the piece with magma when the foe is molten;
  `env_target` context `keg` (Molten Palm's wind-up, toward a barrel).
- `scripts/env_piece.gd` Live Floor: `LIVE_*`, `_live()`, `_live_tick()`, `on_tile()`, `live_grates()`;
  `void_element._short_circuit` adds the foes near live grates to its arcs and the grates to its sources.
- `scripts/frost_wall.gd`: `raise()`, `current()`, `splat()`, `shatter()`, `melt()`, `struck()`;
  `scripts/frost_spear.gd` `plant()` calls `frost_wall()`; `thrown_foe._burst` shatters it on a splat.
- `scripts/breaker_alt_fx.gd` (the Uproot region): `uproot_tear`, `uproot_club` (round 52: the hold, `_uproot_shadow`,
  `_shade`), `uproot_open`.
- `scripts/env_piece.gd` torches conduct (round 52): `CONDUCT_*`, `_conduct()`, `torch_chain()`, `_relay()`, `_flare()`,
  `_conduct_tick()`, `conducting_torches()`, `conduct_near()`; Live Floor's `_live_rim()`; the keg's `_keg_word()`.
- `scripts/env_target.gd`: CTX `conduct`, `_conduct_ctx()`, mode `torch` in `resolve()`, the torch bracket in `_draw()`.
- `scripts/rooms.gd`: `ROOM_DEFS` (round 57; round 52's `ROOM_RULES`), `REAL_ROOM`, `rule()`, `rebuild()`;
  `count_in_pieces` on the middle torch (counted where a room has `count_marked`).
- `scripts/game.gd`: `room_setting` (saved under `training/room`), `room` (this run), `toggle_room()`,
  `room_label()`; `scripts/menu_screen.gd` Settings row.
- `scripts/env_flourish.gd` (round 53): `on()`, gallows (`hook_point()`, `hooks()`, `gallows_hook()`, `hang()`,
  `Hang`), ice rink (`RinkWatch`, `rink_extra()`, `rink_ice()`), brazier spill (`leash_seam()`, `spill()`, `light()`,
  `spill_seams()`, `leash_brazier()`); `placed()` / `restore()` from `env_piece.place` / `rebuild`. `counter.gd`
  `ricochet_target` / `_gallows_hit`, `thrown_foe._aim` (`_rink`), `lava_leash._seam_add`, `void_element._hellseam`,
  `env_target` CTX `gallows` / `brazier` and mode `hook`, `designed_breaker` `_piece_under`.
- `scripts/training_bot.gd`: `room` on a BOT_STRINGS entry plays it only in that room (`active()`);
  `BOT_PIECE_LAYOUTS` (`keg`, `grate`) stand him and the dummies by a piece; the `[env]` line ends
  `room=<plain|pieces> pieces=N/N uproot= keg= frost_wall= live_floor=`.

## Invariants

- The plain room is today's arena: the same pillars with the same 0.75 x 4 m colliders at `rooms.PILLARS`, the
  same torches, the same random floor and walls, and no other live piece (env_piece_check).
- Every hit on a piece goes through `hit()`; it plays the element's verb only when `usable()`.
- A used-up piece leaves env_target and its collider goes off; it stays gone for the room unless the room's
  `ROOM_RULES` say `rebuild` (both training rooms do; a real room doesn't).

## Testing

- `tests/env_piece_check.gd` (in `agent.sh check`): the plain room's pieces and colliders; the room with pieces;
  a thrown foe breaks the barrel (x1 on half of x2, x1.5 on the spikes: 15 from 10) and the crate (10); a breaker
  landing breaks a crate and throws rubble chunks; a banner tears; everything rebuilds after `REBUILD_S`; `usable()`.
- `tests/env_piece_check.gd` `_keg`: magma on a foe by the barrel sets it burning, nothing during the fuse, then 30 to
  the foe beside it and to one 2.5 m off, both molten, the barrel used up.
- `tests/env_piece_check.gd` `_frost_wall`: a spear by the grate raises it on the far edge, the grate frosted, a wall in
  env_target, on the walls' layer (a ray stops on it), none with no grate near, melted and gone after `LIFE`.
- `tests/env_breaker_check.gd` (in `agent.sh check`): Slapshot into the Frost Wall pays more than in the open (x1.3 at least).
- `tests/env_piece_check.gd` `_live_floor`: storm on a foe on the grate makes it live, the other foe on it is charged
  by the grate, it is a live grate for Short Circuit, cold after `LIVE_S`.
- `tests/env_breaker_check.gd` `_live_floor_short_circuit`: Short Circuit reaches a foe 20 m off from a live grate, not
  from a cold one.
- `godot --headless --path . -- --autotest --room=pieces`: `pieces=5/5 uproot=1 keg=1 frost_wall=1 live_floor=4`,
  strings 44/44.
- `tests/cool_pass_check.gd` `_uproot_pair` (moved there from void_arm_check by the cool pass): Uproot beats Abyss by a pillar (x1.3 at least), Abyss beats Uproot in
  the open (x1.5 at least); the pillar is toppled, out of the swing anchors, and the foes buried.
- `godot --headless --path . -- --autotest --room=pieces`: the `[env]` line's `pieces=N/N`.
- Look (windowed): `godot --path . -s tests/piece_shots.gd -- --room=pieces [--tag=x]` puts the hero beside each
  placed brazier, pool, hook and ledge from the game camera, then lines every new model up with the hero and kit pieces
  (`user://piece_shots/`, each shot also at 800x450). `comic_check` covers their files, sizes and nodes.
- `tests/env_piece_check.gd` `_frost_shatter` (round 52): a foe into the Frost Wall 20 (x2), an ice cube 32 (x1.6 more);
  on a diagonal the wall faces him. `_conduct`: the relay above, once per `CONDUCT_CD`, lit again after `CONDUCT_S`,
  nothing far from a torch or with them out, nothing for the prince. `_room_rules`: the rebuild rule per room.
- `agent.sh check` (round 52): the second autotest is `--autotest --kit=full --room=pieces` (folded into the kit run,
  not a third run: each is about 3 min) and fails unless its `[env]` line has `pieces=N/N` and every built verb
  (`uproot keg frost_wall live_floor conduct`) above 0. Measured: `pieces=6/6 uproot=1 keg=1 frost_wall=1
  live_floor=4 conduct=3`, strings 47/47, upgrades 1/1, 190 s.
- Round 53: `tests/counter_check.gd` `_gallows`, `tests/env_breaker_check.gd` `_ice_rink`, `tests/lava_leash_check.gd`
  `_brazier_spill` (numbers above); the land check's `[env]` line also needs `gallows ice_rink brazier_spill` above 0.
  Measured: `pieces=9/9 uproot=1 keg=1 frost_wall=1 live_floor=4 conduct=3 gallows=2 ice_rink=7 brazier_spill=1`,
  strings 50/50.

### Not verified

- The conduct bracket was not filmed in a window long enough to judge it against Live Wire's own tentacles (it
  shows on the nearest conducting torch only).
- The 6 m Frost Wall against a real diagonal Harpoon row in play (the bot's row is straight); the check covers the
  facing, not a diagonal volley.
- Real rooms (`rebuild: false`) exist only as the rule: nothing builds one yet.
- Round 53: the hang against a real enemy (only the dummy and stand-ins); a foe knocked onto the rink by a real move
  (the check sets the knock by hand); Avalanche's topple and Ice Cube's bowl over the rink (they take the same
  thrown_foe path as Slapshot's cubes); the out brazier in play (no room places one out).
