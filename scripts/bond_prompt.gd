extends "res://scripts/menu_screen.gd"
## The bond prompt (docs/features/spirits.md): pressing E at a spirit opens this instead of claiming it outright.
## It asks "Bond with the STORM SPIRIT?" in the element's colour and lists what comes with it (Spirits.offers):
## the combos it opens, their breakers, and its passive. Bond claims it; Not now, Esc or gamepad B closes.
## The game is paused while it shows. spirit_companion.place() makes the one prompt the three spirits share.

const ELEMENTS := preload("res://scripts/elements.gd")
const WORDS: Dictionary = preload("res://scripts/hero_moves.gd").ELEMENT_WORDS
const WIDTH := 640.0  # px: the panel
const INPUT_WIDTH := 250.0  # px: the input column, wide enough for "Dash H H L, then H"
const BUTTON_WIDTH := 220
const HEAD := Color(1.0, 0.7, 0.25)  # the menus' gold
const TEXT := Color(0.85, 0.8, 0.95)
const DIM := Color(1, 1, 1, 0.5)
const TAG := Color(0.72, 0.6, 1.0, 0.7)  # the MOVES panel's slot tag

var _on_yes := Callable()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close_menu()
		get_viewport().set_input_as_handled()


## Ask whether to bond with `element`'s spirit; `on_yes` runs if he does.
func ask(element: String, on_yes: Callable) -> void:
	close_menu(false)
	_on_yes = on_yes
	_build_prompt(element)
	visible = true
	get_tree().paused = true
	_buttons[0].grab_focus()


func _yes() -> void:
	var on_yes := _on_yes
	close_menu()
	if on_yes.is_valid():
		on_yes.call()


func _build_prompt(element: String) -> void:
	var color: Color = ELEMENTS.LOOK[element].color
	var offer := Spirits.offers(element)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.05, 0.1, 0.92), color.darkened(0.25)))
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	centre.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	# "Bond with the STORM SPIRIT?": three labels, so only the spirit's name wears its colour
	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 12)
	col.add_child(title)
	_label(title, "Bond with the", 38, HEAD)
	_label(title, "%s SPIRIT" % str(WORDS[element]).to_upper(), 38, color)
	_label(title, "?", 38, HEAD)
	if Spirits.held != "" and Spirits.held != element:  # a swap: say what he gives up
		var swap := HBoxContainer.new()
		swap.alignment = BoxContainer.ALIGNMENT_CENTER
		swap.add_theme_constant_override("separation", 6)
		col.add_child(swap)
		var held_color: Color = ELEMENTS.LOOK[Spirits.held].color
		_label(swap, "Your", 16, DIM)
		_label(swap, "%s spirit" % str(WORDS[Spirits.held]).to_upper(), 16, held_color)
		_label(swap, "goes back to its spot, and its moves with it.", 16, DIM)
	_gap(col, 10)
	_left(_label(col, "What comes with it:", 20, TEXT))

	_head(col, "COMBOS", "")
	var combos: Array = offer.combos
	for c: Dictionary in combos:
		_row(col, c.input, c.name, color, c.tag)
	var breakers: Array = offer.breakers
	if not breakers.is_empty():
		_head(col, "BREAKERS", "The last press, timed in the window after the combo.")
		for b: Dictionary in breakers:
			var lands: Color = ELEMENTS.LOOK[b.element].color
			_row(col, b.input, b.name, lands, "")
	_head(col, "PASSIVE", "")
	var passive: String = offer.passive
	var line := _left(_label(col, passive if passive != "" else "None yet.", 17, color if passive != "" else DIM))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(WIDTH - 40.0, 0)

	_gap(col, 14)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	col.add_child(buttons)
	_button(buttons, "Bond", _yes, BUTTON_WIDTH)
	_button(buttons, "Not now", close_menu, BUTTON_WIDTH)
	_label(col, "Enter / click: choose      Esc: not now", 13, Color(1, 1, 1, 0.4))


func _gap(parent: Control, height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	parent.add_child(gap)


func _left(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


## A section heading, with its hint in a dim line under it.
func _head(parent: Control, text: String, hint: String) -> void:
	_gap(parent, 8)
	_left(_label(parent, text, 15, Color(HEAD, 0.85)))
	if hint != "":
		_left(_label(parent, hint, 13, DIM))


## One input, the name it plays in `color`, and its slot tag.
func _row(parent: Control, input: String, text: String, color: Color, tag: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	parent.add_child(line)
	_left(_label(line, input, 17, TEXT)).custom_minimum_size = Vector2(INPUT_WIDTH, 0)
	_left(_label(line, text, 17, color))
	if tag != "":
		_left(_label(line, tag, 13, TAG))
