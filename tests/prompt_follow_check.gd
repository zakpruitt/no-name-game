extends SceneTree
## Combo breaker timing circle (breaker_prompt.gd) placement, headless: it
## pins itself up and to the left of the hero's chest on screen (OFFSET), follows
## him as he moves, ignores the leaping model's height, and stays inside the
## screen near an edge. Prints PASS/FAIL.
## Run: godot --headless --path . -s tests/prompt_follow_check.gd

var fails := 0


class FakeHero extends Node3D:
	var model := Node3D.new()
	func _ready() -> void: add_child(model)
	func breaker_window() -> Dictionary:
		return {"live": true, "t": 0.3, "open": 0.36, "sweet": 0.5, "close": 0.66, "color": Color.CYAN, "name": "Ground Breaker"}


func _initialize() -> void:
	await process_frame
	get_root().size = Vector2i(1280, 720)  # headless starts at 64x64
	var world := Node3D.new()
	get_root().add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 14, 9)
	cam.look_at(Vector3.ZERO)
	cam.make_current()
	var hero := FakeHero.new()
	world.add_child(hero)
	var layer := CanvasLayer.new()
	get_root().add_child(layer)
	var pr: Control = load("res://scripts/breaker_prompt.gd").new()
	pr.player = hero
	layer.add_child(pr)
	await process_frame
	await process_frame
	var size := pr.get_viewport_rect().size
	var chest: Vector2 = cam.unproject_position(hero.global_position + Vector3.UP * pr.CHEST)
	var want: Vector2 = chest + pr.OFFSET
	_check(pr.center.distance_to(want) < 1.0, "pinned at the hero's chest + OFFSET (%s vs %s)" % [pr.center, want])
	_check(pr.center.x < chest.x and pr.center.y < chest.y, "up and to his left")
	var mid := size * 0.5
	_check(pr.center.distance_to(mid) < size.length() * 0.25, "near mid-screen when he is (%s, screen %s)" % [pr.center, size])
	_check(pr._w.get("name", "") == "Ground Breaker", "carries the breaker's name to draw under the circle")
	# He leaps: the model rises, the circle holds still.
	var before: Vector2 = pr.center
	hero.model.position.y = 2.5
	await process_frame
	_check(pr.center.distance_to(before) < 0.5, "holds still while the model leaps")
	# He moves: it follows.
	hero.global_position = Vector3(3, 0, 0)
	await process_frame
	_check(pr.center.x > before.x + 20.0, "follows him across the screen (%.0f -> %.0f)" % [before.x, pr.center.x])
	# Far off to the left edge: clamped on screen.
	hero.global_position = Vector3(-40, 0, 0)
	await process_frame
	_check(pr.center.x >= pr.MARGIN - 0.5 and pr.center.y >= pr.MARGIN - 0.5, "kept on screen at the edge (%s)" % pr.center)
	print("[prompt] ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()


func _check(ok: bool, what: String) -> void:
	print("[prompt] ", "ok " if ok else "FAIL ", what)
	if not ok:
		fails += 1
