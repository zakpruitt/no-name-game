extends Node3D
## Spirit echo: the bound ancestor in the axe finishes the swing. A giant
## spectral copy of the hero's axe sweeps the same arc a beat after the real
## hit, laid flat so its silhouette reads from the top-down camera, hitting
## each enemy in its arc once and leaving a swoosh. Spawned by player._cast
## for casts of kind "echo" (elements.CASTS).

const FADE_IN := 0.04
const FADE_OUT := 0.14
const HEIGHT := 1.0  # sweep height above the floor

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
var _hit: Array[Node] = []
var _scale := 1.0


func _ready() -> void:
	rotation.y = atan2(fwd.x, fwd.z)
	_pivot = Node3D.new()
	_pivot.position.y = HEIGHT
	add_child(_pivot)
	var axe := ghost(axe_mesh, color)
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
## tween material_override's albedo alpha) with a bright rim overlay.
static func ghost(mesh: Mesh, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := Color.from_hsv(c.h, 0.85, 0.85)
	mat.albedo_color = Color(body, 0.0)
	mi.material_override = mat
	var rim: ShaderMaterial = Fx.rim_material().duplicate()
	rim.set_shader_parameter("glow_color", c.lerp(Color.WHITE, 0.5))
	rim.set_shader_parameter("intensity", 2.0)
	mi.material_overlay = rim
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## One foe struck by a spirit cast: the hit, the combo counter, element debris
## at the foe (`debris_dir`, `big`) under `fx_parent`, then the caller's hook.
static func strike(e: Node, damage: float, knockback: Vector3, launch: float, heavy: bool,
		fx_parent: Node, el: String, debris_dir: Vector3, big: bool, on_hit: Callable) -> void:
	e.take_hit(damage, knockback, launch, heavy)
	Game.register_hit("cast")
	Fx.element_hit(fx_parent, e.global_position, el, debris_dir, big)
	if on_hit.is_valid():
		on_hit.call(e)


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
		strike(e, damage, to.normalized() * 5.0, 0.0, false, get_parent(), el, to.normalized(), false, on_hit)
