shader_type spatial;
// A designed ground stamp (round 44 fx-cohesion, designed_ink.gd): an authored brush strip (gen_cohesion.py
// stamp_shock / stamp_cue) laid round an annulus flat on the floor, repeated `tiles` times round the circle so a
// big ring and a small one keep the same brush. UV.x runs round the circle 0..1, UV.y across the band (0 inner,
// 1 outer). Rows are frames (boils, or the cue's two ring kinds). Tones come from the element's palette row,
// or, when `tint.a` > 0, from a tint (the breaker cue's colours mean things); `tint2` alternates per tile (a
// breaker with two endings). Drawn over the pile like the old flat hoops (no depth test).
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/designed_fx.gdshaderinc"

uniform float rows = 4.0;
instance uniform float tiles = 8.0;
instance uniform float scroll = 0.0;
instance uniform vec4 tint = vec4(0.0);
instance uniform vec4 tint2 = vec4(0.0);
instance uniform float accent_every = 0.0;  // round 45: > 0: only every Nth tile takes tint2 (an accent), not every other

vec3 tint_ramp(float t, vec3 c) {
	float x = clamp(t, 0.0, 1.0) * 4.0;
	float aa = max(fwidth(x) * 0.75, 0.04);
	vec3 ink = vec3(0.012, 0.01, 0.02);
	vec3 o = ink;
	o = mix(o, c * 0.55, smoothstep(0.5 - aa, 0.5 + aa, x));
	o = mix(o, c * 0.8, smoothstep(1.5 - aa, 1.5 + aa, x));
	o = mix(o, c, smoothstep(2.5 - aa, 2.5 + aa, x));
	o = mix(o, mix(c, vec3(1.0, 0.98, 0.9), 0.6), smoothstep(3.5 - aa, 3.5 + aa, x));
	return o;
}

void fragment() {
	float x = UV.x * tiles + scroll;
	float u = fract(x);
	float f = floor(frame + 0.5);
	vec2 uv = vec2(clamp(u, 0.002, 0.998), (f + clamp(1.0 - UV.y, 0.01, 0.99)) / rows);
	vec4 s = texture(sheet, uv);
	vec4 d = designed(s, erode, pal_row);
	vec3 c = d.rgb;
	if (tint.a > 0.0) {
		vec3 tc = tint.rgb;
		float n = accent_every > 0.5 ? accent_every : 2.0;
		bool second = accent_every > 0.5 ? mod(floor(x), n) < 0.5 : mod(floor(x), n) > 0.5;
		if (tint2.a > 0.0 && second) {
			tc = tint2.rgb;
		}
		c = tint_ramp(s.r, tc);
		if (erode > 0.0) {
			float g = s.g + (s.b - 0.5) * 0.06;
			float burn = 1.0 - smoothstep(erode + burn_width * 0.4, erode + burn_width, g);
			c = mix(c, vec3(0.012, 0.01, 0.02), burn);
		}
	}
	ALBEDO = c;
	ALPHA = d.a * alpha;
}
