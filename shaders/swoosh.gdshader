shader_type spatial;
// Not additive: big additive shapes wash out to white on the light floor tiles.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Melee swoosh on Fx.swoosh()'s arc mesh: UV.x runs along the arc (0 = where
// the swing starts), UV.y from the inner edge (0) to the outer edge (1).
// `progress` is tweened 0 -> 1 over the effect. Sweep logic adapted from the
// REEBOO Stylized VFX slash shader (MIT, (c) 2026 REEBOO Labs).
uniform vec4 color : source_color = vec4(0.3, 0.95, 0.85, 0.9);
uniform vec4 edge_color : source_color = vec4(1.0);
uniform float progress = 0.0;
// How much of the arc stays lit behind the head (in arc lengths).
uniform float trail_length = 0.95;
// Above 0 only the outer band past this UV.y draws, with an ink line on its inner edge (Awakened gold,
// Fx.AWAKEN_SWOOSH_BAND): a crescent edge, not a sheet.
uniform float band = 0.0;
uniform vec3 ink : source_color = vec3(0.04, 0.02, 0.06);
uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;

void fragment() {
	// Fast start, slow finish (reads as a strong swing); the head runs past the end.
	float head = pow(progress, 0.4) * 1.35;
	float behind = head - UV.x;
	float trail = smoothstep(-0.03, 0.02, behind) * (1.0 - smoothstep(0.0, trail_length, behind));
	// The outer (blade) edge lasts longest; the inner body thins out down the trail.
	float inner = 1.0 - trail * 1.15;
	float body = smoothstep(inner, inner + 0.2, UV.y);
	float rim = 1.0 - smoothstep(0.93, 1.0, UV.y);
	float n = texture(noise, vec2(UV.x * 3.0 - progress * 2.0, UV.y * 0.6)).r;
	float m = trail * body * rim * mix(1.0, n * 1.6, 0.35) * 1.5;
	float hot = smoothstep(0.72, 0.95, UV.y) * trail;
	// Past 1.0 the environment's glow blooms the edge (white alone vanishes on the light floor).
	vec3 c = mix(color.rgb, edge_color.rgb * 1.8, hot);
	if (band > 0.0) {
		float keep = smoothstep(band - 0.06, band, UV.y);
		float line = keep * (1.0 - smoothstep(band, band + 0.07, UV.y));
		c = mix(c, ink, line);
		m = max(trail * keep * rim * 1.5, 0.0);
	}
	ALBEDO = c;
	ALPHA = clamp(m * color.a * (1.0 - smoothstep(0.6, 1.0, progress)), 0.0, 1.0);
}
