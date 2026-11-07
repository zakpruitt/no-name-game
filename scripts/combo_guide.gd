extends Control
## Combo guide: beside the hero mid-string, one row per input that continues
## it (button glyph + the move it starts, coloured by combo tier) and, dimmer,
## the best named combo one press past that. Reads `hero_moves.combo_options()`
## every frame, so it changes the instant a move starts. A ring round each
## glyph fills toward the move's cancel point and the rows light up once a
## press would be taken (`hero_input.combo_window()`); pressing flashes the row
## straight from `_input`, before the move even starts. Animates in real time
## so hitstop and slow motion don't stall it. Off in Settings (Game.combo_guide).

const FADE_IN := 0.05
const KEY_COLORS := {"light": Color(0.35, 0.62, 1.0), "heavy": Color(1.0, 0.78, 0.2), "dash": Color(0.35, 0.88, 0.45)}  # each button's key rim
const FADE_OUT := 0.14
const SWAP_TIME := 0.09  # rows slide in when the options change
const SWAP_STAGGER := 0.018
const FLASH_TIME := 0.2
const ROW_H := 34.0
const ROW_GAP := 5.0
const GLYPH_H := 26.0
const SMALL_GLYPH_H := 18.0
const NAME_SIZE := 19
const NEXT_SIZE := 15
const KEY_SIZE := 15
const PAUSE_TEXT := "or pause: "  # before a row's pause combo (hero_moves.combo_options() `pause`)
## Round 34, fourth pass: mixing elements shows on the rows. A crossover row carries its element change ("storm >
## magma", `mix`) and a row whose move would cash in a state on a foe in its reach the payoff's name ("+ Shatter",
## `pay`, from hero_moves.pays()); both only read the real routes and the foes, like every row.
const MIX_SIZE := 14
const MIX_COLOR := Color(0.72, 0.6, 1.0)  # the tag's ink: the void arm's violet, lifted
const PAY_TEXT := "+ "
const SIDE_GAP := 76.0  # px from the hero's centre to the rows
const CHEST := 1.1  # metres above the feet the rows centre on
const EDGE := 330.0  # flip to the hero's left this close to the right edge (and right near the left)
const EDGE_SLACK := 80.0  # px past EDGE before an edge flip lets go
const PILE_RADIUS := 6.0  # m: foes this near him count for which side the pile is on
const PILE_SLACK := 30.0  # px the pile's middle must be off his to move the rows
const PLAIN_COLOR := Color(0.84, 0.86, 0.92)
const BACK_COLOR := Color(0.04, 0.03, 0.07, 0.5)  # (round 33, part 3: 0.74 under the halftone)
## Round 33, part 3 (sleek HUD, hud_ink.gd): each row's backing is a see-through pill with halftone dots in the
## row's colour, densest at its key and fading across, inside a thin line in that colour, not a solid dark slab.
const ROW_DOTS := 0.28  # alpha of the backing's dots
const ROW_LINE := 0.55  # alpha of its line
const HUD_INK := preload("res://scripts/hud_ink.gd")
const COUNTER_HINT := preload("res://scripts/counter.gd")
## Button text: mouse and keyboard, the one control set shown in the game.
const LABELS := {"light": "LMB", "heavy": "RMB", "dash": "SPACE"}
const ACTIONS := {"attack_light": "light", "attack_heavy": "heavy", "dash": "dash"}

var player: Node3D
var shown := 0  # times the guide appeared (autotest)
var _rows: Array = []
var _sig := ""
var _vis := 0.0
var _swap_t := 99.0
var _ready_t := 99.0  # since the rows became ready (pop)
var _was_ready := false
var _side := 1.0
var _pile_side := 1.0  # the side away from the pile (before the edges have their say)
var _flashes: Array = []  # [offset from anchor, colour, age]
var _press := {}  # kind -> age of the last press
var _anchor := Vector2.ZERO
var _glyph_at := {}  # row index -> main glyph centre, relative to the anchor (last draw)
var _last_us := 0
var _font: Font
var _box := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_box.anti_aliasing = true
	_last_us = Time.get_ticks_usec()


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	for action: String in ACTIONS:
		if event.is_action(action):
			_on_press(ACTIONS[action])


## Flash the row for `kind` right away (also called by the autotest bot).
func _on_press(kind: String) -> void:
	_press[kind] = 0.0
	if _vis <= 0.05:
		return
	for i in _rows.size():
		if _rows[i].kind == kind and _glyph_at.has(i):
			_flashes.append([_glyph_at[i], _row_color(_rows[i]), 0.0])


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		visible = false
	elif what == NOTIFICATION_UNPAUSED:
		visible = true


func _process(_delta: float) -> void:
	# Real time: hitstop and breaker slow motion scale delta down.
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_us) / 1000000.0, 0.1)
	_last_us = now
	var rows: Array = [] if not Game.combo_guide or not is_instance_valid(player) else (player.guide_rows()
		if player.has_method("guide_rows") else player.HERO_MOVES.combo_options(player))  # (guide_rows: the prince)
	if Game.combo_guide and is_instance_valid(player) and "_counter" in player:
		rows = COUNTER_HINT.hint(player, rows)  # a strike is coming: SPACE Backlash on top (counter.gd)
	if not rows.is_empty():
		var sig := ",".join(rows.map(func(r: Dictionary) -> String: return "%s:%s:%s:%s" % [r.kind, r.id, r.next.get("id", ""), r.get("pay", "")]))
		if sig != _sig:
			_sig = sig
			_swap_t = 0.0
			_was_ready = false
		if _vis <= 0.0:
			shown += 1
		_rows = rows
		_vis = minf(_vis + dt / FADE_IN, 1.0)
	else:
		_sig = ""
		_vis = maxf(_vis - dt / FADE_OUT, 0.0)
	_swap_t += dt
	_ready_t += dt
	for k in _press:
		_press[k] += dt
	for f in _flashes:
		f[2] += dt
	_flashes = _flashes.filter(func(f: Array) -> bool: return f[2] < FLASH_TIME)
	queue_redraw()


func _draw() -> void:
	if (_vis <= 0.0 and _flashes.is_empty()) or not is_instance_valid(player):
		return
	var cam := get_viewport().get_camera_3d()
	var chest: Vector3 = player.global_position + Vector3.UP * CHEST
	if cam == null or cam.is_position_behind(chest):
		return
	var screen := get_viewport_rect().size
	var at := cam.unproject_position(chest)
	# Feel audit 2026-11-04 item 3: the rows sat over the pile. They go on the side away from the foes
	# near him (screen x, with PILE_SLACK px of hysteresis), then flip in from the edges.
	# Feel audit 3 (2026-11-06) item 2: the right-edge flip's "slack" branch sent every left choice back to the right
	# (it ran whenever he was not near the right edge), so the pile choice never held and the rows sat on the foes in
	# every string that faced right. The pile picks `_pile_side`; the edges override it, each with its own slack.
	var pile := _pile_dx(cam, player.global_position, at)
	if pile > PILE_SLACK:
		_pile_side = -1.0
	elif pile < -PILE_SLACK:
		_pile_side = 1.0
	_side = guide_side(_pile_side, _side, at.x, screen.x)
	_anchor = at + Vector2(_side * SIDE_GAP, 0.0)
	var win: Dictionary = player.HERO_INPUT.combo_window(player)
	var ready: bool = win.ready
	if ready and not _was_ready:
		_ready_t = 0.0
	_was_ready = ready
	var top := -(_rows.size() * ROW_H + (_rows.size() - 1) * ROW_GAP) * 0.5
	_anchor.y = clampf(_anchor.y, 110.0 - top, screen.y - 60.0 + top)
	for i in _rows.size():
		var k := clampf((_swap_t - i * SWAP_STAGGER) / SWAP_TIME, 0.0, 1.0)
		k = 1.0 - (1.0 - k) * (1.0 - k)
		var row: Dictionary = _rows[i]
		var usable: bool = ready and (row.kind != "dash" or win.dash)
		_draw_row(i, row, _row_pos(i) + Vector2(-_side * 14.0 * (1.0 - k), 0.0), _vis * k, usable, win.progress)
	for f: Array in _flashes:
		var a: float = f[2] / FLASH_TIME
		draw_arc(_anchor + f[0], GLYPH_H * (0.6 + a * 0.9), 0.0, TAU, 40, Color(f[1], 1.0 - a), 2.0 * (1.0 - a) + 1.0, true)


## Which side of him the rows go (1 right, -1 left): `want` (away from the pile) unless that side would run off an
## edge (EDGE px), with EDGE_SLACK px before an edge flip lets go so it doesn't flicker. `side` is the last answer.
static func guide_side(want: float, side: float, x: float, width: float) -> float:
	if want < 0.0 and (x < EDGE or (side > 0.0 and x < EDGE + EDGE_SLACK)):
		return 1.0
	if want > 0.0 and (x > width - EDGE or (side < 0.0 and x > width - EDGE - EDGE_SLACK)):
		return -1.0
	return want


## Left (right when flipped) middle of row `i`, relative to the anchor.
func _row_pos(i: int) -> Vector2:
	var top := -(_rows.size() * ROW_H + (_rows.size() - 1) * ROW_GAP) * 0.5
	return Vector2(0.0, top + i * (ROW_H + ROW_GAP) + ROW_H * 0.5)


func _row_color(row: Dictionary) -> Color:
	return player.COMBO_TIER_COLORS[row.tier - 1] if row.tier > 0 else PLAIN_COLOR


func _draw_row(i: int, row: Dictionary, pos: Vector2, alpha: float, usable: bool, progress: float) -> void:
	if alpha <= 0.01:
		return
	var col := _row_color(row)
	var t := Time.get_ticks_msec() / 1000.0
	var lit := 1.0 if usable else 0.78
	var pressed: float = clampf(1.0 - _press.get(row.kind, 9.0) / FLASH_TIME, 0.0, 1.0)
	# Lay the row out first (measured left to right), then mirror if flipped.
	var parts := []  # [kind, x, w] pieces
	var x := 6.0
	var gw := _glyph_w(row.kind, GLYPH_H)
	parts.append(["glyph", x, gw, row.kind, GLYPH_H])
	x += gw + 4.0
	if row.kind == "dash":
		var sw := _glyph_w("light", SMALL_GLYPH_H)
		parts.append(["glyph", x, sw, "light", SMALL_GLYPH_H])
		x += sw + 4.0
	x += 4.0
	var name: String = row.name
	if row.hold:
		name = ("RELEASE  " if usable else "HOLD  ") + name
	if row.has("mix"):  # (before the name: the element it turns into)
		var mw := _font.get_string_size(row.mix, HORIZONTAL_ALIGNMENT_LEFT, -1, MIX_SIZE).x
		parts.append(["mix", x, mw, row.mix])
		x += mw + 8.0
	var nw := _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	parts.append(["name", x, nw, name])
	x += nw
	if row.has("pay"):
		x += 8.0
		var pt: String = PAY_TEXT + row.pay
		var pw := _font.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, NEXT_SIZE).x
		parts.append(["pay", x, pw, pt])
		x += pw
	if not row.next.is_empty():
		x += 10.0
		parts.append(["arrow", x, 8.0])
		x += 16.0
		var nk: String = row.next.kind
		var ngw := _glyph_w(nk, SMALL_GLYPH_H)
		parts.append(["glyph", x, ngw, nk, SMALL_GLYPH_H])
		x += ngw + 6.0
		var nn: String = row.next.name
		var nnw := _font.get_string_size(nn, HORIZONTAL_ALIGNMENT_LEFT, -1, NEXT_SIZE).x
		parts.append(["next", x, nnw, nn])
		x += nnw
	if row.has("pause"):
		x += 12.0
		var pt: String = PAUSE_TEXT + row.pause.name
		var pw := _font.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, NEXT_SIZE).x
		parts.append(["pause", x, pw, pt])
		x += pw
	var width := x + 10.0
	var x0 := pos.x if _side > 0.0 else pos.x - width
	var base := _anchor + Vector2(x0, pos.y)

	# Backing pill; a press flashes it.
	var back := Rect2(base + Vector2(0.0, -ROW_H * 0.5), Vector2(width, ROW_H))
	_pill(back, Color(BACK_COLOR, BACK_COLOR.a * alpha), Color(col, ROW_LINE * alpha), 1)
	HUD_INK.dots(self, back, Color(col, ROW_DOTS * alpha * lit), _side > 0.0)
	if pressed > 0.0:
		_pill(Rect2(base + Vector2(0.0, -ROW_H * 0.5), Vector2(width, ROW_H)), Color(col, 0.45 * pressed * alpha))

	for p: Array in parts:
		var px: float = base.x + p[1]
		match p[0]:
			"glyph":
				var main: bool = p[4] == GLYPH_H
				var c := Vector2(px + p[2] * 0.5, base.y)
				if main:
					_glyph_at[i] = c - _anchor
				var s := 1.0
				if main and usable:
					s = 1.0 + 0.16 * clampf(1.0 - _ready_t / 0.12, 0.0, 1.0) + 0.04 * sin(t * 14.0)
				if main:
					s += 0.18 * pressed
				_glyph(c, p[3], p[4] * s, alpha * (lit if main else 0.75 * lit))
				if main and not usable:
					var r: float = p[4] * 0.5 + 4.0
					draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.15 * alpha), 2.0, true)
					draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, Color(col, 0.9 * alpha), 2.5, true)
				elif main and row.hold:
					draw_arc(c, p[4] * 0.5 + 4.0, 0.0, TAU, 32, Color(col, alpha), 2.5, true)
			"name":
				_text(Vector2(px, base.y), p[3], NAME_SIZE, Color(col.lightened(0.15 * pressed), alpha * lit))
			"mix":
				_text(Vector2(px, base.y), p[3], MIX_SIZE, Color(MIX_COLOR, 0.95 * alpha * lit))
			"pay":
				_text(Vector2(px, base.y), p[3], NEXT_SIZE, Color(player.COMBO_TIER_COLORS[1], alpha * lit))
			"arrow":
				var a := Vector2(px, base.y)
				draw_polyline([a + Vector2(0, -5), a + Vector2(5, 0), a + Vector2(0, 5)], Color(1, 1, 1, 0.45 * alpha), 2.0, true)
			"next":
				var nc: Color = player.COMBO_TIER_COLORS[row.next.tier - 1]
				_text(Vector2(px, base.y), p[3], NEXT_SIZE, Color(nc, 0.9 * alpha * lit))
			"pause":
				_text(Vector2(px, base.y), p[3], NEXT_SIZE, Color(player.COMBO_TIER_COLORS[row.pause.tier - 1], 0.6 * alpha * lit))


func _glyph_w(kind: String, h: float) -> float:
	var label: String = LABELS[kind]
	return maxf(h, _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(KEY_SIZE * h / GLYPH_H)).x + h * 0.6)


## A button: a dark key with a rim in the input's colour.
func _glyph(c: Vector2, kind: String, h: float, alpha: float) -> void:
	var label: String = LABELS[kind]
	var size := int(KEY_SIZE * h / GLYPH_H)
	var w := maxf(h, _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + h * 0.6)
	var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var kc: Color = KEY_COLORS.get(kind, ComicLook.VOID_COLOR)
	_pill(r, Color(0.1, 0.08, 0.14, 0.95 * alpha), Color(kc, alpha), 2)
	var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(c.x - tw * 0.5, c.y + size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, alpha))


func _pill(r: Rect2, fill: Color, border := Color.TRANSPARENT, border_w := 0) -> void:
	_box.bg_color = fill
	_box.set_corner_radius_all(int(r.size.y * 0.5))
	_box.set_border_width_all(border_w)
	_box.border_color = border
	draw_style_box(_box, r)


## Text with its left edge at `at.x`, vertically centred on `at.y`.
func _text(at: Vector2, s: String, size: int, c: Color) -> void:
	var p := Vector2(at.x, at.y + size * 0.36)
	draw_string_outline(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, HUD_INK.outline(size), Color(HUD_INK.INK, c.a))
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## Mean screen x of the foes within PILE_RADIUS of `from`, minus his (`at`); 0 with none.
func _pile_dx(cam: Camera3D, from: Vector3, at: Vector2) -> float:
	var sum := 0.0
	var n := 0
	for e: Node3D in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.global_position.distance_to(from) < PILE_RADIUS and not cam.is_position_behind(e.global_position):
			sum += cam.unproject_position(e.global_position).x - at.x
			n += 1
	return sum / n if n > 0 else 0.0
