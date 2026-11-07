extends RefCounted
## The dash counter (kit grammar slot 9, docs/characters/kit-grammar.md section 4; docs/features/counter.md): Space
## pressed while a foe's strike is coming (`enemy.strike_in()` within WINDOW s of contact) and the dash aimed within
## ARC degrees of it turns the dash into the heretic's counter, Backlash (KRRAK-SNAP!): i-frames through the strike,
## a hitstop and the parry flash (counter_fx.gd: the tentacle catching the weapon, violet), the attacker staggered and
## marked (Reap's mark, dark_fx.mark), then the tentacle wraps it, swings it up over him and slams it down in front.
## Pressed in the last PERFECT s it is a perfect counter: after the slam the counter breaker window opens (hero_leap,
## BREAKERS "CB"), one ending, Ricochet: the tentacle hurls the attacker into the nearest foe or wall (a wall splat),
## and it is bound where it lands. An enemy bolt (projectile.gd) inside the window is parried back at its shooter.
## A dash with nothing coming is the dash, so pressing it costs nothing.
## Static functions over the hero (the hero_*.gd pattern): player._start_dash calls try_start(), State.DASH runs
## tick() while hero._counter is set, and void_element.breaker_impact calls ricochet() for the window's ending.

const VOID_ELEMENT := preload("res://scripts/void_element.gd")
const HERO_LEAP := preload("res://scripts/hero_leap.gd")
const FX := preload("res://scripts/counter_fx.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const FLOOR_BIND := preload("res://scripts/floor_bind.gd")
const FLOURISH := preload("res://scripts/env_flourish.gd")  # round 53: gallows (a hook in reach takes Ricochet)
const ENV := preload("res://scripts/env_target.gd")

## The trigger: game s before the strike lands that a dash counters it (the windup's last WINDOW s, up to the strike
## frame), the last PERFECT s of it a perfect; the dash aimed within ARC degrees of the attacker; the attacker no
## further than its strike's reach plus REACH_PAD (the strike is meant for him).
const WINDOW := 0.25
const PERFECT := 0.1
const ARC := 60.0
const REACH_PAD := 1.2  # m
const BOLT_PAD := 0.5  # m beside a bolt's line that still counts as in its way
## The parry: a hitstop of STOP (PERFECT_STOP) s at STOP_SCALE, the shake, the Awakening it pays.
const STOP := 0.1
const PERFECT_STOP := 0.16
const STOP_SCALE := 0.04
const AWAKEN := 6.0
const AWAKEN_PERFECT := 10.0
const WORD := "KRRAK-SNAP!"
const WORD_SCALE := 0.62  # (ComicFx.WORD_SCALE units; the breakers' words are 0.78)
## Backlash, in game s from the parry: the tentacle is on it by WRAP, has it up over him (LIFT_Y m, LIFT_AHEAD m in
## front) by LIFT, slams it down SLAM_AHEAD m in front of him at SLAM for DAMAGE, and lets go by END. The attacker is
## staggered for the lot and he is untouchable until END + INVULN_PAD.
const WRAP := 0.1
const LIFT := 0.26
const SLAM := 0.38
const END := 0.52
const LIFT_Y := 1.9
const LIFT_AHEAD := 0.5
const SLAM_AHEAD := 1.7
const DAMAGE := 18.0
const STAGGER := 1.0  # s past END
const INVULN_PAD := 0.15
const SLAM_STOP := 0.08
const CHEST := Vector3(0.0, 0.9, 0.0)
## A bolt parried: it goes back at its shooter REFLECT_SPEED times as fast for REFLECT_MULT of its damage; he holds
## the parry pose BOLT_END s.
const REFLECT_SPEED := 1.6
const REFLECT_MULT := 2.0
const BOLT_END := 0.22
## The perfect counter's window (VOID_ELEMENT.BREAKERS "CB", the shared window rhythm) and its ending, Ricochet: the
## attacker hurled at RICOCHET_SPEED into the nearest living foe or wall within RICOCHET_REACH of it, BREAKERS.CB.damage (30)
## (x RICOCHET_WALL_MULT on a wall; the foe it hits takes thrown_foe.OTHER_MULT of it), then bound BIND_TIME s where it
## lands. With neither in reach it flies RICOCHET_OPEN m along his aim and lands.
const BREAKER := "CB"
const RICOCHET_WALL_MULT := 2.5
const RICOCHET_REACH := 10.0
const RICOCHET_OPEN := 7.0
const RICOCHET_SPEED := 24.0
const RICOCHET_CUE_MS := 1400
const BIND_TIME := 1.6

static var last_ricochet := ""  # "foe" / "wall" / "open" / "hook": where the last Ricochet went (counter_check)


## The strike (or bolt) a dash along `dir` would counter now, or {}: {foe, t (game s to contact), bolt, perfect}.
static func find(hero: CharacterBody3D, dir: Vector3) -> Dictionary:
	var best := {}
	var me: Vector3 = hero.global_position
	for e: Node in hero.get_tree().get_nodes_in_group("enemies"):
		if not e.has_method("strike_in") or not e.is_alive():
			continue
		var t: float = e.strike_in()
		if t < 0.0 or t > WINDOW:
			continue
		var to: Vector3 = (e as Node3D).global_position - me
		to.y = 0.0
		var d := to.length()
		if d > e.strike_reach() + REACH_PAD or not _aimed(dir, to):
			continue
		if best.is_empty() or t < best.t:
			best = {"foe": e, "t": t, "bolt": null}
	for p: Node in hero.get_tree().get_nodes_in_group("projectiles"):
		if p.get("reflected") == true or p.is_queued_for_deletion():
			continue
		var rel: Vector3 = me + Vector3.UP - (p as Node3D).global_position
		var along: float = rel.dot(p.direction)
		if along <= 0.0 or (rel - p.direction * along).length() > float(p.hit_radius) + BOLT_PAD:
			continue
		var t := maxf(along - float(p.hit_radius), 0.0) / maxf(float(p.speed), 0.1)
		var to: Vector3 = (p as Node3D).global_position - me
		to.y = 0.0
		if t > WINDOW or not _aimed(dir, to):
			continue
		if best.is_empty() or t < best.t:
			best = {"foe": p.source if is_instance_valid(p.source) else null, "t": t, "bolt": p}
	if not best.is_empty():
		best.perfect = best.t <= PERFECT
	return best


static func _aimed(dir: Vector3, to: Vector3) -> bool:
	return to.length() < 0.05 or rad_to_deg(dir.angle_to(to.normalized())) <= ARC


## player._start_dash: the counter instead of the dash, if a strike is coming along `dir`. True if it countered.
static func try_start(hero: CharacterBody3D, dir: Vector3) -> bool:
	var c := find(hero, dir)
	if c.is_empty():
		return false
	start(hero, c)
	return true


## The parry lands: hitstop, flash, the attacker staggered and marked, Backlash's tentacle out to it.
static func start(hero: CharacterBody3D, c: Dictionary) -> void:
	var parent: Node = hero.get_parent()
	var perfect: bool = c.perfect
	var bolt: Variant = c.bolt
	var e: Variant = c.foe
	hero._dash_buffer_t = 0.0
	hero._dash_cd = hero.dash_cooldown
	hero._dash_from = hero.global_position
	hero._dash_out = false
	hero._air_dash = false
	hero._since_dash = 0.0
	hero._perfect_this_dash = true  # (the strike it stopped is no perfect dodge as well)
	hero._anim_mult = hero.HERO_AWAKEN.base_anim_mult(hero)
	hero.counters += 1
	if perfect:
		hero.counter_perfects += 1
	var at: Vector3 = (bolt as Node3D).global_position if bolt != null else (e as Node3D).global_position
	var to := at - hero.global_position
	to.y = 0.0
	hero._face(to)
	hero.model.rotation.y = hero._facing_yaw
	hero._set_state(hero.State.DASH)
	hero._counter = {"foe": e, "perfect": perfect, "t": 0.0, "bolt": bolt != null, "slammed": false,
		"from": at, "tendril": null, "time": 0.0}
	hero._invuln_t = (BOLT_END if bolt != null else END) + INVULN_PAD
	hero.velocity = Vector3(0.0, hero.velocity.y, 0.0)
	FX.parry(parent, hero.global_position, at, perfect)
	Game.hitstop(PERFECT_STOP if perfect else STOP, STOP_SCALE)
	Game.shake(0.45 if perfect else 0.3)
	Game.sfx("perfect" if perfect else "hit_big", -3.0, 0.05)
	Game.sfx("swing_heavy", -5.0, 0.1)
	if Game.camera_rig:
		Game.camera_rig.punch(0.86 if perfect else 0.9, 0.2)
	ComicFx.say(WORD, hero.global_position.lerp(at, 0.5), WORD_SCALE)
	Game.add_awakening(AWAKEN_PERFECT if perfect else AWAKEN)
	Game.register_hit("counter")
	hero._play("Ab_GR", 0.03, true)
	if hero.bot_enabled:
		hero.bot_log.append("[autotest] counter #%d perfect=%s t=%.3f %s" % [hero.counters, perfect, c.t, "bolt" if bolt != null else str(e.get_meta("kind", e.name)) if e != null else "?"])
	if bolt != null:
		_reflect(bolt)
		if is_instance_valid(e):
			VOID_ELEMENT.DARK.mark(e)
		return
	e.stagger(END + STAGGER)
	VOID_ELEMENT.DARK.mark(e)
	e.set_meta(VOID_ELEMENT.THROWN.FLYING, true)  # (nothing else moves it while the tentacle has it)
	var t := TENDRIL.new()
	hero.add_child(t)
	hero._counter.tendril = t


## A parried bolt goes back at whoever shot it.
static func _reflect(bolt: Node3D) -> void:
	bolt.set("reflected", true)
	var back: Vector3 = -bolt.direction
	if is_instance_valid(bolt.source):
		var to: Vector3 = (bolt.source as Node3D).global_position + Vector3.UP - bolt.global_position
		if to.length() > 0.1:
			back = to.normalized()
	bolt.direction = back
	bolt.speed = float(bolt.speed) * REFLECT_SPEED
	bolt.damage = float(bolt.damage) * REFLECT_MULT
	bolt.set("_age", 0.0)
	bolt.rotation.y = atan2(back.x, back.z)


## State.DASH while hero._counter is set: Backlash's wrap, lift and slam, then the window (perfect) or his feet.
static func tick(hero: CharacterBody3D, delta: float) -> void:
	var c: Dictionary = hero._counter
	c.t += delta
	c.time += delta
	hero.velocity.x = 0.0
	hero.velocity.z = 0.0
	if c.bolt:
		if c.t >= BOLT_END:
			_finish(hero)
		return
	var e: Variant = c.foe
	if not is_instance_valid(e) or not e.is_alive():
		_finish(hero)
		return
	var foe: Node3D = e
	var me: Vector3 = hero.global_position
	var fwd: Vector3 = hero._facing()
	var t: float = c.t
	var reach := 1.0
	if t < WRAP:
		reach = t / WRAP
		c.from = foe.global_position
		foe.velocity = Vector3.ZERO
	elif not c.slammed:
		var top := Vector3(me.x, 0.0, me.z) + fwd * LIFT_AHEAD + Vector3.UP * LIFT_Y
		var spot := Vector3(me.x, 0.0, me.z) + fwd * SLAM_AHEAD
		if t < LIFT:
			if not c.has("lifting"):
				c.lifting = true
				hero._play("Ab_VS", 0.03, true)
				Game.sfx("swing_heavy", -3.0, 0.1)
			var k := (t - WRAP) / (LIFT - WRAP)
			foe.global_position = c.from.lerp(top, 1.0 - (1.0 - k) * (1.0 - k))
		else:
			var k := clampf((t - LIFT) / (SLAM - LIFT), 0.0, 1.0)
			foe.global_position = top.lerp(spot, k * k)
		foe.velocity = Vector3.ZERO
		if t >= SLAM:
			_slam(hero, foe, fwd)
	else:
		reach = clampf(1.0 - (t - SLAM) / (END - SLAM), 0.0, 1.0)
	var tendril: Variant = c.tendril
	if is_instance_valid(tendril):
		tendril.visible = reach > 0.02
		if tendril.visible:
			tendril.draw(hero._void._hand_pos(), foe.global_position + CHEST, reach, 0.05, float(foe.radius) + 0.05, c.time)
	if c.slammed and t >= END:
		if c.perfect:
			_window(hero, foe)
		else:
			_finish(hero)


## Backlash lands: down in front of him, the whip-crack, a hit.
static func _slam(hero: CharacterBody3D, foe: Node3D, fwd: Vector3) -> void:
	var c: Dictionary = hero._counter
	c.slammed = true
	var parent: Node = hero.get_parent()
	if foe.has_meta(VOID_ELEMENT.THROWN.FLYING):
		foe.remove_meta(VOID_ELEMENT.THROWN.FLYING)
	var spot := Vector3(foe.global_position.x, 0.0, foe.global_position.z)
	foe.global_position = spot
	foe.take_hit(DAMAGE * hero._dmg_mult, fwd * 2.0, 0.0, true)
	foe.stagger(END - SLAM + STAGGER)
	VOID_ELEMENT.DARK.mark(foe)
	Game.register_hit("counter")
	FX.snap(parent, spot, fwd)
	VOID_ELEMENT.DARK.burst(parent, spot, 1.0)
	Game.hitstop(SLAM_STOP)
	Game.shake(0.5)
	Game.sfx("quake", -7.0, 0.05)
	Game.sfx("hit_big", -2.0, 0.1)
	if Game.camera_rig:
		Game.camera_rig.punch(0.88, 0.22)


## A perfect counter's breaker window: the leap with the tentacle on the attacker alone (void_grab.seize `only`).
static func _window(hero: CharacterBody3D, foe: Node3D) -> void:
	_clear(hero)
	var entry: Dictionary = VOID_ELEMENT.entry(BREAKER)
	entry["only"] = foe
	HERO_LEAP.start(hero, BREAKER, entry)


static func _finish(hero: CharacterBody3D) -> void:
	_clear(hero)
	hero._set_state(hero.State.MOVE)


## The counter is over (or cut short: player._set_state leaving DASH): the tentacle goes, the attacker is free.
static func cut(hero: CharacterBody3D) -> void:
	_clear(hero)


static func _clear(hero: CharacterBody3D) -> void:
	var c: Dictionary = hero._counter
	if c.is_empty():
		return
	hero._counter = {}
	if is_instance_valid(c.tendril):
		c.tendril.queue_free()
	if is_instance_valid(c.foe) and c.foe.has_meta(VOID_ELEMENT.THROWN.FLYING) and not c.slammed:
		c.foe.remove_meta(VOID_ELEMENT.THROWN.FLYING)


## Ricochet (the counter breaker's ending; void_element.breaker_impact): each held foe (the attacker) hurled into the
## nearest foe or wall, bound where it lands.
static func ricochet(hero: CharacterBody3D, b: Dictionary, _at: Vector3, seized: Array, mult: float) -> void:
	var damage: float = b.damage * hero._dmg_mult * mult
	for e: Variant in seized:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var target := ricochet_target(hero, e)
		last_ricochet = target.kind
		(e as Node).set_meta(VOID_ELEMENT.CAMERA_CUE, Time.get_ticks_msec() + RICOCHET_CUE_MS)
		var opts := {"solid": true, "el": "void", "speed": RICOCHET_SPEED, "land_y": 0.0, "wall_mult": RICOCHET_WALL_MULT,
			"on_burst": _ricochet_hit.bind(hero)}
		if target.has("hook"):  # round 53, gallows: over the foes onto the hook, x GALLOWS_MULT on the wall's
			FLOURISH.claim_hook(target.hook)
			opts.solid = false
			opts.wall_mult = RICOCHET_WALL_MULT * FLOURISH.GALLOWS_MULT
			opts.on_burst = _gallows_hit.bind(hero, target.hook)
		VOID_ELEMENT.THROWN.launch(hero, e, target.to, damage, opts)
		Game.register_hit("breaker")
	Game.shake(0.5)


## Where Ricochet sends `e`: the nearer of the nearest living foe and the nearest wall or pillar within
## RICOCHET_REACH of it, else RICOCHET_OPEN m along his aim. {"kind": "foe" / "wall" / "open", "to"}.
static func ricochet_target(hero: CharacterBody3D, e: Node3D) -> Dictionary:
	var from := Vector3(e.global_position.x, 0.0, e.global_position.z)
	# Round 53 (gallows, env_flourish.gd): a hook's point in reach takes it over any foe or wall, unless the cursor chose
	# a wall or pillar in the window (env_target CTX "gallows").
	var hook: Node3D = FLOURISH.gallows_hook(hero, e)
	if hook != null:
		var p := FLOURISH.hook_point(hook)
		var to_hook := Vector3(p.x - from.x, 0.0, p.z - from.z)
		return {"kind": "hook", "hook": hook, "to": from + to_hook.normalized() * (to_hook.length() + 1.0)}
	var over: Dictionary = ENV.chosen(hero, "gallows")
	if not over.is_empty():
		var f: Dictionary = ENV.surface(over, from)
		var to_wall: Vector3 = f.at - from
		return {"kind": "wall", "to": from + to_wall.normalized() * (to_wall.length() + 1.5)}
	var foe: Node3D = null
	var foe_d := RICOCHET_REACH
	for o: Node3D in VOID_ELEMENT.FOES.near(hero.get_tree(), from, RICOCHET_REACH):
		if o == e or VOID_ELEMENT.THROWN.flying(o):
			continue
		var d := Vector3(o.global_position.x - from.x, 0.0, o.global_position.z - from.z).length()
		if d < foe_d:
			foe_d = d
			foe = o
	# (round 50: the room's walls and pillars, env_target.gd; a structure the cursor was on at the press wins outright)
	var wall: Dictionary = VOID_ELEMENT.pinwheel_target(hero, from, "ricochet", RICOCHET_REACH)
	var wall_d: float = wall.dist if wall.found and float(wall.dist) <= RICOCHET_REACH + 0.5 else INF
	if foe != null and foe_d <= wall_d and not (wall.get("chosen", false) and wall_d < INF):
		var aim := Vector3(foe.global_position.x - from.x, 0.0, foe.global_position.z - from.z)
		return {"kind": "foe", "to": from + aim.normalized() * (aim.length() + 1.0)}
	if wall_d < INF:
		var aim: Vector3 = wall.at - from
		return {"kind": "wall", "to": from + aim.normalized() * (aim.length() + 1.5)}
	return {"kind": "open", "to": from + hero._brk_dir * RICOCHET_OPEN}


## It hit something: the tendrils come up out of the floor and hold it there.
static func _ricochet_hit(f: Node3D, _walled: bool, _dir: Vector3, hero: CharacterBody3D) -> void:
	if is_instance_valid(hero) and is_instance_valid(f) and f.is_alive():
		FLOOR_BIND.bind(hero, [f], {"time": BIND_TIME, "ropes": 3, "tick_damage": 2.0, "color": VOID_ELEMENT.DARK.VIOLET})


## Gallows (round 53): the throw stopped by the hook; it hangs there (env_flourish.Hang), or, stopped short, is bound
## where it lands as any Ricochet.
static func _gallows_hit(f: Node3D, walled: bool, dir: Vector3, hero: CharacterBody3D, hook: Node3D) -> void:
	if FLOURISH.hang(hero, f, hook) == null:
		_ricochet_hit(f, walled, dir, hero)


## The combo guide's hint (combo_guide.gd): while a strike a dash along his facing would counter is coming, a SPACE
## Backlash row goes on top (tier 3 and the Ricochet follow-up once it would be perfect), in place of any dash row.
static func hint(hero: CharacterBody3D, rows: Array) -> Array:
	if not hero._counter.is_empty():
		return []  # (Backlash takes no input: the dash rows under it would lie)
	if hero.state == hero.State.LEAP or hero.state == hero.State.DEAD:
		return rows
	var c := find(hero, hero._facing())
	if c.is_empty() or c.bolt != null:
		return rows
	var row := {"kind": "dash", "id": "BACKLASH", "name": "Backlash", "tier": 3 if c.perfect else 2, "hold": false, "next": {}}
	if c.perfect:
		row.next = {"kind": "heavy", "id": BREAKER, "name": VOID_ELEMENT.BREAKERS[BREAKER].names.spirit, "tier": 3}
	return [row] + rows.filter(func(r: Dictionary) -> bool: return r.kind != "dash")
