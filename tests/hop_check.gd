extends SceneTree
## Move hops (player.MOVES `hop`), headless: L2 / L3 / CH / DL leave the ground and land
## on their hit; L H rises and L H H, started at L H's cancel, comes down from
## that height onto its hit; L H L L holds the air (air slashes) and L3 slams
## down from it; back in MOVE the model settles to the floor.
## Prints PASS/FAIL. Run: godot --headless --path . -s tests/hop_check.gd

var fails := 0


class Floater extends Node3D:  # a juggled foe hanging in the air
	var radius := 0.5
	var hp := 100.0
	func is_alive() -> bool: return hp > 0.0
	func take_hit(d: float, _kb = Vector3.ZERO, _l = 0.0, _b = false, _x = null) -> void: hp -= d
	func is_airborne() -> bool: return true


func _initialize() -> void:
	await process_frame
	var world := Node3D.new()
	get_root().add_child(world)
	var p: CharacterBody3D = load("res://scripts/player.gd").new()
	world.add_child(p)
	await process_frame
	for id: String in ["L2", "L3", "CH", "DL"]:
		p._start_attack(id)
		var peak := await _run(p, p.MOVES[id].hits[0])
		_check(peak > 0.5 and p.model.position.y < 0.1, "%s hops (peak %.2f) and lands on its hit (y %.2f)" % [id, peak, p.model.position.y])
		await _settle(p)
	# The neutral heavy whirls in the air through its hits, then lands.
	p._start_attack("H")
	var h_peak := await _run(p, p.MOVES.H.hits[1])
	_check(h_peak > 0.5 and p.model.position.y > 0.4, "H whirls in the air (y %.2f at its 2nd hit)" % p.model.position.y)
	await _run(p, p.MOVES.H.cancel)
	_check(p.model.position.y < 0.1, "H lands by its cancel (y %.2f)" % p.model.position.y)
	await _settle(p)
	p._start_attack("LH")
	var lh_peak := await _run(p, p.MOVES.LH.cancel)
	var y0: float = p.model.position.y
	_check(y0 > 0.6, "L H rises with the launch (y %.2f at its cancel)" % y0)
	p._start_attack("LHH")
	await physics_frame
	_check(p.model.position.y > y0 * 0.7, "L H H starts in the air (y %.2f)" % p.model.position.y)
	await _run(p, p.MOVES.LHH.hits[0])
	_check(p.model.position.y < 0.1, "L H H lands on its hit (y %.2f)" % p.model.position.y)
	await _settle(p)
	# The air string: L H, L, L stays up; the third L (Triple Chop) slams down.
	p._start_attack("LH")
	await _run(p, p.MOVES.LH.cancel)
	_check(p._next_move("light") == "AL1", "light after L H is the air slash (got %s)" % p._next_move("light"))
	var prev_y: float = p.model.position.y
	for id: String in ["AL1", "AL2"]:
		p._start_attack(id)
		var low := 99.0
		for i in 240:
			if p.state != p.State.ATTACK or p._state_t * p.anim_speed * p._anim_mult / p._move_len >= p.MOVES[id].cancel:
				break
			await physics_frame
			low = minf(low, p.model.position.y)
		_check(low > 1.0, "%s stays in the air (lowest %.2f)" % [id, low])
		_check(p.model.position.y > prev_y + 0.2, "%s climbs (%.2f -> %.2f)" % [id, prev_y, p.model.position.y])
		prev_y = p.model.position.y
	_check(p._next_move("light") == "L3" and p._next_move("heavy") == "LHH", "after the air slashes: L = Triple Chop, H = Spike")
	var air_peak: float = p._hop_peak
	_check(air_peak > 2.0, "the air string ends high (%.2f)" % air_peak)
	p._start_attack("L3")
	p._hits_done = 1
	var plunge: float = p.plunge_mult()
	p._hits_done = 0
	_check(plunge > 1.25, "Triple Chop off Sky Rend plunges (x%.2f)" % plunge)
	await _run(p, p.MOVES.L3.hits[0])
	await create_timer(0.15).timeout
	var axes := 0
	for n in world.get_children():
		if n.get_script() and str(n.get_script().resource_path).contains("spirit_guillotine"):
			axes += 1
	_check(axes == 3, "the plunge off Sky Rend slams 3 spectral axes (%d)" % axes)
	_check(p._hop_peak == 0.0, "the slam used and reset the peak")
	_check(p.model.position.y < 0.1, "Triple Chop slams down from the air (y %.2f)" % p.model.position.y)
	await _settle(p)
	p._start_attack("L1")
	p._hits_done = 1
	_check(p.plunge_mult() == 1.0, "no plunge from the ground (x%.2f)" % p.plunge_mult())
	p._hits_done = 0
	await _settle(p)
	_check(p.model.position.y == 0.0, "settled on the floor after (y %.2f, lh peak %.2f)" % [p.model.position.y, lh_peak])
	# Air dash: dashing out of the launcher keeps him up, and the next press
	# carries on in the air.
	p._start_attack("LH")
	await _run(p, p.MOVES.LH.cancel)
	_check(p.dash_light() == "AL1", "the guide's dash row off L H is the air slash (%s)" % p.dash_light())
	p._start_dash()
	_check(p._air_dash, "a dash out of L H in the air is an air dash")
	var cut: Node3D = null
	for n in p.get_children():
		if n.get_script() and str(n.get_script().resource_path).contains("spirit_echo"):
			cut = n
	_check(cut != null and cut.position.y > 1.0, "it cuts with a spectral axe up at his height")
	var dlow := 99.0
	for i in 120:
		await physics_frame
		dlow = minf(dlow, p.model.position.y)
		if p.state == p.State.MOVE:
			break
	_check(dlow > 1.0, "he stays up through the air dash (lowest %.2f)" % dlow)
	_check(p._next_move("light") == "AL1" and p._next_move("heavy") == "LHH", "after it: L = Air Slash, H = Spike (%s / %s)" % [p._next_move("light"), p._next_move("heavy")])
	_check(not p._can_air_dash(), "only one air dash per trip up")
	var drows: Array = p.combo_options()
	_check(not drows.is_empty() and drows[0].id == "AL1", "the guide shows the air slash after the air dash")
	p._start_attack(p._next_move("light"))
	await physics_frame
	_check(p.model.position.y > 1.0 and not p._air_dash, "the air slash goes on from up there (y %.2f)" % p.model.position.y)
	# The air slashes don't climb past AIR_MAX_HEIGHT, however they're chained.
	var top := 0.0
	for id: String in ["AL2", "AL1", "AL2", "AL1"]:
		p._start_attack(id)
		top = maxf(top, await _run(p, p.MOVES[id].cancel))
	_check(top <= p.AIR_MAX_HEIGHT + 0.2, "air slashes stop climbing at the cap (peak %.2f)" % top)
	await _settle(p)
	_check(p._air_dashes == 0, "landing gives the air dash back")
	p._start_attack("L1")
	await _run(p, p.MOVES.L1.cancel)
	_check(p.dash_light() == "DL", "a dash off the ground is still Dash Stab")
	p._start_dash()
	_check(not p._air_dash, "and not an air dash")
	await _settle(p)
	# Juggle tracking: from the air, the slash turns to a foe drifting off to
	# the side and lunges to reach it by its hit.
	var f := Floater.new()
	world.add_child(f)
	f.add_to_group("enemies")
	f.global_position = p.global_position + Vector3(4.5, 0, 0)
	p._start_attack("LH")
	await _run(p, p.MOVES.LH.cancel)
	f.global_position = p.global_position + Vector3(4.5, 0, 0)
	f.hp = 100.0
	p._start_attack("AL1")
	var face: Vector3 = p._facing()
	_check(face.x > 0.95, "an air slash turns to the airborne foe (facing %s)" % face)
	await _run(p, p.MOVES.AL1.hits[0] + 0.02)
	var gap: float = Vector2(f.global_position.x - p.global_position.x, f.global_position.z - p.global_position.z).length()
	_check(gap < 2.7 and f.hp < 100.0, "and reaches it by the hit (gap %.2f, hp %.0f)" % [gap, f.hp])
	f.queue_free()
	await _settle(p)
	print("[hop] ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()


## Physics frames until the move reaches progress `to`; returns the peak height.
func _run(p: Node, to: float) -> float:
	var peak := 0.0
	for i in 240:
		if p.state != p.State.ATTACK or p._state_t * p.anim_speed * p._anim_mult / p._move_len >= to:
			break
		await physics_frame
		peak = maxf(peak, p.model.position.y)
	return peak


func _settle(p: Node) -> void:
	for i in 120:
		if p.state == p.State.MOVE and p.model.position.y == 0.0:
			return
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print("[hop] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		fails += 1
