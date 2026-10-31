extends CanvasLayer
## End-of-run screen (victory or defeat): pauses the game, lists the run's
## stats and upgrades. Enter or the button (gamepad: A) begins a new run.

var _root: Control


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## `stats` is an ordered Dictionary of label -> value text.
## `new_bests` lists the stats keys to flag as new personal records.
## `synergies`: active Upgrades.SYNERGIES ids; `run_seed` (if >= 0) is shown
## small under the button so a run can be replayed with `--seed`.
func open(victory: bool, stats: Dictionary, upgrades: Dictionary, new_bests: Array = [], synergies: Array = [],
		run_seed := -1) -> void:
	_build(victory, stats, upgrades, new_bests, synergies, run_seed)
	visible = true
	get_tree().paused = true


func new_run() -> void:
	Game.skip_title = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		new_run()


func _build(victory: bool, stats: Dictionary, upgrades: Dictionary, new_bests: Array, synergies: Array,
		run_seed: int) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	_root.add_child(col)

	var title := _label(col, "VICTORY" if victory else "YOU FELL", 72,
		Color(1.0, 0.8, 0.3) if victory else Color(0.95, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 48)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for key in stats:
		var best: bool = key in new_bests
		_label(grid, key, 26, Color(0.75, 0.75, 0.85))
		var value := _label(grid, str(stats[key]) + ("   NEW BEST" if best else ""), 26,
			Color(1.0, 0.8, 0.3) if best else Color.WHITE)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var names: Array[String] = []
	for id in upgrades:
		names.append(Upgrades.get_by_id(id).name + Upgrades.level_tag(upgrades[id]))
	var ups := _label(col, "Powers: " + (", ".join(names) if not names.is_empty() else "none"), 20, Color(1.0, 0.8, 0.5))
	ups.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ups.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ups.custom_minimum_size = Vector2(700, 0)
	if not synergies.is_empty():
		var syn := _label(col, "Synergies: " + ", ".join(synergies.map(func(t: String) -> String:
			return Upgrades.SYNERGIES[t].name)), 20, Color(0.6, 0.95, 0.85))
		syn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var b := Button.new()
	b.text = "New run  [Enter]"
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(300, 60)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(new_run)
	col.add_child(b)
	b.grab_focus()
	if run_seed >= 0:
		_label(col, "seed %d" % run_seed, 16, Color(1, 1, 1, 0.4)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Center the column once its size is known.
	await get_tree().process_frame
	col.position = (_root.size - col.size) * 0.5


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	parent.add_child(l)
	return l
