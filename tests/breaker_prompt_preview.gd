extends SceneTree
## Combo breaker timing prompt (breaker_prompt.gd), windowed: five states in
## a row on a dark backdrop, saved to user://breaker_prompt.png:
## filling (before the window), window open, full (the sweet spot), a perfect
## press flashing, a too-early lockout fading. Needs a window (2D drawing).
## Run: godot --path . -s tests/breaker_prompt_preview.gd


class FakePlayer extends Node:
	var w := {}
	func breaker_window() -> Dictionary: return w


func _initialize() -> void:
	await process_frame
	var prompt_script: GDScript = load("res://scripts/breaker_prompt.gd")
	var back := ColorRect.new()
	back.color = Color(0.32, 0.31, 0.3)
	back.size = Vector2(760, 200)
	get_root().add_child(back)
	var b := {"open": 0.36, "sweet": 0.5, "close": 0.66, "color": Color(0.3, 0.95, 0.85)}
	var live := [0.2, 0.42, 0.5]
	for i in 5:
		var fake := FakePlayer.new()
		get_root().add_child(fake)
		var w := b.duplicate()
		w.live = true
		w.t = live[mini(i, 2)]
		fake.w = w
		var pr: Control = prompt_script.new()
		pr.player = fake
		pr.center = Vector2(80 + i * 150, 100)
		pr.fixed = true
		get_root().add_child(pr)
		if i >= 3:  # one live frame, then it ends
			await process_frame
			await process_frame
			fake.w = {"ended": "perfect" if i == 3 else "lock"}
	await create_timer(0.08).timeout
	var img: Image = null if DisplayServer.get_name() == "headless" else get_root().get_texture().get_image()
	if img == null:
		print("breaker_prompt_preview: no image (headless); run it windowed")
	else:
		img.save_png("user://breaker_prompt.png")
		print("saved ", ProjectSettings.globalize_path("user://breaker_prompt.png"))
	quit()
