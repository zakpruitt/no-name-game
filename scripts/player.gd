extends CharacterBody3D
## The heretic: the node, its state machine and everything other scripts call on him. MOVE / ATTACK /
## DASH / HURT / CHARGE / DEAD run here; State.LEAP is hero_leap.gd and State.SWING is void_grab.gd.
## The work is split by job, each file static functions over the state declared here (the pattern of
## void_element.gd), so the checks, the bot and void_grab.gd keep reading the hero's fields directly:
##   hero_moves.gd   MOVES / COMBOS, routing (void_route), hops, air string, plunge, the guide's rows
##   hero_input.gd   the press buffer, cancel points and hit-confirm, the dash cancel rule, aim
##   hero_leap.gd    combo breakers: the leap, window, press, dive and impact (VOID_ELEMENT.BREAKERS)
##   hero_awaken.gd  Awakening: activation burst, the buff, the drain
##   hero_fx.gd      the swoosh, spirit casts, the combo callout, ender camera, rank-up and last-kill bursts
## Other scripts and the checks call the hero_*.gd functions directly (HERO_INPUT.cancel_point(hero), ...);
## player.gd keeps the state machine, the hit, take_hit and the few methods duck-typed callers use.

signal health_changed(hp: float, max_hp: float)
signal awakened_changed(active: bool)
signal died
## Fired when any attack begins (enemies that dodge listen for this).
signal attack_started(move_id: String)
signal combo_found(id: String)  # a named combo landed for the first time this run

enum State { MOVE, ATTACK, DASH, HURT, CHARGE, DEAD, LEAP, SWING }

const HERO_MOVES := preload("res://scripts/hero_moves.gd")
const HERO_INPUT := preload("res://scripts/hero_input.gd")
const HERO_LEAP := preload("res://scripts/hero_leap.gd")
const HERO_AWAKEN := preload("res://scripts/hero_awaken.gd")
const HERO_FX := preload("res://scripts/hero_fx.gd")
const COUNTER := preload("res://scripts/counter.gd")  # the dash counter, Backlash (docs/features/counter.md)
const VOID_ELEMENT := preload("res://scripts/void_element.gd")
const VOID_GRAB := preload("res://scripts/void_grab.gd")
const VOID_ARM := preload("res://scripts/void_arm.gd")
const HERETIC_RIG := preload("res://scripts/heretic_rig.gd")
const ELEMENTS := preload("res://scripts/elements.gd")
const TRAIL := preload("res://scripts/weapon_trail.gd")

# Names other scripts and the checks read off the hero; the data lives in the hero_*.gd files.
const MOVES := HERO_MOVES.MOVES
const COMBOS := HERO_MOVES.COMBOS
const GUIDE_LEARNED := HERO_MOVES.GUIDE_LEARNED
const BUFFER_MS := HERO_INPUT.BUFFER_MS
const BREAKER_SPILL := HERO_LEAP.BREAKER_SPILL
const BREAKER_EARLY := HERO_LEAP.BREAKER_EARLY
const COMBO_TIER_COLORS := HERO_FX.COMBO_TIER_COLORS
const COMBO_TIER_SFX := HERO_FX.COMBO_TIER_SFX  # (hero_leap reads these off the hero)
const COMBO_SFX_DB := HERO_FX.COMBO_SFX_DB

const LOOPING := ["Idle", "Running_A", "2H_Melee_Idle", "Run_F", "Run_B", "Strafe_L", "Strafe_R", "Idle_Ready"]
const LOOP_SPEED := 1.1  # loops, fidgets and the run one-shots (_loop_speed)
## Runs play this much faster while Awakened (he moves HERO_AWAKEN.SPEED_MULT faster), so his feet stay
## locked to the floor (tests/hero_stride_check.gd).
const AWAKENED_RUN_CLIP := HERO_AWAKEN.SPEED_MULT
## The lunge setting off from slower than RUN_START_BELOW of move_speed, the skid letting go above
## RUN_STOP_ABOVE (_play_locomotion): one of each per run clip (RUN_SUFFIX), and each skid again ending
## on the guard (`_Ready`) while he is still on guard after a fight (_ready_t).
const RUN_SUFFIX := {"Run_F": "", "Run_B": "_B", "Strafe_L": "_L", "Strafe_R": "_R"}
const RUN_ONESHOTS := ["Run_Start", "Run_Start_B", "Run_Start_L", "Run_Start_R", "Run_Stop", "Run_Stop_B",
	"Run_Stop_L", "Run_Stop_R", "Run_Stop_Ready", "Run_Stop_B_Ready", "Run_Stop_L_Ready", "Run_Stop_R_Ready"]
const RUN_START_BELOW := 0.3
const RUN_STOP_ABOVE := 0.6
const ENDER_HITSTOP := 0.025  # extra hitstop per tier when a named combo's ender lands
const PULL_INVULN := 0.8  # s, on the tentacle (void_grab.gd)
const SWING_COOLDOWN := 1.5  # s between presses of R
const FLING_ACCEL_MULT := 0.2  # how much grip he has flying off a swing
# Charging (hold right click from neutral): release before CHARGE_TIME for the
# grab (GR), after it for Overwhelm (OW). He can creep while charging at
# CHARGE_MOVE_MULT speed; dash cancels the charge.
const CHARGE_TIME := 0.8
const CHARGE_MOVE_MULT := 0.35
const CHARGE_COLOR := Color(1.0, 0.85, 0.45)

@export var move_speed := 7.5
@export var accel := 70.0
@export var dash_speed := 24.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.3
@export var max_hp := 100.0
@export var anim_speed := 1.7
## s a press is remembered (BUFFER_MS).
@export var input_buffer := BUFFER_MS / 1000.0
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

var hp := max_hp
var state := State.MOVE
var awakened := false
var model: Node3D
var anim: AnimationPlayer
var _state_t := 0.0
var _facing_yaw := 0.0
var _invuln_t := 0.0
var _anim_mult := 1.0
var _dmg_mult := 1.0

# The move playing (hero_moves.gd).
var _move_id := ""
var _move: Dictionary = {}
var _move_len := 1.0
var _hits_done := 0
var _connected := false  # the current move has hit something (combo breakers need it)
var _hop_y0 := 0.0  # model height the current move started at (MOVES `hop`)
var _hop_air := false  # off the ground this move (for the landing dust)
var _hop_peak := 0.0  # highest the model got this time up (scales the landing slam)
var _chain_i := 0
var _chain_reset_t := 0.0

# Presses and aim (hero_input.gd).
var _buffered := ""
var _buffer_t := 0.0
var _dash_buffer_t := 0.0
var _swing_buffer_t := 0.0  # s left on a press of R
var _aim_lock: Node3D  # the foe the current move turned onto (AIM_LOCK_BREAK)
var _mouse_active := true  # false once a gamepad is the last thing touched

# Dash, swing and charge.
var _dash_cd := 0.0
var _dash_dir := Vector3.FORWARD
var _dash_from := Vector3.ZERO  # where his last dash or swing began (void_element._tow)
var _dash_out := false  # this dash cancelled a move (a buffered light ends it early: HERO_MOVES.DASH_STAB_CANCEL)
var _post_dash_t := 0.0
var _air_dash := false  # this dash started up in the air string (AIR_DASH_*)
var _air_dashes := 0  # air dashes since he last touched the floor (AIR_DASHES)
var _ghost_t := 0.0
var _since_dash := 99.0
var _perfect_this_dash := false
var _counter := {}  # this dash turned into Backlash, the dash counter (counter.gd), while set
var counters := 0  # counters landed (autotest `[counter]`, counter_check)
var counter_perfects := 0
var _swing_cd := 0.0  # s until R swings again
var _fling_t := 0.0  # s left flying off a swing
var _charged := false
var _charge_fx_t := 0.0
var _charge_light: OmniLight3D

# The look: trails, callouts, stance, Awakening (hero_awaken.gd).
var _coats: Array[Node3D] = []  # ComicLook.infuse_axes for the current element
var _trails: Array = []
var _swoosh_flip := false  # alternate swing direction each swoosh
var _callout: Label3D
var _callout_tw: Tween
var _callout_done := false
var _orbit: Node3D
var _ready_t := 0.0  # s left in the guard after a fight
var _fidget_t: float = ComicLook.FIDGET_EVERY  # s until he next fidgets
var _fidget_i := 0
var _awaken_t := 0.0
var _awaken_light: OmniLight3D
var _meshes: Array[Node] = []
var _awaken_rim: ShaderMaterial
var _rank_i := 0  # current style rank as a step above D (Game.RANKS)

var _void: Node  # his tentacle: grab, slam, swing, breaker holds (void_grab.gd)

# The breaker in play (hero_leap.gd).
var _brk: Dictionary = {}  # its BREAKERS entry
var _brk_id := ""
var _brk_phase := 0  # 0 rising / hanging, 1 diving, 2 falling (missed)
var _brk_press := -1.0  # s after take-off it was pressed (-1 none)
var _brk_locked := false
var _brk_held := false  # pressed just before `open`: dives as the window opens (BREAKER_EARLY)
var _brk_alt := false  # the window's press was the other button: `alt` (void_element.BREAKERS)
var _brk_y0 := 0.0  # m up he was when a tentacle breaker began
var _brk_zone := Vector3.ZERO
var _brk_dir := Vector3.FORWARD
var _brk_dive_from := Vector3.ZERO
var _brk_cue: Node3D
var _brk_meteor: Node3D  # the fire round him on the way down (void_element.meteor_shell)
var _brk_focus := false  # the window's slow motion has started
var _brk_ended := ""  # how the last breaker's press went (breaker_window)
var _brk_prompt: Control  # the timing circle (breaker_prompt.gd), made on the first leap

# Counts the pause menu, HUD and autotest read.
var combos_landed := {}  # COMBOS id -> times landed this run (pause menu, combo guide)
var breakers_landed := 0  # combo breakers (timed finishers) landed (autotest)
var breaker_perfects := 0
var breakers_seen := {}  # BREAKERS id -> true once landed (autotest `breakers=`)
var endings_seen := {}  # breaker name -> true once landed, alt endings too (autotest `endings=`)
var rank_ups := 0  # style rank climbs that burst at the hero (autotest)
var last_kills := 0  # fights ended with the slow-motion final blow (autotest)

# The autotest bot (main.gd) drives him without real input.
var bot_enabled := false
var bot_move := Vector3.ZERO
var bot_alt := false  # the bot's window press takes `alt`
var bot_out := false  # the bot may dash out of a breaker's hang (its "out" token; hero_leap.tick)
## The bot's `[autotest]` lines, printed by main at the end: a print mid-fight with stdout piped costs
## 2-10 ms, the windowed autotest's only frame spikes.
var bot_log: Array[String] = []


func _ready() -> void:
	hp = max_hp
	Game.enemy_killed.connect(_on_enemy_killed)
	Game.combo_changed.connect(_on_combo_changed)
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

	model = ComicLook.scene(ComicLook.HERETIC).instantiate()
	add_child(model)
	ComicLook.apply(model, ComicLook.HERETIC)
	Fx.outline(model)
	_meshes = model.find_children("*", "MeshInstance3D", true, false)
	_awaken_rim = Fx.rim_material().duplicate()
	for blade in ComicLook.hero_blades(model):
		_add_trail(blade)
	anim = model.find_child("AnimationPlayer", true, false)
	_coats = _coat_axes()  # after _meshes
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var void_arm := VOID_ARM.new()
	void_arm.setup(self, model, skel)
	void_arm.rest_form = "hand"  # a free tentacle at rest; weapons only form to strike
	void_arm.pops = false
	void_arm.shape("hand", false)
	HERETIC_RIG.new().setup(void_arm, skel)
	_void = VOID_GRAB.new()
	add_child(_void)
	_void.setup(self, void_arm, skel)
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
	_callout = HERO_FX.make_callout(self)
	_orbit = ELEMENTS.Orbit.new()
	_orbit.piece_size = ComicLook.HERO_ORBIT_SIZE
	add_child(_orbit)
	_orbit.setup(element(), false)

	health_changed.emit(hp, max_hp)
	_play("Idle")


func _add_trail(weapon: MeshInstance3D) -> void:
	var trail := TRAIL.new()
	add_child(trail)
	trail.setup(weapon)
	trail.color = HERO_FX.trail_rest_color(self)
	_trails.append(trail)


func _coat_axes() -> Array[Node3D]:
	return ComicLook.infuse_axes(model, element())


## What the rig calls a clip the game asks for.
func _clip_name(wanted: String) -> String:
	return ComicLook.clip(anim, ComicLook.HERETIC, wanted)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	HERO_AWAKEN.keep_rim(self)
	HERO_INPUT.read_input(self)

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
		State.LEAP: HERO_LEAP.tick(self, delta)
		State.SWING: _void.travel_tick(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)

	move_and_slide()
	var air_hold := _air_dash and (state == State.DASH or (state == State.MOVE and _post_dash_t > 0.0))
	if state in [State.MOVE, State.DASH, State.HURT, State.CHARGE, State.DEAD] and model.position.y > 0.0 and not air_hold:
		model.position.y = move_toward(model.position.y, 0.0, 16.0 * delta)  # out of a hop
	if state != State.ATTACK and (model.position.x != 0.0 or model.position.z != 0.0):
		model.position.x = move_toward(model.position.x, 0.0, 6.0 * delta)  # back under him
		model.position.z = move_toward(model.position.z, 0.0, 6.0 * delta)
	if model.position.y < 0.05:
		_air_dashes = 0  # back on the floor: the air dash comes back
	var swinging: bool = state == State.ATTACK and HERO_MOVES.progress(self) < _move.cancel
	if swinging and VOID_ELEMENT.is_element_move(_move_id):
		swinging = false  # the element is the swing (void_element.gd)
	if swinging and _move.get("thrust", false) and TRAIL.DESIGNED.on():
		swinging = false  # fx-ice3: a thrust drags the brush ribbon into long cyan blades (Zak: no crystals)
	for trail in _trails:
		trail.emitting = swinging
	model.rotation.y = lerp_angle(model.rotation.y, _facing_yaw, 1.0 - exp(-25.0 * delta))


func _tick_timers(delta: float) -> void:
	_state_t += delta
	_ready_t -= delta
	_fidget_t -= delta
	_since_dash += delta
	_buffer_t -= delta
	_dash_buffer_t -= delta
	_dash_cd -= delta
	_swing_cd -= delta
	_swing_buffer_t -= delta
	_post_dash_t -= delta
	_fling_t -= delta
	_invuln_t -= delta
	_chain_reset_t -= delta
	if _buffer_t <= 0.0:
		_buffered = ""
	if _chain_reset_t <= 0.0 and state != State.ATTACK:
		_chain_i = 0
	HERO_AWAKEN.tick(self, delta)


## The last device touched decides, so a gamepad goes back to facing the way he runs.
func _input(event: InputEvent) -> void:
	HERO_INPUT.note_device(self, event)


# --- States ------------------------------------------------------------------

func _state_move(delta: float) -> void:
	var dir := HERO_INPUT.input_dir(self)
	var speed := move_speed * (HERO_AWAKEN.SPEED_MULT if awakened else 1.0)
	var target := dir * speed
	var grip := accel * (FLING_ACCEL_MULT if _fling_t > 0.0 else 1.0)
	velocity.x = move_toward(velocity.x, target.x, grip * delta)
	velocity.z = move_toward(velocity.z, target.z, grip * delta)
	_face(HERO_INPUT.mouse_dir(self) if HERO_INPUT.mouse_aiming(self) else dir)
	_play_locomotion(dir)

	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0:
		_start_dash()
	elif _try_swing():
		pass
	elif _buffered == "heavy" and _next_move("heavy") == VOID_ELEMENT.NEUTRAL and Input.is_action_pressed("attack_heavy"):
		_start_charge()
	elif _buffered != "":
		_start_attack(_next_move(_buffered))


## Idle or a run. The comic hero has a clip per direction relative to where he faces; they share
## one cycle, so a change of clip carries on from the same step.
func _play_locomotion(dir: Vector3) -> void:
	var playing := anim.current_animation
	var ground := Vector2(velocity.x, velocity.z).length() / move_speed
	if dir.length() <= 0.1:
		var stop := "Run_Stop%s%s" % [RUN_SUFFIX.get(playing, ""), "_Ready" if _ready_t > 0.0 else ""]
		if ComicLook.is_run_clip(playing) and ground > RUN_STOP_ABOVE and anim.has_animation(stop):
			_play(stop, 0.06, true)
		elif not playing.begins_with("Run_Stop"):  # the skid plays out, then the stand
			_comic_stand()
	else:
		_fidget_t = ComicLook.FIDGET_EVERY
		var clip := ComicLook.run_clip(dir, _facing(), playing)
		var start: String = "Run_Start" + RUN_SUFFIX.get(clip, "")
		if playing == start:
			return  # the lunge lands on the run's first step
		if not ComicLook.is_run_clip(playing) and ground < RUN_START_BELOW and anim.has_animation(start):
			_play(start, 0.06, true)
			return
		if clip == playing:
			anim.speed_scale = _loop_speed(clip)  # Awakened can start or end mid-run
			return
		var step := anim.current_animation_position if ComicLook.is_run_clip(anim.current_animation) else 0.0
		_play(clip, 0.12)
		anim.seek(step, true)


## Standing still: on guard for a moment after a fight, then at ease, fidgeting now and then.
func _comic_stand() -> void:
	if _ready_t > 0.0:
		_fidget_t = ComicLook.FIDGET_EVERY
		_play(ComicLook.HERO_READY, 0.15)
	elif anim.current_animation in ComicLook.HERO_FIDGETS:
		return  # plays out; when it ends current_animation clears
	elif _fidget_t <= 0.0:
		_fidget_t = ComicLook.FIDGET_EVERY
		_play(ComicLook.HERO_FIDGETS[_fidget_i], 0.25)
		_fidget_i = (_fidget_i + 1) % ComicLook.HERO_FIDGETS.size()
	else:
		_play("Idle", 0.3)


func _start_charge() -> void:
	_buffered = ""
	_charged = false
	_charge_fx_t = 0.0
	_set_state(State.CHARGE)
	_play("2H_Melee_Idle", 0.1)


func _state_charge(delta: float) -> void:
	var dir := HERO_INPUT.input_dir(self)
	var target := dir * move_speed * CHARGE_MOVE_MULT
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	_face(HERO_INPUT.mouse_dir(self) if HERO_INPUT.mouse_aiming(self) else dir)
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
		_start_attack(VOID_ELEMENT.CHARGED if _charged else VOID_ELEMENT.NEUTRAL)


func _state_attack(delta: float) -> void:
	var t := HERO_MOVES.progress(self)
	if _void != null:
		_void.attack_tick(t, delta)
	if HERO_INPUT.mouse_aiming(self) and not _hop_air:  # (in the air hero_moves.air_home has him)
		HERO_INPUT.steer(self, delta)
	# Lunge decays quickly so attacks feel snappy, not slidey.
	var lunge: float = _move.lunge * maxf(0.0, 1.0 - t * _move.get("decay", 3.0))
	var fwd := _facing()
	velocity.x = fwd.x * lunge
	velocity.z = fwd.z * lunge
	if _move_id in VOID_ELEMENT.SPEAR_RUN and _hits_done == 0:
		VOID_ELEMENT.run_to_spear(self, delta)

	HERO_MOVES.hop(self, t)
	var hits: Array = _move.hits
	while _hits_done < hits.size() and t >= hits[_hits_done]:
		_hits_done += 1
		_do_hit()
	var brk := HERO_LEAP.entry_for(_move_id)
	if not brk.is_empty() and _connected and t >= _move.get("leap", brk.leap):  # (a whiff plays out normally)
		HERO_LEAP.start(self, _move_id, brk)
		return

	# Dash cancels anything once the first hit has come out (or early on whiff).
	var can_cancel := HERO_INPUT.can_dash_cancel(self, t)
	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0 and can_cancel:
		_start_dash()
		return
	if can_cancel and _try_swing():
		return
	if t >= HERO_INPUT.cancel_point(self) and _buffered != "" and not HERO_INPUT.held_for_window(self):
		_start_attack(_next_move(_buffered))
		return
	if t >= _move.end:
		_chain_reset_t = 0.35
		_set_state(State.MOVE)


func _state_dash(delta: float) -> void:
	if not _counter.is_empty():
		COUNTER.tick(self, delta)
		return
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = afterimage_interval
		Fx.afterimage(get_parent(), model, Color(_fx_color(), 0.45))
	velocity.x = _dash_dir.x * dash_speed
	velocity.z = _dash_dir.z * dash_speed
	if _state_t >= dash_time or HERO_INPUT.dash_hands_over(self):
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
	if s != State.DASH and not _counter.is_empty():
		COUNTER.cut(self)
	state = s
	_state_t = 0.0
	if _void != null:
		_void.on_state(s)
	if s != State.CHARGE:
		_charge_light.light_energy = 0.0


# --- Actions -----------------------------------------------------------------

func _start_attack(id: String) -> void:
	_buffered = ""
	_ready_t = ComicLook.READY_HOLD
	if id == "GR" and _void.begin():
		return
	var prev_id := _move_id
	_move_id = id
	_move = HERO_MOVES.effective_move(anim, id)
	_anim_mult = HERO_AWAKEN.base_anim_mult(self) * _move.get("speed", 1.0)
	_move_len = anim.get_animation(_clip_name(_move.anim)).length
	_hits_done = 0
	_connected = false
	_hop_y0 = model.position.y
	_hop_air = _hop_y0 > 0.4
	_hop_peak = _hop_y0 if _hop_air else 0.0
	_callout_done = false
	_chain_i = HERO_MOVES.chain_after(id)
	_post_dash_t = 0.0
	_air_dash = false
	HERO_INPUT.aim(self, state == State.ATTACK)
	if _hop_air:
		HERO_MOVES.air_home(self)
	else:
		HERO_MOVES.brake(self)  # (Dash Stab stops in front of the foe it aims at)
	_set_state(State.ATTACK)
	_void.on_move(id, prev_id)
	attack_started.emit(id)
	Game.sfx("swing", -3.0, 0.12)
	_play(_move.anim, 0.05, true)


func _next_move(kind: String) -> String:
	return HERO_MOVES.routed(self, kind, _move_id, state == State.ATTACK, _chain_i, _post_dash_t > 0.0)


## R: the void arm swings him, if it's ready. True if it did.
func _try_swing() -> bool:
	if _swing_buffer_t <= 0.0 or _swing_cd > 0.0:
		return false
	_swing_buffer_t = 0.0
	_swing_cd = SWING_COOLDOWN
	_void.traverse()
	return true


func _start_dash() -> void:
	var aim := HERO_INPUT.input_dir(self)
	if COUNTER.try_start(self, aim.normalized() if aim.length() > 0.1 else _facing()):
		return  # a strike was coming at him: the dash is the counter (counter.gd)
	_dash_from = global_position
	_dash_out = state == State.ATTACK
	_air_dash = HERO_MOVES.can_air_dash(self)
	if _air_dash:
		_air_dashes += 1
	_dash_buffer_t = 0.0
	_dash_cd = dash_cooldown
	_anim_mult = HERO_AWAKEN.base_anim_mult(self)
	var dir := HERO_INPUT.input_dir(self)
	_dash_dir = dir.normalized() if dir.length() > 0.1 else _facing()
	_face(_dash_dir)
	_invuln_t = dash_time + 0.08
	_since_dash = 0.0
	_perfect_this_dash = false
	_set_state(State.DASH)
	_ghost_t = 0.0
	_play("Dodge_Forward", 0.04, true)
	if _air_dash:
		HERO_MOVES.air_dash_cut(self)
	else:
		Fx.dust(get_parent(), global_position, 8)
		Fx.dash_streak(get_parent(), global_position, _dash_dir, dash_speed * dash_time + 0.8, Color(_fx_color(), 0.8))
	Game.sfx("dash", -4.0)


func _do_hit() -> void:
	if _move_id == "GR":
		_void.strike()
		if _void._target_alive():
			VOID_ELEMENT.DARK.burst(get_parent(), _void._target.global_position, 0.8)
		return
	if _move_id == "VS":
		_void.slam_lands()
	var fwd := _facing()
	var named_before := _callout_done  # a combo ender lands its extra punch once
	# (not on H's moves: the element is the swing, and the arc hides it)
	if not VOID_ELEMENT.is_element_move(_move_id):
		HERO_FX.swoosh(self, fwd)
	var hit_any := false
	var any_airborne := false
	# (a move with no reach is all fire(): its `range` 0 still caught a foe standing on him, a 0-damage touch that
	# broke the ice before fire() read it)
	for e in get_tree().get_nodes_in_group("enemies") if _move.range > 0.0 else []:
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
		var dmg: float = _move.damage * _dmg_mult * HERO_MOVES.plunge_mult(self)
		e.take_hit(dmg, kb_dir * _move.knockback, _move.launch, _move.get("big", false))
		Fx.element_hit(get_parent(), e.global_position, element(), kb_dir, _move.get("big", false))
		Game.register_hit(_move_id + ("_air" if was_airborne else ""))
		hit_any = true
		_connected = true
	# Slot effects that fire on the move's first active frame, hit or miss.
	if _hits_done == 1:
		HERO_FX.cast(self, fwd)
		if VOID_ELEMENT.is_element_move(_move_id) and VOID_ELEMENT.fire(self, _move_id, fwd) > 0:
			hit_any = true
			_connected = true
	if _move_id == "VS":
		_void.slam_landed()
	if hit_any:
		var ender: int = COMBOS[_move_id].tier if COMBOS.has(_move_id) and not named_before else 0
		HERO_FX.combo_callout(self, _move_id)
		Game.sfx("hit_big" if _move.get("big", false) else "hit")
		if _move.get("big", false):
			Game.rumble("hit_big")
		Game.hitstop(HERO_MOVES.hit_stop(self, _move_id, ender, any_airborne))  # (escalates: opener, mid, ender)
		Game.shake(_move.shake)
		if ender > 0 or _move.get("big", false):
			HERO_FX.camera_hit(fwd, HERO_MOVES.cam_tier(_move_id, ender))


func _facing() -> Vector3:
	return Vector3(sin(_facing_yaw), 0.0, cos(_facing_yaw))


func facing_dir() -> Vector3:
	return _facing()


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		_facing_yaw = atan2(dir.x, dir.z)


## _facing turned at most `max_deg` toward `want`.
func _turned(want: Vector3, max_deg: float) -> Vector3:
	var yaw := rotate_toward(_facing_yaw, atan2(want.x, want.z), deg_to_rad(max_deg))
	return Vector3(sin(yaw), 0.0, cos(yaw))


## How far the hero can travel along `dir` (up to `length`) before a wall.
func _clear_ahead(dir: Vector3, length: float) -> float:
	var from := global_position + Vector3.UP * 0.9
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (length + 0.6), collision_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return length
	return maxf(from.distance_to(hit.position) - 0.6, 0.0)


## True if offset `to` (flat) lies in the strip `length` ahead along `fwd`.
static func _in_strip(to: Vector3, fwd: Vector3, length: float, half_width: float, pad: float) -> bool:
	var ahead := to.dot(fwd)
	var side := (to - fwd * ahead).length()
	return ahead > -0.5 and ahead <= length + pad and side <= half_width + pad


# --- Casts and the look ------------------------------------------------------

## The hero's element for his own casts and trails: spirit. (Each void move
## takes its element from the weapon it forms: VOID_ELEMENT.ELEMENT_OF.)
func element() -> String:
	return "spirit"


## Colour for the hero's own effects (dash ghosts and streak): Awakening's
## gold while Awakened, otherwise the element's.
func _fx_color() -> Color:
	return HERO_AWAKEN.AWAKEN_COLOR if awakened else ELEMENTS.color(element())


func _on_enemy_killed(e: Node) -> void:
	if state != State.DEAD and _is_last_kill():
		HERO_FX.last_kill(self, e)


## Style rank climbed: a burst in the new rank's colour (the HUD's), bigger the higher it goes.
func _on_combo_changed(_count: int, rank: String) -> void:
	var i := Game.RANKS.size() - 1 - Game.RANKS.map(func(r: Array) -> String: return r[0]).find(rank)
	if i > _rank_i and state != State.DEAD and is_inside_tree():
		rank_ups += 1
		HERO_FX.rank_up(self, i, rank)
	_rank_i = i


## Nothing left to fight: no enemy alive and no reinforcements queued (main._queue).
func _is_last_kill() -> bool:
	if not get_tree().get_nodes_in_group("enemies").is_empty():
		return false
	var queue = get_parent().get("_queue")
	return queue is Array and queue.is_empty()


# --- Taking hits -------------------------------------------------------------

func is_invulnerable() -> bool:
	return _invuln_t > 0.0


func is_dead() -> bool:
	return state == State.DEAD


## Slow time, refund Awakening, stun the attacker, and allow an instant re-dash.
func _perfect_dodge(attacker: Node) -> void:
	_perfect_this_dash = true
	_dash_cd = 0.0
	Game.perfect_dodge(perfect_dodge_refund)
	Game.hitstop(0.5, 0.25)
	Fx.ring(get_parent(), global_position, Color(0.5, 0.85, 1.0, 0.9), 4.0, 0.4)
	Fx.ring(get_parent(), global_position, Color(0.25, 0.6, 1.0, 0.9), 2.2, 0.3)
	Fx.flare(get_parent(), global_position + Vector3.UP * 1.0, Color(0.35, 0.75, 1.0), 9.0, 0.35, "flare")
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.8, Color(0.6, 0.9, 1.0), 20, 9.0, 0.14, 0.4, Vector3.UP, 180.0, 0.0, 0.0, "dot", true)
	Fx.afterimage(get_parent(), model, Color(0.8, 0.95, 1.0, 0.6), 0.5)
	if attacker and attacker.has_method("stagger"):
		attacker.stagger(perfect_dodge_stun)


func take_hit(damage: float, knockback: Vector3, attacker: Node = null) -> void:
	if state == State.DEAD:
		return
	if _invuln_t > 0.0:
		if _since_dash <= perfect_dodge_window and not _perfect_this_dash:
			_perfect_dodge(attacker)
		return
	hp = maxf(hp - damage * (HERO_AWAKEN.DAMAGE_TAKEN if awakened else 1.0), 0.0)
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
	if hp <= 0.0:
		_set_state(State.DEAD)
		if awakened:
			HERO_AWAKEN.set_awakened(self, false)
		_play("Death_A", 0.1, true)
		died.emit()
		return
	# Awakened hero has super armor: takes damage but isn't staggered.
	if not awakened:
		_set_state(State.HURT)
		_ready_t = ComicLook.READY_HOLD
		_play("Hit_A", 0.05, true)


func _play(anim_name: String, blend := 0.1, restart := false) -> void:
	anim_name = _clip_name(anim_name)
	if anim.current_animation == anim_name and not restart:
		return
	anim.play(anim_name, blend, 1.0)
	if restart:
		anim.seek(0.0, true)
	# Locomotion plays at natural speed; actions are sped up for snappiness.
	var loop := anim_name in LOOPING or anim_name in RUN_ONESHOTS or anim_name in ComicLook.HERO_FIDGETS
	anim.speed_scale = _loop_speed(anim_name) if loop else anim_speed * _anim_mult


func _loop_speed(clip: String) -> float:
	var run := ComicLook.is_run_clip(clip) or clip in RUN_ONESHOTS
	return LOOP_SPEED * (AWAKENED_RUN_CLIP if awakened and run else 1.0)


# --- Read by duck-typed callers (breaker_prompt.gd and its test fakes) -------

## The breaker window breaker_prompt.gd draws (hero_leap.window).
func breaker_window() -> Dictionary:
	return HERO_LEAP.window(self)


# Forwarders kept for hero_leap.gd, void_element.gd and training_bot.gd (owned by another lane; drop
# these once those files call HERO_FX / HERO_INPUT directly).
func _cast_grow() -> float:
	return HERO_FX.cast_grow()


func _cast_power() -> float:
	return HERO_FX.cast_power()


func cancel_point() -> float:
	return HERO_INPUT.cancel_point(self)


func combo_window() -> Dictionary:
	return HERO_INPUT.combo_window(self)
