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
	"chain_halo": {"grid": Vector2(4, 3), "frames": 12, "kind": "sprite"},
	"daze_star": {"grid": Vector2(4, 1), "frames": 4, "kind": "sprite_depth"},
	"combo_burst": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"echo_axe": {"grid": Vector2(4, 1), "frames": 4, "kind": "sprite"},
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

## Chain halos (Fx.chain_spark, tiers 1-3 past Fx.CHAIN_TIERS): a sparkle behind the hit, strokes from tier 2, arcs at 3.
const HALO_SIZE := [1.2, 1.5, 1.85]  # m per tier
const HALO_TIMES := [0.033, 0.075, 0.06, 0.06]
## Daze stars (Fx.daze): two drawn cartoon stars circling the head, boiling on twos, depth tested (the head hides
## the one behind it).
const DAZE_SIZE := 0.56  # m: a star's quad (the old polygon star was 0.32 m across; 0.46 read as specks)
## Combo burst (Fx.combo_pop): burst lines thrown out all round him from a clear hole, tier-scaled.
const BURST_SIZE := 3.0  # m at tier 1, + BURST_GROW a tier
const BURST_GROW := 0.5
const BURST_TIMES := [0.033, 0.05, 0.05, 0.05, 0.06, 0.07]

## The spirit echo's ghost axe (spirit_echo.gd, designed): a drawn axe head flying the swing's outer arc with two
## edge echoes behind it, instead of the 3 m halftone axe mesh that covered his swing.
const ECHO_SIZE := 2.3  # m: the axe head's quad (the head is ~0.9 m tall in it; 1.25 read as a speck at the arc's edge)
const ECHO_REACH := 0.82  # of the echo's radius: on the arc's outer edge, past his own blade

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


## Fx.chain_spark (designed): one drawn halo behind the hit, in the colour's nearest element.
static func halo(parent: Node, at: Vector3, color: Color, tier: int) -> Node3D:
	_register()
	var k := clampi(tier, 1, 3) - 1
	var fx := DESIGNED.spawn(parent, "chain_halo", at, HALO_SIZE[k], DESIGNED.PAL.nearest(color), HALO_TIMES, Vector2(0.5, 1.0))
	fx.first = k * 4
	fx.real_until = 1
	return fx.vary(0.5, true)


## Fx.combo_pop (designed): burst lines all round him, never over him.
static func burst(parent: Node, at: Vector3, color: Color, tier: int) -> Node3D:
	_register()
	var t := clampi(tier, 1, 3)
	var times: Array = BURST_TIMES.duplicate()
	if t >= 3:
		times[1] = 0.1  # the big ones hold their peak
	var fx := DESIGNED.spawn(parent, "combo_burst", at, BURST_SIZE + BURST_GROW * (t - 1), DESIGNED.PAL.nearest(color), times, Vector2(0.45, 1.0))
	fx.real_until = 1
	return fx.vary(PI, true)


## Fx.daze (designed): two drawn stars on a spinning pivot over the head. Named "DazeStars" like the old one.
static func daze(node: Node3D, height: float, time: float, ring: float, spin: float) -> Node3D:
	_register()
	var pivot := Node3D.new()
	pivot.name = "DazeStars"
	node.add_child(pivot)
	pivot.position.y = height
	var stars: Array = []
	for i in 2:
		var a := TAU * i / 2.0
		var mi := MeshInstance3D.new()
		mi.mesh = QuadMesh.new()
		mi.material_override = DESIGNED.material("daze_star")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_ghost", true)
		mi.position = Vector3(cos(a), 0.0, sin(a)) * ring
		mi.scale = Vector3.ONE * DAZE_SIZE
		mi.set_instance_shader_parameter("pal_row", DESIGNED.row("gold"))
		mi.set_instance_shader_parameter("frame", float(i * 2))
		mi.set_instance_shader_parameter("erode", 0.0)
		mi.set_instance_shader_parameter("alpha", 1.0)
		pivot.add_child(mi)
		stars.append(mi)
	pivot.scale = Vector3.ONE * 0.2
	var tw := pivot.create_tween().set_parallel()
	tw.tween_property(pivot, "rotation:y", spin * time, time)
	tw.tween_property(pivot, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void:  # boil on twos, erode out over the last share
		for k in stars.size():
			var mi: MeshInstance3D = stars[k]
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("frame", float((int(v * 12.0) + k * 2) % 4))
				mi.set_instance_shader_parameter("erode", clampf((v / time - 0.72) / 0.28, 0.0, 1.0) * 0.98)
		, 0.0, time, time)
	tw.chain().tween_callback(pivot.queue_free)
	return pivot


## spirit_echo (designed): the drawn axe head for one sweep of `time` game s. Frame 0 the leading edge, 1-2 the head
## with its echoes over the sweep, 3 the edge left behind; spirit_echo.pose() moves and turns it (echo_pose()).
static func echo_axe(parent: Node, at: Vector3, color: Color, time: float) -> Node3D:
	_register()
	var times := [0.033, time * 0.5, time * 0.5, 0.09]
	var fx := DESIGNED.spawn(parent, "echo_axe", at, ECHO_SIZE, DESIGNED.PAL.nearest(color), times, Vector2(0.7, 1.0))
	fx.real_until = 1
	return fx


## Put the drawn axe at `at`, turned on screen so it flies towards `ahead` (a point a little further along the arc).
static func echo_pose(fx: Node3D, at: Vector3, ahead: Vector3) -> void:
	if fx == null or not is_instance_valid(fx) or not fx.is_inside_tree():
		return
	fx.global_position = at
	var cam := fx.get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.unproject_position(ahead) - cam.unproject_position(at)
	if d.length() > 0.001:
		fx.set_spin(atan2(-d.y, d.x), 1.0)
