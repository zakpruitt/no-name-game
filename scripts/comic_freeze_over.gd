extends "res://scripts/comic_flat.gd"
## Black Ice's frozen pool (Flash Freeze's crystal shell on a foe, `foe()`, went in round 53: unused since its
## rebuild, and a crystal; the ice block is the frost-over):
##   ComicFreezeOver.pool(parent, spot, radius): Black Ice's press. The dark pool freezes over from the middle out
##     in three steps: ice plates with ink between them and a light glint line on each, opaque on the floor, depth
##     tested. It holds (real time, at most POOL_HOLD s) until shatter(), when his landing breaks it: the plates
##     flip up as inked chips flying out, and the floor sheet is gone in two steps.
##   ComicFreezeOver.shatter(parent, spot, radius): breaks the pool there (spawning one already broken if there is none).

const SELF := preload("res://scripts/comic_freeze_over.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const POLISH := preload("res://scripts/designed_polish.gd")
const D_POOL := 1.7  # fx-polygons: the drawn rime's square, per metre of the pool's radius (the rime is ~0.46 of it round)
const D_POOL_ALPHA := 0.85
const GROUP := "comic_freeze_pool"
const PLATES := 9
const POOL_GROW := [0.45, 0.8, 1.0]  # of the radius, the first steps
const POOL_HOLD := 2.2  # s at most before it melts on its own
const POOL_LIFT := 0.06  # m over the dark pool's own floor parts
const SHATTER_STEPS := 4
const GRAVITY := 10.0

var radius := 3.0
var _p: Dictionary
var _plates := []  # {a0, a1, r: PackedFloat32Array (outer edge), mid: Vector2}
var _broke := -1.0  # _t it shattered at
var _chips := []  # {pos, vel, size, shape, turn}
var _loop: Node3D  # fx-polygons (designed): the frost floor over the pool


static func pool(parent: Node, spot: Vector3, r: float) -> Node3D:
	var f: Node3D = SELF.new()
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
	if DESIGNED_EL.DESIGNED.on():  # fx-polygons: the frost floor breaks away, the ice ring and cold mist over it
		_broke = _t
		life = _t + 0.3
		remove_from_group(GROUP)
		if is_instance_valid(_loop):
			_loop.erode_out(0.22)
		DESIGNED_EL.DESIGNED.ice_shatter(get_parent(), global_position + Vector3.UP * 0.5, clampf(radius / 2.5, 0.7, 1.3))
		DESIGNED_EL.frost_mark(get_parent(), global_position, clampf(radius / 1.6, 0.8, 1.6), 0.5)
		return
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
	if DESIGNED_EL.DESIGNED.on():  # fx-polygons: a drawn rime over the pool (straight cracks, glints; no plates, no shards)
		_loop = POLISH.loop(self, "tell_pinned", radius * D_POOL, "water")
		_loop.set_alpha(D_POOL_ALPHA)
		_loop.offset(Vector3.UP * (DESIGNED_EL.DESIGNED.GROUND_LIFT + 0.02))  # (over the dark pool's own decal)
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


func _draw(s: int) -> void:
	if _loop != null:
		return
	if _broke < 0.0:
		_draw_sheet(POOL_GROW[mini(s, POOL_GROW.size() - 1)], s)
	else:
		var bs := int((_t - _broke) * STEPS_PER_S)
		if bs < 2:
			_draw_sheet(1.0 - 0.3 * bs, 99)
		_draw_chips(bs)


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
