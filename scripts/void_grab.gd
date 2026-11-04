extends Node
## E: the void arm reaches out. Picks what's in front of him (pick()) and does what suits it: a foe is
## yanked to him, something too big drags him to it, a pillar swings him round it and flings him off,
## nothing gets a whip. E off a string is the slam: the tentacle heaves the foe over him and brings it
## down. Also owns the arm's shapes (axe, spear, hammer, bare), which each move asks for.
## The comic hero only; player.gd makes one of these and calls in. See docs/features/void-arm.md.

const TENDRIL := preload("res://scripts/void_tendril.gd")
const QUAKE := preload("res://scripts/breaker_quake.gd")

const FOE_RANGE := 9.0  # m
const ANCHOR_RANGE := 8.0  # m
const CONE := 60.0  # degrees either side of where he aims
const ANCHOR_HANDICAP := 8.0  # pick() score: a foe wins a near tie with a pillar

const YANK_TO := 1.7  # m in front of him
const YANK_END := 0.46  # move progress when the foe has arrived (hits[0] is when it starts)
const RETRACT_END := 0.62
const WHIP_REACH := 6.0  # m

const PULL_SPEED := 26.0  # m/s
const PULL_STOP := 1.6  # m from the big thing's edge
const PULL_MAX_T := 0.7  # s
const PULL_LIFT := 0.8  # m

const SWING_R := 2.8  # m from the pillar
const SWING_SPEED := 17.0  # m/s
const SWING_LIFT := 1.4  # m
const SWING_MIN_ARC := PI  # radians a tap gets
const SWING_MAX_ARC := 3.0 * PI  # radians holding E can run to
const SWING_SHOOT := 0.07  # s for the tentacle to get there
const SWING_DAMAGE := 10.0
const SWING_HIT_RANGE := 1.5  # m
const FLING_TIME := 0.4  # s player._fling_t
const FLING_MULT := 1.1

const SLAM_SHOOT_END := 0.12  # move progress: the tentacle has it
const SLAM_TOP_AT := 0.3  # ...has it over his head
const SLAM_TOP := 3.4  # m up
const SLAM_AT := 2.6  # m ahead of him, where it lands
const SLAM_REACH := 6.5  # m it can take a foe from
const SLAM_RETRACT_END := 0.66
const STRING_SLAM_MULT := 1.6  # off the whole weapon string (L L L E)
const HOLD := 0.9  # s a held foe is staggered for, renewed as it runs out
const CHEST := Vector3(0.0, 0.9, 0.0)

var hero: CharacterBody3D
var arm: Node  # void_arm.gd
var tendril: Node3D
var after_string := false  # this slam finishes the weapon string: player.named_id() names it

var _skel: Skeleton3D
var _hand := -1
var _target: Node3D  # the foe the tentacle has
var _target_heavy := false
var _from := Vector3.ZERO  # where the held thing started
var _aim_at := Vector3.ZERO  # where it lands, or a whiff ends
var _done := false  # the move's hit has happened
var _time := 0.0

# travelling (player.State.SWING)
var _kind := ""  # "pull" or "swing"
var _anchor: Node3D
var _r := 0.0
var _ang := 0.0
var _sign := 1.0
var _swept := 0.0
var _t := 0.0
var _struck := {}


func setup(p: CharacterBody3D, void_arm: Node, skel: Skeleton3D) -> void:
	hero = p
	arm = void_arm
	_skel = skel
	_hand = skel.find_bone("hand.r")
	tendril = TENDRIL.new()
	p.add_child(tendril)


## What E goes for from `from`, aiming along `dir`: {kind: "foe" | "heavy" | "anchor" | "none", node}.
## The nearest thing to the middle of his aim wins. Pure, so the check can walk it.
static func pick(from: Vector3, dir: Vector3, foes: Array, anchors: Array) -> Dictionary:
	var best := {"kind": "none", "node": null}
	var best_score := INF
	for e in foes:
		if not e.is_alive():
			continue
		var s := _score(from, dir, e.global_position, FOE_RANGE)
		if s < best_score:
			best_score = s
			best = {"kind": "heavy" if is_heavy(e) else "foe", "node": e}
	for a in anchors:
		var s := _score(from, dir, a.global_position, ANCHOR_RANGE) + ANCHOR_HANDICAP
		if s < best_score:
			best_score = s
			best = {"kind": "anchor", "node": a}
	return best


static func _score(from: Vector3, dir: Vector3, at: Vector3, reach: float) -> float:
	var to := at - from
	to.y = 0.0
	var d := to.length()
	if d > reach:
		return INF
	var angle := 0.0 if d < 0.01 else rad_to_deg(dir.angle_to(to / d))
	return INF if angle > CONE else angle + d * 3.0


## Too big to throw about.
static func is_heavy(e: Node) -> bool:
	return e.has_method("is_boss") or e.get("elite") == true or float(e.get("radius")) >= 0.9


func _aim_dir() -> Vector3:
	if hero._mouse_aiming():
		return hero._mouse_dir()
	var d: Vector3 = hero._input_dir()
	return d.normalized() if d.length() > 0.1 else hero._facing()


func _pick_now() -> Dictionary:
	var anchors := get_tree().get_nodes_in_group("grab_anchors").filter(func(a: Node3D) -> bool:
		return a.global_position.y > -1.0)  # (a room's old pillars sink away)
	return pick(hero.global_position, _aim_dir(), get_tree().get_nodes_in_group("enemies"), anchors)


func _hand_pos() -> Vector3:
	return (_skel.global_transform * _skel.get_bone_global_pose(_hand)).origin


# --- E from neutral ---------------------------------------------------------

## True if E sends him travelling (State.SWING) instead of playing the grab move.
func begin() -> bool:
	var p := _pick_now()
	_clear_target()
	if p.kind == "anchor":
		_begin_swing(p.node)
		return true
	var to: Vector3 = p.node.global_position - hero.global_position if p.node else Vector3.ZERO
	to.y = 0.0
	if p.kind == "heavy" and to.length() > float(p.node.radius) + PULL_STOP + 1.0:
		_begin_pull(p.node)
		return true
	if p.kind == "foe" or p.kind == "heavy":
		_target = p.node
		_target_heavy = p.kind == "heavy"
		_aim_at = _target.global_position
	else:
		_aim_at = hero.global_position + _aim_dir() * WHIP_REACH
	return false


func _clear_target() -> void:
	_target = null
	_target_heavy = false
	tendril.visible = false


## A move has started: the arm takes that move's shape, and a slam finds what it's slamming.
func on_move(id: String, prev: String) -> void:
	arm.shape(ComicLook.HERO_MOVE_FORMS.get(id, "axe"))
	_done = false
	if id == "GR":
		hero._face(_flat_to(_aim_at))
	elif id == "VS":
		after_string = prev == "L3"
		if after_string:
			hero._move.damage *= STRING_SLAM_MULT
		_begin_slam()
	else:
		_clear_target()


func on_state(s: int) -> void:
	if s == hero.State.ATTACK or s == hero.State.SWING:
		return
	_clear_target()
	arm.shape(arm.rest_form)


func _flat_to(at: Vector3) -> Vector3:
	var to := at - hero.global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.01 else hero._facing()


# --- The grab move (GR) and the slam (VS): driven from player._state_attack ----

func attack_tick(t: float, delta: float) -> void:
	_time += delta
	if hero._move_id == "GR":
		_tick_grab(t)
	elif hero._move_id == "VS":
		_tick_slam(t)


func _tick_grab(t: float) -> void:
	var hit: float = hero._move.hits[0]
	if t < hit:
		var to := _target_chest() if _target_alive() else _aim_at + CHEST
		tendril.draw(_hand_pos(), to, smoothstep(0.04, hit, t), 0.14, 0.0, _time)
	elif _target_alive() and not _target_heavy and t < YANK_END:
		var k := (t - hit) / (YANK_END - hit)
		var dest := hero.global_position + _flat_to(_target.global_position) * YANK_TO
		_target.global_position = _from.lerp(dest, 1.0 - (1.0 - k) * (1.0 - k))
		_target.velocity = Vector3.ZERO
		tendril.draw(_hand_pos(), _target_chest(), 1.0, 0.03, float(_target.radius) + 0.05, _time)
	else:
		var to := _target_chest() if _target_alive() else _aim_at + CHEST
		tendril.draw(_hand_pos(), to, 1.0 - smoothstep(YANK_END, RETRACT_END, t), 0.1, 0.0, _time)


## GR's hit (from player._do_hit): the tentacle arrives.
func strike() -> void:
	if not _target_alive():
		Game.sfx("swing", -6.0, 0.1)
		Fx.dust(hero.get_parent(), _aim_at, 5, 0.6)
		return
	var dir := _flat_to(_target.global_position)
	_from = _target.global_position
	_target.take_hit(hero._move.damage * hero._dmg_mult, dir * hero._move.knockback, 0.0, false)
	if _target_alive() and not _target_heavy and _target.has_method("stagger"):
		_target.stagger(HOLD)
	Game.register_hit("GR")
	hero._connected = true
	Game.sfx("hit")
	Game.hitstop(hero._move.stop)
	Game.shake(hero._move.shake)


func _begin_slam() -> void:
	# Whoever the grab still has, or the best thing in reach.
	if not _target_alive() or _target_heavy:
		var p := _pick_now()
		_clear_target()
		if p.kind == "foe" or p.kind == "heavy":
			var to: Vector3 = p.node.global_position - hero.global_position
			to.y = 0.0
			if to.length() <= SLAM_REACH:
				_target = p.node
				_target_heavy = p.kind == "heavy"
	if _target_alive():
		hero._face(_flat_to(_target.global_position))
		_from = _target.global_position
		if _target_heavy:
			# It stays put, so the slam comes to it: reach out as far as it stands.
			var to := _target.global_position - hero.global_position
			to.y = 0.0
			hero._move.range = maxf(hero._move.range, to.length())
		elif _target.has_method("stagger"):
			_target.stagger(HOLD)
	else:
		_from = hero.global_position + _aim_dir() * SLAM_AT


func _tick_slam(t: float) -> void:
	var hit: float = hero._move.hits[0]
	var fwd: Vector3 = hero._facing()
	var ground: Vector3 = hero.global_position + fwd * SLAM_AT
	var carried := _target_alive() and not _target_heavy
	if _target_alive() and _target_heavy:
		ground = _target.global_position
	if t >= hit:
		var to := (_aim_at if _done else ground) + Vector3.UP * 0.1
		tendril.draw(_hand_pos(), to, 1.0 - smoothstep(hit + 0.1, SLAM_RETRACT_END, t), 0.03, 0.0, _time)
		return
	var top: Vector3 = hero.global_position + fwd * 0.6 + Vector3.UP * SLAM_TOP
	if not carried:
		top = ground + Vector3.UP * SLAM_TOP  # nothing to lift: the tentacle alone rears and comes down
	var at := _from
	if t >= SLAM_TOP_AT:
		var k := (t - SLAM_TOP_AT) / (hit - SLAM_TOP_AT)
		at = top.lerp(ground, k * k)
	elif t >= SLAM_SHOOT_END:
		var k := (t - SLAM_SHOOT_END) / (SLAM_TOP_AT - SLAM_SHOOT_END)
		at = _from.lerp(top, smoothstep(0.0, 1.0, k))
	if carried:
		_target.global_position = at
		_target.velocity = Vector3.ZERO
		tendril.draw(_hand_pos(), at + CHEST, smoothstep(0.0, SLAM_SHOOT_END, t), 0.05, float(_target.radius) + 0.05, _time)
	else:
		tendril.draw(_hand_pos(), at + CHEST * 0.3, smoothstep(0.0, SLAM_SHOOT_END, t), 0.08, 0.0, _time)


## VS comes down this frame, before player._do_hit looks for what it struck.
func slam_lands() -> void:
	var fwd: Vector3 = hero._facing()
	_aim_at = _target.global_position if _target_alive() and _target_heavy else hero.global_position + fwd * SLAM_AT
	if _target_alive() and not _target_heavy:
		_target.global_position = _aim_at
	_done = true


## After player._do_hit: the floor takes it, the foe is let go.
func slam_landed() -> void:
	var parent := hero.get_parent()
	QUAKE.crater(parent, _aim_at, hero.element(), 1.6 if after_string else 1.1, false)
	Fx.ring(parent, _aim_at, Color(ComicLook.VOID_COLOR, 0.9), hero._move.range, 0.3)
	Fx.burst(parent, _aim_at + Vector3.UP * 0.2, ComicLook.VOID_COLOR, 22, 8.0, 0.14, 0.35, Vector3.UP, 80.0)
	Fx.dust(parent, _aim_at, 14, 1.0)
	Game.sfx("hit_big")
	_target = null


func _target_alive() -> bool:
	return is_instance_valid(_target) and _target.is_alive()


func _target_chest() -> Vector3:
	return _target.global_position + CHEST


# --- Travelling (player.State.SWING) ------------------------------------------

func _begin_pull(e: Node3D) -> void:
	_kind = "pull"
	_target = e
	_t = 0.0
	_start_travel(hero.PULL_INVULN)
	hero._face(_flat_to(e.global_position))


func _begin_swing(a: Node3D) -> void:
	_kind = "swing"
	_anchor = a
	_t = 0.0
	_swept = 0.0
	_struck = {}
	var out := hero.global_position - a.global_position
	out.y = 0.0
	_r = out.length()
	_ang = atan2(out.z, out.x)
	# Round whichever way carries him where he's pushing; left of the pillar by default.
	var push: Vector3 = hero._input_dir()
	if push.length() <= 0.1:
		push = hero._facing()
	_sign = -1.0 if out.cross(push).y > 0.0 else 1.0
	_start_travel(hero.SWING_INVULN)


func _start_travel(invuln: float) -> void:
	arm.shape("hand")
	hero._invuln_t = invuln
	hero._set_state(hero.State.SWING)
	hero._play("Ab_Swing", 0.05, true)
	Game.sfx("swing_heavy", -3.0, 0.12)


func travel_tick(delta: float) -> void:
	_time += delta
	_t += delta
	if hero._dash_buffer_t > 0.0 and hero._dash_cd <= 0.0:
		_release(false)
		hero._start_dash()
		return
	if _kind == "pull":
		_tick_pull(delta)
	else:
		_tick_swing(delta)


func _tick_pull(delta: float) -> void:
	if not _target_alive() or _t >= PULL_MAX_T:
		_release(false)
		return
	var to := _target.global_position - hero.global_position
	to.y = 0.0
	var shoot := smoothstep(0.0, SWING_SHOOT, _t)
	tendril.draw(_hand_pos(), _target_chest(), shoot, 0.04, 0.0, _time)
	if shoot < 1.0:
		hero.velocity.x = 0.0
		hero.velocity.z = 0.0
		return
	if to.length() <= float(_target.radius) + PULL_STOP:
		hero.velocity = Vector3.ZERO
		_clear_target()
		hero._start_attack("L1")  # arrives swinging
		return
	var v := to.normalized() * PULL_SPEED
	hero.velocity.x = v.x
	hero.velocity.z = v.z
	hero.model.position.y = move_toward(hero.model.position.y, PULL_LIFT, 8.0 * delta)


func _tick_swing(delta: float) -> void:
	if not is_instance_valid(_anchor):
		_release(false)
		return
	var hold := Input.is_action_pressed("special")
	var pressed_on: bool = hero._buffered != ""
	if pressed_on or _swept >= SWING_MAX_ARC or (_swept >= SWING_MIN_ARC and not hold):
		_release(true)
		return
	var shoot := smoothstep(0.0, SWING_SHOOT, _t)
	tendril.draw(_hand_pos(), _anchor.global_position + Vector3.UP * 2.2, shoot, 0.04, 0.0, _time)
	if shoot < 1.0:
		hero.velocity.x = 0.0
		hero.velocity.z = 0.0
		return
	_r = move_toward(_r, SWING_R, 16.0 * delta)
	var w := SWING_SPEED / maxf(_r, 0.5)
	_ang += _sign * w * delta
	_swept += w * delta
	var want := _anchor.global_position + Vector3(cos(_ang), 0.0, sin(_ang)) * _r
	var v := (want - hero.global_position) / maxf(delta, 0.001)
	hero.velocity.x = v.x
	hero.velocity.z = v.z
	hero._face(_tangent())
	hero.model.position.y = move_toward(hero.model.position.y, SWING_LIFT, 7.0 * delta)
	_rake()
	if _swept > 0.4 and hero.get_real_velocity().length() < 2.0:
		_release(false)  # into a wall


## Whatever he swings through takes his boots, once a swing.
func _rake() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if _struck.has(e) or not e.is_alive():
			continue
		var to: Vector3 = e.global_position - hero.global_position
		to.y = 0.0
		if to.length() > SWING_HIT_RANGE + float(e.radius):
			continue
		_struck[e] = true
		e.take_hit(SWING_DAMAGE * hero._dmg_mult, _tangent() * 8.0, 0.0, false)
		Game.register_hit("GR")
		Game.sfx("hit")
		Game.hitstop(0.03)


func _tangent() -> Vector3:
	return Vector3(-sin(_ang), 0.0, cos(_ang)) * _sign


func _release(fling: bool) -> void:
	_anchor = null
	if fling:
		var v := _tangent() * SWING_SPEED * FLING_MULT
		hero.velocity.x = v.x
		hero.velocity.z = v.z
		hero._fling_t = FLING_TIME
		hero._post_dash_t = FLING_TIME  # so a press off the fling is the dash's lunge
		hero._face(_tangent())
	hero._set_state(hero.State.MOVE)
