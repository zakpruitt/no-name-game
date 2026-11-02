class_name ComicLook
extends RefCounted
## The comic-book look (Game.comic_style): palette, model swap, clip names and
## lighting. See docs/features/comic-style.md. The tones are copied from
## vendor_src/shaman_redesign/comic_poc (comic_lib.shared_materials + each
## enemy_*.py's extras), keyed by the material names the GLBs carry.

const TOON_SHADER := "res://shaders/comic_toon.gdshader"
const EMIT_SHADER := "res://shaders/comic_emit.gdshader"
const MODEL_PATH := "res://assets/comic/%s.glb"

## Material name -> toon tones (comic_lib.toon's arguments, sRGB). Optional keys:
## hi (else = light), rim (else black), spot (0.075), inner (0.17).
const TONES := {
	"P_Skin": {"shadow": Color(0.36, 0.1, 0.14), "mid": Color(0.86, 0.46, 0.28), "light": Color(1, 0.75, 0.5), "hi": Color(1, 0.92, 0.74), "rim": Color(0.55, 0.26, 0.2), "brush": 0.1},
	"P_Socket": {"shadow": Color(0.012, 0.01, 0.02), "mid": Color(0.1, 0.03, 0.05), "light": Color(0.18, 0.06, 0.07), "brush": 0.05, "inner": 0.0},
	"P_Hair": {"shadow": Color(0.2, 0.24, 0.5), "mid": Color(0.62, 0.68, 0.86), "light": Color(0.95, 0.95, 0.92), "hi": Color(1, 1, 0.98), "rim": Color(0.25, 0.35, 0.6), "brush": 0.2, "inner": 0.2},
	"P_Iron": {"shadow": Color(0.05, 0.06, 0.14), "mid": Color(0.2, 0.25, 0.38), "light": Color(0.46, 0.54, 0.68), "hi": Color(0.86, 0.92, 1), "rim": Color(0.18, 0.3, 0.5), "brush": 0.16, "inner": 0.2},
	"P_Bronze": {"shadow": Color(0.2, 0.06, 0.02), "mid": Color(0.68, 0.34, 0.08), "light": Color(0.98, 0.68, 0.18), "hi": Color(1, 0.95, 0.56), "rim": Color(0.3, 0.16, 0.05), "brush": 0.14},
	"P_Leather": {"shadow": Color(0.1, 0.03, 0.03), "mid": Color(0.34, 0.14, 0.08), "light": Color(0.6, 0.32, 0.15), "rim": Color(0.15, 0.07, 0.04), "brush": 0.2},
	"P_Cloth": {"shadow": Color(0.02, 0.08, 0.16), "mid": Color(0.03, 0.32, 0.36), "light": Color(0.08, 0.6, 0.56), "hi": Color(0.34, 0.86, 0.72), "rim": Color(0.05, 0.24, 0.24), "brush": 0.28},
	"P_Trousers": {"shadow": Color(0.06, 0.05, 0.13), "mid": Color(0.2, 0.17, 0.32), "light": Color(0.42, 0.36, 0.5), "rim": Color(0.1, 0.1, 0.2), "brush": 0.24},
	"P_Rock": {"shadow": Color(0.05, 0.02, 0.05), "mid": Color(0.2, 0.12, 0.16), "light": Color(0.42, 0.28, 0.28), "hi": Color(0.72, 0.55, 0.44), "rim": Color(0.8, 0.28, 0.03), "brush": 0.14, "inner": 0.22},
	"P_Bone": {"shadow": Color(0.36, 0.17, 0.1), "mid": Color(0.8, 0.6, 0.36), "light": Color(0.98, 0.92, 0.72), "rim": Color(0.2, 0.15, 0.1), "brush": 0.14},
	"P_Ice": {"shadow": Color(0.08, 0.3, 0.72), "mid": Color(0.26, 0.62, 0.96), "light": Color(0.6, 0.9, 1), "hi": Color(0.98, 1, 1), "rim": Color(0.4, 0.7, 1), "brush": 0.08, "inner": 0.14},
	"P_Teeth": {"shadow": Color(0.4, 0.28, 0.16), "mid": Color(0.8, 0.7, 0.44), "light": Color(0.96, 0.9, 0.68), "brush": 0.08, "inner": 0.0},
	"P_Black": {"shadow": Color(0.012, 0.01, 0.02), "mid": Color(0.03, 0.02, 0.03), "light": Color(0.06, 0.05, 0.06), "brush": 0.05, "inner": 0.0},
	"P_Floor": {"shadow": Color(0.03, 0.03, 0.07), "mid": Color(0.09, 0.09, 0.16), "light": Color(0.17, 0.165, 0.26), "brush": 0.1, "inner": 0.0, "spot": 0.02},
	# enemy_*.py extras
	"P_Rust": {"shadow": Color(0.14, 0.04, 0.03), "mid": Color(0.55, 0.24, 0.09), "light": Color(0.8, 0.45, 0.2), "hi": Color(1, 0.82, 0.55), "rim": Color(0.3, 0.12, 0.04), "brush": 0.3},
	"P_Wood": {"shadow": Color(0.15, 0.06, 0.06), "mid": Color(0.42, 0.23, 0.13), "light": Color(0.72, 0.47, 0.25), "hi": Color(0.95, 0.74, 0.44), "rim": Color(0.22, 0.1, 0.05), "brush": 0.32, "inner": 0.1},
	"P_Bomb": {"shadow": Color(0.02, 0.02, 0.05), "mid": Color(0.065, 0.065, 0.115), "light": Color(0.14, 0.145, 0.23), "hi": Color(0.34, 0.37, 0.52), "rim": Color(0.75, 0.24, 0.05), "brush": 0.12, "inner": 0.12},
	"P_Shroud": {"shadow": Color(0.08, 0.015, 0.06), "mid": Color(0.32, 0.05, 0.11), "light": Color(0.58, 0.12, 0.16), "hi": Color(0.84, 0.3, 0.24), "rim": Color(0.3, 0.05, 0.1), "brush": 0.16},
	"P_WardenIron": {"shadow": Color(0.04, 0.05, 0.11), "mid": Color(0.16, 0.19, 0.3), "light": Color(0.36, 0.42, 0.56), "hi": Color(0.72, 0.8, 0.92), "rim": Color(0.14, 0.24, 0.4), "brush": 0.16, "inner": 0.2},
	"P_Edge": {"shadow": Color(0.2, 0.24, 0.34), "mid": Color(0.55, 0.62, 0.72), "light": Color(0.9, 0.95, 1), "hi": Color(1, 1, 1), "rim": Color(0.3, 0.4, 0.5), "brush": 0.1, "inner": 0.1},
	"P_IronPlain": {"shadow": Color(0.05, 0.06, 0.14), "mid": Color(0.2, 0.25, 0.38), "light": Color(0.46, 0.54, 0.68), "hi": Color(0.86, 0.92, 1), "rim": Color(0.18, 0.3, 0.5), "brush": 0.16, "inner": 0.2},
	"P_Steel": {"shadow": Color(0.08, 0.1, 0.2), "mid": Color(0.3, 0.36, 0.5), "light": Color(0.56, 0.64, 0.76), "hi": Color(0.8, 0.86, 0.92), "rim": Color(0.26, 0.36, 0.5), "brush": 0.16, "inner": 0.1},
	"P_Coat": {"shadow": Color(0.05, 0.06, 0.36), "mid": Color(0.1, 0.15, 0.62), "light": Color(0.22, 0.32, 0.92), "hi": Color(0.52, 0.64, 1), "rim": Color(0.2, 0.16, 0.6), "brush": 0.16, "spot": 0.02},
	"P_Hat": {"shadow": Color(0.1, 0.05, 0.4), "mid": Color(0.2, 0.11, 0.68), "light": Color(0.36, 0.24, 0.95), "hi": Color(0.66, 0.52, 1), "rim": Color(0.32, 0.14, 0.62), "brush": 0.18, "spot": 0.02},
	"P_Wrap": {"shadow": Color(0.1, 0.02, 0.14), "mid": Color(0.32, 0.07, 0.28), "light": Color(0.58, 0.16, 0.4), "hi": Color(0.8, 0.34, 0.52), "rim": Color(0.26, 0.08, 0.24), "brush": 0.26, "inner": 0.14},
	"P_Forest": {"shadow": Color(0.03, 0.16, 0.1), "mid": Color(0.07, 0.36, 0.16), "light": Color(0.17, 0.6, 0.22), "hi": Color(0.48, 0.86, 0.38), "rim": Color(0.1, 0.3, 0.12), "brush": 0.2, "spot": 0.02},
	"P_Lining": {"shadow": Color(0.08, 0.01, 0.14), "mid": Color(0.28, 0.05, 0.34), "light": Color(0.5, 0.12, 0.5), "rim": Color(0.2, 0.05, 0.2), "brush": 0.2},
}
## Material name -> flat stepped colour [low, high] (comic_lib.emit, sRGB).
const EMITS := {
	"P_Fire": [Color(0.95, 0.1, 0.02), Color(1, 0.9, 0.2)],
	"P_Lava": [Color(1, 0.28, 0.02), Color(1, 0.86, 0.2)],
	"P_Bolt": [Color(0.2, 0.55, 1), Color(0.98, 1, 0.92)],
	"P_Wind": [Color(0.2, 0.85, 0.5), Color(0.9, 1, 0.8)],
	"P_Spirit": [Color(0.05, 0.75, 0.72), Color(0.86, 1, 0.86)],
	"P_EyeWhite": [Color(0.965, 0.93, 0.82), Color(0.965, 0.93, 0.82)],
	"P_EyeBlue": [Color(0.1, 0.45, 1), Color(0.7, 0.95, 1)],
	"P_Pupil": [Color(0.012, 0.01, 0.02), Color(0.012, 0.01, 0.02)],
	"P_Necro": [Color(0.2, 0.85, 0.3), Color(0.9, 1, 0.55)],
	"P_Hot": [Color(1, 0.72, 0.12), Color(1, 1, 0.78)],
	"P_Arcane": [Color(0.55, 0.16, 1), Color(0.96, 0.86, 1)],
	"P_Ember": [Color(1, 0.42, 0.05), Color(1, 0.93, 0.55)],
	# comic_lib.flat: one colour
	"P_String": [Color(0.96, 0.92, 0.74), Color(0.96, 0.92, 0.74)],
	"P_Under": [Color(0.13, 0.05, 0.3), Color(0.13, 0.05, 0.3)],
}
## A kind whose script defines a shared material name differently.
const KIND_TONES := {
	"rogue": {"P_Steel": {"shadow": Color(0.08, 0.1, 0.2), "mid": Color(0.32, 0.38, 0.52), "light": Color(0.62, 0.7, 0.82), "hi": Color(0.88, 0.93, 1), "rim": Color(0.26, 0.36, 0.5), "brush": 0.12, "inner": 0.08}},
}
## Model name -> clip the game asks for -> clip it has ("" = keep what's playing,
## the clip already covers that beat). Only consulted when the model lacks the clip
## asked for, so a re-export that adds one wins by itself.
const CLIPS := {
	"necromancer": {"Running_A": "Walking_D_Skeletons", "Spawn_Ground_Skeletons": "Idle_Combat"},
	"warden": {
		"Spawn_Ground_Skeletons": "Idle_Combat",
		"Hit_B": "Hit_A",
		"Lie_StandUp": "Idle_Combat",
		# boss.gd's beats inside Attack_Slam / Attack_Nova / Attack_Cage
		"Jump_Idle": "",
		"Jump_Land": "",
		"Spellcast_Shoot": "",
	},
}
## Model name -> scale on its rig node. enemy.gd's model_scale also sizes collision, so
## it stays as tuned; the Warden is modelled at full size (3.2 m) where the KayKit boss
## relied on model_scale 1.8. The others match KayKit's height (~2.2 m bounds) as built.
const RIG_SCALE := {"warden": 1.0 / 1.8}
## Used (with a warning) for a material the tables don't know yet.
const FALLBACK_TONE := "P_Trousers"
const INK := Color(0.012, 0.01, 0.02)

# comic_lib.comic_scene, converted: Blender energy / PI (a sun of strength E gives
# E / PI radiance), directions from its Euler angles, Blender (x, y, z) -> Godot
# (x, z, -y), so shadows fall up and right on screen as in the renders.
const BACKGROUND := Color(0.05, 0.05, 0.1)
const AMBIENT := Color(0.3, 0.3, 0.5)
const AMBIENT_ENERGY := 0.5
const KEY_DIR := Vector3(0.291, -0.754, -0.589)
const KEY_ENERGY := 1.146
const KEY_COLOR := Color(1.0, 0.97, 0.9)  # linear, as Blender's
const FILL_DIR := Vector3(-0.476, -0.309, 0.824)
const FILL_ENERGY := 0.134
const FILL_COLOR := Color(0.55, 0.62, 1.0)  # linear

static var _mats := {}  # material name -> shared ShaderMaterial, so every enemy batches
static var _warned := {}
static var _scenes := {}


## The comic model for `kind`, or null (flag off, or no GLB yet: caller keeps KayKit).
static func scene(kind: String) -> PackedScene:
	if not Game.comic_style:
		return null
	if not _scenes.has(kind):
		var path := MODEL_PATH % kind
		_scenes[kind] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[kind]


## The clip to play on this model for a clip name the game asks for.
static func clip(player: AnimationPlayer, kind: String, wanted: String) -> String:
	if player.has_animation(wanted):
		return wanted
	return CLIPS.get(kind, {}).get(wanted, wanted)


## Scale the rig under the model's root (the root belongs to model_scale and _squash).
static func fit(model: Node3D, kind: String) -> void:
	if RIG_SCALE.has(kind):
		for child in model.get_children():
			if child is Node3D:
				child.scale *= RIG_SCALE[kind]


## The shared comic material for a GLB material name.
static func material(mat_name: String, kind := "") -> ShaderMaterial:
	var override: Dictionary = KIND_TONES.get(kind, {})
	var key := kind + "/" + mat_name if override.has(mat_name) else mat_name
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	if EMITS.has(mat_name):
		var c: Array = EMITS[mat_name]
		m.shader = load(EMIT_SHADER)
		m.set_shader_parameter("low_color", c[0])
		m.set_shader_parameter("mid_color", (c[0] as Color).lerp(c[1], 0.55))
		m.set_shader_parameter("high_color", c[1])
	else:
		if not known_material(mat_name) and not _warned.has(mat_name):
			_warned[mat_name] = true
			push_warning("ComicLook: no tones for material %s" % mat_name)
		var t: Dictionary = override.get(mat_name, TONES.get(mat_name, TONES[FALLBACK_TONE]))
		m.shader = load(TOON_SHADER)
		m.set_shader_parameter("ink_color", INK)
		m.set_shader_parameter("shadow_color", t.shadow)
		m.set_shader_parameter("mid_color", t.mid)
		m.set_shader_parameter("light_color", t.light)
		m.set_shader_parameter("hi_color", t.get("hi", t.light))
		m.set_shader_parameter("rim_color", t.get("rim", Color.BLACK))
		m.set_shader_parameter("brush", t.brush)
		m.set_shader_parameter("spot", t.get("spot", 0.075))
		m.set_shader_parameter("inner", t.get("inner", 0.17))
	_mats[key] = m
	return m


## Swap every surface under `root` to its comic material. Call before Fx.outline,
## which adds the ink hull to whatever is active.
static func apply(root: Node, kind := "") -> void:
	if DisplayServer.get_name() == "headless":
		return  # like Fx.outline: the dummy renderer errors on shared override materials at exit
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src != null:
				mi.set_surface_override_material(i, material(src.resource_name, kind))


## Every GLB material name under `root` (imported names, works headless).
static func material_names(root: Node) -> Array:
	var names := []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src != null and src.resource_name not in names:
				names.append(src.resource_name)
	return names


static func known_material(mat_name: String) -> bool:
	return TONES.has(mat_name) or EMITS.has(mat_name)


## comic_lib.comic_scene: flat dark indigo, untonemapped, one hard sun with real
## cast shadows and a weak blue fill. No glow: glow is drawn, not lit. Toon materials
## ignore the ambient; it's only there so KayKit pieces under the flag stay readable.
static func build_environment(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.ssao_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	var key := DirectionalLight3D.new()
	key.basis = Basis.looking_at(KEY_DIR, Vector3.UP)
	key.light_energy = KEY_ENERGY
	key.light_color = KEY_COLOR.linear_to_srgb()
	key.shadow_enabled = true
	key.shadow_blur = 0.0
	key.directional_shadow_max_distance = 60.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.basis = Basis.looking_at(FILL_DIR, Vector3.UP)
	fill.light_energy = FILL_ENERGY
	fill.light_color = FILL_COLOR.linear_to_srgb()
	parent.add_child(fill)


## Undo build_environment's global shadow filter when the flag goes off.
static func restore_shadows() -> void:
	var path := "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
	RenderingServer.directional_soft_shadow_filter_set_quality(ProjectSettings.get_setting(path))


## Drop cached materials so nothing is left alive at exit.
static func release() -> void:
	_mats.clear()
	_scenes.clear()
