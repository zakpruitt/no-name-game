extends SceneTree
## Checks the Ascendancy element effects on a real enemy: Water chill/freeze/
## shatter, Earth magma pool and volcano, Wind lightning and tempest.
## Prints `[ascend] PASS` or `[ascend] FAIL ...`. Works headless:
## godot --headless --path . -s tests/ascend_check.gd

var _fails: Array[String] = []
var A: GDScript  # scripts/ascendancy.gd, loaded at runtime (it uses the Game autoload)


func _initialize() -> void:
	await process_frame
	A = load("res://scripts/ascendancy.gd")
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	main.clear_room()
	var at: Vector3 = main.player.global_position + Vector3(0.0, 0.0, 5.0)

	# Water: 4 chill hits freeze; the next hit deals shatter_mult damage and thaws.
	var w: Dictionary = A.PATHS.water
	var e: Node = await _fresh(main, at)
	for i in int(w.freeze_hits):
		A.chill_hit(e)
	_check(e.chill_t > 0.0, "chill sets chill_t")
	_check(e.frozen_t > 0.0, "%d chill hits freeze" % w.freeze_hits)
	var hp: float = e.hp
	e.take_hit(4.0, Vector3.ZERO, 0.0, false)
	_check(is_equal_approx(hp - e.hp, 4.0 * w.shatter_mult), "frozen hit deals x%s (took %s)" % [w.shatter_mult, hp - e.hp])
	_check(e.frozen_t <= 0.0, "hit shatters the ice")

	# Earth: a magma pool under an enemy burns it.
	e = await _fresh(main, at)
	hp = e.hp
	A.magma_pool(main, e.global_position, 1.5)
	await create_timer(1.0).timeout
	_check(e.hp < hp, "magma pool burns (%s -> %s)" % [hp, e.hp])
	e = await _fresh(main, at)
	hp = e.hp
	var v: Node3D = A.Volcano.new()
	main.add_child(v)
	v.global_position = at + Vector3(2.0, 0.0, 0.0)
	await create_timer(1.6).timeout
	_check(not is_instance_valid(e) or e.hp < hp, "volcano bombs hit")

	# Wind: lightning damages in its radius; the tempest pulls and strikes.
	e = await _fresh(main, at)
	hp = e.hp
	A.lightning(main, e.global_position, 10.0, 1.8, "lightning")
	_check(e.hp < hp, "lightning hits")
	e = await _fresh(main, at + Vector3(4.0, 0.0, 0.0))
	hp = e.hp
	var start: Vector3 = e.global_position
	var t: Node3D = A.Tempest.new()
	main.add_child(t)
	t.global_position = Vector3(at.x, 0.0, at.z)
	await create_timer(1.0).timeout
	_check(not is_instance_valid(e) or e.global_position.distance_to(t.global_position) < start.distance_to(Vector3(at.x, 0.0, at.z)), "tempest pulls")
	_check(not is_instance_valid(e) or e.hp < hp, "tempest strikes")

	print("[ascend] PASS" if _fails.is_empty() else "[ascend] FAIL " + "; ".join(_fails))
	quit()


## A minion at `at`, past its spawn animation, standing still.
func _fresh(main: Node, at: Vector3) -> Node:
	for old in main.get_tree().get_nodes_in_group("enemies"):
		old.queue_free()
	var e: Node = main._spawn("minion", false, at)
	e.max_hp = 500.0
	e.hp = 500.0
	await create_timer(1.1).timeout
	e.move_speed = 0.0
	e.attack_damage = 0.0
	return e


func _check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
