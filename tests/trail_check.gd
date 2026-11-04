extends SceneTree
## Weapon trail swell (weapon_trail.gd), headless: the ribbon's new samples
## reach further and live longer as the chain passes Fx.CHAIN_TIERS
## (CHAIN_GROW) and right after a heavy hit (Game.hit_weight from its hitstop,
## HIT_GROW); old samples keep their size; the weight fades in real time.
## Prints PASS/FAIL. Run: godot --headless --path . -s tests/trail_check.gd

var fails := 0
var game: Node


func _initialize() -> void:
	await process_frame
	game = get_root().get_node("Game")
	game.save_hints = false
	game.combo_count = 0
	game.hit_weight = 0.0
	var world := Node3D.new()
	get_root().add_child(world)
	var weapon := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 1.0, 0.1)
	weapon.mesh = box
	world.add_child(weapon)
	var trail: MeshInstance3D = load("res://scripts/weapon_trail.gd").new()
	world.add_child(trail)
	trail.setup(weapon)
	trail.emitting = true
	var plain := await _swing(weapon, trail, 4)
	_check(trail.mesh.get_surface_count() == 1, "draws a ribbon once it has samples")
	_check(is_equal_approx(trail._points[-1][4], 0.0) and is_equal_approx(trail._points[-1][3], trail.lifetime), "plain at combo 0: no swell, base lifetime (%.2f s)" % trail._points[-1][3])
	game.combo_count = 40  # past every chain tier
	game._combo_timer = 100.0  # and the chain not timing out mid-test
	var deep := await _swing(weapon, trail, 4)
	var want: float = 1.0 + trail.CHAIN_GROW * 3
	_check(absf(deep / plain - want) < 0.02, "deep in the chain each sample reaches x%.2f (%.2f)" % [want, deep / plain])
	_check(trail._points[0][1].distance_to(trail._points[0][0]) < deep - 0.01, "earlier samples keep their size")
	_check(trail._points[-1][3] > trail.lifetime * 1.1, "and lives longer (%.2f s)" % trail._points[-1][3])
	game.combo_count = 0
	game.hitstop(game.HIT_WEIGHT_STOP)
	_check(is_equal_approx(game.hit_weight, 1.0), "a %.0f ms freeze is a full-weight hit" % (game.HIT_WEIGHT_STOP * 1000.0))
	var heavy := await _swing(weapon, trail, 1)
	_check(heavy / plain > 1.0 + trail.HIT_GROW * 0.6, "right after it the ribbon reaches x%.2f (weight now %.2f)" % [heavy / plain, game.hit_weight])
	game.end_slowmo()
	game.hit_weight = 0.0
	game.hitstop(0.03)
	_check(game.hit_weight < 0.5, "a light hit doesn't push the weight up (%.2f)" % game.hit_weight)
	game.end_slowmo()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() < t0 + 600:
		await process_frame
	_check(game.hit_weight == 0.0, "the weight fades out within 0.6 s (%.2f)" % game.hit_weight)
	game.hitstop(0.3, 0.6)
	_check(game.hit_weight == 0.0, "breaker focus slow motion carries no weight")
	game.end_slowmo()
	print("[trail] ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()


## Turn the weapon over `frames` frames; returns the newest sample's base-to-tip reach.
func _swing(weapon: Node3D, trail: MeshInstance3D, frames: int) -> float:
	for i in frames:
		weapon.rotate_y(0.3)
		await process_frame
	var p: Array = trail._points[-1]
	return p[0].distance_to(p[1])


func _check(ok: bool, what: String) -> void:
	print("[trail] ", "ok " if ok else "FAIL ", what)
	if not ok:
		fails += 1
