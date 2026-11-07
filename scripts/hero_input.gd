extends RefCounted
## The hero's input feel: reading presses into the buffer, when the current move takes the next press
## (cancel_point, hit-confirm, the dash cancel), the stick or the bot's direction, and aim (mouse aim,
## the soft lock-on, the per-move aim lock). Static functions over the hero's state, like
## void_element.gd: the buffer and timers stay on player.gd, where the checks and the bot read them.
## Numbers: tests/rhythm_check.gd.

const HERO_MOVES := preload("res://scripts/hero_moves.gd")
const HERO_LEAP := preload("res://scripts/hero_leap.gd")
const HERO_AWAKEN := preload("res://scripts/hero_awaken.gd")

## Input feel (round 30; tests/rhythm_check.gd).
## A press of L / right click / dash / R is remembered this long and fires on the first frame it's legal
## (the next move's cancel point, the end of a dash). 300: L1 cancels 0.275 s in, so a press as a move
## starts still carries; much longer and a mashed ender spills into a whole extra string.
const BUFFER_MS := 300
## Hit-confirm: once the move has connected, its cancel point comes CANCEL_ON_HIT of the way back from
## `cancel` toward its last hit, so a string that lands flows faster than one swung at air (a whiff keeps
## the table's `cancel`: the recovery is the whiff's price). Never before HIT_CONFIRM_MIN s (move time)
## after the last hit, nor before a breaker's `leap`.
const CANCEL_ON_HIT := 0.5  # a move's `confirm` overrides it (Rockslide: hero_moves.ROCKSLIDE_CONFIRM)
const HIT_CONFIRM_MIN := 0.03
## A dash cancels any move once its first hit is out, or this far into it on a whiff (fraction).
const DASH_CANCEL_WHIFF := 0.2
## A dash hands over to the press buffered in it (round 41, feel audit 2 item 10; hero_moves.DASH_STAB_CANCEL):
## a dash that cancelled a move ends DASH_STAB_CANCEL of the way in for a light (Dash Stab); any dash with a light buffered ends once a foe ahead is inside DASH_ARRIVE m (after DASH_ARRIVE_MIN of
## it), so the dash doesn't carry him through the foe the stab is for (the bot's D L H from 2 m went 3.8 m, past it).
const DASH_ARRIVE := 2.8  # m: Dash Stab's range
const DASH_ARRIVE_ARC := 35.0  # deg either side of the dash
const TOW_LINE_CANCEL := 0.7  # of dash_time: a dash out of a move hands over to a buffered right click (Tow Line) here
const DASH_ARRIVE_MIN := 0.25  # of dash_time: always this much dash (1 m), so it still reads as one
## Mouse aim keeps the foe a move started on (hero._aim_lock) while the cursor stays within AIM_LOCK_BREAK
## deg of it, so the per-frame turn doesn't flick between two foes mid-string; past that the cursor wins.
const AIM_LOCK_BREAK := 40.0
## Mouse aim (mouse_aiming). He faces the cursor while free and turns toward it at a limited rate
## through a combo, so a string can be redirected but not spun on the spot.
const AIM_HEIGHT := 0.8  # m: the cursor is read on this plane, about where a foe's body is
const AIM_DEAD_ZONE := 0.35  # m round him where the cursor stops steering, or he'd spin
const AIM_ASSIST_MOUSE_ANGLE := 25.0  # deg: the cursor says where, so the soft lock is narrower
const COMBO_REDIRECT := 55.0  # deg a chained move may turn as it starts
const COMBO_TURN_WINDUP := 420.0  # deg/s before a move's first hit
const COMBO_TURN_ACTIVE := 140.0  # deg/s from then on


# --- Presses --------------------------------------------------------------------

## This frame's presses into the buffer (L / right click share one slot; R and dash have their own).
static func read_input(hero: CharacterBody3D) -> void:
	if hero.state == hero.State.DEAD:
		return
	if Input.is_action_just_pressed("attack_light"):
		hero._buffered = "light"
		hero._buffer_t = hero.input_buffer
	elif Input.is_action_just_pressed("attack_heavy"):
		hero._buffered = "heavy"
		hero._buffer_t = hero.input_buffer
	if Input.is_action_just_pressed("traverse"):
		hero._swing_buffer_t = hero.input_buffer
	if Input.is_action_just_pressed("dash"):
		hero._dash_buffer_t = hero.input_buffer
	if Input.is_action_just_pressed("awaken"):
		HERO_AWAKEN.try_awaken(hero)


## The last device touched decides, so a gamepad goes back to facing the way he runs.
static func note_device(hero: CharacterBody3D, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hero._mouse_active = true
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		hero._mouse_active = false


## The stick (or the autotest bot's bot_move) as a flat direction.
static func input_dir(hero: CharacterBody3D) -> Vector3:
	if hero.bot_enabled:
		return hero.bot_move
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return Vector3(v.x, 0.0, v.y)


# --- When the next press is taken -----------------------------------------------

## Where the current move takes the next press (fraction of its clip): `cancel`, or earlier once it has
## connected (CANCEL_ON_HIT, HIT_CONFIRM_MIN), never before a breaker's leap.
static func cancel_point(hero: CharacterBody3D) -> float:
	var move: Dictionary = hero._move
	var c: float = move.get("cancel", 0.0)
	if not hero._connected or hero._hits_done < move.hits.size():
		return c
	var last: float = move.hits[-1]
	var early := maxf(lerpf(c, last, move.get("confirm", CANCEL_ON_HIT)), last + HIT_CONFIRM_MIN * hero.anim_speed * hero._anim_mult / hero._move_len)
	var brk: Dictionary = HERO_LEAP.entry_for(hero._move_id)
	if not brk.is_empty() and move.get("leap", brk.leap) <= c:  # (a leap after the cancel, Harpoon's: the press wins it)
		early = maxf(early, move.get("leap", brk.leap))
	return minf(c, early)


## Round 51 (fluidity): in a pause window (BREAKERS `pause`: Harpoon, Impale) a press of a button whose route would not go
## on down the string (L off Harpoon restarted the chain at the hammer, H off Impale grabbed) is held for the window
## instead of firing at the cancel: hero_leap.start dives on it as the window opens (like BREAKER_EARLY), with that
## button's ending (Slapshot, Anvil). The documented early routes still fire: H off Harpoon is Ice Cube, L off Impale
## is Backdraft. (tests/input_snap_check.gd)
static func held_for_window(hero: CharacterBody3D) -> bool:
	if hero._buffered == "" or not hero._connected:
		return false
	var b: Dictionary = HERO_LEAP.entry_for(hero._move_id)
	if b.is_empty() or not b.get("pause", false) or HERO_MOVES.pause_ending(hero._move_id, hero._buffered) == "":
		return false
	var id: String = hero._next_move(hero._buffered)
	return id == HERO_MOVES.VOID_ELEMENT.NEUTRAL or id in HERO_MOVES.LIGHT_CHAIN


## Whether a dash may cut the current move at progress `t`: once its first hit is out, or past
## DASH_CANCEL_WHIFF on a whiff. (R's swing follows the same rule.)
static func can_dash_cancel(hero: CharacterBody3D, t: float) -> bool:
	return hero._hits_done > 0 or t > DASH_CANCEL_WHIFF


## Whether the dash ends now and hands over to the buffered press (DASH_ARRIVE*, hero_moves.DASH_STAB_CANCEL).
static func dash_hands_over(hero: CharacterBody3D) -> bool:
	if hero._buffered == "":
		return false
	var t: float = hero._state_t / maxf(hero.dash_time, 0.001)
	if hero._buffered != "light":
		# (a right click waits out most of the dash: Tow Line's line is the dash, and at DASH_STAB_CANCEL a short one lost
		# frozen x dark. Round 51: a dash out of a move hands over at TOW_LINE_CANCEL, EF / IP -> Tow Line 365-380 ms.)
		return hero._buffered == "heavy" and hero._dash_out and t >= TOW_LINE_CANCEL
	if hero._dash_out and t >= HERO_MOVES.DASH_STAB_CANCEL:
		return true
	if t < DASH_ARRIVE_MIN:
		return false
	for e in hero.get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - hero.global_position
		to.y = 0.0
		if to.length() <= DASH_ARRIVE and to.length() > 0.01 and rad_to_deg(hero._dash_dir.angle_to(to.normalized())) <= DASH_ARRIVE_ARC:
			return true
	return false


## How soon a press is taken: `progress` 0..1 toward the move's cancel point,
## `ready` once a press now would be buffered into the next move (input_buffer);
## while charging, how far the charge is and whether it's full.
static func combo_window(hero: CharacterBody3D) -> Dictionary:
	var dash_ready: bool = hero._dash_cd <= 0.0
	if hero.state == hero.State.CHARGE:
		return {"progress": clampf(hero._state_t / hero.CHARGE_TIME, 0.0, 1.0), "ready": hero._charged, "dash": dash_ready}
	if hero.state != hero.State.ATTACK:
		return {"progress": 1.0, "ready": true, "dash": dash_ready}
	var t := HERO_MOVES.progress(hero)
	var cancel := cancel_point(hero)
	var left: float = (cancel - t) * hero._move_len / (hero.anim_speed * hero._anim_mult)
	return {"progress": clampf(t / cancel, 0.0, 1.0), "ready": left <= hero.input_buffer,
		"dash": dash_ready and can_dash_cancel(hero, t)}


# --- Aim ------------------------------------------------------------------------

static func mouse_aiming(hero: CharacterBody3D) -> bool:
	return hero._mouse_active and not hero.bot_enabled and DisplayServer.get_name() != "headless"


## Flat direction from him to the cursor; zero with no camera or a cursor on top of him.
static func mouse_dir(hero: CharacterBody3D) -> Vector3:
	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var at := hero.get_viewport().get_mouse_position()
	var ray := cam.project_ray_normal(at)
	if absf(ray.y) < 0.001:
		return Vector3.ZERO
	var from := cam.project_ray_origin(at)
	var hit := from + ray * ((hero.global_position.y + AIM_HEIGHT - from.y) / ray.y)
	var to := hit - hero.global_position
	to.y = 0.0
	return to.normalized() if to.length() > AIM_DEAD_ZONE else Vector3.ZERO


## Mid-move under mouse aim: turn toward the cursor (or the locked foe) at the combo's limited rate.
static func steer(hero: CharacterBody3D, delta: float) -> void:
	var rate := COMBO_TURN_WINDUP if hero._hits_done == 0 else COMBO_TURN_ACTIVE
	hero._face(hero._turned(aim_want(hero, true), rate * delta))


## Soft lock-on: rotate toward the best enemy roughly in front of us. `chained`: this move
## follows another, so under mouse aim it only turns part of the way (see COMBO_REDIRECT).
static func aim(hero: CharacterBody3D, chained := false) -> void:
	var want := aim_want(hero)
	if chained and mouse_aiming(hero):
		hero._face(hero._turned(want, COMBO_REDIRECT))
		return
	hero._face(want)
	hero.model.rotation.y = hero._facing_yaw  # snap: attacks must point where they hit


## Where an attack wants to point: the cursor (else the stick, else ahead), pulled onto a foe near that line.
## `held`: mid-move, stay on the foe the move started on while the cursor is near it (AIM_LOCK_BREAK).
static func aim_want(hero: CharacterBody3D, held := false) -> Vector3:
	var mouse := mouse_aiming(hero)
	var dir := mouse_dir(hero) if mouse else input_dir(hero)
	var want: Vector3 = dir.normalized() if dir.length() > 0.1 else hero._facing()
	var lock: Variant = hero._aim_lock  # (untyped: it can be a freed foe, and a typed var won't take one)
	if held and is_instance_valid(lock) and lock.is_alive():
		var to_lock: Vector3 = lock.global_position - hero.global_position
		to_lock.y = 0.0
		if to_lock.length() > 0.01 and rad_to_deg(want.angle_to(to_lock.normalized())) <= AIM_LOCK_BREAK:
			return to_lock
	var max_angle: float = AIM_ASSIST_MOUSE_ANGLE if mouse else hero.aim_assist_angle
	var best: Node3D = null
	var best_score := INF
	for e in hero.get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - hero.global_position
		to.y = 0.0
		var d := to.length()
		if d > hero.aim_assist_range or d < 0.01:
			continue
		var ang := rad_to_deg(want.angle_to(to / d))
		if ang > max_angle:
			continue
		var score := d + ang * 0.05
		if score < best_score:
			best_score = score
			best = e
	if best:
		want = best.global_position - hero.global_position
		want.y = 0.0
	if not held:
		hero._aim_lock = best
	return want
