extends RefCounted
## The dark element's things in the world, in flat ink and violet: the black hole (Singularity), the mark
## (Reap), the pool (Black Tide, Overwhelm), the jaws (Maw). What they do to foes is in void_element.gd,
## except the hole's pull. See docs/features/void-element.md.

const FOES := preload("res://scripts/foes.gd")
const SELF := preload("res://scripts/dark_fx.gd")
const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const INK_SHADER := preload("res://shaders/dark_ink.gdshader")
const STANDING := preload("res://scripts/standing_fx.gd")

const INK_FX := preload("res://scripts/designed_ink.gd")
const INK := Color(0.03, 0.01, 0.06)
const VIOLET := Color(0.62, 0.3, 1.0)
const HOT := Color(1.0, 0.4, 0.95)
const MARK_NAME := "VoidMark"
const MARK_TIME := 6.0  # s
const MARK_R := 0.75  # m round the foe's feet
const MARK_DRAWN := 2.8  # fx-polygons: the drawn mark's square per metre of its radius (its strokes sit at ~0.62 of the half)
## Round 33 (sleek; feel audit item 7): a pool's ink stays on the floor at most this long, whatever its
## gameplay time (the binds still hold the foes): at 1.8-2.2 s it sat under the next string.
const POOL_SHOW := 1.1
const POOL_DRAWN := 1.25  # round 45: the designed pool's quad is this many radii across each way (the arm tips reach ~r)


static func flat_mat(color: Color, ink := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if ink and DisplayServer.get_name() != "headless":
		mat.next_pass = Fx.ink_material()
	return mat


static func part(parent: Node3D, mesh: Mesh, mat: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.position = at
	return m


## Churning ink for the floor: goes on floor_ink().
static func ink_mat(spin := 0.9, flow := 1.6) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = INK_SHADER
	mat.set_shader_parameter("spin", spin)
	mat.set_shader_parameter("flow", flow)
	mat.set_shader_parameter("seed", randf() * 40.0)
	return mat


static func set_param(value: float, mat: ShaderMaterial, param: String) -> void:
	mat.set_shader_parameter(param, value)


static func floor_ink() -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	return plane


## A hard-edged ring on the floor that runs out to `to` and goes: a designed ground stamp (inked brush shock line).
static func hoop_run(parent: Node, spot: Vector3, _from: float, to: float, time: float, color := VIOLET, thin := 0.08) -> void:
	INK_FX.shock(parent, spot, color, to, time + 0.08, clampf(thin * to * 1.6, INK_FX.SHOCK_THIN_W, 0.36))


## An inky pop at a spot.
## A held-frame ink splat and chunky ink debris, in place of the soft flare and violet dots it had.
static func burst(parent: Node, at: Vector3, size := 1.0) -> void:
	splat(parent, at + Vector3.UP * 0.9, 1.1 * size)
	Fx.shards(parent, at + Vector3.UP * 0.5, INK, int(10 * size), Vector3.UP, 7.0 * size, 0.16, 0.5)


const REAP_DRAWN := 0.6

## A crescent of darkness flying out in front of him: the authored brush crescent in the dark palette, drawn at
## REAP_DRAWN of the reach (the full 6.5 m arc's band was a 2 m slab).
static func reap(parent: Node, at: Vector3, fwd: Vector3, reach: float, half_angle: float) -> void:
	INK_FX.DESIGNED.slash(parent, Vector3(at.x, 0.0, at.z), fwd, reach * REAP_DRAWN, rad_to_deg(half_angle) * 2.0, "void", false, 0.24, 0.8)


## Puts a mark on a foe (or renews it). Black Tide comes for the marked.
static func mark(e: Node3D) -> void:
	var old: Node = e.get_node_or_null(MARK_NAME)
	if old != null:
		old.life = MARK_TIME
		old.relight()
		return
	var m := Mark.new()
	m.name = MARK_NAME
	e.add_child(m)
	m.position.y = 0.08


static func marked(e: Node) -> bool:
	return e.get_node_or_null(MARK_NAME) != null


static func unmark(e: Node) -> void:
	var m: Node = e.get_node_or_null(MARK_NAME)
	if m != null:
		m.name = "VoidMarkGone"
		m.queue_free()


class Mark extends Node3D:
	var life := MARK_TIME
	var _spin: Node3D

	func _ready() -> void:
		var r: float = MARK_R + float(get_parent().get("radius") if get_parent().get("radius") != null else 0.5) * 0.5
		_spin = Node3D.new()
		add_child(_spin)
		STANDING.add(self)
		load("res://scripts/designed_polish.gd").loop(_spin, "tell_marked", r * MARK_DRAWN, "void")  # three drawn ink claw strokes round its feet, spinning

	## The next string's first hit landed (standing_fx.gd): the arcs go, the mark stays for Black Tide.
	func clear_standing() -> void:
		var tw := create_tween()
		tw.tween_property(_spin, "scale", Vector3.ONE * 0.01, STANDING.CLEAR_S)
		tw.tween_callback(_spin.hide)

	## Marked again: the arcs come back.
	func relight() -> void:
		if not _spin.visible or _spin.scale.x < 1.0:
			_spin.show()
			_spin.scale = Vector3.ONE
			STANDING.add(self)

	func _process(delta: float) -> void:
		life -= delta
		_spin.rotate_y(3.5 * delta)
		if life <= 0.0:
			name = "VoidMarkGone"
			queue_free()


## A pool of black on the floor, there for `time`.
static func pool(parent: Node, spot: Vector3, r: float, time: float) -> Node3D:
	var p := Pool.new()
	p.r = r
	p.time = time
	parent.add_child(p)
	p.global_position = Vector3(spot.x, 0.05, spot.z)
	return p


class Pool extends Node3D:
	const OPEN_S := 0.14  # s its opening tween takes
	const POOL_THIN_SIZE := 0.7  # of its size while thin (it draws in under the slam)
	var r := 3.0
	var time := 2.0
	var _t := 0.0

	var _loop: Node3D

	func _ready() -> void:
		add_to_group("dark_pool")
		_loop = INK_FX.floor_loop(self, "dark_pool", 2.0 * SELF.POOL_DRAWN)  # an authored ink pool (curling arms, holes, a light rim), boiling on twos
		scale = Vector3(r * 0.3, 1.0, r * 0.3)
		create_tween().tween_property(self, "scale", Vector3(r, 1.0, r), OPEN_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		STANDING.add(self)

	## The next string's first hit landed (standing_fx.gd): the ink erodes now.
	func clear_standing() -> void:
		time = minf(time, _t)

	## Round 56 (feel-audit6): the pool goes see-through to `to` over `down` s, stays `hold` s, and comes back over `up` s
	## (Overwhelm's haul: the slam read as one more purple shape on the busy pool). Designed pools only.
	func thin(to: float, down: float, hold: float, up: float) -> void:
		if _loop == null or not is_instance_valid(_loop):
			return
		var tw := create_tween()
		tw.tween_interval(maxf(OPEN_S - _t, 0.0))  # (past its own opening tween on the scale)
		tw.tween_method(_loop.set_alpha, 1.0, to, down)
		tw.parallel().tween_property(self, "scale", Vector3(r * POOL_THIN_SIZE, 1.0, r * POOL_THIN_SIZE), down)
		tw.tween_interval(hold)
		tw.tween_method(_loop.set_alpha, to, 1.0, up)
		tw.parallel().tween_property(self, "scale", Vector3(r, 1.0, r), up)


	func _process(delta: float) -> void:
		_t += delta
		if _t >= time or _t >= SELF.POOL_SHOW:
			set_process(false)
			_loop.erode_out(0.25)
			get_tree().create_timer(0.27, true, false, true).timeout.connect(queue_free)


## The black hole. It drags small foes to it and slows big ones, burning all of them.
class Hole extends Node3D:
	const RADIUS := 6.5  # m
	const PULL := 9.0  # m/s
	const STOP := 0.9  # m from the middle they stop
	const LIFE := 2.4  # s
	const TICK := 0.25  # s
	const TICK_DAMAGE := 3.0
	const BIG_SLOW := 0.4
	const STAGGER := 0.9
	const STAGGER_EVERY := 0.25  # s
	const VIEW_R := 2.6  # m the ink shows out to (the look only; the pull is RADIUS)
	const COLLAPSE_SPLAT := 2.2  # m: the ink burst as it falls in (thin; sleek 6: 2.8 full-width)
	const FLYING := "thrown_foe_flying"

	var hero: CharacterBody3D
	var power := 1.0
	var _t := 0.0
	var _next_tick := 0.0
	var _next_stagger := 0.0
	var _gone := false
	var _spin: Node3D

	func _ready() -> void:
		add_to_group("dark_hole")
		_spin = Node3D.new()
		add_child(_spin)
		INK_FX.floor_loop(_spin, "dark_vortex", VIEW_R * 2.3)  # an authored vortex decal (curling arms into an ink hole), spun
		scale = Vector3(0.05, 1.0, 0.05)
		create_tween().tween_property(self, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		SELF.splat(get_parent(), global_position + Vector3.UP * 0.9, 1.6, true)
		Fx.shards(get_parent(), global_position + Vector3.UP * 0.5, INK, 8, Vector3.UP, 7.0, 0.16, 0.5)
		Game.shake(0.3)

	func _physics_process(delta: float) -> void:
		if _gone:
			return
		_t += delta
		_spin.rotate_y(-7.0 * delta)
		var tick := _t >= _next_tick
		if tick:
			_next_tick += TICK
		var again := _t >= _next_stagger
		if again:
			_next_stagger += STAGGER_EVERY
		for e: Node3D in FOES.near(get_tree(), global_position, RADIUS):
			if e.has_meta(FLYING):
				continue
			var to := global_position - e.global_position
			to.y = 0.0
			if float(e.get("radius")) >= 0.9:  # (no foe in play is this heavy)
				if e.has_method("chill"):
					e.chill(0.4, BIG_SLOW)
			else:
				if to.length() > STOP:
					e.global_position += to.normalized() * minf(PULL * delta, to.length() - STOP)
				e.velocity = Vector3.ZERO
				if again and e.has_method("stagger"):
					e.stagger(STAGGER)
			if tick:
				SELF.quiet_hit(e, TICK_DAMAGE * power)
				Game.register_hit("cast")
		if _t >= LIFE:
			fade()

	func fade() -> void:
		if _gone:
			return
		_gone = true
		remove_from_group("dark_hole")
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(0.05, 1.0, 0.05), 0.15)
		tw.tween_callback(queue_free)

	## It falls in on itself and blows. The damage is void_element._collapse's.
	func collapse() -> void:
		if _gone:
			return
		_gone = true
		remove_from_group("dark_hole")
		var parent := get_parent()
		var at := global_position
		SELF.hoop_run(parent, at, 0.5, RADIUS * 0.8, 0.28, HOT, 0.04)
		SELF.splat(parent, at + Vector3.UP * 1.2, COLLAPSE_SPLAT, true)
		SELF.ink_drops(parent, at + Vector3.UP * 0.8, 3, RADIUS * 0.6)
		Fx.shards(parent, at + Vector3.UP * 0.5, INK, 8, Vector3.UP, 9.0, 0.18, 0.5)
		queue_free()


## Jaws of darkness out of the floor, closing on `spot`.
static func maw(parent: Node, spot: Vector3, r: float) -> Node3D:
	var m := Maw.new()
	m.r = r
	parent.add_child(m)
	m.global_position = Vector3(spot.x, 0.0, spot.z)
	return m


## A curved fang standing on its base and bending towards -Z, in hard bands of ink, violet and a hot tip.
static func fang_mesh(high: float, base: float, bend: float) -> ArrayMesh:
	const SEGMENTS := 6
	const SIDES := 5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for i in SEGMENTS:
		var k0 := float(i) / SEGMENTS
		var k1 := float(i + 1) / SEGMENTS
		var color := INK if k0 < 0.5 else (VIOLET if k0 < 0.8 else HOT)
		for j in SIDES:
			var a0 := TAU * j / SIDES
			var a1 := TAU * (j + 1) / SIDES
			var low0 := _fang_point(k0, a0, high, base, bend)
			var low1 := _fang_point(k0, a1, high, base, bend)
			var up0 := _fang_point(k1, a0, high, base, bend)
			var up1 := _fang_point(k1, a1, high, base, bend)
			for v: Array in [[low1, a1], [up1, a1], [up0, a0], [low1, a1], [up0, a0], [low0, a0]]:  # (clockwise from outside)
				st.set_color(color)
				st.set_normal(Vector3(cos(v[1]), 0.15, sin(v[1])).normalized())
				st.add_vertex(v[0])
	return st.commit()


static func _fang_point(k: float, a: float, high: float, base: float, bend: float) -> Vector3:
	var w := base * pow(1.0 - k, 0.8)
	return Vector3(cos(a) * w, k * high, sin(a) * w - bend * k * k)


## Jaws of black rising out of the floor. They come up open while he dives and bite() shuts them as he lands,
## so the hit and its hitstop hold the shut frame. Timing is deliberately stepped, not eased.
class Maw extends Node3D:
	const RISE := 0.1  # s
	const LEAN_OPEN := 0.55  # rad, leaning out
	const LEAN_SNAP := -0.62  # past shut: held through the hitstop
	const LEAN_SHUT := -0.46  # a ring of teeth round them, not a lid: the foes stay in sight
	const NEAR_SHORT := 0.35  # how tall the teeth between the camera and the foes are (sleek 6: 0.55)
	const SNAP_HOLD := 0.05  # s
	const HOLD := 0.3  # s shut
	const SINK := 0.14  # s
	const WAIT_MAX := 1.0  # s with no bite, then they go anyway
	## count, height, base, at what fraction of r. Round 33, sleek 6: one row of 11 (15 + 11 at 2.9 / 1.6 m stood as a
	## black and violet wall round the pile, with a 4.3 m splat and a hoop on top).
	const ROWS := [[9, 1.9, 0.3, 1.0]]
	const BITE_SPLAT := 0.8  # of r: the bite's one thin splat (1.25, full width)

	var r := 3.4
	var _t := 0.0
	var _last_us := 0
	var _bitten := -1.0
	var _sinking := false
	var _ink: ShaderMaterial
	var _fangs := []  # {pivot, jitter}
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		add_to_group("dark_maw")
		_rng.randomize()
		_ink = SELF.ink_mat(3.0, 4.0)
		_ink.set_shader_parameter("open", 0.2)
		var pit := SELF.part(self, SELF.floor_ink(), _ink, Vector3.UP * 0.07)
		pit.scale = Vector3(r * 1.1, 1.0, r * 1.1)
		var mat := SELF.flat_mat(Color.WHITE, true)
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		for row: Array in ROWS:
			var count: int = row[0]
			for i in count:
				var a := TAU * (i + 0.5 * float(row[3] < 1.0)) / count + _rng.randf_range(-0.05, 0.05)
				var high: float = row[1] * _rng.randf_range(0.8, 1.2) * lerpf(1.0, NEAR_SHORT, maxf(cos(a), 0.0))  # (the camera's on +Z)
				var pivot := Node3D.new()
				add_child(pivot)
				pivot.position = Vector3(sin(a), 0.0, cos(a)) * r * row[3]
				pivot.rotation = Vector3(LEAN_OPEN, a, 0.0)
				pivot.scale = Vector3(1.0, 0.02, 1.0)
				SELF.part(pivot, SELF.fang_mesh(high, row[2], high * 0.25), mat)
				_fangs.append({"pivot": pivot, "jitter": _rng.randf_range(-0.09, 0.09)})

	func _process(delta: float) -> void:
		var now := Time.get_ticks_usec()
		if _bitten >= 0.0:  # shut on real time: the bite's hitstop held the jaws 2 s over the pile
			delta = minf((now - _last_us) / 1000000.0, 0.1)
		_last_us = now
		_t += delta
		if _sinking:
			position.y -= 4.0 / SINK * delta
			return
		if _bitten < 0.0:
			var k := minf(_t / RISE, 1.0)
			var up := 1.0 - (1.0 - k) * (1.0 - k)
			_ink.set_shader_parameter("open", lerpf(0.2, 1.0, up))
			for f: Dictionary in _fangs:
				f.pivot.scale.y = maxf(up, 0.02)
			if _t >= WAIT_MAX:
				_sink()
			return
		var since := _t - _bitten
		var shake := 0.03 if int(since * 12.0) % 2 == 0 else -0.03  # on twos
		var lean := LEAN_SNAP if since < SNAP_HOLD else LEAN_SHUT + shake
		for f: Dictionary in _fangs:
			f.pivot.rotation.x = lean + f.jitter
		if since >= HOLD:
			_sink()

	## Shut, right now: this is the frame the hitstop holds.
	func bite() -> void:
		if _bitten >= 0.0:
			return
		_bitten = _t
		_ink.set_shader_parameter("open", 1.0)
		_ink.set_shader_parameter("spin", 7.0)
		for f: Dictionary in _fangs:
			f.pivot.scale.y = 1.0
			f.pivot.rotation.x = LEAN_SNAP + f.jitter
		SELF.splat(get_parent(), global_position + Vector3.UP * 1.3, r * BITE_SPLAT, true)
		SELF.ink_drops(get_parent(), global_position + Vector3.UP * 0.8, 3, r * 1.5)
		SELF.hoop_run(get_parent(), global_position, r * 0.9, r * 1.45, 0.2, HOT, 0.025)

	func _sink() -> void:
		_sinking = true
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_method(SELF.set_param.bind(_ink, "erode"), 0.0, 1.0, SINK * 1.6)
		tw.tween_callback(queue_free)


## A burst of ink tentacles that plays as a few held frames, not a smooth fade.
static func splat(parent: Node, at: Vector3, size: float, thin := false) -> void:
	var s := Splat.new()
	s.thin = thin
	parent.add_child(s)
	s.global_position = at
	s.size = size


class Splat extends Node3D:
	## Ink tentacles lashing out of a blob, flat and facing the camera, on twos: an inked edge, a violet
	## body and a hot core line down each, tapering in segments, curling as they go. The old spiky shader
	## splat read as flat black slabs (four of them over a towed pile), not as tentacles.
	const FRAMES := [0.12, 0.3, 0.52, 0.74, 0.92]  # how far through it each held frame is
	const FRAME_TIME := 0.05  # s
	const REACH_BY_FRAME := [0.6, 1.0, 1.05, 0.95, 0.7]
	const WIDTH_BY_FRAME := [1.15, 1.05, 0.95, 0.75, 0.45]
	const ARMS := Vector2i(5, 7)
	const ARM_W := 0.14  # of the size: the ink half-width at the root
	const SEGMENTS := 4  # each narrows to its joint, so the arm reads as a tentacle
	const POINTS := 16
	const BLOB := 0.3  # of the size: the middle
	const SLEEK_W := 0.75  # round 33 (sleek): thinner arms, with a thin ink line instead of a hull 1.6x the violet
	## Round 33, sleek 6 (`thin`, the breaker landings: Abyss, Maw, Collapse): the arms are lines, a THIN_ARM_W m
	## violet stroke in a LINE of ink with no hot core, out of a small blob, so the pile reads through them. The
	## full-width arms of a 2.8-4 m splat were a violet wall over every foe on the pile.
	const THIN_ARM_W := 0.05  # m: half the violet stroke at the root
	const THIN_BLOB := 0.45  # of BLOB

	var size := 3.0
	var thin := false
	var _t := 0.0
	var _frame := -1
	var _right := Vector3.RIGHT
	var _up := Vector3.UP
	var _arms := []  # [angle, reach, curl, width]
	var _blob := PackedFloat32Array()
	var _rng := RandomNumberGenerator.new()
	var _mesh := ArrayMesh.new()
	var _verts := PackedVector3Array()
	var _colors := PackedColorArray()

	func _ready() -> void:
		_rng.randomize()
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_right = cam.global_basis.x
			_up = cam.global_basis.y
		var n := _rng.randi_range(ARMS.x, ARMS.y)
		var turn := _rng.randf() * TAU
		for i in n:
			_arms.append([turn + TAU * (i + _rng.randf_range(-0.2, 0.2)) / n, _rng.randf_range(0.7, 1.0),
				_rng.randf_range(0.5, 1.1) * (1.0 if _rng.randf() < 0.5 else -1.0), _rng.randf_range(0.8, 1.15)])
		for i in 9:
			_blob.append(_rng.randf_range(0.8, 1.2))
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = size + 2.0
		mi.set_meta("no_ghost", true)
		add_child(mi)
		tick(0.0)

	func _process(delta: float) -> void:
		tick(delta)

	## Public so a test can step it exactly.
	func tick(delta: float) -> void:
		_t += delta
		var frame := int(_t / FRAME_TIME)
		if frame >= FRAMES.size():
			queue_free()
			return
		if frame != _frame:
			_frame = frame
			_draw(frame)

	func _draw(f: int) -> void:
		_verts.clear()
		_colors.clear()
		var reach: float = size * REACH_BY_FRAME[f]
		var w: float = size * ARM_W * SLEEK_W * WIDTH_BY_FRAME[f]
		var last := f == FRAMES.size() - 1
		var line := 0.035 * 2.0  # fx_palette.LINE each side
		if thin:
			_draw_thin(f, reach, line)
			return
		for arm: Array in _arms:
			_arm(arm, reach, w * 0.62 + line, INK)
		_disc(size * BLOB * WIDTH_BY_FRAME[f] * 0.9 + line, INK)
		var body := Color(VIOLET, 0.6 if last else 0.88)
		for arm: Array in _arms:
			_arm(arm, reach * 0.97, w * 0.62, body)
		_disc(size * BLOB * WIDTH_BY_FRAME[f] * 0.9, body)
		if not last:
			for arm: Array in _arms:
				_arm(arm, reach * 0.85, w * 0.2, HOT)
			_disc(size * BLOB * 0.42 * WIDTH_BY_FRAME[f], INK)  # the hole in the middle
		_mesh.clear_surfaces()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts
		arrays[Mesh.ARRAY_COLOR] = _colors
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_mesh.surface_set_material(0, FORM_FX.material())

	## Lines, not slabs: an ink stroke under a violet one per arm, a small ink blob with a violet rim.
	func _draw_thin(f: int, reach: float, line: float) -> void:
		var w: float = THIN_ARM_W * WIDTH_BY_FRAME[f]
		var blob: float = size * BLOB * THIN_BLOB * WIDTH_BY_FRAME[f]
		var last := f == FRAMES.size() - 1
		for arm: Array in _arms:
			_arm(arm, reach, w + line * 0.5, INK)
		_disc(blob + line * 0.5, INK)
		var body := Color(VIOLET, 0.55 if last else 0.9)
		for arm: Array in _arms:
			_arm(arm, reach * 0.97, w, body)
		_disc(blob, body)
		_disc(blob * 0.6, INK)
		_commit()

	func _commit() -> void:
		_mesh.clear_surfaces()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts
		arrays[Mesh.ARRAY_COLOR] = _colors
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_mesh.surface_set_material(0, FORM_FX.material())

	func _screen(a: float) -> Vector3:
		return _right * cos(a) + _up * sin(a)

	## One tentacle: out from the blob's edge along its angle, curling, segment by segment narrower.
	func _arm(arm: Array, reach: float, w: float, c: Color) -> void:
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for i in POINTS + 1:
			var k := float(i) / POINTS
			var a: float = arm[0] + arm[2] * k * k
			var along := _screen(a)
			var side := _screen(a + PI * 0.5)
			var p: Vector3 = along * (size * BLOB * 0.5 + reach * float(arm[1]) * k)
			var seg := fmod(k * SEGMENTS, 1.0)
			var half: float = w * arm[3] * pow(1.0 - k, 0.7) * (1.0 - 0.3 * seg)
			var l: Vector3 = p + side * half
			var r: Vector3 = p - side * half
			if i > 0:
				_tri(prev_l, prev_r, l, c)
				_tri(l, prev_r, r, c)
			prev_l = l
			prev_r = r

	func _disc(r: float, c: Color) -> void:
		var n := _blob.size()
		for i in n:
			_tri(Vector3.ZERO, _screen(TAU * i / n) * r * _blob[i], _screen(TAU * (i + 1) / n) * r * _blob[(i + 1) % n], c)

	func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
		_verts.append_array([a, b, c])
		_colors.append_array([col, col, col])


## Fat drops of ink flung out, falling and shrinking away.
static func ink_drops(parent: Node, at: Vector3, count: int, reach: float) -> void:
	var mat := flat_mat(VIOLET, true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	for i in count:
		var ball := SphereMesh.new()
		var size := randf_range(0.05, 0.14)
		ball.radius = size
		ball.height = size * 2.0
		ball.radial_segments = 12
		ball.rings = 6
		var root := Node3D.new()
		parent.add_child(root)
		root.global_position = at
		part(root, ball, mat)
		var a := TAU * (i + randf()) / count
		var far := randf_range(0.55, 1.0) * reach
		var end := at + Vector3(sin(a), 0.0, cos(a)) * far
		end.y = 0.1
		var time := randf_range(0.2, 0.34)
		var tw := root.create_tween().set_parallel()
		tw.tween_property(root, "global_position:x", end.x, time)
		tw.tween_property(root, "global_position:z", end.z, time)
		tw.tween_property(root, "global_position:y", at.y + randf_range(0.8, 2.0), time * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(root, "global_position:y", end.y, time * 0.6).set_delay(time * 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(root, "scale", Vector3.ONE * 0.1, time * 0.4).set_delay(time * 0.6)
		tw.chain().tween_callback(root.queue_free)


## Materials that want compiling before their first fight (elements.prewarm), at a real size.
static func prewarm_pieces(root: Node3D) -> void:
	part(root, floor_ink(), ink_mat())  # (Splat draws with heretic_form_fx's material, warmed with the form bursts)


## A hit that does its damage and number without sparks or a word per foe: the source draws its own.
static func quiet_hit(e: Node, damage: float, big := false, knockback := Vector3.ZERO) -> void:
	if e.has_method("burn_hit"):
		e.burn_hit(damage, big, knockback)
	else:
		e.take_hit(damage, knockback, 0.0, big)


## A spike of black going straight up from under a foe: a flat inked spike facing the camera, violet
## round a hot core so it reads on the dark floor, coming up SPOUT_DELAY s after the landing so the
## impact frame doesn't swallow it, overshooting and breaking up on twos.
const SPOUT_DELAY := 0.12
const SPOUT_GROW := 1.0  # of the asked height (sleek 6: 1.3)
const SPOUT_HALF_W := 0.22  # m at the base (round 33, sleek 6: 0.5; three over the Abyss pile were a violet fence)
const SPOUT_BY_STEP := [1.15, 1.0, 0.85, 0.45]  # height; the last is colour only


## Abyss asks for one per foe; over a pile that was a wall of spikes. Spouts asked for together (inside
## SPOUT_SAME_MS) keep SPOUT_SPACING apart and stop at SPOUT_MAX; the rest are skipped (null).
const SPOUT_SAME_MS := 100
const SPOUT_SPACING := 2.0  # m
const SPOUT_MAX := 3
## Round 33, sleek 6: each spout burst its own 1.1 m splat and the Overwhelm pool (3.6 m of churning ink with violet
## streaks) still lay under the pile, so Abyss's landing was a dark splat and violet arms over every foe. Now the
## batch's first spout draws the one splat, thin (Splat.thin), at the middle of the batch, the others only chips,
## and the first one erodes any dark pool under them (the pool's job, holding them, is done).
const SPOUT_SPLAT := 2.2  # m: the batch's one thin splat
const SPOUT_POOL_CLEAR := 4.5  # m round the batch's first spout a dark pool erodes
static var _spouts := []  # [ms, flat position] of this batch


static func spout(parent: Node, spot: Vector3, high := 3.4) -> Node3D:
	var now := Time.get_ticks_msec()
	var flat := Vector3(spot.x, 0.0, spot.z)
	_spouts = _spouts.filter(func(r: Array) -> bool: return now - int(r[0]) <= SPOUT_SAME_MS)
	if _spouts.size() >= SPOUT_MAX:
		return null
	for r: Array in _spouts:
		if (r[1] as Vector3).distance_to(flat) < SPOUT_SPACING:
			return null
	var s := Spout.new()
	s.lead = _spouts.is_empty()
	if s.lead and parent.is_inside_tree():  # the landing: the pool under them erodes now, not after the spouts
		for p: Node in parent.get_tree().get_nodes_in_group("dark_pool"):
			if p is Node3D and (p as Node3D).global_position.distance_to(flat) < SPOUT_POOL_CLEAR:
				p.clear_standing()
	_spouts.append([now, flat])
	s.high = high * SPOUT_GROW
	parent.add_child(s)
	s.global_position = Vector3(spot.x, 0.0, spot.z)
	return s


class Spout extends Node3D:
	var high := 4.4
	var lead := false  # the first of its batch: draws the batch's one splat
	var _t := 0.0
	var _step := -1
	var _right := Vector3.RIGHT
	var _mesh := ArrayMesh.new()
	var _verts := PackedVector3Array()
	var _colors := PackedColorArray()
	var _lean := 0.0

	func _ready() -> void:
		add_to_group("dark_spout")
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_right = cam.global_basis.x
		_lean = randf_range(-0.12, 0.12)
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = high + 2.0
		add_child(mi)

	func _process(delta: float) -> void:
		tick(delta)

	## Public so a test can step it exactly.
	func tick(delta: float) -> void:
		_t += delta
		if _t < SPOUT_DELAY:
			return
		var step := int((_t - SPOUT_DELAY) * 12.0)
		if step >= SPOUT_BY_STEP.size():
			queue_free()
			return
		if step == _step:
			return
		if _step < 0:
			_burst()
		_step = step
		_verts.clear()
		_colors.clear()
		var h: float = high * SPOUT_BY_STEP[step]
		var last := step == SPOUT_BY_STEP.size() - 1
		var tip := Vector3.UP * h + _right * h * _lean
		if not last:
			_spike(tip * 1.02, SPOUT_HALF_W + 0.07, INK)  # round 33: a thin ink line, not a hull 1.5x
		_spike(tip, SPOUT_HALF_W * (0.6 if last else 1.0), VIOLET)
		if not last:
			_spike(tip * 0.8, SPOUT_HALF_W * 0.38, HOT)
		_mesh.clear_surfaces()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts
		arrays[Mesh.ARRAY_COLOR] = _colors
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_mesh.surface_set_material(0, FORM_FX.material())

	## The batch's one thin splat at its middle (lead), chips under each.
	func _burst() -> void:
		var parent := get_parent()
		Fx.shards(parent, global_position + Vector3.UP * 0.5, INK, 6, Vector3.UP, 6.0, 0.14, 0.45)
		if not lead:
			return
		var mid := Vector3.ZERO
		for r: Array in SELF._spouts:
			mid += r[1]
		mid = mid / float(SELF._spouts.size()) if not SELF._spouts.is_empty() else global_position
		SELF.splat(parent, Vector3(mid.x, 0.9, mid.z), SPOUT_SPLAT, true)

	func _spike(tip: Vector3, w: float, c: Color) -> void:
		var a := _right * w
		_verts.append_array([-a, a, tip])
		_colors.append_array([c, c, c])
