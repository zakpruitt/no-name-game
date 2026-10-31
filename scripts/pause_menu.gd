extends "res://scripts/menu_screen.gd"
## Pause menu: Esc / Start toggles it during a run. Won't open over other
## screens that already pause the game (title, rewards, run summary).


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_open():
		close_menu()
	elif not get_tree().paused:
		_open()
	else:
		return
	get_viewport().set_input_as_handled()


func _open(focus := 0) -> void:
	show_menu("PAUSED", "", [
		["Resume", close_menu],
		[Game.shake_label(), _cycle_shake],
		[Game.music_label(), _cycle_music],
		["Restart run", _restart.bind(true)],
		["Quit to title", _restart.bind(false)],
		["Quit game", _quit],
	], "", 0.7, focus)


func _cycle_shake() -> void:
	Game.cycle_shake()
	_open(1)


func _cycle_music() -> void:
	Game.cycle_music()
	_open(2)


func _restart(skip_title: bool) -> void:
	Game.skip_title = skip_title
	close_menu()
	get_tree().reload_current_scene()


func _quit() -> void:
	Game.stop_all_sfx()
	get_tree().quit()
