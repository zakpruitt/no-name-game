extends Control
## Combo breaker timing prompt (player.BREAKERS): a circle affixed to the
## hero, above his left shoulder on screen (the combo guide sits on his
## right), so the timing stays in the middle of the screen. It fills up while the hero is in a breaker's leap, with
## the button to press (heavy) in the middle. Full = the sweet spot (press
## now: PERFECT); the ring turns gold while the window is open. A press flashes
## it (gold if perfect) and it goes; too early greys it out. Separate from the
## combo guide (combo_guide.gd), which only shows the next combo inputs.
## Reads player.breaker_window() every frame; the player adds it on its own
## CanvasLayer the first time it leaps (player._breaker_prompt()).

const OFFSET := Vector2(-92.0, -78.0)  # px from the hero's chest on screen: up and to his left
const CHEST := 1.1  # metres above the feet it hangs off (as combo_guide.CHEST)
const MARGIN := 56.0  # keep this far inside the screen edges
const RADIUS := 38.0
const WIDTH := 8.0
const KEY_H := 26.0
const KEY_SIZE := 15
const GOLD := Color(1.0, 0.82, 0.3)
const GREY := Color(0.42, 0.42, 0.46)
const OUT_TIME := 0.22  # real s the press flash / lockout fade takes
const NAME_SIZE := 15  # the breaker's name under the circle (breaker_window() `name`)
const NAME_GAP := 8.0

var player: Node
var center := Vector2.ZERO  # where it draws (follows the hero each frame)
var fixed := false  # true: stay at `center` (tests/breaker_prompt_preview.gd lays several out)

var _font: Font
var _label := "RMB"  # the heavy button (combo_guide.LABELS, loaded in _ready)
var _box := StyleBoxFlat.new()
var _shown := false
var _w: Dictionary = {}  # last breaker_window() while shown
var _out := -1.0  # real s since it ended (-1 = live)
var _out_kind := ""  # "hit" / "perfect" / "lock" / "miss"
var _last_us := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_label = load("res://scripts/combo_guide.gd").LABELS.heavy
	_box.anti_aliasing = true
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	# Real time: the window plays in slow motion and the press freezes the frame.
	var now := Time.get_ticks_usec()
	var dt := (now - _last_us) / 1000000.0
	_last_us = now
	var w: Dictionary = player.breaker_window() if is_instance_valid(player) else {}
	if w.get("live", false):
		_shown = true
		_out = -1.0
		_w = w
	elif _shown and _out < 0.0:
		_out = 0.0  # just ended: how?
		_out_kind = w.get("ended", "miss")
	if _shown and not fixed:
		_follow()
	if _out >= 0.0:
		_out += dt
		if _out >= OUT_TIME:
			_shown = false
			_out = -1.0
	queue_redraw()


## Pin it next to the hero: his chest on screen plus OFFSET, kept on screen.
## The body, not the leaping model, so it holds still while he's in the air.
func _follow() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not (player is Node3D):
		return
	var chest: Vector3 = player.global_position + Vector3.UP * CHEST
	if cam.is_position_behind(chest):
		return
	var screen := get_viewport_rect().size
	var at := cam.unproject_position(chest) + OFFSET
	center = Vector2(clampf(at.x, MARGIN, screen.x - MARGIN), clampf(at.y, MARGIN, screen.y - MARGIN))


func _draw() -> void:
	if not _shown or _w.is_empty():
		return
	var c := center
	var t: float = _w.t
	var fill := clampf(t / _w.sweet, 0.0, 1.0)
	var in_window: bool = t >= _w.open and t <= _w.close
	var a := 1.0
	var col: Color = _w.color
	var scale := 1.0
	if _out >= 0.0:
		var k := _out / OUT_TIME
		a = 1.0 - k
		match _out_kind:
			"perfect":
				col = GOLD
				scale = 1.0 + 0.5 * k
			"hit":
				scale = 1.0 + 0.3 * k
			_:
				col = GREY
		fill = 1.0 if _out_kind in ["perfect", "hit"] else fill
	elif in_window:
		col = GOLD
	var r := RADIUS * scale
	# Back disc and empty track.
	draw_circle(c, r + WIDTH * 0.5 + 3.0, Color(0.04, 0.03, 0.07, 0.72 * a))
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.14 * a), WIDTH, true)
	# The window on the track: a thin gold band from `open` to full.
	var open_frac: float = clampf(_w.open / _w.sweet, 0.0, 1.0)
	draw_arc(c, r + WIDTH * 0.5 + 1.5, -PI * 0.5 + TAU * open_frac, PI * 1.5, 32, Color(GOLD, 0.55 * a), 2.0, true)
	# The fill, clockwise from the top.
	if fill > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * fill, 48, Color(col, 0.95 * a), WIDTH, true)
	# Full and still open: pulse (press now).
	if in_window and fill >= 1.0 and _out < 0.0:
		var p := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 30.0)
		draw_arc(c, r + WIDTH + 2.0 + 3.0 * p, 0.0, TAU, 48, Color(GOLD, 0.7 * (1.0 - p)), 3.0, true)
	if _out >= 0.0 and _out_kind in ["perfect", "hit"]:
		draw_arc(c, r + WIDTH + 18.0 * (_out / OUT_TIME), 0.0, TAU, 48, Color(col, a), 3.0, true)
	_key(c, a, col if in_window or _out >= 0.0 else Color(1, 1, 1))
	_name(c + Vector2(0.0, r + WIDTH * 0.5 + NAME_GAP), a, col)


## The breaker's name centred under the circle, with a dark outline so it
## reads over the floor.
func _name(at: Vector2, a: float, col: Color) -> void:
	var label: String = _w.get("name", "")
	if label == "":
		return
	var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	var pos := Vector2(at.x - tw * 0.5, at.y + NAME_SIZE)
	draw_string_outline(_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, 4, Color(0.04, 0.03, 0.07, 0.8 * a))
	draw_string(_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, Color(col.lerp(Color.WHITE, 0.5), a))


## The button to press in the middle (the combo guide's key style).
func _key(c: Vector2, a: float, rim: Color) -> void:
	var label := _label
	var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_SIZE).x
	var w := maxf(KEY_H, tw + KEY_H * 0.6)
	var rect := Rect2(c - Vector2(w, KEY_H) * 0.5, Vector2(w, KEY_H))
	_box.bg_color = Color(0.1, 0.08, 0.14, 0.95 * a)
	_box.set_corner_radius_all(int(KEY_H * 0.5))
	_box.set_border_width_all(2)
	_box.border_color = Color(rim, a)
	draw_style_box(_box, rect)
	draw_string(_font, Vector2(c.x - tw * 0.5, c.y + KEY_SIZE * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_SIZE,
		Color(1, 1, 1, a))
