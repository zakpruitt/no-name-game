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

### The pieces

| Piece | Shared rule (anyone) | States | In the game | Art |
|---|---|---|---|---|
| wall | a thrown foe splats on it at the throw's `wall_mult`; the wall endings aim at it | none | yes (main.gd's walls) | `wall` |
| pillar | a wall for splats, the R anchor, the pillar slam, shakes on landings | whole / cracked / toppled | yes, both rooms | `pillar_decorated` |
| torch | swings when a foe splats on the wall under it | lit / out | yes, both rooms | `torch_mounted` |
| barrel | a thrown foe breaks it: a splat at half the wall's mult (at least x1), staves fly | whole / burning / gone | with pieces | `barrel_large` |
| crate | a thrown foe, a breaker landing within 1.5 m, or a burst keg breaks it | whole / gone | with pieces | `crates_stacked` |
| chest | heavy: a wall for splats, never breaks | shut / open | a look (the corner) | `chest_gold` |
| banner | a foe splatted within 1.4 m of it tears it down | hanging / torn / burning | live with pieces | `banner_patternA_red` |
| grate | floor to anyone without storm or ice | cold / live / frosted | with pieces | `floor_tile_big_grate` |
| spikes | a thrown foe that comes down on it takes x1.5 | up / down | with pieces | `floor_tile_big_spikes` |
| rubble | a breaker landing on it throws three chunks, 6 to everyone within 2 m | none | with pieces | `floor_tile_large_rocks` |
| brazier | (data) knocked over: a 2 m fire patch, molten | lit / out / spilled | no | **stub**: `column` |
| pool | (data) foes move at 0.8, molten quenched | water / frozen / live / steam | no | **stub**: `floor_tile_large_rocks` |
| hook | (data) a wall for everyone | empty / hung | no | **stub**: `wall_broken` |
| ledge | (data) a walkway 2.5 m up, its face a wall | none | no | **stub**: `wall_arched` |

**Art.** The ten pieces in the game use the comic dungeon kit (`assets/comic/dungeon/`). The brazier, pool, hook and
ledge have no comic piece yet; their `PIECES` rows name an existing model as a stand-in (`stub: true`) and none of
them is placed in a room. They belong to later lanes (brazier_spill, ice_rink, gallows, High Ground), which make them
with the `comic-asset-kit` skill in one batch.

### The training room with pieces

`rooms.gd` `ROOMS.training_pieces`, each `count`ed for the autotest:

| Piece | At | By |
|---|---|---|
| rubble | tile (-2, -6) | under the dummy at (-1.6, -4.5), where most breakers land |
| spikes | tile (-10, -2) | the keg corner: Molten Palm's carry comes down on it |
| barrel | (-11.2, -2) | the back of the spikes |
| crate | (-11, 1) | beside the barrel |
| grate | tile (6, -2) | under the dummy at (4.2, -3.2) |

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

### Frost Wall (ice on a grate)

Frost Spear (L L H) planted on a grate, or within `REACH` 1 m of one, raises a real wall of ice along the grate's far
edge from him (`scripts/frost_wall.gd`, `frost_spear.frost_wall()`), for `LIFE` 6 s. It is a StaticBody3D on the
walls' layer, so `thrown_foe.clear_from` stops on it, and env_target knows it as a wall (`add_wall_id`, id
`frost_wall`): every wall ending gets a wall in the open (Slapshot aims at it from the cursor's pick, Pinwheel and
Ricochet see it, a splat on it carries the wall mark for Meteor Fall). One splat shatters it `SHATTER_AFTER` 0.25 s
later (so the rest of a volley lands) with the designed `ice_shatter`; otherwise it melts. The grate reads frosted
while it stands. Look: three faceted `designed_elements.ice_block` meshes squashed to `THICK` 0.7 m, rising with a
back-ease, a `frost_mark` and dust at its foot, "KRRSSHK!"; no crystals. The x1.6 shatter bonus from the proposal is
not built: the wall pays Slapshot's own wall mult. Bot string: `grate alt L L H D L H` (the room with pieces).

| Case (env_breaker_check, three cubes, a 4 m grate edge) | Damage |
|---|---|
| Slapshot into the Frost Wall | 153 |
| Slapshot in the open | 63 |

### Live Floor (storm on a grate)

A storm hit that charges a foe standing on a grate (Live Wire's jolts, Grounded, Galvanize: `void_element.mark(e,
"charged")` calls `env_piece.marked`) makes the grate live for `LIVE_S` 4 s (more storm on it refreshes it). Live, it
charges everyone on it every `LIVE_TICK` 0.5 s, four designed `arc_crawl` loops run over the tile with "BZZZT!", and
Short Circuit treats it as a source: its reach is measured from the grate too (foes within `SC_REACH` 12 m of a live
grate are in the arcs), and an arc may start from the grate itself. Then it goes cold. Bot string: `grate alt L H H`
(slot `big_1`, the room with pieces): Live Wire's jolts on the dummy on the grate make it live, and Short Circuit
lands.

| Case (env_breaker_check: Short Circuit, a foe 20 m off, a grate 14 m out) | Damage to the far foe |
|---|---|
| the grate live | 25 |
| the grate cold | 0 |

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
- `scripts/breaker_alt_fx.gd` (the Uproot region): `uproot_tear`, `uproot_club`, `uproot_open`.
- `scripts/game.gd`: `room_setting` (saved under `training/room`), `room` (this run), `toggle_room()`,
  `room_label()`; `scripts/menu_screen.gd` Settings row.
- `scripts/training_bot.gd`: `room` on a BOT_STRINGS entry plays it only in that room (`active()`);
  `BOT_PIECE_LAYOUTS` (`keg`, `grate`) stand him and the dummies by a piece; the `[env]` line ends
  `room=<plain|pieces> pieces=N/N uproot= keg= frost_wall= live_floor=`.

## Invariants

- The plain room is today's arena: the same pillars with the same 0.75 x 4 m colliders at `rooms.PILLARS`, the
  same torches, the same random floor and walls, and no other live piece (env_piece_check).
- Every hit on a piece goes through `hit()`; it plays the element's verb only when `usable()`.
- A used-up piece leaves env_target and its collider goes off; it stays gone for the room, except in training
  (both training rooms rebuild it).

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
