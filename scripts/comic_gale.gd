## A whirlwind: the designed twister (ribbon bands, floor swirl, wisps, debris) in the air palette
## (designed_twister.spawn). A forwarder for the callers (elements.pillar, comic_fault).

const TWISTER := preload("res://scripts/designed_twister.gd")


static func spawn(parent: Node, spot: Vector3, h: float, r: float, time: float) -> Node3D:
	return TWISTER.spawn(parent, spot, h, r, time)
