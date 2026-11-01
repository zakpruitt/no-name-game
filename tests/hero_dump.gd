extends SceneTree
## Windowless hero preview, part 1: builds the hero (optionally ascended) and
## writes every visible triangle to user://hero_dump.json (world positions,
## UV, colour). tools/render_hero.py rasterizes it to a PNG, so the look can be
## checked without opening a window. Bone attachments sit at the animation's
## first frame (`--anim=`, default 2H_Melee_Idle); skinned meshes are drawn in
## their bind pose (T-pose arms).
## Run: godot --headless --path . -s tests/hero_dump.gd [-- --ascend=wind --awakened]
##      then python tools/render_hero.py

func _initialize() -> void:
	await process_frame
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ascend="):
			path = a.trim_prefix("--ascend=")
	var p: Node3D = load("res://scripts/player.gd").new()
	get_root().add_child(p)
	p.set_physics_process(false)
	if path != "":
		p.ascend(path)
	if "--awakened" in OS.get_cmdline_user_args():
		p._set_awakened(true)
	await process_frame
	await process_frame
	var tris: Array = []
	for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):  # model + aura
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		# Skinned meshes are in bind pose under the model, so their node transform
		# (with the Awakened model scale) places them; attachments follow bones.
		var xf: Transform3D = p.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat := mi.material_override if mi.material_override != null else mi.get_active_material(s)
			var col := Color.WHITE
			var textured := false
			var emissive := false
			if mat is BaseMaterial3D:
				col = mat.albedo_color
				textured = mat.albedo_texture != null and p.model.is_ancestor_of(mi)  # decals: flat colour
				emissive = mat.emission_enabled
			if mat is ShaderMaterial:
				var bc = mat.get_shader_parameter("body_color")
				if bc is Color:
					col = bc
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(v.size())
				for i in v.size():
					idx[i] = i
			for t in range(0, idx.size() - 2, 3):
				var pts := []
				var u := Vector2.ZERO
				for k in 3:
					var w: Vector3 = xf * v[idx[t + k]]
					pts.append([w.x, w.y, w.z])
					if not uv.is_empty():
						u += uv[idx[t + k]] / 3.0
				tris.append({"p": pts, "uv": [u.x, u.y], "c": [col.r, col.g, col.b, col.a if (mat is BaseMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED) or mat is ShaderMaterial else 1.0], "tex": textured, "glow": emissive})
	var f := FileAccess.open("user://hero_dump.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"ascend": path, "tris": tris}))
	f.close()
	print("dumped ", tris.size(), " triangles to ", ProjectSettings.globalize_path("user://hero_dump.json"))
	p.queue_free()
	await process_frame
	quit()
