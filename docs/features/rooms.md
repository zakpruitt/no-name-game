# Rooms as data: the flooded cistern and the forge hall

Round 57 (rooms lane). Zak wants the environment to be "a big part of what you can do", and later to be shaped by
items. Rounds 51-53 made the pieces data (`env_piece.gd`, [env-pieces.md](env-pieces.md)); this makes the **room**
data too, so a room is a table entry and a run (or an item) can build, pick or change one without code. Two new
training rooms each favour a different pair of the heretic's elements, and each has a combo that only works there.
The world behind them: [environment-lore.md](../design/environment-lore.md).

## What it does

- **Room picker.** Settings "Room (on restart)" cycles plain, with pieces, flooded cistern, forge hall (saved);
  `--room=plain|pieces|cistern|forge` for one run (the game, the autotest, `string_film`, `piece_shots`). The
  autotest still plays the plain room unless `--room=` is given.
- **A room is data** (`rooms.gd` `ROOM_DEFS`): label, size, layers of piece placements (`ROOMS` lists, each entry with
  its position and yaw), the tags it makes live, its rules (`rebuild`, its own `flourishes`, `links`), a lore line,
  and showcase strings. `ORDER` is the picker.
- **Plain and with pieces are unchanged**: the same entries in the same order (`layout()`), so every bot string, the
  `--room=pieces` autotest line and `env_piece_check` play the same.
- **The flooded cistern** (ice and dark): an aqueduct of four pools end to end along the back wall with the sluice's
  cold iron grate at its east end, the dummies' grate where the room with pieces has it, three hook chains (two over
  the water on the back wall, one on the east pillar's face toward the dummies) and a ledge on the west wall. Flourishes
  `gallows` and `ice_rink`; `links: ["pool"]`.
- **The forge hall** (magma and storm): a powder line up the room, three kegs 3 m apart between two lit braziers, and
  three bonded iron plates across the hall under the dummies. Flourish `brazier_spill`; `links: ["grate"]`.
- **Hazards are hero-safe** (orchestrator's decision): kegs, live plates and spilled coals reach foes only
  (`FOES.near`, the `enemies` group); `rooms_check` stands him in each and checks his hp. Open question in the lore doc.

### What each new room makes possible

| Room | Showcase (bot tokens) | What happens | Why the room with pieces can't |
|---|---|---|---|
| cistern | **Down the channel** (`alt D L H`: Dash Stab, Harpoon, Slapshot) | Harpoon's cubes by the west pool freeze the whole channel (one body of water); Slapshot sends the row the length of it, +6 m per frozen pool (24 m), and it shatters on the east wall ~21 m off, "KER-SMASH!" | one pool: +6 m, the row stops by ~17 m |
| forge | **Powder line** (`L L L H H`: Molten Palm, Undertow, Meteor Fall) | the palm carries the dummies into the middle keg; it bursts, both kegs beside it catch and burst 1.2 s later, and each tips the lit brazier past it: two coal runs, two molten patches, Hellseam fresh on both | one barrel, its brazier 6 m off |
| forge | **Bonded plates** (`alt L H H`: Live Wire, Short Circuit) | Live Wire's jolts on the dummies on the east plate make all three plates live; the dummy on the west plate, ~11 m off and past the tentacles' reach, is charged by the floor and Short Circuit arcs from every plate | one grate |

### The rules this needed (all no-ops in the plain room and the room with pieces)

- **Linked floor tiles** (`ROOM_DEFS.links`, `env_piece.linked(n)`): in a room that links a tag, floor pieces of it
  that share an edge are one piece for their verbs (a flood fill over touching tiles). Pools: `RinkWatch.freeze()`
  freezes every linked pool. Grates: `env_piece._live()` makes every linked grate live (and counts each touched).
  The room with pieces links nothing, and has one pool and one grate anyway.
- **A cube's slide counts every frozen pool** (`env_flourish.rink_extra`): `RINK_EXTRA` per frozen pool its line
  crosses, the line looked along again as it grows. One pool is `RINK_EXTRA`, as before (`env_breaker_check _ice_rink`
  unchanged).
- **A keg's burst tips a lit brazier** within `KEG_R` (`env_flourish.keg_spill`, called from `env_piece._keg_burst`),
  away from the blast, by `spill()` (the same coals, patch and fresh Hellseam as Lava Leash's tip; verb
  `keg_spill`). Needs `brazier_spill` on (the forge's flourish, or the Kit upgrade). In the room with pieces the
  brazier is 5.7 m from the barrel's edge, out of reach.
- **Flourishes per room**: `ROOM_DEFS.flourishes` is a list of ids; `env_flourish.on(id)` is `Kit.has(id) or
  rooms.flourish(Game.room, id)` (was one boolean for all three).

## Files

- `scripts/rooms.gd`: `ROOMS` (`training`, `training_pieces`, `cistern`, `forge` placement lists), `ORDER`,
  `ROOM_DEFS`, `REAL_ROOM`; `def_of()`, `rule()`, `rebuild()`, `flourish()`, `links()`, `known()`, `label()`,
  `next_room()`, `showcase()`, `layout()`, `floor_spots()`. Round 52's `ROOM_RULES` is folded into `ROOM_DEFS`.
- `scripts/game.gd`: `--room=` takes any `rooms.known()` name; `toggle_room()` cycles `ORDER`; `room_label()`.
- `scripts/env_piece.gd`: `linked()`, `_live()` spreads (`_linking`), `_keg_burst()` calls `keg_spill`.
- `scripts/env_flourish.gd`: `on()`, `rink_extra()` per pool, `RinkWatch.freeze()` spreads (`_linking`), `keg_spill()`.
- `tests/rooms_check.gd` (in `agent.sh check`): below.
- `tests/string_film.gd`: `--showcase` films the room's showcases from their spots (`_showcase()` sets the dummies'
  homes and the bot's start, `_showcase_start()` stands him on the showcase's start and facing after the bot's reset,
  before its first press); `--overview` films from a fixed camera over the whole room; the INDEX lines carry his spot,
  facing, `_brk_dir` and each dummy's spot in showcase mode.
- `tests/piece_shots.gd`: `<tag>_overview.png`, the whole room from high up (any `--room=`).

## Invariants

- `layout("plain")` and `layout("pieces")` return the same entries as before round 57, in the same order (`main.gd`'s
  random floor and walls draw `randf()` in the same order too: the room never changes what is drawn for it).
- Every room in `ORDER` is a training room: `rebuild` true. A name not in `ROOM_DEFS` is a real room (nothing rebuilds,
  no flourishes, no links): `env_piece_check _room_rules` still checks `rooms.rebuild("hall")` is false.
- Every piece lies inside the room's size, floor pieces sit on tile centres one per tile, and no two standing pieces'
  footprints overlap (a standing piece may stand on a floor tile: the keg corner's barrel on the spikes).
- Keep pieces off the tiles touching the pillars at (±8, -8) and (±8, 7): those tiles have a pillar at their corner.
- No hazard hurts the hero.

## Extending

- **A new room**: a placement list in `ROOMS`, an entry in `ROOM_DEFS` (layers usually `["training", "<yours>"]`),
  its name in `ORDER`. `rooms_check` then checks it loads, fits and doesn't overlap. Give it a showcase and add its
  state to `rooms_check` in a `match room` branch.
- **A room rule an item flips** (the roguelike hook, design in the lore doc): add the key to `REAL_ROOM` with its
  default, read it through `rooms.rule()`. `links` is the pattern: data on the room, one guarded spread in the verb.
- **Showcase strings** live in the room, not in `training_bot.BOT_STRINGS` (whose `room` field plays a string only in
  that room, on `BOT_PIECE_LAYOUTS` in the pieces room's coordinates). To put a showcase in the autotest, add it to
  `BOT_STRINGS` with `room` and a layout (training_bot is another lane's file).

## Testing

- `godot --headless --path . -s tests/rooms_check.gd` (~40 s, PASS/FAIL): the data (picker cycles, labels, lore,
  flourish ids, links on floor pieces, inside the walls, tile centres, overlaps, the room with pieces' one pool /
  barrel / grate), every room builds its live pieces with no engine error and passes its rebuild rule; the cistern's
  channel freezes as one (`+24` m down it, `+6` over one pool) and a real Slapshot carries a cube to x 15 (the east
  wall's face at 16); the forge's powder line bursts all three kegs and spills both braziers from one magma mark, the
  foe on the coals molten, two fresh seams; one storm mark makes all three plates live and charges the foe on the far
  one, cold after `LIVE_S`; the hero unhurt in both.
- Unchanged: `env_piece_check`, `env_breaker_check`, `lava_leash_check`, `counter_check`, `env_target_check`,
  `kit_check`, and the `--room=pieces` autotest's `[env]` line.
- Film (windowed): `godot --path . -s tests/string_film.gd -- --room=cistern --showcase --dir=<name> [--overview]
  [--fps=24 --tail=3000]`, and `--room=forge`. Stills: `tests/piece_shots.gd -- --room=cistern --tag=<name>`.
  Clips: `awaken-combo-clips/49 Rooms *`.

## Not verified

- The cistern and forge in a full `--autotest` (the plain strings in them): the land check runs plain and pieces
  only. The plain strings' layouts don't know the new pieces (a "wall" string's throw may cross the aqueduct).
- Gallows on the cistern's back-wall hooks (over the water, ~11 m from the dummies, past `GALLOWS_REACH` from their
  homes; the pillar hook is the counted one, as in the room with pieces).
- The showcases with a real player's aim: Slapshot goes along his facing at the breaker's start, so the channel shot
  needs him to face down it; the bot's dummies stand in a line along it. From the game camera the cubes leave the
  frame before they reach the wall (the `--overview` clip shows the whole run).
- Frame cost of three live plates' rims and crawls at once (36 crawl loops) windowed.
