extends Node3D
## The designed twister (fx-air lane, docs/features/designed-fx.md "Air"): Updraft Lash's whirlwind and every
## comic_gale (Fault Line's gales, Hailstorm's miss) when designed effects are on. A volume, not a spring:
##   - a swirl on the floor (air_swirl: pulls in on its first frame, three hooked spiral arms with grit, breaking
##     into curls at the end);
##   - BANDS fat wind ribbons (air_ribbon on helix strips, depth tested so the lifted foes sit inside the column:
##     the near half of a band passes in front of them, the far half behind, one cel band darker), widening
##     upward, each turning on twos with its stroke sliding round head first;
##   - cloud wisps (air_wisp) flung off the top at the peak, drifting out and up;
##   - debris (air_debris: leaves, paper scraps, pebbles, a twig) spiralling up through it, tumbling on twos.
## Timeline: anticipation (ANTIC s, real time: the bands squeezed small and low, the swirl pulling in), the peak
## (overshoots to PEAK_SCALE, settles), the hold, then the dissolve (the ribbons switch to their broken-into-curls
## row and erode tail first). All in the "air" palette row: pale wind, never the lightning's colour.

const SELF := preload("res://scripts/designed_twister.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const STEPS_PER_S := 12.0  # on twos
const ANTIC := 0.12  # s (real time): the pull-in before the peak (round 2: 0.05 never reached a 12 fps film frame)
const BANDS := 3
const HEIGHT_SEEN := 0.82  # of the asked height: from the high camera a 3.5 m column ran off the top of the frame
const SWEEP := [1.25, 1.4, 1.5]  # of PI, each band's arc round the column (the gaps show it's turning)
const BAND_W := [0.52, 0.6, 0.68]  # m up the column (fat ribbons: the drawn stroke inside tapers to points)
const BAND_Y := [0.1, 0.4, 0.68]  # of the height, each band's foot
const BAND_RISE := 0.22  # of the height, how far a band climbs over its arc (a helix, not a stack of rings)
const RADIUS_FOOT := 0.32  # of the radius at the floor; 1.0 + RADIUS_FLARE at the top (it widens upward)
const RADIUS_FLARE := -0.12  # (round 2: a wider top filled half the air string's frame)
const FLARE_OUT := 0.55  # of a band's width: its top edge leans out (a funnel, not a pipe; and the high camera sees more of a leaning band)
const TURN := [0.95, 1.15, 1.35]  # rad a step: the top turns faster
const PEAK_SCALE := 1.1  # the first peak step's overshoot
const ANTIC_SCALE := Vector2(0.5, 0.55)  # radius, height while it pulls in
const DISSOLVE := 0.62  # of the life: the ribbons break into curls and erode from here
const SWIRL_SIZE := 3.2  # of the radius: the floor swirl's square (its arms reach past a pile of four)
const SWIRL_TIMES := [0.05, 0.1, 0.083, 0.083, 0.083, 0.083, 0.1, 0.12]
const WISPS := 3
const WISP_SIZE := 1.0  # m
const WISP_SPEED := Vector2(2.4, 1.3)  # m/s out, up
const WISP_TIMES := [0.04, 0.08, 0.07, 0.07, 0.07, 0.08, 0.08, 0.1]
const DEBRIS := 7
const DEBRIS_SIZE := 0.56  # m (0.46 was specks in the half-size film)
const DEBRIS_SPIN := 6.5  # rad/s round the column
const DRAG := 0.24  # s: the debris drags in along the floor from DRAG_FROM x the radius before it lifts (the anticipation)
const DRAG_FROM := 2.3
const MIN_HEIGHT := 3.0  # m: smaller asks (Fault Line's gales, 2.4 x 0.75) grow to this, so they read as twisters
const MIN_RADIUS := 1.0  # m

var height := 3.5
var radius := 1.3
var life := 0.7
var _t := 0.0
var _last_us := 0
var _step := -1
var _bands: Array = []  # MeshInstance3D
var _boil := 0
var _wisps: Array = []  # [node, velocity]
var _debris: Array = []  # [node, angle, rise time, phase]
var _rng := RandomNumberGenerator.new()


static func spawn(parent: Node, spot: Vector3, h: float, r: float, time: float) -> Node3D:
	var g: Node3D = SELF.new()
	g.height = maxf(h, MIN_HEIGHT) * HEIGHT_SEEN
	g.radius = maxf(r, MIN_RADIUS)
	g.life = maxf(time * 1.2, 0.5)
	parent.add_child(g)
	g.global_position = Vector3(spot.x, 0.0, spot.z)
	g.setup()
	return g


func setup() -> void:
	add_to_group("comic_gale")
	_rng.randomize()
	_boil = _rng.randi() % 3
	_last_us = Time.get_ticks_usec()
	var swirl := DESIGNED.spawn(get_parent(), "air_swirl", global_position + Vector3.UP * DESIGNED.GROUND_LIFT,
			radius * SWIRL_SIZE, "air", _stretch(SWIRL_TIMES), Vector2(0.6, 1.0))
	swirl.real_until = 1
	swirl.rotation.y = _rng.randf() * TAU
	for k in BANDS:
		var mi := MeshInstance3D.new()
		mi.mesh = _helix(k)
		mi.material_override = DESIGNED.material("air_ribbon")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_ghost", true)
		mi.extra_cull_margin = 6.0
		mi.rotation.y = _rng.randf() * TAU
		add_child(mi)
		mi.set_instance_shader_parameter("pal_row", DESIGNED.row("air"))
		mi.set_instance_shader_parameter("span", 1.0)
		mi.set_instance_shader_parameter("tiles", 0.0)
		_bands.append(mi)
	_lift_debris()  # (on the floor round it first: they drag in through the anticipation)
	tick(0.0)


## The timeline's frame times stretched to this twister's life.
func _stretch(times: Array) -> Array:
	var total := 0.0
	for t: float in times:
		total += t
	var out := []
	for i in times.size():
		out.append(times[i] if i == 0 else times[i] * maxf(life - times[0], 0.2) / maxf(total - times[0], 0.01))
	return out


## One band: a helix strip round the column, UV.x along it (the stroke runs tail 0 -> head 1), UV.y up it.
func _helix(k: int) -> ArrayMesh:
	var segs := 28
	var sweep: float = SWEEP[k] * PI
	var w: float = BAND_W[k]
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in segs + 1:
		var u := float(i) / segs
		var a := sweep * u
		var y: float = height * (BAND_Y[k] + BAND_RISE * u)
		var r := _radius_at(y)
		var out := Vector3(cos(a), 0.0, sin(a))
		var p := out * r + Vector3.UP * y
		verts.append(p - Vector3.UP * w * 0.5)
		uvs.append(Vector2(u, 0.0))
		verts.append(p + Vector3.UP * w * 0.5 + out * w * FLARE_OUT)
		uvs.append(Vector2(u, 1.0))
	var idx := PackedInt32Array()
	for i in segs:
		var j := i * 2
		idx.append_array([j, j + 1, j + 2, j + 1, j + 3, j + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _radius_at(y: float) -> float:
	var k := clampf(y / maxf(height, 0.1), 0.0, 1.2)
	return radius * lerpf(RADIUS_FOOT, 1.0 + RADIUS_FLARE, pow(k, 0.85))


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := float(now - _last_us) / 1000000.0
	_last_us = now
	tick(real if _t < ANTIC and not DESIGNED.game_time_only else delta)  # the pull-in runs through the hitstop


## Public so a test can step it.
func tick(delta: float) -> void:
	_t += delta
	if _t >= life:  # (wisps and debris are DesignedFx nodes: they free themselves)
		queue_free()
		return
	_move_riders(delta)
	var step := -1 if _t < ANTIC else int((_t - ANTIC) * STEPS_PER_S)
	if step == _step:
		_erode()
		return
	var steps_moved := maxi(1, step - _step)
	_step = step
	_draw_step(step, steps_moved)
	_erode()


func _draw_step(step: int, moved: int) -> void:
	var sc := Vector2(1.0, 1.0)
	if step < 0:
		sc = ANTIC_SCALE
	elif step == 0:
		sc = Vector2(PEAK_SCALE, PEAK_SCALE)
	elif step == 1:
		sc = Vector2(1.04, 1.04)
	var dissolving := _t >= life * DISSOLVE
	for k in _bands.size():
		var mi: MeshInstance3D = _bands[k]
		mi.scale = Vector3(sc.x, sc.y, sc.x)
		if step >= 0:
			mi.rotation.y -= TURN[k] * moved  # (rotation.y > 0 turns against the stroke: it runs head first)
		# the stroke grows round the band at the start (its head leads), then holds the whole band
		var head := 0.45 if step < 0 else (0.8 if step == 0 else 1.0)
		mi.set_instance_shader_parameter("head", head)
		mi.set_instance_shader_parameter("span", head)
		mi.set_instance_shader_parameter("frame", 3.0 if dissolving else float((_boil + maxi(step, 0) + k) % 3))
	if step == 1:
		_fling_wisps()
	for d: Array in _debris:
		var n: Variant = d[0]
		if is_instance_valid(n):
			n.set_spin(_rng.randf_range(-PI, PI), 1.0 if _rng.randf() < 0.5 else -1.0)


func _erode() -> void:
	var e := clampf((_t / life - DISSOLVE) / (1.0 - DISSOLVE), 0.0, 1.0)
	for mi: MeshInstance3D in _bands:
		mi.set_instance_shader_parameter("erode", e * 0.98)


func _fling_wisps() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var a0 := _rng.randf() * TAU
	for k in WISPS:
		var a := a0 + TAU * k / WISPS + _rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0.0, sin(a))
		var top := height * (0.95 + 0.1 * _rng.randf())
		var at := global_position + out * _radius_at(top) + Vector3.UP * top
		var w := DESIGNED.spawn(get_parent(), "air_wisp", at, WISP_SIZE * _rng.randf_range(0.85, 1.1), "air",
				WISP_TIMES, Vector2(0.5, 1.0))
		var vel := out * WISP_SPEED.x + Vector3.UP * WISP_SPEED.y
		var spin := 0.0
		if cam != null:  # the wisp's tail trails its flight on screen
			spin = atan2(vel.dot(cam.global_basis.y), vel.dot(cam.global_basis.x))
		w.set_spin(spin, 1.0)
		_wisps.append([w, vel])


func _lift_debris() -> void:
	for k in DEBRIS:
		var span := life * _rng.randf_range(0.55, 0.85) + DRAG
		var d := DESIGNED.spawn(get_parent(), "air_debris", global_position, DEBRIS_SIZE * _rng.randf_range(0.75, 1.15),
				"dust", [span], Vector2(0.75, 1.0))
		d.first = (k + _rng.randi()) % 8
		_debris.append([d, TAU * k / DEBRIS + _rng.randf_range(-0.3, 0.3), span, _rng.randf_range(0.0, 0.25)])
	_move_riders(0.0)


## Wisps drift on their flight (slowing); debris spirals up the column, quantised to twos so it moves in held frames.
func _move_riders(delta: float) -> void:
	for w: Array in _wisps:
		var n: Variant = w[0]
		if is_instance_valid(n):
			n.global_position += w[1] * delta
			w[1] = w[1] * maxf(0.0, 1.0 - 2.2 * delta)
	var tq := floorf(_t * STEPS_PER_S) / STEPS_PER_S
	for d: Array in _debris:
		var n: Variant = d[0]
		if not is_instance_valid(n):
			continue
		var y := 0.25
		var a: float = d[1] + DEBRIS_SPIN * tq
		var r := _radius_at(y) * 1.05
		if _t < DRAG:  # dragging in along the floor, on 24 fps steps (the anticipation is short)
			var kin := floorf(_t * 24.0) / 24.0 / DRAG
			r = lerpf(radius * DRAG_FROM, r, kin * kin)
			a = float(d[1]) + kin * 1.4
		else:
			var k := clampf((tq - DRAG) / (float(d[2]) - DRAG) + float(d[3]) * 0.5, 0.0, 1.0)
			y = lerpf(0.25, height * 1.05, k)
			a = float(d[1]) + 1.4 + DEBRIS_SPIN * (tq - DRAG)
			r = _radius_at(y) * 1.05
		n.global_position = global_position + Vector3(cos(a) * r, y, sin(a) * r)
