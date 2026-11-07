extends RefCounted
## The elements. The hero's own casts are spirit; wind / earth / water / void
## dress the void moves (void_element.gd). CASTS is the per-move tuning (the
## moves that summon a spirit axe); LOOK is each element's palette. Effects
## only deal damage where a caller passes it (hit_area, Bolt.damage).
##   bolt     flying blade that pierces (nova's blades)
##   pillar   column at a point: tornado / stone pillar / geyser / spirit beam
##   fissure  a march of small pillars or spikes along a line
##   nova     burst all around: spikes or blades outward
##   echo     the axe's bound spirit finishes the swing: a giant spectral axe
##            sweeping the same arc a beat later (spirit_echo.gd; L1, L2 bigger)
##   lash     the claw whips the tentacle's inked ribbon straight out to `range` and
##            snaps it back, cutting what its tip passes each way (claw_lash.gd; DL)
##   Orbit    motes circling the hero (a few at rest, more while Awakened)

const FOES := preload("res://scripts/foes.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const WELL_TIME := 4.0  # s a lava well burns before it drains
const WELL_RADIUS := 1.5
const WELL_MAX := 9  # oldest wells drain first past this
## Round 33, sleek 5 (comic): a well's look is a thin crack mark for the pull, not the glowing pool, core and crust
## chunks: under the comic floor tiles (tops at 0.05 m) the pool only lit the grout, an orange web with brown boxes
## that stood WELL_TIME 4 s under Undertow's foes. The burn keeps WELL_TIME; bubbles stop with the look.
const WELL_COMIC_SHOW := 0.9  # s (comic_crack.MAX_TIME; Undertow's pull is UNDERTOW_TIME 1.6 s from the bind)
const WELL_COMIC_CRACK := 0.85  # of the radius (the plain look's scorch is 1.3)
const WELL_DAMAGE := 3.0  # each WELL_TICK s to foes standing in lava
const WELL_TICK := 0.5
const LAVA := Color(1.0, 0.35, 0.05)
const LAVA_HOT := Color(1.0, 0.8, 0.3)
const CASTS := {
	"L1": {"kind": "echo", "damage": 5.0, "radius": 3.4, "arc": 160.0, "delay": 0.05, "time": 0.18},
	"L2": {"kind": "echo", "damage": 6.0, "radius": 3.9, "arc": 200.0, "delay": 0.04, "time": 0.2},
	"DL": {"kind": "lash", "damage": 6.0, "back_damage": 4.0, "range": 8.0, "size": 2.6},
}
## color: main glow; glow: hot core; rock: solid pieces (earth).
const LOOK := {
	"spirit": {"color": Color(0.3, 0.95, 0.85), "glow": Color(1.0, 0.88, 0.5), "sfx": "cast_spirit"},
	"wind": {"color": Color(0.72, 1.0, 0.14), "glow": Color(0.96, 1.0, 0.75), "sfx": "cast_wind"},  # fx-air: the lightning lime (fx_palette "wind"); the wind's own look is fx_palette.AIR
	"earth": {"color": Color(1.0, 0.38, 0.08), "glow": Color(1.0, 0.78, 0.3), "rock": Color(0.2, 0.16, 0.15), "sfx": "cast_earth"},
	"water": {"color": Color(0.4, 0.78, 1.0), "glow": Color(0.88, 0.97, 1.0), "sfx": "cast_water"},
	"void": {"color": Color(0.62, 0.3, 1.0), "glow": Color(1.0, 0.4, 0.95), "sfx": "cast_spirit"},  # the void arm's dark moves only
}
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const COMIC_BOLT := preload("res://scripts/comic_bolt.gd")
const COMIC_GEYSER := preload("res://scripts/comic_geyser.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")  # round 46: designed ice and magma
const GEYSER_SQUASH := 0.7  # of the asked height: at 0.85 five of them walled off the whole landing
const GEYSER_WIDTH := 0.75  # of the radius: the column's width at the top (1.5 hid every foe)
const ARC_WIDTH := 0.26  # m: the colour band of a bolt between two points (the ink is twice as wide)
const DARK_FX := preload("res://scripts/dark_fx.gd")
const COMIC_GALE := preload("res://scripts/comic_gale.gd")
const STRIKE_HIGH := 5.0  # m the storm strike's bolt drops from (round 33, sleek 5: 9.0; five on Grounded filled the frame)
const STRIKE_WIDTH := 0.15  # m, its colour band; the ink is twice that (sleek 5: 0.4, comic_fault's Cataclysm bolts are 0.15)
const STRIKE_STAR := 0.8  # m, the impact star at its foot (sleek 5: 1.1)
const STRIKE_FORKS := 0  # (sleek 5: 2)
const COMIC_SPIKE_FAT := 1.35  # comic spikes are chunkier
## Round 33 (sleek): comic earth spikes are the see-through halftone look (spirit_echo.ghost_mat, earth
## palette: thin ink and a light edge round a ~0.3 alpha fill fading up to the tips), not opaque brown rock,
## and stand for less of their life.
const SPIKE_HOLD := 0.4  # of `life` a comic spike stands at full height (0.6)
const SPIKE_SINK := 0.25  # of `life` it takes to sink (0.3)
## The spirit (and void) strike from the sky in the comic style: one see-through column in the element's
## palette that fades out going up, not an 8 m x 1.4 m swirl round a white-gold core.
const COLUMN_HIGH := 7.0  # m
const COLUMN_R := 0.45  # m at the foot (0.7 at the top)
const COLUMN_LIFE := 0.4  # s (the beam's 0.7)
const COLUMN_STAR := 0.8  # m, the inked star at its foot
const NOVA_HOOP_R := 0.9  # of the nova's radius: its one comic hoop
const NOVA_HOOP_THIN := 0.035  # of the hoop's radius: about 0.1 m on a Live Wire nova
const ORBIT_REST := 3
const MOTE_R := 0.075  # m: a comic spirit mote (the glow dot was 0.08 in a 0.16 halo; 0.055 vanished)
const MOTE_INK_PX := 1.6  # px at 1080p
const ORBIT_AWAKENED := 7

static var _mats := {}
static var _meshes := {}
static var casts := 0  # casts summoned (autotest)


## Drop cached materials and meshes so nothing is left alive at exit (Game._exit_tree).
static func release() -> void:
	_mats.clear()
	SPIRIT_ECHO._mats.clear()
	_meshes.clear()


## Draw every element material once, hidden under the hero, so their shaders
## compile at load instead of hitching the first cast.
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
	root.add_child(_mi(_spike_mesh(0.3, 1.0, 5), SPIRIT_ECHO.ghost_mat(LOOK.water.color)))  # comic ice spikes
	root.add_child(_mi(crescent(0.16), load("res://scripts/frost_spear.gd").zone_material()))  # the frost's halftone
	# A lit box (emissive StandardMaterial3D).
	var lit := StandardMaterial3D.new()
	lit.emission_enabled = true
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = lit
	root.add_child(mi)
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
	load("res://scripts/dark_fx.gd").prewarm_pieces(root)
	load("res://scripts/designed_fx.gd").prewarm(root)  # round 43: one material per designed sheet
	load("res://scripts/designed_ink.gd").prewarm(root)  # round 44: the tentacle's skin, ground stamps, hit pops
	DESIGNED_EL.prewarm(root)  # round 46: the ice and magma sheets
	load("res://scripts/designed_finish.gd").prewarm(root)  # round 46: the Awakening, halos
	load("res://scripts/counter_fx.gd").prewarm(root)  # the dash counter's parry flash and slam
	load("res://scripts/designed_polish.gd").prewarm(root)  # round 48 (fx-polygons): chips, comet trails, tells, tear
	load("res://scripts/lava_leash.gd").prewarm(root)  # dark-magma lane: Lava Leash's seam and eruption
	load("res://scripts/env_target.gd").prewarm(root)  # round 50: the structure indicator, chunks, wall marks
	load("res://scripts/env_flourish.gd").prewarm(root)  # round 53: the frozen pool's glint
	load("res://scripts/collapse_spit.gd").prewarm(root)  # round 51 cool pass: Collapse's spit
	load("res://scripts/avalanche_topple.gd").prewarm(root)  # round 51 cool pass: Avalanche's spill
	load("res://scripts/abyss_rise.gd").prewarm(root)  # round 51 cool pass: Abyss's column
	load("res://scripts/eruption_hurl.gd").prewarm(root)  # round 52 cool pass: Eruption's fuse and wall drip
	load("res://scripts/frost_shell.gd").prewarm(root)  # round 52 cool pass: Flash Freeze's steam
	load("res://scripts/mid_beats.gd").prewarm(root)  # round 54 cool pass 3: Reap's hook
	root.add_child(_mi(crescent(0.16), load("res://scripts/heretic_form_fx.gd").material()))  # the flat comic effects (bolts, stars, geysers)
	root.add_child(_mi(crescent(0.16), load("res://scripts/frost_spear.gd").frost_material()))  # the frost spear's floor
	root.add_child(_mi(funnel(0.3, 0.1, 0.5), swirl_mat(LOOK.wind.color)))
	root.add_child(_mi(funnel(0.3, 0.1, 0.5), swirl_mat(LOOK.wind.color, true)))
	root.add_child(_mi(funnel(0.3, 0.1, 0.5), swirl_mat(LOOK.water.color, true, 0.6, 5.0)))
	root.add_child(_mi(funnel(0.3, 0.1, 0.5), swirl_mat(LOOK.spirit.color, true, 3.0, 2.0)))
	var ghost: MeshInstance3D = SPIRIT_ECHO.ghost(BoxMesh.new(), Color.WHITE)  # spirit casts
	SPIRIT_ECHO.set_alpha(0.5, ghost)
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


## The comic spirit mote's look: the palette's light tone, flat and opaque, in a MOTE_INK_PX ink hull.
static func mote_mat(el: String) -> StandardMaterial3D:
	var key := "mote_" + el
	if not _mats.has(key):
		var pal := PAL.of(el if LOOK.has(el) and el != "void" else "spirit")
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = pal.light
		var ink := ShaderMaterial.new()
		ink.shader = SPIRIT_ECHO.INK_SHADER
		ink.set_shader_parameter("ink_color", pal.ink)
		ink.set_shader_parameter("width_px", MOTE_INK_PX)
		m.next_pass = ink
		_mats[key] = m
	return _mats[key]


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
		_ when Game.comic_style:  # round 33 (sleek): a small flat bead in a thin ink line, not a glowing dot in a halo
			var s := SphereMesh.new()
			s.radius = MOTE_R * size
			s.height = MOTE_R * 2.0 * size
			s.radial_segments = 10
			s.rings = 5
			root.add_child(_mi(s, mote_mat(el)))
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


## A short burst of light in the element's colour (big casts and breakers).
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


## Damage everything within `radius` of `pos`; `on_hit` gets each enemy hit. Returns the count.
static func hit_area(tree: SceneTree, pos: Vector3, radius: float, damage: float, launch: float, big: bool,
		source: String, on_hit := Callable()) -> int:
	var n := 0
	for e in FOES.near(tree, pos, radius):
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
	if el == "wind" and Game.comic_style:  # fat inked wind bands on twos, not the soft funnels
		COMIC_GALE.spawn(parent, pos, height, radius, life)
		return
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
	if el in ["earth", "water"] and Game.comic_style and DESIGNED_EL.DESIGNED.on():  # drawn lava spurts / ice crystals
		DESIGNED_EL.spikes(parent, pos, el, size, count, life)
		return
	if el not in ["earth", "water"]:
		pillar(parent, pos, el, 2.2 * size, 0.7 * size, life * 0.7)
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	var comic := Game.comic_style
	var mat: Material = rock() if el == "earth" else ice()
	for i in count:
		var h := randf_range(1.0, 1.8) * size
		var fat := COMIC_SPIKE_FAT if comic else 1.0
		if comic:  # see-through halftone earth or ice in a thin line, fading up to the tip (round 33, part 3:
			# ice too; its round-29 flat two-tone ice was the last opaque spike)
			mat = SPIRIT_ECHO.ghost_mat(LOOK[el].color)
		var s := _mi(_spike_mesh(randf_range(0.22, 0.34) * size * fat, h, 5), mat)
		if comic:
			s.set_instance_shader_parameter("fade_height", h * 1.05)  # (the tip stands about h up)
		var off := Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4)) * size if i > 0 else Vector3.ZERO
		s.position = off + Vector3.UP * -h * 0.5
		s.rotation = Vector3(off.z * 0.8, randf() * TAU, -off.x * 0.8)
		root.add_child(s)
		var tw := s.create_tween()
		tw.tween_interval(i * 0.03)
		var up := tw.tween_property(s, "position:y", h * 0.45, 0.07).set_ease(Tween.EASE_OUT)
		if comic:
			up.set_trans(Tween.TRANS_BACK)  # punches past and settles
		tw.tween_interval(life * (SPIKE_HOLD if comic else 0.6))
		tw.tween_property(s, "position:y", -h * 0.5, life * (SPIKE_SINK if comic else 0.3)).set_ease(Tween.EASE_IN)
	var t0 := root.create_tween()
	t0.tween_interval(life + 0.1)
	t0.tween_callback(root.queue_free)
	if comic:  # no soft dots or smoke round comic spikes
		return
	var c: Color = LOOK[el].color
	Fx.burst(parent, root.global_position + Vector3.UP * 0.3, c, 8, 6.0, 0.12, 0.35, Vector3.UP, 60.0, -10.0)
	if el == "earth":
		Fx.dust(parent, root.global_position, 5, 0.6)
	else:
		Fx.burst(parent, root.global_position + Vector3.UP * 0.2, Color(0.9, 0.97, 1.0), 8, 4.0, 0.2, 0.5, Vector3.UP, 90.0, 0.0, 0.4)


## Spikes or small pillars marching from `from` along `dir`.
static func fissure(parent: Node, from: Vector3, dir: Vector3, length: float, steps: int, el: String, size := 1.0, step_time := 0.035) -> void:
	if el in ["earth", "water"] and Game.comic_style and DESIGNED_EL.DESIGNED.on():  # a drawn lava seam / crystal line
		DESIGNED_EL.fissure(parent, from, dir, length, steps, el, size, step_time)
		return
	for i in steps:
		var at := from + dir * (1.0 + i * (length - 1.0) / maxf(steps - 1, 1))
		var tw := parent.create_tween()
		tw.tween_interval(i * step_time)
		tw.tween_callback(spikes.bind(parent, at, el, size * lerpf(0.8, 1.2, float(i) / steps)))


## Burst all around `pos`: a ring of spikes (earth, water) or blades flying outward (wind, spirit).
static func nova(parent: Node, pos: Vector3, el: String, radius: float, count: int) -> void:
	var c: Color = LOOK[el].color
	var comic := Game.comic_style
	if comic:  # hard thin hoops: the soft ring texture read as a blue glow pooled under the foes
		# (0.08 of a 3.5 m hoop plus a pale one inside was a fat green ring round every Live Wire frame)
		DARK_FX.hoop_run(parent, pos, 0.4, radius * NOVA_HOOP_R, 0.22, c, NOVA_HOOP_THIN)
	else:
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
	if not comic:  # (soft dots: comic spikes carry it)
		Fx.burst(parent, pos + Vector3.UP * 0.3, c, 30, 10.0, 0.16, 0.45, Vector3.UP, 85.0, -6.0)


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
			for e in FOES.near(get_tree(), global_position, 0.9 * size):
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


## A strike from above on `pos` in the element: lightning, spikes or a beam (the void
## breakers' landings, breaker_quake).
static func storm_strike(parent: Node, pos: Vector3, el: String) -> void:
	match el:
		"wind":  # a fat flat bolt out of the sky into a hot star, on twos (comic_bolt.gd)
			if _strike_batch.is_empty():
				_flush_strikes.call_deferred()
			_strike_batch.append([parent, pos])
			return
		"earth":
			spikes(parent, pos, el, 1.8, 4, 0.9)
			if Game.comic_style:  # round 33, part 3: the breaker cue's thin inked hoop, not a fat orange band
				Fx.thin_hoop(parent, pos, "earth", 2.2, 0.3)
			else:
				Fx.ring(parent, pos, Color(LOOK.earth.color, 0.9), 2.2, 0.3)
		"water":
			spikes(parent, pos, el, 2.0, 5, 1.2)
		_:
			if Game.comic_style:
				comic_column(parent, pos, el)
			else:
				pillar(parent, pos, el, 8.0, 1.3, 0.7)
	light_pop(parent, pos, LOOK[el].color, 5.0, 5.0, 0.25)


## Round 33, sleek 6: Grounded asks for a strike under every foe and one at the pile's middle, six bolts and six
## stars in one frame. The frame's strikes are drawn together: at most STRIKE_MAX, nearest the middle of them first,
## STRIKE_SPACING apart, STRIKE_STAGGER real s after each other (comic_fault's Cataclysm cadence), and only the first
## (the pile's centre) lands in a star.
const STRIKE_MAX := 3
const STRIKE_SPACING := 1.4  # m
const STRIKE_STAGGER := 0.06  # real s
static var _strike_batch := []  # [parent, pos] asked this frame
static var strikes_drawn := 0  # (fx_sleek_check)


static func _flush_strikes() -> void:
	var batch := _strike_batch
	_strike_batch = []
	var mid := Vector3.ZERO
	for r: Array in batch:
		mid += r[1]
	mid /= maxf(batch.size(), 1.0)
	batch.sort_custom(func(x: Array, y: Array) -> bool: return _flat(x[1] - mid).length() < _flat(y[1] - mid).length())
	var picked := []
	for r: Array in batch:
		if picked.size() >= STRIKE_MAX or not is_instance_valid(r[0]):
			continue
		if picked.any(func(q: Array) -> bool: return _flat(q[1] - r[1]).length() < STRIKE_SPACING):
			continue
		picked.append(r)
	for k in picked.size():
		var parent: Node = picked[k][0]
		var pos: Vector3 = picked[k][1]
		if k == 0:
			_strike_bolt(parent, pos, STRIKE_STAR)
		elif parent.is_inside_tree():
			parent.get_tree().create_timer(STRIKE_STAGGER * k, true, false, true).timeout.connect(func() -> void:
				if is_instance_valid(parent) and parent.is_inside_tree():
					_strike_bolt(parent, pos, 0.0))


static func _strike_bolt(parent: Node, pos: Vector3, star: float) -> void:
	strikes_drawn += 1
	var foot := Vector3(pos.x, 0.25, pos.z)
	var sky := foot + Vector3(randf_range(-1.2, 1.2), STRIKE_HIGH, randf_range(-1.2, 1.2))
	COMIC_BOLT.spawn(parent, sky, foot, STRIKE_WIDTH, star, STRIKE_FORKS)


## The comic strike from the sky (spirit, void): a see-through column (COLUMN_*) snapping open at `pos`
## with an inked star at its foot, gone in COLUMN_LIFE.
static func comic_column(parent: Node, pos: Vector3, el: String) -> void:
	var c: Color = LOOK[el].color
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = _flat(pos)
	var cyl := CylinderMesh.new()
	cyl.top_radius = COLUMN_R * 1.55
	cyl.bottom_radius = COLUMN_R
	cyl.height = COLUMN_HIGH
	cyl.radial_segments = 16
	cyl.rings = 1
	cyl.cap_top = false
	var col := SPIRIT_ECHO.ghost(cyl, c)
	col.set_instance_shader_parameter("fade_height", COLUMN_HIGH * 0.85)
	SPIRIT_ECHO.set_alpha(1.0, col)
	col.position.y = COLUMN_HIGH * 0.5
	root.add_child(col)
	root.scale = Vector3(0.25, 1.0, 0.25)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.06).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(COLUMN_LIFE * 0.35)
	tw.tween_method(SPIRIT_ECHO.set_alpha.bind(col), 1.0, 0.0, COLUMN_LIFE * 0.5)
	tw.tween_callback(root.queue_free)
	var pal := PAL.of(el)
	Fx.COMIC_POP.spawn(parent, root.global_position + Vector3.UP * 0.3, {"star": COLUMN_STAR, "steps": 3,
		"star_color": pal.body, "star_core": pal.light})


# --- Lava and lightning the void moves share (were element_rite.gd) --------

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Lava welling up at `pos` (floor_bind: Molten Palm's hold). `big` = 30% wider.
static func well(parent: Node, pos: Vector3, big := false) -> void:
	var wells := parent.get_tree().get_nodes_in_group("lava_wells")
	if wells.size() >= WELL_MAX:
		wells[0].drain()
	var w := Well.new()
	w.radius = WELL_RADIUS * (1.3 if big else 1.0)
	parent.add_child(w)
	w.global_position = Vector3(pos.x, 0.0, pos.z)


## A jagged lightning arc between two points: a flat inked zigzag on twos (comic_bolt.gd). The storm's
## palette is fixed (ink, green, pale core), so `c` is only kept for the callers.
static func arc(parent: Node, a: Vector3, b: Vector3, _c: Color) -> void:
	if Game.comic_style and Fx.in_breaker(parent):
		_breaker_arc(parent, a, b)
		return
	COMIC_BOLT.spawn(parent, a, b, ARC_WIDTH, 0.0, 1 if a.distance_to(b) > 2.5 else 0)


## Round 33, sleek 6: Live Wire's hang (void_element.zap every WIRE_STEP 0.09 s) chains a bolt to every foe it holds,
## each living a quarter second, so Worldbreaker and Grounded hung a dozen bolts over the pile. In a breaker at most
## BREAKER_ARC_MAX bolts are alive (or due) at once, and the ones asked for in the same frame start
## BREAKER_ARC_STAGGER real s apart (one designed run, as comic_fault's Cataclysm bolts are, not a wall).
const BREAKER_ARC_MAX := 3
const BREAKER_ARC_STAGGER := 0.06  # real s
static var _breaker_arcs := []  # the live bolts (untyped: freed nodes are filtered)
static var _arcs_due := 0  # staggered ones not yet drawn
static var _arc_frame := -1
static var _arc_in_frame := 0
static var arcs_capped := 0  # bolts not drawn (fx_sleek_check)


static func _breaker_arc(parent: Node, a: Vector3, b: Vector3) -> void:
	_breaker_arcs = _breaker_arcs.filter(func(v: Variant) -> bool: return is_instance_valid(v))
	if _breaker_arcs.size() + _arcs_due >= BREAKER_ARC_MAX:
		arcs_capped += 1
		return
	var f := Engine.get_process_frames()
	if f != _arc_frame:
		_arc_frame = f
		_arc_in_frame = 0
	var delay := BREAKER_ARC_STAGGER * _arc_in_frame
	_arc_in_frame += 1
	if delay <= 0.0:
		_breaker_arcs.append(COMIC_BOLT.spawn(parent, a, b, ARC_WIDTH, 0.0, 0))
		return
	_arcs_due += 1
	parent.get_tree().create_timer(delay, true, false, true).timeout.connect(func() -> void:
		_arcs_due -= 1
		if is_instance_valid(parent) and parent.is_inside_tree():
			_breaker_arcs.append(COMIC_BOLT.spawn(parent, a, b, ARC_WIDTH, 0.0, 0)))


## A lava geyser at `pos`: a flat inked column punching up on twos, fat lava blobs off the top and a
## hard splash at its foot (comic_geyser.gd), magma spikes round it and a scorch left behind.
## `h`: how tall. `hot_core` is kept for the callers: the core is always the hot yellow band now.
static func geyser(parent: Node, pos: Vector3, radius: float, h := 5.5, _hot_core := true) -> void:
	var at := _flat(pos)
	if Game.comic_style and DESIGNED_EL.DESIGNED.on():  # (designed: the drawn column falls back into a crusted mound)
		DESIGNED_EL.geyser(parent, at, h * GEYSER_SQUASH)
		spikes(parent, at, "earth", 1.0, 3, 0.8)
		return
	COMIC_GEYSER.spawn(parent, at, h * GEYSER_SQUASH, radius * GEYSER_WIDTH)
	spikes(parent, at, "earth", 1.2, 4, 0.8)
	Fx.scorch(parent, at, LAVA, radius * 1.4, 1.6)


## Round 33, sleek 5: a thin geyser at a breaker landing's rim (Meteor Fall): the column only, narrower and
## lower than `geyser`, with no spikes or scorch of its own (the landing's crater mark is under it). Five full
## geysers with four spikes and a scorch each walled the pile in.
const RIM_GEYSER_WIDTH := 0.42  # of the radius (geyser: GEYSER_WIDTH 0.75)
const RIM_GEYSER_SQUASH := 0.55  # of the asked height (geyser: GEYSER_SQUASH 0.7)
static func rim_geyser(parent: Node, pos: Vector3, radius: float, h := 5.5, _hot_core := true) -> void:
	if not Game.comic_style:
		geyser(parent, pos, radius, h, _hot_core)
		return
	if not _batch_take(_rim_batch, pos, RIM_GEYSER_MAX, RIM_GEYSER_SPACING):
		return
	if DESIGNED_EL.DESIGNED.on():
		DESIGNED_EL.geyser(parent, _flat(pos), h * RIM_GEYSER_SQUASH)
		return
	COMIC_GEYSER.spawn(parent, _flat(pos), h * RIM_GEYSER_SQUASH, radius * RIM_GEYSER_WIDTH)


## Round 33, sleek 6: Worldbreaker asks for a rim geyser under every foe on its pile (void_element.under("earth")), five
## orange columns in one frame. At most RIM_GEYSER_MAX of one batch (asked inside BATCH_MS), RIM_GEYSER_SPACING apart.
const RIM_GEYSER_MAX := 3
const RIM_GEYSER_SPACING := 1.3  # m
const BATCH_MS := 100
static var _rim_batch := []  # [ms, flat position]


## One batch of effects asked for together (a landing's per-foe calls): true if `pos` may draw, and records it.
static func _batch_take(batch: Array, pos: Vector3, most: int, spacing: float) -> bool:
	var now := Time.get_ticks_msec()
	var flat := _flat(pos)
	var live := batch.filter(func(r: Array) -> bool: return now - int(r[0]) <= BATCH_MS)
	batch.clear()
	batch.append_array(live)
	if batch.size() >= most:
		return false
	for r: Array in batch:
		if (r[1] as Vector3).distance_to(flat) < spacing:
			return false
	batch.append([now, flat])
	return true


## A pool of lava welled up through the floor: a cracked crust round a bright
## core, bubbling and spitting; burns foes standing in it.
class Well extends Node3D:
	const E := preload("res://scripts/elements.gd")
	var radius := 1.5
	var _age := 0.0
	var _tick := 0.2
	var _bubble := 0.0
	var _core: MeshInstance3D
	var _done := false

	func _ready() -> void:
		add_to_group("lava_wells")
		if Game.comic_style:
			_core = MeshInstance3D.new()  # (nothing to draw: _physics_process still pulses it)
			add_child(_core)
			_comic_mark.call_deferred()  # (elements.well() places it after add_child)
			return
		var pool := CylinderMesh.new()
		pool.top_radius = radius
		pool.bottom_radius = radius
		pool.height = 0.04
		pool.radial_segments = 14
		add_child(E._mi(pool, E.glow(Color(E.LAVA, 0.85), 1.6)))
		var hot := CylinderMesh.new()
		hot.top_radius = radius * 0.55
		hot.bottom_radius = radius * 0.55
		hot.height = 0.06
		hot.radial_segments = 10
		_core = E._mi(hot, E.glow(E.LAVA_HOT, 2.2))
		add_child(_core)
		for i in 7:  # crust chunks round the rim
			var b := BoxMesh.new()
			b.size = Vector3(randf_range(0.3, 0.55), randf_range(0.12, 0.25), randf_range(0.2, 0.35))
			var rock := E._mi(b, E.rock())
			var ang := TAU * (i + randf_range(-0.3, 0.3)) / 7.0
			rock.position = Vector3(sin(ang), 0.0, cos(ang)) * radius * randf_range(0.85, 1.05)
			rock.rotation = Vector3(randf_range(-0.3, 0.3), ang, randf_range(-0.3, 0.3))
			add_child(rock)
		scale = Vector3(0.2, 1.0, 0.2)
		create_tween().tween_property(self, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		var parent := get_parent()
		Fx.burst(parent, global_position + Vector3.UP * 0.2, E.LAVA, 14, 7.0, 0.14, 0.5, Vector3.UP, 45.0, -18.0, radius * 0.4, "dot", true)
		Fx.scorch(parent, global_position, E.LAVA, radius * 1.3, E.WELL_TIME)
		Fx.dust(parent, global_position, 6, 0.6)

	func _physics_process(delta: float) -> void:
		if _done:
			return
		_age += delta
		if _age >= E.WELL_TIME:
			drain()
			return
		_core.scale = Vector3.ONE * (1.0 + 0.12 * sin(_age * 9.0))
		_bubble -= delta
		var drawn: bool = Game.comic_style and E.DESIGNED_EL.DESIGNED.on()  # (designed: the pool draws its own bubbles)
		if _bubble <= 0.0 and (_age < E.WELL_COMIC_SHOW or not Game.comic_style) and not drawn:
			_bubble = randf_range(0.12, 0.25)
			var off := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * radius * 0.6
			Fx.burst(get_parent(), global_position + off + Vector3.UP * 0.1, E.LAVA_HOT, 3, 3.0, 0.1, 0.45, Vector3.UP, 20.0, -6.0, 0.0, "dot", true)
		_tick -= delta
		if _tick <= 0.0:
			_tick = E.WELL_TICK
			for e in E.FOES.near(get_tree(), global_position, radius):
				# Feel audit 3 (2026-11-06): a burn, not a blow. As a full hit every tick put a hit star, a word and a
				# number on each foe every 0.5 s for 4 s after Undertow's look had gone (WELL_COMIC_SHOW 0.9 s): words
				# cycling over the dummies with nothing on screen doing it, into the next string's walk-up.
				if e.has_method("burn_hit"):
					e.burn_hit(E.WELL_DAMAGE)
				else:
					e.take_hit(E.WELL_DAMAGE, Vector3.ZERO, 0.0, false)
				Game.register_hit("lava")

	func _comic_mark() -> void:
		if is_inside_tree():
			if E.DESIGNED_EL.DESIGNED.on():
				E.DESIGNED_EL.pool(get_parent(), global_position, radius)
				return
			Fx.scorch(get_parent(), global_position, E.LAVA, radius * E.WELL_COMIC_CRACK, E.WELL_COMIC_SHOW)

	## Cools and sinks away.
	func drain() -> void:
		if _done:
			return
		_done = true
		remove_from_group("lava_wells")
		E._fade_free(self, 0.0, 0.4)
