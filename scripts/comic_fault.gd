extends "res://scripts/comic_flat.gd"
## Fault Line's cracks (L H L L H): one jagged crack per foe runs out from him across the floor, glowing
## (ink edge, earth body, hot core line while it runs), the nearest first and the rest a beat apart, and opens
## where it arrives: a hot splat under the foe and, for Fault Line, the gale coming up out of it (comic_gale).
## `big` is Cataclysm's landing: the same cracks fatter and slower out of his landing, a lightning strike out of
## the sky where each arrives (comic_bolt) and no gale. Fewer, larger shapes with staggered timing in place of the
## round 34 placeholders (a fissure, a pillar, a strike, a geyser and spikes per foe: "a wall of effects").
## Cools to the deep tone and shrinks away; about 0.7 s.
##   ComicFault.spawn(parent, from, spots, big)

const SELF := preload("res://scripts/comic_fault.gd")
const COMIC_GALE := preload("res://scripts/comic_gale.gd")
const COMIC_BOLT := preload("res://scripts/comic_bolt.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const DESIGNED_INK := preload("res://scripts/designed_ink.gd")
## fx-polygons (designed): each crack is laid as it runs, one magma_crack tile every D_STEP m turned along it (the
## fissure's drawn seam), and opens with a magma pop where it arrives (Cataclysm: a magma burst under the strike).
const D_STEP := 0.75
const D_SIZE := 0.62  # of designed_elements.CRACK_SIZE (Fault Line; Cataclysm x D_BIG)
const D_BIG := 1.3
const D_TIMES := [0.05, 0.1, 0.22, 0.3]
const RUN := 30.0  # m/s a crack runs (big: BIG_RUN)
const BIG_RUN := 22.0
const STAGGER := 0.06  # s between one crack starting and the next (nearest first)
const START := 0.55  # m from him the crack starts (out of his feet, not under him)
const WIDTH := 0.26  # m at the root (big: BIG_WIDTH)
const BIG_WIDTH := 0.34
const TIP := 0.45  # of the root width at the far end
const SPLAT := 0.42  # m: the splat where it arrives (big: x BIG_SPLAT)
const BIG_SPLAT := 1.6
const HOT_S := 0.17  # s a crack stays hot after it arrives
const HOLD_S := 0.3  # s after the last arrival before it shrinks away
const OUT_S := 0.22  # s it takes to shrink away
const GALE_HIGH := 2.4
const GALE_R := 0.75
const GALE_LIFE := 0.42
## Round 33, sleek 4: Cataclysm's sky bolts were 0.3 m bands with a fork each, 8 m tall, one per foe: at the landing's
## push-in five fat green zigzags filled the frame over the pile. Thinner, shorter, no fork, at most STRIKES of them
## (the nearest cracks; the rest just open).
const STRIKE_HIGH := 5.5  # (8.0)
const STRIKE_WIDTH := 0.15  # (0.3)
const STRIKE_STAR := 0.55  # (0.8)
const STRIKE_FORKS := 0  # (1)
const STRIKES := 3  # most bolts one landing calls down

var big := false
var spots: Array = []  # world
var _cracks := []  # {pts: PackedVector2Array, lens: PackedFloat32Array, length, delay, arrived, splat, spot}
var _p: Dictionary
var _end_t := 0.0
var _strikes := 0


static func spawn(parent: Node, from: Vector3, to: Array, is_big := false) -> Node3D:
	var f: Node3D = SELF.new()
	f.big = is_big
	f.real_time = not is_big  # (Fault Line's hit stop would hold the run; Cataclysm's waits out the impact frame)
	f.spots = to
	f.begin(parent, Vector3(from.x, 0.0, from.z))
	return f


func _build() -> void:
	_p = PAL.of("earth")
	var me := Vector2(global_position.x, global_position.z)
	var order := spots.duplicate()
	order.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x, a.z).distance_to(me) < Vector2(b.x, b.z).distance_to(me))
	var run := BIG_RUN if big else RUN
	for i in order.size():
		var s: Vector3 = order[i]
		var end := Vector2(s.x, s.z) - me
		if end.length() < START + 0.3:
			end = end.normalized() * (START + 0.3) if end.length() > 0.01 else Vector2(0.0, START + 0.3)
		var pts := _jagged(end.normalized() * START, end, 0.7, 0.55)
		var lens := PackedFloat32Array([0.0])
		for k in range(1, pts.size()):
			lens.append(lens[k - 1] + pts[k].distance_to(pts[k - 1]))
		var splat := PackedVector2Array()
		for k in 9:
			var a := TAU * k / 9.0
			splat.append(Vector2(cos(a), sin(a)) * _rng.randf_range(0.7, 1.2))
		var c := {"pts": pts, "lens": lens, "length": lens[lens.size() - 1], "delay": STAGGER * i, "arrived": false,
			"splat": splat, "spot": s}
		c.at = c.delay + c.length / run
		_cracks.append(c)
		_end_t = maxf(_end_t, c.at)
	life = _end_t + HOLD_S + OUT_S


## Each crack arriving opens its foe's spot that frame, not on the next step.
func _follow(_delta: float) -> void:
	if DESIGNED_EL.DESIGNED.on():
		_lay()
	for c: Dictionary in _cracks:
		if c.arrived or _t < c.at:
			continue
		c.arrived = true
		var s: Vector3 = c.spot
		if big and _strikes < STRIKES:
			_strikes += 1
			var foot := Vector3(s.x, 0.25, s.z)
			var sky := foot + Vector3(_rng.randf_range(-1.0, 1.0), STRIKE_HIGH, _rng.randf_range(-1.0, 1.0))
			COMIC_BOLT.spawn(get_parent(), sky, foot, STRIKE_WIDTH, STRIKE_STAR, STRIKE_FORKS)
		elif not big:
			COMIC_GALE.spawn(get_parent(), Vector3(s.x, 0.0, s.z), GALE_HIGH, GALE_R, GALE_LIFE)
		if DESIGNED_EL.DESIGNED.on():
			DESIGNED_INK.pop(get_parent(), Vector3(s.x, 0.5, s.z), "earth", 1.1 if big else 0.8)
			if big:
				var b := DESIGNED_EL.DESIGNED.spawn(get_parent(), "magma_burst", Vector3(s.x, 0.0, s.z), 2.0, "earth",
					DESIGNED_EL.DESIGNED.MAGMA_TIMES, Vector2(0.55, 1.0))
				b.real_until = 1
		_step = -1  # (redraw now, with the splat)


## Designed: lay the crack tiles each crack has run past since the last frame.
func _lay() -> void:
	var run := BIG_RUN if big else RUN
	for c: Dictionary in _cracks:
		var gone := clampf((_t - float(c.delay)) * run, 0.0, float(c.length))
		var laid: float = c.get("laid", -D_STEP * 0.5)
		while laid + D_STEP <= gone + 0.001:
			laid += D_STEP
			var p := _at(c.pts, c.lens, laid)
			var q := _at(c.pts, c.lens, minf(laid + 0.2, c.length))
			var d := q - p
			var w := global_position + Vector3(p.x, 0.0, p.y)
			var k := lerpf(1.0, 0.75, laid / maxf(float(c.length), 0.1)) * (D_BIG if big else 1.0)
			var fx := DESIGNED_EL._spawn(get_parent(), "magma_crack", Vector3(w.x, DESIGNED_EL.DESIGNED.GROUND_LIFT, w.z),
				DESIGNED_EL.CRACK_SIZE * D_SIZE * k, "earth", D_TIMES, Vector2(0.55, 1.0))
			fx.real_time = real_time
			fx.rotation.y = atan2(d.x, d.y) + PI * 0.5 + randf_range(-0.1, 0.1)
		c["laid"] = laid


func _at(pts: PackedVector2Array, lens: PackedFloat32Array, at: float) -> Vector2:
	for i in range(1, pts.size()):
		if lens[i] >= at:
			var f := (at - lens[i - 1]) / maxf(lens[i] - lens[i - 1], 0.001)
			return pts[i - 1].lerp(pts[i], f)
	return pts[pts.size() - 1]


func _draw(_s: int) -> void:
	if DESIGNED_EL.DESIGNED.on():  # (the tiles and pops are the look)
		return
	var t := _t
	var run := BIG_RUN if big else RUN
	var w0 := BIG_WIDTH if big else WIDTH
	var out := clampf((t - _end_t - HOLD_S) / OUT_S, 0.0, 1.0)
	var k := 1.0 - out
	for layer in 3:
		for c: Dictionary in _cracks:
			var gone := clampf((t - c.delay) * run, 0.0, c.length)
			if gone <= 0.0:
				continue
			var hot: bool = t < c.at + HOT_S
			var pts := _cut(c.pts, c.lens, gone)
			var w := w0 * k
			var tip := lerpf(1.0, TIP, gone / c.length)
			var splat_r: float = SPLAT * (BIG_SPLAT if big else 1.0) * k
			if c.arrived and t < c.at + 2.0 / STEPS_PER_S:
				splat_r *= 1.25  # punches out on its first frame
			match layer:
				0:
					_floor_strip(pts, w + PAL.LINE * 2.0, w * tip + PAL.LINE * 2.0, INK)
					if c.arrived:
						_floor_fan(c.pts[c.pts.size() - 1], _scale(c.splat, splat_r + PAL.LINE * 1.5), INK)
				1:
					_floor_strip(pts, w, w * tip, _p.body if hot else _p.deep, _p.deep)
					if c.arrived:
						_floor_fan(c.pts[c.pts.size() - 1], _scale(c.splat, splat_r), _p.hot if hot else _p.body, _p.body if hot else _p.deep)
				2:
					if hot:
						_floor_strip(pts, w * 0.32, w * tip * 0.2, _p.hot)
		_layer()


## The points of a crack up to `gone` m along it.
func _cut(pts: PackedVector2Array, lens: PackedFloat32Array, gone: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		if lens[i] <= gone:
			out.append(pts[i])
			continue
		var f := (gone - lens[i - 1]) / maxf(lens[i] - lens[i - 1], 0.001)
		out.append(pts[i - 1].lerp(pts[i], f))
		break
	return out


func _scale(ring: PackedVector2Array, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in ring:
		out.append(p * r)
	return out
