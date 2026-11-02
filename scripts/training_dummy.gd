extends "res://scripts/enemy.gd"
## Training dummy: a skeleton that never fights back or dies. It takes hits,
## staggers, launches and juggles like any foe (but heavier: LAUNCH_SCALE,
## MAX_HEIGHT), then walks back to its spot and refills once left alone. Reports each hit's damage for the training
## readout (main._train_hit).

signal hit_taken(damage: float)

const REFILL_DELAY := 2.0  # seconds without a hit before HP refills
const HOME_SPEED := 2.0
# Heavier than a skeleton in the air: launches lift it LAUNCH_SCALE as high,
# and however many hits keep it up (casts, wheels, element set-offs) it never
# climbs past MAX_HEIGHT m, so long strings don't juggle it out of reach.
const LAUNCH_SCALE := 0.55
const MAX_HEIGHT := 3.0
const AIR_GRAVITY := 14.0  # (enemy.gd's airborne gravity)

var home := Vector3.ZERO


func _ready() -> void:
	max_hp = 1000.0
	bones = 0
	body_tint = Color(0.85, 0.7, 0.5)
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if hp < max_hp and Time.get_ticks_msec() - last_hit_ms > REFILL_DELAY * 1000.0:
		hp = max_hp


## Never winds up: faces the hero and strolls back home if knocked away.
func _state_chase(delta: float) -> void:
	var back := home - global_position
	back.y = 0.0
	if back.length() > 0.4:
		var dir := back.normalized()
		velocity.x = move_toward(velocity.x, dir.x * HOME_SPEED, 25.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * HOME_SPEED, 25.0 * delta)
		_face(dir)
		_play(run_anim)
		return
	_friction(delta, 20.0)
	if is_instance_valid(_player):
		var to := _player.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			_face(to)
	_play("Idle_Combat")


func take_hit(damage: float, knockback: Vector3, launch: float, big: bool) -> void:
	# Top up before a hit that could finish it (frozen hits deal extra).
	if hp <= damage * 4.0:
		hp = max_hp
	var before := hp
	super(damage, knockback, launch * LAUNCH_SCALE, big)
	if state == State.AIRBORNE:  # rise no higher than MAX_HEIGHT: v^2 = 2 g h
		velocity.y = minf(velocity.y, sqrt(2.0 * AIR_GRAVITY * maxf(MAX_HEIGHT - global_position.y, 0.0)))
	if hp < before:
		hit_taken.emit(before - hp)
