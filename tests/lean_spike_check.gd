extends SceneTree
## The turn lean (heretic_rig._lean_into_turns) under frame spikes (headless, PASS/FAIL):
##   godot --headless --path . -s tests/lean_spike_check.gd
## Windowed runs with long frame spikes blew the stiff lean spring up (an explicit step past ~0.06 s
## diverges): "axis must be normalized" every frame and the hero vanished. Feeds 0.5 s deltas while his
## velocity flips and drops to zero, and a NaN lean, and checks the lean and the root bone stay finite
## and the root's basis orthonormal.

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func _root_ok(skel: Skeleton3D, root: int) -> bool:
	var q := skel.get_bone_pose_rotation(root)
	if not (is_finite(q.x) and is_finite(q.y) and is_finite(q.z) and is_finite(q.w)):
		return false
	var b := Basis(q)
	return b.is_finite() and absf(b.determinant() - 1.0) < 1e-3 and b.orthonormalized().is_equal_approx(b)


func _initialize() -> void:
	await process_frame
	var game := get_root().get_node("Game")
	game.save_hints = false
	game._hints_seen = game.HINTS.keys()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	var p: CharacterBody3D = main.player
	var skel: Skeleton3D = p.model.find_children("*", "Skeleton3D", true, false)[0]
	var rig: Node = skel.find_children("*", "", false, false).filter(func(n: Node) -> bool: return n.has_method("form_weight"))[0]
	var root := skel.find_bone("root")
	_check(root >= 0, "the hero has a root bone")
	p.state = p.State.MOVE
	var worst := 0.0
	var ok := true
	for i in 40:
		p.velocity = [Vector3(7.5, 0, 0), Vector3(-7.5, 0, 0), Vector3.ZERO, Vector3(0, 0, 9)][i % 4]
		skel.set_bone_pose_rotation(root, Quaternion.IDENTITY)
		rig._lean_into_turns(0.5, skel)
		ok = ok and rig.lean.is_finite() and _root_ok(skel, root)
		worst = maxf(worst, rig.lean.length())
	_check(ok, "0.5 s deltas with the velocity flipping: lean and root stay finite and orthonormal")
	_check(worst <= 15.0 * 1.6, "the lean stays near its cap (worst %.1f deg)" % worst)
	rig.lean = Vector2(NAN, 0.0)
	rig._lean_into_turns(1.0 / 60.0, skel)
	_check(rig.lean.is_finite() and _root_ok(skel, root), "a non-finite lean resets to zero")
	p.velocity = Vector3.ZERO
	for i in 10:
		rig._lean_into_turns(0.0001, skel)
	_check(rig.lean.is_finite() and _root_ok(skel, root), "tiny deltas at zero velocity stay finite")
	print("PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit()
