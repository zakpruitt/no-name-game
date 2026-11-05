extends RefCounted
## Round 33, sleek 4 (nothing lingering): the combo-name / breaker-name callout over the hero (player._callout,
## raised by player._combo_callout and hero_leap._callout) fades on its tween, which runs on game time. Hitstop
## and a breaker's slow motion stretched it: CATACLYSM / ABYSS / GROUNDED PERFECT hung 1-1.3 s into the next
## string and FLASH FREEZE PERFECT for 5 s. ComicFx calls `watch(hero)` every frame (no edit to the hero's
## files): a new callout is a new `_callout_tw`; after HOLD_S of real time, or as soon as the next string starts
## (standing_fx's start), it fades over FADE_S real s and hides.
##   const CALLOUT_CAP := preload("res://scripts/callout_cap.gd")
##   CALLOUT_CAP.watch(hero)

const STANDING := preload("res://scripts/standing_fx.gd")
const HOLD_S := 0.95  # real s a callout stays whole (its own tween at full speed ends at 0.8-1.0 s)
const FADE_S := 0.15  # real s it fades once capped

static var _tw_id := 0  # the instance id of the callout tween we're timing
static var _shown_ms := 0
static var _fade_from_ms := -1  # when the cap's fade started (-1: not capped)
static var _alpha0 := 1.0
static var capped := 0  # callouts cut short (fx_sleek_check)

## Round 33, sleek 6: a breaker's name (hero_leap._callout: WORLDBREAKER / PERFECT) went up over his head as he
## landed on the pile, so in most of the densest frames it sat on the foes. A breaker callout is moved to the top
## band of the screen, centred, where the HUD's AIRBORNE / PERFECT announcements are (hud.ANNOUNCE_Y 0.2), just above
## them, and held BREAKER_HOLD_S real s. The combo-name callout (player._combo_callout) stays over him.
const BREAKER_Y := 0.11  # of the screen height: the name's middle (the announcements' row is 0.2)
const BREAKER_HOLD_S := 0.6  # real s whole, then FADE_S
const BREAKER_SCALE := 0.85  # of the label's scale, settled (it pops from BREAKER_POP)
const BREAKER_POP := 1.25
const BREAKER_POP_S := 0.12  # real s
static var _is_breaker := false
static var breakers_placed := 0  # breaker callouts moved to the top band (fx_sleek_check)
static var _names := {}

## Feel audit 2, item 3: a name popped over him on every named move (DASH STAB, HARPOON, ICE CUBE...), so every
## beat had a name plus a word plus a number on him. A name now goes up only for an ender (a move with a breaker:
## void_element.BREAKERS), a crossover (`X*`, the string's element change paying off) and the breakers' own names;
## the light mids keep their word (ComicFx.MOVE_WORDS) and lose the name and its stroke pop (Fx.combo_pop).
static var muted := 0  # mid callouts taken down (fx_sleek_check)
static var _named := {}  # COMBOS names that still go up


## Does this COMBOS id get its name over him? Enders and crossovers.
static func names_move(id: String) -> bool:
	return id.begins_with("X") or load("res://scripts/void_element.gd").BREAKERS.has(id)


## Is this callout text the name of a move that gets one (names_move)?
static func is_named_text(hero: Node, text: String) -> bool:
	if _named.is_empty() and "COMBOS" in hero:
		for id: String in hero.COMBOS:
			if names_move(id):
				_named[hero.COMBOS[id].name] = true
	return _named.has(text.get_slice("\n", 0))


## Is this callout text a breaker's name (its first line)?
static func is_breaker_text(text: String) -> bool:
	if _names.is_empty():
		var breakers: Dictionary = load("res://scripts/void_element.gd").BREAKERS  # (load, not preload: a preload cycle leaks at exit)
		for id: String in breakers:
			var b: Dictionary = breakers[id]
			for n: String in b.names.values():
				_names[n] = true
			if b.has("alt"):
				for n: String in b.alt.get("names", {}).values():
					_names[n] = true
	return _names.has(text.get_slice("\n", 0))


## Where on screen a breaker callout sits, in world space at the hero's depth (Label3D billboards keep their size).
static func _place(hero: Node, label: Label3D, now: int) -> void:
	var cam := label.get_viewport().get_camera_3d() if label.is_inside_tree() else null
	if cam == null:
		return
	var vp := label.get_viewport().get_visible_rect().size
	var depth: float = (hero.global_position - cam.global_position).dot(-cam.global_basis.z)
	label.global_position = cam.project_position(Vector2(vp.x * 0.5, vp.y * BREAKER_Y), maxf(depth, 1.0))
	var k := clampf((now - _shown_ms) / (BREAKER_POP_S * 1000.0), 0.0, 1.0)
	label.scale = Vector3.ONE * BREAKER_SCALE * lerpf(BREAKER_POP, 1.0, k)


static func watch(hero: Node) -> void:
	var label: Variant = hero.get("_callout")
	if not label is Label3D or not label.visible:
		_fade_from_ms = -1
		return
	var now := Time.get_ticks_msec()
	var tw: Variant = hero.get("_callout_tw")
	var id: int = tw.get_instance_id() if tw is Tween else 0
	if id != _tw_id:  # a new callout
		_tw_id = id
		_shown_ms = now
		_fade_from_ms = -1
		_is_breaker = is_breaker_text(label.text)
		if not _is_breaker and not is_named_text(hero, label.text):
			muted += 1
			if tw is Tween and tw.is_valid():
				tw.kill()
			label.hide()  # (before it draws: ComicFx's _process runs ahead of the frame)
			return
		if _is_breaker:
			breakers_placed += 1
			if tw is Tween and tw.is_valid():
				tw.kill()  # (it tweens position and scale over his head)
	if _is_breaker:
		_place(hero, label, now)
	if _fade_from_ms < 0:
		var next_string: bool = STANDING._start_ms > _shown_ms  # the next string has started since it went up
		var hold: float = BREAKER_HOLD_S if _is_breaker else HOLD_S
		if now - _shown_ms < hold * 1000.0 and not next_string:
			return
		_fade_from_ms = now
		_alpha0 = label.modulate.a
		capped += 1
		if tw is Tween and tw.is_valid():
			tw.kill()  # (its own fade would fight ours)
	var k := clampf((now - _fade_from_ms) / (FADE_S * 1000.0), 0.0, 1.0)
	label.modulate.a = _alpha0 * (1.0 - k)
	if k >= 1.0:
		label.hide()
		_fade_from_ms = -1
