extends Node3D
## A spectral axe the shaman hurls down during a combo breaker's leap
## (player.BREAKERS `spikes`): a ghost copy of his own axe in the element's
## form (spirit_echo.ghost: earth molten spikes, water icicles, wind wing
## blades) flies from `from` to `to` spinning end over end, buries its head in
## the floor leaning along the throw (small hit there) and stands there.
## `detonate()` (the breaker's dive landing) blows it out of the floor;
## otherwise it sinks away after `life`.

const ELEMENTS := preload("res://scripts/elements.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const TOP := 0.97  # axe-local Y of the head's far edge (spirit_guillotine)
const SPINS := 2.0  # end-over-end turns in flight
const LEAN := 24.0  # degrees it leans along the throw once buried
const ALPHA := 0.7

var axe_mesh: Mesh
var el := "spirit"
var color := Color(0.3, 0.95, 0.85)
var from := Vector3.ZERO
var to := Vector3.ZERO
var size := 1.5
var time := 0.16
var damage := 4.0
var detonate_damage := 6.0
var life := 1.4
var on_hit := Callable()
var blasted: Dictionary = {}  # shared by one breaker's spikes: each foe takes one detonation

var landed := false
var _done := false
var _t := 0.0
var _axe: MeshInstance3D
var _mat: StandardMaterial3D
var _rim: ShaderMaterial
var _rest: Basis  # buried pose
var _rest_y := 0.0
var _start := Vector3.ZERO  # flight start, local


func _ready() -> void:
	var flat := to - from
	flat.y = 0.0
	if flat.length_squared() < 0.001:
		flat = Vector3.FORWARD
	global_position = Vector3(to.x, 0.0, to.z)
	rotation.y = atan2(flat.x, flat.z)
	_axe = SPIRIT_ECHO.ghost(axe_mesh, color, el)
	_mat = _axe.material_override
	_rim = _axe.material_overlay
	_mat.albedo_color.a = ALPHA
	_rim.set_shader_parameter("intensity", 2.4)
	# Upside down (head in the floor, handle up), blade flat to the camera,
	# handle leaning back toward the thrower.
	_rest = Basis(Vector3.RIGHT, -deg_to_rad(LEAN)) * Basis(Vector3.BACK, PI).scaled(Vector3.ONE * size)
	_rest_y = TOP * size * 0.85
	_start = to_local(from)
	add_child(_axe)
	_fly(0.0)


func _process(delta: float) -> void:
	if landed:
		return
	_t += delta
	_fly(clampf(_t / time, 0.0, 1.0))
	if _t >= time:
		_land()


## Flight pose at `k` 0..1: straight in from the hand, spinning end over end
## about the axis across the throw, into the buried pose.
func _fly(k: float) -> void:
	var pos := _start.lerp(Vector3(0.0, _rest_y, 0.0), k)
	var spin := Basis(Vector3.RIGHT, (1.0 - k) * TAU * SPINS)
	_axe.transform = Transform3D(spin * _rest, pos)


func _land() -> void:
	landed = true
	_fly(1.0)
	var parent := get_parent()
	var at := global_position
	var c: Color = ELEMENTS.LOOK[el].color
	Fx.dust(parent, at, 5, 0.55)
	Fx.shards(parent, at, c.darkened(0.3), 5, Vector3.UP, 7.0, 0.16, 0.5)
	Fx.scorch(parent, at, c, 0.7, life + 0.4)
	Fx.element_hit(parent, at + Vector3.UP * 0.3, el, Vector3.DOWN)
	for e in Ascendancy.enemies_near(get_tree(), at, 0.9):
		e.take_hit(damage, Vector3.ZERO, 0.0, false)
		Game.register_hit("breaker")
		if on_hit.is_valid():
			on_hit.call(e)
	var tw := create_tween()
	tw.tween_property(_axe, "position:y", _rest_y - 0.12, 0.05)  # bites in
	tw.tween_interval(life)
	tw.tween_callback(_fade)


## The dive landed: the axe blasts up out of the floor (the element's spikes
## where it stood) and hits round it.
func detonate() -> void:
	if _done:
		return
	_done = true
	landed = true
	var parent := get_parent()
	var at := global_position
	var c: Color = ELEMENTS.LOOK[el].color
	if el in ["earth", "water"]:
		ELEMENTS.spikes(parent, at, el, 1.0, 3)
	else:
		Fx.burst(parent, at + Vector3.UP * 0.4, color, 14, 9.0, 0.16, 0.4, Vector3.UP, 60.0, -10.0)
	Fx.flare(parent, at + Vector3.UP * 0.5, Color(color, 0.95), 2.4, 0.14, "flare")
	Fx.shards(parent, at, c.darkened(0.2), 8, Vector3.UP, 10.0, 0.2, 0.7)
	for e in Ascendancy.enemies_near(get_tree(), at, 1.5):
		if blasted.has(e):
			continue
		blasted[e] = true
		var kb: Vector3 = e.global_position - at
		kb.y = 0.0
		e.take_hit(detonate_damage, kb.normalized() * 4.0, 5.0, true)
		Game.register_hit("breaker")
		if on_hit.is_valid():
			on_hit.call(e)
	# Blown up and out of the floor, swelling as it fades.
	var tw := create_tween().set_parallel()
	tw.tween_property(_axe, "position:y", _rest_y + 2.2, 0.28).set_ease(Tween.EASE_OUT)
	tw.tween_property(_axe, "scale", _axe.scale * 1.6, 0.28)
	tw.tween_property(_mat, "albedo_color:a", 0.0, 0.28)
	tw.tween_property(_rim, "shader_parameter/intensity", 0.0, 0.28)
	tw.chain().tween_callback(queue_free)


func _fade() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_axe, "position:y", _rest_y - size * 0.7, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(_mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_property(_rim, "shader_parameter/intensity", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)
