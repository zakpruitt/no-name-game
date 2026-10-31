extends Control
## Small health bars over enemies: shown for SHOW_TIME s after an enemy takes
## damage (then fade), always on elites. A pale trail shows the chunk just
## lost. The boss has its own bar in the HUD, so it's skipped here.

const SHOW_TIME := 3.0
const FADE := 0.5
const SIZE := Vector2(60, 7)
const HEAD_HEIGHT := 2.4  # metres above the feet (scaled by model_scale)
const TRAIL_SPEED := 0.9  # bar fractions per second
const FILL_COLOR := Color(0.95, 0.25, 0.2)
const ELITE_COLOR := Color(1.0, 0.75, 0.25)
const TRAIL_COLOR := Color(1.0, 0.95, 0.85)
const BACK_COLOR := Color(0.05, 0.03, 0.08, 0.8)

var _trail := {}  # enemy instance id -> trailing hp fraction


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var trail := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		var ratio: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
		var id: int = e.get_instance_id()
		trail[id] = move_toward(_trail.get(id, ratio), ratio, TRAIL_SPEED * delta)
	_trail = trail
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var now := Time.get_ticks_msec()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_boss") or e.state == e.State.SPAWN:
			continue
		var age: float = (now - e.last_hit_ms) / 1000.0
		var alpha: float = 1.0 if e.elite else clampf((SHOW_TIME - age) / FADE, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var head: Vector3 = e.global_position + Vector3.UP * HEAD_HEIGHT * e.model_scale
		if cam.is_position_behind(head):
			continue
		var at := cam.unproject_position(head) - Vector2(SIZE.x * 0.5, 0.0)
		var ratio: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
		var trail: float = maxf(_trail.get(e.get_instance_id(), ratio), ratio)
		draw_rect(Rect2(at - Vector2.ONE, SIZE + Vector2.ONE * 2.0), Color(BACK_COLOR, BACK_COLOR.a * alpha))
		draw_rect(Rect2(at, Vector2(SIZE.x * trail, SIZE.y)), Color(TRAIL_COLOR, 0.8 * alpha))
		var fill := ELITE_COLOR if e.elite else FILL_COLOR
		draw_rect(Rect2(at, Vector2(SIZE.x * ratio, SIZE.y)), Color(fill, alpha))
