extends Control
## Combo breaker timing prompt (void_element.gd BREAKERS): a circle affixed to the
## hero, above his left shoulder on screen (the combo guide sits on his
## right), so the timing stays in the middle of the screen. It fills up while the hero is in a breaker's leap, with
## the button to press (heavy) in the middle. Full = the sweet spot (press
## now: PERFECT); the ring turns gold while the window is open. A press flashes
## it (gold if perfect) and it goes; too early greys it out. Separate from the
## combo guide (combo_guide.gd), which only shows the next combo inputs.
## Round 43 (Zak: "make sure the indicator shows each option for the player to choose"): every ending the window
## offers is on it at once (hero_leap.options()): a little inked mouse in the middle with each button that does
## something filled in its ending's element colour (fx_palette body), and under the circle one chip per ending,
## in mouse order, "[LMB] Black Ice  or  [RMB] Maw", each chip's key rim and name in that colour. One ending
## shows the same layout with only the right button lit and one chip. The press keeps the chosen chip and drops
## the other.
## Reads player.breaker_window() every frame; the player adds it on its own
## CanvasLayer the first time it leaps (hero_leap._make_prompt()).

const OFFSET := Vector2(-92.0, -78.0)  # px from the hero's chest on screen: up and to his left
const CHEST := 1.1  # metres above the feet it hangs off (as combo_guide.CHEST)
const MARGIN := 56.0  # keep this far inside the screen edges
const RADIUS := 38.0
const WIDTH := 6.0  # (round 33, part 3: 8)
## Round 33, part 3 (sleek HUD, hud_ink.gd): a see-through back disc with halftone dots in the breaker's colour
## round the key, the track between two thin ink lines, 2 px rings (3) and the name in the words' font.
const BACK_ALPHA := 0.45  # (0.72)
const DOTS_ALPHA := 0.3
const HUD_INK := preload("res://scripts/hud_ink.gd")
const GOLD := Color(1.0, 0.82, 0.3)
const GREY := Color(0.42, 0.42, 0.46)
const OUT_TIME := 0.22  # real s the press flash / lockout fade takes
const NAME_SIZE := 19  # (18 for the lone name before round 43) each ending's name under the circle
const NAME_GAP := 7.0
const MOUSE_W := 24.0  # px: the mouse glyph in the middle (round 43; was a "RMB" key)
const MOUSE_H := 33.0
const MOUSE_BTN := 14.0  # px tall, its two buttons
const CHIP_KEY_H := 21.0  # each ending's key pill under the circle
const CHIP_KEY_SIZE := 13
const CHIP_GAP := 5.0  # px from a chip's key to its name
const OR_TEXT := "or"
const OR_SIZE := 15
const OR_GAP := 9.0  # px either side of "or"
const CHIP_BACK := 0.55  # alpha of the ink capsule behind the chips (they sat on Maw's purple pool unread)
const CHIP_PAD := 7.0  # px of it round them
const CHIP_REACH := 10.0  # px past the circle's right edge the chips may reach: the rest goes left, off the hero
const PAPER := Color(1.0, 0.96, 0.85)  # the fill with two endings: neither colour until he picks
const LABELS := {"light": "LMB", "heavy": "RMB"}  # (combo_guide.LABELS)

var player: Node
var center := Vector2.ZERO  # where it draws (follows the hero each frame)
var fixed := false  # true: stay at `center` (tests/breaker_prompt_preview.gd lays several out)

var _font: Font
var _name_font: Font
var _box := StyleBoxFlat.new()
var _shown := false
var _w: Dictionary = {}  # last breaker_window() while shown
var _out := -1.0  # real s since it ended (-1 = live)
var _out_kind := ""  # "hit" / "perfect" / "lock" / "miss"
var _out_chose := ""  # the button that picked the ending ("light" / "heavy"; "" on a miss)
var _group_l := 0.0  # px the chips under the circle reach left / right of its centre (last draw; _follow keeps
var _group_r := 0.0  # them on screen)
var _last_us := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_name_font = HUD_INK.font()
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
		_out_chose = w.get("chose", "")
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
	var lo := maxf(MARGIN, _group_l + 8.0)  # the chips under it stay on screen too
	var hi := screen.x - maxf(MARGIN, _group_r + 8.0)
	center = Vector2(clampf(at.x, lo, maxf(lo, hi)), clampf(at.y, MARGIN, screen.y - MARGIN))


func _draw() -> void:
	if not _shown or _w.is_empty():
		return
	var opts := options()
	var c := center
	var t: float = _w.t
	var fill := clampf(t / _w.sweet, 0.0, 1.0)
	var in_window: bool = t >= _w.open and t <= _w.close
	var a := 1.0
	var col: Color = _w.color if opts.size() < 2 else PAPER
	var scale := 1.0
	if _out >= 0.0:
		var k := _out / OUT_TIME
		a = 1.0 - k
		match _out_kind:
			"perfect":
				col = GOLD
				scale = 1.0 + 0.5 * k
			"hit":
				col = _chosen_color(opts, col)
				scale = 1.0 + 0.3 * k
			_:
				col = GREY
		fill = 1.0 if _out_kind in ["perfect", "hit"] else fill
	elif in_window:
		col = GOLD
	var r := RADIUS * scale
	# Back disc and empty track.
	draw_circle(c, r + WIDTH * 0.5 + 3.0, Color(HUD_INK.INK, BACK_ALPHA * a))
	HUD_INK.dot_ring(self, c, MOUSE_H * 0.6, r - WIDTH * 0.5 - 2.0, Color(col, DOTS_ALPHA * a))
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.14 * a), WIDTH, true)
	for edge: float in [-1.0, 1.0]:  # the track's ink lines
		draw_arc(c, r + edge * (WIDTH * 0.5 + HUD_INK.LINE * 0.5), 0.0, TAU, 48, Color(HUD_INK.INK, 0.9 * a), HUD_INK.LINE, true)
	# The window on the track: a thin gold band from `open` to full.
	var open_frac: float = clampf(_w.open / _w.sweet, 0.0, 1.0)
	draw_arc(c, r + WIDTH * 0.5 + 1.5, -PI * 0.5 + TAU * open_frac, PI * 1.5, 32, Color(GOLD, 0.55 * a), 2.0, true)
	# The fill, clockwise from the top.
	if fill > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * fill, 48, Color(col, 0.95 * a), WIDTH, true)
	# Full and still open: pulse (press now).
	var pulse := 0.0
	if in_window and fill >= 1.0 and _out < 0.0:
		pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 30.0)
		draw_arc(c, r + WIDTH + 2.0 + 3.0 * pulse, 0.0, TAU, 48, Color(GOLD, 0.7 * (1.0 - pulse)), 2.0, true)
	if _out >= 0.0 and _out_kind in ["perfect", "hit"]:
		draw_arc(c, r + WIDTH + 18.0 * (_out / OUT_TIME), 0.0, TAU, 48, Color(col, a), 2.0, true)
	_mouse(c, a, opts, GOLD if in_window and _out < 0.0 else Color(1, 1, 1, 0.85), pulse)
	_chips(c + Vector2(0.0, r + WIDTH * 0.5 + NAME_GAP), a, opts)


## The endings on offer, left button first: the window's `options` (hero_leap.options()), or, for a window with
## only `name` / `alt_name` (the tests' fakes), built from those.
func options() -> Array:
	if _w.has("options"):
		return _w.options
	var main := {"button": "heavy", "name": _w.get("name", ""), "color": _w.get("color", Color.WHITE)}
	if _w.get("alt_name", "") == "":
		return [main]
	return [{"button": "light", "name": _w.alt_name, "color": _w.get("alt_color", main.color)}, main]


## The colour of the ending the press picked (the circle flashes in it).
func _chosen_color(opts: Array, fallback: Color) -> Color:
	for o: Dictionary in opts:
		if o.button == _out_chose:
			return o.color
	return fallback


## How much of an option to draw: all of it while live; once it's over the chosen one stays and the other drops
## out fast; on a lockout or a miss both fade.
func _option_alpha(o: Dictionary, a: float) -> float:
	if _out < 0.0:
		return a
	if _out_kind in ["perfect", "hit"]:
		return a if o.button == _out_chose else a * a * 0.3
	return a * 0.6


func _option_color(o: Dictionary) -> Color:
	if _out >= 0.0 and not _out_kind in ["perfect", "hit"]:
		return GREY
	return o.color


## A little inked mouse in the middle of the circle: each button that does something is filled in its ending's
## colour (both with two endings, only the right with one); the other stays dark.
func _mouse(c: Vector2, a: float, opts: Array, rim: Color, pulse: float) -> void:
	var rect := Rect2(c - Vector2(MOUSE_W, MOUSE_H) * 0.5, Vector2(MOUSE_W, MOUSE_H))
	_box.bg_color = Color(0.1, 0.08, 0.14, 0.95 * a)
	_box.set_corner_radius_all(int(MOUSE_W * 0.5))
	_box.set_border_width_all(2)
	_box.border_color = Color(rim, a * rim.a)
	draw_style_box(_box, rect)
	var half := MOUSE_W * 0.5 - 2.0
	for o: Dictionary in opts:
		var left: bool = o.button == "light"
		var btn := Rect2(Vector2(c.x - half if left else c.x, rect.position.y + 2.0), Vector2(half, MOUSE_BTN - 2.0))
		var bc: Color = _option_color(o).lerp(Color.WHITE, 0.35 * pulse)
		_box.bg_color = Color(bc, _option_alpha(o, a))
		_box.set_border_width_all(0)
		_box.set_corner_radius_all(0)
		if left:
			_box.corner_radius_top_left = int(half)
		else:
			_box.corner_radius_top_right = int(half)
		draw_style_box(_box, btn)
	# The ink between the buttons and under them.
	var ink := Color(HUD_INK.INK, 0.95 * a)
	draw_line(Vector2(c.x, rect.position.y + 1.0), Vector2(c.x, rect.position.y + MOUSE_BTN), ink, HUD_INK.LINE + 0.5, true)
	draw_line(Vector2(rect.position.x + 2.0, rect.position.y + MOUSE_BTN), Vector2(rect.end.x - 2.0, rect.position.y + MOUSE_BTN), ink, HUD_INK.LINE, true)


## One chip per ending under the circle, in mouse order with "or" between: the button's key pill (rim in the
## ending's colour) and the ending's name in the words' font.
func _chips(at: Vector2, a: float, opts: Array) -> void:
	var widths: Array[float] = []
	var total := 0.0
	for o: Dictionary in opts:
		var w: float = _key_w(LABELS.get(o.button, "")) + CHIP_GAP + _name_font.get_string_size(o.name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
		widths.append(w)
		total += w
	var or_w := _name_font.get_string_size(OR_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, OR_SIZE).x
	total += (opts.size() - 1) * (or_w + OR_GAP * 2.0)
	# Centred under the circle, unless that reaches past CHIP_REACH right of it (toward the hero): then it ends there.
	var x := minf(at.x - total * 0.5, at.x + RADIUS + WIDTH * 0.5 + CHIP_REACH - total)
	_group_l = at.x - x + CHIP_PAD
	_group_r = x + total - at.x + CHIP_PAD
	var y := at.y + CHIP_KEY_H * 0.5
	_box.bg_color = Color(HUD_INK.INK, CHIP_BACK * a)
	_box.set_corner_radius_all(int(CHIP_KEY_H * 0.5 + CHIP_PAD))
	_box.set_border_width_all(0)
	draw_style_box(_box, Rect2(x - CHIP_PAD, at.y - CHIP_PAD * 0.6, total + CHIP_PAD * 2.0, CHIP_KEY_H + CHIP_PAD * 1.2))
	for i in opts.size():
		var o: Dictionary = opts[i]
		var oa := _option_alpha(o, a)
		var oc := _option_color(o)
		var label: String = LABELS.get(o.button, "")
		var kw := _key_w(label)
		_key(Vector2(x + kw * 0.5, y), label, oa, oc)
		_text(Vector2(x + kw + CHIP_GAP, y), o.name, NAME_SIZE, Color(oc.lerp(Color.WHITE, 0.3), oa))
		x += widths[i]
		if i < opts.size() - 1:
			_text(Vector2(x + OR_GAP, y), OR_TEXT, OR_SIZE, Color(1, 1, 1, 0.7 * a))
			x += or_w + OR_GAP * 2.0


func _key_w(label: String) -> float:
	return maxf(CHIP_KEY_H, _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_KEY_SIZE).x + CHIP_KEY_H * 0.6)


## A button's key pill (the combo guide's key style), its rim in the ending's colour.
func _key(c: Vector2, label: String, a: float, rim: Color) -> void:
	var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_KEY_SIZE).x
	var w := _key_w(label)
	var rect := Rect2(c - Vector2(w, CHIP_KEY_H) * 0.5, Vector2(w, CHIP_KEY_H))
	_box.bg_color = Color(0.1, 0.08, 0.14, 0.95 * a)
	_box.set_corner_radius_all(int(CHIP_KEY_H * 0.5))
	_box.set_border_width_all(2)
	_box.border_color = Color(rim, a)
	draw_style_box(_box, rect)
	draw_string(_font, Vector2(c.x - tw * 0.5, c.y + CHIP_KEY_SIZE * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_KEY_SIZE,
		Color(1, 1, 1, a))


## Words-font text with its left edge at `at.x`, centred on `at.y`, in a thin ink outline so it reads over the floor.
func _text(at: Vector2, label: String, size: int, col: Color) -> void:
	var pos := Vector2(at.x, at.y + size * 0.36)
	draw_string_outline(_name_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, HUD_INK.outline(size), Color(HUD_INK.INK, 0.8 * col.a))
	draw_string(_name_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
