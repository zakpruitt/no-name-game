## A lightning bolt from `a` to `b` (strikes out of the sky, the arcs between foes): the authored bolt strip on a
## ribbon (designed_fx.bolt). With `star_size` it lands in an impact star. A forwarder for the callers
## (void_element, elements, live_current, comic_arc, comic_fault); `_fork_count` is kept for their signature
## and not drawn.

const DESIGNED := preload("res://scripts/designed_fx.gd")


static func spawn(parent: Node, a: Vector3, b: Vector3, w := 0.24, star_size := 0.0, _fork_count := 1) -> Node3D:
	return DESIGNED.bolt(parent, a, b, w, star_size)
