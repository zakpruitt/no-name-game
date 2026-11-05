shader_type spatial;
// Not additive: big additive shapes wash out to white on the light floor tiles.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Swing trail ribbon (scripts/weapon_trail.gd). UV.x = age along the ribbon
// (0 at the blade, 1 at the oldest sample), UV.y = blade base (0) to tip (1).
// COLOR = trail colour and alpha. UV2.x = swell (0 plain .. 1 a heavy hit deep
// in a chain): a fuller crescent, a wider hot edge and a slower erosion.
uniform vec4 edge_color : source_color = vec4(1.0);
uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;

// Round 33 (sleek): a see-through crescent, not a sheet. The body is a gradient from clear at the inner
// edge to `body_alpha` near the tip, the tip is one crisp light line with a thin ink line outside it, and
// the crescent's inner edge climbs fast so the ribbon is a blade-edge arc, not a filled fan.
uniform vec3 ink : source_color = vec3(0.03, 0.02, 0.06);
uniform float body_alpha = 0.5;

void fragment() {
	float age = UV.x;
	float swell = clamp(UV2.x, 0.0, 1.0);
	float inner = mix(0.25, mix(0.82, 0.74, swell), age);
	float body = smoothstep(inner, inner + 0.3, UV.y);
	// Noise eats the tail away instead of an even fade (slower when swollen).
	float n = texture(noise, vec2(UV.x * 1.3 + TIME * 0.6, UV.y * 0.8)).r;
	float bite = age * mix(1.2, 1.1, swell);
	float erode = smoothstep(bite - 0.12, bite + 0.08, n);
	// The light line along the tip, and the ink line just past it.
	float line = smoothstep(0.86, 0.9, UV.y) * (1.0 - smoothstep(0.95, 0.965, UV.y));
	float inkline = smoothstep(0.955, 0.97, UV.y) * (1.0 - smoothstep(0.99, 1.0, UV.y));
	float fresh = 1.0 - age;
	vec3 c = mix(COLOR.rgb, edge_color.rgb, line);
	c = mix(c, ink, inkline);
	float a = body * body_alpha * (0.35 + 0.65 * smoothstep(inner, 0.9, UV.y));
	a = max(a, line * (1.0 - age * 0.6));
	a = max(a, inkline * 0.85 * fresh);
	ALBEDO = c;
	ALPHA = clamp(a * erode * fresh * min(COLOR.a * 1.25, 1.0), 0.0, 1.0);
}
