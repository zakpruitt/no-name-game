extends CanvasLayer
## Shared base for full-screen menus (title, pause): a dimmed backdrop, a
## big title, a column of buttons, and an optional footer line. Pauses the
## game while open. Mouse, keyboard arrows + Enter, or gamepad all work.

var _root: Control
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func is_open() -> bool:
	return visible


## `items` is an Array of [text, Callable] pairs, top to bottom.
func show_menu(title: String, subtitle: String, items: Array, footer := "", dim := 0.7) -> void:
	close_menu()
	_build(title, subtitle, items, footer, dim)
	visible = true
	get_tree().paused = true
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func close_menu(unpause := true) -> void:
	if _root:
		_root.queue_free()
		_root = null
	_buttons.clear()
	visible = false
	if unpause:
		get_tree().paused = false


func _build(title: String, subtitle: String, items: Array, footer: String, dim: float) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	_root.add_child(col)

	_label(col, title, 96 if subtitle != "" else 64, Color(1.0, 0.7, 0.25))
	if subtitle != "":
		_label(col, subtitle, 24, Color(0.85, 0.8, 0.95))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	col.add_child(gap)

	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(340, 58)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_stylebox_override("normal", _style(Color(0.12, 0.1, 0.18), Color(0.4, 0.35, 0.55)))
		b.add_theme_stylebox_override("hover", _style(Color(0.2, 0.15, 0.28), Color(1.0, 0.7, 0.3)))
		b.add_theme_stylebox_override("focus", _style(Color(0.2, 0.15, 0.28), Color(1.0, 0.7, 0.3)))
		b.add_theme_stylebox_override("pressed", _style(Color(0.3, 0.2, 0.1), Color(1.0, 0.8, 0.4)))
		b.pressed.connect(item[1])
		col.add_child(b)
		_buttons.append(b)

	if footer != "":
		var gap2 := Control.new()
		gap2.custom_minimum_size = Vector2(0, 16)
		col.add_child(gap2)
		_label(col, footer, 18, Color(1, 1, 1, 0.55))

	# Center the column once its size is known.
	await get_tree().process_frame
	if is_instance_valid(col):
		col.position = (_root.size - col.size) * 0.5


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	parent.add_child(l)
	return l


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(12)
	return s
