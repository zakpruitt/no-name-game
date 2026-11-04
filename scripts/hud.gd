extends CanvasLayer
## Health, Awakening meter, combo counter with style rank, room title and the
## training readout under it, boss bar,
## the combo guide beside the hero (combo_guide.gd), and a red edge vignette +
## heartbeat when HP runs low.

const RANK_COLORS := {"D": Color(0.7, 0.7, 0.7), "C": Color(0.5, 0.8, 1.0), "B": Color(0.4, 1.0, 0.5),
	"A": Color(1.0, 0.9, 0.3), "S": Color(1.0, 0.55, 0.2), "SS": Color(1.0, 0.3, 0.3), "SSS": Color(1.0, 0.3, 0.9)}
const LOW_HP := 0.25  # vignette + heartbeat below this fraction of max HP
const HEARTBEAT := 0.8  # seconds between beats at LOW_HP; quicker as HP drops
const FOUND_HOLD := 2.5  # s the "New combo" hint stays up
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float d = length((UV - 0.5) * vec2(1.5, 1.0));
	COLOR = vec4(0.7, 0.0, 0.04, smoothstep(0.5, 1.0, d) * strength);
}
"""

var hp_bar: ProgressBar
var awaken_bar: ProgressBar
var awaken_hint: Label
var combo_label: Label
var rank_label: Label
var air_label: Label
var wave_label: Label
var readout_label: Label  # under the room title: the training readout (each string's damage)
var center_label: Label
var hint_label: Label
var hint_panel: PanelContainer
var _hint_tween: Tween
var boss_root: Control
var boss_bar: ProgressBar
var boss_break_bar: ProgressBar
var boss_name: Label
var _boss: Node
var _vignette_mat: ShaderMaterial
var _hp_ratio := 1.0
var _beat_t := 0.0
var _pulse := 0.0
var _vignette := 0.0
var combo_guide: Control


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = shader
	vignette.material = _vignette_mat
	root.add_child(vignette)
	root.add_child(preload("res://scripts/enemy_bars.gd").new())
	root.add_child(preload("res://scripts/threat_arrows.gd").new())
	combo_guide = preload("res://scripts/combo_guide.gd").new()
	root.add_child(combo_guide)

	hp_bar = _bar(root, Vector2(32, 28), Vector2(360, 22), Color(0.9, 0.25, 0.25))
	awaken_bar = _bar(root, Vector2(32, 58), Vector2(360, 14), Color(1.0, 0.6, 0.15))
	awaken_bar.max_value = Game.AWAKEN_MAX
	awaken_hint = _label(root, "AWAKEN READY  [Q]", 20, Color(1.0, 0.7, 0.2))
	awaken_hint.position = Vector2(32, 88)
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
	_anchor(wave_label, 0.5, 0.0, Rect2(-260, 24, 520, 40))
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout_label = _label(root, "", 20, Color(1.0, 0.93, 0.6))
	_anchor(readout_label, 0.5, 0.0, Rect2(-300, 62, 600, 30))
	readout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	center_label = _label(root, "", 64, Color.WHITE)
	_anchor(center_label, 0.5, 0.5, Rect2(-500, -120, 1000, 160))
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_label(root, "WASD move   LMB light   RMB heavy   Space dash   Q awaken   Esc pause", 16, Color(1, 1, 1, 0.5)) \
		.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)

	# Hint: a soft dark panel sized to the text, bottom center.
	hint_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.02, 0.06, 0.65)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(12)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	hint_panel.add_theme_stylebox_override("panel", panel_style)
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_row := CenterContainer.new()  # keeps the panel centered at its text size
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_row)
	hint_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_row.offset_top = -200
	hint_row.offset_bottom = -100
	hint_row.add_child(hint_panel)
	hint_label = _label(hint_panel, "", 22, Color(1.0, 0.92, 0.75))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.modulate.a = 0.0
	Game.hint_shown.connect(show_hint)

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
		hp_bar.value = hp
		_hp_ratio = hp / mx)
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp
	combo_guide.player = p
	# A combo's first landing, unless a tutorial hint is still up.
	p.combo_found.connect(func(id: String) -> void:
		if hint_panel.modulate.a < 0.05:
			show_hint("New combo: %s   (%s)   ·   %d / %d found" % [p.combo_name(id), p.COMBOS[id].input,
				p.combos_landed.size(), p.COMBOS.size()], FOUND_HOLD))


func show_boss(boss: Node) -> void:
	_boss = boss
	boss_name.text = boss.display_name
	boss_bar.max_value = boss.max_hp
	boss_break_bar.max_value = 1.0
	boss_root.visible = true


func _process(delta: float) -> void:
	_update_low_hp(delta)
	if not boss_root.visible:
		return
	if not is_instance_valid(_boss) or _boss.hp <= 0.0:
		boss_root.visible = false
		return
	boss_bar.value = _boss.hp
	boss_break_bar.value = _boss.break_ratio()
	boss_name.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if _boss.is_enraged else Color(1.0, 0.85, 0.7))


## The line under the room title ("" hides it): the training readout.
func set_readout(text: String) -> void:
	readout_label.text = text


## Below LOW_HP: the vignette fades in and throbs with a heartbeat that
## quickens as HP drops; it fades back out once healed.
func _update_low_hp(delta: float) -> void:
	var low := _hp_ratio > 0.0 and _hp_ratio < LOW_HP
	if low:
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = HEARTBEAT * lerpf(0.6, 1.0, _hp_ratio / LOW_HP)
			_pulse = 1.0
			Game.sfx("heartbeat", -3.0, 0.0)
	else:
		_beat_t = 0.0
	_pulse = move_toward(_pulse, 0.0, delta * 2.5)
	_vignette = move_toward(_vignette, 0.5 if low else 0.0, delta * 1.5)
	var throb := 0.0 if Game.reduce_flashing else 0.7 * _pulse
	_vignette_mat.set_shader_parameter("strength", _vignette * (1.0 + throb))


## Tutorial tip above the controls line: fades in, holds, fades out.
## Menus pause the tree: hide the hint behind them (its tween is paused too,
## so it picks up where it left off once play resumes).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and hint_panel:
		hint_panel.visible = false
	elif what == NOTIFICATION_UNPAUSED and hint_panel:
		hint_panel.visible = true


func show_hint(text: String, hold := 5.0) -> void:
	hint_label.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(hint_panel, "modulate:a", 1.0, 0.25)
	_hint_tween.tween_interval(hold)
	_hint_tween.tween_property(hint_panel, "modulate:a", 0.0, 0.6)


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
