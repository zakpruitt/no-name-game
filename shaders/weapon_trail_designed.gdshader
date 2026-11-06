shader_type spatial;
// The weapon's swing ribbon, designed (round 44 fx-cohesion; weapon_trail.gd picks it unless --fx=classic): the
// pilot's authored brush stroke (slash_strip: pointed head, banded blade light, dry-brush bristle tail) laid
// along the ribbon instead of a soft gradient crescent. UV.x = age along the ribbon (0 at the blade, 1 oldest),
// UV.y = blade base (0) to tip (1); the stroke's head rides the blade and its tail is the oldest sample, so the
// tail erodes first (the sheet's erode order runs along it). COLOR.a fades it; UV2.x = the swell (a heavy hit
// deep in a chain erodes slower). The stroke re-draws on twos through its four boils.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/designed_fx.gdshaderinc"

uniform float rows = 4.0;

void fragment() {
	float age = clamp(UV.x, 0.0, 1.0);
	float swell = clamp(UV2.x, 0.0, 1.0);
	float f = mod(floor(TIME * 12.0), rows);
	vec2 uv = vec2(clamp(1.0 - age, 0.002, 0.998), (f + clamp(1.0 - UV.y, 0.01, 0.99)) / rows);
	vec4 d = designed(texture(sheet, uv), mix(0.12, 0.04, swell) + age * mix(0.55, 0.4, swell), pal_row);
	ALBEDO = d.rgb;
	ALPHA = clamp(d.a * min(COLOR.a * 1.25, 1.0), 0.0, 1.0);
}
