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

// Round 33 (sleek): the arc is a clear-to-tinted gradient with one crisp light line on its outer edge and a
// thin ink line past it, not an opaque fan. `body_alpha` is the fill's alpha at its fullest.
uniform float body_alpha = 0.55;

void fragment() {
	// Fast start, slow finish (reads as a strong swing); the head runs past the end.
	float head = pow(progress, 0.4) * 1.35;
	float behind = head - UV.x;
	float trail = smoothstep(-0.03, 0.02, behind) * (1.0 - smoothstep(0.0, trail_length, behind));
	// The outer (blade) edge lasts longest; the inner body thins out fast down the trail.
	float inner = 0.35 + (1.0 - trail) * 0.6;
	float body = smoothstep(inner, inner + 0.25, UV.y);
	float n = texture(noise, vec2(UV.x * 3.0 - progress * 2.0, UV.y * 0.6)).r;
	float line = smoothstep(0.88, 0.91, UV.y) * (1.0 - smoothstep(0.955, 0.97, UV.y));
	float inkline = smoothstep(0.96, 0.975, UV.y) * (1.0 - smoothstep(0.99, 1.0, UV.y));
	vec3 c = mix(color.rgb, edge_color.rgb * 1.3, line);
	c = mix(c, ink, inkline);
	float m = body * body_alpha * mix(1.0, n * 1.4, 0.3) * smoothstep(inner, 0.9, UV.y);
	m = max(m, line);
	m = max(m, inkline * 0.85);
	m *= trail;
	if (band > 0.0) {  // Awakened: no fill at all, only the lines
		m = trail * max(line, inkline * 0.85);
	}
	ALBEDO = c;
	ALPHA = clamp(m * color.a * (1.0 - smoothstep(0.6, 1.0, progress)), 0.0, 1.0);
}
