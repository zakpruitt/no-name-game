extends RefCounted
## Round 44 (fx-cohesion, docs/features/designed-fx.md): the designed versions of the effects that still drew as
## runtime polygons after the pilot (the tentacle's skin, the ground stamps that replace the flat floor hoops, the
## per-element hit pop). Sheets: tools/vfx_gen/gen_cohesion.py. Kept beside designed_fx.gd (the storm lane adds
## to that file) and reusing its palette, timeline node and shaders.

const DESIGNED := preload("res://scripts/designed_fx.gd")
const SELF := preload("res://scripts/designed_ink.gd")


## Draw every material this file uses once at real size (elements.prewarm), so nothing compiles mid-fight.
static func prewarm(root: Node3D) -> void:
	if not DESIGNED.on():
		return
	var at := root.global_position
	var t: Node3D = load("res://scripts/void_tendril.gd").new()
	root.add_child(t)
	t.draw(at, at + Vector3(3.0, 0.0, 0.0), 1.0, 0.1, 0.5, 0.0)
	t.draw(at, at + Vector3(0.0, 0.0, 3.0), 1.0, 0.1, 0.0, 0.1)  # (a jump: no smear; the smear is warmed below)
	_register()
	for n: String in ["pop_storm", "pop_magma", "pop_ice", "pop_dark", "stamp"] + LOOP_SHEETS:
		var mi := MeshInstance3D.new()
		mi.mesh = QuadMesh.new()
		mi.material_override = stamp_material("shock") if n == "stamp" else DESIGNED.material(n)
		root.add_child(mi)
		mi.scale = Vector3.ONE * 20.0
	var trail: MeshInstance3D = load("res://scripts/weapon_trail.gd").new()  # (its designed ribbon's shader)
	root.add_child(trail)
	trail.mesh = QuadMesh.new()
	trail.scale = Vector3.ONE * 20.0
	trail.set_process(false)
	var smear := MeshInstance3D.new()
	smear.mesh = QuadMesh.new()
	smear.material_override = t.smear_material()
	root.add_child(smear)
	smear.scale = Vector3.ONE * 20.0


# --- Ground stamps (round 44): the floor shock lines that replace the flat hoops ---------------------------------

const STAMP_SHADER := preload("res://shaders/designed_stamp.gdshader")
const STAMP_SHEETS := {
	"shock": {"tex": preload("res://assets/vfx/designed/stamp_shock.png"), "rows": 4.0},
	"cue": {"tex": preload("res://assets/vfx/designed/stamp_cue.png"), "rows": 4.0},
}
const STAMP_ASPECT := 6.0  # the strips are 6:1: a tile round the circle is this many band widths long
const STAMP_LIFT := 0.07  # m over the floor (the stones reach 0.05)
const SHOCK_W := 0.42  # m: the band a shock line is drawn in (its fattest part fills ~75% of it)
const SHOCK_THIN_W := 0.3  # m: thin_hoop's
const SHOCK_FROM := 0.45  # of the radius: where it starts racing out from
const SHOCK_LIFE_MAX := 0.35  # s real: slow motion never holds one longer than this
const SHOCK_LIFE := Vector2(0.15, 0.25)  # s: a shock line is an accent, not a lingering ring (round 45)
const SHOCK_APART := 5.0  # m: a second shock this close to a live one is dropped (one floor mark an event)
const STEP := 1.0 / 12.0

static var _stamp_mats := {}
static var _last_shock: WeakRef
static var _cues: Array[WeakRef] = []


static func stamp_material(sheet: String) -> ShaderMaterial:
	if _stamp_mats.has(sheet):
		return _stamp_mats[sheet]
	var s: Dictionary = STAMP_SHEETS[sheet]
	var m := ShaderMaterial.new()
	m.shader = STAMP_SHADER
	m.set_shader_parameter("sheet", s.tex)
	m.set_shader_parameter("palette", DESIGNED.palette())
	m.set_shader_parameter("palette_rows", float(DESIGNED.ROWS.size()))
	m.set_shader_parameter("rows", s.rows)
	_stamp_mats[sheet] = m
	return m


## A floor shock: a broken inked brush line racing out to `radius` in `color`, eroding as it goes.
## Round 45: none while a breaker cue is closing (its ring is the only ring on screen then) and at most one alive
## near the spot (a crowd hit or a ring pair calls this several times in one beat).
static func shock(parent: Node, at: Vector3, color: Color, radius: float, time := 0.35, width := SHOCK_W) -> Node3D:
	if cue_live():
		return null
	var last: Node3D = _last_shock.get_ref() if _last_shock else null
	if last and is_instance_valid(last) and last.is_inside_tree() 			and Vector2(last.global_position.x - at.x, last.global_position.z - at.z).length() < SHOCK_APART:
		return null
	var s: Node3D = Shock.new()
	_last_shock = weakref(s)
	parent.add_child(s)
	s.setup(Vector3(at.x, STAMP_LIFT, at.z), color, radius, time, width)
	return s


## The breaker cue says it is on screen (breaker_cue._ready); `cue_live()` is true while one is still closing.
static func cue_on(cue: Node) -> void:
	_cues.append(weakref(cue))
	var last: Node = _last_shock.get_ref() if _last_shock else null
	if last and is_instance_valid(last):  # a shock still racing out from the string's last hit goes now
		last.queue_free()


static func cue_live() -> bool:
	for i in range(_cues.size() - 1, -1, -1):
		var c: Node = _cues[i].get_ref()
		if c == null or not is_instance_valid(c) or c.is_queued_for_deletion():
			_cues.remove_at(i)
		elif c.is_inside_tree() and c.closing():
			return true
	return false


## A flat annulus of `segs` pieces with the strip's UVs (x round, y across). For the stamps and the cue.
static func annulus(mesh: ArrayMesh, r: float, w: float, segs: int, mat: Material) -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var r0 := maxf(r - w * 0.5, 0.0)
	var r1 := r + w * 0.5
	for i in segs + 1:
		var a := TAU * i / segs
		var d := Vector3(sin(a), 0.0, cos(a))
		verts.append(d * r0)
		verts.append(d * r1)
		uvs.append(Vector2(float(i) / segs, 0.0))
		uvs.append(Vector2(float(i) / segs, 1.0))
		if i > 0:
			var b := (i - 1) * 2
			idx.append_array([b, b + 1, b + 2, b + 2, b + 1, b + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)


## Tiles round a circle of radius r for a band w wide (the brush keeps its drawn proportions).
static func tiles_for(r: float, w: float) -> float:
	return maxf(3.0, roundf(TAU * r / (w * STAMP_ASPECT)))


## A shock line is a few big broken arcs (one a tile) whatever its size: a dashed hoop read as a gizmo.
static func shock_tiles(r: float, w: float) -> float:
	return clampf(roundf(TAU * r / (w * STAMP_ASPECT * 1.6)), 3.0, 5.0)


class Shock extends Node3D:
	var _mi: MeshInstance3D
	var _mesh := ArrayMesh.new()
	var _radius := 1.0
	var _width := 0.3
	var _life := 0.35
	var _t := 0.0
	var _real_ms := 0
	var _step := -1
	var _spin := 0.0

	func setup(at: Vector3, color: Color, radius: float, time: float, width: float) -> void:
		top_level = true
		global_position = at
		_radius = radius
		_width = width
		_life = clampf(time, SHOCK_LIFE.x, SHOCK_LIFE.y)
		_real_ms = Time.get_ticks_msec()
		_spin = randf()
		_mi = MeshInstance3D.new()
		_mi.mesh = _mesh
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi.set_meta("no_ghost", true)
		_mi.extra_cull_margin = radius + 1.0
		add_child(_mi)
		_mi.set_instance_shader_parameter("tint", Color(color.r, color.g, color.b, 1.0))
		_mi.set_instance_shader_parameter("scroll", _spin)
		_tick(0.0)

	func _process(delta: float) -> void:
		_tick(delta)

	func _tick(delta: float) -> void:
		_t += delta
		if _t >= _life or Time.get_ticks_msec() - _real_ms > SHOCK_LIFE_MAX * 1000.0:
			queue_free()
			return
		var step := int(_t / STEP)
		if step == _step:
			return
		_step = step
		var k := clampf(float(step) * STEP / _life, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - minf(1.0, k * 1.4), 3.0)  # races out, then eases
		var r := lerpf(_radius * SHOCK_FROM, _radius, e)
		var w := _width * (1.0 - 0.35 * k)
		SELF.annulus(_mesh, r, w, clampi(int(r * 16.0), 24, 96), SELF.stamp_material("shock"))
		_mi.set_instance_shader_parameter("tiles", SELF.shock_tiles(_radius, _width))
		_mi.set_instance_shader_parameter("frame", float(step % 4))
		_mi.set_instance_shader_parameter("erode", smoothstep(0.1, 1.0, k) * 0.95)


# --- Hit pops (round 44): one designed pop a hit, in the element's own shape -------------------------------------
# Storm a jagged zigzag star with forked sparks, magma a blobby splash with globs, ice faceted shards, dark an ink
# splat with curling strokes; the plain hit, spirit and gold keep the pilot's hit star. They replace the star +
# element chips each foe got on every hit (Fx.element_hit draws nothing more when designed), and a crowd hit in one
# frame gets POP_FULL full pops and POP_SMALL small ones, the rest none: one clear focal effect a beat.

const POP_FOR := {"wind": "pop_storm", "earth": "pop_magma", "water": "pop_ice", "void": "pop_dark"}
const POP_TIMES := [0.033, 0.08, 0.05, 0.05, 0.05, 0.06]
const POP_SIZE := 1.5  # m: the quad at Fx.HIT_STAR (the drawings fill ~85% of it)
const POP_FULL := 2  # full-size pops in one frame
const POP_SMALL := 2  # then this many at POP_SMALL_K
const POP_SMALL_K := 0.6
const STREAKS_A_FRAME := 1  # impact streaks (Fx.impact) in one frame
const KILL_TIMES := [0.033, 0.12, 0.08, 0.06, 0.06, 0.06, 0.07, 0.08]  # round 45: the kill star holds its peak (hit_spark's 8)

static var _registered := false
static var _frame := -1
static var _pops_this_frame := 0
static var _streaks_frame := -1
static var _streaks_this_frame := 0


static func _register() -> void:
	if _registered:
		return
	_registered = true
	for n: String in ["pop_storm", "pop_magma", "pop_ice", "pop_dark"]:
		DESIGNED.extra_sheets[n] = {"tex": load("res://assets/vfx/designed/%s.png" % n), "grid": Vector2(3, 2), "frames": 6,
			"kind": "sprite"}
	for n: String in LOOP_SHEETS:
		DESIGNED.extra_sheets[n] = {"tex": load("res://assets/vfx/designed/%s.png" % n), "grid": Vector2(2, 2), "frames": 4,
			"kind": "ground"}


## How big this frame's next hit pop should be: 1, POP_SMALL_K, or 0 (none).
static func pop_share() -> float:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_pops_this_frame = 0
	_pops_this_frame += 1
	if _pops_this_frame <= POP_FULL:
		return 1.0
	if _pops_this_frame <= POP_FULL + POP_SMALL:
		return POP_SMALL_K
	return 0.0


## Whether this frame may throw another set of impact streaks.
static func streaks_ok() -> bool:
	var f := Engine.get_process_frames()
	if f != _streaks_frame:
		_streaks_frame = f
		_streaks_this_frame = 0
	_streaks_this_frame += 1
	return _streaks_this_frame <= STREAKS_A_FRAME


## The hit's pop in its element's shape (falls back to the pilot's hit star). `size` is Fx.HIT_STAR's scale.
static func pop(parent: Node, at: Vector3, element: String, size := 0.9) -> Node3D:
	var k := pop_share()
	if k <= 0.0:
		return null
	var e: String = DESIGNED.PAL.ALIAS.get(element, element)
	if not POP_FOR.has(e):
		return DESIGNED.hit(parent, at, e, size * k)
	_register()
	var fx: Node3D = DESIGNED.spawn(parent, POP_FOR[e], at, POP_SIZE * size * k / 0.9, e, POP_TIMES, Vector2(0.45, 1.0))
	fx.real_until = 1
	fx.pop = 0.12
	return fx.vary(PI, true)


static var _once := {}


## True the first time `key` asks in this frame (a crowd hit's per-foe flourishes: one a frame).
static func once_a_frame(key: String) -> bool:
	var f := Engine.get_process_frames()
	if _once.get(key, -1) == f:
		return false
	_once[key] = f
	return true


# --- Floor loops (round 45): dark pools and the Singularity's vortex as authored decals ---------------------------
# A ground quad that boils through its sheet's four frames on twos for as long as its owner lives, then erodes away
# (`erode_out`). The owner keeps its own gameplay (groups, pulls, timers); this is only the look.

const LOOP_SHEETS: Array[String] = ["dark_pool", "dark_vortex"]


static func floor_loop(parent: Node3D, sheet: String, size: float, element := "void") -> FloorLoop:
	_register()
	var l := FloorLoop.new()
	parent.add_child(l)
	l.setup(sheet, size, element)
	return l


class FloorLoop extends Node3D:
	var _mi: MeshInstance3D
	var _t := 0.0
	var _step := -1
	var _erode_t := -1.0
	var _erode_for := 0.25
	var _last_us := 0

	func setup(sheet: String, size: float, element: String) -> void:
		_mi = MeshInstance3D.new()
		_mi.mesh = DESIGNED._mesh_for("ground")
		_mi.material_override = DESIGNED.material(sheet)
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi.set_meta("no_ghost", true)
		_mi.extra_cull_margin = size
		_mi.scale = Vector3.ONE * size
		_mi.position.y = DESIGNED.GROUND_LIFT
		add_child(_mi)
		_mi.set_instance_shader_parameter("pal_row", DESIGNED.row(element))
		_mi.set_instance_shader_parameter("erode", 0.0)
		_mi.set_instance_shader_parameter("frame", float(randi() % 4))
		rotation.y = randf() * TAU
		_last_us = Time.get_ticks_usec()

	## Its see-through (round 56: Overwhelm's pool thins under the haul).
	func set_alpha(a: float) -> void:
		_mi.set_instance_shader_parameter("alpha", a)

	## Eat it away over `time` s (real time), then free it.
	func erode_out(time := 0.25) -> void:
		if _erode_t < 0.0:
			_erode_t = 0.0
			_erode_for = maxf(time, 0.05)

	func _process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		var real := float(now - _last_us) / 1000000.0
		_last_us = now
		_t += real
		var step := int(_t * 12.0)
		if step != _step:
			_step = step
			_mi.set_instance_shader_parameter("frame", float(step % 4))
		if _erode_t >= 0.0:
			_erode_t += real
			var k := clampf(_erode_t / _erode_for, 0.0, 1.0)
			_mi.set_instance_shader_parameter("erode", k * 0.98)
			if k >= 1.0:
				queue_free()
