extends RefCounted
## The combo breaker leap (player State.LEAP): an ender that connected throws him up and back with
## the tentacles on what the string hit, a floor cue rings the landing, a timed right click dives
## onto it (VOID_ELEMENT.breaker_impact) and anything else floats him down. Which ender leads where,
## and every window's numbers, are VOID_ELEMENT.BREAKERS; this file plays them. The timing circle
## (breaker_prompt.gd) reads window(). Static functions over the hero's state, like void_element.gd:
## the _brk_* state stays on player.gd, where the checks and the bot read it.
## See docs/features/combo-breakers.md.

const VOID_ELEMENT := preload("res://scripts/void_element.gd")
const BREAKER_QUAKE := preload("res://scripts/breaker_quake.gd")
const BREAKER_CUE := preload("res://scripts/breaker_cue.gd")
const BREAKER_PROMPT := preload("res://scripts/breaker_prompt.gd")
const ELEMENTS := preload("res://scripts/elements.gd")

# Combo breakers (VOID_ELEMENT.BREAKERS, timed finishers). The move leaps into the air at `leap`
# (fraction of its anim), hops `back` m while rising `height` m over `rise` s
# with the tentacles on the foes, and a cue rings a zone `zone` m ahead: press
# right click between `open` and `close` s after take-off (rings meet at `sweet`;
# within `perfect` of it = PERFECT, x`perfect_mult`) to dive onto it in `dive` s,
# slamming what he holds. Too early locks it out; no press = he floats down in `fall` s.
# The breaker window plays in slow motion (BREAKER_FOCUS time scale, camera
# pushed in to BREAKER_FOCUS_ZOOM), and a perfect press freezes the frame for
# BREAKER_PERFECT_STOP real s before the dive.
const BREAKER_FOCUS := 0.6
const BREAKER_FOCUS_ZOOM := 0.86
const BREAKER_PERFECT_STOP := 0.07
# Forgiving presses: a heavy in the first BREAKER_SPILL s after take-off is the
# ender's own mashed press spilling over and is ignored (no lockout), and one
# within BREAKER_EARLY s before `open` is held and fires as the window opens
# (a normal hit). Only a press between the two locks the breaker out.
const BREAKER_SPILL := 0.12
const BREAKER_EARLY := 0.12  # (was 0.08) a press up to 120 ms early is held, not locked out: on a 0.2 s rise that
# leaves only 0.12-0.18 s after take-off as the lockout, a press nowhere near the window


## The breaker this move leads to, if any (void_element.BREAKERS).
static func entry_for(id: String) -> Dictionary:
	return VOID_ELEMENT.entry(id) if VOID_ELEMENT.BREAKERS.has(id) else {}


## Combo breaker, part 1: leap up and back with the tentacles on what the string hit,
## and ring the landing with the timing cue.
static func start(hero: CharacterBody3D, id: String, entry: Dictionary) -> void:
	hero._brk_id = id
	hero._brk = entry
	hero._brk_phase = 0
	hero._brk_press = -1.0
	hero._brk_locked = false
	hero._brk_held = false
	hero._brk_cue = null
	hero._brk_focus = false
	hero._brk_ended = ""
	hero._brk_alt = false
	hero._brk_y0 = hero.model.position.y
	_make_prompt(hero)
	var dir: Vector3 = hero._facing()
	hero._brk_dir = dir
	var ahead: float = minf(entry.zone, hero._clear_ahead(dir, entry.zone) + 0.3)
	hero._brk_zone = Vector3(hero.global_position.x, 0.0, hero.global_position.z) + dir * ahead
	hero._buffered = ""
	hero._set_state(hero.State.LEAP)
	hero._play("Jump_Start", 0.05, true)
	Game.sfx("dash", -4.0, 0.05)
	Fx.dust(hero.get_parent(), hero.global_position, 10, 0.8)
	hero._void.seize(entry)  # the tentacles go out for what the string hit
	_aim(hero)


## Some of his breakers land where the string put them, however far off that is: Meteor Fall on whoever
## the tentacle has hold of, the dark ones `short` of dark_spot.
static func _aim(hero: CharacterBody3D) -> void:
	var b: Dictionary = hero._brk
	var void_grab: Node = hero._void
	var spot: Vector3
	if b.has("at_spot"):
		spot = void_grab.dark_spot
	elif b.has("meteor") and not void_grab.held_foes().is_empty():
		var held: Node3D = void_grab.held_foes()[0]
		spot = Vector3(held.global_position.x, 0.0, held.global_position.z)
	else:
		return
	var to := spot - Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	if to.length() > 0.1:
		hero._brk_dir = to.normalized()
	var dir: Vector3 = hero._brk_dir
	var short: float = b.get("short", 0.0)
	hero._brk_zone = spot - dir * minf(short, hero._clear_ahead(-dir, short) + to.length())  # (back off if he's already that close)
	if is_instance_valid(hero._brk_cue):
		hero._brk_cue.global_position = spot


## Combo breaker, part 2 (State.LEAP each frame): rise and hang, throw, wait for the timed press, then
## dive (pressed in the window) or float down (missed / locked out).
static func tick(hero: CharacterBody3D, delta: float) -> void:
	var b: Dictionary = hero._brk
	var t: float = hero._state_t
	var model: Node3D = hero.model
	hero._invuln_t = maxf(hero._invuln_t, 0.12)  # airborne: untouchable
	hero.velocity.x = 0.0
	hero.velocity.z = 0.0
	# Dash cancels anything, a breaker's hang included. (Not for the autotest
	# bot: its dodge presses would throw away the breakers it's there to test;
	# he's untouchable in the hang anyway. A string with the bot's "out" token does dash out: bot_out.)
	if hero._brk_phase == 0 and hero._dash_buffer_t > 0.0 and hero._dash_cd <= 0.0 and (not hero.bot_enabled or hero.bot_out):
		_dash_out(hero)
		return
	hero._void.seized_tick(hero._brk_phase, t, b)
	if hero._brk_phase == 0:
		_aim(hero)
		var dir: Vector3 = hero._brk_dir
		if t < b.rise:  # hop back (forward if `back` < 0) while rising
			var k: float = t / b.rise
			hero.velocity.x = -dir.x * b.back / b.rise
			hero.velocity.z = -dir.z * b.back / b.rise
			model.position.y = lerpf(hero._brk_y0, b.height, 1.0 - pow(1.0 - k, 3.0))
		else:
			model.position.y = b.height + sin((t - b.rise) * 9.0) * 0.06  # hangs
			if hero.anim.current_animation != "Jump_Idle":
				hero._play("Jump_Idle", 0.15)
		hero._face(dir)
		if t >= b.cue and hero._brk_cue == null:
			var cue := BREAKER_CUE.new()
			cue.color = color(hero)
			cue.crisp = true
			cue.open = b.open - b.cue
			cue.sweet = b.sweet - b.cue
			cue.close = b.close - b.cue
			hero._brk_cue = cue
			hero.get_parent().add_child(cue)
			cue.global_position = hero._brk_zone
		if not hero._brk_locked and not hero._brk_focus and t >= b.open:
			hero._brk_focus = true  # the window opens: slow down, push in
			Game.hitstop((b.close - b.open) / BREAKER_FOCUS, BREAKER_FOCUS)
			if Game.camera_rig:
				Game.camera_rig.punch(BREAKER_FOCUS_ZOOM, (b.close - b.open) / BREAKER_FOCUS)
			Game.sfx("heartbeat", -6.0, 0.0)
			# The war cry marks the window: he roars in the slowed hang.
			Game.sfx("war_cry", -3.0, 0.06)
			BREAKER_QUAKE.war_cry(hero.get_parent(), hero.global_position + Vector3.UP * (model.position.y + 1.5), color(hero), element(hero), false)  # (its bubble hid him and filled the floor)
		if not hero._brk_locked and not hero._brk_held and _pressed(hero, t):
			if t < BREAKER_SPILL:
				pass  # the ender's own press spilling over: ignored
			elif t >= b.open - BREAKER_EARLY and t < b.open:
				hero._brk_held = true  # a hair early: dives as the window opens
			elif t < b.open:
				hero._brk_locked = true  # too early: no breaker this time
				hero._brk_ended = "lock"
				if is_instance_valid(hero._brk_cue):
					hero._brk_cue.lock()
				Game.sfx("player_hurt", -14.0, 0.0)
			else:
				hero._brk_press = t
				_start_dive(hero)
				return
		if hero._brk_held and t >= b.open:
			hero._brk_press = t
			_start_dive(hero)
			return
		if t > b.close:
			if hero._brk_ended == "":
				hero._brk_ended = "miss"
			hero._void.release_seized()
			hero._brk_phase = 2
			hero._state_t = 0.0
			hero._play("Jump_Idle", 0.1)
	elif hero._brk_phase == 1:
		var k: float = clampf(t / b.dive, 0.0, 1.0)
		var to: Vector3 = hero._brk_zone - hero._brk_dive_from
		to.y = 0.0
		hero.velocity.x = to.x / b.dive
		hero.velocity.z = to.z / b.dive
		model.position.y = b.height * (1.0 - k * k)
		hero._ghost_t -= delta
		if hero._ghost_t <= 0.0:
			hero._ghost_t = 0.02
			if b.has("meteor"):  # (the tail on the shell does the work: this is what comes off it)
				Fx.burst(hero.get_parent(), model.global_position + Vector3.UP, VOID_ELEMENT.METEOR_HOT, 5, 3.0, 0.14, 0.3, Vector3.UP, 60.0)
			else:  # the dive comes down like a comet in his element
				_comet(hero, color(hero))
		if is_instance_valid(hero._brk_meteor):
			hero._brk_meteor.global_position = model.global_position + Vector3.UP
		if k >= 1.0:
			_impact(hero)
	elif hero._brk_phase == 3:
		_tick_beats(hero, t)
	else:
		var k: float = clampf(t / b.fall, 0.0, 1.0)
		model.position.y = b.height * (1.0 - k * k)
		if k >= 1.0:
			_end(hero)
			Fx.dust(hero.get_parent(), hero.global_position, 8, 0.6)


## The breaker press this frame: heavy, light where the breaker has an `alt`, or the autotest bot at the
## sweet spot. Which one it was is in hero._brk_alt.
static func _pressed(hero: CharacterBody3D, t: float) -> bool:
	var b: Dictionary = hero._brk
	if hero.bot_enabled:
		hero._brk_alt = hero.bot_alt
		return t >= b.sweet
	if b.has("alt") and Input.is_action_just_pressed("attack_light"):
		hero._brk_alt = true
		return true
	hero._brk_alt = false
	return Input.is_action_just_pressed("attack_heavy")


static func _start_dive(hero: CharacterBody3D) -> void:
	var b: Dictionary = hero._brk
	var void_grab: Node = hero._void
	if hero._brk_alt and b.has("alt"):
		b.merge(b.alt, true)
	if b.has("cubes") or b.has("refreeze"):
		void_grab.freeze_seized()
	if b.has("refreeze"):  # Flash Freeze: the frost climbs over each as he dives
		for e: Node3D in void_grab.held_foes():
			VOID_ELEMENT.COMIC_FREEZE.foe(hero.get_parent(), e)
	if b.has("black_ice"):
		VOID_ELEMENT.freeze_pool(hero)
	elif b.has("maw"):
		void_grab.dark_maw = VOID_ELEMENT.DARK.maw(hero.get_parent(), void_grab.dark_spot, VOID_ELEMENT.MAW_RADIUS)
	if b.has("abyss") and is_instance_valid(void_grab.dark_bind):
		void_grab.dark_bind.sink = VOID_ELEMENT.ABYSS_SINK
	if b.has("press"):
		void_grab.aim_crush()
	_aim(hero)
	var perfect: bool = absf(hero._brk_press - b.sweet) <= b.perfect
	hero._brk_ended = "perfect" if perfect else "hit"
	if is_instance_valid(hero._brk_cue):
		hero._brk_cue.hit(perfect)
	if hero._brk_focus:
		Game.end_slowmo()
	if perfect:
		Game.hitstop(BREAKER_PERFECT_STOP, 0.05)
		Game.sfx("perfect", -4.0, 0.0)
	if b.has("gather"):  # Meteor Fall: two beats in the hang before the dive (_tick_beats)
		hero._brk_phase = 3
		hero._brk_beat = 0
		hero._state_t = 0.0
		Fx.flash(hero.model)
		VOID_ELEMENT.meteor_wall(hero)
		return
	_dive(hero)


## Meteor Fall's hang after the press (phase 3): beat 1 (meteor_wall, on the press) has thrown them at the walls;
## once they've hit, beat 2 drags them all into one pile (meteor_gather), and once that's in, beat 3 is the dive.
static func _tick_beats(hero: CharacterBody3D, t: float) -> void:
	var b: Dictionary = hero._brk
	hero.model.position.y = b.height + sin(t * 9.0) * 0.06
	hero._face(hero._brk_dir)
	var flying: bool = VOID_ELEMENT.pile_flying(hero)
	if hero._brk_beat == 0:
		if t >= VOID_ELEMENT.METEOR_GATHER_AT and (not flying or t >= VOID_ELEMENT.METEOR_GATHER_LATE):
			hero._brk_beat = 1
			hero._state_t = 0.0
			Game.hitstop(VOID_ELEMENT.METEOR_BEAT_STOP)
			hero._play("Ab_GR", 0.05, true)
			VOID_ELEMENT.meteor_gather(hero)
	elif t >= VOID_ELEMENT.METEOR_DRAG_TIME and (not flying or t >= VOID_ELEMENT.METEOR_DIVE_LATE):
		hero._brk_beat = 2
		Game.hitstop(VOID_ELEMENT.METEOR_BEAT_STOP)
		Game.sfx("hit_big", -4.0, 0.1)
		_dive(hero)


## The dive itself: down onto the zone in `dive` s (phase 1), as the meteor where the breaker is one.
static func _dive(hero: CharacterBody3D) -> void:
	var b: Dictionary = hero._brk
	var model: Node3D = hero.model
	if b.has("meteor"):
		var run: Vector3 = hero._brk_zone - Vector3(hero.global_position.x, 0.0, hero.global_position.z)
		hero._brk_meteor = VOID_ELEMENT.meteor_shell(hero.get_parent(), Vector3(run.x, -b.height, run.z))
		hero._brk_meteor.global_position = model.global_position + Vector3.UP
	hero._brk_phase = 1
	hero._state_t = 0.0
	hero._brk_dive_from = hero.global_position
	hero._play("Ab_VS", 0.03, true)
	hero.anim.seek(hero.anim.current_animation_length * 0.3, true)
	Game.sfx("ult", -6.0, 0.0)
	Fx.flash(model)
	if Game.camera_rig:
		Game.camera_rig.punch(0.85, 0.3)


## The dive lands: the element's slam (VOID_ELEMENT.breaker_impact), the crater, name the breaker.
static func _impact(hero: CharacterBody3D) -> void:
	var b: Dictionary = hero._brk
	var void_grab: Node = hero._void
	var el := element(hero)
	var at := Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	var perfect: bool = absf(hero._brk_press - b.sweet) <= b.perfect
	var mult: float = (b.perfect_mult if perfect else 1.0) * hero._cast_power()
	if is_instance_valid(hero._brk_meteor):
		hero._brk_meteor.queue_free()
	VOID_ELEMENT.breaker_impact(hero, b, at, void_grab.held_foes() if b.has("cubes") or b.has("rip") else void_grab.slam_seized(), mult)
	# Barbaric landing: the floor breaks (the element erupts under each foe already).
	if not b.has("press") and not b.has("at_spot"):  # (its ice buried the cubes as they left; the dark ones have their own)
		BREAKER_QUAKE.crater(hero.get_parent(), at, el, maxf(b.radius, 2.4), true, perfect)
	Game.sfx("quake", -2.0 if perfect else -5.0, 0.05)
	if b.radius > 0.0:
		ELEMENTS.hit_area(hero.get_tree(), at, b.radius, b.damage * hero._dmg_mult * mult, b.launch, true, "breaker")
	Game.hitstop(0.18 if perfect else 0.12, 0.05)
	Game.shake(0.8 if perfect else 0.6)
	if Game.camera_rig:
		Game.camera_rig.punch(0.75 if perfect else 0.82, 0.35)
	Game.add_awakening(b.awaken_perfect if perfect else b.awaken)
	hero.breakers_landed += 1
	hero.breakers_seen[hero._brk_id] = true
	hero.endings_seen[breaker_name(hero)] = true
	if perfect:
		hero.breaker_perfects += 1
	_callout(hero, breaker_name(hero), perfect)
	if hero.bot_enabled:
		hero.bot_log.append("[autotest] combo_breaker #%d %s perfect=%s" % [hero.breakers_landed, hero._brk_id, perfect])
	_end(hero)


## The breaker's name over his head, bigger and gold on a perfect.
static func _callout(hero: CharacterBody3D, text: String, perfect: bool) -> void:
	var label: Label3D = hero._callout
	Game.sfx(hero.COMBO_TIER_SFX[2], hero.COMBO_SFX_DB, 0.0)
	label.text = text + ("\nPERFECT" if perfect else "")
	label.modulate = hero.COMBO_TIER_COLORS[2] if perfect else hero._fx_color().lerp(Color.WHITE, 0.3)
	label.position = Vector3(0.0, 2.9, 0.0)
	label.scale = Vector3.ONE * 0.6
	label.visible = true
	if hero._callout_tw:
		hero._callout_tw.kill()
	var tw := label.create_tween()
	hero._callout_tw = tw
	tw.tween_property(label, "scale", Vector3.ONE * (1.35 if perfect else 1.15), 0.08)
	tw.tween_property(label, "scale", Vector3.ONE * (1.15 if perfect else 1.0), 0.08)
	tw.parallel().tween_property(label, "position:y", 3.3, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.tween_callback(label.hide)


## Dash out of a breaker's hang (before the press): the breaker is off, what
## he holds drops, the floor cue goes, the slow motion ends and he dashes. The
## prompt shows it as a miss.
static func _dash_out(hero: CharacterBody3D) -> void:
	hero._brk_ended = "miss"
	hero._void.release_seized()
	if is_instance_valid(hero._brk_cue):
		hero._brk_cue.queue_free()
	if hero._brk_focus:
		Game.end_slowmo()
	hero.velocity = Vector3.ZERO
	hero._brk_cue = null
	hero._chain_i = 0
	hero._set_state(hero.State.MOVE)  # (the model settles from the hang during the dash)
	hero._start_dash()


static func _end(hero: CharacterBody3D) -> void:
	hero._void.release_seized()
	hero._buffered = ""  # the press that dove him isn't a grab as well
	hero.velocity = Vector3.ZERO  # (the dive speed would carry on)
	hero.model.position.y = 0.0
	hero._brk_cue = null
	hero._chain_i = 0
	hero._set_state(hero.State.MOVE)


## One beat of a breaker dive's comet (every 0.02 s as he drops): one fat inked streak that ends in a
## held impact star when the beats stop (comic_comet.gd).
static func _comet(hero: CharacterBody3D, c: Color) -> void:
	load("res://scripts/comic_comet.gd").beat(hero.get_parent(), hero.model, c)


## The breaker timing prompt (breaker_prompt.gd) reads this every frame:
## `live` while the press is still to come (times in s since take-off, the
## hero's colour); otherwise how the last one `ended` ("perfect", "hit",
## "lock" = too early, "miss" = no press).
static func window(hero: CharacterBody3D) -> Dictionary:
	if hero.state == hero.State.LEAP and hero._brk_phase == 0 and not hero._brk_locked:
		var b: Dictionary = hero._brk
		return {"live": true, "t": hero._state_t, "open": b.open, "sweet": b.sweet, "close": b.close, "color": color(hero),
			"name": breaker_name(hero), "alt_name": b.alt.names.spirit if b.has("alt") else ""}
	return {"ended": hero._brk_ended}


## The timing circle, made on his first leap in its own CanvasLayer.
static func _make_prompt(hero: CharacterBody3D) -> void:
	if hero._brk_prompt != null:
		return
	var layer := CanvasLayer.new()
	hero.add_child(layer)
	var prompt := BREAKER_PROMPT.new()
	prompt.player = hero
	hero._brk_prompt = prompt
	layer.add_child(prompt)


## A breaker's shared effects: in what it lands in, if it says, instead of his axe's teal.
static func color(hero: CharacterBody3D) -> Color:
	var b: Dictionary = hero._brk
	return VOID_ELEMENT.ELEMENTS.LOOK[b.erupt].color if b.has("erupt") else hero._fx_color()


## The element a breaker's effects come in: his own, unless the breaker says otherwise.
static func element(hero: CharacterBody3D) -> String:
	var b: Dictionary = hero._brk
	return VOID_ELEMENT.breaker_element(b) if b.has("erupt") else hero.element()


## The breaker in play's name for the current element.
static func breaker_name(hero: CharacterBody3D) -> String:
	var b: Dictionary = hero._brk
	return b.names.get(hero.element(), b.names.spirit) if not b.is_empty() else ""
