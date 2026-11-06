extends "res://scripts/comic_flat.gd"
## Eruption's landing (Meltdown's breaker, H in window): the floor goes up under everyone near. Under each foe,
## nearest first STAGGER s apart, three inked rock slabs jut up out of the floor round it, tilted out, over a hot
## crack ring, and three lava blobs fly off the top; the molten (Meltdown's state) get a bigger ring and a hot
## star. The slabs sink back and the ring cools to the deep tone; about 0.5 s (five blunt slabs at 1.1 m a foe
## walled the pile in brown boxes). Game time: the landing's hit stop holds it until the impact frame is gone
## (the round 37 Cataclysm lesson). Replaces under() (a geyser and five spikes each) and the 3.5 m scorch.
##   ComicErupt.spawn(parent, from, spots, hot)   (hot: Array of bool, one per spot)

const SELF := preload("res://scripts/comic_erupt.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_FINISH := preload("res://scripts/designed_finish.gd")
const STAGGER := 0.05
const SLABS := 3
const SLAB_H := Vector2(0.5, 0.75)  # m
const SLAB_W := 0.3
const RING := 0.6  # m round its feet (molten: x HOT_GROW)
const HOT_GROW := 1.3
const BLOBS := 3
const GRAVITY := 11.0
const EACH := 0.42  # s each one lasts after it starts

var spots: Array = []
var hot: Array = []
var _p: Dictionary
var _ones := []  # {c: Vector3 (local), delay, hot, slabs: [[angle, h]], blobs: [{vel}], ring: PackedFloat32Array}


static func spawn(parent: Node, from: Vector3, at: Array, molten: Array) -> Node3D:
	if DESIGNED.on():  # round 46: a drawn magma crown up under each (designed_finish.erupt)
		DESIGNED_FINISH.erupt(parent, from, at, molten)
		return null
	var e: Node3D = SELF.new()
	e.spots = at
	e.hot = molten
	e.begin(parent, Vector3(from.x, 0.0, from.z))
	return e


func _build() -> void:
	_p = PAL.of("earth")
	var order := range(spots.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return _flat_len(spots[a]) < _flat_len(spots[b]))
	for n in order.size():
		var i: int = order[n]
		var s: Vector3 = spots[i]
		var one := {"c": Vector3(s.x - global_position.x, 0.0, s.z - global_position.z), "delay": n * STAGGER,
			"hot": bool(hot[i]) if i < hot.size() else false, "slabs": [], "blobs": [], "ring": PackedFloat32Array()}
		var turn := _rng.randf() * TAU
		for k in SLABS:
			one.slabs.append([turn + TAU * (k + _rng.randf_range(-0.15, 0.15)) / SLABS, _rng.randf_range(SLAB_H.x, SLAB_H.y)])
		for k in BLOBS:
			var a := PI * 0.5 + (k - 1) * 0.7 + _rng.randf_range(-0.2, 0.2)
			one.blobs.append({"vel": _screen(a) * _rng.randf_range(4.5, 6.0), "r": _rng.randf_range(0.13, 0.19)})
		var ring := PackedFloat32Array()  # (filled here: a packed array read out of a Dictionary is a copy)
		for k in 10:
			ring.append(_rng.randf_range(0.8, 1.12))
		one.ring = ring
		_ones.append(one)
	life = (order.size() - 1) * STAGGER + EACH if order.size() > 0 else 0.05


func _flat_len(s: Vector3) -> float:
	return Vector2(s.x - global_position.x, s.z - global_position.z).length()


func _draw(_s: int) -> void:
	for one: Dictionary in _ones:
		var t: float = _t - float(one.delay)
		if t < 0.0 or t >= EACH:
			continue
		_one(one, int(t * STEPS_PER_S), t / EACH)


func _one(one: Dictionary, s: int, k: float) -> void:
	var c: Vector3 = one.c
	var molten: bool = one.hot
	var r := RING * (HOT_GROW if molten else 1.0) * (0.7 if s == 0 else 1.0)
	var cool := clampf(1.0 - (k - 0.5) / 0.5, 0.0, 1.0)
	var c2 := Vector2(c.x, c.z)
	var ring := PackedVector2Array()
	var shape: PackedFloat32Array = one.ring
	for i in shape.size():
		var a := TAU * i / shape.size()
		ring.append(Vector2(cos(a), sin(a)) * r * shape[i] * (1.0 if i % 2 == 0 else 0.62))  # (a jagged break, not a tile)
	var ink_ring := PackedVector2Array()
	for p in ring:
		ink_ring.append(p + p.normalized() * PAL.LINE * 2.0)
	_floor_fan(c2, ink_ring, PAL.fade(INK, cool))
	_layer()
	_floor_fan(c2, ring, PAL.fade(_p.hot if s < 2 else _p.body, 0.85 * cool), PAL.fade(_p.body if s < 2 else _p.deep, PAL.EDGE_ALPHA * cool))
	_layer()
	if s == 0 and molten:
		_fan(c + _up * 0.4, _star_ring(shape, 0.9, 0.35), HOT_CORE, PAL.fade(HOT, 0.85))
	# the slabs: up with an overshoot, held, then sinking back
	var rise: float = [0.6, 1.12, 1.0][mini(s, 2)] * (1.0 - clampf((k - 0.55) / 0.45, 0.0, 1.0))
	if rise > 0.02:
		for sl: Array in one.slabs:
			var a: float = sl[0]
			var base := c + Vector3(cos(a), 0.0, sin(a)) * r * 0.75
			var tilt := Vector3(cos(a), 0.0, sin(a)) * 0.35 + Vector3.UP
			var tip := base + tilt.normalized() * float(sl[1]) * rise
			var side := (tip - base).cross(_view).normalized() * SLAB_W * 0.5
			var quad := PackedVector3Array([base - side, base + side, tip])  # (pointed: blunt slabs round a foe read as a box)
			var mid := (base + tip) * 0.5
			var rel := PackedVector3Array()
			for p in quad:
				rel.append(p - mid)
			_outline(mid, rel, PAL.LINE, INK)
			_fan(mid, rel, _p.body, PAL.fade(_p.deep, 0.7))
			_strip(PackedVector3Array([base + side * 0.5, tip]), 0.07, 0.0, _p.light)
	if s <= 4:  # lava off the top
		for b: Dictionary in one.blobs:
			var tt := s / STEPS_PER_S + 0.04
			var v: Vector3 = b.vel
			var at := c + _up * 0.5 + v * tt + Vector3.DOWN * GRAVITY * tt * tt * 0.5
			var br: float = b.r * (1.0 - 0.15 * s)
			var blob := _ring(PackedFloat32Array([1.0, 0.92, 1.05, 0.95, 1.0, 0.9]), br)
			_outline(at, blob, PAL.LINE, INK)
			_fan(at, blob, _p.hot, _p.body)
