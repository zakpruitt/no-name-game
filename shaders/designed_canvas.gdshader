shader_type canvas_item;
// A designed sheet (tools/vfx_gen, tone / erode / boil / cover; docs/features/designed-fx.md) drawn on the screen:
// the breaker hang's focus lines and the ending's callout banner (scripts/designed_breaker.gd). The five tones come
// from the element's fx_palette row as uniforms (canvas items have no instance uniforms), hard cel bands, and the
// same erosion with an ink burn line as the 3D shaders. `band` picks a sub-rect of the frame (the banner is drawn
// across the middle third of its square).

uniform sampler2D sheet : filter_linear_mipmap, repeat_disable;
uniform vec2 grid = vec2(2.0, 2.0);
uniform float frame = 0.0;
uniform float erode = 0.0;
uniform float alpha = 1.0;
uniform vec4 band = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 c_ink : source_color = vec3(0.03, 0.01, 0.06);
uniform vec3 c_deep : source_color = vec3(0.3, 0.1, 0.56);
uniform vec3 c_body : source_color = vec3(0.62, 0.3, 1.0);
uniform vec3 c_light : source_color = vec3(1.0, 0.52, 0.95);
uniform vec3 c_hot : source_color = vec3(1.0, 0.86, 1.0);

void fragment() {
	vec2 uv = band.xy + UV * band.zw;
	float f = floor(frame + 0.5);
	vec2 cell = vec2(mod(f, grid.x), floor(f / grid.x));
	vec4 s = texture(sheet, (cell + clamp(uv, 0.002, 0.998)) / grid);
	float x = clamp(s.r, 0.0, 1.0) * 4.0;
	float aa = max(fwidth(x) * 0.75, 0.04);
	vec3 c = c_ink;
	c = mix(c, c_deep, smoothstep(0.5 - aa, 0.5 + aa, x));
	c = mix(c, c_body, smoothstep(1.5 - aa, 1.5 + aa, x));
	c = mix(c, c_light, smoothstep(2.5 - aa, 2.5 + aa, x));
	c = mix(c, c_hot, smoothstep(3.5 - aa, 3.5 + aa, x));
	float a = s.a;
	if (erode > 0.0) {
		float g = s.g + (s.b - 0.5) * 0.06;
		float w = fwidth(g) + 0.01;
		a *= smoothstep(erode - w, erode + w, g);
		c = mix(c, c_ink, 1.0 - smoothstep(erode + 0.03, erode + 0.07, g));
	}
	COLOR = vec4(c, a * alpha);
}
