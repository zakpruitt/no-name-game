extends RefCounted
## The dark element's things in the world, in flat ink and violet: the black hole (Singularity), the mark
## (Reap), the pool (Black Tide, Overwhelm), the jaws (Maw). What they do to foes is in void_element.gd,
## except the hole's pull. See docs/features/void-element.md.

const SELF := preload("res://scripts/dark_fx.gd")
const INK_SHADER := preload("res://shaders/dark_ink.gdshader")
const SPLAT_SHADER := preload("res://shaders/dark_splat.gdshader")

const INK := Color(0.03, 0.01, 0.06)
const VIOLET := Color(0.62, 0.3, 1.0)
const HOT := Color(1.0, 0.4, 0.95)
const MARK_NAME := "VoidMark"
const MARK_TIME := 6.0  # s
const MARK_R := 0.75  # m round the foe's feet


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


static func disc(r: float) -> CylinderMesh:
	var d := CylinderMesh.new()
	d.top_radius = r
	d.bottom_radius = r
	d.height = 0.02
	d.radial_segments = 28
	return d


static func hoop(thin: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = 1.0 - thin
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 3
	return t


## A flat band round part of a circle, tapering to points: a crescent lying on the floor, facing +Z.
static func arc_mesh(r: float, half_angle: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var steps := 16
	for i in steps + 1:
		var k := float(i) / steps
		var a := lerpf(-half_angle, half_angle, k)
		var w := width * sin(k * PI)
		st.add_vertex(Vector3(sin(a), 0.0, cos(a)) * r)
		st.add_vertex(Vector3(sin(a), 0.0, cos(a)) * (r - w))
	return st.commit()


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


## A hard-edged ring on the floor that runs from one size to another and goes.
static func hoop_run(parent: Node, spot: Vector3, from: float, to: float, time: float, color := VIOLET, thin := 0.08) -> void:
	var mat := flat_mat(color)
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(spot.x, 0.09, spot.z)
	root.scale = Vector3(from, 0.05, from)
	part(root, hoop(thin), mat)
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "scale", Vector3(to, 0.05, to), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time * 0.4).set_delay(time * 0.6)
	tw.chain().tween_callback(root.queue_free)


## An inky pop at a spot.
static func burst(parent: Node, at: Vector3, size := 1.0) -> void:
	Fx.flare(parent, at + Vector3.UP * 0.9, HOT, 1.5 * size, 0.14, "star8")
	Fx.shards(parent, at + Vector3.UP * 0.5, INK, int(10 * size), Vector3.UP, 7.0 * size, 0.16, 0.5)
	Fx.burst(parent, at + Vector3.UP * 0.6, VIOLET, int(10 * size), 7.0, 0.1, 0.3, Vector3.UP, 90.0)


## A crescent of darkness flying out in front of him.
static func reap(parent: Node, at: Vector3, fwd: Vector3, reach: float, half_angle: float) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(at.x, 0.8, at.z)
	root.rotation.y = atan2(fwd.x, fwd.z)
	root.scale = Vector3(0.25, 1.0, 0.25)
	var ink := flat_mat(INK)
	var edge := flat_mat(HOT)
	var rim := flat_mat(VIOLET)
	part(root, arc_mesh(reach, half_angle, reach * 0.34), ink)
	part(root, arc_mesh(reach, half_angle * 0.95, reach * 0.1), rim, Vector3.UP * 0.01)
	part(root, arc_mesh(reach, half_angle * 0.9, reach * 0.035), edge, Vector3.UP * 0.02)
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "scale", Vector3.ONE, 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	for mat: Material in [ink, edge, rim]:
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.1).set_delay(0.13)
	tw.chain().tween_callback(root.queue_free)


## Puts a mark on a foe (or renews it). Black Tide comes for the marked.
static func mark(e: Node3D) -> void:
	var old: Node = e.get_node_or_null(MARK_NAME)
	if old != null:
		old.life = MARK_TIME
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
		var mesh := SELF.arc_mesh(r, PI * 0.28, r * 0.3)
		var mat := SELF.flat_mat(HOT)
		_spin = Node3D.new()
		add_child(_spin)
		for i in 3:
			SELF.part(_spin, mesh, mat).rotation.y = TAU * i / 3.0

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
	var r := 3.0
	var time := 2.0
	var _t := 0.0
	var _ink: ShaderMaterial

	func _ready() -> void:
		_ink = SELF.ink_mat()
		SELF.part(self, SELF.floor_ink(), _ink)
		scale = Vector3(r, 1.0, r)
		_ink.set_shader_parameter("open", 0.05)
		var tw := create_tween()
		tw.tween_method(SELF.set_param.bind(_ink, "open"), 0.05, 1.0, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= time:
			set_process(false)
			var tw := create_tween()
			tw.tween_method(SELF.set_param.bind(_ink, "erode"), 0.0, 1.0, 0.25)
			tw.tween_callback(queue_free)


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
	const CORE_R := 1.3  # m
	const FLYING := "thrown_foe_flying"

	var hero: CharacterBody3D
	var power := 1.0
	var _t := 0.0
	var _next_tick := 0.0
	var _next_stagger := 0.0
	var _next_ring := 0.0
	var _gone := false
	var _spin: Node3D

	func _ready() -> void:
		add_to_group("dark_hole")
		SELF.part(self, SELF.disc(CORE_R), SELF.flat_mat(INK))
		_spin = Node3D.new()
		add_child(_spin)
		var hot := SELF.flat_mat(HOT)
		var rim := SELF.flat_mat(VIOLET)
		for i in 3:
			var a := TAU * i / 3.0
			SELF.part(_spin, SELF.arc_mesh(CORE_R * 1.9, 0.9, 0.34), rim, Vector3.UP * 0.03).rotation.y = a
			SELF.part(_spin, SELF.arc_mesh(CORE_R * 1.35, 0.8, 0.14), hot, Vector3.UP * 0.05).rotation.y = a + 1.0
		var edge := SELF.part(self, SELF.hoop(0.08), hot, Vector3.UP * 0.06)
		edge.scale = Vector3(CORE_R, 0.05, CORE_R)
		scale = Vector3(0.05, 1.0, 0.05)
		create_tween().tween_property(self, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		SELF.burst(get_parent(), global_position, 1.3)
		Game.shake(0.3)

	func _physics_process(delta: float) -> void:
		if _gone:
			return
		_t += delta
		_spin.rotate_y(-7.0 * delta)
		if _t >= _next_ring:
			_next_ring += 0.3
			SELF.hoop_run(get_parent(), global_position, RADIUS, CORE_R, 0.3, VIOLET, 0.05)
		var tick := _t >= _next_tick
		if tick:
			_next_tick += TICK
		var again := _t >= _next_stagger
		if again:
			_next_stagger += STAGGER_EVERY
		for e: Node3D in Ascendancy.enemies_near(get_tree(), global_position, RADIUS):
			if e.has_meta(FLYING):
				continue
			var to := global_position - e.global_position
			to.y = 0.0
			if float(e.get("radius")) >= 0.9 or e.has_method("is_boss") or e.get("elite") == true:
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
				hero._cast_hit(e)
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
		SELF.hoop_run(parent, at, 0.5, RADIUS, 0.28, HOT, 0.1)
		SELF.hoop_run(parent, at, 0.3, RADIUS * 0.7, 0.24, Color.WHITE, 0.06)
		SELF.burst(parent, at, 2.2)
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
	const NEAR_SHORT := 0.55  # how tall the teeth between the camera and the foes are
	const SNAP_HOLD := 0.05  # s
	const HOLD := 0.3  # s shut
	const SINK := 0.14  # s
	const WAIT_MAX := 1.0  # s with no bite, then they go anyway
	const ROWS := [[15, 2.9, 0.48, 1.0], [11, 1.6, 0.3, 0.76]]  # count, height, base, at what fraction of r

	var r := 3.4
	var _t := 0.0
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
		SELF.splat(get_parent(), global_position + Vector3.UP * 1.3, r * 1.25)
		SELF.ink_drops(get_parent(), global_position + Vector3.UP * 0.8, 12, r * 1.5)
		SELF.hoop_run(get_parent(), global_position, r * 0.9, r * 1.45, 0.2, HOT, 0.05)

	func _sink() -> void:
		_sinking = true
		var tw := create_tween()
		tw.tween_method(SELF.set_param.bind(_ink, "erode"), 0.0, 1.0, SINK * 1.6)
		tw.tween_callback(queue_free)


## A burst of ink that plays as a few held frames, not a smooth fade.
static func splat(parent: Node, at: Vector3, size: float) -> void:
	var s := Splat.new()
	parent.add_child(s)
	s.global_position = at
	s.size = size


class Splat extends Node3D:
	const FRAMES := [0.12, 0.3, 0.52, 0.74, 0.92]
	const FRAME_TIME := 0.05  # s

	var size := 3.0
	var _t := 0.0
	var _mat: ShaderMaterial

	func _ready() -> void:
		_mat = ShaderMaterial.new()
		_mat.shader = SPLAT_SHADER
		_mat.set_shader_parameter("seed", randf() * 40.0)
		_mat.set_shader_parameter("progress", FRAMES[0])
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 2.0
		var m := SELF.part(self, quad, _mat)
		m.extra_cull_margin = 8.0
		scale = Vector3.ONE * size

	func _process(delta: float) -> void:
		_t += delta
		var frame := int(_t / FRAME_TIME)
		if frame >= FRAMES.size():
			queue_free()
			return
		_mat.set_shader_parameter("progress", FRAMES[frame])


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
	part(root, floor_ink(), ink_mat())
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = SPLAT_SHADER
	part(root, quad, mat)


## A hit that does its damage and number without sparks or a word per foe: the source draws its own.
static func quiet_hit(e: Node, damage: float, big := false) -> void:
	if e.has_method("burn_hit"):
		e.burn_hit(damage, big)
	else:
		e.take_hit(damage, Vector3.ZERO, 0.0, big)


## A spike of black going straight up from under a foe.
static func spout(parent: Node, spot: Vector3, high := 3.4) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(spot.x, 0.0, spot.z)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.75
	cone.height = high
	cone.radial_segments = 5
	part(root, cone, flat_mat(INK, true), Vector3.UP * high * 0.5)
	var inner := CylinderMesh.new()
	inner.top_radius = 0.0
	inner.bottom_radius = 0.3
	inner.height = high * 0.75
	inner.radial_segments = 5
	part(root, inner, flat_mat(HOT), Vector3(0.0, high * 0.38, 0.0))
	root.scale = Vector3(1.0, 0.05, 1.0)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.14)
	tw.tween_property(root, "scale", Vector3(0.1, 1.0, 0.1), 0.12)
	tw.tween_callback(root.queue_free)
	burst(parent, spot)
