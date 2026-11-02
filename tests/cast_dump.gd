extends SceneTree
## Windowless cast preview: builds the hero plus one shaped spirit cast frozen
## at a pose, and writes the triangles to user://cast_dump.json for
## tools/render_hero.py (auto-fit). Floor = a grey square, enemies = red posts.
## Run: godot --headless --path . -s tests/cast_dump.gd -- --cast=cleave --t=0.5 [--el=earth]
##      python tools/render_hero.py "%APPDATA%/Godot/app_userdata/Awaken/cast_dump.json" out.png 3/4,top
## --t: 0..1 through the move (cleave: <0 = rising, -1 raised .. 0 top, 0..1 chop;
## avatar: 0 wind-up .. 1 the axe landing; its skinned meshes are baked in that pose).

const DUMP := "user://cast_dump.json"

var _foes: Array = []  # breaker case: real dummy foes (drawn as the red posts)


class Dummy extends Node3D:
	var radius := 0.5
	var hp := 1000.0
	func is_alive() -> bool: return hp > 0.0
	func is_airborne() -> bool: return false
	func take_hit(d: float, _kb = Vector3.ZERO, _l = 0.0, _b = false, _x = null) -> void: hp -= d


func _initialize() -> void:
	await process_frame
	var cast := "cleave"
	var t := 0.5
	var el := "spirit"
	var size := 0.0  # avatar scale_to / axe size override
	var brk := "LLH"  # --breaker=CH: which BREAKERS entry the breaker case leaps from (--t<0: -t s after it lands)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cast="):
			cast = a.trim_prefix("--cast=")
		elif a.begins_with("--t="):
			t = float(a.trim_prefix("--t="))
		elif a.begins_with("--size="):
			size = float(a.trim_prefix("--size="))
		elif a.begins_with("--breaker="):
			brk = a.trim_prefix("--breaker=")
		elif a.begins_with("--el="):
			el = a.trim_prefix("--el=")
	var world := Node3D.new()
	get_root().add_child(world)
	var p: Node3D = load("res://scripts/player.gd").new()
	world.add_child(p)
	p.set_physics_process(false)
	await process_frame
	var axe: Mesh = (p.model.find_child("1H_Axe", true, false) as MeshInstance3D).mesh
	var c: Color = load("res://scripts/elements.gd").LOOK[el].color
	if cast == "breaker":  # a breaker's leap (--breaker=, default LLH), `t` s after take-off
		p.set_physics_process(true)
		for at in [Vector3(-1.6, 0, 3.2), Vector3(1.8, 0, 2.4), Vector3(0.4, 0, 4.8)]:  # in the leap's way (+Z)
			var d := Dummy.new()
			d.add_to_group("enemies")
			world.add_child(d)
			d.global_position = at
			_foes.append(d)
		if el != "spirit":
			p.ascend(el)  # the breaker takes the hero's element
		if "--awakened" in OS.get_cmdline_user_args():
			p._set_awakened(true)  # dive breakers summon the ancestor as the window opens
		if t < 0.0:  # the landed breaker, -t s after it lands (the bot presses at the sweet spot)
			p.bot_enabled = true
			p._start_leap(brk)
			while p.breakers_landed == 0:
				await physics_frame
			for i in int(-t * Engine.physics_ticks_per_second):
				await physics_frame
		else:
			p._start_leap(brk)
		while t >= 0.0 and p._state_t < t:
			await physics_frame
		world.process_mode = Node.PROCESS_MODE_DISABLED
		p.global_position.y = 0.0  # (no floor here: the body falls)
		print("breaker: model y=%.2f hero=%s zone=%s" % [p.model.position.y, p.global_position, p._brk_zone])
		cast = "none"
	if cast == "plunge":  # the air-string plunge's fan of axes ahead (player._plunge_axes), landed
		for i in 3:
			var side := i - 1
			var dir := Vector3.BACK.rotated(Vector3.UP, deg_to_rad(32.0 * side))
			var g: Node3D = load("res://scripts/spirit_guillotine.gd").new()
			g.axe_mesh = axe
			g.color = c
			g.el = el
			g.fwd = dir
			g.size = 2.4 * (1.0 if side == 0 else 0.8)
			world.add_child(g)
			g.global_position = dir * (2.4 if side == 0 else 2.0)
			g.process_mode = Node.PROCESS_MODE_DISABLED
			g._axe.position.y = g._rest
		cast = "none"
	if cast == "cataclysm":  # the ring of axes round the hero, all landed
		for i in 6:
			var ang := TAU * (i + 0.5) / 6.0
			var g: Node3D = load("res://scripts/spirit_guillotine.gd").new()
			g.axe_mesh = axe
			g.color = c
			g.el = el
			g.size = 4.2
			world.add_child(g)
			g.global_position = Vector3(sin(ang), 0, cos(ang)) * 3.8
			g.process_mode = Node.PROCESS_MODE_DISABLED
			g._axe.position.y = g._rest
		cast = "none"
	var node: Node3D
	match cast:
		"cleave":
			node = load("res://scripts/spirit_cleave.gd").new()
		"echo":
			node = load("res://scripts/spirit_echo.gd").new()
			node.radius = 3.9
			node.arc_deg = 200.0
		"avatar":
			node = load("res://scripts/spirit_avatar.gd").new()
		"crown":
			node = load("res://scripts/spirit_crown.gd").new()
		"rift":
			node = load("res://scripts/spirit_rift.gd").new()
		"wheel":
			node = load("res://scripts/spirit_wheel.gd").new()
		"tomahawk":
			node = load("res://scripts/spirit_tomahawk.gd").new()
		"guillotine":
			node = load("res://scripts/spirit_guillotine.gd").new()
			node.size = 3.8
	if node == null:  # (cataclysm: the pieces are already placed)
		node = Node3D.new()
	if cast in ["wheel", "tomahawk"]:
		node.set_process(false)
	if size > 0.0:
		node.set("scale_to" if cast == "avatar" else "size", size)
	if "axe_mesh" in node:
		node.axe_mesh = axe
	if "color" in node:
		node.color = c
		node.el = el
	if "fwd" in node:
		node.fwd = Vector3.FORWARD
	world.add_child(node)
	if cast in ["cleave", "crown", "guillotine"]:
		node.global_position = Vector3(0, 0, -3.2)
	node.process_mode = Node.PROCESS_MODE_DISABLED  # freeze its tweens; pose by hand
	if cast == "cleave":
		if t < 0.0:
			node._appear(t + 1.0)
		else:
			node._appear(1.0)
			node.pose(t)
	elif cast == "none":
		pass
	elif cast == "crown":
		node._rise(t)
	elif cast == "guillotine":
		node._axe.position.y = node._rest + node.DROP * (1.0 - t)
	elif cast == "tomahawk":
		node._fly_out(t)
		node._spinner.rotation.y = t * 5.0
	elif cast == "wheel":
		node._hub.scale = Vector3.ONE
		node._hub.rotation.y = t * TAU
		node._fade(1.0)
	elif cast == "rift":  # every axe fully up
		for i in node.steps:
			node._burst(i)
		for a in node.find_children("*", "MeshInstance3D", true, false):
			a.position.y = 0.0
			a.material_override.albedo_color.a = 0.6
	elif cast == "avatar":
		node._grow(1.0)
		node.model.process_mode = Node.PROCESS_MODE_ALWAYS  # skeleton + bone attachments follow the seek
		node.anim.seek(node.anim.current_animation_length * lerpf(node.START, node.IMPACT, t), true)
		node.anim.pause()
		var land: Vector3 = node.land_point()
		print("land point ", land)
	else:
		node.pose(t)
		node._mat.albedo_color.a = 0.6
	if not p.state == p.State.LEAP:
		p.rotation.y = PI  # faces -Z, like the casts
	await process_frame
	var tris: Array = []
	_quad(tris, Vector3.ZERO, 7.0, Color(0.55, 0.52, 0.48))
	if _foes.is_empty():
		for x in [-1.2, 0.0, 1.3]:
			_post(tris, Vector3(x, 0, -4.2 - absf(x) * 0.4), Color(0.8, 0.2, 0.2))
	for f: Node3D in _foes:
		_post(tris, Vector3(f.global_position.x, 0, f.global_position.z), Color(0.8, 0.2, 0.2))
	for mi: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		if mi.mesh is PlaneMesh or mi.mesh is QuadMesh:  # decals and sprites: drawn as flat squares
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.material_override if mi.material_override != null else mi.get_active_material(s)
			var col := Color.WHITE
			var alpha := 1.0
			var tex := false
			if mat is BaseMaterial3D:
				col = mat.albedo_color
				tex = mat.albedo_texture != null and p.model.is_ancestor_of(mi)
				if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					alpha = col.a
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var v := _world_verts(mi, s, arr, p)
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(v.size())
				for i in v.size():
					idx[i] = i
			var ghost := not p.is_ancestor_of(mi)
			for k0 in range(0, idx.size() - 2, 3):
				var pts := []
				var u := Vector2.ZERO
				for k in 3:
					var w: Vector3 = v[idx[k0 + k]]
					pts.append([w.x, w.y, w.z])
					if not uv.is_empty():
						u += uv[idx[k0 + k]] / 3.0
				tris.append({"p": pts, "uv": [u.x, u.y], "c": [col.r, col.g, col.b, alpha], "tex": tex, "glow": ghost})
	var f := FileAccess.open(DUMP, FileAccess.WRITE)
	f.store_string(JSON.stringify({"ascend": cast, "fit": true, "tris": tris}))
	f.close()
	print("dumped ", tris.size(), " triangles to ", ProjectSettings.globalize_path(DUMP))
	world.queue_free()
	await process_frame
	quit()


## World positions of surface `s`'s vertices; skinned avatar meshes are
## skinned on the CPU in the current pose (headless never registers skins, so
## bake_mesh_from_current_skeleton_pose fails).
func _world_verts(mi: MeshInstance3D, s: int, arr: Array, hero: Node) -> PackedVector3Array:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var out := PackedVector3Array()
	out.resize(v.size())
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if hero.is_ancestor_of(mi) or mi.skin == null or skel == null or arr[Mesh.ARRAY_BONES] == null:
		for i in v.size():
			out[i] = mi.global_transform * v[i]
		return out
	var binds: Array[Transform3D] = []
	for i in mi.skin.get_bind_count():
		var bone := mi.skin.get_bind_bone(i)
		if bone < 0:
			bone = skel.find_bone(mi.skin.get_bind_name(i))
		binds.append(skel.global_transform * skel.get_bone_global_pose(bone) * mi.skin.get_bind_pose(i))
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / v.size()
	for i in v.size():
		var w := Vector3.ZERO
		for k in per:
			var wt := weights[i * per + k]
			if wt > 0.0:
				w += binds[bones[i * per + k]] * v[i] * wt
		out[i] = w
	return out


func _quad(tris: Array, at: Vector3, half: float, c: Color) -> void:
	var a := at + Vector3(-half, 0, -half)
	var b := at + Vector3(half, 0, -half)
	var d := at + Vector3(half, 0, half)
	var e := at + Vector3(-half, 0, half)
	for tri in [[a, b, d], [a, d, e]]:
		tris.append({"p": tri.map(func(q): return [q.x, q.y - 0.01, q.z]), "uv": [0, 0], "c": [c.r, c.g, c.b, 1.0], "tex": false, "glow": false})


func _post(tris: Array, at: Vector3, c: Color) -> void:
	var r := 0.35
	var h := 1.6
	for i in 6:
		var a0 := TAU * i / 6.0
		var a1 := TAU * (i + 1) / 6.0
		var p0 := at + Vector3(sin(a0) * r, 0, cos(a0) * r)
		var p1 := at + Vector3(sin(a1) * r, 0, cos(a1) * r)
		for tri in [[p0, p1, p1 + Vector3.UP * h], [p0, p1 + Vector3.UP * h, p0 + Vector3.UP * h]]:
			tris.append({"p": tri.map(func(q): return [q.x, q.y, q.z]), "uv": [0, 0], "c": [c.r, c.g, c.b, 1.0], "tex": false, "glow": false})
