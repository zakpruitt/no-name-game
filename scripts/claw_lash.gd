extends Node3D
## Dash Stab's lash (elements.CASTS "lash", fired by hero_fx.cast on DL's first hit): the claw whips the
## tentacle's inked ribbon (void_tendril.gd) straight out ahead to `reach`, cutting what its tip passes,
## then snaps it back, cutting again. Each foe once per leg. It replaced the shaman's spirit tomahawk
## (round 30, second pass) with the same damage, reach and timing: 0.3 s out, 0.32 s back.

const FOES := preload("res://scripts/foes.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const HEIGHT := 0.9  # m: the line it cuts along
const WAVE := 0.12  # how hard the ribbon whips on the way out
const SNAP_WAVE := 0.03  # nearly straight when it's taut, at the far end

var color := Color(0.3, 0.95, 0.85)  # (set by hero_fx.spirit; the ink keeps the tentacle's own colours)
var el := "spirit"
var dir := Vector3.FORWARD
var hero: Node3D  # it comes out of his hand and goes back to it
var size := 2.6  # m across what the tip cuts (the tomahawk's size)
var reach := 8.0
var out_time := 0.3
var back_time := 0.32
var damage := 6.0
var back_damage := 4.0
var on_hit := Callable()
## Round 55 cool pass 4 (combo-cool4): the catch. At the far end the lash's barb takes the furthest light foe it cut on
## the way out (CATCH_MIN m or more from him) and the back leg reels it in to CATCH_TO m in front of him: the tentacle
## brings the straggler to the stab, a snap (catch_damage) and a stop as it gets there. It lets go early once he is out
## of Dash Stab (Harpoon takes it from there). Best: a foe behind the one he lunged at.
const VOID_GRAB := preload("res://scripts/void_grab.gd")
const CATCH_MIN := 3.2
const CATCH_TO := 1.7
const CATCH_STOP := 0.05
const AIM_CONE := 50.0  # degrees round the line to the foe he lunged at
const AIM_RANGE := 8.0  # m (elements.CASTS DL range)
const FLYING := "thrown_foe_flying"
static var catches := 0  # (checks)
var catch := true
var catch_damage := 6.0
var _caught: Node3D
var _caught_from := Vector3.ZERO

var _rope: Node3D
var _from := Vector3.ZERO
var _k := 0.0  # 0..1 how far out the tip is
var _back := false
var _hit: Array[Node] = []
var _time := 0.0


func _ready() -> void:
	_from = global_position
	if catch:
		_aim_catch()
	_rope = TENDRIL.new()
	add_child(_rope)
	var tw := create_tween()
	tw.tween_method(_out, 0.0, 1.0, out_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_turn)
	tw.tween_method(_in, 1.0, 0.0, back_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	var hand := _hand()
	var tip := Vector3(_from.x, HEIGHT, _from.z) + dir * reach * _k
	if _caught != null:
		tip = _reel()
	_rope.draw(hand, tip, maxf(_k, 0.05), lerpf(WAVE, SNAP_WAVE, _k), 0.0 if _caught == null else 0.55, _time)
	_cut(tip)


func _out(k: float) -> void:
	_k = k


func _in(k: float) -> void:
	_k = k


func _turn() -> void:
	_back = true
	if catch:
		_catch()
	_hit.clear()
	var tip := Vector3(_from.x, HEIGHT, _from.z) + dir * reach
	Fx.DESIGNED.hit(get_parent(), tip, el, 1.0)  # the snap: a drawn star in the lash's element


## Round 55: the lash goes for the straggler. Round the line to the foe he lunged at (his aim lock, else his aim), the
## furthest foe within AIM_CONE degrees and the lash's range, CATCH_MIN m or more off, is where it whips to.
func _aim_catch() -> void:
	if not is_instance_valid(hero) or not is_inside_tree():
		return
	var base := dir
	var lock: Variant = hero.get("_aim_lock")
	if lock is Node3D and is_instance_valid(lock):
		var to: Vector3 = _flat((lock as Node3D).global_position - hero.global_position)
		if to.length() > 0.3:
			base = to.normalized()
	var best: Node3D = null
	var best_d := CATCH_MIN
	for e: Node3D in FOES.near(get_tree(), _flat(hero.global_position), AIM_RANGE):
		if VOID_GRAB.is_heavy(e) or e.has_meta(FLYING):
			continue
		var to := _flat(e.global_position - hero.global_position)
		if to.length() <= best_d or rad_to_deg(base.angle_to(to.normalized())) > AIM_CONE:
			continue
		best = e
		best_d = to.length()
	if best == null:
		return
	var to := _flat(best.global_position - _from)
	dir = to.normalized()
	reach = minf(AIM_RANGE, to.length() + 0.9)


## The barb takes the furthest foe the out leg cut, if it is light, free and far enough to be worth bringing in.
func _catch() -> void:
	if not is_instance_valid(hero):
		return
	var best: Node3D = null
	var best_d := CATCH_MIN
	for e: Node in _hit:
		if not is_instance_valid(e) or not (e as Node).has_method("is_alive") or not e.is_alive() or e.has_meta(FLYING):
			continue
		if VOID_GRAB.is_heavy(e):
			continue
		var d := _flat((e as Node3D).global_position - hero.global_position).length()
		if d > best_d:
			best_d = d
			best = e as Node3D
	if best == null:
		return
	_caught = best
	catch_damage = damage  # (the cast's own, scaled by the chain)
	_caught_from = best.global_position
	best.set_meta(FLYING, true)
	catches += 1
	if best.has_method("stagger"):
		best.stagger(0.6)


## The caught foe rides the back leg in toward him; let go at CATCH_TO, or when he leaves Dash Stab.
func _reel() -> Vector3:
	var e := _caught
	if not is_instance_valid(e) or not is_instance_valid(hero):
		_let_go(false)
		return Vector3(_from.x, HEIGHT, _from.z) + dir * reach * _k
	var to: Vector3 = _flat(hero.global_position) + dir * CATCH_TO
	var p: Vector3 = to.lerp(_flat(_caught_from), _k)
	e.global_position = Vector3(p.x, 0.0, p.z)
	if e is CharacterBody3D:
		(e as CharacterBody3D).velocity = Vector3.ZERO
	if _k <= 0.08 or str(hero.get("_move_id")) != "DL":
		_let_go(_k <= 0.08)
	return e.global_position + Vector3.UP * HEIGHT


func _let_go(arrived: bool) -> void:
	var e := _caught
	_caught = null
	if not is_instance_valid(e):
		return
	if e.has_meta(FLYING):
		e.remove_meta(FLYING)
	if arrived and e.has_method("is_alive") and e.is_alive():
		e.take_hit(catch_damage, -dir * 2.0, 0.0, false)
		Game.register_hit("cast")
		Game.hitstop(CATCH_STOP)
		Game.shake(0.2)
		Fx.DESIGNED.hit(get_parent(), e.global_position + Vector3.UP * HEIGHT, "void", 1.1)


func _exit_tree() -> void:
	if _caught != null:
		_let_go(false)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Where the ribbon starts: his claw when the rig has one, else his chest.
func _hand() -> Vector3:
	if is_instance_valid(hero):
		var v: Variant = hero.get("_void")
		if v != null and is_instance_valid(v) and v.has_method("_hand_pos"):
			return v._hand_pos()
		return hero.global_position + Vector3.UP * HEIGHT
	return Vector3(_from.x, HEIGHT, _from.z)


func _cut(tip: Vector3) -> void:
	var at := Vector3(tip.x, 0.0, tip.z)
	for e in FOES.near(get_tree(), at, size * 0.55):
		if e in _hit:
			continue
		_hit.append(e)
		var push: Vector3 = dir if not _back else -dir
		SPIRIT_ECHO.strike(e, back_damage if _back else damage, push * 4.0, 0.0, false,
			get_parent(), el, push, false, on_hit)
