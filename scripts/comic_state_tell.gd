extends "res://scripts/comic_flat.gd"
## The improvisation tells (round 37, second pass): a small mark on a foe for each crossover state it carries
## (VOID_ELEMENT.mark: the `x_buried` / `x_molten` / `x_skewered` metas, good for ELEMENT_HOLD s of real time), so
## a player can read which dash route pays off on it. One node per foe draws all its states, fading out over the
## state's last FADE_S and gone when none is left:
##   molten: a see-through halftone glow over its lower body (earth dots, biggest in the middle), pulsing on twos,
##     and one ember rising off it now and then.
##   buried: an inked crack ring on the floor round its feet (ink round the earth's deep tone, four short cracks).
##   skewered: an ice stake stuck through its chest, poking out both sides (ink line, light to body, a glint).
## The foe calls sync(self) every physics frame (enemy.gd); with no state metas it costs three has_meta calls.
##   const STATE_TELL := preload("res://scripts/comic_state_tell.gd")
##   STATE_TELL.sync(self)

const SELF := preload("res://scripts/comic_state_tell.gd")
const STATES := ["buried", "molten", "skewered"]
const META := "x_tell"
const FADE_S := 0.4  # s: fades over its last
const IN_S := 0.12  # s: comes in over
## molten
const GLOW_C := 0.55  # m up the foe, the glow's middle
const GLOW_R := Vector2(0.7, 0.62)  # m half width / height
const DOT_STEP := 0.14  # m between halftone dots
const DOT_R := 0.08  # m at the middle
const GLOW_ALPHA := 0.8
## buried
const RING_R := 0.72
const RING_W := 0.09
## skewered
const STAKE := Vector2(-0.6, 0.75)  # m along the stake: its back end and its tip, from the chest
const STAKE_W := 0.15
const CHEST := 0.85

var foe: Variant
var _born := {}  # state -> real s it showed
var _rim_shape := PackedFloat32Array()
var _cracks := []
var _stake_a := 0.0


## Spawns a tell on `e` if it carries a live state and has none yet.
static func sync(e: Node3D) -> void:
	if not (e.has_meta("x_buried") or e.has_meta("x_molten") or e.has_meta("x_skewered")) or e.has_meta(META):
		return
	if not _any(e):
		return
	var t: Node3D = SELF.new()
	t.foe = e
	t.life = 1.0e9
	t.real_time = true
	e.set_meta(META, true)
	t.begin(e, e.global_position)
	t.remove_from_group(STANDING.GROUP)  # (it outlasts the next string's first hit: that's its point)


static func left(e: Variant, state: String) -> float:
	return (int(e.get_meta("x_" + state, 0)) - Time.get_ticks_msec()) / 1000.0


static func _any(e: Variant) -> bool:
	for s: String in STATES:
		if left(e, s) > 0.0:
			return true
	return false


func clear_standing() -> void:
	pass


func _build() -> void:
	for i in 10:
		_rim_shape.append(_rng.randf_range(0.88, 1.1))
	for i in 4:
		var a := TAU * (i + _rng.randf_range(-0.2, 0.2)) / 4.0
		var d := Vector2(cos(a), sin(a))
		_cracks.append(_jagged(d * RING_R, d * (RING_R + _rng.randf_range(0.3, 0.45)), 0.14, 0.4))
	_stake_a = _rng.randf_range(0.35, 0.6) * (1.0 if _rng.randf() < 0.5 else -1.0)


func _exit_tree() -> void:
	if is_instance_valid(foe) and foe.has_meta(META):
		foe.remove_meta(META)


func _follow(_delta: float) -> void:
	if not is_instance_valid(foe):
		queue_free()
		return
	global_position = foe.global_position
	if not _any(foe) or (foe.has_method("is_alive") and not foe.is_alive()):
		if foe.has_meta(META):
			foe.remove_meta(META)
		queue_free()


func _alpha(state: String) -> float:
	var l := left(foe, state)
	if l <= 0.0:
		_born.erase(state)
		return 0.0
	if not _born.has(state):
		_born[state] = _t
	var in_k := clampf((_t - float(_born[state])) / IN_S, 0.0, 1.0)
	return in_k * clampf(l / FADE_S, 0.0, 1.0)


func _draw(s: int) -> void:
	if not is_instance_valid(foe):
		return
	var a := _alpha("buried")
	if a > 0.0:
		_buried(a)
	a = _alpha("molten")
	if a > 0.0:
		_molten(a, s)
	a = _alpha("skewered")
	if a > 0.0:
		_skewered(a)


func _molten(a: float, s: int) -> void:
	var p := PAL.of("earth")
	var pulse := 1.0 + (0.12 if s % 2 == 0 else 0.0)
	var c := _up * GLOW_C
	var nx := int(GLOW_R.x / DOT_STEP)
	var ny := int(GLOW_R.y / DOT_STEP)
	var dot := _ring(PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0]), 1.0)
	for iy in range(-ny, ny + 1):
		for ix in range(-nx, nx + 1):
			var x := (ix + (0.5 if iy % 2 != 0 else 0.0)) * DOT_STEP
			var y := iy * DOT_STEP
			var d := Vector2(x / GLOW_R.x, y / GLOW_R.y).length()
			if d >= 1.0:
				continue
			var r := DOT_R * (1.0 - d * d) * pulse
			if r < 0.012:
				continue
			var at := c + _right * x + _up * y
			var ring := PackedVector3Array()
			for v in dot:
				ring.append(v * r)
			var col: Color = p.hot if d < 0.3 else (p.light if d < 0.6 else p.body)
			_fan(at, ring, PAL.fade(col, GLOW_ALPHA * a))
	if s % 3 == 0:  # an ember off it
		var x := _rng.randf_range(-0.35, 0.35)
		var base := _right * x + _up * (GLOW_C + 0.25)
		_wedge(base, _up, 0.45, 0.12, PAL.fade(p.hot, a))


func _buried(a: float) -> void:
	var p := PAL.of("earth")
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in _rim_shape.size():
		var ang := TAU * i / _rim_shape.size()
		var d := Vector2(cos(ang), sin(ang)) * _rim_shape[i]
		outer.append(d * (RING_R + RING_W))
		inner.append(d * (RING_R - RING_W))
	var loop := PackedVector2Array()  # one closed strip: the ring
	for i in outer.size() + 1:
		var j := i % outer.size()
		loop.append((outer[j] + inner[j]) * 0.5)
	_floor_strip(loop, RING_W * 2.0 + PAL.LINE * 2.0, RING_W * 2.0 + PAL.LINE * 2.0, PAL.fade(INK, 0.9 * a))
	for pts: PackedVector2Array in _cracks:
		_floor_strip(pts, 0.1 + PAL.LINE * 2.0, 0.0, PAL.fade(INK, 0.9 * a))
	_layer()
	_floor_strip(loop, RING_W * 2.0, RING_W * 2.0, PAL.fade(p.deep, 0.85 * a))
	for pts: PackedVector2Array in _cracks:
		_floor_strip(pts, 0.07, 0.0, PAL.fade(p.deep, 0.85 * a))


func _skewered(a: float) -> void:
	var p := PAL.of("water")
	var d := _screen(_stake_a)
	var side := _screen(_stake_a + PI * 0.5)
	var c := _up * CHEST
	var ring := PackedVector3Array([d * STAKE.x - side * STAKE_W * 0.35, d * STAKE.x + side * STAKE_W * 0.35,
		d * 0.05 + side * STAKE_W * 0.5, d * STAKE.y, d * 0.05 - side * STAKE_W * 0.5])
	var rim := PackedVector3Array()
	for v in ring:
		rim.append(v + (v - d * 0.05).normalized() * PAL.LINE)
	_fan(c, rim, PAL.fade(INK, a))
	_fan(c + d * 0.05, _shifted(ring, -d * 0.05), PAL.fade(p.light, 0.95 * a), PAL.fade(p.body, 0.95 * a))
	_strip(PackedVector3Array([c + d * (STAKE.x * 0.5) + side * 0.03, c + d * (STAKE.y * 0.7) + side * 0.03]), 0.04, 0.0, PAL.fade(p.hot, a))


func _shifted(pts: PackedVector3Array, by: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for v in pts:
		out.append(v + by)
	return out
