extends RefCounted
## Finding foes: the living enemies (group "enemies") round a point, the shared picks over them (nearest,
## nearest first, the densest spot) and the one hit call every element move makes. Preload it
## (const FOES := preload("res://scripts/foes.gd")); no class_name, so a checkout needs no re-import for it.
## No preload of thrown_foe.gd here (it preloads this file): FLYING is its meta, kept in one place.

const FLYING := "thrown_foe_flying"  # meta on a foe in flight (thrown_foe.FLYING reads it from here)


## Living foes whose body reaches within `radius` of `pos`, on the floor plane.
static func near(tree: SceneTree, pos: Vector3, radius: float) -> Array:
	return tree.get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		if not e.is_alive():
			return false
		var d: Vector3 = e.global_position - pos
		d.y = 0.0
		return d.length() < radius + e.radius)


## `v` on the floor plane.
static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## The floor-plane vector from one node to another.
static func to_flat(from: Node3D, to: Node3D) -> Vector3:
	return flat(to.global_position - from.global_position)


## Still there and still alive (a foe a delayed call reaches may have been freed: a Variant, never typed).
static func alive(e: Variant) -> bool:
	return is_instance_valid(e) and e.is_alive()


## The living ones of `arr`.
static func live(arr: Array) -> Array:
	return arr.filter(func(e: Variant) -> bool: return alive(e))


static func flying(e: Node) -> bool:
	return e.has_meta(FLYING)


## The nearest foe (flat distance) to `at` within `r` that passes `pred` (if given), or null.
static func nearest(tree: SceneTree, at: Vector3, r: float, pred: Callable = Callable()) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for e: Node3D in near(tree, at, r):
		if pred.is_valid() and not pred.call(e):
			continue
		var d: float = flat(e.global_position - at).length()
		if d < best_d:
			best_d = d
			best = e
	return best


## The foes within `r` of `at`, not in flight (`skip_flying`), nearest first by flat distance, `limit` at most (-1: all).
static func sorted_near(tree: SceneTree, at: Vector3, r: float, limit := -1, skip_flying := true) -> Array:
	var foes: Array = near(tree, at, r)
	if skip_flying:
		foes = foes.filter(func(e: Node) -> bool: return not flying(e))
	return sorted_from(foes, at, limit)


## `foes` nearest `at` first (flat distance), `limit` at most (-1: all). Sorts in place and returns it.
static func sorted_from(foes: Array, at: Vector3, limit := -1) -> Array:
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return flat(a.global_position - at).length() < flat(b.global_position - at).length())
	return foes.slice(0, limit) if limit >= 0 else foes


## The one of `foes` with the most others within `r` of it (each counted by `weight`, 1 by default), the nearest
## `at` on a tie; null when `foes` is empty. `min_n`: the count a winner needs (spear_auto wants a group of two).
static func densest(foes: Array, r: float, at: Vector3, weight: Callable = Callable(), min_n := 0) -> Node3D:
	var best: Node3D = null
	var best_n := -1.0
	var best_d := INF
	for e: Node3D in foes:
		var n: float = float(weight.call(e)) if weight.is_valid() else 0.0
		for o: Node3D in foes:
			if o != e and flat(o.global_position - e.global_position).length() <= r:
				n += float(weight.call(o)) if weight.is_valid() else 1.0
		var d: float = flat(e.global_position - at).length()
		if n > best_n or (n == best_n and d < best_d):
			best = e
			best_n = n
			best_d = d
	return best if best_n >= float(min_n) else null


## One hit from the hero's side: the foe takes it and the style meter hears of it (`tag`: "cast", "breaker", a move
## id; `air` adds player._do_hit's "_air" suffix, the juggle count). The two calls every element move made by hand.
static func hit(e: Node3D, dmg: float, kb: Vector3, launch: float, big: bool, tag: String, air := false) -> void:
	e.take_hit(dmg, kb, launch, big)
	Game.register_hit(tag + ("_air" if air else ""))
