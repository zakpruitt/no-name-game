extends "res://scripts/enemy.gd"
## The Bone Warden: a giant skeleton with three telegraphed attacks.
##   cleave  spin sweep around itself (red ring shows the reach)
##   slam    leaps onto the hero's spot (red ring at the landing point)
##   nova    ring of slow bolts (purple ring); dash through the gaps
##   spikes  (enraged only) smashes the floor; a line of bone spikes runs at
##           the hero, turning to follow, each flagged red just before it stabs
##   cage    (enraged only) a ring of bone walls bursts up around the hero and
##           closes in, turning; get out through the gap or dash a wall
## Normal hits never stagger it; dealing `break_damage` within a few seconds
## breaks its guard for a long opening. Below half HP it enrages: faster
## windups, denser novas, the spike line, and it summons minions.

const BONE_SPIKE := preload("res://scripts/bone_spike.gd")
const BONE_CAGE := preload("res://scripts/bone_cage.gd")

signal summon(count: int)
signal enraged
signal spike_line
signal cage

## Per-attack tuning: windup (s), recover (s), damage, plus attack specifics.
const ATTACKS := {
	"cleave": {"windup": 0.85, "recover": 0.9, "damage": 22.0, "range": 4.2},
	"slam": {"windup": 1.0, "recover": 1.1, "damage": 26.0, "radius": 3.6, "air_time": 0.55},
	"nova": {"windup": 1.1, "recover": 0.8, "damage": 12.0, "bolts": 10, "bolts_enraged": 14},
	# count spikes, `step` m apart, one every `interval` s; each turns at most
	# `turn` degrees toward the hero and warns for `warn` s before stabbing.
	"spikes": {"windup": 0.9, "recover": 1.0, "damage": 18.0, "count": 12, "step": 1.6,
		"interval": 0.11, "turn": 22.0, "warn": 0.4, "radius": 1.0},
	# ring of `walls` pieces from `radius` m closing to `end_radius` over
	# `close` s (after `rise` s), turning `spin` deg/s, with a `gap` deg opening.
	"cage": {"windup": 1.0, "recover": 1.2, "damage": 20.0, "radius": 7.0, "end_radius": 1.0,
		"rise": 0.5, "close": 2.6, "gap": 50.0, "spin": 25.0, "walls": 22},
}
## warden.glb's clips, one per attack: [clip, frame the attack lands on]. They were
## keyed to ATTACKS at CLIP_FPS, so at unit speed the hit falls on the windup's end.
const COMIC_ATTACKS := {
	"cleave": ["Attack_Cleave", 20.0],
	"slam": ["Attack_Slam", 24.0],
	"nova": ["Attack_Nova", 26.0],
	"spikes": ["Attack_Spikes", 22.0],
	"cage": ["Attack_Cage", 24.0],
}
const CLIP_FPS := 24.0
const COMIC_SLAM_AIR := 13.0  # Attack_Slam frames from take-off to landing
const COMIC_SLAM_RECOVER := 26.0  # and from landing to the end
## Damage that breaks its guard if dealt within `break_window` seconds.
@export var break_damage := 90.0
@export var break_window := 4.0
@export var break_stun := 2.2
## Enraged multiplier on windups/recovers, and minions summoned on enrage.
@export var enrage_speed := 0.75
@export var enrage_summon := 3
## Perfect-dodge stuns last this fraction as long as on normal enemies.
@export var dodge_stun_mult := 0.5

var display_name := "THE BONE WARDEN"
var force_attack := ""  # ATTACKS key it always picks (autotest --boss-attack=)
var is_enraged := false
var _attack := ""
var _leaping := false
var _slam_target := Vector3.ZERO
var _target_ring: MeshInstance3D
var _target_mat: StandardMaterial3D
var _target_edge: MeshInstance3D
var _break_meter := 0.0
var _break_decay_t := 0.0
var _last_attack := ""
var _meshes: Array[Node] = []
var _enrage_mat: ShaderMaterial


func _ready() -> void:
	super()
	separation_radius = 3.0
	# Grow the collision capsule with the model.
	var shape: CollisionShape3D = get_child(0)
	(shape.shape as CapsuleShape3D).radius = 0.45 * model_scale
	(shape.shape as CapsuleShape3D).height = 1.8 * model_scale
	shape.position.y = 0.9 * model_scale
	_build_target_ring()
	_attack_cd = 1.5


func is_boss() -> bool:
	return true


func _physics_process(delta: float) -> void:
	super(delta)
	_break_decay_t -= delta
	if _break_decay_t <= 0.0:
		_break_meter = move_toward(_break_meter, 0.0, break_damage * 0.5 * delta)
	if _leaping and state == State.RECOVER and is_on_floor() and _state_t > 0.15:
		_land()
	# Fx.flash clears overlays on hit; put the enrage glow back afterwards.
	if is_enraged:
		for mi: MeshInstance3D in _meshes:
			if mi.material_overlay == null:
				mi.material_overlay = _enrage_mat


func _state_chase(delta: float) -> void:
	if not is_instance_valid(_player) or _player.is_dead():
		super(delta)
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if _attack_cd <= 0.0:
		_start_attack(_pick_attack(d))
		return
	_face(to)
	var dir := to / maxf(d, 0.001) if d > 2.8 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, dir.x * move_speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * move_speed, 20.0 * delta)
	_play(run_anim if dir != Vector3.ZERO else "Idle_Combat")


## Close: mostly cleave. Far: slam or nova. Avoid repeating the same attack.
func _pick_attack(d: float) -> String:
	var options: Array = ["cleave", "cleave", "slam"] if d < 4.5 else ["slam", "nova", "nova"]
	if force_attack != "":
		return force_attack
	if is_enraged:
		options += ["spikes", "cage"] if d < 4.5 else ["spikes", "spikes", "cage"]
	while options.has(_last_attack):
		options.erase(_last_attack)
	if options.is_empty():
		options = ["slam"]
	return options.pick_random()


func _start_attack(kind: String) -> void:
	_attack = kind
	_last_attack = kind
	var spec: Dictionary = ATTACKS[kind]
	var mult := enrage_speed if is_enraged else 1.0
	attack_windup = spec.windup * mult
	attack_recover = spec.recover * mult
	attack_damage = spec.damage
	_set_state(State.WINDUP)
	match kind:
		"cleave":
			attack_range = spec.range
			_set_telegraph(spec.range, Color(1.0, 0.15, 0.1, 0.3))
			_windup_anim("2H_Melee_Attack_Spin", 0.4)
		"slam":
			_slam_target = _player.global_position
			_windup_anim("Jump_Start", 1.0)
		"nova":
			_set_telegraph(1.8, Color(0.7, 0.3, 1.0, 0.3))
			_windup_anim("Spellcast_Raise", 1.0)
		"spikes":
			_set_telegraph(2.2, Color(1.0, 0.15, 0.1, 0.3))
			_windup_anim("2H_Melee_Attack_Chop", 0.45)
		"cage":
			_set_telegraph(2.6, Color(0.95, 0.85, 0.6, 0.3))
			_windup_anim("Spellcast_Raise", 1.0)
	Game.sfx("spawn", -6.0, 0.1)


## Play `clip` so `fraction` of it fits the windup, or the comic model's own clip for
## the current attack, timed so its hit frame lands on the windup's end.
func _windup_anim(clip: String, fraction: float) -> void:
	if comic_kind != "":
		var c: Array = COMIC_ATTACKS[_attack]
		_play(c[0], 0.1, c[1] / CLIP_FPS / attack_windup)
		return
	_play(clip, 0.1, anim.get_animation(clip).length * fraction / attack_windup)


func _state_windup(delta: float) -> void:
	_friction(delta, 30.0)
	var k := clampf(_state_t / attack_windup, 0.0, 1.0)
	if _attack == "slam":
		# The landing spot tracks the hero for most of the windup, then locks.
		if k < 0.7 and is_instance_valid(_player):
			_slam_target = _slam_target.lerp(_player.global_position, 0.2)
		_face(_slam_target - global_position)
		_target_ring.visible = true
		_target_ring.global_position = _slam_target + Vector3.UP * 0.08
		_target_ring.scale = Vector3.ONE * lerpf(0.3, 1.0, k)
		_target_mat.albedo_color.a = lerpf(0.15, 0.6, k)
		_edge_t += delta * lerpf(EDGE_PULSE_HZ.x, EDGE_PULSE_HZ.y, k)
		Fx.pulse_edge(_target_edge, _target_mat.albedo_color, _edge_t)
	else:
		if is_instance_valid(_player):
			_face(_player.global_position - global_position)
		_telegraph.visible = true
		_scale_fill(lerpf(0.3, 1.0, k))
		_telegraph_mat.albedo_color.a = lerpf(0.15, 0.55, k)
	if _state_t >= attack_windup:
		_telegraph.visible = false
		match _attack:
			"cleave": _cleave()
			"slam": _leap()
			"nova": _nova()
			"spikes": _spike_line()
			"cage": _cage()
		_attack_cd = randf_range(0.6, 1.2) * (enrage_speed if is_enraged else 1.0)
		_set_state(State.RECOVER)


func _cleave() -> void:
	Game.shake(0.35)
	Game.sfx("swing_heavy", -2.0, 0.05)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.4, 0.2, 0.8), attack_range + 0.3, 0.3)
	if not is_instance_valid(_player):
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	if to.length() <= attack_range + 0.4:
		_player.take_hit(attack_damage, to.normalized() * 12.0, self)


func _leap() -> void:
	var spec: Dictionary = ATTACKS.slam
	var air: float = spec.air_time
	var flat := _slam_target - global_position
	flat.y = 0.0
	velocity = Vector3(flat.x / air, 30.0 * air * 0.5, flat.z / air)
	_leaping = true
	attack_recover = 5.0  # held until landing; _land() starts the real recover
	_play("Jump_Idle", 0.05)
	if comic_kind != "":
		_clip_speed(COMIC_SLAM_AIR / CLIP_FPS / air)
	Fx.dust(get_parent(), global_position, 16, 1.0)


func _land() -> void:
	_leaping = false
	_target_ring.visible = false
	var spec: Dictionary = ATTACKS.slam
	var r: float = spec.radius
	attack_recover = spec.recover * (enrage_speed if is_enraged else 1.0)
	_set_state(State.RECOVER)
	_play("Jump_Land", 0.05, 1.2, true)
	if comic_kind != "":
		_clip_speed(COMIC_SLAM_RECOVER / CLIP_FPS / attack_recover)
	velocity.x = 0.0
	velocity.z = 0.0
	Game.shake(0.7)
	Game.sfx("hit_big", 0.0, 0.05)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.35, 0.15, 0.9), r, 0.35)
	Fx.dust(get_parent(), global_position, 30, 1.6)
	if not is_instance_valid(_player):
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	if to.length() <= r + 0.3:
		_player.take_hit(attack_damage, to.normalized() * 14.0, self)


func _nova() -> void:
	var spec: Dictionary = ATTACKS.nova
	var n: int = spec.bolts_enraged if is_enraged else spec.bolts
	var offset := randf() * TAU
	_play("Spellcast_Shoot", 0.05, 1.2, true)
	Game.sfx("awaken", -8.0, 0.1)
	for i in n:
		var ang := offset + TAU * i / n
		var p := PROJECTILE.new()
		p.direction = Vector3(cos(ang), 0.0, sin(ang))
		p.speed = 7.5
		p.damage = attack_damage
		p.source = self
		get_parent().add_child(p)
		p.global_position = global_position + Vector3.UP * 1.0 + p.direction * 1.4


## Lay spikes one by one from the boss toward the hero, steering a little
## each step (so dashing sideways outruns it).
func _spike_line() -> void:
	var spec: Dictionary = ATTACKS.spikes
	Game.shake(0.45)
	Game.sfx("hit_big", -2.0, 0.05)
	Fx.dust(get_parent(), global_position, 20, 1.2)
	spike_line.emit()
	var dir := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var pos := global_position + dir * 1.5
	var turn := deg_to_rad(spec.turn)
	for i in spec.count:
		if state == State.DEAD or not is_inside_tree():
			return
		if is_instance_valid(_player):
			var want := _player.global_position - pos
			want.y = 0.0
			if want.length() > 0.5:
				var ang := clampf(dir.signed_angle_to(want.normalized(), Vector3.UP), -turn, turn)
				dir = dir.rotated(Vector3.UP, ang)
		pos += dir * spec.step
		if absf(pos.x) > 15.0 or absf(pos.z) > 15.0:
			return  # hit the wall
		var s := BONE_SPIKE.new()
		s.damage = spec.damage
		s.warn_time = spec.warn
		s.radius = spec.radius
		s.source = self
		get_parent().add_child(s)
		s.global_position = Vector3(pos.x, 0.0, pos.z)
		await get_tree().create_timer(spec.interval, false).timeout


## Raise a closing ring of bone walls centred on the hero.
func _cage() -> void:
	if not is_instance_valid(_player):
		return
	var spec: Dictionary = ATTACKS.cage
	_play("Spellcast_Shoot", 0.05, 1.2, true)
	Game.shake(0.5)
	Game.sfx("cage_rise", 0.0, 0.05)
	cage.emit()
	var c := BONE_CAGE.new()
	c.radius = spec.radius
	c.end_radius = spec.end_radius
	c.rise_time = spec.rise
	c.close_time = spec.close
	c.gap = spec.gap
	c.spin = spec.spin * (1.0 if randf() < 0.5 else -1.0)
	c.walls = spec.walls
	c.damage = spec.damage
	c.gap_angle = randf() * TAU
	c.source = self
	get_parent().add_child(c)
	c.global_position = Vector3(_player.global_position.x, 0.0, _player.global_position.z)


func stagger(time: float) -> void:
	_cancel_leap()
	super(time * dodge_stun_mult)


func _cancel_leap() -> void:
	if _leaping:
		_leaping = false
		attack_recover = 0.5
	_target_ring.visible = false


## No launches or flinches; damage fills the guard-break meter instead.
func take_hit(damage: float, knockback: Vector3, _launch: float, big: bool) -> void:
	if state == State.DEAD or state == State.SPAWN:
		return
	hp -= damage
	Fx.damage_number(get_parent(), global_position + Vector3.UP * 1.2, damage, big)
	Fx.hit_spark(get_parent(), global_position + Vector3.UP * 0.8 + knockback.normalized() * -0.6, Color(1.0, 0.9, 0.6), 1.5 if big else 1.0)
	Fx.impact(get_parent(), global_position + Vector3.UP * 0.8, knockback + Vector3.UP * 2.0, big)
	Fx.flash(model)
	_freeze_t = hit_freeze
	if hp <= 0.0:
		_cancel_leap()
		_die(knockback * 0.3)
		return
	if not is_enraged and hp <= max_hp * 0.5:
		_enrage()
	if state == State.HURT:
		return  # already broken: free hits
	_break_meter += damage
	_break_decay_t = break_window
	if _break_meter >= break_damage:
		_guard_break()


func _guard_break() -> void:
	_break_meter = 0.0
	_cancel_leap()
	_telegraph.visible = false
	_set_state(State.HURT)
	_state_t = 0.4 - break_stun
	_play("Hit_B", 0.05, 0.6, true)
	_squash(Vector3(1.2, 0.8, 1.2))
	Game.announced.emit("GUARD BREAK")
	Game.hitstop(0.12)
	Game.shake(0.5)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.85, 0.3, 0.9), 3.0, 0.4)


func _enrage() -> void:
	is_enraged = true
	if comic_kind != "":
		_hold_clip("Enrage")
	move_speed *= 1.25
	Game.announced.emit("THE WARDEN ENRAGES")
	Game.shake(0.6)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.2, 0.1, 0.9), 6.0, 0.5)
	_enrage_mat = Fx.rim_material().duplicate()
	_enrage_mat.set_shader_parameter("glow_color", Color(1.0, 0.15, 0.1))
	_meshes = model.find_children("*", "MeshInstance3D", true, false)
	enraged.emit()
	summon.emit(enrage_summon)


func _die(knockback: Vector3) -> void:
	super(knockback)
	Game.add_awakening(40.0)
	Game.hitstop(0.35, 0.1)
	Game.shake(1.0)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.85, 0.4, 0.9), 8.0, 0.6)
	Fx.burst(get_parent(), global_position + Vector3.UP * 1.5, Color(1.0, 0.8, 0.4), 60, 10.0, 0.25, 0.8, Vector3.UP, 180.0, -6.0)
	Fx.shards(get_parent(), global_position + Vector3.UP * 1.5, Color(0.93, 0.89, 0.78), 36, knockback, 14.0, 0.38, 1.0)


## 0..1 fill of the guard-break meter (for the HUD).
func break_ratio() -> float:
	return clampf(_break_meter / break_damage, 0.0, 1.0)


func _friction(delta: float, amount: float) -> void:
	if _leaping:
		return  # keep the leap's momentum
	super(delta, amount)


func _set_telegraph(r: float, color: Color) -> void:
	var mesh := _telegraph.mesh as CylinderMesh
	mesh.top_radius = r
	mesh.bottom_radius = r
	fit_edge(r)
	_telegraph_mat.albedo_color = color


func _build_target_ring() -> void:
	_target_ring = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	var r: float = ATTACKS.slam.radius
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = 0.02
	_target_mat = StandardMaterial3D.new()
	_target_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_target_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.3)
	mesh.material = _target_mat
	_target_ring.mesh = mesh
	_target_ring.top_level = true
	_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_target_ring.visible = false
	add_child(_target_ring)
	_target_edge = Fx.edge_ring(r)
	_target_ring.add_child(_target_edge)
