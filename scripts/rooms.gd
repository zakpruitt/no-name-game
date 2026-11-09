extends RefCounted
## Rooms as data (round 51, env-pieces lane; round 57, rooms lane: docs/features/rooms.md). main.gd keeps building the
## floor tiles, the walls and the near edge's rubble, then places a room's entries with env_piece.gd (EnvPiece.place):
## each entry is {tag, at, yaw, model, live, count, light, occlude}. `live` false is a model only (today's corner
## clutter and banners in the plain room); `count` puts the piece on the autotest's `[env] pieces=N/N`; `light`
## (torches) gives it the classic style's lamp; `occlude` fades it when it hides the hero.
##
## A room (ROOM_DEFS) is a name and nothing but data: its Settings label, its size, the layers of ROOMS entries it is
## built from (each a list of piece placements with their yaw), the tags it makes live, its rules (rebuild, the
## flourishes it plays, the piece tags whose touching tiles act as one: `links`), a lore line, and its showcase strings
## (where the bot stands him and the dummies to play the combo only this room makes possible; tests/string_film.gd
## `--showcase`). ORDER is the Settings picker. A name not in ROOM_DEFS is a real room (REAL_ROOM: nothing rebuilds).
##
## ROOMS.training is today's arena, unchanged (every bot string and film plays the same). "Room: with pieces"
## (Settings, or `--room=pieces`) adds ROOMS.training_pieces: one of each piece the heretic or everyone can use, each by
## a dummy, the banners live, and every used-up piece rebuilt EnvPiece.REBUILD_S after. The flooded cistern and the
## forge hall (round 57) add their own layers to the same hall.

## The four pillars R swings on (main.PILLARS reads this).
const PILLARS := [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(-8, 0, 7), Vector3(8, 0, 7)]

const ROOMS := {
	"training": [
		{"tag": "pillar", "at": Vector3(-8, 0, -8), "occlude": true},
		{"tag": "pillar", "at": Vector3(8, 0, -8), "occlude": true},
		{"tag": "pillar", "at": Vector3(-8, 0, 7), "occlude": true},
		{"tag": "pillar", "at": Vector3(8, 0, 7), "occlude": true},
		# torches on the back wall (env_target swings them)
		{"tag": "torch", "at": Vector3(-10, 2.4, -15.5), "light": true},
		{"tag": "torch", "at": Vector3(-2, 2.4, -15.5), "light": true, "count_in_pieces": true},  # (round 52: torches conduct)
		{"tag": "torch", "at": Vector3(6, 2.4, -15.5), "light": true},
		{"tag": "banner", "at": Vector3(-6, 0, -15.6), "live": false},
		{"tag": "banner", "at": Vector3(2, 0, -15.6), "live": false},
		{"tag": "banner", "at": Vector3(10, 0, -15.6), "live": false},
		# clutter in the corners (a look, out of the fighting space)
		{"tag": "barrel", "at": Vector3(-14.5, 0, -14.0), "model": "barrel_large", "live": false},
		{"tag": "barrel", "at": Vector3(-12.8, 0, -14.6), "model": "barrel_small", "live": false},
		{"tag": "crate", "at": Vector3(14.0, 0, -13.8), "yaw": 20.0, "model": "crates_stacked", "live": false},
		{"tag": "chest", "at": Vector3(13.6, 0, 12.0), "yaw": -30.0, "live": false},
		{"tag": "crate", "at": Vector3(-14.2, 0, 12.5), "yaw": 15.0, "model": "box_large", "live": false},
	],
	# "with pieces": added to training. Rubble under the dummy at (-1.6, -4.5), where most breakers land; the keg
	# corner on the left (the spikes, the barrel and a crate at their back: Molten Palm carries the dummies into the
	# barrel over the spikes, training_bot's "keg" layout); the grate on the right under the dummy at (4.2, -3.2)
	# (Frost Wall, Live Floor).
	"training_pieces": [
		{"tag": "rubble", "at": Vector3(-2, 0, -6), "count": true},
		{"tag": "spikes", "at": Vector3(-10, 0, -2), "count": true},
		{"tag": "barrel", "at": Vector3(-11.2, 0, -2.0), "count": true},
		{"tag": "crate", "at": Vector3(-11.0, 0, 1.0), "yaw": 10.0, "model": "crates_stacked", "count": true},
		{"tag": "grate", "at": Vector3(6, 0, -2), "count": true},
		# env-art lane: the four pieces whose rules are still to build (art only, not counted): the pool's tile under the
		# dummy at (1.6, -4.5) (ice_rink), the brazier behind the one at (-4.2, -3.2) (brazier_spill), the hook on the back
		# wall between a banner and a torch (gallows; a side wall shows it edge-on to the camera), the ledge on the right wall
		# level with the dummies (High Ground)
		# round 53 (env-flourish): the pool, the brazier and a second hook have rules now (env_flourish.gd) and count. The
		# second hook hangs on the face of the pillar at (8, -8) toward the dummies (the counter dummy's Ricochet reaches its
		# point, ~9 m; the back wall's is ~11 m off, past GALLOWS_REACH): ice_rink, brazier_spill, gallows.
		{"tag": "pool", "at": Vector3(2, 0, -6), "count": true},
		{"tag": "brazier", "at": Vector3(-5.8, 0, -5.2), "count": true},
		{"tag": "hook", "at": Vector3(-4.0, 3.4, -15.5)},
		{"tag": "hook", "at": Vector3(7.47, 3.85, -7.47), "yaw": -45.0, "count": true},
		{"tag": "ledge", "at": Vector3(14.5, 0, -4.0), "yaw": -90.0},
	],
	# Round 57 (rooms lane): the flooded cistern (ice and dark). The aqueduct along the back wall: four pools end to end,
	# one body of water (its `links` rule: ice on one freezes them all, and a cube's slide gets RINK_EXTRA for every
	# frozen pool its line crosses), the sluice's cold iron grate at its east end; the dummies' grate (Frost Wall, Live
	# Floor) where the room with pieces has it; hook chains over the water on the back wall and on the east pillar's
	# face (gallows); a ledge on the west wall (a look). No barrels, crates or braziers: nothing here burns.
	"cistern": [
		{"tag": "pool", "at": Vector3(-6, 0, -14), "count": true},
		{"tag": "pool", "at": Vector3(-2, 0, -14), "count": true},
		{"tag": "pool", "at": Vector3(2, 0, -14), "count": true},
		{"tag": "pool", "at": Vector3(6, 0, -14), "count": true},
		{"tag": "grate", "at": Vector3(10, 0, -14), "count": true},
		{"tag": "grate", "at": Vector3(6, 0, -2), "count": true},
		{"tag": "hook", "at": Vector3(-4.0, 3.4, -15.5)},
		{"tag": "hook", "at": Vector3(4.0, 3.4, -15.5)},
		{"tag": "hook", "at": Vector3(7.47, 3.85, -7.47), "yaw": -45.0, "count": true},
		{"tag": "ledge", "at": Vector3(-14.5, 0, -4.0), "yaw": 90.0},
	],
	# Round 57: the forge hall (magma and storm). The powder line up the room: three kegs 3 m apart (each burst catches
	# the next: env_piece KEG_R) between two lit braziers (a keg's burst tips a lit brazier in its reach: the coals'
	# molten patch, Hellseam fresh on them); the bonded iron plates across the hall under the dummies (its `links`
	# rule: storm that makes one live makes every plate touching it live).
	"forge": [
		{"tag": "brazier", "at": Vector3(-6, 0, -11), "count": true},
		{"tag": "barrel", "at": Vector3(-3, 0, -11), "count": true},
		{"tag": "barrel", "at": Vector3(0, 0, -11), "count": true},
		{"tag": "barrel", "at": Vector3(3, 0, -11), "count": true},
		{"tag": "brazier", "at": Vector3(6, 0, -11), "count": true},
		{"tag": "grate", "at": Vector3(-2, 0, -2), "count": true},
		{"tag": "grate", "at": Vector3(2, 0, -2), "count": true},
		{"tag": "grate", "at": Vector3(6, 0, -2), "count": true},
	],
}
## The Settings picker's order (Game.toggle_room cycles it; `--room=<name>` takes any of them).
const ORDER := ["plain", "pieces", "cistern", "forge"]

## The rooms (round 57; round 52's ROOM_RULES folded in). Keys:
##   label        Settings "Room (on restart): <label>"
##   size         the floor, x by z m (main.gd's ARENA_HALF builds 32 x 32; rooms_check holds every piece inside it)
##   layers       the ROOMS lists placed, in order
##   make_live    tags whose look-only entries in those layers become live pieces here
##   count_marked entries with `count_in_pieces` are counted here (the middle torch: torches conduct)
##   rebuild      used-up pieces come back EnvPiece.REBUILD_S after (with a dust pop). Every training room rebuilds;
##                a real room keeps its pieces gone (the proposal's open question 2)
##   flourishes   env_flourish.gd ids on here without their Kit upgrade (env_flourish.on(): practice)
##   links        piece tags whose touching floor tiles are one piece for their verbs (env_piece.linked()): "pool"
##                (one body of water: ice_rink freezes all of it), "grate" (bonded plates: Live Floor spreads)
##   lore         one line of the world (docs/design/environment-lore.md)
##   showcase     strings that show what only this room can do: {name, slot, tokens (training_bot tokens), hero and
##                face (where he starts and which way; within 3 m of a dummy, or the bot walks up first), dummies
##                (their spots), expect (what it reaches; tests/rooms_check.gd checks it)}
const ROOM_DEFS := {
	"plain": {"label": "plain", "size": Vector2(32, 32), "layers": ["training"], "make_live": [], "count_marked": false,
		"rebuild": true, "flourishes": [], "links": [],
		"lore": "The church's drill hall, swept bare: four pillars to swing on and torches on the wall, for practising strings."},
	"pieces": {"label": "with pieces", "size": Vector2(32, 32), "layers": ["training", "training_pieces"],
		"make_live": ["banner"], "count_marked": true, "rebuild": true, "flourishes": ["gallows", "ice_rink", "brazier_spill"],
		"links": [], "lore": "The drill hall stocked with one of everything the prison was built from, each set by a dummy."},
	"cistern": {"label": "flooded cistern", "size": Vector2(32, 32), "layers": ["training", "cistern"], "make_live": [],
		"count_marked": false, "rebuild": true, "flourishes": ["gallows", "ice_rink"], "links": ["pool"],
		"lore": "The cistern dug under the hall to drown the stolen fire. Its channel was never drained, cold iron still bars the sluice, and the drowned were hung on the chains above it.",
		"showcase": [
			# Harpoon's cubes on the aqueduct's west pool freeze the whole channel, and Slapshot sends the row the length
			# of it into the east wall (~21 m; one frozen pool, all the room with pieces has, stops them by ~17 m)
			{"name": "down the channel", "slot": "dash_ender_l", "tokens": ["alt", "D", "L", "H"],
				"hero": Vector3(-9.4, 0, -14.0), "face": Vector3(1, 0, 0),
				"dummies": [Vector3(-7.4, 0, -14.0), Vector3(-6.0, 0, -14.3), Vector3(-4.6, 0, -13.7), Vector3(-3.2, 0, -14.0)],
				"expect": "every pool in the channel frozen; a cube splats on the east wall"},
		]},
	"forge": {"label": "forge hall", "size": Vector2(32, 32), "layers": ["training", "forge"], "make_live": [],
		"count_marked": false, "rebuild": true, "flourishes": ["brazier_spill"], "links": ["grate"],
		"lore": "The forge where the church cast its cold iron. The pitch for the pyres is still stacked between the fires, and the bonded plates of its floor still carry a current.",
		"showcase": [
			# Molten Palm carries the dummies into the middle keg: it bursts, both kegs beside it catch and burst, and
			# each tips the brazier past it (one barrel, all the room with pieces has, is one burst)
			{"name": "powder line", "slot": "big_3", "tokens": ["L", "L", "L", "H", "H"],
				"hero": Vector3(0.0, 0, -3.2), "face": Vector3(0, 0, -1),
				"dummies": [Vector3(0.0, 0, -5.4), Vector3(-0.4, 0, -6.1), Vector3(0.4, 0, -6.1), Vector3(0.0, 0, -6.6)],
				"expect": "three kegs burst and both braziers spilled from one magma hit"},
			# Live Wire's jolts on the dummies on the east plate make every bonded plate live: the dummy on the west
			# plate, 11 m off and past the tentacles' reach, is charged by the floor, and Short Circuit arcs from them
			{"name": "bonded plates", "slot": "big_1", "tokens": ["alt", "L", "H", "H"],
				"hero": Vector3(8.6, 0, -2.0), "face": Vector3(-1, 0, 0),
				"dummies": [Vector3(6.6, 0, -2.0), Vector3(5.8, 0, -2.8), Vector3(5.8, 0, -1.2), Vector3(-2.8, 0, -2.6)],
				"expect": "all three plates live; the dummy on the far plate charged"},
		]},
}
const REAL_ROOM := {"label": "", "size": Vector2(32, 32), "layers": [], "make_live": [], "count_marked": false,
	"rebuild": false, "flourishes": [], "links": [], "lore": "", "showcase": []}


## Room `room`'s definition (ROOM_DEFS, else a real room's REAL_ROOM).
static func def_of(room: String) -> Dictionary:
	return ROOM_DEFS.get(room, REAL_ROOM)


## Room `room`'s rule `key` (its ROOM_DEFS entry, else REAL_ROOM's).
static func rule(room: String, key: String) -> Variant:
	return def_of(room).get(key, REAL_ROOM.get(key))


## Whether used-up pieces come back in `room` (main.gd passes it to EnvPiece.begin).
static func rebuild(room: String) -> bool:
	return bool(rule(room, "rebuild"))


## Whether flourish `id` (env_flourish.IDS) plays in `room` without its Kit upgrade.
static func flourish(room: String, id: String) -> bool:
	return id in (rule(room, "flourishes") as Array)


## Whether `tag`'s touching floor tiles act as one piece in `room` (env_piece.linked()).
static func links(room: String, tag: String) -> bool:
	return tag in (rule(room, "links") as Array)


## Whether `room` is one of the rooms (`--room=`, the saved setting).
static func known(room: String) -> bool:
	return room in ORDER


## The Settings label of `room`.
static func label(room: String) -> String:
	return str(rule(room, "label")) if ROOM_DEFS.has(room) else room


## The room after `room` in the Settings picker.
static func next_room(room: String) -> String:
	return ORDER[(ORDER.find(room) + 1) % ORDER.size()]


## The showcase strings of `room` (ROOM_DEFS key `showcase`).
static func showcase(room: String) -> Array:
	return def_of(room).get("showcase", [])


## The entries for a room: its layers' entries in order, the room's `make_live` tags live and (`count_marked`) the
## `count_in_pieces` ones counted. "plain" is today's arena, "pieces" training plus training_pieces.
static func layout(room: String) -> Array:
	var d: Dictionary = def_of(room)
	var out: Array = []
	for layer: String in d.get("layers", []):
		for e: Dictionary in ROOMS[layer]:
			var x := e.duplicate()
			if x.tag in d.get("make_live", []):
				x.live = true
			if d.get("count_marked", false) and x.get("count_in_pieces", false):  # (round 52: on the [env] line's pieces=N/N)
				x.count = true
			out.append(x)
	return out


## env_piece.gd preloads this file (for `links`), so it is loaded once here, on first use, instead of preloaded.
static var _piece_s: GDScript


## Floor tiles a room's floor pieces cover (main skips its own tile there): tile centres.
static func floor_spots(room: String) -> Array:
	if _piece_s == null:
		_piece_s = load("res://scripts/env_piece.gd")
	var pieces: Dictionary = _piece_s.PIECES
	var out := []
	for e: Dictionary in layout(room):
		if e.get("live", true) and pieces[e.tag].get("floor", false):
			out.append(Vector3(e.at.x, 0.0, e.at.z))
	return out
