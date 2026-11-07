extends Node3D
## Breaker spectacle (docs/features/combo-breakers.md "Presentation", designed-fx.md "Breaker spectacle"): every
## breaker ending's landing as one comic-book beat, shared by every ending, in the element's shape language.
## Sheets: tools/vfx_gen/gen_spectacle.py, registered here in DESIGNED.extra_sheets.
##
## A landing (`landing(hero)`, fired by impact_frame.gd when the hero's breakers_landed goes up, so no gameplay file
## calls it) plays on real time, in beats:
##   0       the impact frame (impact_frame.slam: the element's own negative, halftone and speed lines on the spot),
##           the camera jolt (camera_rig.jolt: a damped shake along the element's axis) and FOV snap, the landing
##           stop's shape (Game.slam_stop: a crunch freeze, then a short slow exhale)
##   BEAT_S  (past the negative) the burst behind the pile (slam_star / magma / frost / ink, depth tested: the foes
##           stay in front), radial speed lines thrown out (slam_rays), the floor-wide spread (floor_arcs / cracks /
##           splat), the pillars near it shaking dust off their tops
##   AFTER_S the after-beat on each foe struck: smoke curling off (magma), cold mist (ice), dark wisps (dark), arcs
##           crackling (storm, DESIGNED.crawl)
## The ending's name and the landing's total go up as one callout banner on the screen layer (`Screen`, below);
## callout_cap / comic_number keep their logic and fade their own copies out of sight.
## Other lanes (a new ending) need nothing: a landing gets all of it. An ending that wants an extra beat can call
## `burst()`, `spread()`, `after_beat()` or `wall_star()` itself.
##   const DESIGNED_BREAKER := preload("res://scripts/designed_breaker.gd")
##   DESIGNED_BREAKER.wall_star(parent, at, "earth")

const DESIGNED := preload("res://scripts/designed_fx.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const SELF := preload("res://scripts/designed_breaker.gd")
const CANVAS := preload("res://shaders/designed_canvas.gdshader")
const FOES := preload("res://scripts/foes.gd")
const NUMBER := preload("res://scripts/comic_number.gd")

const SHEETS := {
	"slam_star": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite_depth"},
	"slam_magma": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite_depth"},
	"slam_frost": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite_depth"},
	"slam_ink": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite_depth"},
	"slam_rays": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"floor_cracks": {"grid": Vector2(3, 2), "frames": 6, "kind": "ground"},
	"floor_arcs": {"grid": Vector2(3, 2), "frames": 6, "kind": "ground"},
	"floor_splat": {"grid": Vector2(3, 2), "frames": 6, "kind": "ground"},
	"wall_star": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"smoke_curl": {"grid": Vector2(4, 2), "frames": 8, "kind": "sprite_depth", "anchor": Vector2(0.0, -0.35)},
}

## Each element's family: the shapes it lands in and how the landing feels.
const FAMILY := {"wind": "storm", "water": "ice", "earth": "magma", "void": "dark"}  # (spirit, gold, hit: storm's stars)
const LOOK := {
	"storm": {"burst": "slam_star", "floor": "floor_arcs", "after": "crackle"},
	"magma": {"burst": "slam_magma", "floor": "floor_cracks", "after": "smoke"},
	"ice": {"burst": "slam_frost", "floor": "floor_cracks", "after": "mist", "rays": false},  # (pale tapered rays read as ice crystals)
	"dark": {"burst": "slam_ink", "floor": "floor_splat", "after": "wisp", "floor_size": 0.72},
}
## jolt: camera_rig.jolt metres (at REF_DIST), hz, decay /s, axis (screen x, y); fov: x camera_rig.FOV_ENDER;
## crunch: real s of the landing's freeze at CRUNCH_SCALE, then tail real s at tail_scale (Game.slam_stop).
## Storm snaps and buzzes sideways, magma thuds down and rumbles, ice cracks short and hard, dark sinks slow.
const FEEL := {
	"storm": {"jolt": 0.32, "hz": 22.0, "decay": 9.0, "axis": Vector2(1.0, 0.35), "fov": 1.3, "crunch": 0.05, "tail": 0.1, "tail_scale": 0.35},
	"magma": {"jolt": 0.5, "hz": 9.0, "decay": 5.5, "axis": Vector2(0.15, 1.0), "fov": 1.6, "crunch": 0.07, "tail": 0.12, "tail_scale": 0.3},
	"ice": {"jolt": 0.34, "hz": 15.0, "decay": 11.0, "axis": Vector2(0.45, 1.0), "fov": 1.2, "crunch": 0.09, "tail": 0.05, "tail_scale": 0.4},
	"dark": {"jolt": 0.42, "hz": 6.5, "decay": 4.5, "axis": Vector2(0.0, 1.0), "fov": 1.5, "crunch": 0.06, "tail": 0.14, "tail_scale": 0.25},
}
const PERFECT_FEEL := 1.25  # jolt and fov on a perfect

const BEAT_S := 0.11  # real s: the burst waits out the impact frame (two inked flash frames hide anything earlier)
const AFTER_S := 0.42  # real s: the after-beat on the struck
const LIFE_S := 1.4

const BURST_SIZE := 4.0  # m: the burst's square (its spikes reach ~1.7 m round the pile; 4.8 hid the pile)
const BURST_UP := 1.15  # m: its middle over the floor
const BURST_BACK := 1.0  # m behind the pile, away from the camera (depth tested: the foes stay in front)
const BURST_TIMES := [0.035, 0.09, 0.07, 0.07, 0.08, 0.1]
const RAYS_SIZE := 8.0  # m: the speed lines' square (their clear middle is ~1.2 m round the pile)
const RAYS_UP := 1.0
const RAYS_TIMES := [0.035, 0.07, 0.055, 0.055, 0.06, 0.07]
const FLOOR_SIZE := 8.0  # m: the spread's square (cracks / arcs reach ~3.8 m)
const FLOOR_TIMES := [0.04, 0.09, 0.12, 0.16, 0.2, 0.26]
const PERFECT_SIZE := 1.12
const PILE_R := 3.5  # m: foes this close to the landing make the pile (its middle is where it all goes)

const AFTER_REACH := 4.5  # m: struck foes that get the after-beat
const AFTER_MAX := 4
const SMOKE_SIZE := 1.7
const SMOKE_TIMES := [0.06, 0.09, 0.1, 0.1, 0.11, 0.12, 0.13, 0.15]
const AFTER_ROW := {"smoke": "dust", "mist": "water", "wisp": "void"}

const PILLAR_REACH := 8.0  # m: pillars this close shake on a landing
const PILLAR_SHAKE := 0.07  # m at the landing (falls off to 0 at PILLAR_REACH)
const PILLAR_SHAKE_S := 0.35
const PILLAR_TOP := 3.6  # m: where their dust falls from

const WALL_STAR_SIZE := 2.6
const WALL_STAR_TIMES := [0.035, 0.08, 0.07, 0.07, 0.08, 0.1]
const WALL_META := "last_wall_ms"  # thrown_foe.WALL_META: a foe splatted on a wall, when

static var _registered := false
static var landings := 0  # landings drawn (checks)
static var wall_stars := 0
static var _screen: Node = null

var _hero: Node3D
var _at := Vector3.ZERO
var _el := "spirit"
var _fam := "storm"
var _perfect := false
var _t := 0.0
var _last_us := 0
var _beat := 0
var _struck: Array = []


static func _register() -> void:
	if _registered:
		return
	_registered = true
	for n: String in SHEETS:
		var s: Dictionary = SHEETS[n].duplicate()
		s["tex"] = load("res://assets/vfx/designed/%s.png" % n)
		DESIGNED.extra_sheets[n] = s


## Draw every material once at real size (elements.prewarm).
static func prewarm(root: Node3D) -> void:
	if not DESIGNED.on():
		return
	_register()
	for n: String in SHEETS:
		var mi := MeshInstance3D.new()
		mi.mesh = PlaneMesh.new() if SHEETS[n].kind == "ground" else QuadMesh.new()
		mi.material_override = DESIGNED.material(n)
		root.add_child(mi)
		mi.scale = Vector3.ONE * 20.0


static func family(element: String) -> String:
	return FAMILY.get(PAL.ALIAS.get(element, element), "storm")


## The breaker that just landed, read off the hero (hero_leap leaves _brk, _brk_ended and the element on him).
static func info(hero: Node) -> Dictionary:
	var out := {"element": "spirit", "name": "", "perfect": hero.get("_brk_ended") == "perfect", "at": Vector3.ZERO}
	if hero is Node3D:
		var p: Vector3 = (hero as Node3D).global_position
		out.at = Vector3(p.x, 0.0, p.z)
	if not "_brk" in hero or not hero.has_method("breaker_window"):
		return out
	var b: Variant = hero.get("_brk")
	if b is Dictionary and not (b as Dictionary).is_empty():
		var leap: GDScript = hero.HERO_LEAP
		out.element = leap.element(hero)
		out.name = leap.breaker_name(hero)
	return out


## A breaker landed (impact_frame._watch_hero): the whole beat. Returns the timeline node (null when designed
## effects are off or there is no world to draw in).
static func landing(hero: Node) -> Node3D:
	if not DESIGNED.on() or not hero is Node3D or not hero.is_inside_tree() or hero.get_parent() == null:
		return null
	_register()
	landings += 1
	var inf := info(hero)
	var fx: Node3D = SELF.new()
	fx._hero = hero
	fx._el = inf.element
	fx._fam = family(inf.element)
	fx._perfect = inf.perfect
	fx._at = _pile_middle(hero.get_tree(), inf.at)
	hero.get_parent().add_child(fx)
	fx.top_level = true
	fx.global_position = fx._at
	fx._feel()
	var s := screen(hero)
	if s != null and inf.name != "":
		s.callout(inf.name, inf.element, inf.perfect)
	return fx


## The middle of the foes within PILE_R of `at` (the burst goes up on the pile, not beside it).
static func _pile_middle(tree: SceneTree, at: Vector3) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for e: Node in tree.get_nodes_in_group("enemies"):
		var p: Vector3 = (e as Node3D).global_position
		if Vector2(p.x - at.x, p.z - at.z).length() < PILE_R:
			sum += Vector3(p.x, 0.0, p.z)
			n += 1
	return at if n == 0 else (at + sum) / float(n + 1)


func _ready() -> void:
	_last_us = Time.get_ticks_usec()


func _feel() -> void:
	var f: Dictionary = FEEL[_fam]
	var k := PERFECT_FEEL if _perfect else 1.0
	var rig: Node = Game.camera_rig
	if rig != null and rig.has_method("jolt"):
		rig.jolt(f.jolt * k, f.hz, f.decay, f.axis)
		rig.fov_punch(rig.FOV_ENDER * f.fov * k)
	if Game.has_method("slam_stop"):
		Game.slam_stop(f.crunch, f.tail, f.tail_scale)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	_t += (now - _last_us) / 1000000.0
	_last_us = now
	if _beat == 0 and _t >= BEAT_S:
		_beat = 1
		_struck = FOES.near(get_tree(), _at, AFTER_REACH).slice(0, AFTER_MAX)
		var parent := get_parent()
		var k := PERFECT_SIZE if _perfect else 1.0
		burst(parent, _at, _el, k)
		if LOOK[family(_el)].get("rays", true):
			rays(parent, _at, _el, k)
		spread(parent, _at, _el, k)
		shake_pillars(get_tree(), _at)
	if _beat == 1 and _t >= AFTER_S:
		_beat = 2
		for i in _struck.size():
			var e: Variant = _struck[i]
			if is_instance_valid(e) and (e as Node).is_inside_tree():
				after_beat(get_parent(), e, _el, i)
	if _t >= LIFE_S:
		queue_free()


# --- the beats (public: an ending can add one of its own) ---------------------------------------------------------

## The landing's burst behind the pile at `at` (floor), in the element's shapes.
static func burst(parent: Node, at: Vector3, element: String, size := 1.0) -> Node3D:
	_register()
	var back := _away_from_camera(parent, at) * BURST_BACK
	var fx := DESIGNED.spawn(parent, LOOK[family(element)].burst, at + Vector3.UP * BURST_UP + back, BURST_SIZE * size, element, BURST_TIMES, Vector2(0.5, 1.0))
	fx.pop = 0.15
	return fx.vary(0.3, true)


## Radial speed lines thrown out from the landing, over the pile (their middle is clear).
static func rays(parent: Node, at: Vector3, element: String, size := 1.0) -> Node3D:
	_register()
	var fx := DESIGNED.spawn(parent, "slam_rays", at + Vector3.UP * RAYS_UP, RAYS_SIZE * size, element, RAYS_TIMES, Vector2(0.45, 1.0))
	return fx.vary(PI, true)


## The floor-wide spread: arcs racing over it (storm), cracks (magma hot, ice cold), an ink splash (dark).
static func spread(parent: Node, at: Vector3, element: String, size := 1.0) -> Node3D:
	_register()
	var look: Dictionary = LOOK[family(element)]
	size *= look.get("floor_size", 1.0)  # (the splat is a solid pool, not lines: 0.72 keeps a Maw under the coverage budget)
	var fx := DESIGNED.spawn(parent, look.floor, Vector3(at.x, DESIGNED.GROUND_LIFT, at.z), FLOOR_SIZE * size, element, FLOOR_TIMES, Vector2(0.55, 1.0))
	fx.real_until = 1
	fx.rotation.y = randf() * TAU
	return fx


## The after-beat on a struck foe: smoke, mist or dark wisps curling off it, or arcs crackling on it (storm).
static func after_beat(parent: Node, foe: Node3D, element: String, i := 0) -> Node3D:
	_register()
	var kind: String = LOOK[family(element)].after
	if kind == "crackle":
		return DESIGNED.crawl(parent, foe, 1.15)
	var back := _away_from_camera(parent, foe.global_position) * 0.35
	var off := Vector3(0.0, 0.25, 0.0) + back
	var fx := DESIGNED.spawn(parent, "smoke_curl", foe.global_position + off, SMOKE_SIZE * (1.0 if i % 2 == 0 else 0.85), AFTER_ROW[kind], SMOKE_TIMES, Vector2(0.5, 1.0))
	fx.follow = foe
	fx.follow_off = off
	fx.standing = true
	return fx.set_spin(randf_range(-0.15, 0.15), -1.0 if i % 2 else 1.0)


## A drawn impact star on a wall where a foe was splatted (thrown_foe's wall splat; Screen watches for them).
static func wall_star(parent: Node, at: Vector3, element := "hit") -> Node3D:
	_register()
	wall_stars += 1
	var fx := DESIGNED.spawn(parent, "wall_star", at, WALL_STAR_SIZE, element, WALL_STAR_TIMES, Vector2(0.5, 1.0))
	fx.real_until = 1
	fx.pop = 0.2
	return fx.vary(0.5, true)


## Every pillar (main's grab_anchors) within PILLAR_REACH of `at` shudders and drops dust off its top.
static func shake_pillars(tree: SceneTree, at: Vector3) -> void:
	for p: Node in tree.get_nodes_in_group("grab_anchors"):
		if not p is Node3D:
			continue
		var n := p as Node3D
		var d := Vector2(n.global_position.x - at.x, n.global_position.z - at.z).length()
		if d > PILLAR_REACH or n.has_meta("bs_shaking"):
			continue
		var amp := PILLAR_SHAKE * (1.0 - d / PILLAR_REACH)
		var home := n.position
		n.set_meta("bs_shaking", true)
		var tw := n.create_tween()
		tw.set_ignore_time_scale(true)
		for k in 6:
			var s := (1.0 if k % 2 == 0 else -1.0) * amp * (1.0 - k / 6.0)
			tw.tween_property(n, "position", home + Vector3(s, 0.0, -s * 0.5), PILLAR_SHAKE_S / 6.0)
		tw.tween_property(n, "position", home, 0.03)
		tw.tween_callback(n.remove_meta.bind("bs_shaking"))
		if amp > PILLAR_SHAKE * 0.3 and n.get_parent() != null:
			var dust := DESIGNED.dust(n.get_parent(), n.global_position, 0.9)
			dust.global_position.y = PILLAR_TOP * 0.35


static func _away_from_camera(node: Node, at: Vector3) -> Vector3:
	var cam := node.get_viewport().get_camera_3d() if node.is_inside_tree() else null
	if cam == null:
		return Vector3.ZERO
	var d := at - cam.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.ZERO


# --- the screen layer ---------------------------------------------------------------------------------------------

## The one screen layer (made on the first call; impact_frame.gd makes it at load): the hang's focus lines and
## vignette, the landing's callout banner, the wall-splat watch.
static func screen(from: Node = null) -> Node:
	if is_instance_valid(_screen):
		return _screen
	if from == null or not from.is_inside_tree():
		return null
	_screen = Screen.new()
	from.get_tree().root.get_node("Game").add_child(_screen)
	return _screen


static func canvas_material(sheet: String, grid: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CANVAS
	m.set_shader_parameter("sheet", load("res://assets/vfx/designed/%s.png" % sheet))
	m.set_shader_parameter("grid", grid)
	return m


static func set_tones(m: ShaderMaterial, element: String, light_mix := 0.0) -> void:
	var p: Dictionary = PAL.of(element)
	m.set_shader_parameter("c_ink", p.ink)
	m.set_shader_parameter("c_deep", p.deep)
	m.set_shader_parameter("c_body", p.body)
	m.set_shader_parameter("c_light", (p.light as Color).lerp(Color(1.0, 0.96, 0.85), light_mix))
	m.set_shader_parameter("c_hot", p.hot)


class Screen extends CanvasLayer:
	## The hang: manga focus lines in from the screen's edges (hang_focus, boiling on twos) and a vignette in a dark
	## tone of the breaker's element, faint from take-off, full once the window opens, gone on the press.
	const FOCUS_RISE := 0.25  # of FOCUS_ALPHA before the window opens
	const FOCUS_ALPHA := 0.5
	const FOCUS_REDUCED := 0.5  # x with reduce_flashing
	const VIGNETTE := 0.42  # the vignette's edge alpha in the window
	const FOCUS_IN := 10.0  # per real s
	const FOCUS_OUT := 14.0
	## The callout: the ending's name and the landing's running total on one slanted banner, top centre.
	const CALL_Y := 0.135  # of the screen height: the banner's middle
	const CALL_Y_LOW := 0.86  # where it goes when a cued or wall-splatted foe is under it (Pinwheel's wall, Meteor's)
	const CALL_DODGE_MS := 1500  # a wall splat this fresh counts
	const CALL_DODGE_PAD := 0.06  # of the screen height round the banner
	const PIECE_SAMPLES := [-2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0]  # m along a cued piece's up axis (round 53)
	const CALL_W := 0.5  # of the screen width: the widest banner (WORLDBREAKER and its total)
	const CALL_MAX_W := 900.0
	const CALL_ASPECT := 0.22  # the banner's height over its widest width (the sheet's band is squashed to it)
	const CALL_MIN_W := 0.24  # of the screen width: the narrowest banner (a short name)
	const CALL_BAND := Vector4(0.0, 0.27, 1.0, 0.44)  # the banner's rows in its square
	const CALL_IN_S := 0.07  # real s: the stroke slashing in (frame 0)
	const CALL_HOLD_S := 0.9  # real s whole at least
	const CALL_AFTER_ADD_S := 0.45  # and this long after the total's last add
	const CALL_MAX_S := 1.6
	const CALL_OUT_S := 0.18
	const NAME_PX := 0.085  # of the screen height
	const NUM_PX := 0.075
	const TAG_PX := 0.046
	const GOLD := Color(1.0, 0.82, 0.3)
	const INK := Color(0.012, 0.01, 0.02)
	const PAPER := Color(1.0, 0.96, 0.84)
	const HOT := Color(1.0, 0.86, 0.12)
	const PRINT := Color(0.9, 0.12, 0.04)

	var focus: TextureRect
	var vignette: ColorRect
	var banner: TextureRect
	var text: Control
	var _focus_mat: ShaderMaterial
	var _banner_mat: ShaderMaterial
	var _vig_mat := ShaderMaterial.new()
	var _focus := 0.0
	var _last_us := 0
	var _font: Font
	# the callout
	var call_name := ""
	var call_total := 0.0
	var call_perfect := false
	var _call_t := -1.0  # real s since it went up (-1: none)
	var _call_since := 0.0  # real s since the total last grew
	var _call_ms := 0  # when it went up
	var _call_from_ms := 0  # a breaker total that started at or after this is the callout's
	var _call_low := false  # moved to the bottom, off a cued / wall-splatted foe
	var _call_y := 0.135
	const CALL_TOTAL_MS := 400  # a breaker total that starts up to this long before the callout is the landing's
	## Round 54 (camera-hang lane): how the banner leaves the top for the bottom when it must dodge. "cut" (round 53:
	## it jumps there with a pop) or "slide" (CALL_SLIDE_STEPS frames on twos down the screen, faded, then whole at the
	## bottom; never resting on the middle). `--banner=slide` plays the other one (Zak's call: see camera.md).
	const CALL_MOVE := "cut"
	const CALL_SLIDE_STEPS := [Vector2(0.2, 0.4), Vector2(0.8, 0.65)]  # (of the way down, alpha) per frame
	const CALL_STEP_S := 1.0 / 12.0
	var move_mode := CALL_MOVE
	var _move_t := -1.0  # real s into the move down (-1: none)
	var dodged := 0  # callouts that had to dodge (checks, the camera-hang probe)
	## Round 54 (feel audit 6 item 10: Eruption's banner showed no total, its damage lands over the beats): while the
	## banner is up and not fading it counts every hit into its total (comic_number.banner_open), as Live Wire's
	## shocks count in the hang, and stays CALL_AFTER_ADD_S past the last one, up to CALL_COUNT_MAX_S.
	const CALL_COUNT_MAX_S := 2.4
	var _shown_total := -1.0
	var _pop := 0.0
	var shown := 0  # callouts drawn (checks)
	var _warm := 4  # frames left of the load-time warm-up
	const WARM_ALPHA := 0.004
	var _walls := {}  # foe instance id -> last wall ms seen

	func _ready() -> void:
		layer = 2
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--banner="):
				move_mode = arg.get_slice("=", 1)
		_font = load("res://assets/fonts/Bangers-Regular.ttf")
		_last_us = Time.get_ticks_usec()
		vignette = ColorRect.new()
		vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform vec3 tint : source_color;\nuniform float strength = 0.0;\nvoid fragment() {\n\tfloat d = length((UV - 0.5) * vec2(1.25, 1.0));\n\tCOLOR = vec4(tint, smoothstep(0.38, 0.78, d) * strength);\n}\n"
		_vig_mat.shader = sh
		vignette.material = _vig_mat
		vignette.visible = false
		add_child(vignette)
		focus = TextureRect.new()
		focus.set_anchors_preset(Control.PRESET_FULL_RECT)
		focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		focus.stretch_mode = TextureRect.STRETCH_SCALE
		focus.texture = load("res://assets/vfx/designed/hang_focus.png")
		_focus_mat = SELF.canvas_material("hang_focus", Vector2(2, 2))
		focus.material = _focus_mat
		focus.visible = false
		add_child(focus)
		banner = TextureRect.new()
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_SCALE
		banner.texture = load("res://assets/vfx/designed/callout_panel.png")
		_banner_mat = SELF.canvas_material("callout_panel", Vector2(2, 2))
		_banner_mat.set_shader_parameter("band", CALL_BAND)
		banner.material = _banner_mat
		banner.visible = false
		add_child(banner)
		text = Control.new()
		text.set_anchors_preset(Control.PRESET_FULL_RECT)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.draw.connect(_draw_text)
		add_child(text)

	## The ending's name goes up (its total follows comic_number's breaker total).
	func callout(name_: String, element: String, perfect: bool) -> void:
		call_name = name_.to_upper()
		call_perfect = perfect
		_call_low = false
		_call_y = CALL_Y
		call_total = 0.0
		_shown_total = -1.0
		_call_t = 0.0
		_call_since = 0.0
		_call_ms = Time.get_ticks_msec()
		_call_from_ms = _call_ms - CALL_TOTAL_MS
		_move_t = -1.0
		# a total already counting (the hang's chain hits: Live Wire's shocks) is the ending's too: the banner
		# takes it over from there
		var live: Node3D = SELF.NUMBER._breaker
		if is_instance_valid(live):
			_call_from_ms = mini(_call_from_ms, SELF.NUMBER.breaker_ms)
		shown += 1
		_adds_at_call = SELF.NUMBER.banner_adds
		SELF.set_tones(_banner_mat, element, 0.0)  # (the element, even on a perfect: the PERFECT tag is the gold)

	func _process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		var dt := clampf((now - _last_us) / 1000000.0, 0.0, 0.1)
		_last_us = now
		if _warm > 0:  # (the three canvas materials drawn near-invisible for a few frames at load: their shaders
			_warm -= 1  # compile then, not in the first hang)
			var on := _warm > 0
			for c: CanvasItem in [vignette, focus, banner]:
				c.visible = on
				c.modulate.a = WARM_ALPHA if on else 1.0
			banner.size = Vector2(32.0, 8.0)
			return
		var hero := get_tree().get_first_node_in_group("player")
		_hang(hero, dt)
		_callout_tick(dt)
		_watch_walls(hero)

	func _hang(hero: Node, dt: float) -> void:
		var want := 0.0
		var el := "spirit"
		var brk: Variant = hero.get("_brk") if hero != null else null
		if hero != null and hero.has_method("breaker_window") and brk is Dictionary and (brk as Dictionary).has("open"):
			var w: Dictionary = hero.breaker_window()
			if w.get("live", false):
				want = 1.0 if float(w.get("t", 0.0)) >= float(w.get("open", 0.0)) else FOCUS_RISE
				var opts: Array = w.get("options", [])
				el = (opts[opts.size() - 1] as Dictionary).get("element", "spirit") if not opts.is_empty() else "spirit"
		_focus = lerpf(_focus, want, 1.0 - exp(-(FOCUS_IN if want > _focus else FOCUS_OUT) * dt))
		var on := _focus > 0.01
		focus.visible = on
		vignette.visible = on
		if not on:
			return
		if want > 0.0:
			SELF.set_tones(_focus_mat, el, 0.55)
			var p: Dictionary = PAL.of(el)
			_vig_mat.set_shader_parameter("tint", (p.ink as Color).lerp(p.deep, 0.35))
		var red := FOCUS_REDUCED if Game.reduce_flashing else 1.0
		_focus_mat.set_shader_parameter("alpha", FOCUS_ALPHA * _focus * red)
		_focus_mat.set_shader_parameter("frame", float(int(Time.get_ticks_msec() / 83) % 4))
		_vig_mat.set_shader_parameter("strength", VIGNETTE * _focus)

	func _callout_tick(dt: float) -> void:
		if _call_t < 0.0:
			banner.visible = false
			SELF.NUMBER.banner_open = false
			return
		_call_t += dt
		_call_since += dt
		var total: float = SELF.NUMBER.breaker_total
		var started: int = SELF.NUMBER.breaker_ms
		if started >= _call_from_ms and total != call_total:
			call_total = total
			_call_since = 0.0
			_pop = 1.0
		var live: Node3D = SELF.NUMBER._breaker
		if is_instance_valid(live) and live.visible and SELF.NUMBER.breaker_ms >= _call_from_ms:
			live.visible = false  # (the banner carries it now)
		_pop = maxf(0.0, _pop - dt * 9.0)
		var end := _end_s()
		SELF.NUMBER.banner_open = _call_t < end
		SELF.NUMBER.banner_from_ms = _call_from_ms
		if _call_t >= end + CALL_OUT_S:
			_call_t = -1.0
			banner.visible = false
			SELF.NUMBER.banner_open = false
			text.queue_redraw()
			return
		var vp := get_viewport().get_visible_rect().size
		var w := minf(vp.x * CALL_W, CALL_MAX_W)
		var h := w * CALL_ASPECT
		w = clampf(_text_w(vp) + h * 1.1, vp.x * CALL_MIN_W, w)  # (fits the words: MAW is not as wide as WORLDBREAKER)
		banner.size = Vector2(w, h)
		var top := Rect2(vp.x * 0.5 - w * 0.5, vp.y * CALL_Y - h * 0.5, w, h).grow(vp.y * CALL_DODGE_PAD)
		var low := Rect2(vp.x * 0.5 - w * 0.5, vp.y * CALL_Y_LOW - h * 0.5, w, h).grow(vp.y * CALL_DODGE_PAD)
		if not _call_low and _foe_under(top) and not _foe_under(low, true):
			_call_low = true  # (once a callout: it never flips back)
			dodged += 1
			_pop = 1.0  # round 53 (feel audit 5): it cuts to the bottom with a pop; the slide crossed the middle of the
			# screen, over the pile, for ~0.2 s (Flash Freeze, Abyss, Shatterstorm, Avalanche, Uproot films)
			if move_mode == "slide":
				_move_t = 0.0
				_pop = 0.0
		_call_y = CALL_Y_LOW if _call_low else CALL_Y
		var move_a := 1.0
		if _move_t >= 0.0:  # the slide-fade: a step down the screen a frame, faded, then whole at the bottom
			var k := int(_move_t / CALL_STEP_S)
			_move_t += dt
			if k < CALL_SLIDE_STEPS.size():
				var st: Vector2 = CALL_SLIDE_STEPS[k]
				_call_y = lerpf(CALL_Y, CALL_Y_LOW, st.x)
				move_a = st.y
			else:
				_move_t = -1.0
				_pop = 1.0
		banner.position = Vector2(vp.x * 0.5 - w * 0.5, vp.y * _call_y - h * 0.5)
		banner.visible = true
		SELF.NUMBER.banner_rect = Rect2(banner.position, banner.size + Vector2(0.0, h * BANNER_TAG_H))
		var fr := 0.0 if _call_t < CALL_IN_S else 1.0 + float(int(_call_t * 12.0) % 3)
		_banner_mat.set_shader_parameter("frame", minf(fr, 3.0))
		_banner_mat.set_shader_parameter("erode", clampf((_call_t - end) / CALL_OUT_S, 0.0, 1.0) * 0.98)
		_banner_mat.set_shader_parameter("alpha", move_a)
		_move_a = move_a
		text.queue_redraw()

	const BANNER_TAG_H := 0.6  # of the banner's height: the PERFECT tag under it (round 56: words keep off both)
	var _move_a := 1.0  # the slide-fade's alpha this frame (the words follow it)

	## When the banner starts to go: held CALL_HOLD_S at least, CALL_AFTER_ADD_S past the total's last add, at most
	## CALL_MAX_S, or CALL_COUNT_MAX_S once a beat after the landing's own total has counted in (round 54).
	func _end_s() -> float:
		var most := CALL_COUNT_MAX_S if _counted_late else CALL_MAX_S
		return clampf(maxf(CALL_HOLD_S, _call_t - _call_since + CALL_AFTER_ADD_S), 0.0, most)

	var _counted_late: bool:
		get:
			return SELF.NUMBER.banner_adds > _adds_at_call
	var _adds_at_call := 0

	## Is a foe the camera was cued to (camera_rig.FRAME_CUE) or one fresh off a wall splat on screen inside `r`?
	## (Pinwheel throws the kebab into the top wall after the landing: the payoff must not sit under the banner.)
	## Round 56 (feel-audit6): the breaker scene's own foes count too (camera_rig's actors: Meteor Fall's pile and the
	## keg's burst sat under the banner, which only dodged cued foes), by their middle and their heads (ACTOR_HEAD up).
	## `low`: the check on the bottom band before the cut; the banner stays up if a foe is under that one too.
	func _foe_under(r: Rect2, low := false) -> bool:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return false
		var now := Time.get_ticks_msec()
		var rig: Variant = Game.camera_rig
		var actors: Dictionary = rig.get("_actors") if rig is Object and is_instance_valid(rig) and rig.get("_actors") is Dictionary else {}
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			var foe := e as Node3D
			if foe == null:
				continue
			var cued := int(foe.get_meta(&"frame_cue_ms", 0)) > now
			var walled := foe.has_meta(SELF.WALL_META) and now - int(foe.get_meta(SELF.WALL_META)) < CALL_DODGE_MS
			var actor := actors.has(foe.get_instance_id())
			if not (cued or walled or actor):
				continue
			for up: float in ([0.0, 1.0, ACTOR_HEAD] if low else ([1.0, ACTOR_HEAD] if actor else [1.0])):
				var at := foe.global_position + Vector3.UP * up
				if not cam.is_position_behind(at) and r.has_point(cam.unproject_position(at)):
					return true
		return _piece_under(r, cam, now)

	const ACTOR_HEAD := 1.8  # m: a scene foe's head and the word over it

	## Round 53 (env-flourish): a cued room piece counts like a cued foe (Uproot's pillar on its fall line, a hook with
	## a foe hung on it, a spilled brazier): points up its length (its own up axis, so a pillar lying down too).
	func _piece_under(r: Rect2, cam: Camera3D, now: int) -> bool:
		for n: Node in get_tree().get_nodes_in_group("env"):
			var p := n as Node3D
			if p == null or int(p.get_meta(&"frame_cue_ms", 0)) <= now:
				continue
			for k: float in PIECE_SAMPLES:
				var at := p.global_transform * Vector3(0.0, k, 0.0)
				if not cam.is_position_behind(at) and r.has_point(cam.unproject_position(at)):
					return true
		return false

	## The callout's words' width (the name and its total at their settled size), for the banner to fit.
	func _text_w(vp: Vector2) -> float:
		var name_w := _font.get_string_size(call_name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(vp.y * NAME_PX)).x
		var num := str(roundi(call_total)) if call_total > 0.0 else ""
		if num == "":
			return name_w
		return name_w + vp.y * 0.02 + _font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, int(vp.y * NUM_PX)).x

	func _draw_text() -> void:
		if _call_t < CALL_IN_S * 0.5 or not banner.visible:
			return
		var vp := get_viewport().get_visible_rect().size
		var end := _end_s()
		var a := (1.0 - clampf((_call_t - end) / (CALL_OUT_S * 0.7), 0.0, 1.0)) * _move_a
		var settle := clampf((_call_t - CALL_IN_S) / 0.1, 0.0, 1.0)
		var r := banner.get_rect()
		var mid_y := r.position.y + r.size.y * 0.5
		var name_px := int(vp.y * NAME_PX * lerpf(1.3, 1.0, settle))
		var num_px := int(vp.y * NUM_PX * (1.0 + 0.3 * _pop))
		var num := str(roundi(call_total)) if call_total > 0.0 else ""
		var num_w := _font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, num_px).x if num != "" else 0.0
		var name_w := _font.get_string_size(call_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
		var gap := vp.y * 0.02
		var x := r.position.x + r.size.x * 0.5 - (name_w + (gap + num_w if num != "" else 0.0)) * 0.5
		_word(Vector2(x, mid_y + name_px * 0.36), call_name, name_px, PAPER, a)
		if num != "":
			_word(Vector2(x + name_w + gap, mid_y + num_px * 0.36), num, num_px, HOT, a)
		if call_perfect:
			var tag_px := int(vp.y * TAG_PX)
			var tag := "PERFECT!"
			var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_px).x
			var tag_y := r.position.y - tag_px * 0.1 if _call_low else r.end.y + tag_px * 0.2  # (above it at the bottom)
			_word(Vector2(r.end.x - tw * 0.85, tag_y), tag, tag_px, GOLD, a)

	## Words-font text with the words' ink and red print offset (ComicFx's words).
	func _word(at: Vector2, s: String, px: int, fill: Color, a: float) -> void:
		var ink_px := maxi(4, int(px * 0.16))
		text.draw_string_outline(_font, at + Vector2(px * 0.05, px * 0.06), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink_px, Color(INK, a))
		text.draw_string(_font, at + Vector2(px * 0.05, px * 0.06), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(PRINT, a))
		text.draw_string_outline(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink_px, Color(INK, a))
		text.draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(fill, a))

	## A foe splatted on a wall (thrown_foe sets WALL_META): a drawn impact star on the wall behind it, the pillars
	## near it shake. Read only, so no gameplay file changes.
	func _watch_walls(hero: Node) -> void:
		if not DESIGNED.on():
			return
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if not e.has_meta(SELF.WALL_META):
				continue
			var ms: int = e.get_meta(SELF.WALL_META)
			var id := e.get_instance_id()
			if _walls.get(id, ms) == ms and _walls.has(id):
				continue
			var fresh := not _walls.has(id) and Time.get_ticks_msec() - ms > 200
			_walls[id] = ms
			if fresh:
				continue  # (one that was splatted before we looked)
			var foe := e as Node3D
			var out := Vector3.ZERO
			if hero is Node3D:
				out = foe.global_position - (hero as Node3D).global_position
				out.y = 0.0
				out = out.normalized() if out.length() > 0.01 else Vector3.ZERO
			var el := "hit"
			if hero != null and hero.has_method("breaker_window") and hero.get("state") == hero.State.LEAP:
				el = hero.HERO_LEAP.element(hero)
			SELF.wall_star(foe.get_parent(), Vector3(foe.global_position.x, 1.1, foe.global_position.z) + out * 0.7, el)
			SELF.shake_pillars(get_tree(), foe.global_position)
			if Game.camera_rig and Game.camera_rig.has_method("jolt"):
				Game.camera_rig.jolt(0.18, 14.0, 10.0, Vector2(out.x, 0.6))
