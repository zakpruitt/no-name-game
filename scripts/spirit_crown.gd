extends Node3D
## Spirit crown (Launcher's cast): three colossal spectral axes burst blade-up
## out of the floor under the target in a flared crown, flinging it skyward,
## hang there a beat and sink back. The element's column rises in the middle.
## Spawned by player._cast for casts of kind "crown" (elements.CASTS) at the
## target point; built from spirit_echo.gd's ghost().

const ELEMENTS := preload("res://scripts/elements.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const COUNT := 3
const FLARE := 18.0  # degrees each axe leans out from the centre
const RING := 0.7  # m the handles sit out from the centre
const DEPTH := 0.92  # axe length (x size) buried at the start

var axe_mesh: Mesh
var color := Color(0.3, 0.95, 0.85)
var fwd := Vector3.FORWARD
var size := 3.4  # axe scale
var radius := 1.9  # m hit radius
var damage := 6.0
var launch := 9.0
var height := 4.0  # element column
var delay := 0.03  # s before the axes break the floor
var burst := 0.08  # s to erupt
var hold := 0.16
var on_hit := Callable()
var el := "spirit"

var _axes: Array[Node3D] = []
var _mats: Array[StandardMaterial3D] = []
var _rims: Array[ShaderMaterial] = []


func _ready() -> void:
	rotation.y = atan2(fwd.x, fwd.z)
	for i in COUNT:
		var ang := TAU * i / COUNT  # one leans away ahead (seen face-on from behind), two flank
		var out := Vector3(sin(ang), 0.0, cos(ang))
		var slot := Node3D.new()
		slot.position = out * RING
		# Lean out from the centre; every blade's face turned to the camera behind
		# the hero (axe-local -X = blade), edges pointing outward.
		var face := PI if out.x > 0.01 else 0.0
		slot.basis = Basis(out.cross(Vector3.UP).normalized(), deg_to_rad(-FLARE)) * Basis(Vector3.UP, face)
		add_child(slot)
		var axe := SPIRIT_ECHO.ghost(axe_mesh, color, el)
		axe.scale = Vector3.ONE * size
		slot.add_child(axe)
		_axes.append(axe)
		_mats.append(axe.material_override)
		_rims.append(axe.material_overlay)
	_rise(0.0)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_erupt)
	tw.tween_method(_rise, 0.0, 1.0, burst).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(hold)
	tw.tween_method(pose, 1.0, 0.45, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_method(_fade, 1.0, 0.0, 0.22)
	tw.tween_callback(queue_free)


## Eruption `t`: 0 buried .. 1 fully out (heads high, handles in the floor).
func pose(t: float) -> void:
	for i in _axes.size():
		_axes[i].position.y = -DEPTH * size * (1.0 - t)  # out: the handle's butt stays buried
		_axes[i].rotation.y = (1.0 - t) * 1.2 * (1.0 if i % 2 == 0 else -1.0)  # twists square to the camera as it rises


func _rise(t: float) -> void:
	pose(t)
	_fade(minf(t * 3.0, 1.0))


func _fade(a: float) -> void:
	SPIRIT_ECHO.fade_ghosts(_mats, _rims, 0.6 * a, 2.4 * a)


func _erupt() -> void:
	var parent := get_parent()
	var at := Vector3(global_position.x, 0.0, global_position.z)
	var c: Color = ELEMENTS.LOOK[el].color
	ELEMENTS.pillar(parent, at, el, height, radius * 0.7)
	Fx.scorch(parent, at, c, radius * 1.1, 1.2)
	Fx.ring(parent, at, Color(c, 0.95), radius * 1.8, 0.3)
	Fx.shards(parent, at, c.darkened(0.3), 14, Vector3.UP, 13.0, 0.2, 0.8)
	Fx.dust(parent, at, 10, 0.7)
	Fx.flare(parent, at + Vector3.UP * 1.2, Color(c, 0.95), 3.2, 0.16, "flare")
	ELEMENTS.light_pop(parent, at, c, 6.0, 8.0, 0.35)
	Game.shake(0.35)
	ELEMENTS.hit_area(get_tree(), at, radius, damage, launch, true, "cast", on_hit)
