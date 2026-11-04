class_name Fx
## Small throwaway visual effects: damage numbers, hit sparks, flashes.

## Particle and flare sprites (Kenney Particle Pack, CC0): white with alpha, tinted per use.
const TEX := {
	"dot": preload("res://assets/vfx/circle_05.png"),
	"ring": preload("res://assets/vfx/circle_03.png"),
	"flare": preload("res://assets/vfx/magic_05.png"),
	"star": preload("res://assets/vfx/star_06.png"),
	"smoke": preload("res://assets/vfx/smoke_04.png"),
	"scorch": preload("res://assets/vfx/scorch_02.png"),
	"spark": preload("res://assets/vfx/spark_05.png"),
	"star8": preload("res://assets/vfx/star_08.png"),
}
## Combo-counter thresholds where hit sparks escalate (chain_tier).
const CHAIN_TIERS := [10, 20, 35]
## How much bigger a sprite's quad is than the solid shape it replaced (soft edges).
const TEX_SCALE := {"dot": 2.0, "smoke": 1.5}
const SWOOSH_SHADER := preload("res://shaders/swoosh.gdshader")
const NOISE := preload("res://assets/vfx/noise_soft.png")
const COMIC_INK_PX := 1.6  # Game.comic_style's hull width (default 3.5): a hero is only ~130 px tall
const COMIC_INK_WOBBLE := 0.25  # how much of the width varies over the form
const COMIC_INK_PUSH := 0.08  # m behind the model, so a part's hull doesn't cover its neighbours
## Telegraph rim (edge_ring): a light ring just inside the radius with a dark outline just outside it.
const EDGE_WIDTH := 0.16  # m, light rim
const EDGE_OUTLINE := 0.07  # m, dark outline
## Game.comic_style draws the per-hit flourishes as flat inked shapes on twos (scripts/comic_pop.gd)
## instead of glowing flares and dot sprays, which read as a different game next to inked heroes.
const COMIC_POP := preload("res://scripts/comic_pop.gd")
const COMIC_NUMBER := preload("res://scripts/comic_number.gd")
const COMIC_CRACK := preload("res://scripts/comic_crack.gd")
const COMIC_CRACK_SIZE := 0.8  # of the scorch's radius: the scorch texture only filled about half its quad, but cracks reach their tips
const COMIC_BURST_CHIPS := 6  # most chips a comic burst throws
const COMIC_GHOST_STEP := 1.0 / 12.0  # s: the comic afterimage's two steps, on twos
const COMIC_FLASH := Color(1.0, 0.97, 0.88)  # a comic hit flash's paper ink
## Flat two-tone chip colour off the axes per element (element_hit).
const COMIC_CHIP := {"wind": Color(0.16, 0.85, 0.38), "earth": Color(1.0, 0.36, 0.04), "water": Color(0.5, 0.82, 1.0),
	"spirit": Color(0.2, 0.85, 0.78)}

static var _flash_mat: StandardMaterial3D
static var _tint_mats := {}  # flash_tint() overlays, one per colour
static var _rim_mat: ShaderMaterial
static var _outline_mat: ShaderMaterial
# Source material -> copy with the outline pass, shared by every character using it.
static var _outlined: Dictionary = {}
# Particle materials are colourless (tint comes from the colour ramp), so one per texture/blend.
static var _particle_mats: Dictionary = {}
## Tick time of the last big impact (read by the autotest to snap a frame).
static var last_big_hit_ms := 0
static var last_afterimage_ms := 0


## The base of nearly every effect material: unshaded, alpha-blended (`add`:
## additive), with the sprite `tex` from TEX when given.
static func unshaded_mat(color := Color.WHITE, tex := "", add := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if tex != "":
		mat.albedo_texture = TEX[tex]
	mat.albedo_color = color
	return mat


## A floating billboard label (damage numbers, heals): the caller animates and frees it.
static func _label(text: String, font_size: int, color: Color, outline_color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = font_size
	l.outline_size = 18
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_modulate = outline_color
	return l


## Melee swing arc: a flat crescent around `pos` facing `fwd`, out to `radius`
## across `arc_deg` (360 = full spin), sweeping across it over `time`.
## `flip` swings right-to-left instead of left-to-right.
static func swoosh(parent: Node, pos: Vector3, fwd: Vector3, radius: float, arc_deg: float,
		color: Color, flip := false, time := 0.26, height := 0.8) -> void:
	var arc := deg_to_rad(clampf(arc_deg, 20.0, 360.0))
	var inner := radius * 0.4
	var segs := maxi(10, int(arc_deg / 6.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var u := float(i) / segs
		var a := (-arc * 0.5 + arc * u) * (-1.0 if flip else 1.0)
		var d := Vector3(sin(a), 0.0, cos(a))
		st.set_uv(Vector2(u, 0.0))
		st.add_vertex(d * inner)
		st.set_uv(Vector2(u, 1.0))
		st.add_vertex(d * radius)
	var mat := ShaderMaterial.new()
	mat.shader = SWOOSH_SHADER
	mat.set_shader_parameter("noise", NOISE)
	var a_mult := 0.5 if Game.reduce_flashing else 1.0
	mat.set_shader_parameter("color", Color(color, color.a * a_mult))
	mat.set_shader_parameter("edge_color", Color(color.lerp(Color.WHITE, 0.45), a_mult))
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos + Vector3.UP * height
	m.rotation.y = atan2(fwd.x, fwd.z)
	var tw := m.create_tween()
	tw.tween_method(func(p: float) -> void: mat.set_shader_parameter("progress", p), 0.0, 1.0, time)
	tw.tween_callback(m.queue_free)


## `foe`: who took it, so the comic number merges that foe's hits (comic_number.gd).
static func damage_number(parent: Node, pos: Vector3, amount: float, big := false, foe: Object = null) -> void:
	if Game.comic_style:  # one chunky inked number per foe, growing as hits add in, drifting off the pile
		COMIC_NUMBER.add(parent, pos, amount, big, foe)
		return
	var l := _label(str(roundi(amount)), 96 if big else 64,
		Color(1.0, 0.85, 0.3) if big else Color.WHITE, Color(0.1, 0.05, 0.1))
	parent.add_child(l)
	var jitter := Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.2, 0.2))
	l.global_position = pos + Vector3.UP * 2.2 + jitter
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


static func hit_spark(parent: Node, pos: Vector3, color := Color(1.0, 0.9, 0.6), size := 0.9) -> void:
	var at := pos + Vector3.UP * 1.1
	if Game.comic_style:  # the hot inked star; impact() adds the strokes
		COMIC_POP.spawn(parent, at, {"star": size * 0.5, "steps": 3})
		return
	# Pale colours vanish on the light floor tiles: push the flare's saturation up.
	var vivid := Color.from_hsv(color.h, maxf(color.s, 0.75), 1.0, color.a)
	flare(parent, at, vivid, size * 3.0, 0.16, "flare")
	flare(parent, at, Color(1.0, 1.0, 1.0, color.a), size * 1.2, 0.1, "dot", true)


## 0..3: how far the combo counter has climbed past CHAIN_TIERS.
static func chain_tier(count: int) -> int:
	var t := 0
	for n: int in CHAIN_TIERS:
		if count >= n:
			t += 1
	return t


## Extra hit flourish that grows with the combo counter, in the hero's colour:
## tier 1 a star flare, 2 adds a spray of spark streaks, 3 a shock ring flare.
static func chain_spark(parent: Node, pos: Vector3, color: Color, tier: int, dir := Vector3.UP) -> void:
	if tier <= 0:
		return
	var at := pos + Vector3.UP * 1.1
	if Game.comic_style:  # a halo in his colour behind the hit's star, more strokes each tier
		COMIC_POP.spawn(parent, at, {"star": 0.32 + 0.06 * tier, "star_color": color, "star_core": color.lightened(0.5),
			"spikes": 7 + tier, "layer": -0.5, "steps": 2, "strokes": 0 if tier < 2 else tier,
			"dir": dir, "spread": 1.1, "stroke_color": color.lightened(0.35), "stroke_len": 0.4 + 0.08 * tier})
		return
	var vivid := Color.from_hsv(color.h, maxf(color.s, 0.8), 1.0)
	flare(parent, at, vivid, 1.6 + tier * 0.6, 0.14, "star8")
	if tier >= 2:
		burst(parent, at, vivid, 6 + tier * 3, 13.0, 0.16, 0.22, dir, 70.0, -6.0, 0.0, "spark")
	if tier >= 3:
		flare(parent, at, Color(vivid, 0.85), 3.4, 0.18, "ring")


## Debris off the hero's element-coated axes on each hit (player._do_hit):
## spirit wisps, wind streaks, obsidian chips and embers, ice shards and frost.
static func element_hit(parent: Node, pos: Vector3, element: String, dir: Vector3, big := false) -> void:
	var at := pos + Vector3.UP * 1.0
	var k := 1.5 if big else 1.0
	if Game.comic_style:  # chunky chips of the element, flung along the blow
		COMIC_POP.spawn(parent, at, {"chips": int(3 * k), "chip": COMIC_CHIP.get(element, COMIC_CHIP.spirit),
			"chip_size": 0.11 * k, "chip_speed": 6.0, "dir": dir, "spread": 0.6, "steps": 3})
		return
	match element:
		"wind":
			burst(parent, at, Color(0.45, 1.0, 0.55), int(6 * k), 12.0, 0.15, 0.2, dir, 40.0, 0.0, 0.0, "spark")
		"earth":
			shards(parent, at, Color(0.18, 0.14, 0.13), int(4 * k), dir, 7.0, 0.13, 0.5)
			burst(parent, at, Color(1.0, 0.45, 0.1), int(6 * k), 6.0, 0.08, 0.45, Vector3.UP, 60.0, -3.0, 0.2, "dot", true)
		"water":
			shards(parent, at, Color(0.7, 0.9, 1.0), int(5 * k), dir, 8.0, 0.12, 0.45)
			flare(parent, at, Color(0.55, 0.85, 1.0), 1.2 * k, 0.12, "star8")
		_:
			burst(parent, at, Color(0.3, 0.95, 0.85), int(5 * k), 3.0, 0.12, 0.5, Vector3.UP, 50.0, -1.5, 0.25, "dot", true)


## A named combo landing (player._combo_callout): star flare, ground ring and a
## spark spray at the hero, scaled by the combo's tier (1-3).
static func combo_pop(parent: Node, pos: Vector3, color: Color, tier: int) -> void:
	var at := pos + Vector3.UP * 1.2
	var vivid := Color.from_hsv(color.h, maxf(color.s, 0.7), 1.0)
	if Game.comic_style:  # strokes bursting out all round him, never a star over him
		COMIC_POP.spawn(parent, at, {"strokes": 7 + tier * 2, "radial": true, "gap": 0.85 + tier * 0.1,
			"stroke_len": 0.55 + tier * 0.15, "stroke_w": 0.2 + tier * 0.03, "stroke_color": vivid,
			"hold": 2 if tier >= 3 else 1, "steps": 3})
		return
	flare(parent, at, vivid, 2.2 + tier * 1.0, 0.18, "star8")
	flare(parent, at, Color(1, 1, 1, 0.9), 0.9 + tier * 0.3, 0.1, "dot", true)
	ring(parent, pos, Color(vivid, 0.85), 1.6 + tier * 0.7, 0.3)
	burst(parent, at, vivid, 8 + tier * 6, 11.0 + tier * 2.0, 0.17, 0.3, Vector3.UP, 180.0, -8.0, 0.3, "spark")


## Camera-facing sprite that pops to `size` (m across) and fades over `time`.
## `add` blends additively: keep that for small hot cores, big additive
## shapes wash out to white on the light floor.
static func flare(parent: Node, at: Vector3, color: Color, size: float, time := 0.16,
		tex := "flare", add := false) -> void:
	var mat := unshaded_mat(color, tex, add)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true  # a hit flare reads through the enemy it lands on
	if Game.reduce_flashing:
		mat.albedo_color.a *= 0.45
		size *= 0.6
	var quad := QuadMesh.new()
	quad.material = mat
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = at
	m.scale = Vector3.ONE * size * 0.6  # starts big: a hit flash has to read on frame one
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3.ONE * size, time * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time * 0.6).set_delay(time * 0.4)
	tw.chain().tween_callback(m.queue_free)


## One-shot particle burst. `dir` biases the spray (e.g. knockback direction).
static func burst(parent: Node, pos: Vector3, color: Color, amount := 14, speed := 7.0,
		size := 0.12, lifetime := 0.3, dir := Vector3.UP, spread := 70.0, gravity := -12.0,
		radius := 0.0, tex := "dot", add := false) -> void:
	if Game.comic_style:  # a few chunky two-tone chips, no smoke and no dot spray
		if tex == "smoke" or amount <= 1:  # (1: elements.prewarm; the chips' material is already warm)
			return
		var c := Color(color, 1.0)
		var wide := spread >= 120.0 or dir.length() < 0.01
		COMIC_POP.spawn(parent, pos, {"chips": clampi(amount / 3, 2, COMIC_BURST_CHIPS), "chip": c,
			"chip_size": clampf(size * 0.9, 0.08, 0.17), "chip_speed": clampf(speed * 0.6, 2.5, 6.0),
			"dir": Vector3.ZERO if wide else dir, "spread": deg_to_rad(clampf(spread, 20.0, 80.0)), "steps": 3})
		return
	# CPU particles: no shader compile hitch on first spawn, cheap at these counts.
	var p := CPUParticles3D.new()
	size *= TEX_SCALE.get(tex, 1.0)
	p.angle_min = 0.0
	p.angle_max = 360.0  # random spin so repeated sprites don't line up
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = true  # emitter never moves; world-space emission misplaces the first burst
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, gravity, 0.0)
	p.damping_min = speed * 0.6
	p.damping_max = speed * 1.2
	if radius > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = particle_mat(tex, add)
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = parent.to_local(pos) if parent is Node3D else pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func particle_mat(tex: String, add: bool) -> StandardMaterial3D:
	var key := tex + ("+" if add else "")
	if not _particle_mats.has(key):
		var mat := unshaded_mat(Color.WHITE, tex, add)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		_particle_mats[key] = mat
	return _particle_mats[key]


## Solid low-poly chunks (bone, rock, ice) flung along `dir` that tumble and fall.
## Shaded, not glowing: debris should read as stuff, not light.
static func shards(parent: Node, pos: Vector3, color: Color, amount := 10, dir := Vector3.UP,
		speed := 8.0, size := 0.18, lifetime := 0.7) -> void:
	if Game.comic_style:  # flat inked two-tone chips, not shaded boxes
		COMIC_POP.spawn(parent, pos, {"chips": clampi(int(amount * 0.6), 2, 14), "chip": color,
			"chip_size": size * 0.85, "chip_speed": speed * 0.7, "dir": dir, "spread": 1.2,
			"steps": clampi(int(lifetime * 10.0), 4, 7)})
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = true
	p.direction = (dir.normalized() + Vector3.UP * 0.8).normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -26.0, 0.0)
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	var shrink := Curve.new()  # pieces shrink away at the end instead of popping out
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.7, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	p.color = color
	var box := BoxMesh.new()
	box.size = Vector3(size, size * 0.6, size * 1.4)
	box.material = shard_mat()
	p.mesh = box
	p.position = parent.to_local(pos) if parent is Node3D else pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func shard_mat() -> StandardMaterial3D:
	if not _particle_mats.has("shard"):
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		_particle_mats["shard"] = mat
	return _particle_mats["shard"]


## An enemy going down: kill flash, shock ring, bone shards along the
## knockback, a smoke puff. `color` tints the shards (bone by default).
static func death(parent: Node, pos: Vector3, dir: Vector3, big := false,
		color := Color(0.93, 0.89, 0.78)) -> void:
	var at := pos + Vector3.UP * 0.9
	if Game.comic_style:  # a held kill star, strokes all round, bone chips; no smoke, no soft ring
		COMIC_POP.spawn(parent, at, {"star": 1.15 if big else 0.9, "spikes": 11, "hold": 2, "steps": 3,
			"strokes": 8, "radial": true, "gap": 0.7, "stroke_len": 0.6, "stroke_w": 0.18,
			"chips": 7 if big else 5, "chip": color, "chip_size": 0.17, "chip_speed": 6.5, "chip_ink": 4, "dir": dir, "spread": 1.3})
		return
	# Saturated gold: cream and white vanish on the light floor tiles.
	flare(parent, at, Color(1.0, 0.62, 0.15), 4.4 if big else 3.4, 0.22, "flare")
	flare(parent, at, Color(1.0, 1.0, 1.0), 1.6 if big else 1.2, 0.1, "dot", true)
	ring(parent, pos, Color(1.0, 0.55, 0.12, 0.9), 3.2 if big else 2.4, 0.32)
	shards(parent, at, color, 18 if big else 12, dir, 10.0 if big else 8.5, 0.28)
	dust(parent, pos, 12, 0.7)


## Speed streak on the floor along a dash: `length` m from `from` along `dir`,
## narrowing and fading over `time`.
static func dash_streak(parent: Node, from: Vector3, dir: Vector3, length: float, color: Color,
		time := 0.3, width := 2.2) -> void:
	# The dot stretched along the dash: a soft speed smear.
	var mat := unshaded_mat(Color(color, color.a * (0.5 if Game.reduce_flashing else 1.0)), "dot")
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, length)
	plane.material = mat
	var m := MeshInstance3D.new()
	m.mesh = plane
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	m.global_position = from + d * length * 0.5 + Vector3.UP * 0.08
	m.rotation.y = atan2(d.x, d.z)
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale:x", 0.25, time).set_ease(Tween.EASE_IN)
	tw.tween_property(mat, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(m.queue_free)


## Column of light that shoots up from `pos` and collapses inward over `time`:
## a coloured shell around a white-hot core.
static func beam(parent: Node, pos: Vector3, color: Color, height := 10.0, radius := 1.3,
		time := 0.55) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var mats: Array[StandardMaterial3D] = []
	for layer: Array in [[radius, Color(color, 0.7)], [radius * 0.45, Color(1.0, 1.0, 1.0, 0.9)]]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = layer[0] * 0.7
		cyl.bottom_radius = layer[0]
		cyl.height = height
		cyl.cap_top = false
		cyl.cap_bottom = false
		cyl.radial_segments = 16  # faceted on purpose: low-poly look
		var mat := unshaded_mat(layer[1])
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if Game.reduce_flashing:
			mat.albedo_color.a *= 0.4
		cyl.material = mat
		mats.append(mat)
		var m := MeshInstance3D.new()
		m.mesh = cyl
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position.y = height * 0.5
		root.add_child(m)
	root.scale = Vector3(1.0, 0.05, 1.0)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3(1.0, 1.0, 1.0), time * 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(root, "scale", Vector3(0.05, 1.15, 0.05), time * 0.85).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	for mat in mats:
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, time * 0.85).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)


## Awakening activation at `pos`: light pillar, flash, double shockwave
## (`radius` = the blast), rising motes and a dust blast.
static func awaken_burst(parent: Node, pos: Vector3, color: Color, radius := 7.0) -> void:
	beam(parent, pos, color, 12.0, 1.5, 0.6)
	flare(parent, pos + Vector3.UP * 1.2, color, 11.0, 0.4, "flare")
	flare(parent, pos + Vector3.UP * 1.2, Color.WHITE, 3.5, 0.18, "dot", true)
	ring(parent, pos, Color(color, 0.95), radius, 0.45)
	ring(parent, pos, Color(1.0, 1.0, 1.0, 0.85), radius * 0.45, 0.3)
	burst(parent, pos + Vector3.UP * 0.4, color, 40, 12.0, 0.2, 0.7, Vector3.UP, 35.0, -4.0, 1.0, "dot")
	burst(parent, pos + Vector3.UP * 0.4, Color.WHITE, 16, 14.0, 0.12, 0.5, Vector3.UP, 25.0, -4.0, 0.6, "dot", true)
	dust(parent, pos, 24, 1.2)


## Pale motes rising off a corpse as it sinks away.
static func soul(parent: Node, pos: Vector3, color := Color(0.3, 0.75, 1.0, 0.9)) -> void:
	burst(parent, pos + Vector3.UP * 0.3, color, 16, 2.5, 0.2, 0.9, Vector3.UP, 25.0, 3.0, 0.5, "dot")
	burst(parent, pos + Vector3.UP * 0.3, Color(0.85, 0.95, 1.0), 6, 3.0, 0.1, 0.7, Vector3.UP, 20.0, 3.0, 0.4, "dot", true)


static func impact(parent: Node, pos: Vector3, dir: Vector3, big := false) -> void:
	var at := pos + Vector3.UP * 1.1
	if big:
		last_big_hit_ms = Time.get_ticks_msec()
	if Game.comic_style:  # fat speed strokes along the blow and ink flecks; hit_spark has the star
		COMIC_POP.spawn(parent, at, {"strokes": 4 if big else 3, "dir": dir, "spread": 0.45,
			"stroke_len": 0.8 if big else 0.55, "stroke_w": 0.17 if big else 0.13, "chip_ink": 4 if big else 2,
			"chip_size": 0.09, "chip_speed": 5.5, "steps": 3})
		return
	flare(parent, at, Color(1.0, 0.5, 0.08), 3.6 if big else 2.4, 0.15, "flare")
	flare(parent, at, Color(1.0, 0.97, 0.85), 1.2 if big else 0.8, 0.08, "dot", true)
	flare(parent, at, Color(1.0, 0.6, 0.2, 0.9), 2.2 if big else 1.4, 0.2, "ring")
	burst(parent, at, Color(1.0, 0.6, 0.15), 24 if big else 14, 14.0 if big else 10.0, 0.22, 0.35, dir, 50.0)
	burst(parent, at, Color(1.0, 0.97, 0.85), 8 if big else 4, 18.0, 0.18, 0.2, dir, 30.0, 0.0, 0.0, "dot", true)


static func dust(parent: Node, pos: Vector3, amount := 10, size := 0.45) -> void:
	if Game.comic_style:
		return  # no smoke in the comic look: the landing's ring and cracks carry it
	burst(parent, pos + Vector3.UP * 0.2, Color(0.62, 0.57, 0.5, 0.6), amount, 4.0, size, 0.55, Vector3.UP, 80.0, 1.0, 0.45, "smoke")


## Expanding flat ring on the ground (shockwaves, Awakening burst).
static func ring(parent: Node, pos: Vector3, color: Color, radius: float, time := 0.35) -> void:
	if Game.comic_style:  # a hard inked hoop on twos, not a soft glowing disc
		COMIC_POP.spawn(parent, pos, {"ring": radius, "ring_color": color, "steps": clampi(int(time * 12.0) + 1, 3, 6)})
		return
	var m := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * 2.2  # the texture's ring sits just inside the quad: outer edge ~1 m
	# Soft edges read fainter than the solid torus did, so the alpha is pushed up.
	var mat := unshaded_mat(Color(color, minf(color.a * 1.3, 1.0)), "ring")
	mesh.material = mat
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos + Vector3.UP * 0.15
	m.scale = Vector3(0.3, 0.05, 0.3)
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3(radius, 0.05, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time * 0.6).set_delay(time * 0.4)
	tw.chain().tween_callback(m.queue_free)


## Where a foe was spiked into the floor (enemy._crater): a dark hole (a hard
## disc CRATER_HOLE of the radius) under a ragged splat, both popping out to
## `radius`, a dust ring past it, the lot fading over `time`.
const CRATER_COLOR := Color(0.16, 0.12, 0.1, 0.85)  # soot brown, reads on the light tiles
const CRATER_HOLE := 0.45  # the solid disc's radius, as a share of `radius`
const CRATER_SPLAT := 1.6  # the splat quad's half-size, as a share of `radius` (its texture fills ~half of it)
const CRATER_SEGMENTS := 14  # a chunky low-poly edge, not a perfect circle
const CRATER_RING := Color(0.62, 0.57, 0.5, 0.75)  # the dust colour of dust()
const CRATER_RING_OUT := 1.5  # the dust ring's reach, in crater radii
static func crater(parent: Node, pos: Vector3, radius: float, time := 1.4) -> void:
	_crater_layer(parent, pos + Vector3.UP * 0.05, radius * CRATER_HOLE, "", time)
	_crater_layer(parent, pos + Vector3.UP * 0.06, radius * CRATER_SPLAT, "scorch", time)
	ring(parent, pos, CRATER_RING, radius * CRATER_RING_OUT, 0.3)


static func _crater_layer(parent: Node, at: Vector3, radius: float, tex: String, time: float) -> void:
	var m := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	if tex == "":  # the hole: a hard-edged flat disc, 1 m radius
		var disc := CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = 0.01
		disc.radial_segments = CRATER_SEGMENTS
		disc.rings = 1
		mesh = disc
	else:
		var quad := PlaneMesh.new()
		quad.size = Vector2.ONE * 2.0
		mesh = quad
	var mat := unshaded_mat(CRATER_COLOR, tex)
	mesh.material = mat
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = at + Vector3.UP * randf() * 0.01  # jitter: overlapping marks don't z-fight
	m.rotation.y = randf() * TAU
	m.scale = Vector3(radius * 0.3, 1.0, radius * 0.3)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(radius, 1.0, radius), 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(time * 0.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, time * 0.5)
	tw.tween_callback(m.queue_free)


## Cartoon dizzy stars circling a dazed head (training_dummy._shake_off):
## DAZE_STARS solid five-point stars inked in ComicFx.INK, on a DAZE_RING m
## ring `height` above `node`, spinning DAZE_SPIN rad/s, popping in and
## shrinking away over `time`. Named "DazeStars".
const DAZE_STARS := 3
const DAZE_RING := 0.5  # m, the ring's radius
const DAZE_SIZE := 0.2  # m, a star's outer radius
const DAZE_INNER := 0.45  # a star's inner points, as a share of its outer radius
const DAZE_INK := 1.35  # the ink star behind, as a share of the star
const DAZE_SPIN := 7.0  # rad/s
const DAZE_COLOR := Color(1.0, 0.86, 0.2)
static var _star_mesh: ArrayMesh
static func daze(node: Node3D, height: float, time := 0.9) -> void:
	if _star_mesh == null:
		_star_mesh = _star(DAZE_SIZE, DAZE_INNER)
	var pivot := Node3D.new()
	pivot.name = "DazeStars"
	node.add_child(pivot)
	pivot.position.y = height
	var fill := unshaded_mat(DAZE_COLOR)
	fill.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill.render_priority = 1  # over its ink
	var ink := unshaded_mat(Color(0.012, 0.01, 0.02))
	ink.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	ink.billboard_keep_scale = true  # a billboard drops the node's scale otherwise: the ink would hide
	for i in DAZE_STARS:
		var a := TAU * i / DAZE_STARS
		for layer in 2:
			var star := MeshInstance3D.new()
			star.mesh = _star_mesh
			star.material_override = ink if layer == 0 else fill
			star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			star.position = Vector3(cos(a), 0.0, sin(a)) * DAZE_RING
			star.scale = Vector3.ONE * (DAZE_INK if layer == 0 else 1.0)
			pivot.add_child(star)
	pivot.scale = Vector3.ONE * 0.2
	var tw := pivot.create_tween().set_parallel()
	tw.tween_property(pivot, "rotation:y", DAZE_SPIN * time, time)
	tw.tween_property(pivot, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "scale", Vector3.ONE * 0.01, 0.15).set_delay(time - 0.15)
	tw.chain().tween_callback(pivot.queue_free)


## A flat five-point star facing +z, `outer` m to its points, `inner` of that to its notches.
static func _star(outer: float, inner: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i in 10:
		var a := PI * 0.5 + TAU * i / 10.0
		var r := outer if i % 2 == 0 else outer * inner
		var p := Vector3(cos(a) * r, sin(a) * r, 0.0)
		var q_a := PI * 0.5 + TAU * (i + 1) / 10.0
		var q_r := outer if (i + 1) % 2 == 0 else outer * inner
		verts.append_array([Vector3.ZERO, Vector3(cos(q_a) * q_r, sin(q_a) * q_r, 0.0), p])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Burn mark on the floor: a ragged scorch decal that flashes in `color`, cools to
## soot and fades over `time` (magma, breaker landings). Blend mix so it reads on light tiles.
static func scorch(parent: Node, pos: Vector3, color: Color, radius: float, time := 1.2) -> void:
	if Game.comic_style:  # a flat inked splat and cracks, hot then soot; not a soft glowing decal
		COMIC_CRACK.spawn(parent, pos, Color.from_hsv(color.h, maxf(color.s, 0.85), 1.0), radius * COMIC_CRACK_SIZE, time)
		return
	var m := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * 2.0
	var mat := unshaded_mat(Color(Color.from_hsv(color.h, 0.95, 1.0), 0.95), "scorch")
	mesh.material = mat
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos + Vector3.UP * (0.04 + randf() * 0.02)  # jitter: overlapping marks don't z-fight
	m.rotation.y = randf() * TAU
	m.scale = Vector3(radius * 0.6, 1.0, radius * 0.6)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(radius, 1.0, radius), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color", Color(0.18, 0.1, 0.08, 0.7), time * 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, time * 0.5)
	tw.tween_callback(m.queue_free)


## Green "+N" and rising sparkles for healing.
static func heal(parent: Node, pos: Vector3, amount: float) -> void:
	var l := _label("+%d" % roundi(amount), 88, Color(0.45, 1.0, 0.5), Color(0.02, 0.12, 0.05))
	parent.add_child(l)
	l.global_position = pos + Vector3.UP * 2.4
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.2, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)
	burst(parent, pos + Vector3.UP * 0.2, Color(0.4, 1.0, 0.5), 24, 3.0, 0.12, 0.9, Vector3.UP, 30.0, 2.0, 0.8)
	ring(parent, pos, Color(0.4, 1.0, 0.5, 0.7), 2.0, 0.4)


## Frozen translucent copy of a (skinned) model in its current pose.
static func afterimage(parent: Node, model: Node3D, color: Color, time := 0.25) -> void:
	if DisplayServer.get_name() == "headless":
		return  # the dummy renderer has no skeletons to bake from
	var comic := Game.comic_style
	if comic and Time.get_ticks_msec() - last_afterimage_ms < int(COMIC_GHOST_STEP * 1000.0):
		return  # on twos: a dash asks every 0.035 s, which stacked into a solid bar
	last_afterimage_ms = Time.get_ticks_msec()
	# Comic: a flat inked silhouette, not a see-through copy: one step in his colour, then ink, on twos.
	var mat := unshaded_mat(Color(Color.from_hsv(color.h, maxf(color.s, 0.6), 0.95), 1.0) if comic else color)
	if comic:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.next_pass = ink_material()
	var ghost := Node3D.new()
	parent.add_child(ghost)
	var poses := {}  # his skeleton -> a frozen copy of its pose: skinned on the GPU, not baked
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var flashing := _flash_mat != null and mi.material_overlay == _flash_mat
		if not mi.is_visible_in_tree() or mi.mesh == null or flashing or mi.has_meta("no_ghost"):  # (no_ghost: effects riding on him)
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		copy.material_override = mat
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
		copy.global_transform = mi.global_transform
		var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi.skin else null
		if skel != null:
			if not poses.has(skel):
				poses[skel] = _frozen_pose(skel, ghost)
			copy.skin = mi.skin
			copy.skeleton = copy.get_path_to(poses[skel])
		elif mi.skin:
			copy.mesh = mi.bake_mesh_from_current_skeleton_pose()
	var tw := ghost.create_tween()
	if comic:
		tw.tween_interval(COMIC_GHOST_STEP)
		tw.tween_callback(func() -> void: mat.albedo_color = ComicLook.INK)
		tw.tween_interval(maxf(time - COMIC_GHOST_STEP, COMIC_GHOST_STEP))
	else:
		tw.tween_property(mat, "albedo_color:a", 0.0, time)
	tw.tween_callback(ghost.queue_free)


## A Skeleton3D under `parent` holding `skel`'s current pose. Baking a skinned
## mesh on the CPU (bake_mesh_from_current_skeleton_pose) took ~18 ms for the
## heretic; a copied pose lets the GPU skin the shared mesh as usual.
static func _frozen_pose(skel: Skeleton3D, parent: Node3D) -> Skeleton3D:
	var copy := Skeleton3D.new()
	for i in skel.get_bone_count():
		copy.add_bone(skel.get_bone_name(i))
	for i in skel.get_bone_count():
		copy.set_bone_parent(i, skel.get_bone_parent(i))
		copy.set_bone_rest(i, skel.get_bone_rest(i))
	for i in skel.get_bone_count():  # global poses: they include the rig's sway and spring bones (parents come first)
		copy.set_bone_global_pose(i, skel.get_bone_global_pose(i))
	parent.add_child(copy)
	copy.global_transform = skel.global_transform
	return copy


## Briefly paint every mesh under `root` white.
static func flash(root: Node, duration := 0.08) -> void:
	if Game.comic_style and not Game.reduce_flashing and _own_inks(root).size() > 0:
		flash_tint(root, COMIC_FLASH, duration)  # (a foe: its ink flashes, not a white blob over it)
		return
	if _flash_mat == null:
		_flash_mat = unshaded_mat()
	_flash_mat.albedo_color = Color(1, 1, 1, 0.3 if Game.reduce_flashing else 0.85)
	_overlay(root, _flash_mat, duration)


## flash() in a colour (enemy hit confirms in the hero's element): one shared
## overlay per colour, so a crowd flashing together costs one material.
static func flash_tint(root: Node, color: Color, duration := 0.08) -> void:
	var key := color.to_rgba32()
	if not _tint_mats.has(key):
		_tint_mats[key] = unshaded_mat()
	var mat: StandardMaterial3D = _tint_mats[key]
	mat.albedo_color = Color(color, 0.3 if Game.reduce_flashing else 0.85)
	if Game.comic_style and not Game.reduce_flashing and _own_inks(root).size() > 0:
		# Comic: the foe's own ink goes paper, then his colour, for two short steps, round its own tones.
		# An overlay fill (even a solid one) turned each foe into a flat inkless blob over a zapped crowd.
		var inks := _own_inks(root)
		var tone := Color.from_hsv(color.h, maxf(color.s, 0.6), 1.0)
		for ink: ShaderMaterial in inks:
			ink.set_shader_parameter("outline_color", COMIC_FLASH)
		var tree := root.get_tree()  # (held: root may be freed during the wait; the inks are kept alive here)
		await tree.create_timer(duration * 0.5, true, false, true).timeout
		if not is_instance_valid(root):
			return
		for ink: ShaderMaterial in inks:
			ink.set_shader_parameter("outline_color", tone)
		await tree.create_timer(duration * 0.5, true, false, true).timeout
		if not is_instance_valid(root):
			return
		for ink: ShaderMaterial in inks:
			ink.set_shader_parameter("outline_color", ComicLook.INK)
		return
	_overlay(root, mat, duration)


## Lays `mat` over every mesh under `root` for `duration`. If `root` leaves the tree first (a foe freed
## a frame after its hit), the overlay comes off as it goes: freed with an overlay still on, each mesh
## printed "Parameter material is null" (agents.md).
static func _overlay(root: Node, mat: Material, duration: float) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		mi.material_overlay = mat
	var clear := func() -> void:
		for mi in meshes:  # (untyped: a mesh freed during the wait can't be assigned to a typed loop variable)
			if is_instance_valid(mi) and mi.material_overlay == mat:
				mi.material_overlay = null
	root.tree_exiting.connect(clear, CONNECT_ONE_SHOT)
	await root.get_tree().create_timer(duration, true, false, true).timeout
	if is_instance_valid(root) and root.tree_exiting.is_connected(clear):
		root.tree_exiting.disconnect(clear)
		clear.call()


## The outline materials of `root`'s own (outline_own), not the shared one: what a comic flash recolours.
static func _own_inks(root: Node) -> Array:
	var out := []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k)
			var ink: Material = m.next_pass if m != null else null
			if ink is ShaderMaterial and ink != _outline_mat and not out.has(ink):
				out.append(ink)
	return out


## Drop cached materials so nothing is left alive at exit.
static func release() -> void:
	_flash_mat = null
	_tint_mats.clear()
	_star_mesh = null
	_rim_mat = null
	_outline_mat = null
	_outlined.clear()
	_particle_mats.clear()
	COMIC_POP.release()
	ComicLook.release()


## Give every mesh under `root` a dark toon outline (inverted hull pass).
## The outline material Fx.outline puts on the hero, for something built later (void_tendril.gd).
static func ink_material() -> Material:
	return _outline_mat


static func outline(root: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return  # the dummy renderer errors on the shared override materials at exit
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://shaders/outline.gdshader")
	if Game.comic_style:  # thicker, darker ink, swelling over the form like a brush
		_outline_mat.set_shader_parameter("width_px", COMIC_INK_PX)
		_outline_mat.set_shader_parameter("wobble", COMIC_INK_WOBBLE)
		_outline_mat.set_shader_parameter("depth_push", COMIC_INK_PUSH)
		_outline_mat.set_shader_parameter("outline_color", ComicLook.INK)
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			if src == null:
				continue
			if not _outlined.has(src):
				var copy: Material = src.duplicate()
				copy.next_pass = _outline_mat
				_outlined[src] = copy
			mi.set_surface_override_material(i, _outlined[src])


## Fx.outline with an outline material of `root`'s own (enemy.gd thickens it
## on big hits): each surface gets its own copy, so one character's ink can
## change width alone. Returns that material (null headless, as outline()).
static func outline_own(root: Node) -> ShaderMaterial:
	if DisplayServer.get_name() == "headless":
		return null
	outline(root)  # sets up the shared material's look (comic width, wobble, ink)
	var own: ShaderMaterial = _outline_mat.duplicate()
	var copies := {}  # this character's shared copy -> its own copy
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var shared := mi.get_surface_override_material(i)
			if shared == null or shared.next_pass != _outline_mat:
				continue
			if not copies.has(shared):
				var copy: Material = shared.duplicate()
				copy.next_pass = own
				copies[shared] = copy
			mi.set_surface_override_material(i, copies[shared])
	return own


## Telegraph rim: a light ring just inside radius r (EDGE_WIDTH) with a dark
## outline just outside it (EDGE_OUTLINE), so attack areas read on bright tiles
## without relying on colour. Add it under the telegraph mesh; colour it each
## frame with pulse_edge().
static func edge_ring(r: float) -> MeshInstance3D:
	var edge := MeshInstance3D.new()
	var outline := MeshInstance3D.new()
	edge.add_child(outline)
	for mi: MeshInstance3D in [edge, outline]:
		var torus := TorusMesh.new()
		torus.rings = 48
		torus.ring_segments = 4
		torus.material = unshaded_mat()
		mi.mesh = torus
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(outline.mesh.material as StandardMaterial3D).albedo_color = Color(0.05, 0.02, 0.05, 0.8)
	edge.scale = Vector3(1.0, 0.3, 1.0)
	fit_edge(edge, r)
	return edge


static func fit_edge(edge: MeshInstance3D, r: float) -> void:
	var rim := edge.mesh as TorusMesh
	rim.inner_radius = maxf(r - EDGE_WIDTH, 0.01)
	rim.outer_radius = r
	var dark := (edge.get_child(0) as MeshInstance3D).mesh as TorusMesh
	dark.inner_radius = r
	dark.outer_radius = r + EDGE_OUTLINE


## Light rim in `color`'s hue, pulsing with `t` (cycles), fading with color.a.
static func pulse_edge(edge: MeshInstance3D, color: Color, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * TAU)
	var mat := (edge.mesh as TorusMesh).material as StandardMaterial3D
	mat.albedo_color = Color(color.lerp(Color.WHITE, 0.7), lerpf(0.4, 1.0, pulse) * minf(color.a * 2.2, 1.0))


static func rim_material() -> ShaderMaterial:
	if _rim_mat == null:
		_rim_mat = ShaderMaterial.new()
		_rim_mat.shader = load("res://shaders/rim_glow.gdshader")
	return _rim_mat
