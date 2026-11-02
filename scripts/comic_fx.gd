class_name ComicFx
extends CanvasLayer
## Comic combat text (Game.comic_style only, added by main): onomatopoeia on hits that
## escalate with the chain tier (Fx.CHAIN_TIERS), and a slanted two-bar panel cut-in
## naming a landed combo. The port of comic_poc/comic_vfx.py `word` and `panel`.
## Everything steps on twos at 24 fps and runs on real time, so hitstop doesn't hold it.
## Sits under the HUD (layer 0) so bars never cover health or the combo count.
## The static calls do nothing when no instance exists, i.e. with the flag off.

const FONT_PATH := "res://assets/fonts/Bangers-Regular.ttf"
const FONT_SIZE := 96  # rendered big and scaled down, so one size serves every tier
const INK := Color(0.012, 0.01, 0.02)
const PAPER := Color(0.965, 0.93, 0.82)
const WORD_LOW := Color(0.9, 0.12, 0.04)  # always hot: an element colour sinks into its own effect
const WORD_HIGH := Color(1.0, 0.86, 0.12)
const FPS := 24.0

## By chain tier (Fx.chain_tier: 0..3). A big hit reads one tier up.
const WORDS := [
	["THWAK!", "CHOP!", "WHAK!"],
	["KRAK!", "SMASH!", "THOK!"],
	["KRAKOOM!", "SHIIING!", "SKRAAK!"],
	["THOOOM!", "VRRRSH!", "RRAAAH!"],
]
const WORD_SCALE := [0.42, 0.52, 0.66, 0.84]
const WORD_FRAMES := 20
const POOL := 6
# Words can't stack into noise on a crowd: at most one per gap.
const WORD_GAP_MS := 110
const WORD_GAP_REDUCED_MS := 400
const WORD_RISE_PX := 1.3  # per frame
const WORD_HEAD := 1.6  # metres above the foe's feet
const WORD_JITTER := 34.0
const WORD_TILT := 0.11
const WORD_ALPHA_REDUCED := 0.8
# Keeps a word on the page, as comic_vfx._on_page: side margin, top and bottom bands.
const PAGE_MARGIN := Vector2(0.1, 0.14)

const PANEL_FRAMES := [18, 22, 28]  # by combo tier
const PANEL_FADE_REDUCED := 0.15  # s; bars fade in rather than cut
const PANEL_ALPHA_REDUCED := 0.6
const CAPTION_SCALE := [0.34, 0.42, 0.56]
const CAPTION_POS := Vector2(0.275, 0.1)  # fraction of the screen
const CAPTION_TILT := -0.03

static var _inst: ComicFx

var _font: Font
var _words: Array[Label] = []
var _born: Array[int] = []  # ms, per word; 0 = free
var _next := 0
var _last_word_ms := -100000
var _bars: Bars
var _caption: Label
var _panel_born := 0
var _panel_frames := 0
var _reduced_panel := false


## A hit landed at `world`.
static func hit(world: Vector3, big: bool) -> void:
	if _inst != null:
		_inst._word(world, mini(Fx.chain_tier(Game.combo_count) + (1 if big else 0), WORDS.size() - 1))


## A named combo landed.
static func combo(combo_name: String, tier: int) -> void:
	if _inst != null:
		_inst._panel(combo_name, tier)


## Word size over its life in frames: pops past full size, settles, swells as it goes.
static func word_scale(frame: int, reduced: bool) -> float:
	if reduced:
		return 1.0  # no pop
	if frame < 2:
		return 0.6
	if frame < 4:
		return 1.22
	if frame < WORD_FRAMES - 2:
		return 1.0
	return 1.08


func _ready() -> void:
	_inst = self
	layer = 0
	_font = load(FONT_PATH)
	for i in POOL:
		var l := _make_label()
		_words.append(l)
		_born.append(0)
	_bars = Bars.new()
	_bars.visible = false
	add_child(_bars)
	_caption = _make_label()


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func _make_label() -> Label:
	var l := Label.new()
	l.visible = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", WORD_HIGH)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", FONT_SIZE / 4)
	# The print-offset second colour: a hard red shadow, inked too.
	l.add_theme_color_override("font_shadow_color", WORD_LOW)
	l.add_theme_constant_override("shadow_offset_x", FONT_SIZE / 24)
	l.add_theme_constant_override("shadow_offset_y", FONT_SIZE / 16)
	l.add_theme_constant_override("shadow_outline_size", 0)
	add_child(l)
	return l


func _word(world: Vector3, tier: int) -> void:
	var now := Time.get_ticks_msec()
	var reduced := Game.reduce_flashing
	if now - _last_word_ms < (WORD_GAP_REDUCED_MS if reduced else WORD_GAP_MS):
		return
	_last_word_ms = now
	var i := _next
	_next = (_next + 1) % POOL
	var l := _words[i]
	var options: Array = WORDS[tier]
	l.text = options.pick_random()
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	var at := _on_page(_to_screen(world) + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * WORD_JITTER, l.size * WORD_SCALE[tier])
	l.position = at - l.size * 0.5
	l.rotation = WORD_TILT * (1.0 if randf() < 0.5 else -1.0)
	l.modulate.a = WORD_ALPHA_REDUCED if reduced else 1.0
	l.set_meta("base", WORD_SCALE[tier])
	l.set_meta("y", l.position.y)
	l.set_meta("reduced", reduced)
	l.scale = Vector2.ONE * WORD_SCALE[tier] * word_scale(0, reduced)
	l.visible = true
	_born[i] = maxi(now, 1)


func _to_screen(world: Vector3) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	var top := world + Vector3.UP * WORD_HEAD
	if cam == null or cam.is_position_behind(top):
		return get_viewport().get_visible_rect().size * 0.5
	return cam.unproject_position(top)


func _on_page(p: Vector2, size_px: Vector2) -> Vector2:
	var page := get_viewport().get_visible_rect().size
	var half := size_px * 0.5
	var low := page * PAGE_MARGIN + half
	var high := page * (Vector2.ONE - PAGE_MARGIN) - half
	# A word wider than the page's middle just centres.
	return Vector2(clampf(p.x, low.x, maxf(low.x, high.x)), clampf(p.y, low.y, maxf(low.y, high.y)))


func _panel(combo_name: String, tier: int) -> void:
	var t := clampi(tier, 1, PANEL_FRAMES.size()) - 1
	_reduced_panel = Game.reduce_flashing
	_panel_born = maxi(Time.get_ticks_msec(), 1)
	_panel_frames = PANEL_FRAMES[t]
	_bars.big = t == PANEL_FRAMES.size() - 1
	_bars.modulate.a = 0.0 if _reduced_panel else 1.0
	_bars.visible = true
	_bars.queue_redraw()
	var page := get_viewport().get_visible_rect().size
	_caption.text = combo_name.to_upper() + "!"
	_caption.reset_size()
	_caption.pivot_offset = Vector2.ZERO
	_caption.position = page * CAPTION_POS
	_caption.rotation = CAPTION_TILT
	_caption.set_meta("base", CAPTION_SCALE[t])
	_caption.modulate.a = PANEL_ALPHA_REDUCED if _reduced_panel else 1.0
	_caption.scale = Vector2.ONE * CAPTION_SCALE[t] * (1.0 if _reduced_panel else 1.3)
	_caption.visible = true


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for i in POOL:
		if _born[i] == 0:
			continue
		var frame := _frame(now - _born[i])
		var l := _words[i]
		if frame >= WORD_FRAMES:
			l.visible = false
			_born[i] = 0
			continue
		l.scale = Vector2.ONE * float(l.get_meta("base")) * word_scale(frame, l.get_meta("reduced"))
		l.position.y = float(l.get_meta("y")) - WORD_RISE_PX * frame
	if _panel_born == 0:
		return
	var age := now - _panel_born
	var pf := _frame(age)
	if pf >= _panel_frames:
		_bars.visible = false
		_caption.visible = false
		_panel_born = 0
		return
	if _reduced_panel:
		_bars.modulate.a = minf(age / 1000.0 / PANEL_FADE_REDUCED, 1.0) * PANEL_ALPHA_REDUCED
	elif pf >= 2:
		_caption.scale = Vector2.ONE * float(_caption.get_meta("base"))


## Whole frames at FPS, held on twos.
static func _frame(age_ms: int) -> int:
	return int(age_ms / 1000.0 * FPS) / 2 * 2


## The two slanted ink bars and their paper gutters.
class Bars extends Control:
	const HEIGHT := 0.15  # of half the screen height
	const HEIGHT_BIG := 0.2
	const SLANT := 0.0125  # of the screen width, each side of level
	const GUTTER := 0.011  # of the screen height

	var big := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var page := get_viewport().get_visible_rect().size
		var w := page.x
		var h := page.y
		var bar := h * 0.5 * (HEIGHT_BIG if big else HEIGHT)
		var sl := w * SLANT
		var gut := h * GUTTER
		# Both bars close toward the left, as the POC's panel does.
		var top_l := bar + sl
		var top_r := bar - sl
		var bot_l := h - bar - sl
		var bot_r := h - bar + sl
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, top_r), Vector2(0, top_l)]), ComicFx.INK)
		draw_colored_polygon(PackedVector2Array([Vector2(0, top_l), Vector2(w, top_r), Vector2(w, top_r + gut), Vector2(0, top_l + gut)]), ComicFx.PAPER)
		draw_colored_polygon(PackedVector2Array([Vector2(0, h), Vector2(0, bot_l), Vector2(w, bot_r), Vector2(w, h)]), ComicFx.INK)
		draw_colored_polygon(PackedVector2Array([Vector2(0, bot_l - gut), Vector2(w, bot_r - gut), Vector2(w, bot_r), Vector2(0, bot_l)]), ComicFx.PAPER)
