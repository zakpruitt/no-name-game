class_name ComicFx
extends CanvasLayer
## Comic combat text (Game.comic_style only, added by main): onomatopoeia on hits that
## escalate with the chain tier (Fx.CHAIN_TIERS). The port of comic_poc/comic_vfx.py `word`.
## Everything steps on twos at 24 fps and runs on real time, so hitstop doesn't hold it.
## Sits under the HUD (layer 0) so words never cover health or the combo count.
## The static calls do nothing when no instance exists, i.e. with the flag off.

const STANDING := preload("res://scripts/standing_fx.gd")
const COMIC_DUST := preload("res://scripts/comic_dust.gd")
const CALLOUT_CAP := preload("res://scripts/callout_cap.gd")
const AWAKEN_FLOURISH := preload("res://scripts/awaken_flourish.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const NUMBER := preload("res://scripts/comic_number.gd")
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
## Round 33 (sleek; Zak: "sleeker and more put together"): words a quarter smaller with an ink line half as
## thick and a tighter print offset, and gone in 14 frames (0.58 s) instead of 20 (0.83 s).
const WORD_SCALE := [0.32, 0.4, 0.5, 0.64]
const WORD_FRAMES := 14
const OUTLINE_DIV := 9  # FONT_SIZE / this: the ink line (was / 4)
const POOL := 6
# Words can't stack into noise on a crowd: at most one per gap.
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
	"XR": "KRUNCH!", "XF": "SKRRRAK!", "XS": "PSSHHHH!", "XT": "ZZWANNG!", "XC": "BZZRAKK!",  # crossovers (round 37)
	"XG": "WHIRRRL!", "XM": "SIZZ-BLAM!", "XK": "KSHUNK!", "XW": "FWHOOOM!",  # three-element strings (round 37, second pass)
	"XL": "SHLURK-FWOOM!",  # Lava Leash (dark-magma lane): said on the seam's eruption (LATE_WORDS)
}
const BREAKER_WORDS := {
	"Grounded": "KRA-KOOM!", "Short Circuit": "KZZZT-KRAK!", "Worldbreaker": "KRAKATHOOM!", "Cold Front": "SHKRAASH!", "Meteor Fall": "KA-THOOOM!",
	"Collapse": "SHLUMPF!", "Maw": "CHOMP!", "Abyss": "SKRUNNCH!",
	"Cataclysm": "KRAKA-DOOM!", "Flash Freeze": "FSSSH-KRAK!", "Black Ice": "KLISSSH!",
	"Eruption": "KA-BLOOOSH!", "Anvil": "KLANNNG!",
	"Shatterstorm": "KRSSSH-BOOM!", "Slapshot": "THWAKK!",  # round 47 b (Slapshot's wall hits say slapshot_fx.WALL_WORD)
	"Ricochet": "KA-SPLATT!",  # the dash counter's ending (counter.gd)
	"Meteor Shower": "BLAM-BLAM-BLAMM!", "Pinwheel": "WHIRRR-KRAK!", "Tempest": "VWOOOM-KZZAK!",  # breaker-pairs (Pinwheel's wall hits say breaker_alt_fx.WALL_WORD)
	"Hellseam": "KRAKA-FWOOOM!",  # dark-magma lane
	"Uproot": "KRR-RACK-THOOM!",  # env-pieces lane (Abyss's LMB)
}
const BREAKER_SCALE := 0.78
## The element matrix's payoffs (void_element.IMPROV; comic_improv.gd draws each cell's tell), by cell: said over the
## move's own word (ComicFx.improv), since the payoff is the news.
const IMPROV_WORDS := {
	"frozen_x_wind": "FWISSH!", "frozen_x_void": "SHA-KRAK!",
	"buried_x_water": "KRRIK!", "buried_x_earth": "BA-DOOM!", "buried_x_void": "GULP!",
	"molten_x_wind": "FWAAASH!", "molten_x_water": "HSSSSK!", "molten_x_earth": "FWUMP!", "molten_x_void": "SMOOSH!",
	"skewered_x_water": "KRIK-KRIK!", "skewered_x_void": "RRRIP!",
	"airborne_x_water": "FRZZK!", "airborne_x_earth": "KA-CHUNK!",
	"bound_x_wind": "SNAPP!", "bound_x_water": "KLINNK!",
	"charged_x_void": "BZZT-ZAP!", "charged_x_water": "KRZZZK!", "charged_x_earth": "FWA-KOOM!", "charged_x_wind": "ZZRAAAK!",
	# The six rules (round 49, void_element.RULES; the cells above are the upgrade cells').
	"frozen": "SHA-KRASH!", "charged": "ZZAK-ZAK!", "molten": "FWOOMPH!", "bound": "SNAP!", "airborne": "WHAP-UP!", "buried": "KA-THOOM!",
}
const IMPROV_SCALE := 0.5  # (WORD_SCALE's tier 2)
## Moves whose word is said by the move itself, later than its first hit (say()): Galvanize's on its discharge.
const LATE_WORDS := ["XC", "XL", "XR", "IS", "XM", "OW", "VD"]  # round 55 (combo-cool4): the rebuilt mids say theirs on their beat (void_element)
const IMPROV_HOLD_MS := 300  # the move's own word stays quiet this long after a payoff's
## Words sit at the blow (feel audit 2026-11-04 item 2: placed 2-4 m off in clear floor they read as
## captions): round the contact point, in the clearest of these directions (degrees off the way from
## the hero to the hit), on the near ring unless it is covered.
const SPOT_ANGLES := [0.0, -35.0, 35.0, -70.0, 70.0, -110.0, 110.0, 180.0]
const SPOT_TURN_COST := 0.25  # px of clearance a degree of turning away from ahead costs
const SPOT_RINGS := [12.0, 55.0]  # px from the contact point to the word's edge
const SPOT_FAR_COST := 40.0  # px of clearance the outer ring costs
const SPOT_ENOUGH := 24.0  # px of clearance that's as good as any more: it never wanders off for room
const HIT_FRESH_MS := 120  # a signature word sits at the last generic hit's contact if it was this recent
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
var _last_text := ""  # the last word said: the next generic word is never the same
var _hit_world := Vector3.ZERO  # the last hit's contact (world) and when (ms)
var _hit_ms := -100000
## One word on the page at a time (item 2): a new word replaces the live one. Off in the look tests' lineups.
var replace := true
var _breakers_seen := 0
var _improv_ms := -100000
var _brk_word_ms := -100000  # the last breaker word said

## Impact lane (spar audit 2026-11-07 item 10): a kill under an impact frame (the kill's own grey negative, or a
## breaker's) had its kill star washed out and nothing else said it died. The frame draws on layer -1, under this
## layer, so the kill word KILL_WORD goes up on the frame itself; the kill star pops again, bigger, once the frame has
## cleared (Game.impact.current() back to 0, at most KILL_STAR_WAIT_MS). A breaker word this fresh keeps the page
## (KILL_QUIET_MS): the re-popped star carries that kill.
const KILL_WORD := "K.O.!"
const KILL_SCALE := 0.7
const KILL_QUIET_MS := 250
const KILL_STAR_WAIT_MS := 260
const KILL_STAR_SIZE := 1.8  # x designed_fx.HIT_SIZE (Fx.death's star is 1.3, 1.6 for an elite)
const KILL_STAR_UP := 0.9
var _kills: Array = []  # [foe, ms, last position] waiting for the frame to clear
static var kill_words := 0  # (breaker_spectacle_check)
static var kill_stars := 0
## Impact lane (feel audit 7 item 8): a word placed before a name callout went up, or before the breaker banner opened
## (FAULT LINE over KRUNCH!, BLACK TIDE over SPLOOSH!, SHLUMPF! on COLLAPSE's PERFECT!), stayed under it: the name
## lifts to the top band in the hang, and the banner opens a frame after the landing word. Every frame each live word
## is checked against the hero's name callout and the open banner and moved clear of them (below a block in the top
## half of the screen, above one in the bottom half), RELAY_PAD px off.
const RELAY_PAD := 6.0
static var relaid := 0  # words moved off a name or the banner (breaker_spectacle_check)


## An element-matrix payoff (comic_improv.gd) on the foe at `world`: its cell's word, once a move however many pay.
static func improv(cell: String, world: Vector3) -> void:
	if _inst == null or not IMPROV_WORDS.has(cell):
		return
	var now := Time.get_ticks_msec()
	if now - _inst._improv_ms <= SAME_FRAME_MS:
		return
	_inst._improv_ms = now
	_inst._say(IMPROV_WORDS[cell], world, IMPROV_SCALE)


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
	Game.enemy_killed.connect(_on_killed)


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
	l.add_theme_constant_override("outline_size", FONT_SIZE / OUTLINE_DIV)
	# The print-offset second colour: a hard red shadow, inked too.
	l.add_theme_color_override("font_shadow_color", WORD_LOW)
	l.add_theme_constant_override("shadow_offset_x", FONT_SIZE / 32)
	l.add_theme_constant_override("shadow_offset_y", FONT_SIZE / 24)
	l.add_theme_constant_override("shadow_outline_size", 0)
	add_child(l)
	return l


func _word(world: Vector3, tier: int) -> void:
	var now := Time.get_ticks_msec()
	_hit_world = world
	_hit_ms = now
	var reduced := Game.reduce_flashing
	if now - _last_word_ms < (WORD_GAP_REDUCED_MS if reduced else WORD_GAP_HERETIC_MS):
		return
	_last_word_ms = now
	var i := _next
	_next = (_next + 1) % POOL
	var l := _words[i]
	var options: Array = WORDS[tier].filter(func(w: String) -> bool: return w != _last_text)
	l.text = options.pick_random()
	_last_text = l.text
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	_show(i, world, WORD_SCALE[tier])


## Puts word `i` up at `base` scale, in empty space near the hero on the way to `world`.
func _show(i: int, world: Vector3, base: float) -> void:
	var l := _words[i]
	l.add_theme_constant_override("outline_size", PAL.text_ink(base))  # the hit's ink weight, at any tier
	var reduced := Game.reduce_flashing
	if replace:
		for k in POOL:
			if k != i and _born[k] != 0:
				_words[k].visible = false
				_born[k] = 0
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	var at := _place(world, l.size * base, i)
	l.position = at - l.size * 0.5
	l.rotation = WORD_TILT * (1.0 if randf() < 0.5 else -1.0)
	l.modulate.a = WORD_ALPHA_REDUCED if reduced else 1.0
	l.set_meta("base", base)
	l.set_meta("y", l.position.y)
	l.set_meta("reduced", reduced)
	l.remove_meta("relaid")  # (a pooled label: the next word may need moving again)
	l.scale = Vector2.ONE * base * word_scale(0, reduced)
	l.visible = true
	_born[i] = maxi(Time.get_ticks_msec(), 1)
	if is_inside_tree():
		_relay(get_tree().get_first_node_in_group("player"))  # (said after this frame's _process: clear of the name now)


## Where a word of `size_px` goes: at the contact point (`world` raised WORD_HEAD), turned from the way
## the hero hit towards whichever side is clear of him, the foes and the other text. With no hero, over the hit.
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
			var c := _on_page(hit + v * (SPOT_RINGS[ring] + absf(v.x) * half.x + absf(v.y) * half.y), size_px)
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
	if NUMBER.banner_open and NUMBER.banner_rect.size.x > 0.0:  # round 56 (feel-audit6): the breaker banner and its tag
		blocks.append(NUMBER.banner_rect)  # (Collapse's -FTOOO! and Meteor Shower's BLAMM sat on its PERFECT!)
	if hero == null:
		return blocks
	var name_rect := _callout_rect(cam, hero)
	if name_rect.size.x > 0.0:
		blocks.append(name_rect)
	var prompt: Variant = hero.get("_brk_prompt")
	if prompt is Control and is_instance_valid(prompt) and prompt.get("_shown") == true:
		blocks.append(Rect2(prompt.center - PROMPT_HALF_PX * Vector2(1.0, 0.8), PROMPT_HALF_PX * 2.0))
	return blocks


## The hero's name callout on screen (Rect2() when none shows: hidden, or left undrawn for the banner).
func _callout_rect(cam: Camera3D, hero: Node) -> Rect2:
	var callout: Variant = hero.get("_callout") if hero != null else null
	if not callout is Label3D or not callout.is_visible_in_tree() or (callout as Label3D).modulate.a < 0.05:
		return Rect2()
	if cam.is_position_behind(callout.global_position):
		return Rect2()
	var half_m: float = callout.get_aabb().size.x * 0.5 * callout.global_basis.get_scale().x
	var mid := cam.unproject_position(callout.global_position)
	var half_px := absf(cam.unproject_position(callout.global_position + cam.global_basis.x * half_m).x - mid.x)
	var half_h := CALLOUT_HALF_H_PX * float(callout.text.count("\n") + 1)
	return Rect2(mid - Vector2(half_px, half_h), Vector2(half_px, half_h) * 2.0)


## Live word `i`'s drawn rect (its label scaled about its middle).
func word_rect(i: int) -> Rect2:
	var l := _words[i]
	var ws := l.size * l.scale
	return Rect2(l.position + l.size * 0.5 - ws * 0.5, ws)


## Moves each live word off the name callout and the open banner (item 8 above).
func _relay(hero: Node) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var blocks: Array[Rect2] = []
	var name_rect := _callout_rect(cam, hero)
	if name_rect.size.x > 0.0:
		blocks.append(name_rect)
	if NUMBER.banner_open and NUMBER.banner_rect.size.x > 0.0:
		blocks.append(NUMBER.banner_rect)
	if blocks.is_empty():
		return
	var mid_y := get_viewport().get_visible_rect().size.y * 0.5
	for i in POOL:
		if _born[i] == 0:
			continue
		for b: Rect2 in blocks:
			var r := word_rect(i)
			if not r.intersects(b):
				continue
			var dy := (b.end.y + RELAY_PAD - r.position.y) if b.get_center().y < mid_y else (b.position.y - RELAY_PAD - r.end.y)
			_words[i].position.y += dy
			_words[i].set_meta("y", float(_words[i].get_meta("y")) + dy)
			if not _words[i].has_meta("relaid"):
				_words[i].set_meta("relaid", true)
				relaid += 1


## A foe died (Game.enemy_killed; game.gd's kill frame has already fired by now).
func _on_killed(e: Node) -> void:
	var foe := e as Node3D
	if foe == null or not is_inside_tree() or Game.impact == null or Game.impact.current() <= 0.0:
		return  # (no frame up: the kill's own star reads)
	var now := Time.get_ticks_msec()
	if now - _brk_word_ms > KILL_QUIET_MS:
		_say(KILL_WORD, foe.global_position, KILL_SCALE)
		kill_words += 1
	_kills.append([foe, now, foe.global_position])


## The kill stars waiting for the frame to clear.
func _kill_tick() -> void:
	var now := Time.get_ticks_msec()
	var left: Array = []
	for k: Array in _kills:
		var foe: Variant = k[0]
		var alive := is_instance_valid(foe) and (foe as Node).is_inside_tree()
		if Game.impact.current() > 0.0 and now - int(k[1]) < KILL_STAR_WAIT_MS:
			if alive:
				k[2] = (foe as Node3D).global_position
			left.append(k)
			continue
		var parent: Node = (foe as Node).get_parent() if alive else get_tree().current_scene
		if parent == null:
			continue
		var at: Vector3 = (foe as Node3D).global_position if alive else k[2]
		kill_stars += 1
		var designed: GDScript = load("res://scripts/designed_fx.gd")
		if designed.on():
			var star: Node3D = designed.spawn(parent, "hit_spark", at + Vector3.UP * KILL_STAR_UP, designed.HIT_SIZE * KILL_STAR_SIZE,
				"hit", load("res://scripts/designed_ink.gd").KILL_TIMES, Vector2(0.55, 1.0))
			star.real_time = true
			star.pop = 0.25
			star.vary(PI, true)
		else:
			Fx.death(parent, at, Vector3.ZERO, true)
	_kills = left


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
	_last_text = text
	var i := _next
	_next = (_next + 1) % POOL
	_words[i].text = text
	_show(i, world, base)


## Watches the hero (read only): a signature move's first hit, a breaker landing.
func _watch_hero() -> void:
	var hero := get_tree().get_first_node_in_group("player")
	if hero == null or not "_move_id" in hero:
		return
	STANDING.watch(hero)  # the last string's floor fades on this one's first hit
	COMIC_DUST.watch(hero)  # a puff (and skid marks) on his run start, skid and dodge
	CALLOUT_CAP.watch(hero)  # the combo / breaker name over him fades on real time, and on the next string
	AWAKEN_FLOURISH.note(hero)  # when his breakers land: the Awakening flourish waits past one
	var id: String = hero._move_id
	if hero._hits_done == 0:
		_move_seen = ""
	elif id != _move_seen:
		_move_seen = id
		if MOVE_WORDS.has(id) and not id in LATE_WORDS and Time.get_ticks_msec() - _improv_ms > IMPROV_HOLD_MS:
			var tier: int = hero.COMBOS[id].tier if hero.COMBOS.has(id) else 1
			tier = mini(tier + (1 if Fx.chain_tier(Game.combo_count) >= 2 else 0), WORD_SCALE.size() - 1)
			var at: Vector3 = _hit_world if Time.get_ticks_msec() - _hit_ms <= HIT_FRESH_MS else hero.global_position + hero._facing() * 1.4
			_say(MOVE_WORDS[id], at, WORD_SCALE[tier])
	if hero.breakers_landed > _breakers_seen:
		_breakers_seen = hero.breakers_landed
		var word: String = BREAKER_WORDS.get(hero.HERO_LEAP.breaker_name(hero), "")
		if word != "":
			_say(word, hero.global_position, BREAKER_SCALE)
			_brk_word_ms = Time.get_ticks_msec()


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
	if not _kills.is_empty():
		_kill_tick()
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
	_relay(get_tree().get_first_node_in_group("player"))


## Whole frames at FPS, held on twos.
static func _frame(age_ms: int) -> int:
	return int(age_ms / 1000.0 * FPS) / 2 * 2


## A word said by a move on its own beat (LATE_WORDS: Galvanize's discharge), `base` its size (WORD_SCALE units).
static func say(text: String, world: Vector3, base: float) -> void:
	if _inst != null:
		_inst._say(text, world, base)
