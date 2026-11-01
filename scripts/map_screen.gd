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
const AHEAD := Color(1, 1, 1, 0.34)  # links on the routes the focused room leads to
const OFF_ROUTE := 0.32  # alpha of rooms the focused room can't reach
const MOVE_TIME := 0.35  # the marker's walk to the picked room (s)
const LOW_HP := 0.4  # below this share of max HP the status line turns red
## Legend order along the bottom.
const LEGEND := ["fight", "elite", "rest", "shrine", "vault", "trial", "mystery", "boss"]
const LEGEND_VAULT := Color(0.95, 0.78, 0.4)  # vaults wear their path's colour on the map

var _map: Array = []
var _visited: Array = []  # Vector2i (column, lane) of every room so far
var _choices: Array = []  # nodes the player may pick
var _counts := {}  # Upgrades.path_counts() of the build, for the vault line
var _owned := {}  # the hero's powers (id -> level), for the trial's payout line
var _room := 0  # room number of the choices
var _read_only := false
var _intro := false  # the run's first look (open_intro): closing it starts room 1
var _focus := 0
var _hover := Vector2i(-1, -1)  # any room under the mouse, for its detail
var _reach := {}  # Vector2i -> true: rooms the focused room (or the hero) can still reach
var _move_t := -1.0  # >= 0 while the marker walks to the picked room
var _move_to := -1
## Hidden while the map is open (main sets it to the HUD).
var cover: CanvasLayer
var _cover_was := false
var _t := 0.0
var _icons := {}
var _root: Control
var _board: Control
var _title: Label
var _status: Label  # HP, bones, level (the HUD is hidden under the map)
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
	_intro = false
	_counts = counts
	_room = visited[-1].x + 2 if not visited.is_empty() else 1
	_focus = 0
	_hover = Vector2i(-1, -1)
	_move_t = -1.0
	_t = 0.0
	if cover:
		_cover_was = cover.visible
		cover.visible = false
	_title.text = "THE RUN" if read_only else "CHOOSE YOUR PATH"
	visible = true
	get_tree().paused = true
	_update_detail()
	_board.queue_redraw()


## The hero's powers, so a trial says what meeting it would pay right now.
func set_build(owned: Dictionary) -> void:
	_owned = owned
	_update_detail()


## What a met trial pays with the current build: the fusions it could offer,
## else a fusion level-up, else a level-up (main._finish_trial's order).
func trial_payout() -> String:
	var ready: Array = []
	var ups := false
	for u: Dictionary in Upgrades.ALL:
		if not u.has("fusion"):
			continue
		var level: int = _owned.get(u.id, 0)
		if level == 0 and Upgrades.can_fuse(_owned, u):
			ready.append(u.name)
		elif level > 0 and level < Upgrades.MAX_LEVEL:
			ups = true
	if not ready.is_empty():
		return "Fusion ready: " + ", ".join(ready.slice(0, 3)) + (" +%d more" % (ready.size() - 3) if ready.size() > 3 else "")
	if ups:
		return "No new fusion ready: pays a fusion level-up"
	return "No fusion ready yet (own powers of two paths): pays a level-up"


## What a vault of `path` has left for the build ("3 new, 2 to level up"),
## counted the way Upgrades.roll(..., path) builds its pool; under 3 cards it
## tops up from other paths.
func vault_pool(path: String) -> String:
	var fresh := 0
	var ups := 0
	for u: Dictionary in Upgrades.ALL:
		if path not in Upgrades.paths_of(u):
			continue
		var level: int = _owned.get(u.id, 0)
		if level == 0 and (not u.has("fusion") or Upgrades.can_fuse(_owned, u)):
			fresh += 1
		elif level > 0 and level < Upgrades.MAX_LEVEL:
			ups += 1
	var text := "%d new, %d to level up" % [fresh, ups]
	if fresh + ups < 3:
		text += ": the rest from other paths"
	return text


## The hero's state while choosing: "HP 64 / 110   ·   23 bones   ·   Lv 3".
## Under LOW_HP the line turns red, since that's when a rest matters.
func set_status(hp: float, max_hp: float, bones: int, level: int) -> void:
	_status.text = "HP %d / %d   ·   %d bones   ·   Lv %d" % [ceili(hp), roundi(max_hp), bones, level]
	_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if hp < max_hp * LOW_HP else Color(0.92, 0.9, 0.96))


## The whole run at its start, read-only; Enter (or Esc) begins room 1.
func open_intro(map: Array, visited: Array) -> void:
	open(map, visited, [], true)
	_intro = true
	_title.text = "YOUR RUN"
	_update_detail()


func is_open() -> bool:
	return visible


## Choose `_choices[index]`: the marker walks there, then `chosen` fires.
func pick(index: int) -> void:
	if not visible or _read_only or _move_t >= 0.0 or index < 0 or index >= _choices.size():
		return
	_set_focus(index)
	_move_to = index
	_move_t = 0.0


func _close() -> void:
	visible = false
	if cover:
		cover.visible = _cover_was
	if not _read_only or _intro:
		get_tree().paused = false
	closed.emit()


## Screen position of the node at column `col`, lane `lane`.
func node_pos(col: int, lane: int) -> Vector2:
	var t := float(col) / maxf(_map.size() - 1, 1)
	return Vector2(lerpf(X0, X1, t), Y_MID + (lane - 1) * LANE_GAP)


func _process(delta: float) -> void:
	if visible:
		_t += delta
		if _move_t >= 0.0:
			_move_t += delta
			if _move_t >= MOVE_TIME:
				_move_t = -1.0
				_close()
				chosen.emit(_move_to)
				return
		_board.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	if _move_t >= 0.0:
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_set_hover(_node_under(event.position))
	if _read_only:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			_close()
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			move_cursor(1 if event.is_action_pressed("ui_right") else -1, 0)
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
			move_cursor(0, 1 if event.is_action_pressed("ui_down") else -1)
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
		handled = false
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _node_under(event.position)
		pick(_choice_index(at.x, at.y))
	else:
		handled = event is InputEventKey or event is InputEventMouseButton
	if handled:
		get_viewport().set_input_as_handled()


## (column, lane) of the room under `screen_pos` (viewport coordinates),
## or (-1, -1).
func _node_under(screen_pos: Vector2) -> Vector2i:
	var at := _board.get_global_transform_with_canvas().affine_inverse() * screen_pos
	for c in _map.size():
		for n: Dictionary in _map[c]:
			if at.distance_to(node_pos(c, n.lane)) <= (R_BOSS if n.kind == "boss" else R) + 10.0:
				return Vector2i(c, n.lane)
	return Vector2i(-1, -1)


## Read-only map: arrows walk a cursor over the rooms (columns left/right,
## lanes up/down), starting from where the hero stands.
func move_cursor(dc: int, dl: int) -> void:
	var at: Vector2i = _hover if _hover.x >= 0 else (_visited[-1] if not _visited.is_empty() else Vector2i(0, 1))
	var c := clampi(at.x + dc, 0, _map.size() - 1)
	var lanes: Array = _map[c].map(func(n: Dictionary) -> int: return n.lane)
	var lane: int = at.y
	if dl != 0:
		var i := lanes.find(lane)
		lane = lanes[clampi((i if i >= 0 else 0) + dl, 0, lanes.size() - 1)]
	elif lane not in lanes:
		lane = lanes.reduce(func(best: int, l: int) -> int: return l if absi(l - at.y) < absi(best - at.y) else best)
	_set_hover(Vector2i(c, lane))


## Hover a room: a choice takes the focus; any other room shows its detail.
func _set_hover(at: Vector2i) -> void:
	if at == _hover:
		return
	_hover = at
	var i := _choice_index(at.x, at.y)
	if i >= 0:
		_set_focus(i)
	else:
		_update_detail()


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
	if _choice_index(_hover.x, _hover.y) != _focus:
		_hover = Vector2i(-1, -1)
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
	_status = _label(_root, "", 20, Color(0.92, 0.9, 0.96))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.position = Vector2(40, 30)
	_status.size = Vector2(420, 30)

	_detail = PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.05, 0.1, 0.92)
	s.border_color = Color(0.4, 0.35, 0.55)
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(14)
	_detail.add_theme_stylebox_override("panel", s)
	_detail.position = Vector2(400, 655)
	_detail.custom_minimum_size = Vector2(800, 0)
	_root.add_child(_detail)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_detail.add_child(col)
	_detail_title = _label(col, "", 28, Color.WHITE)
	_detail_text = _label(col, "", 20, Color(0.88, 0.86, 0.94))
	_detail_hint = _label(col, "", 15, Color(1, 1, 1, 0.45))


func _update_detail() -> void:
	var here: Vector2i = _visited[-1] if not _visited.is_empty() else Vector2i(-1, -1)
	var hovered := {} if _choice_index(_hover.x, _hover.y) >= 0 else RunMap.node_at(_map, _hover)
	var from := here
	if not hovered.is_empty():
		from = _hover
	elif not _read_only and not _choices.is_empty():
		from = Vector2i(_room - 1, _choices[_focus].lane)
	_reach = _reach_from(from)
	if not hovered.is_empty():
		_show_room(hovered, _hover.x + 1)
		var where := "you were here" if _hover in _visited else (
			"on your way" if _reach_from(here).has(_hover) else "out of reach now")
		_detail_hint.text = "Room %d  ·  %s" % [_hover.x + 1, where]
		return
	if _read_only or _choices.is_empty():
		var at := RunMap.node_at(_map, here)
		_detail_title.text = "Room %d of %d%s" % [_room - 1, _map.size(),
			("  ·  " + RunMap.title(at)) if not at.is_empty() else ""]
		_detail_title.add_theme_color_override("font_color", Color.WHITE)
		var ahead := _ahead_text(here)
		_detail_text.text = "Ahead: " + ahead if ahead != "" else "Only the Bone Warden remains."
		_detail_hint.text = ("[Enter] begin" if _intro else "[Esc] back") + "   ·   hover a room or use the arrows for its detail"
		return
	_show_room(_choices[_focus], _room)
	var keys := ", ".join(range(_choices.size()).map(func(i: int) -> String: return "[%d]" % (i + 1)))
	_detail_hint.text = "%s or click   ·   arrows + Enter" % keys


## Title and text of room `n` (room number `room`), with what it leads to.
func _show_room(n: Dictionary, room: int) -> void:
	_detail_title.text = RunMap.title(n)
	_detail_title.add_theme_color_override("font_color", RunMap.color(n).lightened(0.15))
	var text := RunMap.describe(n, room)
	if n.kind == "vault" and _counts.has(n.path):
		var have: int = _counts[n.path]
		text += "\nYou have %d %s power%s  %s" % [have, Upgrades.PATHS[n.path].name, "" if have == 1 else "s",
			PowerIcon.mastery_pips(have) + " mastery"]
	if n.kind == "vault":
		text += "\nIn the vault: " + vault_pool(n.path)
	if n.kind == "trial":
		text += "\n" + trial_payout()
	var ahead := _ahead_text(Vector2i(room - 1, n.lane))
	if ahead != "":
		text += "\nLeads on to: " + ahead
	_detail_text.text = text


## Rooms reachable from `at` (inclusive), as a set of Vector2i.
func _reach_from(at: Vector2i) -> Dictionary:
	var reach := {at: true}
	for c in range(maxi(at.x, 0), _map.size() - 1):
		for n: Dictionary in _map[c]:
			if reach.has(Vector2i(c, n.lane)):
				for lane: int in n.next:
					reach[Vector2i(c + 1, lane)] = true
	return reach


## The rooms past `at` that `_reach` holds, fights and the boss left out:
## "2 elites  ·  Light vault  ·  1 rest".
func _ahead_text(at: Vector2i) -> String:
	var count := {}
	var vaults: Array = []
	for c in range(at.x + 1, _map.size() - 1):
		for n: Dictionary in _map[c]:
			if not _reach.has(Vector2i(c, n.lane)):
				continue
			if n.kind == "vault":
				var name: String = Upgrades.PATHS[n.path].name + " vault"
				if name not in vaults:
					vaults.append(name)
			else:
				count[n.kind] = count.get(n.kind, 0) + 1
	var parts: Array = []
	for kind: String in LEGEND:
		if kind == "vault":
			parts.append_array(vaults)
		elif kind not in ["fight", "boss"] and count.has(kind):
			parts.append("%d %s%s" % [count[kind], RunMap.KINDS[kind].name.to_lower(), "s" if count[kind] > 1 else ""])
	return "  ·  ".join(parts)


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
				elif _reach.has(from) and _reach.has(to) and from.x > here.x:
					col = AHEAD
					width = 3.0
				_board.draw_line(a + dir * (R + 4), b - dir * (R + 4), Color(col, col.a * fade), width, true)
	# Rooms.
	for c in _map.size():
		for n: Dictionary in _map[c]:
			_draw_node(c, n, here, pulse, fade)
	# Where the hero stands, walking to the picked room after a pick.
	if here.x >= 0:
		var p := node_pos(here.x, here.y)
		if _move_t >= 0.0:
			var to := node_pos(_room - 1, _choices[_move_to].lane)
			var dir := (to - p).normalized()
			var walked := p.lerp(to, ease(_move_t / MOVE_TIME, -2.0))
			_board.draw_line(p + dir * (R + 4), walked, Color(1.0, 0.8, 0.35, 0.9), 5.0, true)
			p = walked
		var m := p + Vector2(0, -R - 14)
		_board.draw_colored_polygon(PackedVector2Array([m + Vector2(-9, -12), m + Vector2(9, -12), m]),
			Color(1.0, 0.8, 0.35, fade))
	_draw_legend(fade)


## Room kinds along the bottom: icon and name.
func _draw_legend(fade: float) -> void:
	var font := ThemeDB.fallback_font
	var widths: Array = LEGEND.map(func(k: String) -> float:
		return 30.0 + font.get_string_size(RunMap.KINDS[k].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var gap := 28.0
	var total: float = widths.reduce(func(a: float, b: float) -> float: return a + b, 0.0)
	var x := 800.0 - (total + gap * (LEGEND.size() - 1)) * 0.5
	for i in LEGEND.size():
		var kind: String = LEGEND[i]
		var color: Color = LEGEND_VAULT if kind == "vault" else RunMap.KINDS[kind].color
		var c := Vector2(x + 11, 868)
		_board.draw_circle(c, 13, Color(BACK, fade))
		_board.draw_arc(c, 13, 0.0, TAU, 24, Color(color, 0.8 * fade), 2.0, true)
		var tex: Texture2D = _icons.get(kind)
		if tex:
			_board.draw_texture_rect(tex, Rect2(c - Vector2(8, 8), Vector2(16, 16)), false, Color(color, fade))
		_board.draw_string(font, Vector2(x + 30, 874), RunMap.KINDS[kind].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(1, 1, 1, 0.6 * fade))
		x += widths[i] + gap


func _draw_node(c: int, n: Dictionary, here: Vector2i, pulse: float, fade: float) -> void:
	var at := Vector2i(c, n.lane)
	var p := node_pos(c, n.lane)
	var r := R_BOSS if n.kind == "boss" else R
	var color := RunMap.color(n)
	var choice := _choice_index(c, n.lane)
	var visited := at in _visited
	var passed := c <= here.x and not visited  # a room left behind
	var off := c > here.x and choice < 0 and not _reach.has(at)  # the focused room can't reach it
	var a := (0.3 if passed else (OFF_ROUTE if off else 1.0)) * fade
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
	if at == here:
		_board.draw_arc(p, r + 6, 0.0, TAU, 48, Color(1.0, 0.8, 0.35, 0.9 * fade), 3.0, true)
	elif at == _hover:
		_board.draw_arc(p, r + 6, 0.0, TAU, 48, Color(1, 1, 1, 0.7 * fade), 2.0, true)
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
