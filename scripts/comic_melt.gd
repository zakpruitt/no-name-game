extends "res://scripts/comic_flat.gd"
## Meltdown (Dash L H H H L, storm into magma, up in the air), two pieces:
##   ComicMelt.swing(parent, at, fwd): the molten hammer's arc round him: one fat inked crescent sweeping down
##     through where they hang (ink, earth body to a hot leading edge), three steps, 0.25 s.
##   ComicMelt.foe(parent, foe, frozen): rides one foe it hit down. If it was frozen, the ice bursts off it on the
##     first frame (four inked ice chips and a small hot star); while it falls three flame tongues stream up off
##     it; where it lands a hot splat with four cracks opens on the floor and cools to the deep tone. Not down in
##     FALL_MAX s (held by the breaker's hang): it just goes. At most 0.7 s.
##     Replaces the placeholder's Fx.shards, Fx.burst and Fx.scorch per foe.

const SELF := preload("res://scripts/comic_melt.gd")
const SWING_R := 1.7  # m: the crescent's radius round him
const SWING_W := 0.5  # m at its widest
const SWING_ARC := 2.2  # rad it covers
const CHEST := 0.8
const CHIPS := 4
const FLAMES := 3
const FLAME_SPLAY := 0.45  # how far the outer tongues lean out (of up)
const FLAME_LICK := 0.22  # each step a tongue licks this far to one side, then the other
const LANDED_Y := 0.35  # m: under this it's down
const SPLAT := 0.7  # m
const CRACKS := 4
const SPLAT_LIFE := 0.4  # s after landing
const FALL_MAX := 0.3  # s: if it isn't down by then (held in the breaker's hang, a heavy foe) it just goes: no flames hanging on

var mode := "foe"
var target: Variant
var frozen := false
var fwd := Vector3.FORWARD
var _p: Dictionary
var _ice: Dictionary
var _chips := []  # {pos, vel, turn}
var _landed := -1.0
var _cracks := []  # PackedVector2Array
var _shape := PackedFloat32Array()


static func swing(parent: Node, at: Vector3, facing: Vector3) -> Node3D:
	var m: Node3D = SELF.new()
	m.mode = "swing"
	m.fwd = facing
	m.life = 0.25
	m.begin(parent, at)
	return m


static func foe(parent: Node, e: Variant, was_frozen: bool) -> Node3D:
	if not is_instance_valid(e):
		return null
	var m: Node3D = SELF.new()
	m.mode = "foe"
	m.target = e
	m.frozen = was_frozen
	m.life = FALL_MAX + SPLAT_LIFE
	m.begin(parent, e.global_position)
	return m


func _build() -> void:
	_p = PAL.of("earth")
	_ice = PAL.of("water")
	for i in CHIPS:
		var a := TAU * (i + _rng.randf_range(-0.2, 0.2)) / CHIPS + 0.4
		_chips.append({"pos": _screen(a) * 0.3 + _up * CHEST, "vel": _screen(a) * _rng.randf_range(4.0, 6.0), "turn": _rng.randf() * TAU})
	for i in 8:
		_shape.append(_rng.randf_range(0.7, 1.12))
	var turn := _rng.randf() * TAU
	for i in CRACKS:
		var a := turn + TAU * (i + _rng.randf_range(-0.2, 0.2)) / CRACKS
		_cracks.append(_jagged(Vector2.ZERO, Vector2(cos(a), sin(a)) * SPLAT * _rng.randf_range(1.5, 2.0), 0.2, 0.5))


func _follow(_delta: float) -> void:
	if mode != "foe" or _landed >= 0.0:
		return
	if not is_instance_valid(target):
		queue_free()
		return
	global_position = target.global_position
	if _t >= FALL_MAX:
		queue_free()
		return
	if _t > 0.06 and target.global_position.y < LANDED_Y:
		_landed = _t
		life = _t + SPLAT_LIFE
		_step = -1


func _draw(s: int) -> void:
	if mode == "swing":
		_draw_swing(s)
		return
	if s == 0 and frozen:
		var star := PackedFloat32Array([1.0, 0.6, 1.0, 0.6, 1.0, 0.6])
		_fan(_up * CHEST, _star_ring(star, 0.55, 0.3), HOT_CORE, PAL.fade(HOT, 0.8))
	if frozen and s <= 3:  # the ice off it
		for c: Dictionary in _chips:
			var at: Vector3 = c.pos + c.vel * (s / STEPS_PER_S)
			var ring := PackedVector3Array()
			for j in 3:
				ring.append(_screen(float(c.turn) + s + TAU * j / 3.0) * 0.17 * (1.0 - 0.2 * s))
			_outline(at, ring, PAL.LINE, INK)
			_fan(at, ring, _ice.hot, _ice.body)
	if _landed < 0.0:
		# Round 33, sleek 4: three straight upright wedges side by side read as candles up close. Each tongue now
		# leans out from the middle, licks to the other side each step, and hooks at the tip (a second, narrower
		# wedge turned further), in a thin ink line.
		for i in FLAMES:  # burning on the way down: tongues streaming up off it
			var x := (i - 1) * 0.32 + _rng.randf_range(-0.05, 0.05)
			var base := _right * x + _up * (CHEST + 0.2 - absf(x) * 0.4)
			var length := _rng.randf_range(0.8, 1.15) * (1.2 if i == 1 else 0.9)
			var lick := FLAME_LICK * (1.0 if (_step + i) % 2 == 0 else -1.0)
			var lean := (i - 1) * FLAME_SPLAY + lick
			var d := (_up + _right * lean).normalized()
			var hook := (_up + _right * (lean + lick * 1.6)).normalized()
			var tip := base + d * length * 0.42
			_wedge(base - d * 0.04, d, length * 0.75 + 0.06, 0.26 + PAL.LINE * 2.0, INK)
			_wedge(tip - d * 0.04, hook, length * 0.6 + 0.06, 0.2 + PAL.LINE * 2.0, INK)
			_wedge(base, d, length * 0.75, 0.26, _p.body)
			_wedge(tip, hook, length * 0.6, 0.2, _p.body)
			_wedge(base + d * 0.08, d, length * 0.45, 0.1, _p.hot)
		return
	var ls := int((_t - _landed) * STEPS_PER_S)
	var hot := ls < 2
	var k := clampf(1.0 - (_t - _landed) / SPLAT_LIFE, 0.0, 1.0)
	var grow := 0.75 if ls == 0 else 1.0
	for pts: PackedVector2Array in _cracks:
		_floor_strip(_scaled(pts, grow), 0.16 + PAL.LINE * 2.0, 0.0, PAL.fade(INK, k))
	var ring := PackedVector2Array()
	for i in _shape.size():
		var a := TAU * i / _shape.size()
		ring.append(Vector2(cos(a), sin(a)) * SPLAT * _shape[i] * grow * (0.6 + 0.4 * k) + Vector2(cos(a), sin(a)) * PAL.LINE * 2.0)
	_floor_fan(Vector2.ZERO, ring, PAL.fade(INK, k))
	_layer()
	var inner := PackedVector2Array()
	for p in ring:
		inner.append(p * 0.86)
	_floor_fan(Vector2.ZERO, inner, PAL.fade(_p.hot if hot else _p.body, k), PAL.fade(_p.body if hot else _p.deep, k))
	for pts: PackedVector2Array in _cracks:
		_floor_strip(_scaled(pts, grow), 0.12, 0.0, PAL.fade(_p.light if hot else _p.deep, k))
	if ls == 0:  # the hit on the floor
		_fan(_up * 0.3, _star_ring(_shape, 0.7, 0.35), HOT_CORE, PAL.fade(HOT, 0.8))


func _draw_swing(s: int) -> void:
	var f := _right * fwd.dot(_right) + _up * fwd.dot(_up)
	var a_mid := _angle(f) if f.length() > 0.1 else -PI * 0.5
	var lead := a_mid + SWING_ARC * 0.5 - SWING_ARC * minf(1.0, (s + 1) / 2.0)  # sweeping down through them
	var outer := PackedVector3Array()
	var n := 9
	for i in n:
		var k := float(i) / (n - 1)
		outer.append(_screen(lead + SWING_ARC * k) * SWING_R)
	var fade := 1.0 - 0.45 * s
	_strip(outer, SWING_W + PAL.LINE * 2.0, PAL.LINE, PAL.fade(INK, fade), PAL.fade(INK, 0.0))
	_strip(outer, SWING_W, 0.0, PAL.fade(_p.hot, fade), PAL.fade(_p.deep, 0.0))
	var core := PackedVector3Array()
	for p in outer:
		core.append(p * 1.04)
	_strip(core, SWING_W * 0.3, 0.0, PAL.fade(HOT_CORE, fade), PAL.fade(_p.body, 0.0))


func _scaled(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k)
	return out
