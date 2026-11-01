extends CharacterBody3D
## The hero: movement, dash (with i-frames, cancels attacks), light/heavy
## combo routes, soft auto-aim, and the Awakening transformation.

signal health_changed(hp: float, max_hp: float)
signal awakened_changed(active: bool)
signal died
## Fired when any attack begins (enemies that dodge listen for this).
signal attack_started(move_id: String)

enum State { MOVE, ATTACK, DASH, HURT, CHARGE, ULT, DEAD }

const MODEL := preload("res://assets/kaykit/characters/Barbarian.glb")
const TRAIL := preload("res://scripts/weapon_trail.gd")
const HERO_LOOK := preload("res://scripts/hero_look.gd")
const ELEMENTS := preload("res://scripts/elements.gd")
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
## Fixed length of Awakening; nothing extends it, and the meter can't refill
## while it lasts (Game.awaken_locked), so it ends empty.
@export var awaken_duration := 8.0
@export var afterimage_interval := 0.035
## Dash this soon before an enemy hit lands for a perfect dodge.
@export var perfect_dodge_window := 0.15
@export var perfect_dodge_refund := 20.0
@export var perfect_dodge_stun := 1.2
## Each level-up raises max HP by this much (and heals it).
@export var level_hp := 5.0

# Moves. Timings are fractions of the animation's length, so changing
# anim_speed keeps everything in sync.
#   hits: when damage is dealt   cancel: when the next input is accepted
#   end: when control returns    lunge: forward burst speed at start
#   width: (optional) hits a straight strip `range` long and 2x`width` wide
#          instead of the `arc` cone
#   decay: (optional, default 3) how fast the lunge dies: it's gone at 1/decay
#          of the move, so a low decay keeps the hero travelling
const MOVES := {
	"L1": {"anim": "1H_Melee_Attack_Slice_Diagonal", "damage": 8.0, "range": 2.4, "arc": 140.0,
		"hits": [0.35], "cancel": 0.45, "end": 0.75, "lunge": 7.0, "knockback": 2.5, "launch": 0.0,
		"stop": 0.045, "shake": 0.12},
	"L2": {"anim": "Throw", "damage": 9.0, "range": 2.5, "arc": 160.0,
		"hits": [0.42], "cancel": 0.5, "end": 0.7, "lunge": 6.0, "knockback": 2.5, "launch": 0.0,
		"stop": 0.05, "shake": 0.14},
	"L3": {"anim": "Dualwield_Melee_Attack_Chop", "damage": 16.0, "range": 2.7, "arc": 150.0,
		"hits": [0.4], "cancel": 0.6, "end": 0.85, "lunge": 9.0, "knockback": 11.0, "launch": 0.0,
		"stop": 0.1, "shake": 0.35, "big": true},
	# Light after a pause once L2 has finished (L L · L): Flurry, a quick run
	# of small cuts that keeps foes in reach (low knockback).
	"LPL": {"anim": "Dualwield_Melee_Attack_Slice", "damage": 4.5, "range": 2.6, "arc": 170.0,
		"hits": [0.22, 0.32, 0.42, 0.52, 0.62], "cancel": 0.66, "end": 0.85, "lunge": 5.0, "knockback": 0.8,
		"launch": 0.0, "stop": 0.03, "shake": 0.1},
	# Heavy from neutral: spinning AoE, multi-hit.
	"H": {"anim": "2H_Melee_Attack_Spin", "damage": 6.0, "range": 3.2, "arc": 360.0,
		"hits": [0.3, 0.45, 0.6], "cancel": 0.7, "end": 0.85, "lunge": 4.0, "knockback": 3.0, "launch": 0.0,
		"stop": 0.035, "shake": 0.12},
	# Heavy after any light hit: launcher (raises a pillar of the element under
	# the target). Juggled enemies take bonus style.
	"LH": {"anim": "Spellcast_Raise", "damage": 14.0, "range": 2.8, "arc": 120.0,
		"hits": [0.3], "cancel": 0.42, "end": 0.58, "lunge": 3.0, "knockback": 2.0, "launch": 9.0,
		"stop": 0.09, "shake": 0.3, "big": true},
	# Heavy right after L2 (L L H): Ground Breaker, a lunging thrust that
	# knocks down everything in a strip ahead (launch > 0 also breaks guards).
	"LLH": {"anim": "2H_Melee_Attack_Stab", "damage": 18.0, "range": 5.0, "width": 1.1, "arc": 360.0,
		"hits": [0.4], "cancel": 0.6, "end": 0.85, "lunge": 8.0, "knockback": 12.0, "launch": 4.0,
		"stop": 0.1, "shake": 0.4, "big": true},
	# Charged heavy: hold heavy from neutral for CHARGE_TIME, then release.
	# Big launching slam; breaks shield guards (launch > 0).
	"CH": {"anim": "2H_Melee_Attack_Chop", "damage": 30.0, "range": 3.4, "arc": 160.0,
		"hits": [0.4], "cancel": 0.6, "end": 0.85, "lunge": 10.0, "knockback": 12.0, "launch": 8.0,
		"stop": 0.14, "shake": 0.55, "big": true},
	# Light right out of a dash: long lunging stab.
	"DL": {"anim": "1H_Melee_Attack_Stab", "damage": 12.0, "range": 2.8, "arc": 90.0,
		"hits": [0.3], "cancel": 0.5, "end": 0.7, "lunge": 16.0, "knockback": 7.0, "launch": 0.0,
		"stop": 0.07, "shake": 0.22},
	# Heavy right out of a dash: Cyclone, a spin that keeps travelling
	# through the crowd (low lunge decay).
	"DH": {"anim": "2H_Melee_Attack_Spinning", "damage": 6.0, "range": 2.9, "arc": 360.0,
		"hits": [0.2, 0.38, 0.56, 0.74], "cancel": 0.78, "end": 0.9, "lunge": 11.0, "decay": 1.2,
		"knockback": 4.0, "launch": 0.0, "stop": 0.035, "shake": 0.16},
	# Awakened only: heavy right after L3. Huge two-handed swing that erupts all around.
	"AF": {"anim": "2H_Melee_Attack_Slice", "damage": 30.0, "range": 4.5, "arc": 360.0,
		"hits": [0.45], "cancel": 0.7, "end": 0.9, "lunge": 5.0, "knockback": 6.0, "launch": 10.0,
		"stop": 0.16, "shake": 0.7, "big": true},
}
# The named combos: landing one plays its tier's sound and shows its name
# above the hero. Moves not listed here (L1, L2, H) stay quiet. Also the
# pause menu's move list. tier: 1 string, 2 heavy route, 3 finisher.
const COMBOS := {
	"L3": {"name": "Triple Chop", "input": "L L L", "tier": 1},
	"LPL": {"name": "Flurry", "input": "L L, pause, L", "tier": 1},
	"DL": {"name": "Dash Stab", "input": "Dash > L", "tier": 1},
	"DH": {"name": "Cyclone", "input": "Dash > H", "tier": 2},
	"LH": {"name": "Launcher", "input": "L H", "tier": 2},
	"LLH": {"name": "Ground Breaker", "input": "L L H", "tier": 2},
	"CH": {"name": "Charged Slam", "input": "hold H", "tier": 2},
	"AF": {"name": "Cataclysm", "input": "L L L H (Awakened)", "tier": 3},
	"SKY": {"name": "Ancestor's Fall", "input": "L H H (Awakened)", "tier": 3},
	"RUSH": {"name": "Spirit Stampede", "input": "Dash L H (Awakened)", "tier": 3},
}
# Awakened ultimates: these combos turn into a cinematic move (AF, the
# finisher, is the third). The hero is invulnerable throughout. Each ultimate
# in the same Awakening adds ULT_CHAIN_BONUS damage to the next, and landing
# all three calls down the TRINITY storm. Names per element (spirit = no
# Ascendancy yet). Damage is before the Awakened damage multiplier.
#   SKY   leap toward a foe within `reach`, gather the element overhead, smash
#         down at `impact` (fraction of `time`) hitting everything in `radius`
#   RUSH  wind up for `go`, charge `length` ahead over `dash` hitting what's in
#         `width`, then the whole line erupts `wake` later for `wake_damage`
const ULTIMATES := {
	"SKY": {"time": 1.05, "impact": 0.62, "rise": 3.2, "reach": 6.0, "damage": 36.0, "radius": 4.8, "launch": 10.0,
		"names": {"spirit": "Ancestor's Fall", "wind": "Thunder Dive", "earth": "Meteor Fall", "water": "Frozen Comet"}},
	"RUSH": {"time": 0.85, "go": 0.16, "dash": 0.26, "length": 9.0, "width": 1.6, "damage": 26.0, "launch": 6.0,
		"wake": 0.12, "wake_damage": 12.0,
		"names": {"spirit": "Spirit Stampede", "wind": "Gale Rush", "earth": "Tectonic Charge", "water": "Tidal Surge"}},
}
const ULT_CHAIN_BONUS := 0.3
const TRINITY := {"damage": 24.0, "radius": 12.0, "delay": 0.35, "gap": 0.06,
	"names": {"spirit": "Ancestral Storm", "wind": "Skyfall", "earth": "Worldbreaker", "water": "Absolute Zero"}}
const CAST_SFX_DB := -11.0
# Names of the moves that aren't combos, for the combo guide.
const MOVE_NAMES := {"L1": "Slice", "L2": "Hurl", "H": "Spin"}
const COMBO_TIER_COLORS := [Color(0.95, 0.92, 0.85), Color(1.0, 0.75, 0.3), Color(1.0, 0.45, 0.15)]
const COMBO_TIER_SFX := ["combo_1", "combo_2", "combo_3"]
const COMBO_SFX_DB := -9.0
const LIGHT_CHAIN := ["L1", "L2", "L3"]
# Charging (hold heavy from neutral): release before CHARGE_TIME for the
# normal spin (H), after it for the charged slam (CH). You can creep while
# charging at CHARGE_MOVE_MULT speed; dash cancels the charge.
const CHARGE_TIME := 0.8
const CHARGE_MOVE_MULT := 0.35
const CHARGE_COLOR := Color(1.0, 0.85, 0.45)
const SYNERGY_COLOR := Color(0.45, 1.0, 0.85)
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
var ground_breakers := 0  # reported by the autotest
var shatters := 0  # Shatter bursts (autotest)
## Moves that count as heavy for Shatter.
const SHATTER_MOVES := ["H", "LH", "LLH", "CH", "AF", "DH"]
const SHATTER_COLOR := Color(0.92, 0.88, 0.78)
var synergies: Array = []  # active Upgrades.SYNERGIES ids, kept by add_upgrade()
var masteries: Array = []  # Upgrades.PATHS ids with their mastery on, kept by add_upgrade()
## Light-press moves, for the Light path's powers.
const LIGHT_MOVES := ["L1", "L2", "L3", "DL", "LPL"]
const RAZOR_GALE_SPREAD := 16.0  # degrees between Razor Gale's blades
var _crescendo := false  # Crescendo: the next heavy is empowered
var _slipped: Array = []  # enemies Slipstream already cut this dash
var power_procs := {}  # power id -> times it fired, for the newer powers (autotest)
var last_hit_by := ""  # who landed the latest hit ("a rogue"), for the death recap
var cataclysms := 0  # finishers landed (reported by the autotest)
var callouts := 0  # combo callouts shown (autotest)
var last_callout_tier := 0  # (autotest screenshot)
var _callout: Label3D
var _callout_tw: Tween
var _callout_done := false
var _awaken_light: OmniLight3D
## Ascendancy path (Ascendancy.PATHS key) picked at level 6, or "".
var ascendancy := ""
var element_procs := 0  # lightning strikes, magma pools, freezes (autotest)
var _wind_hits := 0
var _aura: CPUParticles3D
var _meshes: Array[Node] = []
var _awaken_rim: ShaderMaterial
var _trails: Array = []
var _orbit: Node3D
var _ult_id := ""
var _ult_from := Vector3.ZERO
var _ult_at := Vector3.ZERO
var _ult_dir := Vector3.FORWARD
var _ult_len := 0.0  # RUSH distance, cut short by walls
var _ult_hit := {}
var _ult_step_d := 0.0
var _ult_phase := 0
var _ult_fired := false
var _ult_fx_t := 0.0
var _ult_chain := 0  # ultimates so far this Awakening
var _ult_kinds: Array[String] = []
var _trinity_done := false
var ults := 0  # ultimates started (autotest)
var max_chain := 0
var ult_impacts := 0  # SKY/RUSH impacts (autotest screenshot)
var trinities := 0
var _ghost_t := 0.0
var _since_dash := 99.0
var _perfect_this_dash := false

# Lets the autotest drive the hero without real input.
var bot_move := Vector3.ZERO

## Owned combo-slot upgrades: id -> level (see upgrades.gd).
var upgrades := {}
var bot_enabled := false


func _ready() -> void:
	hp = max_hp
	Game.enemy_killed.connect(_on_enemy_killed)
	Game.leveled_up.connect(_on_level_up)
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
	HERO_LOOK.dress(model)
	Fx.outline(model)
	HERO_LOOK.add_kit(model)
	_meshes = model.find_children("*", "MeshInstance3D", true, false)
	_awaken_rim = Fx.rim_material().duplicate()
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
	_aura = CPUParticles3D.new()
	_aura.amount = 24
	_aura.lifetime = 0.8
	_aura.emitting = false
	_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_aura.emission_sphere_radius = 0.8
	_aura.direction = Vector3.UP
	_aura.spread = 25.0
	_aura.gravity = Vector3.ZERO
	_aura.initial_velocity_min = 1.2
	_aura.initial_velocity_max = 2.4
	_aura.scale_amount_min = 0.6
	_aura.scale_amount_max = 1.2
	var dot := SphereMesh.new()
	dot.radius = 0.06
	dot.height = 0.12
	_aura.mesh = dot
	var aura_mat := Ascendancy.glow_mat(Color.WHITE)
	aura_mat.vertex_color_use_as_albedo = true
	_aura.material_override = aura_mat
	_aura.position.y = 1.0
	add_child(_aura)
	add_child(_awaken_light)
	_charge_light = OmniLight3D.new()
	_charge_light.light_color = CHARGE_COLOR
	_charge_light.light_energy = 0.0
	_charge_light.omni_range = 4.0
	_charge_light.position.y = 1.0
	add_child(_charge_light)
	_callout = Label3D.new()
	_callout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_callout.no_depth_test = true
	_callout.font_size = 84
	_callout.outline_size = 24
	_callout.pixel_size = 0.006
	_callout.outline_modulate = Color(0.1, 0.05, 0.1)
	_callout.visible = false
	add_child(_callout)
	_orbit = ELEMENTS.Orbit.new()
	add_child(_orbit)
	_orbit.setup(element(), false)

	health_changed.emit(hp, max_hp)
	_play("Idle")


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	# Fx.flash clears overlays on hit; put the Awakening rim or axe runes back.
	for mi: MeshInstance3D in _meshes:
		if mi.material_overlay == null and (awakened or mi.has_meta("rest_overlay")):
			mi.material_overlay = _awaken_rim if awakened else _rest_overlay(mi)
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
		State.ULT: _state_ult(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)

	move_and_slide()
	var swinging: bool = state == State.ULT or (state == State.ATTACK and _state_t * anim_speed * _anim_mult / _move_len < _move.cancel)
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
		Game.add_awakening(-Game.AWAKEN_MAX / _awaken_len() * delta)
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
	var speed := move_speed * (1.2 * _path("speed", 1.0) if awakened else 1.0)
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
	var lunge: float = _move.lunge * maxf(0.0, 1.0 - t * _move.get("decay", 3.0))
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
		if _hits_done > 0 and has_upgrade("shockstep") and _move_id in SHATTER_MOVES:
			_shockstep(global_position)
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
		var tint := Color(Ascendancy.color(ascendancy), 0.45) if awakened else Color(0.55, 0.8, 1.0, 0.4)
		Fx.afterimage(get_parent(), model, tint)
	velocity.x = _dash_dir.x * dash_speed
	velocity.z = _dash_dir.z * dash_speed
	if has_upgrade("slipstream"):
		_slipstream()
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
	return route(kind, _move_id, state == State.ATTACK, _chain_i, _post_dash_t > 0.0, awakened)


## The move a "light" or "heavy" press starts. `from` is the move playing (or
## the last one), `attacking` whether it's still going, `chain` the light
## chain position, `post_dash` just out of a dash. The combo guide asks this
## too (with made-up states to look one press ahead), so they always agree.
static func route(kind: String, from: String, attacking: bool, chain: int, post_dash: bool, awake: bool) -> String:
	if kind == "light":
		if post_dash:
			return "DL"
		if not attacking and from == "L2" and chain == 2:
			return "LPL"  # L2 has finished: the pause turns the third light into Flurry
		return LIGHT_CHAIN[chain % LIGHT_CHAIN.size()]
	# Heavy: Cyclone out of a dash, Awakened ultimates off L3 / LH / DL,
	# launcher if mid-string, spin from neutral.
	if post_dash and not attacking:
		return "DH"
	if awake and attacking and from == "L3":
		return "AF"
	if awake and attacking and from == "LH":
		return "SKY"
	if awake and attacking and from == "DL":
		return "RUSH"
	if (attacking and from == "L2") or (not attacking and chain == 2):
		return "LLH"
	if (attacking and from != "H") or chain > 0:
		return "LH"
	return "H"


## Light chain position after `id` starts.
static func chain_after(id: String) -> int:
	if id in LIGHT_CHAIN:
		return (LIGHT_CHAIN.find(id) + 1) % LIGHT_CHAIN.size()
	if id == "DL":
		return 1  # a dash stab flows into L2
	return 0


## What the combo guide shows right now: one row per input that continues the
## string ("light", "heavy", "dash" = dash then light), each with the move it
## starts and the best named combo one more press past it. Empty when there's
## no string to continue.
func combo_options() -> Array:
	var attacking := state == State.ATTACK
	var dashing := state == State.DASH or _post_dash_t > 0.0
	var live := attacking or dashing or state == State.CHARGE or (state == State.MOVE and _chain_i > 0)
	if not live or (attacking and _move_id == "AF"):
		return []  # (the finisher has the screen to itself)
	if state == State.CHARGE:
		return [_option("heavy", "CH", true)]
	var rows := []
	for kind: String in ["light", "heavy"]:
		var id := route(kind, _move_id, attacking, _chain_i, dashing, awakened)
		if kind == "heavy" and id == "H":
			continue  # the plain spin isn't a continuation
		rows.append(_option(kind, id))
	if attacking and not dashing:
		rows.append(_option("dash", "DL"))
	return rows


func _option(kind: String, id: String, hold := false) -> Dictionary:
	var o := {"kind": kind, "id": id, "name": guide_name(id), "tier": COMBOS[id].tier if COMBOS.has(id) else 0,
		"ult": ULTIMATES.has(id) or id == "AF", "hold": hold, "next": {}}
	if o.tier < 3 and not hold:
		var best := 0
		for k: String in ["heavy", "light"]:  # heavy first: wins ties
			var n := route(k, id, true, chain_after(id), false, awakened)
			var tier: int = COMBOS[n].tier if COMBOS.has(n) and n != "CH" else 0
			if tier > best:
				best = tier
				o.next = {"kind": k, "id": n, "name": guide_name(n), "tier": tier, "ult": ULTIMATES.has(n) or n == "AF"}
	return o


func guide_name(id: String) -> String:
	return combo_name(id) if COMBOS.has(id) else MOVE_NAMES.get(id, id)


## How soon a press is taken: `progress` 0..1 toward the move's cancel point,
## `ready` once a press now would be buffered into the next move (input_buffer);
## while charging, how far the charge is and whether it's full.
func combo_window() -> Dictionary:
	if state == State.CHARGE:
		return {"progress": clampf(_state_t / CHARGE_TIME, 0.0, 1.0), "ready": _charged, "dash": _dash_cd <= 0.0}
	if state != State.ATTACK:
		return {"progress": 1.0, "ready": true, "dash": _dash_cd <= 0.0}
	var t := _state_t * anim_speed * _anim_mult / _move_len
	var left: float = (_move.cancel - t) * _move_len / (anim_speed * _anim_mult)
	return {"progress": clampf(t / _move.cancel, 0.0, 1.0), "ready": left <= input_buffer,
		"dash": _dash_cd <= 0.0 and (_hits_done > 0 or t > 0.2)}


func _start_attack(id: String) -> void:
	_buffered = ""
	if ULTIMATES.has(id):
		_start_ult(id)
		return
	_move_id = id
	_move = _effective_move(id)
	_anim_mult = _base_anim_mult()
	if id in LIGHT_MOVES and has_upgrade("quickblade"):
		_anim_mult *= 1.0 + upg("quickblade", "speed") / 100.0
	if _crescendo and id in SHATTER_MOVES:
		_crescendo = false
		_move.damage *= 1.0 + upg("crescendo", "bonus") / 100.0
		_move.knockback *= 1.5
		_proc("crescendo")
		Fx.flash(model)
		Fx.burst(get_parent(), global_position + Vector3.UP, Upgrades.PATHS.heavy.color, 16, 5.0, 0.1, 0.3, Vector3.UP, 70.0)
	_move_len = anim.get_animation(_move.anim).length
	_hits_done = 0
	_callout_done = false
	_chain_i = chain_after(id)
	_post_dash_t = 0.0
	_aim()
	_set_state(State.ATTACK)
	attack_started.emit(id)
	Game.sfx("swing_heavy" if id in ["H", "LH", "LLH", "AF", "CH", "DH"] else "swing", -3.0, 0.12)
	_play(_move.anim, 0.05, true)
	if id == "AF":
		_ult_begin(id)
		_move.damage *= _ult_mult()


func _start_dash() -> void:
	_dash_buffer_t = 0.0
	_dash_cd = dash_cooldown * (_path("dash_cd", 1.0) if awakened else 1.0) * (1.0 - _mastery("dash", "cooldown") / 100.0)
	_anim_mult = _base_anim_mult()
	_slipped.clear()
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
		if _move.has("width"):
			if not _in_strip(to, fwd, _move.range, _move.width, e.radius):
				continue
		elif d > _move.range + e.radius:
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
		if not e.is_alive() and _move_id in SHATTER_MOVES and has_upgrade("shatter") and not e.has_method("is_boss"):
			_shatter(e)
		if was_airborne and has_upgrade("chain_spark"):
			_chain_spark(e)
		if _move_id == "L1" and has_upgrade("bloodthirst"):
			heal(upg("bloodthirst", "heal"), false)
		if _move_id in LIGHT_MOVES and has_upgrade("thousand_cuts") and e.is_alive():
			_thousand_cuts(e)
		if awakened and ascendancy != "":
			_element_hit(e)
	# Slot effects that fire on the move's first active frame, hit or miss.
	if _hits_done == 1:
		_cast(fwd)
		if _move_id == "L3" and has_upgrade("ember_cleave"):
			var w := FIRE_WAVE.new()
			w.direction = fwd
			w.damage = upg("ember_cleave", "damage")
			get_parent().add_child(w)
			w.global_position = global_position + fwd * 1.0
		if _move_id in ["AF", "LLH"]:
			_combo_callout(_move_id)  # big enough to name even on a whiff
		if _move_id == "AF":
			_finisher(fwd)
			_ult_landed()
		if awakened and ascendancy == "earth" and _move_id in Ascendancy.HEAVY_MOVES and _move_id != "AF":
			element_procs += 1
			var r: float = Ascendancy.PATHS.earth.magma_radius
			Ascendancy.magma_pool(get_parent(), global_position + (Vector3.ZERO if _move.arc >= 360.0 else fwd * 1.6), r)
		if _move_id == "LLH":
			ground_breakers += 1
			_crack_line(fwd, Color(0.85, 0.75, 0.6))
			if has_upgrade("fault_line"):
				_fault_line(global_position, fwd)
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
	if _move_id == "LPL" and _hits_done == _move.hits.size() and has_upgrade("razor_gale"):
		_razor_gale(fwd)
	if _move_id == "DH" and has_upgrade("eye_of_storm"):
		_eye_of_storm()
	if hit_any:
		if _move_id == "L3" and has_upgrade("crescendo") and not _crescendo:
			_crescendo = true
			Fx.ring(get_parent(), global_position, Color(Upgrades.PATHS.heavy.color, 0.8), 1.6, 0.25)
		_combo_callout(_move_id)
		Game.sfx("hit_big" if _move.get("big", false) else "hit")
		if _move.get("big", false):
			Game.rumble("hit_big")
		Game.hitstop(_move.stop * (1.3 if any_airborne else 1.0))
		Game.shake(_move.shake)


## Names a landed combo (COMBOS) above the hero with its tier's sound, once per move.
func _combo_callout(id: String) -> void:
	if _callout_done or not COMBOS.has(id):
		return
	_callout_done = true
	var c: Dictionary = COMBOS[id]
	var tier: int = c.tier
	callouts += 1
	last_callout_tier = tier
	Game.sfx(COMBO_TIER_SFX[tier - 1], COMBO_SFX_DB, 0.03)
	_callout.text = combo_name(id)
	_callout.modulate = Ascendancy.color(ascendancy) if id == "AF" and ascendancy != "" else COMBO_TIER_COLORS[tier - 1]
	_callout.position = Vector3(0.0, 2.9, 0.0)
	_callout.scale = Vector3.ONE * 0.6
	_callout.visible = true
	if _callout_tw:
		_callout_tw.kill()
	_callout_tw = _callout.create_tween()
	_callout_tw.tween_property(_callout, "scale", Vector3.ONE * 1.15, 0.08)
	_callout_tw.tween_property(_callout, "scale", Vector3.ONE, 0.08)
	_callout_tw.parallel().tween_property(_callout, "position:y", 3.2, 0.6).set_ease(Tween.EASE_OUT)
	_callout_tw.tween_property(_callout, "modulate:a", 0.0, 0.3).set_delay(0.35)
	_callout_tw.tween_callback(_callout.hide)


# --- Elements and ultimates ---------------------------------------------------

## The hero's element: the Ascendancy path, or spirit before one.
func element() -> String:
	return ascendancy if ascendancy != "" else "spirit"


## The element cast that comes with the current move (ELEMENTS.CASTS), on its first active frame.
func _cast(fwd: Vector3) -> void:
	if not ELEMENTS.CASTS.has(_move_id):
		return
	var c: Dictionary = ELEMENTS.CASTS[_move_id]
	var el := element()
	var parent := get_parent()
	ELEMENTS.casts += 1
	Game.sfx(ELEMENTS.LOOK[el].sfx, CAST_SFX_DB, 0.1)
	match c.kind:
		"bolt":
			var n: int = c.get("fan", 1)
			for i in n:
				var b := ELEMENTS.Bolt.new()
				b.el = el
				b.dir = fwd.rotated(Vector3.UP, deg_to_rad(c.get("spread", 0.0) * (i - (n - 1) * 0.5)))
				b.speed = c.speed
				b.reach = minf(c.range, _clear_ahead(b.dir, c.range) + 0.6)  # stops at walls
				b.damage = c.damage * _dmg_mult
				b.size = c.get("size", 1.0)
				b.tilt = c.tilt
				b.on_hit = _cast_hit
				parent.add_child(b)
				b.global_position = global_position + b.dir * 0.7 + Vector3.UP * (0.25 if el == "earth" else 1.0)
		"vortex":
			ELEMENTS.vortex(self, el, c.radius, c.time)
		"pillar":
			var at := _cast_target(fwd, c.reach, c.ahead)
			ELEMENTS.pillar(parent, at, el, c.height, c.radius)
			ELEMENTS.hit_area(get_tree(), at, c.radius, c.damage * _dmg_mult, c.launch, false, "cast", _cast_hit)
		"fissure":
			ELEMENTS.fissure(parent, global_position, fwd, c.length, c.steps, el)
		"nova":
			var at := global_position + fwd * 1.6
			ELEMENTS.nova(parent, at, el, c.radius, c.count)
			ELEMENTS.hit_area(get_tree(), at, c.radius, c.damage * _dmg_mult, 6.0, true, "cast", _cast_hit)


## Element casts and ultimates hitting `e`: the Awakened path passive applies.
func _cast_hit(e: Node) -> void:
	if awakened and ascendancy != "":
		_element_hit(e)


## Ground point for a targeted cast: the nearest foe roughly ahead within `reach`, else `ahead` m in front.
func _cast_target(fwd: Vector3, reach: float, ahead: float) -> Vector3:
	var best: Node3D = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and (d < 0.5 or rad_to_deg(fwd.angle_to(to / d)) < 50.0):
			best_d = d
			best = e
	var at := best.global_position if best else global_position + fwd * ahead
	return Vector3(at.x, 0.0, at.z)


func _ult_mult() -> float:
	return 1.0 + ULT_CHAIN_BONUS * maxi(_ult_chain - 1, 0)


## An ultimate starts: chain count, banner, slow-mo, camera punch, light.
func _ult_begin(id: String) -> void:
	_ult_chain += 1
	if id not in _ult_kinds:
		_ult_kinds.append(id)
	ults += 1
	max_chain = maxi(max_chain, _ult_chain)
	_callout_done = true  # the banner names it
	var c: Color = ELEMENTS.color(element())
	if id == "AF":
		c = Ascendancy.color(ascendancy) if ascendancy != "" else COMBO_TIER_COLORS[2]
	Game.ultimate.emit(combo_name(id), c, _ult_chain)
	Game.sfx("ult", -3.0, 0.0)
	Game.hitstop(0.16, 0.2)
	Game.rumble("awaken")
	if Game.camera_rig:
		Game.camera_rig.punch(0.78, 0.6)
	Fx.flash(model)
	ELEMENTS.light_pop(get_parent(), global_position, c, 6.0, 7.0, 0.5)
	ELEMENTS.gather(get_parent(), global_position + Vector3.UP, c, 3.5, 40)


## An ultimate hit home; once all three have landed this Awakening, the Trinity follows.
func _ult_landed() -> void:
	if _ult_kinds.size() >= ULTIMATES.size() + 1 and not _trinity_done:
		_trinity_done = true
		_trinity()


func _start_ult(id: String) -> void:
	_ult_id = id
	_move_id = id
	_ult_fired = false
	_ult_hit.clear()
	_ult_step_d = 0.0
	_ult_phase = 0
	_ult_fx_t = 0.0
	_chain_i = 0
	_post_dash_t = 0.0
	_aim()
	_ult_dir = _facing()
	_ult_from = global_position
	if id == "SKY":
		_ult_at = _cast_target(_ult_dir, ULTIMATES.SKY.reach, 3.0)
	if id == "RUSH":
		_ult_len = _clear_ahead(_ult_dir, ULTIMATES.RUSH.length)
	_set_state(State.ULT)
	_ult_begin(id)
	attack_started.emit(id)
	_play("Jump_Start" if id == "SKY" else "Spellcasting", 0.05, true)


func _state_ult(delta: float) -> void:
	var u: Dictionary = ULTIMATES[_ult_id]
	var t := _state_t
	var el := element()
	var c := ELEMENTS.color(el)
	_invuln_t = maxf(_invuln_t, 0.15)
	_ghost_t -= delta
	if _ghost_t <= 0.0 and (_ult_id == "RUSH" or t < u.time * u.get("impact", 1.0)):
		_ghost_t = afterimage_interval * 1.5
		Fx.afterimage(get_parent(), model, Color(c, 0.4))
	if _ult_id == "SKY":
		_state_sky(u, t, el, c, delta)
	else:
		_state_rush(u, t, el, delta)
	if t >= u.time:
		_end_ult()


## SKY: leap toward the target, gather the element overhead, smash down.
func _state_sky(u: Dictionary, t: float, el: String, c: Color, delta: float) -> void:
	var hit_t: float = u.time * u.impact
	var k := clampf(t / hit_t, 0.0, 1.0)
	var to := _ult_at - _ult_from
	to.y = 0.0
	velocity.x = to.x / hit_t if k < 1.0 else 0.0
	velocity.z = to.z / hit_t if k < 1.0 else 0.0
	_face(to)
	var rise: float = u.rise
	model.position.y = rise * (1.0 - pow(1.0 - k / 0.7, 3.0)) if k < 0.7 else rise * (1.0 - pow((k - 0.7) / 0.3, 2.0))
	if k >= 0.3 and _ult_phase == 0:
		_ult_phase = 1
		_play("Spellcast_Raise", 0.08, true)
		if el == "earth":
			ELEMENTS.meteor(get_parent(), _ult_at, hit_t * 0.7)
	if _ult_phase == 1:
		_ult_fx_t -= delta
		if _ult_fx_t <= 0.0:
			_ult_fx_t = 0.1
			ELEMENTS.gather(get_parent(), global_position + Vector3.UP * (model.position.y + 2.4), c, 2.2, 14)
	if k >= 0.72 and _ult_phase == 1:
		_ult_phase = 2
		_play("2H_Melee_Attack_Chop", 0.04, true)
		anim.seek(anim.current_animation_length * 0.25, true)
	if k >= 1.0 and not _ult_fired:
		_ult_fired = true
		model.position.y = 0.0
		var at := Vector3(global_position.x, 0.0, global_position.z)
		ELEMENTS.sky_impact(get_parent(), at, el, u.radius)
		var water: Dictionary = Ascendancy.PATHS.water
		ELEMENTS.hit_area(get_tree(), at, u.radius, u.damage * _dmg_mult * _ult_mult(), u.launch, true, "ult",
			func(e: Node) -> void:
				_cast_hit(e)
				if el == "water" and e.is_alive() and not e.has_method("is_boss"):
					e.freeze(water.glacier_freeze, water.shatter_mult))
		_ult_impact()


## RUSH: wind up, charge through everything ahead, then the line erupts.
func _state_rush(u: Dictionary, t: float, el: String, delta: float) -> void:
	var go: float = u.go
	var dash_end: float = go + u.dash
	_face(_ult_dir)
	if t < go:
		velocity.x = 0.0
		velocity.z = 0.0
	elif t < dash_end:
		if _ult_phase == 0:
			_ult_phase = 1
			_play("Dodge_Forward", 0.03, true)
			Game.sfx("dash", 0.0, 0.0)
			if el == "water":
				ELEMENTS.wave_wall(model, u.dash + 0.25)
		var spd: float = _ult_len / u.dash
		velocity.x = _ult_dir.x * spd
		velocity.z = _ult_dir.z * spd
		_ult_step_d += spd * delta
		if _ult_step_d >= 1.2:
			_ult_step_d = 0.0
			ELEMENTS.rush_step(get_parent(), global_position, _ult_dir, el)
		for e in Ascendancy.enemies_near(get_tree(), global_position, u.width):
			if _ult_hit.has(e):
				continue
			_ult_hit[e] = true
			var side: Vector3 = e.global_position - global_position
			side.y = 0.0
			side = (side - _ult_dir * side.dot(_ult_dir)).normalized()
			e.take_hit(u.damage * _dmg_mult * _ult_mult(), side * 6.0 + _ult_dir * 3.0, u.launch, true)
			Game.register_hit("ult")
			_cast_hit(e)
			Game.hitstop(0.03)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 80.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 80.0 * delta)
		if _ult_phase == 1:
			_ult_phase = 2
			_play("2H_Melee_Attack_Slice", 0.04, true)
			anim.seek(anim.current_animation_length * 0.3, true)
		if not _ult_fired and t >= dash_end + u.wake:
			_ult_fired = true
			var line := global_position - _ult_from
			line.y = 0.0
			var length := maxf(line.length(), 2.0)
			ELEMENTS.rush_wake(get_parent(), _ult_from, _ult_dir, length, el)
			for e in get_tree().get_nodes_in_group("enemies"):
				var to: Vector3 = e.global_position - _ult_from
				to.y = 0.0
				if e.is_alive() and _in_strip(to, _ult_dir, length, u.width, e.radius):
					e.take_hit(u.wake_damage * _dmg_mult * _ult_mult(), Vector3.UP, 7.0, true)
					Game.register_hit("ult")
					_cast_hit(e)
			_ult_impact()


## How far the hero can travel along `dir` (up to `length`) before a wall.
func _clear_ahead(dir: Vector3, length: float) -> float:
	var from := global_position + Vector3.UP * 0.9
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (length + 0.6), collision_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return length
	return maxf(from.distance_to(hit.position) - 0.6, 0.0)


## A SKY or RUSH impact: the big hit juice.
func _ult_impact() -> void:
	ult_impacts += 1
	Game.sfx("ult_impact", 0.0, 0.05)
	Game.hitstop(0.12)
	Game.shake(0.9)
	Game.rumble("hit_big")
	_ult_landed()


func _end_ult() -> void:
	model.position.y = 0.0
	_buffered = ""
	_chain_reset_t = 0.0
	_ghost_t = 0.0
	_set_state(State.MOVE)


## All three ultimates in one Awakening: a strike of the element on every foe around.
func _trinity() -> void:
	trinities += 1
	var el := element()
	var c := ELEMENTS.color(el)
	var parent := get_parent()
	await get_tree().create_timer(TRINITY.delay, false).timeout
	if not is_inside_tree():
		return
	Game.ultimate.emit(TRINITY.names[el], c, 0)
	Game.sfx("ult", 0.0, 0.0)
	Game.hitstop(0.25, 0.15)
	Game.shake(1.0)
	if Game.camera_rig:
		Game.camera_rig.punch(1.15, 0.8)
	ELEMENTS.light_pop(parent, global_position, c, 12.0, 20.0, 0.8)
	Fx.ring(parent, global_position, Color(c, 0.95), TRINITY.radius, 0.6)
	var targets := Ascendancy.enemies_near(get_tree(), global_position, TRINITY.radius)
	if targets.is_empty():
		for i in 6:
			var ang := TAU * i / 6.0
			ELEMENTS.storm_strike(parent, global_position + Vector3(sin(ang), 0.0, cos(ang)) * 4.0, el)
	for e in targets:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		ELEMENTS.storm_strike(parent, e.global_position, el)
		e.take_hit(TRINITY.damage * _dmg_mult, Vector3.ZERO, 6.0, true)
		Game.register_hit("trinity")
		_cast_hit(e)
		await get_tree().create_timer(TRINITY.gap, false).timeout
		if not is_inside_tree():
			return


# --- Upgrades ---------------------------------------------------------------

func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


## Current level's tuning number `key` for owned upgrade `id` (upgrades.gd
## lv), boosted by any active synergy (Upgrades.SYNERGIES).
func upg(id: String, key: String) -> float:
	return Upgrades.value(id, key, upgrades.get(id, 1)) * Upgrades.boost(synergies, id, key)


## A synergy switched on: chime, a teal ring and sparks around the hero.
func _synergy_burst() -> void:
	Game.sfx("synergy", -2.0, 0.0)
	Fx.flash(model)
	Fx.ring(get_parent(), global_position, Color(SYNERGY_COLOR, 0.9), 3.0, 0.5)
	Fx.burst(get_parent(), global_position + Vector3.UP, SYNERGY_COLOR, 24, 5.0, 0.12, 0.6, Vector3.UP, 60.0, -4.0)


## Lose upgrade `id` entirely (shrine melt).
func remove_upgrade(id: String) -> void:
	upgrades.erase(id)
	synergies = Upgrades.active_synergies(upgrades)
	_refresh_masteries()


## Recompute the path masteries (Upgrades.PATHS): announce new ones and keep
## the Soul mastery's max HP in step.
func _refresh_masteries() -> void:
	var before := masteries
	masteries = Upgrades.masteries(upgrades)
	var hp_bonus: float = Upgrades.PATHS.soul.mastery.hp
	if "soul" in masteries and "soul" not in before:
		max_hp += hp_bonus
		heal(hp_bonus, false)
	elif "soul" in before and "soul" not in masteries:
		max_hp -= hp_bonus
		hp = minf(hp, max_hp)
	health_changed.emit(hp, max_hp)
	for path: String in masteries:
		if path not in before:
			Game.announced.emit("%s MASTERY" % Upgrades.PATHS[path].name.to_upper())
			Game.sfx("synergy", -2.0, 0.0)
			var c: Color = Upgrades.PATHS[path].color
			Fx.ring(get_parent(), global_position, Color(c, 0.9), 3.2, 0.5)
			Fx.burst(get_parent(), global_position + Vector3.UP, c, 24, 5.0, 0.12, 0.6, Vector3.UP, 60.0, -4.0)


## Mastery number `key` of `path` while that mastery is on, else 0.
func _mastery(path: String, key: String) -> float:
	return Upgrades.PATHS[path].mastery[key] if path in masteries else 0.0


## How long an Awakening lasts, with the Awaken mastery.
func _awaken_len() -> float:
	return awaken_duration + _mastery("awaken", "time")


## Animation speed before per-move boosts (Awakening is faster).
func _base_anim_mult() -> float:
	return 1.3 if awakened else 1.0


func _proc(id: String) -> void:
	power_procs[id] = power_procs.get(id, 0) + 1


## Gain an upgrade, or level it up if it's already owned (up to MAX_LEVEL).
func add_upgrade(id: String) -> void:
	upgrades[id] = mini(upgrades.get(id, 0) + 1, Upgrades.MAX_LEVEL)
	var before := synergies
	synergies = Upgrades.active_synergies(upgrades)
	for tag: String in synergies:
		if tag not in before:
			Game.announced.emit("%s SYNERGY" % Upgrades.SYNERGIES[tag].name.to_upper())
			_synergy_burst()
	if id == "overflow":
		Game.awakening_gain_mult = 1.0 + upg(id, "bonus") / 100.0
	_refresh_masteries()


func _on_level_up(level: int) -> void:
	max_hp += level_hp
	heal(level_hp, false)
	health_changed.emit(hp, max_hp)
	Game.announced.emit("LEVEL %d" % level)
	Game.sfx("wave_clear", -6.0, 0.0)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.85, 0.4, 0.9), 2.5, 0.4)
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.4, Color(1.0, 0.85, 0.4), 18, 5.0, 0.1, 0.5, Vector3.UP, 30.0)


func _on_enemy_killed(_e: Node) -> void:
	if has_upgrade("reaper") and state != State.DEAD:
		heal(upg("reaper", "heal"), false)
		Game.add_awakening(upg("reaper", "awaken"))
	if has_upgrade("undying_flame") and awakened and state != State.DEAD:
		# The meter drains in step with _awaken_t, so refill both.
		_awaken_t = minf(_awaken_t + upg("undying_flame", "time"), _awaken_len())
		Game.awakening = Game.AWAKEN_MAX * _awaken_t / _awaken_len()
		Game.awakening_changed.emit(Game.awakening)
		heal(upg("undying_flame", "heal"), false)
		_proc("undying_flame")
		Fx.burst(get_parent(), global_position + Vector3.UP, Upgrades.PATHS.awaken.color, 10, 4.0, 0.1, 0.4, Vector3.UP, 60.0)


## True if offset `to` (flat) lies in the strip `length` ahead along `fwd`.
static func _in_strip(to: Vector3, fwd: Vector3, length: float, half_width: float, pad: float) -> bool:
	var ahead := to.dot(fwd)
	var side := (to - fwd * ahead).length()
	return ahead > -0.5 and ahead <= length + pad and side <= half_width + pad


## Dust bursts along the Ground Breaker's strip.
## Shatter: the slain foe bursts into bone shards that hit everyone close by
## (shard kills don't shatter again).
func _shatter(dead: Node3D) -> void:
	shatters += 1
	var at := dead.global_position
	var r: float = upg("shatter", "radius")
	Fx.burst(get_parent(), at + Vector3.UP * 0.7, SHATTER_COLOR, 26, 9.0, 0.12, 0.35, Vector3.UP, 160.0)
	Fx.ring(get_parent(), at, Color(SHATTER_COLOR, 0.8), r, 0.3)
	Game.sfx("enemy_death", 0.0, 0.15)
	Game.shake(0.25)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == dead or not e.is_alive():
			continue
		var to: Vector3 = e.global_position - at
		to.y = 0.0
		if to.length() <= r + e.radius:
			e.take_hit(upg("shatter", "damage"), to.normalized() * 6.0, 3.0, false)
			Game.register_hit("shatter")


func _crack_line(fwd: Vector3, color: Color, from := Vector3.INF) -> void:
	var start := global_position if from == Vector3.INF else from
	var length: float = MOVES.LLH.range
	for i in 5:
		var at := start + fwd * (1.0 + i * (length - 1.0) / 4.0)
		Fx.dust(get_parent(), at, 6, 0.7)
		Fx.burst(get_parent(), at + Vector3.UP * 0.1, color, 5, 4.0, 0.08, 0.25, Vector3.UP, 40.0)


## Fault Line: the strip erupts again a moment later, launching what's on it.
func _fault_line(origin: Vector3, fwd: Vector3) -> void:
	var delay: float = upg("fault_line", "delay")
	var glow := _fault_glow(origin, fwd)
	glow.create_tween().tween_property(glow.mesh.material, "albedo_color:a", 0.75, delay)
	await get_tree().create_timer(delay, false).timeout
	var mat: StandardMaterial3D = glow.mesh.material
	mat.albedo_color.a = 0.95
	var tw := glow.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(glow.queue_free)
	_crack_line(fwd, Color(1.0, 0.55, 0.2), origin)
	Game.shake(0.3)
	Game.sfx("hit_big", -6.0, 0.1)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - origin
		to.y = 0.0
		if e.is_alive() and _in_strip(to, fwd, MOVES.LLH.range, MOVES.LLH.width, e.radius):
			e.take_hit(upg("fault_line", "damage"), fwd * 3.0, 7.0, true)
			Game.register_hit("fault_line")


## Glowing crack along the Ground Breaker's strip; it brightens until the
## Fault Line erupts, so the eruption reads as a telegraph.
func _fault_glow(origin: Vector3, fwd: Vector3) -> MeshInstance3D:
	var length: float = MOVES.LLH.range
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(MOVES.LLH.width * 1.2, 0.02, length)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.35)
	mesh.material = mat
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(m)
	m.global_position = origin + fwd * (length * 0.5 + 0.5) + Vector3.UP * 0.06
	m.rotation.y = atan2(fwd.x, fwd.z)
	return m


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
	if id in LIGHT_CHAIN:
		m.damage *= 1.0 + _mastery("light", "damage") / 100.0
	if id in SHATTER_MOVES:
		m.damage *= 1.0 + _mastery("heavy", "damage") / 100.0
	if id == "DL":
		m.damage *= 1.0 + _mastery("dash", "damage") / 100.0
	if id in LIGHT_MOVES and has_upgrade("flicker") and _since_dash <= upg("flicker", "time"):
		m.damage *= 1.0 + upg("flicker", "bonus") / 100.0
		_proc("flicker")
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


## Thousand Cuts: count light hits per foe; every `hits`th one rends it.
func _thousand_cuts(e: Node3D) -> void:
	var n: int = e.get_meta("cuts", 0) + 1
	if n < int(upg("thousand_cuts", "hits")):
		e.set_meta("cuts", n)
		return
	e.set_meta("cuts", 0)
	_proc("thousand_cuts")
	var c: Color = Upgrades.PATHS.light.color
	Fx.burst(get_parent(), e.global_position + Vector3.UP * 0.9, c, 18, 7.0, 0.1, 0.25, Vector3.UP, 180.0)
	Fx.ring(get_parent(), e.global_position, Color(c, 0.8), 1.2, 0.2)
	e.take_hit(upg("thousand_cuts", "damage"), Vector3.ZERO, 0.0, false)
	Game.register_hit("thousand_cuts")


## Slipstream: cut each enemy the dash passes through, once per dash.
func _slipstream() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive() or e in _slipped:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() <= 0.9 + e.radius:
			_slipped.append(e)
			_proc("slipstream")
			var c: Color = Upgrades.PATHS.dash.color
			Fx.burst(get_parent(), e.global_position + Vector3.UP * 0.9, c, 12, 6.0, 0.1, 0.25, _dash_dir, 60.0)
			e.take_hit(upg("slipstream", "damage"), _dash_dir * 3.0, 0.0, false)
			Game.register_hit("slipstream")


## Shockstep: a heavy dash-cancel leaves a launching shockwave behind.
func _shockstep(pos: Vector3) -> void:
	_proc("shockstep")
	var r := upg("shockstep", "radius")
	Fx.ring(get_parent(), pos, Color(Upgrades.PATHS.heavy.color, 0.9), r, 0.35)
	Fx.ring(get_parent(), pos, Color(Upgrades.PATHS.dash.color, 0.8), r * 0.6, 0.25)
	Fx.dust(get_parent(), pos, 12, 0.9)
	Game.shake(0.2)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - pos
		to.y = 0.0
		if e.is_alive() and to.length() < r + e.radius:
			e.take_hit(upg("shockstep", "damage"), to.normalized() * 4.0, 7.0, true)
			Game.register_hit("shockstep")


## Razor Gale: Flurry's last cut flings a fan of the element's blades.
func _razor_gale(fwd: Vector3) -> void:
	_proc("razor_gale")
	var n := int(upg("razor_gale", "count"))
	var el := element()
	for i in n:
		var b := ELEMENTS.Bolt.new()
		b.el = el
		b.dir = fwd.rotated(Vector3.UP, deg_to_rad(RAZOR_GALE_SPREAD * (i - (n - 1) * 0.5)))
		b.speed = 24.0
		b.reach = minf(8.0, _clear_ahead(b.dir, 8.0) + 0.6)
		b.damage = upg("razor_gale", "damage") * _dmg_mult
		b.size = 0.8
		b.tilt = 70.0 if i % 2 == 0 else -70.0
		b.on_hit = _cast_hit
		get_parent().add_child(b)
		b.global_position = global_position + b.dir * 0.7 + Vector3.UP * (0.25 if el == "earth" else 1.0)


## Eye of the Storm: each Cyclone hit drags foes around it into the spin
## (not the boss).
func _eye_of_storm() -> void:
	_proc("eye_of_storm")
	var r := upg("eye_of_storm", "radius")
	Fx.ring(get_parent(), global_position, Color(Upgrades.PATHS.dash.color, 0.5), r, 0.2)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if e.is_alive() and d > _move.range * 0.6 and d < r + e.radius and not e.has_method("is_boss"):
			e.take_hit(upg("eye_of_storm", "damage"), -to / d * minf(d * 2.5, 9.0), 0.0, false)
			Game.register_hit("eye_of_storm")


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
	var r := upg("eruption", "radius") if has_upgrade("eruption") else 7.0
	Fx.ring(get_parent(), global_position, Color(1.0, 0.55, 0.15, 0.9), r, 0.45)
	if has_upgrade("eruption"):
		_proc("eruption")
		Fx.ring(get_parent(), global_position, Color(Upgrades.PATHS.awaken.color, 0.9), r * 0.7, 0.35)
		Fx.burst(get_parent(), global_position + Vector3.UP * 0.3, Upgrades.PATHS.awaken.color, 40, 10.0, 0.18, 0.5, Vector3.UP, 160.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < r:
			e.take_hit(upg("eruption", "damage") if has_upgrade("eruption") else 10.0, to.normalized() * 12.0, 5.0, true)


## The overlay a mesh wears when not Awakened (HERO_LOOK's axe runes), or null.
func _rest_overlay(mi: MeshInstance3D) -> Material:
	return mi.get_meta("rest_overlay") if mi.has_meta("rest_overlay") else null


## A tuning number of the chosen Ascendancy path, or `fallback` without one.
func _path(key: String, fallback: float) -> float:
	return Ascendancy.PATHS[ascendancy].get(key, fallback) if ascendancy != "" else fallback


## COMBOS name, with the finisher renamed by the Ascendancy path.
func combo_name(id: String) -> String:
	if ULTIMATES.has(id):
		return ULTIMATES[id].names[element()]
	if id == "AF" and ascendancy != "":
		return Ascendancy.PATHS[ascendancy].finisher
	return COMBOS[id].name


func ascend(path: String) -> void:
	ascendancy = path
	Game.announced.emit(Ascendancy.PATHS[path].title)
	Game.sfx("synergy", 0.0, 0.0)
	var c := Ascendancy.color(path)
	Fx.ring(get_parent(), global_position, Color(c, 0.95), 5.0, 0.5)
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.6, c, 40, 9.0, 0.15, 0.6, Vector3.UP, 60.0)
	_orbit.setup(element(), awakened)
	if awakened:
		_set_awakened(true)


## Awakened per-hit element effect (Wind lightning, Water chill).
func _element_hit(e: Node) -> void:
	match ascendancy:
		"wind":
			_wind_hits += 1
			var w: Dictionary = Ascendancy.PATHS.wind
			if _wind_hits % int(w.strike_every) == 0:
				element_procs += 1
				Ascendancy.lightning(get_parent(), Vector3(e.global_position.x, 0.0, e.global_position.z),
					w.strike_damage, w.strike_radius, "lightning")
		"water":
			if e.is_alive():
				var was: int = e.chill_hits
				Ascendancy.chill_hit(e)
				if e.chill_hits < was:
					element_procs += 1


## The Awakened L L L H finisher: Cataclysm, or the Ascendancy's own.
func _finisher(fwd: Vector3) -> void:
	match ascendancy:
		"wind":
			cataclysms += 1
			var t := Ascendancy.Tempest.new()
			get_parent().add_child(t)
			t.global_position = Vector3(global_position.x, 0.0, global_position.z) + fwd * 2.0
			Game.sfx("awaken", -4.0, 0.1)
		"earth":
			cataclysms += 1
			var v := Ascendancy.Volcano.new()
			get_parent().add_child(v)
			v.global_position = Vector3(global_position.x, 0.0, global_position.z) + fwd * 2.5
			Game.sfx("awaken", -4.0, 0.1)
		"water":
			cataclysms += 1
			Ascendancy.glacier(get_parent(), Vector3(global_position.x, 0.0, global_position.z))
		_:
			_cataclysm()


func _set_awakened(on: bool) -> void:
	awakened = on
	Game.awaken_locked = on
	if not on:
		Game.add_awakening(-Game.AWAKEN_MAX)  # always starts over from empty
	_awaken_t = _awaken_len()
	_anim_mult = 1.3 if on else 1.0
	_dmg_mult = 1.6 if on else 1.0
	var tw := create_tween().set_parallel()
	tw.tween_property(model, "scale", Vector3.ONE * (1.18 if on else 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_awaken_light, "light_energy", 3.0 if on else 0.0, 0.2)
	var c := Ascendancy.color(ascendancy)
	_awaken_light.light_color = c
	_awaken_rim.set_shader_parameter("glow_color", c)
	for mi: MeshInstance3D in _meshes:
		mi.material_overlay = _awaken_rim if on else _rest_overlay(mi)
	for trail in _trails:
		trail.color = Color(c, 0.9) if on else Color(1.0, 0.95, 0.8, 0.8)
	_aura.color = c
	_aura.emitting = on and ascendancy != ""
	_orbit.setup(element(), on)
	if on:
		_ult_chain = 0
		_ult_kinds.clear()
		_trinity_done = false
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


## "a spike trap" (no attacker), "the Bone Warden", "an elite skeleton
## archer"... (titles come from main.ENEMY_TYPES).
static func _describe_attacker(attacker: Node) -> String:
	if attacker == null:
		return "a spike trap"
	if attacker.has_method("is_boss"):
		return "the Bone Warden"
	var kind: String = ("elite " if attacker.elite else "") + attacker.get_meta("title", "skeleton")
	return ("an " if kind[0] in "aeiou" else "a ") + kind


## `cause` names hazards for the death recap ("the Bone Warden's cage");
## otherwise the attacker is described.
func take_hit(damage: float, knockback: Vector3, attacker: Node = null, cause := "") -> void:
	if state == State.DEAD:
		return
	if _invuln_t > 0.0:
		if _since_dash <= perfect_dodge_window and not _perfect_this_dash:
			_perfect_dodge(attacker)
		return
	hp = maxf(hp - damage * (_path("armor", 0.6) if awakened else 1.0), 0.0)
	last_hit_by = cause if cause != "" else _describe_attacker(attacker)
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
