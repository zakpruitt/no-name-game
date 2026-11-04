extends Node3D
## Spirit wheel (the heavy spin's and Cyclone's cast): a ring of giant
## spectral axes, laid out flat like a sawblade round the hero (handles
## pointing out, blades leading), whirls with him through the spin and grinds
## everything in reach every TICK. Child of the hero so it follows the
## Cyclone's dash. Spawned by player._cast for casts of kind "wheel" (elements.CASTS).

const FOES := preload("res://scripts/foes.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const TICK := 0.2  # s between grinding hits
const TILT := 14.0  # degrees the outer ends lift: a shallow cone, reads as 3D
const HEIGHT := 0.9

var axe_mesh: Mesh
var color := Color(0.3, 0.95, 0.85)
var count := 4
var radius := 3.0  # m to the blade tips
var time := 0.95  # s it lasts
var turns := 2.5  # revolutions over `time`
var damage := 2.0  # per tick
var on_hit := Callable()
var el := "spirit"

var _mats: Array[StandardMaterial3D] = []
var _rims: Array[ShaderMaterial] = []
var _tick := 0.0
var _hub: Node3D


func _ready() -> void:
	position.y = HEIGHT
	_hub = Node3D.new()
	add_child(_hub)
	var s := maxf(radius - 0.4, 0.5) / 0.95  # blade tip lands on `radius` (spirit_echo)
	for i in count:
		var slot := Node3D.new()
		slot.rotation.y = TAU * i / count
		_hub.add_child(slot)
		var lift := Node3D.new()
		lift.rotation.x = -deg_to_rad(TILT)  # +Z end up
		slot.add_child(lift)
		var axe := SPIRIT_ECHO.ghost(axe_mesh, color, el)
		# Laid flat, handle out along +Z, blade toward +X (leads the spin), flat
		# side to the camera: spirit_echo's sweep basis.
		axe.transform = Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)).scaled(Vector3.ONE * s), Vector3(0, 0, 0.4))
		lift.add_child(axe)
		_mats.append(axe.material_override)
		_rims.append(axe.material_overlay)
	_hub.scale = Vector3.ONE * 0.3
	_fade(0.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(_hub, "rotation:y", TAU * turns, time)
	tw.tween_property(_hub, "scale", Vector3.ONE, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_method(_fade, 0.0, 1.0, 0.1)
	tw.tween_method(_fade, 1.0, 0.0, time * 0.3).set_delay(time * 0.7)
	tw.chain().tween_callback(queue_free)


func _fade(a: float) -> void:
	SPIRIT_ECHO.fade_ghosts(_mats, _rims, 0.55 * a, 2.2 * a)


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var at := Vector3(global_position.x, 0.0, global_position.z)
	for e in FOES.near(get_tree(), at, radius):
		var out: Vector3 = e.global_position - at
		out.y = 0.0
		var tangent := out.normalized().cross(Vector3.DOWN)  # the way the blades are moving
		SPIRIT_ECHO.strike(e, damage, (out.normalized() + tangent).normalized() * 3.0, 0.0, false,
			get_parent().get_parent(), el, tangent, false, on_hit)
