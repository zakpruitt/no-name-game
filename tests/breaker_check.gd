extends SceneTree
## Combo breaker check (player.BREAKERS), headless:
## Every BREAKERS entry (L L H, hold H, Flurry, Cyclone, Spike), each case:
##   perfect — the move into the leap, press at the sweet spot: dive lands, PERFECT, foe hit
##   late    — press near the window's close: dive lands, not perfect
##   early   — press before the window: locked out, he floats down, no dive
##   none    — no press: floats down, no dive
##   awakened — perfect while Awakened: the dive breakers summon the ancestor
## Prints PASS/FAIL per case. Run: godot --headless --path . -s tests/breaker_check.gd

class Dummy extends Node3D:
	var radius := 0.5
	var hp := 100.0
	func is_alive() -> bool: return hp > 0.0
	func take_hit(d: float, _kb = Vector3.ZERO, _l = 0.0, _b = false, _x = null) -> void: hp -= d
	func is_airborne() -> bool: return false

var fails := 0
var _id := "LLH"


func _initialize() -> void:
	await process_frame
	for id: String in load("res://scripts/player.gd").BREAKERS:
		_id = id
		var b: Dictionary = load("res://scripts/player.gd").BREAKERS[id]
		await _case("perfect", b.sweet, true, true)
		await _case("late", b.close - 0.04, true, false)  # (the press reaches the player a frame or two later)
		await _case("early", b.open - 0.15, false, false)
		await _case("none", -1.0, false, false)
		await _case("awakened", b.sweet, true, true, true)
		await _dash_out()
	await _trigger(true)
	await _trigger(false)
	print("[breaker] ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()


## Dash during the hang (in the slow-motion window, Awakened so the dive
## breakers' ancestor is up): the breaker is off, its pieces go, full speed
## comes back and he dashes.
func _dash_out() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var p: CharacterBody3D = load("res://scripts/player.gd").new()
	world.add_child(p)
	var foe := Dummy.new()
	foe.add_to_group("enemies")
	world.add_child(foe)
	foe.global_position = Vector3(0.5, 0.0, 3.0)
	await process_frame
	p._set_awakened(true)
	p._start_leap(_id)
	var b: Dictionary = p.BREAKERS[_id]
	for i in 600:
		if p._state_t >= b.open + 0.03:
			break
		await physics_frame
	var slowed := Engine.time_scale < 0.99
	Input.action_press("dash")
	await physics_frame
	Input.action_release("dash")
	await physics_frame
	var ok: bool = p.state == p.State.DASH and Engine.time_scale > 0.99 and not is_instance_valid(p._brk_ancestor) 		and p._brk_volley.is_empty() and p.breaker_window().get("ended", "") == "miss"
	ok = ok and slowed
	print("[breaker] %s dash out of the hang %s: state %s, time %.2f (slowed before: %s)" % [_id, "ok" if ok else "FAIL",
		p.State.keys()[p.state], Engine.time_scale, slowed])
	if not ok:
		fails += 1
	get_root().get_node("Game").end_slowmo()
	world.queue_free()
	await process_frame


## Leap, press heavy `press_at` s after take-off (-1 never); expect a dive
## (`dive`) and whether it's perfect.
func _case(name: String, press_at: float, dive: bool, perfect: bool, awake := false) -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var p: CharacterBody3D = load("res://scripts/player.gd").new()
	world.add_child(p)
	var foe := Dummy.new()
	foe.add_to_group("enemies")
	world.add_child(foe)
	# In the dive zone (off the Ground Breaker thrust's strip).
	foe.global_position = {"LLH": Vector3(1.6, 0.0, 3.8), "CH": Vector3(0.8, 0.0, 2.6), "LPL": Vector3(0.4, 0.0, 4.0), "DH": Vector3(-1.0, 0.0, 2.0), "LHH": Vector3(2.5, 0.0, 2.5)}.get(_id, Vector3(0.0, 0.0, 3.0))
	await process_frame
	if awake:
		p._set_awakened(true)
	p._start_leap(_id)
	var pressed := false
	var t := 0.0
	var ancestor := false  # Awakened dive breakers: the ancestor rose
	var slowed := false  # the window plays in slow motion
	var guided := false  # the timing prompt is live in the window, and the combo guide stays out of it
	while p.state == p.State.LEAP and t < 3.0:
		var w: Dictionary = p.breaker_window()
		if p._brk_phase == 0 and p._state_t >= b_open() + 0.01 and p._state_t <= b_sweet() and w.get("live", false):
			guided = guided or (p.combo_options().is_empty() and w.t >= w.open and w.t <= w.close and w.get("name", "") != "")
			slowed = slowed or Engine.time_scale <= p.BREAKER_FOCUS + 0.01
			ancestor = ancestor or is_instance_valid(p._brk_ancestor)
		if press_at >= 0.0 and not pressed and p._brk_phase == 0 and p._state_t >= press_at:
			Input.action_press("attack_heavy")
			pressed = true
			await physics_frame
			Input.action_release("attack_heavy")
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	var ok: bool = p.state == p.State.MOVE and p.model.position.y == 0.0
	ok = ok and (p.breakers_landed == 1) == dive and (p.breaker_perfects == 1) == perfect
	if press_at < 0.0 or press_at >= b_open():
		ok = ok and guided and slowed
	ok = ok and ancestor == (awake and not p._brk.has("dash") and not p._brk.has("fan"))
	for i in 60:  # full speed again once it's over
		if Engine.time_scale == 1.0:
			break
		await process_frame
	ok = ok and Engine.time_scale == 1.0
	var ended: String = p.breaker_window().get("ended", "")
	var want := "perfect" if perfect else ("hit" if dive else ("lock" if press_at >= 0.0 else "miss"))
	ok = ok and ended == want
	if dive:
		ok = ok and foe.hp <= 100.0 - p.BREAKERS[_id].damage
	print("[breaker] %s %s %s landed=%d perfect=%d foe_hp=%.0f t=%.2f slowed=%s ended=%s" % [_id, name, "ok" if ok else "FAIL",
		p.breakers_landed, p.breaker_perfects, foe.hp, t, slowed, p.breaker_window().get("ended", "")])
	if not ok:
		fails += 1
	if awake:
		p._set_awakened(false)
	world.queue_free()
	await process_frame


func b_open() -> float: return load("res://scripts/player.gd").BREAKERS[_id].open
func b_sweet() -> float: return load("res://scripts/player.gd").BREAKERS[_id].sweet


## Through the real move: L L H leaps into the breaker only if its thrust
## connected (`hit` = a foe in front); a whiff plays out to MOVE.
func _trigger(hit: bool) -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var p: CharacterBody3D = load("res://scripts/player.gd").new()
	world.add_child(p)
	var foe := Dummy.new()
	foe.add_to_group("enemies")
	world.add_child(foe)
	foe.global_position = Vector3(0.0, 0.0, 2.0) if hit else Vector3(0.0, 0.0, -30.0)
	await process_frame
	p._face(foe.global_position - p.global_position if hit else Vector3.BACK)
	p._start_attack("LLH")
	var leapt := false
	for i in 240:
		if p.state == p.State.LEAP:
			leapt = true
			break
		if p.state != p.State.ATTACK:
			break
		await physics_frame
	var ok := leapt == hit
	print("[breaker] trigger %s %s (leapt=%s)" % ["hit" if hit else "whiff", "ok" if ok else "FAIL", leapt])
	if not ok:
		fails += 1
	world.queue_free()
	await process_frame
