extends SceneTree
## Hitstop shape (game.hitstop), headless: a freeze holds its time scale, eases
## back up over its last HITSTOP_EASE (never snapping, never dipping), a string's
## opener is shorter (HITSTOP_OPENER), slow motion ramps over SLOWMO_EASE,
## breaker focus (>= HITSTOP_FLAT_SCALE) stays flat, overlapping stops keep
## their own shapes with the slowest winning, and end_slowmo() cuts everything.
## Prints PASS/FAIL. Run: godot --headless --path . -s tests/hitstop_check.gd

var fails := 0
var game: Node


func _initialize() -> void:
	await process_frame
	game = get_root().get_node("Game")
	game.save_hints = false
	game.combo_count = 5  # mid-string: no opener discount
	# A plain freeze: flat, then a rising tail, then full speed.
	var t0 := Time.get_ticks_msec()
	game.hitstop(0.4, 0.03)
	_check(is_equal_approx(Engine.time_scale, 0.03), "freezes at once (%.3f)" % Engine.time_scale)
	await _until(t0, 0.2)
	_check(is_equal_approx(Engine.time_scale, 0.03), "holds the freeze through its body (%.3f at 50%%)" % Engine.time_scale)
	await _until(t0, 0.32)  # 80%: inside the last 30%
	var mid := Engine.time_scale
	_check(mid > 0.03 and mid < 1.0, "ramps up in its tail (%.3f at 80%%)" % mid)
	var last := mid
	var monotonic := true
	while Time.get_ticks_msec() < t0 + 400:
		await process_frame
		if Engine.time_scale < last - 0.001:
			monotonic = false
		last = Engine.time_scale
	_check(monotonic, "the ramp never dips (ended %.3f)" % last)
	await _until(t0, 0.45)
	_check(is_equal_approx(Engine.time_scale, 1.0), "back to full speed after (%.3f)" % Engine.time_scale)
	# The opener: combo_count <= 1 shortens a freeze by HITSTOP_OPENER.
	game.combo_count = 1
	t0 = Time.get_ticks_msec()
	game.hitstop(0.3, 0.03)
	await _until(t0, 0.3 * game.HITSTOP_OPENER + 0.03)
	_check(is_equal_approx(Engine.time_scale, 1.0), "a string's opener is over at %d%% of its length (%.3f)" % [roundi(game.HITSTOP_OPENER * 100.0), Engine.time_scale])
	game.combo_count = 5
	t0 = Time.get_ticks_msec()
	game.hitstop(0.3, 0.03)
	await _until(t0, 0.3 * game.HITSTOP_OPENER + 0.03)
	_check(Engine.time_scale < 1.0, "mid-string the same freeze is still on then (%.3f)" % Engine.time_scale)
	await _until(t0, 0.35)
	# Slow motion (last kill: 0.2) ramps over its longer tail.
	t0 = Time.get_ticks_msec()
	game.hitstop(0.4, 0.2)
	await _until(t0, 0.15)
	_check(is_equal_approx(Engine.time_scale, 0.2), "slow motion holds its scale early (%.3f)" % Engine.time_scale)
	await _until(t0, 0.3)  # 75%: inside SLOWMO_EASE (last 45%)
	_check(Engine.time_scale > 0.2 and Engine.time_scale < 1.0, "slow motion eases out over its tail (%.3f at 75%%)" % Engine.time_scale)
	await _until(t0, 0.45)
	# Breaker focus (0.6) never ramps.
	t0 = Time.get_ticks_msec()
	game.hitstop(0.3, game.HITSTOP_FLAT_SCALE + 0.1)
	await _until(t0, 0.27)
	_check(is_equal_approx(Engine.time_scale, game.HITSTOP_FLAT_SCALE + 0.1), "focus slow motion stays flat to its end (%.3f at 90%%)" % Engine.time_scale)
	await _until(t0, 0.35)
	# Overlap: a short freeze inside slow motion, then the slow motion carries on.
	t0 = Time.get_ticks_msec()
	game.hitstop(0.5, 0.2)
	game.hitstop(0.08, 0.03)
	_check(is_equal_approx(Engine.time_scale, 0.03), "a freeze inside slow motion wins (%.3f)" % Engine.time_scale)
	await _until(t0, 0.15)
	_check(is_equal_approx(Engine.time_scale, 0.2), "and the slow motion takes over when it ends (%.3f)" % Engine.time_scale)
	game.end_slowmo()
	_check(is_equal_approx(Engine.time_scale, 1.0), "end_slowmo cuts it all (%.3f)" % Engine.time_scale)
	await process_frame
	await process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "and nothing comes back (%.3f)" % Engine.time_scale)
	print("[hitstop] ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()


## Spin frames until `sec` real seconds after `since` (ticks ms), whatever the time scale.
func _until(since: int, sec: float) -> void:
	while Time.get_ticks_msec() < since + int(sec * 1000.0):
		await process_frame


func _check(ok: bool, what: String) -> void:
	print("[hitstop] ", "ok " if ok else "FAIL ", what)
	if not ok:
		fails += 1
