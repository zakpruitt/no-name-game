shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, blend_mix, shadows_disabled;

// Round 33 (sleek): the see-through comic fill for shapes that were opaque slabs: the spirit echo's ghost
// axe (spirit_echo.gd), the spirit strike's sky column and the earth spikes (elements.gd). Screen-space
// halftone dots in the light tone over a faint body tone, about `fill` alpha on average, so a shape reads as
// printed ink on paper. Drawn twice: first `depth_only` (writes depth, no colour) so only the nearest layer of
// overlapping parts gets the fill, then the fill; the ink hull (ghost_ink.gdshader) draws after both and only
// shows past the silhouette. The materials are shared per palette (spirit_echo.ghost_mat); the fade and the
// height gradient are per instance.
uniform vec4 body_color : source_color = vec4(0.28, 0.92, 0.84, 1.0);
uniform vec4 dot_color : source_color = vec4(0.84, 1.0, 0.95, 1.0);
uniform float fill = 0.3;  // mean alpha of the fill
uniform float base = 0.35;  // alpha between the dots, of `fill`
uniform float dots = 95.0;  // halftone cells per screen height
uniform float dot_r = 0.33;  // dot radius, of a cell (0.5 touches)
uniform bool depth_only = false;
instance uniform float alpha = 1.0;  // the whole fade (tweened)
instance uniform float fade_height = 0.0;  // m above the floor where the fill has faded out (0 = no gradient)

varying float v_height;

void vertex() {
	v_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (depth_only) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	} else {
		vec2 cell = FRAGCOORD.xy / VIEWPORT_SIZE.y * dots;
		vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * cell;  // 45 degree screen
		// Dots swell toward the silhouette (edge-on faces), so the shape has a rim of tone.
		float edge = 1.0 - abs(dot(NORMAL, VIEW));
		float grad = fade_height > 0.0 ? clamp(1.0 - v_height / fade_height, 0.0, 1.0) : 1.0;
		float r = dot_r * (0.8 + 0.4 * edge) * mix(0.55, 1.0, grad);  // dots shrink up the gradient
		float d = length(fract(g) - 0.5);
		float m = 1.0 - smoothstep(r - 0.05, r + 0.05, d);
		ALBEDO = mix(body_color.rgb, dot_color.rgb, m);
		float cover = 3.14159 * r * r;  // dot share of a cell, so the mean stays near `fill`
		float hi = (1.0 - base * (1.0 - cover)) / max(cover, 0.05);
		ALPHA = clamp(fill * mix(base, hi, m), 0.0, 1.0) * alpha * grad;
	}
}
