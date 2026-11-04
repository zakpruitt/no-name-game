shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;

// The hero's bright rim (heretic_rig.gd _add_rim): a wider inverted hull in paper, drawn after the
// effects (transparent pass, high render_priority) so it rings his silhouette over bolts, rings and words.
// Pushed back further than the ink hull, which hides its inner part: only a band past the ink shows.
// Depth tested against opaque things only (effects don't write depth), so a foe in front still covers it.
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.84, 1.0);
uniform float width_px = 4.0;
uniform float depth_push = 0.14;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.z -= depth_push;
	vec4 clip = PROJECTION_MATRIX * view;
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	if (length(dir) > 0.0001) {
		clip.xy += normalize(dir) * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = rim_color.rgb;
	ALPHA = rim_color.a;
}
