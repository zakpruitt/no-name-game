extends "res://scripts/comic_flat.gd"
## Ice closing over things, two ways:
##   ComicFreezeOver.foe(parent, foe): Flash Freeze's frost-over, as he dives. A see-through crystal shell climbs a
##     held foe from its feet (half on the first frame, full with a 1.1 overshoot on the next), pale in the middle to
##     ice blue at the edge, a light rim line inside a thin ink line, three ice tips out of the top and a white glint.
##     It rides the foe (who may be freed: kept untyped) and is gone in 0.5 s of real time (the dive is slow motion).
##   ComicFreezeOver.pool(parent, spot, radius): Black Ice's press. The dark pool freezes over from the middle out
##     in three steps: ice plates with ink between them and a light glint line on each, opaque on the floor, depth
##     tested. It holds (real time, at most POOL_HOLD s) until shatter(), when his landing breaks it: the plates
##     flip up as inked chips flying out, and the floor sheet is gone in two steps.
##   ComicFreezeOver.shatter(parent, spot, radius): breaks the pool there (spawning one already broken if there is none).

const SELF := preload("res://scripts/comic_freeze_over.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const GROUP := "comic_freeze_pool"
const SHELL := Vector2(0.88, 1.5)  # m: half its width, its height (a dummy is about 1.5 m)
const SHELL_POINTS := 12
const TIPS := 3
const FOE_LIFE := 0.5
const PLATES := 9
const POOL_GROW := [0.45, 0.8, 1.0]  # of the radius, the first steps
const POOL_HOLD := 2.2  # s at most before it melts on its own
const POOL_LIFT := 0.06  # m over the dark pool's own floor parts
const SHATTER_STEPS := 4
const GRAVITY := 10.0

var mode := "foe"
var radius := 3.0
var target: Variant  # the foe (untyped: it may be freed)
var _p: Dictionary
var _shape := PackedFloat32Array()
var _tips := []  # [angle, length]
var _plates := []  # {a0, a1, r: PackedFloat32Array (outer edge), mid: Vector2}
var _broke := -1.0  # _t it shattered at
var _chips := []  # {pos, vel, size, shape, turn}


static func foe(parent: Node, e: Variant) -> Node3D:
	if not is_instance_valid(e):
		return null
	if DESIGNED_EL.DESIGNED.on():  # fx-ice2: the ice block (freeze_seized's cube) is the frost-over; frost and mist under it
		DESIGNED_EL.frost_mark(parent, e.global_position, 0.75, 0.5)
		return null
	var f: Node3D = SELF.new()
	f.mode = "foe"
	f.target = e
	f.life = FOE_LIFE
	f.real_time = true
	f.begin(parent, e.global_position)
	return f


static func pool(parent: Node, spot: Vector3, r: float) -> Node3D:
	var f: Node3D = SELF.new()
	f.mode = "pool"
	f.radius = r
	f.life = POOL_HOLD
	f.real_time = true
	f.lift = POOL_LIFT
	f.add_to_group(GROUP)
	f.begin(parent, Vector3(spot.x, 0.0, spot.z))
	return f


static func shatter(parent: Node, spot: Vector3, r: float) -> void:
	var near: Node3D = null
	for f: Node in parent.get_tree().get_nodes_in_group(GROUP):
		var d := Vector2(f.global_position.x - spot.x, f.global_position.z - spot.z).length()
		if d < r and not f.is_queued_for_deletion() and f._broke < 0.0:
			near = f
	if near == null:
		near = pool(parent, spot, r)
		near._t = 3.0 / STEPS_PER_S  # (already grown)
	near.break_up()


func break_up() -> void:
	_broke = _t
	life = _t + SHATTER_STEPS / STEPS_PER_S
	remove_from_group(GROUP)
	for pl: Dictionary in _plates:
		var mid: Vector2 = pl.mid
		var world := Vector3(mid.x, 0.4, mid.y)
		var out := Vector3(mid.x, 0.0, mid.y).normalized()
		var shape := PackedFloat32Array()
		for k in 3:
			shape.append(_rng.randf_range(0.75, 1.15))
		_chips.append({"pos": world, "vel": out * _rng.randf_range(3.0, 5.0) + Vector3.UP * _rng.randf_range(4.0, 6.5),
			"size": radius * _rng.randf_range(0.11, 0.16), "shape": shape, "turn": _rng.randf() * TAU})
	_step = -1


func _build() -> void:
	_p = PAL.of("water")
	if mode == "foe":
		for i in SHELL_POINTS:
			_shape.append(1.0 if i % 2 == 0 else _rng.randf_range(0.8, 0.9))
		for i in TIPS:
			_tips.append([PI * 0.5 + (i - 1) * 0.55 + _rng.randf_range(-0.12, 0.12), _rng.randf_range(0.32, 0.48)])
		return
	var turn := _rng.randf() * TAU
	var cuts := PackedFloat32Array()  # shared edges, so every ink gap is the same width
	for i in PLATES:
		cuts.append(turn + TAU * (i + _rng.randf_range(-0.15, 0.15)) / PLATES)
	for i in PLATES:
		var a0 := cuts[i]
		var a1 := cuts[(i + 1) % PLATES] + (TAU if i == PLATES - 1 else 0.0)
		var r := PackedFloat32Array()
		for k in 4:
			r.append(_rng.randf_range(0.86, 1.08))
		var am := (a0 + a1) * 0.5
		_plates.append({"a0": a0, "a1": a1, "r": r, "mid": Vector2(cos(am), sin(am)) * radius * 0.6,
			"ring": _rng.randf_range(0.38, 0.55)})  # (where the inner plate ends and the outer begins: a mosaic, not a pie)


func _follow(_delta: float) -> void:
	if mode == "foe":
		if not is_instance_valid(target) or not target.is_alive():
			queue_free()
			return
		global_position = target.global_position


func _draw(s: int) -> void:
	if mode == "foe":
		_draw_shell(s)
	elif _broke < 0.0:
		_draw_sheet(POOL_GROW[mini(s, POOL_GROW.size() - 1)], s)
	else:
		var bs := int((_t - _broke) * STEPS_PER_S)
		if bs < 2:
			_draw_sheet(1.0 - 0.3 * bs, 99)
		_draw_chips(bs)


func _draw_shell(s: int) -> void:
	var h := 0.55 if s == 0 else (1.1 if s == 1 else 1.0)
	var fade := clampf((_t / life - 0.7) / 0.3, 0.0, 1.0)
	var foot := -_up * 0.05
	var ring := PackedVector3Array()
	for i in _shape.size():
		var a := TAU * i / _shape.size()
		var y := (sin(a) * 0.5 + 0.5) * SHELL.y * h  # 0 at the bottom, up to its top
		ring.append(_right * cos(a) * SHELL.x * _shape[i] + _up * (y - SHELL.y * h * 0.5))
	var centre := foot + _up * SHELL.y * h * 0.5
	if s >= 1:
		for t: Array in _tips:
			var root := centre + _screen(t[0]) * SHELL.y * h * 0.42
			var tip := root + _screen(t[0]) * float(t[1])
			var side := _screen(t[0] + PI * 0.5) * 0.11
			_tri(root + side * 1.35, tip + _screen(t[0]) * PAL.LINE * 2.0, root - side * 1.35, INK)
			_tri3(root + side, tip, root - side, _p.light, _p.hot, _p.body)
	_outline(centre, ring, PAL.LINE, PAL.fade(INK, 1.0 - fade))
	_fan(centre, ring, PAL.fade(_p.light, 0.32 * (1.0 - fade)), PAL.fade(_p.body, 0.6 * (1.0 - fade)))
	var inner := PackedVector3Array()
	for p in ring:
		inner.append(p * 0.92)
	_outline(centre, inner, PAL.LINE * 0.8, PAL.fade(_p.light, 0.9 * (1.0 - fade)))
	if s == 1 or s == 2:  # the glint
		var g := centre + _right * SHELL.x * 0.35 + _up * SHELL.y * 0.25
		var r := 0.34 if s == 1 else 0.2
		var glint := PackedFloat32Array([1.0, 0.35, 1.0, 0.35])
		_fan(g, _star_ring(glint, r, 0.12, PI * 0.25), _p.hot, PAL.fade(_p.light, 0.8))


## The ice over the pool out to `k` of the radius: ink under, plates over with a gap of ink between them.
func _draw_sheet(k: float, s: int) -> void:
	var r := radius * k
	var outer := PackedVector2Array()
	for pl: Dictionary in _plates:
		for j in 4:
			var a: float = lerpf(pl.a0, pl.a1, j / 4.0)
			outer.append(Vector2(cos(a), sin(a)) * (r * pl.r[j] + PAL.LINE * 2.0))
	_floor_fan(Vector2.ZERO, outer, INK)
	_layer()
	var gap := 0.06 / maxf(r, 0.5)  # rad: the ink line between plates
	for pl: Dictionary in _plates:
		var cut: float = r * pl.ring
		var inner := PackedVector2Array()
		var outer_pts := PackedVector2Array()
		for j in 3:
			var a: float = lerpf(pl.a0 + gap * 2.0, pl.a1 - gap * 2.0, j / 2.0)
			inner.append(Vector2(cos(a), sin(a)) * 0.12)
		for j in range(2, -1, -1):
			var a: float = lerpf(pl.a0 + gap, pl.a1 - gap, j / 2.0)
			inner.append(Vector2(cos(a), sin(a)) * (cut - 0.05))
		for j in 3:
			var a: float = lerpf(pl.a0 + gap, pl.a1 - gap, j / 2.0)
			outer_pts.append(Vector2(cos(a), sin(a)) * (cut + 0.05))
		for j in range(4, -1, -1):
			var a: float = lerpf(pl.a0 + gap, pl.a1 - gap, j / 4.0)
			outer_pts.append(Vector2(cos(a), sin(a)) * r * pl.r[mini(j, 3)])
		_plate(inner, _p.hot, _p.light)
		_plate(outer_pts, _p.light, _p.body.lerp(_p.light, 0.35))
	_layer()
	if s <= 2 or s == 99:
		return
	for pl: Dictionary in _plates:  # a light glint line across each plate, once it's grown
		var am: float = (pl.a0 + pl.a1) * 0.5
		var a := Vector2(cos(am - 0.12), sin(am - 0.12)) * r * 0.35
		var b := Vector2(cos(am + 0.1), sin(am + 0.1)) * r * 0.72
		_floor_strip(PackedVector2Array([a, b]), 0.07, 0.0, _p.hot)


## One ice plate: `inner` at its middle to `edge` round it.
func _plate(pts: PackedVector2Array, inner: Color, edge: Color) -> void:
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= pts.size()
	var ring := PackedVector2Array()
	for p in pts:
		ring.append(p - cen)
	_floor_fan(cen, ring, inner, edge)


func _draw_chips(bs: int) -> void:
	var shrink := 1.0 - 0.2 * bs
	for c: Dictionary in _chips:
		if bs > 0:
			c.pos += c.vel / STEPS_PER_S
			c.vel += Vector3.DOWN * GRAVITY / STEPS_PER_S
		var shape: PackedFloat32Array = c.shape
		var ring := PackedVector3Array()
		for i in 3:
			ring.append(_screen(c.turn + TAU * i / 3.0 + bs * 0.9) * c.size * shrink * shape[i])
		var centre: Vector3 = c.pos
		_outline(centre, ring, PAL.LINE, INK)
		_fan(centre, ring, _p.hot, _p.body)
