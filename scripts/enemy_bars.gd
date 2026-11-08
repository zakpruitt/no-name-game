extends Control
## Small health bars over enemies: shown for SHOW_TIME s after an enemy takes
## damage (then fade), always on elites. A pale trail shows the chunk just
## lost. The boss has its own bar in the HUD, so it's skipped here.

const SHOW_TIME := 3.0
const FADE := 0.5
const SIZE := Vector2(60, 7)
const HEAD_HEIGHT := 2.4  # metres above the feet (scaled by model_scale), for a kind without bar_height
const TYPES: Dictionary = preload("res://scripts/enemy_types.gd").TYPES
const TRAIL_SPEED := 0.9  # bar fractions per second
const FILL_COLOR := Color(0.95, 0.25, 0.2)
const ELITE_COLOR := Color(1.0, 0.75, 0.25)
const TRAIL_COLOR := Color(1.0, 0.95, 0.85)
const BACK_COLOR := Color(0.05, 0.03, 0.08, 0.8)
## Bars never go above this (the HP / room band at the top of the HUD), so
## enemies juggled off the top of the screen pin their bar just below it.
const TOP_MARGIN := 96.0
## Likewise kept above the controls line along the bottom edge.
const BOTTOM_MARGIN := 48.0
## A living foe never shows an empty bar (spar audit 2026-11-07 item 10: the warrior lived on under 1 hp of 75 for a
## second with a bar that read 0): the fill is at least SLIVER_PX wide while hp > 0.
const SLIVER_PX := 4.0

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
	var screen := get_viewport_rect().size
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_boss") or e.state == e.State.SPAWN:
			continue
		var age: float = (now - e.last_hit_ms) / 1000.0
		var alpha: float = 1.0 if e.elite else clampf((SHOW_TIME - age) / FADE, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var head: Vector3 = e.global_position + Vector3.UP * bar_height(e) * e.model_scale
		if cam.is_position_behind(head):
			continue
		var at := cam.unproject_position(head) - Vector2(SIZE.x * 0.5, 0.0)
		at.x = clampf(at.x, 4.0, screen.x - SIZE.x - 4.0)
		at.y = clampf(at.y, TOP_MARGIN, screen.y - BOTTOM_MARGIN - SIZE.y)
		var ratio: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
		var trail: float = maxf(_trail.get(e.get_instance_id(), ratio), ratio)
		draw_rect(Rect2(at - Vector2.ONE, SIZE + Vector2.ONE * 2.0), Color(BACK_COLOR, BACK_COLOR.a * alpha))
		draw_rect(Rect2(at, Vector2(SIZE.x * trail, SIZE.y)), Color(TRAIL_COLOR, 0.8 * alpha))
		var fill := ELITE_COLOR if e.elite else FILL_COLOR
		draw_rect(Rect2(at, Vector2(fill_px(e.hp, e.max_hp), SIZE.y)), Color(fill, alpha))


## The fill's width for `hp` of `max_hp`: SLIVER_PX at least while it lives, 0 only when dead.
static func fill_px(hp: float, max_hp: float) -> float:
	if hp <= 0.0:
		return 0.0
	return clampf(SIZE.x * hp / maxf(max_hp, 0.001), SLIVER_PX, SIZE.x)


## Bar height above the feet before model_scale: the kind's `bar_height` (enemy_types.gd), else HEAD_HEIGHT.
static func bar_height(e: Node) -> float:
	var spec: Dictionary = TYPES.get(e.get_meta("kind", ""), {})
	return spec.get("bar_height", HEAD_HEIGHT)
