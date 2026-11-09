extends SceneTree
## A foe freed while its hit effects run (flash, squash, ink, lean tweens) must not print errors:
## "Parameter material is null" came from freeing a foe a frame after hitting it (agents.md).
## Hits real minions and training dummies (the dummy reproduced it: its KayKit meshes kept Fx.flash's
## overlay as they were freed), frees each 0, 1 and 3 frames later (and one killed outright), waits out
## every tween and fails on any engine or script error seen meanwhile. Prints [fx_free] PASS/FAIL.
## Run: godot --headless --path . -s tests/fx_free_check.gd

class Catch extends Logger:
	var errors: Array[String] = []
	var on := false

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if on and error_type != ERROR_TYPE_WARNING:
			errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])

var _main: Node
var _catch := Catch.new()


func _initialize() -> void:
	OS.add_logger(_catch)
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await create_timer(0.3).timeout
	_main.clear_room()
	_main.player.bot_enabled = true
	await create_timer(0.3).timeout
	_catch.on = true
	var cases := 0
	for frames: int in [0, 1, 3]:
		for big: bool in [false, true]:
			var e: Node = _main._spawn("minion", false, Vector3(2.0, 0.0, 4.0))
			await physics_frame
			e.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 0.0, big)
			for i in frames:
				await process_frame
			e.queue_free()
			cases += 1
	var k: Node = _main._spawn("minion", false, Vector3(-2.0, 0.0, 4.0))
	await physics_frame
	k.take_hit(99999.0, Vector3(0.0, 0.0, 6.0), 0.0, true)
	await process_frame
	k.queue_free()
	cases += 1
	for frames: int in [0, 1, 3]:
		var d: Node = load("res://scripts/training_dummy.gd").new()
		_main._set_model(d, "dummy")
		_main.add_child(d)
		d.home = _main.player.global_position + Vector3(0.0, 0.0, 4.0)
		d.global_position = d.home
		await create_timer(1.1).timeout
		d.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 0.0, frames == 1)
		for i in frames:
			await process_frame
		d.queue_free()
		cases += 1
	# Pooled locomotion dust (comic_dust.gd) whose parent goes mid-puff: the pool drops it, a new one is made.
	var dust: GDScript = load("res://scripts/comic_dust.gd")
	var holder := Node3D.new()
	_main.add_child(holder)
	dust.spawn(holder, Vector3(1, 0, 1), Vector3.FORWARD, "stop")
	await process_frame
	holder.queue_free()
	await process_frame
	dust.spawn(_main, Vector3(1, 0, 1), Vector3.FORWARD, "dodge")
	cases += 1
	await create_timer(1.5).timeout  # every flash / squash / lean / ink tween would have run out
	_catch.on = false
	if _catch.errors.is_empty():
		print("[fx_free] PASS (%d foes freed mid-hit, no errors)" % cases)
	else:
		for err in _catch.errors.slice(0, 6):
			print("[fx_free] FAIL: ", err)
		print("[fx_free] FAIL (%d errors)" % _catch.errors.size())
	OS.remove_logger(_catch)
	quit(0)
