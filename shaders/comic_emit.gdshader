shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// Flat stepped colour for anything that glows, the port of comic_poc/comic_lib.py
// `emit`: three cut tones along the mesh's `g` attribute, no bloom. Glow is drawn,
// not lit. The GLBs keep `g` in COLOR_1, which Godot drops; tools/comic_glb.py swaps
// it into COLOR_0 when copying into assets/comic.

uniform vec3 low_color : source_color = vec3(0.2, 0.85, 0.3);
uniform vec3 mid_color : source_color = vec3(0.6, 0.93, 0.44);
uniform vec3 high_color : source_color = vec3(0.9, 1.0, 0.55);


void fragment() {
	float g = COLOR.r;
	ALBEDO = g < 0.42 ? low_color : (g < 0.72 ? mid_color : high_color);
}
