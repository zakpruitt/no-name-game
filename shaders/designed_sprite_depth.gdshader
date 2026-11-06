shader_type spatial;
// designed_sprite.gdshader with the depth test on (big bursts stood behind a pile: the foes in front stay in
// front). A designed flipbook sprite (round 43, docs/features/designed-fx.md): camera-facing, drawn over the pile like
// the flat comic effects (no depth test), turned in the screen plane by `spin`. The quad's local size is its
// scale (DesignedFx sets it); `anchor` lifts the pivot so a sheet drawn standing on its ground line sits on the floor.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/designed_fx.gdshaderinc"

uniform vec2 grid = vec2(4.0, 2.0);  // columns, rows
uniform vec2 anchor = vec2(0.0, 0.0);  // the pivot, in quad units (-0.5..0.5) from its middle
instance uniform float spin = 0.0;  // radians in the screen plane
instance uniform float flip = 1.0;  // -1 mirrors it

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec2 q = (VERTEX.xy - anchor) * sc.xy;
	q.x *= flip;
	float cs = cos(spin), sn = sin(spin);
	q = vec2(q.x * cs - q.y * sn, q.x * sn + q.y * cs);
	vec4 v = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	v.xy += q;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	float f = floor(frame + 0.5);
	vec2 cell = vec2(mod(f, grid.x), floor(f / grid.x));
	vec2 uv = (cell + UV) / grid;
	vec4 d = designed(texture(sheet, uv), erode, pal_row);
	ALBEDO = d.rgb;
	ALPHA = d.a * alpha;
}
