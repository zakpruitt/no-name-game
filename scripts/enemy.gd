extends CharacterBody3D
## Skeleton enemy: spawns from the ground, chases (melee) or keeps its
## distance and fires bolts (ranged) or crossbow shots (line), telegraphs
## every attack, staggers when hit (unless its poise holds), and can be
## launched/juggled.

signal died(enemy: Node)
signal raise_requested(enemy: Node)

enum State { SPAWN, CHASE, WINDUP, RECOVER, HURT, AIRBORNE, DODGE, DEAD }

const LOOPING := ["Idle_Combat", "Running_A", "Walking_D_Skeletons", "Running_C", "Spellcasting"]
const PROJECTILE := preload("res://scripts/projectile.gd")

@export var model_scene: PackedScene
## ComicLook model name when model_scene is a comic GLB ("" = KayKit, nothing changes).
var comic_kind := ""
var _clip_hold_ms := 0  # comic: run/idle don't replace a held clip until then (_hold_clip)
@export var max_hp := 30.0
@export var move_speed := 3.6
@export var attack_range := 1.9
@export var attack_damage := 10.0
@export var attack_windup := 0.6
@export var attack_recover := 0.7
## Knockback below this doesn't stagger (0 = always staggers).
@export var poise := 0.0
@export var model_scale := 1.0
@export var run_anim := "Running_A"
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
## Elite: tougher, bigger, gold aura, and pays out extra Awakening on death.
@export var elite := false
## Bone shards dropped on death (elites drop ELITE_BONES_MULT times as many).
@export var bones := 1
const ELITE_BONES_MULT := 3
const ELITE_HP_MULT := 2.5
const ELITE_DAMAGE_MULT := 1.4
const ELITE_SCALE_MULT := 1.3
const ELITE_POISE_BONUS := 6.0
const ELITE_AWAKEN_BONUS := 15.0
## Shield bearer: blocks hits from the front while walking/recovering (not
## while attacking). Big hits and launchers break the guard for a while;
## hits from the side or behind always land.
@export var shield := false
const SHIELD_SCENE := preload("res://assets/kaykit/props/Skeleton_Shield_Large_A.gltf")
const SHIELD_BREAK_TIME := 2.0
## Crossbow archer (attack_kind "line").
const CROSSBOW_SCENE := preload("res://assets/kaykit/props/Skeleton_Crossbow.gltf")
const AIM_LOCK := 0.7
const LINE_COLOR := Color(1.0, 0.55, 0.15)
## Flat colour for the model's hood/cape/cloak meshes (alpha 0 = keep the
## texture). Lets types that share a model read differently (archer vs rogue).
@export var cloth_color := Color(0, 0, 0, 0)
## Multiplies every surface's colour (white = untouched); bombers are scorched.
@export var body_tint := Color.WHITE
const CLOTH_MESHES := ["Hood", "Cape", "Cloak", "Hat"]
## Bomber (attack_kind "bomb"): walks up and lights a fuse (attack_windup s,
## orange ring = blast_radius). The fuse keeps burning through hits and
## launches, so knock it into a crowd: the blast hurts the hero and skeletons
## alike. Killed while lit, it blows up on the spot (chains into other bombs).
@export var blast_radius := 3.2
@export var blast_enemy_damage := 40.0
@export var blast_enemy_launch := 7.0
const BOMB_COLOR := Color(1.0, 0.5, 0.1)
var _fuse := -1.0  # seconds left once lit; < 0 = not lit
## Volatile (elite room twist): bursts VOLATILE_DELAY s after dying, with a
## smaller blast_radius and much less damage to other skeletons; the ring warns where.
var volatile := false
const VOLATILE_DELAY := 0.7
const VOLATILE_RADIUS := 2.4
const VOLATILE_ENEMY_DAMAGE := 12.0  # to other skeletons (bombers do blast_enemy_damage)
const VOLATILE_ENEMY_LAUNCH := 0.0  # stagger only; a launch left crowds helpless
var _spark: MeshInstance3D
## Necromancer (attack_kind "raise"): hangs back and raises up to raise_count
## fallen minions (main.gd keeps the graves; `can_raise` asks it whether any
## are near). With none to raise it shoots a bolt like a mage.
@export var raise_count := 2
@export var raise_cooldown := 5.0
const RAISE_COLOR := Color(0.45, 1.0, 0.4)
var can_raise: Callable
var _raising := false
## Seconds this enemy alone freezes on hit (on top of global hitstop).
@export var hit_freeze := 0.06
@export var hit_freeze_big := 0.11
# Hit reactions (_hit_reaction, the one place every visual reaction to a hit
# lives): the model snaps to SQUASH[kind] (x, y, z scale) and springs back,
# leans away along the knockback (LEAN rad, LEAN_BIG on big hits, back over
# LEAN_TIME) and flashes in the hero's hit colour mixed FLASH_TINT toward it
# (FLASH_TAP / FLASH_BIG s). A kill holds the corpse's last pose KILL_FREEZE s
# before it flies (longer than hit_freeze_big: the pop reads).
const SQUASH := {
	"tap": Vector3(1.15, 0.87, 1.15),
	"big": Vector3(1.32, 0.7, 1.32),
	"launch": Vector3(0.72, 1.45, 0.72),  # stretched tall as it leaves the ground
	"juggle": Vector3(1.2, 0.84, 1.2),  # a sharp snap on each hit that keeps it up
	"kill": Vector3(1.4, 0.6, 1.4),
	"land": Vector3(1.35, 0.65, 1.35),  # flattened on the floor
	"bounce": Vector3(0.9, 1.15, 0.9),
}
const LEAN := 0.2
const LEAN_BIG := 0.42
const LEAN_TIME := 0.35
const FLASH_TAP := 0.07
const FLASH_BIG := 0.12
const FLASH_TINT := 0.55
const KILL_FREEZE := 0.14
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

static var dodges := 0  # running count, reported by the autotest
static var _wave_frame := -1  # physics frame of the last hit taken by any enemy, and
static var _wave_n := 0  # how many took one that frame (_wave_slot)
static var blocks := 0
static var blasts := 0

var radius := 0.55
var hp := 0.0
var last_hit_ms := -100000  # when damage last landed (health bar, enemy_bars.gd)
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
var _glow_mat: ShaderMaterial  # set_glow() rim, kept on through hit flashes
var _glow_meshes: Array[Node] = []
var _attack_cd := 0.0
var _freeze_t := 0.0
# Water Ascendancy: chilled foes move and act at chill_mult speed; frozen ones
# are encased (stunned) and the next hit shatters the ice for frozen_mult damage.
var chill_t := 0.0
var chill_mult := 1.0
var chill_hits := 0
var frozen_t := 0.0
var frozen_mult := 1.0
var _ice: MeshInstance3D
var _frozen_speed := -1.0
var _squash_tween: Tween
var last_squash := Vector3.ONE  # the last _squash() amount (enemy_feel_check reads it)
var _lean_tween: Tween
var _fall_vy := 0.0  # last in-air vertical speed (the landing frame has already zeroed velocity.y)
var _bounced := false
var _tumble_v := 0.0  # rad/s around the model's side axis while airborne
var _air_dir := Vector3.ZERO  # the launch's horizontal direction (the knockdown skates along it)
var _skid_dust_t := 0.0
var _orbit_side := 1.0
var _dodge_cd := 0.0
var _guard_broken_t := 0.0
var _shield_node: Node3D
var _aim_dir := Vector3.FORWARD
var _aim_line: Node3D


func _ready() -> void:
	if elite:
		bones *= ELITE_BONES_MULT
		max_hp *= ELITE_HP_MULT
		attack_damage *= ELITE_DAMAGE_MULT
		model_scale *= ELITE_SCALE_MULT
		poise += ELITE_POISE_BONUS
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
		ComicLook.fit(model, comic_kind)
		ComicLook.apply(model, comic_kind)
	if shield and comic_kind == "":
		_attach_shield()
	if body_tint != Color.WHITE and comic_kind == "":
		_tint_body()
	if cloth_color.a > 0.0 and comic_kind == "":
		_tint_cloth()
	if attack_kind == "bomb":
		_attach_bomb()
	if attack_kind == "line" and comic_kind == "":
		var bow: Node3D = CROSSBOW_SCENE.instantiate()
		bow.rotation_degrees.y = 90.0  # point down the aim
		_attach_to_hand("handslot.r", bow)
	Fx.outline(model)
	anim = model.find_child("AnimationPlayer", true, false)
	for a in LOOPING:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR

	_build_telegraph()
	if elite:
		_build_elite_aura()
	_player = get_tree().get_first_node_in_group("player")
	if dodge_chance > 0.0 and _player:
		_player.attack_started.connect(_on_player_attack)
	_attack_cd = randf_range(0.2, 1.0)
	_orbit_side = 1.0 if randf() < 0.5 else -1.0
	_play("Spawn_Ground_Skeletons", 0.0, 1.6)
	Game.sfx("spawn", -10.0, 0.2)


## Shoots from a distance (doesn't need a melee slot).
func is_ranged() -> bool:
	return attack_kind in ["ranged", "line", "raise"]


func fuse_left() -> float:
	return _fuse


## Targetable: spawned, not dead, and not mid-dodge.
func is_alive() -> bool:
	return state != State.DEAD and state != State.SPAWN and state != State.DODGE


func is_airborne() -> bool:
	return state == State.AIRBORNE


func _physics_process(delta: float) -> void:
	if _telegraph.visible:
		_pulse_edge(delta)
	# Fx.flash clears overlays on hit; put the glow back afterwards.
	if _glow_mat != null:
		for mi: MeshInstance3D in _glow_meshes:
			if is_instance_valid(mi) and mi.material_overlay == null:
				mi.material_overlay = _glow_mat
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
	_state_t += delta * slow
	_attack_cd -= delta
	_dodge_cd -= delta
	_guard_broken_t -= delta
	if _fuse >= 0.0 and state != State.DEAD:
		_burn_fuse(delta)
	velocity.y -= _gravity() * delta
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	else:
		_fall_vy = velocity.y

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
	if attack_kind == "bomb":
		if d <= attack_range and _fuse < 0.0:
			_light_fuse()
	elif d <= attack_range and _attack_cd <= 0.0 and (is_ranged() or _melee_slot_free()):
		_set_state(State.WINDUP)
		_aim_dir = to / maxf(d, 0.001)
		_raising = attack_kind == "raise" and can_raise.is_valid() and can_raise.call(self)
		if attack_kind == "raise":
			var c := RAISE_COLOR if _raising else Color(0.7, 0.3, 1.0)
			_telegraph_mat.albedo_color = Color(c, _telegraph_mat.albedo_color.a)
		if attack_kind == "line":
			_play("2H_Ranged_Aiming", 0.1)
			Game.sfx("swing", -12.0, 0.15)
		elif _raising:
			_play("Spellcasting", 0.1, 0.8)
		elif is_ranged():
			_play("Spellcasting", 0.1, 1.2)
		else:
			_play("1H_Melee_Attack_Chop", 0.1, anim.get_animation("1H_Melee_Attack_Chop").length * 0.45 / attack_windup)
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
		elif _raising:
			_play("Spellcast_Summon", 0.05, 1.2, true)
			raise_requested.emit(self)
			_attack_cd = raise_cooldown
		elif is_ranged():
			_shoot()
			_attack_cd = randf_range(1.6, 2.6)
		else:
			_strike()
			_attack_cd = randf_range(0.8, 1.6)
		_set_state(State.RECOVER)


func _strike() -> void:
	if not is_instance_valid(_player):
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
		add_child(_ice)
		_ice.position.y = m.height * 0.5
	_ice.visible = true
	Game.sfx("cage_shut", -10.0, 0.1)


## Ice ends: on a hit (`shattered`) it bursts into shards.
func _thaw(shattered: bool) -> void:
	frozen_t = 0.0
	if _ice:
		_ice.visible = false
	var cube := get_node_or_null("ThrownCube")  # (thrown_foe.cube_on)
	if cube != null:
		cube.queue_free()
	if shattered:
		Fx.burst(get_parent(), global_position + Vector3.UP * 0.9, Color(0.75, 0.95, 1.0), 16, 7.0, 0.14, 0.35, Vector3.UP, 90.0)
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
	dodges += 1
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
func burn_hit(damage: float, big := false) -> void:
	_quiet_hit = true
	take_hit(damage, Vector3.ZERO, 0.0, big)
	_quiet_hit = false
	if big and is_instance_valid(model):
		Fx.flash(model)


func take_hit(damage: float, knockback: Vector3, launch: float, big: bool) -> void:
	if state == State.DEAD or state == State.SPAWN or state == State.DODGE:
		return
	if _shield_blocks(knockback, launch, big):
		return
	if frozen_t > 0.0:
		damage *= frozen_mult
		_thaw(true)
	hp -= damage
	last_hit_ms = Time.get_ticks_msec()
	Fx.damage_number(get_parent(), global_position, damage, big)
	if not _quiet_hit:
		Fx.hit_spark(get_parent(), global_position + knockback.normalized() * -0.3, Color(1.0, 0.9, 0.6), 1.3 if big else 0.9)
		Fx.impact(get_parent(), global_position, knockback + Vector3.UP * 2.0, big)
		ComicFx.hit(global_position, big)
	var hero := get_tree().get_first_node_in_group("player")
	if hero != null and hero.has_method("_fx_color") and not _quiet_hit:  # long strings escalate the sparks
		Fx.chain_spark(get_parent(), global_position, hero._fx_color(), Fx.chain_tier(Game.combo_count),
			knockback.normalized() + Vector3.UP * 0.5)
	if _quiet_hit:  # a burn tick: the pose hold, none of the show
		_freeze_t = hit_freeze_big if big else hit_freeze
	else:
		_hit_reaction(damage, knockback, launch, big)
	_telegraph.visible = false
	if hp <= 0.0:
		_die(knockback)
		return

	var airborne := state == State.AIRBORNE
	if launch > 0.0 or airborne:
		# Launched or juggled: keep them floating as long as hits connect.
		velocity = Vector3(knockback.x * 0.4, maxf(launch, 4.5), knockback.z * 0.4)
		_set_state(State.AIRBORNE)
		_play("Hit_B", 0.05, 1.5, true)
		return
	if knockback.length() < poise and state == State.WINDUP:
		return  # poise held: flinch-free, the attack still lands
	velocity.x = knockback.x
	velocity.z = knockback.z
	_set_state(State.HURT)
	_play("Hit_A" if randf() < 0.5 else "Hit_B", 0.05, 1.6, true)


## Which SQUASH key a hit gets, from the enemy's side: "kill" (hp is already
## down), "launch" (leaving the ground), "juggle" (hit while up), "big" / "tap"
## (grounded flinches) or "none" (poise held: it still flashes).
func _reaction_kind(knockback: Vector3, launch: float, big: bool) -> String:
	if hp <= 0.0:
		return "kill"
	if state == State.AIRBORNE:
		return "juggle"
	if launch > 0.0:
		return "launch"
	if knockback.length() < poise and state == State.WINDUP:
		return "none"
	return "big" if big else "tap"


## Every visual reaction to a landed hit, in one place (take_hit calls it once,
## beside the hit sparks, so damage-over-time ticks can skip the lot): the
## freeze, the flash in the hero's colour, the squash and the lean away.
func _hit_reaction(_damage: float, knockback: Vector3, launch: float, big: bool) -> void:
	var kind := _reaction_kind(knockback, launch, big)
	var delay := _wave_slot() * WAVE_STEP
	_freeze_t = (KILL_FREEZE if kind == "kill" else (hit_freeze_big if big else hit_freeze)) + delay
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
	Fx.flash_tint(model, _hit_color(), FLASH_BIG if big or kind == "kill" else FLASH_TAP)
	if kind == "none":
		return
	_squash(SQUASH[kind])
	match kind:
		"tap":
			_lean(knockback, LEAN)
		"big", "kill":
			_lean(knockback, LEAN_BIG)
		"launch", "juggle":
			_kick_tumble(knockback, big)
			_bounced = false  # every hit that keeps it up earns a bounce on the way down


## The hero's current hit colour (element, Ascendancy when Awakened), white
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


## Start (or renew) the backwards tumble: the top goes with the blow.
func _kick_tumble(knockback: Vector3, big: bool) -> void:
	if _lean_tween:
		_lean_tween.kill()
	model.rotation.z = 0.0
	var flat := Vector3(knockback.x, 0.0, knockback.z)
	var dir := 1.0
	if flat.length_squared() > 0.001:
		_air_dir = flat.normalized()
		var local := Basis(Vector3.UP, model.rotation.y).inverse() * _air_dir
		dir = 1.0 if local.z >= 0.0 else -1.0
	_tumble_v = dir * (TUMBLE_BIG if big else TUMBLE_SPEED)


func _tumble(delta: float) -> void:
	if _tumble_v == 0.0:
		return
	model.rotation.x += _tumble_v * delta
	_tumble_v = move_toward(_tumble_v, 0.0, TUMBLE_DRAG * delta)


## Touching down from a juggle: a hard fall bounces once, then it flops flat,
## rights itself and slides out (HURT with _state_t < 0 = lying there).
func _land_from_air() -> void:
	var fall := -_fall_vy
	if not _bounced and fall >= BOUNCE_MIN_FALL:
		_bounced = true
		velocity.y = fall * BOUNCE_KEEP
		velocity.x = _air_dir.x * fall * LAND_SLIDE
		velocity.z = _air_dir.z * fall * LAND_SLIDE
		_state_t = 0.0
		_squash(SQUASH.bounce)
		Fx.dust(get_parent(), global_position, 8, 0.45)
		return
	_play("Lie_StandUp", 0.1, 2.0)
	Fx.dust(get_parent(), global_position, 14, 0.6)
	Game.shake(0.1)
	_squash(SQUASH.land)
	_tumble_v = 0.0
	if _lean_tween:
		_lean_tween.kill()
	_lean_tween = create_tween()
	_lean_tween.tween_property(model, "rotation:x", roundf(model.rotation.x / TAU) * TAU, TUMBLE_SETTLE)
	_lean_tween.tween_callback(func() -> void: model.rotation.x = 0.0)
	_set_state(State.HURT)
	_state_t = -0.35  # lying on the ground a bit longer
	_skid_dust_t = 0.0


## The knockdown slide: low friction and a dust puff while it still moves.
func _skid(delta: float) -> void:
	_friction(delta, SKID_FRICTION)
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
	_lean_tween = create_tween().set_parallel()
	_lean_tween.tween_property(model, "rotation:x", 0.0, LEAN_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_lean_tween.tween_property(model, "rotation:z", 0.0, LEAN_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Fall apart on the spot (e.g. when the boss that summoned it dies).
func crumble() -> void:
	if state != State.DEAD:
		_die(Vector3.ZERO)


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


func _attach_shield() -> void:
	var s: Node3D = SHIELD_SCENE.instantiate()
	s.rotation_degrees.y = 90.0  # face forward instead of edge-on
	_attach_to_hand("handslot.l", s)
	_shield_node = s


## Torn off for good. True if there was one.
func rip_shield() -> bool:
	if not shield:
		return false
	shield = false
	if is_instance_valid(_shield_node):
		_shield_node.visible = false
	Game.announced.emit("GUARD BREAK")
	return true


func _tint_body() -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i).duplicate() as StandardMaterial3D
			if mat:
				mat.albedo_color *= body_tint
				mi.set_surface_override_material(i, mat)


func _tint_cloth() -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not CLOTH_MESHES.any(func(part: String) -> bool: return part in mi.name):
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i).duplicate() as StandardMaterial3D
			if mat:
				mat.albedo_texture = null
				mat.albedo_color = cloth_color
				mi.set_surface_override_material(i, mat)


func _attach_to_hand(bone: String, item: Node3D) -> void:
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var hand := BoneAttachment3D.new()
	hand.bone_name = bone
	skel.add_child(hand)
	hand.add_child(item)


func _attach_bomb() -> void:
	if comic_kind != "":
		_attach_comic_spark()
		return
	var bomb := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.36
	ball.height = 0.72
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.1, 0.12)
	mat.roughness = 0.4
	ball.material = mat
	bomb.mesh = ball
	_spark = MeshInstance3D.new()
	var tip := SphereMesh.new()
	tip.radius = 0.08
	tip.height = 0.16
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = BOMB_COLOR
	tip.material = glow
	_spark.mesh = tip
	_spark.position.y = 0.4
	_spark.scale = Vector3.ONE * 0.6  # a smoulder until lit
	bomb.add_child(_spark)
	_attach_to_hand("handslot.r", bomb)


## The comic bomber carries its own bomb; only the fuse's spark is live.
func _attach_comic_spark() -> void:
	_spark = MeshInstance3D.new()
	var tip := SphereMesh.new()
	tip.radius = 0.08
	tip.height = 0.16
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = BOMB_COLOR
	tip.material = glow
	_spark.mesh = tip
	_spark.scale = Vector3.ONE * 0.6
	_attach_to_hand("spark", _spark)


func _light_fuse() -> void:
	if comic_kind != "":
		_hold_clip("Bomb_Windup", 0.1, anim.get_animation("Bomb_Windup").length / attack_windup)
	_fuse = attack_windup
	_spark.visible = true
	_telegraph.visible = true
	_scale_fill(1.0)
	Game.sfx("swing", -10.0, 0.2)


## Flash the ring (faster near the end) and keep chasing until it blows.
func _burn_fuse(delta: float) -> void:
	_fuse -= delta
	var k := 1.0 - _fuse / attack_windup
	_telegraph.visible = true
	_telegraph_mat.albedo_color.a = 0.15 + 0.4 * absf(sin(k * k * 30.0))
	_spark.scale = Vector3.ONE * randf_range(0.8, 1.6)
	if _fuse <= 0.0:
		_die(Vector3.ZERO)


func _volatile_pop() -> void:
	blast_radius = VOLATILE_RADIUS
	blast_enemy_damage = VOLATILE_ENEMY_DAMAGE
	blast_enemy_launch = VOLATILE_ENEMY_LAUNCH
	var warn := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = blast_radius
	disc.bottom_radius = blast_radius
	disc.height = 0.02
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(BOMB_COLOR, 0.15)
	disc.material = mat
	warn.mesh = disc
	warn.top_level = true
	warn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(warn)
	warn.global_position = Vector3(global_position.x, 0.08, global_position.z)
	create_tween().tween_property(mat, "albedo_color:a", 0.5, VOLATILE_DELAY)
	await get_tree().create_timer(VOLATILE_DELAY, false).timeout
	warn.queue_free()
	_blast()


func _blast() -> void:
	blasts += 1
	_telegraph.visible = false
	if _spark:
		_spark.visible = false
	var at := global_position
	Game.shake(0.5)
	Game.sfx("hit_big", 0.0, 0.1)
	Fx.ring(get_parent(), at, Color(BOMB_COLOR, 0.9), blast_radius, 0.35)
	Fx.burst(get_parent(), at + Vector3.UP * 0.5, BOMB_COLOR, 30, 10.0, 0.18, 0.4, Vector3.UP, 120.0)
	Fx.dust(get_parent(), at, 20, 1.4)
	if is_instance_valid(_player) and not _player.is_dead():
		var to: Vector3 = _player.global_position - at
		to.y = 0.0
		if to.length() <= blast_radius:
			var who: String = _player._describe_attacker(self)
			_player.take_hit(attack_damage, to.normalized() * 10.0, self,
				("%s's blast" if attack_kind == "bomb" else "%s's dying burst") % who)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - at
		to.y = 0.0
		if e != self and e.is_alive() and to.length() <= blast_radius:
			e.take_hit(blast_enemy_damage, to.normalized() * 6.0, blast_enemy_launch, true)
			Game.register_hit("bomb")


func _die(knockback: Vector3) -> void:
	if _fuse >= 0.0:
		_fuse = -1.0
		remove_from_group("enemies")  # so chained blasts don't hit it again
		_blast()
	elif volatile:
		_volatile_pop()
	_set_state(State.DEAD)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3(knockback.x * 1.3, 4.0, knockback.z * 1.3)
	_play("Death_A", 0.05, 1.4, true)
	Fx.death(get_parent(), global_position, knockback, elite, Color(1.0, 0.85, 0.45) if elite else Color(0.93, 0.89, 0.78))
	Game.add_awakening(4.0 + (ELITE_AWAKEN_BONUS if elite else 0.0))
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


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0


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
	if _frozen_speed >= 0.0:
		_frozen_speed = speed  # applied when the hit freeze ends
	else:
		anim.speed_scale = speed


## Comic clips the state machine would otherwise replace next frame with run/idle.
func _hold_clip(anim_name: String, blend := 0.1, speed := 1.0) -> void:
	_play(anim_name, blend, speed, true)
	_clip_hold_ms = Time.get_ticks_msec() + int(anim.get_animation(anim_name).length / speed * 1000.0)


## Speed of the clip already playing, respecting a running hit freeze.
func _clip_speed(speed: float) -> void:
	if _frozen_speed >= 0.0:
		_frozen_speed = speed
	else:
		anim.speed_scale = speed


## Snap the model to `amount` (per-axis scale) and spring back.
func _squash(amount: Vector3) -> void:
	if _squash_tween:
		_squash_tween.kill()
	last_squash = amount
	model.scale = amount * model_scale
	_squash_tween = create_tween()
	_squash_tween.tween_property(model, "scale", Vector3.ONE * model_scale, 0.3) 		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A coloured rim glow over the whole model (e.g. split minions).
func set_glow(color: Color) -> void:
	_glow_mat = Fx.rim_material().duplicate()
	_glow_mat.set_shader_parameter("glow_color", color)
	_glow_meshes = model.find_children("*", "MeshInstance3D", true, false)


func _build_elite_aura() -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.75
	mesh.outer_radius = 0.95
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.8)
	mesh.material = mat
	ring.mesh = mesh
	ring.scale = Vector3(1.0, 0.05, 1.0) * model_scale
	ring.position.y = 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var pulse := ring.create_tween().set_loops()
	pulse.tween_property(mat, "albedo_color:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(mat, "albedo_color:a", 0.85, 0.6).set_trans(Tween.TRANS_SINE)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.3)
	light.light_energy = 1.2
	light.omni_range = 3.5
	light.position.y = 1.4
	add_child(light)


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


## Match the rim to a ring of radius r (boss.gd resizes its telegraph).
func fit_edge(r: float) -> void:
	Fx.fit_edge(_edge, r)


func _pulse_edge(delta: float) -> void:
	var k := clampf(_state_t / maxf(attack_windup, 0.01), 0.0, 1.0) if state == State.WINDUP else 1.0
	_edge_t += delta * lerpf(EDGE_PULSE_HZ.x, EDGE_PULSE_HZ.y, k)
	Fx.pulse_edge(_edge, _telegraph_mat.albedo_color, _edge_t)


func _build_telegraph() -> void:
	_telegraph = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	# Melee rings show the reach; shooters get a small ring at their feet.
	var r := 1.1 if is_ranged() else attack_range + 0.3
	if attack_kind == "bomb":
		r = blast_radius
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = 0.02
	_telegraph_mat = StandardMaterial3D.new()
	_telegraph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_mat.albedo_color = Color(0.7, 0.3, 1.0, 0.3) if attack_kind in ["ranged", "raise"] else Color(1.0, 0.15, 0.1, 0.3)
	if attack_kind == "bomb":
		_telegraph_mat.albedo_color = Color(BOMB_COLOR, 0.3)
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
