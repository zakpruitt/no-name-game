extends SceneTree
## Impact frame (impact_frame.gd), headless: Game owns one under every HUD
## layer; a small hitstop leaves it idle, a big one (IMPACT_STOP+) flashes it
## for IMPACT_HOLD then fades over IMPACT_FADE, longer stops hit harder, a
## kill flashes a lighter frame, frames closer than IMPACT_GAP_MS are dropped,
## and reduce_flashing keeps the vignette pulse but drops the negative and
## kill frames. Prints PASS/FAIL.
## Run: godot --headless --path . -s tests/impact_frame_check.gd

var fails := 0
var game: Node


class Corpse extends Node:
	var bones := 0


func _initialize() -> void:
	await process_frame
	game = get_root().get_node("Game")
	game.save_hints = false
	game.reduce_flashing = false
	game.register_hit("L1")  # two hits in: the opener discount is off
	game.register_hit("L2")
	var fr: CanvasLayer = game.impact
	_check(fr != null and fr.layer < 0 and fr.rect != null, "Game owns an impact frame under the HUD layers")
	_check(not fr.rect.visible and fr.current() == 0.0, "idle at rest")
	game.hitstop(0.05)
	await process_frame
	_check(not fr.rect.visible, "a small hitstop leaves it idle")
	game.end_slowmo()
	await _wait(fr.IMPACT_GAP_MS * 0.001 + 0.05)
	var t0 := Time.get_ticks_msec()
	game.hitstop(fr.IMPACT_STOP)
	var light: float = fr.current()
	_check(fr.rect.visible and is_equal_approx(light, fr.IMPACT_MIN), "a big hitstop flashes it at IMPACT_MIN (%.2f)" % light)
	_check(is_equal_approx(fr._invert, 1.0), "as a negative")
	await _until(t0, fr.IMPACT_HOLD * 0.6)
	_check(is_equal_approx(fr.current(), light), "held at full strength through IMPACT_HOLD (%.2f)" % fr.current())
	await _until(t0, fr.IMPACT_HOLD + fr.IMPACT_FADE * 0.5)
	var mid: float = fr.current()
	_check(mid > 0.0 and mid < light, "fading after the hold (%.2f)" % mid)
	await _until(t0, fr.IMPACT_HOLD + fr.IMPACT_FADE + 0.03)
	await process_frame
	_check(not fr.rect.visible and fr.current() == 0.0, "gone after IMPACT_HOLD + IMPACT_FADE")
	game.end_slowmo()
	await _wait(fr.IMPACT_GAP_MS * 0.001)
	game.hitstop(fr.IMPACT_FULL_STOP, 0.2)
	_check(is_equal_approx(fr.current(), 1.0), "a long stop (last kill, Cataclysm) hits at full strength (%.2f)" % fr.current())
	_check(not fr.flash(1.0), "a second frame inside IMPACT_GAP_MS is dropped")
	game.end_slowmo()
	await _wait(fr.IMPACT_GAP_MS * 0.001 + fr.IMPACT_HOLD + fr.IMPACT_FADE)
	game.hitstop(0.3, game.HITSTOP_FLAT_SCALE + 0.1)
	_check(fr.current() == 0.0, "breaker focus slow motion is not a hit: no frame")
	game.end_slowmo()
	var corpse := Corpse.new()
	game.enemy_killed.emit(corpse)
	_check(is_equal_approx(fr.current(), fr.IMPACT_KILL), "a kill flashes a lighter frame (%.2f)" % fr.current())
	await _wait(fr.IMPACT_GAP_MS * 0.001 + fr.IMPACT_HOLD + fr.IMPACT_FADE)
	game.reduce_flashing = true
	game.hitstop(fr.IMPACT_FULL_STOP)
	_check(fr.rect.visible and is_equal_approx(fr.current(), fr.REDUCED_SCALE), "reduce flashing: a big hit still pulses, softened (%.2f)" % fr.current())
	_check(is_equal_approx(fr._invert, 0.0), "without the negative")
	game.end_slowmo()
	await _wait(fr.IMPACT_GAP_MS * 0.001 + fr.IMPACT_HOLD + fr.IMPACT_FADE)
	game.enemy_killed.emit(corpse)
	_check(fr.current() == 0.0, "and kills get no frame")
	game.reduce_flashing = false
	corpse.free()
	print("[impact] ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()


func _wait(sec: float) -> void:
	await _until(Time.get_ticks_msec(), sec)


func _until(since: int, sec: float) -> void:
	while Time.get_ticks_msec() < since + int(sec * 1000.0):
		await process_frame


func _check(ok: bool, what: String) -> void:
	print("[impact] ", "ok " if ok else "FAIL ", what)
	if not ok:
		fails += 1
