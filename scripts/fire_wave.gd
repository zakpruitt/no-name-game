extends Node3D
## Ground wave that rolls forward, damaging each enemy it passes once.

@export var speed := 12.0
@export var lifetime := 0.6
@export var damage := 10.0
@export var width := 1.4
@export var color := Color(1.0, 0.45, 0.1)

var direction := Vector3.FORWARD
var _age := 0.0
var _hit: Array = []
var _puff_t := 0.0
var _scorch_t := 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta
	_puff_t -= delta
	_scorch_t -= delta
	if _puff_t <= 0.0:
		_puff_t = 0.045
		# Saturated flame tongues licking up (pale puffs washed out on the light floor).
		var hot := Color.from_hsv(color.h, 0.95, 1.0)
		Fx.burst(get_parent(), global_position + Vector3.UP * 0.2, hot, 4, 4.5, 0.22, 0.25, Vector3.UP, 25.0, 3.0, 0.45, "flare")
	if _scorch_t <= 0.0:
		_scorch_t = 0.18  # few decals: 8 Cataclysm waves at once
		Fx.scorch(get_parent(), global_position, color, width * 0.6, 0.8)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in _hit or not e.is_alive():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0.0
		if d.length() < width + e.radius:
			_hit.append(e)
			e.take_hit(damage, direction * 6.0, 0.0, false)
			Game.register_hit("ember_cleave")
