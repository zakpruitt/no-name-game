shader_type spatial;
// Round 46 (fx-elements, docs/features/designed-fx.md): a faceted mesh drawn as authored flat facets, for the 3D
// objects that must stay 3D (the ice block round a frozen foe, the frost spear). Each face takes one cel tone by which
// way it faces the camera (lit facet / body facet / shadow facet, so a spinning cube flips its facets on twos), a light
// rim band along its edges, one hot specular stripe on lit faces and a straight ink crack on some. See-through in the
// middle so the foe inside shows. The ink line round the silhouette is ghost_ink.gdshader's hull (next pass).
// Mesh contract (designed_elements.facet_*): COLOR.rgb = the face's flat normal * 0.5 + 0.5, COLOR.a = a per-face
// seed; NORMAL = corner normals (for the ink hull); UV 0..1 across each face (fan triangles keep x at 0.5).
render_mode unshaded, cull_back, depth_draw_always, blend_mix, shadows_disabled;

uniform vec4 c_ink : source_color = vec4(0.02, 0.04, 0.12, 1.0);
uniform vec4 c_deep : source_color = vec4(0.12, 0.36, 0.78, 1.0);
uniform vec4 c_body : source_color = vec4(0.42, 0.78, 1.0, 1.0);
uniform vec4 c_light : source_color = vec4(0.88, 0.97, 1.0, 1.0);
uniform vec4 c_hot : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fill_alpha = 0.42;  // the see-through middle of a face (1 = opaque: the spear's shaft)
uniform float rim = 0.085;  // of the face: the light band along its edges
uniform float crack_chance = 0.5;
instance uniform float alpha = 1.0;  // (the same three instance uniforms, in this order, as ghost_ink: its hull pass)
instance uniform float fade_height = 0.0;
instance uniform vec2 local_fade = vec2(0.0, 0.0);

varying vec3 v_flat;
varying float v_seed;

void vertex() {
	v_flat = normalize((MODELVIEW_MATRIX * vec4(COLOR.rgb * 2.0 - 1.0, 0.0)).xyz);
	v_seed = COLOR.a;
}

float hash(float x) {
	return fract(sin(x * 91.345 + 7.13) * 43758.5453);
}

void fragment() {
	vec3 n = normalize(v_flat);
	float lit = dot(n, normalize(vec3(-0.55, 0.72, 0.42)));
	vec3 c = lit > 0.42 ? c_light.rgb : (lit > -0.08 ? c_body.rgb : c_deep.rgb);
	float a = fill_alpha + (lit > 0.42 ? 0.12 : 0.0);
	float e = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float aa = fwidth(e) * 1.2 + 0.002;
	float band = 1.0 - smoothstep(rim - aa, rim + aa, e);
	vec3 bc = lit > 0.42 ? c_hot.rgb : c_light.rgb;
	c = mix(c, bc, band);
	a = mix(a, 0.95, band);
	// one hot specular stripe across a lit face, parallel to its diagonal
	float d = UV.x + UV.y;
	float s0 = 0.55 + 0.25 * hash(v_seed * 3.0);
	float stripe = (smoothstep(s0 - aa * 2.0, s0, d) - smoothstep(s0 + 0.09, s0 + 0.09 + aa * 2.0, d))
		* step(0.2, UV.x) * step(UV.x, 0.8) * step(0.12, lit);
	c = mix(c, c_hot.rgb, stripe);
	a = mix(a, 0.95, stripe);
	// a straight ink crack on some faces
	if (hash(v_seed * 7.0) < crack_chance) {
		float ang = hash(v_seed * 11.0) * 3.1416;
		vec2 p = vec2(0.3 + 0.4 * hash(v_seed * 13.0), 0.3 + 0.4 * hash(v_seed * 17.0));
		vec2 dn = vec2(-sin(ang), cos(ang));
		float dist = abs(dot(UV - p, dn));
		float along = abs(dot(UV - p, vec2(cos(ang), sin(ang))));
		float w = 0.012 * (1.0 - smoothstep(0.05, 0.32, along));
		float crack = (1.0 - smoothstep(w, w + aa, dist)) * step(along, 0.32) * step(rim, e);
		c = mix(c, c_ink.rgb, crack);
		a = mix(a, 0.95, crack);
	}
	ALBEDO = c;
	ALPHA = a * alpha;
}
