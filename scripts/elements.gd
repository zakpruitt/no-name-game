extends RefCounted
## The shaman's elements. Every attack summons the hero's element alongside
## the axes (spirit before an Ascendancy, then wind / earth / water), and the
## Awakened ultimates (player.ULTIMATES) are built from the same pieces.
## CASTS is the per-move tuning; LOOK is each element's palette. Effects only
## deal damage where a caller passes it (hit_area, Bolt.damage).
##   bolt     flying blade that pierces: wind/spirit crescent, water ice
##            shards, earth a run of stone spikes along the ground
##   pillar   column at a point: tornado / stone pillar / geyser / spirit beam
##   fissure  a march of small pillars or spikes along a line
##   nova     burst all around: spikes or blades outward
##   vortex   pieces whirling round the hero during the spin
##   echo     the axe's bound spirit finishes the swing: a giant spectral axe
##            sweeping the same arc a beat later (spirit_echo.gd; L1, L2 bigger)
##   cleave   two colossal spectral axes rise either side of the target and slam
##            inward, meeting in a V on it: blast round the heads (spirit_cleave.gd; L3)
##   avatar   a towering spectral copy of the shaman rises round him and brings
##            the great axe down ahead: blast + the element's nova (spirit_avatar.gd; CH)
##   crown    three colossal spectral axes burst blade-up from the floor under the
##            target round the element's column, launching it (spirit_crown.gd; LH)
##   rift     a wave of colossal spectral axes bursting from the floor one after
##            another along the thrust, growing (spirit_rift.gd; LLH)
##   wheel    a ring of giant spectral axes laid flat like a sawblade, whirling
##            round the hero through the spin, grinding (spirit_wheel.gd; H, DH)
##   tomahawk giant spectral axe flung spinning flat like a sawblade, piercing out
##            to `range` and boomeranging back to the hero (spirit_tomahawk.gd; DL, LPL fan)
##   guillotine colossal spectral axe dropping blade-first from the sky onto the
##            target and burying itself in the floor (spirit_guillotine.gd; LHH)
##   Orbit    motes circling the hero (a few at rest, more while Awakened)

const CASTS := {
	"L1": {"kind": "echo", "damage": 5.0, "radius": 3.4, "arc": 160.0, "delay": 0.05, "time": 0.18},
	"L2": {"kind": "echo", "damage": 6.0, "radius": 3.9, "arc": 200.0, "delay": 0.04, "time": 0.2},
	"AL1": {"kind": "echo", "damage": 4.0, "radius": 3.2, "arc": 170.0, "delay": 0.05, "time": 0.18},
	"AL2": {"kind": "echo", "damage": 5.0, "radius": 3.6, "arc": 210.0, "delay": 0.04, "time": 0.2},
	"AL3": {"kind": "echo", "damage": 4.0, "radius": 3.8, "arc": 240.0, "delay": 0.03, "time": 0.18},
	"L3": {"kind": "cleave", "damage": 12.0, "reach": 5.0, "ahead": 3.0, "size": 3.2, "blast": 2.8, "launch": 4.0},
	"DL": {"kind": "tomahawk", "damage": 6.0, "back_damage": 4.0, "range": 8.0, "size": 2.6},
	"LPL": {"kind": "tomahawk", "damage": 4.0, "back_damage": 3.0, "range": 6.5, "size": 1.5, "fan": 2, "spread": 34.0},
	"H": {"kind": "wheel", "radius": 3.1, "time": 0.95, "count": 4, "turns": 2.5, "damage": 2.0},
	"DH": {"kind": "wheel", "radius": 3.0, "time": 0.9, "count": 6, "turns": 3.0, "damage": 2.0},
	"LH": {"kind": "crown", "damage": 6.0, "radius": 1.9, "height": 4.0, "launch": 9.0, "reach": 4.5, "ahead": 2.4, "size": 3.4},
	"LHH": {"kind": "guillotine", "damage": 7.0, "radius": 2.4, "size": 3.8, "reach": 4.5, "ahead": 2.0},
	"CH": {"kind": "avatar", "damage": 14.0, "radius": 4.2, "launch": 8.0, "size": 3.0},
}
## color: main glow; glow: hot core; rock: solid pieces (earth).
const LOOK := {
	"spirit": {"color": Color(0.3, 0.95, 0.85), "glow": Color(1.0, 0.88, 0.5), "sfx": "cast_spirit"},
	"wind": {"color": Color(0.5, 1.0, 0.55), "glow": Color(0.92, 1.0, 0.9), "sfx": "cast_wind"},
	"earth": {"color": Color(1.0, 0.38, 0.08), "glow": Color(1.0, 0.78, 0.3), "rock": Color(0.2, 0.16, 0.15), "sfx": "cast_earth"},
	"water": {"color": Color(0.4, 0.78, 1.0), "glow": Color(0.88, 0.97, 1.0), "sfx": "cast_water"},
}
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const ORBIT_REST := 3
const ORBIT_AWAKENED := 7

static var _mats := {}
static var _meshes := {}
static var casts := 0  # casts summoned (autotest)


## Drop cached materials and meshes so nothing is left alive at exit (Game._exit_tree).
static func release() -> void:
	SPIRIT_ECHO._form_meshes.clear()
	_mats.clear()
	_meshes.clear()


## Draw every element material once, hidden under the hero, so their shaders
## compile at load instead of hitching the first cast or ultimate.
static func prewarm(parent: Node, at: Vector3) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at + Vector3.DOWN * 0.3
	root.scale = Vector3.ONE * 0.05
	for el: String in LOOK:
		root.add_child(piece(el))
		var c: Color = LOOK[el].color
		for hdr in [1.0, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 2.0, 2.2, 2.5, 3.0]:
			root.add_child(_mi(crescent(0.16), glow(Color(c, 0.5), hdr)))
	root.add_child(_mi(crescent(0.16), ice()))
	root.add_child(_mi(crescent(0.16), rock()))
	# Ascendancy's finisher pieces (magma, volcano, glacier, bombs).
	var lit := StandardMaterial3D.new()
	lit.emission_enabled = true
	var box := BoxMesh.new()
	for mat: Material in [Ascendancy.glow_mat(Color.WHITE), Ascendancy.glow_mat(Color.WHITE, 0.5), lit]:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		root.add_child(mi)
	gather(root, at, Color.WHITE, 0.1, 1)
	# Fx sprite materials (particle textures, flares, ground ring).
	for tex: String in ["dot", "smoke", "spark"]:
		for add: bool in [false, true]:
			Fx.burst(root, at, Color.WHITE, 1, 0.0, 0.01, 0.1, Vector3.UP, 0.0, 0.0, 0.0, tex, add)
	Fx.flare(root, at, Color.WHITE, 0.01, 0.1, "flare")
	Fx.flare(root, at, Color.WHITE, 0.01, 0.1, "dot", true)
	Fx.flare(root, at, Color.WHITE, 0.3, 0.1, "dot")  # projectile halo variant
	Fx.flare(root, at, Color.WHITE, 0.3, 0.1, "star8")
	Fx.flare(root, at, Color.WHITE, 0.3, 0.1, "ring")
	Fx.ring(root, at, Color.WHITE, 0.01, 0.1)
	Fx.scorch(root, at, Color.WHITE, 0.3, 0.1)
	# Real sizes (the root is scaled to 5%): sub-pixel draws may skip the compile.
	Fx.swoosh(root, at, Vector3.FORWARD, 1.0, 90.0, Color.WHITE, false, 0.15)
	Fx.shards(root, at, Color.WHITE, 2, Vector3.UP, 0.0, 0.3, 0.15)
	Fx.dash_streak(root, at, Vector3.FORWARD, 1.0, Color.WHITE, 0.15)
	Fx.beam(root, at, Color.WHITE, 1.0, 0.3, 0.15)
	root.add_child(_mi(funnel(0.3, 0.1, 0.5), swirl_mat(LOOK.wind.color)))
	root.add_child(_mi(funnel(0.3, 0.1, 0.5), swirl_mat(LOOK.wind.color, true)))
	root.add_child(_mi(funnel(0.3, 0.1, 0.5), swirl_mat(LOOK.water.color, true, 0.6, 5.0)))
	root.add_child(_mi(funnel(0.3, 0.1, 0.5), swirl_mat(LOOK.spirit.color, true, 3.0, 2.0)))
	root.add_child(_mi(funnel(0.3, 0.1, 0.5), swirl_mat(Color(0.95, 0.25, 0.05))))  # Cataclysm vortex
	root.add_child(_mi(funnel(0.3, 0.1, 0.5), swirl_mat(Color(0.95, 0.25, 0.05), true)))
	var ghost: MeshInstance3D = SPIRIT_ECHO.ghost(BoxMesh.new(), Color.WHITE)  # spirit casts
	ghost.material_override.albedo_color.a = 0.5
	root.add_child(ghost)
	var ribbon := MeshInstance3D.new()  # the weapon trail's shader (it draws nothing until a swing)
	ribbon.mesh = QuadMesh.new()
	var ribbon_mat := ShaderMaterial.new()
	ribbon_mat.shader = load("res://shaders/weapon_trail.gdshader")
	ribbon_mat.set_shader_parameter("noise", Fx.NOISE)
	ribbon.material_override = ribbon_mat
	root.add_child(ribbon)
	var l := OmniLight3D.new()
	l.light_energy = 0.01
	root.add_child(l)
	var tw := root.create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(root.queue_free)


static func color(el: String) -> Color:
	return LOOK[el].color


# --- Materials and meshes -----------------------------------------------------

## Unshaded colour; fade instances with `transparency`. `hdr` > 1 pushes
## it past white so the environment's glow blooms it (hot cores); `add`
## blends additively (only for small bright bits: on the light floor tiles
## big additive shapes wash out to white).
static func glow(c: Color, hdr := 1.0, add := false) -> StandardMaterial3D:
	var key := "g%s%.1f%s" % [c.to_html(), hdr, add]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(c.r * hdr, c.g * hdr, c.b * hdr, c.a)
		_mats[key] = m
	return _mats[key]


## Open cone for the wind funnels: wide at the top, narrow at the base.
static func funnel(top: float, bottom: float, height: float) -> CylinderMesh:
	var key := "funnel%.2f_%.2f_%.2f" % [top, bottom, height]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.cap_top = false
		m.cap_bottom = false
		m.radial_segments = 18
		m.rings = 6
		_meshes[key] = m
	return _meshes[key]


## Swirling band shader for the wind funnels (shaders/swirl.gdshader) in colour
## `c`: a darker body so it reads on the light floor, bright streaks over it.
## `inner` = the faster, brighter inner funnel.
## `twist` = turns a band makes over the height (low = a straight jet), `bands` > 0 overrides the count.
static func swirl_mat(c: Color, inner := false, twist := 1.6, bands := 0.0) -> ShaderMaterial:
	var key := "swirl%s%s%.1f%.1f" % [c.to_html(), inner, twist, bands]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/swirl.gdshader")
		m.set_shader_parameter("noise", Fx.NOISE)
		# Deep but saturated: darkening alone turns pale green muddy grey.
		var body := Color.from_hsv(c.h, 0.85, 0.6 if not inner else 0.85)
		m.set_shader_parameter("body_color", Color(body, 0.62 if not inner else 0.4))
		m.set_shader_parameter("streak_color", c.lerp(Color.WHITE, 0.6))
		m.set_shader_parameter("speed", 2.2 if not inner else 3.5)
		m.set_shader_parameter("bands", bands if bands > 0.0 else (3.0 if not inner else 2.0))
		m.set_shader_parameter("twist", twist)
		_mats[key] = m
	return _mats[key]


## Dark stone with glowing magma seams.
static func rock() -> StandardMaterial3D:
	if not _mats.has("rock"):
		var m := StandardMaterial3D.new()
		m.albedo_color = LOOK.earth.rock
		m.roughness = 0.95
		m.emission_enabled = true
		m.emission = Color(0.35, 0.06, 0.0)
		_mats["rock"] = m
	return _mats["rock"]


## Translucent shiny ice.
static func ice() -> StandardMaterial3D:
	if not _mats.has("ice"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.5, 0.82, 1.0, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.08
		m.metallic_specular = 1.0
		m.emission_enabled = true
		m.emission = Color(0.3, 0.65, 1.0)
		m.emission_energy_multiplier = 1.4
		m.rim_enabled = true
		m.rim = 1.0
		_mats["ice"] = m
	return _mats["ice"]


## Flat crescent in the XZ plane bulging toward +Z, radius 1, `width` thick in the middle.
static func crescent(width: float) -> ArrayMesh:
	var key := "cres%.2f" % width
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	var half := deg_to_rad(70.0)
	var prev_out := Vector3.ZERO
	var prev_in := Vector3.ZERO
	for i in n + 1:
		var t := float(i) / n
		var a := lerpf(-half, half, t)
		var d := Vector3(sin(a), 0.0, cos(a))
		var w := width * pow(sin(PI * t), 0.7)
		var o := d
		var inn := d * (1.0 - w)
		if i > 0:
			st.add_vertex(prev_out)
			st.add_vertex(o)
			st.add_vertex(prev_in)
			st.add_vertex(prev_in)
			st.add_vertex(o)
			st.add_vertex(inn)
		prev_out = o
		prev_in = inn
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


static func _spike_mesh(radius: float, height: float, sides: int) -> CylinderMesh:
	var key := "sp%.2f_%.2f_%d" % [radius, height, sides]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = radius
		m.height = height
		m.radial_segments = sides
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## A piece of the element (orbit motes, vortex pieces): wisp, leaf blade, rock chunk or ice shard.
static func piece(el: String, size := 1.0) -> Node3D:
	var root := Node3D.new()
	match el:
		"earth":
			var b := BoxMesh.new()
			b.size = Vector3.ONE * 0.22 * size
			var r := _mi(b, rock())
			r.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
			root.add_child(r)
			var s := SphereMesh.new()
			s.radius = 0.09 * size
			s.height = 0.18 * size
			root.add_child(_mi(s, glow(LOOK.earth.color, 2.5)))
		"water":
			var sh := _mi(_spike_mesh(0.07 * size, 0.42 * size, 5), ice())
			sh.rotation = Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
			root.add_child(sh)
		"wind":
			var c := _mi(crescent(0.35), glow(LOOK.wind.color, 1.6))
			c.scale = Vector3.ONE * 0.28 * size
			c.rotation = Vector3(0.0, 0.0, 0.5)
			root.add_child(c)
		_:
			var s := SphereMesh.new()
			s.radius = 0.08 * size
			s.height = 0.16 * size
			root.add_child(_mi(s, glow(LOOK.spirit.glow, 3.0)))
			var halo := SphereMesh.new()
			halo.radius = 0.16 * size
			halo.height = 0.32 * size
			var h := _mi(halo, glow(Color(LOOK.spirit.color, 0.4), 1.3))
			root.add_child(h)
	return root


static func _fade_free(node: Node3D, delay: float, time: float) -> void:
	var tw := node.create_tween()
	tw.tween_interval(delay)
	var first := true
	for gi: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false):
		if not first:
			tw.parallel()
		tw.tween_property(gi, "transparency", 1.0, time)
		first = false
	tw.tween_callback(node.queue_free)


## A short burst of light in the element's colour (big casts and ultimates).
static func light_pop(parent: Node, pos: Vector3, c: Color, energy := 5.0, reach := 7.0, time := 0.35) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy * (0.4 if Game.reduce_flashing else 1.0)
	l.omni_range = reach
	parent.add_child(l)
	l.global_position = pos + Vector3.UP * 1.5
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## Motes pulled in from all around `pos` (a charge-up before an ultimate).
static func gather(parent: Node, pos: Vector3, c: Color, radius := 3.0, amount := 30) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = amount
	p.lifetime = 0.45
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = radius
	p.gravity = Vector3.ZERO
	p.radial_accel_min = -radius * 9.0
	p.radial_accel_max = -radius * 7.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	fade.colors = PackedColorArray([Color(c, 0.0), c, Color(c.lightened(0.5), 1.0)])
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.32
	quad.material = Fx.particle_mat("dot", true)  # soft round sprite
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = parent.to_local(pos) if parent is Node3D else pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Damage everything within `radius` of `pos`; `on_hit` gets each enemy hit. Returns the count.
static func hit_area(tree: SceneTree, pos: Vector3, radius: float, damage: float, launch: float, big: bool,
		source: String, on_hit := Callable()) -> int:
	var n := 0
	for e in Ascendancy.enemies_near(tree, pos, radius):
		var kb: Vector3 = e.global_position - pos
		kb.y = 0.0
		e.take_hit(damage, kb.normalized() * 4.0, launch, big)
		Game.register_hit(source)
		if on_hit.is_valid():
			on_hit.call(e)
		n += 1
	return n


# --- Pieces of casts ----------------------------------------------------------

## A column at `pos`: tornado (wind), stone pillar (earth), geyser (water), beam (spirit).
static func pillar(parent: Node, pos: Vector3, el: String, height := 4.0, radius := 1.4, life := 0.6) -> void:
	var c: Color = LOOK[el].color
	var g: Color = LOOK[el].glow
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	match el:
		"wind":
			# Two nested swirling funnels, spinning against each other.
			var outer := _mi(funnel(radius * 1.1, radius * 0.25, height), swirl_mat(c))
			outer.position.y = height * 0.5
			root.add_child(outer)
			var inner := _mi(funnel(radius * 0.6, radius * 0.12, height * 0.85), swirl_mat(c, true))
			inner.position.y = height * 0.425
			root.add_child(inner)
			var spin := root.create_tween().set_parallel()
			spin.tween_property(outer, "rotation:y", TAU * 2.0, life)
			spin.tween_property(inner, "rotation:y", -TAU * 3.0, life)
			root.scale = Vector3(0.2, 0.6, 0.2)
			spin.tween_property(root, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			Fx.ring(parent, root.global_position, Color(c.darkened(0.25), 0.85), radius * 1.4, 0.3)
			Fx.burst(parent, root.global_position + Vector3.UP * 0.5, c, 18, 9.0, 0.14, 0.5, Vector3.UP, 25.0, 4.0, radius * 0.6)
		"earth":
			var col := CylinderMesh.new()
			col.top_radius = radius * 0.6
			col.bottom_radius = radius * 0.8
			col.height = height * 0.75
			col.radial_segments = 6
			col.rings = 1
			var stone := _mi(col, rock())
			stone.position.y = -col.height * 0.5
			root.add_child(stone)
			var t := TorusMesh.new()
			t.inner_radius = radius * 0.75
			t.outer_radius = radius * 1.15
			var ring := _mi(t, glow(c, 2.2))
			ring.position.y = 0.05
			ring.scale.y = 0.2
			root.add_child(ring)
			var cap := CylinderMesh.new()
			cap.top_radius = radius * 0.62
			cap.bottom_radius = radius * 0.62
			cap.height = 0.08
			cap.radial_segments = 6
			var hot := _mi(cap, glow(c, 2.5))
			hot.position.y = col.height * 0.5
			stone.add_child(hot)
			var tw := stone.create_tween()
			tw.tween_property(stone, "position:y", col.height * 0.5, 0.08).set_ease(Tween.EASE_OUT)
			tw.tween_interval(life * 0.6)
			tw.tween_property(stone, "position:y", -col.height * 0.5, life * 0.4).set_ease(Tween.EASE_IN)
			Fx.burst(parent, root.global_position + Vector3.UP * 0.4, LOOK.earth.rock.lightened(0.2), 14, 10.0, 0.22, 0.6, Vector3.UP, 45.0, -25.0)
			Fx.burst(parent, root.global_position + Vector3.UP * 0.2, c, 16, 8.0, 0.1, 0.45, Vector3.UP, 60.0, -8.0)
			Fx.dust(parent, root.global_position, 10, 0.8)
		"water":
			var col := CylinderMesh.new()
			col.top_radius = radius * 1.0
			col.bottom_radius = radius * 0.55
			col.height = height
			col.cap_top = false
			col.cap_bottom = false
			var spout := _mi(col, swirl_mat(c, true, 0.6, 5.0))  # a twisting jet of water bands (bright body: deep reads as metal)
			spout.position.y = height * 0.5
			root.add_child(spout)
			var inner := CylinderMesh.new()
			inner.top_radius = radius * 0.28
			inner.bottom_radius = radius * 0.18
			inner.height = height * 1.1
			var core := _mi(inner, glow(Color(g, 0.55), 1.6))  # thin: a fat white core hides the jet
			core.position.y = height * 0.55
			root.add_child(core)
			root.scale = Vector3(1.0, 0.1, 1.0)
			root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)
			Fx.burst(parent, root.global_position + Vector3.UP * height, Color(0.9, 0.97, 1.0), 24, 9.0, 0.18, 0.7, Vector3.UP, 70.0, -18.0)
			Fx.burst(parent, root.global_position + Vector3.UP * 0.2, c, 14, 6.0, 0.25, 0.5, Vector3.UP, 85.0, -6.0, radius * 0.5)
		_:
			var beam := CylinderMesh.new()
			beam.top_radius = radius * 0.6
			beam.bottom_radius = radius * 0.45
			beam.height = height * 1.4
			beam.cap_top = false
			beam.cap_bottom = false
			var outer := _mi(beam, swirl_mat(c, true, 3.0, 2.0))  # tight fast spiral round the core
			outer.position.y = height * 0.7
			root.add_child(outer)
			var thin := CylinderMesh.new()
			thin.top_radius = radius * 0.2
			thin.bottom_radius = radius * 0.2
			thin.height = height * 1.4
			var core := _mi(thin, glow(Color(g, 0.9), 2.5))
			core.position.y = height * 0.7
			root.add_child(core)
			root.scale = Vector3(0.1, 1.0, 0.1)
			root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.08).set_ease(Tween.EASE_OUT)
			Fx.burst(parent, root.global_position + Vector3.UP * 0.4, g, 18, 7.0, 0.12, 0.6, Vector3.UP, 30.0, 3.0, radius * 0.5)
	_fade_free(root, life * 0.5, life * 0.5)


## A cluster of spikes bursting up at `pos`: stone (earth) or ice (water); others make a small pillar.
static func spikes(parent: Node, pos: Vector3, el: String, size := 1.0, count := 3, life := 0.7) -> void:
	if el not in ["earth", "water"]:
		pillar(parent, pos, el, 2.2 * size, 0.7 * size, life * 0.7)
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	var mat := rock() if el == "earth" else ice()
	for i in count:
		var h := randf_range(1.0, 1.8) * size
		var s := _mi(_spike_mesh(randf_range(0.22, 0.34) * size, h, 5), mat)
		var off := Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4)) * size if i > 0 else Vector3.ZERO
		s.position = off + Vector3.UP * -h * 0.5
		s.rotation = Vector3(off.z * 0.8, randf() * TAU, -off.x * 0.8)
		root.add_child(s)
		var tw := s.create_tween()
		tw.tween_interval(i * 0.03)
		tw.tween_property(s, "position:y", h * 0.45, 0.07).set_ease(Tween.EASE_OUT)
		tw.tween_interval(life * 0.6)
		tw.tween_property(s, "position:y", -h * 0.5, life * 0.3).set_ease(Tween.EASE_IN)
	var c: Color = LOOK[el].color
	Fx.burst(parent, root.global_position + Vector3.UP * 0.3, c, 8, 6.0, 0.12, 0.35, Vector3.UP, 60.0, -10.0)
	if el == "earth":
		Fx.dust(parent, root.global_position, 5, 0.6)
	else:
		Fx.burst(parent, root.global_position + Vector3.UP * 0.2, Color(0.9, 0.97, 1.0), 8, 4.0, 0.2, 0.5, Vector3.UP, 90.0, 0.0, 0.4)
	var t := root.create_tween()
	t.tween_interval(life + 0.1)
	t.tween_callback(root.queue_free)


## Spikes or small pillars marching from `from` along `dir`.
static func fissure(parent: Node, from: Vector3, dir: Vector3, length: float, steps: int, el: String, size := 1.0, step_time := 0.035) -> void:
	for i in steps:
		var at := from + dir * (1.0 + i * (length - 1.0) / maxf(steps - 1, 1))
		var tw := parent.create_tween()
		tw.tween_interval(i * step_time)
		tw.tween_callback(spikes.bind(parent, at, el, size * lerpf(0.8, 1.2, float(i) / steps)))


## Burst all around `pos`: a ring of spikes (earth, water) or blades flying outward (wind, spirit).
static func nova(parent: Node, pos: Vector3, el: String, radius: float, count: int) -> void:
	var c: Color = LOOK[el].color
	Fx.ring(parent, pos, Color(c, 0.95), radius, 0.35)
	Fx.ring(parent, pos, Color(LOOK[el].glow, 0.8), radius * 0.55, 0.25)
	light_pop(parent, pos, c, 6.0, radius * 1.8)
	for i in count:
		var ang := TAU * i / count
		var d := Vector3(sin(ang), 0.0, cos(ang))
		if el in ["earth", "water"]:
			spikes(parent, pos + d * radius * 0.65, el, 1.0, 2)
		else:
			var b := Bolt.new()
			b.el = el
			b.dir = d
			b.speed = 18.0
			b.reach = radius
			b.size = 0.8
			parent.add_child(b)
			b.global_position = pos + d * 0.6 + Vector3.UP * 0.6
	Fx.burst(parent, pos + Vector3.UP * 0.3, c, 30, 10.0, 0.16, 0.45, Vector3.UP, 85.0, -6.0)


## Pieces whirling round `hero` for the spin.
static func vortex(hero: Node3D, el: String, radius: float, time: float) -> void:
	var root := Node3D.new()
	hero.add_child(root)
	root.position.y = 0.9
	var n := 7
	for i in n:
		var p := piece(el, 2.0)
		var ang := TAU * i / n
		p.position = Vector3(sin(ang), randf_range(-0.25, 0.35), cos(ang)) * Vector3(radius * 0.8, 1.0, radius * 0.8)
		p.rotation.y = ang + PI * 0.5
		root.add_child(p)
	var t := TorusMesh.new()
	t.inner_radius = radius * 0.85
	t.outer_radius = radius
	var ring := _mi(t, glow(Color(LOOK[el].color, 0.55), 1.4))
	ring.position.y = -0.75
	ring.scale.y = 0.15
	root.add_child(ring)
	root.scale = Vector3.ONE * 0.3
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "rotation:y", -TAU * 2.5, time)
	tw.tween_property(root, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)
	_fade_free(root, time * 0.65, time * 0.35)


## A jagged bolt from the sky onto `pos` (visual only).
static func lightning_fx(parent: Node, pos: Vector3, c: Color, height := 10.0) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	var prev := Vector3(randf_range(-1.0, 1.0), height, randf_range(-1.0, 1.0))
	var segs := 7
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := Vector3(randf_range(-0.6, 0.6) * (1.0 - t), height * (1.0 - t), randf_range(-0.6, 0.6) * (1.0 - t))
		for layer in 2:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.16 if layer == 0 else 0.06
			cyl.bottom_radius = cyl.top_radius
			cyl.height = prev.distance_to(p)
			cyl.radial_segments = 6
			cyl.rings = 1
			var seg := _mi(cyl, glow(Color(c, 0.7), 1.6) if layer == 0 else glow(Color(1, 1, 1, 0.95), 3.0))
			root.add_child(seg)
			seg.position = (prev + p) * 0.5
			var up := (prev - p).normalized()
			seg.basis = Basis(Quaternion(Vector3.UP, up))
		prev = p
	Fx.ring(parent, pos, Color(c, 0.9), 1.8, 0.25)
	Fx.burst(parent, root.global_position + Vector3.UP * 0.3, c, 14, 9.0, 0.14, 0.3, Vector3.UP, 80.0)
	light_pop(parent, pos, c, 7.0, 6.0, 0.2)
	_fade_free(root, 0.06, 0.16)


# --- Casts ---------------------------------------------------------------------

class Bolt extends Node3D:
	## Flying piercing blade. Hits each enemy once for `damage` (0 = visual only).
	var el := "spirit"
	var dir := Vector3.FORWARD
	var speed := 20.0
	var reach := 7.0
	var damage := 0.0
	var size := 1.0
	var tilt := 0.0
	var on_hit := Callable()
	var _dist := 0.0
	var _spike_d := 0.0
	var _hit := {}
	var _trail: CPUParticles3D
	const E := preload("res://scripts/elements.gd")

	func _ready() -> void:
		var look: Dictionary = E.LOOK[el]
		var body := Node3D.new()
		add_child(body)
		body.basis = Basis(Vector3.UP, atan2(dir.x, dir.z)) * Basis(Vector3.FORWARD, deg_to_rad(tilt))
		match el:
			"water":
				for i in 3:
					var s := E._mi(E._spike_mesh(0.14 * size, 1.25 * size, 5), E.ice())
					s.rotation.x = PI * 0.5
					s.position = Vector3((i - 1) * 0.32 * size, (0.12 if i == 1 else -0.05) * size, -0.15 * absf(i - 1) * size)
					body.add_child(s)
					var g := E._mi(E._spike_mesh(0.22 * size, 1.45 * size, 5), E.glow(Color(look.color, 0.35), 1.5))
					g.rotation.x = PI * 0.5
					g.position = s.position
					body.add_child(g)
			"earth":
				var s := SphereMesh.new()
				s.radius = 0.22 * size
				s.height = 0.44 * size
				body.add_child(E._mi(s, E.glow(look.color, 2.5)))
			_:
				var outer := E._mi(E.crescent(0.32), E.glow(Color(look.color, 0.9), 1.4))
				outer.scale = Vector3.ONE * 1.25 * size
				body.add_child(outer)
				var core := E._mi(E.crescent(0.16), E.glow(Color(look.glow, 1.0), 3.0))
				core.scale = Vector3.ONE * 1.2 * size
				core.position.y = 0.01
				body.add_child(core)
		_trail = CPUParticles3D.new()
		_trail.amount = 24
		_trail.lifetime = 0.35
		_trail.local_coords = false
		_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_trail.emission_sphere_radius = 0.5 * size
		_trail.gravity = Vector3(0.0, 2.0 if el != "earth" else -6.0, 0.0)
		_trail.initial_velocity_max = 1.0
		_trail.scale_amount_min = 0.6
		_trail.scale_amount_max = 1.3
		var fade := Gradient.new()
		fade.set_color(0, look.glow)
		fade.set_color(1, Color(look.color, 0.0))
		_trail.color_ramp = fade
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.28
		quad.material = Fx.particle_mat("dot", true)  # soft round sprite
		_trail.mesh = quad
		_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_trail)

	func _physics_process(delta: float) -> void:
		var step := speed * delta
		global_position += dir * step
		_dist += step
		if el == "earth":
			_spike_d += step
			if _spike_d >= 0.8:
				_spike_d = 0.0
				E.spikes(get_parent(), global_position, "earth", 0.75 * size, 2, 0.45)
		if damage > 0.0:
			for e in Ascendancy.enemies_near(get_tree(), global_position, 0.9 * size):
				if _hit.has(e):
					continue
				_hit[e] = true
				e.take_hit(damage, dir * 3.0, 0.0, false)
				Game.register_hit("cast")
				Fx.burst(get_parent(), e.global_position + Vector3.UP, E.LOOK[el].color, 10, 7.0, 0.14, 0.25, dir, 60.0)
				if on_hit.is_valid():
					on_hit.call(e)
		if _dist >= reach:
			set_physics_process(false)
			_trail.emitting = false
			for gi: GeometryInstance3D in find_children("*", "MeshInstance3D", true, false):
				create_tween().tween_property(gi, "transparency", 1.0, 0.1)
			var tw := create_tween()
			tw.tween_interval(0.4)
			tw.tween_callback(queue_free)


class Orbit extends Node3D:
	## Motes circling the hero: a few at rest, more and wider while Awakened.
	const E := preload("res://scripts/elements.gd")
	var _t := 0.0
	var _radius := 0.9
	var _spin := 2.0
	var piece_size := 1.0

	func setup(el: String, awakened: bool) -> void:
		for c in get_children():
			remove_child(c)
			c.queue_free()
		var n := E.ORBIT_AWAKENED if awakened else E.ORBIT_REST
		_radius = 1.25 if awakened else 0.85
		_spin = 3.2 if awakened else 1.6
		for i in n:
			add_child(E.piece(el, (1.3 if awakened else 0.9) * piece_size))

	func _process(delta: float) -> void:
		_t += delta
		var n := get_child_count()
		for i in n:
			var p: Node3D = get_child(i)
			var ang := _t * _spin + TAU * i / n
			p.position = Vector3(sin(ang) * _radius, 1.0 + sin(_t * 2.3 + i * 1.7) * 0.35, cos(ang) * _radius)
			p.rotation.y = ang + PI * 0.5


# --- Ultimates (player.ULTIMATES) ---------------------------------------------

## SKY lands at `pos`: the element's big impact (visual; the hero deals the damage).
static func sky_impact(parent: Node, pos: Vector3, el: String, radius: float) -> void:
	var c: Color = LOOK[el].color
	Fx.ring(parent, pos, Color(c, 0.95), radius + 1.0, 0.45)
	Fx.ring(parent, pos, Color(LOOK[el].glow, 0.9), radius * 0.6, 0.3)
	Fx.ring(parent, pos, Color(1, 1, 1, 0.7), radius * 0.3, 0.2)
	light_pop(parent, pos, c, 10.0, radius * 2.5, 0.5)
	Fx.dust(parent, pos, 24, 1.3)
	match el:
		"wind":
			pillar(parent, pos, el, 7.0, 2.4, 1.0)
			for i in 6:
				var ang := TAU * i / 6.0
				var at := pos + Vector3(sin(ang), 0.0, cos(ang)) * radius * 0.75
				var tw := parent.create_tween()
				tw.tween_interval(0.04 * i)
				tw.tween_callback(lightning_fx.bind(parent, at, c, 10.0))
		"earth":
			for i in 10:
				var ang := TAU * i / 10.0
				spikes(parent, pos + Vector3(sin(ang), 0.0, cos(ang)) * radius * 0.7, el, 1.5, 3, 1.1)
			Ascendancy.magma_pool(parent, pos, 2.4)
		"water":
			for i in 14:
				var ang := TAU * i / 14.0
				spikes(parent, pos + Vector3(sin(ang), 0.0, cos(ang)) * randf_range(1.2, radius), el, 1.6, 3, 1.4)
			spikes(parent, pos, el, 2.6, 5, 1.4)
		_:
			pillar(parent, pos, el, 9.0, 2.6, 1.0)
	Fx.burst(parent, pos + Vector3.UP * 0.5, c, 60, 16.0, 0.22, 0.7, Vector3.UP, 75.0, -10.0, 1.0)
	Fx.burst(parent, pos + Vector3.UP * 0.5, LOOK[el].glow, 30, 22.0, 0.14, 0.45, Vector3.UP, 120.0, -4.0)


## Earth's SKY: a meteor falls from the sky onto `pos` over `time`.
static func meteor(parent: Node, pos: Vector3, time: float) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	var from := pos + Vector3(-4.0, 16.0, -6.0)
	root.global_position = from
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	var core := _mi(s, rock())
	root.add_child(core)
	var h := SphereMesh.new()
	h.radius = 1.45
	h.height = 2.9
	root.add_child(_mi(h, glow(Color(LOOK.earth.color, 0.55), 2.0)))
	var trail := CPUParticles3D.new()
	trail.amount = 60
	trail.lifetime = 0.5
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 1.0
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 1.0
	trail.scale_amount_max = 2.5
	var fade := Gradient.new()
	fade.set_color(0, LOOK.earth.glow)
	fade.set_color(1, Color(LOOK.earth.color, 0.0))
	trail.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.8
	quad.material = Fx.particle_mat("dot", true)  # soft round sprite
	trail.mesh = quad
	root.add_child(trail)
	var tw := root.create_tween()
	tw.tween_property(root, "global_position", pos + Vector3.UP * 0.5, time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(core, "rotation", Vector3(4.0, 2.0, 1.0), time)
	tw.tween_callback(root.queue_free)


## RUSH: the element trails behind the hero as he charges, one step at `pos`.
static func rush_step(parent: Node, pos: Vector3, dir: Vector3, el: String) -> void:
	match el:
		"water":
			pillar(parent, pos, el, 2.2, 1.1, 0.5)
		"earth":
			var side := dir.cross(Vector3.UP)
			spikes(parent, pos + side * 0.9, el, 1.0, 2, 0.8)
			spikes(parent, pos - side * 0.9, el, 1.0, 2, 0.8)
		_:
			pillar(parent, pos, el, 2.6, 0.9, 0.45)


## RUSH ends: the whole line erupts a moment later.
static func rush_wake(parent: Node, from: Vector3, dir: Vector3, length: float, el: String) -> void:
	fissure(parent, from, dir, length, 8, el, 1.4, 0.03)
	if el == "wind":
		for i in 4:
			var tw := parent.create_tween()
			tw.tween_interval(0.05 * i)
			tw.tween_callback(lightning_fx.bind(parent, from + dir * (1.5 + i * length / 4.0), LOOK.wind.color, 10.0))
	light_pop(parent, from + dir * length * 0.5, LOOK[el].color, 8.0, length, 0.4)


## Water's RUSH: a wall of water in front of the hero (child of the hero).
static func wave_wall(hero: Node3D, time: float) -> void:
	var root := Node3D.new()
	hero.add_child(root)
	root.position = Vector3(0.0, 0.0, 0.0)
	var b := BoxMesh.new()
	b.size = Vector3(3.6, 2.4, 0.5)
	var wall := _mi(b, glow(Color(LOOK.water.color, 0.55), 1.2))
	wall.position = Vector3(0.0, 1.1, 1.0)
	root.add_child(wall)
	var crest := CylinderMesh.new()
	crest.top_radius = 0.35
	crest.bottom_radius = 0.35
	crest.height = 3.8
	var c := _mi(crest, glow(Color(LOOK.water.glow, 0.85), 2.0))
	c.rotation.z = PI * 0.5
	c.position = Vector3(0.0, 2.35, 1.2)
	root.add_child(c)
	_fade_free(root, time * 0.7, time * 0.3)


## Trinity: all three ultimates in one Awakening call down a storm on every
## enemy near `pos`, one strike each (`strike` deals the damage per target).
static func storm_strike(parent: Node, pos: Vector3, el: String) -> void:
	match el:
		"wind":
			lightning_fx(parent, pos, LOOK.wind.color, 12.0)
			pillar(parent, pos, el, 4.0, 1.4, 0.6)
		"earth":
			spikes(parent, pos, el, 1.8, 4, 0.9)
			Fx.ring(parent, pos, Color(LOOK.earth.color, 0.9), 2.2, 0.3)
		"water":
			spikes(parent, pos, el, 2.0, 5, 1.2)
		_:
			pillar(parent, pos, el, 8.0, 1.3, 0.7)
	light_pop(parent, pos, LOOK[el].color, 5.0, 5.0, 0.25)
