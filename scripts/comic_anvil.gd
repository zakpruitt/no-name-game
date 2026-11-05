extends "res://scripts/comic_flat.gd"
## Anvil's landing (Backdraft's breaker, H in window): the hammer drives everyone held into the floor, a crater
## each. Per foe: three fat down strokes above it on the first two steps (the drive), and on the floor an inked
## dent (ink rim, hot then deep earth inside) with five cracks out of it; two rubble chips kick out. Nearest
## first, STAGGER s apart; cools and shrinks by 0.55 s. Game time (the landing's hit stop holds it). Replaces three
## earth spikes per foe.
##   ComicAnvil.spawn(parent, from, spots)

const SELF := preload("res://scripts/comic_anvil.gd")
const STAGGER := 0.04
const DENT := 0.62  # m
const CRACKS := 5
const CRACK_LEN := 1.25  # m
const EACH := 0.5
const GRAVITY := 11.0

var spots: Array = []
var _p: Dictionary
var _ones := []  # {c: Vector2, delay, ring, cracks, chips}


static func spawn(parent: Node, from: Vector3, at: Array) -> Node3D:
	var a: Node3D = SELF.new()
	a.spots = at
	a.begin(parent, Vector3(from.x, 0.0, from.z))
	return a


func _build() -> void:
	_p = PAL.of("earth")
	var me := Vector2(global_position.x, global_position.z)
	var order := spots.duplicate()
	order.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x, a.z).distance_to(me) < Vector2(b.x, b.z).distance_to(me))
	for n in order.size():
		var s: Vector3 = order[n]
		var one := {"c": Vector2(s.x, s.z) - me, "delay": n * STAGGER, "ring": PackedFloat32Array(), "cracks": [], "chips": []}
		var ring := PackedFloat32Array()  # (filled here: a packed array read out of a Dictionary is a copy)
		for k in 9:
			ring.append(_rng.randf_range(0.85, 1.1))
		one.ring = ring
		var turn := _rng.randf() * TAU
		for k in CRACKS:
			var a := turn + TAU * (k + _rng.randf_range(-0.2, 0.2)) / CRACKS
			var d := Vector2(cos(a), sin(a))
			one.cracks.append(_jagged(d * DENT * 0.8, d * CRACK_LEN * _rng.randf_range(0.8, 1.1), 0.22, 0.5))
		for k in 2:
			var a := PI * 0.5 + (0.6 if k == 0 else -0.6) + _rng.randf_range(-0.2, 0.2)
			one.chips.append(_screen(a) * _rng.randf_range(4.0, 5.5))
		_ones.append(one)
	life = (order.size() - 1) * STAGGER + EACH if order.size() > 0 else 0.05


func _draw(_s: int) -> void:
	for one: Dictionary in _ones:
		var t: float = _t - float(one.delay)
		if t < 0.0 or t >= EACH:
			continue
		_one(one, int(t * STEPS_PER_S), t / EACH)


func _one(one: Dictionary, s: int, k: float) -> void:
	var c: Vector2 = one.c
	var c3 := Vector3(c.x, 0.0, c.y)
	var cool := clampf(1.0 - (k - 0.45) / 0.55, 0.0, 1.0)
	var hot := s < 2
	var shape: PackedFloat32Array = one.ring
	var ring := PackedVector2Array()
	var rim := PackedVector2Array()
	var size := DENT * (0.8 if s == 0 else 1.0) * (0.7 + 0.3 * cool)
	for i in shape.size():
		var a := TAU * i / shape.size()
		var d := Vector2(cos(a), sin(a)) * shape[i]
		ring.append(d * size)
		rim.append(d * (size + PAL.LINE * 2.5))
	for pts: PackedVector2Array in one.cracks:
		_floor_strip(_off(pts, c, 0.75 if s == 0 else 1.0), 0.15 + PAL.LINE * 2.0, 0.0, PAL.fade(INK, cool))
	_floor_fan(c, rim, PAL.fade(INK, cool))
	_layer()
	_floor_fan(c, ring, PAL.fade(_p.deep if not hot else _p.body, cool), PAL.fade(_p.light if hot else _p.deep, cool))
	for pts: PackedVector2Array in one.cracks:
		_floor_strip(_off(pts, c, 0.75 if s == 0 else 1.0), 0.11, 0.0, PAL.fade(_p.light if hot else _p.deep, cool))
	if s <= 1:  # the drive: fat strokes coming down on it
		for i in 3:
			var x := (i - 1) * 0.42
			var top := c3 + _right * x + Vector3.UP * (2.6 - absf(x))
			_wedge(top, Vector3.DOWN, 1.5, 0.3, INK)
			_wedge(top + Vector3.DOWN * 0.04, Vector3.DOWN, 1.4, 0.2, _p.light if s == 0 else PAL.fade(_p.light, 0.5))
	if s <= 4:
		for v: Vector3 in one.chips:
			var tt := s / STEPS_PER_S + 0.03
			var at := c3 + Vector3.UP * 0.3 + v * tt + Vector3.DOWN * GRAVITY * tt * tt * 0.5
			var r := _ring(PackedFloat32Array([1.0, 0.8, 1.1, 0.85, 0.95]), 0.15, s * 0.8)
			_outline(at, r, PAL.LINE, INK)
			_fan(at, r, _p.body, _p.deep)


func _off(pts: PackedVector2Array, c: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p * k)
	return out
