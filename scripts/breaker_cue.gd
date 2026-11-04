extends Node3D
## Combo breaker timing cue (void_element.gd BREAKERS): a fixed target ring on the
## floor where the dive will land and a closing ring shrinking onto it. The
## rings meet at `sweet` s after spawning, the press window is `open`..`close`
## (the target ring lights up gold through it). lock() = pressed too early
## (greys out), hit(perfect) = the dive is coming (flash), else it fades at close.

const TARGET := 1.6  # m radius of the target ring
const START := 4.6  # m radius the closing ring starts at
const GOLD := Color(1.0, 0.82, 0.3)

var color := Color(0.3, 0.95, 0.85)
var open := 0.2
var sweet := 0.38
var close := 0.54
var crisp := false  # thin hard rings: the tentacle's breakers land right on this spot

var _t := 0.0
var _target: MeshInstance3D
var _closing: MeshInstance3D
var _over := false


func _ready() -> void:
	_target = _ring(Color(1, 1, 1, 0.55))
	_target.scale = Vector3(TARGET, 1.0, TARGET)
	_closing = _ring(Color(color, 0.95))
	_update()


func _ring(c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	if crisp:
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.92
		hoop.outer_radius = 1.0
		hoop.rings = 48
		hoop.ring_segments = 4
		mesh = hoop
	else:
		var quad := PlaneMesh.new()
		quad.size = Vector2.ONE * 2.2  # Fx.ring: the texture's ring sits ~1 m out
		mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true  # reads over the spikes and enemies
	if not crisp:
		mat.albedo_texture = Fx.TEX.ring
	mat.albedo_color = c
	mesh.material = mat
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position.y = 0.12
	add_child(m)
	return m


func _process(delta: float) -> void:
	if _over:
		return
	_t += delta
	_update()
	if _t >= close:
		_over = true
		_fade(0.15)


func _update() -> void:
	# Linear from START to TARGET at `sweet`, on past it toward the centre.
	var r := lerpf(START, TARGET, _t / sweet) if _t < sweet else lerpf(TARGET, TARGET * 0.4, (_t - sweet) / maxf(close - sweet, 0.01))
	_closing.scale = Vector3(r, 1.0, r)
	var in_window := _t >= open and _t <= close
	var tm: StandardMaterial3D = _target.mesh.material
	tm.albedo_color = Color(GOLD, 0.75 + 0.25 * sin(_t * 40.0)) if in_window else Color(1, 1, 1, 0.55)


## Pressed too early: no breaker this time.
func lock() -> void:
	if _over:
		return
	_over = true
	for m in [_target, _closing]:
		(m.mesh.material as StandardMaterial3D).albedo_color = Color(0.35, 0.35, 0.38, 0.7)
	_fade(0.25)


## Pressed in the window: flash and go.
func hit(perfect: bool) -> void:
	if _over:
		return
	_over = true
	if not crisp:
		Fx.ring(get_parent(), global_position, Color(GOLD if perfect else color, 0.95), TARGET * 1.6, 0.25)
	_fade(0.1)


func _fade(time: float) -> void:
	var tw := create_tween().set_parallel()
	for m in [_target, _closing]:
		tw.tween_property(m, "transparency", 1.0, time)
	tw.chain().tween_callback(queue_free)
