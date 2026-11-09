extends RefCounted
## Storm Pitch's lightning (Dash H L, dark into storm), two pieces:
##   ComicArc.ride(parent, foe, flight): the storm riding a thrown foe: the authored `arc_crawl` sheet stamped on
##     it again every RIDE_EVERY steps while its flight (thrown_foe) lasts, then a step more (Rider below).
##   ComicArc.jump(parent, a, b): the jolt it throws at a foe it passes: a thin comic_bolt with a small star on the
##     one it hits, thinner than Live Wire's so the rider stays the main shape.

const COMIC_BOLT := preload("res://scripts/comic_bolt.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const FX_BEAT := preload("res://scripts/fx_beat.gd")
const RIDE_EVERY := 3  # steps (on twos) between the rider's arc stamps: each crawl's peak is over by then
const RIDE_SIZE := 2.6  # m: a crawl's square (DESIGNED.CRAWL_SIZE 1.9 sat on the body as specks; the forks must reach past it)
const MAX_LIFE := 1.4  # s
const AFTER := 0.1  # s it lasts once the flight is over
const JUMP_WIDTH := 0.18
const JUMP_STAR := 0.42


static func ride(parent: Node, e: Variant, by: Variant) -> Node3D:
	if not is_instance_valid(e):
		return null
	var d := Rider.new()
	d.foe = e
	d.flight = by
	parent.add_child(d)
	return d


static func jump(parent: Node, a: Vector3, b: Vector3) -> void:
	COMIC_BOLT.spawn(parent, a, b, JUMP_WIDTH, JUMP_STAR, 0)


## The crawl's own beat (glint, held strike, afterimage, erosion) carries each burst; no speed strokes (the throw's
## own trail and the jolts it throws show the flight). `foe` and `flight` stay untyped: either can be freed under it.
class Rider extends Node3D:
	var foe: Variant
	var flight: Variant
	var _t := 0.0
	var _over := -1.0
	var _next := 0

	func _process(delta: float) -> void:
		_t += delta
		if not is_instance_valid(foe):
			queue_free()
			return
		var flying: bool = is_instance_valid(flight) and not (flight as Node).is_queued_for_deletion()
		if not flying and _over < 0.0:
			_over = _t
		if (_over >= 0.0 and _t - _over >= AFTER) or _t >= MAX_LIFE:
			queue_free()
			return
		var step := FX_BEAT.step(_t)
		if step < _next or _over >= 0.0:
			return
		_next = step + RIDE_EVERY
		var off := Vector3.UP * DESIGNED.CRAWL_UP
		var fx: Node3D = FX_BEAT.stamp(get_parent(), "arc_crawl", (foe as Node3D).global_position + off, RIDE_SIZE, "wind",
				DESIGNED.CRAWL_TIMES, {"erode": Vector2(0.5, 1.0)})
		if fx != null:
			fx.follow = foe
			fx.follow_off = off
			(foe as Node3D).set_meta("arc_crawl_until", Time.get_ticks_msec() + 360)  # (DESIGNED.crawl won't stack one on it)
