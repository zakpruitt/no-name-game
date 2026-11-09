## Tow Line's rip out of the air (Dash H on a launched foe: airborne into dark): the drawn ink tear across the
## foe's chest, run the way it's yanked, riding the foe (designed_polish.tear). The tether and the landing burst
## are Tow Line's own.
##   ComicRip.spawn(parent, foe, toward)

const POLISH := preload("res://scripts/designed_polish.gd")
const CHEST := 0.9


static func spawn(parent: Node, e: Variant, to: Vector3) -> Node3D:
	if not is_instance_valid(e):
		return null
	var t: Node3D = POLISH.tear(parent, e.global_position + Vector3.UP * CHEST, to - e.global_position)
	t.follow = e  # (rides the foe it's ripped off)
	t.follow_off = Vector3.UP * CHEST
	return t
