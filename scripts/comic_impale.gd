extends "res://scripts/comic_flat.gd"
## Impale (L L H, Dash H H: dark into ice), two pieces:
##   ComicImpale.burst(parent, spot, reach): the spear's frost going out to catch them: the frost cracking out
##     across the floor from its foot and cold mist (designed_elements.frost_mark / frost_burst).
##   ComicImpale.stake(parent, spot, foe, flight): waits for the foe's throw (thrown_foe, untyped) to land, then a
##     clean water hit star where it lands on the spear. The `skewered` tell (comic_state_tell) carries the state
##     for the rest of ELEMENT_HOLD.

const SELF := preload("res://scripts/comic_impale.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const CHEST := 0.85
const WAIT_MAX := 0.5  # s for the throw to land
const STAKE_LIFE := 0.45

var foe: Variant
var flight: Variant
var _hit := -1.0
var _starred := false


static func burst(parent: Node, spot: Vector3, r: float) -> Node3D:
	DESIGNED_EL.frost_mark(parent, spot, 0.9, 0.6)
	return DESIGNED_EL.frost_burst(parent, spot, r / DESIGNED_EL.FROST_BURST_REACH * 0.8)


static func stake(parent: Node, _spot: Vector3, e: Variant, by: Variant) -> Node3D:
	if not is_instance_valid(e):
		return null
	var b: Node3D = SELF.new()
	b.foe = e
	b.flight = by
	b.life = WAIT_MAX + STAKE_LIFE
	b.begin(parent, e.global_position)
	return b


func _follow(_delta: float) -> void:
	if not is_instance_valid(foe):
		queue_free()
		return
	global_position = foe.global_position
	if _hit < 0.0:
		var landed: bool = not is_instance_valid(flight) or flight.is_queued_for_deletion()
		if landed or _t >= WAIT_MAX:
			_hit = _t
			life = _t + STAKE_LIFE
			_step = -1


func _draw(_s: int) -> void:
	if _hit < 0.0 or _starred:
		return
	if int((_t - _hit) * STEPS_PER_S) == 0:
		_starred = true
		DESIGNED_EL.DESIGNED.hit(get_parent(), global_position + Vector3.UP * CHEST, "water", 1.0)
