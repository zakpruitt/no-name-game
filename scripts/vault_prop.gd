extends Node3D
## The vault room's chest: a gold chest between two candles, lit in the
## vault's path colour (`color`, set before adding). Rises out of the floor,
## bursts when the power is taken, sinks after (main._vault).

## [piece, offset, yaw degrees]
const PIECES := [
	["chest_gold", Vector3.ZERO, 0.0],
	["candle_lit", Vector3(-1.3, 0.0, 0.4), 0.0],
	["candle_lit", Vector3(1.3, 0.0, 0.4), 0.0],
]
const DEPTH := 2.5  # how far below the floor it starts

var color := Color.WHITE
var _light: OmniLight3D
var _mote_t := 0.0
var _t := 0.0


func _ready() -> void:
	for p: Array in PIECES:
		var n: Node3D = ComicLook.piece(p[0])
		n.position = p[1]
		n.rotation_degrees.y = p[2]
		add_child(n)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 0.0
	_light.omni_range = 6.0
	_light.position = Vector3(0.0, 1.6, 0.8)
	add_child(_light)


func rise() -> void:
	position.y = -DEPTH
	var tw := create_tween()
	tw.tween_property(self, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_light, "light_energy", 2.5, 0.8)
	Game.shake(0.25)
	Fx.dust(get_parent(), global_position + Vector3.UP * DEPTH, 12, 0.8)


## The power was taken: a burst of the path colour out of the chest.
func burst() -> void:
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.8, color, 30, 6.0, 0.12, 0.5, Vector3.UP, 70.0)
	Fx.ring(get_parent(), global_position, Color(color, 0.85), 2.5, 0.4)


func sink() -> void:
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 0.0, 0.4)
	tw.tween_property(self, "position:y", -DEPTH, 0.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	if _light.light_energy > 0.5:
		_light.light_energy = 2.5 + sin(_t * 2.5) * 0.5
	_mote_t -= delta
	if _mote_t <= 0.0 and position.y > -0.1:
		_mote_t = 0.3
		Fx.burst(get_parent(), global_position + Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.3, 0.3)),
			Color(color, 0.8), 2, 1.2, 0.07, 1.2, Vector3.UP, 20.0, 0.0, 0.0)
