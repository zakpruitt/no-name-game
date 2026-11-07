extends Node3D
## Dash Stab's lash (elements.CASTS "lash", fired by hero_fx.cast on DL's first hit): the claw whips the
## tentacle's inked ribbon (void_tendril.gd) straight out ahead to `reach`, cutting what its tip passes,
## then snaps it back, cutting again. Each foe once per leg. It replaced the shaman's spirit tomahawk
## (round 30, second pass) with the same damage, reach and timing: 0.3 s out, 0.32 s back.

const FOES := preload("res://scripts/foes.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const HEIGHT := 0.9  # m: the line it cuts along
const WAVE := 0.12  # how hard the ribbon whips on the way out
const SNAP_WAVE := 0.03  # nearly straight when it's taut, at the far end

var color := Color(0.3, 0.95, 0.85)  # (set by hero_fx.spirit; the ink keeps the tentacle's own colours)
var el := "spirit"
var dir := Vector3.FORWARD
var hero: Node3D  # it comes out of his hand and goes back to it
var size := 2.6  # m across what the tip cuts (the tomahawk's size)
var reach := 8.0
var out_time := 0.3
var back_time := 0.32
var damage := 6.0
var back_damage := 4.0
var on_hit := Callable()

var _rope: Node3D
var _from := Vector3.ZERO
var _k := 0.0  # 0..1 how far out the tip is
var _back := false
var _hit: Array[Node] = []
var _time := 0.0


func _ready() -> void:
	_from = global_position
	_rope = TENDRIL.new()
	add_child(_rope)
	var tw := create_tween()
	tw.tween_method(_out, 0.0, 1.0, out_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_turn)
	tw.tween_method(_in, 1.0, 0.0, back_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	var hand := _hand()
	var tip := Vector3(_from.x, HEIGHT, _from.z) + dir * reach * _k
	_rope.draw(hand, tip, maxf(_k, 0.05), lerpf(WAVE, SNAP_WAVE, _k), 0.0, _time)
	_cut(tip)


func _out(k: float) -> void:
	_k = k


func _in(k: float) -> void:
	_k = k


func _turn() -> void:
	_back = true
	_hit.clear()
	var tip := Vector3(_from.x, HEIGHT, _from.z) + dir * reach
	if Game.comic_style and Fx.DESIGNED.on():  # fx-polygons: the snap is a drawn star in the lash's element
		Fx.DESIGNED.hit(get_parent(), tip, el, 1.0)
	else:
		Fx.flare(get_parent(), tip, Color(color, 0.9), size * 0.9, 0.12, "star8", true)


## Where the ribbon starts: his claw when the rig has one, else his chest.
func _hand() -> Vector3:
	if is_instance_valid(hero):
		var v: Variant = hero.get("_void")
		if v != null and is_instance_valid(v) and v.has_method("_hand_pos"):
			return v._hand_pos()
		return hero.global_position + Vector3.UP * HEIGHT
	return Vector3(_from.x, HEIGHT, _from.z)


func _cut(tip: Vector3) -> void:
	var at := Vector3(tip.x, 0.0, tip.z)
	for e in FOES.near(get_tree(), at, size * 0.55):
		if e in _hit:
			continue
		_hit.append(e)
		var push: Vector3 = dir if not _back else -dir
		SPIRIT_ECHO.strike(e, back_damage if _back else damage, push * 4.0, 0.0, false,
			get_parent(), el, push, false, on_hit)
