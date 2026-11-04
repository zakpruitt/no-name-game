extends Node3D
## Spirit cleave (Triple Chop's cast): the axes' bound spirits rise as two
## colossal spectral axes standing either side of the target, lean back for a
## beat, then slam inward and meet in a V on it (blade faces toward the
## top-down camera, so the silhouettes read; a straight-ahead chop would be
## edge-on). The impact cracks the floor (scorch + element eruption + double
## shockwave) and hits everything round the heads and under the handles.
## Spawned by player._cast for casts of kind "cleave" (elements.CASTS) at the
## target point; built from spirit_echo.gd's ghost().

const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const SPIRIT_AVATAR := preload("res://scripts/spirit_avatar.gd")
const HEAD := 0.62  # axe-local Y of the head centre (hero_look.BLADE_CENTER)
const EDGE := 0.59  # axe-local depth of the blade below the handle line
const RAISED := -118.0  # degrees: handles past upright, leaning out
const SWEEP := 28.0  # degrees each handle swings back toward the hero: a V opening at him

var axe_mesh: Mesh
var color := Color(0.3, 0.95, 0.85)
var fwd := Vector3.FORWARD
var size := 3.2  # axe scale
var blast := 2.8  # m radius hit round the heads
var damage := 12.0
var launch := 4.0
var rise := 0.12  # s the axes take to appear and lean out
var hang := 0.05  # s they hover at the top
var time := 0.11  # s the slam takes (accelerating)
var on_hit := Callable()
var el := "spirit"

var _pivots: Array[Node3D] = []
var _mats: Array[StandardMaterial3D] = []
var _rims: Array[ShaderMaterial] = []
var _ends: Array[Vector3] = []  # each pivot (handle butt) on the floor, for the handle hit


func _ready() -> void:
	rotation.y = atan2(fwd.x, fwd.z)
	var reach := 0.4 + HEAD * size  # pivot to head centre
	var height := EDGE * size * 0.92  # blade edge bites the floor
	for sgn: float in [-1.0, 1.0]:
		# Pivot out to the side and back toward the hero; local +Z points at the target.
		var out := Vector3(sgn, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(-sgn * SWEEP))
		var yaw := Node3D.new()
		yaw.position = out * reach + Vector3.UP * height
		yaw.rotation.y = atan2(-out.x, -out.z)
		add_child(yaw)
		_ends.append(out * reach)
		var pivot := Node3D.new()
		yaw.add_child(pivot)
		var axe := SPIRIT_ECHO.ghost(axe_mesh, color, el)
		# Axe-local: handle +Y, blade toward -X. In the pivot: handle along +Z
		# (toward the target), cutting edge -Y (leads the slam).
		var b := Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
		axe.transform = Transform3D(b.scaled(Vector3.ONE * size), Vector3(0, 0, 0.4))
		pivot.add_child(axe)
		_pivots.append(pivot)
		_mats.append(axe.material_override)
		_rims.append(axe.material_overlay)
	pose(0.0)
	var tw := create_tween()
	tw.tween_method(_appear, 0.0, 1.0, rise).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(hang)
	tw.tween_method(pose, 0.0, 1.0, time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_impact)
	tw.tween_method(_bury, 0.0, 1.0, 0.1)
	tw.tween_interval(0.08)
	tw.tween_method(_fade, 1.0, 0.0, 0.3)
	tw.tween_callback(queue_free)


## Rising in: fades up and leans out from upright to RAISED.
func _appear(t: float) -> void:
	for p in _pivots:
		p.rotation.x = deg_to_rad(lerpf(-90.0, RAISED, t))
		p.scale = Vector3.ONE * lerpf(0.6, 1.0, t)
	_fade(t)


## Slam position `t` (0 raised .. 1 heads meeting on the floor).
func pose(t: float) -> void:
	for p in _pivots:
		p.rotation.x = deg_to_rad(lerpf(RAISED, 0.0, t))


func _bury(t: float) -> void:
	for p in _pivots:
		p.position.y = -0.2 * t
		p.rotation.x = deg_to_rad(5.0 * t)  # heads bite into the floor


func _fade(a: float) -> void:
	SPIRIT_ECHO.fade_ghosts(_mats, _rims, 0.62 * a, 2.4 * a)


func _impact() -> void:
	var parent := get_parent()
	var head := Vector3(global_position.x, 0.0, global_position.z)
	SPIRIT_AVATAR.slam_fx(parent, head, el, blast * 0.8, fwd)
	if Game.camera_rig:
		Game.camera_rig.punch(0.88, 0.25)
	_hit(head)


## Everything within `blast` of the heads, or under either handle.
func _hit(head: Vector3) -> void:
	var butts: Array[Vector3] = []
	for e0 in _ends:
		var w := global_transform * e0
		butts.append(Vector3(w.x, 0.0, w.z))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var p: Vector3 = e.global_position
		p.y = 0.0
		var near: bool = p.distance_to(head) <= blast + e.radius
		for b in butts:
			near = near or p.distance_to(Geometry3D.get_closest_point_to_segment(p, b, head)) <= 0.9 + e.radius
		if not near:
			continue
		var kb := (p - head).normalized() if p.distance_to(head) > 0.3 else fwd
		SPIRIT_ECHO.strike(e, damage, kb * 5.0, launch, true, get_parent(), el, kb, true, on_hit)
