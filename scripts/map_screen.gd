extends CanvasLayer
## The run map (RunMap): every room of the run left to right, the route so
## far, and the rooms reachable next. Between rooms the player picks one
## (mouse, keys 1-3, or arrows + Enter); from the pause menu it opens
## read-only (Esc / Enter closes it). Drawn in code on one Control.

signal chosen(index: int)  # into the `choices` passed to open()
signal closed

const X0 := 150.0  # first and last column centres (px, 1600x900 space)
const X1 := 1450.0
const Y_MID := 400.0
const LANE_GAP := 160.0
const R := 34.0  # node radius
const R_BOSS := 46.0
const BACK := Color(0.07, 0.05, 0.11, 0.95)
const FAINT := Color(1, 1, 1, 0.13)
const TRAVELLED := Color(1, 1, 1, 0.85)

var _map: Array = []
var _visited: Array = []  # Vector2i (column, lane) of every room so far
var _choices: Array = []  # nodes the player may pick
var _counts := {}  # Upgrades.path_counts() of the build, for the vault line
var _room := 0  # room number of the choices
var _read_only := false
var _focus := 0
var _t := 0.0
var _icons := {}
var _root: Control
var _board: Control
var _title: Label
var _detail_title: Label
var _detail_text: Label
var _detail_hint: Label
var _detail: PanelContainer


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for kind: String in RunMap.KINDS:
		_icons[kind] = load("res://assets/icons/rooms/%s.svg" % kind)
	_build()


## Show the map. `visited`: the route so far (last = where the hero is);
## `choices`: nodes to pick from (empty with `read_only`). `counts` (path ->
## owned powers) adds mastery progress to a vault's line.
func open(map: Array, visited: Array, choices: Array, read_only := false, counts := {}) -> void:
	_map = map
	_visited = visited
	_choices = choices
	_read_only = read_only
	_counts = counts
	_room = visited[-1].x + 2 if not visited.is_empty() else 1
	_focus = 0
	_t = 0.0
	_title.text = "THE RUN" if read_only else "CHOOSE YOUR PATH"
	visible = true
	get_tree().paused = true
	_update_detail()
	_board.queue_redraw()


func is_open() -> bool:
	return visible


func pick(index: int) -> void:
	if not visible or _read_only or index < 0 or index >= _choices.size():
		return
	_close()
	chosen.emit(index)


func _close() -> void:
	visible = false
	if not _read_only:
		get_tree().paused = false
	closed.emit()


## Screen position of the node at column `col`, lane `lane`.
func node_pos(col: int, lane: int) -> Vector2:
	var t := float(col) / maxf(_map.size() - 1, 1)
	return Vector2(lerpf(X0, X1, t), Y_MID + (lane - 1) * LANE_GAP)


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_board.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	if _read_only:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			_close()
		elif not (event is InputEventMouseMotion):
			handled = event is InputEventKey or event is InputEventMouseButton
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode >= KEY_1 \
			and event.physical_keycode < KEY_1 + _choices.size():
		pick(event.physical_keycode - KEY_1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_set_focus(_focus - 1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_set_focus(_focus + 1)
	elif event.is_action_pressed("ui_accept"):
		pick(_focus)
	elif event is InputEventMouseMotion:
		var i := _choice_at(event.position)
		if i >= 0:
			_set_focus(i)
		handled = false
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pick(_choice_at(event.position))
	else:
		handled = event is InputEventKey or event is InputEventMouseButton
	if handled:
		get_viewport().set_input_as_handled()


## Index of the choice under `screen_pos` (viewport coordinates), or -1.
func _choice_at(screen_pos: Vector2) -> int:
	var at := _board.get_global_transform_with_canvas().affine_inverse() * screen_pos
	for i in _choices.size():
		var n: Dictionary = _choices[i]
		if at.distance_to(node_pos(_room - 1, n.lane)) <= R + 10.0:
			return i
	return -1


## Index into `_choices` of the node at column `c`, lane `lane`, or -1.
## (By position: nodes are dictionaries, and equal ones exist in other
## columns, so Array.find would match the wrong one.)
func _choice_index(c: int, lane: int) -> int:
	if _read_only or c != _room - 1:
		return -1
	for i in _choices.size():
		if _choices[i].lane == lane:
			return i
	return -1


func _set_focus(i: int) -> void:
	if _choices.is_empty():
		return
	_focus = wrapi(i, 0, _choices.size())
	_update_detail()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_board = Control.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_draw_map)
	_root.add_child(_board)

	_title = _label(_root, "", 44, Color(1.0, 0.75, 0.3))
	_title.position = Vector2(500, 40)
	_title.size = Vector2(600, 60)

	_detail = PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.05, 0.1, 0.92)
	s.border_color = Color(0.4, 0.35, 0.55)
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(14)
	_detail.add_theme_stylebox_override("panel", s)
	_detail.position = Vector2(400, 700)
	_detail.custom_minimum_size = Vector2(800, 0)
	_root.add_child(_detail)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_detail.add_child(col)
	_detail_title = _label(col, "", 28, Color.WHITE)
	_detail_text = _label(col, "", 20, Color(0.88, 0.86, 0.94))
	_detail_hint = _label(col, "", 15, Color(1, 1, 1, 0.45))


func _update_detail() -> void:
	if _read_only or _choices.is_empty():
		var here := RunMap.node_at(_map, _visited[-1]) if not _visited.is_empty() else {}
		_detail_title.text = "Room %d of %d%s" % [_room - 1, _map.size(),
			("  ·  " + RunMap.title(here)) if not here.is_empty() else ""]
		_detail_title.add_theme_color_override("font_color", Color.WHITE)
		_detail_text.text = "The route so far is lit; plan the rooms ahead."
		_detail_hint.text = "[Esc] back"
		return
	var n: Dictionary = _choices[_focus]
	_detail_title.text = RunMap.title(n)
	_detail_title.add_theme_color_override("font_color", RunMap.color(n).lightened(0.15))
	var text := RunMap.describe(n, _room)
	if n.kind == "vault" and _counts.has(n.path):
		var have: int = _counts[n.path]
		text += "\nYou have %d %s power%s  %s" % [have, Upgrades.PATHS[n.path].name, "" if have == 1 else "s",
			PowerIcon.mastery_pips(have) + " mastery"]
	_detail_text.text = text
	var keys := ", ".join(range(_choices.size()).map(func(i: int) -> String: return "[%d]" % (i + 1)))
	_detail_hint.text = "%s or click   ·   arrows + Enter" % keys


func _draw_map() -> void:
	if _map.is_empty():
		return
	var fade := clampf(_t / 0.18, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var here: Vector2i = _visited[-1] if not _visited.is_empty() else Vector2i(-1, -1)
	var font := ThemeDB.fallback_font
	# Column numbers along the top.
	for c in _map.size():
		var label := "BOSS" if c == _map.size() - 1 else str(c + 1)
		var p := node_pos(c, 0) + Vector2(0, -R - 50)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var lit := c + 1 == _room and not _read_only
		_board.draw_string(font, p - Vector2(w * 0.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(1, 1, 1, (0.9 if lit else 0.4) * fade))
	# Links: the route travelled, the links to the choices, the rest faint.
	for c in _map.size() - 1:
		for n: Dictionary in _map[c]:
			for lane: int in n.next:
				var a := node_pos(c, n.lane)
				var b := node_pos(c + 1, lane)
				var dir := (b - a).normalized()
				var col := FAINT
				var width := 2.0
				var from := Vector2i(c, n.lane)
				var to := Vector2i(c + 1, lane)
				var vi := _visited.find(from)
				if vi >= 0 and vi + 1 < _visited.size() and _visited[vi + 1] == to:
					col = TRAVELLED
					width = 5.0
				elif from == here and not _read_only:
					var target := RunMap.node_at(_map, to)
					var focused: bool = _choice_index(c + 1, lane) == _focus
					col = Color(RunMap.color(target), 0.45 + 0.45 * pulse if focused else 0.5)
					width = 5.0 if focused else 3.5
				_board.draw_line(a + dir * (R + 4), b - dir * (R + 4), Color(col, col.a * fade), width, true)
	# Rooms.
	for c in _map.size():
		for n: Dictionary in _map[c]:
			_draw_node(c, n, here, pulse, fade)


func _draw_node(c: int, n: Dictionary, here: Vector2i, pulse: float, fade: float) -> void:
	var at := Vector2i(c, n.lane)
	var p := node_pos(c, n.lane)
	var r := R_BOSS if n.kind == "boss" else R
	var color := RunMap.color(n)
	var choice := _choice_index(c, n.lane)
	var visited := at in _visited
	var passed := c <= here.x and not visited  # a room left behind
	var a := (0.3 if passed else 1.0) * fade
	if choice >= 0 and choice == _focus:
		for i in 4:
			_board.draw_circle(p, r + 6 + i * 5 * (0.6 + 0.4 * pulse), Color(color, 0.07 * fade))
		r *= 1.0 + 0.06 * pulse
	_board.draw_circle(p, r, Color(BACK, BACK.a * a))
	_board.draw_circle(p, r * 0.86, Color(color.darkened(0.75 if not visited else 0.45), 0.7 * a))
	_board.draw_arc(p, r, 0.0, TAU, 48, Color(color, a), 4.0 if choice >= 0 or visited else 3.0, true)
	var tex: Texture2D = _icons.get(n.kind)
	if tex:
		var g := Vector2.ONE * r * 1.15
		_board.draw_texture_rect(tex, Rect2(p - g * 0.5, g), false, Color(color.lerp(Color.WHITE, 0.2), a))
	# Twist pips under an elite.
	for i in n.twists.size():
		var tp := p + Vector2((i - (n.twists.size() - 1) * 0.5) * 12.0, r + 9.0)
		_board.draw_circle(tp, 4.5, Color(BACK, a))
		_board.draw_circle(tp, 3.0, Color(RunMap.KINDS.elite.color, a))
	# Where the hero stands: a marker above the node.
	if at == here:
		var m := p + Vector2(0, -r - 14)
		_board.draw_colored_polygon(PackedVector2Array([m + Vector2(-9, -12), m + Vector2(9, -12), m]),
			Color(1.0, 0.8, 0.35, fade))
		_board.draw_arc(p, r + 6, 0.0, TAU, 48, Color(1.0, 0.8, 0.35, 0.9 * fade), 3.0, true)
	# Key number on each choice.
	if choice >= 0:
		var k := p + Vector2(r * 0.75, -r * 0.75)
		_board.draw_circle(k, 12, Color(color, fade))
		var font := ThemeDB.fallback_font
		var label := str(choice + 1)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_board.draw_string(font, k + Vector2(-w * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(0.06, 0.04, 0.1, fade))


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
