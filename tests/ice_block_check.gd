extends SceneTree
## The ice block round a frozen foe covers the whole model (fx-ice2; Zak: "ensure they're covering the whole
## character model tho. the dummies part of them clip out."). Headless, on every foe kind the room can spawn (the
## training dummy and the eight enemy_types kinds): each is hit, encased the way the ice moves do it
## (void_element.encase: enemy.freeze, then thrown_foe.cube_on), and for a second after, every vertex of its model,
## skinned on the CPU in its current pose, must lie inside the block (designed_elements.fit_block: a hex prism, its
## flats `r` from its axis, narrowing to BLOCK_TAPER at the top). Weapons held out past FIT_R_MAX may poke out
## ("within reason"); the body may not. Also: the dummy's bag tilt holds while frozen, the clip holds at 0 and runs
## again after the thaw, and the crown crystals are gone. Prints [ice_block] PASS/FAIL and each kind's numbers.
## Run: godot --headless --path . -s tests/ice_block_check.gd

const TOLERANCE := 0.02  # m: under the block's ink line (the hit freeze shudders the model 0.07 m round its spot)
const KINDS := ["dummy", "minion", "warrior", "mage", "rogue", "archer", "shield", "necromancer", "bomber"]

var _fails: Array[String] = []
var _main: Node
var _el: GDScript
var _void: GDScript


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	_el = load("res://scripts/designed_elements.gd")
	_void = load("res://scripts/void_element.gd")
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await create_timer(0.3).timeout
	if not _el.DESIGNED.on():
		print("[ice_block] FAIL designed effects are off")
		quit(1)
		return
	var dummy: Node3D = null
	for d in get_nodes_in_group("enemies"):
		dummy = d
		break
	var home: Vector3 = _main.player.global_position
	for kind: String in KINDS:
		for old in get_nodes_in_group("enemies"):
			if old != dummy:
				old.queue_free()
		var e: Node3D = dummy
		if kind != "dummy":
			e = _main._spawn(kind, false, home + Vector3(0.0, 0.0, 5.0))
			await create_timer(0.8).timeout
			e.move_speed = 0.0
			e.attack_damage = 0.0
		await _freeze_and_measure(kind, e)
	_crown_gone()
	print("[ice_block] ", "PASS" if _fails.is_empty() else "FAIL " + "; ".join(_fails))
	quit(0 if _fails.is_empty() else 1)


func _freeze_and_measure(kind: String, e: Node3D) -> void:
	for i in 60:  # (out of its spawn rise first)
		if e.is_alive():
			break
		await create_timer(0.05).timeout
	# a big hit along the blow first, as the ice moves land (lean / squash / the dummy's bag swing), then the ice
	e.take_hit(1.0, Vector3(5.0, 0.0, 1.0), 0.0, true)
	await physics_frame
	var t0 := Time.get_ticks_usec()
	_void.encase(e)
	var fit_us := Time.get_ticks_usec() - t0
	var cube0: MeshInstance3D = e.get_node_or_null("ThrownCube")
	if cube0 != null:
		t0 = Time.get_ticks_usec()
		for i in 4:
			_el.fit_block(e, cube0)
		fit_us = (Time.get_ticks_usec() - t0) / 4
	var cube: MeshInstance3D = e.get_node_or_null("ThrownCube")
	if cube == null:
		_fails.append("%s: no ice block (state %s alive %s frozen_t %.2f)" % [kind, e.state, e.is_alive(), e.frozen_t])
		return
	var worst_out := 0
	var worst_body := 0.0
	var worst_any := 0.0
	var total := 0
	for step in 12:
		await create_timer(1.0 / 12.0).timeout
		if not is_instance_valid(cube) or e.frozen_t <= 0.0:
			break
		var r: float = _block_r(cube)
		var h: float = _block_h(cube)
		var inv: Transform3D = cube.global_transform.affine_inverse()
		var out := 0
		var pts := _posed(e.model)
		total = pts.size()
		for p in pts:
			if p.y < 0.0:  # (under the floor: hidden by it)
				continue
			var q := inv * p
			var t := clampf((q.y + h * 0.5) / h, 0.0, 1.0)
			var lim := r * lerpf(1.0, _el.BLOCK_TAPER, t)
			var d := Vector2(q.x, q.z).length()
			var over := maxf(d - lim, maxf(absf(q.y) - h * 0.5, 0.0))
			if over <= TOLERANCE:
				continue
			worst_any = maxf(worst_any, over)
			var from_foe := e.global_transform.affine_inverse() * p
			if Vector2(from_foe.x, from_foe.z).length() <= _el.FIT_R_MAX:
				out += 1
				worst_body = maxf(worst_body, over)
		worst_out = maxi(worst_out, out)
	if OS.get_cmdline_user_args().has("--debug"):
		var box := AABB()
		var inv2 := e.global_transform.affine_inverse()
		var first := true
		for p in _posed(e.model):
			box = AABB(inv2 * p, Vector3.ZERO) if first else box.expand(inv2 * p)
			first = false
		var mp: PackedVector3Array = _el.model_points(e)
		var mb := AABB(mp[0], Vector3.ZERO)
		var far := Vector3.ZERO
		for q in mp:
			mb = mb.expand(q)
			if Vector2(q.x, q.z).length() > Vector2(far.x, far.z).length():
				far = q
		print("   posed %s  points %s far %s  fit %s  cube at %s" % [box, mb, far, _el.block_fit(mp), cube.position])
	print("[ice_block] %-12s r=%.2f high=%.2f verts=%d body_out=%d (worst %.3f m) any_out_max=%.3f m fit=%.2f ms" % [kind,
		_block_r(cube), _block_h(cube), total, worst_out, worst_body, worst_any, fit_us / 1000.0])
	if worst_out > 0:
		_fails.append("%s: %d vertices of the body outside its block (worst %.2f m)" % [kind, worst_out, worst_body])
	if Vector2(e.model.rotation.x, e.model.rotation.z).length() > 0.01:
		_fails.append("%s: leaning %s while frozen (it stands up in its ice)" % [kind, e.model.rotation])
	if absf(e.anim.speed_scale) > 0.0001 and e._frozen_speed < 0.0:
		_fails.append("%s: its clip runs while frozen (speed %.2f)" % [kind, e.anim.speed_scale])
	# the thaw: a hit shatters it and the clip runs again
	e.take_hit(1.0, Vector3(1.0, 0.0, 0.0), 0.0, false)
	await create_timer(0.5).timeout
	if e.frozen_t > 0.0 or is_equal_approx(e.anim.speed_scale, 0.0):
		_fails.append("%s: still frozen after the shatter (frozen_t %.2f speed %.2f)" % [kind, e.frozen_t, e.anim.speed_scale])
	await create_timer(0.6).timeout


## The block's flat radius and height from its mesh (a hex prism centred on the node).
func _block_r(cube: MeshInstance3D) -> float:
	return _flat_r(cube.mesh)


func _block_h(cube: MeshInstance3D) -> float:
	return cube.mesh.get_aabb().size.y


## The smallest distance from the axis to a side face at the bottom: the prism's flat radius.
func _flat_r(mesh: Mesh) -> float:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bottom := INF
	for v in verts:
		bottom = minf(bottom, v.y)
	var corner := 0.0
	for v in verts:
		if absf(v.y - bottom) < 0.001:
			corner = maxf(corner, Vector2(v.x, v.z).length())
	return corner * cos(PI / 6.0)


## No crystals stand on the block any more: every vertex lies on the prism (no point above its top cap).
func _crown_gone() -> void:
	var mesh: ArrayMesh = _el.ice_block(0.6, 1.5)
	var top := mesh.get_aabb().end.y
	if absf(top - 0.75) > 0.01:
		_fails.append("the block stands %.2f m over its top: crown crystals are back" % (top - 0.75))


## Every vertex under `root`, skinned on the CPU in its current pose, in world space.
func _posed(root: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null or mi.has_meta("no_ghost"):
			continue
		var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		var skin: Skin = mi.skin
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if sk == null or skin == null or arr[Mesh.ARRAY_BONES] == null:
				for v in verts:
					out.append(mi.global_transform * v)
				continue
			var mats: Array[Transform3D] = []
			for b in skin.get_bind_count():
				var bi := skin.get_bind_bone(b)
				if bi < 0:
					bi = sk.find_bone(skin.get_bind_name(b))
				mats.append(sk.get_bone_global_pose(bi) * skin.get_bind_pose(b))
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / verts.size()
			for i in verts.size():
				var acc := Vector3.ZERO
				var wsum := 0.0
				for k in per:
					var w := weights[i * per + k]
					if w <= 0.0:
						continue
					acc += (mats[bones[i * per + k]] * verts[i]) * w
					wsum += w
				out.append(sk.global_transform * (acc / wsum if wsum > 0.0 else verts[i]))
	return out
