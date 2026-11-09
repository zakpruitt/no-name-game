extends Node3D
## Spirit echo: the bound ancestor in the axe finishes the swing. A drawn axe head flies the same arc a beat
## after the real hit over a thin ink line (designed_finish.echo_axe / echo_line), hitting each enemy in its
## arc once. Spawned by hero_fx.cast for casts of kind "echo" (elements.CASTS). It sweeps in `time` and is
## gone FADE_OUT later.

const FADE_OUT := 0.06  # (round 33, sleek: 0.14; sleek 5: 0.1 hung it into L3's wind-up)
const HEIGHT := 1.0  # sweep height above the floor
const PAL := preload("res://scripts/fx_palette.gd")
const FILL_SHADER := preload("res://shaders/ghost_halftone.gdshader")
const INK_SHADER := preload("res://shaders/ghost_ink.gdshader")
const FILL := 0.3  # mean alpha of the halftone fill (the slab was 0.6 solid)
const INK_PX := 3.2  # px at 1080p, the ink line's outer edge (ink alone vanished on the indigo floor)
const EDGE_PX := 1.7  # px at 1080p: a crisp light-tone line inside the ink, so the edge reads on the floor
## Per-palette fill tones for ghost_mat (the see-through halftone that the ice cube, comic_column and the Awakening
## column share): earth's orange body tint between the dots read as brown on indigo at 0.3 alpha, so earth and
## water draw clean dots only (`base` is the share of the fill between the dots). Unlisted palettes: body under
## light dots at FILL.
const GHOST_TONES := {"earth": {"body": "body", "dot": "light", "fill": 0.42, "base": 0.04},
	"water": {"body": "body", "dot": "light", "fill": 0.4, "base": 0.12}}
const DESIGNED_FINISH := preload("res://scripts/designed_finish.gd")

var color := Color(0.3, 0.95, 0.85)
var fwd := Vector3.FORWARD
var flip := false  # sweep right-to-left (follows the swing's swoosh)
var arc_deg := 150.0
var radius := 3.2
var damage := 5.0
var delay := 0.05
var time := 0.18
var on_hit := Callable()
var el := "spirit"  # the cast's element (set by hero_fx.cast)

var _pivot: Node3D
var _hit: Array[Node] = []
var _drawn: Node3D  # the drawn axe head


func _ready() -> void:
	rotation.y = atan2(fwd.x, fwd.z)
	_pivot = Node3D.new()
	_pivot.position.y = HEIGHT
	add_child(_pivot)
	pose(0.0)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_start)
	tw.tween_method(pose, 0.0, 1.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(FADE_OUT)
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


## Round 51 (fluidity): a cast that lands where nothing froze lately (the blade whiffed a spread foe, the lash cut one
## far ahead) takes a small stop of its own, so no contact plays at x1.00; inside or just after the blade's stop it
## adds nothing (overlapping stops only extend), so the string's beats don't move.
const CAST_STOP := 0.03  # s, at the freeze scale
const CAST_STOP_GAP_MS := 90  # ms since the last stop ended (150 skipped L2's cast after L1's on the wall_alt film, 118 ms apart)


## One foe struck by a spirit cast: the hit, the combo counter, then the caller's hook (`fx_parent`, `el`,
## `debris_dir` and `big` are kept for the callers: the debris went with Fx.element_hit).
static func strike(e: Node, damage: float, knockback: Vector3, launch: float, heavy: bool,
		_fx_parent: Node, _el: String, _debris_dir: Vector3, _big: bool, on_hit: Callable) -> void:
	e.take_hit(damage, knockback, launch, heavy)
	Game.register_hit("cast")
	if Time.get_ticks_msec() - Game._hitstop_end_ms > CAST_STOP_GAP_MS:
		Game.hitstop(CAST_STOP)
	if on_hit.is_valid():
		on_hit.call(e)


## Sweep position `t` (0 start .. 1 end of the arc); also hits enemies it passes.
func pose(t: float) -> void:
	var half := deg_to_rad(arc_deg) * 0.5
	var side := -1.0 if flip else 1.0
	_pivot.rotation.y = lerpf(-half, half, t) * side
	_pivot.scale = Vector3.ONE * lerpf(0.75, 1.0, minf(t * 3.0, 1.0))  # swells as it comes through
	if t > 0.0 and is_inside_tree():
		_hit_swept(_pivot.rotation.y)


## A small drawn axe head and a thin ink line, in real time (designed_finish).
func _start() -> void:
	_drawn = DESIGNED_FINISH.echo_axe(get_parent(), global_position + Vector3.UP * HEIGHT, color, DESIGNED_FINISH.ECHO_REAL)
	DESIGNED_FINISH.echo_line(get_parent(), global_position, fwd, radius, arc_deg, flip, HEIGHT)
	_pose_drawn(0.0)
	create_tween().set_ignore_time_scale().tween_method(_pose_drawn, 0.0, 1.0, DESIGNED_FINISH.ECHO_REAL).set_ease(
		Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## The drawn axe head at sweep `t` on the drawn arc (designed_finish.ECHO_DRAW of the reach), on real time.
func _pose_drawn(t: float) -> void:
	if _drawn == null or not is_instance_valid(_drawn) or not is_inside_tree():
		return
	var half := deg_to_rad(arc_deg) * 0.5
	var side := -1.0 if flip else 1.0
	var a := lerpf(-half, half, t) * side
	var r := radius * DESIGNED_FINISH.ECHO_DRAW * DESIGNED_FINISH.ECHO_REACH * lerpf(0.75, 1.0, minf(t * 3.0, 1.0))
	var at := global_transform * (Vector3(0, HEIGHT, 0) + Basis(Vector3.UP, a) * Vector3(0, 0, r))
	var ahead := global_transform * (Vector3(0, HEIGHT, 0) + Basis(Vector3.UP, a + 0.2 * side) * Vector3(0, 0, r))
	DESIGNED_FINISH.echo_pose(_drawn, at, ahead)


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
