extends Node3D
## Spirit echo: the bound ancestor in the axe finishes the swing. A giant
## spectral copy of the hero's axe sweeps the same arc a beat after the real
## hit, laid flat so its silhouette reads from the top-down camera, hitting
## each enemy in its arc once and leaving a swoosh. Spawned by player._cast
## for casts of kind "echo" (elements.CASTS).

const HERO_LOOK := preload("res://scripts/hero_look.gd")
# Ascendancy forms of a spirit axe (ghost(el)): [radius, length, sides, axe-local
# base, z rotation (deg; 90 = out of the blade edge toward -X)].
const FORMS := {
	"earth": [[0.09, 0.45, 5, Vector3(-0.5, 0.38, 0), 62.0], [0.1, 0.62, 5, Vector3(-0.58, 0.62, 0), 90.0],
		[0.09, 0.45, 5, Vector3(-0.52, 0.84, 0), 118.0], [0.08, 0.38, 5, Vector3(0, -0.25, 0), 180.0],
		[0.08, 0.32, 5, Vector3(0.08, 0.7, 0), -80.0]],
	"water": [[0.07, 0.5, 4, Vector3(-0.5, 0.38, 0), 50.0], [0.08, 0.72, 4, Vector3(-0.58, 0.62, 0), 80.0],
		[0.07, 0.5, 4, Vector3(-0.52, 0.84, 0), 110.0], [0.08, 0.55, 4, Vector3(0, 0.93, 0), 0.0]],
	"wind": [[0.11, 0.85, 3, Vector3(0.06, 0.82, 0), -55.0], [0.1, 0.7, 3, Vector3(0.06, 0.62, 0), -95.0],
		[0.08, 0.5, 3, Vector3(0.04, 0.44, 0), -125.0]],
}
const FADE_IN := 0.04
const FADE_OUT := 0.14
const HEIGHT := 1.0  # sweep height above the floor

static var _form_meshes := {}

var axe_mesh: Mesh
var color := Color(0.3, 0.95, 0.85)
var fwd := Vector3.FORWARD
var flip := false  # sweep right-to-left (follows the swing's swoosh)
var arc_deg := 150.0
var radius := 3.2
var damage := 5.0
var delay := 0.05
var time := 0.18
var on_hit := Callable()
var el := "spirit"  # element of the hit debris (Fx.element_hit)

var _pivot: Node3D
var _mat: StandardMaterial3D
var _hit: Array = []
var _scale := 1.0


func _ready() -> void:
	rotation.y = atan2(fwd.x, fwd.z)
	_pivot = Node3D.new()
	_pivot.position.y = HEIGHT
	add_child(_pivot)
	var axe := ghost(axe_mesh, color, el)
	_mat = axe.material_override
	var rim: ShaderMaterial = axe.material_overlay
	# Axe-local: handle +Y, blade toward -X, thin in Z. Lay it flat: handle points
	# out from the hero (+Z), blade leads the sweep, flat side faces the camera.
	var side := -1.0 if flip else 1.0
	var basis := Basis(Vector3(-side, 0, 0), Vector3(0, 0, 1), Vector3(0, side, 0))
	_scale = maxf(radius - 0.4, 0.5) / 0.95  # blade tip lands on the arc's edge
	axe.transform = Transform3D(basis.scaled(Vector3.ONE * _scale), Vector3(0, 0, 0.4))
	_pivot.add_child(axe)
	pose(0.0)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_start)
	tw.tween_method(pose, 0.0, 1.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_mat, "albedo_color:a", 0.0, FADE_OUT)
	tw.parallel().tween_property(rim, "shader_parameter/intensity", 0.0, FADE_OUT)
	tw.tween_callback(queue_free)


## A spectral copy of `mesh`: translucent unshaded body (starts invisible:
## tween material_override's albedo alpha) with a bright rim overlay. With an
## Ascendancy element (`el` wind / earth / water) the axe takes that form:
## extra blades sharing the body's materials (so they fade with it) and a body
## tint: earth = dark molten with spikes off the edge and butt, water = pale
## ice with icicles and a point, wind = swept wing blades off the back.
static func ghost(mesh: Mesh, c: Color, el := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := Color.from_hsv(c.h, 0.85, 0.85)
	match el:
		"earth":
			body = Color.from_hsv(c.h, 0.95, 0.6)
		"water":
			body = Color.from_hsv(c.h, 0.35, 1.0)
	mat.albedo_color = Color(body, 0.0)
	mi.material_override = mat
	var rim: ShaderMaterial = Fx.rim_material().duplicate()
	rim.set_shader_parameter("glow_color", c.lerp(Color.WHITE, 0.5))
	rim.set_shader_parameter("intensity", 2.0)
	mi.material_overlay = rim
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for o: Array in FORMS.get(el, []):
		var part := MeshInstance3D.new()
		part.mesh = _form_mesh(o[0], o[1], o[2])
		part.material_override = mat
		part.material_overlay = rim
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.position = o[3]
		part.rotation_degrees = Vector3(0, 0, o[4])
		part.scale = Vector3(1, 1, 0.5)  # flat like the blade
		mi.add_child(part)
	return mi


## Faceted spike `radius` x `length` with `sides`, base at the origin pointing +Y (cached).
static func _form_mesh(radius: float, length: float, sides: int) -> Mesh:
	var key := Vector3(radius, length, sides)
	if not _form_meshes.has(key):
		_form_meshes[key] = HERO_LOOK._flat_mesh(HERO_LOOK._prism(radius, length, sides))
	return _form_meshes[key]


## Sweep position `t` (0 start .. 1 end of the arc); also hits enemies it passes.
func pose(t: float) -> void:
	var half := deg_to_rad(arc_deg) * 0.5
	var side := -1.0 if flip else 1.0
	_pivot.rotation.y = lerpf(-half, half, t) * side
	_pivot.scale = Vector3.ONE * lerpf(0.75, 1.0, minf(t * 3.0, 1.0))  # swells as it comes through
	if _mat != null and t > 0.0:
		_mat.albedo_color.a = minf(t / (FADE_IN / time), 1.0) * 0.6
	if t > 0.0 and is_inside_tree():
		_hit_swept(_pivot.rotation.y)


func _start() -> void:
	Fx.swoosh(get_parent(), global_position, fwd, radius, arc_deg, Color(color, 0.9), flip, time * 1.4, HEIGHT)


## Enemies within reach whose bearing the blade has passed are hit once.
func _hit_swept(angle: float) -> void:
	var side := -1.0 if flip else 1.0
	var half := deg_to_rad(arc_deg) * 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in _hit or not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() > radius + e.radius:
			continue
		var bearing := fwd.signed_angle_to(to.normalized(), Vector3.UP)
		# Swept so far: bearings from the start of the arc up to the blade's angle.
		var start := -half * side
		if bearing * side < start * side or bearing * side > angle * side:
			continue
		_hit.append(e)
		e.take_hit(damage, to.normalized() * 5.0, 0.0, false)
		Game.register_hit("cast")
		Fx.element_hit(get_parent(), e.global_position, el, to.normalized())
		if on_hit.is_valid():
			on_hit.call(e)
