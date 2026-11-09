## Anvil's landing (Backdraft's breaker, H in window): the hammer drives everyone held into the floor, a drawn
## crater star under each (designed_finish.anvil). A forwarder: void_element.gd calls ComicAnvil.spawn.
##   ComicAnvil.spawn(parent, from, spots)

const DESIGNED_FINISH := preload("res://scripts/designed_finish.gd")


static func spawn(parent: Node, from: Vector3, at: Array) -> Node3D:
	DESIGNED_FINISH.anvil(parent, from, at)
	return null
