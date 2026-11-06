extends Node3D
## Designed effects (round 43, docs/features/designed-fx.md): authored flipbook sheets and strip textures
## (tools/vfx_gen/gen_designed.py -> assets/vfx/designed/) played on camera-facing quads, floor quads and shaped
## ribbons by three shaders (shaders/designed_*.gdshader). The sheets hold tone, not colour: each effect takes
## its element's five tones from fx_palette through one palette texture, so one drawing serves every element.
## Each effect is one of these nodes with a timeline: per-frame holds (anticipation short, the peak held, the
## rest on twos), then the shader's erosion eats it with an ink (or hot) burn line.
##
## On by default; `--fx=classic` (or `DESIGNED.enabled = false`) plays the old polygon effects, so before and
## after film from the same build. Every call site branches on `DESIGNED.on()` and keeps its old code path.
##   const DESIGNED := preload("res://scripts/designed_fx.gd")
##   if DESIGNED.on(): DESIGNED.hit(parent, at, "earth", 0.9)

const SELF := preload("res://scripts/designed_fx.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const STANDING := preload("res://scripts/standing_fx.gd")
const SPRITE := preload("res://shaders/designed_sprite.gdshader")
const SPRITE_DEPTH := preload("res://shaders/designed_sprite_depth.gdshader")
const GROUND := preload("res://shaders/designed_ground.gdshader")
const RIBBON := preload("res://shaders/designed_ribbon.gdshader")

## Palette rows, in the order of the palette texture.
const ROWS := ["hit", "wind", "water", "earth", "void", "spirit", "gold", "dust"]

## name -> texture, grid (cols, rows), frame count, shader kind, anchor (the pivot in quad units: sheets drawn
## standing on a ground line pivot there), burn (1 = the erosion edge burns hot, magma).
const SHEETS := {
	"hit_spark": {"tex": preload("res://assets/vfx/designed/hit_spark.png"), "grid": Vector2(4, 2), "frames": 8, "kind": "sprite"},
	"impact_streaks": {"tex": preload("res://assets/vfx/designed/impact_streaks.png"), "grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"slash_strip": {"tex": preload("res://assets/vfx/designed/slash_strip.png"), "grid": Vector2(1, 4), "frames": 4, "kind": "ribbon"},
	"magma_burst": {"tex": preload("res://assets/vfx/designed/magma_burst.png"), "grid": Vector2(4, 3), "frames": 10, "kind": "sprite_depth",
		"anchor": Vector2(0.0, -0.31), "burn": 1.0},
	"magma_wave": {"tex": preload("res://assets/vfx/designed/magma_wave.png"), "grid": Vector2(3, 2), "frames": 6, "kind": "ground", "burn": 1.0},
	"magma_crust": {"tex": preload("res://assets/vfx/designed/magma_crust.png"), "grid": Vector2(2, 2), "frames": 4, "kind": "ground", "burn": 1.0},
	"magma_splat": {"tex": preload("res://assets/vfx/designed/magma_splat.png"), "grid": Vector2(4, 2), "frames": 8, "kind": "sprite", "burn": 1.0},
	"ice_shatter": {"tex": preload("res://assets/vfx/designed/ice_shatter.png"), "grid": Vector2(4, 2), "frames": 8, "kind": "sprite"},
	"bolt_strip": {"tex": preload("res://assets/vfx/designed/bolt_strip.png"), "grid": Vector2(1, 4), "frames": 4, "kind": "ribbon"},
	"storm_burst": {"tex": preload("res://assets/vfx/designed/storm_burst.png"), "grid": Vector2(3, 2), "frames": 6, "kind": "sprite",
		"anchor": Vector2(0.0, -0.125)},
	"dust_puff": {"tex": preload("res://assets/vfx/designed/dust_puff.png"), "grid": Vector2(4, 2), "frames": 8, "kind": "sprite",
		"anchor": Vector2(0.0, -0.3)},
}

## Timelines: seconds each frame shows. Frame 0 is the anticipation (one 30 Hz frame), the peak holds, the
## tail runs on twos (1/12 s). `erode` is [start, end] as shares of the whole life.
const HIT_TIMES := [0.033, 0.075, 0.05, 0.042, 0.042, 0.042, 0.042, 0.042]
const STREAK_TIMES := [0.033, 0.042, 0.042, 0.042, 0.042, 0.042]
const MAGMA_TIMES := [0.05, 0.1, 0.083, 0.083, 0.083, 0.083, 0.083, 0.1, 0.12, 0.14]
const WAVE_TIMES := [0.042, 0.05, 0.06, 0.07, 0.08, 0.09]
const SPLAT_TIMES := [0.04, 0.09, 0.083, 0.083, 0.1, 0.12, 0.14, 0.3]
const ICE_TIMES := [0.05, 0.07, 0.05, 0.05, 0.05, 0.06, 0.06, 0.07]
const STORM_TIMES := [0.033, 0.07, 0.05, 0.05, 0.05, 0.06]
const DUST_TIMES := [0.042, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1, 0.11]
const CRUST_TIMES := [0.2, 0.35, 0.45, 0.6]

## Sizes at the game camera (about 48 px a metre at 1080p).
const HIT_SIZE := 1.6  # m: the quad, per Fx.HIT_STAR (0.9); the star's long tips reach ~0.7 m, the rest ~0.45 m
const STREAK_SIZE := 2.2
const STREAK_BACK := 0.36  # of the size: the sheet fans out from its left edge, so the quad moves that far along the blow
const SLASH_SPAN := 0.6  # of the arc: how long the stroke is behind its head
const SLASH_INNER := 0.7  # of the radius: the stroke's inner edge at its fullest (0.48 was a sheet over the pile)
const SLASH_INNER_LINES := 0.84  # Awakened gold and the spirit echo: a thinner stroke
const METEOR_BURST := 5.6  # m: the sheet's square (the crown stands ~2 m tall)
const METEOR_WAVE := 1.0  # of the pile radius: the wave's reach
const METEOR_CRUST := 0.55  # of the pile radius
const METEOR_BACK := 1.1  # m the crown stands behind the pile (depth tested: the foes stay in front of it)
const METEOR_SPLASH := 1.9  # m, the small crowns round the rim
const SPLAT_SIZE := 1.9
const ICE_SIZE := 2.3
const STRIKE_BURST := 1.6
const BOLT_TILE := 3.2  # the strip's length on the mesh, in widths: zigzags keep their drawn proportions
const DUST_SIZE := 1.3
const GROUND_LIFT := 0.065  # m: floor quads sit over the floor stones (their tallest is 0.05; at 0.03 only the grooves showed)

static var enabled := true
static var game_time_only := false  # tests that film with slow readbacks: real-time steps would jump frames
static var _args_read := false
static var _mats := {}
static var _palette: ImageTexture
static var _quad: QuadMesh
static var _plane: PlaneMesh


## Designed effects on? (`--fx=classic` turns them off for a before / after.)
static func on() -> bool:
	if not _args_read:
		_args_read = true
		for a: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
			if a == "--fx=classic":
				enabled = false
	return enabled


static func row(element: String) -> float:
	var e: String = PAL.ALIAS.get(element, element)
	var i := ROWS.find(e)
	return float(i if i >= 0 else 0)


static func palette() -> ImageTexture:
	if _palette == null:
		var img := Image.create(5, ROWS.size(), false, Image.FORMAT_RGBA8)
		for r in ROWS.size():
			var p: Dictionary = PAL.DUST if ROWS[r] == "dust" else PAL.of(ROWS[r])
			for k in 5:
				img.set_pixel(k, r, p[["ink", "deep", "body", "light", "hot"][k]])
		_palette = ImageTexture.create_from_image(img)
	return _palette


## One shared material per sheet (nothing compiles per effect; warm with prewarm()).
static func material(sheet: String) -> ShaderMaterial:
	if _mats.has(sheet):
		return _mats[sheet]
	var s: Dictionary = SHEETS[sheet]
	var m := ShaderMaterial.new()
	m.shader = {"sprite": SPRITE, "sprite_depth": SPRITE_DEPTH, "ground": GROUND, "ribbon": RIBBON}[s.kind]
	m.set_shader_parameter("sheet", s.tex)
	m.set_shader_parameter("palette", palette())
	m.set_shader_parameter("palette_rows", float(ROWS.size()))
	m.set_shader_parameter("burn_hot", s.get("burn", 0.0))
	if s.kind == "ribbon":
		m.set_shader_parameter("rows", s.grid.y)
	else:
		m.set_shader_parameter("grid", s.grid)
	if s.has("anchor"):
		m.set_shader_parameter("anchor", s.anchor)
	_mats[sheet] = m
	return m


static func _mesh_for(kind: String) -> Mesh:
	if kind == "ground":
		if _plane == null:
			_plane = PlaneMesh.new()
			_plane.size = Vector2.ONE
		return _plane
	if _quad == null:
		_quad = QuadMesh.new()
	return _quad


# --- the node -------------------------------------------------------------------------------------------------

var sheet := ""
var times: Array = []
var erode_span := Vector2(0.6, 1.0)  # shares of the life
var real_until := -1  # frames before this play in real time (anticipation -> peak through the hitstop)
var real_time := false  # the whole effect on real time (slow motion would stretch a lingering floor)
var pop := 0.0  # extra scale on frame 0, settling by frame 2
var standing := false  # fades when the next string's first hit lands (standing_fx)
var _mi: MeshInstance3D
var _base_scale := Vector3.ONE
var _t := 0.0
var _life := 0.0
var _last_us := 0
var _frame := -1
var _fade := 1.0
var _clearing := false


static func spawn(parent: Node, name_: String, at: Vector3, size: float, element: String, frame_times: Array,
		erode := Vector2(0.6, 1.0)) -> Node3D:
	var fx: Node3D = SELF.new()
	fx.sheet = name_
	fx.times = frame_times
	fx.erode_span = erode
	parent.add_child(fx)
	fx.top_level = true
	fx.global_position = at
	fx._build(size, element)
	return fx


func _build(size: float, element: String) -> void:
	var s: Dictionary = SHEETS[sheet]
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh_for(s.kind)
	_mi.material_override = material(sheet)
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.set_meta("no_ghost", true)
	_mi.extra_cull_margin = size * 2.0
	add_child(_mi)
	_base_scale = Vector3.ONE * size
	_mi.scale = _base_scale
	_mi.set_instance_shader_parameter("pal_row", row(element))
	_mi.set_instance_shader_parameter("frame", 0.0)
	_mi.set_instance_shader_parameter("erode", 0.0)
	for t: float in times:
		_life += t
	_last_us = Time.get_ticks_usec()
	if standing:
		STANDING.add(self)


## Random turn and mirror in the screen plane (sprites), so repeats never look stamped.
func vary(spin_range := PI, mirror := true) -> Node3D:
	_mi.set_instance_shader_parameter("spin", randf_range(-spin_range, spin_range))
	_mi.set_instance_shader_parameter("flip", -1.0 if mirror and randf() < 0.5 else 1.0)
	return self


func set_spin(a: float, mirror := 1.0) -> Node3D:
	_mi.set_instance_shader_parameter("spin", a)
	_mi.set_instance_shader_parameter("flip", mirror)
	return self


func clear_standing() -> void:
	_clearing = true


func _process(delta: float) -> void:
	if times.is_empty():  # (the ribbons run on their own tween)
		return
	var now := Time.get_ticks_usec()
	var real := float(now - _last_us) / 1000000.0
	_last_us = now
	tick(real if not game_time_only and (real_time or _frame < real_until) else delta)


## Public so a test can step it.
func tick(delta: float) -> void:
	_t += delta
	if _clearing:
		_fade -= delta / STANDING.CLEAR_S
		if _fade <= 0.0:
			queue_free()
			return
	if _t >= _life:
		queue_free()
		return
	var acc := 0.0
	var f := 0
	for i in times.size():
		acc += times[i]
		if _t < acc:
			f = i
			break
	if f != _frame:
		_frame = f
		_mi.set_instance_shader_parameter("frame", float(f))
		if pop > 0.0:
			_mi.scale = _base_scale * (1.0 + pop * maxf(0.0, 1.0 - f * 0.5))
	var share := _t / _life
	var e := clampf((share - erode_span.x) / maxf(erode_span.y - erode_span.x, 0.001), 0.0, 1.0)
	_mi.set_instance_shader_parameter("erode", e * 0.98)
	_mi.set_instance_shader_parameter("alpha", _fade)


# --- the effects ----------------------------------------------------------------------------------------------

## The every-hit impact star in the blow's element (Fx.hit_spark).
static func hit(parent: Node, at: Vector3, element: String, size := 0.9) -> Node3D:
	var fx := spawn(parent, "hit_spark", at, HIT_SIZE * size / 0.9, element, HIT_TIMES, Vector2(0.45, 1.0))
	fx.real_until = 1  # the anticipation flicks to the peak in real time; the peak holds through the hitstop
	fx.pop = 0.12
	return fx.vary(PI, true)


## The directional half of a hit (Fx.impact): streaks thrown along the knockback, turned to it on screen.
static func streaks(parent: Node, at: Vector3, dir: Vector3, element: String, big := false) -> Node3D:
	var size := STREAK_SIZE * (1.3 if big else 1.0)
	var fx := spawn(parent, "impact_streaks", at, size, element, STREAK_TIMES, Vector2(0.55, 1.0))
	fx.real_until = 1
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	var a := randf() * TAU
	if cam != null and dir.length() > 0.01:
		var d := dir.normalized()
		var sx := d.dot(cam.global_basis.x)
		var sy := d.dot(cam.global_basis.y)
		if Vector2(sx, sy).length() > 0.05:
			a = atan2(sy, sx)
	# the sheet's streaks start at its middle: push the quad half its size along the blow
	fx.position += (cam.global_basis.x * cos(a) + cam.global_basis.y * sin(a)) * size * STREAK_BACK if cam != null else Vector3.ZERO
	return fx.set_spin(a, 1.0 if randf() < 0.5 else -1.0)


## The melee swing (Fx.swoosh): the same arc mesh, with the authored brush stroke sliding along it.
static func slash(parent: Node, pos: Vector3, fwd: Vector3, radius: float, arc_deg: float, element: String,
		flip := false, time := 0.26, height := 0.8, lines_only := false) -> Node3D:
	var arc := deg_to_rad(clampf(arc_deg, 20.0, 360.0))
	var inner := radius * (SLASH_INNER_LINES if lines_only else SLASH_INNER)
	var segs := maxi(12, int(arc_deg / 5.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var u := float(i) / segs
		var a := (-arc * 0.5 + arc * u) * (-1.0 if flip else 1.0)
		var d := Vector3(sin(a), 0.0, cos(a))
		var r_in := lerpf(radius * 0.92, inner, minf(1.0, u * 3.0))  # the stroke's back starts thin
		st.set_uv(Vector2(u, 0.0))
		st.add_vertex(d * r_in)
		st.set_uv(Vector2(u, 1.0))
		st.add_vertex(d * radius)
	var fx: Node3D = SELF.new()
	fx.sheet = "slash_strip"
	parent.add_child(fx)
	fx.top_level = true
	fx.global_position = pos + Vector3.UP * height
	fx.rotation.y = atan2(fwd.x, fwd.z)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material("slash_strip")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	fx.add_child(mi)
	mi.set_instance_shader_parameter("pal_row", row(element))
	mi.set_instance_shader_parameter("span", SLASH_SPAN)
	mi.set_instance_shader_parameter("tiles", 0.0)
	var boil := randi() % 4
	var tw := fx.create_tween()
	tw.tween_method(func(p: float) -> void:
		var head := pow(p, 0.45) * (1.0 + SLASH_SPAN)
		mi.set_instance_shader_parameter("head", head)
		mi.set_instance_shader_parameter("frame", float((boil + int(p * time * 12.0)) % 4))  # boils on twos
		mi.set_instance_shader_parameter("erode", clampf((p - 0.35) / 0.65, 0.0, 1.0) * 0.98)
		mi.set_instance_shader_parameter("alpha", 0.75 if lines_only else 1.0), 0.0, 1.0, time)
	tw.tween_callback(fx.queue_free)
	return fx


## Meteor Fall's landing (void_element._meteor_landing): the crown burst, the lava wave rolling out, small
## crowns round the rim, and the cracked crust left on the floor (cools, then breaks up plate by plate).
static func meteor(parent: Node, at: Vector3, radius: float) -> void:
	var foot := Vector3(at.x, 0.0, at.z)
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	var back := Vector3.ZERO
	if cam != null:  # stand the crown a little behind the pile on screen, so the foes read in front of it
		var away := -cam.global_basis.z
		back = Vector3(away.x, 0.0, away.z).normalized() * METEOR_BACK
	var burst := spawn(parent, "magma_burst", foot + back, METEOR_BURST, "earth", MAGMA_TIMES, Vector2(0.62, 1.0))
	burst.real_until = 1
	burst.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	var wave := spawn(parent, "magma_wave", foot + Vector3.UP * (GROUND_LIFT + 0.01), radius * METEOR_WAVE * 2.0, "earth", WAVE_TIMES, Vector2(0.55, 1.0))
	wave.real_until = 1
	var crust := spawn(parent, "magma_crust", foot + Vector3.UP * GROUND_LIFT, radius * METEOR_CRUST * 2.0, "earth", CRUST_TIMES, Vector2(0.55, 1.0))
	crust.real_time = true
	crust.standing = true
	STANDING.add(crust)
	crust.rotation.y = randf() * TAU
	for k in 3:
		var a := TAU * (k + 0.25) / 3.0 + randf_range(-0.3, 0.3)
		var spot := foot + Vector3(sin(a), 0.0, cos(a)) * radius * 0.95
		var delay := 0.06 + 0.05 * k
		parent.get_tree().create_timer(delay, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(parent) and parent.is_inside_tree():
				spawn(parent, "magma_burst", spot, METEOR_SPLASH, "earth", MAGMA_TIMES, Vector2(0.5, 1.0)).set_spin(0.0, -1.0 if k % 2 else 1.0))


## Molten Palm's wall splat (thrown_foe._burst on a wall): a fat splash on the wall, drips running down.
static func wall_splat(parent: Node, at: Vector3, element := "earth") -> Node3D:
	var fx := spawn(parent, "magma_splat", at, SPLAT_SIZE, element, SPLAT_TIMES, Vector2(0.6, 1.0))
	fx.real_until = 1
	return fx.set_spin(randf_range(-0.25, 0.25), -1.0 if randf() < 0.5 else 1.0)


## Ice breaking (a frozen foe shattered, an ice cube bursting): faceted shards and glints.
static func ice_shatter(parent: Node, at: Vector3, size := 1.0) -> Node3D:
	var fx := spawn(parent, "ice_shatter", at, ICE_SIZE * size, "water", ICE_TIMES, Vector2(0.55, 1.0))
	fx.real_until = 1
	return fx.vary(0.5, true)


## A lightning bolt from `a` to `b` (comic_bolt.spawn: strikes out of the sky and the arcs between foes): the
## authored bolt strip on a camera-facing ribbon, its rows boiling on twos; with `star` it lands in a storm burst.
static func bolt(parent: Node, a: Vector3, b: Vector3, width := 0.24, star := 0.0, _forks := 1) -> Node3D:
	var fx: Node3D = SELF.new()
	fx.sheet = "bolt_strip"
	parent.add_child(fx)
	fx.top_level = true
	fx.global_transform = Transform3D.IDENTITY
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	var view := cam.global_basis.z if cam != null else Vector3.BACK
	var span := b - a
	var across := span.cross(view)
	across = across.normalized() if across.length() > 0.001 else Vector3.RIGHT
	var w := maxf(width, 0.18) * 2.6  # the strip's height: the bolt's body is ~a third of it, forks use the rest
	var n := 8
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		var p := a + span * u
		var taper := 0.55 + 0.45 * sin(minf(u * 1.4, 1.0) * PI * 0.5)  # thin out of the sky, full at the foot
		verts.append_array([p + across * w * 0.5 * taper, p - across * w * 0.5 * taper])
		uvs.append_array([Vector2(u, 1.0), Vector2(u, 0.0)])
	var idx := PackedInt32Array()
	for i in n:
		var k := i * 2
		idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material("bolt_strip")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.extra_cull_margin = 16.0
	fx.add_child(mi)
	mi.set_instance_shader_parameter("pal_row", row("wind"))
	mi.set_instance_shader_parameter("tiles", maxf(1.0, span.length() / (w * BOLT_TILE)))
	mi.set_instance_shader_parameter("scroll", randf())
	var boil := randi() % 4
	var life := 0.3
	var tw := fx.create_tween()
	tw.tween_method(func(p: float) -> void:
		var step := int(p * life * 12.0)
		mi.set_instance_shader_parameter("frame", float((boil + step) % 4))
		mi.set_instance_shader_parameter("scroll", float(boil) * 0.37 + step * 0.21)
		mi.set_instance_shader_parameter("erode", clampf((p - 0.45) / 0.55, 0.0, 1.0) * 0.98), 0.0, 1.0, life)
	tw.tween_callback(fx.queue_free)
	if star > 0.0:
		var foot := Vector3(b.x, 0.0, b.z)
		var burst := spawn(parent, "storm_burst", foot, STRIKE_BURST * clampf(star / 1.1, 0.6, 1.4), "wind", STORM_TIMES, Vector2(0.5, 1.0))
		burst.real_until = 1
		burst.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	return fx


## A ground-dust puff (landings, skids, slams).
static func dust(parent: Node, at: Vector3, size := 1.0) -> Node3D:
	var fx := spawn(parent, "dust_puff", Vector3(at.x, 0.0, at.z), DUST_SIZE * size, "dust", DUST_TIMES, Vector2(0.4, 1.0))
	return fx.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)


## Draw every material once at real size under `root` (elements.prewarm), so no effect compiles on first use.
static func prewarm(root: Node3D) -> void:
	for name_: String in SHEETS:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh_for(SHEETS[name_].kind)
		mi.material_override = material(name_)
		root.add_child(mi)
		mi.scale = Vector3.ONE * 20.0  # (the prewarm root is at 5%)
