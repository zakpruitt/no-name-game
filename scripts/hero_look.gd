extends RefCounted
## The shaman's look on top of the KayKit Barbarian: the recoloured texture
## (tools/gen_shaman_texture.gd), feathers on the pelt hood, a bead-and-fang
## necklace, and runes that shimmer on the axes. Positions are in the bone's
## space; tune them with tests/hero_preview.gd.

const TEXTURE := preload("res://assets/hero/shaman_texture.png")
const RUNE_COLOR := Color(0.35, 0.95, 0.85)  # axe runes at rest (Awakening recolours the whole body)
const RUNE_INTENSITY := 1.2
const AXES := ["1H_Axe", "1H_Axe_Offhand"]
const FEATHER_COLOR := Color(0.12, 0.55, 0.55)
const FEATHER_TIP := Color(0.95, 0.93, 0.88)
const BEAD_COLORS := [Color(0.92, 0.88, 0.78), Color(0.25, 0.78, 0.72)]  # bone, turquoise
# [bone, position, rotation (degrees)] for each feather
const FEATHERS := [
	["head", Vector3(0.52, 0.42, -0.12), Vector3(15, 0, -150)],
	["head", Vector3(0.56, 0.5, -0.02), Vector3(5, 0, -165)],
	["head", Vector3(-0.52, 0.42, -0.12), Vector3(15, 0, 150)],
]
const NECKLACE_BONE := "chest"
const NECKLACE_CENTER := Vector3(0.0, 0.3, 0.33)
const NECKLACE_RADIUS := 0.26
const NECKLACE_BEADS := 9

static var _retextured := {}  # source material -> copy with the shaman texture


## Retexture `model` (a Barbarian.glb instance) and add the axe runes. Call before Fx.outline.
static func dress(model: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return  # like Fx.outline: the dummy renderer errors on shared override materials at exit
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			if src is BaseMaterial3D:
				if not _retextured.has(src):
					var copy: BaseMaterial3D = src.duplicate()
					copy.albedo_texture = TEXTURE
					_retextured[src] = copy
				mi.set_surface_override_material(i, _retextured[src])
		if mi.name in AXES:
			var rune: ShaderMaterial = Fx.rim_material().duplicate()
			rune.set_shader_parameter("glow_color", RUNE_COLOR)
			rune.set_shader_parameter("intensity", RUNE_INTENSITY)
			mi.set_meta("rest_overlay", rune)
			mi.material_overlay = rune


## Feathers and necklace. Call after Fx.outline (outlining them leaks their
## one-off materials at exit, and they're too small to need it).
static func add_kit(model: Node3D) -> void:
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	for f: Array in FEATHERS:
		_attach(skel, f[0], _feather(), f[1], f[2])
	var beads := Node3D.new()
	for i in NECKLACE_BEADS:
		var t := float(i) / (NECKLACE_BEADS - 1)
		var ang := lerpf(-1.1, 1.1, t)
		var fang := i == NECKLACE_BEADS / 2
		var b := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.045 if not fang else 0.04
		s.height = s.radius * (2.0 if not fang else 4.5)
		b.mesh = s
		b.material_override = _mat(BEAD_COLORS[0] if fang or i % 2 == 0 else BEAD_COLORS[1])
		b.position = Vector3(sin(ang) * NECKLACE_RADIUS, -absf(sin(ang)) * 0.06 - (0.06 if fang else 0.0), cos(ang) * NECKLACE_RADIUS * 0.6)
		beads.add_child(b)
	_attach(skel, NECKLACE_BONE, beads, NECKLACE_CENTER, Vector3.ZERO)


## Drop cached materials so nothing is left alive at exit (Game._exit_tree).
static func release() -> void:
	_retextured.clear()


static func _feather() -> Node3D:
	var f := Node3D.new()
	var vane := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	vane.mesh = s
	vane.scale = Vector3(0.11, 0.42, 0.025)
	vane.position.y = 0.2
	vane.material_override = _mat(FEATHER_COLOR)
	f.add_child(vane)
	var tip := MeshInstance3D.new()
	tip.mesh = s
	tip.scale = Vector3(0.08, 0.12, 0.03)
	tip.position.y = 0.38
	tip.material_override = _mat(FEATHER_TIP)
	f.add_child(tip)
	return f


static func _attach(skel: Skeleton3D, bone: String, node: Node3D, pos: Vector3, rot_deg: Vector3) -> void:
	var at := BoneAttachment3D.new()
	at.bone_name = bone
	skel.add_child(at)
	node.position = pos
	node.rotation_degrees = rot_deg
	at.add_child(node)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m
