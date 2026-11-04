extends Node3D
## Spirit guillotine (Spike's cast, L H H): a colossal spectral axe drops out
## of the sky blade-first onto the target, buries itself in the floor with a
## floor-cracking slam (spirit_avatar.slam_fx) and stands there a beat before
## sinking away. Blade face turned to the camera behind the hero. No launch:
## Spike drives juggled foes down. Spawned by player._cast for casts of kind
## "guillotine" (elements.CASTS) at the target point.

const FOES := preload("res://scripts/foes.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const SPIRIT_AVATAR := preload("res://scripts/spirit_avatar.gd")
const DROP := 9.0  # m above its resting height it falls from
const TOP := 0.97  # axe-local Y of the head's far edge (lands on the floor)
const HOVER := 4.5  # m above its resting height it waits at (`wait`)

var axe_mesh: Mesh
var color := Color(0.3, 0.95, 0.85)
var fwd := Vector3.FORWARD
var size := 3.0
var radius := 2.4
var damage := 7.0
var fall := 0.13  # s
var hold := 0.22
var on_hit := Callable()
var heavy := true  # false: light impact, no hitstop / camera (volleys: Cataclysm, Trinity); 0 damage = visual only
var el := "spirit"
var wait := false  # hover point-down HOVER m up over `target` until drop() (Spike's breaker volley)
var target: Node3D
var shared = null  # Dictionary shared by a volley: each foe hit once by all of them

var _axe: MeshInstance3D
var _rest := 0.0


func _ready() -> void:
	rotation.y = atan2(fwd.x, fwd.z)
	_axe = SPIRIT_ECHO.ghost(axe_mesh, color, el)
	# Upside down: head at the bottom, handle up; blade faces sideways (flat
	# side toward the camera).
	_axe.basis = Basis(Vector3.BACK, PI).scaled(Vector3.ONE * size)
	_rest = TOP * size * 0.9  # the head bites into the floor
	_axe.position.y = _rest + DROP
	add_child(_axe)
	var mat: StandardMaterial3D = _axe.material_override
	var rim: ShaderMaterial = _axe.material_overlay
	if wait:
		_axe.position.y = _rest + HOVER
		var tw := create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.5, 0.12)
		tw.parallel().tween_property(rim, "shader_parameter/intensity", 2.2, 0.12)
		return
	_fall()


func _process(_delta: float) -> void:
	if wait and is_instance_valid(target):
		global_position = Vector3(target.global_position.x, 0.0, target.global_position.z)
		_axe.position.y = _rest + HOVER + sin(Time.get_ticks_msec() / 1000.0 * 6.0) * 0.12


## Waiting: fall now (after `delay` s), onto wherever the target is.
func drop(delay := 0.0) -> void:
	if not wait:
		return
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		wait = false
		_axe.position.y = _rest + DROP * 0.5  # (falls from just above the hover)
		_fall())


## Waiting: no drop after all; fade out.
func cancel() -> void:
	wait = false
	var tw := create_tween().set_parallel()
	tw.tween_property(_axe.material_override, "albedo_color:a", 0.0, 0.2)
	tw.tween_property(_axe.material_overlay, "shader_parameter/intensity", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)


func _fall() -> void:
	var mat: StandardMaterial3D = _axe.material_override
	var rim: ShaderMaterial = _axe.material_overlay
	mat.albedo_color.a = 0.65
	rim.set_shader_parameter("intensity", 2.6)
	Fx.flare(get_parent(), global_position + Vector3.UP * 0.3, Color(color, 0.7), radius * 1.2, fall, "ring")
	var tw := create_tween()
	tw.tween_property(_axe, "position:y", _rest, fall).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_impact)
	tw.tween_property(_axe, "position:y", _rest - 0.15, 0.05)
	tw.tween_interval(hold)
	tw.tween_property(_axe, "position:y", _rest - size * 0.6, 0.3).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.parallel().tween_property(rim, "shader_parameter/intensity", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _impact() -> void:
	var at := Vector3(global_position.x, 0.0, global_position.z)
	SPIRIT_AVATAR.slam_fx(get_parent(), at, el, radius * 0.9, Vector3.ZERO, heavy)
	if heavy and Game.camera_rig:
		Game.camera_rig.punch(0.85, 0.22)
	if damage <= 0.0:
		return
	for e in FOES.near(get_tree(), at, radius):
		if shared != null:
			if shared.has(e):
				continue
			shared[e] = true
		var kb: Vector3 = e.global_position - at
		kb.y = 0.0
		SPIRIT_ECHO.strike(e, damage, kb.normalized() * 3.0, 0.0, true, get_parent(), el, Vector3.DOWN, true, on_hit)
