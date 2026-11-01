shader_type spatial;
// Not additive: big additive shapes wash out to white on the light floor tiles.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Wind funnel (elements.gd funnel()): an open CylinderMesh, UV.x around the
// circumference, UV.y top (0) to bottom (1). Diagonal bands spiral up it;
// a darker body colour keeps it readable on the light floor, bright streaks
// on top. Fade with the instance's `transparency` (elements._fade_free).
uniform vec4 body_color : source_color = vec4(0.2, 0.6, 0.3, 0.55);
uniform vec4 streak_color : source_color = vec4(0.9, 1.0, 0.9, 1.0);
uniform float bands = 3.0;      // spiral bands around the funnel
uniform float twist = 1.6;      // how far a band winds over the height
uniform float speed = 2.2;      // upward spin speed
uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;

void fragment() {
	float h = 1.0 - UV.y;  // 0 at the bottom, 1 at the top
	float s = fract(UV.x * bands + h * twist - TIME * speed);
	float n = texture(noise, vec2(UV.x * 2.0 + TIME * 0.3, h * 1.5 - TIME * 0.8)).r;
	float streak = smoothstep(0.55, 0.7, s) * (1.0 - smoothstep(0.78, 0.95, s));
	streak *= smoothstep(0.25, 0.6, n);
	float body = mix(0.35, 1.0, smoothstep(0.0, 0.5, s) * (1.0 - smoothstep(0.5, 1.0, s)));
	// Fade the open ends.
	float ends = smoothstep(0.0, 0.12, h) * (1.0 - smoothstep(0.8, 1.0, h));
	ALBEDO = mix(body_color.rgb, streak_color.rgb * 1.4, streak);
	ALPHA = clamp((body_color.a * body + streak) * ends, 0.0, 1.0);
}
