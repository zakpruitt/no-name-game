extends CharacterBody3D
## Skeleton enemy: spawns from the ground, chases (melee) or keeps its
## distance and fires bolts (ranged) or crossbow shots (line), telegraphs
## every attack, staggers when hit (unless its poise holds), and can be
## launched/juggled.

signal died(enemy: Node)

enum State { SPAWN, CHASE, WINDUP, RECOVER, HURT, AIRBORNE, DODGE, DEAD }

## Spellcasting is out since round 38 b: the comic casters' windups are all tell, held on their last frame.
const LOOPING := ["Idle_Combat", "Running_A", "Walking_D_Skeletons", "Running_C"]
const PROJECTILE := preload("res://scripts/projectile.gd")
const FOE_LEAN := preload("res://scripts/foe_lean.gd")
const STATE_TELL := preload("res://scripts/comic_state_tell.gd")

@export var model_scene: PackedScene
## ComicLook model name of model_scene (every spawnable kind has a comic GLB; main._set_model sets it).
var comic_kind := ""
var _clip_hold_ms := 0  # comic: run/idle don't replace a held clip until then (_hold_clip)
@export var max_hp := 30.0
@export var move_speed := 3.6
@export var attack_range := 1.9
@export var attack_damage := 10.0
@export var attack_windup := 0.6
@export var attack_recover := 0.7
## Frame of the melee clip (1H_Melee_Attack_Chop, at ATTACK_CLIP_FPS) where the blow lands (enemy_types
## `attack_hit`, the comic foes' keyed contact, foe_cycles.py): the clip plays at
## attack_hit / ATTACK_CLIP_FPS / attack_windup so that frame falls on the windup's end. 0 = the
## KayKit rule, CHOP_HIT_AT of the clip's length.
@export var attack_hit := 0.0
const ATTACK_CLIP_FPS := 24.0
const CHOP_HIT_AT := 0.45
## Knockback below this doesn't stagger (0 = always staggers).
@export var poise := 0.0
@export var model_scale := 1.0
@export var run_anim := "Running_A"
## m/s a planted foot slides back on the comic run clip at 1x, before model_scale (enemy_types
## `run_foot_speed`, measured by tests/foe_stride_check.gd). The run plays at ground speed over
## this, clamped to RUN_CLIP_SPEED_MIN/MAX, so short chibi legs don't skate. 0 = always 1x.
@export var run_foot_speed := 0.0
## "melee", "ranged" or "line". Ranged and line enemies hold
## `preferred_range` and shoot; "line" is a fast crossbow bolt aimed along a
## ground line that tracks the player until `AIM_LOCK` of the windup, then
## freezes, so sidestepping late dodges it.
@export var attack_kind := "melee"
@export var preferred_range := 7.0
@export var projectile_speed := 9.0
## Crowd behaviour: personal space from other enemies, and how many melee
## enemies may wind up at the same time (the rest circle and wait).
@export var separation_radius := 1.8
@export var max_melee_attackers := 2
## Flankers circle to the hero's back before closing in.
@export var flank := false
## Chance to hop away when the hero starts an attack nearby (only from
## neutral; once hit, combos land normally).
@export var dodge_chance := 0.0
@export var dodge_cooldown := 1.6
## Shield bearer: blocks hits from the front while walking/recovering (not
## while attacking). Big hits and launchers break the guard for a while;
## hits from the side or behind always land.
@export var shield := false
const SHIELD_BREAK_TIME := 2.0
## Crossbow archer (attack_kind "line").
const AIM_LOCK := 0.7
const LINE_COLOR := Color(1.0, 0.55, 0.15)
## Seconds this enemy alone freezes on hit (on top of global hitstop).
@export var hit_freeze := 0.06
@export var hit_freeze_big := 0.11
# Hit reactions (_hit_reaction, the one place every visual reaction to a hit
# lives): the model snaps to SQUASH[kind] (x, y, z scale) and springs back,
# leans away along the knockback (LEAN rad, LEAN_BIG on big hits, held
# LEAN_HOLD s through the freeze, then back upright over LEAN_TIME) and
# flashes in the hero's hit colour mixed FLASH_TINT toward it
# (FLASH_TAP / FLASH_BIG s). A kill holds the corpse's last pose KILL_FREEZE s
# before it flies (longer than hit_freeze_big: the pop reads).
const SQUASH := {
	"tap": Vector3(1.15, 0.87, 1.15),
	"big": Vector3(1.32, 0.7, 1.32),
	"launch": Vector3(0.72, 1.45, 0.72),  # stretched tall as it leaves the ground
	"juggle": Vector3(1.2, 0.84, 1.2),  # a sharp snap on each hit that keeps it up
	"kill": Vector3(1.4, 0.6, 1.4),
	"air_kill": Vector3(1.4, 0.6, 1.4),  # killed while up: the same pop, then it spins down (_die)
	"land": Vector3(1.35, 0.65, 1.35),  # flattened on the floor
	"bounce": Vector3(0.9, 1.15, 0.9),
	"spike": Vector3(0.7, 1.5, 0.7),  # stretched long as it's driven down
	"crater": Vector3(1.75, 0.32, 1.75),  # pancaked into the floor (held CRATER_HOLD)
}
const SQUASH_TIME := 0.3  # s the elastic spring back to full size takes
const LEAN := 0.2
const LEAN_BIG := 0.42
const LEAN_HOLD := 0.08
const LEAN_TIME := 0.3
const FLASH_TAP := 0.07
const FLASH_BIG := 0.12
const FLASH_TINT := 0.55
const KILL_FREEZE := 0.14
# Ink (_ink_pulse): big hits swell this foe's own outline to INK[kind] times
# its width and ease it back over INK_TIME, so the blow reads in the line too.
const INK := {"big": 2.0, "launch": 2.0, "spike": 2.4, "crater": 2.6, "kill": 2.8, "air_kill": 2.8}
# A kill in the air tumbles AIR_KILL_SPIN times TUMBLE_BIG all the way down,
# then the corpse settles flat over TUMBLE_SETTLE on touchdown.
const AIR_KILL_SPIN := 1.8
const INK_TIME := 0.28  # s back to the resting width
# Crowd hits read as a wave, not one frame: of the foes hit in the same
# physics frame, each after the first reacts WAVE_STEP s later than the one
# before (its freeze runs that much longer and its flash/squash/lean wait),
# up to WAVE_MAX steps (a Cataclysm's ring all land inside ~0.2 s).
const WAVE_STEP := 0.035
const WAVE_MAX := 6
# Juggles (_gravity, _tumble, _land_from_air, _skid): AIR_GRAVITY while
# launched (GROUND_GRAVITY otherwise), HANG_GRAVITY of it while |vy| <
# HANG_SPEED so a launched foe hangs a beat at the apex (a 9 m/s launch
# spends ~0.67 s within 0.3 m of its top instead of 0.41); it tumbles
# over backwards at TUMBLE_SPEED rad/s (big hits TUMBLE_BIG), slowing by
# TUMBLE_DRAG per s, and rights itself over TUMBLE_SETTLE on landing. Falling
# faster than BOUNCE_MIN_FALL it bounces once at BOUNCE_KEEP of the fall
# speed (SQUASH.bounce), skating on along the launch at LAND_SLIDE of the fall
# speed, and the knockdown slides out at SKID_FRICTION with a
# dust puff every SKID_DUST_EVERY s while faster than SKID_MIN_SPEED (AIR_DRAG
# is the slide in the air, low so a launch carries). launch_speed_for() is the
# inverse of the gravity profile (training_dummy caps its rise with it).
const AIR_GRAVITY := 14.0
const GROUND_GRAVITY := 30.0
const HANG_SPEED := 2.0
const HANG_GRAVITY := 0.55
const TUMBLE_SPEED := 2.5
const TUMBLE_BIG := 4.0
const TUMBLE_DRAG := 1.5
const TUMBLE_SETTLE := 0.12
const BOUNCE_MIN_FALL := 7.0
const BOUNCE_KEEP := 0.35
const AIR_DRAG := 2.5
const LAND_SLIDE := 0.4  # the hard touchdown's horizontal speed, as a share of the fall speed, along the launch
const SKID_FRICTION := 6.0
const SKID_DUST_EVERY := 0.08
const SKID_MIN_SPEED := 1.0
const LIE_TIME := 0.35  # s a plain knockdown lies there before HURT's 0.4 s
# Hit direction (_reaction_kind, _crater, _land_from_air, _kick_tumble). From
# below: an airborne hit launching at least RELAUNCH_MIN re-launches with the
# launch stretch, not the juggle snap. Downward (launch < 0 or knockback.y < 0:
# how a slam says so; Spike's own SPIKE_DOWN arrives as a fast fall): an
# airborne foe is driven down at SPIKE_SPEED stretched (SQUASH.spike), and
# any touchdown faster than SPIKE_FALL craters instead of bouncing; a
# grounded foe craters on the spot. A crater pancakes it (SQUASH.crater, held
# CRATER_HOLD, back over CRATER_TIME), marks the floor CRATER_RADIUS wide, and
# the knockdown lies SPIKE_LIE s, skidding out at SPIKE_SLIDE of the fall
# speed (grounded: SPIKE_GROUND_SLIDE of the knockback) with the lower
# SPIKE_SKID_FRICTION. Side: a launch whose knockback is more across the foe
# than along its facing (by ROLL_BIAS) rolls sideways instead of backflipping.
const RELAUNCH_MIN := 7.0  # m/s; air-string hits launch 5, launchers 8-11
const SPIKE_SPEED := 24.0  # m/s down, the same as player.SPIKE_DOWN
const SPIKE_FALL := 15.0  # m/s; the highest natural fall (an 11 m/s launch) lands at ~11
const SPIKE_SLIDE := 0.2  # share of the fall speed it skids out at (24 -> 4.8 m/s)
const SPIKE_GROUND_SLIDE := 0.8  # share of a grounded spike's knockback it skids out at
const SPIKE_SKID_FRICTION := 4.0  # m/s^2 (SKID_FRICTION 6): a spiked skid goes ~2.9 m
const SPIKE_LIE := 0.7  # s lying in the crater (LIE_TIME 0.35)
const CRATER_HOLD := 0.12  # s the pancake holds before springing back
const CRATER_TIME := 0.5  # s the spring back from the pancake takes
const CRATER_RADIUS := 1.6  # m, the floor mark
const CRATER_SHAKE := 0.22  # Game.shake amount (a plain knockdown 0.1)
const ROLL_BIAS := 1.0  # |local x| > ROLL_BIAS * |local z| rolls

static var _wave_frame := -1  # physics frame of the last hit taken by any enemy, and
static var _wave_n := 0  # how many took one that frame (_wave_slot)
static var blocks := 0

var radius := 0.55
var hp := 0.0
var last_hit_ms := -100000  # when damage last landed (health bar, enemy_bars.gd)
var hits_taken := 0  # landed hits, blocks not counted (spar.gd reports it)
var _quiet_hit := false  # inside burn_hit
var state := State.SPAWN
var model: Node3D
var anim: AnimationPlayer

var _state_t := 0.0
var _player: Node3D
var _telegraph: MeshInstance3D
var _telegraph_mat: StandardMaterial3D
var _edge: MeshInstance3D  # bright pulsing rim + dark outline on the telegraph ring (Fx.edge_ring)
var _edge_t := 0.0
var _attack_cd := 0.0
var _freeze_t := 0.0
# Cold (the void ice moves): chilled foes move and act at chill_mult speed; frozen ones
# are encased (stunned) and the next hit shatters the ice for frozen_mult damage.
var chill_t := 0.0
var chill_mult := 1.0
var frozen_t := 0.0
var frozen_mult := 1.0
var _ice: MeshInstance3D
var _frozen_speed := -1.0
var _clip_want := 1.0  # the clip's speed once it's free (frozen in ice it holds at 0: _clip_speed)
var _squash_tween: Tween
var _ink_mat: ShaderMaterial  # this foe's own outline (Fx.outline_own; null headless), thickened by _ink_pulse
var _ink_px := 0.0  # its resting width_px
var _ink_tween: Tween
var _wave_delay := 0.0  # this hit's place in its frame's wave, s (_die waits it out for the death pop)
var last_ink := 1.0  # the last _ink_pulse multiplier (enemy_feel_check reads it)
var last_squash := Vector3.ONE  # the last _squash() amount (enemy_feel_check reads it)
var _lean_tween: Tween
var _fall_vy := 0.0  # last in-air vertical speed (the landing frame has already zeroed velocity.y)
var _bounced := false
var _tumble_v := 0.0  # rad/s around the model's side axis while airborne
var _tumble_roll := false  # the tumble turns rotation.z (a side roll), not rotation.x (a backflip)
var _spiked := false  # lying in a crater: _skid uses SPIKE_SKID_FRICTION
var _air_dir := Vector3.ZERO  # the launch's horizontal direction (the knockdown skates along it)
var _skid_dust_t := 0.0
var _orbit_side := 1.0
var _dodge_cd := 0.0
var _guard_broken_t := 0.0
var _aim_dir := Vector3.FORWARD
var _aim_line: Node3D


func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 4
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	model = model_scene.instantiate()
	model.scale = Vector3.ONE * model_scale
	radius *= model_scale
	add_child(model)
	if comic_kind != "":
		ComicLook.apply(model, comic_kind)
	_ink_mat = Fx.outline_own(model)
	if _ink_mat != null:
		_ink_px = _ink_mat.get_shader_parameter("width_px")
	anim = model.find_child("AnimationPlayer", true, false)
	if TURN_LEAN.has(comic_kind):
		var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
		if skel != null:
			var lean := FOE_LEAN.new()
			lean.foe = self
			lean.deg_per_mps = TURN_LEAN[comic_kind]
			skel.add_child(lean)
	for a in LOOPING:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR

	_build_telegraph()
	_player = get_tree().get_first_node_in_group("player")
	if dodge_chance > 0.0 and _player:
		_player.attack_started.connect(_on_player_attack)
	_attack_cd = randf_range(0.2, 1.0)
	_orbit_side = 1.0 if randf() < 0.5 else -1.0
	_play("Spawn_Ground_Skeletons", 0.0, 1.6)
	Game.sfx("spawn", -10.0, 0.2)
	load("res://scripts/designed_elements.gd").prime_fit.call_deferred(self)  # (round 53: the first ice block's 44 ms, at spawn)


## Shoots from a distance (doesn't need a melee slot).
func is_ranged() -> bool:
	return attack_kind in ["ranged", "line"]


## Targetable: spawned, not dead, and not mid-dodge.
func is_alive() -> bool:
	return state != State.DEAD and state != State.SPAWN and state != State.DODGE


func is_airborne() -> bool:
	return state == State.AIRBORNE


## Held by a control move: carried or thrown (thrown_foe.FLYING: a tentacle carry, a gather, Collapse, Abyss,
## Avalanche, the counter's lift), bound (floor_bind.BOUND: tendrils, a gallows hook; big foes are only slowed, so
## not them) or frozen in a cube. A held foe never strikes: a windup under way is cut (HELD_CUT) and none starts
## (spar audit 2026-11-07: a carried foe kept winding up and hit him from mid-air).
func held() -> bool:
	if has_meta(HELD_FLYING) or frozen_t > 0.0:
		return true
	return has_meta(HELD_BOUND) and radius < 0.9


const HELD_FLYING := "thrown_foe_flying"  # (thrown_foe.FLYING)
const HELD_BOUND := "x_bound"  # (floor_bind.BOUND)
const HELD_CUT := 0.4  # s the stagger a cut windup turns into
var held_cuts := 0  # windups a hold has cut (spar_check, the film's INDEX)
## Spar pass two: a hold's own first touch (the grab's hit, Harpoon's spear) staggers the foe a frame before the hold
## takes it, so the windup was already gone when held() came true and nothing was counted (`cuts=0` in every autotest).
## A windup broken by a hit and held within HOLD_CUT_GRACE game s counts as cut by that hold too, and so does the
## tentacle's grab (right click: it staggers and keeps what it holds staggered rather than holding it, `_grabbed()`).
const HOLD_CUT_GRACE := 0.2
var _windup_broke_t := INF  # game s since a windup was broken by anything but its strike


## Backlash (counter.gd) has this foe: its stagger and lift are the counter's, not a hold's.
func _countered() -> bool:
	return is_instance_valid(_player) and "_counter" in _player and _player._counter.get("foe") == self


## The tentacle's grab (void_grab.gd) has this foe.
func _grabbed() -> bool:
	if not is_instance_valid(_player) or not "_void" in _player or _player._void == null:
		return false
	return _player._void.get("_target") == self


func _physics_process(delta: float) -> void:
	STATE_TELL.sync(self)  # (a crossover state's tell: buried / molten / skewered, comic_state_tell.gd)
	if _telegraph.visible:
		_pulse_edge(delta)
	# Hit freeze: hold the pose and shudder; knockback starts once it ends.
	if _freeze_t > 0.0:
		_freeze_t -= delta
		if _frozen_speed < 0.0:
			_frozen_speed = anim.speed_scale
		anim.speed_scale = 0.0
		model.position = Vector3(randf_range(-0.07, 0.07), 0.0, randf_range(-0.07, 0.07))
		return
	if _frozen_speed >= 0.0:
		anim.speed_scale = _frozen_speed
		_frozen_speed = -1.0
		model.position = Vector3.ZERO
	chill_t -= delta
	var slow := chill_mult if chill_t > 0.0 else 1.0
	if frozen_t > 0.0:
		frozen_t -= delta
		if frozen_t <= 0.0:
			_thaw(false)
		elif anim.speed_scale != 0.0:  # (ice set straight on frozen_t, void_element.freeze_aloft: hold the pose too)
			_clip_speed(anim.speed_scale)
	_state_t += delta * slow
	_attack_cd -= delta
	_dodge_cd -= delta
	_guard_broken_t -= delta
	velocity.y -= _gravity() * delta
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	else:
		_fall_vy = velocity.y

	_windup_broke_t += delta
	if state == State.WINDUP and held():  # caught mid-windup: the strike is off
		held_cuts += 1
		stagger(HELD_CUT)
		_windup_broke_t = INF
	elif _windup_broke_t <= HOLD_CUT_GRACE and (held() or _grabbed()):  # (the hold's own hit broke it a moment ago)
		if not _countered():  # (Backlash's lift holds it too, but the counter cut that strike, not a hold)
			held_cuts += 1
		_windup_broke_t = INF
	match state:
		State.SPAWN:
			if _state_t >= 1.0:
				_set_state(State.CHASE)
		State.CHASE:
			_state_chase(delta)
		State.WINDUP:
			_state_windup(delta)
		State.RECOVER:
			_friction(delta, 30.0)
			if _state_t >= attack_recover:
				_set_state(State.CHASE)
		State.HURT:
			if _state_t < 0.0:  # knocked down: sliding out
				_skid(delta)
			else:
				_friction(delta, 18.0)
			if _state_t >= 0.4:
				_set_state(State.CHASE)
		State.AIRBORNE:
			_friction(delta, AIR_DRAG)
			_tumble(delta)
			if is_on_floor() and _state_t > 0.15:
				_land_from_air()
		State.DODGE:
			_friction(delta, 26.0)
			if _state_t >= 0.35:
				_set_state(State.CHASE)
		State.DEAD:
			_friction(delta, 20.0)
			_corpse_tumble(delta)

	if slow < 1.0 and state != State.AIRBORNE:
		velocity.x *= slow
		velocity.z *= slow
		move_and_slide()
		velocity.x /= slow
		velocity.z /= slow
	else:
		move_and_slide()


func _state_chase(delta: float) -> void:
	if not is_instance_valid(_player) or _player.is_dead():
		_friction(delta, 20.0)
		_play("Idle_Combat")
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	_face(to)
	if d <= attack_range and _attack_cd <= 0.0 and (is_ranged() or _melee_slot_free()) and not held():
		_set_state(State.WINDUP)
		_aim_dir = to / maxf(d, 0.001)
		if attack_kind == "line":
			_play("2H_Ranged_Aiming", 0.1)
			Game.sfx("swing", -12.0, 0.15)
		elif is_ranged():
			_play("Spellcasting", 0.1, 1.2)
		else:
			_play("1H_Melee_Attack_Chop", 0.1, chop_speed())
		return
	var dir := Vector3.ZERO
	var behind: Vector3 = _player.global_position - _player.facing_dir() * 2.5 - global_position
	behind.y = 0.0
	if flank and d > attack_range + 1.5 and behind.length() > 1.0:
		dir = behind.normalized()
	elif is_ranged():
		# Back off when crowded, close in when too far, otherwise hold.
		if d < preferred_range - 1.5:
			dir = -to / maxf(d, 0.001)
		elif d > attack_range * 0.9:
			dir = to / maxf(d, 0.001)
	elif d > attack_range * 0.8:
		dir = to / maxf(d, 0.001)
	else:
		# In range but waiting for a turn: circle slowly around the player.
		dir = Vector3(-to.z, 0.0, to.x) / maxf(d, 0.001) * _orbit_side * 0.4
	var push := _separation()
	var moving := dir != Vector3.ZERO or push.length() > 0.05
	dir += push
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * move_speed, 25.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * move_speed, 25.0 * delta)
	_play_locomotion(moving, dir)
	if moving and comic_kind != "" and anim.current_animation == ComicLook.clip(anim, comic_kind, run_anim):
		_clip_speed(run_clip_speed(Vector2(velocity.x, velocity.z).length()))


## The melee clip's speed that puts its hit frame on the windup's end (attack_hit).
func chop_speed() -> float:
	var hit := attack_hit / ATTACK_CLIP_FPS
	if hit <= 0.0:
		hit = anim.get_animation("1H_Melee_Attack_Chop").length * CHOP_HIT_AT
	return hit / attack_windup


## Run or idle, with the comic run start / stop one-shots where the model has them (the rogue and
## the minion, foe_cycles.py run_start / run_stop): Run_Start when it sets off on a full run from below
## RUN_START_BELOW of move_speed, Run_Stop when it lets go above RUN_STOP_ABOVE. Both play out at 1x
## (_hold_clip); setting off again cuts the skid short.
func _play_locomotion(moving: bool, dir: Vector3) -> void:
	if comic_kind != "" and anim.has_animation("Run_Start"):
		var ground := Vector2(velocity.x, velocity.z).length()
		var playing := anim.current_animation
		var run := ComicLook.clip(anim, comic_kind, run_anim)
		if moving and playing == "Run_Stop":
			_clip_hold_ms = 0
		elif dir.length() > RUN_START_DIR and playing != run and playing != "Run_Start" \
				and ground < move_speed * RUN_START_BELOW and Time.get_ticks_msec() >= _clip_hold_ms:
			_hold_clip("Run_Start", 0.06)
			return
		elif not moving and playing == run and ground > move_speed * RUN_STOP_ABOVE:
			_hold_clip("Run_Stop", 0.06)
			return
	_play(run_anim if moving else "Idle_Combat")


## Push away from nearby enemies so groups spread out and surround.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self:
			continue
		var away: Vector3 = global_position - e.global_position
		away.y = 0.0
		var d := away.length()
		if d < separation_radius and d > 0.001:
			push += away / d * (1.0 - d / separation_radius)
	return push * 1.5


func _melee_slot_free() -> bool:
	var busy := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.attack_kind == "melee" and e.state == State.WINDUP:
			busy += 1
	return busy < max_melee_attackers


func _state_windup(delta: float) -> void:
	_friction(delta, 30.0)
	var k := clampf(_state_t / attack_windup, 0.0, 1.0)
	_telegraph.visible = true
	_telegraph_mat.albedo_color.a = lerpf(0.15, 0.55, k)
	if attack_kind == "line":
		_track_aim(k)
	else:
		_scale_fill(lerpf(0.3, 1.0, k))
	if _state_t >= attack_windup:
		_telegraph.visible = false
		if attack_kind == "line":
			_shoot_line()
			_attack_cd = randf_range(1.8, 2.8)
		elif is_ranged():
			_shoot()
			_attack_cd = randf_range(1.6, 2.6)
		else:
			_strike()
			_attack_cd = randf_range(0.8, 1.6)
		_set_state(State.RECOVER)


## Strike telemetry for the dash counter (counter.gd, docs/features/counter.md): game seconds until this foe's
## melee strike lands (the windup's end, longer under a chill), or -1 when none is coming. Shots are not strikes.
func strike_in() -> float:
	if state != State.WINDUP or attack_kind != "melee":
		return -1.0
	var slow := chill_mult if chill_t > 0.0 else 1.0
	return maxf(attack_windup - _state_t, 0.0) / maxf(slow, 0.05)


## How far the strike reaches (_strike: its range plus a step).
func strike_reach() -> float:
	return attack_range + STRIKE_PAD


const STRIKE_PAD := 0.6
const STRIKE_MAX_Y := 0.8  # m off the floor past which a strike can't land (lifted by something that isn't a hold)


func _strike() -> void:
	if not is_instance_valid(_player) or held() or global_position.y > STRIKE_MAX_Y:
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	var fwd := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	if to.length() <= attack_range + 0.6 and fwd.angle_to(to.normalized()) < deg_to_rad(70.0):
		_player.take_hit(attack_damage, to.normalized() * 8.0, self)


func _shoot() -> void:
	if not is_instance_valid(_player):
		return
	_play("Spellcast_Shoot", 0.05, 1.5, true)
	var origin := global_position + Vector3.UP * 1.0
	var aim := _player.global_position + Vector3.UP * 1.0 - origin
	aim.y = 0.0
	var p := PROJECTILE.new()
	p.direction = aim.normalized()
	p.speed = projectile_speed
	p.damage = attack_damage
	p.source = self
	get_parent().add_child(p)
	p.global_position = origin + p.direction * 0.8


## Follow the player with the aim line until AIM_LOCK, then hold still;
## the line narrows and brightens as the shot nears.
func _track_aim(k: float) -> void:
	if k < AIM_LOCK and is_instance_valid(_player):
		var to := _player.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			_aim_dir = to.normalized()
	_face(_aim_dir)
	_aim_line.rotation.y = atan2(_aim_dir.x, _aim_dir.z)
	var locked := k >= AIM_LOCK
	_aim_line.scale.x = 0.35 if locked else lerpf(1.6, 0.6, k / AIM_LOCK)
	_telegraph_mat.albedo_color = Color(1.0, 0.2, 0.1, 0.75) if locked else Color(LINE_COLOR, _telegraph_mat.albedo_color.a)


func _shoot_line() -> void:
	_play("2H_Ranged_Shoot", 0.05, 1.2, true)
	Game.sfx("dash", -6.0, 0.1)
	var p := PROJECTILE.new()
	p.direction = _aim_dir
	p.speed = projectile_speed
	p.damage = attack_damage
	p.source = self
	p.color = LINE_COLOR
	p.bolt = true
	p.lifetime = (attack_range + 6.0) / projectile_speed
	get_parent().add_child(p)
	p.global_position = global_position + Vector3.UP * 1.0 + _aim_dir * 0.8


## Stunned and open (e.g. after the player perfect-dodges this enemy's attack).
func chill(time: float, mult: float) -> void:
	if state == State.DEAD:
		return
	if chill_t <= 0.0:
		Fx.burst(get_parent(), global_position + Vector3.UP * 0.8, Color(0.7, 0.92, 1.0), 6, 3.0, 0.12, 0.4, Vector3.UP, 60.0)
	chill_t = maxf(chill_t, time)
	chill_mult = mult


## Encase in ice and stun for `time`; the next hit deals `mult` x damage and breaks it.
func freeze(time: float, mult: float) -> void:
	if state == State.DEAD or state == State.SPAWN:
		return
	stagger(time)
	frozen_t = time
	frozen_mult = mult
	if _ice == null:
		_ice = MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = radius + 0.25
		m.bottom_radius = radius + 0.35
		m.height = 2.0 * model_scale
		_ice.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.65, 0.9, 1.0, 0.45)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.45, 0.6)
		_ice.material_override = mat
		preload("res://scripts/thrown_foe.gd").comic_ice(_ice, radius + 0.2, m.height)  # flat two-tone ice the foe shows through
		add_child(_ice)
		_ice.position.y = m.height * 0.5
	if _lean_tween:  # frozen solid standing up (fx-ice2): a hit's lean would tip it out of its block
		_lean_tween.kill()
	model.rotation.x = 0.0
	model.rotation.z = 0.0
	preload("res://scripts/designed_elements.gd").fit_block(self, _ice)  # the block fitted to the model as it stands
	_ice.visible = true
	_clip_speed(_clip_want)  # (frozen solid: the clip holds until the thaw)
	Game.sfx("cage_shut", -10.0, 0.1)


## Ice ends: on a hit (`shattered`) it bursts into shards.
func _thaw(shattered: bool) -> void:
	frozen_t = 0.0
	_clip_speed(_clip_want)
	if _ice:
		_ice.visible = false
	var cube := get_node_or_null("ThrownCube")  # (thrown_foe.cube_on)
	if cube != null:
		cube.queue_free()
	if shattered:
		Fx.DESIGNED.ice_shatter(get_parent(), global_position + Vector3.UP * 0.9)  # drawn faceted shards
		Game.register_hit("shatter_ice")


func stagger(time: float) -> void:
	if state == State.DEAD or state == State.SPAWN:
		return
	_telegraph.visible = false
	_set_state(State.HURT)
	_state_t = 0.4 - time
	Fx.flash(model)
	_play("Hit_B", 0.05, 0.8, true)


func _on_player_attack(_move_id: String) -> void:
	if state != State.CHASE and state != State.RECOVER:
		return
	if _dodge_cd > 0.0 or randf() >= dodge_chance or not is_instance_valid(_player):
		return
	var away := global_position - _player.global_position
	away.y = 0.0
	if away.length() > 3.5:
		return
	_dodge_cd = dodge_cooldown
	# Hop back and to the side, out of the swing.
	var side := Vector3(-away.z, 0.0, away.x).normalized() * _orbit_side
	var dir := (away.normalized() + side * 0.6).normalized()
	velocity.x = dir.x * 11.0
	velocity.z = dir.z * 11.0
	_set_state(State.DODGE)
	_play("Dodge_Backward", 0.05, 1.8, true)
	Fx.dust(get_parent(), global_position, 6)


## Damage and its number with no sparks, word or flash, for an effect that draws its own: ticks several times
## a second on a whole crowd would bury whatever's holding them. `big` is one solid blow, which does flash.
## A downward `knockback` (Maw's bite) still gets the full reaction (_hit_reaction: the crater), no sparks.
func burn_hit(damage: float, big := false, knockback := Vector3.ZERO) -> void:
	_quiet_hit = true
	take_hit(damage, knockback, 0.0, big)
	_quiet_hit = false
	if big and is_instance_valid(model) and not _is_spike(knockback, 0.0):
		Fx.flash(model)


func take_hit(damage: float, knockback: Vector3, launch: float, big: bool) -> void:
	if state == State.DEAD or state == State.SPAWN or state == State.DODGE:
		return
	if _shield_blocks(knockback, launch, big):
		return
	hits_taken += 1
	if frozen_t > 0.0:
		damage *= frozen_mult
		_thaw(true)
	hp -= damage
	last_hit_ms = Time.get_ticks_msec()
	Fx.damage_number(get_parent(), global_position, damage, big, self)
	if not _quiet_hit:
		Fx.hit_spark(get_parent(), global_position + knockback.normalized() * -0.3, Color(1.0, 0.9, 0.6), Fx.HIT_STAR_BIG if big else Fx.HIT_STAR)
		Fx.impact(get_parent(), global_position, knockback + Vector3.UP * 2.0, big)
		ComicFx.hit(global_position, big)
	var hero := get_tree().get_first_node_in_group("player")
	if hero != null and hero.has_method("_fx_color") and not _quiet_hit:  # long strings escalate the sparks
		Fx.chain_spark(get_parent(), global_position, hero._fx_color(), Fx.chain_tier(Game.combo_count),
			knockback.normalized() + Vector3.UP * 0.5)
	if _quiet_hit and not _is_spike(knockback, launch):  # a burn tick: the pose hold, none of the show
		_freeze_t = hit_freeze_big if big else hit_freeze
		_wave_delay = 0.0
	else:
		_hit_reaction(damage, knockback, launch, big)
	_telegraph.visible = false
	if hp <= 0.0:
		_die(Vector3(knockback.x, maxf(knockback.y, 0.0), knockback.z))  # a slam's kill still pops up and out
		return

	var airborne := state == State.AIRBORNE
	if _is_spike(knockback, launch):
		if airborne or not is_on_floor():  # driven down: it craters on touchdown (_land_from_air)
			velocity = Vector3(knockback.x * 0.4, -SPIKE_SPEED, knockback.z * 0.4)
			_set_state(State.AIRBORNE)
			_play("Hit_B", 0.05, 1.5, true)
			return
		velocity.x = knockback.x * SPIKE_GROUND_SLIDE  # slammed flat where it stands
		velocity.z = knockback.z * SPIKE_GROUND_SLIDE
		_knock_down(SPIKE_LIE)
		_spiked = true
		return
	if launch > 0.0 or airborne:
		# Launched or juggled: keep them floating as long as hits connect.
		velocity = Vector3(knockback.x * 0.4, maxf(launch, 4.5), knockback.z * 0.4)
		_set_state(State.AIRBORNE)
		_play("Hit_B", 0.05, 1.5, true)
		return
	if _poise_holds(knockback, big):
		_poise_hits += 1
		return  # poise held: flinch-free, the attack still lands
	velocity.x = knockback.x
	velocity.z = knockback.z
	_set_state(State.HURT)
	_play("Hit_A" if randf() < 0.5 else "Hit_B", 0.05, 1.6, true)


## Which SQUASH key a hit gets, from the enemy's side: "kill" (hp is already
## down), "spike" / "crater" (a downward hit, in the air / on the floor),
## "launch" (leaving the ground, or re-launched from below while up), "juggle"
## (any other hit while up), "big" / "tap"
## (grounded flinches) or "none" (poise held: it still flashes).
func _reaction_kind(knockback: Vector3, launch: float, big: bool) -> String:
	if hp <= 0.0:
		return "air_kill" if state == State.AIRBORNE else "kill"
	if _is_spike(knockback, launch):
		return "spike" if state == State.AIRBORNE or not is_on_floor() else "crater"
	if state == State.AIRBORNE:
		return "launch" if launch >= RELAUNCH_MIN else "juggle"  # from below: a fresh launch
	if launch > 0.0:
		return "launch"
	if _poise_holds(knockback, big):
		return "none"
	return "big" if big else "tap"


## Every visual reaction to a landed hit, in one place (take_hit calls it once,
## beside the hit sparks, so damage-over-time ticks can skip the lot): the
## freeze, the flash in the hero's colour, the squash and the lean away.
func _hit_reaction(_damage: float, knockback: Vector3, launch: float, big: bool) -> void:
	var kind := _reaction_kind(knockback, launch, big)
	var delay := _wave_slot() * WAVE_STEP
	_wave_delay = delay
	_freeze_t = (KILL_FREEZE if kind in ["kill", "air_kill"] else (hit_freeze_big if big else hit_freeze)) + delay
	if delay <= 0.0:
		_react(kind, knockback, big)
		return
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_react.bind(kind, knockback, big))


## This hit's place in the frame's wave: 0 for the first foe hit this physics
## frame, 1 for the next, ... capped at WAVE_MAX.
func _wave_slot() -> int:
	var f := Engine.get_physics_frames()
	if f != _wave_frame:
		_wave_frame = f
		_wave_n = 0
	else:
		_wave_n += 1
	return mini(_wave_n, WAVE_MAX)


func _react(kind: String, knockback: Vector3, big: bool) -> void:
	Fx.flash_tint(model, _hit_color(), FLASH_BIG if big or kind in ["kill", "air_kill"] else FLASH_TAP)
	if kind == "none":
		return
	if INK.has(kind):
		_ink_pulse(INK[kind])
	_squash(SQUASH[kind])
	match kind:
		"tap":
			_lean(knockback, LEAN)
		"big", "kill":
			_lean(knockback, LEAN_BIG)
		"launch", "juggle":
			_kick_tumble(knockback, big)
			_bounced = false  # every hit that keeps it up earns a bounce on the way down
		"spike":
			_kick_tumble(knockback, true)
		"air_kill":
			_kick_tumble(knockback, true)
			_tumble_v *= AIR_KILL_SPIN
		"crater":
			_crater()


## Swell this foe's outline to `mult` times its width and ease it back.
func _ink_pulse(mult: float) -> void:
	last_ink = mult
	if _ink_mat == null:
		return
	if _ink_tween:
		_ink_tween.kill()
	_ink_mat.set_shader_parameter("width_px", _ink_px * mult)
	_ink_tween = create_tween()
	_ink_tween.tween_method(func(w: float) -> void: _ink_mat.set_shader_parameter("width_px", w),
		_ink_px * mult, _ink_px, INK_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## A downward hit: a negative launch, or knockback pointing into the floor.
static func _is_spike(knockback: Vector3, launch: float) -> bool:
	return launch < 0.0 or knockback.y < 0.0


## Pancaked into the floor: the long squash, a crater mark, dust and a thump.
func _crater() -> void:
	_squash(SQUASH.crater, CRATER_TIME, CRATER_HOLD)
	Fx.crater(get_parent(), global_position, CRATER_RADIUS)
	Fx.dust(get_parent(), global_position, 22, 0.8)
	Game.shake(CRATER_SHAKE)


## The hero's current hit colour (the move's element, gold when Awakened), white
## without a hero (lineups, previews).
func _hit_color() -> Color:
	var hero := get_tree().get_first_node_in_group("player")
	if hero != null and hero.has_method("_fx_color"):
		return Color.WHITE.lerp(hero._fx_color(), FLASH_TINT)
	return Color.WHITE


## Gravity this frame: lighter near a juggle's apex so it hangs there.
func _gravity() -> float:
	if state != State.AIRBORNE:
		return GROUND_GRAVITY
	return AIR_GRAVITY * (HANG_GRAVITY if absf(velocity.y) < HANG_SPEED else 1.0)


## The launch speed that peaks `height` above the floor under _gravity()'s
## profile (a frame's integration lands it a few cm under that).
static func launch_speed_for(height: float) -> float:
	var hang_h := HANG_SPEED * HANG_SPEED / (2.0 * AIR_GRAVITY * HANG_GRAVITY)
	if height <= hang_h:
		return sqrt(2.0 * AIR_GRAVITY * HANG_GRAVITY * maxf(height, 0.0))
	return sqrt(HANG_SPEED * HANG_SPEED + 2.0 * AIR_GRAVITY * (height - hang_h))


## Start (or renew) the tumble: the top goes with the blow. A blow along the
## foe's facing flips it (rotation.x), one across it rolls it (rotation.z).
func _kick_tumble(knockback: Vector3, big: bool) -> void:
	if _lean_tween:
		_lean_tween.kill()
	var flat := Vector3(knockback.x, 0.0, knockback.z)
	var dir := 1.0
	if flat.length_squared() > 0.001:
		_air_dir = flat.normalized()
		var local := Basis(Vector3.UP, model.rotation.y).inverse() * _air_dir
		_tumble_roll = absf(local.x) > absf(local.z) * ROLL_BIAS
		if _tumble_roll:
			dir = -1.0 if local.x >= 0.0 else 1.0  # as _lean's rotation.z = -local.x
		else:
			dir = 1.0 if local.z >= 0.0 else -1.0
	# Drop a leftover lean on the other axis (a turn already under way stays for the landing to settle).
	if _tumble_roll and absf(model.rotation.x) <= LEAN_BIG + 0.01:
		model.rotation.x = 0.0
	elif not _tumble_roll and absf(model.rotation.z) <= LEAN_BIG + 0.01:
		model.rotation.z = 0.0
	_tumble_v = dir * (TUMBLE_BIG if big else TUMBLE_SPEED)


func _tumble(delta: float) -> void:
	if _tumble_v == 0.0:
		return
	if _tumble_roll:
		model.rotation.z += _tumble_v * delta
	else:
		model.rotation.x += _tumble_v * delta
	_tumble_v = move_toward(_tumble_v, 0.0, TUMBLE_DRAG * delta)


## Touching down from a juggle: a spiked fall craters; a hard fall bounces
## once, then it flops flat, rights itself and slides out (HURT with
## _state_t < 0 = lying there).
func _land_from_air() -> void:
	var fall := -_fall_vy
	if fall >= SPIKE_FALL:
		velocity.x = _air_dir.x * fall * SPIKE_SLIDE
		velocity.z = _air_dir.z * fall * SPIKE_SLIDE
		_crater()
		_knock_down(SPIKE_LIE)
		_spiked = true
		return
	if not _bounced and fall >= BOUNCE_MIN_FALL:
		_bounced = true
		velocity.y = fall * BOUNCE_KEEP
		velocity.x = _air_dir.x * fall * LAND_SLIDE
		velocity.z = _air_dir.z * fall * LAND_SLIDE
		_state_t = 0.0
		_squash(SQUASH.bounce)
		Fx.dust(get_parent(), global_position, 8, 0.45)
		return
	Fx.dust(get_parent(), global_position, 14, 0.6)
	Game.shake(0.1)
	_squash(SQUASH.land)
	_knock_down(LIE_TIME)


## Down on the floor: the get-up clip, the tumble settled to the nearest full
## turn on both axes then zeroed, lying `lie` s (HURT with _state_t < 0).
func _knock_down(lie: float) -> void:
	_play("Lie_StandUp", 0.1, 2.0)
	_tumble_v = 0.0
	if _lean_tween:
		_lean_tween.kill()
	_lean_tween = create_tween().set_parallel()
	_lean_tween.tween_property(model, "rotation:x", roundf(model.rotation.x / TAU) * TAU, TUMBLE_SETTLE)
	_lean_tween.tween_property(model, "rotation:z", roundf(model.rotation.z / TAU) * TAU, TUMBLE_SETTLE)
	_lean_tween.chain().tween_callback(func() -> void:
		model.rotation.x = 0.0
		model.rotation.z = 0.0)
	_set_state(State.HURT)
	_state_t = -lie
	_skid_dust_t = 0.0


## The knockdown slide: low friction and a dust puff while it still moves.
func _skid(delta: float) -> void:
	_friction(delta, SPIKE_SKID_FRICTION if _spiked else SKID_FRICTION)
	if Vector2(velocity.x, velocity.z).length() < SKID_MIN_SPEED:
		return
	_skid_dust_t -= delta
	if _skid_dust_t <= 0.0:
		_skid_dust_t = SKID_DUST_EVERY
		Fx.dust(get_parent(), global_position, 2, 0.3)


## Tip the model over along the knockback (the top goes with the blow) and
## spring it back upright. Only the x/z tilt: _face keeps owning the yaw.
func _lean(knockback: Vector3, amount: float) -> void:
	var flat := Vector3(knockback.x, 0.0, knockback.z)
	if flat.length_squared() < 0.001:
		return
	var local := Basis(Vector3.UP, model.rotation.y).inverse() * flat.normalized()
	if _lean_tween:
		_lean_tween.kill()
	model.rotation.x = local.z * amount
	model.rotation.z = -local.x * amount
	_lean_tween = create_tween()
	_lean_tween.tween_interval(LEAN_HOLD)
	_lean_tween.tween_property(model, "rotation:x", 0.0, LEAN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lean_tween.parallel().tween_property(model, "rotation:z", 0.0, LEAN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A corpse killed in the air spins on until it lands, then settles flat.
func _corpse_tumble(delta: float) -> void:
	if _tumble_v == 0.0:
		return
	if not is_on_floor() or _state_t < 0.15:
		_tumble(delta)
		return
	_tumble_v = 0.0
	if _lean_tween:
		_lean_tween.kill()
	_lean_tween = create_tween().set_parallel()
	_lean_tween.tween_property(model, "rotation:x", roundf(model.rotation.x / TAU) * TAU, TUMBLE_SETTLE)
	_lean_tween.tween_property(model, "rotation:z", roundf(model.rotation.z / TAU) * TAU, TUMBLE_SETTLE)


## True if the shield stopped this hit. Big hits/launchers break the guard
## instead (and land).
func _shield_blocks(knockback: Vector3, launch: float, big: bool) -> bool:
	if not shield or _guard_broken_t > 0.0 or (state != State.CHASE and state != State.RECOVER):
		return false
	if knockback.length() < 0.01:
		return false
	var fwd := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	if fwd.dot(knockback.normalized()) > -0.3:
		return false  # from the side or behind
	var shield_pos := global_position + Vector3.UP * 1.0 + fwd * 0.6 * model_scale
	if big or launch > 0.0:
		_guard_broken_t = SHIELD_BREAK_TIME
		Fx.ring(get_parent(), global_position, Color(1.0, 0.85, 0.3, 0.9), 2.2, 0.3)
		Fx.burst(get_parent(), shield_pos, Color(1.0, 0.85, 0.4), 18, 8.0, 0.14, 0.35, -knockback.normalized(), 70.0)
		Game.announced.emit("GUARD BREAK")
		return false
	blocks += 1
	if comic_kind != "":
		_hold_clip("Block_Hit", 0.05)
	Fx.hit_spark(get_parent(), shield_pos, Color(0.7, 0.85, 1.0), 0.8)
	Game.sfx("hit", -6.0, 0.3)
	Game.hitstop(0.03)
	velocity.x = knockback.x * 0.4
	velocity.z = knockback.z * 0.4
	_squash(Vector3(1.08, 0.94, 1.08))
	return true


## Torn off for good. True if there was one.
func rip_shield() -> bool:
	if not shield:
		return false
	shield = false
	Game.announced.emit("GUARD BREAK")
	return true


func _die(knockback: Vector3) -> void:
	_set_state(State.DEAD)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3(knockback.x * 1.3, 4.0, knockback.z * 1.3)
	_play("Death_A", 0.05, 1.4, true)
	var pop := func() -> void:
		Fx.death(get_parent(), global_position, knockback, false, Color(0.93, 0.89, 0.78))
	if _wave_delay > 0.0:  # a crowd killed by one blow pops one after another, as its reactions do
		create_tween().tween_callback(pop).set_delay(_wave_delay)
	else:
		pop.call()
	Game.add_awakening(4.0)
	Game.sfx("enemy_death", -2.0, 0.15)
	died.emit(self)
	Game.enemy_killed.emit(self)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(func() -> void: Fx.soul(get_parent(), global_position))
	tw.tween_property(model, "position:y", -1.5, 0.6)
	tw.tween_callback(queue_free)


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.25)


func _friction(delta: float, amount: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, amount * delta)
	velocity.z = move_toward(velocity.z, 0.0, amount * delta)


## Poise holds a windup through a hit: a light one (knockback under `poise`), not a big one, and not the
## POISE_HITS-th of this windup (spar audit 2026-11-07: the warrior's poise 8 held through every zero-knockback element
## hit, big ones too, so a whole string landed on it and its strike still hit him).
func _poise_holds(knockback: Vector3, big: bool) -> bool:
	return state == State.WINDUP and knockback.length() < poise and not big and _poise_hits + 1 < POISE_HITS


const POISE_HITS := 3  # the hit of one windup that breaks poise
var _poise_hits := 0  # hits poise held through in this windup


func _set_state(s: State) -> void:
	if state == State.WINDUP and s != State.RECOVER and s != State.WINDUP:
		_windup_broke_t = 0.0  # (HOLD_CUT_GRACE)
	state = s
	_state_t = 0.0
	_poise_hits = 0
	_spiked = false  # the crater paths set it again after their _knock_down


func _play(anim_name: String, blend := 0.15, speed := 1.0, restart := false) -> void:
	if comic_kind != "":
		if anim_name in [run_anim, "Idle_Combat"] and Time.get_ticks_msec() < _clip_hold_ms:
			return
		anim_name = ComicLook.clip(anim, comic_kind, anim_name)
		if anim_name == "":
			return  # the clip already playing covers this beat
	if anim.current_animation == anim_name and not restart:
		return
	anim.play(anim_name, blend, 1.0)
	if restart:
		anim.seek(0.0, true)
	_clip_speed(speed)  # (applied when the hit freeze ends; held at 0 while frozen in ice)


## Comic clips the state machine would otherwise replace next frame with run/idle.
func _hold_clip(anim_name: String, blend := 0.1, speed := 1.0) -> void:
	_play(anim_name, blend, speed, true)
	_clip_hold_ms = Time.get_ticks_msec() + int(anim.get_animation(anim_name).length / speed * 1000.0)


## Run start / stop one-shots (_play_locomotion), as the hero's (player.gd RUN_START_BELOW / RUN_STOP_ABOVE).
const RUN_START_BELOW := 0.3
const RUN_STOP_ABOVE := 0.6
const RUN_START_DIR := 0.6  # a full run, not the slow circling at 0.4 of move speed
## Turn lean (scripts/foe_lean.gd on the skeleton): degrees per m/s of velocity change across its facing,
## per kind; the fast ones only.
const TURN_LEAN := {"rogue": 3.5, "minion": 3.0}

## Clip speed range for the run matched to the ground (run_foot_speed).
## The runs are keyed for move_speed at 1x (round 38, foe_keys.py), so at full speed this is ~1;
## the floor lets a foe circling at 0.4 of its speed slow its feet too.
const RUN_CLIP_SPEED_MIN := 0.35
const RUN_CLIP_SPEED_MAX := 1.6


## The run clip's speed that keeps planted feet on the floor at `ground` m/s.
func run_clip_speed(ground: float) -> float:
	if run_foot_speed <= 0.0:
		return 1.0
	return clampf(ground / (run_foot_speed * model_scale), RUN_CLIP_SPEED_MIN, RUN_CLIP_SPEED_MAX)


## Speed of the clip already playing, respecting a running hit freeze.
func _clip_speed(speed: float) -> void:
	_clip_want = speed
	if frozen_t > 0.0:  # frozen in ice: the pose holds (the block was fitted to it)
		speed = 0.0
	if _frozen_speed >= 0.0:
		_frozen_speed = speed
	else:
		anim.speed_scale = speed


## Snap the model to `amount` (per-axis scale), hold it `hold` s and spring back over `time`.
func _squash(amount: Vector3, time := SQUASH_TIME, hold := 0.0) -> void:
	if _squash_tween:
		_squash_tween.kill()
	last_squash = amount
	model.scale = amount * model_scale
	_squash_tween = create_tween()
	if hold > 0.0:
		_squash_tween.tween_interval(hold)
	_squash_tween.tween_property(model, "scale", Vector3.ONE * model_scale, time) 		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Telegraph rim (Fx.edge_ring): pulses faster as the windup runs out.
const EDGE_PULSE_HZ := Vector2(3.0, 9.0)  # pulses/s at windup start, end


func _build_edge(r: float) -> void:
	_edge = Fx.edge_ring(r)
	_telegraph.add_child(_edge)


## Grow the telegraph's fill to `s` of the reach while the rim stays at full
## reach the whole windup: the hit lands when the fill meets the rim.
func _scale_fill(s: float) -> void:
	_telegraph.scale = Vector3.ONE * s
	if _edge:
		_edge.scale = Vector3(1.0 / s, 0.3 / s, 1.0 / s)  # edge_ring's own scale is (1, 0.3, 1)


func _pulse_edge(delta: float) -> void:
	var k := clampf(_state_t / maxf(attack_windup, 0.01), 0.0, 1.0) if state == State.WINDUP else 1.0
	_edge_t += delta * lerpf(EDGE_PULSE_HZ.x, EDGE_PULSE_HZ.y, k)
	Fx.pulse_edge(_edge, _telegraph_mat.albedo_color, _edge_t)


func _build_telegraph() -> void:
	_telegraph = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	# Melee rings show the reach; shooters get a small ring at their feet.
	var r := 1.1 if is_ranged() else attack_range + 0.3
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = 0.02
	_telegraph_mat = StandardMaterial3D.new()
	_telegraph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_mat.albedo_color = Color(0.7, 0.3, 1.0, 0.3) if attack_kind == "ranged" else Color(1.0, 0.15, 0.1, 0.3)
	mesh.material = _telegraph_mat
	_telegraph.mesh = mesh
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph.position.y = 0.08
	_telegraph.visible = false
	add_child(_telegraph)
	_build_edge(r)
	if attack_kind == "line":
		_telegraph_mat.albedo_color = Color(LINE_COLOR, 0.3)
		# Long strip along the shot (pivot at the archer; rotated in _track_aim).
		_aim_line = Node3D.new()
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		var length := attack_range + 4.0
		box.size = Vector3(0.5, 0.02, length)
		box.material = _telegraph_mat
		strip.mesh = box
		strip.position.z = length * 0.5 + 0.6
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_aim_line.add_child(strip)
		_telegraph.add_child(_aim_line)
