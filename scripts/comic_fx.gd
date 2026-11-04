class_name ComicFx
extends CanvasLayer
## Comic combat text (Game.comic_style only, added by main): onomatopoeia on hits that
## escalate with the chain tier (Fx.CHAIN_TIERS). The port of comic_poc/comic_vfx.py `word`.
## Everything steps on twos at 24 fps and runs on real time, so hitstop doesn't hold it.
## Sits under the HUD (layer 0) so words never cover health or the combo count.
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
const WORD_GAP_HERETIC_MS := 240  # his moves hit whole crowds at once
const WORD_RISE_PX := 1.3  # per frame
const WORD_HEAD := 1.6  # metres above the foe's feet
const WORD_JITTER := 34.0
const WORD_TILT := 0.11
const WORD_ALPHA_REDUCED := 0.8
## The signature moves' own words (by move id), said on the move's first hit instead of a generic one,
## sized by its combo tier (player.COMBOS) plus the chain; the breakers' words on landing, biggest of all.
const MOVE_WORDS := {
	"EC": "FWOOSH!", "EE": "ZZZAKT!", "EW": "KZZRAAK!",  # wind
	"EF": "THUNK!", "EA": "KLONK!", "IP": "SHKKT!", "IS": "KRRSSH!",  # water
	"EM": "KA-POW!", "EV": "GLORP!",  # earth
	"VS": "VWOOM!", "VR": "SHUNK!", "VD": "SPLOOSH!", "OW": "SKRONCH!", "TW": "YOINK!",  # dark
}
const BREAKER_WORDS := {
	"Grounded": "KRA-KOOM!", "Worldbreaker": "KRAKATHOOM!", "Cold Front": "SHKRAASH!", "Meteor Fall": "KA-THOOOM!",
	"Collapse": "SHLUMPF!", "Maw": "CHOMP!", "Abyss": "SKRUNNCH!",
}
const BREAKER_SCALE := 1.0
## Words go ahead of the hero, in the emptiest of these directions (degrees off the way to the hit).
const SPOT_ANGLES := [0.0, -35.0, 35.0, -70.0, 70.0, -110.0, 110.0, 180.0]
const SPOT_TURN_COST := 0.5  # px of clearance a degree of turning away from ahead costs
const SPOT_RINGS := [75.0, 170.0]  # px from the hero's middle to the word's edge
const SPOT_FAR_COST := 30.0  # px of clearance the outer ring costs
const SPOT_ENOUGH := 220.0  # px of clearance that's as good as any more
const HERO_PAD_PX := 55.0
const FOE_PAD_PX := 40.0  # a foe counts as this big round its chest
const CALLOUT_HALF_H_PX := 28.0  # the hero's combo-name callout, half its height
const PROMPT_HALF_PX := Vector2(62.0, 62.0)  # the breaker prompt's circle and its name under it
const BLOCK_OVERLAP_COST := 60.0  # px: sitting on top of something is worse than just touching it
const SAME_FRAME_MS := 60  # a signature word replaces a generic one born this recently
# Keeps a word on the page, as comic_vfx._on_page: side margin, top and bottom bands.
const PAGE_MARGIN := Vector2(0.1, 0.14)

static var _inst: ComicFx

var _font: Font
var _words: Array[Label] = []
var _born: Array[int] = []  # ms, per word; 0 = free
var _next := 0
var _last_word_ms := -100000
var _move_seen := ""  # the hero's move whose word has been said
var _breakers_seen := 0


## A hit landed at `world`.
static func hit(world: Vector3, big: bool) -> void:
	if _inst != null:
		_inst._word(world, mini(Fx.chain_tier(Game.combo_count) + (1 if big else 0), WORDS.size() - 1))


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
	if now - _last_word_ms < (WORD_GAP_REDUCED_MS if reduced else WORD_GAP_HERETIC_MS):
		return
	_last_word_ms = now
	var i := _next
	_next = (_next + 1) % POOL
	var l := _words[i]
	var options: Array = WORDS[tier]
	l.text = options.pick_random()
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	_show(i, world, WORD_SCALE[tier])


## Puts word `i` up at `base` scale, in empty space near the hero on the way to `world`.
func _show(i: int, world: Vector3, base: float) -> void:
	var l := _words[i]
	var reduced := Game.reduce_flashing
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	var at := _place(world, l.size * base, i)
	l.position = at - l.size * 0.5
	l.rotation = WORD_TILT * (1.0 if randf() < 0.5 else -1.0)
	l.modulate.a = WORD_ALPHA_REDUCED if reduced else 1.0
	l.set_meta("base", base)
	l.set_meta("y", l.position.y)
	l.set_meta("reduced", reduced)
	l.scale = Vector2.ONE * base * word_scale(0, reduced)
	l.visible = true
	_born[i] = maxi(Time.get_ticks_msec(), 1)


## Where a word of `size_px` goes: beside the hero, turned from the way to the hit towards whichever
## side has the most room, clear of the foes and the other words. With no hero, over the hit.
func _place(world: Vector3, size_px: Vector2, me: int) -> Vector2:
	var hit := _to_screen(world)
	var cam := get_viewport().get_camera_3d()
	var hero := get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	if cam == null or hero == null:
		return _on_page(hit + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * WORD_JITTER, size_px)
	var body: Node3D = hero.model if "model" in hero and is_instance_valid(hero.model) else hero
	var h := _screen_of(cam, body.global_position + Vector3.UP * 1.0)
	var toward := hit - h
	if toward.length() < 20.0:  # a hit on top of him: the way he faces
		var f: Vector3 = hero._facing() if hero.has_method("_facing") else hero.global_basis.z
		toward = _screen_of(cam, hero.global_position + Vector3.UP * 1.0 + f) - h
	toward = toward.normalized() if toward.length() > 0.01 else Vector2.UP
	# Everything a word must keep clear of, as screen rects: the hero, each foe, the live words, his
	# combo-name callout and the breaker prompt.
	var blocks: Array[Rect2] = [_pad_rect(h, HERO_PAD_PX)]
	for e: Node3D in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not cam.is_position_behind(e.global_position):
			blocks.append(_pad_rect(cam.unproject_position(e.global_position + Vector3.UP * 1.0), FOE_PAD_PX))
	blocks.append_array(_text_blocks(cam, hero, me))
	var best := Vector2.ZERO
	var best_score := -INF
	var half := size_px * 0.5
	for ring in SPOT_RINGS.size():
		for deg: float in SPOT_ANGLES:
			var v := toward.rotated(deg_to_rad(deg))
			var c := _on_page(h + v * (SPOT_RINGS[ring] + absf(v.x) * half.x + absf(v.y) * half.y), size_px)
			var clear := SPOT_ENOUGH
			for b: Rect2 in blocks:
				var bc := b.get_center()
				var dx := maxf(absf(bc.x - c.x) - half.x - b.size.x * 0.5, 0.0)
				var dy := maxf(absf(bc.y - c.y) - half.y - b.size.y * 0.5, 0.0)
				clear = minf(clear, Vector2(dx, dy).length() - (BLOCK_OVERLAP_COST if dx == 0.0 and dy == 0.0 else 0.0))
			var score := clear - absf(deg) * SPOT_TURN_COST - ring * SPOT_FAR_COST
			if score > best_score:
				best_score = score
				best = c
	return best


## The screen rects of the text a word or a damage number must keep off: the live words (but `me`), the
## hero's combo-name callout (a line per line of it, so a "PERFECT" under the name counts) and the breaker prompt.
func _text_blocks(cam: Camera3D, hero: Node, me := -1) -> Array[Rect2]:
	var blocks: Array[Rect2] = []
	for k in POOL:
		if k != me and _born[k] != 0:
			var ws: Vector2 = _words[k].size * float(_words[k].get_meta("base", 1.0))
			blocks.append(Rect2(_words[k].position + _words[k].size * 0.5 - ws * 0.5, ws))
	if hero == null:
		return blocks
	var callout: Variant = hero.get("_callout")
	if callout is Label3D and callout.is_visible_in_tree() and not cam.is_position_behind(callout.global_position):
		var half_m: float = callout.get_aabb().size.x * 0.5 * callout.global_basis.get_scale().x
		var mid := cam.unproject_position(callout.global_position)
		var half_px := absf(cam.unproject_position(callout.global_position + cam.global_basis.x * half_m).x - mid.x)
		var half_h := CALLOUT_HALF_H_PX * float(callout.text.count("\n") + 1)
		blocks.append(Rect2(mid - Vector2(half_px, half_h), Vector2(half_px, half_h) * 2.0))
	var prompt: Variant = hero.get("_brk_prompt")
	if prompt is Control and is_instance_valid(prompt) and prompt.get("_shown") == true:
		blocks.append(Rect2(prompt.center - PROMPT_HALF_PX * Vector2(1.0, 0.8), PROMPT_HALF_PX * 2.0))
	return blocks


## _text_blocks for anyone else (ComicNumber), [] with the comic style off.
static func text_blocks() -> Array[Rect2]:
	if _inst == null or not _inst.is_inside_tree():
		return []
	var cam := _inst.get_viewport().get_camera_3d()
	if cam == null:
		return []
	return _inst._text_blocks(cam, _inst.get_tree().get_first_node_in_group("player"))


func _pad_rect(p: Vector2, pad: float) -> Rect2:
	return Rect2(p - Vector2.ONE * pad, Vector2.ONE * pad * 2.0)


func _screen_of(cam: Camera3D, p: Vector3) -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5 if cam.is_position_behind(p) else cam.unproject_position(p)


## A signature move's or breaker's word, replacing a generic word that came up with the same hit.
func _say(text: String, world: Vector3, base: float) -> void:
	var now := Time.get_ticks_msec()
	for k in POOL:
		if _born[k] != 0 and now - _born[k] <= SAME_FRAME_MS and _words[k].get_meta("base", 0.0) < base:
			_words[k].visible = false
			_born[k] = 0
	_last_word_ms = now
	var i := _next
	_next = (_next + 1) % POOL
	_words[i].text = text
	_show(i, world, base)


## Watches the hero (read only): a signature move's first hit, a breaker landing.
func _watch_hero() -> void:
	var hero := get_tree().get_first_node_in_group("player")
	if hero == null or not "_move_id" in hero:
		return
	var id: String = hero._move_id
	if hero._hits_done == 0:
		_move_seen = ""
	elif id != _move_seen:
		_move_seen = id
		if MOVE_WORDS.has(id):
			var tier: int = hero.COMBOS[id].tier if hero.COMBOS.has(id) else 1
			tier = mini(tier + (1 if Fx.chain_tier(Game.combo_count) >= 2 else 0), WORD_SCALE.size() - 1)
			_say(MOVE_WORDS[id], hero.global_position + hero._facing() * 2.0, WORD_SCALE[tier])
	if hero.breakers_landed > _breakers_seen:
		_breakers_seen = hero.breakers_landed
		var word: String = BREAKER_WORDS.get(hero.breaker_name(), "")
		if word != "":
			_say(word, hero.global_position, BREAKER_SCALE)


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


func _process(_delta: float) -> void:
	_watch_hero()
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


## Whole frames at FPS, held on twos.
static func _frame(age_ms: int) -> int:
	return int(age_ms / 1000.0 * FPS) / 2 * 2
