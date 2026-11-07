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

const GROUP := "env"
const STATE_META := &"env_state"
const TAG_META := &"env_tag"
const HOME_META := &"env_home"  # {at, yaw, state}: what a rebuild puts back
const ID_META := &"env_id"  # its id in env_target.structures, while registered
const REBUILD_META := &"env_rebuild"  # on the room: used-up pieces come back REBUILD_S after (training)
const REBUILD_S := 6.0
const POP_SIZE := 1.4  # the rebuild's dust pop

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
	"torch": {"models": ["torch_mounted"], "collider": "none", "wall": false, "breaks": false, "states": ["lit", "out"], "built": true,
		"rule": "Light; swings when a foe splats on the wall under it."},
	"brazier": {"models": ["column"], "stub": true, "collider": "cyl", "size": Vector2(0.4, 1.4), "wall": false, "breaks": true,
		"states": ["lit", "out", "spilled"], "built": false,
		"rule": "Floor fire bowl. A thrown foe knocks it over: a 2 m fire patch for 3 s that leaves molten on foes in it."},
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
	"pool": {"models": ["floor_tile_large_rocks"], "stub": true, "collider": "none", "floor": true, "size": Vector3(4.0, 0.0, 4.0),
		"wall": false, "breaks": false, "states": ["water", "frozen", "live", "steam"], "built": false,
		"rule": "Water: foes in it move at 0.8, and molten on them ends (quenched)."},
	"hook": {"models": ["wall_broken"], "stub": true, "collider": "none", "wall": true, "breaks": false, "states": ["empty", "hung"],
		"built": false, "rule": "Chains and hooks on a wall segment: a wall for everyone."},
	"ledge": {"models": ["wall_arched"], "stub": true, "collider": "none", "wall": true, "breaks": false, "states": [], "built": false,
		"rule": "A walkway along a wall 2.5 m up; its face is a wall."},
}

## Exclusive verbs by element (the proposal's open question 1 picked element): element -> piece -> verb ids. The
## structure indicator marks a piece for a verb only when the hero has the element (usable()), so the room reads
## differently per character: a grate glows under the heretic's indicator and is plain floor under the prince's.
const EXCLUSIVE := {
	"void": {"pillar": ["uproot"]},
	"earth": {"barrel": ["keg"]},
	"water": {"grate": ["frost_wall"]},
	"wind": {"grate": ["live_floor"]},
}
## Which verbs are in the game (the rest of EXCLUSIVE is the proposal's, still to build).
const BUILT := ["uproot", "keg", "frost_wall", "live_floor"]
## The elements each hero hits with (the heretic's four colours; the prince's from his draft card).
const HERO_ELEMENTS := {"heretic": ["void", "wind", "water", "earth"], "prince": ["dragonfire", "radiance", "steel"]}
## The element verbs a hit can trigger: element -> piece -> the verb hit() plays.
const RULES_BY_ELEMENT := {
	"earth": {"barrel": "keg"},
	"wind": {"grate": "live_floor"},
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

## Run counters (the autotest's [env] line): the pieces placed with `count` and the ones a hit has touched.
static var counted: Array = []
static var touched := {}  # instance id -> verb or rule it played last
static var verbs := {}  # verb id -> times


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
		"barrel", "crate", "chest", "grate":
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
	var d := Vector3(at.x - n.global_position.x, 0.0, at.z - n.global_position.z)
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


## Whether this hero (Game.hero) has the element for `verb` on `tag`: the indicator marks only what he can use.
static func usable(tag: String, verb: String) -> bool:
	if not verb in BUILT:
		return false
	for el: String in HERO_ELEMENTS.get(Game.hero, []):
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


## A verb played (counted for the autotest's [env] line and the checks).
static func played(verb: String) -> void:
	verbs[verb] = int(verbs.get(verb, 0)) + 1


## The element verbs. Each lane adds its branch (keg, live_floor); Uproot and Frost Wall are moves, not hits, and call
## topple() / the frost wall themselves.
static func _verb(_n: Node3D, _verb_id: String, _el: String, _by: Node, _how: String) -> String:
	return ""


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
	if DESIGNED.on():
		DESIGNED.dust(parent, at, 1.3)
		load("res://scripts/designed_polish.gd").chips(parent, at + Vector3.UP * 0.9, Color(0.55, 0.36, 0.2), STAVES, 6.5, Vector3.UP, true)
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
	if DESIGNED.on():
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
	use_up(n, "toppled")
	played("topple")


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
	var probe := Vector3(spot.x, 0.0, spot.z) + Vector3(dir.x, 0.0, dir.z).normalized() * (foe_r + 0.6)
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
	if DESIGNED.on():
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
