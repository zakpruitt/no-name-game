shader_type spatial;
// A designed flipbook laid flat on the floor (round 43): shockwaves, crusts. Depth tested, so foes stand on it.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/designed_fx.gdshaderinc"

uniform vec2 grid = vec2(3.0, 2.0);

void fragment() {
	float f = floor(frame + 0.5);
	vec2 cell = vec2(mod(f, grid.x), floor(f / grid.x));
	vec4 d = designed(texture(sheet, (cell + UV) / grid), erode, pal_row);
	ALBEDO = d.rgb;
	ALPHA = d.a * alpha;
}
