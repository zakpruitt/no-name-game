extends Node3D
## Spirit echo: the bound ancestor in the axe finishes the swing. A giant
## spectral copy of the hero's axe sweeps the same arc a beat after the real
## hit, laid flat so its silhouette reads from the top-down camera, hitting
## each enemy in its arc once and leaving a swoosh. Spawned by player._cast
## for casts of kind "echo" (elements.CASTS).
## Round 33 (sleek): a thin ink line round a see-through halftone fill (about FILL alpha) in the element's
## palette (fx_palette: teal spirit, gold Awakened), not a 60% slab under an additive rim. It sweeps in
## `time` and is gone FADE_OUT later.

const FADE_IN := 0.04
const FADE_OUT := 0.1  # (round 33, sleek: 0.14)
const HEIGHT := 1.0  # sweep height above the floor
const PAL := preload("res://scripts/fx_palette.gd")
const FILL_SHADER := preload("res://shaders/ghost_halftone.gdshader")
const INK_SHADER := preload("res://shaders/ghost_ink.gdshader")
const FILL := 0.3  # mean alpha of the halftone fill (the slab was 0.6 solid)
const INK_PX := 3.2  # px at 1080p, the ink line's outer edge (ink alone vanished on the indigo floor)
const EDGE_PX := 1.7  # px at 1080p: a crisp light-tone line inside the ink, so the edge reads on the floor
## Round 33, part 3: the fill fades along the haft toward the hand (axe-local Y: the KayKit 1H_Axe's grip end is
## at -0.27, the blade starts about 0.22), so the 3 m ghost reads as a blade sweeping, not a teal slab.
## ghost_halftone `local_fade`: clear at x, full from y (the blade's middle). The ink line keeps 45% down the haft.
## (-0.2, 0.32) faded only the grip and read the same as no fade at the game camera.
## Round 33, part 3: per-palette fill tones where body + light at FILL sank into the indigo floor. Earth's orange
## body tint between the dots read as brown on indigo at 0.3 alpha (a light body under hot dots read as khaki);
## clean dots only (`base` 0.04, the share of the fill between the dots) at 0.42 read as printed orange.
## Unlisted palettes: body under light dots at FILL.
const GHOST_TONES := {"earth": {"body": "body", "dot": "light", "fill": 0.42, "base": 0.04}}
const HAFT_FADE := Vector2(0.1, 0.6)

var axe_mesh: Mesh
var color := Color(0.3, 0.95, 0.85)
var fwd := Vector3.FORWARD
var flip := false  # sweep right-to-left (follows the swing's swoosh)
var arc_deg := 150.0
var radius := 3.2
var damage := 5.0
var delay := 0.05
var time := 0.18
var on_hit := Callable()
var el := "spirit"  # element of the hit debris (Fx.element_hit)

var _pivot: Node3D
var _axe: MeshInstance3D
var _hit: Array[Node] = []
var _scale := 1.0


func _ready() -> void:
	rotation.y = atan2(fwd.x, fwd.z)
	_pivot = Node3D.new()
	_pivot.position.y = HEIGHT
	add_child(_pivot)
	var axe := ghost(axe_mesh, color)
	axe.set_instance_shader_parameter("local_fade", HAFT_FADE)
	_axe = axe
	# Axe-local: handle +Y, blade toward -X, thin in Z. Lay it flat: handle points
	# out from the hero (+Z), blade leads the sweep, flat side faces the camera.
	var side := -1.0 if flip else 1.0
	var basis := Basis(Vector3(-side, 0, 0), Vector3(0, 0, 1), Vector3(0, side, 0))
	_scale = maxf(radius - 0.4, 0.5) / 0.95  # blade tip lands on the arc's edge
	axe.transform = Transform3D(basis.scaled(Vector3.ONE * _scale), Vector3(0, 0, 0.4))
	_pivot.add_child(axe)
	pose(0.0)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_start)
	tw.tween_method(pose, 0.0, 1.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(set_alpha.bind(_axe), 1.0, 0.0, FADE_OUT)
	tw.tween_callback(queue_free)


static var _mats := {}  # palette name -> the shared ghost material chain


## A spectral copy of `mesh` in the palette nearest `c` (ghost_mat). Starts invisible: set_alpha() fades it.
static func ghost(mesh: Mesh, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ghost_mat(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_alpha(0.0, mi)
	return mi


## The see-through comic look in the palette nearest `c`, shared: a depth-only pass, the halftone fill
## (ghost_halftone.gdshader), the ink line and a light line inside it (ghost_ink.gdshader), chained as next
## passes so the lines only show past the silhouette. The fade (set_alpha) and the height gradient
## (`fade_height`) are instance parameters, so every ghost, spike and column of a palette shares these.
static func ghost_mat(c: Color) -> Material:
	var key := PAL.nearest(c)
	if _mats.has(key):
		return _mats[key]
	var pal := PAL.of(key)
	var depth := ShaderMaterial.new()
	depth.shader = FILL_SHADER
	depth.set_shader_parameter("depth_only", true)
	depth.render_priority = 0
	var fill := ShaderMaterial.new()
	fill.shader = FILL_SHADER
	var tones: Dictionary = GHOST_TONES.get(key, {})
	fill.set_shader_parameter("body_color", pal[tones.get("body", "body")])
	fill.set_shader_parameter("dot_color", pal[tones.get("dot", "light")])
	fill.set_shader_parameter("fill", tones.get("fill", FILL))
	if tones.has("base"):
		fill.set_shader_parameter("base", tones.base)
	fill.render_priority = 1
	var ink := ShaderMaterial.new()
	ink.shader = INK_SHADER
	ink.set_shader_parameter("ink_color", pal.ink)
	ink.set_shader_parameter("width_px", INK_PX)
	ink.render_priority = 2
	var edge := ShaderMaterial.new()  # same hull, narrower, drawn over the ink's inner half
	edge.shader = INK_SHADER
	edge.set_shader_parameter("ink_color", pal.light)
	edge.set_shader_parameter("width_px", EDGE_PX)
	edge.render_priority = 3
	depth.next_pass = fill
	fill.next_pass = ink
	ink.next_pass = edge
	_mats[key] = depth
	return depth


## A ghost's fade, 0..1 (fill and lines together).
static func set_alpha(a: float, mi: GeometryInstance3D) -> void:
	mi.set_instance_shader_parameter("alpha", a)


## One foe struck by a spirit cast: the hit, the combo counter, element debris
## at the foe (`debris_dir`, `big`) under `fx_parent`, then the caller's hook.
static func strike(e: Node, damage: float, knockback: Vector3, launch: float, heavy: bool,
		fx_parent: Node, el: String, debris_dir: Vector3, big: bool, on_hit: Callable) -> void:
	e.take_hit(damage, knockback, launch, heavy)
	Game.register_hit("cast")
	Fx.element_hit(fx_parent, e.global_position, el, debris_dir, big)
	if on_hit.is_valid():
		on_hit.call(e)


## Sweep position `t` (0 start .. 1 end of the arc); also hits enemies it passes.
func pose(t: float) -> void:
	var half := deg_to_rad(arc_deg) * 0.5
	var side := -1.0 if flip else 1.0
	_pivot.rotation.y = lerpf(-half, half, t) * side
	_pivot.scale = Vector3.ONE * lerpf(0.75, 1.0, minf(t * 3.0, 1.0))  # swells as it comes through
	if _axe != null and t > 0.0:
		set_alpha(minf(t / (FADE_IN / time), 1.0), _axe)
	if t > 0.0 and is_inside_tree():
		_hit_swept(_pivot.rotation.y)


func _start() -> void:
	Fx.swoosh(get_parent(), global_position, fwd, radius, arc_deg, Color(color, 0.9), flip, time * 1.4, HEIGHT)


## Enemies within reach whose bearing the blade has passed are hit once.
func _hit_swept(angle: float) -> void:
	var side := -1.0 if flip else 1.0
	var half := deg_to_rad(arc_deg) * 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in _hit or not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() > radius + e.radius:
			continue
		var bearing := fwd.signed_angle_to(to.normalized(), Vector3.UP)
		# Swept so far: bearings from the start of the arc up to the blade's angle.
		var start := -half * side
		if bearing * side < start * side or bearing * side > angle * side:
			continue
		_hit.append(e)
		strike(e, damage, to.normalized() * 5.0, 0.0, false, get_parent(), el, to.normalized(), false, on_hit)
