extends Node3D
## The tentacle when it leaves him. A reach this long can't be baked into a clip, so while it's out this
## draws a flat inked ribbon from his hand to whatever it's after, rebuilt each frame in world space.
## `reach` runs it out (0..1), `wave` whips it, `coil` wraps its end round what it holds (radius, 0 = none).

const DARK := preload("res://scripts/dark_fx.gd")
const STEPS := 20
const COIL_STEPS := 14
const COIL_TURNS := 2.0
# A flat ribbon facing the camera, in dark_fx.Splat's three layers: ink edge, violet body, hot core line.
# (A 0.17 m shaded tube read as a thin pink thread at the game camera.)
const ROOT_W := 0.26  # m, the ink's half-width at his hand (0.15 still read as a thread)
const TIP_W := 0.13
const LAYERS := [[1.0, 0.0], [0.6, 0.015], [0.2, 0.03]]  # width of the ink, m towards the camera
const SEGMENTS := 4  # each narrows to its joint, as the splat's tentacles
const SAG := 0.05  # of its length, at the middle
const WAVE_COUNT := 9.0  # radians of wave along it
const WAVE_SPEED := 30.0
const STEP_S := 1.0 / 12.0  # the whip moves on twos; the ends follow every frame
const MIN_REACH := 0.02

static var _flat: StandardMaterial3D

var _mi: MeshInstance3D
var _mesh: ArrayMesh
var _mat: Material


## Unshaded vertex colour, depth tested (so a coil goes behind what it holds), both sides.
static func material() -> StandardMaterial3D:
	if _flat == null:
		_flat = StandardMaterial3D.new()
		_flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_flat.vertex_color_use_as_albedo = true
		_flat.vertex_color_is_srgb = true
		_flat.disable_fog = true
	return _flat


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
	if DisplayServer.get_name() != "headless":
		_mat = material()
	visible = false


func draw(from: Vector3, to: Vector3, reach: float, wave: float, coil: float, time: float) -> void:
	if reach < MIN_REACH:
		visible = false
		return
	visible = true
	var pts := spine(from, to, reach, wave, coil, floorf(time / STEP_S) * STEP_S)
	_build(pts, STEPS + 1)


## The tube's centre line. Static so a check can read it without drawing.
static func spine(from: Vector3, to: Vector3, reach: float, wave: float, coil: float, time: float) -> PackedVector3Array:
	var tip := from.lerp(to, reach)
	var along := tip - from
	var side := along.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var pts := PackedVector3Array()
	for i in STEPS + 1:
		var f := float(i) / STEPS
		var swell := sin(f * PI)
		pts.append(from + along * f + side * sin(f * WAVE_COUNT - time * WAVE_SPEED) * wave * swell
			+ Vector3.DOWN * along.length() * SAG * swell)
	if coil > 0.0 and reach >= 1.0:
		for j in range(1, COIL_STEPS + 1):
			var k := float(j) / COIL_STEPS
			var a := k * COIL_TURNS * TAU
			pts.append(tip + Vector3(cos(a) * coil, (k - 0.5) * 0.6, sin(a) * coil))
	return pts


## `straight` points are the reach (tapering, in segments); any after are the coil, at the tip's width.
func _build(pts: PackedVector3Array, straight: int) -> void:
	var n := pts.size()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := cam.global_position if cam != null else pts[0] + Vector3(0.0, 20.0, 10.0)
	var sides := PackedVector3Array()
	var halves := PackedFloat32Array()
	var views := PackedVector3Array()
	for i in n:
		var t := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var view := (eye - pts[i]).normalized()
		var side := t.cross(view)
		side = side.normalized() if side.length() > 0.0001 else Vector3.RIGHT
		var f := clampf(float(i) / (straight - 1), 0.0, 1.0)
		var w := lerpf(ROOT_W, TIP_W, f)
		if i < straight:
			w *= 1.0 - 0.3 * fmod(f * SEGMENTS, 1.0)
		if i == n - 1:
			w *= 0.35  # a point
		sides.append(side)
		halves.append(w)
		views.append(view)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var cols := [DARK.INK, DARK.VIOLET, DARK.HOT]
	for k in LAYERS.size():
		var lw: float = LAYERS[k][0]
		var lift: float = LAYERS[k][1]
		var c: Color = cols[k]
		for i in n - 1:
			var a := pts[i] + views[i] * lift
			var b := pts[i + 1] + views[i + 1] * lift
			var al := a + sides[i] * halves[i] * lw
			var ar := a - sides[i] * halves[i] * lw
			var bl := b + sides[i + 1] * halves[i + 1] * lw
			var br := b - sides[i + 1] * halves[i + 1] * lw
			verts.append_array([al, ar, bl, bl, ar, br])
			colors.append_array([c, c, c, c, c, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _mat:
		_mesh.surface_set_material(0, _mat)
