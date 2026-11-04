extends SceneTree
## Enemy hit reactions, headless, on real minions in the arena: every landed
## hit squashes the model per SQUASH kind, grounded hits lean it away along
## the knockback and spring it back, the flash is in the hero's colour, and a
## kill holds the corpse KILL_FREEZE. Prints [enemy_feel] PASS/FAIL.
## Run: godot --headless --path . -s tests/enemy_feel_check.gd

var _fails: Array[String] = []
var _main: Node


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game.skip_title = true
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await create_timer(0.3).timeout
	_main._queue.clear()
	_main.player.bot_enabled = true
	var home: Vector3 = _main.player.global_position
	var at := home + Vector3(0.0, 0.0, 4.0)
	var kb := Vector3(0.0, 0.0, 6.0)  # the hero stands at -z of it: knocked away from him

	# A tap: light squash, a small lean with the blow, back upright in LEAN_TIME.
	var e: Node = await _fresh(at)
	e.model.rotation.y = PI  # facing the hero (-z)
	e.take_hit(1.0, kb, 0.0, false)
	_check(is_equal_approx(e.model.scale.y, e.SQUASH.tap.y * e.model_scale), "tap squashes to %.2f (%.2f)" % [e.SQUASH.tap.y, e.model.scale.y])
	# Facing -z, a blow toward +z is from the front: the top tips back (local -z): rotation.x < 0.
	_check(is_equal_approx(e.model.rotation.x, -e.LEAN) and absf(e.model.rotation.z) < 0.001,
		"tap leans %.2f away from the blow (x %.2f z %.2f)" % [e.LEAN, e.model.rotation.x, e.model.rotation.z])
	_check(e._freeze_t == e.hit_freeze, "tap freezes hit_freeze (%.2f)" % e._freeze_t)
	await create_timer(e.LEAN_TIME + 0.3).timeout
	_check(absf(e.model.rotation.x) < 0.02 and is_equal_approx(e.model.scale.y, e.model_scale),
		"upright and unsquashed again (x %.3f scale %.2f)" % [e.model.rotation.x, e.model.scale.y])
	# A big hit from the side: the lean is LEAN_BIG, around the other axis.
	e.take_hit(1.0, Vector3(6.0, 0.0, 0.0), 0.0, true)
	_check(is_equal_approx(e.model.scale.y, e.SQUASH.big.y * e.model_scale), "big hit squashes to %.2f" % e.SQUASH.big.y)
	_check(absf(absf(e.model.rotation.z) - e.LEAN_BIG) < 0.001 and absf(e.model.rotation.x) < 0.001,
		"big hit leans %.2f sideways (x %.2f z %.2f)" % [e.LEAN_BIG, e.model.rotation.x, e.model.rotation.z])
	_check(e._freeze_t == e.hit_freeze_big, "big hit freezes hit_freeze_big")
	var tinted: MeshInstance3D = e.model.find_children("*", "MeshInstance3D", true, false)[0]
	_check(tinted.material_overlay != null and tinted.material_overlay.albedo_color.a > 0.0, "the hit flash is on")
	await create_timer(0.6).timeout
	# A launch: stretched tall; a hit while up snaps it.
	e.take_hit(1.0, kb, 9.0, true)
	_check(e.state == e.State.AIRBORNE and is_equal_approx(e.model.scale.y, e.SQUASH.launch.y * e.model_scale),
		"a launch stretches to %.2f" % e.SQUASH.launch.y)
	await physics_frame
	await physics_frame
	e.take_hit(1.0, kb, 9.0, false)
	_check(is_equal_approx(e.model.scale.y, e.SQUASH.juggle.y * e.model_scale), "a juggle hit snaps to %.2f" % e.SQUASH.juggle.y)
	# Poise held mid-windup: no squash, still a flash.
	var w: Node = await _fresh(at)
	w.poise = 100.0
	w._set_state(w.State.WINDUP)
	w.take_hit(1.0, kb, 0.0, false)
	_check(is_equal_approx(w.model.scale.y, w.model_scale) and w.model.rotation.x == 0.0, "poise held: no squash or lean")
	# A kill: the pop squash and the long hold.
	var k: Node = await _fresh(at)
	k.hp = 1.0
	k.take_hit(5.0, kb, 0.0, false)
	_check(k.state == k.State.DEAD and k._freeze_t == k.KILL_FREEZE and is_equal_approx(k.model.scale.y, k.SQUASH.kill.y * k.model_scale),
		"a kill pops to %.2f and holds %.2f s (%.2f)" % [k.SQUASH.kill.y, k.KILL_FREEZE, k._freeze_t])
	await _extra()
	print("[enemy_feel] ", "PASS" if _fails.is_empty() else "FAIL " + "; ".join(_fails))
	get_root().get_node("Game").stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


## Further checks (juggle feel, crowd waves) go here as the rounds add them.
func _extra() -> void:
	pass


## A sturdy minion at `at`, past its spawn animation, standing still and harmless.
func _fresh(at: Vector3) -> Node:
	for old in _main.get_tree().get_nodes_in_group("enemies"):
		old.queue_free()
	var e: Node = _main._spawn("minion", false, Vector3(at.x, 0.0, at.z))
	e.max_hp = 2000.0
	e.hp = 2000.0
	await create_timer(1.1).timeout
	e.move_speed = 0.0
	e.attack_damage = 0.0
	e.global_position = Vector3(at.x, 0.0, at.z)
	return e


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		push_error("enemy_feel_check: " + what)
