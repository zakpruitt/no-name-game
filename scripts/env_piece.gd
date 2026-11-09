extends RefCounted
## The room's pieces as data (round 51, env-pieces lane; docs/features/env-pieces.md, the proposal
## docs/design/environment-per-character.md). A room is built from the nouns in PIECES and nothing else. Every piece has
## one shared rule any hit triggers (a thrown foe breaks a crate for anyone); the exclusive verbs come from the
## element that hits it (EXCLUSIVE): a grate answers to storm and ice, a barrel to magma, a pillar to the dark. What a
## piece then leaves on foes is always one of the six states, so passives on a state reach it.
##
##   place(room, tag, at, yaw, state, opts)  builds one with ComicLook.piece(), its collider, the groups `env` and
##                                            `env_<tag>`, the `env_state` meta, and registers it with env_target.gd
##   hit(piece, el, by, how)                  the one entry every hit calls: the element's verb if it has one
##                                            (RULES_BY_ELEMENT), else the piece's shared rule for `how`
##   near(tree, tag, at, r)                   the FOES.near() of pieces (live ones, nearest first)
##   usable(tag, verb)                        whether this hero's elements have that verb (the indicator asks)
##
## A used-up piece stays used up for the room; the training room rebuilds it REBUILD_S after (room meta
## REBUILD_META), with a drawn dust pop. No class_name: preload it.

const ENV := preload("res://scripts/env_target.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const FOES := preload("res://scripts/foes.gd")
const POLISH := preload("res://scripts/designed_polish.gd")
const ROOMS := preload("res://scripts/rooms.gd")
## void_element, thrown_foe and env_flourish preload this file (env_target.gd has the whole order), so a preload of
## them here would close a cycle: each is loaded once, on first use, and held.
static var _ve_s: GDScript
static var _thrown_s: GDScript
static var _flourish_s: GDScript

const GROUP := "env"
const STATE_META := &"env_state"
const TAG_META := &"env_tag"
const HOME_META := &"env_home"  # {at, yaw, state}: what a rebuild puts back
const ID_META := &"env_id"  # its id in env_target.structures, while registered
const REBUILD_META := &"env_rebuild"  # on the room: used-up pieces come back REBUILD_S after (training)
const REBUILD_S := 6.0
const POP_SIZE := 1.4  # the rebuild's dust pop
## Round 54 (camera-hang lane; feel audit 6 item 10: Uproot's heaps and the pillar on the floor lingered into the next
## strings, H L H 003-018): RUBBLE_HOLD_S after the topple (the club has landed by then) the pillar lying there and
## its heaps erode: a designed dust puff on each, then they sink RUBBLE_SINK m into the floor over RUBBLE_ERODE_S
## (eased in, a second puff halfway) and hide, about 4 s in all. A room that keeps pieces gone (no rebuild) keeps a
## low flat rubble decal along the fall line instead (RUBBLE_DECAL, RUBBLE_DECAL_H tall).
const RUBBLE_HOLD_S := 1.2  # real s
const RUBBLE_ERODE_S := 2.8  # real s
const RUBBLE_SINK := 1.3  # m
const RUBBLE_PUFF := 0.9  # dust puff size on each
const RUBBLE_DECAL := "floor_tile_large_rocks"
const RUBBLE_DECAL_H := 0.25  # of the tile's height
const ERODE_META := &"env_erode"  # the erosion's tween on the toppled piece (rebuild stops it)
static var eroded := 0  # toppled pieces eroded away (checks)

## The fourteen nouns. `models` (the first is the default; `assets/comic/dungeon/`, KayKit's per piece as the
## fallback), `collider` "box" | "cyl" | "none" and its `size` (box: x, y, z; cyl: radius, height), `wall` (a thrown
## foe splats on it at full wall_mult), `breaks` (a hit can use it up), `floor` (a floor tile: it replaces the room's
## tile where it lies), `states` (the first is how it starts), `rule` (its shared rule, the docs' and MOVES' text),
## `built` (the shared rule is in the game; the rest are data until their lane), `stub` (no comic piece of its own
## yet: the model named stands in, docs/features/env-pieces.md "Art").
const PIECES := {
	"wall": {"models": ["wall"], "collider": "none", "wall": true, "breaks": false, "states": [], "built": true,
		"rule": "Wall splat: a thrown foe that meets it takes the throw's wall_mult; Pinwheel, Slapshot, Ricochet and Collapse aim at it."},
	"pillar": {"models": ["pillar_decorated"], "collider": "cyl", "size": Vector2(0.75, 4.0), "wall": true, "breaks": false,
		"states": ["whole", "cracked", "toppled"], "built": true,
		"rule": "A wall for splats, the R swing's anchor, the pillar slam; shakes on landings. Toppled: rubble for the room."},
	"torch": {"models": ["torch_mounted"], "collider": "none", "wall": false, "breaks": false, "states": ["lit", "out", "conducting"], "built": true,
		"rule": "Light; swings when a foe splats on the wall under it."},
	"brazier": {"models": ["brazier", "brazier_spilled"], "stub": false, "collider": "cyl", "size": Vector2(0.55, 1.3), "wall": false, "breaks": true,
		"states": ["lit", "out", "spilled"], "built": true,
		"rule": "Floor fire bowl, lit. Lava Leash's seam tips it in (brazier_spill): the coals run the seam on and leave a molten patch; magma lights an out one."},
	"barrel": {"models": ["barrel_large", "barrel_small"], "collider": "cyl", "size": Vector2(0.8, 2.0), "wall": false, "breaks": true,
		"states": ["whole", "burning", "gone"], "built": true,
		"rule": "A thrown foe breaks it: a splat at half the wall's, staves fly, gone."},
	"crate": {"models": ["crates_stacked", "box_large"], "collider": "box", "size": Vector3(1.9, 2.1, 2.0), "wall": false, "breaks": true,
		"states": ["whole", "gone"], "built": true,
		"rule": "A thrown foe, a breaker landing within 1.5 m or a burst keg breaks it (in runs it drops a pickup)."},
	"chest": {"models": ["chest_gold"], "collider": "box", "size": Vector3(1.6, 1.3, 1.4), "wall": true, "breaks": false,
		"states": ["shut", "open"], "built": true,
		"rule": "Heavy: a wall for splats, never breaks; opens when the room is cleared (run reward)."},
	"banner": {"models": ["banner_patternA_red"], "collider": "none", "wall": false, "breaks": true,
		"states": ["hanging", "torn", "burning"], "built": true,
		"rule": "Hangs on a wall; a foe splatted through it tears it down."},
	"grate": {"models": ["floor_tile_big_grate"], "collider": "none", "floor": true, "size": Vector3(4.0, 0.0, 4.0), "wall": false,
		"breaks": false, "states": ["cold", "live", "frosted"], "built": true,
		"rule": "Metal floor tile; floor to anyone without storm or ice."},
	"spikes": {"models": ["floor_tile_big_spikes"], "collider": "none", "floor": true, "size": Vector3(4.0, 0.0, 4.0), "wall": false,
		"breaks": false, "states": ["up", "down"], "built": true,
		"rule": "A thrown foe that comes down on it takes x1.5 on the landing."},
	"rubble": {"models": ["floor_tile_large_rocks", "rubble_half"], "collider": "none", "floor": true, "size": Vector3(4.0, 0.0, 4.0),
		"wall": false, "breaks": false, "states": [], "built": true,
		"rule": "Low; a breaker landing on it throws chunks for a small splash."},
	"pool": {"models": ["pool"], "stub": false, "collider": "none", "floor": true, "size": Vector3(4.0, 0.0, 4.0),
		"wall": false, "breaks": false, "states": ["water", "frozen", "live", "steam"], "built": true,
		"rule": "Water. Ice by it freezes it (ice_rink): cubes slide across it at full speed and further, foes knocked onto it slide and freeze."},
	"hook": {"models": ["hook_chain"], "stub": false, "collider": "none", "wall": true, "breaks": false, "states": ["empty", "hung"],
		"built": true, "rule": "A hook on a chain on a wall: a wall for everyone. Ricochet hangs the attacker on it (gallows): bound, every hit a Snap."},
	"ledge": {"models": ["ledge"], "stub": false, "collider": "box", "size": Vector3(8.0, 1.2, 2.0), "wall": true, "breaks": false, "states": [], "built": false,
		"rule": "A raised ledge along a wall, 1.2 m up with a step at its front; its face is a wall."},
}

## Exclusive verbs by element (the proposal's open question 1 picked element): element -> piece -> verb ids. The
## structure indicator marks a piece for a verb only when the hero has the element (usable()).
const EXCLUSIVE := {
	"void": {"pillar": ["uproot"], "hook": ["gallows"]},
	"earth": {"barrel": ["keg"], "brazier": ["brazier_spill"]},
	"water": {"grate": ["frost_wall"], "pool": ["ice_rink"]},
	"wind": {"grate": ["live_floor"], "torch": ["conduct"]},
}
## Which verbs are in the game (the rest of EXCLUSIVE is the proposal's, still to build).
const BUILT := ["uproot", "keg", "frost_wall", "live_floor", "conduct", "gallows", "ice_rink", "brazier_spill"]
## The elements the heretic hits with (his four colours).
const HERO_ELEMENTS := ["void", "wind", "water", "earth"]
## The element verbs a hit can trigger: element -> piece -> the verb hit() plays.
const RULES_BY_ELEMENT := {
	"earth": {"barrel": "keg"},
	"wind": {"grate": "live_floor", "torch": "conduct"},
}

## Shared numbers.
const SPLAT_HALF := 0.5  # a throw into a breakable splats for this of the wall's mult (at least x1)
const SPIKES_MULT := 1.5
const CRATE_LANDING_R := 1.5  # m: a breaker landing this near a crate breaks it
const RUBBLE_LANDING_R := 1.5  # m: a breaker landing on rubble throws chunks
const RUBBLE_DAMAGE := 6.0  # the chunks' splash, each foe within RUBBLE_SPLASH_R
const RUBBLE_SPLASH_R := 2.0
const BANNER_NEAR := 1.4  # m along the wall from a splat that tears a banner
const STAVES := 10  # chips a breaking barrel or crate throws

## Powder Keg (round 51, magma on a barrel): a magma hit on a barrel (Molten Palm carrying a foe into it, a molten
## foe splatted on it, magma reaching a foe within KEG_CATCH of it) sets it burning; KEG_FUSE s later it bursts,
## KEG_R round, by the molten rule: KEG_DAMAGE (the Burst rule's x1.5 on KEG_BASE) to everyone in it, and they are
## left molten; crates in it break. Hits on a burning barrel feed the fire (no break).
const KEG_FUSE := 1.2  # s (game)
const KEG_R := 3.0
const KEG_BASE := 20.0
const KEG_DAMAGE := KEG_BASE * 1.5  # (void_element.IMPROV_MULT, the Burst rule's)
const KEG_CATCH := 1.2  # m: magma on a foe this near a barrel reaches it
const KEG_WORD := "KA-BLOOOM!"
const KEG_TELL := 2.2  # m: the tell_molten licks on the burning barrel
## Round 52 (env-pieces2): the keg's word waits its turn. ComicFx shows one word at a time (`replace`), so in the keg
## string Meteor Fall's word, landing on the pile as the keg went, wiped "KA-BLOOOM!" in the same beat. It waits while
## he is in a breaker's leap and until KEG_WORD_GAP_MS after the last word (at most KEG_WORD_WAIT real s), and goes up
## KEG_WORD_UP over the barrel.
const KEG_WORD_GAP_MS := 450
const KEG_WORD_WAIT := 1.2
const KEG_WORD_UP := 2.8
const KEG_WORD_POLL := 0.05

## Live Floor (round 51, storm on a grate): a storm hit that charges a foe standing on a grate (Live Wire's jolts,
## Grounded, Galvanize: void_element.mark(e, "charged")) makes the grate live for LIVE_S: everyone on it is charged
## every LIVE_TICK s, the designed arc_crawl runs over it, and Short Circuit's arcs may start from the grate, its
## reach measured from the grate too (void_element._short_circuit, live_sources()).
const LIVE_S := 4.0  # s (game)
const LIVE_TICK := 0.5
const LIVE_CRAWLS := 4  # arc_crawl loops over the tile
const LIVE_CRAWL_SIZE := 1.7

static var _live_ticking := false  # (the grate's own charge doesn't make it live again)
static var _linking := false  # (round 57: a linked plate's spread doesn't spread back)

## Live Floor's look (round 52, env-pieces2): the crawls sit on the tile's edge, bigger, and a lime bolt runs round its
## rim every tick, so a live grate reads under the pile standing on it.
const LIVE_EDGE_CRAWLS := 8  # arc_crawl loops round the edge (corners and edge middles)
const LIVE_EDGE_SIZE := 2.4
const LIVE_RIM_W := 0.3  # the rim bolt's width

## Torches conduct (round 52, env-pieces2; build order item 5): a storm hit that charges a foe within CONDUCT_REACH of a
## lit torch makes it conduct for CONDUCT_S: the current runs along the wall through every lit torch within
## CONDUCT_LINK of the next (a lime bolt_path from the foe to the torch and on along the wall), and each torch in the
## chain zaps the foes within CONDUCT_REACH of it for CONDUCT_DAMAGE and charges them. Live Wire's jolts, Galvanize's
## zaps and Short Circuit's arcs all charge, so all three relay; Short Circuit also counts conducting torches as
## sources and reaches CONDUCT_REACH round each (void_element._short_circuit). One relay per torch per CONDUCT_CD.
const CONDUCT_REACH := 3.5  # m (flat) from the torch
const CONDUCT_LINK := 8.5  # m between torches along the wall the current jumps (the training room's are 8 apart)
const CONDUCT_S := 3.0  # s (game) a torch keeps conducting after the last storm near it
const CONDUCT_DAMAGE := 8.0  # each relayed zap (x his damage mult)
const CONDUCT_CD := 0.45  # real s between one torch's relays (Live Wire jolts every 0.1 s)
const CONDUCT_FLAME := 0.55  # m over the torch's origin: its flame, where the bolts meet it
const CONDUCT_WORD := "ZZRAK!"
static var _relaying := false  # (the relay's own charges don't relay again)

## Run counters (the autotest's [env] line): the pieces placed with `count` and the ones a hit has touched.
static var counted: Array = []
static var touched := {}  # instance id -> verb or rule it played last
static var verbs := {}  # verb id -> times
static var keg_words := 0  # (round 52: the keg's words that went up, after their wait)


static func _ve() -> GDScript:
	if _ve_s == null:
		_ve_s = load("res://scripts/void_element.gd")
	return _ve_s


static func _thrown() -> GDScript:
	if _thrown_s == null:
		_thrown_s = load("res://scripts/thrown_foe.gd")
	return _thrown_s


## The heretic's flourishes on the hook, the pool and the brazier (env_flourish.gd), each a Kit upgrade, on in a room
## with the `flourishes` rule (rooms.gd).
static func _flourish() -> GDScript:
	if _flourish_s == null:
		_flourish_s = load("res://scripts/env_flourish.gd")
	return _flourish_s


# --- placing ------------------------------------------------------------------------------------------------------

## A fresh room: forget the last one's counters.
static func begin(room: Node, rebuild := false) -> void:
	counted.clear()
	touched.clear()
	verbs.clear()
	room.set_meta(REBUILD_META, rebuild)


## Builds piece `tag` at `at` (y included: a torch hangs), turned `yaw` degrees, starting in `state` (its first by
## default). `opts`: `model` (one of its models), `live` false places the model only (deco: no collider, no group,
## not registered: today's plain room's clutter), `count` (the [env] line counts it), `scale`.
static func place(room: Node, tag: String, at: Vector3, yaw := 0.0, state := "", opts := {}) -> Node3D:
	var spec: Dictionary = PIECES[tag]
	var n: Node3D = ComicLook.piece(opts.get("model", spec.models[0]))
	n.position = at
	n.rotation_degrees.y = yaw
	if opts.has("scale"):
		n.scale = opts.scale
	room.add_child(n)
	if spec.get("floor", false):  # (flat tiles only receive shadows, like the room's own)
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not opts.get("live", true):
		return n
	var first: String = state if state != "" else (spec.states[0] if not spec.states.is_empty() else "")
	n.add_to_group(GROUP)
	n.add_to_group("env_" + tag)
	n.set_meta(TAG_META, tag)
	n.set_meta(STATE_META, first)
	n.set_meta(HOME_META, {"at": at, "yaw": yaw, "state": first})
	if spec.collider != "none":
		_collider(n, spec)
	if tag == "pillar":
		n.add_to_group("grab_anchors")  # the void arm swings on them (void_grab.gd)
	_register(n)
	if tag in ["pool", "brazier"]:  # the pool's watch (ice_rink), the brazier's lit look
		_flourish().placed(n)
	if opts.get("count", false):
		counted.append(n)
	return n


static func _collider(n: Node3D, spec: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "EnvBody"
	var shape := CollisionShape3D.new()
	if spec.collider == "cyl":
		var cyl := CylinderShape3D.new()
		cyl.radius = spec.size.x
		cyl.height = spec.size.y
		shape.shape = cyl
		shape.position.y = spec.size.y * 0.5
	else:
		var box := BoxShape3D.new()
		box.size = spec.size
		shape.shape = box
		shape.position.y = spec.size.y * 0.5
	body.add_child(shape)
	n.add_child(body)


## The piece's radius on the floor plane (its collider's, or half a floor tile).
static func radius(n: Node3D) -> float:
	var spec: Dictionary = PIECES[tag_of(n)]
	if spec.get("floor", false):
		return float(spec.size.x) * 0.5
	if spec.collider == "cyl":
		return float(spec.size.x)
	if spec.collider == "box":
		return maxf(spec.size.x, spec.size.z) * 0.5
	return 0.5


## env_target.gd knows the pieces that are structures (pillars) and the props a verb aims at (barrels for the keg).
static func _register(n: Node3D) -> void:
	var env: Node = ENV.of(n.get_tree())
	if env == null:
		return
	var tag := tag_of(n)
	var id := ""
	match tag:
		"pillar":
			id = env.add_pillar(n, float(PIECES.pillar.size.x))
		"torch":
			env.add_torch(n)
		"barrel", "crate", "chest", "grate", "brazier", "hook":  # (round 53: the brazier and hook for the flourishes' brackets)
			id = env.add_prop(n, tag, radius(n))
	if id != "":
		n.set_meta(ID_META, id)


static func _unregister(n: Node3D) -> void:
	var env: Node = ENV.of(n.get_tree())
	if env != null and n.has_meta(ID_META):
		env.remove(str(n.get_meta(ID_META)))
	n.remove_meta(ID_META)


# --- asking -----------------------------------------------------------------------------------------------------

static func tag_of(n: Variant) -> String:
	return str((n as Node).get_meta(TAG_META, "")) if is_instance_valid(n) else ""


static func state(n: Variant) -> String:
	return str((n as Node).get_meta(STATE_META, "")) if is_instance_valid(n) else ""


## Still there to be used (not gone, toppled, torn).
static func live(n: Variant) -> bool:
	return is_instance_valid(n) and (n as Node).is_inside_tree() and not state(n) in ["gone", "toppled", "torn", "spilled"]


## The live pieces of `tag` whose footprint comes within `r` of `at` (flat), nearest first.
static func near(tree: SceneTree, tag: String, at: Vector3, r: float) -> Array:
	var out := []
	for n: Node in tree.get_nodes_in_group("env_" + tag):
		if live(n) and gap(n as Node3D, at) <= r:
			out.append(n)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return gap(a, at) < gap(b, at))
	return out


## How far `at` is from piece `n`'s footprint (0 on it): a floor tile's square, else its radius round its middle.
static func gap(n: Node3D, at: Vector3) -> float:
	var d := _flat(at - n.global_position)
	var spec: Dictionary = PIECES[tag_of(n)]
	if spec.get("floor", false):
		var h: float = float(spec.size.x) * 0.5
		return Vector2(maxf(absf(d.x) - h, 0.0), maxf(absf(d.z) - h, 0.0)).length()
	return maxf(d.length() - radius(n), 0.0)


## The floor piece of `tag` under `at`, or null.
static func under(tree: SceneTree, tag: String, at: Vector3) -> Node3D:
	for n: Node in tree.get_nodes_in_group("env_" + tag):
		if live(n) and gap(n as Node3D, at) <= 0.0:
			return n
	return null


## Whether the hero has the element for `verb` on `tag`: the indicator marks only what he can use.
static func usable(tag: String, verb: String) -> bool:
	if not verb in BUILT:
		return false
	for el: String in HERO_ELEMENTS:
		if EXCLUSIVE.get(el, {}).get(tag, []).has(verb):
			return true
	return false


# --- hits ---------------------------------------------------------------------------------------------------------

## A hit on piece `n` by element `el` (thrown_foe's names: wind storm, water ice, earth magma, void dark), from `by`
## (the hero, or anything in his room). `how`: "throw" (a thrown foe stopped on it), "landing" (a breaker came down
## by it), "element" (an element's hit reached it), "burst" (a keg went off by it). The element's verb if this hero
## has it (RULES_BY_ELEMENT, usable()), else the shared rule. Returns what it did ("" for nothing).
static func hit(n: Variant, el: String, by: Node, how := "throw") -> String:
	if not live(n):
		return ""
	var piece := n as Node3D
	var tag := tag_of(piece)
	var verb: String = RULES_BY_ELEMENT.get(el, {}).get(tag, "")
	var did := ""
	if verb != "" and usable(tag, verb):
		did = _verb(piece, verb, el, by, how)
	if did == "":
		did = _shared(piece, tag, el, by, how)
	if did != "":
		touched[piece.get_instance_id()] = did
	return did


## A flourish played on piece `n` (round 53, env_flourish.gd): it counts as touched for the [env] line's pieces=N/N.
static func touch(n: Node3D, verb: String) -> void:
	if is_instance_valid(n):
		touched[n.get_instance_id()] = verb


## A verb played (counted for the autotest's [env] line and the checks).
static func played(verb: String) -> void:
	verbs[verb] = int(verbs.get(verb, 0)) + 1


## The element verbs. Each lane adds its branch (keg, live_floor); Uproot and Frost Wall are moves, not hits, and call
## topple() / the frost wall themselves.
static func _verb(n: Node3D, verb_id: String, _el: String, by: Node, _how: String) -> String:
	match verb_id:
		"keg":
			return _keg(n, by)
		"live_floor":
			return _live(n)
		"conduct":
			return _conduct(n, by)
	return ""


## Live Floor: the grate goes live (or stays live LIVE_S longer). In a room whose `links` hold "grate" (the forge's
## bonded plates), every grate touching it goes live with it (linked()).
static func _live(n: Node3D) -> String:
	n.set_meta(&"live_until", Time.get_ticks_msec() + int(LIVE_S * 1000.0 / maxf(Game.slow, 0.01)))
	if not _linking:
		_linking = true
		for g: Node3D in linked(n):
			_live(g)
			touched[g.get_instance_id()] = "live"
		_linking = false
	if state(n) == "live":
		return "live"
	n.set_meta(STATE_META, "live")
	played("live_floor")
	var crawls := []
	var h: float = float(PIECES.grate.size.x) * 0.25
	for i in LIVE_CRAWLS:
		var c: Node3D = POLISH.loop(n, "arc_crawl", LIVE_CRAWL_SIZE, "wind", 6)
		c.position = Vector3((float(i % 2) - 0.5) * 2.0 * h, 0.35, (float(i >> 1) - 0.5) * 2.0 * h)
		crawls.append(c)
	var edge: float = float(PIECES.grate.size.x) * 0.5 - 0.15  # bigger crawls on the edge, out from under the pile
	for i in LIVE_EDGE_CRAWLS:
		var a := TAU * i / LIVE_EDGE_CRAWLS
		var c: Node3D = POLISH.loop(n, "arc_crawl", LIVE_EDGE_SIZE, "wind", 6)
		c.position = Vector3(clampf(cos(a) * 1.5, -1.0, 1.0) * edge, 0.5, clampf(sin(a) * 1.5, -1.0, 1.0) * edge)
		crawls.append(c)
	n.set_meta(&"env_tell", crawls)
	ComicFx.say("BZZZT!", n.global_position + Vector3.UP * 1.2, 0.5)
	Game.sfx("cast_wind", -6.0, 0.1)
	_live_tick(n)
	return "live"


static func _live_tick(n: Variant) -> void:
	if not is_instance_valid(n) or state(n) != "live":
		return
	var p := n as Node3D
	if Time.get_ticks_msec() >= int(p.get_meta(&"live_until", 0)):
		p.set_meta(STATE_META, "cold")
		for c: Variant in p.get_meta(&"env_tell", []):
			if is_instance_valid(c):
				c.erode_out(0.3)
		p.remove_meta(&"env_tell")
		return
	_live_rim(p)
	var VE: GDScript = _ve()
	_live_ticking = true
	for e: Node3D in on_tile(p):
		VE.mark(e, "charged")
	_live_ticking = false
	p.get_tree().create_timer(LIVE_TICK, false).timeout.connect(_live_tick.bind(p))


## The live grate's lime rim: a bolt along each of the tile's four edges, drawn again every tick.
static func _live_rim(n: Node3D) -> void:
	var e: float = float(PIECES.grate.size.x) * 0.5
	var c := Vector3(n.global_position.x, 0.12, n.global_position.z)
	var pts := PackedVector3Array()
	for k: Vector3 in [Vector3(-e, 0, -e), Vector3(e, 0, -e), Vector3(e, 0, e), Vector3(-e, 0, e), Vector3(-e, 0, -e)]:
		pts.append(c + k)
	DESIGNED.bolt_path(n.get_parent(), pts, LIVE_RIM_W)


## The floor pieces of `n`'s tag that are one piece with it in this room (rooms.gd `links`): every live tile reached
## from it through tiles sharing an edge, `n` left out. Empty where the room doesn't link the tag (the plain room, the
## room with pieces) or for a piece that isn't a floor tile.
static func linked(n: Node3D) -> Array:
	var tag := tag_of(n)
	if tag == "" or not PIECES[tag].get("floor", false) or not ROOMS.links(Game.room, tag):
		return []
	var size: float = float(PIECES[tag].size.x)
	var all: Array = n.get_tree().get_nodes_in_group("env_" + tag).filter(func(o: Node) -> bool: return live(o))
	var seen: Array = [n]
	var todo: Array = [n]
	while not todo.is_empty():
		var a: Node3D = todo.pop_back()
		for o: Node3D in all:
			if o in seen:
				continue
			var d := o.global_position - a.global_position
			var dx := absf(d.x)
			var dz := absf(d.z)
			if (absf(dx - size) < 0.05 and dz < 0.05) or (absf(dz - size) < 0.05 and dx < 0.05):
				seen.append(o)
				todo.append(o)
	seen.erase(n)
	return seen


## The living foes standing on floor piece `n` (its square).
static func on_tile(n: Node3D) -> Array:
	return n.get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		return e.is_alive() and gap(n, (e as Node3D).global_position) <= 0.0)


## The live grates in the room.
static func live_grates(tree: SceneTree) -> Array:
	return tree.get_nodes_in_group("env_grate").filter(func(g: Node) -> bool: return state(g) == "live")


## Torches conduct: torch `n` takes the current from `by` (the charged foe by it) and relays it along the wall.
static func _conduct(n: Node3D, by: Node) -> String:
	var now := Time.get_ticks_msec()
	var until := now + int(CONDUCT_S * 1000.0 / maxf(Game.slow, 0.01))
	if now < int(n.get_meta(&"relay_ms", 0)):
		n.set_meta(&"conduct_until", until)
		return "conducting"
	var chain := torch_chain(n)
	for t: Node3D in chain:
		t.set_meta(&"relay_ms", now + int(CONDUCT_CD * 1000.0))
		t.set_meta(&"conduct_until", until)
		if state(t) != "conducting":
			t.set_meta(STATE_META, "conducting")
			if t == n:
				played("conduct")
			_flare(t)
			_conduct_tick(t)
	_relay(chain, by)
	return "conducting"


## The lit torches the current runs through from `n`: `n`, then every one within CONDUCT_LINK of one already in (along
## the wall).
static func torch_chain(n: Node3D) -> Array:
	var out: Array = [n]
	var left: Array = n.get_tree().get_nodes_in_group("env_torch").filter(func(t: Node) -> bool:
		return t != n and live(t) and state(t) != "out")
	var grew := true
	while grew:
		grew = false
		for t: Node3D in left.duplicate():
			for o: Node3D in out:
				if _flat_d(t.global_position, o.global_position) <= CONDUCT_LINK:
					out.append(t)
					left.erase(t)
					grew = true
					break
	return out


## The relay: a lime bolt from the charged foe to the torch and on along the wall, and each torch's zap on the foes by it.
static func _relay(chain: Array, by: Node) -> void:
	var first := chain[0] as Node3D
	var tree := first.get_tree()
	var parent := first.get_parent()
	var hero: Node = tree.get_first_node_in_group("player")
	var mult: float = float(hero.get("_dmg_mult")) if hero != null and hero.get("_dmg_mult") != null else 1.0
	var VE: GDScript = _ve()
	var THROWN: GDScript = _thrown()
	var path := PackedVector3Array()
	if is_instance_valid(by) and by is Node3D:
		path.append((by as Node3D).global_position + Vector3.UP * 1.0)
	for t: Node3D in chain:
		path.append(_flame(t))
	if path.size() >= 2:
		DESIGNED.bolt_path(parent, path, 0.3)
	_relaying = true
	var zapped := {}
	if is_instance_valid(by):
		zapped[by] = true
	for t: Node3D in chain:
		for e: Node3D in FOES.near(tree, _flat(t.global_position), CONDUCT_REACH):
			if zapped.has(e) or THROWN.flying(e):
				continue
			zapped[e] = true
			DESIGNED.bolt(parent, _flame(t), e.global_position + Vector3.UP * 1.0, 0.26, 0.6)
			VE.zap_hit(e, CONDUCT_DAMAGE * mult)
			VE.mark(e, "charged")
			Game.register_hit("cast")
			t.set_meta(&"relayed", int(t.get_meta(&"relayed", 0)) + 1)
	_relaying = false
	Game.sfx("hit_big", -9.0, 0.15)


## A torch takes the current: its flame flares (a storm star on it, arcs crawling round it while it conducts), the word.
static func _flare(t: Node3D) -> void:
	DESIGNED.hit(t.get_parent(), _flame(t), "wind", 1.1)
	var c: Node3D = POLISH.loop(t, "arc_crawl", 1.6, "wind", 6)
	c.position = Vector3.UP * CONDUCT_FLAME
	t.set_meta(&"env_tell", c)
	var tw := t.create_tween()
	var home := t.scale
	tw.tween_property(t, "scale", home * 1.25, 0.06)
	tw.tween_property(t, "scale", home, 0.18)
	ComicFx.say(CONDUCT_WORD, _flame(t) + Vector3.UP * 0.8, 0.45)


static func _conduct_tick(n: Variant) -> void:
	if not is_instance_valid(n) or state(n) != "conducting":
		return
	var t := n as Node3D
	if Time.get_ticks_msec() >= int(t.get_meta(&"conduct_until", 0)):
		t.set_meta(STATE_META, "lit")
		var c: Variant = t.get_meta(&"env_tell") if t.has_meta(&"env_tell") else null
		if is_instance_valid(c):
			c.erode_out(0.3)
		t.remove_meta(&"env_tell")
		return
	t.get_tree().create_timer(0.25, false).timeout.connect(_conduct_tick.bind(t))


## The conducting torches in the room (Short Circuit's sources, the indicator's brackets).
static func conducting_torches(tree: SceneTree) -> Array:
	return tree.get_nodes_in_group("env_torch").filter(func(t: Node) -> bool: return state(t) == "conducting")


## Storm on foe `e`: the nearest lit torch within CONDUCT_REACH of it takes the current.
static func conduct_near(e: Node3D) -> void:
	if not usable("torch", "conduct"):
		return
	var best: Node3D = null
	for t: Node in e.get_tree().get_nodes_in_group("env_torch"):
		var d := _flat_d((t as Node3D).global_position, e.global_position)
		if live(t) and state(t) != "out" and d <= CONDUCT_REACH and (best == null or d < _flat_d(best.global_position, e.global_position)):
			best = t
	if best != null:
		hit(best, "wind", e, "element")


static func _flame(t: Node3D) -> Vector3:
	return t.global_position + Vector3.UP * CONDUCT_FLAME


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Powder Keg: the barrel catches (KEG_FUSE), then bursts.
static func _keg(n: Node3D, by: Node) -> String:
	if state(n) == "burning":
		return "burning"  # (a second foe into it feeds the fire)
	n.set_meta(STATE_META, "burning")
	played("keg")
	var tell: Node3D = POLISH.loop(n, "tell_molten", KEG_TELL, "earth")
	tell.position.y = 0.4
	n.set_meta(&"env_tell", tell)
	ComicFx.say("FSSSS!", n.global_position + Vector3.UP * 2.2, 0.45)
	Game.sfx("cast_earth", -8.0, 0.1)
	var tw := n.create_tween()
	tw.tween_interval(KEG_FUSE)
	tw.tween_callback(_keg_burst.bind(n, by))
	return "burning"


static func _keg_burst(n: Variant, by: Variant) -> void:
	if not is_instance_valid(n) or state(n) != "burning":
		return
	var p := n as Node3D
	var tree := p.get_tree()
	var at := _flat(p.global_position)
	var parent := p.get_parent()
	var tell: Variant = p.get_meta(&"env_tell") if p.has_meta(&"env_tell") else null
	if is_instance_valid(tell):
		(tell as Node).queue_free()
	p.remove_meta(&"env_tell")
	var hero: Node = tree.get_first_node_in_group("player")
	var mult: float = float(hero.get("_dmg_mult")) if hero != null and hero.get("_dmg_mult") != null else 1.0
	var VE: GDScript = _ve()
	var hit_n := 0
	for e: Node3D in FOES.near(tree, at, KEG_R):
		var away := _flat(e.global_position) - at
		e.take_hit(KEG_DAMAGE * mult, (away.normalized() if away.length() > 0.05 else Vector3.ZERO) * 5.0, 0.0, true)
		VE.mark(e, "molten")
		Game.register_hit("breaker")
		hit_n += 1
	p.set_meta(&"keg_hits", hit_n)
	DESIGNED.meteor(parent, at, KEG_R * 0.8)
	POLISH.chips(parent, at + Vector3.UP * 1.0, Color(0.55, 0.36, 0.2), STAVES, 8.0, Vector3.UP, true)
	_keg_word(tree, at, 0.0)
	Game.hitstop(0.06)
	Game.shake(0.7)
	Game.sfx("hit_big", -2.0, 0.08)
	p.visible = false
	use_up(p)
	for c: Node3D in near(tree, "crate", at, KEG_R):
		hit(c, "earth", hero, "burst")
	for b: Node3D in near(tree, "barrel", at, KEG_R):
		hit(b, "earth", hero, "element")  # (a chain: the next keg catches)
	_flourish().keg_spill(tree, at, hero)  # a lit brazier in reach tips (the forge's powder line)


## "KA-BLOOOM!" over the burst, once no other word or breaker leap holds the page (KEG_WORD_*).
static func _keg_word(tree: SceneTree, at: Vector3, waited: float) -> void:
	if tree == null:
		return
	var hero: Node = tree.get_first_node_in_group("player")
	var busy := ComicFx._inst != null and Time.get_ticks_msec() - int(ComicFx._inst.get("_last_word_ms")) < KEG_WORD_GAP_MS
	if hero != null and "state" in hero and hero.state == hero.State.LEAP:
		busy = true
	if busy and waited < KEG_WORD_WAIT:
		tree.create_timer(KEG_WORD_POLL, true, false, true).timeout.connect(_keg_word.bind(tree, at, waited + KEG_WORD_POLL))
		return
	keg_words += 1
	ComicFx.say(KEG_WORD, at + Vector3.UP * KEG_WORD_UP, 0.7)


## A foe took a state (void_element.mark): the pieces it reaches answer.
static func marked(e: Variant, st: String) -> void:
	if not is_instance_valid(e) or not (e as Node).is_inside_tree():
		return
	if st == "molten":
		molten_near(e)
		_flourish().molten_near(e)  # magma lights an out brazier
	elif st == "charged" and not _live_ticking:  # Live Floor: storm on a foe standing on a grate
		var g := under((e as Node).get_tree(), "grate", (e as Node3D).global_position)
		if g != null:
			hit(g, "wind", e, "element")
		if not _relaying:  # torches conduct
			conduct_near(e)


## Magma reached foe `e` (void_element.mark(e, "molten")): a barrel within KEG_CATCH of it catches.
static func molten_near(e: Node3D) -> void:
	if not usable("barrel", "keg"):
		return
	for b: Node3D in near(e.get_tree(), "barrel", e.global_position, KEG_CATCH):
		hit(b, "earth", e, "element")


## The shared rules (PIECES[tag].rule).
static func _shared(n: Node3D, tag: String, _el: String, _by: Node, how: String) -> String:
	match tag:
		"barrel":
			if how in ["throw", "burst"]:
				_break(n)
				return "broke"
		"crate":
			if how in ["throw", "landing", "burst"]:
				_break(n)
				return "broke"
		"banner":
			if how == "throw":
				_tear(n)
				return "torn"
		"spikes":
			if how == "throw":
				return "spiked"
		"rubble":
			if how == "landing":
				_chunks(n)
				return "chunks"
		"pillar", "chest":
			if how == "throw":
				return "splat"
	return ""


## Used up: hidden, its collider off, out of env_target, and back in REBUILD_S in the training room.
static func use_up(n: Node3D, to_state := "gone") -> void:
	n.set_meta(STATE_META, to_state)
	var body := n.get_node_or_null("EnvBody") as StaticBody3D
	if body != null:
		body.process_mode = Node.PROCESS_MODE_DISABLED  # (its shape leaves the physics space)
	_unregister(n)
	_rebuild_later(n)


static func _break(n: Node3D) -> void:
	var parent := n.get_parent()
	var at := n.global_position
	DESIGNED.dust(parent, at, 1.3)
	POLISH.chips(parent, at + Vector3.UP * 0.9, Color(0.55, 0.36, 0.2), STAVES, 6.5, Vector3.UP, true)
	ComicFx.say("KRAK!", at + Vector3.UP * 1.6, 0.55)
	Game.sfx("hit_big", -6.0, 0.15)
	n.visible = false
	use_up(n)


static func _tear(n: Node3D) -> void:
	n.set_meta(STATE_META, "torn")
	var home: Transform3D = n.transform
	var tw := n.create_tween()
	tw.tween_property(n, "position", home.origin + Vector3.DOWN * 2.6, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(n, "rotation:x", -1.3, 0.35)
	tw.tween_callback(func() -> void:
		n.visible = false
		n.transform = home)
	DESIGNED.dust(n.get_parent(), n.global_position, 0.9)
	_rebuild_later(n)


static func _chunks(n: Node3D) -> void:
	var env: Node = ENV.of(n.get_tree())
	var at := n.global_position
	if env != null:
		for i in 3:
			var a := TAU * i / 3.0 + randf()
			env._chunk(at + Vector3.UP * 0.5, Vector3(cos(a), 0.0, sin(a)) * ENV.CHUNK_SPEED * 0.7 + Vector3.UP * ENV.CHUNK_LIFT, i)


## Uproot has hold of pillar `n` (void_element.uproot_dive): it leaves the swing anchors and env_target now.
static func claim(n: Node3D) -> void:
	n.remove_from_group("grab_anchors")
	_unregister(n)


## Uproot brought pillar `n` down from `base` along `dir` (breaker_alt_fx.uproot_club lays it there): toppled, its
## collider off, two drawn rubble heaps at its ends; rubble for the room (back in REBUILD_S in training).
static func topple(n: Node3D, base: Vector3, dir: Vector3) -> void:
	claim(n)
	var room := n.get_parent()
	var left := []
	for k: float in [0.3, PIECES.pillar.size.y + 0.2]:
		var heap := ComicLook.piece("rubble_half")
		heap.scale = Vector3.ONE * 0.4
		heap.position = base + dir * k
		heap.rotation.y = randf() * TAU
		room.add_child(heap)
		left.append(heap)
	n.set_meta(&"env_leftovers", left)
	for h: Node3D in near(n.get_tree(), "hook", n.global_position, 1.4):  # round 53: a hook on the pillar goes with it
		h.visible = false
		use_up(h)
	use_up(n, "toppled")
	played("topple")
	_erode(n, left, base, dir)


## The toppled pillar `n` and its heaps erode RUBBLE_HOLD_S later (RUBBLE_* above); real time, so a hitstop doesn't
## stretch it. A room without the rebuild gets the flat decal as they go.
static func _erode(n: Node3D, heaps: Array, base: Vector3, dir: Vector3) -> void:
	var room := n.get_parent()
	var keep: bool = room != null and not room.get_meta(REBUILD_META, false)
	var tw := n.create_tween().set_ignore_time_scale(true)
	n.set_meta(ERODE_META, tw)
	var parts: Array = [n] + heaps
	var y0 := {}
	tw.tween_interval(RUBBLE_HOLD_S)
	tw.tween_callback(func() -> void:
		for p: Variant in parts:
			if is_instance_valid(p):
				y0[(p as Node).get_instance_id()] = (p as Node3D).position.y
				DESIGNED.dust((p as Node).get_parent(), (p as Node3D).global_position, RUBBLE_PUFF)
		if keep and is_instance_valid(room):
			var decal := ComicLook.piece(RUBBLE_DECAL)
			var length: float = PIECES.pillar.size.y
			decal.scale = Vector3(0.35, RUBBLE_DECAL_H, length / 4.0)
			decal.position = base + dir * length * 0.5
			decal.rotation.y = atan2(dir.x, dir.z)
			room.add_child(decal)
			n.set_meta(&"env_leftovers", heaps + [decal]))
	tw.tween_method(func(k: float) -> void:
		for p: Variant in parts:
			if is_instance_valid(p) and y0.has((p as Node).get_instance_id()):
				(p as Node3D).position.y = float(y0[(p as Node).get_instance_id()]) - RUBBLE_SINK * k * k, 0.0, 0.5, RUBBLE_ERODE_S * 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(n):
			DESIGNED.dust(n.get_parent(), n.global_position, RUBBLE_PUFF * 0.8))
	tw.tween_method(func(k: float) -> void:
		for p: Variant in parts:
			if is_instance_valid(p) and y0.has((p as Node).get_instance_id()):
				(p as Node3D).position.y = float(y0[(p as Node).get_instance_id()]) - RUBBLE_SINK * k * k, 0.5, 1.0, RUBBLE_ERODE_S * 0.5)
	tw.tween_callback(func() -> void:
		eroded += 1
		for p: Variant in parts:
			if is_instance_valid(p):
				(p as Node3D).visible = false)


## A breaker came down at `at` (void_element.breaker_impact): crates near it break, rubble under it throws chunks
## (RUBBLE_DAMAGE to everyone round it).
static func landing(by: Node3D, at: Vector3) -> void:
	if by == null or not by.is_inside_tree():
		return
	var tree := by.get_tree()
	for c: Node3D in near(tree, "crate", at, CRATE_LANDING_R):
		hit(c, "", by, "landing")
	for r: Node3D in near(tree, "rubble", at, 0.0):
		if hit(r, "", by, "landing") == "chunks":
			for e: Node3D in FOES.near(tree, at, RUBBLE_SPLASH_R):
				e.take_hit(RUBBLE_DAMAGE * float(by.get("_dmg_mult") if by.get("_dmg_mult") != null else 1.0), Vector3.ZERO, 0.0, false)
				Game.register_hit("breaker")


## A thrown foe stopped against something at `spot` flying along `dir` (thrown_foe._burst): the piece it hit, if it
## was one (the nearest within reach of a point just past the foe), else null.
static func struck(tree: SceneTree, spot: Vector3, dir: Vector3, foe_r: float) -> Node3D:
	var probe := _flat(spot) + _flat(dir).normalized() * (foe_r + 0.6)
	var best: Node3D = null
	var best_d := 0.9
	for n: Node in tree.get_nodes_in_group(GROUP):
		var p := n as Node3D
		if not live(p) or PIECES[tag_of(p)].get("floor", false) or PIECES[tag_of(p)].collider == "none":
			continue
		var d := gap(p, probe)
		if d < best_d:
			best_d = d
			best = p
	return best


## The wall_mult a throw that stopped on `n` pays: a breakable's is half the wall's (at least x1); a wall-like piece
## (pillar, chest) the full one.
static func splat_mult(n: Node3D, wall_mult: float) -> float:
	if n != null and PIECES[tag_of(n)].breaks:
		return maxf(1.0, wall_mult * SPLAT_HALF)
	return wall_mult


## A thrown foe's splat at `spot` on the wall: the banners hanging there within BANNER_NEAR tear.
static func wall_splat(tree: SceneTree, spot: Vector3, by: Node) -> void:
	for b: Node3D in near(tree, "banner", spot, BANNER_NEAR):
		hit(b, "", by, "throw")


# --- rebuild ------------------------------------------------------------------------------------------------------

static func _rebuild_later(n: Node3D) -> void:
	var room := n.get_parent()
	if room == null or not room.get_meta(REBUILD_META, false):
		return
	var tw := n.create_tween()
	tw.tween_interval(REBUILD_S)
	tw.tween_callback(rebuild.bind(n))


## Back as it was placed: its home spot and state, its collider on, registered again, a dust pop.
static func rebuild(n: Variant) -> void:
	if not is_instance_valid(n) or not (n as Node).is_inside_tree():
		return
	var p := n as Node3D
	var home: Dictionary = p.get_meta(HOME_META, {})
	if home.is_empty():
		return
	var erode: Variant = p.get_meta(ERODE_META, null) if p.has_meta(ERODE_META) else null
	if erode is Tween and (erode as Tween).is_valid():
		(erode as Tween).kill()  # (back mid-erosion: stand it up as placed)
	if p.has_meta(ERODE_META):
		p.remove_meta(ERODE_META)
	p.position = home.at
	p.rotation = Vector3(0.0, deg_to_rad(home.yaw), 0.0)
	p.visible = true
	p.set_meta(STATE_META, home.state)
	var body := p.get_node_or_null("EnvBody") as StaticBody3D
	if body != null:
		body.process_mode = Node.PROCESS_MODE_INHERIT
	if tag_of(p) == "pillar" and not p.is_in_group("grab_anchors"):
		p.add_to_group("grab_anchors")
	for extra: Variant in p.get_meta(&"env_leftovers", []):
		if is_instance_valid(extra):
			(extra as Node).queue_free()
	p.remove_meta(&"env_leftovers")
	if not p.has_meta(ID_META):
		_register(p)
	if tag_of(p) in ["hook", "brazier", "pool"]:  # the flourishes' pieces as placed (env_flourish.restore)
		_flourish().restore(p)
	DESIGNED.dust(p.get_parent(), p.global_position, POP_SIZE)


# --- the run's report ---------------------------------------------------------------------------------------------

## "pieces=touched/placed" over the counted pieces (the training layout's, by the dummies), and the verbs played.
static func report() -> String:
	var hit_n := 0
	for n: Variant in counted:
		if is_instance_valid(n) and touched.has((n as Node).get_instance_id()):
			hit_n += 1
	var vs := []
	for v: String in BUILT:
		vs.append("%s=%d" % [v, int(verbs.get(v, 0))])
	return "pieces=%d/%d %s" % [hit_n, counted.size(), " ".join(vs)]
