extends Node3D
## Collapse (H H's window, round 51 cool pass; docs/features/combo-breakers.md "Round 51 cool pass"): the hole the
## Singularity gathered them round swallows them and spits them out, one at a time, into the structure the indicator
## marks (env_target "collapse"), or straight up out of the floor in the open. Per foe, in three beats:
##   1. grab: a tentacle whips up out of the hole to the foe (REACH s, a little later for each: STAGGER) and coils it;
##   2. swallow: it drags the foe down into the hole (SWALLOW s, sinking SINK m under the floor), on_swallow(foe) as it
##      goes under (the hit);
##   3. spit: from SPIT_FIRST s, SPIT_STEP apart, the hole spits each back out (the `void_spit` sheet: tentacles
##      bursting up), on_spit(foe) launching it (void_element._collapse_spit: into the structure, or up).
## Big ones are coiled where they stand and never go under: on_swallow hits them, on_spit hits them again.
## Game time (hit stops hold it). Headless it draws nothing but moves them.
##   var g := COLLAPSE_SPIT.start(hero, hole_spot, foes)
##   g.on_swallow = func(e): ...;  g.on_spit = func(e, i): ...

const SELF := preload("res://scripts/collapse_spit.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")

const STAGGER := 0.03  # s between tentacles leaving the hole
const REACH := 0.07  # s up out of the hole to a foe
const SWALLOW := 0.14  # s it drags the foe down into the hole
const SINK := 1.3  # m under the floor it holds them (out of sight: the hole's ink is over them)
const IN_R := 0.35  # m round the hole's middle they go down (not one on another)
const SPIT_FIRST := 0.36  # s from the landing to the first spit
const SPIT_STEP := 0.11  # s between spits
const SPIT_TOWARD := -0.5  # m along the camera's look (negative: toward it)
const SPIT_SIZE := 4.4  # m: the void_spit quad (its tentacles stand ~2 m over the floor)
const SPIT_TIMES := [0.04, 0.06, 0.07, 0.08, 0.08, 0.1, 0.12]
const WAVE := 0.06
const CHEST := Vector3(0.0, 0.85, 0.0)
const FLYING := "thrown_foe_flying"
const LET_GO := 0.12  # s the tentacles draw back into the hole after their foe is spat
## Round 52 (combo-cool2): each spit is its own beat. A fat ink crown thrown up out of the hole (`spit_burst`, BURST_SIZE m,
## sprite, over the foe), a word each (void_element._collapse_spit), and the foe's own ink trail as it flies (the dark
## breaker dive's comet on its model, comic_comet.gd: a streak behind it and a blot where it lands), TRAIL_S s at most.
const BURST_SIZE := 3.4
const BURST_TIMES := [0.035, 0.06, 0.06, 0.07, 0.08, 0.1]
const BURST_UP := 0.6  # m over the hole's middle (it's a camera-facing sprite: drawn over the foe it spits)
const TRAIL_S := 0.55
const COMET := preload("res://scripts/comic_comet.gd")
const TRAIL_COLOR := Color(0.55, 0.22, 0.95)  # (the dark's: comic_comet picks the ink smear by the nearest palette)
## Round 54 (camera-hang lane; feel audit 6 item 10: in the open the spits flew off the bottom-right edge, H H 030-036).
## A spit leaves the hole on the side the foe is set down on (void_element._collapse_spit throws it out from the hole's
## middle), so the side is picked here. A structure the indicator marks still takes the throw (it aims at the face);
## in the open it is the way with the most room on screen, SPIT_REACH m out, never past SPIT_EDGE of it; each
## spit after the first fans SPIT_FAN off the last.
const SPIT_REACH := 5.0  # m: about where a spit in the open comes down (COLLAPSE_THROW x 0.5 off the floor, 10 up)
const SPIT_EDGE := 0.8  # of the half-screen: the farthest out a landing may be
const SPIT_DIRS := 16  # ways tried round the hole
const SPIT_FAN := 0.55  # rad between spits
const SPIT_SET := 0.6  # m from the hole's middle it is set down on that side
var spit_dirs: Array[Vector3] = []  # the way each spit went (checks)

var hero: CharacterBody3D
var hole := Vector3.ZERO
var grabs := []  # {foe, heavy, t0, from, to, swallowed, spat, spit_t, tendril, i}
var on_swallow := Callable()  # (foe) it goes under
var on_spit := Callable()  # (foe, i) it comes back out
var spat := 0  # (checks)
var bursts := 0  # (checks) spit_burst crowns thrown
var _trails := []  # {foe, until}: spat foes trailing ink
var _t := 0.0


static func register() -> void:
	if not DESIGNED.extra_sheets.has("void_spit"):
		DESIGNED.extra_sheets["void_spit"] = {"tex": load("res://assets/vfx/designed/void_spit.png"), "grid": Vector2(4, 2),
			"frames": 7, "kind": "sprite_depth", "anchor": Vector2(0.0, -0.31)}
	if not DESIGNED.extra_sheets.has("spit_burst"):
		DESIGNED.extra_sheets["spit_burst"] = {"tex": load("res://assets/vfx/designed/spit_burst.png"), "grid": Vector2(3, 2),
			"frames": 6, "kind": "sprite", "anchor": Vector2(0.0, -0.17)}


static func prewarm(root: Node3D) -> void:
	register()
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	mi.material_override = DESIGNED.material("void_spit")
	root.add_child(mi)
	mi.scale = Vector3.ONE * 20.0
	var burst := MeshInstance3D.new()
	burst.mesh = QuadMesh.new()
	burst.material_override = DESIGNED.material("spit_burst")
	root.add_child(burst)
	burst.scale = Vector3.ONE * 20.0


static func start(by: CharacterBody3D, at: Vector3, foes: Array, heavy: Callable) -> Node3D:
	var g: Node3D = SELF.new()
	g.hero = by
	g.hole = Vector3(at.x, 0.0, at.z)
	var live: Array = foes.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.is_alive())
	live.sort_custom(func(a: Node3D, c: Node3D) -> bool:  # nearest the hole first: they go down in rings
		return Vector3(a.global_position.x, 0.0, a.global_position.z).distance_to(g.hole) < Vector3(c.global_position.x, 0.0, c.global_position.z).distance_to(g.hole))
	for i in live.size():
		var e: Node3D = live[i]
		var a := TAU * i / maxf(live.size(), 1.0)
		g.grabs.append({"foe": e, "heavy": heavy.call(e), "t0": i * STAGGER, "i": i, "swallowed": false, "spat": false,
			"spit_t": SPIT_FIRST + i * SPIT_STEP, "to": g.hole + Vector3(sin(a), 0.0, cos(a)) * (IN_R if live.size() > 1 else 0.0)})
	by.get_parent().add_child(g)
	return g


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for one: Dictionary in grabs:
		one.tendril = TENDRIL.new()
		add_child(one.tendril)


func _physics_process(delta: float) -> void:
	_t += delta
	var done := true
	for tr: Dictionary in _trails:  # (the spat ones' ink trails, fed while they fly)
		if _t < float(tr.until) and _alive(tr.foe) and (tr.foe as Node).has_meta(FLYING) and (tr.foe as Node).get("model") is Node3D:
			done = false
			COMET.beat(get_parent(), (tr.foe as Node).get("model"), TRAIL_COLOR)
	for one: Dictionary in grabs:
		var e: Variant = one.foe
		var tendril: Node3D = one.tendril
		var local: float = _t - float(one.t0)
		if not _alive(e):
			tendril.visible = false
			_unfly(one)
			continue
		var foe := e as Node3D
		var root := hole + Vector3.UP * 0.05
		if one.spat:
			var k: float = clampf((_t - float(one.spit_t)) / LET_GO, 0.0, 1.0)
			if k >= 1.0:
				tendril.visible = false
			else:
				done = false
				tendril.draw(root, foe.global_position + CHEST, 1.0 - k, WAVE, 0.0, _t)
			continue
		done = false
		if local < 0.0:
			tendril.visible = false
			continue
		if local < REACH:  # 1. grab: up out of the hole to the foe
			tendril.draw(root, foe.global_position + CHEST, smoothstep(0.0, REACH, local), WAVE, 0.0, _t)
			continue
		if not one.has("from"):
			one.from = foe.global_position
			if not one.heavy:
				foe.set_meta(FLYING, true)
		var coil: float = float(foe.get("radius")) + 0.05
		var k := clampf((local - REACH) / SWALLOW, 0.0, 1.0)
		if not one.heavy:  # 2. swallow: dragged in and down
			var ease_k := k * k
			var at: Vector3 = (one.from as Vector3).lerp(one.to, minf(ease_k * 1.4, 1.0))
			at.y = lerpf((one.from as Vector3).y, -SINK, ease_k)
			foe.global_position = at
			if foe is CharacterBody3D:
				(foe as CharacterBody3D).velocity = Vector3.ZERO
		tendril.draw(root, foe.global_position + CHEST, 1.0, 0.02, coil, _t)
		if k >= 1.0 and not one.swallowed:
			one.swallowed = true
			if on_swallow.is_valid():
				on_swallow.call(foe)
		if one.swallowed and _t >= float(one.spit_t):  # 3. spit
			_spit(one)
	if done and _t > SPIT_FIRST:
		queue_free()


func _spit(one: Dictionary) -> void:
	one.spat = true
	spat += 1
	var e: Node3D = one.foe
	_unfly(one)
	if not one.heavy:
		var way := spit_way(int(one.i))
		spit_dirs.append(way)
		var at: Vector3 = hole + way * SPIT_SET if way != Vector3.ZERO else one.to
		e.global_position = Vector3(at.x, 1.4, at.z)  # (up out of the hole, chest high, on the side it goes)
	if on_spit.is_valid():
		on_spit.call(e, int(one.i))
	if not one.heavy:
		_trails.append({"foe": e, "until": _t + TRAIL_S})
	if is_inside_tree():
		register()
		bursts += 1
		var crown: Node3D = DESIGNED.spawn(get_parent(), "spit_burst", hole + Vector3.UP * BURST_UP, BURST_SIZE * (1.0 if one.i == 0 else 0.85), "void", BURST_TIMES, Vector2(0.55, 1.0))
		crown.real_until = 1
		crown.pop = 0.18
		crown.set_spin(0.0, -1.0 if int(one.i) % 2 else 1.0)
		var fx: Node3D = DESIGNED.spawn(get_parent(), "void_spit", hole, SPIT_SIZE * (1.0 if one.i == 0 else 0.8), "void", SPIT_TIMES, Vector2(0.55, 1.0))
		fx.real_until = 1
		fx.set_spin(0.0, -1.0 if int(one.i) % 2 else 1.0)
		var cam := get_viewport().get_camera_3d()
		if cam != null:  # stood a little toward the camera: behind the hole the floor in front hid it (depth tested)
			var away := hole - cam.global_position
			fx.global_position += Vector3(away.x, 0.0, away.z).normalized() * SPIT_TOWARD + Vector3.UP * 0.05


## The way spit `i` leaves the hole (flat, unit): the side with the most room on screen, fanned per spit; ZERO with no
## camera (the old ring round the hole). (With a structure picked, _collapse_spit throws at its face anyway.)
func spit_way(i: int) -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return Vector3.ZERO
	var best := Vector3.ZERO
	var best_room := -INF
	for k in SPIT_DIRS:
		var a := TAU * k / SPIT_DIRS
		var d := Vector3(sin(a), 0.0, cos(a))
		var room := SPIT_EDGE - _edge(cam, hole + d * SPIT_REACH)
		if room > best_room + 0.01:
			best_room = room
			best = d
	if i == 0:
		return best
	var fan := SPIT_FAN * float((i + 1) / 2) * (1.0 if i % 2 == 1 else -1.0)  # (+1, -1, +2, -2... fans off it)
	var d := best.rotated(Vector3.UP, fan)
	return d if SPIT_EDGE - _edge(cam, hole + d * SPIT_REACH) > 0.0 else best


## How far out on the screen `at` (and a foe's height over it) sits: the larger |ndc|, 1 at the edge.
static func _edge(cam: Camera3D, at: Vector3) -> float:
	var vp := cam.get_viewport().get_visible_rect().size
	var worst := 0.0
	for h: float in [0.0, 1.6]:
		var p := at + Vector3.UP * h
		if cam.is_position_behind(p):
			return 9.0
		var s := cam.unproject_position(p) / vp * 2.0 - Vector2.ONE
		worst = maxf(worst, maxf(absf(s.x), absf(s.y)))
	return worst


func _unfly(one: Dictionary) -> void:
	var e: Variant = one.foe
	if is_instance_valid(e) and (e as Node).has_meta(FLYING) and one.has("from") and not one.heavy:
		(e as Node).remove_meta(FLYING)
		if (e as Node3D).global_position.y < 0.0:
			(e as Node3D).global_position.y = 0.0


func _exit_tree() -> void:
	for one: Dictionary in grabs:  # (freed mid-swallow: nobody stays under the floor)
		var e: Variant = one.foe
		if is_instance_valid(e) and not one.spat and one.has("from") and not one.heavy:
			(e as Node3D).global_position = Vector3(one.to.x, 0.0, one.to.z)
			if (e as Node).has_meta(FLYING):
				(e as Node).remove_meta(FLYING)


static func _alive(e: Variant) -> bool:
	return is_instance_valid(e) and e.is_alive()
