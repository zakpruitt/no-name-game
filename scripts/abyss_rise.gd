extends Node3D
## Abyss (Overwhelm's window, H, round 51 cool pass; docs/features/combo-breakers.md "Round 51 cool pass"): the
## foes Overwhelm pinned sank under the floor on his dive (floor_bind.sink); when he lands the deep gives them back.
## Per foe, the picked one first (the window's bracket: the cursor's, or the biggest), STEP s apart, in three beats:
##   1. up: a column of tentacles (the `abyss_column` sheet) tears up out of the floor under it and carries it up to
##      APEX m (RISE s, eased out), on_rise(foe, i) as it leaves the floor;
##   2. hang: the column holds it up there HANG s, a tentacle coiled round it from the hole (you see who has it);
##   3. slam: the column folds and drives it straight down into the floor (SLAM s, eased in), on_slam(foe, i) as it
##      hits (void_element._abyss_slam: the hit, the crater).
## Game time (hit stops hold it). Headless it draws nothing but moves them.

const SELF := preload("res://scripts/abyss_rise.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")

const STEP := 0.12  # s between columns
const OPEN := 0.05  # s the floor tears before it comes up (the sheet's first frame)
const RISE := 0.15  # s up to the top
const HANG := 0.1  # s held up there
const SLAM := 0.06  # s back down
const APEX := 1.9  # m (the sheet's column stands 0.65 of its quad, ~2.6 m: the hand at the top holds its chest)
const UNDER := 1.8  # m under the floor they start (the bind sank them)
const COLUMN_SIZE := 4.0  # m: the abyss_column quad
const COLUMN_TIMES := [0.05, 0.08, 0.1, 0.1, 0.06, 0.09, 0.14]
const CHEST := Vector3(0.0, 0.85, 0.0)
const FLYING := "thrown_foe_flying"

var hero: CharacterBody3D
var rises := []  # {foe, i, t0, at, up, slammed, tendril}
var on_rise := Callable()  # (foe, i)
var on_slam := Callable()  # (foe, i)
var slammed := 0  # (checks)
var top := 0.0  # (checks) the highest any got
var _t := 0.0


static func register() -> void:
	if not DESIGNED.extra_sheets.has("abyss_column"):
		DESIGNED.extra_sheets["abyss_column"] = {"tex": load("res://assets/vfx/designed/abyss_column.png"),
			"grid": Vector2(4, 2), "frames": 7, "kind": "sprite_depth", "anchor": Vector2(0.0, -0.36)}


static func prewarm(root: Node3D) -> void:
	register()
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	mi.material_override = DESIGNED.material("abyss_column")
	root.add_child(mi)
	mi.scale = Vector3.ONE * 20.0


## `foes`: who comes back up (the bind's), in the order they come (void_element._abyss: the picked one first).
static func start(by: CharacterBody3D, foes: Array) -> Node3D:
	var g: Node3D = SELF.new()
	g.hero = by
	var live: Array = foes.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.is_alive())
	for i in live.size():
		var e: Node3D = live[i]
		g.rises.append({"foe": e, "i": i, "t0": i * STEP, "at": Vector3(e.global_position.x, 0.0, e.global_position.z),
			"up": false, "slammed": false})
	by.get_parent().add_child(g)
	return g


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for one: Dictionary in rises:
		one.tendril = TENDRIL.new()
		add_child(one.tendril)
		(one.foe as Node).set_meta(FLYING, true)
		(one.foe as Node3D).global_position = one.at + Vector3.DOWN * UNDER


func _physics_process(delta: float) -> void:
	_t += delta
	var left := false
	for one: Dictionary in rises:
		var e: Variant = one.foe
		var tendril: Node3D = one.tendril
		if one.slammed or not is_instance_valid(e) or not e.is_alive():
			tendril.visible = false
			if not one.slammed:
				_land(one)
			continue
		left = true
		var foe := e as Node3D
		var local: float = _t - float(one.t0)
		if local < 0.0:
			tendril.visible = false
			continue
		if not one.has("fx"):
			one.fx = true
			_column(one)
		var y := -UNDER
		var k := local - OPEN
		if k >= 0.0 and not one.up:
			one.up = true
			if on_rise.is_valid():
				on_rise.call(foe, int(one.i))
		if k < 0.0:
			y = -UNDER
		elif k < RISE:  # 1. up
			var j := k / RISE
			y = lerpf(-UNDER, APEX, 1.0 - (1.0 - j) * (1.0 - j))
		elif k < RISE + HANG:  # 2. hang
			y = APEX + sin((k - RISE) / HANG * PI) * 0.15
		else:  # 3. slam
			var j := clampf((k - RISE - HANG) / SLAM, 0.0, 1.0)
			y = lerpf(APEX, 0.0, j * j)
			if j >= 1.0:
				foe.global_position = Vector3(one.at.x, 0.0, one.at.z)
				_land(one)
				if on_slam.is_valid():
					on_slam.call(foe, int(one.i))
				continue
		top = maxf(top, y)
		foe.global_position = Vector3(one.at.x, y, one.at.z)
		if foe is CharacterBody3D:
			(foe as CharacterBody3D).velocity = Vector3.ZERO
		var coil: float = float(foe.get("radius")) + 0.05
		tendril.draw(one.at + Vector3.UP * 0.05, foe.global_position + CHEST, 1.0 if k >= 0.0 else 0.0, 0.03, coil, _t)
	if not left:
		queue_free()


func _land(one: Dictionary) -> void:
	one.slammed = true
	slammed += 1
	(one.tendril as Node3D).visible = false
	var e: Variant = one.foe
	if is_instance_valid(e):
		if (e as Node).has_meta(FLYING):
			(e as Node).remove_meta(FLYING)
		if (e as Node3D).global_position.y < 0.0 or (e as Node3D).global_position.y > 0.0:
			(e as Node3D).global_position.y = 0.0


func _column(one: Dictionary) -> void:
	if not is_inside_tree():
		return
	register()
	var size: float = COLUMN_SIZE * (1.0 if int(one.i) == 0 else 0.85)
	var fx: Node3D = DESIGNED.spawn(get_parent(), "abyss_column", one.at, size, "void", COLUMN_TIMES, Vector2(0.55, 1.0))
	fx.real_until = 1
	fx.set_spin(0.0, -1.0 if int(one.i) % 2 else 1.0)
	var cam := get_viewport().get_camera_3d()
	if cam != null:  # stood behind the foe from the camera (depth tested: the foe reads in front of the column)
		var away: Vector3 = one.at - cam.global_position
		fx.global_position += Vector3(away.x, 0.0, away.z).normalized() * 0.45


func _exit_tree() -> void:
	for one: Dictionary in rises:  # (freed mid-throw: nobody stays in the air or under the floor)
		if not one.slammed:
			_land(one)
