extends CharacterBody3D
## Skeleton enemy: spawns from the ground, chases (melee) or keeps its
## distance and fires bolts (ranged), telegraphs every attack, staggers when
## hit (unless its poise holds), and can be launched/juggled.

signal died(enemy: Node)

enum State { SPAWN, CHASE, WINDUP, RECOVER, HURT, AIRBORNE, DODGE, DEAD }

const LOOPING := ["Idle_Combat", "Running_A", "Walking_D_Skeletons", "Running_C", "Spellcasting"]
const PROJECTILE := preload("res://scripts/projectile.gd")

@export var model_scene: PackedScene
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
## "melee" or "ranged". Ranged enemies hold `preferred_range` and shoot.
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
const ELITE_HP_MULT := 2.5
const ELITE_DAMAGE_MULT := 1.4
const ELITE_SCALE_MULT := 1.3
const ELITE_POISE_BONUS := 6.0
const ELITE_AWAKEN_BONUS := 15.0
## Seconds this enemy alone freezes on hit (on top of global hitstop).
@export var hit_freeze := 0.06
@export var hit_freeze_big := 0.11

static var dodges := 0  # running count, reported by the autotest

var radius := 0.55
var hp := 0.0
var state := State.SPAWN
var model: Node3D
var anim: AnimationPlayer

var _state_t := 0.0
var _player: Node3D
var _telegraph: MeshInstance3D
var _telegraph_mat: StandardMaterial3D
var _attack_cd := 0.0
var _freeze_t := 0.0
var _frozen_speed := -1.0
var _squash_tween: Tween
var _orbit_side := 1.0
var _dodge_cd := 0.0


func _ready() -> void:
	if elite:
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


## Targetable: spawned, not dead, and not mid-dodge.
func is_alive() -> bool:
	return state != State.DEAD and state != State.SPAWN and state != State.DODGE


func is_airborne() -> bool:
	return state == State.AIRBORNE


func _physics_process(delta: float) -> void:
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
	_state_t += delta
	_attack_cd -= delta
	_dodge_cd -= delta
	velocity.y -= (14.0 if state == State.AIRBORNE else 30.0) * delta
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0

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
			_friction(delta, 18.0)
			if _state_t >= 0.4:
				_set_state(State.CHASE)
		State.AIRBORNE:
			_friction(delta, 4.0)
			if is_on_floor() and _state_t > 0.15:
				_play("Lie_StandUp", 0.1, 2.0)
				Fx.dust(get_parent(), global_position, 14, 0.6)
				Game.shake(0.1)
				_set_state(State.HURT)
				_state_t = -0.35  # lying on the ground a bit longer
		State.DODGE:
			_friction(delta, 26.0)
			if _state_t >= 0.35:
				_set_state(State.CHASE)
		State.DEAD:
			_friction(delta, 20.0)

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
	if d <= attack_range and _attack_cd <= 0.0 and (attack_kind == "ranged" or _melee_slot_free()):
		_set_state(State.WINDUP)
		if attack_kind == "ranged":
			_play("Spellcasting", 0.1, 1.2)
		else:
			_play("1H_Melee_Attack_Chop", 0.1, anim.get_animation("1H_Melee_Attack_Chop").length * 0.45 / attack_windup)
		return
	var dir := Vector3.ZERO
	var behind: Vector3 = _player.global_position - _player.facing_dir() * 2.5 - global_position
	behind.y = 0.0
	if flank and d > attack_range + 1.5 and behind.length() > 1.0:
		dir = behind.normalized()
	elif attack_kind == "ranged":
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
	_telegraph.scale = Vector3.ONE * lerpf(0.3, 1.0, k)
	_telegraph_mat.albedo_color.a = lerpf(0.15, 0.55, k)
	if _state_t >= attack_windup:
		_telegraph.visible = false
		if attack_kind == "ranged":
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


## Stunned and open (e.g. after the player perfect-dodges this enemy's attack).
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


func take_hit(damage: float, knockback: Vector3, launch: float, big: bool) -> void:
	if state == State.DEAD or state == State.SPAWN or state == State.DODGE:
		return
	hp -= damage
	Fx.damage_number(get_parent(), global_position, damage, big)
	Fx.hit_spark(get_parent(), global_position + knockback.normalized() * -0.3, Color(1.0, 0.9, 0.6), 1.3 if big else 0.9)
	Fx.impact(get_parent(), global_position, knockback + Vector3.UP * 2.0, big)
	Fx.flash(model)
	_telegraph.visible = false
	_freeze_t = hit_freeze_big if big else hit_freeze
	if hp <= 0.0:
		_die(knockback)
		return

	var airborne := state == State.AIRBORNE
	if launch > 0.0 or airborne:
		# Launched or juggled: keep them floating as long as hits connect.
		velocity = Vector3(knockback.x * 0.4, maxf(launch, 4.5), knockback.z * 0.4)
		_set_state(State.AIRBORNE)
		_play("Hit_B", 0.05, 1.5, true)
		_squash(Vector3(0.8, 1.3, 0.8))  # stretch upward when launched
		return
	if knockback.length() < poise and state == State.WINDUP:
		return  # poise held: flinch-free, the attack still lands
	velocity.x = knockback.x
	velocity.z = knockback.z
	_set_state(State.HURT)
	_play("Hit_A" if randf() < 0.5 else "Hit_B", 0.05, 1.6, true)
	_squash(Vector3(1.25, 0.78, 1.25) if big else Vector3(1.15, 0.87, 1.15))


## Fall apart on the spot (e.g. when the boss that summoned it dies).
func crumble() -> void:
	if state != State.DEAD:
		_die(Vector3.ZERO)


func _die(knockback: Vector3) -> void:
	_set_state(State.DEAD)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3(knockback.x * 1.3, 4.0, knockback.z * 1.3)
	_play("Death_A", 0.05, 1.4, true)
	Game.add_awakening(4.0 + (ELITE_AWAKEN_BONUS if elite else 0.0))
	Game.sfx("enemy_death", -2.0, 0.15)
	died.emit(self)
	Game.enemy_killed.emit(self)
	var tw := create_tween()
	tw.tween_interval(1.4)
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
	if anim.current_animation == anim_name and not restart:
		return
	anim.play(anim_name, blend, 1.0)
	if restart:
		anim.seek(0.0, true)
	if _frozen_speed >= 0.0:
		_frozen_speed = speed  # applied when the hit freeze ends
	else:
		anim.speed_scale = speed


## Snap the model to `amount` (per-axis scale) and spring back.
func _squash(amount: Vector3) -> void:
	if _squash_tween:
		_squash_tween.kill()
	model.scale = amount * model_scale
	_squash_tween = create_tween()
	_squash_tween.tween_property(model, "scale", Vector3.ONE * model_scale, 0.3) 		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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


func _build_telegraph() -> void:
	_telegraph = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	# Melee rings show the reach; casters get a small ring at their feet.
	var r := 1.1 if attack_kind == "ranged" else attack_range + 0.3
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
