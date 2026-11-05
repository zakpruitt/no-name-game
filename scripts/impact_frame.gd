extends CanvasLayer
## Comic-style impact frame: on a big hit or a kill the scene view flips for a
## few real-time frames into a high-contrast negative (ink where it was light,
## paper where it was dark) with a dark vignette, then fades. One ColorRect
## reading the screen, on layer -1 (above the 3D view, under every HUD layer),
## owned by the Game autoload. It is saved for slams and kills (feel audit
## 2026-11-04 item 1: on every ender it flipped about every 1.2 s): a combo
## breaker's landing (watched here: the hero's breakers_landed goes up),
## Game.enemy_killed, and hitstops of IMPACT_STOP or more, which is above any
## ender's stop (move stop x1.3 airborne + ENDER_HITSTOP per tier, ~0.23 s) and
## Awakening's 0.25 s, so only the last kill's slow motion and the like qualify. With
## Game.reduce_flashing the negative is dropped and only a soft vignette
## pulse remains (and kills get nothing). The vignette leans the way the last
## blow went (Game.last_hit_dir) and its ink takes a dark tone of his element.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength = 0.0;
uniform float invert = 1.0;
uniform vec3 ink : source_color = vec3(0.06, 0.03, 0.1);
uniform vec3 paper : source_color = vec3(1.0, 0.95, 0.82);
uniform vec2 dir = vec2(0.0);  // screen direction of the blow (UV units, y down); zero = centred
uniform vec3 tint : source_color = vec3(0.06, 0.03, 0.1);  // the vignette's ink, toned by his element
void fragment() {
	vec3 col = textureLod(screen, SCREEN_UV, 0.0).rgb;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 two = mix(paper, ink, smoothstep(0.3, 0.7, l));
	vec3 c = mix(col, two, strength * invert);
	// The vignette's middle sits back against the blow, so the ink piles up on the side it went.
	float d = length((SCREEN_UV - 0.5 + dir) * vec2(1.4, 1.0));
	c = mix(c, tint, smoothstep(0.45, 1.05, d) * strength * 0.85);
	COLOR = vec4(c, 1.0);
}
"""
const IMPACT_STOP := 0.3  # hitstops this long (real s) or longer flash a frame: above every ender's stop
const IMPACT_FULL_STOP := 0.5  # a stop this long flashes at full strength (shorter ones scale down)
const IMPACT_MIN := 0.45  # strength of the lightest big-hit frame (an IMPACT_STOP stop)
const IMPACT_SLAM := 0.85  # a combo breaker's landing
const IMPACT_SLAM_PERFECT := 1.0  # a perfect one
const IMPACT_KILL := 0.4  # strength of a kill's frame
const IMPACT_HOLD := 0.05  # real seconds held at full strength (about three frames)
const IMPACT_FADE := 0.09  # real seconds fading out after the hold
const IMPACT_GAP_MS := 900  # no new frame closer than this to the last: one string never flips twice
const REDUCED_SCALE := 0.45  # strength multiplier with Game.reduce_flashing (vignette only)
const DIR_SHIFT := 0.2  # UV the vignette's middle moves back against the blow
const TINT_MIX := 0.5  # how far the vignette's ink goes to a dark tone of his element
const TINT_DARK := 0.5  # that tone: his element colour darkened this much
const INK := Color(0.06, 0.03, 0.1)

var rect: ColorRect
var _mat := ShaderMaterial.new()
var _strength := 0.0  # the frame's peak strength; 0 = idle
var _reduced := false
var _invert := 1.0  # what the shader's invert is set to (shader params can't be read back headless)
var _start_ms := 0
var _last_ms := -100000
var dir := Vector2.ZERO  # what the shader's dir is set to (read by impact_frame_check)
var tint := INK  # and its tint
var _breakers_seen := -1  # the hero's breakers_landed last frame (-1: not read yet)


func _ready() -> void:
	layer = -1
	var shader := Shader.new()
	shader.code = SHADER
	_mat.shader = shader
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _mat
	rect.visible = false
	add_child(rect)


## Flash a frame of `strength` (0..1). False when one just fired (IMPACT_GAP_MS)
## or it would show nothing. A hit's frame shows under reduce_flashing (softened,
## no negative); a kill's (`kill`) doesn't. `blow`: the hit's direction on screen
## (normalised, y down; zero for none), `element`: his colour (alpha 0 for none).
func flash(strength: float, kill := false, blow := Vector2.ZERO, element := Color(0, 0, 0, 0)) -> bool:
	var now := Time.get_ticks_msec()
	if strength <= 0.0 or now - _last_ms < IMPACT_GAP_MS:
		return false
	_reduced = Game.reduce_flashing
	if _reduced and kill:
		return false
	_last_ms = now
	_start_ms = now
	_strength = clampf(strength, 0.0, 1.0) * (REDUCED_SCALE if _reduced else 1.0)
	_invert = 0.0 if _reduced else 1.0
	_mat.set_shader_parameter("invert", _invert)
	tint = INK.lerp(element.darkened(TINT_DARK), TINT_MIX) if element.a > 0.0 else INK
	_mat.set_shader_parameter("tint", tint)
	lean(blow)
	_apply(_strength)
	return true


## Points the vignette against `blow` (screen, y down; zero centres it).
func lean(blow: Vector2) -> void:
	dir = blow.limit_length(1.0) * DIR_SHIFT
	_mat.set_shader_parameter("dir", dir)


## The frame fired by a hitstop of `duration` real seconds, if it is big enough.
func on_hitstop(duration: float, blow := Vector2.ZERO, element := Color(0, 0, 0, 0)) -> bool:
	if duration < IMPACT_STOP:
		return false
	return flash(lerpf(IMPACT_MIN, 1.0, clampf((duration - IMPACT_STOP) / (IMPACT_FULL_STOP - IMPACT_STOP), 0.0, 1.0)), false, blow, element)


## Strength showing right now (0 when idle).
func current() -> float:
	if _strength <= 0.0:
		return 0.0
	var t := (Time.get_ticks_msec() - _start_ms) * 0.001
	if t <= IMPACT_HOLD:
		return _strength
	return _strength * clampf(1.0 - (t - IMPACT_HOLD) / IMPACT_FADE, 0.0, 1.0)


## A combo breaker landed: the frame at slam strength, and the camera's ender FOV punch.
func slam(perfect: bool) -> bool:
	if not flash(IMPACT_SLAM_PERFECT if perfect else IMPACT_SLAM, false, Game.hit_dir_screen(), Game.hero_hit_color()):
		return false
	if Game.camera_rig and Game.camera_rig.has_method("fov_punch"):
		Game.camera_rig.fov_punch(Game.camera_rig.FOV_ENDER)
	return true


## Watches the hero (read only) for a breaker landing.
func _watch_hero() -> void:
	var hero := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if hero == null or not "breakers_landed" in hero:
		return
	var n: int = hero.breakers_landed
	if _breakers_seen >= 0 and n > _breakers_seen:
		slam(hero.get("_brk_ended") == "perfect")
	_breakers_seen = n


func _process(_delta: float) -> void:
	_watch_hero()
	if _strength <= 0.0:
		return
	var s := current()
	if s <= 0.0:
		_strength = 0.0
	elif Time.get_ticks_msec() - _start_ms <= IMPACT_HOLD * 1000.0 and Game.last_hit_ms >= _start_ms:
		lean(Game.hit_dir_screen())  # (the hero kicks the camera along the blow just after the hitstop that fired this)
	_apply(s)


func _apply(s: float) -> void:
	_mat.set_shader_parameter("strength", s)
	rect.visible = s > 0.0
