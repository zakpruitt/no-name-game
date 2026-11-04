extends CanvasLayer
## Comic-style impact frame: on a big hit or a kill the scene view flips for a
## few real-time frames into a high-contrast negative (ink where it was light,
## paper where it was dark) with a dark vignette, then fades. One ColorRect
## reading the screen, on layer -1 (above the 3D view, under every HUD layer),
## owned by the Game autoload: Game.hitstop() fires it for stops of
## IMPACT_STOP or more and Game.enemy_killed for kills. With
## Game.reduce_flashing the negative is dropped and only a soft vignette
## pulse remains (and kills get nothing).

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength = 0.0;
uniform float invert = 1.0;
uniform vec3 ink : source_color = vec3(0.06, 0.03, 0.1);
uniform vec3 paper : source_color = vec3(1.0, 0.95, 0.82);
void fragment() {
	vec3 col = textureLod(screen, SCREEN_UV, 0.0).rgb;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 two = mix(paper, ink, smoothstep(0.3, 0.7, l));
	vec3 c = mix(col, two, strength * invert);
	float d = length((SCREEN_UV - 0.5) * vec2(1.4, 1.0));
	c = mix(c, ink, smoothstep(0.45, 1.05, d) * strength * 0.85);
	COLOR = vec4(c, 1.0);
}
"""
const IMPACT_STOP := 0.1  # hitstops this long (real s) or longer flash a frame: enders, slams, breakers
const IMPACT_FULL_STOP := 0.25  # a stop this long flashes at full strength (shorter ones scale down)
const IMPACT_MIN := 0.45  # strength of the lightest big-hit frame (a 0.1 s stop: enders)
const IMPACT_KILL := 0.4  # strength of a kill's frame
const IMPACT_HOLD := 0.05  # real seconds held at full strength (about three frames)
const IMPACT_FADE := 0.09  # real seconds fading out after the hold
const IMPACT_GAP_MS := 240  # no new frame closer than this to the last (no strobing on a crowd)
const REDUCED_SCALE := 0.45  # strength multiplier with Game.reduce_flashing (vignette only)

var rect: ColorRect
var _mat := ShaderMaterial.new()
var _strength := 0.0  # the frame's peak strength; 0 = idle
var _reduced := false
var _invert := 1.0  # what the shader's invert is set to (shader params can't be read back headless)
var _start_ms := 0
var _last_ms := -100000


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
## no negative); a kill's (`kill`) doesn't.
func flash(strength: float, kill := false) -> bool:
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
	_apply(_strength)
	return true


## The frame fired by a hitstop of `duration` real seconds, if it is big enough.
func on_hitstop(duration: float) -> bool:
	if duration < IMPACT_STOP:
		return false
	return flash(lerpf(IMPACT_MIN, 1.0, clampf((duration - IMPACT_STOP) / (IMPACT_FULL_STOP - IMPACT_STOP), 0.0, 1.0)))


## Strength showing right now (0 when idle).
func current() -> float:
	if _strength <= 0.0:
		return 0.0
	var t := (Time.get_ticks_msec() - _start_ms) * 0.001
	if t <= IMPACT_HOLD:
		return _strength
	return _strength * clampf(1.0 - (t - IMPACT_HOLD) / IMPACT_FADE, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _strength <= 0.0:
		return
	var s := current()
	if s <= 0.0:
		_strength = 0.0
	_apply(s)


func _apply(s: float) -> void:
	_mat.set_shader_parameter("strength", s)
	rect.visible = s > 0.0
