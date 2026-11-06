// Shared by the designed effect shaders (round 43, docs/features/designed-fx.md).
// A sheet texel is (tone, erode order, boil, cover): tools/vfx_gen/vfxlib.py writes them.
// `palette` is DesignedFx.palette(): one row per element, five texels (ink, deep, body, light, hot).

uniform sampler2D sheet : filter_linear_mipmap, repeat_disable;
uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform float palette_rows = 8.0;
// The burn line where erosion eats the shape: 0 ink, 1 the palette's hot tone (magma burns hot).
uniform float burn_hot = 0.0;
uniform float burn_width = 0.07;

instance uniform float frame = 0.0;  // which frame of the sheet (integer; DesignedFx steps it)
instance uniform float erode = 0.0;  // 0 whole .. 1 gone
instance uniform float alpha = 1.0;
instance uniform float pal_row = 0.0;

vec3 tone_color(float row, float k) {
	return texture(palette, vec2((k + 0.5) / 5.0, (row + 0.5) / palette_rows)).rgb;
}

// Hard cel bands, anti-aliased only across the one texel the bilinear filter blends.
vec3 ramp(float t, float row) {
	float x = clamp(t, 0.0, 1.0) * 4.0;
	float aa = max(fwidth(x) * 0.75, 0.04);
	vec3 c = tone_color(row, 0.0);
	c = mix(c, tone_color(row, 1.0), smoothstep(0.5 - aa, 0.5 + aa, x));
	c = mix(c, tone_color(row, 2.0), smoothstep(1.5 - aa, 1.5 + aa, x));
	c = mix(c, tone_color(row, 3.0), smoothstep(2.5 - aa, 2.5 + aa, x));
	c = mix(c, tone_color(row, 4.0), smoothstep(3.5 - aa, 3.5 + aa, x));
	return c;
}

// The texel through erosion: rgb and alpha. `e` is the erode threshold.
vec4 designed(vec4 s, float e, float row) {
	vec3 c = ramp(s.r, row);
	float a = s.a;
	if (e > 0.0) {
		float g = s.g + (s.b - 0.5) * 0.06;  // the boil wobbles the edge a little
		float w = fwidth(g) + 0.01;
		a *= smoothstep(e - w, e + w, g);
		float burn = 1.0 - smoothstep(e + burn_width * 0.4, e + burn_width, g);
		c = mix(c, mix(tone_color(row, 0.0), tone_color(row, 4.0), burn_hot), burn);
	}
	return vec4(c, a);
}
