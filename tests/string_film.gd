extends SceneTree
## Films every autotest bot string (training_bot.strings: all 21 moves and the 7 breakers) from the game
## camera at 12 fps, on the training dummies, played by the bot exactly as the autotest plays them:
##   timeout 300 godot --path . -s tests/string_film.gd [-- --no-gather] [--from=N: start at strings[N]] [--to=N: stop after it] [--dir=name] [--fps=N] [--tail=MS: film on after the string] [--no-awaken]
##     user://string_film/<string>/NNN.png + INDEX.txt  (one folder per string, e.g. L_L_L_H, hold)
##     user://string_film/freeplay/NNN.png + INDEX.txt  (10 s of the bot chaining strings after the pass)
##   `--room=<name>` (Game reads it: plain, pieces, cistern, forge; rooms.gd ORDER) films in that room; with
##     `--showcase` (round 57) it films the room's own showcase strings instead (rooms.gd ROOM_DEFS `showcase`: the
##     combo only that room makes possible), each from its spots, into user://<dir>/showcase_<name>/; `--overview`
##     films from a fixed camera high over the whole room instead of the game camera
##   `--layout=wall|stray` (with --from=11 --to=11, L L L H H + Meteor Fall): the dummies' homes near the back wall
##     instead of the fan. wall: all four in Molten Palm's strip, it carries them into the wall and the meteor drops
##     on them there; stray: one in the strip (splatted alone) and three bunched off to the side (the bigger group).
## Windowed only (headless draws nothing), about a minute. Frames are 800x450 (half the window); each grab stalls
## a few ms, so hitstop and rhythm run a touch slower than in play: read the INDEX's real ms, time scale and move,
## and take the autotest's `[rhythm]` lines for the numbers. Frames sit in memory and are written when the bot
## moves to the next string (a stall while he walks up, not mid-string). `user://` is shared: copy it out at once.
## Contact sheets: tools are the caller's (PIL), the INDEX lines say what each frame shows.

const DIR := "user://string_film"
## `-- --dir=<name>`: film into user://<name> instead (user:// is shared by every worktree: two lanes filming at once
## overwrote each other's frames).
var _dir := DIR
var _last := -1  # `-- --to=N`: the last BOT_STRINGS entry filmed (and no freeplay); -1 films them all
const FPS := 12.0
const FREEPLAY_S := 10.0
const SIZE := Vector2i(800, 450)

var _main: Node
var _p: CharacterBody3D
var _bot: Node
var _frames: Array = []  # [Image, index line]
var _t0 := 0  # ms the current film started
var _fps := FPS  # `-- --fps=N`: film denser (clips for Zak; frames still land on the display's 60 Hz)
var _tail := 0.0  # `-- --tail=MS`: keep filming a string this long after the bot moves on (a slide or a fall that outlasts it)
var _calm := false  # `-- --no-awaken`: the meter is held empty, so the bot never Awakens mid-film (its burst breaks ice)
var _n := 0  # frames due so far in this film (a fixed 1/FPS schedule from _t0)
var _brk_seen := 0  # breakers landed at the last slam frame grabbed
var _hit_seen := ""  # move id + hits done at the last contact frame grabbed
var _laid := false  # `--layout=`: the INDEX lines add each dummy's spot (x,z), hp and a * if fresh off a wall splat
var _show: Array = []  # `--showcase`: the room's showcase entries (rooms.gd), filmed in place of BOT_STRINGS
var _show_placed := -1  # the showcase he was last stood at its start for


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
		if arg.begins_with("--fps="):
			_fps = float(arg.get_slice("=", 1))
		if arg == "--no-awaken":
			_calm = true
		if arg.begins_with("--tail="):
			_tail = float(arg.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	if "--showcase" in OS.get_cmdline_user_args():
		_show = load("res://scripts/rooms.gd").showcase(game.room)
		if _show.is_empty():
			print("[string_film] room %s has no showcase (rooms.gd)" % game.room)
			quit(1)
			return
		_bot.strings = _show.map(func(sc: Dictionary) -> Array: return sc.tokens)
		_bot.string_labels = _show
		physics_frame.connect(_showcase_start)
	if "--overview" in OS.get_cmdline_user_args():  # (round 57: the whole room from high over the near edge, a fixed camera)
		var cam := Camera3D.new()
		get_root().add_child(cam)
		cam.fov = 50.0
		cam.global_position = Vector3(0, 30, 17)
		cam.look_at(Vector3(0, 0, -3))
		cam.make_current()
	var strings: Array = _bot.strings
	var filming := 0
	# Scattered, dazed dummies after a breaker made the next string whiff whole (L L L H after Grounded): by
	# default each string starts with the dummies in a fan in front of him. `-- --no-gather` films the room as is.
	var gather := not "--no-gather" in OS.get_cmdline_user_args() and _show.is_empty()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--layout="):
			gather = false
			_laid = true
			_layout(arg.get_slice("=", 1))
	if gather:
		_gather()
	for arg: String in OS.get_cmdline_user_args():  # `-- --from=N`: start at strings[N], the earlier ones count as filmed
		if arg.begins_with("--to="):
			_last = int(arg.get_slice("=", 1))
		if arg.begins_with("--from="):
			filming = clampi(int(arg.get_slice("=", 1)), 0, strings.size() - 1)
			_bot._bot_string = filming
			for i in filming:
				_bot._bot_strings_done[i] = true
	if not _show.is_empty():
		_showcase(filming)
	_t0 = Time.get_ticks_msec()
	while _bot._bot_strings_done.size() < strings.size():
		_bot._autotest_t = 0.0
		await RenderingServer.frame_post_draw
		if _bot._bot_string != filming and _tail > 0.0:  # (the tail: film on until the next string's reset)
			var tail_t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - tail_t0 < _tail and not _bot._reset_done:
				_bot._autotest_t = 0.0
				_grab()
				await RenderingServer.frame_post_draw
		if _bot._bot_string != filming:  # the bot moved on: write the last string out
			_flush(_name(strings[filming]))
			filming = _bot._bot_string
			if _last >= 0 and filming > _last:  # `-- --to=N`: stop after strings[N]
				break
			_t0 = Time.get_ticks_msec()
			_n = 0
			if gather and not _bot._reset_done:  # (a tail ran on to the bot's own reset: its layout stands, a "wall" one too)
				_gather()
			if not _show.is_empty() and not _bot._reset_done:
				_showcase(filming)
		_grab()
		if Time.get_ticks_msec() - _t0 > 20000:
			print("[string_film] stuck on ", _name(strings[filming]), " step=", _bot._bot_step, " pending=", _bot._bot_pending,
				" wait=", _bot._bot_wait, " post_dash=", _p._post_dash_t, " state=", _p.state, " foes=",
				get_nodes_in_group("enemies").map(func(e: Node3D) -> float: return snappedf(e.global_position.distance_to(_p.global_position), 0.1)))
			break
	if not _show.is_empty() and strings.size() == 1 and not _frames.is_empty():  # (one showcase: the bot's index never moves on, so it isn't flushed in the loop)
		_bot.process_mode = Node.PROCESS_MODE_DISABLED  # (or it resets the dummies and plays the string again)
		var end_t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - end_t0 < _tail:  # (and its tail: the bot is idle, the room plays on)
			_bot._autotest_t = 0.0
			_grab()
			await RenderingServer.frame_post_draw
		_flush(_name(strings[filming]))
	_frames.clear()  # (the next string's first walk-up frames)
	if _last >= 0:
		print("[string_film] done (--to=%d) -> %s" % [_last, ProjectSettings.globalize_path(_dir)])
		quit(0)
		return
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
	var foes := get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return not e.has_meta("spar"))
	_spar_near()
	for i in foes.size():
		var side := (i - (foes.size() - 1) * 0.5) * 1.4
		foes[i].global_position = _p.global_position + fwd * (2.2 + i % 2 * 1.0) + fwd.cross(Vector3.UP) * side
		foes[i].velocity = Vector3.ZERO
		if "home" in foes[i]:
			foes[i].home = foes[i].global_position  # (or it strolls back mid-string)


## Spar pass two: the live foe (`--spar=`) is not gathered into the fan (pulled 1.6-1.8 m in front of him, it wound
## up as the bot walked in, so his hurts clustered at each string's start). It stays where it is, in play; only when it
## has wandered past SPAR_NEAR m from the room's middle is it put SPAR_AT from there, on his flank, to walk back in.
const SPAR_NEAR := 7.0
const SPAR_AT := Vector3(4.6, 0.0, 1.2)
func _spar_near() -> void:
	var spar: Node = _main.get_node_or_null("Spar")
	if spar == null or not is_instance_valid(spar.foe) or not spar.foe.is_alive():
		return
	var e: Node3D = spar.foe
	if e.has_meta("thrown_foe_flying") or Vector2(e.global_position.x, e.global_position.z).length() <= SPAR_NEAR:
		return
	e.global_position = Vector3(SPAR_AT.x, e.global_position.y if e.is_on_floor() else 0.0, SPAR_AT.z)
	e.velocity = Vector3.ZERO


## `--layout=`: the dummies' homes (the bot puts them there before each string, and him BOT_SPOT m short of the
## first one, facing it: here up the room at the back wall, z -16).
const LAYOUTS := {
	"wall": [Vector3(0, 0, -8.0), Vector3(-1.0, 0, -8.4), Vector3(1.0, 0, -8.4), Vector3(0, 0, -9.0)],
	"stray": [Vector3(0, 0, -8.0), Vector3(4.2, 0, -8.6), Vector3(5.2, 0, -9.2), Vector3(4.4, 0, -9.9)],
}
func _layout(kind: String) -> void:
	var foes: Array = _main._dummies
	for i in foes.size():
		foes[i].home = LAYOUTS[kind][i % LAYOUTS[kind].size()]
		foes[i].global_position = foes[i].home
		foes[i].velocity = Vector3.ZERO


func _name(string: Array) -> String:
	if not _show.is_empty():
		for sc: Dictionary in _show:
			if sc.tokens == string:
				return "showcase_" + str(sc.name).replace(" ", "_")
	return "_".join(string)


## `--showcase`: showcase `i`'s spots (rooms.gd): the dummies' homes, and his start (the bot's reset stands him
## training_bot.BOT_SPOT m from the first dummy toward it; _showcase_start then puts him on it).
func _showcase(i: int) -> void:
	var sc: Dictionary = _show[i]
	var foes: Array = _main._dummies
	for k in foes.size():
		foes[k].home = sc.dummies[k % sc.dummies.size()]
		foes[k].global_position = foes[k].home
		foes[k].velocity = Vector3.ZERO
	_bot._start_pos = sc.hero
	_p.global_position = Vector3(sc.hero.x, _p.global_position.y, sc.hero.z)


## One frame every 1/FPS s of real time (the display's 60 Hz quantises that to 83 or 100 ms), plus an extra frame
## marked HIT the first drawn frame after each new hit lands (the contact pose and hitstop rarely fall on the beat).
func _grab() -> void:
	if _calm:
		get_root().get_node("Game").awakening = 0.0
	var now := Time.get_ticks_msec()
	var key := "%s%d" % [_p._move_id, _p._hits_done]
	var hit: bool = _p.state == _p.State.ATTACK and _p._hits_done > 0 and key != _hit_seen
	if hit:
		_hit_seen = key
	if _p.breakers_landed != _brk_seen:  # a breaker's slam
		_brk_seen = _p.breakers_landed
		hit = true
	var due := now - _t0 >= _n * 1000.0 / _fps
	if not due and not hit:
		return
	if due:
		_n = int((now - _t0) * _fps / 1000.0) + 1
	var img: Image = get_root().get_texture().get_image()
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
	var line := "%03d%s t=%5d ms move=%-3s state=%-6s hits=%d scale=%.2f brk=%d combo=%d" % [_frames.size(), " HIT" if hit else "    ", now - _t0,
		_p._move_id if _p.state == _p.State.ATTACK else "-", _p.State.keys()[_p.state], _p._hits_done,
		Engine.time_scale, _p._brk_phase if _p.state == _p.State.LEAP else -1, get_root().get_node("Game").combo_count]
	var spar: Node = _main.get_node_or_null("Spar")  # `-- --spar=<kind>`: the live foe's state on every line
	if spar != null:
		line += _spar_cols(spar)
	if not _show.is_empty():  # (the showcase: where he is and faces, the breaker's aim)
		var f: Vector3 = _p._facing()
		line += " | at %.1f,%.1f face %.2f,%.2f brk_dir %.2f,%.2f" % [_p.global_position.x, _p.global_position.z, f.x, f.z,
			_p._brk_dir.x, _p._brk_dir.z]
		for d: Node3D in _main._dummies:
			line += " | %.1f,%.1f" % [d.global_position.x, d.global_position.z]
	if _laid:
		var ve: GDScript = load("res://scripts/void_element.gd")
		for d: Node3D in _main._dummies:
			line += " | %.1f,%.1f hp%d%s" % [d.global_position.x, d.global_position.z, int(d.hp), "*" if ve.wall_fresh(d) else ""]
	_frames.append([img, line])


## ` | spar <STATE> hp y strike_in [held flags] d | hero hp`: what the live foe (spar.gd) is doing this frame.
## Flags: F flying (thrown_foe), B bound (floor_bind / a hook), Z frozen, A airborne, W telegraph up; b m s c buried,
## molten, skewered, charged.
func _spar_cols(spar: Node) -> String:
	var hero := " | hero hp%d %s" % [int(_p.hp), "INV" if _p._invuln_t > 0.0 else ""]
	var e: Node3D = spar.foe
	if not is_instance_valid(e):
		return " | spar - kills=%d hits=%d%s" % [spar.kills, spar.total_hits(), hero]
	var flags := ""
	flags += "F" if e.has_meta("thrown_foe_flying") else ""
	flags += "B" if e.has_meta("x_bound") else ""
	flags += "Z" if e.frozen_t > 0.0 else ""
	flags += "A" if e.state == e.State.AIRBORNE else ""
	flags += "W" if e._telegraph.visible else ""
	for st: String in ["buried", "molten", "skewered", "charged"]:  # (the crossover states, lower case)
		flags += st[0] if int(e.get_meta("x_" + st, 0)) > Time.get_ticks_msec() else ""
	return " | spar %-8s hp%d y%.1f si%.2f %-4s d%.1f%s" % [e.State.keys()[e.state], int(e.hp), e.global_position.y,
		e.strike_in(), flags, e.global_position.distance_to(_p.global_position), hero]


func _flush(film: String) -> void:
	var dir := "%s/%s" % [_dir, film]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var index := PackedStringArray(["%s at %d fps, %dx%d, game camera" % [film, int(_fps), SIZE.x, SIZE.y]])
	for i in _frames.size():
		_frames[i][0].save_png("%s/%03d.png" % [dir, i])
		index.append(_frames[i][1])
	var f := FileAccess.open(dir + "/INDEX.txt", FileAccess.WRITE)
	f.store_string("\n".join(index) + "\n")
	f.close()
	print("[string_film] %s frames=%d" % [film, _frames.size()])
	_frames.clear()


## `--showcase`: once the bot has reset the string (before its first press, which comes on its next physics tick), him
## on the showcase's own start, facing its way.
func _showcase_start() -> void:
	if not _bot._reset_done or _bot._bot_step != 0 or _show_placed == _bot._bot_string:
		return
	_show_placed = _bot._bot_string
	var sc: Dictionary = _show[_bot._bot_string]
	_p.global_position = Vector3(sc.hero.x, _p.global_position.y, sc.hero.z)
	_p.velocity = Vector3.ZERO
	_p._face(sc.get("face", Vector3(sc.dummies[0] - sc.hero)))
	_p.model.rotation.y = _p._facing_yaw
