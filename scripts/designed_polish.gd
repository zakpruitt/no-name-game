extends RefCounted
## Round 48 (fx-polygons, docs/features/designed-fx.md "fx-polygons"): the last runtime polygon effects as designed
## ones. Sheets: tools/vfx_gen/gen_polygons.py (registered here through DESIGNED.extra_sheets); the timeline node,
## palette and shaders are designed_fx.gd's. Every caller branches on DESIGNED.on() and keeps its old path
## (--fx=classic).
##   chips()       every Fx.burst in comic style (rank-ups, landings, casts, breakers' sparks): one drawn chip spray
##   trail_mesh()  the breaker dive's comet (comic_comet.gd): dive_trail (brush), dive_ink (dark), bolt_strip (storm)
##   Loop          a looping sheet riding a node: the state tells (comic_state_tell.gd), Black Ice's frozen pool
##   improv()      the element matrix's tells (comic_improv.gd), from the shared designed pieces
##   tear()        a dark rip across a foe (Tow Line, Torn Off, Shatter)
## No crystals or spike clusters (Zak): ice here is rime, straight cracks, glints, mist and the faceted block.

const DESIGNED := preload("res://scripts/designed_fx.gd")
const INK := preload("res://scripts/designed_ink.gd")
const ELEMENTS := preload("res://scripts/designed_elements.gd")
const FINISH := preload("res://scripts/designed_finish.gd")
const PAL := preload("res://scripts/fx_palette.gd")

const SHEETS := {
	"dive_trail": {"grid": Vector2(1, 4), "frames": 4, "kind": "ribbon"},
	"dive_ink": {"grid": Vector2(1, 4), "frames": 4, "kind": "ribbon"},
	"chip_spray": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"tell_buried": {"grid": Vector2(2, 2), "frames": 4, "kind": "ground"},
	"tell_pinned": {"grid": Vector2(2, 2), "frames": 4, "kind": "ground"},
	"tell_molten": {"grid": Vector2(2, 2), "frames": 4, "kind": "sprite_depth", "anchor": Vector2(0.0, -0.28), "burn": 1.0},
	"ink_tear": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"tell_marked": {"grid": Vector2(2, 2), "frames": 4, "kind": "ground"},  # Reap's mark (dark_fx.Mark)
	"drag_line": {"grid": Vector2(1, 4), "frames": 4, "kind": "ribbon"},  # (comic_drag_mark draws it with designed_drag)
}

static var _registered := false


static func register() -> void:
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
	register()
	for n: String in SHEETS:
		var mi := MeshInstance3D.new()
		mi.mesh = PlaneMesh.new() if SHEETS[n].kind == "ground" else QuadMesh.new()
		mi.material_override = DESIGNED.material(n)
		root.add_child(mi)
		mi.scale = Vector3.ONE * 20.0
	var drag := MeshInstance3D.new()  # the drag line's own shader (comic_drag_mark)
	drag.mesh = QuadMesh.new()
	drag.material_override = load("res://scripts/comic_drag_mark.gd")._drag_material("earth")
	root.add_child(drag)
	drag.scale = Vector3.ONE * 20.0


static func _spawn(parent: Node, sheet: String, at: Vector3, size: float, element: String, times: Array, erode: Vector2) -> Node3D:
	register()
	return DESIGNED.spawn(parent, sheet, at, size, element, times, erode)


static func _cam(parent: Node) -> Camera3D:
	return parent.get_viewport().get_camera_3d() if parent != null and parent.is_inside_tree() else null


## A world direction's angle on the screen (0 = screen right, PI/2 = up).
static func screen_angle(parent: Node, d: Vector3) -> float:
	var cam := _cam(parent)
	if cam == null or d.length() < 0.001:
		return PI * 0.5
	return atan2(d.dot(cam.global_basis.y), d.dot(cam.global_basis.x))


# --- Fx.burst: one drawn chip spray -----------------------------------------------------------------------------
# The comic Fx.burst threw 2-7 inked polygon chips; designed, it is one chip_spray quad in the colour's nearest
# element, turned so its fan flies along `dir` (wide sprays fly up), sized by the burst's speed. CHIPS_A_FRAME a frame.

const CHIP_SIZE := Vector2(1.0, 1.9)  # m: the quad, slow to fast (the chips fly out ~0.4 of it)
const CHIP_TIMES := [0.033, 0.05, 0.05, 0.055, 0.06, 0.07]
const CHIPS_A_FRAME := 3
static var _chip_frame := -1
static var _chips_now := 0


static func chips(parent: Node, pos: Vector3, color: Color, amount: int, speed: float, dir: Vector3, wide: bool) -> Node3D:
	var f := Engine.get_process_frames()
	if f != _chip_frame:
		_chip_frame = f
		_chips_now = 0
	_chips_now += 1
	if _chips_now > CHIPS_A_FRAME:
		return null
	var el := PAL.nearest(color)
	var size := lerpf(CHIP_SIZE.x, CHIP_SIZE.y, clampf((speed - 2.5) / 9.0, 0.0, 1.0)) * clampf(0.8 + amount / 40.0, 0.8, 1.25)
	var fx := _spawn(parent, "chip_spray", pos, size, el, CHIP_TIMES, Vector2(0.5, 1.0))
	fx.real_until = 1
	var a := PI * 0.5 + randf_range(-0.35, 0.35) if wide else screen_angle(parent, dir)
	return fx.set_spin(a - PI * 0.5, -1.0 if randf() < 0.5 else 1.0)


# --- The breaker dive's comet (comic_comet.gd) --------------------------------------------------------------------

## The trail sheet for `el` ("" = storm: the lime bolt strip).
static func trail_sheet(el: String) -> String:
	match PAL.ALIAS.get(el, el):
		"wind":
			return "bolt_strip"
		"void":
			return "dive_ink"
	return "dive_trail"


## A camera-facing ribbon along `pts` (head first), `width` m across, UV.x 1 at the head .. 0 at the tail.
static func trail_mesh(mesh: ArrayMesh, pts: PackedVector3Array, width: float, view: Vector3, right: Vector3) -> void:
	mesh.clear_surfaces()
	var n := pts.size()
	if n < 2:
		return
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in n:
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, n - 1)]
		var across := (b - a).cross(view)
		across = across.normalized() if across.length() > 0.001 else right
		var u := 1.0 - float(i) / (n - 1)
		verts.append_array([pts[i] + across * width * 0.5, pts[i] - across * width * 0.5])
		uvs.append_array([Vector2(u, 1.0), Vector2(u, 0.0)])
	for i in n - 1:
		var k := i * 2
		idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## The landing at the end of a dive: the element's pop (storm's jagged star, dark's blot, ice's ring, the hit star
## for the rest) and one shock line, in place of the polygon star, strokes and chips.
static func dive_land(parent: Node, at: Vector3, color: Color, el: String) -> void:
	var e: String = PAL.ALIAS.get(el, el)
	var up := Vector3(at.x, 0.55, at.z)
	if INK.POP_FOR.has(e):
		INK._register()
		var fx := DESIGNED.spawn(parent, INK.POP_FOR[e], up, INK.POP_SIZE * 1.15, e, INK.POP_TIMES, Vector2(0.45, 1.0))
		fx.real_until = 1
		fx.vary(PI, true)
	else:
		DESIGNED.hit(parent, up, e, 1.1)
	INK.shock(parent, Vector3(at.x, 0.0, at.z), color, 1.6, 0.25)


# --- Loops: a sheet riding a node, cycling on twos, its alpha set by the owner -------------------------------------

static func loop(owner: Node3D, sheet: String, size: float, element: String, frames := 4) -> Loop:
	register()
	var l := Loop.new()
	owner.add_child(l)
	l.setup(sheet, size, element, frames)
	return l


class Loop extends Node3D:
	var _mi: MeshInstance3D
	var _frames := 4
	var _t := 0.0
	var _step := -1
	var _last_us := 0
	var _erode_t := -1.0
	var _erode_for := 0.25
	var pin_floor := false  # ground loops stay on the floor while their owner is launched

	func setup(sheet: String, size: float, element: String, frames: int) -> void:
		_frames = frames
		var kind: String = DESIGNED.sheet_of(sheet).kind
		_mi = MeshInstance3D.new()
		_mi.mesh = DESIGNED._mesh_for(kind)
		_mi.material_override = DESIGNED.material(sheet)
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi.set_meta("no_ghost", true)
		_mi.extra_cull_margin = size
		_mi.scale = Vector3.ONE * size
		if kind == "ground":
			_mi.position.y = DESIGNED.GROUND_LIFT
			rotation.y = randf() * TAU
			pin_floor = true
		add_child(_mi)
		_mi.set_instance_shader_parameter("pal_row", DESIGNED.row(element))
		_mi.set_instance_shader_parameter("erode", 0.0)
		_mi.set_instance_shader_parameter("frame", float(randi() % frames))
		_last_us = Time.get_ticks_usec()

	func set_alpha(a: float) -> void:
		_mi.set_instance_shader_parameter("alpha", a)

	## Where the quad sits under its owner (sprites stood behind a foe).
	func offset(v: Vector3) -> void:
		_mi.position = v

	func erode_out(time := 0.25) -> void:
		if _erode_t < 0.0:
			_erode_t = 0.0
			_erode_for = maxf(time, 0.05)

	func _process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		var real := float(now - _last_us) / 1000000.0
		_last_us = now
		_t += real
		if pin_floor:
			global_position.y = 0.0
		var step := int(_t * 12.0)
		if step != _step:
			_step = step
			_mi.set_instance_shader_parameter("frame", float(step % _frames))
		if _erode_t >= 0.0:
			_erode_t += real
			var k := clampf(_erode_t / _erode_for, 0.0, 1.0)
			_mi.set_instance_shader_parameter("erode", k * 0.98)
			if k >= 1.0:
				queue_free()


## The state tells (comic_state_tell): one loop per state on the tell's node.
const TELL_BURIED := 2.4  # m: the crust ring's square (the ring is ~0.56 of the half: ~0.67 m round, past a dummy)
const TELL_PINNED := 1.9
const TELL_MOLTEN := 1.9  # m: the licks' square (the tallest stand ~0.6 m at the sides)
const TELL_MOLTEN_BACK := 0.3  # m behind the foe from the camera (depth tested: it reads in front)
const TELL_CHARGED := 1.5
const TELL_CHEST := 0.85


static func tell(owner: Node3D, state: String) -> Loop:
	match state:
		"buried":
			return loop(owner, "tell_buried", TELL_BURIED, "dust")
		"skewered":
			return loop(owner, "tell_pinned", TELL_PINNED, "water")
		"molten":
			var l := loop(owner, "tell_molten", TELL_MOLTEN, "earth")
			var cam := _cam(owner)
			if cam != null:
				var away := -cam.global_basis.z
				l.offset(Vector3(away.x, 0.0, away.z).normalized() * TELL_MOLTEN_BACK)
			return l
		"charged":
			var c := loop(owner, "arc_crawl", TELL_CHARGED, "wind", 6)
			c.offset(Vector3.UP * TELL_CHEST)
			return c
	return null


# --- A dark tear across a foe ---------------------------------------------------------------------------------

const TEAR_SIZE := 2.0
const TEAR_TIMES := [0.033, 0.07, 0.05, 0.05, 0.06, 0.07]


static func tear(parent: Node, at: Vector3, pull := Vector3.ZERO, size := 1.0) -> Node3D:
	var fx := _spawn(parent, "ink_tear", at, TEAR_SIZE * size, "void", TEAR_TIMES, Vector2(0.45, 1.0))
	fx.real_until = 1
	if pull.length() > 0.1:  # the tear runs across the way it is yanked (drawn at -0.5 rad, drops below)
		return fx.set_spin(screen_angle(parent, pull) + PI * 0.5 + 0.5, 1.0)
	return fx.vary(0.6, true)


# --- The element matrix's tells (comic_improv) ------------------------------------------------------------------
# Each cell said in the two elements it joins, from the shared designed pieces: pops, hit stars, shock lines, frost
# marks, mist, magma spurts and cracks, gusts, bolts, the dark tear. One beat, no lingering shapes.

static func improv(parent: Node, cell: String, foe: Node3D, from: Vector3, to: Variant) -> void:
	var at := foe.global_position
	var chest := at + Vector3.UP * 0.9
	var foot := Vector3(at.x, 0.0, at.z)
	var next: Vector3 = to if to is Vector3 else Vector3.ZERO
	var has_next := to is Vector3
	match cell:
		"frozen_x_wind":  # Gale Lift: the cube burst up in a gust
			DESIGNED.ice_shatter(parent, chest, 0.8)
			DESIGNED.gust(parent, chest, Vector3.UP, 1.2, true)
		"frozen_x_void":  # Shatter: a dark tear through the ice, the ice breaking
			tear(parent, chest, (next - at) if has_next else Vector3.ZERO)
			DESIGNED.ice_shatter(parent, chest, 0.85)
			if has_next:
				DESIGNED.streaks(parent, chest, next - at, "void", false)
		"buried_x_water":  # Frozen In: frost cracking over its crater
			ELEMENTS.frost_mark(parent, foot, 1.25, 0.6)
			INK.pop(parent, chest, "water", 0.8)
		"buried_x_earth":  # Aftershock: the crater heaves, a shock line out of it
			ELEMENTS._spike(parent, foot, "earth", 0.75, 0.45)
			INK.shock(parent, foot, PAL.of("earth").body, 1.5, 0.3)
		"buried_x_void":  # Swallowed: the dark closes over the crater
			INK.pop(parent, at + Vector3.UP * 0.3, "void", 1.1)
			INK.shock(parent, foot, PAL.of("void").body, 1.2, 0.25)
		"molten_x_wind":  # Firestorm: the flames whipped round in a gust, a streak to the next
			INK.pop(parent, chest, "earth", 0.8)
			DESIGNED.gust(parent, chest, (next - at) if has_next else (at - from), 1.1, true)
			if has_next:
				DESIGNED.streaks(parent, chest, next - at, "earth", false)
		"molten_x_water":  # Quench: steam off it, a frost ring
			FINISH.steam(parent, foot)
			DESIGNED.ice_shatter(parent, chest, 0.6)
		"molten_x_earth":  # Flare-up: magma thrown up under it
			ELEMENTS._spike(parent, foot, "earth", 0.9, 0.5)
			INK.pop(parent, chest, "earth", 0.9)
		"molten_x_void":  # Smother: an ink blot over the flames, dust squeezed out
			INK.pop(parent, chest, "void", 1.0)
			DESIGNED.dust(parent, foot, 0.8)
		"skewered_x_water":  # Ice Spreads: a frost line along the floor to the next (cracks, no tips)
			if has_next:
				var d := Vector3(next.x - at.x, 0.0, next.z - at.z)
				ELEMENTS.fissure(parent, foot, d, maxf(d.length(), 1.2), maxi(2, int(d.length() / 0.9)), "water", 0.8)
				INK.pop(parent, next + Vector3.UP * 0.9, "water", 0.8)
			else:
				ELEMENTS.frost_mark(parent, foot, 0.8, 0.45)
		"skewered_x_void":  # Torn Off: the frost breaks as it's yanked (comic_rip draws the tear)
			DESIGNED.ice_shatter(parent, chest, 0.6)
		"airborne_x_water":  # Freeze Aloft: a water star (its block is the read)
			DESIGNED.hit(parent, chest, "water", 1.1)
		"airborne_x_earth":  # Meteor Spike: driven down hot, a burst where it lands
			DESIGNED.streaks(parent, chest, Vector3.DOWN, "earth", true)
			ELEMENTS._spike(parent, foot, "earth", 0.8, 0.45)
		"bound_x_wind":  # Torn Loose: the ropes torn off in a gust
			INK.pop(parent, at + Vector3.UP * 0.3, "void", 0.8)
			DESIGNED.gust(parent, chest, Vector3.UP, 1.2, true)
		"bound_x_water":  # Frozen in the Dark: frost over the bind
			ELEMENTS.frost_mark(parent, foot, 1.0, 0.55)
			INK.pop(parent, at + Vector3.UP * 0.4, "void", 0.7)
		"charged_x_void":  # Conduct: the dark blot, the current on through it
			INK.pop(parent, chest, "void", 0.9)
			DESIGNED.crawl(parent, foe, 0.9)
		"charged_x_water":  # Superconduct: the ice ring with the current crawling out of it
			DESIGNED.ice_shatter(parent, chest, 0.7)
			DESIGNED.crawl(parent, foe, 1.0)
		"charged_x_earth":  # Arc Flash: a magma pop, storm burst, a shock line
			INK.pop(parent, chest, "earth", 1.0)
			INK.pop(parent, chest, "wind", 0.8)
			INK.shock(parent, foot, PAL.of("earth").body, 1.6, 0.3)
		"charged_x_wind":  # Overload: the storm pop and crawl
			INK.pop(parent, chest, "wind", 1.1)
			DESIGNED.crawl(parent, foe, 1.1)


# --- Kills ----------------------------------------------------------------------------------------------------

const SOUL_SIZE := 1.2
const SOUL_TIMES := [0.06, 0.09, 0.09, 0.09, 0.1, 0.1, 0.11, 0.12]
const SOUL_RISE := 1.3  # m over its life


## Fx.soul (designed): two spirit wisps curling up off the corpse as it sinks, not a spray of dots.
static func soul(parent: Node, pos: Vector3) -> void:
	for k in 2:
		var fx := _spawn(parent, "air_wisp", pos + Vector3.UP * (0.45 + 0.35 * k) + Vector3(randf_range(-0.2, 0.2), 0.0, 0.0),
			SOUL_SIZE * (1.0 - 0.2 * k), "spirit", SOUL_TIMES, Vector2(0.45, 1.0))
		fx.set_spin(PI * 0.5 + randf_range(-0.3, 0.3), -1.0 if k % 2 else 1.0)
		var tw := fx.create_tween()
		tw.tween_property(fx, "global_position:y", fx.global_position.y + SOUL_RISE, 0.76).set_ease(Tween.EASE_OUT)


## hero_fx.last_kill (designed): the gold hit star held big over the last foe (its rings are shock stamps already).
static func last_kill(parent: Node, at: Vector3) -> void:
	var fx := DESIGNED.hit(parent, at + Vector3.UP * 1.1, "gold", 1.9)
	fx.real_time = true  # (the slow motion would hold it for a second)
