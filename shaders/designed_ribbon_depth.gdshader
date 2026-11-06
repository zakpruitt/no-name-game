shader_type spatial;
// designed_ribbon.gdshader with the depth test on (fx-air): bands wrapped round a volume (the twister's helix
// ribbons), so a foe inside reads in front of the band's far half and behind its near half. The far half (the
// band's inside, seen through the volume) takes `back_shade` off its tone: the ribbon's back reads one cel band
// darker, which is what makes a ring of flat strokes read as a turning column.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/designed_fx.gdshaderinc"

uniform float rows = 4.0;
uniform float back_shade = 0.25;  // tone steps (0.25 = one cel band) the band's inside drops
instance uniform float head = 1.0;
instance uniform float span = 1.0;
instance uniform float tiles = 0.0;  // 0: the strip covers [head - span, head]; > 0: repeat it this many times
instance uniform float scroll = 0.0;

void fragment() {
	float u;
	if (tiles > 0.0) {
		u = fract(UV.x * tiles + scroll);
	} else {
		u = (UV.x - (head - span)) / max(span, 0.001);
	}
	float inside = step(0.0, u) * step(u, 1.0);
	float f = floor(frame + 0.5);
	vec2 uv = vec2(clamp(u, 0.002, 0.998), (f + clamp(1.0 - UV.y, 0.01, 0.99)) / rows);
	vec4 s = texture(sheet, uv);
	if (!FRONT_FACING) {
		s.r = s.r > 0.12 ? max(0.25, s.r - back_shade) : s.r;  // ink stays ink; light and body drop a band
	}
	vec4 d = designed(s, erode, pal_row);
	ALBEDO = d.rgb;
	ALPHA = d.a * alpha * inside;
}
