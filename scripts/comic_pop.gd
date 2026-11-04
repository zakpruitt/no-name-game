extends Node3D
## A comic hit flourish: a flat inked impact star, short fat speed-strokes in the hit's direction (or
## all round, `radial`), and chunky two-tone chips, all facing the camera and redrawn on twos. Peaks on
## its first frame and is gone in about a quarter of a second, before the next swing lands. This is what
## Fx.hit_spark, impact, chain_spark, element_hit, combo_pop, death and shards draw with the comic
## style, instead of glowing flares and dot sprays. Uses heretic_form_fx's shared material.
##   ComicPop.spawn(parent, at, {"star": 0.6, "strokes": 3, "dir": kb, "chips": 4, "chip": Color})

const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const STEPS_PER_S := 12.0  # on twos, at 24 fps
const INK := Color(0.012, 0.01, 0.02)
const HOT := Color(1.0, 0.45, 0.05)  # the impact star, whatever the element
const HOT_CORE := Color(1.0, 0.88, 0.25)
const PAPER := Color(1.0, 0.96, 0.82)  # speed strokes
const GRAVITY := 9.0
const STAR_BY_STEP := [1.0, 0.72, 0.4]  # the last is colour only, no ink or core
const STROKE_BY_STEP := [1.0, 0.75, 0.4]
const CHIP_HEAD_START := 0.035  # s of flight on the first frame, so they don't start in a pile

## Every option, with its default. Sizes in metres.
const DEFAULTS := {
	"star": 0.0,  # outer spike radius; 0 for none
	"spikes": 9,
	"star_color": HOT,
	"star_core": HOT_CORE,
	"star_ring": Color(0, 0, 0, 0),  # a jagged outline star behind it in this colour (chain tiers)
	"hold": 1,  # steps the first frame holds: 2+ is a held impact frame
	"strokes": 0,
	"dir": Vector3.ZERO,  # world direction the strokes and chips fly; zero = all round
	"spread": 0.7,  # rad either side of `dir`
	"stroke_len": 0.7,
	"stroke_w": 0.16,
	"stroke_color": PAPER,
	"radial": false,  # strokes evenly all round, starting `gap` out (round the hero)
	"gap": 0.0,
	"chips": 0,
	"chip": Color(0.93, 0.89, 0.78),  # the low tone; the high tone is lighter
	"chip_size": 0.12,
	"chip_speed": 5.0,
	"chip_ink": 0,  # extra plain ink chips
	"ring": 0.0,  # m: a flat inked hoop on the floor racing out to this radius; 0 for none
	"ring_color": HOT,
	"ring_w": 0.2,  # m of the colour band
	"layer": 0.0,  # sorting offset: a chain tier's halo goes under the hit's own star
	"steps": 4,  # gone after this many steps
}

var o := {}
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _fwd := Vector3.ZERO  # `dir` on the screen plane
var _t := 0.0
var _step := -1
var _rng := RandomNumberGenerator.new()
var _strokes := []  # [angle, start out, length k, width k]
var _chips := []  # {pos, vel, size, stretch, shape, ink}
var _spikes := PackedFloat32Array()
var _turn := 0.0
var _reduced := false
var _mesh := ArrayMesh.new()
var _verts := PackedVector3Array()
var _colors := PackedColorArray()


static func spawn(parent: Node, at: Vector3, opts: Dictionary) -> Node3D:
	var pop: Node3D = load("res://scripts/comic_pop.gd").new()
	parent.add_child(pop)
	pop.setup(at, opts)
	return pop


func setup(at: Vector3, opts: Dictionary) -> void:
	add_to_group("comic_pop")
	top_level = true
	global_transform = Transform3D(Basis.IDENTITY, at)
	o = DEFAULTS.duplicate()
	o.merge(opts, true)
	_rng.randomize()
	_reduced = Game.reduce_flashing
	if _reduced:
		o.star *= 0.7
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		_right = cam.global_basis.x
		_up = cam.global_basis.y
	var d: Vector3 = o.dir
	_fwd = _right * d.dot(_right) + _up * d.dot(_up)
	_fwd = _fwd.normalized() if _fwd.length() > 0.05 else Vector3.ZERO
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.extra_cull_margin = 8.0 + float(o.ring)
	mi.sorting_offset = o.layer
	add_child(mi)
	_new_star()
	var n: int = o.strokes
	for i in n:
		var a: float
		if o.radial or _fwd == Vector3.ZERO:
			a = TAU * (i + _rng.randf_range(-0.2, 0.2)) / n
		else:
			a = _angle(_fwd) + (lerpf(-1.0, 1.0, (i + 0.5) / n) + _rng.randf_range(-0.25, 0.25)) * o.spread
		_strokes.append([a, _rng.randf_range(0.0, 0.25), _rng.randf_range(0.7, 1.15), _rng.randf_range(0.8, 1.2)])
	_throw_chips()
	for c: Dictionary in _chips:
		c.pos += c.vel * CHIP_HEAD_START
	tick(0.0)


func _throw_chips() -> void:
	var low: Color = o.chip
	for i in int(o.chips) + int(o.chip_ink):
		var out: Vector3
		if _fwd != Vector3.ZERO:
			out = _screen(_angle(_fwd) + _rng.randf_range(-1.0, 1.0) * maxf(o.spread, 0.5) * 1.3)
		else:
			out = _screen(_rng.randf() * TAU)
		out = (out + _up * 0.35).normalized()  # thrown up a little, so gravity bends them
		var ink := i >= int(o.chips)
		var shape := PackedFloat32Array()
		for k in (5 if ink else _rng.randi_range(4, 6)):
			shape.append(_rng.randf_range(0.72, 1.15))
		_chips.append({"pos": Vector3.ZERO, "vel": out * o.chip_speed * _rng.randf_range(0.6, 1.2),
			"size": o.chip_size * _rng.randf_range(0.7, 1.3) * (0.7 if ink else 1.0),
			"stretch": _rng.randf_range(1.0, 1.6), "shape": shape, "ink": ink, "low": low,
			"high": low.lightened(0.45)})


func _new_star() -> void:
	_spikes.clear()
	for i in int(o.spikes):
		_spikes.append(_rng.randf_range(0.72, 1.25))
	_turn = _rng.randf() * TAU


func _process(delta: float) -> void:
	tick(delta)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	_t += delta
	var step := int(_t * STEPS_PER_S)
	if step >= int(o.steps) + int(o.hold) - 1:
		queue_free()
		return
	if step == _step:
		return
	for k in step - maxi(_step, 0):
		for c: Dictionary in _chips:
			c.pos += c.vel / STEPS_PER_S
			c.vel += Vector3.DOWN * GRAVITY / STEPS_PER_S
	if step >= int(o.hold):
		_new_star()  # a new jag each step once the held frame lets go
	_step = step
	_draw_step(maxi(step - int(o.hold) + 1, 0))


## `s`: 0 is the peak (however long it holds), then the steps it breaks up over.
func _draw_step(s: int) -> void:
	_verts.clear()
	_colors.clear()
	var shrink := 1.0 - float(s) / maxf(o.steps, 1.0)
	if o.ring > 0.0:
		_hoop(s)
	for c: Dictionary in _chips:
		_chip(c, shrink)
	if s < STROKE_BY_STEP.size():
		var k: float = STROKE_BY_STEP[s]
		for st: Array in _strokes:
			_stroke_layers(st, s, k)
	if o.star > 0.0 and s < STAR_BY_STEP.size():
		var size: float = o.star * STAR_BY_STEP[s]
		var last := s == STAR_BY_STEP.size() - 1
		var ring: Color = o.star_ring
		if ring.a > 0.0 and not last:
			_star(size * 1.55, INK, 1.0)
			_star(size * 1.4, ring, 1.0)
		if not last:
			_star(size * 1.22, INK)
		_star(size, o.star_color)
		if not last and not _reduced:
			_star(size * 0.48, o.star_core)
	_mesh.clear_surfaces()
	if _verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.surface_set_material(0, FORM_FX.material())


func _star(size: float, color: Color, twist := 0.0) -> void:
	var n := _spikes.size()
	var ring := PackedVector3Array()
	for i in n * 2:
		var a := _turn + twist * PI / n + TAU * i / (n * 2)
		var r: float = size * _spikes[i / 2] if i % 2 == 0 else size * 0.42
		ring.append(_screen(a) * r)
	_fan(Vector3.ZERO, ring, color)


## A speed stroke: a fat wedge flying outward, blunt at the back, pointed ahead.
func _stroke_layers(st: Array, s: int, k: float) -> void:
	var d := _screen(st[0])
	var side := d.cross(_right.cross(_up)).normalized()
	var base: float = o.gap if o.radial else o.star * 0.55
	var start: float = base + (st[1] + s * 0.45) * o.stroke_len
	var length: float = o.stroke_len * st[2] * k
	var w: float = o.stroke_w * st[3] * k
	var p := d * start
	if s < STROKE_BY_STEP.size() - 1:
		_wedge(p - d * w * 0.3, d, length + w * 0.6, w * 1.9, side, INK)
	_wedge(p, d, length, w, side, o.stroke_color)


func _wedge(p: Vector3, d: Vector3, length: float, w: float, side: Vector3, color: Color) -> void:
	var a := p + side * w * 0.5
	var b := p - side * w * 0.5
	var tip := p + d * length
	var mid := p + d * length * 0.3
	_tri(a, b, mid + side * w * 0.42, color)
	_tri(mid + side * w * 0.42, b, mid - side * w * 0.42, color)
	_tri(mid + side * w * 0.42, mid - side * w * 0.42, tip, color)


func _chip(c: Dictionary, shrink: float) -> void:
	var size: float = c.size * maxf(shrink, 0.3)
	var v: Vector3 = c.vel
	var x := (_right * v.dot(_right) + _up * v.dot(_up))
	x = x.normalized() if x.length() > 0.01 else _right
	var y := x.cross(_right.cross(_up)).normalized()
	var sides: PackedFloat32Array = c.shape
	var ring := PackedVector3Array()
	for i in sides.size():
		var a := TAU * i / sides.size()
		ring.append(x * cos(a) * size * c.stretch * sides[i] + y * sin(a) * size * sides[i])
	if c.ink:
		_fan(c.pos, ring, INK)
		return
	var hull := PackedVector3Array()
	var face := PackedVector3Array()
	for p in ring:
		hull.append(p * 1.5)
		face.append(p * 0.5)
	_fan(c.pos, hull, INK)
	_fan(c.pos, ring, c.low)
	_fan(c.pos + (_up - _right) * size * 0.22, face, c.high)  # the lit facet


## The floor ring: ink either side of a colour band, racing out fast then easing, thinning as it goes.
func _hoop(s: int) -> void:
	var n: int = o.steps
	var k := float(s) / maxf(n - 1, 1)
	var r: float = o.ring * (1.0 - 0.5 * pow(1.0 - k, 2.0))
	var w: float = o.ring_w * (1.0 - 0.55 * k)
	var ink := 0.07 * (1.0 - 0.4 * k)
	var col: Color = o.ring_color
	col.a = maxf(col.a, 0.9)
	var y := Vector3.UP * (0.12 - global_position.y)  # on the floor, wherever the pop is
	var segs := clampi(int(r * 14.0), 24, 72)
	if s < n - 1:
		_band(y, r - w * 0.5 - ink, r + w * 0.5 + ink, segs, INK)
	_band(y, r - w * 0.5, r + w * 0.5, segs, col)


func _band(y: Vector3, r0: float, r1: float, segs: int, color: Color) -> void:
	for i in segs:
		var a := Vector3(sin(TAU * i / segs), 0.0, cos(TAU * i / segs))
		var b := Vector3(sin(TAU * (i + 1) / segs), 0.0, cos(TAU * (i + 1) / segs))
		_tri(y + a * r0, y + a * r1, y + b * r1, color)
		_tri(y + a * r0, y + b * r1, y + b * r0, color)


func _screen(a: float) -> Vector3:
	return _right * cos(a) + _up * sin(a)


func _angle(v: Vector3) -> float:
	return atan2(v.dot(_up), v.dot(_right))


func _fan(centre: Vector3, ring: PackedVector3Array, color: Color) -> void:
	for i in ring.size():
		_tri(centre, centre + ring[i], centre + ring[(i + 1) % ring.size()], color)


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_verts.append_array([a, b, c])
	_colors.append_array([color, color, color])
