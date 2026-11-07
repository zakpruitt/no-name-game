extends RefCounted
## Rooms as data (round 51, env-pieces lane; docs/features/env-pieces.md). main.gd keeps building the floor tiles, the
## walls and the near edge's rubble, then places a room's entries with env_piece.gd (EnvPiece.place): each entry is
## {tag, at, yaw, model, live, count, light, occlude}. `live` false is a model only (today's corner clutter and
## banners in the plain room); `count` puts the piece on the autotest's `[env] pieces=N/N`; `light` (torches) gives it
## the classic style's lamp; `occlude` fades it when it hides the hero.
##
## ROOMS.training is today's arena, unchanged (every bot string and film plays the same). "Room: with pieces"
## (Settings, or `--room=pieces`) adds ROOMS.training_pieces: one of each piece the heretic or everyone can use, each by
## a dummy, the banners live, and every used-up piece rebuilt EnvPiece.REBUILD_S after.

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
		{"tag": "hook", "at": Vector3(7.47, 3.5, -7.47), "yaw": -45.0, "count": true},
		{"tag": "ledge", "at": Vector3(14.5, 0, -4.0), "yaw": -90.0},
	],
}
## Pieces the plain room has as looks that "with pieces" makes live (the banners tear).
const LIVE_IN_PIECES := ["banner"]

## Round 52 (env-pieces2): each room's own rules, beside its entries. `rebuild`: used-up pieces come back
## EnvPiece.REBUILD_S after (with a dust pop). Both training rooms rebuild (a pillar Uproot tore out of the plain room
## comes back, so the string can be practised again); a real room keeps its pieces gone, so tearing a pillar down costs
## the swing anchor for the rest of the fight (the proposal's open question 2). A room with no entry here is a real
## room: rebuild false. No run builds real rooms yet; `rule()` is what main.gd and a run will read.
## Round 53 (env-flourish): `flourishes` turns the heretic's flourishes on in the room (env_flourish.on(): gallows,
## ice_rink, brazier_spill; elsewhere each is its Kit upgrade), so the room with pieces is where they are practised.
const ROOM_RULES := {
	"plain": {"rebuild": true, "flourishes": false},
	"pieces": {"rebuild": true, "flourishes": true},
}
const REAL_ROOM := {"rebuild": false, "flourishes": false}


## Room `room`'s rule `key` (ROOM_RULES, else a real room's REAL_ROOM).
static func rule(room: String, key: String) -> Variant:
	return ROOM_RULES.get(room, REAL_ROOM).get(key, REAL_ROOM.get(key))


## Whether used-up pieces come back in `room` (main.gd passes it to EnvPiece.begin).
static func rebuild(room: String) -> bool:
	return bool(rule(room, "rebuild"))


## The entries for a room: "plain" (today's arena) or "pieces" (training plus training_pieces).
static func layout(room: String) -> Array:
	var out: Array = []
	for e: Dictionary in ROOMS.training:
		var d := e.duplicate()
		if room == "pieces" and d.tag in LIVE_IN_PIECES:
			d.live = true
		if room == "pieces" and d.get("count_in_pieces", false):  # (round 52: on the [env] line's pieces=N/N)
			d.count = true
		out.append(d)
	if room == "pieces":
		out.append_array(ROOMS.training_pieces)
	return out


## Floor tiles a room's floor pieces cover (main skips its own tile there): tile centres.
static func floor_spots(room: String) -> Array:
	var out := []
	for e: Dictionary in layout(room):
		if e.get("live", true) and load("res://scripts/env_piece.gd").PIECES[e.tag].get("floor", false):
			out.append(Vector3(e.at.x, 0.0, e.at.z))
	return out
