extends "res://scripts/comic_flat.gd"
## Steam Burst's cloud (Dash L H H L, ice into magma): a frozen foe goes off in steam. Nine fat puffs in one inked
## outline (every puff's ink drawn first, then every fill over it, so only the cloud's outer edge is inked), white
## in the middle to a cool blue-grey edge, rising and swelling, with a small hot magma star at its foot on the
## first frame and three paper strokes shooting up. Thins and shrinks away by 0.55 s. Replaces the soft white
## Fx.burst and the lava geyser the placeholder put on each.
##   ComicSteam.spawn(parent, spot)

const SELF := preload("res://scripts/comic_steam.gd")
const PUFFS := 9
const CROWN := 3  # of them over its head
const HIGH := 0.9  # m: the cloud's middle over the floor at the start
const SPREAD := 0.6  # m: the ring round its body
const PUFF_R := Vector2(0.28, 0.36)
const RISE := Vector2(1.2, 2.0)  # m/s up
const GROW := 0.6  # of its size it grows over its life
const EDGE := Color(0.66, 0.76, 0.9, 0.95)  # the puffs' cool edge
const CORE := Color(1.0, 1.0, 1.0, 0.97)
const STAR := 0.62  # m: the magma star at its foot
const STROKES := 3

var _puffs := []  # {pos, vel, r, shape}
var _star := PackedFloat32Array()
var _hot: Dictionary


static func spawn(parent: Node, spot: Vector3) -> Node3D:
	var s: Node3D = SELF.new()
	s.life = 0.55
	s.begin(parent, Vector3(spot.x, HIGH, spot.z))
	return s


func _build() -> void:
	_hot = PAL.of("earth")
	for i in PUFFS:  # a ring round the foe's body and a crown over its head: the foe still shows in the middle
		var crown := i >= PUFFS - CROWN
		var a: float
		if crown:
			a = PI * 0.5 + (i - (PUFFS - CROWN) - (CROWN - 1) * 0.5) * 0.9
		else:
			a = TAU * i / (PUFFS - CROWN) + _rng.randf_range(-0.25, 0.25)
		var out := _screen(a)
		var off := (_right * out.dot(_right) + _up * out.dot(_up) * 0.6) * SPREAD if not crown else out * 0.35 + _up * 0.95
		var shape := PackedFloat32Array()
		for k in 10:
			shape.append(_rng.randf_range(0.9, 1.06))
		_puffs.append({"pos": off, "vel": _up * _rng.randf_range(RISE.x, RISE.y) + out * _rng.randf_range(0.7, 1.2),
			"r": _rng.randf_range(PUFF_R.x, PUFF_R.y) * (1.2 if crown else 1.0), "shape": shape})
	for i in 7:
		_star.append(_rng.randf_range(0.75, 1.15))


func _draw(s: int) -> void:
	var k := _t / life
	var grow := 1.0 + GROW * sqrt(k)
	var thin := clampf((k - 0.6) / 0.4, 0.0, 1.0)  # the last steps: shrinks and goes see-through
	if s == 0:
		var foot := -_up * (HIGH - 0.25)
		_fan(foot, _star_ring(_star, STAR, 0.34), HOT_CORE, PAL.fade(_hot.body, 0.85))
		_outline(foot, _star_ring(_star, STAR, 0.34), PAL.LINE, INK)
		for i in STROKES:
			var x := (i - 1) * 0.45
			_wedge(_right * x + _up * 0.2, _up, 1.3, 0.13, CORE)
	var rings := []
	for p: Dictionary in _puffs:
		var at: Vector3 = p.pos + p.vel * _t * (1.0 - 0.35 * k)
		rings.append([at, _ring(p.shape, p.r * grow * (1.0 - 0.45 * thin))])
	if thin < 0.7:
		for r: Array in rings:
			_outline(r[0], r[1], PAL.LINE * 1.3, PAL.fade(INK, 1.0 - thin))
	for r: Array in rings:
		_fan(r[0], r[1], PAL.fade(CORE, 1.0 - thin * 0.6), PAL.fade(EDGE, 1.0 - thin * 0.7))
