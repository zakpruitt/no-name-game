extends SceneTree
## Films one live foe (spar.gd's kinds) against the hero from the game camera, scripted, for the spar audit's
## before / after clips (docs/spar-audit-2026-11-07.md):
##   timeout 120 godot --path . -s tests/spar_film.gd -- --kind=warrior --case=counter [--dir=name] [--fps=30]
##     user://<dir>/<kind>_<case>/NNN.png + INDEX.txt (real ms, his state and hp, the foe's state, strike_in, held)
## Cases:
##   counter   it winds up on its own; he dashes into it as strike_in() reaches COUNTER_AT (Backlash; a bolt for archer
##             and mage)
##   hurt      he stands there: the strike lands, and he dashes out of the hurt as soon as it lets him
##   collapse  mid-windup it is swallowed by Collapse's hole (collapse_spit.gd, as void_element._collapse plays it)
##   poise     mid-windup he hits it L1, L2, then Molten Palm's EC (warrior: poise 8)
##   respawn   he stands by the back wall and it dies: where it comes back
## Windowed only (headless draws nothing). The dummies are cleared; `user://` is shared, so copy the frames out.

const SIZE := Vector2i(800, 450)
const COUNTER_AT := 0.15  # s before contact he presses

var _main: Node
var _p: CharacterBody3D
var _foe: Node
var _frames: Array = []
var _t0 := 0
var _n := 0
var _fps := 30.0
var _dir := "user://spar_film"
var _kind := "warrior"
var _case := "counter"


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game._hints_seen = game.HINTS.keys()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			_kind = arg.get_slice("=", 1)
		if arg.begins_with("--case="):
			_case = arg.get_slice("=", 1)
		if arg.begins_with("--dir="):
			_dir = "user://" + arg.get_slice("=", 1)
		if arg.begins_with("--fps="):
			_fps = float(arg.get_slice("=", 1))
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await create_timer(1.5).timeout
	_p = _main.player
	_p.bot_enabled = true
	_p.bot_move = Vector3.ZERO
	_main.clear_room()
	await create_timer(0.3).timeout
	var spar: GDScript = load("res://scripts/spar.gd")
	if _case == "respawn":
		_p.global_position = Vector3(0.0, _p.global_position.y, -_main.ARENA_HALF + 2.0)
		var s: Node = spar.start(_main, PackedStringArray(["--spar=" + _kind]))
		await create_timer(1.2).timeout
		_start()
		for i in 15:
			await _frame()
		s.foe.take_hit(9999.0, Vector3(0, 0, -6.0), 0.0, true)
		await _film(4.5)
		_flush()
		return
	_p.global_position = Vector3(0.0, _p.global_position.y, 0.0)
	_p._face(Vector3(0, 0, -1))
	_p.model.rotation.y = _p._facing_yaw
	var far := 6.0 if _kind in ["archer", "mage"] else 1.8
	_foe = _main._spawn(_kind, false, Vector3(0.0, 0.0, -far))
	_foe.attack_damage *= spar.DAMAGE_SCALE
	_foe.max_hp = 500.0
	_foe.hp = 500.0
	_foe.dodge_chance = 0.0
	await create_timer(1.1).timeout
	_foe.move_speed = 0.0
	_foe._attack_cd = 99.0
	_start()
	for i in 8:
		await _frame()
	match _case:
		"counter":
			_foe._attack_cd = 0.0
			var counter: GDScript = load("res://scripts/counter.gd")
			for i in 300:
				await _frame()
				var c: Dictionary = counter.find(_p, _to())
				if not c.is_empty() and c.t <= COUNTER_AT:
					_p.bot_move = _to()
					_p._start_dash()
					_p.bot_move = Vector3.ZERO
					break
			await _film(2.2)
		"hurt":
			_foe._attack_cd = 0.0
			var hp: float = _p.hp
			for i in 200:
				await _frame()
				if _p.hp < hp:
					break
			while _p.state == _p.State.HURT:
				_p._dash_buffer_t = 0.2
				_p.bot_move = Vector3(1, 0, 0)
				await _frame()
			_p.bot_move = Vector3.ZERO
			await _film(1.0)
		"collapse":
			_windup(0.55)
			for i in 3:
				await _frame()
			var collapse: GDScript = load("res://scripts/collapse_spit.gd")
			var dark: GDScript = load("res://scripts/dark_fx.gd")
			var g: Node3D = collapse.start(_p, (_foe as Node3D).global_position + Vector3(0.4, 0, 0), [_foe], func(_e: Node) -> bool: return false)
			g.on_swallow = func(e: Node3D) -> void: dark.quiet_hit(e, 4.0, true)
			g.on_spit = func(e: Node3D, _i: int) -> void:
				if is_instance_valid(e):
					e.remove_meta("thrown_foe_flying")
					e.take_hit(4.0, Vector3(0, 0, -2.0), 9.0, true)
			await _film(2.6)
		"poise":
			_windup(0.8)
			_p._start_attack("L1")
			await _film(0.24)
			_p._start_attack("L2")
			await _film(0.26)
			_p._start_attack("EC")
			await _film(1.6)
	_flush()


func _to() -> Vector3:
	var to: Vector3 = (_foe as Node3D).global_position - _p.global_position
	to.y = 0.0
	return to.normalized()


func _windup(total: float) -> void:
	_foe._set_state(_foe.State.WINDUP)
	_foe._face(-_to())
	_foe._play("1H_Melee_Attack_Chop", 0.1, _foe.chop_speed())
	_foe._state_t = _foe.attack_windup - total


func _start() -> void:
	_t0 = Time.get_ticks_msec()
	_n = 0


func _film(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await _frame()


func _frame() -> void:
	await RenderingServer.frame_post_draw
	var now := Time.get_ticks_msec()
	if now - _t0 < _n * 1000.0 / _fps:
		return
	_n = int((now - _t0) * _fps / 1000.0) + 1
	var img: Image = get_root().get_texture().get_image()
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
	var spar: Node = _main.get_node_or_null("Spar")
	var e: Variant = _foe if spar == null else spar.foe
	var line := "%03d t=%5d ms hero=%-6s hp%d scale=%.2f" % [_frames.size(), now - _t0, _p.State.keys()[_p.state], int(_p.hp), Engine.time_scale]
	if is_instance_valid(e):
		line += " | foe %-8s y%.1f si%.2f%s%s" % [e.State.keys()[e.state], e.global_position.y, e.strike_in(),
			" held" if e.has_method("held") and e.held() else "", " (%.1f,%.1f)" % [e.global_position.x, e.global_position.z]]
	_frames.append([img, line])


func _flush() -> void:
	var dir := "%s/%s_%s" % [_dir, _kind, _case]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var index := PackedStringArray(["%s %s at %d fps" % [_kind, _case, int(_fps)]])
	for i in _frames.size():
		_frames[i][0].save_png("%s/%03d.png" % [dir, i])
		index.append(_frames[i][1])
	var f := FileAccess.open(dir + "/INDEX.txt", FileAccess.WRITE)
	f.store_string("\n".join(index) + "\n")
	f.close()
	print("[spar_film] %s frames=%d -> %s" % [dir, _frames.size(), ProjectSettings.globalize_path(dir)])
	quit(0)
