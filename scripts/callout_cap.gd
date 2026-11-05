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
	if _fade_from_ms < 0:
		var next_string: bool = STANDING._start_ms > _shown_ms  # the next string has started since it went up
		if now - _shown_ms < HOLD_S * 1000.0 and not next_string:
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
