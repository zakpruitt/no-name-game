extends Control
## Edge-of-screen arrows for threats the camera can't see: enemies winding
## up an attack (red melee / purple ranged, growing as the hit gets close)
## and enemy bolts in flight.

const MARGIN := 36.0
const MELEE_COLOR := Color(1.0, 0.25, 0.2)
const RANGED_COLOR := Color(0.75, 0.4, 1.0)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state == e.State.WINDUP:
			var k: float = clampf(e._state_t / maxf(e.attack_windup, 0.01), 0.0, 1.0)
			_mark(cam, e.global_position + Vector3.UP, RANGED_COLOR if e.is_ranged() else MELEE_COLOR, k)
	for p in get_tree().get_nodes_in_group("projectiles"):
		_mark(cam, p.global_position, RANGED_COLOR, 0.5)


## Arrow on the screen edge pointing at `pos`, if `pos` is off-screen.
func _mark(cam: Camera3D, pos: Vector3, color: Color, urgency: float) -> void:
	var screen := get_viewport_rect().size
	var sp := cam.unproject_position(pos)
	if not cam.is_position_behind(pos) and Rect2(Vector2.ZERO, screen).grow(-8.0).has_point(sp):
		return
	var center := screen * 0.5
	var dir := sp - center
	if cam.is_position_behind(pos):
		dir = -dir
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var half := center - Vector2(MARGIN, MARGIN)
	var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var tip := center + dir * t
	var size := 30.0 + 18.0 * urgency
	var side := Vector2(-dir.y, dir.x)
	# Notched arrowhead (tip, wing, notch, wing) so the direction reads at a glance.
	var pts := PackedVector2Array([tip, tip - dir * size + side * size * 0.55, tip - dir * size * 0.55,
		tip - dir * size - side * size * 0.55])
	var c := color
	c.a = 0.55 + 0.45 * urgency
	draw_colored_polygon(pts, c)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.05, 0.02, 0.08, c.a), 3.0)
