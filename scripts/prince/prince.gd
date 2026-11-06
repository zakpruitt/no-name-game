extends "res://scripts/player.gd"
## The dragon prince, second playable hero (first slice; docs/characters/dragon-prince.md section 8). Played with
## `--hero=prince` (Game.hero; main.gd picks this script). He extends the heretic's player.gd for the shared body:
## the CharacterBody, run, dash, hurt, death, Awakening, HUD and camera hooks, and every field the HUD, camera,
## dummies and effects read. His own pieces are here and beside it:
##   prince_moves.gd  the MOVES / COMBOS tables, the sword-state routing, the guide rows, the MOVES panel
##   sunbrand.gd      the one sword out in the world (thrown, planted, branded, returning, shattered)
##   prince_fx.gd     his placeholder look on the chibi body and his effects (breath, blast, summon, words)
## He overrides _physics_process so none of the heretic's tentacle moves, breakers or element casts run; the
## heretic's file is untouched.
##
## Inputs: L the sword string (in hand) or the Talon claws (sword out / shattered); H after lights picks the H
## (L H Ember Flick, L L H Javelin), H alone is Dragon Breath, H with the sword out is the smash (Skyfall);
## hold L with the sword out recalls it (Rightful Return); Dash as the heretic's.

const PRINCE_MOVES := preload("res://scripts/prince/prince_moves.gd")
const PRINCE_FX := preload("res://scripts/prince/prince_fx.gd")
const SUNBRAND := preload("res://scripts/prince/sunbrand.gd")

## The smash (the doc's section 2 "Out, H"): he beats his wings, rises over the sword, hangs, dives onto it.
const SMASH_REACH := 9.0  # m: further than this, H is breath
const SMASH_RISE := 0.3  # s
const SMASH_HEIGHT := 2.5  # m up at the hang
const SMASH_HANG := 0.14  # s (the timed PERFECT window goes here next slice)
const SMASH_DIVE := 0.13  # s
const SMASH_LAND := 0.3  # s on one knee before he can act (a dash cuts it)
const SMASH_BEHIND := 1.2  # m short of the sword he hangs, so the dive comes in at an angle the camera reads
const SMASH_STOP := 0.14  # hitstop on the blast
const SMASH_SHAKE := 0.9
## Hold L this long with the sword out: Rightful Return.
const RECALL_HOLD := 0.2
## Dragon Breath: 60 deg, 4 m, two ticks (the Ember Flick's puff is `breath` 0.6 of it).
const BREATH_RANGE := 4.0
const BREATH_ARC := 60.0
const BREATH_DAMAGE := 6.0  # per tick
const SWORD_TRAIL := Color(1.0, 0.85, 0.4)
const TALON_TRAIL := Color(1.0, 0.45, 0.1)

var sword: Node3D  # sunbrand.gd
var hand_sword: Node3D
var bot_hold_light := false  # the checks' and films' "L is held" (with bot_enabled)
var _light_held_t := 0.0
var _recall_lock := false  # a recall happened on this hold; wait for the release
var _smash_phase := -1  # -1 none, 0 rise, 1 hang, 2 dive, 3 landed
var _smash_t := 0.0
var _smash_from := Vector3.ZERO
var _smash_hang := Vector3.ZERO
var _smash_to := Vector3.ZERO
# Counters for the checks and the report.
var smashes := 0
var throws := 0
var breaths := 0
var breath_hits := 0
var reforms := 0
var recalls := 0
var move_log: Array[String] = []


func _ready() -> void:
	super._ready()
	hand_sword = PRINCE_FX.dress(model)
	for t in _trails:
		t.queue_free()
	_trails.clear()
	_add_trail(PRINCE_FX.trail_blade(hand_sword))
	for t in _trails:
		t.color = SWORD_TRAIL
	if _orbit != null:
		_orbit.visible = false  # the heretic's spirit motes
	sword = SUNBRAND.new()
	add_child(sword)
	sword.setup(self)


func is_prince() -> bool:
	return true


## His dash ghosts and the foes' hit tint: sapphire, gold when Awakened.
func _fx_color() -> Color:
	return HERO_AWAKEN.AWAKEN_COLOR if awakened else PRINCE_FX.SAPPHIRE_LIGHT


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	HERO_AWAKEN.keep_rim(self)
	HERO_INPUT.read_input(self)
	_light_held_t = _light_held_t + delta if _light_held() else 0.0
	if _light_held_t <= 0.0:
		_recall_lock = false

	if not is_on_floor():
		velocity.y -= 30.0 * delta
	else:
		velocity.y = 0.0

	match state:
		State.MOVE: _prince_move(delta)
		State.ATTACK: _prince_attack(delta)
		State.DASH: _state_dash(delta)
		State.HURT: _state_hurt(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
		_:
			_set_state(State.MOVE)  # (no charge, leap or swing for him)
	_try_recall()

	move_and_slide()
	if _smash_phase < 0 and model.position.y > 0.0:
		model.position.y = move_toward(model.position.y, 0.0, 16.0 * delta)
	if state != State.ATTACK and (model.position.x != 0.0 or model.position.z != 0.0):
		model.position.x = move_toward(model.position.x, 0.0, 6.0 * delta)
		model.position.z = move_toward(model.position.z, 0.0, 6.0 * delta)
	var swinging: bool = state == State.ATTACK and _smash_phase < 0 and _move.range > 0.0 \
		and HERO_MOVES.progress(self) < _move.cancel
	for trail in _trails:
		trail.emitting = swinging and not _move.get("talon", false)
	hand_sword.visible = sword.state == SUNBRAND.S.HELD
	model.rotation.y = lerp_angle(model.rotation.y, _facing_yaw, 1.0 - exp(-25.0 * delta))


func _light_held() -> bool:
	return bot_hold_light if bot_enabled else Input.is_action_pressed("attack_light")


func _set_state(s: State) -> void:
	super._set_state(s)
	if s != State.ATTACK:
		_smash_phase = -1


# --- States ----------------------------------------------------------------------------------------

func _prince_move(delta: float) -> void:
	var dir := HERO_INPUT.input_dir(self)
	var speed := move_speed * (HERO_AWAKEN.SPEED_MULT if awakened else 1.0)
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	_face(HERO_INPUT.mouse_dir(self) if HERO_INPUT.mouse_aiming(self) else dir)
	_play_locomotion(dir)
	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0:
		_start_dash()
	elif _buffered != "":
		_prince_start(next_move(_buffered))


func _prince_attack(delta: float) -> void:
	if _smash_phase >= 0:
		_smash_tick(delta)
		return
	var t := HERO_MOVES.progress(self)
	if HERO_INPUT.mouse_aiming(self):
		HERO_INPUT.steer(self, delta)
	var lunge: float = _move.lunge * maxf(0.0, 1.0 - t * _move.get("decay", 3.0))
	var fwd := _facing()
	velocity.x = fwd.x * lunge
	velocity.z = fwd.z * lunge
	var hits: Array = _move.hits
	while _hits_done < hits.size() and t >= hits[_hits_done]:
		_hits_done += 1
		_prince_hit()
	var can_cancel := HERO_INPUT.can_dash_cancel(self, t)
	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0 and can_cancel:
		_start_dash()
		return
	if t >= HERO_INPUT.cancel_point(self) and _buffered != "":
		_prince_start(next_move(_buffered))
		return
	if t >= _move.end:
		_chain_reset_t = 0.35
		_set_state(State.MOVE)


## Hold L with the sword out (planted, or still flying): call it back. A Talon the press started is cut.
func _try_recall() -> void:
	if _recall_lock or _light_held_t < RECALL_HOLD or not sword.is_out() or sword.state == SUNBRAND.S.RETURN:
		return
	if state == State.MOVE or (state == State.ATTACK and _smash_phase < 0 and _move_id != "P_RECALL"):
		_recall_lock = true
		_prince_start("P_RECALL")


# --- Moves -----------------------------------------------------------------------------------------

## What a press of `kind` starts now (prince_moves.route over the sword's state).
func next_move(kind: String) -> String:
	return PRINCE_MOVES.route(kind, _move_id, state == State.ATTACK, _chain_i, sword.state_word(), sword_in_reach())


func sword_in_reach() -> bool:
	if sword.state != SUNBRAND.S.PLANTED:
		return false
	var p: Vector3 = sword.ground_point()
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() <= SMASH_REACH


func _prince_start(id: String) -> void:
	_buffered = ""
	_ready_t = ComicLook.READY_HOLD
	var chained := state == State.ATTACK
	move_log.append(id)
	_move_id = id
	_move = PRINCE_MOVES.MOVES[id].duplicate(true)
	_anim_mult = HERO_AWAKEN.base_anim_mult(self) * _move.get("speed", 1.0)
	_move_len = anim.get_animation(_clip_name(_move.anim)).length
	_hits_done = 0
	_connected = false
	_callout_done = false
	_hop_y0 = 0.0
	_hop_air = false
	_post_dash_t = 0.0
	_air_dash = false
	if id in PRINCE_MOVES.CHAIN:
		_chain_i = PRINCE_MOVES.CHAIN.find(id) + 1
	elif id in PRINCE_MOVES.TALONS:
		_chain_i = PRINCE_MOVES.TALONS.find(id) + 1
	else:
		_chain_i = 0
	if id == "P_SMASH":
		_start_smash()
		return
	HERO_INPUT.aim(self, chained)
	_set_state(State.ATTACK)
	attack_started.emit(id)
	if id == "P_RECALL":
		recalls += 1
		sword.recall(true)
		_callout_combo(id)
		Game.sfx("dash", -6.0)
	else:
		Game.sfx("swing", -3.0, 0.12)
	_play(_move.anim, 0.05, true)


func _prince_hit() -> void:
	var fwd := _facing()
	if _move.get("throw", false):
		throws += 1
		sword.throw(global_position + Vector3.UP * 1.1 + fwd * 0.6, fwd)
		Fx.swoosh(get_parent(), global_position + model.position, fwd, 2.2, 70.0, SWORD_TRAIL, _swoosh_flip, 0.2)
		_connected = true  # (the sword does its own hitting; the string goes on)
		Game.shake(_move.shake)
		return
	var hit_any := false
	if _move.has("breath") and (_hits_done == 1 or _move.anim == "Spellcast_Shoot"):
		hit_any = _breath(_move.breath, fwd, _hits_done == 1) > 0
	if _move.range > 0.0:
		var talon: bool = _move.get("talon", false)
		_swoosh_flip = not _swoosh_flip
		Fx.swoosh(get_parent(), global_position + model.position, fwd, _move.range * 0.9, _move.arc,
			TALON_TRAIL if talon else SWORD_TRAIL, _swoosh_flip, 0.3 if _move.get("big", false) else 0.24)
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e.is_alive():
				continue
			var to: Vector3 = e.global_position - global_position
			to.y = 0.0
			var d := to.length()
			if d > _move.range + e.radius:
				continue
			if d > 0.4 and rad_to_deg(fwd.angle_to(to / d)) > _move.arc * 0.5:
				continue
			var kb := to / d if d > 0.01 else fwd
			e.take_hit(_move.damage * _dmg_mult, kb * _move.knockback, _move.launch, _move.get("big", false))
			Fx.element_hit(get_parent(), e.global_position, "earth" if talon else "spirit", kb, _move.get("big", false))
			Game.register_hit(_move_id)
			hit_any = true
	if hit_any:
		_connected = true
		var tier: int = PRINCE_MOVES.COMBOS[_move_id].tier if PRINCE_MOVES.COMBOS.has(_move_id) and not _callout_done else 0
		_callout_combo(_move_id)
		Game.sfx("hit_big" if _move.get("big", false) else "hit")
		Game.hitstop(_move.stop + tier * ENDER_HITSTOP)
		Game.shake(_move.shake)
		if tier > 0 or _move.get("big", false):
			HERO_FX.camera_hit(fwd, tier)


## One tick of the cone, `k` of Dragon Breath's reach and damage. Returns foes hit.
func _breath(k: float, fwd: Vector3, first: bool) -> int:
	var reach := BREATH_RANGE * (0.6 + 0.4 * k)
	var arc := BREATH_ARC * (0.75 + 0.25 * k)
	if first:
		breaths += 1
		PRINCE_FX.breath(get_parent(), global_position + Vector3.UP * 0.9 + fwd * 0.45, fwd, reach, arc)
		if k >= 1.0:
			PRINCE_FX.say("FWAROOO!", global_position + fwd * 2.0, 0.5)
		Game.sfx("dash", -2.0, 0.1)
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > reach + e.radius or (d > 0.4 and rad_to_deg(fwd.angle_to(to / d)) > arc * 0.5 + 8.0):
			continue
		var kb := to / d if d > 0.01 else fwd
		e.take_hit(BREATH_DAMAGE * k * _dmg_mult, kb * 1.5, 0.0, false)
		Fx.element_hit(get_parent(), e.global_position, "earth", kb, false)
		Game.register_hit("P_BREATH")
		n += 1
	breath_hits += n
	if n > 0:
		Game.hitstop(0.03)
	return n


# --- The smash -------------------------------------------------------------------------------------

func _start_smash() -> void:
	_smash_phase = 0
	_smash_t = 0.0
	_smash_from = global_position
	_smash_to = sword.ground_point()
	var to := _smash_to - global_position
	to.y = 0.0
	if to.length() > 0.05:
		_face(to)
		model.rotation.y = _facing_yaw
	_smash_hang = _smash_to - to.normalized() * minf(SMASH_BEHIND, to.length()) if to.length() > 0.05 else _smash_to
	_set_state(State.ATTACK)
	attack_started.emit("P_SMASH")
	smashes += 1
	_play("Jump_Start", 0.05, true)
	Fx.dust(get_parent(), global_position, 10)
	_wing_ring(global_position, 1.6)
	Game.sfx("dash", -2.0)


func _wing_ring(at: Vector3, r: float) -> void:
	PRINCE_FX.COMIC_POP.spawn(get_parent(), Vector3(at.x, 0.05, at.z), {"ring": r, "ring_color": PRINCE_FX.CREAM, "ring_w": 0.16, "steps": 3})


func smash_hanging() -> bool:
	return _smash_phase == 0 or _smash_phase == 1


func _smash_tick(delta: float) -> void:
	_smash_t += delta
	velocity.x = 0.0
	velocity.z = 0.0
	match _smash_phase:
		0:  # rise: up and over, the sword still the target (a branded foe can move)
			if sword.state == SUNBRAND.S.PLANTED:
				_smash_to = sword.ground_point()
			var k := clampf(_smash_t / SMASH_RISE, 0.0, 1.0)
			var e := 1.0 - (1.0 - k) * (1.0 - k)
			model.position.y = SMASH_HEIGHT * e
			global_position = _smash_from.lerp(_smash_hang, e)
			if k >= 1.0:
				_smash_phase = 1
				_smash_t = 0.0
				_play("Jump_Idle", 0.08, true)
		1:  # hang
			model.position.y = SMASH_HEIGHT
			if _smash_t >= SMASH_HANG:
				if sword.state != SUNBRAND.S.PLANTED:  # recalled or gone mid-rise: float down
					_smash_phase = -1
					_set_state(State.MOVE)
					return
				_smash_to = sword.ground_point()
				_smash_phase = 2
				_smash_t = 0.0
				_invuln_t = SMASH_DIVE + 0.1
				_play("Ab_L3", 0.04, true)
				anim.seek(anim.get_animation(_clip_name("Ab_L3")).length * (PRINCE_MOVES.CLEAVE_HIT - 0.12), true)
				anim.speed_scale = 1.4
				Fx.afterimage(get_parent(), model, Color(PRINCE_FX.SAPPHIRE_LIGHT, 0.5))
		2:  # dive, pommel first
			var k := clampf(_smash_t / SMASH_DIVE, 0.0, 1.0)
			model.position.y = SMASH_HEIGHT * (1.0 - k * k)
			global_position = _smash_hang.lerp(_smash_to, k)
			if k >= 1.0:
				_smash_land()
		3:  # on one knee; the new sword forms on its own (sunbrand REFORM_TIME)
			if _dash_buffer_t > 0.0 and _dash_cd <= 0.0:
				_start_dash()
				return
			if _smash_t >= SMASH_LAND:
				_smash_phase = -1
				_chain_reset_t = 0.35
				_set_state(State.MOVE)


func _smash_land() -> void:
	global_position = Vector3(_smash_to.x, global_position.y, _smash_to.z)
	model.position.y = 0.0
	_smash_phase = 3
	_smash_t = 0.0
	_hits_done = 1
	var n: int = sword.detonate()
	_connected = n > 0
	_callout_combo("P_SMASH")
	PRINCE_FX.say("KRA-BLAMM!", _smash_to + Vector3.UP * 0.5, 0.78)
	Game.sfx("hit_big")
	Game.rumble("hit_big")
	Game.hitstop(SMASH_STOP)
	Game.shake(SMASH_SHAKE)
	HERO_FX.camera_hit(_facing(), 3)


## sunbrand.gd: the new sword has formed in his hand.
func sword_formed() -> void:
	reforms += 1
	var at := hand_sword.global_position + Vector3.UP * 0.5
	PRINCE_FX.summon(get_parent(), at)
	PRINCE_FX.say("SHWING!", at, 0.45)
	Game.sfx("perfect", -8.0, 0.05)


## sunbrand.gd: the recalled sword is back in his hand.
func sword_caught() -> void:
	PRINCE_FX.summon(get_parent(), hand_sword.global_position + Vector3.UP * 0.4)
	Game.sfx("hit", -6.0)


## sunbrand.gd: the Javelin bit a foe (branded).
func on_sword_hit(_e: Node) -> void:
	if _move_id == "P_JAVELIN":
		_callout_combo("P_JAVELIN")


## Names a landed string over him (hero_fx.combo_callout's look, his COMBOS).
func _callout_combo(id: String) -> void:
	if _callout_done or not PRINCE_MOVES.COMBOS.has(id):
		return
	_callout_done = true
	var tier: int = PRINCE_MOVES.COMBOS[id].tier
	combos_landed[id] = combos_landed.get(id, 0) + 1
	Game.sfx(COMBO_TIER_SFX[tier - 1], COMBO_SFX_DB, 0.03)
	_callout.text = PRINCE_MOVES.COMBOS[id].name
	_callout.modulate = COMBO_TIER_COLORS[tier - 1]
	Fx.combo_pop(get_parent(), global_position, PRINCE_FX.GOLD if tier < 3 else _callout.modulate, tier)
	_callout.position = Vector3(0.0, 2.9, 0.0)
	_callout.scale = Vector3.ONE * 0.6
	_callout.visible = true
	if _callout_tw:
		_callout_tw.kill()
	var tw := _callout.create_tween()
	_callout_tw = tw
	tw.tween_property(_callout, "scale", Vector3.ONE * 1.15, 0.08)
	tw.tween_property(_callout, "scale", Vector3.ONE, 0.08)
	tw.parallel().tween_property(_callout, "position:y", 3.2, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(_callout, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tw.tween_callback(_callout.hide)


# --- Read by the combo guide and the pause menu (duck-typed hooks) ------------------------------

## combo_guide.gd: his next-press rows (hero_moves.combo_options' shape).
func guide_rows() -> Array:
	var attacking := state == State.ATTACK
	if not (attacking or (state == State.MOVE and _chain_i > 0)) or _smash_phase >= 0:
		return []
	var rows := []
	for kind: String in ["light", "heavy"]:
		var id := next_move(kind)
		rows.append({"kind": kind, "id": id, "name": PRINCE_MOVES.guide_name(id),
			"tier": PRINCE_MOVES.COMBOS[id].tier if PRINCE_MOVES.COMBOS.has(id) else 0, "hold": false, "next": {}})
	return rows


## pause_menu.gd: the MOVES panel.
func move_sections() -> Array:
	return PRINCE_MOVES.SECTIONS
