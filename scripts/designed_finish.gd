extends Node3D
## Round 46 (fx-finish, docs/features/designed-fx.md "Round 46"): designed versions of the last polygon effects,
## the Awakening first. Sheets: tools/vfx_gen/gen_finish.py (registered in DESIGNED.extra_sheets here); plays
## through designed_fx.gd's palette, timeline node and shaders.
##
## The Awakening (awaken()): an authored event in gold, in three beats on real time (his own freeze must not hold it):
##   anticipation  awaken_gather: manga focus lines and gold motes pulled in to his chest (GATHER_TIMES)
##   peak          awaken_crown: a crown of inked gold flame tongues bursting up round him, stood just behind him
##                 and depth tested (he stays in front), held and boiled; awaken_floor: a sunburst of gold rays
##                 racing out on the floor (the reach that blows the foes back)
##   dissolve      the tongues lift off the floor, throw licks and erode; the rays thin and erode from their tips
## Nothing covers him: the gather's hole is wider than he is, the crown is behind him.

const DESIGNED := preload("res://scripts/designed_fx.gd")
const SELF := preload("res://scripts/designed_finish.gd")

const SHEETS := {
	"awaken_gather": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"awaken_crown": {"grid": Vector2(4, 2), "frames": 8, "kind": "sprite_depth", "anchor": Vector2(0.0, -0.35)},
	"awaken_floor": {"grid": Vector2(3, 2), "frames": 6, "kind": "ground"},
	"chain_halo": {"grid": Vector2(4, 3), "frames": 12, "kind": "sprite"},
	"daze_star": {"grid": Vector2(4, 1), "frames": 4, "kind": "sprite_depth"},
	"combo_burst": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"echo_axe": {"grid": Vector2(4, 1), "frames": 4, "kind": "sprite"},
	"rock_boulder": {"grid": Vector2(4, 2), "frames": 8, "kind": "sprite"},
	"steam_cloud": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite_depth"},
}

const GATHER_SIZE := 5.2  # m: the focus lines' square (the hole in it is 0.27 of the half: ~1.4 m across)
const GATHER_UP := 0.85  # m: centred on his chest
const GATHER_TIMES := [0.05, 0.05, 0.045, 0.04, 0.035, 0.05]  # 0.27 s: the freeze he Awakens in (0.25 s)
const CROWN_SIZE := 5.4  # m: the crown's square (the tallest tongues stand ~3 m; 4.6 read hero-sized in the punch-in)
const CROWN_BACK := 0.55  # m behind him, away from the camera: depth tested, he reads in front of it
const CROWN_TIMES := [0.045, 0.13, 0.13, 0.08, 0.08, 0.085, 0.09, 0.1]  # anticipation, held peak and boil, dissolve
const CROWN_ERODE := Vector2(0.5, 1.0)
const FLOOR_SIZE := 6.4  # m: the sunburst's square (the rays reach ~3 m: AWAKEN_BURST_RADIUS blows foes out of it)
const FLOOR_TIMES := [0.04, 0.07, 0.07, 0.08, 0.09, 0.1]
const FLOOR_ERODE := Vector2(0.45, 1.0)

## Chain halos (Fx.chain_spark, tiers 1-3 past Fx.CHAIN_TIERS): a sparkle behind the hit, strokes from tier 2, arcs at 3.
const HALO_SIZE := [1.2, 1.5, 1.85]  # m per tier
const HALO_TIMES := [0.033, 0.075, 0.06, 0.06]
## Daze stars (Fx.daze): two drawn cartoon stars circling the head, boiling on twos, depth tested (the head hides
## the one behind it).
const DAZE_SIZE := 0.56  # m: a star's quad (the old polygon star was 0.32 m across; 0.46 read as specks)
## Combo burst (Fx.combo_pop): burst lines thrown out all round him from a clear hole, tier-scaled.
const BURST_SIZE := 3.0  # m at tier 1, + BURST_GROW a tier
const BURST_GROW := 0.5
const BURST_TIMES := [0.033, 0.05, 0.05, 0.05, 0.06, 0.07]

## The spirit echo's ghost axe (spirit_echo.gd, designed): a drawn axe head flying the swing's outer arc with two
## edge echoes behind it, instead of the 3 m halftone axe mesh that covered his swing.
const ECHO_SIZE := 1.4  # m: the axe head's quad (was 2.3: feel audit 3 item 9, half the size)
const ECHO_REACH := 0.82  # of the drawn arc's radius: on its outer edge
## Feel audit 3 item 9: the echo's fan (its slash stroke out at the cast's full 3.4-3.9 m reach, the element's fill,
## lingering in game time through the hitstop into the next move's wind-up) was the biggest shape on L2 / L3 / Air
## Slash and sat under his own arc. Now it is drawn at ECHO_DRAW of the reach (the hit reach is unchanged), as a
## thin ink-coloured line only (ECHO_LINE_INNER of its radius in), and the line and the axe head play in real time,
## ECHO_REAL s, so both are gone by the time the string's next hit lands.
const ECHO_DRAW := 0.62
const ECHO_LINE_INNER := 0.94
const ECHO_REAL := 0.2  # s, real: the sweep (the hitstop it starts in is ~0.05-0.1 s)
const ECHO_ELEMENT := "void"  # the ink-dark palette row for the line

## The limb changing into a weapon (heretic_form_fx.gd, designed): the weapon's element pop (designed_ink's drawn
## storm / ice / magma / dark hit pops) up the new haft, clear of his hood, instead of a polygon star and chips.
const FORM_ELEMENT := {"axe": "wind", "spear": "water", "hammer": "earth", "hand": "void"}
const FORM_SIZE := 1.1  # m: the pop's quad (designed_ink.POP_SIZE is a hit's 1.5)
const FORM_UP := 0.45  # m up the haft from the hand

## Rockslide's boulder (comic_boulder.gd, designed): one drawn boulder slamming down and splitting, a dust puff.
const BOULDER_SIZE := 2.6  # m per boulder size 1 (the rock is ~0.95 m across in it)
const BOULDER_TIMES := [0.05, 0.09, 0.08, 0.06, 0.06, 0.07, 0.08, 0.1]
## Steam Burst's cloud (comic_steam.gd, designed).
const STEAM_SIZE := 2.6  # m
const STEAM_UP := 1.25  # m: the cloud's middle over the floor
const STEAM_BACK := 0.55  # m behind the foe, away from the camera (depth tested: the foe reads in front of it)
const STEAM_TIMES := [0.04, 0.09, 0.08, 0.09, 0.1, 0.12]

## Eruption's landing (comic_erupt.gd, designed): the meteor's magma crown, small, up under each foe nearest first.
const ERUPT_SIZE := 2.3  # m: magma_burst's square (its tongues stand ~0.8 m); molten foes x ERUPT_HOT
const ERUPT_HOT := 1.3
const ERUPT_BACK := 0.35  # m behind the foe (depth tested: the foe reads in front of its tongues)
const ERUPT_STAGGER := 0.05  # game s, nearest first (comic_erupt.STAGGER)
## Anvil's landing (comic_anvil.gd, designed): a drawn scorched crater star under each foe, a dust puff, staggered.
const ANVIL_SIZE := 2.6  # m: strike_scorch's square in the earth row
const ANVIL_STAGGER := 0.04
const ANVIL_TIMES := [0.05, 0.08, 0.12, 0.16, 0.2, 0.24]

static var _registered := false
static var drawn := 0  # Awakenings drawn (checks)

var _hero: Node3D
var _at := Vector3.ZERO
var _t := 0.0
var _last_us := 0
var _peaked := false


static func _register() -> void:
	if _registered:
		return
	_registered = true
	for n: String in SHEETS:
		var s: Dictionary = SHEETS[n].duplicate()
		s["tex"] = load("res://assets/vfx/designed/%s.png" % n)
		DESIGNED.extra_sheets[n] = s


## Draw every material once at real size (elements.prewarm).
static func prewarm(root: Node3D) -> void:
	if not DESIGNED.on():
		return
	_register()
	for n: String in SHEETS:
		var mi := MeshInstance3D.new()
		mi.mesh = PlaneMesh.new() if SHEETS[n].kind == "ground" else QuadMesh.new()
		mi.material_override = DESIGNED.material(n)
		root.add_child(mi)
		mi.scale = Vector3.ONE * 20.0


## The Awakening's look round `hero` (awaken_flourish._show, designed): the gather now, the peak GATHER_TIMES later.
static func awaken(parent: Node, hero: Node3D, at: Vector3) -> Node3D:
	_register()
	drawn += 1
	var fx: Node3D = SELF.new()
	fx._hero = hero
	fx._at = at
	parent.add_child(fx)
	fx.top_level = true
	fx.global_position = at
	var g := DESIGNED.spawn(parent, "awaken_gather", at + Vector3.UP * GATHER_UP, GATHER_SIZE, "gold", GATHER_TIMES, Vector2(0.8, 1.0))
	g.real_time = true
	g.set_spin(randf_range(-0.3, 0.3), 1.0)
	_ride(g, hero, Vector3.UP * GATHER_UP)
	return fx


static func _ride(fx: Node3D, hero: Node3D, off: Vector3) -> void:
	if hero != null and is_instance_valid(hero):
		fx.follow = hero
		fx.follow_off = off


func _ready() -> void:
	_last_us = Time.get_ticks_usec()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := float(now - _last_us) / 1000000.0
	_last_us = now
	_t += delta if DESIGNED.game_time_only else real
	if _peaked:
		return
	var due := 0.0
	for d: float in GATHER_TIMES:
		due += d
	if _t < due - 0.02:  # (the crown's own anticipation frame overlaps the gather's snap)
		return
	_peaked = true
	_peak()
	queue_free()


func _peak() -> void:
	var parent := get_parent()
	var foot := _at
	if _hero != null and is_instance_valid(_hero):
		foot = _hero.global_position
	foot.y = 0.0
	var back := Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var away := -cam.global_basis.z
		back = Vector3(away.x, 0.0, away.z).normalized() * CROWN_BACK
	var crown := DESIGNED.spawn(parent, "awaken_crown", foot + back, CROWN_SIZE, "gold", CROWN_TIMES, CROWN_ERODE)
	crown.real_time = true
	crown.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	_ride(crown, _hero, back)
	var floor_ := DESIGNED.spawn(parent, "awaken_floor", foot + Vector3.UP * DESIGNED.GROUND_LIFT, FLOOR_SIZE, "gold", FLOOR_TIMES, FLOOR_ERODE)
	floor_.real_time = true
	floor_.rotation.y = randf() * TAU


## Fx.chain_spark (designed): one drawn halo behind the hit, in the colour's nearest element.
static func halo(parent: Node, at: Vector3, color: Color, tier: int) -> Node3D:
	_register()
	var k := clampi(tier, 1, 3) - 1
	var fx := DESIGNED.spawn(parent, "chain_halo", at, HALO_SIZE[k], DESIGNED.PAL.nearest(color), HALO_TIMES, Vector2(0.5, 1.0))
	fx.first = k * 4
	fx.real_until = 1
	return fx.vary(0.5, true)


## Fx.combo_pop (designed): burst lines all round him, never over him.
static func burst(parent: Node, at: Vector3, color: Color, tier: int) -> Node3D:
	_register()
	var t := clampi(tier, 1, 3)
	var times: Array = BURST_TIMES.duplicate()
	if t >= 3:
		times[1] = 0.1  # the big ones hold their peak
	var fx := DESIGNED.spawn(parent, "combo_burst", at, BURST_SIZE + BURST_GROW * (t - 1), DESIGNED.PAL.nearest(color), times, Vector2(0.45, 1.0))
	fx.real_until = 1
	return fx.vary(PI, true)


## Fx.daze (designed): two drawn stars on a spinning pivot over the head. Named "DazeStars" like the old one.
static func daze(node: Node3D, height: float, time: float, ring: float, spin: float) -> Node3D:
	_register()
	var pivot := Node3D.new()
	pivot.name = "DazeStars"
	node.add_child(pivot)
	pivot.position.y = height
	var stars: Array = []
	for i in 2:
		var a := TAU * i / 2.0
		var mi := MeshInstance3D.new()
		mi.mesh = QuadMesh.new()
		mi.material_override = DESIGNED.material("daze_star")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_ghost", true)
		mi.position = Vector3(cos(a), 0.0, sin(a)) * ring
		mi.scale = Vector3.ONE * DAZE_SIZE
		mi.set_instance_shader_parameter("pal_row", DESIGNED.row("gold"))
		mi.set_instance_shader_parameter("frame", float(i * 2))
		mi.set_instance_shader_parameter("erode", 0.0)
		mi.set_instance_shader_parameter("alpha", 1.0)
		pivot.add_child(mi)
		stars.append(mi)
	pivot.scale = Vector3.ONE * 0.2
	var tw := pivot.create_tween().set_parallel()
	tw.tween_property(pivot, "rotation:y", spin * time, time)
	tw.tween_property(pivot, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void:  # boil on twos, erode out over the last share
		for k in stars.size():
			var mi: MeshInstance3D = stars[k]
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("frame", float((int(v * 12.0) + k * 2) % 4))
				mi.set_instance_shader_parameter("erode", clampf((v / time - 0.72) / 0.28, 0.0, 1.0) * 0.98)
		, 0.0, time, time)
	tw.chain().tween_callback(pivot.queue_free)
	return pivot


## spirit_echo (designed): the drawn axe head for one sweep of `time` game s. Frame 0 the leading edge, 1-2 the head
## with its echoes over the sweep, 3 the edge left behind; spirit_echo.pose() moves and turns it (echo_pose()).
static func echo_axe(parent: Node, at: Vector3, color: Color, time: float) -> Node3D:
	_register()
	var times := [0.033, time * 0.4, time * 0.4, 0.05]
	var fx := DESIGNED.spawn(parent, "echo_axe", at, ECHO_SIZE, DESIGNED.PAL.nearest(color), times, Vector2(0.55, 1.0))
	fx.real_time = true  # (gone by the next hit: it played on through the hitstop in game time)
	return fx


## spirit_echo (designed): the echo's line, a thin ink stroke on the drawn arc (ECHO_DRAW of `radius`), real time.
static func echo_line(parent: Node, pos: Vector3, fwd: Vector3, radius: float, arc_deg: float, flip: bool,
		height: float) -> Node3D:
	var fx: Node3D = DESIGNED.slash(parent, pos, fwd, radius * ECHO_DRAW, arc_deg, ECHO_ELEMENT, flip, ECHO_REAL * 1.2,
		height, true, true)
	var mi := fx.get_child(0) as MeshInstance3D
	if mi != null and mi.mesh is ArrayMesh:  # thinner than lines_only's 0.84: rebuild the strip's inner edge
		_thin_strip(mi.mesh as ArrayMesh, radius * ECHO_DRAW * ECHO_LINE_INNER, radius * ECHO_DRAW)
	return fx


## Moves the inner vertices (even ones) of a slash strip to `inner` m out (the strip's back still tapers in).
static func _thin_strip(mesh: ArrayMesh, inner: float, outer: float) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(0, v.size(), 2):
		var d := Vector3(v[i].x, 0.0, v[i].z)
		var r := d.length()
		if r > 0.001:
			v[i] = d / r * clampf(r, inner, outer)
	arrays[Mesh.ARRAY_VERTEX] = v
	var mat := mesh.surface_get_material(0)
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	if mat != null:
		mesh.surface_set_material(0, mat)


## Put the drawn axe at `at`, turned on screen so it flies towards `ahead` (a point a little further along the arc).
static func echo_pose(fx: Node3D, at: Vector3, ahead: Vector3) -> void:
	if fx == null or not is_instance_valid(fx) or not fx.is_inside_tree():
		return
	fx.global_position = at
	var cam := fx.get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.unproject_position(ahead) - cam.unproject_position(at)
	if d.length() > 0.001:
		fx.set_spin(atan2(-d.y, d.x), 1.0)


## heretic_form_fx.spawn (designed): one drawn element pop where the new weapon grows (group "heretic_form_fx", so
## heretic_shots counts and ticks it like the old burst).
static func form_burst(parent: Node, at: Vector3, form: String, dir: Vector3) -> Node3D:
	var ink: GDScript = load("res://scripts/designed_ink.gd")
	ink._register()
	var e: String = FORM_ELEMENT.get(form, "void")
	var spot := at + (dir * FORM_UP if dir != Vector3.ZERO else Vector3.UP * 0.2)
	var fx := DESIGNED.spawn(parent, ink.POP_FOR[e], spot, FORM_SIZE, e, ink.POP_TIMES, Vector2(0.45, 1.0))
	fx.real_until = 1
	fx.pop = 0.12
	fx.add_to_group("heretic_form_fx")
	return fx.vary(PI, true)


## comic_boulder.spawn (designed): the drawn boulder at the slam, a dust puff under it (the floor dents are left to
## the hit stars and the crater the foes make).
static func boulder(parent: Node, at: Vector3, size: float) -> Node3D:
	_register()
	var fx := DESIGNED.spawn(parent, "rock_boulder", at, BOULDER_SIZE * size, "earth", BOULDER_TIMES, Vector2(0.55, 1.0))
	fx.real_until = 1
	fx.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	DESIGNED.dust(parent, Vector3(at.x, 0.0, at.z), 1.3)
	return fx


## comic_steam.spawn (designed): the drawn steam cloud round the foe going off.
static func steam(parent: Node, spot: Vector3) -> Node3D:
	_register()
	var back := Vector3.ZERO
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	if cam != null:
		var away := -cam.global_basis.z
		back = Vector3(away.x, 0.0, away.z).normalized() * STEAM_BACK
	var fx := DESIGNED.spawn(parent, "steam_cloud", Vector3(spot.x, STEAM_UP, spot.z) + back, STEAM_SIZE, "water", STEAM_TIMES, Vector2(0.5, 1.0))
	fx.real_until = 1
	return fx.vary(0.15, true)


## comic_erupt.spawn (designed): spots nearest `from` first, ERUPT_STAGGER apart on game time (the landing's hit stop
## holds them until its impact frame has gone, as the flat version did).
static func erupt(parent: Node, from: Vector3, spots: Array, molten: Array) -> void:
	var order := range(spots.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return _flat_dist(spots[a], from) < _flat_dist(spots[b], from))
	var back := _away(parent) * ERUPT_BACK
	for n in order.size():
		var i: int = order[n]
		var spot: Vector3 = spots[i]
		var hot: bool = bool(molten[i]) if i < molten.size() else false
		_later(parent, n * ERUPT_STAGGER, func() -> void:
			var fx := DESIGNED.spawn(parent, "magma_burst", Vector3(spot.x, 0.0, spot.z) + back,
				ERUPT_SIZE * (ERUPT_HOT if hot else 1.0), "earth", DESIGNED.MAGMA_TIMES, Vector2(0.55, 1.0))
			fx.real_until = 1
			fx.set_spin(0.0, -1.0 if n % 2 else 1.0))


## comic_anvil.spawn (designed).
static func anvil(parent: Node, from: Vector3, spots: Array) -> void:
	var order := spots.duplicate()
	order.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _flat_dist(a, from) < _flat_dist(b, from))
	for n in order.size():
		var spot: Vector3 = order[n]
		_later(parent, n * ANVIL_STAGGER, func() -> void:
			var fx := DESIGNED.spawn(parent, "strike_scorch", Vector3(spot.x, DESIGNED.GROUND_LIFT, spot.z), ANVIL_SIZE, "earth",
				ANVIL_TIMES, Vector2(0.5, 1.0))
			fx.real_until = 1
			fx.rotation.y = randf() * TAU
			DESIGNED.dust(parent, Vector3(spot.x, 0.0, spot.z), 0.9))


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Away from the camera on the floor (unit), or zero.
static func _away(parent: Node) -> Vector3:
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	if cam == null:
		return Vector3.ZERO
	var away := -cam.global_basis.z
	return Vector3(away.x, 0.0, away.z).normalized()


## Run `f` after `delay` game s (0: now), if the parent is still there.
static func _later(parent: Node, delay: float, f: Callable) -> void:
	if delay <= 0.0:
		f.call()
		return
	parent.get_tree().create_timer(delay, true, false, false).timeout.connect(func() -> void:
		if is_instance_valid(parent) and parent.is_inside_tree():
			f.call())
