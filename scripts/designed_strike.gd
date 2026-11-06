extends Node3D
## The sky strike (fx-air round 2, docs/features/designed-fx.md "Sky strike"): every bolt out of the sky when
## designed effects are on (DesignedFx.bolt hands it any bolt falling more than STRIKE_DROP): Grounded's storm
## strikes (elements._strike_bolt), Cataclysm's and Fault Line's (comic_fault). One authored moment, in beats:
##   1. the leader: a thin, dim bolt on a kinked path, LEADER_S real seconds (the sky finding the floor);
##   2. the main bolt: MAIN_W x fatter, burned white-hot (the ribbon's `heat`) and frozen on one drawing while the
##      hit holds (HOLD_GAME game seconds, so a hitstop keeps it up, and at least HOLD_REAL real ones), then
##      cooling to its drawn tones and boiling on twos while it erodes;
##   3. the afterimage: the strike's path again, dimmed a band, with FORKS short branches off it, eroding away;
##   4. the scorch: a jagged star burned on the floor (strike_scorch), white-hot cooling to dark, breaking up;
##   5. small arcs crawling over each struck foe for a few frames (arc_crawl), riding the foe as it flies.
## The storm burst at the foot still comes with `star` (the old strike's impact flash).

const SELF := preload("res://scripts/designed_strike.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const FOES := preload("res://scripts/foes.gd")
const STEPS_PER_S := 12.0  # on twos
const LEADER_S := 0.04  # real s
const LEADER_W := 0.45  # of the asked width
const LEADER_HEAT := -0.25
const LEADER_SWAY := 0.35  # m: the leader's kink, off the main path at mid height
const MAIN_W := 2.2  # of the asked width (round 2: 1.7 read as the old bolt)
const HOLD_GAME := 0.07  # s the main bolt holds white-hot (game time: a hitstop holds it)
const HOLD_REAL := 0.09  # s at least, real
const HOLD_HEAT := 0.35  # past one band up: a white-hot core in a thin pale-lime rim (0.5 burned it all white, 0.25 read lime)
const MAIN_FADE := 0.14  # game s: cooling, boiling, eroding
const AFTER_LIFE := 0.3  # game s
const AFTER_HEAT := -0.25
const AFTER_SHIFT := 0.25  # m the afterimage sits off the main path
const FORKS := 2
const FORK_LEN := Vector2(0.9, 1.5)  # m
const SCORCH_SIZE := 3.4  # m, the floor star's square (round 1: 2.0 hid under the struck foe)
const SCORCH_TIMES := [0.06, 0.08, 0.14, 0.25, 0.35, 0.45]  # real s: white-hot, cooling, breaking up
const CRAWL_SIZE := 1.9  # m, the crawling arcs' square (round 1: 1.5 read as specks)
const CRAWL_UP := 0.8  # m above the foe's feet
const CRAWL_REACH := 0.7  # m from the strike's foot
const CRAWL_TIMES := [0.035, 0.06, 0.06, 0.06, 0.07, 0.08]

var _sky := Vector3.ZERO
var _foot := Vector3.ZERO
var _width := 0.15
var _real := 0.0
var _game := 0.0
var _last_us := 0
var _main_at := -1.0  # game time the main bolt's hold ended (-1: still holding)
var _leader: MeshInstance3D
var _main: MeshInstance3D
var _after: Array[MeshInstance3D] = []
var _boil := 0


static func spawn(parent: Node, sky: Vector3, foot: Vector3, width := 0.15, star := 0.0) -> Node3D:
	var fx: Node3D = SELF.new()
	fx._sky = sky
	fx._foot = foot
	fx._width = width
	parent.add_child(fx)
	fx.top_level = true
	fx.global_transform = Transform3D.IDENTITY
	fx._build(parent, star)
	return fx


func _build(parent: Node, star: float) -> void:
	_boil = randi() % 4
	_last_us = Time.get_ticks_usec()
	var kink := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * LEADER_SWAY
	var mid := (_sky + _foot) * 0.5 + kink
	_leader = DESIGNED.bolt_strip(self, _sky, mid, _width * LEADER_W)
	DESIGNED.bolt_strip(_leader, mid, _foot, _width * LEADER_W)  # (rides the first leg: one node to free)
	_strip_set(_leader, (_boil + 1) % 4, LEADER_HEAT, 0.0)
	_main = DESIGNED.bolt_strip(self, _sky, _foot, _width * MAIN_W)
	_strip_set(_main, _boil, HOLD_HEAT, 0.0)
	_main.visible = false
	var floor_at := Vector3(_foot.x, DESIGNED.GROUND_LIFT, _foot.z)
	var scorch := DESIGNED.spawn(parent, "strike_scorch", floor_at, SCORCH_SIZE, "wind", SCORCH_TIMES, Vector2(0.55, 1.0))
	scorch.real_time = true
	scorch.rotation.y = randf() * TAU
	if star > 0.0:
		var burst := DESIGNED.spawn(parent, "storm_burst", Vector3(_foot.x, 0.0, _foot.z), DESIGNED.STRIKE_BURST * clampf(star / 1.1, 0.6, 1.4),
				"wind", DESIGNED.STORM_TIMES, Vector2(0.5, 1.0))
		burst.real_until = 1
		burst.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	if is_inside_tree():
		for foe: Node3D in FOES.near(get_tree(), _foot, CRAWL_REACH):
			_crawl(parent, foe)


## Arcs crawling over a struck foe: one set per foe at a time.
func _crawl(parent: Node, foe: Node3D) -> void:
	var now := Time.get_ticks_msec()
	if int(foe.get_meta("arc_crawl_until", 0)) > now:
		return
	var life := 0.0
	for t: float in CRAWL_TIMES:
		life += t
	foe.set_meta("arc_crawl_until", now + int(life * 1000.0))
	var off := Vector3(0.0, CRAWL_UP, 0.0)
	var fx := DESIGNED.spawn(parent, "arc_crawl", foe.global_position + off, CRAWL_SIZE, "wind", CRAWL_TIMES, Vector2(0.5, 1.0))
	fx.real_until = 1
	fx.follow = foe
	fx.follow_off = off
	fx.vary(PI, true)


func _strip_set(mi: MeshInstance3D, frame: int, heat: float, erode: float) -> void:
	var all: Array = [mi]
	for c: Node in mi.get_children():
		if c is MeshInstance3D:
			all.append(c)
	for m: MeshInstance3D in all:
		m.set_instance_shader_parameter("frame", float(frame))
		m.set_instance_shader_parameter("heat", heat)
		m.set_instance_shader_parameter("erode", erode)


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := float(now - _last_us) / 1000000.0
	_last_us = now
	tick(delta, delta if DESIGNED.game_time_only else real)


## Public so a test can step it: `delta` game seconds, `real` real ones.
func tick(delta: float, real: float) -> void:
	_real += real
	_game += delta
	if _real < LEADER_S:
		return
	if _leader != null:
		_leader.queue_free()
		_leader = null
		_main.visible = true
		_game = 0.0  # the hold counts from the main bolt
		_real = LEADER_S
	if _main_at < 0.0:
		if _game < HOLD_GAME or _real < LEADER_S + HOLD_REAL:
			return
		_main_at = _game
		_afterimage()
	var t := _game - _main_at
	if _main != null:
		var p := t / MAIN_FADE
		if p >= 1.0:
			_main.queue_free()
			_main = null
		else:
			var step := int(t * STEPS_PER_S) + 1
			_main.set_instance_shader_parameter("frame", float((_boil + step) % 4))
			_main.set_instance_shader_parameter("scroll", float(_boil) * 0.37 + step * 0.21)
			_main.set_instance_shader_parameter("heat", HOLD_HEAT * maxf(0.0, 1.0 - p * 2.5))
			_main.set_instance_shader_parameter("erode", clampf(p * 1.2 - 0.2, 0.0, 1.0) * 0.98)
	var q := t / AFTER_LIFE
	if q >= 1.0:
		queue_free()
		return
	for m: MeshInstance3D in _after:
		m.set_instance_shader_parameter("erode", clampf(q * 1.1, 0.0, 1.0) * 0.98)


## The strike's path again, a band dimmer and off to one side, with short forks: what the eye keeps.
func _afterimage() -> void:
	var cam := get_viewport().get_camera_3d()
	var side := cam.global_basis.x if cam != null else Vector3.RIGHT
	var s := 1.0 if randf() < 0.5 else -1.0
	var a := _sky + side * AFTER_SHIFT * s
	var b := _foot + side * AFTER_SHIFT * 0.4 * s
	_after.append(DESIGNED.bolt_strip(self, a, b, _width))
	for k in FORKS:
		var u := 0.35 + 0.25 * k + randf_range(-0.05, 0.05)
		var from := a.lerp(b, u)
		var out := side * (s if k % 2 == 0 else -s) * randf_range(0.6, 1.0)
		var to := from + (out + Vector3.DOWN * randf_range(0.6, 1.0)).normalized() * randf_range(FORK_LEN.x, FORK_LEN.y)
		_after.append(DESIGNED.bolt_strip(self, from, to, _width * 0.6))
	for f: MeshInstance3D in _after:
		f.set_instance_shader_parameter("frame", float((_boil + 2) % 4))
		f.set_instance_shader_parameter("heat", AFTER_HEAT)
