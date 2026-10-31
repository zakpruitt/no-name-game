extends CanvasLayer
## Between-room reward: pause the game and pick 1 of 3 upgrade cards.
## Mouse, keys 1-3, or arrows/D-pad + confirm. A Reroll button [R] (when
## main passes a cost) asks main for new cards via `reroll_pressed`.

signal picked(id: String)
signal reroll_pressed

var _choices: Array = []
var _reroll_cost := -1  # -1 = no reroll offered
var _reroll_button: Button
var _buttons: Array[Button] = []
var _root: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open(choices: Array, reroll_cost := -1) -> void:
	_choices = choices
	_reroll_cost = reroll_cost
	if _root:
		_root.queue_free()
	_build()
	visible = true
	get_tree().paused = true
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func pick(index: int) -> void:
	if not visible or index < 0 or index >= _choices.size():
		return
	visible = false
	get_tree().paused = false
	var id: String = _choices[index].id  # a new upgrade or a level-up
	_root.queue_free()
	_root = null
	picked.emit(id)


func can_reroll() -> bool:
	return visible and _reroll_cost >= 0 and Game.bones >= _reroll_cost


func reroll() -> void:
	if can_reroll():
		reroll_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.physical_keycode - KEY_1
		if n >= 0 and n < _choices.size():
			pick(n)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R:
			reroll()
			get_viewport().set_input_as_handled()


func _build() -> void:
	_buttons.clear()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 28)
	_root.add_child(col)

	var title := Label.new()
	title.text = "CHOOSE A POWER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	var player := get_tree().get_first_node_in_group("player")
	for i in _choices.size():
		var u: Dictionary = _choices[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 220)
		var level: int = u.get("level", 1)
		var head := "%s%s" % [u.name, Upgrades.level_tag(level)]
		if level > 1:
			head += "\nLEVEL UP"
		var tags := Upgrades.tags(u.id)
		# Numbers as they'd be once taken, counting any synergy it completes.
		var owned: Dictionary = player.upgrades if player != null else {}
		var after := owned.duplicate()
		after[u.id] = level
		var desc := Upgrades.describe(u, level, Upgrades.active_synergies(after))
		for tag: String in Upgrades.would_activate(owned, u.id):
			desc += "\nCompletes %s synergy!" % Upgrades.SYNERGIES[tag].name
		b.text = "%d   [%s]%s\n\n%s\n\n%s" % [i + 1, u.slot, ("  ·  " + tags) if tags != "" else "", head, desc]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_stylebox_override("normal", _card_style(Color(0.12, 0.1, 0.18), Color(0.4, 0.35, 0.55)))
		b.add_theme_stylebox_override("hover", _card_style(Color(0.2, 0.15, 0.28), Color(1.0, 0.7, 0.3)))
		b.add_theme_stylebox_override("focus", _card_style(Color(0.2, 0.15, 0.28), Color(1.0, 0.7, 0.3)))
		b.add_theme_stylebox_override("pressed", _card_style(Color(0.3, 0.2, 0.1), Color(1.0, 0.8, 0.4)))
		b.pressed.connect(pick.bind(i))
		row.add_child(b)
		_buttons.append(b)

	if _reroll_cost >= 0:
		_reroll_button = Button.new()
		_reroll_button.text = "Reroll [R]   %d bones   (have %d)" % [_reroll_cost, Game.bones]
		_reroll_button.custom_minimum_size = Vector2(420, 52)
		_reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_reroll_button.add_theme_font_size_override("font_size", 20)
		_reroll_button.add_theme_stylebox_override("normal", _card_style(Color(0.1, 0.08, 0.14), Color(0.35, 0.3, 0.45)))
		_reroll_button.add_theme_stylebox_override("hover", _card_style(Color(0.2, 0.15, 0.28), Color(1.0, 0.7, 0.3)))
		_reroll_button.add_theme_stylebox_override("focus", _card_style(Color(0.2, 0.15, 0.28), Color(1.0, 0.7, 0.3)))
		_reroll_button.add_theme_stylebox_override("pressed", _card_style(Color(0.3, 0.2, 0.1), Color(1.0, 0.8, 0.4)))
		_reroll_button.add_theme_stylebox_override("disabled", _card_style(Color(0.08, 0.07, 0.1), Color(0.25, 0.22, 0.3)))
		_reroll_button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
		_reroll_button.disabled = not can_reroll()
		_reroll_button.pressed.connect(reroll)
		col.add_child(_reroll_button)

	# Center the column once its size is known.
	await get_tree().process_frame
	col.position = (_root.size - col.size) * 0.5


func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(18)
	return s
