extends RefCounted
## Finding foes: the living enemies (group "enemies") round a point. Preload it
## (const FOES := preload("res://scripts/foes.gd")); no class_name, so a
## checkout needs no re-import for it.


## Living foes whose body reaches within `radius` of `pos`, on the floor plane.
static func near(tree: SceneTree, pos: Vector3, radius: float) -> Array:
	return tree.get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		if not e.is_alive():
			return false
		var d: Vector3 = e.global_position - pos
		d.y = 0.0
		return d.length() < radius + e.radius)
