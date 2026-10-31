extends CharacterBody3D
## The hero: movement, dash (with i-frames, cancels attacks), light/heavy
## combo routes, soft auto-aim, and the Awakening transformation.

signal health_changed(hp: float, max_hp: float)
signal awakened_changed(active: bool)
signal died
## Fired when any attack begins (enemies that dodge listen for this).
signal attack_started(move_id: String)

enum State { MOVE, ATTACK, DASH, HURT, CHARGE, DEAD }

const MODEL := preload("res://assets/kaykit/characters/Barbarian.glb")
const TRAIL := preload("res://scripts/weapon_trail.gd")
const TRAIL_MESHES := ["1H_Axe", "1H_Axe_Offhand"]
const HIDDEN_MESHES := ["Barbarian_Round_Shield", "2H_Axe", "Mug"]
const LOOPING := ["Idle", "Running_A", "2H_Melee_Idle"]

@export var move_speed := 7.5
@export var accel := 70.0
@export var dash_speed := 24.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.3
@export var max_hp := 100.0
@export var anim_speed := 1.7
@export var input_buffer := 0.25
@export var aim_assist_range := 5.5
@export var aim_assist_angle := 70.0
@export var awaken_duration := 12.0
@export var afterimage_interval := 0.035
## Dash this soon before an enemy hit lands for a perfect dodge.
@export var perfect_dodge_window := 0.15
@export var perfect_dodge_refund := 20.0
@export var perfect_dodge_stun := 1.2

# Moves. Timings are fractions of the animation's length, so changing
# anim_speed keeps everything in sync.
#   hits: when damage is dealt   cancel: when the next input is accepted
#   end: when control returns    lunge: forward burst speed at start
const MOVES := {
	"L1": {"anim": "1H_Melee_Attack_Slice_Diagonal", "damage": 8.0, "range": 2.4, "arc": 140.0,
		"hits": [0.35], "cancel": 0.45, "end": 0.75, "lunge": 7.0, "knockback": 2.5, "launch": 0.0,
		"stop": 0.045, "shake": 0.12},
	"L2": {"anim": "1H_Melee_Attack_Slice_Horizontal", "damage": 9.0, "range": 2.5, "arc": 160.0,
		"hits": [0.35], "cancel": 0.45, "end": 0.75, "lunge": 7.0, "knockback": 2.5, "launch": 0.0,
		"stop": 0.05, "shake": 0.14},
	"L3": {"anim": "Dualwield_Melee_Attack_Chop", "damage": 16.0, "range": 2.7, "arc": 150.0,
		"hits": [0.4], "cancel": 0.6, "end": 0.85, "lunge": 9.0, "knockback": 11.0, "launch": 0.0,
		"stop": 0.1, "shake": 0.35, "big": true},
	# Heavy from neutral: spinning AoE, multi-hit.
	"H": {"anim": "2H_Melee_Attack_Spin", "damage": 6.0, "range": 3.2, "arc": 360.0,
		"hits": [0.3, 0.45, 0.6], "cancel": 0.7, "end": 0.85, "lunge": 4.0, "knockback": 3.0, "launch": 0.0,
		"stop": 0.035, "shake": 0.12},
	# Heavy after any light hit: launcher. Juggled enemies take bonus style.
	"LH": {"anim": "2H_Melee_Attack_Chop", "damage": 14.0, "range": 2.6, "arc": 120.0,
		"hits": [0.4], "cancel": 0.55, "end": 0.8, "lunge": 6.0, "knockback": 2.0, "launch": 9.0,
		"stop": 0.09, "shake": 0.3, "big": true},
	# Charged heavy: hold heavy from neutral for CHARGE_TIME, then release.
	# Big launching slam; breaks shield guards (launch > 0).
	"CH": {"anim": "2H_Melee_Attack_Chop", "damage": 30.0, "range": 3.4, "arc": 160.0,
		"hits": [0.4], "cancel": 0.6, "end": 0.85, "lunge": 10.0, "knockback": 12.0, "launch": 8.0,
		"stop": 0.14, "shake": 0.55, "big": true},
	# Light right out of a dash: long lunging stab.
	"DL": {"anim": "1H_Melee_Attack_Stab", "damage": 12.0, "range": 2.8, "arc": 90.0,
		"hits": [0.3], "cancel": 0.5, "end": 0.7, "lunge": 16.0, "knockback": 7.0, "launch": 0.0,
		"stop": 0.07, "shake": 0.22},
	# Awakened only: heavy right after L3. Huge two-handed swing that erupts all around.
	"AF": {"anim": "2H_Melee_Attack_Slice", "damage": 30.0, "range": 4.5, "arc": 360.0,
		"hits": [0.45], "cancel": 0.7, "end": 0.9, "lunge": 5.0, "knockback": 6.0, "launch": 10.0,
		"stop": 0.16, "shake": 0.7, "big": true},
}
const LIGHT_CHAIN := ["L1", "L2", "L3"]
# Charging (hold heavy from neutral): release before CHARGE_TIME for the
# normal spin (H), after it for the charged slam (CH). You can creep while
# charging at CHARGE_MOVE_MULT speed; dash cancels the charge.
const CHARGE_TIME := 0.8
const CHARGE_MOVE_MULT := 0.35
const CHARGE_COLOR := Color(1.0, 0.85, 0.45)
const FIRE_WAVE := preload("res://scripts/fire_wave.gd")
const CATACLYSM_WAVES := 6  # fire waves radiating from the Awakened finisher

var hp := max_hp
var state := State.MOVE
var awakened := false
var model: Node3D
var anim: AnimationPlayer

var _state_t := 0.0
var _move_id := ""
var _move: Dictionary = {}
var _move_len := 1.0
var _hits_done := 0
var _chain_i := 0
var _chain_reset_t := 0.0
var _buffered := ""
var _buffer_t := 0.0
var _dash_buffer_t := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.FORWARD
var _post_dash_t := 0.0
var _awaken_t := 0.0
var _facing_yaw := 0.0
var _invuln_t := 0.0
var _anim_mult := 1.0
var _dmg_mult := 1.0
var _second_wind_used := false
var _charged := false
var _charge_fx_t := 0.0
var _charge_light: OmniLight3D
var charged_slams := 0  # reported by the autotest
var cataclysms := 0  # finishers landed (reported by the autotest)
var _awaken_light: OmniLight3D
var _trails: Array = []
var _ghost_t := 0.0
var _since_dash := 99.0
var _perfect_this_dash := false

# Lets the autotest drive the hero without real input.
var bot_move := Vector3.ZERO

## Owned combo-slot upgrades: id -> level (see upgrades.gd).
var upgrades := {}
var _awaken_base := -1.0
var bot_enabled := false


func _ready() -> void:
	hp = max_hp
	Game.enemy_killed.connect(_on_enemy_killed)
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	model = MODEL.instantiate()
	add_child(model)
	Fx.outline(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name in HIDDEN_MESHES:
			mi.visible = false
		elif mi.name in TRAIL_MESHES:
			var trail := TRAIL.new()
			add_child(trail)
			trail.setup(mi)
			_trails.append(trail)
	anim = model.find_child("AnimationPlayer", true, false)
	for a in LOOPING:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR

	_awaken_light = OmniLight3D.new()
	_awaken_light.light_color = Color(1.0, 0.5, 0.15)
	_awaken_light.light_energy = 0.0
	_awaken_light.omni_range = 5.0
	_awaken_light.position.y = 1.2
	add_child(_awaken_light)
	_charge_light = OmniLight3D.new()
	_charge_light.light_color = CHARGE_COLOR
	_charge_light.light_energy = 0.0
	_charge_light.omni_range = 4.0
	_charge_light.position.y = 1.0
	add_child(_charge_light)

	health_changed.emit(hp, max_hp)
	_play("Idle")


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_read_input()

	if not is_on_floor():
		velocity.y -= 30.0 * delta
	else:
		velocity.y = 0.0

	match state:
		State.MOVE: _state_move(delta)
		State.ATTACK: _state_attack(delta)
		State.DASH: _state_dash(delta)
		State.HURT: _state_hurt(delta)
		State.CHARGE: _state_charge(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)

	move_and_slide()
	var swinging: bool = state == State.ATTACK and _state_t * anim_speed * _anim_mult / _move_len < _move.cancel
	for trail in _trails:
		trail.emitting = swinging
	model.rotation.y = lerp_angle(model.rotation.y, _facing_yaw, 1.0 - exp(-25.0 * delta))


func _tick_timers(delta: float) -> void:
	_state_t += delta
	_since_dash += delta
	_buffer_t -= delta
	_dash_buffer_t -= delta
	_dash_cd -= delta
	_post_dash_t -= delta
	_invuln_t -= delta
	_chain_reset_t -= delta
	if _buffer_t <= 0.0:
		_buffered = ""
	if _chain_reset_t <= 0.0 and state != State.ATTACK:
		_chain_i = 0
	if awakened:
		_awaken_t -= delta
		Game.add_awakening(-Game.AWAKEN_MAX / awaken_duration * delta)
		if _awaken_t <= 0.0:
			_set_awakened(false)


func _read_input() -> void:
	if state == State.DEAD:
		return
	if Input.is_action_just_pressed("attack_light"):
		_buffered = "light"
		_buffer_t = input_buffer
	elif Input.is_action_just_pressed("attack_heavy"):
		_buffered = "heavy"
		_buffer_t = input_buffer
	if Input.is_action_just_pressed("dash"):
		_dash_buffer_t = input_buffer
	if Input.is_action_just_pressed("awaken"):
		try_awaken()


func _input_dir() -> Vector3:
	if bot_enabled:
		return bot_move
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return Vector3(v.x, 0.0, v.y)


func facing_dir() -> Vector3:
	return _facing()


func _facing() -> Vector3:
	return Vector3(sin(_facing_yaw), 0.0, cos(_facing_yaw))


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		_facing_yaw = atan2(dir.x, dir.z)


# --- States -----------------------------------------------------------------

func _state_move(delta: float) -> void:
	var dir := _input_dir()
	var speed := move_speed * (1.2 if awakened else 1.0)
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	_face(dir)
	_play("Running_A" if dir.length() > 0.1 else "Idle", 0.12)

	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0:
		_start_dash()
	elif _buffered == "heavy" and _next_move("heavy") == "H" and Input.is_action_pressed("attack_heavy"):
		_start_charge()
	elif _buffered != "":
		_start_attack(_next_move(_buffered))


func _start_charge() -> void:
	_buffered = ""
	_charged = false
	_charge_fx_t = 0.0
	_set_state(State.CHARGE)
	_play("2H_Melee_Idle", 0.1)


func _state_charge(delta: float) -> void:
	var dir := _input_dir()
	var target := dir * move_speed * CHARGE_MOVE_MULT
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	_face(dir)
	var k := clampf(_state_t / CHARGE_TIME, 0.0, 1.0)
	_charge_light.light_energy = k * 2.5
	_charge_fx_t -= delta
	if _charge_fx_t <= 0.0:
		_charge_fx_t = 0.12
		Fx.burst(get_parent(), global_position + Vector3.UP * 0.2, CHARGE_COLOR, 4 + int(k * 8), 2.0 + k * 3.0,
			0.08, 0.35, Vector3.UP, 30.0, 2.0, 0.9 - k * 0.4)
	if k >= 1.0 and not _charged:
		_charged = true
		Fx.ring(get_parent(), global_position, Color(CHARGE_COLOR, 0.9), 2.2, 0.25)
		Fx.flash(model)
		Game.sfx("perfect", -6.0, 0.0)
	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0:
		_start_dash()
	elif not Input.is_action_pressed("attack_heavy"):
		_start_attack("CH" if _charged else "H")


func _state_attack(delta: float) -> void:
	var t := _state_t * anim_speed * _anim_mult / _move_len  # normalized progress
	# Lunge decays quickly so attacks feel snappy, not slidey.
	var lunge: float = _move.lunge * maxf(0.0, 1.0 - t * 3.0)
	var fwd := _facing()
	velocity.x = fwd.x * lunge
	velocity.z = fwd.z * lunge

	var hits: Array = _move.hits
	while _hits_done < hits.size() and t >= hits[_hits_done]:
		_hits_done += 1
		_do_hit()

	# Dash cancels anything once the first hit has come out (or early on whiff).
	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0 and (_hits_done > 0 or t > 0.2):
		if _hits_done > 0 and has_upgrade("static_step"):
			_static_trap(global_position)
		_start_dash()
		return
	if t >= _move.cancel and _buffered != "":
		_start_attack(_next_move(_buffered))
		return
	if t >= _move.end:
		_chain_reset_t = 0.35
		_set_state(State.MOVE)


func _state_dash(delta: float) -> void:
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = afterimage_interval
		var tint := Color(1.0, 0.55, 0.15, 0.45) if awakened else Color(0.55, 0.8, 1.0, 0.4)
		Fx.afterimage(get_parent(), model, tint)
	velocity.x = _dash_dir.x * dash_speed
	velocity.z = _dash_dir.z * dash_speed
	if _state_t >= dash_time:
		velocity.x *= 0.3
		velocity.z *= 0.3
		_post_dash_t = 0.3
		_set_state(State.MOVE)


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	if _dash_buffer_t > 0.0 and _state_t > 0.12 and _dash_cd <= 0.0:
		_start_dash()  # dash out of hitstun = burst escape
	elif _state_t >= 0.35:
		_set_state(State.MOVE)


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0
	if s != State.CHARGE:
		_charge_light.light_energy = 0.0


# --- Actions ----------------------------------------------------------------

func _next_move(kind: String) -> String:
	if kind == "light":
		if _post_dash_t > 0.0:
			return "DL"
		var id: String = LIGHT_CHAIN[_chain_i % LIGHT_CHAIN.size()]
		return id
	# Heavy: Awakened finisher off L3, launcher if mid-string, spin from neutral.
	if awakened and state == State.ATTACK and _move_id == "L3":
		return "AF"
	if (state == State.ATTACK and _move_id != "H") or _chain_i > 0:
		return "LH"
	return "H"


func _start_attack(id: String) -> void:
	_buffered = ""
	_move_id = id
	_move = _effective_move(id)
	_move_len = anim.get_animation(_move.anim).length
	_hits_done = 0
	if id in LIGHT_CHAIN:
		_chain_i = (LIGHT_CHAIN.find(id) + 1) % LIGHT_CHAIN.size()
	elif id == "DL":
		_chain_i = 1  # a dash stab flows into L2
	else:
		_chain_i = 0
	_post_dash_t = 0.0
	_aim()
	_set_state(State.ATTACK)
	attack_started.emit(id)
	Game.sfx("swing_heavy" if id in ["H", "LH", "AF", "CH"] else "swing", -3.0, 0.12)
	_play(_move.anim, 0.05, true)


func _start_dash() -> void:
	_dash_buffer_t = 0.0
	_dash_cd = dash_cooldown
	var dir := _input_dir()
	_dash_dir = dir.normalized() if dir.length() > 0.1 else _facing()
	_face(_dash_dir)
	_invuln_t = dash_time + 0.08
	_since_dash = 0.0
	_perfect_this_dash = false
	_set_state(State.DASH)
	_ghost_t = 0.0
	_play("Dodge_Forward", 0.04, true)
	Fx.dust(get_parent(), global_position, 8)
	Game.sfx("dash", -4.0)


## Soft lock-on: rotate toward the best enemy roughly in front of us.
func _aim() -> void:
	var dir := _input_dir()
	var want := dir.normalized() if dir.length() > 0.1 else _facing()
	var best: Node3D = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > aim_assist_range or d < 0.01:
			continue
		var ang := rad_to_deg(want.angle_to(to / d))
		if ang > aim_assist_angle:
			continue
		var score := d + ang * 0.05
		if score < best_score:
			best_score = score
			best = e
	if best:
		want = best.global_position - global_position
		want.y = 0.0
	_face(want)
	model.rotation.y = _facing_yaw  # snap: attacks must point where they hit


func _do_hit() -> void:
	var fwd := _facing()
	var hit_any := false
	var any_airborne := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > _move.range + e.radius:
			continue
		if _move.arc < 360.0 and d > 0.4 and rad_to_deg(fwd.angle_to(to / d)) > _move.arc * 0.5:
			continue
		var kb_dir := to / d if d > 0.01 else fwd
		var was_airborne: bool = e.is_airborne()
		any_airborne = any_airborne or was_airborne
		var dmg: float = _move.damage * _dmg_mult
		if _move_id == "CH" and has_upgrade("bone_breaker") and (e.shield or e.elite or e.has_method("is_boss")):
			dmg *= 1.0 + upg("bone_breaker", "bonus") / 100.0
			Fx.ring(get_parent(), e.global_position, Color(1.0, 0.95, 0.8, 0.9), 1.4, 0.25)
		e.take_hit(dmg, kb_dir * _move.knockback, _move.launch, _move.get("big", false))
		Game.register_hit(_move_id + ("_air" if was_airborne else ""))
		hit_any = true
		if was_airborne and has_upgrade("chain_spark"):
			_chain_spark(e)
		if _move_id == "L1" and has_upgrade("bloodthirst"):
			heal(upg("bloodthirst", "heal"), false)
	# Slot effects that fire on the move's first active frame, hit or miss.
	if _hits_done == 1:
		if _move_id == "L3" and has_upgrade("ember_cleave"):
			var w := FIRE_WAVE.new()
			w.direction = fwd
			w.damage = upg("ember_cleave", "damage")
			get_parent().add_child(w)
			w.global_position = global_position + fwd * 1.0
		if _move_id == "AF":
			_cataclysm()
		if _move_id == "CH":
			charged_slams += 1
			var at := global_position + fwd * 1.6
			Fx.ring(get_parent(), at, Color(CHARGE_COLOR, 0.9), _move.range, 0.3)
			Fx.burst(get_parent(), at + Vector3.UP * 0.2, CHARGE_COLOR, 24, 9.0, 0.14, 0.35, Vector3.UP, 80.0)
			Fx.dust(get_parent(), at, 16, 1.0)
			if has_upgrade("quake"):
				_quake(at)
		if _move_id == "LH" and has_upgrade("skybreaker"):
			var r := upg("skybreaker", "radius")
			Fx.ring(get_parent(), global_position, Color(0.9, 0.95, 1.0, 0.8), r, 0.3)
			for e in get_tree().get_nodes_in_group("enemies"):
				var to: Vector3 = e.global_position - global_position
				to.y = 0.0
				if e.is_alive() and not e.is_airborne() and to.length() < r:
					e.take_hit(4.0, to.normalized() * 2.0, 8.0, false)
					Game.register_hit("skybreaker")
	if hit_any:
		Game.sfx("hit_big" if _move.get("big", false) else "hit")
		if _move.get("big", false):
			Game.rumble("hit_big")
		Game.hitstop(_move.stop * (1.3 if any_airborne else 1.0))
		Game.shake(_move.shake)


# --- Upgrades ---------------------------------------------------------------

func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


## Current level's tuning number `key` for owned upgrade `id` (upgrades.gd lv).
func upg(id: String, key: String) -> float:
	return Upgrades.value(id, key, upgrades.get(id, 1))


## Gain an upgrade, or level it up if it's already owned (up to MAX_LEVEL).
func add_upgrade(id: String) -> void:
	upgrades[id] = mini(upgrades.get(id, 0) + 1, Upgrades.MAX_LEVEL)
	if id == "overflow":
		Game.awakening_gain_mult = 1.0 + upg(id, "bonus") / 100.0
	if id == "long_night":
		if _awaken_base < 0.0:
			_awaken_base = awaken_duration
		awaken_duration = _awaken_base * (1.0 + upg(id, "bonus") / 100.0)


func _on_enemy_killed(_e: Node) -> void:
	if has_upgrade("reaper") and state != State.DEAD:
		heal(upg("reaper", "heal"), false)
		Game.add_awakening(upg("reaper", "awaken"))


## Quake: a shockwave out from the charged slam's impact.
func _quake(at: Vector3) -> void:
	var r := upg("quake", "radius")
	Fx.ring(get_parent(), at, Color(1.0, 0.75, 0.35, 0.9), r, 0.45)
	Game.shake(0.3)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - at
		to.y = 0.0
		if e.is_alive() and to.length() < r:
			e.take_hit(upg("quake", "damage"), to.normalized() * 5.0, 6.0, true)
			Game.register_hit("quake")


## MOVES entry with owned upgrades applied (never mutates MOVES itself).
func _effective_move(id: String) -> Dictionary:
	var m: Dictionary = MOVES[id].duplicate(true)
	if id == "H" and has_upgrade("whirlwind"):
		# Spread the extra hits evenly across the spin.
		var n := int(upg("whirlwind", "hits"))
		m.hits = []
		for i in n:
			m.hits.append(lerpf(0.22, 0.7, float(i) / (n - 1)))
		m.range += upg("whirlwind", "reach")
	if id == "L2" and has_upgrade("rising_edge"):
		m.launch = upg("rising_edge", "launch")
	if id == "DL" and has_upgrade("momentum"):
		m.damage *= 1.0 + upg("momentum", "bonus") / 100.0
		m.range += 1.5
		m.lunge *= 1.3
	return m


func _chain_spark(from: Node3D) -> void:
	var targets := get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		return e != from and e.is_alive() and e.global_position.distance_to(from.global_position) < 6.0)
	targets.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(from.global_position) < b.global_position.distance_to(from.global_position))
	for e in targets.slice(0, int(upg("chain_spark", "targets"))):
		var mid: Vector3 = (from.global_position + e.global_position) * 0.5
		Fx.burst(get_parent(), mid + Vector3.UP, Color(0.5, 0.85, 1.0), 10, 6.0, 0.15, 0.2)
		e.take_hit(upg("chain_spark", "damage"), Vector3.ZERO, 0.0, false)
		Game.register_hit("chain_spark")


func _static_trap(pos: Vector3) -> void:
	Fx.ring(get_parent(), pos, Color(0.5, 0.85, 1.0, 0.6), 1.2, 0.4)
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	Fx.ring(get_parent(), pos, Color(0.6, 0.9, 1.0, 0.9), 3.0, 0.3)
	Fx.burst(get_parent(), pos + Vector3.UP * 0.5, Color(0.6, 0.9, 1.0), 20, 9.0, 0.18, 0.3, Vector3.UP, 90.0)
	Game.sfx("hit_big", -4.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.global_position.distance_to(pos) < 3.0:
			e.take_hit(upg("static_step", "damage"), (e.global_position - pos).normalized() * 4.0, 0.0, true)
			Game.register_hit("static_step")


func is_invulnerable() -> bool:
	return _invuln_t > 0.0


func is_dead() -> bool:
	return state == State.DEAD


func try_awaken() -> void:
	if awakened or state == State.DEAD or Game.awakening < Game.AWAKEN_MAX:
		return
	_set_awakened(true)
	Game.sfx("awaken", 0.0, 0.0)
	Game.rumble("awaken")
	if has_upgrade("phoenix_heart"):
		heal(upg("phoenix_heart", "heal"))
	# Activation burst: big freeze, shockwave that blows enemies back.
	Game.hitstop(0.25, 0.05)
	Game.shake(0.6)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.55, 0.15, 0.9), 7.0, 0.45)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < 7.0:
			e.take_hit(10.0, to.normalized() * 12.0, 5.0, true)


func _set_awakened(on: bool) -> void:
	awakened = on
	_awaken_t = awaken_duration
	_anim_mult = 1.3 if on else 1.0
	_dmg_mult = 1.6 if on else 1.0
	var tw := create_tween().set_parallel()
	tw.tween_property(model, "scale", Vector3.ONE * (1.18 if on else 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_awaken_light, "light_energy", 3.0 if on else 0.0, 0.2)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = Fx.rim_material() if on else null
	for trail in _trails:
		trail.color = Color(1.0, 0.55, 0.15, 0.9) if on else Color(1.0, 0.95, 0.8, 0.8)
	awakened_changed.emit(on)


## Slow time, refund Awakening, stun the attacker, and allow an instant re-dash.
func _perfect_dodge(attacker: Node) -> void:
	_perfect_this_dash = true
	_dash_cd = 0.0
	Game.perfect_dodge(perfect_dodge_refund)
	Game.hitstop(0.5, 0.25)
	Fx.ring(get_parent(), global_position, Color(0.5, 0.85, 1.0, 0.9), 4.0, 0.4)
	Fx.afterimage(get_parent(), model, Color(0.8, 0.95, 1.0, 0.6), 0.5)
	if attacker and attacker.has_method("stagger"):
		attacker.stagger(perfect_dodge_stun)
	if has_upgrade("riposte"):
		_riposte()


## Cataclysm's eruption: fire rings, embers and radiating fire waves on top of the move's own hit.
func _cataclysm() -> void:
	cataclysms += 1
	Game.sfx("awaken", -4.0, 0.1)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.5, 0.15, 0.95), _move.range + 0.5, 0.4)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.85, 0.4, 0.8), _move.range * 0.5, 0.25)
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.3, Color(1.0, 0.5, 0.15), 50, 11.0, 0.2, 0.5, Vector3.UP, 160.0, -8.0, 1.0)
	Fx.dust(get_parent(), global_position, 24, 1.2)
	for i in CATACLYSM_WAVES:
		var ang := TAU * i / CATACLYSM_WAVES
		var w := FIRE_WAVE.new()
		w.direction = Vector3(cos(ang), 0.0, sin(ang))
		w.damage = 8.0
		get_parent().add_child(w)
		w.global_position = global_position + w.direction * 1.0


func _riposte() -> void:
	var r := upg("riposte", "radius")
	Fx.ring(get_parent(), global_position, Color(0.7, 0.9, 1.0, 0.9), r, 0.3)
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.5, Color(0.7, 0.9, 1.0), 24, 9.0, 0.15, 0.3, Vector3.UP, 120.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if e.is_alive() and to.length() < r:
			e.take_hit(upg("riposte", "damage"), to.normalized() * 3.0, 7.0, true)
			Game.register_hit("riposte")


## Restore HP (capped at max). `show` pops a green number and sparkle.
func heal(amount: float, show := true) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	var before := hp
	hp = minf(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)
	if show and hp > before:
		Fx.heal(get_parent(), global_position, hp - before)


func take_hit(damage: float, knockback: Vector3, attacker: Node = null) -> void:
	if state == State.DEAD:
		return
	if _invuln_t > 0.0:
		if _since_dash <= perfect_dodge_window and not _perfect_this_dash:
			_perfect_dodge(attacker)
		return
	hp = maxf(hp - damage * (0.6 if awakened else 1.0), 0.0)
	health_changed.emit(hp, max_hp)
	Game.player_damaged()
	Game.sfx("player_hurt")
	Game.shake(0.4)
	Game.hitstop(0.06)
	Fx.flash(model)
	Fx.damage_number(get_parent(), global_position, damage)
	_invuln_t = 0.5
	velocity.x = knockback.x
	velocity.z = knockback.z
	if hp <= 0.0 and has_upgrade("second_wind") and not _second_wind_used:
		_second_wind_used = true
		hp = max_hp * upg("second_wind", "hp") / 100.0
		health_changed.emit(hp, max_hp)
		Game.announced.emit("SECOND WIND")
		Fx.heal(get_parent(), global_position, hp)
		Game.hitstop(0.3, 0.1)
		_invuln_t = 1.2
	if hp <= 0.0:
		_set_state(State.DEAD)
		if awakened:
			_set_awakened(false)
		_play("Death_A", 0.1, true)
		died.emit()
		return
	# Awakened hero has super armor: takes damage but isn't staggered.
	if not awakened:
		_set_state(State.HURT)
		_play("Hit_A", 0.05, true)


func _play(anim_name: String, blend := 0.1, restart := false) -> void:
	if anim.current_animation == anim_name and not restart:
		return
	anim.play(anim_name, blend, 1.0)
	if restart:
		anim.seek(0.0, true)
	# Locomotion plays at natural speed; actions are sped up for snappiness.
	anim.speed_scale = 1.1 if anim_name in LOOPING else anim_speed * _anim_mult
