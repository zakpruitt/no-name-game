extends RefCounted
## The elements. The hero's own casts are spirit; wind / earth / water / void
## dress the void moves (void_element.gd). CASTS is the per-move tuning (the
## moves that summon a spirit axe); LOOK is each element's palette. Effects
## only deal damage where a caller passes it (hit_area).
##   pillar   a wind column at a point (comic_gale)
##   spikes   drawn lava spurts (earth) or frost cracks and mist (water) (designed_elements)
##   fissure  a march of spikes along a line
##   nova     burst all around: a hoop and a ring of spikes
##   echo     the axe's bound spirit finishes the swing: a drawn axe head
##            sweeping the same arc a beat later (spirit_echo.gd; L1, L2 bigger)
##   lash     the claw whips the tentacle's inked ribbon straight out to `range` and
##            snaps it back, cutting what its tip passes each way (claw_lash.gd; DL)
##   Orbit    motes circling the hero (a few at rest, more while Awakened)

const FOES := preload("res://scripts/foes.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const WELL_TIME := 4.0  # s a lava well burns before it drains
const WELL_RADIUS := 1.5
const WELL_MAX := 9  # oldest wells drain first past this
## A well's look is designed_elements.pool for about 0.9 s (POOL_TIMES); the burn keeps WELL_TIME.
const WELL_DAMAGE := 3.0  # each WELL_TICK s to foes standing in lava
const WELL_TICK := 0.5
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
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const GEYSER_SQUASH := 0.7  # of the asked height: at 0.85 five of them walled off the whole landing
const ARC_WIDTH := 0.26  # m: the colour band of a bolt between two points (the ink is twice as wide)
const DARK_FX := preload("res://scripts/dark_fx.gd")
const COMIC_GALE := preload("res://scripts/comic_gale.gd")
const STRIKE_HIGH := 5.0  # m the storm strike's bolt drops from (round 33, sleek 5: 9.0; five on Grounded filled the frame)
const STRIKE_WIDTH := 0.15  # m, its colour band; the ink is twice that (sleek 5: 0.4, comic_fault's Cataclysm bolts are 0.15)
const STRIKE_STAR := 0.8  # m, the impact star at its foot (sleek 5: 1.1)
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
static var casts := 0  # casts summoned (autotest)


## Drop cached materials and meshes so nothing is left alive at exit (Game._exit_tree).
static func release() -> void:
	_mats.clear()
	SPIRIT_ECHO._mats.clear()


## Draw every element material once, hidden under the hero, so their shaders
## compile at load instead of hitching the first cast.
static func prewarm(parent: Node, at: Vector3) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at + Vector3.DOWN * 0.3
	root.scale = Vector3.ONE * 0.05
	for el: String in LOOK:
		root.add_child(piece(el))
	# A lit box (emissive StandardMaterial3D).
	var lit := StandardMaterial3D.new()
	lit.emission_enabled = true
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = lit
	root.add_child(mi)
	# Fx sprite materials (flares).
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
	load("res://scripts/dark_fx.gd").prewarm_pieces(root)
	load("res://scripts/designed_fx.gd").prewarm(root)  # one material per designed sheet
	load("res://scripts/designed_ink.gd").prewarm(root)  # the tentacle's skin, ground stamps, hit pops
	DESIGNED_EL.prewarm(root)  # the ice and magma sheets
	load("res://scripts/designed_finish.gd").prewarm(root)  # the Awakening, halos
	load("res://scripts/counter_fx.gd").prewarm(root)  # the dash counter's parry flash and slam
	load("res://scripts/designed_polish.gd").prewarm(root)  # chips, comet trails, tells, tear
	load("res://scripts/lava_leash.gd").prewarm(root)  # dark-magma lane: Lava Leash's seam and eruption
	load("res://scripts/env_target.gd").prewarm(root)  # round 50: the structure indicator, chunks, wall marks
	load("res://scripts/env_flourish.gd").prewarm(root)  # round 53: the frozen pool's glint
	load("res://scripts/collapse_spit.gd").prewarm(root)  # round 51 cool pass: Collapse's spit
	load("res://scripts/avalanche_topple.gd").prewarm(root)  # round 51 cool pass: Avalanche's spill
	load("res://scripts/abyss_rise.gd").prewarm(root)  # round 51 cool pass: Abyss's column
	load("res://scripts/eruption_hurl.gd").prewarm(root)  # round 52 cool pass: Eruption's fuse and wall drip
	load("res://scripts/frost_shell.gd").prewarm(root)  # round 52 cool pass: Flash Freeze's steam
	load("res://scripts/mid_beats.gd").prewarm(root)  # round 54 cool pass 3: Reap's hook
	root.add_child(_mi(BoxMesh.new(), load("res://scripts/heretic_form_fx.gd").material()))  # the flat comic effects (chips, stars)
	var ghost: MeshInstance3D = SPIRIT_ECHO.ghost(BoxMesh.new(), Color.WHITE)  # spirit casts
	SPIRIT_ECHO.set_alpha(0.5, ghost)
	root.add_child(ghost)
	var l := OmniLight3D.new()
	l.light_energy = 0.01
	root.add_child(l)
	var tw := root.create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(root.queue_free)


static func color(el: String) -> Color:
	return LOOK[el].color


# --- Materials and meshes -----------------------------------------------------

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


## A piece of the element for the orbit motes: a small flat bead in a thin ink line (mote_mat).
static func piece(el: String, size := 1.0) -> Node3D:
	var root := Node3D.new()
	var s := SphereMesh.new()
	s.radius = MOTE_R * size
	s.height = MOTE_R * 2.0 * size
	s.radial_segments = 10
	s.rings = 5
	root.add_child(_mi(s, mote_mat(el)))
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

## A wind column at `pos`: fat inked wind bands on twos (comic_gale.gd). Every caller passes "wind".
static func pillar(parent: Node, pos: Vector3, _el: String, height := 4.0, radius := 1.4, life := 0.6) -> void:
	COMIC_GALE.spawn(parent, pos, height, radius, life)


## A cluster of spikes bursting up at `pos`: drawn lava spurts (earth) or frost cracks and cold mist (water).
static func spikes(parent: Node, pos: Vector3, el: String, size := 1.0, count := 3, life := 0.7) -> void:
	DESIGNED_EL.spikes(parent, pos, el, size, count, life)


## Spikes marching from `from` along `dir`: a drawn lava seam (earth) or a frost line (water).
static func fissure(parent: Node, from: Vector3, dir: Vector3, length: float, steps: int, el: String, size := 1.0, step_time := 0.035) -> void:
	DESIGNED_EL.fissure(parent, from, dir, length, steps, el, size, step_time)


## Burst all around `pos`: one thin hoop (the soft ring texture read as a glow pooled under the foes) and a ring
## of spikes (earth, water; the one caller is Live Wire's water nova).
static func nova(parent: Node, pos: Vector3, el: String, radius: float, count: int) -> void:
	DARK_FX.hoop_run(parent, pos, 0.4, radius * NOVA_HOOP_R, 0.22, LOOK[el].color, NOVA_HOOP_THIN)
	for i in count:
		var ang := TAU * i / count
		var d := Vector3(sin(ang), 0.0, cos(ang))
		spikes(parent, pos + d * radius * 0.65, el, 1.0, 2)


# --- Casts ---------------------------------------------------------------------

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


## A strike from above on `pos` in the element: a lightning bolt (wind) or a column (spirit, void); the void
## breakers' landings.
static func storm_strike(parent: Node, pos: Vector3, el: String) -> void:
	if el == "wind":  # a fat flat bolt out of the sky into a hot star, on twos (comic_bolt.gd), batched per frame
		if _strike_batch.is_empty():
			_flush_strikes.call_deferred()
		_strike_batch.append([parent, pos])
		return
	comic_column(parent, pos, el)
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
	COMIC_BOLT.spawn(parent, sky, foot, STRIKE_WIDTH, star)


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
	if Fx.in_breaker(parent):
		_breaker_arc(parent, a, b)
		return
	COMIC_BOLT.spawn(parent, a, b, ARC_WIDTH)


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
		_breaker_arcs.append(COMIC_BOLT.spawn(parent, a, b, ARC_WIDTH))
		return
	_arcs_due += 1
	parent.get_tree().create_timer(delay, true, false, true).timeout.connect(func() -> void:
		_arcs_due -= 1
		if is_instance_valid(parent) and parent.is_inside_tree():
			_breaker_arcs.append(COMIC_BOLT.spawn(parent, a, b, ARC_WIDTH)))


## A lava geyser at `pos`: the drawn column falling back into a crusted mound (designed_elements.geyser) with
## magma spurts round it. `h`: how tall. `_radius` and `_hot_core` are kept for the callers.
static func geyser(parent: Node, pos: Vector3, _radius: float, h := 5.5, _hot_core := true) -> void:
	var at := _flat(pos)
	DESIGNED_EL.geyser(parent, at, h * GEYSER_SQUASH)
	spikes(parent, at, "earth", 1.0, 3, 0.8)


## A thin geyser at a breaker landing's rim (Meteor Fall): the column only, lower than `geyser`, with no spikes of
## its own (the landing's crater mark is under it). Five full geysers with four spikes each walled the pile in.
const RIM_GEYSER_SQUASH := 0.55  # of the asked height (geyser: GEYSER_SQUASH 0.7)
static func rim_geyser(parent: Node, pos: Vector3, _radius: float, h := 5.5, _hot_core := true) -> void:
	if not _batch_take(_rim_batch, pos, RIM_GEYSER_MAX, RIM_GEYSER_SPACING):
		return
	DESIGNED_EL.geyser(parent, _flat(pos), h * RIM_GEYSER_SQUASH)


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


## A pool of lava welled up through the floor (designed_elements.pool draws it); burns foes standing in it.
class Well extends Node3D:
	const E := preload("res://scripts/elements.gd")
	var radius := 1.5
	var _age := 0.0
	var _tick := 0.2
	var _done := false

	func _ready() -> void:
		add_to_group("lava_wells")
		_mark.call_deferred()  # (elements.well() places it after add_child)

	func _physics_process(delta: float) -> void:
		if _done:
			return
		_age += delta
		if _age >= E.WELL_TIME:
			drain()
			return
		_tick -= delta
		if _tick <= 0.0:
			_tick = E.WELL_TICK
			for e in E.FOES.near(get_tree(), global_position, radius):
				# Feel audit 3 (2026-11-06): a burn, not a blow. As a full hit every tick put a hit star, a word and a
				# number on each foe every 0.5 s for 4 s after Undertow's look had gone (about 0.9 s): words
				# cycling over the dummies with nothing on screen doing it, into the next string's walk-up.
				if e.has_method("burn_hit"):
					e.burn_hit(E.WELL_DAMAGE)
				else:
					e.take_hit(E.WELL_DAMAGE, Vector3.ZERO, 0.0, false)
				Game.register_hit("lava")

	func _mark() -> void:
		if is_inside_tree():
			E.DESIGNED_EL.pool(get_parent(), global_position, radius)

	## Cools and sinks away.
	func drain() -> void:
		if _done:
			return
		_done = true
		remove_from_group("lava_wells")
		E._fade_free(self, 0.0, 0.4)
