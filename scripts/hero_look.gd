extends RefCounted
## The shaman's look on top of the KayKit Barbarian: the recoloured texture
## (tools/gen_shaman_texture.gd), the bear hood swapped for a swept mohawk,
## braid and headband with feathers, a bead-and-fang necklace, element-coated
## axes (coat_axes) and runes that shimmer on them. Positions are in the
## bone's space (head bone at the neck: the bald head spans y 0..0.95,
## x +-0.54, front +Z). Tune with tests/hero_preview.gd, or windowless with
## tests/hero_dump.gd + tools/render_hero.py.

const TEXTURE := preload("res://assets/hero/shaman_texture.png")
const RUNE_COLOR := Color(0.35, 0.95, 0.85)  # axe runes at rest (Awakening recolours the whole body)
const RUNE_INTENSITY := 1.2
const AXES := ["1H_Axe", "1H_Axe_Offhand"]
const FEATHER_COLOR := Color(0.12, 0.55, 0.55)
const FEATHER_TIP := Color(0.95, 0.93, 0.88)
const BEAD_COLORS := [Color(0.92, 0.88, 0.78), Color(0.25, 0.78, 0.72)]  # bone, turquoise
# [bone, position, rotation (degrees)] for each feather: tucked into the headband
const FEATHERS := [
	["head", Vector3(0.5, 0.68, -0.12), Vector3(-30, 0, -40)],
	["head", Vector3(0.53, 0.64, -0.02), Vector3(-15, 0, -60)],
	["head", Vector3(-0.5, 0.68, -0.12), Vector3(-30, 0, 40)],
]
const HAIR_COLOR := Color(0.16, 0.1, 0.08)
const EYE_POS := Vector3(0.17, 0.46, 0.5)  # head-local, the +x eye (mirrored for the other)
# Mantle (replaces the bear-pelt cape): ragged cloth panels hanging from the
# chest bone behind the back, alternating two colours, a feather fringe on top.
const MANTLE_COLORS := [Color(0.12, 0.5, 0.5), Color(0.3, 0.2, 0.14)]  # teal cloth, leather
const MANTLE_TOP := 0.26  # chest-local height where the old cape hung from
const MANTLE_PANELS := [  # [x centre, width, length]
	[-0.36, 0.22, 0.8], [-0.18, 0.22, 0.98], [0.0, 0.24, 1.08], [0.18, 0.22, 0.98], [0.36, 0.22, 0.8],
]
const BAND_COLOR := Color(0.12, 0.5, 0.5)
const BAND_Y := 0.66  # head-local height of the headband (just above the brows)
const BAND_RADIUS := Vector2(0.53, 0.5)  # x, z
# Axe coat per element: shell colour (alpha = see-through), and the extra pieces.
const COATS := {
	"spirit": {"shell": Color(0.3, 0.95, 0.85, 0.35), "glow": Color(0.3, 0.95, 0.85)},
	"wind": {"shell": Color(0.55, 1.0, 0.6, 0.35), "glow": Color(0.55, 1.0, 0.6)},
	"earth": {"shell": Color(0.16, 0.12, 0.11, 0.92), "glow": Color(1.0, 0.38, 0.08)},
	"water": {"shell": Color(0.6, 0.88, 1.0, 0.5), "glow": Color(0.75, 0.95, 1.0)},
}
# Axe-local blade: handle along +Y, the head between y 0.3 and 0.9 sticking out to -X.
const BLADE_CENTER := Vector3(-0.3, 0.62, 0.0)
const DRIP_AMOUNT := 5  # motes a coated blade sheds at rest (x3 Awakened)
const BLADE_EDGE := [Vector3(-0.5, 0.38, 0.0), Vector3(-0.58, 0.62, 0.0), Vector3(-0.52, 0.84, 0.0)]
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


## Hair, headband, feathers and necklace. Call after Fx.outline (outlining them
## leaks their one-off materials at exit, and they're too small to need it).
static func add_kit(model: Node3D) -> void:
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	_attach(skel, "head", _hair(), Vector3.ZERO, Vector3.ZERO)
	_attach(skel, "head", _headband(), Vector3(0, BAND_Y, 0), Vector3.ZERO)
	_attach(skel, "chest", _mantle(), Vector3.ZERO, Vector3.ZERO)
	_attach(skel, "head", _eyes(), Vector3.ZERO, Vector3.ZERO)
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


## Ascendancy forms: low-poly, flat-shaded gear the hero grows on ascending
## (player.ascend). Positions are in each bone's space (head bone at the neck:
## the head mesh spans y 0..0.95, x +-0.54, front +Z). Tune with tests/hero_preview.gd.
const FORMS := {
	"wind": {  # Tempest: a swept storm crest and feather mantles, white into green
		"main": Color(0.93, 0.97, 0.94), "accent": Color(0.3, 0.85, 0.5), "glow": Color(0.55, 1.0, 0.6),
		"cloth": [Color(0.85, 0.95, 0.88), Color(0.2, 0.6, 0.35)],
	},
	"earth": {  # Magma: obsidian pauldrons and horns split by glowing lava
		"main": Color(0.2, 0.17, 0.16), "accent": Color(0.4, 0.3, 0.25), "glow": Color(1.0, 0.38, 0.08),
		"cloth": [Color(0.55, 0.12, 0.06), Color(0.16, 0.13, 0.12)],
	},
	"water": {  # Tide: an ice crown and frozen shards on the shoulders
		"main": Color(0.55, 0.85, 1.0), "accent": Color(0.2, 0.45, 0.85), "glow": Color(0.6, 0.92, 1.0),
		"cloth": [Color(0.15, 0.3, 0.65), Color(0.6, 0.82, 0.95)],
	},
}


## Attach the Ascendancy `path`'s gear to `model`; returns its root (free it to remove).
static func add_form(model: Node3D, path: String) -> Node3D:
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var form := Node3D.new()
	form.name = "AscendForm"
	skel.add_child(form)
	var f: Dictionary = FORMS[path]
	var hair := model.find_child("ShamanHair", true, false)
	if hair != null:
		hair.visible = path != "wind"  # the storm crest takes the mohawk's place
	var mantle := model.find_child("ShamanMantle", true, false)
	if mantle != null:  # the cloth takes the Ascendancy's colours
		for mi: MeshInstance3D in mantle.get_children().filter(func(n: Node) -> bool: return n.has_meta("cloth")):
			var cm: StandardMaterial3D = mi.material_override.duplicate()
			cm.albedo_color = f.cloth[mi.get_meta("cloth")]
			mi.material_override = cm
	var main := _mat(f.main)
	var accent := _mat(f.accent)
	var glow := _glow_mat(f.glow)
	match path:
		"wind":
			# Crest: five long feathers fanned up and back over the head, swaying.
			for i in 5:
				var t := (i - 2) / 2.0
				var blade := _feather_blade(0.9 - absf(t) * 0.25, main, accent)
				_part(form, skel, "head", blade, Vector3(t * 0.22, 0.85, -0.15), Vector3(-35 - absf(t) * 10, 0, -t * 30))
				_sway(form, blade, 6.0, 0.9 + i * 0.07)
			# Mantles: a fan of three feathers off each shoulder, sweeping back.
			for side: int in [-1, 1]:
				for i in 3:
					_part(form, skel, "chest", _feather_blade(0.7 - i * 0.12, main, accent),
						Vector3(side * (0.32 + i * 0.05), 0.2 - i * 0.04, -0.2),
						Vector3(-60 + i * 12, side * (20 + i * 15), side * -(70 - i * 15)))
			# Storm gem at the brow.
			_part(form, skel, "head", _flat(_prism(0.09, 0.2, 4)), Vector3(0, 0.62, 0.52), Vector3(80, 0, 0), glow)
		"earth":
			for side: int in [-1, 1]:
				# Pauldron: a squat obsidian block with a lava seam and a spike.
				var bone := "upperarm.l" if side > 0 else "upperarm.r"
				_part(form, skel, bone, _flat(_rock(0.3, 0.22, 6)), Vector3(0, 0.06, 0), Vector3.ZERO, main)
				_part(form, skel, bone, _flat(_rock(0.24, 0.05, 6)), Vector3(0, 0.06, 0), Vector3.ZERO, glow)
				_part(form, skel, bone, _flat(_prism(0.1, 0.32, 5)), Vector3(0.02, 0.05, 0.22), Vector3.ZERO, accent)
				# Horns: two segments curling up and out from the temples.
				_part(form, skel, "head", _flat(_prism(0.13, 0.42, 5)), Vector3(side * 0.42, 0.7, 0.05), Vector3(0, 0, side * -50), main)
				_part(form, skel, "head", _flat(_prism(0.08, 0.3, 5)), Vector3(side * 0.66, 0.98, 0.05), Vector3(0, 0, side * -15), main)
			# Magma crystals jutting from the back.
			for i in 3:
				var t := i - 1
				_part(form, skel, "chest", _flat(_prism(0.1 - absf(t) * 0.02, 0.55 - absf(t) * 0.15, 5)),
					Vector3(t * 0.17, 0.2, -0.38), Vector3(-30, 0, t * -25), glow)
		"water":
			# Crown: a ring of ice spikes, tallest at the front.
			for i in 7:
				var ang := lerpf(-1.3, 1.3, i / 6.0)
				var h := 0.42 - absf(ang) * 0.12
				_part(form, skel, "head", _flat(_prism(0.08, h, 4)),
					Vector3(sin(ang) * 0.4, 0.86, cos(ang) * 0.25), Vector3(cos(ang) * -15, 0, sin(ang) * -25), main)
			for side: int in [-1, 1]:
				# Shards: two ice spikes per shoulder, pointing out and up.
				var bone := "upperarm.l" if side > 0 else "upperarm.r"
				_part(form, skel, bone, _flat(_prism(0.1, 0.45, 4)), Vector3(0.05, 0.12, -0.02), Vector3(0, 0, 20), main)
				_part(form, skel, bone, _flat(_prism(0.07, 0.3, 4)), Vector3(-0.08, 0.1, -0.1), Vector3(-25, 0, 35), accent)
			# Tide gem at the brow.
			_part(form, skel, "head", _flat(_prism(0.09, 0.2, 4)), Vector3(0, 0.62, 0.52), Vector3(80, 0, 0), glow)
	# The glowing pieces breathe; charge_form() makes them burn harder while Awakened.
	form.set_meta("charged", false)
	var pulse := form.create_tween().set_loops()
	var glow_at := func(t: float) -> void:
		glow.emission_energy_multiplier = (1.1 + 1.3 * t) * (2.2 if form.get_meta("charged") else 1.0)
	pulse.tween_method(glow_at, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_method(glow_at, 1.0, 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	return form


## Awakened: the form's glowing pieces burn harder (see the pulse in add_form).
static func charge_form(form: Node, on: bool) -> void:
	if form != null and is_instance_valid(form):
		form.set_meta("charged", on)


## Gentle back-and-forth roll on `node` (degrees, seconds per swing), owned by `form`.
static func _sway(form: Node, node: Node3D, deg: float, period: float) -> void:
	var base := node.rotation_degrees.z
	var tw := form.create_tween().set_loops()
	tw.tween_property(node, "rotation_degrees:z", base + deg, period).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "rotation_degrees:z", base - deg, period * 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "rotation_degrees:z", base, period).set_trans(Tween.TRANS_SINE)


static func _part(form: Node3D, skel: Skeleton3D, bone: String, node: Node3D, pos: Vector3,
		rot_deg: Vector3, mat: Material = null) -> void:
	if node is MeshInstance3D and mat != null:
		(node as MeshInstance3D).material_override = mat
	var at := BoneAttachment3D.new()
	at.bone_name = bone
	skel.add_child(at)
	node.position = pos
	node.rotation_degrees = rot_deg
	at.add_child(node)
	# The attachment lives on the skeleton, so free it with the form.
	form.tree_exiting.connect(at.queue_free)


## A flat feather blade (stretched low-poly diamond): `main` vane, `accent` tip.
static func _feather_blade(length: float, main: Material, accent: Material) -> Node3D:
	var root := Node3D.new()
	var shape := _flat_mesh(_prism(0.5, 1.0, 4))
	var vane := MeshInstance3D.new()
	vane.mesh = shape
	vane.scale = Vector3(0.22, length * 0.75, 0.05)
	vane.material_override = main
	vane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(vane)
	var tip := MeshInstance3D.new()
	tip.mesh = shape
	tip.scale = Vector3(0.16, length * 0.3, 0.06)
	tip.position.y = length * 0.72
	tip.material_override = accent
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tip)
	return root


## Cone/spike pointing +Y: `sides` facets.
static func _prism(radius: float, height: float, sides: int) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


## Squat faceted dome (pauldron).
static func _rock(radius: float, height: float, sides: int) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = radius * 0.65
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


## Re-shade a primitive with one normal per triangle (faceted low-poly look),
## origin moved to the base so parts grow out of their anchor.
static func _flat(src: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _flat_mesh(src)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _flat_mesh(src: Mesh) -> ArrayMesh:
	var arrays: Array = src.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var lift := Vector3.UP * src.get_aabb().size.y * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]] + lift
		var b := verts[idx[t + 1]] + lift
		var c := verts[idx[t + 2]] + lift
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-10:
			continue  # degenerate triangles at the cone's tip
		n = n.normalized()
		for v: Vector3 in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()


static func _glow_mat(c: Color) -> StandardMaterial3D:
	var m := _mat(c)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.6
	return m


## Swept mohawk (five faceted blades front to back) and a braid down the back.
## Named "ShamanHair" so the Tempest crest can replace it.
static func _hair() -> Node3D:
	var hair := Node3D.new()
	hair.name = "ShamanHair"
	var mat := _mat(HAIR_COLOR)
	for i in 5:
		var t := i / 4.0  # 0 = front, 1 = back
		var ang := lerpf(0.55, -1.25, t)  # around the skull, front-top to back
		var blade := _flat(_prism(0.5, 1.0, 4))
		blade.material_override = mat
		blade.scale = Vector3(0.24, 0.42 - absf(t - 0.4) * 0.18, 0.3)
		blade.position = Vector3(0, 0.45 + cos(ang) * 0.48, sin(ang) * 0.48)
		blade.rotation = Vector3(-ang + 0.5 - t * 0.6, 0, 0)  # lean back as it goes over
		hair.add_child(blade)
	# Braid: three shrinking beads hanging behind the head.
	for i in 3:
		var bead := _flat(_rock(0.11 - i * 0.02, 0.16, 5))
		bead.material_override = mat
		bead.position = Vector3(0, 0.32 - i * 0.15, -0.5 - i * 0.03)
		hair.add_child(bead)
	var tie := _flat(_rock(0.07, 0.06, 5))
	tie.material_override = _mat(BEAD_COLORS[1])
	tie.position = Vector3(0, -0.05, -0.56)
	hair.add_child(tie)
	return hair


## Ragged cloth panels down the back (pointed hems, curving round the body)
## and a fringe of feathers along the top. Named "ShamanMantle"; add_form
## recolours its panels (meta "cloth" = 0/1 for the two alternating colours).
static func _mantle() -> Node3D:
	var mantle := Node3D.new()
	mantle.name = "ShamanMantle"
	var mats := [_mat(MANTLE_COLORS[0]), _mat(MANTLE_COLORS[1])]
	for m: StandardMaterial3D in mats:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED  # thin cloth: both sides
	for i in MANTLE_PANELS.size():
		var p: Array = MANTLE_PANELS[i]
		var mi := MeshInstance3D.new()
		mi.mesh = _panel(p[0], p[1], p[2])
		mi.material_override = mats[i % 2]
		mi.set_meta("cloth", i % 2)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mantle.add_child(mi)
	for i in 7:
		var x := lerpf(-0.42, 0.42, i / 6.0)
		var f := _feather()
		f.position = Vector3(x, MANTLE_TOP + 0.02, _mantle_z(x, 0.0) - 0.02)
		f.rotation_degrees = Vector3(-160, 0, x * 40.0)  # hanging down the back, fanned
		f.scale = Vector3.ONE * 0.75
		mantle.add_child(f)
	return mantle


## How far behind the chest bone the mantle sits at `x`, `t` (0 top .. 1 hem) down.
static func _mantle_z(x: float, t: float) -> float:
	var curve := 1.0 - pow(x / 0.55, 2.0)  # wraps round the body: centre furthest back
	return -0.2 - t * 0.2 - curve * 0.08


## One flat-shaded panel: a strip from MANTLE_TOP down `length`, hem cut to a point.
static func _panel(cx: float, width: float, length: float) -> ArrayMesh:
	var hw := width * 0.5
	var pts := [  # top-left, top-right, hem corners, point
		Vector2(cx - hw, 0.0), Vector2(cx + hw, 0.0),
		Vector2(cx + hw, length * 0.82), Vector2(cx, length), Vector2(cx - hw, length * 0.82),
	]
	var v3: Array[Vector3] = []
	for p: Vector2 in pts:
		var t := p.y / 1.1
		v3.append(Vector3(p.x * (1.0 + t * 0.15), MANTLE_TOP - p.y, _mantle_z(p.x, t)))  # flares out a little
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: Array in [[0, 1, 2], [0, 2, 4], [4, 2, 3]]:
		var a: Vector3 = v3[tri[0]]
		var b: Vector3 = v3[tri[1]]
		var c: Vector3 = v3[tri[2]]
		var n := (c - a).cross(b - a).normalized()
		for v: Vector3 in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()


## Glowing eye slits, shown only while Awakened (set_eyes). Named "AwakenEyes".
static func _eyes() -> Node3D:
	var eyes := Node3D.new()
	eyes.name = "AwakenEyes"
	eyes.visible = false
	var mat := _glow_mat(Color(1.0, 0.85, 0.4))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eyes.set_meta("mat", mat)
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 8
	s.rings = 4
	for side: int in [-1, 1]:
		var e := MeshInstance3D.new()
		e.mesh = s
		e.material_override = mat
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.position = EYE_POS * Vector3(side, 1, 1)
		e.rotation_degrees.z = side * -12.0  # slanted: fierce, not cute
		e.scale = Vector3(0.16, 0.08, 0.06)
		eyes.add_child(e)
	return eyes


## Awakened: the eyes light up in `color`.
static func set_eyes(model: Node3D, on: bool, color: Color) -> void:
	var eyes := model.find_child("AwakenEyes", true, false)
	if eyes == null:
		return
	eyes.visible = on
	var mat: StandardMaterial3D = eyes.get_meta("mat")
	mat.albedo_color = color.lerp(Color.WHITE, 0.4)
	mat.emission = color


## Cloth band round the head with two tails hanging at the back.
static func _headband() -> Node3D:
	var band := Node3D.new()
	var mat := _mat(BAND_COLOR)
	var ring := CylinderMesh.new()
	ring.top_radius = 1.0
	ring.bottom_radius = 1.0
	ring.height = 0.1
	ring.radial_segments = 10
	ring.rings = 1
	ring.cap_top = false
	ring.cap_bottom = false
	var mi := _flat(ring)
	mi.material_override = mat
	mi.position.y = -0.05
	mi.scale = Vector3(BAND_RADIUS.x, 1.0, BAND_RADIUS.y)
	band.add_child(mi)
	for side: int in [-1, 1]:
		var tail := _flat(_prism(0.5, 1.0, 4))
		tail.material_override = mat
		tail.scale = Vector3(0.1, 0.32, 0.03)
		tail.position = Vector3(side * 0.08, 0.0, -BAND_RADIUS.y - 0.02)
		tail.rotation_degrees = Vector3(160, 0, side * 15)  # pointing down and out
		band.add_child(tail)
	return band


## Element coat on both axes: a see-through shell in the element's colour plus
## a glowing gem through the blade and pieces (wind feathers at the grip,
## lava spikes, ice spikes). Returns the nodes so the caller can swap them (player.ascend).
static func coat_axes(model: Node3D, element: String) -> Array[Node3D]:
	var made: Array[Node3D] = []
	var c: Dictionary = COATS[element]
	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = c.shell
	shell_mat.roughness = 0.3
	if c.shell.a < 1.0:
		shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_mat.emission_enabled = element != "earth"
	shell_mat.emission = c.glow
	shell_mat.emission_energy_multiplier = 0.35
	var glow := _glow_mat(c.glow)
	for axe_name: String in AXES:
		var axe: MeshInstance3D = model.find_child(axe_name, true, false)
		if axe == null:
			continue
		var coat := Node3D.new()
		coat.name = "Coat"
		axe.add_child(coat)
		made.append(coat)
		var shell := MeshInstance3D.new()
		shell.mesh = axe.mesh
		shell.material_override = shell_mat
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var k := Vector3(1.1, 1.06, 1.7)  # grow about the blade; thin in z so swell it more
		shell.scale = k
		shell.position = BLADE_CENTER - BLADE_CENTER * k
		coat.add_child(shell)
		coat.set_meta("shell_mat", shell_mat)
		coat.set_meta("glow_mat", glow)
		var drip := _drip(element, c.glow)
		drip.position = BLADE_CENTER
		coat.add_child(drip)
		coat.set_meta("drip", drip)
		# A glowing gem through the blade (both faces) in the element's colour.
		var gem := _flat(_rock(0.08, 0.4, 4))  # longer than the shell is thick
		gem.material_override = glow
		gem.position = BLADE_CENTER + Vector3(0.02, 0.0, -0.2)
		gem.rotation_degrees = Vector3(90, 45, 0)
		coat.add_child(gem)
		match element:
			"wind":
				for i in 2:
					var f := _feather()
					f.position = Vector3(0.03 * (i * 2 - 1), 0.08, 0.05)
					f.rotation_degrees = Vector3(0, 0, 160 + i * 25)  # hanging off the grip
					f.scale = Vector3.ONE * 0.8
					coat.add_child(f)
			"earth":
				for i in BLADE_EDGE.size():
					var sp := _flat(_prism(0.06, 0.2 if i != 1 else 0.28, 5))
					sp.material_override = glow
					sp.position = BLADE_EDGE[i]
					sp.rotation_degrees = Vector3(0, 0, 90 + (i - 1) * 25)  # out of the edge
					coat.add_child(sp)
				var cap := _flat(_rock(0.09, 0.08, 5))
				cap.material_override = glow
				cap.position = Vector3(0, -0.32, 0)
				coat.add_child(cap)
			"water":
				for i in BLADE_EDGE.size():
					var sp := _flat(_prism(0.05, 0.22 if i != 1 else 0.32, 4))
					sp.material_override = shell_mat
					sp.position = BLADE_EDGE[i]
					sp.rotation_degrees = Vector3(0, 0, 80 + (i - 1) * 30)
					coat.add_child(sp)
				var top := _flat(_prism(0.06, 0.3, 4))
				top.material_override = shell_mat
				top.position = Vector3(0, 0.88, 0)
				coat.add_child(top)
	return made


## Motes shed by a coated blade, in world space so they trail the swing:
## embers rise off magma, frost drips off ice, wisps float off spirit, wind gusts back.
static func _drip(element: String, c: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = DRIP_AMOUNT
	p.lifetime = 0.7
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.spread = 40.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	match element:
		"earth":
			p.direction = Vector3.UP
			p.gravity = Vector3(0, 2.5, 0)
		"water":
			p.direction = Vector3.DOWN
			p.gravity = Vector3(0, -3.0, 0)
		_:
			p.direction = Vector3.UP
			p.gravity = Vector3(0, 0.8, 0)
	var fade := Gradient.new()
	fade.set_color(0, Color(c, 0.9))
	fade.set_color(1, Color(c, 0.0))
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.14
	quad.material = Fx.particle_mat("dot", true)
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Awakened: coats and gems glow harder, the blades shed twice the motes.
static func charge_coats(coats: Array, on: bool) -> void:
	for coat: Node in coats:
		if not is_instance_valid(coat) or not coat.has_meta("drip"):
			continue
		var shell: StandardMaterial3D = coat.get_meta("shell_mat")
		shell.emission_energy_multiplier = 1.2 if on else 0.35
		var glow: StandardMaterial3D = coat.get_meta("glow_mat")
		glow.emission_energy_multiplier = 3.5 if on else 1.6
		var drip: CPUParticles3D = coat.get_meta("drip")
		drip.amount = DRIP_AMOUNT * (3 if on else 1)
		drip.speed_scale = 1.6 if on else 1.0


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
