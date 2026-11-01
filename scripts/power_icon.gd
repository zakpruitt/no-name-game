class_name PowerIcon
extends Control
## A power's icon: its glyph (Upgrades.icon) tinted in its path colour inside
## a round frame. A fusion's frame is split between its two paths. With
## `level` > 0, pips along the bottom show it out of Upgrades.MAX_LEVEL.
## Used by the reward cards, the pause build view, the HUD strip and the
## run summary.

const BACK := Color(0.07, 0.05, 0.11, 0.92)
const PIP_OFF := Color(0.18, 0.15, 0.24)

var id := ""
var level := 0
var glow := 0.0  # 0..1, a soft halo behind the frame (the hovered card)


static func make(power_id: String, px: float, power_level := 0) -> PowerIcon:
	var icon := PowerIcon.new()
	icon.id = power_id
	icon.level = power_level
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var u := Upgrades.get_by_id(id)
	if u.is_empty():
		return
	var paths := Upgrades.paths_of(u)
	var a: Color = Upgrades.PATHS[paths[0]].color
	var b: Color = Upgrades.PATHS[paths[-1]].color
	var c := size * 0.5
	var width := maxf(2.0, size.x * 0.045)
	var r := minf(size.x, size.y) * 0.5 - width
	if glow > 0.0:
		for i in 4:
			draw_circle(c, r + width * (1.0 + i * 1.2), Color(a, 0.08 * glow))
	draw_circle(c, r, BACK)
	draw_circle(c, r * 0.86, Color(a.darkened(0.75), 0.6))
	if paths.size() == 1:
		draw_arc(c, r, 0.0, TAU, 64, a, width, true)
	else:
		draw_arc(c, r, PI * 0.75, PI * 1.75, 32, a, width, true)
		draw_arc(c, r, PI * 1.75, PI * 2.75, 32, b, width, true)
	var tex := Upgrades.icon(id)
	if tex:
		var g := Vector2.ONE * r * 1.25
		var tint := a.lerp(Color.WHITE, 0.15) if paths.size() == 1 else Color(1.0, 0.97, 0.92)
		draw_texture_rect(tex, Rect2(c - g * 0.5, g), false, tint)
	if level > 0:
		var pr := maxf(2.5, size.x * 0.06)
		var gap := pr * 2.6
		for i in Upgrades.MAX_LEVEL:
			var at := Vector2(c.x + (i - (Upgrades.MAX_LEVEL - 1) * 0.5) * gap, c.y + r)
			draw_circle(at, pr + 1.5, BACK)
			draw_circle(at, pr, a if i < level else PIP_OFF)


## A small key cap ("LMB") filled with `path`'s colour; the Soul path has no
## key, so it shows its name.
static func chip(path: String, font_size := 14) -> PanelContainer:
	var info: Dictionary = Upgrades.PATHS[path]
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = info.color
	s.set_corner_radius_all(5)
	s.content_margin_left = 7
	s.content_margin_right = 7
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = info.key if info.key != "" else info.name.to_upper()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.06, 0.04, 0.1))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


## "■■□": `n` of Upgrades.MASTERY_NEED toward a path's mastery.
static func mastery_pips(n: int) -> String:
	n = mini(n, Upgrades.MASTERY_NEED)
	return "■".repeat(n) + "□".repeat(Upgrades.MASTERY_NEED - n)
