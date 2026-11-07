extends Node3D
## Environmental targeting (round 50, docs/features/environment.md). Zak: "maybe just an indicator to click on the
## structure for combos that require environment!" One node in the room (main.gd adds it and registers what it
## builds: the walls as segments, the pillars as points with a radius, the torches), so every ending or move that uses
## a wall or pillar asks the same thing: which structure this move would use from here.
##
## While a window or move that can use one is live (CTX below: Pinwheel's and Slapshot's windows, the counter's,
## Collapse's, Meteor Fall's, Molten Palm's and Lava Leash's wind-ups, the grab held next to a pillar), the node picks
## its structure every frame and draws the structure indicator on it in the ending's colour: an inked target bracket
## (env_bracket, tools/vfx_gen/gen_environment.py), a ring of inward chevrons round a pillar's foot, and a row of floor
## chevrons from the pile to it. Nothing in reach: a dim, dashed "too far" bracket on the nearest one.
##
## Click to choose: in a window that can choose (`choose`), the cursor (the nearest structure to the cursor's ray, within
## CURSOR_SNAP and the move's reach), or the right stick (the structure nearest its direction, STICK_CONE), switches the
## pick; the window's own press (L / H) is the trigger, so "click the structure" is the press with the cursor on it.
## Default is the auto pick. The pick is written on the hero (PICK_META) every frame, so the ending that lands after the
## press reads what was under the cursor when it was pressed (pick(), chosen()).
##
## The structures also play their beats when a thrown foe hits them (impact(), from thrown_foe's wall splat): a pillar
## cracks and sheds drawn chunks, a wall keeps a drawn mark per element for the room's life (MARK_CAP), a torch near
## the hit swings.

const SELF := preload("res://scripts/env_target.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")

const GROUP := "env_target"
const PICK_META := &"env_pick"
const SHEETS := {
	"env_bracket": {"grid": Vector2(4, 2), "frames": 8, "kind": "sprite"},
	"env_ring": {"grid": Vector2(2, 2), "frames": 4, "kind": "ground"},
	"env_chevron": {"grid": Vector2(4, 1), "frames": 4, "kind": "ground"},
	"env_chunk": {"grid": Vector2(4, 1), "frames": 4, "kind": "sprite"},
	"env_mark": {"grid": Vector2(3, 2), "frames": 6, "kind": "ground"},
}

## The windows and moves that use a structure. `reach` m from `from` (filled per ctx in context()); `choose`: the
## cursor / stick may pick; `far`: show the too-far bracket when nothing is in reach; `kinds` limits to pillars.
const CTX := {
	"pinwheel": {"el": "wind", "choose": true, "far": true},
	"slapshot": {"el": "earth", "choose": true, "far": true},
	"ricochet": {"el": "void", "choose": true, "far": true},
	"collapse": {"el": "void", "choose": true, "far": true},
	"meteor": {"el": "earth", "choose": true, "far": false},
	"palm": {"el": "earth", "choose": false, "far": true},
	"leash": {"el": "earth", "choose": false, "far": false},
	"pillar_slam": {"el": "void", "choose": true, "far": false, "kinds": ["pillar"]},
}
const CURSOR_SNAP := 2.2  # m from the cursor's ray to a structure that it counts as on it
const CURSOR_HEIGHTS := [0.3, 1.4, 2.8]  # m: the ray is sampled at these heights (a wall face, a pillar's body)
const STICK_DEAD := 0.5
const STICK_CONE := 32.0  # degrees
const PICK_FRESH_MS := 3000  # a pick written this long ago still holds (the ending lands after the press)
const COLLAPSE_REACH := 9.0  # m round the hole a structure takes Collapse's throw (void_element.COLLAPSE_WALL_*)
const METEOR_NEAR := 4.0  # m: a structure this close to Meteor Fall's pile is the wall it was splatted on
const LEASH_NEAR := 2.5  # m: a palm foe this close to a structure was torn off it
const PILLAR_SLAM_REACH := 4.5  # m from him to a pillar's face (void_grab.PILLAR_SLAM_*)
## The look. Bracket BRACKET_SIZE m at BRACKET_Y up (PILLAR_BRACKET_* on a pillar), WALL_OUT m out of the wall face;
## the pillar's floor ring RING_PAD m past its radius; floor chevrons CHEV_SIZE m every CHEV_STEP m from the pile.
const BRACKET_SIZE := 2.5
const BRACKET_Y := 1.3
const PILLAR_BRACKET_SIZE := 2.9
const PILLAR_BRACKET_Y := 1.7
const WALL_OUT := 0.45
const RING_PAD := 1.0
const CHEV_SIZE := 0.62
const CHEV_STEP := 1.05
const CHEV_MAX := 12
const POP_S := 0.07  # real s of the pop-in frame
const LOOP_S := 0.11  # real s a loop frame
const LOCK_S := [0.09, 0.14]  # real s of the lock's two frames
const FAR_ALPHA := 0.6
const FAR_ROW := "dust"
const AVAILABLE_ALPHA := 0.7
## The beats. A structure within HIT_NEAR m of a thrown foe's stop is what it hit.
const HIT_NEAR := 2.2
const MARK_CAP := 14  # marks the room keeps (oldest goes)
const MARK_SIZE := 1.9
const MARK_Y := 1.15
const MARK_FADE := 0.6  # s the oldest mark takes to go
const PILLAR_CRACK_SIZE := 2.4
const CHUNKS := 3  # pieces a pillar sheds per hit
const CHUNK_SIZE := 0.55
const CHUNK_SPEED := 5.5  # m/s out
const CHUNK_LIFT := 4.5  # m/s up
const CHUNK_LIFE := 1.1  # s
const TORCH_REACH := 3.5  # m along the wall from a hit that knocks a torch
const TORCH_SWING := 0.55  # radians
const TORCH_SWING_S := 1.4
const MARK_FRAME := {"hit": 0, "earth": 1, "water": 2, "void": 3, "wind": 4, "spirit": 0}
const MARK_ROW := {"hit": "dust", "spirit": "dust"}

var structures: Array = []  # {id, kind "wall" | "pillar", a, b, n (wall), at, r, node (pillar)}
var torches: Array = []  # {node, at}
var test_cursor := Vector3.INF  # tests: a ground point standing in for the cursor
var test_stick := Vector3.ZERO  # tests: the right stick's direction
var hero: CharacterBody3D

## What the indicator shows now ({} for nothing): {ctx, s, at, from, state "target" | "available" | "far", chosen}.
var current: Dictionary = {}
var shown := 0  # indicators started (checks)
var locks := 0
var switches := 0  # the pick changed mid-window (the cursor / stick)
var pillar_hits := 0
var chunks_shed := 0
var torch_swings := 0
var marks: Array = []  # MeshInstance3D, oldest first

var _bracket: MeshInstance3D
var _ring: MeshInstance3D
var _chevs: Array = []
var _t := 0.0
var _last_us := 0
var _lock_t := -1.0
var _last_key := ""  # ctx + structure id the indicator is on


static func of(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group(GROUP) if tree != null else null


static func register() -> void:
	for n: String in SHEETS:
		if not DESIGNED.extra_sheets.has(n):
			var s: Dictionary = SHEETS[n].duplicate()
			s["tex"] = load("res://assets/vfx/designed/%s.png" % n)
			DESIGNED.extra_sheets[n] = s


## Draw every material once at real size (elements.prewarm).
static func prewarm(root: Node3D) -> void:
	register()
	for n: String in SHEETS:
		var mi := MeshInstance3D.new()
		mi.mesh = QuadMesh.new() if SHEETS[n].kind == "sprite" else PlaneMesh.new()
		mi.material_override = DESIGNED.material(n)
		root.add_child(mi)
		mi.scale = Vector3.ONE * 20.0


func _ready() -> void:
	add_to_group(GROUP)
	register()
	top_level = true
	_bracket = _piece("env_bracket", QuadMesh.new())
	_ring = _piece("env_ring", _plane())
	for i in CHEV_MAX:
		_chevs.append(_piece("env_chevron", _plane()))
	_last_us = Time.get_ticks_usec()


func _plane() -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2.ONE
	return p


func _piece(sheet: String, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = DESIGNED.material(sheet)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.extra_cull_margin = 8.0
	mi.visible = false
	mi.set_instance_shader_parameter("erode", 0.0)
	mi.set_instance_shader_parameter("alpha", 1.0)
	add_child(mi)
	mi.top_level = true
	return mi


# --- the room -------------------------------------------------------------------------------------------------------

## A wall from `a` to `b` (flat, its face), `n` the flat normal into the room.
func add_wall(a: Vector3, b: Vector3, n: Vector3) -> void:
	structures.append({"id": "wall%d" % structures.size(), "kind": "wall", "a": _flat(a), "b": _flat(b), "n": _flat(n).normalized()})


## A pillar: its node (it shakes and sheds), its body's radius.
func add_pillar(node: Node3D, r: float) -> void:
	structures.append({"id": "pillar%d" % structures.size(), "kind": "pillar", "at": _flat(node.position), "r": r, "node": node})


func add_torch(node: Node3D) -> void:
	torches.append({"node": node, "at": node.position})


# --- geometry (pure: the check walks it) ----------------------------------------------------------------------------

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## The point of structure `s` nearest `from` (flat) and how far it is: {at, dist, n} (n: the face's normal there).
static func surface(s: Dictionary, from: Vector3) -> Dictionary:
	var p := _flat(from)
	if s.kind == "pillar":
		var off: Vector3 = p - s.at
		var d := off.length()
		var n: Vector3 = off / d if d > 0.01 else Vector3.BACK
		return {"at": s.at + n * float(s.r), "dist": maxf(d - float(s.r), 0.0), "n": n}
	var ab: Vector3 = s.b - s.a
	var k := clampf((p - s.a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	var at: Vector3 = s.a + ab * k
	return {"at": at, "dist": p.distance_to(at), "n": s.n}


static func _kind_ok(s: Dictionary, kinds: Array) -> bool:
	return kinds.is_empty() or kinds.has(s.kind)


## The nearest structure to `from`: {found (any at all), s, at, dist, dir, n, in_reach (within `reach`)}.
static func nearest(structs: Array, from: Vector3, reach: float, kinds: Array = []) -> Dictionary:
	var best := {"found": false, "in_reach": false, "dist": INF}
	for s: Dictionary in structs:
		if not _kind_ok(s, kinds):
			continue
		var f := surface(s, from)
		if float(f.dist) < float(best.dist):
			best = {"found": true, "s": s, "at": f.at, "dist": f.dist, "n": f.n}
	if best.found:
		best.in_reach = float(best.dist) <= reach
		var to: Vector3 = best.at - _flat(from)
		best.dir = to.normalized() if to.length() > 0.01 else -Vector3(best.n)
	return best


## The first structure along `dir` from `from` within `reach`: {found, s, at, dist, dir, n, in_reach}.
static func along(structs: Array, from: Vector3, dir: Vector3, reach: float, kinds: Array = []) -> Dictionary:
	var p := _flat(from)
	var d := _flat(dir).normalized()
	var best := {"found": false, "in_reach": false, "dist": INF}
	for s: Dictionary in structs:
		if not _kind_ok(s, kinds):
			continue
		var t := INF
		if s.kind == "pillar":
			var oc: Vector3 = p - s.at
			var bq := oc.dot(d)
			var cq := oc.length_squared() - float(s.r) * float(s.r)
			var disc := bq * bq - cq
			if disc >= 0.0:
				var t0 := -bq - sqrt(disc)
				t = t0 if t0 >= 0.0 else INF
		else:
			var n: Vector3 = s.n
			var den := d.dot(n)
			if den < -0.001:  # (heading into its face)
				var tt: float = (s.a - p).dot(n) / den
				var hit := p + d * tt
				var ab: Vector3 = s.b - s.a
				var k: float = (hit - s.a).dot(ab) / maxf(ab.length_squared(), 0.0001)
				if tt >= 0.0 and k >= -0.02 and k <= 1.02:
					t = tt
		if t < float(best.dist):
			var at := p + d * t
			best = {"found": true, "s": s, "at": at, "dist": t, "n": surface(s, at).n}
	if best.found:
		best.in_reach = float(best.dist) <= reach
		best.dir = d
	return best


## How far ground point `p` is from structure `s` (0 on it).
static func gap(s: Dictionary, p: Vector3) -> float:
	return float(surface(s, p).dist)


## The structure the cursor's ray (from `ray_from` along `ray_dir`) is on: the nearest within CURSOR_SNAP of one of
## the ray's points at CURSOR_HEIGHTS. {} if none.
static func under_ray(structs: Array, ray_from: Vector3, ray_dir: Vector3, kinds: Array = []) -> Dictionary:
	if absf(ray_dir.y) < 0.001:
		return {}
	var best: Dictionary = {}
	var best_d := CURSOR_SNAP
	for h: float in CURSOR_HEIGHTS:
		var p := ray_from + ray_dir * ((h - ray_from.y) / ray_dir.y)
		var s := under_point(structs, p, kinds, best_d)
		if not s.is_empty():
			best = s
			best_d = gap(s, p)
	return best


## The structure nearest ground point `p` within `snap` m, or {}.
static func under_point(structs: Array, p: Vector3, kinds: Array = [], snap := CURSOR_SNAP) -> Dictionary:
	var best: Dictionary = {}
	var best_d := snap
	for s: Dictionary in structs:
		if not _kind_ok(s, kinds):
			continue
		var d := gap(s, p)
		if d <= best_d:
			best_d = d
			best = s
	return best


## The structure nearest the stick's direction from `from` (within STICK_CONE), or {}.
static func along_stick(structs: Array, from: Vector3, stick: Vector3, reach: float, kinds: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var best_a := STICK_CONE
	var dir := _flat(stick).normalized()
	for s: Dictionary in structs:
		if not _kind_ok(s, kinds):
			continue
		var f := surface(s, from)
		if float(f.dist) > reach:
			continue
		var to: Vector3 = f.at - _flat(from)
		if to.length() < 0.05:
			continue
		var a := rad_to_deg(dir.angle_to(to.normalized()))
		if a <= best_a:
			best_a = a
			best = s
	return best


func by_id(id: String) -> Dictionary:
	for s: Dictionary in structures:
		if s.id == id:
			return s
	return {}


# --- what the moves ask ---------------------------------------------------------------------------------------------

## The structure `ctx` uses from `from` within `reach`: the pick the window last wrote on the hero (the cursor's, or the
## auto pick), else the nearest. {found, at, dir, dist, n, s, chosen}; {"none": true} with no room registered (the
## caller keeps its own raycast: tests that build bare rooms).
static func pick(by: Node3D, ctx: String, from: Vector3, reach: float) -> Dictionary:
	var env: Node = of(by.get_tree()) if by != null and by.is_inside_tree() else null
	if env == null or env.structures.is_empty():
		return {"none": true, "found": false}
	var kinds: Array = CTX.get(ctx, {}).get("kinds", [])
	var lock := _lock(by, ctx)
	if not lock.is_empty():
		var s: Dictionary = env.by_id(lock.id)
		if not s.is_empty():
			var f := surface(s, from)
			var to: Vector3 = f.at - _flat(from)
			var ok: bool = float(f.dist) <= reach + 0.5
			return {"found": ok, "at": f.at, "dist": f.dist, "n": f.n, "s": s, "chosen": lock.chosen,
				"dir": to.normalized() if to.length() > 0.01 else -Vector3(f.n)}
	var r := nearest(env.structures, from, reach, kinds)
	r.found = r.found and r.in_reach
	r.chosen = false
	return r


## The structure the player chose for `ctx` (cursor / stick) in its last window, or {}.
static func chosen(by: Node3D, ctx: String) -> Dictionary:
	var lock := _lock(by, ctx)
	if lock.is_empty() or not lock.chosen:
		return {}
	var env: Node = of(by.get_tree())
	return env.by_id(lock.id) if env != null else {}


static func _lock(by: Node3D, ctx: String) -> Dictionary:
	if by == null or not by.has_meta(PICK_META):
		return {}
	var lock: Dictionary = by.get_meta(PICK_META)
	if lock.get("ctx", "") != ctx or Time.get_ticks_msec() - int(lock.ms) > PICK_FRESH_MS:
		return {}
	return lock


# --- the live context -----------------------------------------------------------------------------------------------

## The window or move in play that uses a structure, or {}: {ctx, from, reach, mode "near" | "along", dir, key}.
func context(h: CharacterBody3D) -> Dictionary:
	var ve: GDScript = h.VOID_ELEMENT
	var me := _flat(h.global_position)
	if h.state == h.State.LEAP and h._brk_phase == 0 and not h._brk_locked and not h._brk.is_empty():
		var b: Dictionary = h._brk
		var alt: Dictionary = b.get("alt", {})
		var key := "leap:" + str(h._brk_id)
		if b.has("pinwheel") or alt.has("pinwheel"):
			return {"ctx": "pinwheel", "from": me, "reach": ve.PINWHEEL_REACH, "mode": "near", "key": key}
		if alt.has("slapshot"):
			var mid := _middle(h._void.held_foes(), _flat(h._brk_zone))
			return {"ctx": "slapshot", "from": mid, "reach": ve.SLIDE_REACH, "mode": "along", "dir": h._brk_dir, "key": key}
		if b.has("counter"):
			var foe: Variant = b.get("only")
			if is_instance_valid(foe):
				return {"ctx": "ricochet", "from": _flat((foe as Node3D).global_position), "reach": load("res://scripts/counter.gd").RICOCHET_REACH,
					"mode": "near", "key": key, "foe": foe}
			return {}
		if b.has("collapse"):
			return {"ctx": "collapse", "from": _flat(h._void.dark_spot), "reach": COLLAPSE_REACH, "mode": "near", "key": key}
		if b.has("meteor"):
			var spot: Dictionary = ve.meteor_spot(h)
			if spot.found:
				return {"ctx": "meteor", "from": _flat(spot.at), "reach": METEOR_NEAR, "mode": "near", "key": key}
		return {}
	if h.state != h.State.ATTACK:
		return {}
	var mkey := "move:%s:%d" % [h._move_id, h.get_instance_id()]
	if h._move_id == "EM" and h._hits_done == 0:
		return {"ctx": "palm", "from": me, "reach": ve.PALM_LENGTH * 0.6 + ve.PALM_WALL_REACH, "mode": "along", "dir": h._facing(), "key": mkey}
	if h._move_id == "XL" and h._hits_done == 0:
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if ve.palm_fresh(e) and ve.wall_fresh(e):
				return {"ctx": "leash", "from": _flat((e as Node3D).global_position), "reach": LEASH_NEAR, "mode": "near", "key": mkey}
		return {}
	if h._void.holds_for_slam():
		return {"ctx": "pillar_slam", "from": me, "reach": PILLAR_SLAM_REACH, "mode": "near", "key": "grab:%d" % h.get_instance_id()}
	return {}


static func _middle(foes: Array, fallback: Vector3) -> Vector3:
	var live := foes.filter(func(e: Variant) -> bool: return is_instance_valid(e))
	if live.is_empty():
		return fallback
	var m := Vector3.ZERO
	for e: Node3D in live:
		m += e.global_position
	return _flat(m / float(live.size()))


## The pick for a live context: the auto one, then the cursor's or the stick's where the window may choose.
func resolve(h: CharacterBody3D, c: Dictionary) -> Dictionary:
	var spec: Dictionary = CTX[c.ctx]
	var kinds: Array = spec.get("kinds", [])
	var r: Dictionary
	if c.mode == "along":
		r = along(structures, c.from, c.dir, c.reach, kinds)
		if not r.found:  # (nothing along the line at all: the nearest, for the too-far bracket)
			r = nearest(structures, c.from, c.reach, kinds)
			r.in_reach = false
	else:
		r = nearest(structures, c.from, c.reach, kinds)
	r.chosen = false
	if spec.choose:
		var s := _choice(h, c, kinds)
		if not s.is_empty():
			var f := surface(s, c.from)
			var to: Vector3 = f.at - _flat(c.from)
			r = {"found": true, "s": s, "at": f.at, "dist": f.dist, "n": f.n, "in_reach": true, "chosen": true,
				"dir": to.normalized() if to.length() > 0.01 else -Vector3(f.n)}
	if c.ctx == "meteor" and r.found and not r.chosen and not r.in_reach:
		return {"found": false}  # (a pile in the open: Meteor Fall isn't environmental there)
	return r


## The structure under the cursor (or the stick, or a test's stand-in) that is in reach for `c`, or {}.
func _choice(h: CharacterBody3D, c: Dictionary, kinds: Array) -> Dictionary:
	var s: Dictionary = {}
	if test_cursor != Vector3.INF:
		s = under_point(structures, test_cursor, kinds)
	elif test_stick.length() > STICK_DEAD:
		s = along_stick(structures, c.from, test_stick, c.reach, kinds)
	elif not h.bot_enabled and DisplayServer.get_name() != "headless":
		var stick := Vector3(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), 0.0, Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if not h._mouse_active and stick.length() > STICK_DEAD:
			s = along_stick(structures, c.from, stick, c.reach, kinds)
		elif h._mouse_active:
			var cam := get_viewport().get_camera_3d()
			if cam != null:
				var m := get_viewport().get_mouse_position()
				s = under_ray(structures, cam.project_ray_origin(m), cam.project_ray_normal(m), kinds)
	if s.is_empty():
		return {}
	if c.ctx == "meteor":  # (only a structure with the palm's foes by it: the dive goes to them)
		var ve: GDScript = h.VOID_ELEMENT
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if ve.palm_fresh(e) and gap(s, (e as Node3D).global_position) <= METEOR_NEAR:
				return s
		return {}
	return s if gap(s, c.from) <= float(c.reach) else {}


func _physics_process(_delta: float) -> void:
	if hero == null:
		var p: Variant = get_parent().get("player") if get_parent() != null else null
		if p is CharacterBody3D:
			hero = p
		else:
			return
	if not is_instance_valid(hero):
		return
	var c := context(hero)
	if c.is_empty():
		_end(hero)
		return
	var r := resolve(hero, c)
	if not r.get("found", false):
		_end(hero)
		return
	var state := "target" if r.in_reach else "far"
	if c.ctx == "ricochet" and state == "target" and not r.chosen:
		var counter: GDScript = load("res://scripts/counter.gd")
		hero.set_meta(PICK_META, {"ctx": c.ctx, "id": r.s.id, "chosen": false, "ms": Time.get_ticks_msec()})
		if counter.ricochet_target(hero, c.foe).kind == "foe":
			state = "available"  # (the foe it would hit is nearer: the wall is there for the click)
	if not CTX[c.ctx].far and state == "far":
		_end(hero)
		return
	hero.set_meta(PICK_META, {"ctx": c.ctx, "id": r.s.id if state != "far" else "", "chosen": r.chosen and state == "target",
		"ms": Time.get_ticks_msec(), "key": c.key})
	var key := "%s:%s:%s" % [c.key, r.s.id, state]
	if key != _last_key:
		if current.is_empty() or current.key_base != c.key:
			shown += 1
			_t = 0.0
		else:
			switches += 1
			_t = 0.0
		_last_key = key
	current = {"ctx": c.ctx, "s": r.s, "at": r.at, "n": r.n, "from": c.from, "state": state, "chosen": r.chosen,
		"key_base": c.key, "el": CTX[c.ctx].el}
	_lock_t = -1.0


## The context is over: a press that took it (the leap dove, the palm hit, the slam began) locks the bracket on the
## structure for LOCK_S; anything else clears it.
func _end(h: CharacterBody3D) -> void:
	if current.is_empty():
		return
	var took := false
	if current.key_base.begins_with("leap:"):
		took = h.state == h.State.LEAP and h._brk_phase == 1
	elif current.key_base.begins_with("move:"):
		took = h.state == h.State.ATTACK and h._hits_done > 0
	elif current.key_base.begins_with("grab:"):
		took = h._void.pillar_slam_on()
	if took and current.state == "target" and _lock_t < 0.0:
		locks += 1
		_lock_t = 0.0
		return
	if _lock_t < 0.0:
		_clear()


func _clear() -> void:
	current = {}
	_last_key = ""
	_lock_t = -1.0
	_bracket.visible = false
	_ring.visible = false
	for c: MeshInstance3D in _chevs:
		c.visible = false


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := float(now - _last_us) / 1000000.0
	_last_us = now
	if current.is_empty():
		return
	_t += real
	var frame := 0
	if _lock_t >= 0.0:
		_lock_t += real
		if _lock_t >= LOCK_S[0] + LOCK_S[1]:
			_clear()
			return
		frame = 4 if _lock_t < LOCK_S[0] else 5
	elif current.state == "far":
		frame = 6
	elif current.state == "available":
		frame = 7
	elif _t >= POP_S:
		frame = 1 + int((_t - POP_S) / LOOP_S) % 3
	_draw(frame)


func _draw(frame: int) -> void:
	var s: Dictionary = current.s
	var pillar: bool = s.kind == "pillar"
	var row: String = FAR_ROW if current.state == "far" else current.el
	var alpha := 1.0
	if current.state == "far":
		alpha = FAR_ALPHA * (0.75 + 0.25 * sin(_t * 6.0))
	elif current.state == "available":
		alpha = AVAILABLE_ALPHA
	var at: Vector3 = current.at
	var n: Vector3 = current.n
	_bracket.visible = true
	if pillar:
		_bracket.global_position = Vector3(s.at.x, PILLAR_BRACKET_Y, s.at.z)
		_bracket.scale = Vector3.ONE * PILLAR_BRACKET_SIZE
	else:
		_bracket.global_position = at + n * WALL_OUT + Vector3.UP * BRACKET_Y
		_bracket.scale = Vector3.ONE * BRACKET_SIZE
	_tone(_bracket, frame, row, alpha)
	_ring.visible = pillar and frame <= 3 or (pillar and current.state == "far")
	if _ring.visible:
		var rf := 3 if current.state == "far" else (frame - 1 if frame >= 1 else 0)
		_ring.global_position = Vector3(s.at.x, DESIGNED.GROUND_LIFT + 0.01, s.at.z)
		_ring.scale = Vector3.ONE * (float(s.r) + RING_PAD) * 2.0
		_tone(_ring, rf, row, alpha)
	# the aim line: floor chevrons from the pile to it, marching in (none too far or locked)
	var from: Vector3 = current.from
	var to := at - from
	var length := to.length()
	var dir := to / length if length > 0.01 else Vector3.FORWARD
	var count := 0
	if current.state != "far" and _lock_t < 0.0:
		count = clampi(int((length - 0.6) / CHEV_STEP), 0, CHEV_MAX)
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP)).scaled(Vector3(CHEV_SIZE, 1.0, CHEV_SIZE))
	for i in CHEV_MAX:
		var c: MeshInstance3D = _chevs[i]
		c.visible = i < count
		if not c.visible:
			continue
		c.global_transform = Transform3D(basis, from + dir * (0.9 + CHEV_STEP * i) + Vector3.UP * (DESIGNED.GROUND_LIFT + 0.02))
		var march := posmod(i - int(_t / 0.08), 4)
		_tone(c, [0, 1, 2, 1][march], row, alpha * (0.6 + 0.4 * float(i + 1) / float(maxi(count, 1))))


func _tone(mi: MeshInstance3D, frame: int, row: String, alpha: float) -> void:
	mi.set_instance_shader_parameter("frame", float(frame))
	mi.set_instance_shader_parameter("pal_row", DESIGNED.row(row))
	mi.set_instance_shader_parameter("alpha", alpha)


# --- the beats ------------------------------------------------------------------------------------------------------

## A thrown foe stopped against something at `at` (flat), flying along `dir`, in element `el` (thrown_foe's wall splat,
## the pillar slam): the structure it hit plays its beat. Returns the structure's kind, or "".
static func impact(by: Node, at: Vector3, dir: Vector3, el: String) -> String:
	var env: Node = of(by.get_tree()) if by != null and by.is_inside_tree() else null
	if env == null:
		return ""
	return env.hit_at(at, dir, el)


func hit_at(at: Vector3, dir: Vector3, el: String) -> String:
	var probe := _flat(at) + _flat(dir).normalized() * 0.6
	var s := under_point(structures, probe, [], HIT_NEAR)
	if s.is_empty():
		return ""
	var f := surface(s, probe)
	if s.kind == "pillar":
		_pillar_hit(s, f, el)
	else:
		_wall_hit(s, f, el)
	return s.kind


func _pillar_hit(s: Dictionary, f: Dictionary, el: String) -> void:
	pillar_hits += 1
	var n: Vector3 = f.n
	var face: Vector3 = f.at + n * 0.08
	# a tall crack up its face (stays), drawn stone chunks thrown off it
	_mark(face + Vector3.UP * 1.6, n, 5, "dust", PILLAR_CRACK_SIZE)
	if DESIGNED.on():
		DESIGNED.dust(get_parent(), _flat(face), 1.0)
	var side := n.cross(Vector3.UP)
	for i in CHUNKS:
		var out := (n + side * randf_range(-0.9, 0.9)).normalized()
		var start := face + Vector3.UP * randf_range(1.0, 2.6)
		_chunk(start, out * CHUNK_SPEED * randf_range(0.7, 1.15) + Vector3.UP * CHUNK_LIFT * randf_range(0.6, 1.1), i)
	var node: Variant = s.get("node")
	if is_instance_valid(node) and (node as Node3D).is_inside_tree():
		load("res://scripts/designed_breaker.gd").shake_pillars(get_tree(), (node as Node3D).global_position)
	Game.sfx("quake", -8.0, 0.1)


## One drawn chunk flying off on an arc, tumbling, then breaking up on the floor.
func _chunk(start: Vector3, v: Vector3, i: int) -> void:
	chunks_shed += 1
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	mi.material_override = DESIGNED.material("env_chunk")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	get_parent().add_child(mi)
	mi.top_level = true
	mi.global_position = start
	mi.scale = Vector3.ONE * CHUNK_SIZE * randf_range(0.8, 1.3)
	_tone(mi, (i + randi() % 4) % 4, "dust", 1.0)
	mi.set_instance_shader_parameter("erode", 0.0)
	mi.set_instance_shader_parameter("spin", randf_range(-PI, PI))
	var land_t := (v.y + sqrt(v.y * v.y + 2.0 * 9.8 * maxf(start.y - 0.25, 0.0))) / 9.8
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		mi.global_position = Vector3(start.x + v.x * t, maxf(start.y + v.y * t - 4.9 * t * t, 0.25), start.z + v.z * t)
		mi.set_instance_shader_parameter("spin", t * 9.0 * (1.0 if i % 2 == 0 else -1.0)), 0.0, land_t, land_t)
	tw.tween_method(func(e: float) -> void: mi.set_instance_shader_parameter("erode", e), 0.0, 0.98, CHUNK_LIFE * 0.5).set_delay(CHUNK_LIFE * 0.3)
	tw.tween_callback(mi.queue_free)


func _wall_hit(s: Dictionary, f: Dictionary, el: String) -> void:
	var e: String = load("res://scripts/fx_palette.gd").ALIAS.get(el, el)
	var frame: int = MARK_FRAME.get(e, 0)
	_mark(f.at + Vector3(s.n) * 0.06 + Vector3.UP * MARK_Y, s.n, frame, MARK_ROW.get(e, e), MARK_SIZE * randf_range(0.9, 1.15))
	for t: Dictionary in torches:
		var node: Variant = t.node
		if not is_instance_valid(node):
			continue
		var tn := node as Node3D
		if _flat(tn.global_position).distance_to(_flat(f.at)) <= TORCH_REACH:
			_swing_torch(tn, s, f.at)


## A drawn mark on a structure's face at `at`, facing `n`, that stays for the room's life (the oldest past MARK_CAP goes).
func _mark(at: Vector3, n: Vector3, frame: int, row: String, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _plane()
	mi.material_override = DESIGNED.material("env_mark")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	get_parent().add_child(mi)
	mi.top_level = true
	var y := _flat(n).normalized()
	var x := Vector3.UP.cross(y).normalized()  # (along the face)
	var z := x.cross(y)  # (the sheet's v runs down the face)
	mi.global_transform = Transform3D(Basis(x, y, z).scaled(Vector3(size, 1.0, size)), at)
	mi.rotate_object_local(Vector3.UP, randf_range(-0.3, 0.3) if frame != 5 else 0.0)
	_tone(mi, frame, row, 1.0)
	mi.set_instance_shader_parameter("erode", 0.0)
	marks.append(mi)
	while marks.size() > MARK_CAP:
		var old: Variant = marks.pop_front()
		if is_instance_valid(old):
			var o := old as MeshInstance3D
			var tw := o.create_tween()
			tw.tween_method(func(e: float) -> void: o.set_instance_shader_parameter("erode", e), 0.0, 0.98, MARK_FADE)
			tw.tween_callback(o.queue_free)
	return mi


## A torch knocked swinging on its mount: a damped swing along the wall, sparks off its flame.
func _swing_torch(t: Node3D, s: Dictionary, at: Vector3) -> void:
	if t.has_meta("env_swinging"):
		return
	torch_swings += 1
	t.set_meta("env_swinging", true)
	var along := (_flat(t.global_position) - _flat(at)).dot(Vector3(s.b - s.a).normalized())
	var sgn := 1.0 if along >= 0.0 else -1.0
	var axis: Vector3 = Vector3(s.n)
	var home := t.transform
	var tw := t.create_tween()
	tw.tween_method(func(k: float) -> void:
		var ang := TORCH_SWING * sgn * exp(-3.2 * k) * sin(k * TAU * 2.2)
		t.transform = Transform3D(home.basis.rotated(axis, ang), home.origin), 0.0, 1.0, TORCH_SWING_S)
	tw.tween_callback(func() -> void:
		t.transform = home
		t.remove_meta("env_swinging"))
	if DESIGNED.on():
		DESIGNED.hit(get_parent(), t.global_position + Vector3.UP * 0.5, "earth", 0.45)
	Game.sfx("hit", -12.0, 0.15)
