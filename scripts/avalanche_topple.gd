extends Node3D
## Avalanche (Deep Freeze's window, round 51 cool pass; docs/features/combo-breakers.md "Round 51 cool pass"): the
## tentacles stacked the cubes into a tower on the dive (void_element.crush_point, stack slots from
## void_grab.aim_crush); he lands and they shove it over. In three beats after the landing:
##   1. stand: the tower stands STAND s with a tentacle on every cube (the landing's freeze holds it there);
##   2. topple: it tips over along `dir` (toward the structure the indicator marks, env_target "avalanche", or away
##      from him), pivoting on its foot, TIP s, eased in (slow, then falling);
##   3. spill: each cube breaks off as the tower comes down, top first, and slides on along the floor in the snow of the
##      `avalanche_spill` sheet: on_throw(foe, to) sends it (void_element: into the structure, or out to a stop).
## Game time (hit stops hold it). Headless it draws nothing but moves them.

const SELF := preload("res://scripts/avalanche_topple.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")

const STAND := 0.1  # s the tower stands after the landing
const TIP := 0.3  # s it takes to fall
const TIP_TO := 1.25  # radians it has turned through when the cubes break off (past flat, onto the floor)
const CHEST := Vector3(0.0, 0.85, 0.0)
const FLYING := "thrown_foe_flying"
const SPILL_TIMES := [0.05, 0.07, 0.08, 0.09, 0.16, 0.22]
const SPILL_W := 0.62  # of the spill's length, its width (the sheet's square holds a fan ~0.6 as wide as it runs)
const SPILL_MIN := 3.0  # m

var hero: CharacterBody3D
var foot := Vector3.ZERO
var dir := Vector3.FORWARD
var reach := 6.0  # m the spill runs (to the structure, or out)
var cubes := []  # {foe, h (height of its foot in the tower), tendril, thrown}
var on_throw := Callable()  # (foe, i) it breaks off the falling tower
var thrown := 0  # (checks)
var _t := 0.0
var _spilled := false


static func register() -> void:
	if not DESIGNED.extra_sheets.has("avalanche_spill"):
		DESIGNED.extra_sheets["avalanche_spill"] = {"tex": load("res://assets/vfx/designed/avalanche_spill.png"),
			"grid": Vector2(3, 2), "frames": 6, "kind": "ground"}


static func prewarm(root: Node3D) -> void:
	register()
	var mi := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2.ONE
	mi.mesh = p
	mi.material_override = DESIGNED.material("avalanche_spill")
	root.add_child(mi)
	mi.scale = Vector3.ONE * 20.0


## `stack`: the cubes bottom first (each stood on the last); `to_dir` the way it falls; `run` m the spill goes.
static func start(by: CharacterBody3D, at: Vector3, stack: Array, to_dir: Vector3, run: float) -> Node3D:
	var g: Node3D = SELF.new()
	g.hero = by
	g.foot = Vector3(at.x, 0.0, at.z)
	g.dir = Vector3(to_dir.x, 0.0, to_dir.z).normalized() if Vector3(to_dir.x, 0.0, to_dir.z).length() > 0.01 else Vector3.FORWARD
	g.reach = run
	var h := 0.0
	for e: Variant in stack:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		g.cubes.append({"foe": e, "h": h, "thrown": false})
		h += stack_step(e)
	by.get_parent().add_child(g)
	return g


## How tall a cube stands in the tower (its foe's ice: void_element.ice_radius is its width; a cube is about as tall).
static func stack_step(e: Variant) -> float:
	var r := 0.7
	if is_instance_valid(e) and e.get("radius") != null:
		r = float(e.radius) + 0.35
	return clampf(r * 1.9, 1.2, 2.2)


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for one: Dictionary in cubes:
		one.tendril = TENDRIL.new()
		one.tendril.line = true
		add_child(one.tendril)
		var e: Node3D = one.foe
		e.set_meta(FLYING, true)
		e.global_position = foot + Vector3.UP * float(one.h)


func _physics_process(delta: float) -> void:
	_t += delta
	var hand: Vector3 = hero._void._hand_pos() if is_instance_valid(hero) and hero._void != null else foot + Vector3.UP
	var k := clampf((_t - STAND) / TIP, 0.0, 1.0)
	var a := TIP_TO * k * k
	var left := false
	for i in range(cubes.size() - 1, -1, -1):  # top first
		var one: Dictionary = cubes[i]
		var e: Variant = one.foe
		var tendril: Node3D = one.tendril
		if one.thrown or not is_instance_valid(e) or not e.is_alive():
			tendril.visible = false
			continue
		left = true
		var foe := e as Node3D
		var h: float = float(one.h)
		var pos := foot + (dir * sin(a) + Vector3.UP * cos(a)) * h
		pos.y = maxf(pos.y, 0.0)
		foe.global_position = pos
		if foe is CharacterBody3D:
			(foe as CharacterBody3D).velocity = Vector3.ZERO
		tendril.draw(hand, pos + CHEST, 1.0, 0.02, 0.0, _t)
		# 3. it breaks off: the top once the tower is a third down, each lower one a beat later, the foot on the floor
		var off_at: float = 0.45 + 0.55 * (1.0 - h / maxf(_top(), 0.01))
		if k >= off_at or k >= 1.0:
			_throw(one, i)
	if k >= 0.45 and not _spilled:
		_spill()
	if not left and _t > STAND + TIP:
		queue_free()


func _top() -> float:
	return float(cubes[-1].h) if not cubes.is_empty() else 0.0


func _throw(one: Dictionary, i: int) -> void:
	one.thrown = true
	thrown += 1
	one.tendril.visible = false
	var e: Node3D = one.foe
	if e.has_meta(FLYING):
		e.remove_meta(FLYING)
	if on_throw.is_valid():
		on_throw.call(e, i)


func _spill() -> void:
	_spilled = true
	if not is_inside_tree():
		return
	register()
	var run := maxf(reach, SPILL_MIN)
	var fx: Node3D = DESIGNED.spawn(get_parent(), "avalanche_spill", foot, 1.0, "water", SPILL_TIMES, Vector2(0.6, 1.0))
	fx.real_until = 1
	var side := dir.cross(Vector3.UP).normalized()
	# the sheet runs along +u (the quad's x) from its left edge: lay x along the fall, centred half a run out
	fx.global_transform = Transform3D(Basis(dir * run, Vector3.UP, side * run * SPILL_W), foot + dir * run * 0.5
		+ Vector3.UP * (DESIGNED.GROUND_LIFT + 0.015))


func _exit_tree() -> void:
	for one: Dictionary in cubes:
		var e: Variant = one.foe
		if is_instance_valid(e) and not one.thrown:
			(e as Node3D).global_position.y = 0.0
			if (e as Node).has_meta(FLYING):
				(e as Node).remove_meta(FLYING)
