shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

// Inverted-hull toon outline, used as a next_pass on character materials.
// The hull is pushed out in screen space, so the line stays `width_px`
// thick at any distance or model scale.
uniform vec4 outline_color : source_color = vec4(0.05, 0.03, 0.08, 1.0);
uniform float width_px = 3.5;
// 0 = even line. Above 0 the width swells and thins over the form (comic_lib.ink_pass),
// heavier underneath, like a brush.
uniform float wobble = 0.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	if (length(dir) > 0.0001) {
		float w = width_px;
		if (wobble > 0.0) {
			float n = sin(VERTEX.x * 11.0 + VERTEX.y * 7.0) * sin(VERTEX.z * 9.0 - VERTEX.y * 13.0) * 0.5 + 0.5;
			w *= 1.0 + wobble * (n + max(-NORMAL.y, 0.0) * 0.5 - 0.5);
		}
		clip.xy += normalize(dir) * w * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
