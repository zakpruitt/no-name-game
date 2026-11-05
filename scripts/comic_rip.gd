extends "res://scripts/comic_flat.gd"
## Tow Line's rip out of the air (Dash H on a launched foe: airborne into dark): a jagged inked tear across the
## foe's chest (ink, void body, hot core line), a small hot star on the first frame and four ink drops flicked off
## the way it's yanked. Rides the foe, 0.3 s: the tether and the landing burst are Tow Line's own.
##   ComicRip.spawn(parent, foe, toward)

const SELF := preload("res://scripts/comic_rip.gd")
const CHEST := 0.9
const TEAR := 1.15  # m
const TEAR_W := 0.2
const DROPS := 4

var foe: Variant
var toward := Vector3.ZERO  # world: where it's yanked to
var _p: Dictionary
var _tear := PackedVector3Array()
var _drops := []  # [dir, speed, r]


static func spawn(parent: Node, e: Variant, to: Vector3) -> Node3D:
	if not is_instance_valid(e):
		return null
	var r: Node3D = SELF.new()
	r.foe = e
	r.toward = to
	r.life = 0.3
	r.begin(parent, e.global_position + Vector3.UP * CHEST)
	return r


func _build() -> void:
	_p = PAL.of("void")
	var a := _rng.randf_range(0.5, 0.9) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var d := _screen(a)
	var side := _screen(a + PI * 0.5)
	for i in 5:
		var k := float(i) / 4.0 - 0.5
		_tear.append(d * TEAR * k + side * (0.12 if i % 2 == 1 else -0.06) * _rng.randf_range(0.7, 1.2))
	var pull := toward - global_position
	var pa := _angle(pull) if pull.length() > 0.1 else 0.0
	for i in DROPS:
		_drops.append([_screen(pa + PI + _rng.randf_range(-0.7, 0.7)), _rng.randf_range(4.0, 6.0), _rng.randf_range(0.06, 0.1)])


func _follow(_delta: float) -> void:
	if not is_instance_valid(foe):
		queue_free()
		return
	global_position = foe.global_position + Vector3.UP * CHEST


func _draw(s: int) -> void:
	var k := 1.0 - 0.3 * s
	if s == 0:
		var star := PackedFloat32Array([1.0, 0.6, 1.0, 0.6, 1.0])
		_fan(Vector3.ZERO, _star_ring(star, 0.5, 0.32), HOT_CORE, PAL.fade(_p.light, 0.8))
	_strip(_tear, (TEAR_W + PAL.LINE * 2.0) * k, PAL.LINE * 2.0, INK)
	_strip(_tear, TEAR_W * k, 0.0, _p.body, _p.light)
	_strip(_tear, TEAR_W * 0.3 * k, 0.0, _p.hot)
	for dr: Array in _drops:
		var d: Vector3 = dr[0]
		var at: Vector3 = d * (0.3 + float(dr[1]) * (s + 1) / STEPS_PER_S)
		_fan(at, _ring(PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0]), float(dr[2]) * k), INK)
