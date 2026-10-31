extends CanvasLayer
## Health, Awakening meter, combo counter with style rank, room banner, boss bar.

const RANK_COLORS := {"D": Color(0.7, 0.7, 0.7), "C": Color(0.5, 0.8, 1.0), "B": Color(0.4, 1.0, 0.5),
	"A": Color(1.0, 0.9, 0.3), "S": Color(1.0, 0.55, 0.2), "SS": Color(1.0, 0.3, 0.3), "SSS": Color(1.0, 0.3, 0.9)}

var hp_bar: ProgressBar
var awaken_bar: ProgressBar
var awaken_hint: Label
var combo_label: Label
var rank_label: Label
var air_label: Label
var wave_label: Label
var center_label: Label
var upgrades_label: Label
var boss_root: Control
var boss_bar: ProgressBar
var boss_break_bar: ProgressBar
var boss_name: Label
var _boss: Node


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

	air_label = _label(root, "", 34, Color(0.55, 0.85, 1.0))
	_anchor(air_label, 1.0, 0.0, Rect2(-380, 290, 340, 50))
	air_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	air_label.pivot_offset = Vector2(300, 25)

	wave_label = _label(root, "", 26, Color(0.85, 0.85, 0.95))
	_anchor(wave_label, 0.5, 0.0, Rect2(-150, 24, 300, 40))
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	center_label = _label(root, "", 64, Color.WHITE)
	_anchor(center_label, 0.5, 0.5, Rect2(-500, -120, 1000, 160))
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_label(root, "WASD move   J/LMB light   K/RMB heavy   Space dash   Q awaken   Esc pause", 16, Color(1, 1, 1, 0.5)) \
		.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)

	upgrades_label = _label(root, "", 18, Color(1.0, 0.8, 0.5))
	_anchor(upgrades_label, 1.0, 1.0, Rect2(-420, -300, 396, 276))
	upgrades_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	upgrades_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	# Boss bar: top center, hidden until a boss spawns.
	boss_root = Control.new()
	boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(boss_root, 0.5, 0.0, Rect2(-320, 70, 640, 70))
	root.add_child(boss_root)
	boss_name = _label(boss_root, "", 22, Color(1.0, 0.85, 0.7))
	boss_name.size = Vector2(640, 30)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = _bar(boss_root, Vector2(0, 34), Vector2(640, 18), Color(0.85, 0.15, 0.2))
	boss_break_bar = _bar(boss_root, Vector2(80, 66), Vector2(480, 6), Color(1.0, 0.8, 0.3))
	boss_root.visible = false

	Game.combo_changed.connect(_on_combo)
	Game.announced.connect(func(text: String) -> void: flash_message(text, 0.5))
	Game.awakening_changed.connect(_on_awakening)
	Game.air_combo_changed.connect(_on_air_combo)


func bind_player(p: Node) -> void:
	p.health_changed.connect(func(hp: float, mx: float) -> void:
		hp_bar.max_value = mx
		hp_bar.value = hp)
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp


func show_boss(boss: Node) -> void:
	_boss = boss
	boss_name.text = boss.display_name
	boss_bar.max_value = boss.max_hp
	boss_break_bar.max_value = 1.0
	boss_root.visible = true


func _process(_delta: float) -> void:
	if not boss_root.visible:
		return
	if not is_instance_valid(_boss) or _boss.hp <= 0.0:
		boss_root.visible = false
		return
	boss_bar.value = _boss.hp
	boss_break_bar.value = _boss.break_ratio()
	boss_name.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if _boss.is_enraged else Color(1.0, 0.85, 0.7))


func set_upgrades(ids: Array) -> void:
	var lines: Array[String] = []
	for id in ids:
		var u := Upgrades.get_by_id(id)
		lines.append("%s  [%s]" % [u.name, u.slot])
	upgrades_label.text = "\n".join(lines)


func set_room(n: int, total: int, kind: String) -> void:
	wave_label.text = "ROOM %d / %d" % [n, total]
	if kind == "elite":
		flash_message("ROOM %d\nELITES" % n, 1.4)
	elif kind != "boss":  # the boss announces itself
		flash_message("ROOM %d" % n, 1.2)


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


func _on_air_combo(count: int) -> void:
	if count < 2:
		# Juggle dropped: fade the counter out instead of snapping it away.
		if air_label.text != "":
			var tw := create_tween()
			tw.tween_property(air_label, "modulate:a", 0.0, 0.3)
			tw.tween_callback(func() -> void: air_label.text = "")
		return
	air_label.text = "AIR x%d" % count
	air_label.modulate.a = 1.0
	air_label.scale = Vector2.ONE * 1.35
	create_tween().tween_property(air_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
