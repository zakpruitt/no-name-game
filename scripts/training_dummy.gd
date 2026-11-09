extends "res://scripts/enemy.gd"
## Training dummy: a cartoon punching bag (assets/comic/dummy.glb, KayKit's skeleton if it's missing) that never fights back or dies. It takes hits,
## staggers, launches and juggles like any foe (but heavier: LAUNCH_SCALE,
## MAX_HEIGHT), then walks back to its spot and refills once left alone. Reports each hit's damage for the training
## readout (main._train_hit). It reacts like a punching bag: hits tip it on an
## overshooting spring (_bag_*), squashes are exaggerated, it boings back up
## after a knockdown, and it shakes off a daze when it refills (_shake_off; a hit cuts it short).
## Over its head a comic tag reads the damage it took in the last string (_tag).

signal hit_taken(damage: float)

const REFILL_DELAY := 2.0  # seconds without a hit before HP refills
const HOME_SPEED := 2.0
# Heavier than a skeleton in the air: launches lift it LAUNCH_SCALE as high,
# and however many hits keep it up (casts, wheels, element set-offs) it never
# climbs past MAX_HEIGHT m, so long strings don't juggle it out of reach.
const LAUNCH_SCALE := 0.55
const MAX_HEIGHT := 3.0
# Punching bag. A hit snaps the tilt (at its feet) to enemy LEAN / LEAN_BIG times
# BAG_LEAN_MULT along the blow, capped at BAG_MAX_TILT; then an angular spring
# (BAG_STIFFNESS, BAG_DAMPING: ~2.2 Hz, damping ratio ~0.18, so each swing back
# is ~55% of the last) rocks it back past upright and settles it under
# BAG_REST. Squashes go BAG_SQUASH_MULT as far (no axis under BAG_MIN_SCALE).
# Standing up after a knockdown kicks the spring BAG_GETUP_KICK rad/s back
# against the blow (it boings upright). Refilling, it shakes off a daze:
# DAZE_SHAKES side kicks of DAZE_KICK rad/s DAZE_BEAT s apart, a DAZE_STRETCH
# boing, and dizzy stars DAZE_HEIGHT m up for DAZE_TIME s.
# HAND-TUNE KNOBS (try live: `godot --path . -- --bag-damping=7 --bag-stiffness=190 --bag-lean=1.8
# --bag-squash=1.6`; each defaults to its const below, read once in _ready: bag_overrides()):
# - BAG_DAMPING sets how long it rocks: a tap (0.36 rad) is still after ~9 / BAG_DAMPING s
#   (5 -> 1.9 s, 7 -> 1.3 s, 3.5 -> 2.6 s); each swing back keeps exp(-BAG_DAMPING * pi / omega).
# - BAG_STIFFNESS sets how fast it swings (omega = sqrt(stiffness), 190 -> 2.2 Hz); damping
#   ratio = BAG_DAMPING / (2 * omega), keep it under ~0.35 or the overshoot stops reading.
# - BAG_LEAN_MULT / BAG_SQUASH_MULT: how far a hit tips and squashes it next to a skeleton.
const BAG_LEAN_MULT := 1.8  # a tap tips 0.36 rad, a big hit 0.76
const BAG_MAX_TILT := 1.0  # rad
const BAG_STIFFNESS := 190.0  # rad/s^2 per rad of tilt (omega 13.8/s)
const BAG_DAMPING := 5.0  # 1/s, on the tilt's speed
const BAG_REST := 0.004  # rad and rad/s: below both it snaps still
const BAG_SQUASH_MULT := 1.6
const BAG_MIN_SCALE := 0.2  # no squash axis goes thinner than this
const BAG_GETUP_KICK := 6.0  # rad/s: ~0.43 rad of overshoot
const DAZE_SHAKES := 3
const DAZE_KICK := 5.0  # rad/s, alternating sides
const DAZE_BEAT := 0.13  # s between shakes (about half the spring's period)
const DAZE_STRETCH := Vector3(0.85, 1.2, 0.85)  # the boing as it shakes it off (before BAG_SQUASH_MULT)
const DAZE_HEIGHT := 2.0  # m above its feet, around the head
const DAZE_TIME := 0.9  # s the stars circle
## The comic bag's own daze (assets/comic/dummy.glb): pupils spin, head lolls, played over DAZE_TIME.
const DAZE_CLIP := "Dazed"
const BAG_FLAGS := {"--bag-damping=": "bag_damping", "--bag-stiffness=": "bag_stiffness",
	"--bag-lean=": "bag_lean_mult", "--bag-squash=": "bag_squash_mult"}
# The last-string tag: TAG_HEIGHT m over its feet, Bangers at TAG_SIZE, popping TAG_POP big when a string
# ends. Feel audit 2, item 2: four 72 px gold tags with a 22 px outline sat over the pile for whole strings, the
# loudest text on screen. It now shows only TAG_SHOW_S real s after this dummy's string ends, at about a damage
# number's size in a thin ink (TAG_INK_PX on screen), fades over TAG_FADE_S and is gone as soon as it is hit again.
const TAG_HEIGHT := 3.3
const TAG_SIZE := 40  # font px (0.24 m at TAG_PIXEL: ~12 px at the game camera, the number's 0.42 m is ~20)
const TAG_PIXEL := 0.006
const TAG_INK_PX := 1.5  # px of ink round it on screen (a hit's word and number take 3)
const TAG_POP := 1.2
const TAG_SHOW_S := 1.5  # real s from the string's end to the tag gone
const TAG_FADE_S := 0.3  # the last part of it
const TAG_COLOR := Color(1.0, 0.86, 0.25)
const TAG_INK := Color(0.05, 0.03, 0.08)
const TAG_FONT := "res://assets/fonts/Bangers-Regular.ttf"
const PAL := preload("res://scripts/fx_palette.gd")
## Swinging dummies (docs/features/counter.md), for the dash counter: with Settings "Dummies swing", `--swing`, or
## `swings` set (the bot's counter string), a dummy at home that he stands in front of (SWING_RANGE m, SWING_ARC
## degrees off its facing) for SWING_BEAT s winds up like a spar foe (enemy._state_windup: the telegraph ring fills
## over SWING_WINDUP) and swings its whole bag at him for SWING_DAMAGE (a spar foe's third), then again every
## SWING_EVERY s while he stays. The bag rocks back SWING_LEAN rad over the windup and snaps forward on the strike.
const SWING_FLAG := "--swing"
const SWING_RANGE := 2.8
const SWING_ARC := 60.0
const SWING_BEAT := 0.5
const SWING_EVERY := 1.4
const SWING_WINDUP := 0.7
const SWING_DAMAGE := 12.0 / 3.0
const SWING_LEAN := 0.42
const SWING_KICK := 9.0  # rad/s forward as it strikes

var home := Vector3.ZERO
var swings := false  # swings whatever the setting (the bot's counter string)
var swings_done := 0  # strikes it has thrown (counter_check)
var _front_t := 0.0
var _swing_cd := 0.0
var _winding := false
static var _swing_flag := -1  # --swing on the command line (-1 unread)
var shakeoffs := 0  # dazes shaken off (enemy_feel_check)
var _bag_tilt := Vector2.ZERO  # (rotation.x, rotation.z) at the feet, rad
var _bag_vel := Vector2.ZERO  # rad/s
var _was_down := false  # knocked down: kick the spring once it's back up
var bag_damping := BAG_DAMPING  # the knobs, after any --bag-*= flag (bag_overrides)
var bag_stiffness := BAG_STIFFNESS
var bag_lean_mult := BAG_LEAN_MULT
var bag_squash_mult := BAG_SQUASH_MULT
var shakeoffs_cut := 0  # shake-offs a hit cut short (enemy_feel_check)
var string_damage := 0.0  # this string's damage on this dummy so far
var last_string_damage := 0.0  # and the last finished string's (the tag)
var _daze_tween: Tween
var _tag: Label3D
var _tag_tween: Tween
static var _flags_said := false


func _ready() -> void:
	max_hp = 1000.0
	super()
	var knobs := bag_overrides(OS.get_cmdline_user_args())
	for key: String in knobs:
		set(key, knobs[key])
	if not knobs.is_empty() and not _flags_said:
		_flags_said = true
		print("[training] bag knobs damping=%.2f stiffness=%.1f lean=%.2f squash=%.2f" % [bag_damping, bag_stiffness, bag_lean_mult, bag_squash_mult])
	_build_tag()
	Game.combo_changed.connect(_on_combo)
	attack_kind = "melee"
	attack_windup = SWING_WINDUP
	attack_damage = SWING_DAMAGE
	attack_range = SWING_RANGE


## Does it swing at him (swings, `--swing`, or Settings "Dummies swing")?
func swinging() -> bool:
	if _swing_flag < 0:
		_swing_flag = 1 if SWING_FLAG in OS.get_cmdline_user_args() else 0
	return swings or _swing_flag == 1 or Game.dummies_swing


## The --bag-*=N flags in `args`, as {property: value}.
static func bag_overrides(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		for flag: String in BAG_FLAGS:
			if arg.begins_with(flag) and arg.substr(flag.length()).is_valid_float():
				out[BAG_FLAGS[flag]] = arg.substr(flag.length()).to_float()
	return out


func _build_tag() -> void:
	_tag = Label3D.new()
	_tag.name = "StringTag"
	if ResourceLoader.exists(TAG_FONT):
		_tag.font = load(TAG_FONT)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = false
	_tag.font_size = TAG_SIZE
	_tag.pixel_size = TAG_PIXEL
	_tag.outline_size = maxi(1, roundi(TAG_INK_PX / (TAG_PIXEL * PAL.PX_PER_M)))
	_tag.modulate = TAG_COLOR
	_tag.outline_modulate = TAG_INK
	_tag.render_priority = 2
	_tag.outline_render_priority = 1
	_tag.visible = false
	add_child(_tag)
	_tag.position.y = TAG_HEIGHT * model_scale


## The string's over: pop its damage on the tag. A new one starting dims the old number.
func _on_combo(count: int, _rank: String) -> void:
	if count > 0 or string_damage <= 0.0:
		return
	last_string_damage = string_damage
	string_damage = 0.0
	_tag.text = "LAST %d" % roundi(last_string_damage)
	_tag.visible = true
	_tag.modulate.a = 1.0
	_tag.outline_modulate.a = 1.0
	if _tag_tween:
		_tag_tween.kill()
	_tag.scale = Vector3.ONE * TAG_POP
	_tag_tween = create_tween().set_ignore_time_scale(true)  # (a landing's hitstop must not hold it up)
	_tag_tween.tween_property(_tag, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tag_tween.tween_interval(TAG_SHOW_S - TAG_FADE_S - 0.2)
	_tag_tween.tween_method(_tag_alpha, 1.0, 0.0, TAG_FADE_S)
	_tag_tween.tween_callback(_tag.hide)


func _tag_alpha(a: float) -> void:
	_tag.modulate.a = a
	_tag.outline_modulate.a = a


func _physics_process(delta: float) -> void:
	super(delta)
	if hp < max_hp and Time.get_ticks_msec() - last_hit_ms > REFILL_DELAY * 1000.0:
		hp = max_hp
		_shake_off()
	if _was_down and state != State.HURT and state != State.AIRBORNE:
		_was_down = false  # back on its feet: boing upright, overshooting back against the blow
		var local := Basis(Vector3.UP, model.rotation.y).inverse() * _air_dir
		_bag_vel -= Vector2(local.z, -local.x) * BAG_GETUP_KICK
	_swing_cd -= delta
	if state == State.WINDUP:  # rocks back over the windup (the spring waits)
		_winding = true
		var k := clampf(_state_t / attack_windup, 0.0, 1.0)
		_bag_tilt = Vector2(-SWING_LEAN * (1.0 - (1.0 - k) * (1.0 - k)), 0.0)
		_bag_vel = Vector2.ZERO
		model.rotation.x = _bag_tilt.x
		model.rotation.z = 0.0
		return
	if _winding:
		_winding = false
		if state == State.RECOVER:  # it struck: the bag snaps forward at him
			swings_done += 1
			_bag_vel.x += SWING_KICK
			Game.sfx("swing_heavy", -6.0, 0.1)
	_bag_step(delta)


## The spring: rocks the tilt back past upright until it settles. Held through
## the hit freeze; the tumble and the landing settle own the tilt while they run.
func _bag_step(delta: float) -> void:
	if frozen_t > 0.0:  # frozen solid in its ice, standing up (fx-ice2; enemy.freeze stood it up): no swing out of the block
		_bag_tilt = Vector2.ZERO
		_bag_vel = Vector2.ZERO
		model.rotation.x = 0.0
		model.rotation.z = 0.0
		return
	if _freeze_t > 0.0 or state == State.AIRBORNE or (_lean_tween != null and _lean_tween.is_running()):
		return
	if _bag_tilt.length() < BAG_REST and _bag_vel.length() < BAG_REST:
		if _bag_tilt != Vector2.ZERO:
			_bag_tilt = Vector2.ZERO
			_bag_vel = Vector2.ZERO
			model.rotation.x = 0.0
			model.rotation.z = 0.0
		return
	_bag_vel += (-bag_stiffness * _bag_tilt - bag_damping * _bag_vel) * delta
	_bag_tilt += _bag_vel * delta
	model.rotation.x = _bag_tilt.x
	model.rotation.z = _bag_tilt.y


## A hit tips it hard along the blow (in place of enemy's tweened lean) and the spring does the rest.
func _lean(knockback: Vector3, amount: float) -> void:
	var flat := Vector3(knockback.x, 0.0, knockback.z)
	if flat.length_squared() < 0.001:
		return
	if _lean_tween:
		_lean_tween.kill()
	var local := Basis(Vector3.UP, model.rotation.y).inverse() * flat.normalized()
	_bag_tilt = (Vector2(local.z, -local.x) * amount * bag_lean_mult).limit_length(BAG_MAX_TILT)
	_bag_vel = Vector2.ZERO
	model.rotation.x = _bag_tilt.x
	model.rotation.z = _bag_tilt.y


## Exaggerated: BAG_SQUASH_MULT as far from full size.
func _squash(amount: Vector3, time := SQUASH_TIME, hold := 0.0) -> void:
	var big := Vector3.ONE + (amount - Vector3.ONE) * bag_squash_mult
	super(big.max(Vector3.ONE * BAG_MIN_SCALE), time, hold)


func _knock_down(lie: float) -> void:
	super(lie)
	_bag_tilt = Vector2.ZERO
	_bag_vel = Vector2.ZERO
	_was_down = true


## Left alone and refilled: shakes its head side to side under circling stars, then boings tall.
func _shake_off() -> void:
	shakeoffs += 1
	Fx.daze(self, DAZE_HEIGHT * model_scale, DAZE_TIME)
	if comic_kind != "" and anim.has_animation(DAZE_CLIP) and state == State.CHASE:
		_hold_clip(DAZE_CLIP, 0.1, anim.get_animation(DAZE_CLIP).length / DAZE_TIME)
	_daze_tween = create_tween()
	for i in DAZE_SHAKES:
		_daze_tween.tween_callback(func() -> void: _bag_vel.y += DAZE_KICK * (1.0 if i % 2 == 0 else -1.0))
		_daze_tween.tween_interval(DAZE_BEAT)
	_daze_tween.tween_callback(func() -> void: _squash(DAZE_STRETCH))


## Hit mid shake-off: it's back in the fight, so the head-shake, the boing and the stars stop at once.
func _cut_shake_off() -> void:
	if _daze_tween == null or not _daze_tween.is_running():
		return
	_daze_tween.kill()
	shakeoffs_cut += 1
	_clip_hold_ms = 0  # the daze clip lets go: the hit's own clip and then idle take over
	var stars := get_node_or_null("DazeStars")
	if stars != null:
		stars.name = "DazeStarsGone"
		stars.queue_free()


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
		if _swing_at(to, delta):
			return
	_play("Idle_Combat")


## A swinging dummy with him in front of it long enough winds up (enemy._state_windup strikes at its end).
func _swing_at(to: Vector3, delta: float) -> bool:
	var fwd := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var front := to.length() <= SWING_RANGE and to.length() > 0.1 and rad_to_deg(fwd.angle_to(to.normalized())) <= SWING_ARC
	if not swinging() or not front or _player.is_dead() or held():  # (held by a move: no swing, enemy.held)
		_front_t = 0.0
		return false
	_front_t += delta
	if _front_t < SWING_BEAT or _swing_cd > 0.0:
		return false
	_swing_cd = SWING_WINDUP + SWING_EVERY
	_aim_dir = to.normalized()
	_set_state(State.WINDUP)
	Game.sfx("swing", -10.0, 0.15)
	return true


func take_hit(damage: float, knockback: Vector3, launch: float, big: bool) -> void:
	# Top up before a hit that could finish it (frozen hits deal extra).
	if hp <= damage * 4.0:
		hp = max_hp
	_cut_shake_off()
	var before := hp
	super(damage, knockback, launch * LAUNCH_SCALE, big)
	if state == State.AIRBORNE:  # rise no higher than MAX_HEIGHT
		velocity.y = minf(velocity.y, launch_speed_for(MAX_HEIGHT - global_position.y))
	if hp < before:
		string_damage += before - hp
		if _tag.visible:  # a new string on it: the last one's number goes
			if _tag_tween:
				_tag_tween.kill()
			_tag.hide()
		hit_taken.emit(before - hp)
