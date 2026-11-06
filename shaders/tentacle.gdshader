shader_type spatial;
// The hero's tentacle (void_tendril.gd, round 44 fx-cohesion): a camera-facing ribbon along a smooth spine that
// tapers from a fat base to a point. The skin is an authored tiling strip (tools/vfx_gen/gen_cohesion.py
// tentacle_skin: back shadow with wrinkle ticks, a light belly with suckers, a hot highlight dash) through the
// void palette; the silhouette ink is drawn here at a fixed width in metres (so the thin tip keeps its line),
// brushed by a slow wobble along the length; the last CLAW_M before the end is the light claw tip.
// UV.x: skin repeats (arc length over the local width), UV.y: across (0 back, 1 belly).
// UV2.x: half width in metres, UV2.y: metres to the end.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

#include "res://shaders/designed_fx.gdshaderinc"

uniform float rows = 3.0;
uniform float ink_m = 0.06;  // the outline, metres
uniform float rim_m = 0.03;  // the paper rim outside the ink (the hero's own rim colour), metres
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.84, 1.0);
uniform float claw_m = 0.24;  // the light claw tip, metres from the end
instance uniform float thin = 0.0;  // 1: a pinning cord (body and ink only)
instance uniform vec4 tint = vec4(0.0);  // rgb, amount: an electrified / charged wash over the body (not the ink)

void fragment() {
	float hw = max(UV2.x, 0.001);
	float across = abs(UV.y * 2.0 - 1.0);
	float brush = 0.012 * sin(UV.x * 23.0 + UV.y * 3.0) + 0.008 * sin(UV.x * 61.0);
	float rim_frac = clamp(rim_m / hw, 0.0, 0.3) * (1.0 - thin);
	float ink_frac = clamp((ink_m + brush) / hw, 0.0, 0.62) + rim_frac;
	float aa = fwidth(across) * 1.2;
	float ink = smoothstep(1.0 - ink_frac - aa, 1.0 - ink_frac + aa, across);
	float rim = smoothstep(1.0 - rim_frac - aa, 1.0 - rim_frac + aa, across) * step(0.001, rim_frac);
	vec3 body;
	if (thin > 0.5) {
		body = tone_color(pal_row, 2.0);
	} else {
		float f = floor(frame + 0.5);
		vec2 uv = vec2(fract(UV.x), (f + clamp(UV.y, 0.02, 0.98)) / rows);
		vec4 s = texture(sheet, uv);
		body = ramp(s.r, pal_row);
		// the claw: a light tip with a wavy edge and a hot line along its back
		float claw_edge = claw_m * (1.0 + 0.25 * sin(UV.y * 6.0));
		float claw = 1.0 - smoothstep(claw_edge - 0.012, claw_edge + 0.012, UV2.y);
		vec3 claw_col = mix(tone_color(pal_row, 3.0), tone_color(pal_row, 4.0), step(UV.y, 0.42) * step(0.18, UV.y));
		body = mix(body, claw_col, claw);
		// an ink line where the claw meets the flesh
		float seam = (1.0 - smoothstep(0.0, 0.025, abs(UV2.y - claw_edge))) * step(0.001, claw_m);
		body = mix(body, tone_color(pal_row, 0.0), seam);
	}
	body = mix(body, tint.rgb, tint.a);
	ALBEDO = mix(mix(body, tone_color(pal_row, 0.0), ink), rim_color.rgb, rim);
}
