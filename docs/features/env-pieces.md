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
  by a dummy, makes the banners live, and rebuilds every used-up piece `REBUILD_S` 6 s later with a dust pop.

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
- `scripts/void_element.gd` `breaker_impact`: `ENV_PIECE.landing(hero, at)` first.
- `scripts/game.gd`: `room_setting` (saved under `training/room`), `room` (this run), `toggle_room()`,
  `room_label()`; `scripts/menu_screen.gd` Settings row.
- `scripts/training_bot.gd`: `room` on a BOT_STRINGS entry plays it only in that room (`active()`);
  `BOT_PIECE_LAYOUTS` (`keg`, `grate`) stand him and the dummies by a piece; the `[env]` line ends
  `room=<plain|pieces> pieces=N/N uproot= keg= frost_wall= live_floor=`.

## Invariants

- The plain room is today's arena: the same pillars with the same 0.75 x 4 m colliders at `rooms.PILLARS`, the
  same torches, the same random floor and walls, and no other live piece (env_piece_check).
- Every hit on a piece goes through `hit()`; it plays the element's verb only when `usable()`.
- A used-up piece leaves env_target and its collider goes off; it stays gone for the room, except in training.

## Testing

- `tests/env_piece_check.gd` (in `agent.sh check`): the plain room's pieces and colliders; the room with pieces;
  a thrown foe breaks the barrel (x1 on half of x2, x1.5 on the spikes: 15 from 10) and the crate (10); a breaker
  landing breaks a crate and throws rubble chunks; a banner tears; everything rebuilds after `REBUILD_S`; `usable()`.
- `godot --headless --path . -- --autotest --room=pieces`: the `[env]` line's `pieces=N/N`.
