shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

// Round 33, part 3 (sleek): ghost_halftone's screen-space dots for a flat floor zone (the frost spear's frost),
// so the ice reads as the same printed see-through ice as the spikes and cubes. A mesh of radius 1 (scaled):
// clear inside `inner`, ramping to `fill` mean alpha at the rim. No depth write (a disc 12 m across writing
// depth hid every floor effect under it) and no hull (the zone's ink is its teeth).
uniform vec4 body_color : source_color = vec4(0.42, 0.78, 1.0, 1.0);
uniform vec4 dot_color : source_color = vec4(0.88, 0.97, 1.0, 1.0);
uniform float fill = 0.3;
uniform float base = 0.2;  // alpha between the dots, of `fill`
uniform float dots = 95.0;  // cells per screen height (ghost_halftone's)
uniform float dot_r = 0.33;
uniform float inner = 0.35;  // of the radius: clear inside this
instance uniform float alpha = 1.0;

varying float v_r;

void vertex() {
	v_r = length(VERTEX.xz);
}

void fragment() {
	vec2 cell = FRAGCOORD.xy / VIEWPORT_SIZE.y * dots;
	vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * cell;
	float grad = smoothstep(inner, 1.0, v_r);
	float r = dot_r * mix(0.45, 1.0, grad);
	float m = 1.0 - smoothstep(r - 0.05, r + 0.05, length(fract(g) - 0.5));
	ALBEDO = mix(body_color.rgb, dot_color.rgb, m);
	float cover = 3.14159 * r * r;
	float hi = (1.0 - base * (1.0 - cover)) / max(cover, 0.05);
	ALPHA = clamp(fill * mix(base, hi, m), 0.0, 1.0) * grad * alpha;
}
