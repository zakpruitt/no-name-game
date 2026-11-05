shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

// A foe's heavy outer line (round 39, ComicLook.SILHOUETTE): a second inverted hull, wider than
// Fx.outline's and pushed far back, so it only shows where nothing of the foe is behind the edge:
// the outer silhouette gets the thick ink, the lines between its own parts stay thin.
uniform vec4 outline_color : source_color = vec4(0.035, 0.032, 0.07, 1.0);
uniform float width_px = 3.2;
uniform float depth_push = 0.3;  // m away from the camera

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
	ALBEDO = outline_color.rgb;
}
