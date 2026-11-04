extends Node3D
## The tentacle when it leaves him. A reach this long can't be baked into a clip, so while it's out this
## draws a tube from his hand to whatever it's after, rebuilt each frame in world space.
## `reach` runs it out (0..1), `wave` whips it, `coil` wraps its end round what it holds (radius, 0 = none).

const SIDES := 6
const STEPS := 20
const COIL_STEPS := 14
const COIL_TURNS := 2.0
const ROOT_R := 0.085  # m, matching the arm's end
const TIP_R := 0.05
const WAVE_COUNT := 9.0  # radians of wave along it
const WAVE_SPEED := 30.0
const MIN_REACH := 0.02

var _mi: MeshInstance3D
var _mesh: ArrayMesh
var _mat: Material


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mesh = ArrayMesh.new()
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	_mi.set_meta("no_ghost", true)
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # (reaching off screen, it threw a long black line)
	add_child(_mi)
	if DisplayServer.get_name() != "headless":
		_mat = ComicLook.material("P_Tendril", ComicLook.hero_kind()).duplicate()
		_mat.next_pass = Fx.ink_material()
	visible = false


func draw(from: Vector3, to: Vector3, reach: float, wave: float, coil: float, time: float) -> void:
	if reach < MIN_REACH:
		visible = false
		return
	visible = true
	var pts := spine(from, to, reach, wave, coil, time)
	_build(pts)


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
		pts.append(from + along * f + side * sin(f * WAVE_COUNT - time * WAVE_SPEED) * wave * swell)
	if coil > 0.0 and reach >= 1.0:
		for j in range(1, COIL_STEPS + 1):
			var k := float(j) / COIL_STEPS
			var a := k * COIL_TURNS * TAU
			pts.append(tip + Vector3(cos(a) * coil, (k - 0.5) * 0.6, sin(a) * coil))
	return pts


func _build(pts: PackedVector3Array) -> void:
	var n := pts.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var frame := Vector3.UP
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		frame = frame - t * frame.dot(t)  # carried along, so the tube doesn't twist
		frame = frame.normalized() if frame.length() > 0.01 else t.cross(Vector3.RIGHT).normalized()
		var other := t.cross(frame)
		var f := float(i) / (n - 1)
		var r := lerpf(ROOT_R, TIP_R, f) * (1.0 if i < n - 2 else 0.3)
		for s in SIDES:
			var a := float(s) / SIDES * TAU
			var o := frame * cos(a) + other * sin(a)
			verts.append(pts[i] + o * r)
			norms.append(o)
		if i < n - 1:
			for s in SIDES:
				var s2 := (s + 1) % SIDES
				var a0 := i * SIDES + s
				var a1 := i * SIDES + s2
				var b0 := a0 + SIDES
				var b1 := a1 + SIDES
				idx.append_array([a0, b0, a1, a1, b0, b1])  # (clockwise from outside: Godot culls the other way)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _mat:
		_mesh.surface_set_material(0, _mat)
