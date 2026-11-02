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
	"P_Coat": {"shadow": Color(0.03, 0.03, 0.22), "mid": Color(0.1, 0.13, 0.58), "light": Color(0.22, 0.3, 0.9), "hi": Color(0.52, 0.62, 1), "rim": Color(0.2, 0.16, 0.6), "brush": 0.16},
	"P_Hat": {"shadow": Color(0.05, 0.02, 0.24), "mid": Color(0.2, 0.11, 0.66), "light": Color(0.36, 0.24, 0.95), "hi": Color(0.66, 0.52, 1), "rim": Color(0.32, 0.14, 0.62), "brush": 0.18},
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
}
## Used (with a warning) for a material the tables don't know yet.
const FALLBACK_TONE := "P_Trousers"
const INK := Color(0.012, 0.01, 0.02)

static var _mats := {}  # material name -> shared ShaderMaterial, so every enemy batches
static var _warned := {}


## The shared comic material for a GLB material name.
static func material(mat_name: String) -> ShaderMaterial:
	if _mats.has(mat_name):
		return _mats[mat_name]
	var m := ShaderMaterial.new()
	if EMITS.has(mat_name):
		var c: Array = EMITS[mat_name]
		m.shader = load(EMIT_SHADER)
		m.set_shader_parameter("low_color", c[0])
		m.set_shader_parameter("mid_color", (c[0] as Color).lerp(c[1], 0.55))
		m.set_shader_parameter("high_color", c[1])
	else:
		if not TONES.has(mat_name) and not _warned.has(mat_name):
			_warned[mat_name] = true
			push_warning("ComicLook: no tones for material %s" % mat_name)
		var t: Dictionary = TONES.get(mat_name, TONES[FALLBACK_TONE])
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
	_mats[mat_name] = m
	return m


## Swap every surface under `root` to its comic material. Call before Fx.outline,
## which adds the ink hull to whatever is active.
static func apply(root: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return  # like Fx.outline: the dummy renderer errors on shared override materials at exit
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src != null:
				mi.set_surface_override_material(i, material(src.resource_name))


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


## Drop cached materials so nothing is left alive at exit.
static func release() -> void:
	_mats.clear()
