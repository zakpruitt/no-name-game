extends CanvasLayer
## Between-room reward: pause the game and pick 1 of 3 upgrade cards.
## Mouse, keys 1-3, or arrows/D-pad + confirm. A Reroll button [R] (when
## main passes a cost) asks main for new cards via `reroll_pressed`.
## Each card wears its path's colour (Upgrades.PATHS); a fusion's is split.

signal picked(id: String)
signal reroll_pressed

const SYNERGY_COLOR := Color(0.45, 1.0, 0.85)
const CARD_BG := Color(0.07, 0.05, 0.11)

var _choices: Array = []
var _reroll_cost := -1  # -1 = no reroll offered
var _title_text := "CHOOSE A POWER"
var _reroll_button: Button
var _buttons: Array[Button] = []
var _root: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## `title` replaces "CHOOSE A POWER" (a vault, a trial's reward).
func open(choices: Array, reroll_cost := -1, title := "") -> void:
	_choices = choices
	_reroll_cost = reroll_cost
	_title_text = title if title != "" else "CHOOSE A POWER"
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
	dim.color = Color(0.02, 0.01, 0.05, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 24)
	_root.add_child(col)

	var title := Label.new()
	title.text = _title_text
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
	var owned: Dictionary = player.upgrades if player != null else {}
	for i in _choices.size():
		var b := _card(i, _choices[i], owned)
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

	# Center the column once its size is known, then deal the cards in.
	await get_tree().process_frame
	col.position = (_root.size - col.size) * 0.5
	for i in _buttons.size():
		var b := _buttons[i]
		b.pivot_offset = b.size * 0.5
		b.modulate.a = 0.0
		b.scale = Vector2.ONE * 0.92
		var tw := b.create_tween().set_parallel()
		tw.tween_property(b, "modulate:a", 1.0, 0.16).set_delay(i * 0.06)
		tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_delay(i * 0.06) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## One power card: path band and keys, icon, name, level, the text with its
## numbers in the path colour, then what taking it adds up to.
func _card(i: int, u: Dictionary, owned: Dictionary) -> Button:
	var level: int = u.get("level", 1)
	var paths := Upgrades.paths_of(u)
	var color := Upgrades.color(u)
	var b := Button.new()
	b.custom_minimum_size = Vector2(330, 470)
	b.add_theme_stylebox_override("normal", _card_style(CARD_BG.lerp(color, 0.08), color.darkened(0.35), 2, 0))
	for look: String in ["hover", "focus"]:
		b.add_theme_stylebox_override(look, _card_style(CARD_BG.lerp(color, 0.18), color, 4, 0))
	b.add_theme_stylebox_override("pressed", _card_style(CARD_BG.lerp(color, 0.3), color.lightened(0.3), 4, 0))
	b.pressed.connect(pick.bind(i))

	var box := _vbox(b, 0)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Colour band across the top: one colour, or split for a fusion.
	var band := HBoxContainer.new()
	band.add_theme_constant_override("separation", 0)
	band.custom_minimum_size = Vector2(0, 10)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(band)
	for path: String in paths:
		var strip := ColorRect.new()
		strip.color = Upgrades.PATHS[path].color
		strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(strip)

	var pad := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pad)
	var inner := _vbox(pad, 8)

	# Keys and path on the left, the move it hooks on the right.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(head)
	for path: String in paths:
		head.add_child(PowerIcon.chip(path))
	var kind := _text(head, "FUSION" if paths.size() > 1 else Upgrades.PATHS[u.path].name.to_upper(), 15,
		Color(1, 1, 1, 0.8) if paths.size() > 1 else color)
	kind.autowrap_mode = TextServer.AUTOWRAP_OFF
	var slot := _text(head, Upgrades.slot_name(u), 15, Color(1, 1, 1, 0.55))
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var icon := PowerIcon.make(u.id, 112, level if level > 1 else 0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(icon)
	for sig: Signal in [b.mouse_entered, b.focus_entered]:
		sig.connect(_glow.bind(icon, 1.0))
	for sig: Signal in [b.mouse_exited, b.focus_exited]:
		sig.connect(_glow.bind(icon, 0.0))

	_text(inner, u.name + Upgrades.level_tag(level), 28, Color.WHITE)
	var player := get_tree().get_first_node_in_group("player")
	# A level-up says how often the power has fired this run (player.power_procs).
	var fired: int = player.power_procs.get(u.id, 0) if player != null and level > 1 else 0
	_text(inner, "NEW" if level == 1 else "LEVEL UP   %d → %d%s" % [level - 1, level,
		"   ·   fired ×%d" % fired if fired > 0 else ""], 15, color.lightened(0.2))

	# Numbers as they'd be once taken, counting any synergy it completes.
	var after := owned.duplicate()
	after[u.id] = level
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for font: String in ["normal_font_size", "bold_font_size"]:
		desc.add_theme_font_size_override(font, 19)
	desc.add_theme_color_override("default_color", Color(0.88, 0.86, 0.94))
	desc.text = "[center]%s[/center]" % Upgrades.describe(u, level, Upgrades.active_synergies(after), color.lightened(0.3))
	inner.add_child(desc)
	# A power on a named combo says how to do the combo ("Flurry:  L L, pause, L").
	var combo := Upgrades.combo_of(u)
	if player != null and player.COMBOS.has(combo):
		var found: bool = player.combos_landed.has(combo)
		_text(inner, "%s:  %s%s" % [player.combo_name(combo), player.COMBOS[combo].input,
			"" if found else "   (not landed yet)"], 15, Color(1, 1, 1, 0.55) if found else Color(1.0, 0.8, 0.5, 0.75))

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(gap)

	# What it adds up to: progress toward each path's mastery, synergies.
	if level == 1:
		var counts := Upgrades.path_counts(owned)
		for path: String in paths:
			var n: int = mini(counts[path] + 1, Upgrades.MASTERY_NEED)
			var pc: Color = Upgrades.PATHS[path].color
			var pname: String = Upgrades.PATHS[path].name.to_upper()
			if counts[path] >= Upgrades.MASTERY_NEED:
				_text(inner, "%s MASTERY ACTIVE" % pname, 16, Color(pc, 0.6))
			elif counts[path] + 1 == Upgrades.MASTERY_NEED:
				_text(inner, "UNLOCKS %s MASTERY" % pname, 16, pc.lightened(0.2))
			else:
				_text(inner, "%s  %s  MASTERY" % [pname, PowerIcon.mastery_pips(n)], 16, Color(pc, 0.85))
	for syn: String in Upgrades.would_activate(owned, u.id):
		_text(inner, "Completes %s synergy!" % Upgrades.SYNERGIES[syn].name, 16, SYNERGY_COLOR)
	var tags := Upgrades.tags(u.id)
	_text(inner, "[%d]%s" % [i + 1, ("   ·   " + tags) if tags != "" else ""], 14, Color(1, 1, 1, 0.4))
	return b


func _glow(icon: PowerIcon, to: float) -> void:
	icon.create_tween().tween_method(func(v: float) -> void:
		icon.glow = v
		icon.queue_redraw(), icon.glow, to, 0.12)


func _vbox(parent: Control, gap: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	return v


func _text(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _card_style(bg: Color, border: Color, width := 3, margin := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(margin)
	return s
