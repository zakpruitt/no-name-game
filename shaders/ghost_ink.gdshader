shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, shadows_disabled;

// The ink line round a see-through ghost (spirit_echo.gd): an inverted hull pushed out `width_px` in screen
// space (like outline.gdshader) but transparent so it can fade with the fill. It draws after the fill, whose
// depth hides the hull's back faces inside the silhouette, so the line never darkens the fill.
uniform vec4 ink_color : source_color = vec4(0.01, 0.05, 0.06, 1.0);
uniform float width_px = 2.0;  // at 1080p (scaled with the viewport height)
instance uniform float alpha = 1.0;  // shared with the fill's fade (per instance)
instance uniform float fade_height = 0.0;  // (unused here: declared so the instance indices match the fill's)
instance uniform vec2 local_fade = vec2(0.0, 0.0);  // shared with the fill: the line thins to LOCAL_FLOOR along it
const float LOCAL_FLOOR = 0.45;

varying float v_local;

void vertex() {
	v_local = VERTEX.y;
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
	float lf = local_fade.y != local_fade.x ? mix(LOCAL_FLOOR, 1.0, smoothstep(local_fade.x, local_fade.y, v_local)) : 1.0;
	ALPHA = ink_color.a * alpha * lf;
}
