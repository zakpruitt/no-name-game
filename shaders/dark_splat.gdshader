shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, depth_test_disabled;

// One burst of ink facing the camera (dark_fx.gd): on a 2 x 2 QuadMesh. A spiky splat whose middle opens up as
// `progress` runs 0 to 1, in hard cut tones. Its code steps `progress` so it plays like a few drawn frames.

uniform vec3 ink_color : source_color = vec3(0.03, 0.01, 0.06);
uniform vec3 mid_color : source_color = vec3(0.62, 0.3, 1.0);
uniform vec3 hot_color : source_color = vec3(1.0, 0.4, 0.95);
uniform float progress = 0.0;
uniform float seed = 0.0;
uniform float spikes = 5.5;

varying vec2 p;


float hash(vec2 q) {
	q = fract(q * vec2(0.3183, 0.3679) + 0.1);
	q *= 17.0;
	return fract(q.x * q.y * (q.x + q.y));
}


float noise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}


void vertex() {
	mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	face[0] *= length(MODEL_MATRIX[0].xyz);
	face[1] *= length(MODEL_MATRIX[1].xyz);
	face[2] *= length(MODEL_MATRIX[2].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * face;
	p = UV * 2.0 - 1.0;
}


void fragment() {
	float r = length(p);
	float a = atan(p.y, p.x);
	vec2 round_it = vec2(cos(a), sin(a));
	float spike = noise(round_it * spikes + seed);
	spike = spike * spike * spike;
	float outer = (0.34 + 1.5 * spike) * (0.5 + 0.5 * sqrt(progress));
	outer = min(outer, 0.98);
	float wobble = noise(round_it * 2.4 - seed);
	float inner = pow(progress, 1.4) * (0.72 + 0.5 * wobble);
	if (r > outer || r < inner) {
		discard;
	}
	vec3 c = ink_color;
	if (outer - r < 0.03) {
		c = mid_color;
	}
	if (r - inner < 0.05 && progress > 0.0) {
		c = hot_color;
	}
	ALBEDO = c;
}
