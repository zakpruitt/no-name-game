shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, fog_disabled;

// Comic-book tones, the Godot port of comic_poc/comic_lib.py `toon`. Colours are
// per material (ComicLook.TONES); the result is flat cut tones, not shading:
//   ink < spot < shadow (hatched) < mid (halftoned) < light < hi
// Each light picks a tone and the brightest tone wins (DIFFUSE_LIGHT = max), so
// lights never stack past the palette. ALBEDO is white, so DIFFUSE_LIGHT is the
// final colour; EMISSION carries the spot black and the rim. The band numbers are
// on the POC's scale: a sun of energy 1.15 (ComicLook.KEY_ENERGY) tops out at 1.15.

uniform vec3 ink_color : source_color = vec3(0.012, 0.01, 0.02);
uniform vec3 shadow_color : source_color = vec3(0.1, 0.1, 0.2);
uniform vec3 mid_color : source_color = vec3(0.4, 0.4, 0.5);
uniform vec3 light_color : source_color = vec3(0.8, 0.8, 0.9);
uniform vec3 hi_color : source_color = vec3(0.8, 0.8, 0.9);  // = light_color when the tone has no highlight
uniform vec3 rim_color : source_color = vec3(0.0);
uniform float brush = 0.3;   // how far the streaky noise bends the tone edges
uniform float spot = 0.075;  // below this: solid ink
uniform float inner = 0.17;  // inner contour: facing ratio below this is inked (0 = none)
uniform float rim_width = 0.05;  // hard rim band just outside the inner ink
// 1 = multiply the tones by the mesh's `g` (dungeon pieces: per-stone tone, 0.5 = neutral,
// env_kit.tone_extra). Stays 0 for enemies, whose `g` means something else.
uniform float tone_by_g = 0.0;
// 1 = the sun's cast shadows land here. 0 for characters: they still cast on the floor, but
// a small, detailed model shadowing itself breaks up into black blotches instead of cut tones.
uniform float receive_shadow = 1.0;
// A painted model's texture; the tones then act as light levels on it. White on everything else.
uniform sampler2D paint : source_color, hint_default_white, filter_linear_mipmap;

const float BAND_MID = 0.3;
const float BAND_LIGHT = 0.72;
const float BAND_HI = 1.12;
const float DOTS = 62.0;   // halftone cells per screen height
const float HATCH = 95.0;  // hatch lines per screen height
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
// How strong the screen-space texture is. Hatching in particular covers everything in shadow,
// floors included, so at full strength shadows read as a busy pattern and not as a shape.
const float DOT_COVER = 0.4;     // most of a cell a dot fills, at the shadow edge
const float DOT_STRENGTH = 0.6;  // 1 = dots in the full shadow colour
const float HATCH_COVER = 0.3;   // most of the shadow a line covers
const float HATCH_STRENGTH = 0.35;  // 1 = lines in full ink

varying vec3 v_pos;
varying float v_brush;  // written in fragment(), read per light


void vertex() {
	v_pos = VERTEX;
}


void fragment() {
	// Cheap stand-in for the POC's stretched noise texture: two crossed sines.
	vec3 p = v_pos * vec3(13.0, 13.0, 5.2);
	float streak = sin(p.x + 1.7 * sin(p.z * 0.7)) * sin(p.y * 0.9 + 1.3 * sin(p.x * 0.6));
	v_brush = streak * 0.5;
	float nv = abs(dot(NORMAL, VIEW));
	float thin = inner + v_brush * inner * 0.6;
	float inked = inner > 0.0 ? step(nv, thin) : 0.0;
	float rim = step(nv, thin + rim_width) * (1.0 - inked);
	ALBEDO = texture(paint, UV).rgb * (1.0 - inked) * (1.0 + tone_by_g * (COLOR.r * 0.8 - 0.4));
	ROUGHNESS = 1.0;
	EMISSION = ink_color + rim_color * rim;
}


void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	float shade = LIGHT_IS_DIRECTIONAL ? mix(1.0, ATTENUATION, receive_shadow) : ATTENUATION;
	float lit = dot(LIGHT_COLOR, LUMA) / PI * ndl * shade;
	float lum = lit + v_brush * brush * 1.1 * step(0.001, lit);
	vec3 tone = vec3(0.0);
	if (lum >= BAND_HI) {
		tone = hi_color;
	} else if (lum >= BAND_LIGHT) {
		tone = light_color;
	} else if (lum >= BAND_MID) {
		// Shadow-colour dots, biggest at the shadow edge, gone by lum 0.56.
		vec2 s = FRAGCOORD.xy / VIEWPORT_SIZE.y;
		const float C = 0.8776;  // cos/sin of the POC's 0.5 rad screen angle
		const float S = 0.4794;
		vec2 uv = vec2(s.x * C - s.y * S, s.x * S + s.y * C) * DOTS * TAU;
		float field = sin(uv.x) * sin(uv.y) * 0.5 + 0.5;
		float cov = clamp((0.56 - lum) / 0.26, 0.0, 1.0) * DOT_COVER;
		tone = mix(mix(mid_color, shadow_color, DOT_STRENGTH), mid_color, smoothstep(cov - 0.06, cov + 0.06, field));
	} else if (lum >= spot) {
		// Ink lines running into the black shapes on the shadow side.
		vec2 s = FRAGCOORD.xy / VIEWPORT_SIZE.y;
		float line = sin((s.x * 0.5403 - s.y * 0.8415) * HATCH * TAU) * 0.5 + 0.5;  // 1 rad
		float cov = clamp((0.2 - lum) / (0.2 - spot), 0.0, 1.0) * HATCH_COVER;
		tone = mix(mix(shadow_color, ink_color, HATCH_STRENGTH), shadow_color, smoothstep(cov - 0.08, cov + 0.08, line));
	}
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, tone);
}
