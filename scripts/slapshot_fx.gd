extends Node3D
## Slapshot's look (Harpoon's LMB breaker ending, round 47; the gameplay is void_element._slapshot / thrown_foe `slide`):
##   trail(): a frost streak on the floor behind a sliding cube: a pale ice core in a deeper blue edge, drawn from where
##     the fist hit it to where it is, on twos, thinning out at its tail and fading once the cube has stopped;
##   punch(): where the molten fist meets the ice, a burst of steam (comic_steam: the designed cloud);
##   wall(): a cube shattering on a wall: big ice shatter, a ground stamp, chips, the word, a hard stop and shake;
##   cord(): the tentacle running out behind the fist, as on Molten Palm.
## Sleek (docs/features/comic-style.md): two flat fills, no particles left standing, short lives. No crystals.

const SELF := preload("res://scripts/slapshot_fx.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const COMIC_STEAM := preload("res://scripts/comic_steam.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_INK := preload("res://scripts/designed_ink.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const FLYING := "thrown_foe_flying"

const STEP_S := 1.0 / 12.0  # the streak redraws on twos
const TRAIL_W := 0.42  # m half width of the streak's edge (a cube is ~1.2 m across)
const CORE_W := 0.6  # of that, the pale core
const TRAIL_Y := 0.035  # m off the floor
const TRAIL_TAIL := 6.0  # m: the streak thins to nothing this far behind the cube
const TRAIL_FADE := 0.45  # s it fades over once the cube has stopped
const WALL_SHATTER := 1.9  # the designed ice shatter's size on a wall hit (a plain burst: 1.0)
const WALL_STAMP := 1.8  # m: the ground stamp at the wall's foot
const WALL_STOP := 0.07  # s hit stop per wall hit (one each, so a row is a drum roll)
const WALL_WORD := "KER-SMASH!"  # (its own: the breaker words say KRSSSH-BOOM! / THWAKK!)
const WALL_WORD_SIZE := 0.75
const CORD_HOLD := 0.1  # s the cord stays after the fist lands

var _foe: Node3D
var _pts := PackedVector3Array()
var _stopped_t := -1.0
var _t := 0.0
var _step := -1
var _mi: MeshInstance3D
var _mesh := ArrayMesh.new()
static var _mat: StandardMaterial3D


## A frost streak following `e` while it slides (thrown_foe's FLYING meta), then fading.
static func trail(parent: Node, e: Node3D) -> Node3D:
	var fx: Node3D = SELF.new()
	fx._foe = e
	parent.add_child(fx)
	fx.top_level = true
	fx.global_transform = Transform3D.IDENTITY
	fx._pts.append(Vector3(e.global_position.x, TRAIL_Y, e.global_position.z))
	return fx


## Steam where the molten fist meets the ice.
static func punch(parent: Node, spot: Vector3) -> void:
	COMIC_STEAM.spawn(parent, Vector3(spot.x, 0.0, spot.z))


## A cube shattering on a wall at `spot` (its feet), thrown along `dir`.
static func wall(parent: Node, spot: Vector3, dir: Vector3) -> void:
	var at := Vector3(spot.x, 0.0, spot.z)
	DESIGNED.ice_shatter(parent, at + dir * 0.4 + Vector3.UP * 1.0, WALL_SHATTER)
	DESIGNED_INK.shock(parent, at, PAL.of("water").light, WALL_STAMP, 0.3)
	Fx.shards(parent, at + Vector3.UP * 1.0, PAL.of("water").light, 16, -dir + Vector3.UP * 0.6, 9.0, 0.2, 0.6)
	ComicFx.say(WALL_WORD, at + Vector3.UP * 1.6, WALL_WORD_SIZE)
	Game.hitstop(WALL_STOP)
	Game.shake(0.55)
	if Game.camera_rig:
		Game.camera_rig.kick(dir, 0.35)
	Game.sfx("quake", -6.0, 0.08)


## The tentacle out behind the fist for its flight (`time` s) and CORD_HOLD after.
static func cord(hero: Node3D, fist: Node3D, time: float) -> void:
	if not is_instance_valid(fist) or hero.get("_void") == null:
		return
	var t: Node3D = TENDRIL.new()
	hero.get_parent().add_child(t)
	var start := Time.get_ticks_msec()
	var tw := t.create_tween()
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(fist) or not is_instance_valid(hero):
			t.visible = false
			return
		var out := 1.0 - smoothstep(0.8, 1.0, k)
		t.draw(hero._void._hand_pos(), fist.global_position, out, 0.03, 0.0, (Time.get_ticks_msec() - start) / 1000.0), 0.0, 1.0, time + CORD_HOLD)
	tw.tween_callback(t.queue_free)


func _ready() -> void:
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.set_meta("no_ghost", true)
	add_child(_mi)


func _physics_process(delta: float) -> void:
	_t += delta
	var sliding := is_instance_valid(_foe) and _foe.has_meta(FLYING)
	if sliding:
		var p := Vector3(_foe.global_position.x, TRAIL_Y, _foe.global_position.z)
		if p.distance_to(_pts[_pts.size() - 1]) > 0.15:
			_pts.append(p)
	elif _stopped_t < 0.0:
		_stopped_t = _t
	var fade := 1.0
	if _stopped_t >= 0.0:
		fade = 1.0 - (_t - _stopped_t) / TRAIL_FADE
		if fade <= 0.0:
			queue_free()
			return
	var step := int(_t / STEP_S)
	if step == _step and sliding:
		return
	_step = step
	_draw(fade)


func _draw(fade: float) -> void:
	_mesh.clear_surfaces()
	if _pts.size() < 2 or DisplayServer.get_name() == "headless":
		return
	var pal: Dictionary = PAL.of("water")
	var total := 0.0
	for i in range(1, _pts.size()):
		total += _pts[i].distance_to(_pts[i - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer: Array in [[1.0, pal.deep, 0.0], [CORE_W, pal.light, 0.004]]:
		var w: float = TRAIL_W * layer[0]
		var c: Color = layer[1]
		var lift: float = layer[2]
		var from_head := 0.0
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		var prev_a := 0.0
		for i in range(_pts.size() - 1, -1, -1):
			if i < _pts.size() - 1:
				from_head += _pts[i].distance_to(_pts[i + 1])
			var j := mini(i + 1, _pts.size() - 1)
			var k := maxi(i - 1, 0)
			var along := _pts[j] - _pts[k]
			along.y = 0.0
			var side := along.normalized().cross(Vector3.UP) if along.length() > 0.001 else Vector3.RIGHT
			var thin := clampf(1.0 - from_head / minf(TRAIL_TAIL, maxf(total, 0.01)), 0.0, 1.0)
			var l := _pts[i] + side * w * (0.35 + 0.65 * thin) + Vector3.UP * lift
			var r := _pts[i] - side * w * (0.35 + 0.65 * thin) + Vector3.UP * lift
			var a := c.a * fade * thin * (0.9 if lift > 0.0 else 0.75)
			if i < _pts.size() - 1:
				for v: Array in [[prev_l, prev_a], [prev_r, prev_a], [r, a], [prev_l, prev_a], [r, a], [l, a]]:
					st.set_color(Color(c, v[1]))
					st.add_vertex(v[0])
			prev_l = l
			prev_r = r
			prev_a = a
	st.commit(_mesh)
	if _mesh.get_surface_count() > 0:
		_mesh.surface_set_material(0, material())


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.disable_fog = true
	return _mat
