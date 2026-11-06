extends SceneTree
## Combo breaker timing prompt (breaker_prompt.gd), windowed: two rows of states on a dark backdrop, saved to
## user://breaker_prompt.png. Top: a two-ending window (Maw / Black Ice: both chips, both mouse buttons lit)
## filling, open, full, LMB picked, too early. Bottom: a one-ending window (Grounded: one chip, the right button)
## in the same states, the last a perfect. Needs a window (2D drawing).
## Run: godot --path . -s tests/breaker_prompt_preview.gd

const PAL := preload("res://scripts/fx_palette.gd")


class FakePlayer extends Node:
	var w := {}
	func breaker_window() -> Dictionary: return w


func _initialize() -> void:
	await process_frame
	get_root().size = Vector2i(1500, 340)
	var prompt_script: GDScript = load("res://scripts/breaker_prompt.gd")
	var back := ColorRect.new()
	back.color = Color(0.32, 0.31, 0.3)
	back.size = Vector2(1500, 340)
	get_root().add_child(back)
	var two := {"open": 0.36, "sweet": 0.5, "close": 0.66, "color": PAL.of("void").body, "name": "Maw", "alt_name": "Black Ice",
		"options": [{"button": "light", "name": "Black Ice", "element": "water", "color": PAL.of("water").body},
			{"button": "heavy", "name": "Maw", "element": "void", "color": PAL.of("void").body}]}
	var one := {"open": 0.36, "sweet": 0.5, "close": 0.66, "color": PAL.of("wind").body, "name": "Grounded", "alt_name": "",
		"options": [{"button": "heavy", "name": "Grounded", "element": "wind", "color": PAL.of("wind").body}]}
	var live := [0.2, 0.42, 0.5]
	var ends := [{"ended": "hit", "chose": "light"}, {"ended": "lock", "chose": "light"}]
	var ends_one := [{"ended": "hit", "chose": "heavy"}, {"ended": "perfect", "chose": "heavy"}]
	for row in 2:
		for i in 5:
			var fake := FakePlayer.new()
			get_root().add_child(fake)
			var w: Dictionary = (two if row == 0 else one).duplicate(true)
			w.live = true
			w.t = live[mini(i, 2)]
			fake.w = w
			var pr: Control = prompt_script.new()
			pr.player = fake
			pr.center = Vector2(150 + i * 300, 80 + row * 170)
			pr.fixed = true
			get_root().add_child(pr)
			if i >= 3:  # one live frame, then it ends
				await process_frame
				await process_frame
				fake.w = (ends if row == 0 else ends_one)[i - 3]
	await create_timer(0.06).timeout
	var img: Image = null if DisplayServer.get_name() == "headless" else get_root().get_texture().get_image()
	if img == null:
		print("breaker_prompt_preview: no image (headless); run it windowed")
	else:
		img.save_png("user://breaker_prompt.png")
		print("saved ", ProjectSettings.globalize_path("user://breaker_prompt.png"))
	quit()
