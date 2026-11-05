shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, shadows_disabled;

// The ink line round a see-through ghost (spirit_echo.gd): an inverted hull pushed out `width_px` in screen
// space (like outline.gdshader) but transparent so it can fade with the fill. It draws after the fill, whose
// depth hides the hull's back faces inside the silhouette, so the line never darkens the fill.
uniform vec4 ink_color : source_color = vec4(0.01, 0.05, 0.06, 1.0);
uniform float width_px = 2.0;  // at 1080p (scaled with the viewport height)
instance uniform float alpha = 1.0;  // shared with the fill's fade (per instance)

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	if (length(dir) > 0.0001) {
		float w = width_px * VIEWPORT_SIZE.y / 1080.0;
		clip.xy += normalize(dir) * w * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink_color.rgb;
	ALPHA = ink_color.a * alpha;
}
