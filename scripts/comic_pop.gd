extends Node3D
## A comic hit flourish: a flat inked impact star, short fat speed-strokes in the hit's direction (or
## all round, `radial`), and chunky two-tone chips, all facing the camera and redrawn on twos. Peaks on
## its first frame and is gone in about a quarter of a second, before the next swing lands. This is what
## Fx.hit_spark, impact, chain_spark, element_hit, combo_pop, death and shards draw with the comic
## style, instead of glowing flares and dot sprays. Uses heretic_form_fx's shared material.
##   ComicPop.spawn(parent, at, {"star": 0.6, "strokes": 3, "dir": kb, "chips": 4, "chip": Color})

const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const INK_FX := preload("res://scripts/designed_ink.gd")
const FX_BEAT := preload("res://scripts/fx_beat.gd")
const STEPS_PER_S := 12.0  # on twos, at 24 fps
const INK := Color(0.012, 0.01, 0.02)
const HOT := Color(1.0, 0.45, 0.05)  # the impact star, whatever the element
const HOT_CORE := Color(1.0, 0.88, 0.25)
const PAPER := Color(1.0, 0.96, 0.82)  # speed strokes
const GRAVITY := 9.0
const STAR_BY_STEP := [1.0, 0.7, 0.36]  # the last is colour only, no ink or core
## Round 33 (sleek, Zak: "sleeker and more put together ... very thick colours"): a star is one gradient
## shape (its hot core at the middle fading to its colour, see-through at the tips) inside a thin ink line,
## not three opaque stars nested in a fat ink hull; strokes are thin speed lines with no ink; chips are fewer
## and smaller. The numbers below are those.
const STAR_INNER := 0.3  # of the spike radius: the star's valleys (0.42 was a chunky blob)
const STAR_TIP_ALPHA := 0.85
const STROKE_THIN := 0.55  # of the asked stroke width
const CHIP_KEEP := 0.6  # of the asked chips (rounded, at least one if any were asked)
const CHIP_SHRINK := 0.75
const RING_THIN := 0.5  # of the asked hoop band
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
var _mi: MeshInstance3D
var _done := false
var _verts := PackedVector3Array()
var _colors := PackedColorArray()


const SELF := preload("res://scripts/comic_pop.gd")
const POOL_MAX := 48  # finished pops kept out of the tree for the next hit (a breaker spawns a dozen at once)

static var _pool := []  # (untyped: a pooled pop someone freed must not error on the way out)


static func spawn(parent: Node, at: Vector3, opts: Dictionary) -> Node3D:
	if float(opts.get("ring", 0.0)) > 0.0 and INK_FX.DESIGNED.on():
		# Round 44 (fx-cohesion): the flat floor hoop is a designed ground stamp now (a broken inked brush shock
		# line, designed_ink.shock); the pop keeps whatever else it was asked for.
		var w := clampf(float(opts.get("ring_w", DEFAULTS.ring_w)) * 2.1, INK_FX.SHOCK_THIN_W, INK_FX.SHOCK_W)
		INK_FX.shock(parent, at, opts.get("ring_color", HOT), opts.ring, int(opts.get("steps", 4)) / STEPS_PER_S + 0.1, w)
		opts = opts.duplicate()
		opts.ring = 0.0
		if float(opts.get("star", 0.0)) <= 0.0 and int(opts.get("strokes", 0)) <= 0 and int(opts.get("chips", 0)) <= 0 and int(opts.get("chip_ink", 0)) <= 0:
			return null
	var pop: Node3D = null
	while pop == null and not _pool.is_empty():
		var p: Variant = _pool.pop_back()
		if is_instance_valid(p):
			pop = p
	if pop == null:
		pop = SELF.new()
	parent.add_child(pop)
	pop.setup(at, opts)
	return pop


## Frees the pooled pops (Fx.release, at exit).
static func release() -> void:
	for p: Variant in _pool:
		if is_instance_valid(p):
			p.free()
	_pool.clear()


## Done: back to the pool out of the tree, or freed when the pool is full.
func _finish() -> void:
	_done = true
	visible = false
	set_process(false)
	if _pool.size() >= POOL_MAX:
		queue_free()
		return
	_to_pool.call_deferred()  # (deferred: tick() may run inside the parent's own loop)


func _to_pool() -> void:
	if _pool.size() >= POOL_MAX:
		queue_free()
		return
	if get_parent() != null:
		get_parent().remove_child(self)
	_pool.append(self)


func setup(at: Vector3, opts: Dictionary) -> void:
	add_to_group("comic_pop")
	set_process(true)
	visible = true
	_done = false
	_t = 0.0
	_step = -1
	_strokes.clear()
	_chips.clear()
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
	if _mi == null:
		_mi = MeshInstance3D.new()
		_mi.mesh = _mesh
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi.set_meta("no_ghost", true)
		add_child(_mi)
	_mi.extra_cull_margin = 8.0 + float(o.ring)
	_mi.sorting_offset = o.layer
	_new_star()
	var n: int = o.strokes
	if o.radial or _fwd == Vector3.ZERO:  # fx-language rule 7: three uneven fans with gaps, never an even ring
		for aw: Vector2 in FX_BEAT.cluster_angles(n, _rng, 3 if n >= 6 else 2, 0.5):
			_strokes.append([aw.x, _rng.randf_range(0.0, 0.15), lerpf(0.55, 1.15, aw.y), lerpf(0.65, 1.2, aw.y)])
	else:
		for i in n:
			var a: float = _angle(_fwd) + (lerpf(-1.0, 1.0, (i + 0.5) / n) + _rng.randf_range(-0.25, 0.25)) * o.spread
			_strokes.append([a, _rng.randf_range(0.0, 0.25), _rng.randf_range(0.7, 1.15), _rng.randf_range(0.8, 1.2)])
	_throw_chips()
	for c: Dictionary in _chips:
		c.pos += c.vel * CHIP_HEAD_START
	tick(0.0)


func _throw_chips() -> void:
	var low: Color = o.chip
	var keep := 0 if int(o.chips) == 0 else maxi(1, roundi(int(o.chips) * CHIP_KEEP))
	var keep_ink := 0 if int(o.chip_ink) == 0 else maxi(1, roundi(int(o.chip_ink) * CHIP_KEEP))
	o.chips = keep
	o.chip_ink = keep_ink
	o.chip_size = float(o.chip_size) * CHIP_SHRINK
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
	for i in mini(int(o.spikes), 8):
		_spikes.append(_rng.randf_range(0.7, 1.2))
	_turn = _rng.randf() * TAU


func _process(delta: float) -> void:
	tick(delta)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	if _done:
		return
	_t += delta
	var step := int(_t * STEPS_PER_S)
	if step >= int(o.steps) + int(o.hold) - 1:
		_finish()
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
			_star_line(size * 1.4, ring, PAL.LINE * 1.4, 1.0)
		var core: Color = o.star_core if not last and not _reduced else o.star_color
		_star(size, core, PAL.fade(o.star_color, STAR_TIP_ALPHA * (0.7 if last else 1.0)))
		if not last:
			_star_line(size, INK, PAL.LINE)
	_mesh.clear_surfaces()
	if _verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.surface_set_material(0, FORM_FX.material())


func _star_ring(size: float, twist: float) -> PackedVector3Array:
	var n := _spikes.size()
	var ring := PackedVector3Array()
	for i in n * 2:
		var a := _turn + twist * PI / n + TAU * i / (n * 2)
		var r: float = size * _spikes[i / 2] if i % 2 == 0 else size * STAR_INNER
		ring.append(_screen(a) * r)
	return ring


## The filled star: `color` at the middle, `edge` at the points.
func _star(size: float, color: Color, edge: Color, twist := 0.0) -> void:
	_fan(Vector3.ZERO, _star_ring(size, twist), color, edge)


## Just the star's outline, `w` m wide, outside its edge.
func _star_line(size: float, color: Color, w: float, twist := 0.0) -> void:
	_outline(Vector3.ZERO, _star_ring(size, twist), w, color)


## A speed stroke: a fat wedge flying outward, blunt at the back, pointed ahead.
func _stroke_layers(st: Array, s: int, k: float) -> void:
	var d := _screen(st[0])
	var side := d.cross(_right.cross(_up)).normalized()
	var base: float = o.gap if o.radial else o.star * 0.55
	var start: float = base + (st[1] + s * 0.45) * o.stroke_len
	var length: float = o.stroke_len * st[2] * k
	var w: float = o.stroke_w * st[3] * k * STROKE_THIN
	var p := d * start
	_wedge(p, d, length, w, side, o.stroke_color)


## A speed line: clear at the back, full colour at its widest, a sharp point ahead.
func _wedge(p: Vector3, d: Vector3, length: float, w: float, side: Vector3, color: Color) -> void:
	var back := PAL.fade(color, 0.0)
	var a := p + side * w * 0.2
	var b := p - side * w * 0.2
	var tip := p + d * length
	var mid := p + d * length * 0.6
	_tri3(a, b, mid + side * w * 0.5, back, back, color)
	_tri3(mid + side * w * 0.5, b, mid - side * w * 0.5, color, back, color)
	_tri(mid + side * w * 0.5, mid - side * w * 0.5, tip, color)


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
	var face := PackedVector3Array()
	for p in ring:
		face.append(p * 0.5)
	_outline(c.pos, ring, PAL.LINE, INK)
	_fan(c.pos, ring, c.low)
	_fan(c.pos + (_up - _right) * size * 0.22, face, c.high)  # the lit facet


## The floor ring: ink either side of a colour band, racing out fast then easing, thinning as it goes.
func _hoop(s: int) -> void:
	var n: int = o.steps
	var k := float(s) / maxf(n - 1, 1)
	var r: float = o.ring * (1.0 - 0.5 * pow(1.0 - k, 2.0))
	var w: float = o.ring_w * RING_THIN * (1.0 - 0.55 * k)
	var ink := PAL.LINE
	var col: Color = o.ring_color
	col.a = maxf(col.a, 0.9) * (1.0 - 0.5 * k)
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


## `edge`: the colour at the ring (a gradient out from `color` at the centre); unset, flat.
func _fan(centre: Vector3, ring: PackedVector3Array, color: Color, edge := Color(0, 0, 0, -1)) -> void:
	var e := color if edge.a < 0.0 else edge
	for i in ring.size():
		_tri3(centre, centre + ring[i], centre + ring[(i + 1) % ring.size()], color, e, e)


## A thin line `w` m wide just outside the ring (pushed out from `centre`).
func _outline(centre: Vector3, ring: PackedVector3Array, w: float, color: Color) -> void:
	var n := ring.size()
	for i in n:
		var p := ring[i]
		var q := ring[(i + 1) % n]
		var po := p + (p.normalized() if p.length() > 0.001 else _up) * w
		var qo := q + (q.normalized() if q.length() > 0.001 else _up) * w
		_tri(centre + p, centre + po, centre + qo, color)
		_tri(centre + p, centre + qo, centre + q, color)


func _tri3(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	_verts.append_array([a, b, c])
	_colors.append_array([ca, cb, cc])


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_verts.append_array([a, b, c])
	_colors.append_array([color, color, color])
