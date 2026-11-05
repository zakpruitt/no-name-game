extends Node
## The autotest bot (`-- --autotest`), a child of the training room (main.gd):
## plays BOT_STRINGS on the dummies, through every element and breaker, for
## AUTOTEST_TIME seconds (longer until every string has played), saves screenshots to user:// (windowed only), then
## prints the `[autotest] done`, `[perf]` and `[training]` lines and quits.
##
## `[perf]`: the wall frame time (capped by the display: 60 fps on Zak's machine
## even with vsync off), and what each frame cost: `cpu` = every node's process
## and physics work (perf_probe.gd) + the render submit, `gpu` = the GPU's
## render time. A spike is a frame over 25 ms wall or 8 ms cpu.

const AUTOTEST_TIME := 16.0
## The autotest runs on past AUTOTEST_TIME until the bot has played every BOT_STRINGS entry once (each prints
## its `[rhythm]` line), up to AUTOTEST_MAX s.
const AUTOTEST_MAX := 100.0  # (was 60, then 80: 24 strings with round 4's two hand-feel cells)

var main: Node  # the training room
var player: CharacterBody3D
var hud: CanvasLayer
var _autotest_t := 0.0
var _hits := 0
var _max_combo := 0
## The bot's strings, in turn: "L" light, "H" right click, "D" dash, "hold" holds right
## click (Overwhelm), "alt" (anywhere in it) makes the breaker press L, its `alt` ending. Each runs into its breaker where it has one (player presses it at
## the sweet spot for the bot), so the autotest walks every element and the dark. Frost Spear (L L H)
## only plays inside L L H L H, which sets the spear off: while it stands (5 s) any L or H press vaults onto
## it (void_element.vaults), and a lone L L H sent the next strings up the spear (Collapse and Grounded
## never played).
const BOT_STRINGS := [["L", "H"], ["L", "H", "H"], ["L", "L", "L", "H"], ["H", "H"], ["H", "L", "H"],
	["L", "H", "L", "H"], ["D", "L", "H"], ["D", "L", "H", "H"], ["D", "H"],
	# (L L L H H: Molten Palm shoves the dummies, Undertow pins them, Meteor Fall dives on the biggest group of them.)
	["L", "L", "H", "L", "H"], ["hold"], ["L", "L", "L", "H", "H"], ["L", "L", "L"],
	# Crossovers (round 34): Rockslide into Fault Line and Cataclysm, Steam Burst into Flash Freeze, Storm Pitch,
	# and Black Ice ("alt": the window's press is L, Maw's other ending).
	["L", "H", "L", "L", "H"], ["D", "L", "H", "H", "L"], ["D", "H", "L"], ["alt", "H", "L", "H"],
	# Three elements a string (second pass): Hailstorm, Meltdown and Eruption in the air; the spear, Impale, Backdraft
	# and Anvil (Backdraft blows the spear apart, so it doesn't send the next string up it).
	# ("line": the dummies stand in a column along his aim for it, so Harpoon reels in all four and Hailstorm has
	# every cube to lift: from the fan Dash Stab lunged into the first and Harpoon only ever took that one.)
	["line", "D", "L", "H", "H", "H", "L"], ["L", "L", "H", "D", "H", "H", "L"],
	# The element matrix (third pass, void_element.IMPROV): a dash and a base move of another element on a state.
	# Harpoon's ice, then Tow Line's dark shatters it (frozen x dark); Rockslide's buried, then Harpoon freezes them in
	# the floor (buried x ice); Updraft Lash's air, then Harpoon freezes them up there (airborne x ice).
	# ("face": he aims at the nearest foe for the string, as a player would. The payoff follows the move's own hit
	# shape (void_element.improv_reach), and the dash and Dash Stab's lunge leave the buried behind him.)
	["line", "D", "L", "H", "D", "H"], ["face", "L", "H", "L", "L", "D", "L", "H"], ["face", "L", "H", "D", "L", "H"],
	# Round 4: the two cells only a hand could reach. "out" lets him dash out of a breaker's hang (the bot never
	# does otherwise), "wait" holds the next press until he stands again (so L is L1, not Dash Stab).
	# Meltdown's molten, then Updraft Lash fans the flames (molten x storm); Undertow's bind, then Updraft Lash tears
	# them loose (bound x storm).
	["line", "out", "face", "D", "L", "H", "H", "H", "L", "D", "wait", "L", "H"],
	["out", "face", "L", "L", "L", "H", "H", "D", "wait", "L", "H"]]
## Tokens that aren't presses (each sets something up for the whole string).
const BOT_SETUP := ["alt", "line", "out", "face"]
## A "line" string's column starts BOT_LINE_FROM m in front of him, BOT_LINE_GAP m apart: the dash and Dash Stab's
## lunge carry him ~5 m, straight through a column that starts at BOT_SPOT (Harpoon then fired at nobody).
const BOT_LINE_FROM := 5.0
const BOT_LINE_GAP := 1.6
const BOT_GAP := 0.35  # s standing between strings
## Every string starts from the same place (round 30, second pass): once the dummies stand again (or after
## BOT_SETTLE_MAX s) they're put back on their homes and the hero BOT_SPOT m from the first one, toward where
## he started, facing it. Strings used to start wherever the last one threw them, so 5-7 of the 7 breakers
## landed; now every run lands all of them (agent.sh checks `breakers=7/7`).
const BOT_SPOT := 2.0
const BOT_SETTLE_MAX := 2.5
## The bot presses this long (s, move time) before the move's cancel point. At combo_window()'s BUFFER_MS
## a press made as an Awakened Updraft Lash started lapsed just before its cancel, and L H L H lost its air slash.
## Still inside the buffer, so every press fires on the first legal frame and the [rhythm] beats are unchanged.
const BOT_LEAD := 0.15
var _start_pos := Vector3.ZERO  # where the hero stood when the bot took over
var _reset_done := false  # this string's start has been reset
var _settle_t := 0.0
var _press_frame := -1  # physics frame of the bot's last press
var _bot_string := 0  # BOT_STRINGS index playing
var _bot_face := false  # this string aims at the nearest foe ("face")
var _homes := {}  # dummy -> its home, while a "line" string has it standing elsewhere
var _bot_step := 0  # next token in it
var _bot_wait := 1.0  # s before the next string starts
var _bot_hold_t := 0.0  # holding right click while > 0
var _bot_pending := ""  # the token just pressed, until he takes it (or BOT_TAKE s pass)
var _bot_pending_t := 0.0
var _bot_starts := 0  # moves started (player.attack_started), to see a press taken
var _bot_starts_at := 0
const BOT_TAKE := 0.7
var _bot_moves := {}  # every move id the bot started (autotest `moves=`)
var _rhythm_log: Array[String] = []  # the [rhythm] lines, printed at the end (a print mid-run is a frame spike)
var _bot_rhythm := []  # [move id, real ms] per move started in this string, for the `[rhythm]` line
var _bot_strings_done := {}  # BOT_STRINGS index -> played (autotest `strings=`)
# Autotest frame stats (real time, so hitstop slow-mo doesn't skew them).
var _perf := {"frames": 0, "total_ms": 0.0, "worst_ms": 0.0, "spikes": 0, "enemies": 0, "draws": 0, "nodes": 0,
	"cpu_ms": 0.0, "cpu_worst": 0.0, "cpu_spikes": 0, "gpu_ms": 0.0, "gpu_worst": 0.0}
var _perf_last_us := 0
var _probe: Node  # perf_probe.gd: times each frame's node work
var _perf_last_frame := 0
# Spike lines, printed at the end: a print costs 2-10 ms with stdout piped,
# which showed up as its own spike the frame after.
var _perf_log: Array[String] = []
var _shots_taken := 0
var _hit_shot_taken := false
var _dash_shot_taken := false
var _dash_shot_at := 0
var _guide_shot_taken := false
var _cast_shot_taken := false
var _quitting := false


func _ready() -> void:
	player = main.player
	hud = main.hud
	_start_pos = player.global_position
	Game.combo_changed.connect(func(c: int, _r: String) -> void:
		_max_combo = maxi(_max_combo, c)
		if c > 0:
			_hits += 1)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_probe = preload("res://scripts/perf_probe.gd").new()
	_probe.on_frame = _sample_perf
	add_child(_probe)
	player.bot_enabled = true
	player.attack_started.connect(func(id: String) -> void:
		_bot_starts += 1
		_bot_rhythm.append([id, Time.get_ticks_msec()]))


func _process(delta: float) -> void:
	_autotest_t += delta
	_drive_bot()
	var shot_times := [2.5, 6.0, 9.5]
	if _shots_taken < shot_times.size() and _autotest_t >= shot_times[_shots_taken]:
		_snap("user://autotest_%d.png" % _shots_taken)
		_shots_taken += 1
	var since_big := Time.get_ticks_msec() - Fx.last_big_hit_ms
	if not _hit_shot_taken and Fx.last_big_hit_ms > 0 and since_big >= 190 and _autotest_t > 3.0:
		_hit_shot_taken = true
		_snap("user://autotest_hit.png")
	if _dash_shot_at == 0 and Fx.last_afterimage_ms > 0 and _autotest_t > 3.0:
		_dash_shot_at = Time.get_ticks_msec() + 110  # a few ghosts into the dash
	if not _dash_shot_taken and _dash_shot_at > 0 and Time.get_ticks_msec() >= _dash_shot_at:
		_dash_shot_taken = true
		_snap("user://autotest_dash.png")
	if not _guide_shot_taken and hud.combo_guide._rows.size() >= 3 and hud.combo_guide._vis >= 1.0 and player.combo_window().ready:
		_guide_shot_taken = true
		_snap("user://autotest_guide.png")
	if not _cast_shot_taken and player.ELEMENTS.casts >= 6:
		_cast_shot_taken = true
		await get_tree().create_timer(0.1, true, false, true).timeout
		_snap("user://autotest_cast.png")
	if _autotest_t >= AUTOTEST_MAX or (_autotest_t >= AUTOTEST_TIME and _bot_strings_done.size() >= BOT_STRINGS.size()):
		_autotest_finish()


## Called by the probe at the end of each frame with that frame's node work.
func _sample_perf(node_ms: float) -> void:
	var now := Time.get_ticks_usec()
	var frame := Engine.get_process_frames()
	# Skip gaps from paused menus and screenshot saves (not gameplay frames).
	if _perf_last_us > 0 and frame == _perf_last_frame + 1 and _autotest_t > 1.0:
		var ms := (now - _perf_last_us) / 1000.0
		# `cpu` is what the frame cost on the main thread (node work + render
		# submit), `gpu` the GPU's render time: the wall `ms` is capped.
		var vp := get_viewport().get_viewport_rid()
		var cpu := node_ms + RenderingServer.viewport_get_measured_render_time_cpu(vp)
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		_perf.cpu_ms += cpu
		_perf.cpu_worst = maxf(_perf.cpu_worst, cpu)
		_perf.gpu_ms += gpu
		_perf.gpu_worst = maxf(_perf.gpu_worst, gpu)
		_perf.frames += 1
		_perf.total_ms += ms
		_perf.worst_ms = maxf(_perf.worst_ms, ms)
		if ms > 25.0 or cpu > 8.0:
			_perf.spikes += 1 if ms > 25.0 else 0
			_perf.cpu_spikes += 1 if cpu > 8.0 else 0
			_perf_log.append("[perf] spike %.1fms at t=%.2f cpu=%.1fms gpu=%.1fms move=%s pipelines=%s nodes=%d" % [ms, _autotest_t, cpu, gpu,
				player._move_id, _pipelines(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		_perf.enemies = maxi(_perf.enemies, get_tree().get_nodes_in_group("enemies").size())
		_perf.draws = maxi(_perf.draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_perf.nodes = maxi(_perf.nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_perf_last_us = now
	_perf_last_frame = frame


## Pipeline compilations so far (canvas, mesh, surface, draw, specialization).
func _pipelines() -> String:
	var out: Array[String] = []
	for m in [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH, Performance.PIPELINE_COMPILATIONS_SURFACE,
			Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]:
		out.append(str(int(Performance.get_monitor(m))))
	return "/".join(out)


func _autotest_finish() -> void:
	if _quitting:
		return
	_quitting = true
	for line: String in player.bot_log + _rhythm_log:
		print(line)
	var paid: Dictionary = player.VOID_ELEMENT.improv_paid
	print("[improv] %s" % (", ".join(paid.keys().map(func(k: String) -> String: return "%s=%d" % [k, paid[k]])) if not paid.is_empty() else "none"))
	print("[autotest] done player_hp=%.0f max_combo=%d hits=%d awakening=%.0f rank=%s perfect=%d air=%d guide=%d casts=%d breakers=%d/%d perfect_breakers=%d strings=%d/%d endings=%s moves=%s" % [
		player.hp, _max_combo, _hits, Game.awakening, Game.rank(), Game.perfect_dodges, Game.best_air,
		hud.combo_guide.shown, player.ELEMENTS.casts, player.breakers_seen.size(), player.VOID_ELEMENT.BREAKERS.size(), player.breaker_perfects, _bot_strings_done.size(), BOT_STRINGS.size(),
		",".join(player.endings_seen.keys()).replace(" ", "_"), ",".join(_bot_moves.keys())])
	var n := maxi(_perf.frames, 1)
	for line in _perf_log:
		print(line)
	print("[perf] avg=%.1fms worst=%.1fms spikes(>25ms)=%d/%d cpu avg=%.1fms worst=%.1fms cpu_spikes(>8ms)=%d gpu avg=%.1fms worst=%.1fms max_enemies=%d max_draw_calls=%d max_nodes=%d" % [
		_perf.total_ms / n, _perf.worst_ms, _perf.spikes, _perf.frames, _perf.cpu_ms / n, _perf.cpu_worst, _perf.cpu_spikes,
		_perf.gpu_ms / n, _perf.gpu_worst, _perf.enemies, _perf.draws, _perf.nodes])
	var dummy: Node = main._dummy
	print("[training] strings=%d best=%.0f last=%.0f/%d dummy_hp=%.0f" % [main._strings, main._best_string,
		main._last_string.x, main._last_string.y, dummy.hp if is_instance_valid(dummy) else -1.0])
	if main._spar != null:
		main._spar.report()
	Game.stop_all_sfx()
	# Give the audio thread a moment to release playbacks, or they leak at exit.
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit()


## One `[rhythm]` line per string the bot played: real ms from each move's start to the next's (hitstop,
## buffering and hit-confirm included), so tuning has numbers. The bot presses as soon as combo_window()
## says a press would be buffered, so these are the fastest the string goes.
func _print_rhythm(string: Array) -> void:
	var gaps := []
	var beats := []  # first hit to first hit, starting from the string's first press
	for i in _bot_rhythm.size():
		var r: Array = _bot_rhythm[i]
		if i > 0:
			gaps.append("%s->%s gap=%d ms" % [_bot_rhythm[i - 1][0], r[0], r[1] - _bot_rhythm[i - 1][1]])
		if r.size() > 2:
			var from: int = _bot_rhythm[i - 1][2] if i > 0 and _bot_rhythm[i - 1].size() > 2 else _bot_rhythm[0][1]
			beats.append("%s %d" % [r[0], r[2] - from])
	_rhythm_log.append("[rhythm] %s: %s | beats %s ms" % [" ".join(string), ", ".join(gaps) if not gaps.is_empty() else "one move", ", ".join(beats)])


func _snap(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(path)
	_perf_last_us = 0  # the save stalls this frame; keep it out of the stats
	print("[autotest] screenshot ", ProjectSettings.globalize_path(path))


func _drive_bot() -> void:
	var nearest: Node3D = null
	var nd := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_to(player.global_position)
		if d < nd:
			nd = d
			nearest = e
	var dt := get_process_delta_time()
	if Engine.get_physics_frames() <= _press_frame:
		return  # a press stays down until a physics step has read it (a faster render frame dropped some)
	for a in ["attack_light", "dash", "awaken"]:
		Input.action_release(a)
	if _bot_hold_t > 0.0:  # hold right click until Overwhelm goes
		_bot_hold_t -= dt
		if player.state == player.State.CHARGE or _bot_hold_t > 0.0:
			return
	Input.action_release("attack_heavy")
	if player.state == player.State.ATTACK:
		_bot_moves[player._move_id] = true
		if player._hits_done > 0 and not _bot_rhythm.is_empty() and _bot_rhythm[-1].size() == 2:
			_bot_rhythm[-1].append(Time.get_ticks_msec())  # its first hit (the [rhythm] beats)
	if nearest == null:
		player.bot_move = Vector3.ZERO
		return
	var to := nearest.global_position - player.global_position
	to.y = 0.0
	var string: Array = BOT_STRINGS[_bot_string]
	var idle: bool = player.state == player.State.MOVE and player._post_dash_t <= 0.0
	player.bot_move = to.normalized() if nd > 2.2 and idle and _bot_step == 0 and not "line" in string else Vector3.ZERO
	if _bot_face and _bot_step > 0 and to.length() > 0.3:
		player.bot_move = to.normalized()  # (aims every press at the nearest foe; he jogs at it between them)
	if Game.awakening >= Game.AWAKEN_MAX and idle:
		Input.action_press("awaken")
	if _bot_step >= string.size():  # the string is done: let it (and any breaker) play out
		if idle:
			_bot_wait -= dt
			if _bot_wait <= 0.0:
				_print_rhythm(string)
				_bot_strings_done[_bot_string] = true
				_bot_string = (_bot_string + 1) % BOT_STRINGS.size()
				_bot_step = 0
				_bot_wait = BOT_GAP
				_reset_done = false
				_settle_t = 0.0
		return
	if _bot_pending != "":  # wait for the last press to be taken before the next one
		_bot_pending_t += dt
		var taken: bool = _bot_starts > _bot_starts_at or player.state == player.State.LEAP
		if _bot_pending == "D":
			taken = player.state == player.State.DASH or player._post_dash_t > 0.0
		if not taken and _bot_pending_t < BOT_TAKE:
			return
		_bot_pending = ""
	if _bot_step == 0 and not _reset_done:
		if not idle:
			return
		_settle_t += dt
		if not _dummies_settled() and _settle_t < BOT_SETTLE_MAX:
			return
		_reset_spots()
		_reset_done = true
		return  # (the next frame starts the string from there)
	if _bot_step == 0 and (not idle or (nd > 3.0 and not "line" in string)):
		return  # walk up first (not to a "line": the dash takes him there)
	if _bot_step == 0:
		_bot_rhythm.clear()
		player.bot_alt = "alt" in string
		player.bot_out = "out" in string
		_bot_face = "face" in string
	if string[_bot_step] in BOT_SETUP:  # (not a press: bot_alt / the line is set for the whole string)
		_bot_step += 1
		return
	if string[_bot_step] == "wait":  # (not a press: the next one waits until he stands again)
		if player.state == player.State.MOVE and player._post_dash_t <= 0.0:
			_bot_step += 1
		return
	var ready: bool = idle or player.state == player.State.DASH or player._post_dash_t > 0.0
	if player.state == player.State.ATTACK:  # (BOT_LEAD before the cancel point, so the buffered press can't lapse)
		var left: float = (player.cancel_point() - player.HERO_MOVES.progress(player)) * player._move_len / (player.anim_speed * player._anim_mult)
		ready = left <= BOT_LEAD and player._hits_done > 0  # (pressed before the hit, the hit's stop could outlast the buffer)
	var out: bool = player.bot_out and string[_bot_step] == "D" and player.state == player.State.LEAP and player._brk_phase == 0
	if (not ready or player.state == player.State.LEAP) and not out:
		return
	match string[_bot_step]:
		"L":
			Input.action_press("attack_light")
		"H":
			Input.action_press("attack_heavy")
		"D":
			Input.action_press("dash")
		"hold":
			Input.action_press("attack_heavy")
			_bot_hold_t = player.CHARGE_TIME + 0.15
	_press_frame = Engine.get_physics_frames()
	_bot_pending = string[_bot_step]
	_bot_pending_t = 0.0
	_bot_starts_at = _bot_starts
	_bot_step += 1


## The dummies are on their feet: none flying, reeling, frozen or held (BOT_SETTLE_MAX).
func _dummies_settled() -> bool:
	for d: Node in main._dummies:
		if is_instance_valid(d) and (d.state != d.State.CHASE or d.frozen_t > 0.0 or not d.is_on_floor()):
			return false
	return true


## The start of every string (BOT_SPOT): dummies home and still, the hero in front of the first one, facing it.
func _reset_spots() -> void:
	for d: Node in _homes:  # (back from a "line" string)
		if is_instance_valid(d):
			d.home = _homes[d]
	_homes.clear()
	for d: Node in main._dummies:
		if is_instance_valid(d):
			d.global_position = d.home
			d.velocity = Vector3.ZERO
	var target: Vector3 = main._dummies[0].home
	var back := _start_pos - target
	back.y = 0.0
	player.global_position = target + back.normalized() * BOT_SPOT
	player.velocity = Vector3.ZERO
	player._face(target - player.global_position)
	player.model.rotation.y = player._facing_yaw
	player.bot_move = Vector3.ZERO
	if "line" in BOT_STRINGS[_bot_string]:  # a column along his aim (homes too, or they stroll back)
		var fwd := target - player.global_position
		fwd.y = 0.0
		for i in main._dummies.size():
			var d: Node = main._dummies[i]
			if is_instance_valid(d):
				_homes[d] = d.home
				d.home = player.global_position + fwd.normalized() * (BOT_LINE_FROM + i * BOT_LINE_GAP)
				d.home.y = target.y
				d.global_position = d.home
