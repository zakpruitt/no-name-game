extends "res://scripts/comic_flat.gd"
## Storm Pitch's lightning (Dash H L, dark into storm), two pieces:
##   ComicArc.ride(parent, foe, flight): the storm riding a thrown foe. Three short inked forks crackle off its
##     body (new zigzags every step: ink line, storm green, pale core) with two pale speed strokes trailing it, for
##     as long as its flight (thrown_foe) lasts, then a step more. Follows the foe every frame; both kept untyped.
##   ComicArc.jump(parent, a, b): the jolt it throws at a foe it passes: a thin comic_bolt with a small star on the
##     one it hits, thinner than Live Wire's so the rider stays the main shape.

const SELF := preload("res://scripts/comic_arc.gd")
const COMIC_BOLT := preload("res://scripts/comic_bolt.gd")
const CHEST := 0.9  # m up the foe
const FORKS := 3
const FORK_LEN := Vector2(0.75, 1.05)  # m
const FORK_W := 0.15  # m of colour at the root
const TRAIL := 2
const TRAIL_LEN := 1.4
const MAX_LIFE := 1.4  # s
const AFTER := 0.1  # s it lasts once the flight is over
const JUMP_WIDTH := 0.18
const JUMP_STAR := 0.42

var foe: Variant
var flight: Variant
var _p: Dictionary
var _last := Vector3.ZERO
var _dir := Vector3.ZERO  # world, its travel
var _over := -1.0


static func ride(parent: Node, e: Variant, by: Variant) -> Node3D:
	if not is_instance_valid(e):
		return null
	var r: Node3D = SELF.new()
	r.foe = e
	r.flight = by
	r.life = MAX_LIFE
	r.begin(parent, e.global_position + Vector3.UP * CHEST)
	return r


static func jump(parent: Node, a: Vector3, b: Vector3) -> void:
	COMIC_BOLT.spawn(parent, a, b, JUMP_WIDTH, JUMP_STAR, 0)


func _build() -> void:
	_p = PAL.of("wind")
	_last = global_position


func _follow(_delta: float) -> void:
	if not is_instance_valid(foe):
		queue_free()
		return
	var at: Vector3 = foe.global_position + Vector3.UP * CHEST
	var moved := at - _last
	if moved.length() > 0.02:
		_dir = _dir.lerp(moved.normalized(), 0.5)
	_last = at
	global_position = at
	var flying: bool = is_instance_valid(flight) and not flight.is_queued_for_deletion()
	if not flying and _over < 0.0:
		_over = _t
	if _over >= 0.0 and _t - _over >= AFTER:
		queue_free()


func _draw(_s: int) -> void:
	var travel := _right * _dir.dot(_right) + _up * _dir.dot(_up)
	if travel.length() > 0.05:
		var back := -travel.normalized()
		for i in TRAIL:
			var off := back.cross(_view).normalized() * (i - 0.5) * 0.5
			_wedge(off + back * (TRAIL_LEN + 0.4), -back, TRAIL_LEN, 0.14, PAL.fade(_p.light, 0.9))
	var turn := _rng.randf() * TAU
	var forks := []
	for i in FORKS:
		var a := turn + TAU * (i + _rng.randf_range(-0.2, 0.2)) / FORKS
		var reach := _rng.randf_range(FORK_LEN.x, FORK_LEN.y)
		var pts := PackedVector3Array([_screen(a) * 0.3])
		for k in range(1, 4):  # hard zigzag kinks, alternating sides: a bolt, not a sprout
			var side := 0.2 * (1.0 if k % 2 == 1 else -1.0) * _rng.randf_range(0.7, 1.2)
			pts.append(_screen(a) * (0.3 + reach * k / 3.0) + _screen(a + PI * 0.5) * side)
		forks.append(pts)
	for pts: PackedVector3Array in forks:
		_strip(pts, FORK_W + PAL.LINE * 2.0, FORK_W * 0.4 + PAL.LINE * 2.0, INK)
	for pts: PackedVector3Array in forks:
		_strip(pts, FORK_W, FORK_W * 0.4, _p.body)
	for pts: PackedVector3Array in forks:
		_strip(pts, FORK_W * 0.35, FORK_W * 0.12, _p.hot)
