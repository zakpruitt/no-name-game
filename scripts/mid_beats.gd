extends Node3D
## Round 54 cool pass 3 (combo-cool3 lane, docs/features/combo-breakers.md "Round 54 cool pass 3"): the looks of the
## rebuilt mids, so each has a beat of its own with the tentacle or the element visibly doing the control. Gameplay
## (numbers, picks, who is moved) stays in void_element.gd's per-move sections; this file only draws and times.
##   - reel(): tentacles out of a root (Singularity's hole) to the foes it is dragging, drawn out then held, for life s.
##   - hook(): Reap's barb (the `reap_hook` sheet) biting the picked foe, riding it while the tether yanks it in.
##   - frost_spread(): Frost Spear's frost racing out along the floor from the spear to each foe in reach, a rime of
##     frost at its feet when it gets there (on_reach(foe, i) then: the slow).
##   - steam_fuse(): Steam Burst's lava crack running from the fist to each frozen foe and the steam column that goes
##     up where it meets the ice.
##   - gale(): Hailstorm's one twister at the middle of the frozen that draws the cubes in as it lifts them.
## Designed sheets only (designed_fx / designed_elements / designed_twister / void_tendril); no crystals. Headless it
## draws nothing (the reel and the gale still move what they hold, so checks see the gameplay).

const SELF := preload("res://scripts/mid_beats.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const FROST_SHELL := preload("res://scripts/frost_shell.gd")
const TWISTER := preload("res://scripts/designed_twister.gd")
const COMET := preload("res://scripts/comic_comet.gd")
const FLYING := "thrown_foe_flying"
const TRAIL_COLOR := Color(0.55, 0.22, 0.95)  # (the dark's: comic_comet picks the ink smear by the nearest palette)

const SHEETS := {"reap_hook": {"grid": Vector2(3, 2), "frames": 5, "kind": "sprite"}}
const CHEST := Vector3(0.0, 0.85, 0.0)
## The reel: each tentacle reaches its foe in REEL_REACH s, STAGGER s after the one before, and lets go in REEL_LET s.
const REEL_REACH := 0.07
const REEL_STAGGER := 0.03
const REEL_LET := 0.12
const REEL_WAVE := 0.06
const REEL_MOST := 4  # tentacles a reel draws (the nearest; more over a crowd were a thicket)
## Reap's barb: HOOK_SIZE m at the foe's chest, its frames in game time after the first.
const HOOK_SIZE := 1.5
const HOOK_TIMES := [0.04, 0.07, 0.08, 0.1, 0.12]
## Frost Spear's spread: a frost line a foe, nearest first SPREAD_STEP s apart, SPREAD_SPEED m/s along the floor.
const SPREAD_STEP := 0.04
const SPREAD_SPEED := 22.0
const SPREAD_MOST := 5
const RIME_SIZE := 1.5  # frost_mark size at the foe's feet (1.15 read as a speck in the film)
## Steam Burst's fuse: the lava crack reaches each frozen foe FUSE_S s after the one before; the steam column
## (steam_shell, played hot in the earth row on its first frames) STEAM_SIZE m.
const FUSE_STEP := 0.035
const STEAM_SIZE := 4.2
const STEAM_TIMES := [0.03, 0.05, 0.06, 0.07, 0.1, 0.14]
## Hailstorm's gale: one twister GALE_HIGH m, GALE_R m round, for GALE_TIME s; the cubes it lifts are drawn in to
## GALE_IN of the way to its middle over GALE_PULL s.
const GALE_HIGH := 3.6
const GALE_R := 1.5
const GALE_TIME := 0.7
const GALE_IN := 0.55
const GALE_PULL := 0.22
## Round 55 cool pass 4: Rockslide's boulder drops out of the sky (rock_boulder, its first frame held over the fall)
## DROP_SIZE x the designed boulder's size; Meltdown's globs are the molten fireball at GLOB_SIZE of its size.
const DESIGNED_FINISH := preload("res://scripts/designed_finish.gd")
const DESIGNED_INK := preload("res://scripts/designed_ink.gd")
const DROP_SIZE := 2.4  # (round 56, feel-audit6: 1.6 read as a dummy-sized blob at the camera's 800x450)
const DROP_HIGH := 1.05  # m: the boulder's middle over the floor where it lands (comic_boulder.HIGH x the size)
const DROP_DUST := 2.4  # m: the landing's dust
const GLOB_SIZE := 0.7

static var _registered := false
static var reels := 0  # (checks) reels started
static var hooks := 0
static var spreads := 0
static var fuses := 0
static var gales := 0
static var trails := 0
static var drops := 0  # round 55: Rockslide's boulder drops
static var globs := 0  # round 55: Meltdown's globs

var root_node: Node3D  # the reel's root follows this node while it lives (the hole)
var root_at := Vector3.ZERO
var foes: Array = []
var life := 1.0
var _tendrils: Array = []
var _t := 0.0
var _mid := Vector3.ZERO
var _pull: Array = []  # gale: [foe, from xz]
var _trail_of: Node3D  # trail: the flying foe
var _trail_color := TRAIL_COLOR


static func register() -> void:
	if _registered:
		return
	_registered = true
	for n: String in SHEETS:
		var s: Dictionary = SHEETS[n].duplicate()
		s["tex"] = load("res://assets/vfx/designed/%s.png" % n)
		DESIGNED.extra_sheets[n] = s


static func prewarm(root: Node3D) -> void:
	if not DESIGNED.on():
		return
	register()
	for n: String in SHEETS:
		var mi := MeshInstance3D.new()
		mi.mesh = QuadMesh.new()
		mi.material_override = DESIGNED.material(n)
		root.add_child(mi)
		mi.scale = Vector3.ONE * 20.0


static func _draws() -> bool:
	return DisplayServer.get_name() != "headless" and DESIGNED.on() and Game.comic_style


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- the reel (Singularity) -----------------------------------------------------------------------------------------

## Tentacles out of `root` (a node, followed) to the nearest REEL_MOST of `who` for `time` s.
static func reel(parent: Node, root: Node3D, who: Array, time: float) -> Node3D:
	reels += 1
	var g: Node3D = SELF.new()
	g.root_node = root
	g.root_at = root.global_position
	var live: Array = who.filter(func(e: Variant) -> bool: return is_instance_valid(e))
	live.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(g.root_at) < b.global_position.distance_to(g.root_at))
	g.foes = live.slice(0, REEL_MOST)
	g.life = time
	parent.add_child(g)
	return g


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	if not _draws():
		return
	for i in foes.size():
		var t: Node3D = TENDRIL.new()
		add_child(t)
		t.visible = false
		_tendrils.append(t)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _pull.is_empty():
		_gale_tick()
	if _trail_of != null:
		_trail_tick()
		return
	if is_instance_valid(root_node):
		root_at = root_node.global_position
	var let := clampf((life - _t) / REEL_LET, 0.0, 1.0)
	for i in _tendrils.size():
		var t: Node3D = _tendrils[i]
		var e: Variant = foes[i]
		if not is_instance_valid(e) or not (e as Node).has_method("is_alive") or not e.is_alive():
			t.visible = false
			continue
		var reach := clampf((_t - i * REEL_STAGGER) / REEL_REACH, 0.0, 1.0) * let
		var r: Variant = (e as Node).get("radius")
		t.draw(root_at + Vector3.UP * 0.1, (e as Node3D).global_position + CHEST, reach, REEL_WAVE,
			(float(r) if r != null else 0.5) + 0.05, _t)
	if _t >= life:
		queue_free()


# --- Reap's hook ----------------------------------------------------------------------------------------------------

## The barb bites `e` (riding it at its chest); `from` is where the line came from (the sprite faces away from it).
static func hook(parent: Node, e: Node3D, from: Vector3) -> void:
	hooks += 1
	if not _draws():
		return
	register()
	var fx: Node3D = DESIGNED.spawn(parent, "reap_hook", e.global_position + CHEST, HOOK_SIZE, "void", HOOK_TIMES, Vector2(0.55, 1.0))
	fx.real_until = 1
	fx.pop = 0.25
	fx.follow = e
	fx.follow_off = CHEST
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	var mirror := 1.0
	if cam != null:  # (the line comes in from the sheet's left: mirror when he stands to the foe's right on screen)
		mirror = -1.0 if (from - e.global_position).dot(cam.global_basis.x) > 0.0 else 1.0
	fx.set_spin(0.0, mirror)


# --- Frost Spear's spread -------------------------------------------------------------------------------------------

## From the spear at `spot` a frost line runs along the floor to each of `who` (nearest first), and rime takes its feet
## as it arrives: on_reach(foe, i) then.
static func frost_spread(parent: Node, spot: Vector3, who: Array, on_reach: Callable) -> void:
	spreads += 1
	var at := _flat(spot)
	var live: Array = who.filter(func(e: Variant) -> bool: return is_instance_valid(e))
	live.sort_custom(func(a: Node3D, b: Node3D) -> bool: return _flat(a.global_position).distance_to(at) < _flat(b.global_position).distance_to(at))
	live = live.slice(0, SPREAD_MOST)
	for i in live.size():
		var e: Node3D = live[i]
		var to := _flat(e.global_position) - at
		var d := to.length()
		var wait := i * SPREAD_STEP + d / SPREAD_SPEED
		if _draws() and d > 1.2:
			var go := func() -> void:
				if is_instance_valid(parent) and parent.is_inside_tree():
					DESIGNED_EL.fissure(parent, at, to, d, maxi(3, int(d / 0.9)), "water", 1.1, 1.0 / SPREAD_SPEED * 0.9)
			if i == 0:
				go.call()
			else:
				parent.get_tree().create_timer(i * SPREAD_STEP, false).timeout.connect(go)
		var reach := func() -> void:
			if not is_instance_valid(e) or not is_instance_valid(parent) or not parent.is_inside_tree():
				return
			if _draws():
				DESIGNED_EL.frost_mark(parent, _flat(e.global_position), RIME_SIZE, 0.9, true)
			if on_reach.is_valid():
				on_reach.call(e, i)
		parent.get_tree().create_timer(wait, false).timeout.connect(reach)


# --- Steam Burst's fuse ---------------------------------------------------------------------------------------------

## From the fist at `from` a lava crack runs to each frozen spot in `spots` (nearest first) and the steam goes up there.
static func steam_fuse(parent: Node, from: Vector3, spots: Array) -> void:
	fuses += 1
	if not _draws():
		return
	FROST_SHELL.register()
	var at := _flat(from)
	var order: Array = spots.duplicate()
	order.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _flat(a).distance_to(at) < _flat(b).distance_to(at))
	for i in order.size():
		var p: Vector3 = _flat(order[i])
		var to := p - at
		var d := to.length()
		if d > 1.3:
			DESIGNED_EL.fissure(parent, at, to, d, maxi(2, int(d / 1.4)), "earth", 0.6, 0.02)
		var up := func() -> void:
			if not is_instance_valid(parent) or not parent.is_inside_tree():
				return
			var fx: Node3D = DESIGNED.spawn(parent, "steam_shell", p, STEAM_SIZE, "earth" if i % 2 == 0 else "water", STEAM_TIMES, Vector2(0.55, 1.0))
			fx.real_until = 2
			fx.pop = 0.3
			fx.set_spin(0.0, -1.0 if i % 2 else 1.0)
		if i == 0:
			up.call()
		else:
			parent.get_tree().create_timer(i * FUSE_STEP, false).timeout.connect(up)


# --- Hailstorm's gale -----------------------------------------------------------------------------------------------

## One twister at the middle of `cubes`: it draws each in toward the column as the gale lifts it.
static func gale(parent: Node, cubes: Array) -> Node3D:
	gales += 1
	var live: Array = cubes.filter(func(e: Variant) -> bool: return is_instance_valid(e))
	if live.is_empty():
		return null
	var mid := Vector3.ZERO
	for e: Node3D in live:
		mid += _flat(e.global_position)
	mid /= float(live.size())
	var g: Node3D = SELF.new()
	g._mid = mid
	g.life = GALE_PULL
	for e: Node3D in live:
		g._pull.append([e, _flat(e.global_position)])
	parent.add_child(g)
	if _draws():
		TWISTER.spawn(parent, mid, GALE_HIGH, GALE_R + 0.25 * live.size(), GALE_TIME)
	return g


func _gale_tick() -> void:
	var k := clampf(_t / GALE_PULL, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	for p: Array in _pull:
		var e: Variant = p[0]
		if not is_instance_valid(e):
			continue
		var from: Vector3 = p[1]
		var to: Vector3 = from.lerp(_mid, GALE_IN)
		var now: Vector3 = from.lerp(to, k)
		(e as Node3D).global_position = Vector3(now.x, (e as Node3D).global_position.y, now.z)


# --- Rockslide's boulder and Meltdown's globs (round 55) -------------------------------------------------------------

## The boulder falls `high` m onto `spot` in `fall` s (game time) and lands: its impact frames, dust and a ring.
static func boulder_drop(parent: Node, spot: Vector3, fall: float, high: float) -> void:
	drops += 1
	if not _draws():
		return
	DESIGNED_FINISH._register()
	var times: Array = [fall]
	times.append_array(DESIGNED_FINISH.BOULDER_TIMES.slice(1))
	var at := Vector3(spot.x, DROP_HIGH, spot.z)
	var fx: Node3D = DESIGNED.spawn(parent, "rock_boulder", at + Vector3.UP * high, DESIGNED_FINISH.BOULDER_SIZE * DROP_SIZE, "earth", times, Vector2(0.55, 1.0))
	fx.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	fx.create_tween().tween_property(fx, "global_position", at, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	parent.get_tree().create_timer(fall, false).timeout.connect(_boulder_land.bind(parent, spot))


static func _boulder_land(parent: Variant, spot: Vector3) -> void:
	if is_instance_valid(parent) and (parent as Node).is_inside_tree():
		DESIGNED.dust(parent, Vector3(spot.x, 0.0, spot.z), DROP_DUST)
		DESIGNED_INK.shock(parent, Vector3(spot.x, 0.0, spot.z), PAL_EARTH, 2.6, 0.3)


const PAL_EARTH := Color(1.0, 0.5, 0.15)


## A molten glob from `from` to foe `e` arriving in `time` s (game time): the drawn fireball, small, following it.
static func glob(parent: Node, from: Vector3, e: Node3D, time: float) -> void:
	globs += 1
	if not _draws() or time <= 0.0 or not is_instance_valid(e):
		return
	var to: Vector3 = e.global_position + Vector3.UP * 0.6
	var s: Node3D = DESIGNED_EL.meteor_shell(parent, to - from)
	s.top_level = true
	s.global_position = from
	s.scale = Vector3.ONE * GLOB_SIZE
	var tw := s.create_tween()
	tw.tween_property(s, "global_position", to, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)


# --- a thrown foe's trail (Ricochet) --------------------------------------------------------------------------------

## The ink streak behind `e` while it flies (thrown_foe's FLYING), at most `time` s: the dive comet on its model and the
## blot where it lands (comic_comet.gd, Collapse's spit trail).
static func trail(parent: Node, e: Node3D, time: float, color := TRAIL_COLOR) -> Node3D:
	trails += 1
	if not _draws() or not is_instance_valid(e):
		return null
	var g: Node3D = SELF.new()
	g._trail_of = e
	g._trail_color = color
	g.life = time
	parent.add_child(g)
	return g


func _trail_tick() -> void:
	var e := _trail_of
	if _t >= life or not is_instance_valid(e) or not e.has_meta(FLYING) or not (e.get("model") is Node3D):
		if _t > 0.05 or not is_instance_valid(e):
			queue_free()
		return
	COMET.beat(get_parent(), e.get("model"), _trail_color)
