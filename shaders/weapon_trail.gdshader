shader_type spatial;
// Not additive: big additive shapes wash out to white on the light floor tiles.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Swing trail ribbon (scripts/weapon_trail.gd). UV.x = age along the ribbon
// (0 at the blade, 1 at the oldest sample), UV.y = blade base (0) to tip (1).
// COLOR = trail colour and alpha.
uniform vec4 edge_color : source_color = vec4(1.0);
uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;

void fragment() {
	float age = UV.x;
	// Crescent: the inner edge climbs toward the tip as the ribbon ages.
	float inner = mix(0.05, 0.7, age);
	float body = smoothstep(inner, inner + 0.22, UV.y);
	// Noise eats the tail away instead of an even fade.
	float n = texture(noise, vec2(UV.x * 1.3 + TIME * 0.6, UV.y * 0.8)).r;
	float erode = smoothstep(age * 1.15 - 0.15, age * 1.15 + 0.1, n);
	// Bright leading edge along the tip.
	float hot = smoothstep(0.8, 0.96, UV.y) * (1.0 - age * 0.8);
	ALBEDO = mix(COLOR.rgb, edge_color.rgb, hot);
	ALPHA = clamp(body * erode * (1.0 - age) * COLOR.a * (0.8 + hot), 0.0, 1.0);
}
