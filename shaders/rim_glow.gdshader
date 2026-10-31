shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;

// Additive fresnel glow used as a material_overlay for the Awakening form.
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float power = 2.2;
uniform float intensity = 2.5;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	float pulse = 0.8 + 0.2 * sin(TIME * 10.0);
	ALBEDO = glow_color.rgb * rim * intensity * pulse;
}
