extends RefCounted
## The dragon prince's look and effects (first slice): the placeholder dressing on the chibi body (tint, horns,
## crown, Sunbrand in his hand), the sword mesh, the breath cone, the smash's blast, the summon, and his words.
## Flat and inked like the comic effects (docs/characters/dragon-prince.md section 7), built from simple meshes
## with shared materials (a fresh material per effect re-compiles its shader: agents.md "Godot frees what nothing
## holds"). Static functions; prince.gd and sunbrand.gd call them.

const COMIC_POP := preload("res://scripts/comic_pop.gd")
const PAL := preload("res://scripts/fx_palette.gd")

## His colours (the doc's palette): gold metal, sapphire magic, crimson scales, cream horns, dragonfire breath.
const GOLD := Color(1.0, 0.78, 0.3)
const GOLD_DEEP := Color(0.82, 0.48, 0.08)
const GOLD_LIGHT := Color(1.0, 0.95, 0.7)
const SAPPHIRE := Color(0.18, 0.45, 1.0)
const SAPPHIRE_LIGHT := Color(0.6, 0.85, 1.0)
const CREAM := Color(0.98, 0.92, 0.78)
const NAVY := Color(0.08, 0.1, 0.25)
const INK := Color(0.012, 0.01, 0.02)
const FIRE_DEEP := Color(0.75, 0.08, 0.05)  # the doc's new `dragonfire`: crimson deep
const FIRE_BODY := Color(1.0, 0.42, 0.08)  # flame orange
const FIRE_LIGHT := Color(1.0, 0.82, 0.3)  # gold light
const FIRE_HOT := Color(1.0, 0.97, 0.85)  # white hot
## Placeholder body tint (the heretic's paint multiplied): reads as a crimson, warm-lit character next to the
## heretic's indigo. The tones are the toon shader's shadow / mid / light bands.
const TINT_SHADOW := Color(0.32, 0.06, 0.08)
const TINT_MID := Color(0.85, 0.25, 0.2)
const TINT_LIGHT := Color(1.25, 0.72, 0.5)
const TINT_RIM := Color(1.0, 0.7, 0.2)

## Sunbrand, in its own space: the grip at the origin, the blade up +Y. Metres.
const GRIP := 0.3
const GUARD_W := 0.62
const BLADE_W := 0.3
const BLADE_L := 1.15
const TIP_L := 0.22
const SWORD_LEN := GRIP + 0.08 + BLADE_L + TIP_L  # pommel to tip

## The dressing on the chibi body, in skeleton rest space (tests/_prince_probe numbers: head bone at y 1.0,
## the top of the hood ~1.8).
const CROWN_AT := Vector3(0.036, 1.74, -0.06)
const HORN_AT := Vector3(0.3, 1.6, -0.12)  # mirrored in x
const HAND_BONE := "hand.r"
const HEAD_BONE := "head"

static var _mats := {}


static func flat(color: Color, alpha := false) -> StandardMaterial3D:
	var key := "%s/%s" % [color.to_html(), alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func vertex_mat() -> StandardMaterial3D:
	if _mats.has("vertex"):
		return _mats["vertex"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_mats["vertex"] = m
	return m


static func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = flat(color)
	mi.mesh = b
	mi.position = at
	parent.add_child(mi)
	return mi


## A fresh Sunbrand mesh (in hand or in the world): wide flat gold blade with a sapphire line, a winged gold
## crossguard, navy grip, round pommel, a pointed tip. Inked with Fx.outline.
static func sword() -> Node3D:
	var s := Node3D.new()
	s.name = "Sunbrand"
	_box(s, Vector3(0.09, GRIP, 0.09), Vector3(0, GRIP * 0.5 - GRIP, 0), NAVY)
	var pommel := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.085
	sp.height = 0.17
	pommel.mesh = sp
	pommel.position = Vector3(0, -GRIP - 0.03, 0)
	sp.material = flat(GOLD)
	s.add_child(pommel)
	_box(s, Vector3(GUARD_W, 0.08, 0.12), Vector3(0, 0.04, 0), GOLD_DEEP)
	for side in [-1.0, 1.0]:  # the guard's wing tips swept up
		var w := _box(s, Vector3(0.16, 0.07, 0.11), Vector3(side * (GUARD_W * 0.5 + 0.04), 0.1, 0), GOLD_DEEP)
		w.rotation.z = side * 0.6
	var blade := _box(s, Vector3(BLADE_W, BLADE_L, 0.05), Vector3(0, 0.08 + BLADE_L * 0.5, 0), GOLD_LIGHT)
	blade.name = "Blade"
	_box(s, Vector3(0.06, BLADE_L * 0.92, 0.065), Vector3(0, 0.08 + BLADE_L * 0.48, 0), SAPPHIRE)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = BLADE_W * 0.5
	cone.height = TIP_L
	cone.radial_segments = 4
	tip.mesh = cone
	tip.scale = Vector3(1.0, 1.0, 0.18)
	tip.rotation.y = PI * 0.25
	tip.position = Vector3(0, 0.08 + BLADE_L + TIP_L * 0.5, 0)
	cone.material = flat(GOLD_LIGHT)
	s.add_child(tip)
	Fx.outline(s)
	return s


## A thin trail target along the blade (weapon_trail.gd follows its +Y extent, like ComicLook.hero_blades).
static func trail_blade(s: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.02, BLADE_L, 0.02)
	mi.mesh = b
	mi.layers = 0
	mi.position = Vector3(0, 0.08 + BLADE_L * 0.5, 0)
	s.add_child(mi)
	return mi


## A node on `bone` whose children are placed in the skeleton's rest space (so the dressing can be authored in
## the model's own coordinates and still follow the bone).
static func rest_frame(skel: Skeleton3D, bone: String) -> Node3D:
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	var frame := Node3D.new()
	frame.transform = skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse()
	att.add_child(frame)
	return frame


## The placeholder prince on the chibi body: tinted crimson, horns and a crown, the heretic's weapon meshes
## hidden, Sunbrand in his right hand. Returns the hand sword.
static func dress(model: Node3D) -> Node3D:
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	tint(model)
	var head := rest_frame(skel, HEAD_BONE)
	var crown := Node3D.new()
	crown.name = "Crown"
	crown.position = CROWN_AT
	crown.rotation.x = -0.15
	head.add_child(crown)
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.17
	cyl.height = 0.1
	cyl.radial_segments = 10
	band.mesh = cyl
	cyl.material = flat(GOLD)
	crown.add_child(band)
	for i in 5:  # five points round the band
		var a := TAU * i / 5.0
		var pt := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.06
		c.height = 0.16
		c.radial_segments = 4
		pt.mesh = c
		pt.position = Vector3(sin(a) * 0.18, 0.12, cos(a) * 0.18)
		c.material = flat(GOLD)
		crown.add_child(pt)
	var gem := MeshInstance3D.new()
	var gs := SphereMesh.new()
	gs.radius = 0.045
	gs.height = 0.09
	gem.mesh = gs
	gem.position = Vector3(0, 0.02, 0.2)
	gs.material = flat(SAPPHIRE)
	crown.add_child(gem)
	for side in [-1.0, 1.0]:  # big swept-back cream horns
		var horn := MeshInstance3D.new()
		var hc := CylinderMesh.new()
		hc.top_radius = 0.0
		hc.bottom_radius = 0.12
		hc.height = 0.75
		hc.radial_segments = 6
		horn.mesh = hc
		horn.position = Vector3(HORN_AT.x * side + CROWN_AT.x, HORN_AT.y, HORN_AT.z)
		horn.rotation = Vector3(-1.45, 0.0, -side * 0.55)  # swept back and out: a "W" with the crown from above
		hc.material = flat(CREAM)
		head.add_child(horn)
	Fx.outline(head)
	for n in ["axe_void_blade", "axe_void_core", "axe_void_edge", "axe_void_haft", "hammer_void_haft",
			"hammer_void_head", "hammer_void_lava", "hammer_void_rock", "spear_void_collar", "spear_void_haft", "spear_void_ice"]:
		var mi: Node3D = model.find_child(n, true, false)
		if mi != null:
			mi.visible = false
			mi.set_meta("prince_hidden", true)
	return hand_sword(skel)


## Sunbrand on the right hand, along the line the heretic's axe takes out of it.
static func hand_sword(skel: Skeleton3D) -> Node3D:
	var frame := rest_frame(skel, HAND_BONE)
	var hand := skel.get_bone_global_rest(skel.find_bone(HAND_BONE)).origin
	var along := Vector3(-0.09, 1.05, 0.43).normalized()  # hand to the axe blade's centre at rest
	var blade_mi: MeshInstance3D = skel.get_parent().find_child("axe_void_blade", true, false)
	if blade_mi != null and blade_mi.mesh != null:
		var d := blade_mi.mesh.get_aabb().get_center() - hand
		if d.length() > 0.1:
			along = d.normalized()
	var s := sword()
	s.name = "HandSword"
	var side := along.cross(Vector3.FORWARD)
	if side.length() < 0.1:
		side = Vector3.RIGHT
	s.basis = Basis(side.normalized(), along, side.normalized().cross(along)).orthonormalized()
	s.position = hand + along * 0.05
	frame.add_child(s)
	return s


## Multiplies the body's toon bands warmer (a copy per surface, so the heretic's own materials keep theirs).
static func tint(model: Node3D) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.name.begins_with("axe_") or mi.name.begins_with("hammer_") or mi.name.begins_with("spear_"):
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i)
			if m is ShaderMaterial and (m as ShaderMaterial).get_shader_parameter("mid_color") != null:
				var t := (m as ShaderMaterial).duplicate() as ShaderMaterial
				t.set_shader_parameter("shadow_color", _mul(t.get_shader_parameter("shadow_color"), TINT_SHADOW))
				t.set_shader_parameter("mid_color", _mul(t.get_shader_parameter("mid_color"), TINT_MID))
				t.set_shader_parameter("light_color", _mul(t.get_shader_parameter("light_color"), TINT_LIGHT))
				t.set_shader_parameter("hi_color", _mul(t.get_shader_parameter("hi_color"), TINT_LIGHT))
				t.set_shader_parameter("rim_color", TINT_RIM * 0.35)
				mi.set_surface_override_material(i, t)


static func _mul(v: Variant, k: Color) -> Color:
	var c: Color = v if v is Color else Color(v.x, v.y, v.z) if v is Vector3 else Color.WHITE
	return Color(c.r * k.r, c.g * k.g, c.b * k.b)


# --- Effects --------------------------------------------------------------------------------------

## His word on the page (ComicFx's pool, like the signature moves' words). Quiet when there is no ComicFx.
static func say(text: String, world: Vector3, scale := 0.6) -> void:
	if ComicFx._inst != null and is_instance_valid(ComicFx._inst):
		ComicFx._inst._say(text, world, scale)


## Dragon Breath: a flat fan of flame tongues on the floor plane at chest height, `radius` out over `arc_deg`,
## crimson edge to white-hot root, an ink fan just outside it; grows in 0.1 s, gone by `life`.
static func breath(parent: Node, origin: Vector3, fwd: Vector3, radius: float, arc_deg: float, life := 0.4) -> void:
	var root := Node3D.new()
	root.top_level = true
	parent.add_child(root)
	root.global_position = origin
	root.basis = Basis.looking_at(-fwd, Vector3.UP)  # local +Z = fwd
	var ink := _fan(radius * 1.07, arc_deg + 6.0, 0.0, Color(INK, 0.85), Color(INK, 0.85), Color(INK, 0.85))
	ink.position.y = -0.02
	root.add_child(ink)
	root.add_child(_fan(radius, arc_deg, 0.35, FIRE_HOT, FIRE_BODY, Color(FIRE_DEEP, 0.9)))
	var core := _fan(radius * 0.55, arc_deg * 0.7, 0.25, Color(FIRE_HOT, 1.0), FIRE_LIGHT, Color(FIRE_BODY, 0.0))
	core.position.y = 0.02
	root.add_child(core)
	root.scale = Vector3(0.25, 1.0, 0.25)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(maxf(life - 0.28, 0.02))
	for mi in root.get_children():
		tw.parallel().tween_property(mi, "transparency", 1.0, 0.18).set_delay(0.0)
	tw.tween_callback(root.queue_free)
	COMIC_POP.spawn(parent, origin + fwd * radius * 0.6, {"strokes": 5, "dir": fwd, "spread": deg_to_rad(arc_deg) * 0.4,
		"stroke_color": FIRE_LIGHT, "stroke_len": radius * 0.4, "chips": 4, "chip": FIRE_BODY, "steps": 4})


## A fan in local XZ (+Z ahead): `root`/`mid`/`edge` vertex colours, a jagged rim (`jag` of the radius).
static func _fan(radius: float, arc_deg: float, jag: float, root: Color, mid: Color, edge: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var half := deg_to_rad(arc_deg) * 0.5
	var pts: Array[Vector3] = []
	for i in n + 1:
		var a := lerpf(-half, half, float(i) / n)
		var r := radius * (1.0 - (jag * (0.5 + 0.5 * sin(i * 2.7)) if i % 2 == 1 else 0.0))
		pts.append(Vector3(sin(a) * r, 0.0, cos(a) * r))
	for i in n:
		var m0 := pts[i] * 0.5
		var m1 := pts[i + 1] * 0.5
		_tri(st, Vector3.ZERO, m0, m1, root, mid, mid)
		_tri(st, m0, pts[i], pts[i + 1], mid, edge, edge)
		_tri(st, m0, pts[i + 1], m1, mid, edge, mid)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = vertex_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	return mi


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


## The smash's blast at `at` (floor): a flat gold star with a sapphire core, radial ink rays, gold chips, a floor
## hoop out to the radius and a dent.
static func blast(parent: Node, at: Vector3, radius: float) -> void:
	COMIC_POP.spawn(parent, at + Vector3.UP * 0.8, {"star": radius * 0.62, "spikes": 8, "star_color": GOLD,
		"star_core": SAPPHIRE_LIGHT, "star_ring": Color(INK, 0.9), "hold": 2, "strokes": 8, "radial": true,
		"gap": radius * 0.45, "stroke_len": radius * 0.4, "stroke_w": 0.22, "stroke_color": GOLD_LIGHT,
		"chips": 12, "chip": GOLD, "chip_size": 0.2, "chip_speed": 9.0, "chip_ink": 3, "steps": 6})
	COMIC_POP.spawn(parent, at + Vector3.UP * 0.05, {"ring": radius, "ring_color": SAPPHIRE, "ring_w": 0.3, "steps": 5})
	Fx.crater(parent, at, radius * 0.8)
	_pillar(parent, at, radius)


## A short sapphire-white column out of the blast (the radiance in the sword), on twos, so the smash reads from
## the top-down camera as "up and out".
static func _pillar(parent: Node, at: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius * 0.03
	c.bottom_radius = radius * 0.08
	c.height = 3.5
	c.radial_segments = 8
	mi.mesh = c
	mi.material_override = flat(Color(SAPPHIRE_LIGHT, 0.75), true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	parent.add_child(mi)
	mi.global_position = at + Vector3.UP * 1.75
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(2.2, 1.3, 2.2), 0.18)
	tw.parallel().tween_property(mi, "transparency", 1.0, 0.18)
	tw.tween_callback(mi.queue_free)


## A new Sunbrand forms in his hand: gold shards in on a sapphire hoop, a star at the blade.
static func summon(parent: Node, at: Vector3) -> void:
	COMIC_POP.spawn(parent, at, {"star": 0.55, "spikes": 4, "star_color": SAPPHIRE_LIGHT, "star_core": Color.WHITE,
		"strokes": 6, "radial": true, "gap": 0.5, "stroke_len": 0.4, "stroke_color": GOLD, "steps": 4})
	COMIC_POP.spawn(parent, Vector3(at.x, 0.05, at.z), {"ring": 1.3, "ring_color": GOLD, "ring_w": 0.14, "steps": 3})


## Where a thrown sword bites: a small gold star and chips.
static func bite(parent: Node, at: Vector3, dir: Vector3) -> void:
	COMIC_POP.spawn(parent, at, {"star": 0.7, "star_color": GOLD, "star_core": GOLD_LIGHT, "strokes": 4,
		"dir": dir, "chips": 5, "chip": GOLD, "steps": 4})
