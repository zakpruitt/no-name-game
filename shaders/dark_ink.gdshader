shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

// Churning ink lying on the floor (dark_fx.gd): on a 2 x 2 PlaneMesh, scaled to size. Spiral streaks in hard
// cut tones, a wobbling hand-inked rim instead of a perfect circle, stepped time so it moves like drawn frames.
// `open` grows it from the middle and `erode` eats it away in holes.

uniform vec3 ink_color : source_color = vec3(0.03, 0.01, 0.06);
uniform vec3 mid_color : source_color = vec3(0.62, 0.3, 1.0);
uniform vec3 hot_color : source_color = vec3(1.0, 0.4, 0.95);
uniform float spin = 0.9;
uniform float flow = 1.6;
uniform float twist = 0.9;
uniform float fps = 12.0;
uniform float open = 1.0;
uniform float erode = 0.0;
uniform float seed = 0.0;

varying vec2 p;


float hash(vec3 q) {
	q = fract(q * 0.3183099 + 0.1);
	q *= 17.0;
	return fract(q.x * q.y * q.z * (q.x + q.y + q.z));
}


float noise(vec3 q) {
	vec3 i = floor(q);
	vec3 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}


void vertex() {
	p = VERTEX.xz;
}


void fragment() {
	float t = floor(TIME * fps) / fps;
	float r = length(p);
	float a = atan(p.y, p.x);
	float edge = open * (0.82 + 0.18 * noise(vec3(cos(a) * 2.6 + seed, sin(a) * 2.6, t * 0.8)));
	if (r > edge) {
		discard;
	}
	float swirl = a + twist / (r + 0.25) + t * spin;
	float n = noise(vec3(cos(swirl) * 3.2 + seed, sin(swirl) * 3.2, r * 2.6 + t * flow));
	n = n * 0.7 + 0.3 * noise(vec3(cos(swirl) * 5.0 - seed, sin(swirl) * 5.0, r * 7.0 + t * flow * 1.6));
	vec3 c = ink_color;
	if (r > 0.24 && n > 0.655) {
		c = mid_color;
	}
	if (r > 0.4 && n > 0.74) {
		c = hot_color;
	}
	if (edge - r < 0.04) {
		c = mid_color;
	}
	if (erode > 0.0) {
		float e = noise(vec3(p * 3.6 + seed, t * 0.4));
		float cut = erode * 1.05;
		if (e < cut) {
			discard;
		}
		if (e < cut + 0.05) {
			c = hot_color;
		}
	}
	ALBEDO = c;
}
