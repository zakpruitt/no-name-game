extends RefCounted
## Hailstorm's lift (Dash L H H H, ice into storm): the `hail_whirl` sheet (air ribbons wrapping the frozen foe,
## hail pellets carried round) riding it up; one per frozen foe in place of a full wind pillar each (a 3.5 m funnel
## per foe walled off the pile).
##   ComicHail.ride(parent, foe)

const FX_BEAT := preload("res://scripts/fx_beat.gd")
const WHIRL_SIZE := 3.0  # m: the sheet's square (the widest band ~2 m across, round a 0.9 m cube)
const WHIRL_UP := 0.7  # m over its feet: the whirl's middle
const WHIRL_TIMES := [0.1, 0.09, 0.083, 0.083, 0.083, 0.083, 0.09, 0.1]  # antic (real), peak, on twos, the break


static func ride(parent: Node, e: Variant) -> Node3D:
	if not is_instance_valid(e):
		return null
	return whirl(parent, e)


## The sheet in the air row riding the foe, pooled through FX_BEAT.stamp; anticipation held long enough to reach a
## 12 fps frame, then on twos, eroding as it breaks into curls.
static func whirl(parent: Node, e: Node3D) -> Node3D:
	load("res://scripts/designed_finish.gd")._register()
	var off := Vector3.UP * WHIRL_UP
	var fx: Node3D = FX_BEAT.stamp(parent, "hail_whirl", e.global_position + off, WHIRL_SIZE, "air", WHIRL_TIMES,
			{"erode": Vector2(0.55, 1.0), "vary": false})
	if fx == null:
		return null
	fx.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	fx.follow = e
	fx.follow_off = off
	return fx
