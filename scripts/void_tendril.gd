extends Node3D
## The tentacle when it leaves him. A reach this long can't be baked into a clip, so while it's out this
## draws an inked ribbon from his hand to whatever it's after, rebuilt each frame in world space.
## `reach` runs it out (0..1), `wave` whips it, `coil` wraps its end round what it holds (radius, 0 = none).
##
## Round 44 (fx-cohesion, docs/features/designed-fx.md "The tentacle"): a smooth spine (Catmull-Rom through the
## wave and the coil, no corners: the coil starts where the reach meets its circle on a tangent), a fat base
## tapering to a pointed claw tip, a living swell along it on twos, and an authored skin
## (shaders/tentacle.gdshader + assets/vfx/designed/tentacle_skin.png: back shadow, wrinkle ticks, light belly
## with suckers, highlight dash, a fixed-width ink line, a light claw tip). A fast lash leaves a drawn smear
## between its last pose and this one (tentacle_smear).
##
## For other lanes: `points()` is the tentacle's last drawn world polyline (root to tip), `tip()` its end, and
## `electrify(amount, color)` washes the body (not the ink) in a colour.

const DESIGNED := preload("res://scripts/designed_fx.gd")
const SKIN_SHADER := preload("res://shaders/tentacle.gdshader")
const SMEAR_SHADER := preload("res://shaders/tentacle_smear.gdshader")
const SKIN_TEX := preload("res://assets/vfx/designed/tentacle_skin.png")
const SMEAR_TEX := preload("res://assets/vfx/designed/tentacle_smear.png")
const STEPS := 20
const COIL_STEPS := 14  # control points a turn (smoothed after)
const COIL_TURNS := 2.0
const SMOOTH := 3  # Catmull-Rom samples per control segment
# Widths (half, metres). Round 44: a fat base, tapering to the claw.
const ROOT_W := 0.3  # at his hand
const BASE_BULB := 0.12  # of the length: the base swells out of the hand before it tapers
const TIP_W := 0.11  # where the reach ends (the coil starts here)
const POINT_W := 0.015  # the claw's point
const SWELL := 0.12  # the living swell along it (share of the width), on twos
const SWELL_WAVE := 5.5  # radians a metre
const SWELL_SPEED := 9.0
const SKIN_ASPECT := 4.0  # the skin tile is 4:1 (length:width)
const WRAP_TURNS := 1.35  # the designed coil (two full turns stacked into a striped cake under a lifted foe)
const COIL_OUT := 0.1  # m the coil sits off the foe's radius (its front shows over the body)
const COIL_W := 0.15  # half width where the coil starts
const CLAW_HOOK := 0.32  # m: the claw flicks out past the coil's end
const SAG := 0.05  # of its length, at the middle
const WAVE_COUNT := 9.0  # radians of wave along it
const WAVE_SPEED := 30.0
const STEP_S := 1.0 / 12.0  # the whip moves on twos; the ends follow every frame
const MIN_REACH := 0.02
## Round 33, sleek 5: `line` draws one thin inked violet line (no skin, one coil turn) for the holds that only
## pin something in place: Deep Freeze's cords to each cube were 0.5 m three-layer ribbons in a crowd of cubes.
const LINE_ROOT_W := 0.075  # m, the ink's half-width at his hand
const LINE_TIP_W := 0.05
const LINE_COIL_TURNS := 1.0
## The smear: drawn when the tip moves faster than this (m a frame at 60 Hz, ~15 m/s), for SMEAR_HOLD s.
const SMEAR_MIN := 0.25
const SMEAR_MAX := 2.2  # m a frame: past this it is a new pose, not a lash
const SMEAR_HOLD := 0.07
const SMEAR_SAMPLES := 16

static var _skin: ShaderMaterial
static var _headless_known := false
static var _headless := false  # the dummy renderer: no skin or smear material, the spine still computed for the checks
static var _smear_mat: ShaderMaterial

var _mi: MeshInstance3D
var _mesh: ArrayMesh
var _mat: Material
var _smear_mi: MeshInstance3D
var _smear_mesh: ArrayMesh
var _pts := PackedVector3Array()  # the last drawn spine, root to tip
var _prev := PackedVector3Array()  # resampled, for the smear
var _prev_tip := Vector3.INF
var _smear_t := 0.0
var _smear_from := PackedVector3Array()
var _last_ms := 0
var _tint := Color(0, 0, 0, 0)
var line := false  # one thin line (LINE_*); the pool owner sets it per hold


static func headless() -> bool:
	if not _headless_known:
		_headless_known = true
		_headless = DisplayServer.get_name() == "headless"
	return _headless


## The designed skin (shared by every tentacle; per-tentacle values are instance uniforms).
static func skin_material() -> ShaderMaterial:
	if _skin == null:
		_skin = ShaderMaterial.new()
		_skin.shader = SKIN_SHADER
		_skin.set_shader_parameter("sheet", SKIN_TEX)
		_skin.set_shader_parameter("palette", DESIGNED.palette())
		_skin.set_shader_parameter("palette_rows", float(DESIGNED.ROWS.size()))
		_skin.set_shader_parameter("rows", 3.0)
	return _skin


static func smear_material() -> ShaderMaterial:
	if _smear_mat == null:
		_smear_mat = ShaderMaterial.new()
		_smear_mat.shader = SMEAR_SHADER
		_smear_mat.set_shader_parameter("sheet", SMEAR_TEX)
		_smear_mat.set_shader_parameter("palette", DESIGNED.palette())
		_smear_mat.set_shader_parameter("palette_rows", float(DESIGNED.ROWS.size()))
		_smear_mat.set_shader_parameter("rows", 2.0)
		_smear_mat.render_priority = -1
	return _smear_mat


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	add_to_group("void_tendrils")  # (element_shots films the first frame one is out)
	_mesh = ArrayMesh.new()
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	_mi.set_meta("no_ghost", true)
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # (reaching off screen, it threw a long black line)
	add_child(_mi)
	if not headless():
		_mat = skin_material()
		_smear_mesh = ArrayMesh.new()
		_smear_mi = MeshInstance3D.new()
		_smear_mi.mesh = _smear_mesh
		_smear_mi.set_meta("no_ghost", true)
		_smear_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_smear_mi.visible = false
		add_child(_smear_mi)
		_mi.set_instance_shader_parameter("pal_row", DESIGNED.row("void"))
		_smear_mi.set_instance_shader_parameter("pal_row", DESIGNED.row("void"))
	visible = false


## The tentacle's last drawn centre line, root (his hand) to tip, in world space. Empty while it is in.
func points() -> PackedVector3Array:
	return _pts if visible else PackedVector3Array()


## Where its end is (the claw), or INF while it is in.
func tip() -> Vector3:
	return _pts[_pts.size() - 1] if visible and not _pts.is_empty() else Vector3.INF


## Wash the body (not the ink) in a colour: amount 0..1 (0 = off). For an electrified or charged tentacle.
func electrify(amount: float, color := Color(0.82, 1.0, 0.76)) -> void:
	_tint = Color(color.r, color.g, color.b, clampf(amount, 0.0, 1.0))
	if _mat is ShaderMaterial:
		_mi.set_instance_shader_parameter("tint", _tint)


func draw(from: Vector3, to: Vector3, reach: float, wave: float, coil: float, time: float) -> void:
	if reach < MIN_REACH:
		visible = false
		_prev_tip = Vector3.INF
		_pts = PackedVector3Array()
		if _smear_mi:
			_smear_mi.visible = false
		return
	visible = true
	var tq := floorf(time / STEP_S) * STEP_S
	var res := spine_designed(from, to, reach, wave, coil, tq, LINE_COIL_TURNS if line else WRAP_TURNS, 1 if line else SMOOTH)
	_pts = res.pts
	_build_skin(res.pts, res.widths, tq)
	_update_smear(tq)


## The designed spine: {pts, widths} (half widths, metres), smoothed. The reach runs to the point where its line
## touches the coil's circle on a tangent, so the coil carries on from it without a corner; the coil spirals down
## and in, then the claw flicks out past its end.
static func spine_designed(from: Vector3, to: Vector3, reach: float, wave: float, coil: float, time: float,
		turns := COIL_TURNS, smooth := SMOOTH) -> Dictionary:
	var coiling := coil > 0.0
	var aim := to
	var a0 := 0.0
	var spin := 1.0
	if coiling:
		var rc := coil + COIL_OUT
		var c := Vector2(to.x, to.z)
		var h := Vector2(from.x, from.z)
		var d := (h - c).length()
		var ah := atan2(h.y - c.y, h.x - c.x)
		a0 = ah + (acos(clampf(rc / d, -1.0, 1.0)) if d > rc * 1.02 else 0.0)
		var tp := c + Vector2(cos(a0), sin(a0)) * rc
		aim = Vector3(tp.x, to.y + 0.12, tp.y)
		var dir := tp - h
		spin = 1.0 if dir.dot(Vector2(-sin(a0), cos(a0))) >= 0.0 else -1.0
	var tip_at := from.lerp(aim, reach)
	var along := tip_at - from
	var side := along.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var ctrl := PackedVector3Array()
	var cw := PackedFloat32Array()  # 0..1 along the reach, then 1+ along the coil
	for i in STEPS + 1:
		var f := float(i) / STEPS
		var swell := sin(f * PI)
		ctrl.append(from + along * f + side * sin(f * WAVE_COUNT - time * WAVE_SPEED) * wave * swell
			+ Vector3.DOWN * along.length() * SAG * swell)
		cw.append(f)
	var wrap := coiling and reach >= 1.0
	if wrap:
		var n := int(ceil(COIL_STEPS * turns))
		var last := Vector3.ZERO
		for j in range(1, n + 1):
			var k := float(j) / n
			var a := a0 + spin * k * turns * TAU
			var r := (coil + COIL_OUT) * (1.0 - 0.15 * k)
			last = to + Vector3(cos(a) * r, lerpf(0.12, -0.14, k), sin(a) * r)
			ctrl.append(last)
			cw.append(1.0 + k)
		# the claw: out past the end, on the coil's tangent and a little outward
		var a_end := a0 + spin * turns * TAU
		var tang := Vector3(-sin(a_end), 0.0, cos(a_end)) * spin
		var outw := Vector3(cos(a_end), 0.0, sin(a_end))
		ctrl.append(last + (tang * 0.7 + outw * 0.7).normalized() * CLAW_HOOK * 0.55 + Vector3.UP * 0.05)
		cw.append(2.0)
		ctrl.append(last + (tang * 0.35 + outw).normalized() * CLAW_HOOK + Vector3.UP * 0.12)
		cw.append(2.1)
	var pts := _catmull(ctrl, smooth)
	var ws := _catmull_f(cw, smooth)
	var widths := PackedFloat32Array()
	var arc := 0.0
	for i in pts.size():
		if i > 0:
			arc += pts[i].distance_to(pts[i - 1])
		var q := ws[i]
		var w: float
		if q <= 1.0:
			var bulb := 1.0 + 0.25 * (1.0 - smoothstep(0.0, BASE_BULB, q)) * smoothstep(0.0, 0.03, q)
			w = lerpf(COIL_W if wrap else TIP_W, ROOT_W, pow(1.0 - q, 1.35)) * bulb
			if not wrap:
				w = lerpf(w, POINT_W, smoothstep(0.82, 1.0, q))  # a free lash ends in a point
		else:
			w = lerpf(COIL_W, POINT_W, smoothstep(1.0, 2.1, q) ** 1.4)
		w *= 1.0 + SWELL * sin(arc * SWELL_WAVE - time * SWELL_SPEED) * smoothstep(0.0, 0.5, arc)
		widths.append(w)
	return {"pts": pts, "widths": widths}


static func _catmull(p: PackedVector3Array, n: int) -> PackedVector3Array:
	if n <= 1 or p.size() < 3:
		return p
	var out := PackedVector3Array()
	var m := p.size()
	for i in m - 1:
		var p0 := p[maxi(i - 1, 0)] if i > 0 else p[0] * 2.0 - p[1]
		var p1 := p[i]
		var p2 := p[i + 1]
		var p3 := p[i + 2] if i + 2 < m else p[m - 1] * 2.0 - p[m - 2]
		for k in n:
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(p[m - 1])
	return out


static func _catmull_f(p: PackedFloat32Array, n: int) -> PackedFloat32Array:
	if n <= 1 or p.size() < 3:
		return p
	var out := PackedFloat32Array()
	for i in p.size() - 1:
		for k in n:
			out.append(lerpf(p[i], p[i + 1], float(k) / n))
	out.append(p[p.size() - 1])
	return out


func _eye(fallback: Vector3) -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam != null else fallback + Vector3(0.0, 20.0, 10.0)


## The designed ribbon: two vertices a spine point, facing the camera; UV for the skin, UV2 (half width, metres
## to the end) for the ink and the claw.
func _build_skin(pts: PackedVector3Array, widths: PackedFloat32Array, time: float) -> void:
	var n := pts.size()
	var eye := _eye(pts[0])
	var total := 0.0
	for i in range(1, n):
		total += pts[i].distance_to(pts[i - 1])
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	var u := 0.0
	var arc := 0.0
	for i in n:
		if i > 0:
			var ds := pts[i].distance_to(pts[i - 1])
			arc += ds
			u += ds / (maxf(2.0 * widths[i], 0.12) * SKIN_ASPECT)
		var t := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var view := (eye - pts[i]).normalized()
		var s := t.cross(view)
		s = s.normalized() if s.length() > 0.0001 else Vector3.RIGHT
		var w := widths[i] if not line else lerpf(LINE_ROOT_W, LINE_TIP_W, float(i) / maxf(1.0, n - 1)) * (0.35 if i == n - 1 else 1.0)
		var lift := view * 0.02
		verts.append(pts[i] + s * w + lift)
		verts.append(pts[i] - s * w + lift)
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
		var to_end := total - arc
		uv2s.append(Vector2(w, to_end if not line else 99.0))
		uv2s.append(Vector2(w, to_end if not line else 99.0))
		if i > 0:
			var a := (i - 1) * 2
			idx.append_array([a, a + 1, a + 2, a + 2, a + 1, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _mat:
		_mesh.surface_set_material(0, _mat)
		_mi.set_instance_shader_parameter("frame", float(int(time / STEP_S) % 3))
		_mi.set_instance_shader_parameter("thin", 1.0 if line else 0.0)


## Resample the spine to SMEAR_SAMPLES points evenly along it.
static func _resample(pts: PackedVector3Array, k: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total := cum[cum.size() - 1]
	var j := 0
	for s in k:
		var d := total * float(s) / (k - 1)
		while j < pts.size() - 2 and cum[j + 1] < d:
			j += 1
		var seg := maxf(cum[j + 1] - cum[j], 0.0001)
		out.append(pts[j].lerp(pts[j + 1], clampf((d - cum[j]) / seg, 0.0, 1.0)))
	return out


## A lash, not a jump to a new pose: the tip moved fast but not across the room, the root stayed put, the
## middle went the same way as the tip, and the length held.
static func _lashing(was: PackedVector3Array, now: PackedVector3Array) -> bool:
	var k := now.size() - 1
	var tip_d := now[k] - was[k]
	var mid_d := now[k >> 1] - was[k >> 1]
	var len_was := was[0].distance_to(was[k])
	var len_now := now[0].distance_to(now[k])
	return tip_d.length() > SMEAR_MIN and tip_d.length() < SMEAR_MAX and now[0].distance_to(was[0]) < 0.3 and mid_d.dot(tip_d) > 0.0 and absf(len_now - len_was) < 0.3 * maxf(len_was, 0.5)


## A fast lash leaves a drawn smear between where it was and where it is, held a moment.
func _update_smear(time: float) -> void:
	if _smear_mi == null or line or _pts.size() < 2:
		return
	var now := Time.get_ticks_msec()
	var dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.1) if _last_ms > 0 else 0.0
	_last_ms = now
	var cur := _resample(_pts, SMEAR_SAMPLES)
	var tip_now := cur[cur.size() - 1]
	if _prev_tip != Vector3.INF and _prev.size() == SMEAR_SAMPLES and _lashing(_prev, cur):
		_smear_from = _prev
		_smear_t = SMEAR_HOLD
	_prev = cur
	_prev_tip = tip_now
	_smear_t -= dt
	if _smear_t <= 0.0 or _smear_from.size() != SMEAR_SAMPLES:
		_smear_mi.visible = false
		return
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var eye := _eye(cur[0])
	for i in SMEAR_SAMPLES:
		var f := float(i) / (SMEAR_SAMPLES - 1)
		var back := _smear_from[i]
		var front := cur[i]
		var lift := (eye - front).normalized() * 0.01
		verts.append(back + lift)
		verts.append(front + lift)
		uvs.append(Vector2(f, 0.0))
		uvs.append(Vector2(f, 1.0))
		if i > 0:
			var a := (i - 1) * 2
			idx.append_array([a, a + 1, a + 2, a + 2, a + 1, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	_smear_mesh.clear_surfaces()
	_smear_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_smear_mesh.surface_set_material(0, smear_material())
	_smear_mi.visible = true
	_smear_mi.set_instance_shader_parameter("alpha", clampf(_smear_t / SMEAR_HOLD, 0.0, 1.0))
	_smear_mi.set_instance_shader_parameter("frame", float(int(time / STEP_S) % 2))
