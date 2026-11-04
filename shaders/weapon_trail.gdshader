shader_type spatial;
// Not additive: big additive shapes wash out to white on the light floor tiles.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Swing trail ribbon (scripts/weapon_trail.gd). UV.x = age along the ribbon
// (0 at the blade, 1 at the oldest sample), UV.y = blade base (0) to tip (1).
// COLOR = trail colour and alpha. UV2.x = swell (0 plain .. 1 a heavy hit deep
// in a chain): a fuller crescent, a wider hot edge and a slower erosion.
uniform vec4 edge_color : source_color = vec4(1.0);
uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;

void fragment() {
	float age = UV.x;
	float swell = clamp(UV2.x, 0.0, 1.0);
	// Crescent: the inner edge climbs toward the tip as the ribbon ages; a
	// swollen ribbon keeps more of its body.
	float inner = mix(0.05, mix(0.7, 0.6, swell), age);
	float body = smoothstep(inner, inner + 0.22, UV.y);
	// Noise eats the tail away instead of an even fade (slower when swollen).
	float n = texture(noise, vec2(UV.x * 1.3 + TIME * 0.6, UV.y * 0.8)).r;
	float bite = age * mix(1.15, 1.05, swell);
	float erode = smoothstep(bite - 0.15, bite + 0.1, n);
	// Bright leading edge along the tip, wider on a heavy hit.
	float hot = smoothstep(mix(0.8, 0.65, swell), 0.96, UV.y) * (1.0 - age * 0.8);
	ALBEDO = mix(COLOR.rgb, edge_color.rgb, hot);
	ALPHA = clamp(body * erode * (1.0 - age) * COLOR.a * (0.8 + hot + 0.2 * swell), 0.0, 1.0);
}
