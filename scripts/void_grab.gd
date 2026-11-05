extends Node
## The void arm reaches out. Right click grabs what's in front of him: a foe is yanked to him, something
## too big drags him to it, nothing gets a whip, and right click again heaves what it holds overhead and
## slams it. R swings him (traverse()). Also owns the arm's shapes (axe, spear, hammer, bare), which
## each move asks for, and the tentacles that hold foes through a breaker.
## The comic hero only; player.gd makes one of these and calls in. See docs/features/void-arm.md.

const FOES := preload("res://scripts/foes.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const QUAKE := preload("res://scripts/breaker_quake.gd")
const VOID_ELEMENT := preload("res://scripts/void_element.gd")
const THROWN := preload("res://scripts/thrown_foe.gd")

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
const SWING_MAX_ARC := 3.0 * PI  # radians holding R can run to
const SWING_SHOOT := 0.07  # s for the tentacle to get there
const SWING_DAMAGE := 10.0
const SWING_HIT_RANGE := 1.5  # m
const FLING_TIME := 0.4  # s player._fling_t
const FLING_MULT := 1.1

const SKY_MIN := 0.45  # s a tap of R gets, with nothing to latch onto
const SKY_MAX := 1.1  # s holding R can run to
const SKY_LEAD := 5.0  # m ahead, and...
const SKY_HIGH := 12.0  # ...m up the tentacle grips: off the top of the screen
const SKY_LIFT := 1.8  # m
const SKY_TURN := 2.2  # radians/s he can steer

const SLAM_SHOOT_END := 0.12  # move progress: the tentacle has it
const SLAM_TOP_AT := 0.3  # ...has it over his head
const SLAM_TOP := 3.4  # m up
const SLAM_AT := 2.6  # m ahead of him, where it lands
const SLAM_REACH := 6.5  # m it can take a foe from
const SLAM_RETRACT_END := 0.66
const SWEEP_ARC := 1.2  # radians either side
const SWEEP_REACH := 4.0  # m
const CARRY_REACH := 4.5  # m: who he can snatch off a swing
const CARRY_AT := 1.4  # m ahead of him
const HOLD := 0.9  # s a held foe is staggered for, renewed as it runs out
const CHEST := Vector3(0.0, 0.9, 0.0)

const SEIZE_RANGE := 8.0  # m: a breaker's tentacles reach this far
const SEIZE_MAX := 5  # one tentacle each
const SEIZE_SHOOT := 0.1  # s for them to arrive
const SEIZE_LIFT := 2.8  # m up they're held
const SEIZE_LIFT_RATE := 12.0  # how quickly they're hauled there
const SEIZE_IN := 0.45  # how far they land towards him, of where they stood
const RESTAGGER := 0.25  # s: kept staggered this often, inside the 0.4 s a hit's stagger lasts
const WIRE_START := 0.08  # s into the hang: the first jolt
const WIRE_STEP := 0.09  # s between jolts

var hero: CharacterBody3D
var arm: Node  # void_arm.gd
var tendril: Node3D
var fist: Node3D  # Molten Palm's, on the end of the tentacle
var shoved := []  # who Molten Palm just sent off: Undertow follows them
var bound := []  # who Undertow has hold of: Meteor Fall goes for them
var chased := []  # those of them the palm shoved: he goes after these first
var dark_spot := Vector3.ZERO  # where the dark string gathered them: its breakers land here
var hole: Node3D  # Singularity's
var dark_bind: Node  # what Overwhelm has them in
var dark_maw: Node3D  # Maw's jaws, up while he dives
var buried := []  # who Rockslide drove into the floor out of the air: Fault Line throws them hardest
var undertow: Node  # Undertow's floor_bind: Meteor Fall's first beat lets it go
var pile := []  # Meteor Fall: who it threw at the walls, then dragged into the pile

var _seized := []  # {foe, from, tendril}: held through a breaker
var _spare := []  # tendrils from earlier breakers
var _zaps := 0  # jolts so far this hang
var _spear_at := Vector3.ZERO  # Harpoon: where the spear tip's going
var _carry: Node3D  # the foe he snatched off a swing
var _carry_rope: Node3D
var _skel: Skeleton3D
var _hand := -1
var _target: Node3D  # the foe the tentacle has
var _target_heavy := false
var _from := Vector3.ZERO  # where the held thing started
var _aim_at := Vector3.ZERO  # where it lands, or a whiff ends
var _done := false  # the move's hit has happened
var _time := 0.0

# travelling (player.State.SWING)
var _kind := ""  # "pull", "swing" round a pillar, or "sky"
var _dir := Vector3.FORWARD  # "sky": which way he's going
var _pivot := Vector3.ZERO  # "sky": where the tentacle grips
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


## What the arm goes for from `from`, aiming along `dir`: {kind: "foe" | "heavy" | "anchor" | "none", node}.
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
	if hero.HERO_INPUT.mouse_aiming(hero):
		return hero.HERO_INPUT.mouse_dir(hero)
	var d: Vector3 = hero.HERO_INPUT.input_dir(hero)
	return d.normalized() if d.length() > 0.1 else hero._facing()


func _pick_now() -> Dictionary:
	return pick(hero.global_position, _aim_dir(), get_tree().get_nodes_in_group("enemies"), [])


func _hand_pos() -> Vector3:
	return (_skel.global_transform * _skel.get_bone_global_pose(_hand)).origin


# --- Right click from neutral -----------------------------------------------

## True if the grab sends him travelling (State.SWING) instead of playing the move.
func begin() -> bool:
	var p := _pick_now()
	_clear_target()
	var to: Vector3 = p.node.global_position - hero.global_position if p.node else Vector3.ZERO
	to.y = 0.0
	if p.kind == "heavy" and to.length() > float(p.node.radius) + PULL_STOP + 1.0:
		_begin_pull(p.node, hero.PULL_INVULN)
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
func on_move(id: String, _prev: String) -> void:
	arm.shape(VOID_ELEMENT.FORM_OF.get(id, ComicLook.HERO_MOVE_FORMS.get(id, "axe")))
	_done = false
	if id == "GR":
		hero._face(_flat_to(_aim_at))
	elif id == "VS":
		_begin_slam()
	else:
		_clear_target()


func on_state(s: int) -> void:
	if s == hero.State.ATTACK or s == hero.State.SWING:
		return
	_drop_carry()
	_clear_target()
	arm.shape(arm.rest_form)


func _flat_to(at: Vector3) -> Vector3:
	var to := at - hero.global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.01 else hero._facing()


## Harpoon: out along the line up to the hit. After that the foes' own tethers draw it (thrown_foe).
func _tick_spear(t: float) -> void:
	var hit: float = hero._move.hits[0]
	var fwd: Vector3 = hero._facing()
	var to := _spear_at if _spear_at != Vector3.ZERO else hero.global_position + fwd * VOID_ELEMENT.HARPOON_LENGTH + Vector3.UP * 0.9
	if t < hit:
		to = hero.global_position + fwd * VOID_ELEMENT.HARPOON_LENGTH + Vector3.UP * 0.9
	tendril.draw(_hand_pos(), to, smoothstep(0.05, hit, t) * (1.0 - smoothstep(hit + 0.05, hit + 0.2, t)), 0.03, 0.0, _time)


func spear_to(at: Vector3) -> void:
	_spear_at = at


## Molten Palm: the tentacle follows its fist out.
func _tick_palm() -> void:
	if is_instance_valid(fist):
		tendril.draw(_hand_pos(), fist.global_position, 1.0, 0.03, 0.0, _time)
	else:
		tendril.visible = false


# --- The grab move (GR) and the slam (VS): driven from player._state_attack ----

func attack_tick(t: float, delta: float) -> void:
	_time += delta
	if hero._move_id == "GR":
		_tick_grab(t)
	elif hero._move_id == "VS":
		_tick_slam(t)
	elif hero._move_id in ["EC", "XF", "XG"]:
		_tick_sweep(t)
	elif hero._move_id == "EF":
		_tick_spear(t)
	elif hero._move_id == "EM" or hero._move_id == "XS":
		_tick_palm()


## Updraft Lash: the tentacle sweeps low across the front of him and under them.
func _tick_sweep(t: float) -> void:
	var hit: float = hero._move.hits[0]
	var side := lerpf(-SWEEP_ARC, SWEEP_ARC, smoothstep(0.05, hit, t))
	var to: Vector3 = hero.global_position + hero._facing().rotated(Vector3.UP, side) * SWEEP_REACH + Vector3.UP * 0.15
	var out := smoothstep(0.02, 0.12, t) * (1.0 - smoothstep(hit + 0.02, hit + 0.2, t))
	tendril.draw(_hand_pos(), to, out, 0.1, 0.0, _time)


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
	QUAKE.crater(parent, _aim_at, hero.element(), 1.1, false)
	Fx.burst(parent, _aim_at + Vector3.UP * 0.2, ComicLook.VOID_COLOR, 22, 8.0, 0.14, 0.35, Vector3.UP, 80.0)
	Fx.dust(parent, _aim_at, 14, 1.0)
	Game.sfx("hit_big")
	_target = null


func _target_alive() -> bool:
	return is_instance_valid(_target) and _target.is_alive()


func _target_chest() -> Vector3:
	return _target.global_position + CHEST


# --- A breaker's hold (void_element.BREAKERS): a tentacle on each foe, up over the floor, then down ---

## Everyone in a breaker's reach, big or small.
func reachable() -> Array:
	var at: Vector3 = hero.global_position
	return get_tree().get_nodes_in_group("enemies").filter(func(e: Node3D) -> bool:
		return e.is_alive() and (e.global_position - at).length() <= SEIZE_RANGE + float(e.radius))


## The one Meteor Fall goes for, out of those Undertow has hold of: a boss, then the biggest, then whoever
## the palm shoved, then the nearest.
func rip_target() -> Node3D:
	var at: Vector3 = hero.global_position
	var best: Node3D = null
	var best_score := -INF
	var pool: Array = bound.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.is_alive())
	for e: Node3D in pool if not pool.is_empty() else reachable():
		var score: float = (100.0 if e.has_method("is_boss") else 0.0) + (20.0 if is_heavy(e) else 0.0) + (10.0 if e in chased else 0.0) \
			+ float(e.radius) - (e.global_position - at).length() * 0.1
		if score > best_score:
			best_score = score
			best = e
	return best


## Airborne ones first: they're what the string put up there. Some breakers hold differently: Meteor
## Fall takes one target where it stands, and Avalanche takes every cube where it stands, for now.
func seize(b := {}) -> void:
	release_seized()
	_zaps = 0
	arm.shape("hand")
	if b.has("no_hold"):
		return
	if b.has("press"):
		for e: Node3D in FOES.near(hero.get_tree(), hero.global_position, VOID_ELEMENT.PRESS_REACH):
			if VOID_ELEMENT.in_cube(e) and not VOID_ELEMENT.THROWN.flying(e):
				VOID_ELEMENT.encase(e)  # (they stay frozen for the whole window)
				var cord: Node3D = _spare.pop_back() if not _spare.is_empty() else null
				if cord == null:
					cord = TENDRIL.new()
					hero.add_child(cord)
				cord.line = true  # (one thin line per cube: the cubes are what you see)
				_seized.append({"foe": e, "from": e.global_position, "tendril": cord, "land": Vector3.ZERO, "stagger_at": INF, "anchored": true})
		aim_crush()
		return
	if b.has("rip"):
		var e := rip_target()
		if e != null:
			var t: Node3D = _spare.pop_back() if not _spare.is_empty() else null
			if t == null:
				t = TENDRIL.new()
				hero.add_child(t)
			var other := TENDRIL.new()
			hero.add_child(other)
			var side := (e.global_position - hero.global_position).cross(Vector3.UP).normalized() * (float(e.radius) + 1.4)
			_seized.append({"foe": e, "from": e.global_position, "tendril": t, "land": Vector3.ZERO, "stagger_at": _time + RESTAGGER,
				"anchored": true, "other": other, "other_from": Vector3(e.global_position.x, 0.0, e.global_position.z) + (side if side.length() > 0.1 else Vector3.RIGHT)})
			if not is_heavy(e):
				e.stagger(HOLD)
		return
	var at: Vector3 = hero.global_position
	var foes: Array = reachable().filter(func(e: Node3D) -> bool: return not is_heavy(e) and not VOID_ELEMENT.THROWN.flying(e))
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		if a.is_airborne() != b.is_airborne():
			return a.is_airborne()
		return (a.global_position - at).length() < (b.global_position - at).length())
	var held: Array = foes.slice(0, SEIZE_MAX)
	var side: Vector3 = hero._facing().cross(Vector3.UP).normalized()
	var fan := {}  # (Anvil's reel: each its own slot across his aim, in the order they stand, so none cross)
	if b.has("reel"):
		var order := held.duplicate()
		order.sort_custom(func(a: Node3D, c: Node3D) -> bool:
			return (a.global_position - at).dot(side) < (c.global_position - at).dot(side))
		for i in order.size():
			fan[order[i]] = side * (i - (order.size() - 1) * 0.5) * VOID_ELEMENT.ANVIL_SPREAD
	for e: Node3D in held:
		var t: Node3D = _spare.pop_back() if not _spare.is_empty() else null
		if t == null:
			t = TENDRIL.new()
			hero.add_child(t)
		var from: Vector3 = e.global_position
		var one := {"foe": e, "from": from, "tendril": t, "land": Vector3.ZERO, "stagger_at": _time + RESTAGGER}
		if b.has("reel"):  # (Anvil: hauled back towards him as they go up, the kebab coming back on the gale)
			var to: Vector3 = at + hero._facing() * VOID_ELEMENT.ANVIL_REEL_GAP
			from = Vector3(lerpf(from.x, to.x, b.reel), from.y, lerpf(from.z, to.z, b.reel))
			# (fanned out across his aim: held a slot apart, and the dive keeps the slot, so a crater each)
			var lateral: float = (from - to).dot(side)
			one.from = from - side * lateral * (1.0 - SEIZE_IN) + fan[e]
			one.fan = fan[e]
		_seized.append(one)
		e.stagger(HOLD)


## phase 0: the tentacles arrive and haul them up. phase 1: the dive brings them down with him.
func seized_tick(phase: int, t: float, b: Dictionary) -> void:
	_time += hero.get_physics_process_delta_time()
	var hand := _hand_pos()
	var delta := hero.get_physics_process_delta_time()
	if phase == 0 and b.has("wire") and t >= WIRE_START + _zaps * WIRE_STEP and t <= b.close:
		_zaps += 1
		VOID_ELEMENT.zap(hero, reachable(), hand)  # (big ones can't be held, but it still finds them)
	for s: Dictionary in _seized:
		var e: Node3D = s.foe
		if not is_instance_valid(e) or not e.is_alive():
			s.tendril.visible = false
			continue
		if s.has("anchored"):  # pulled two ways where it stands
			if _time >= s.stagger_at and not is_heavy(e):
				s.stagger_at = _time + RESTAGGER
				e.stagger(HOLD)
			if phase == 1 and b.has("press") and s.has("crush_to"):
				e.velocity = Vector3.ZERO
				e.global_position = VOID_ELEMENT.crush_point(s.crush_from, s.crush_to, clampf(t / float(b.dive), 0.0, 1.0))
			var coil := float(e.radius) + 0.05
			var out := smoothstep(0.0, SEIZE_SHOOT, t) if phase == 0 else 1.0
			s.tendril.draw(hand, e.global_position + CHEST, out, 0.02, coil, _time)
			if s.has("other"):
				s.other.draw(s.other_from, e.global_position + CHEST, out, 0.02, coil, _time)
			continue
		if _time >= s.stagger_at and e.has_method("stagger"):  # (not every frame: each one flashes them white)
			s.stagger_at = _time + RESTAGGER
			e.stagger(HOLD)
		e.velocity = Vector3.ZERO
		if phase == 0:
			var shoot := smoothstep(0.0, SEIZE_SHOOT, t)
			if shoot >= 1.0:
				var up: Vector3 = Vector3(s.from.x, SEIZE_LIFT, s.from.z)
				e.global_position = e.global_position.lerp(up, 1.0 - exp(-SEIZE_LIFT_RATE * delta))
			s.tendril.draw(hand, e.global_position + CHEST, shoot, 0.06, float(e.radius) + 0.05, _time)
		elif b.has("cubes"):  # frozen where they hang, until he throws them
			e.global_position = Vector3(s.from.x, SEIZE_LIFT, s.from.z)
			s.tendril.draw(hand, e.global_position + CHEST, 1.0, 0.02, float(e.radius) + 0.05, _time)
		else:
			var k := clampf(t / float(b.dive), 0.0, 1.0)
			var was: Vector3 = Vector3(s.from.x, SEIZE_LIFT, s.from.z)
			var land: Vector3 = hero._brk_zone.lerp(Vector3(s.from.x, 0.0, s.from.z), 1.0 - SEIZE_IN) + s.get("fan", Vector3.ZERO) * SEIZE_IN
			e.global_position = was.lerp(land, k * k)
			s.tendril.draw(hand, e.global_position + CHEST, 1.0, 0.02, float(e.radius) + 0.05, _time)


## The slam lands: who's still held, on the floor. The caller hits them, then release_seized() lets go.
func slam_seized() -> Array:
	var foes := []
	for s: Dictionary in _seized:
		var e: Node3D = s.foe
		if is_instance_valid(e) and e.is_alive():
			if s.has("crush_to"):
				e.global_position = s.crush_to
			e.global_position.y = 0.0
			foes.append(e)
	return foes


## Avalanche: the middle of all the cubes held, and each one's place in a pile there. One on its own comes
## straight back down where it was.
func aim_crush() -> void:
	var live: Array = _seized.filter(func(s: Dictionary) -> bool: return is_instance_valid(s.foe) and s.foe.is_alive())
	if live.is_empty():
		dark_spot = Vector3(hero.global_position.x, 0.0, hero.global_position.z)
		return
	var mid := Vector3.ZERO
	for s: Dictionary in live:
		mid += s.foe.global_position
	mid /= float(live.size())
	mid.y = 0.0
	dark_spot = mid
	var ring: float = 0.0 if live.size() == 1 else maxf(VOID_ELEMENT.CRUSH_CUBE_WIDTH * 0.5, live.size() * VOID_ELEMENT.CRUSH_CUBE_WIDTH / TAU)
	for i in live.size():
		var s: Dictionary = live[i]
		var out: Vector3 = s.foe.global_position - mid
		out.y = 0.0
		if out.length() < 0.1:
			out = Vector3(sin(TAU * i / live.size()), 0.0, cos(TAU * i / live.size()))
		s["crush_from"] = s.foe.global_position
		s["crush_to"] = mid + out.normalized() * ring


## Cold Front: everyone held freezes solid.
func freeze_seized() -> void:
	for e: Node3D in held_foes():
		VOID_ELEMENT.encase(e)


## Who's still held, where they are.
func held_foes() -> Array:
	var foes := []
	for s: Dictionary in _seized:
		if is_instance_valid(s.foe) and s.foe.is_alive():
			foes.append(s.foe)
	return foes


## Lets go of everyone (a miss drops them where they hang). The tentacles are kept for next time.
func release_seized() -> void:
	for s: Dictionary in _seized:
		s.tendril.visible = false
		s.tendril.line = false
		_spare.append(s.tendril)
		if s.has("other"):
			s.other.queue_free()
	_seized.clear()


# --- Travelling (player.State.SWING) ------------------------------------------

## R: a pillar or something big where he's aiming, or the tentacle goes up off the top of the screen.
func traverse() -> void:
	_clear_target()
	var big := get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return e.is_alive() and is_heavy(e))
	var anchors := get_tree().get_nodes_in_group("grab_anchors").filter(func(a: Node3D) -> bool:
		return a.global_position.y > -1.0)  # (a room's old pillars sink away)
	var p := pick(hero.global_position, _aim_dir(), big, anchors)
	if p.kind == "anchor":
		_begin_swing(p.node)
	elif p.kind == "heavy":
		var to: Vector3 = p.node.global_position - hero.global_position
		to.y = 0.0
		if to.length() > float(p.node.radius) + PULL_STOP + 1.0:
			_begin_pull(p.node, 0.0)
		else:
			_begin_sky()
	else:
		_begin_sky()


func _begin_sky() -> void:
	_kind = "sky"
	_t = 0.0
	_struck = {}
	_dir = _aim_dir()
	_dir.y = 0.0
	_dir = _dir.normalized()
	_pivot = hero.global_position + _dir * SKY_LEAD + Vector3.UP * SKY_HIGH
	_start_travel(0.0)
	hero._face(_dir)


func _begin_pull(e: Node3D, invuln: float) -> void:
	_kind = "pull"
	_target = e
	_t = 0.0
	_start_travel(invuln)
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
	var push: Vector3 = hero.HERO_INPUT.input_dir(hero)
	if push.length() <= 0.1:
		push = hero._facing()
	_sign = -1.0 if out.cross(push).y > 0.0 else 1.0
	_start_travel(0.0)


func _start_travel(invuln: float) -> void:
	hero._dash_from = hero.global_position  # (what he passes is what Tow Line finds)
	arm.shape("hand")
	hero._invuln_t = maxf(hero._invuln_t, invuln)
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
	if _kind != "pull" and hero._buffered == "heavy" and not is_instance_valid(_carry):
		var e := _carry_pick()
		if e != null:
			hero._buffered = ""
			_carry = e
	_tick_carry()
	if _kind == "pull":
		_tick_pull(delta)
	elif _kind == "sky":
		_tick_sky(delta)
	else:
		_tick_swing(delta)


## Right click on a swing: the nearest small foe in reach comes along.
func _carry_pick() -> Node3D:
	var at: Vector3 = hero.global_position
	var best: Node3D = null
	var best_d := CARRY_REACH
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive() or is_heavy(e) or VOID_ELEMENT.THROWN.flying(e):
			continue
		var d: float = (e.global_position - at).length() - float(e.radius)
		if d < best_d:
			best_d = d
			best = e
	return best


func _tick_carry() -> void:
	if not is_instance_valid(_carry) or not _carry.is_alive():
		_carry = null
		if _carry_rope != null:
			_carry_rope.visible = false
		return
	if _carry_rope == null:
		_carry_rope = TENDRIL.new()
		hero.add_child(_carry_rope)
	var at: Vector3 = hero.global_position + _tangent() * CARRY_AT + Vector3.UP * hero.model.position.y
	_carry.global_position = at
	_carry.velocity = Vector3.ZERO
	if _carry.has_method("stagger") and fmod(_time, RESTAGGER) < hero.get_physics_process_delta_time():
		_carry.stagger(HOLD)
	_carry_rope.draw(_hand_pos(), at + CHEST, 1.0, 0.03, float(_carry.radius) + 0.05, _time)


## What he's carrying flies on when he lets go.
func _drop_carry() -> void:
	if _carry_rope != null:
		_carry_rope.visible = false
	if not is_instance_valid(_carry):
		_carry = null
		return
	var e := _carry
	_carry = null
	if not e.is_alive():
		return
	VOID_ELEMENT.THROWN.launch(hero, e, e.global_position + _tangent() * VOID_ELEMENT.CARRY_LENGTH,
		VOID_ELEMENT.CARRY_DAMAGE * hero._dmg_mult * hero.HERO_FX.cast_power(), {"el": "void"})


func _tick_sky(delta: float) -> void:
	var shoot := smoothstep(0.0, SWING_SHOOT, _t)
	tendril.draw(_hand_pos(), _pivot, shoot, 0.04, 0.0, _time)
	if shoot < 1.0:
		hero.velocity.x = 0.0
		hero.velocity.z = 0.0
		return
	var air := _t - SWING_SHOOT
	var hold := Input.is_action_pressed("traverse")
	if hero._buffered != "" or air >= SKY_MAX or (air >= SKY_MIN and not hold):
		_release(true)
		return
	var want: Vector3 = _aim_dir()
	want.y = 0.0
	if want.length() > 0.01:
		var turn := _dir.signed_angle_to(want.normalized(), Vector3.UP)
		_dir = _dir.rotated(Vector3.UP, clampf(turn, -SKY_TURN * delta, SKY_TURN * delta))
	hero.velocity.x = _dir.x * SWING_SPEED
	hero.velocity.z = _dir.z * SWING_SPEED
	hero._face(_dir)
	hero.model.position.y = move_toward(hero.model.position.y, SKY_LIFT, 7.0 * delta)
	_rake()
	if air > 0.1 and hero.get_real_velocity().length() < 2.0:
		_release(false)  # into a wall


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
	var hold := Input.is_action_pressed("traverse")
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
	if _kind == "sky":
		return _dir
	return Vector3(-sin(_ang), 0.0, cos(_ang)) * _sign


func _release(fling: bool) -> void:
	_drop_carry()
	_anchor = null
	if fling:
		var v := _tangent() * SWING_SPEED * FLING_MULT
		hero.velocity.x = v.x
		hero.velocity.z = v.z
		hero._fling_t = FLING_TIME
		hero._post_dash_t = FLING_TIME  # so a press off the fling is the dash's lunge
		hero._face(_tangent())
	hero._set_state(hero.State.MOVE)
