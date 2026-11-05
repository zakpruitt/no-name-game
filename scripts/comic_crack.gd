extends Node3D
## A comic burn mark on the floor (Fx.scorch with Game.comic_style): a flat inked splat with jagged
## cracks running out of it, hot in the middle on the first steps, cooling to a dark tone of its colour on twos,
## then shrinking away. Replaces the soft glowing scorch texture, which read as an orange haze under
## Molten Palm's line and the geysers. Depth tested, so foes standing on it stay in front.
##   ComicCrack.spawn(parent, pos, color, radius, time)

const SELF := preload("res://scripts/comic_crack.gd")
const STEPS_PER_S := 12.0  # on twos
const INK := Color(0.012, 0.01, 0.02)
const HOT := Color(1.0, 0.86, 0.2)
const COOL := 0.4  # how far the colour darkens once it cools (soot sank into the indigo floor)
const LINE := 0.035  # m of ink round the colour (fx_palette.LINE)
const LIFT := 0.06  # m over the floor (the floor stones' tallest is 0.05)
const SPLAT := 0.3  # of the radius: the middle splat
const CRACKS := Vector2i(5, 7)
const CRACK_REACH := Vector2(0.65, 1.0)  # of the radius
const CRACK_W := 0.07  # m of ink each side at the root, per metre of radius (capped)
const CRACK_W_MAX := 0.22
const HOT_STEPS := 2  # steps the colour glows before it cools
const MAX_TIME := 0.9  # s: round 33 (sleek; feel audit item 7), a 1.2-1.4 s mark sat under the next string
const OUT_AT := 0.7  # of its time: from here it shrinks away
const STANDING := preload("res://scripts/standing_fx.gd")
## Round 33, sleek 4: a breaker-sized mark (Meteor Fall, the rip's landing) lies under the pile it was for, so its
## splat and the roots of its cracks were all under the foes and nothing showed. From PILE_R up the cracks start
## at the pile's edge (PILE_INNER), run out past it over RUN_STEPS steps, reach further, and there is no splat.
const PILE_R := 2.0  # m: marks this big are under a pile
const PILE_INNER := Vector2(0.38, 1.5)  # the cracks' start: this share of the radius, at most this many m
const PILE_REACH := Vector2(0.95, 1.3)  # of the radius (CRACK_REACH)
const RUN_STEPS := 3  # steps on twos the cracks take to run out to their tips
const PILE_W_MAX := 0.34  # m (CRACK_W_MAX): out past the pile they carry the landing alone

static var _mat: StandardMaterial3D

var color := Color(1.0, 0.36, 0.04)
var radius := 1.5
var time := 1.2
var _t := 0.0
var _step := -1
var _rng := RandomNumberGenerator.new()
var _splat := PackedFloat32Array()  # radius per point
var _cracks := []  # PackedVector2Array per crack, in metres
var _mesh := ArrayMesh.new()
var _verts := PackedVector3Array()
var _colors := PackedColorArray()
var _y := 0.0  # each layer a hair above the last, so they don't z-fight


static func spawn(parent: Node, pos: Vector3, c: Color, r: float, t: float) -> Node3D:
	var k: Node3D = SELF.new()
	k.color = c
	k.radius = r
	k.time = minf(t, MAX_TIME)
	parent.add_child(k)
	k.global_position = Vector3(pos.x, LIFT + randf() * 0.01, pos.z)  # (jitter: overlapping marks don't z-fight)
	return k


## Unshaded vertex colour, depth tested, both sides: shared so its first use doesn't hitch.
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat


func _ready() -> void:
	top_level = true
	_rng.randomize()
	for i in 11:
		_splat.append(_rng.randf_range(0.7, 1.25))
	var n := _rng.randi_range(CRACKS.x, CRACKS.y)
	var turn := _rng.randf() * TAU
	var pile := radius >= PILE_R
	var inner := minf(radius * PILE_INNER.x, PILE_INNER.y) if pile else 0.0
	var span := PILE_REACH if pile else CRACK_REACH
	for i in n:
		var a := turn + TAU * (i + _rng.randf_range(-0.25, 0.25)) / n
		var reach := radius * _rng.randf_range(span.x, span.y)
		var pts := PackedVector2Array([Vector2(cos(a), sin(a)) * inner])
		var segs := 4
		for k in range(1, segs + 1):
			var f := float(k) / segs
			var bend := a + _rng.randf_range(-0.35, 0.35)
			pts.append(Vector2(cos(bend), sin(bend)) * lerpf(inner, reach, f))
		_cracks.append(pts)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = radius + 1.0
	mi.set_meta("no_ghost", true)
	add_child(mi)
	STANDING.add(self)
	tick(0.0)


## The next string's first hit landed (standing_fx.gd): shrink away now.
func clear_standing() -> void:
	time = minf(time, _t + STANDING.CLEAR_S)


func _process(delta: float) -> void:
	tick(delta)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	_t += delta
	if _t >= time:
		queue_free()
		return
	var step := int(_t * STEPS_PER_S)
	if step == _step:
		return
	_step = step
	_draw(step)


func _draw(step: int) -> void:
	_verts.clear()
	_colors.clear()
	var hot := step < (RUN_STEPS if radius >= PILE_R else HOT_STEPS)  # (a pile's cracks glow while they run)
	var out := clampf((_t / time - OUT_AT) / (1.0 - OUT_AT), 0.0, 1.0)
	var k := 1.0 - out * 0.85  # shrinks away at the end
	var pile := radius >= PILE_R
	var grow := 0.75 if step == 0 else 1.0  # punches out on the first frame
	var run := minf(float(step + 1) / RUN_STEPS, 1.0) if pile else 1.0  # runs out from the pile's edge
	if pile:
		grow = 1.0
	var w := minf(CRACK_W * radius, PILE_W_MAX if pile else CRACK_W_MAX) * k
	var tone := color if hot else color.darkened(COOL)
	_y = 0.0
	# Round 33 (sleek): a thin ink line round the colour (was ink 2.4x the colour's width).
	for pts: PackedVector2Array in _cracks:
		_crack(pts, w * 0.42 + LINE, grow * k, INK, run)
	if not pile:
		_blob(radius * SPLAT * grow * k * 0.8 + LINE * 2.0, INK)
	_y = 0.006
	if out < 0.8:
		for pts: PackedVector2Array in _cracks:
			_crack(pts, w * 0.42, grow * k * 0.85, tone, run)
		if not pile:
			_blob(radius * SPLAT * grow * k * 0.8, tone)
	_y = 0.012
	if hot:
		if pile:  # a hot line down each crack while it runs
			for pts: PackedVector2Array in _cracks:
				_crack(pts, w * 0.14, grow * k * 0.85, HOT, run)
		else:
			_blob(radius * SPLAT * grow * 0.4, HOT)
	_mesh.clear_surfaces()
	if _verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.surface_set_material(0, material())


func _blob(r: float, c: Color) -> void:
	var n := _splat.size()
	var lift := Vector3.UP * _y
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), 0.0, sin(a0)) * r * _splat[i]
		var p1 := Vector3(cos(a1), 0.0, sin(a1)) * r * _splat[(i + 1) % n]
		_tri(lift, p0 + lift, p1 + lift, c)


## A crack: a tapered strip along the points, fat at the root, to a point at the far end. `run`: the share of its
## segments drawn so far (a pile's cracks run out).
func _crack(pts: PackedVector2Array, w: float, reach_k: float, c: Color, run := 1.0) -> void:
	var n := pts.size()
	for i in mini(n - 1, ceili(run * (n - 1) - 0.001)):
		var a := pts[i] * reach_k
		var b := pts[i + 1] * reach_k
		var d := (b - a).normalized()
		var side := Vector2(-d.y, d.x)
		var wa := w * (1.0 - float(i) / (n - 1))
		var wb := w * (1.0 - float(i + 1) / (n - 1))
		var a0 := Vector3(a.x + side.x * wa, _y, a.y + side.y * wa)
		var a1 := Vector3(a.x - side.x * wa, _y, a.y - side.y * wa)
		var b0 := Vector3(b.x + side.x * wb, _y, b.y + side.y * wb)
		var b1 := Vector3(b.x - side.x * wb, _y, b.y - side.y * wb)
		_tri(a0, a1, b0, c)
		_tri(b0, a1, b1, c)


func _tri(a: Vector3, b: Vector3, c: Vector3, color_: Color) -> void:
	_verts.append_array([a, b, c])
	_colors.append_array([color_, color_, color_])
