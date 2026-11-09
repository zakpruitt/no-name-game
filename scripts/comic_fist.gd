extends Node3D
## Molten Palm's fist (void_element._fist hands off here): the drawn magma fist sheet facing the camera
## (designed_elements.fist_mesh / fist_step), stretched as it flies and squashed with an impact star when it
## arrives. Moves like the old polygon one, so the tentacle (void_grab._tick_palm) still follows it out.

const SELF := preload("res://scripts/comic_fist.gd")  # (held: a load() at fire time recompiled it once freed)
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const HOLD_AFTER := 0.08  # s it holds where it lands, then dissolves

var _time := 0.2  # s out
var _t := 0.0
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _d := Vector3.RIGHT  # its flight on the screen plane
var _sprite: MeshInstance3D


## The same flight as void_element._fist: from 1 m ahead of `at` out `length` m along `fwd` in `time` s.
static func spawn(parent: Node, at: Vector3, fwd: Vector3, length: float, time: float) -> Node3D:
	var fist: Node3D = SELF.new()
	parent.add_child(fist)
	fist.setup(at, fwd, length, time)
	return fist


func setup(at: Vector3, fwd: Vector3, length: float, time: float) -> void:
	add_to_group("comic_fist")
	_time = time
	global_position = at + fwd * 1.0 + Vector3.UP * 1.0
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_right = cam.global_basis.x
		_up = cam.global_basis.y
	var d := _right * fwd.dot(_right) + _up * fwd.dot(_up)
	_d = d.normalized() if d.length() > 0.05 else _right
	_sprite = DESIGNED_EL.fist_mesh(self)
	DESIGNED_EL.aim_sprite(_sprite, atan2(_d.dot(_up), _d.dot(_right)))
	var tw := create_tween()
	tw.tween_property(self, "global_position", at + fwd * length + Vector3.UP * 1.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tick(0.0)


func _process(delta: float) -> void:
	tick(delta)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	_t += delta
	if _t >= _time + HOLD_AFTER + DESIGNED_EL.FIST_DISSOLVE:
		queue_free()
		return
	DESIGNED_EL.fist_step(_sprite, _t, _time, HOLD_AFTER)
