shader_type spatial;
// The axe's drag line on the floor, designed (round 48, fx-polygons; comic_drag_mark.gd): a strip sheet repeated
// along the line by metres (UV.x is metres / tile, UV.y across), each vertex's age in COLOR.r (0 fresh .. 1 gone):
// the line cools down the palette ramp as it ages and erodes away from its old end. Depth tested: foes stand on it.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/designed_fx.gdshaderinc"

uniform float rows = 4.0;
uniform float cool = 0.5;  // how far down the ramp the line has cooled by the end of its life

void fragment() {
	float age = clamp(COLOR.r, 0.0, 1.0);
	float f = floor(frame + 0.5);
	vec2 uv = vec2(fract(UV.x), (f + clamp(UV.y, 0.01, 0.99)) / rows);
	vec4 tx = texture(sheet, uv);
	tx.r = tx.r < 0.13 ? tx.r : clamp(tx.r - age * cool, 0.25, 1.0);  // (the ink stays ink)
	vec4 d = designed(tx, smoothstep(0.45, 1.0, age) * 0.98, pal_row);
	ALBEDO = d.rgb;
	ALPHA = d.a * alpha;
}
