extends Node3D
## Round 46 (fx-finish, docs/features/designed-fx.md "Round 46"): designed versions of the last polygon effects,
## the Awakening first. Sheets: tools/vfx_gen/gen_finish.py (registered in DESIGNED.extra_sheets here); plays
## through designed_fx.gd's palette, timeline node and shaders.
##
## The Awakening (awaken()): an authored event in gold, in three beats on real time (his own freeze must not hold it):
##   anticipation  awaken_gather: manga focus lines and gold motes pulled in to his chest (GATHER_TIMES)
##   peak          awaken_crown: a crown of inked gold flame tongues bursting up round him, stood just behind him
##                 and depth tested (he stays in front), held and boiled; awaken_floor: a sunburst of gold rays
##                 racing out on the floor (the reach that blows the foes back)
##   dissolve      the tongues lift off the floor, throw licks and erode; the rays thin and erode from their tips
## Nothing covers him: the gather's hole is wider than he is, the crown is behind him.

const DESIGNED := preload("res://scripts/designed_fx.gd")
const SELF := preload("res://scripts/designed_finish.gd")

const SHEETS := {
	"awaken_gather": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"awaken_crown": {"grid": Vector2(4, 2), "frames": 8, "kind": "sprite_depth", "anchor": Vector2(0.0, -0.35)},
	"awaken_floor": {"grid": Vector2(3, 2), "frames": 6, "kind": "ground"},
}

const GATHER_SIZE := 5.2  # m: the focus lines' square (the hole in it is 0.27 of the half: ~1.4 m across)
const GATHER_UP := 0.85  # m: centred on his chest
const GATHER_TIMES := [0.05, 0.05, 0.045, 0.04, 0.035, 0.05]  # 0.27 s: the freeze he Awakens in (0.25 s)
const CROWN_SIZE := 5.4  # m: the crown's square (the tallest tongues stand ~3 m; 4.6 read hero-sized in the punch-in)
const CROWN_BACK := 0.55  # m behind him, away from the camera: depth tested, he reads in front of it
const CROWN_TIMES := [0.045, 0.13, 0.13, 0.08, 0.08, 0.085, 0.09, 0.1]  # anticipation, held peak and boil, dissolve
const CROWN_ERODE := Vector2(0.5, 1.0)
const FLOOR_SIZE := 6.4  # m: the sunburst's square (the rays reach ~3 m: AWAKEN_BURST_RADIUS blows foes out of it)
const FLOOR_TIMES := [0.04, 0.07, 0.07, 0.08, 0.09, 0.1]
const FLOOR_ERODE := Vector2(0.45, 1.0)

static var _registered := false
static var drawn := 0  # Awakenings drawn (checks)

var _hero: Node3D
var _at := Vector3.ZERO
var _t := 0.0
var _last_us := 0
var _peaked := false


static func _register() -> void:
	if _registered:
		return
	_registered = true
	for n: String in SHEETS:
		var s: Dictionary = SHEETS[n].duplicate()
		s["tex"] = load("res://assets/vfx/designed/%s.png" % n)
		DESIGNED.extra_sheets[n] = s


## Draw every material once at real size (elements.prewarm).
static func prewarm(root: Node3D) -> void:
	if not DESIGNED.on():
		return
	_register()
	for n: String in SHEETS:
		var mi := MeshInstance3D.new()
		mi.mesh = PlaneMesh.new() if SHEETS[n].kind == "ground" else QuadMesh.new()
		mi.material_override = DESIGNED.material(n)
		root.add_child(mi)
		mi.scale = Vector3.ONE * 20.0


## The Awakening's look round `hero` (awaken_flourish._show, designed): the gather now, the peak GATHER_TIMES later.
static func awaken(parent: Node, hero: Node3D, at: Vector3) -> Node3D:
	_register()
	drawn += 1
	var fx: Node3D = SELF.new()
	fx._hero = hero
	fx._at = at
	parent.add_child(fx)
	fx.top_level = true
	fx.global_position = at
	var g := DESIGNED.spawn(parent, "awaken_gather", at + Vector3.UP * GATHER_UP, GATHER_SIZE, "gold", GATHER_TIMES, Vector2(0.8, 1.0))
	g.real_time = true
	g.set_spin(randf_range(-0.3, 0.3), 1.0)
	_ride(g, hero, Vector3.UP * GATHER_UP)
	return fx


static func _ride(fx: Node3D, hero: Node3D, off: Vector3) -> void:
	if hero != null and is_instance_valid(hero):
		fx.follow = hero
		fx.follow_off = off


func _ready() -> void:
	_last_us = Time.get_ticks_usec()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := float(now - _last_us) / 1000000.0
	_last_us = now
	_t += delta if DESIGNED.game_time_only else real
	if _peaked:
		return
	var due := 0.0
	for d: float in GATHER_TIMES:
		due += d
	if _t < due - 0.02:  # (the crown's own anticipation frame overlaps the gather's snap)
		return
	_peaked = true
	_peak()
	queue_free()


func _peak() -> void:
	var parent := get_parent()
	var foot := _at
	if _hero != null and is_instance_valid(_hero):
		foot = _hero.global_position
	foot.y = 0.0
	var back := Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var away := -cam.global_basis.z
		back = Vector3(away.x, 0.0, away.z).normalized() * CROWN_BACK
	var crown := DESIGNED.spawn(parent, "awaken_crown", foot + back, CROWN_SIZE, "gold", CROWN_TIMES, CROWN_ERODE)
	crown.real_time = true
	crown.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	_ride(crown, _hero, back)
	var floor_ := DESIGNED.spawn(parent, "awaken_floor", foot + Vector3.UP * DESIGNED.GROUND_LIFT, FLOOR_SIZE, "gold", FLOOR_TIMES, FLOOR_ERODE)
	floor_.real_time = true
	floor_.rotation.y = randf() * TAU
