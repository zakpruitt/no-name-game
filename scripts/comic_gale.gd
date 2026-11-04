extends Node3D
## A cartoon whirlwind: fat inked bands of wind stacked up into a funnel, each a ring lying flat round
## the column with a gap in it, wide at the top and tight at the foot. Redrawn on twos with every band
## turned on a step, so it spins in held frames; it punches up past its height on the first frame,
## settles, then thins and goes. Replaces the soft green swirl funnels (elements.pillar wind) on the
## comic hero, which read as a glowing blob over the foes it lifted. heretic_form_fx's material.

const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const STEPS_PER_S := 12.0  # on twos
const INK := Color(0.012, 0.01, 0.02)
const STORM := Color(0.16, 0.85, 0.38)
const LIGHT := Color(0.86, 1.0, 0.72)
const BANDS := 5
const ARC := 1.45 * PI  # of each band's ring; the gap shows it's turning
const SEGS := 14
const TURN := 1.1  # radians each band turns per step
const BAND_W := 0.32  # m (0.2 read as thin pencil rings at the game camera), the colour band's thickness up the column; the ink is twice that
const HEIGHT_BY_STEP := [1.15, 1.0, 1.0]  # then fades over FADE_STEPS
const FADE_STEPS := 2

var height := 3.5
var radius := 1.3
var life := 0.6
var _t := 0.0
var _step := -1
var _steps := 0
var _turns := PackedFloat32Array()
var _mesh := ArrayMesh.new()
var _verts := PackedVector3Array()
var _colors := PackedColorArray()
var _rng := RandomNumberGenerator.new()


static func spawn(parent: Node, spot: Vector3, h: float, r: float, time: float) -> Node3D:
	var g: Node3D = load("res://scripts/comic_gale.gd").new()
	g.height = h
	g.radius = r
	g.life = time
	parent.add_child(g)
	g.global_position = Vector3(spot.x, 0.0, spot.z)
	g.setup()
	return g


func setup() -> void:
	add_to_group("comic_gale")
	_rng.randomize()
	_steps = maxi(int(life * STEPS_PER_S), HEIGHT_BY_STEP.size() + FADE_STEPS)
	for i in BANDS:
		_turns.append(_rng.randf() * TAU)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.extra_cull_margin = 8.0
	add_child(mi)
	tick(0.0)


func _process(delta: float) -> void:
	tick(delta)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	_t += delta
	var step := int(_t * STEPS_PER_S)
	if step >= _steps:
		queue_free()
		return
	if step == _step:
		return
	for k in step - maxi(_step, 0):
		for i in BANDS:
			_turns[i] += TURN * (1.0 + 0.25 * i)
	_step = step
	_draw_step(step)


func _draw_step(step: int) -> void:
	_verts.clear()
	_colors.clear()
	var tall: float = HEIGHT_BY_STEP[mini(step, HEIGHT_BY_STEP.size() - 1)]
	var fading := step >= _steps - FADE_STEPS
	var thin := 0.55 if fading else 1.0
	for i in BANDS:  # bottom first: the higher, wider bands overlap the ones under them
		var k := (i + 0.5) / BANDS
		var y := height * tall * k
		var r := radius * lerpf(0.25, 1.0, k * k * 0.6 + k * 0.4)
		if not fading:
			_band(y, r, BAND_W * 2.1, _turns[i], INK)
		_band(y, r, BAND_W * thin, _turns[i], STORM)
		if not fading and not Game.reduce_flashing:
			_band(y + BAND_W * 0.2, r, BAND_W * 0.35, _turns[i] + 0.3, LIGHT)
	_mesh.clear_surfaces()
	if _verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.surface_set_material(0, FORM_FX.material())


## A ring lying flat at height `y`, `w` thick up the column, tapering to points at both ends.
func _band(y: float, r: float, w: float, turn: float, color: Color) -> void:
	for s in SEGS:
		var k0 := float(s) / SEGS
		var k1 := float(s + 1) / SEGS
		var a0 := turn + ARC * k0
		var a1 := turn + ARC * k1
		var w0 := w * 0.5 * sin(k0 * PI)
		var w1 := w * 0.5 * sin(k1 * PI)
		var p0 := Vector3(cos(a0) * r, y, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, y, sin(a1) * r)
		_tri(p0 + Vector3.UP * w0, p0 - Vector3.UP * w0, p1 + Vector3.UP * w1, color)
		_tri(p1 + Vector3.UP * w1, p0 - Vector3.UP * w0, p1 - Vector3.UP * w1, color)


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_verts.append_array([a, b, c])
	_colors.append_array([color, color, color])
