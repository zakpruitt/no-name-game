extends SceneTree
## Move hops (player.MOVES `hop`), headless: L2 / L3 / CH leave the ground and land
## on their hit; L H rises and L H H, started at L H's cancel, comes down from
## that height onto its hit; L H L L holds the air (air slashes) and L3 slams
## down from it; back in MOVE the model settles to the floor.
## Prints PASS/FAIL. Run: godot --headless --path . -s tests/hop_check.gd

var fails := 0


func _initialize() -> void:
	await process_frame
	var world := Node3D.new()
	get_root().add_child(world)
	var p: CharacterBody3D = load("res://scripts/player.gd").new()
	world.add_child(p)
	await process_frame
	for id: String in ["L2", "L3", "CH"]:
		p._start_attack(id)
		var peak := await _run(p, p.MOVES[id].hits[0])
		_check(peak > 0.5 and p.model.position.y < 0.1, "%s hops (peak %.2f) and lands on its hit (y %.2f)" % [id, peak, p.model.position.y])
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
	for id: String in ["AL1", "AL2"]:
		p._start_attack(id)
		var low := 99.0
		for i in 240:
			if p.state != p.State.ATTACK or p._state_t * p.anim_speed * p._anim_mult / p._move_len >= p.MOVES[id].cancel:
				break
			await physics_frame
			low = minf(low, p.model.position.y)
		_check(low > 1.0, "%s stays in the air (lowest %.2f)" % [id, low])
	_check(p._next_move("light") == "L3" and p._next_move("heavy") == "LHH", "after the air slashes: L = Triple Chop, H = Spike")
	p._start_attack("L3")
	await _run(p, p.MOVES.L3.hits[0])
	_check(p.model.position.y < 0.1, "Triple Chop slams down from the air (y %.2f)" % p.model.position.y)
	await _settle(p)
	_check(p.model.position.y == 0.0, "settled on the floor after (y %.2f, lh peak %.2f)" % [p.model.position.y, lh_peak])
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
