shader_type spatial;
// The drawn smear behind a fast tentacle lash (void_tendril.gd): an authored strip (gen_cohesion.py
// tentacle_smear) stretched between the tentacle's last pose (UV.y 0) and this one (UV.y 1), root to tip along
// UV.x. Solid at the front edge, dry-brush streaks behind. `alpha` fades it; it is cut, not blended, so it reads
// as ink and paint rather than a blur.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

#include "res://shaders/designed_fx.gdshaderinc"

uniform float rows = 2.0;

void fragment() {
	float f = floor(frame + 0.5);
	vec2 uv = vec2(clamp(UV.x, 0.002, 0.998), (f + clamp(UV.y, 0.01, 0.99)) / rows);
	vec4 s = texture(sheet, uv);
	float keep = s.a * step(1.0 - alpha, s.g * 0.6 + UV.y * 0.4);
	if (keep < 0.5) {
		discard;
	}
	ALBEDO = ramp(s.r, pal_row);
}
