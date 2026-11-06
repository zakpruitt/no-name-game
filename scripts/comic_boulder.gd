extends "res://scripts/comic_flat.gd"
## Rockslide's slam (L H L L, storm into earth): one fat inked boulder lands where the hammer comes down, squashed
## on its first frame over a hot star with three fall strokes above it, then splits into four chunks that fly out
## and drop. On the floor a short crack dent under every foe it drove into the floor, hot for two steps, cooling.
## About 0.55 s. One boulder, not a rock per foe: the pile already has a star and a number each.
##   ComicBoulder.spawn(parent, spot, foe_spots, size)

const SELF := preload("res://scripts/comic_boulder.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_FINISH := preload("res://scripts/designed_finish.gd")
const SIDES := 7
const HIGH := 0.75  # m: the boulder's middle over the floor at impact
const SQUASH := Vector2(1.18, 0.84)  # its first frame
const STAR := 1.55  # of the size: the hot star behind it
const CHUNKS := 4
const GRAVITY := 11.0
const DENT := 1.0  # m: a foe's dent cracks
const DENT_CRACKS := 4
const HOT_STEPS := 2
const HOLD := 2  # steps the boulder sits before it splits

var size := 1.0  # m: the boulder's radius
var spots: Array = []  # world spots of the foes it drove down
var _shape := PackedFloat32Array()
var _star := PackedFloat32Array()
var _chunks := []  # {pos, vel, shape, size}
var _dents := []  # [centre Vector2, Array of PackedVector2Array]
var _p: Dictionary


static func spawn(parent: Node, spot: Vector3, foe_spots: Array, boulder := 1.0) -> Node3D:
	if DESIGNED.on():  # round 46: the drawn boulder (designed_finish.boulder)
		return DESIGNED_FINISH.boulder(parent, Vector3(spot.x, HIGH, spot.z), boulder)
	var b: Node3D = SELF.new()
	b.size = boulder
	b.spots = foe_spots
	b.life = 0.55
	b.begin(parent, Vector3(spot.x, HIGH, spot.z))
	return b


func _build() -> void:
	_p = PAL.of("earth")
	for i in SIDES:
		_shape.append(_rng.randf_range(0.78, 1.12))
	for i in 8:
		_star.append(_rng.randf_range(0.75, 1.15))
	for i in CHUNKS:
		var a := TAU * (i + 0.5) / CHUNKS + _rng.randf_range(-0.3, 0.3)
		var out := _screen(a)
		var shape := PackedFloat32Array()
		for k in 5:
			shape.append(_rng.randf_range(0.7, 1.15))
		_chunks.append({"pos": out * size * 0.45, "vel": (out + _up * 0.6) * _rng.randf_range(4.5, 6.5),
			"shape": shape, "size": size * _rng.randf_range(0.34, 0.44)})
	var me := Vector2(global_position.x, global_position.z)
	for s: Vector3 in spots:
		var c := Vector2(s.x, s.z) - me
		var cracks := []
		var turn := _rng.randf() * TAU
		for i in DENT_CRACKS:
			var a := turn + TAU * (i + _rng.randf_range(-0.2, 0.2)) / DENT_CRACKS
			var tip := c + Vector2(cos(a), sin(a)) * DENT * _rng.randf_range(0.75, 1.1)
			cracks.append(_jagged(c, tip, 0.25, 0.5))
		_dents.append([c, cracks])


func _draw(s: int) -> void:
	_dent_layer(s)
	if s <= HOLD:
		_rock(Vector3.ZERO, _shape, size, SQUASH if s == 0 else Vector2(1.1, 0.92) if s == 1 else Vector2.ONE, s)
		return
	for c: Dictionary in _chunks:
		c.pos += c.vel / STEPS_PER_S
		c.vel += Vector3.DOWN * GRAVITY / STEPS_PER_S
		var shrink := 1.0 - 0.18 * (s - HOLD - 1)
		_rock(c.pos, c.shape, c.size * shrink, Vector2.ONE, s)


## A boulder or a chunk: ink line, earth gradient (light middle, deep edge), a lit facet up and left.
func _rock(centre: Vector3, shape: PackedFloat32Array, r: float, squash: Vector2, s: int) -> void:
	var ring := PackedVector3Array()
	for i in shape.size():
		var a := TAU * i / shape.size() + 0.3
		ring.append(_right * cos(a) * r * shape[i] * squash.x + _up * sin(a) * r * shape[i] * squash.y)
	if s == 0:  # the hot star behind the landing, and the fall strokes above it
		var star := _star_ring(_star, size * STAR, 0.32, 0.2)
		_fan(centre + _up * -0.15, star, HOT_CORE, PAL.fade(HOT, 0.85))
		for k in 3:
			var x := (k - 1) * size * 0.55
			_wedge(centre + _right * x + _up * (size * 2.4), -_up, size * 1.3, 0.14, _p.light)
	elif s == 1:
		var star := _star_ring(_star, size * STAR * 0.6, 0.32, 0.5)
		_fan(centre + _up * -0.15, star, PAL.fade(HOT, 0.9), PAL.fade(HOT, 0.4))
	_outline(centre, ring, PAL.LINE * 1.2, INK)
	_fan(centre + (_up - _right) * r * 0.15, ring, _p.body, _p.deep)
	var facet := PackedVector3Array()
	for p in ring:
		facet.append(p * 0.42)
	_fan(centre + (_up - _right) * r * 0.38, facet, _p.light, _p.body)
	if shape.size() == SIDES:  # two ink cracks across the big one
		_strip(PackedVector3Array([centre + ring[2] * 0.95, centre + ring[2] * 0.4 + _right * 0.1, centre]), PAL.LINE * 2.2, 0.0, INK)
		_strip(PackedVector3Array([centre + ring[6] * 0.95, centre + ring[6] * 0.45, centre + _up * 0.08]), PAL.LINE * 2.0, 0.0, INK)


func _dent_layer(s: int) -> void:
	var hot := s < HOT_STEPS
	var k := clampf(1.0 - (s - 3) * 0.3, 0.0, 1.0)
	if k <= 0.0:
		return
	var grow := 0.7 if s == 0 else 1.0
	for d: Array in _dents:
		for pts: PackedVector2Array in d[1]:
			_floor_strip(_scaled(pts, d[0], grow * k), 0.22 * k + PAL.LINE * 2.0, 0.0, INK)
	_layer()
	for d: Array in _dents:
		for pts: PackedVector2Array in d[1]:
			_floor_strip(_scaled(pts, d[0], grow * k * 0.92), 0.22 * k, 0.0, _p.light if hot else _p.deep, _p.body if hot else _p.deep)


func _scaled(pts: PackedVector2Array, c: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * k)
	return out
