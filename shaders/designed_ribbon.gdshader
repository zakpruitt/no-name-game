shader_type spatial;
// A designed strip texture laid along a shaped mesh (round 43): the slash arc (Fx.swoosh's mesh) and the bolt
// ribbon. UV.x runs along the mesh 0..1, UV.y across it (0 inner / 1 outer). The strip's rows are frames
// (hand-drawn boils, stepped on twos). `head` is where the stroke's front is along the mesh and `span` how long the
// stroke is; the texture slides with the head, so the stroke travels instead of fading in place. `tiles`
// repeats the strip along long meshes (bolts) so their zigzags keep their drawn proportions.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/designed_fx.gdshaderinc"

uniform float rows = 4.0;
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
	vec4 d = designed(texture(sheet, uv), erode, pal_row);
	ALBEDO = d.rgb;
	ALPHA = d.a * alpha * inside;
}
