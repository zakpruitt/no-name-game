extends SceneTree
## Combo rhythm, headless: every move's hit / cancel / end in real ms (printed as `[rhythm]` rows), hits on
## their clips' contact frames and inside the clip, a buffered press firing on the first legal frame (and
## a far-too-early one dropped), hit-confirm cancelling earlier than a whiff, and a dash out of every move
## after its first hit (a breaker's hang included). Runs the real hero against stand-in foes. PASS/FAIL.
## Run: godot --headless --path . -s tests/rhythm_check.gd

var fails := 0
var world: Node3D
var hero: CharacterBody3D
var game: Node
var LOOK: GDScript  # ComicLook, loaded at runtime (it names Game)
## Weapon moves: the string's rhythm (hit-confirm must be felt on these).
const WEAPON := ["L1", "L2", "L3", "DL", "AL1"]


class Foe extends CharacterBody3D:
	var radius := 0.5
	var hp := 5000.0
	var elite := false
	var hits := 0
	var frozen := false
	func chill(_t: float, _m: float) -> void: pass
	func freeze(_t: float, _m: float) -> void: frozen = true
	func is_alive() -> bool: return hp > 0.0
	func is_airborne() -> bool: return false
	func stagger(_t: float) -> void: pass
	func take_hit(d: float, _kb = Vector3.ZERO, _l = 0.0, _big = false, _x = null) -> void:
		hp -= d
		hits += 1


func _initialize() -> void:
	await process_frame
	game = root.get_node("Game")
	game.comic_style = true
	LOOK = load("res://scripts/comic_look.gd")
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)
	hero = load("res://scripts/player.gd").new()
	world.add_child(hero)
	await process_frame
	_table()
	_pacing()
	await _buffered()
	await _hit_confirm()
	await _aim_lock()
	await _dash_out_of_everything()
	await _breaker_windows()
	print("rhythm_check: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


## Real ms from the move's start to fraction `f` of its clip, at base speed.
func _ms(f: float) -> float:
	return f * hero._move_len / (hero.anim_speed * hero._anim_mult) * 1000.0


## Every move's timing, printed for tuning, and the hits inside the clip.
func _table() -> void:
	for id: String in hero.MOVES:
		hero._start_attack(id)
		var m: Dictionary = hero._move
		var whiff: float = hero.cancel_point()
		hero._connected = true
		hero._hits_done = m.hits.size()
		var confirm: float = hero.cancel_point()
		print("[rhythm] %-3s hit=%4.0f cancel=%4.0f/%4.0f end=%4.0f ms (whiff/hit cancel) stop=%.3f%s" % [id, _ms(m.hits[0]),
			_ms(whiff), _ms(confirm), _ms(m.end), m.stop, " shape=" + m.stop_shape if m.has("stop_shape") else ""])
		_check(m.hits[0] > 0.0 and m.hits[-1] < whiff and whiff <= m.end and m.end <= 1.0, "%s hits inside its clip, before cancel and end" % id)
		_check(confirm <= whiff and confirm > m.hits[-1], "%s: hit-confirm cancel is after its last hit and no later than a whiff's" % id)
		if LOOK.HERO_MOVES.has(id):
			var h: Dictionary = LOOK.HERO_MOVES[id]
			_check(absf(m.hits[0] - float(h.hit) / h.frames) < 0.0001, "%s lands on its contact frame %d" % [id, h.hit])
		if id in WEAPON:
			_check(confirm < whiff, "%s cancels earlier on a hit (%.0f < %.0f ms)" % [id, _ms(confirm), _ms(whiff)])
		hero._connected = false
		hero._set_state(hero.State.MOVE)
		hero._move_id = ""
		hero._chain_i = 0


## The axe-spear-hammer string as a rhythm: each wind-up longer than the last, the ender freezing longest,
## the mids recovering quickly (<= MID_RECOVERY) and the ender with weight (ENDER_RECOVERY).
const MID_RECOVERY := 260.0  # ms from hit to end
const ENDER_RECOVERY := Vector2(280.0, 400.0)
func _pacing() -> void:
	var hit := {}
	var rec := {}
	var stop := {}
	for id: String in ["L1", "L2", "L3"]:
		hero._start_attack(id)
		hit[id] = _ms(hero._move.hits[0])
		rec[id] = _ms(hero._move.end) - hit[id]
		stop[id] = hero._move.stop
		hero._set_state(hero.State.MOVE)
		hero._move_id = ""
	print("[rhythm] L L L wind-ups %.0f / %.0f / %.0f ms, recoveries %.0f / %.0f / %.0f ms" % [hit.L1, hit.L2, hit.L3, rec.L1, rec.L2, rec.L3])
	_check(hit.L1 < hit.L2 and hit.L2 < hit.L3, "opener quickest, ender winds up longest")
	_check(stop.L1 <= stop.L2 and stop.L2 < stop.L3, "the ender freezes longest")
	_check(rec.L1 <= MID_RECOVERY and rec.L2 <= MID_RECOVERY, "L1 / L2 recover within %.0f ms" % MID_RECOVERY)
	_check(rec.L3 >= ENDER_RECOVERY.x and rec.L3 <= ENDER_RECOVERY.y, "L3 recovers %.0f ms: weight, not sticky" % rec.L3)
	_check(hit.L3 < 400.0, "the hammer lands inside 400 ms (%.0f)" % hit.L3)


## L at L1's start is held and starts L2 on the first frame past the cancel point; L at L3's start
## (past BUFFER_MS before its cancel) is dropped.
func _buffered() -> void:
	await _settle()
	await _tap("attack_light")
	_check(hero._move_id == "L1", "L starts L1")
	await _tap("attack_light")  # pressed about 2 frames into L1
	var cancel: float = hero.cancel_point()
	var last_t := 0.0
	var frames := 0
	while hero._move_id == "L1" and frames < 120:
		last_t = hero._state_t * hero.anim_speed * hero._anim_mult / hero._move_len
		await physics_frame
		frames += 1
	var step: float = (1.0 / 60.0) * hero.anim_speed * hero._anim_mult / hero._move_len
	_check(hero._move_id == "L2", "the early L was held into L2 (%s)" % hero._move_id)
	# (one physics_frame await can cover two physics steps headless: allow two)
	_check(last_t < cancel and last_t + step * 2.01 >= cancel, "and fired on the first frame past the cancel (%.3f -> %.3f, cancel %.3f)" % [last_t, last_t + step, cancel])
	await _settle()
	hero._chain_i = 2
	hero._chain_reset_t = 1.0
	await _tap("attack_light")
	_check(hero._move_id == "L3", "L at chain 2 starts L3")
	var early_ms := _ms(hero.cancel_point())
	await _tap("attack_light")
	await _until(func() -> bool: return hero.state != hero.State.ATTACK or hero._move_id != "L3", 3.0)
	if early_ms > hero.BUFFER_MS + 50:
		_check(hero._move_id == "L3", "a press %.0f ms before L3's cancel is dropped (BUFFER_MS %d)" % [early_ms, hero.BUFFER_MS])
	await _settle()


## The same buffered L after L1: earlier into L2 when L1 hit something than on a whiff.
func _hit_confirm() -> void:
	var whiff := await _l1_to_l2(false)
	var hit := await _l1_to_l2(true)
	print("[rhythm] L1->L2 buffered: whiff %.0f ms, hit %.0f ms (move time)" % [whiff, hit])
	_check(hit < whiff - 10.0, "hit-confirm: L1 hands over to L2 sooner on a hit (%.0f < %.0f ms)" % [hit, whiff])


func _l1_to_l2(with_foe: bool) -> float:
	await _settle()
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var foe: Foe = _foe(Vector3(0, 0, 1.6)) if with_foe else null
	await _tap("attack_light")
	await _tap("attack_light")
	var t := 0.0
	while hero._move_id == "L1" and t < 2.0:
		t = hero._state_t
		await physics_frame
	if with_foe:
		_check(foe.hits > 0, "L1 hit the foe")
		foe.free()
	game.end_slowmo()
	return t * 1000.0


## A move keeps turning onto the foe it started on while the aim stays near it (AIM_LOCK_BREAK), and lets
## go when the aim swings well away.
func _aim_lock() -> void:
	await _settle()
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var a := _foe(Vector3(0, 0, 3))
	var b := _foe(Vector3(1.6, 0, 3))  # 28 deg right of a
	hero.bot_enabled = true
	hero.bot_move = Vector3(0, 0, 1)
	hero._start_attack("L1")
	_check(hero._aim_lock == a, "L1 locks onto the foe it aimed at")
	hero.bot_move = (b.global_position - hero.global_position).normalized()
	var held: Vector3 = hero._aim_want(true)
	_check(held.normalized().dot(Vector3(0, 0, 1)) > 0.99, "aim drifting toward the next foe keeps the lock (no flick)")
	hero.bot_move = Vector3(-1, 0, 0)
	held = hero._aim_want(true)
	_check(held.normalized().dot(Vector3(-1, 0, 0)) > 0.99, "aim swung well away lets go")
	hero.bot_move = Vector3.ZERO
	hero.bot_enabled = false
	a.free()
	b.free()


## Every move: dash once its first hit is out (whiffing), and with a foe in front (a breaker's hang
## when the move has one). The bot never dashes out of hangs, so it's off here.
func _dash_out_of_everything() -> void:
	hero.bot_enabled = false
	var dashes := 0
	for with_foe: bool in [false, true]:
		for id: String in hero.MOVES:
			await _settle()
			hero.global_position = Vector3.ZERO
			hero._face(Vector3(0, 0, 1))
			hero.model.position.y = 0.0
			var foe: Foe = _foe(Vector3(0, 0, 1.8)) if with_foe else null
			hero._start_attack(id)
			if hero.state != hero.State.ATTACK:
				_check(false, "%s starts" % id)
				continue
			await _until(func() -> bool: return hero._hits_done > 0 or hero.state != hero.State.ATTACK, 3.0)
			var was: int = hero.state
			hero._dash_cd = 0.0
			await _tap("dash")
			dashes += 1 if hero._since_dash < 0.1 else 0
			_check(hero.state == hero.State.DASH or hero._since_dash < 0.1, "%s%s: dash out after hit 1 (was %s, now %s)" % [id, " on a foe" if with_foe else "", hero.State.keys()[was], hero.State.keys()[hero.state]])
			game.end_slowmo()
			if foe != null:
				foe.free()
			for f in get_nodes_in_group("enemies"):
				f.queue_free()
	print("[rhythm] dashed out of %d / %d moves after their first hit (whiff and on a foe)" % [dashes, hero.MOVES.size() * 2])


## Every breaker keeps one rhythm from the top of its rise (BREAKER_HANG / TO_SWEET / TO_CLOSE), a press
## a hair early (inside BREAKER_EARLY) is held and dives as the window opens, and one well before it locks.
const EARLY_PRESS := 0.1  # s before `open`: locked out with round 29's 0.08 BREAKER_EARLY, held now
func _breaker_windows() -> void:
	var el: GDScript = load("res://scripts/void_element.gd")
	hero.bot_enabled = false
	for id: String in el.BREAKERS:
		var b: Dictionary = el.entry(id)
		print("[rhythm] breaker %s: rise %.2f open %.2f sweet %.2f close %.2f s after take-off" % [id, b.rise, b.open, b.sweet, b.close])
		_check(is_equal_approx(b.open - b.rise, el.BREAKER_HANG) and is_equal_approx(b.sweet - b.open, el.BREAKER_TO_SWEET)
			and is_equal_approx(b.close - b.open, el.BREAKER_TO_CLOSE), "%s keeps the shared window rhythm" % id)
		_check(b.open - hero.BREAKER_EARLY > hero.BREAKER_SPILL, "%s: the held-early span starts after the ender's spill" % id)
		for early: bool in [true, false]:
			await _settle()
			hero.global_position = Vector3.ZERO
			hero.model.position.y = 0.0
			hero._start_leap(id, el.entry(id))
			var press_at: float = b.open - EARLY_PRESS if early else hero.BREAKER_SPILL + 0.02
			await _until(func() -> bool: return hero._state_t >= press_at - 0.05, 2.0)
			hero._state_t = press_at - 1.0 / 60.0  # (exact: the press is read on the next physics step)
			var pressed_t: float = press_at
			Input.action_press("attack_heavy")
			await physics_frame
			await physics_frame
			Input.action_release("attack_heavy")
			if early:
				_check(hero._brk_held and not hero._brk_locked, "%s: a press %.0f ms before the window is held, not locked (pressed at %.3f s)" % [id, EARLY_PRESS * 1000.0, pressed_t])
			await _until(func() -> bool: return hero.state != hero.State.LEAP or hero._brk_phase != 0, 3.0)
			if early:
				_check(hero._brk_ended in ["hit", "perfect"], "%s: and dives as it opens (%s)" % [id, hero._brk_ended])
			elif press_at + 0.06 < b.open - hero.BREAKER_EARLY:  # (a headless press lands a frame or three late)
				_check(hero._brk_ended == "lock", "%s: a press at %.2f s, nowhere near the window, locks it out (%s)" % [id, press_at, hero._brk_ended])
			await _until(func() -> bool: return hero.state != hero.State.LEAP, 3.0)
			game.end_slowmo()


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


func _foe(at: Vector3) -> Foe:
	var f := Foe.new()
	world.add_child(f)
	f.global_position = at
	f.add_to_group("enemies")
	return f


func _settle() -> void:
	game.end_slowmo()
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 4.0)
	for i in 30:
		await physics_frame
	hero._chain_i = 0
	hero._move_id = ""


func _until(done: Callable, seconds: float) -> void:
	var t := 0.0
	while not done.call() and t < seconds:
		await physics_frame
		t += 1.0 / 60.0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL: ", what)
