extends SceneTree
## Films every autotest bot string (training_bot.BOT_STRINGS: all 21 moves and the 7 breakers) from the game
## camera at 12 fps, on the training dummies, played by the bot exactly as the autotest plays them:
##   timeout 300 godot --path . -s tests/string_film.gd [-- --no-gather] [--from=N: start at BOT_STRINGS[N]] [--dir=name]
##     user://string_film/<string>/NNN.png + INDEX.txt  (one folder per string, e.g. L_L_L_H, hold)
##     user://string_film/freeplay/NNN.png + INDEX.txt  (10 s of the bot chaining strings after the pass)
## Windowed only (headless draws nothing), about a minute. Frames are 800x450 (half the window); each grab stalls
## a few ms, so hitstop and rhythm run a touch slower than in play: read the INDEX's real ms, time scale and move,
## and take the autotest's `[rhythm]` lines for the numbers. Frames sit in memory and are written when the bot
## moves to the next string (a stall while he walks up, not mid-string). `user://` is shared: copy it out at once.
## Contact sheets: tools are the caller's (PIL), the INDEX lines say what each frame shows.

const DIR := "user://string_film"
## `-- --dir=<name>`: film into user://<name> instead (user:// is shared by every worktree: two lanes filming at once
## overwrote each other's frames).
var _dir := DIR
const FPS := 12.0
const FREEPLAY_S := 10.0
const SIZE := Vector2i(800, 450)

var _main: Node
var _p: CharacterBody3D
var _bot: Node
var _frames: Array = []  # [Image, index line]
var _t0 := 0  # ms the current film started
var _n := 0  # frames due so far in this film (a fixed 1/FPS schedule from _t0)
var _brk_seen := 0  # breakers landed at the last slam frame grabbed
var _hit_seen := ""  # move id + hits done at the last contact frame grabbed


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game._hints_seen = game.HINTS.keys()
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	_p = _main.player
	var waited := 0.0
	while get_nodes_in_group("enemies").is_empty() and waited < 6.0:
		await create_timer(0.1).timeout
		waited += 0.1
	await create_timer(1.5).timeout
	_bot = load("res://scripts/training_bot.gd").new()
	_bot.main = _main
	_main.add_child(_bot)
	# Keep the bot's own screenshots and its finish (it quits the tree) out of this run.
	for flag in ["_hit_shot_taken", "_dash_shot_taken", "_guide_shot_taken", "_cast_shot_taken"]:
		_bot.set(flag, true)
	_bot._shots_taken = 99
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			_dir = "user://" + arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var strings: Array = _bot.BOT_STRINGS
	var filming := 0
	# Scattered, dazed dummies after a breaker made the next string whiff whole (L L L H after Grounded): by
	# default each string starts with the dummies in a fan in front of him. `-- --no-gather` films the room as is.
	var gather := not "--no-gather" in OS.get_cmdline_user_args()
	if gather:
		_gather()
	for arg: String in OS.get_cmdline_user_args():  # `-- --from=N`: start at BOT_STRINGS[N], the earlier ones count as filmed
		if arg.begins_with("--from="):
			filming = clampi(int(arg.get_slice("=", 1)), 0, strings.size() - 1)
			_bot._bot_string = filming
			for i in filming:
				_bot._bot_strings_done[i] = true
	_t0 = Time.get_ticks_msec()
	while _bot._bot_strings_done.size() < strings.size():
		_bot._autotest_t = 0.0
		await RenderingServer.frame_post_draw
		if _bot._bot_string != filming:  # the bot moved on: write the last string out
			_flush(_name(strings[filming]))
			filming = _bot._bot_string
			_t0 = Time.get_ticks_msec()
			_n = 0
			if gather:
				_gather()
		_grab()
		if Time.get_ticks_msec() - _t0 > 20000:
			print("[string_film] stuck on ", _name(strings[filming]), " step=", _bot._bot_step, " pending=", _bot._bot_pending,
				" wait=", _bot._bot_wait, " post_dash=", _p._post_dash_t, " state=", _p.state, " foes=",
				get_nodes_in_group("enemies").map(func(e: Node3D) -> float: return snappedf(e.global_position.distance_to(_p.global_position), 0.1)))
			break
	_frames.clear()  # (the next string's first walk-up frames)
	_t0 = Time.get_ticks_msec()
	_n = 0
	while Time.get_ticks_msec() - _t0 < FREEPLAY_S * 1000.0:
		_bot._autotest_t = 0.0
		await RenderingServer.frame_post_draw
		_grab()
	_flush("freeplay")
	for line: String in _bot._rhythm_log:
		print(line)
	print("[string_film] done strings=%d/%d breakers=%d moves=%s -> %s" % [_bot._bot_strings_done.size(), strings.size(),
		_p.breakers_landed, ",".join(_bot._bot_moves.keys()), ProjectSettings.globalize_path(_dir)])
	quit(0)


## Him back in the middle of the room facing up the screen, the dummies in a loose fan in front of him
## (element_shots' fan) with their homes there, so every string starts from the same place and lands on them
## (moving only the dummies walked the films into the east wall string by string).
func _gather() -> void:
	_p.global_position = Vector3(0.0, _p.global_position.y, 0.0)
	_p._face(Vector3(0.0, 0.0, -1.0))
	var fwd: Vector3 = _p._facing()
	var foes := get_nodes_in_group("enemies")
	for i in foes.size():
		var side := (i - (foes.size() - 1) * 0.5) * 1.4
		foes[i].global_position = _p.global_position + fwd * (2.2 + i % 2 * 1.0) + fwd.cross(Vector3.UP) * side
		foes[i].velocity = Vector3.ZERO
		if "home" in foes[i]:
			foes[i].home = foes[i].global_position  # (or it strolls back mid-string)


func _name(string: Array) -> String:
	return "_".join(string)


## One frame every 1/FPS s of real time (the display's 60 Hz quantises that to 83 or 100 ms), plus an extra frame
## marked HIT the first drawn frame after each new hit lands (the contact pose and hitstop rarely fall on the beat).
func _grab() -> void:
	var now := Time.get_ticks_msec()
	var key := "%s%d" % [_p._move_id, _p._hits_done]
	var hit: bool = _p.state == _p.State.ATTACK and _p._hits_done > 0 and key != _hit_seen
	if hit:
		_hit_seen = key
	if _p.breakers_landed != _brk_seen:  # a breaker's slam
		_brk_seen = _p.breakers_landed
		hit = true
	var due := now - _t0 >= _n * 1000.0 / FPS
	if not due and not hit:
		return
	if due:
		_n = int((now - _t0) * FPS / 1000.0) + 1
	var img: Image = get_root().get_texture().get_image()
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
	var line := "%03d%s t=%5d ms move=%-3s state=%-6s hits=%d scale=%.2f brk=%d combo=%d" % [_frames.size(), " HIT" if hit else "    ", now - _t0,
		_p._move_id if _p.state == _p.State.ATTACK else "-", _p.State.keys()[_p.state], _p._hits_done,
		Engine.time_scale, _p._brk_phase if _p.state == _p.State.LEAP else -1, get_root().get_node("Game").combo_count]
	_frames.append([img, line])


func _flush(film: String) -> void:
	var dir := "%s/%s" % [_dir, film]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var index := PackedStringArray(["%s at %d fps, %dx%d, game camera" % [film, int(FPS), SIZE.x, SIZE.y]])
	for i in _frames.size():
		_frames[i][0].save_png("%s/%03d.png" % [dir, i])
		index.append(_frames[i][1])
	var f := FileAccess.open(dir + "/INDEX.txt", FileAccess.WRITE)
	f.store_string("\n".join(index) + "\n")
	f.close()
	print("[string_film] %s frames=%d" % [film, _frames.size()])
	_frames.clear()
