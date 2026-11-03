extends BoneAttachment3D
## The current element on one of the comic hero's axes: hard two-tone tongues along the blade,
## stepping on twos like the rest of the comic effects, and motes shed behind the swing. Geometry
## and not a shader so the look is the same from any angle (ComicLook.infuse_axes builds these).
## rise   flames that stand up in the world and stream behind a swing (spirit, earth)
## spin   thin gusts whirling round the blade (wind)
## shard  ice crystals fixed to the edge, pointing out of it (water)
## Where the blade's tip scrapes the floor it leaves a comic_drag_mark.

const HERO_LOOK := preload("res://scripts/hero_look.gd")
const MARK := preload("res://scripts/comic_drag_mark.gd")
const ELEMENTS := preload("res://scripts/elements.gd")
const LOOKS := {
	"spirit": {"mode": "rise", "count": 5, "size": 0.36, "wiggle": 0.12, "r": 0.16},
	"earth": {"mode": "rise", "count": 8, "size": 0.42, "wiggle": 0.12, "r": 0.26},
	"wind": {"mode": "spin", "count": 5, "size": 0.72, "wiggle": 0.1, "r": 0.12},
	"water": {"mode": "shard", "count": 7, "size": 0.44, "wiggle": 0.0, "r": 0.18},
}
const STEPS_PER_S := 12.0  # on twos, at the clips' 24 fps
const FRAMES := 4
const RISE := 2.2  # how hard a flame stands up against the swing's speed
const SPIN := 9.0  # rad/s, a gust round the blade
const CHARGED := 1.45  # size while Awakened
const FLICKER := 0.14
const SIDES := 5
const RINGS := 5

var look: Dictionary
var tongues: Array[MeshInstance3D] = []
var drip: CPUParticles3D
var mark: Node3D
var _tip := Vector3.ZERO  # the blade's far point, in the hand's space
var _body: Node3D  # stands on the floor; the mark goes down at its height
var _meshes: Array[ArrayMesh] = []
var _axis := Vector3.UP  # grip to blade, in the hand's space
var _centre := Vector3.ZERO
var _t := 0.0
var _step := -1
var _size := 1.0
var _last_pos := Vector3.ZERO
var _primed := false
var _vel := Vector3.ZERO


## `edge`: points along the blade's edge in the hand bone's space. `centre`: the middle of the blade.
func setup(element: String, meshes: Array[ArrayMesh], edge: PackedVector3Array, centre: Vector3, model: Node3D) -> void:
	look = LOOKS[element]
	_body = model.get_parent() as Node3D
	_tip = _farthest_from_handle(edge, centre)
	mark = MARK.new()
	mark.setup(element)
	add_child(mark)
	_meshes = meshes
	_centre = centre
	_axis = centre.normalized()
	for i: int in look.count:
		var at := edge[int(float(i) / maxf(look.count - 1, 1) * (edge.size() - 1))]
		var t := MeshInstance3D.new()
		t.mesh = meshes[i % meshes.size()]
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.set_meta("no_ghost", true)
		t.position = at
		if look.mode == "shard":
			var out := (at - centre).normalized()
			t.basis = Basis(Quaternion(Vector3.UP, out)).scaled(Vector3.ONE * look.size)
		add_child(t)
		tongues.append(t)
	drip = HERO_LOOK._drip(element, ELEMENTS.LOOK[element].color)
	drip.position = centre
	add_child(drip)


## The grip is at the bone, so the handle runs through the origin towards the blade's centre.
static func _farthest_from_handle(edge: PackedVector3Array, centre: Vector3) -> Vector3:
	# out from the blade through the middle of the edge: on a crescent the horns are farther off the handle,
	# but the middle of the edge is what the drag poses stand on the floor
	var mid := Vector3.ZERO
	for v in edge:
		mid += v
	var out := (mid / edge.size() - centre).normalized()
	var best := centre
	var far := -INF
	for v in edge:
		if v.dot(out) > far:
			far = v.dot(out)
			best = v
	return best


func tip_position() -> Vector3:
	return global_transform * _tip


## Awakened: bigger and shedding more.
func charge(on: bool) -> void:
	_size = CHARGED if on else 1.0
	drip.amount = HERO_LOOK.DRIP_AMOUNT * (3 if on else 1)
	drip.speed_scale = 1.6 if on else 1.0
	if look.mode == "shard":
		for t in tongues:
			t.basis = t.basis.orthonormalized().scaled(Vector3.ONE * look.size * _size)


func _process(delta: float) -> void:
	_t += delta
	if _body != null:
		mark.track(tip_position(), _body.global_position.y)
	mark.tick(delta)
	var step := int(_t * STEPS_PER_S)
	var stepped := step != _step
	_step = step
	if look.mode == "shard":
		return
	var pos := global_transform * _centre
	if _primed and delta > 0.0:
		_vel = _vel.lerp((pos - _last_pos) / delta, 0.35)
	_primed = true
	_last_pos = pos
	var axis := (global_basis * _axis).normalized()
	var across := axis.cross(Vector3.UP)
	if across.length() < 0.1:
		across = axis.cross(Vector3.RIGHT)
	across = across.normalized()
	for i in tongues.size():
		var t := tongues[i]
		if stepped:
			t.mesh = _meshes[(step + i) % _meshes.size()]
		var dir := Vector3.UP * RISE - _vel
		if look.mode == "spin":
			dir = across.rotated(axis, _t * SPIN + TAU * i / tongues.size()) + axis * 0.35
		var flicker := 1.0 + FLICKER * sin(step * 2.4 + i * 1.7)
		var b := Basis(Quaternion(Vector3.UP, dir.normalized()))
		t.global_transform = Transform3D(b.scaled(Vector3.ONE * look.size * _size * flicker), t.global_position)


## One element's tongue, in FRAMES poses: outer colour drawn on its back faces with a smaller hot
## core inside, so the core shows through from any side without turning depth off.
static func build_meshes(element: String) -> Array[ArrayMesh]:
	var l: Dictionary = LOOKS[element]
	var outer := _unlit(ELEMENTS.LOOK[element].color, BaseMaterial3D.CULL_FRONT)
	var core := _unlit(ELEMENTS.LOOK[element].glow, BaseMaterial3D.CULL_BACK)
	var made: Array[ArrayMesh] = []
	for f in (FRAMES if l.wiggle > 0.0 else 1):
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _tongue(l.r, l.wiggle, f, 1.0))
		mesh.surface_set_material(0, outer)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _tongue(l.r * 0.5, l.wiggle, f, 0.68))
		mesh.surface_set_material(1, core)
		made.append(mesh)
	return made


static func _unlit(c: Color, cull: BaseMaterial3D.CullMode) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = cull
	return m


## A teardrop up +Y, 1 long, bending side to side by `wiggle`.
static func _tongue(radius: float, wiggle: float, frame: int, length: float) -> Array:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	var phase := frame * TAU / FRAMES
	for ring in RINGS:
		var k := float(ring) / (RINGS - 1)
		var r := radius * sqrt(minf(k * 4.0, 1.0)) * (1.0 - k) * 1.35
		var bend := Vector3(sin(k * 4.0 + phase), 0, cos(k * 3.0 + phase * 2.0)) * wiggle * k
		var c := bend + Vector3.UP * k * length
		for s in SIDES:
			var a := TAU * s / SIDES
			v.append(c + Vector3(cos(a), 0, sin(a)) * r)
	for ring in RINGS - 1:
		for s in SIDES:
			var p := ring * SIDES + s
			var q := ring * SIDES + (s + 1) % SIDES
			idx.append_array([p, q, p + SIDES, q, q + SIDES, p + SIDES])  # clockwise from outside: Godot's front
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays
