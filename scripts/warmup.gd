extends RefCounted
## Keeps what effects load on the fly alive for the whole session, so no effect
## hitches the frame it first (or next) shows. Two things were freed and rebuilt
## mid-fight (10-37 ms each on the main thread):
##
## Scripts: effects `load("res://scripts/comic_fist.gd")` when they fire. The
## resource cache only holds a script while something references it, so once
## the last fist was freed the next one re-parsed and compiled the script
## (~10-15 ms). `keep_scripts()` loads every script once and holds it.
##
## Shaders: StandardMaterial3D and ParticleProcessMaterial generate one shader per
## combination of their flags (shading, transparency, blend, cull, billboard,
## textures...), shared by every material with that combination and *freed
## when the last such material is freed*. Effects build fresh materials each
## time and free them when they end, so the next use compiled the shader again:
## 10-15 ms on the main thread, on every breaker, daze, freeze and awaken.
##
## `prewarm()` builds one material per signature in `warmup_shaders.gd`,
## draws it once and holds it forever. Refresh the list after adding effects:
## `godot --path . -- --autotest --collect-shaders` (and `tests/element_shots.gd
## -- --collect-shaders` for every move) merge the signatures seen into it.

const LIST_PATH := "res://scripts/warmup_shaders.gd"
const KINDS := ["StandardMaterial3D", "ORMMaterial3D", "ParticleProcessMaterial"]
# Properties that never change the generated shader.
const SKIP := ["render_priority", "resource_local_to_scene", "resource_name", "next_pass"]

static var _kept: Array[Material] = []
static var _scripts: Array[Script] = []
static var _known := {}  # signature string -> true (the list plus anything seen this run)
static var _new: Array[Dictionary] = []  # signatures met this run that the list lacks
static var _defaults := {}  # class -> a fresh instance, to leave default values out


## The shader-relevant settings of `mat` that differ from a new one (its class,
## ints / bools, and which textures are set), or {} for a material that doesn't
## generate its shader.
static func signature(mat: Material) -> Dictionary:
	if mat == null or mat.get_class() not in KINDS:
		return {}
	var cls := mat.get_class()
	if not _defaults.has(cls):
		_defaults[cls] = ClassDB.instantiate(cls)
	var base: Material = _defaults[cls]
	var sig := {"class": cls}
	for p: Dictionary in mat.get_property_list():
		if not (p.usage & PROPERTY_USAGE_STORAGE) or p.name in SKIP or p.name.begins_with("metadata/"):
			continue
		var v: Variant = mat.get(p.name)
		match p.type:
			TYPE_INT, TYPE_BOOL:
				if v != base.get(p.name):
					sig[p.name] = v
			TYPE_OBJECT:
				if v != null:
					sig[p.name] = p.hint_string.get_slice(",", 0)
	return sig


## Load and hold every script under res://scripts.
static func keep_scripts() -> void:
	if not _scripts.is_empty():
		return
	for f: String in DirAccess.get_files_at("res://scripts"):
		f = f.trim_suffix(".remap")  # exported builds list compiled scripts as .remap
		if f.get_extension() == "gd":
			var s: Script = load("res://scripts/" + f)
			if s != null:
				_scripts.append(s)


## Build, draw once and keep a material for every listed signature. `at` is
## somewhere the camera sees (they draw just under the floor there).
static func prewarm(parent: Node, at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Warmup"
	parent.add_child(root)
	root.global_position = at + Vector3.DOWN * 0.4
	var list: Array = load(LIST_PATH).LIST
	for sig: Dictionary in list:
		_known[var_to_str(sig)] = true
		var mat := _build(sig)
		if mat == null:
			continue
		_kept.append(mat)
		if mat is ParticleProcessMaterial:
			var p := GPUParticles3D.new()
			p.amount = 1
			p.lifetime = 0.1
			p.process_material = mat
			var q := QuadMesh.new()
			q.material = _build({"class": "StandardMaterial3D", "shading_mode": 0})
			p.draw_pass_1 = q
			root.add_child(p)
		else:
			var mi := MeshInstance3D.new()
			mi.mesh = QuadMesh.new()  # real size: a sub-pixel draw may skip the pipeline
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
	# Drawn for a few frames, then hidden; the materials stay in _kept.
	var tw := root.create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(root.hide)


static func _build(sig: Dictionary) -> Material:
	var mat: Material = ClassDB.instantiate(sig.get("class", ""))
	if mat == null:
		return null
	for key: String in sig:
		if key == "class":
			continue
		var v: Variant = sig[key]
		if v is String:  # a texture slot that was set: any texture of that type
			mat.set(key, _texture(v))
		else:
			mat.set(key, v)
	return mat


static func _texture(type: String) -> Texture:
	if ClassDB.can_instantiate(type) and type not in ["Texture2D", "Texture"]:
		var t: Variant = ClassDB.instantiate(type)
		if t is Texture:
			return t
	return ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))


# --- Collecting (dev runs: `--collect-shaders`) ---------------------------------

## Note every generated-shader material under `root` (call once a frame or so).
static func scan(root: Node) -> void:
	for n: Node in root.find_children("*", "", true, false):
		if n is GeometryInstance3D:
			_note(n.material_override)
			_note(n.material_overlay)
			if n is MeshInstance3D and n.mesh != null:
				for i in n.mesh.get_surface_count():
					_note(n.get_surface_override_material(i))
					_note(n.mesh.surface_get_material(i))
			if n is GPUParticles3D:
				_note(n.process_material)
				for i in n.draw_passes:
					var m: Mesh = n.get_draw_pass_mesh(i)
					if m != null:
						for s in m.get_surface_count():
							_note(m.surface_get_material(s))


static func _note(mat: Material) -> void:
	while mat != null:
		var sig := signature(mat)
		if not sig.is_empty():
			var key := var_to_str(sig)
			if not _known.has(key):
				_known[key] = true
				_new.append(sig)
		mat = mat.next_pass


## Merge this run's new signatures into warmup_shaders.gd (dev checkouts only).
static func save() -> void:
	if _new.is_empty():
		return
	var list: Array = load(LIST_PATH).LIST.duplicate()
	list.append_array(_new)
	var out := "extends RefCounted\n## Generated by warmup.gd (`--collect-shaders`): one entry per built-in\n## material shader the game uses. Edit by rerunning the collection.\n\nconst LIST := [\n"
	for sig: Dictionary in list:
		out += "\t%s,\n" % var_to_str(sig).replace("\n", " ")
	out += "]\n"
	var f := FileAccess.open(ProjectSettings.globalize_path(LIST_PATH), FileAccess.WRITE)
	f.store_string(out)
	f.close()
	print("[shaders] saved %d new, %d total" % [_new.size(), list.size()])
	_new.clear()
