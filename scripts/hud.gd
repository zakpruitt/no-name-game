extends CanvasLayer
## Health, Awakening meter, combo counter with style rank, wave banner.

const RANK_COLORS := {"D": Color(0.7, 0.7, 0.7), "C": Color(0.5, 0.8, 1.0), "B": Color(0.4, 1.0, 0.5),
	"A": Color(1.0, 0.9, 0.3), "S": Color(1.0, 0.55, 0.2), "SS": Color(1.0, 0.3, 0.3), "SSS": Color(1.0, 0.3, 0.9)}

var hp_bar: ProgressBar
var awaken_bar: ProgressBar
var awaken_hint: Label
var combo_label: Label
var rank_label: Label
var wave_label: Label
var center_label: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	hp_bar = _bar(root, Vector2(32, 28), Vector2(360, 22), Color(0.9, 0.25, 0.25))
	awaken_bar = _bar(root, Vector2(32, 58), Vector2(360, 14), Color(1.0, 0.6, 0.15))
	awaken_bar.max_value = Game.AWAKEN_MAX
	awaken_hint = _label(root, "AWAKEN READY  [Q]", 20, Color(1.0, 0.7, 0.2))
	awaken_hint.position = Vector2(32, 76)
	awaken_hint.visible = false

	combo_label = _label(root, "", 56, Color.WHITE)
	_anchor(combo_label, 1.0, 0.0, Rect2(-380, 120, 340, 70))
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label = _label(root, "", 96, Color.WHITE)
	_anchor(rank_label, 1.0, 0.0, Rect2(-380, 180, 340, 110))
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.pivot_offset = Vector2(300, 55)

	wave_label = _label(root, "", 26, Color(0.85, 0.85, 0.95))
	_anchor(wave_label, 0.5, 0.0, Rect2(-150, 24, 300, 40))
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	center_label = _label(root, "", 64, Color.WHITE)
	_anchor(center_label, 0.5, 0.5, Rect2(-500, -120, 1000, 160))
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_label(root, "WASD move   J/LMB light   K/RMB heavy   Space dash   Q awaken", 16, Color(1, 1, 1, 0.5)) \
		.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)

	Game.combo_changed.connect(_on_combo)
	Game.awakening_changed.connect(_on_awakening)


func bind_player(p: Node) -> void:
	p.health_changed.connect(func(hp: float, mx: float) -> void:
		hp_bar.max_value = mx
		hp_bar.value = hp)
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp


func set_wave(n: int) -> void:
	wave_label.text = "WAVE %d" % n
	flash_message("WAVE %d" % n, 1.2)


func flash_message(text: String, duration := 0.0) -> void:
	center_label.text = text
	center_label.modulate.a = 1.0
	center_label.scale = Vector2.ONE
	if duration > 0.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		tw.tween_property(center_label, "modulate:a", 0.0, 0.4)


func _on_combo(count: int, rank: String) -> void:
	if count < 2:
		combo_label.text = ""
		rank_label.text = ""
		return
	combo_label.text = "%d HITS" % count
	if rank_label.text != rank:
		rank_label.text = rank
		rank_label.add_theme_color_override("font_color", RANK_COLORS[rank])
		rank_label.scale = Vector2.ONE * 1.6
		create_tween().tween_property(rank_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_awakening(v: float) -> void:
	awaken_bar.value = v
	awaken_hint.visible = v >= Game.AWAKEN_MAX


## Pin a control to a point on the screen (0..1 on each axis) with a pixel rect.
func _anchor(c: Control, ax: float, ay: float, r: Rect2) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


func _bar(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = size
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	parent.add_child(b)
	return b


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
