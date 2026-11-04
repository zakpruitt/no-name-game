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

static var _flash_mat: StandardMaterial3D
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


static func damage_number(parent: Node, pos: Vector3, amount: float, big := false) -> void:
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
	flare(parent, at, Color(1.0, 0.5, 0.08), 3.6 if big else 2.4, 0.15, "flare")
	flare(parent, at, Color(1.0, 0.97, 0.85), 1.2 if big else 0.8, 0.08, "dot", true)
	flare(parent, at, Color(1.0, 0.6, 0.2, 0.9), 2.2 if big else 1.4, 0.2, "ring")
	burst(parent, at, Color(1.0, 0.6, 0.15), 24 if big else 14, 14.0 if big else 10.0, 0.22, 0.35, dir, 50.0)
	burst(parent, at, Color(1.0, 0.97, 0.85), 8 if big else 4, 18.0, 0.18, 0.2, dir, 30.0, 0.0, 0.0, "dot", true)
	if big:
		last_big_hit_ms = Time.get_ticks_msec()


static func dust(parent: Node, pos: Vector3, amount := 10, size := 0.45) -> void:
	burst(parent, pos + Vector3.UP * 0.2, Color(0.62, 0.57, 0.5, 0.6), amount, 4.0, size, 0.55, Vector3.UP, 80.0, 1.0, 0.45, "smoke")


## Expanding flat ring on the ground (shockwaves, Awakening burst).
static func ring(parent: Node, pos: Vector3, color: Color, radius: float, time := 0.35) -> void:
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


## Burn mark on the floor: a ragged scorch decal that flashes in `color`, cools to
## soot and fades over `time` (Cataclysm, fire waves). Blend mix so it reads on light tiles.
static func scorch(parent: Node, pos: Vector3, color: Color, radius: float, time := 1.2) -> void:
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
	last_afterimage_ms = Time.get_ticks_msec()
	var mat := unshaded_mat(color)
	var ghost := Node3D.new()
	parent.add_child(ghost)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var flashing := _flash_mat != null and mi.material_overlay == _flash_mat
		if not mi.is_visible_in_tree() or mi.mesh == null or flashing or mi.has_meta("no_ghost"):  # (no_ghost: effects riding on him)
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = mi.bake_mesh_from_current_skeleton_pose() if mi.skin else mi.mesh
		copy.material_override = mat
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
		copy.global_transform = mi.global_transform
	var tw := ghost.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, time)
	tw.tween_callback(ghost.queue_free)


## Briefly paint every mesh under `root` white.
static func flash(root: Node, duration := 0.08) -> void:
	if _flash_mat == null:
		_flash_mat = unshaded_mat()
	_flash_mat.albedo_color = Color(1, 1, 1, 0.3 if Game.reduce_flashing else 0.85)
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		mi.material_overlay = _flash_mat
	await root.get_tree().create_timer(duration, true, false, true).timeout
	for mi in meshes:  # (untyped: a mesh freed during the wait can't be assigned to a typed loop variable)
		if is_instance_valid(mi) and mi.material_overlay == _flash_mat:
			mi.material_overlay = null


## Drop cached materials so nothing is left alive at exit.
static func release() -> void:
	_flash_mat = null
	_rim_mat = null
	_outline_mat = null
	_outlined.clear()
	_particle_mats.clear()
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
