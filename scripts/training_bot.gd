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
const AUTOTEST_MAX := 125.0  # (was 60, then 80, then 100: 24 strings with round 4's two hand-feel cells; round 47's two
# Harpoon strings and the pause leaps off the strings that end on Harpoon ran 32 past 100)

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
## Round 49 (kit slots): each entry names the kit slot it plays (`slot`: a KitSlots.SLOTS id, or several, "step" for
## a route step) or the demoted upgrade (`upgrade`: a Kit id; it plays only with that upgrade on, `--kit=full`), and `tokens`
## the presses. `strings` is the list this run plays; the autotest's `[kit]` line counts the slots and windows
## they landed (kit_report()).
const BOT_STRINGS := [{"slot": "ender_1", "tokens": ["L", "H"]}, {"slot": "big_1", "tokens": ["L", "H", "H"]},
	{"slot": "ender_3", "tokens": ["L", "L", "L", "H"]}, {"slot": "sig_gather", "tokens": ["H", "H"]}, {"slot": "sig_drag", "tokens": ["H", "L", "H"]},
	{"slot": "air_route", "tokens": ["L", "H", "L", "H"]}, {"slot": ["dash_l", "dash_ender_l"], "tokens": ["D", "L", "H"]},
	{"slot": "step", "tokens": ["D", "L", "H", "H"]}, {"slot": "dash_h", "tokens": ["D", "H"]},
	# (L L L H H: Molten Palm shoves the dummies, Undertow pins them, Meteor Fall dives on the biggest group of them.)
	{"slot": "big_2", "tokens": ["L", "L", "H", "L", "H"]}, {"slot": "sig_pin", "tokens": ["hold"]},
	{"slot": "big_3", "tokens": ["L", "L", "L", "H", "H"]}, {"slot": "light_string", "tokens": ["L", "L", "L"]},
	# Crossovers (round 34): Rockslide into Fault Line and Cataclysm, Steam Burst into Flash Freeze, Storm Pitch,
	# and Black Ice ("alt": the window's press is L, Maw's other ending).
	{"slot": "cross_storm_magma", "tokens": ["L", "H", "L", "L", "H"]}, {"slot": "cross_ice_magma", "tokens": ["D", "L", "H", "H", "L"]},
	{"upgrade": "storm_pitch", "tokens": ["D", "H", "L"]}, {"slot": "sig_drag", "tokens": ["alt", "H", "L", "H"]},
	# Three elements a string (second pass): Hailstorm, Meltdown and Eruption in the air; the spear, Impale, Backdraft
	# and Anvil (Backdraft blows the spear apart, so it doesn't send the next string up it).
	# ("line": the dummies stand in a column along his aim for it, so Harpoon reels in all four and Hailstorm has
	# every cube to lift: from the fan Dash Stab lunged into the first and Harpoon only ever took that one.)
	{"slot": "cross_ice_storm", "tokens": ["line", "D", "L", "H", "H", "H", "L"]}, {"slot": ["dash_ender_h", "cross_dark_ice"], "tokens": ["L", "L", "H", "D", "H", "H", "L"]},
	# The element matrix (third pass, void_element.IMPROV): a dash and a base move of another element on a state.
	# Harpoon's ice, then Tow Line's dark shatters it (frozen x dark); Rockslide's buried, then Harpoon freezes them in
	# the floor (buried x ice); Updraft Lash's air, then Harpoon freezes them up there (airborne x ice).
	# ("face": he aims at the nearest foe for the string, as a player would. The payoff follows the move's own hit
	# shape (void_element.improv_reach), and the dash and Dash Stab's lunge leave the buried behind him.)
	{"slot": "dash_h", "tokens": ["line", "D", "L", "H", "D", "H"]},
	{"slot": "dash_ender_l", "tokens": ["face", "L", "H", "L", "L", "D", "L", "H"]},
	{"slot": "dash_ender_l", "tokens": ["face", "L", "H", "D", "L", "H"]},
	# Round 4: the two cells only a hand could reach. "out" lets him dash out of a breaker's hang (the bot never
	# does otherwise), "wait" holds the next press until he stands again (so L is L1, not Dash Stab).
	# Meltdown's molten, then Updraft Lash fans the flames (molten x storm); Undertow's bind, then Updraft Lash tears
	# them loose (bound x storm).
	{"slot": "ender_1", "tokens": ["line", "out", "face", "D", "L", "H", "H", "H", "L", "D", "wait", "L", "H"]},
	{"slot": "ender_1", "tokens": ["out", "face", "L", "L", "L", "H", "H", "D", "wait", "L", "H"]},
	# Round 44: Galvanize, a tentacle on everyone Reap marked and the current down them ("spread": the dummies stand
	# apart in a wide arc ahead, the crowd it is for).
	{"slot": "cross_dark_storm", "tokens": ["spread", "H", "L", "L"]},
	# Galvanize charges the spread crowd, and Updraft Lash discharges them all at once (charged x storm: Overload).
	{"slot": "cross_dark_storm", "tokens": ["spread", "H", "L", "L", "wait", "L", "H"]},
	# Round 44 b: Short Circuit, Grounded's L ending ("spread": some stand past the tentacles, where the arcs go).
	{"slot": "big_1", "tokens": ["spread", "far", "alt", "L", "H", "H"]},
	# Round 47: Harpoon's tentacles take everyone round him ("ring": one ahead, one each side, one behind, none on his
	# aim line) and the pause leaps into the window: Shatterstorm (RMB), then Slapshot (LMB) with the back wall ahead
	# ("wall": the ring BOT_WALL_GAP m from the wall, facing it), the cubes punched into it.
	{"slot": "dash_ender_l", "tokens": ["ring", "D", "L", "H"]}, {"slot": "dash_ender_l", "tokens": ["wall", "alt", "D", "L", "H"]},
	# Breaker pairs: Meteor Shower (Meteor Fall's LMB) on a spread crowd the palm scatters, a fireball each; Pinwheel
	# (Anvil's LMB) by the back wall, the kebab whirled and hurled into it.
	{"slot": "big_3", "tokens": ["spread", "alt", "L", "L", "L", "H", "H"]}, {"slot": "cross_dark_ice", "tokens": ["wall", "alt", "L", "L", "H", "D", "H", "H", "L"]},
	# (Cold Front, Worldbreaker's LMB, had no string: endings_n= counts every ending a window offers.)
	{"slot": "air_route", "tokens": ["alt", "L", "H", "L", "H"]},
	# Tempest (Cataclysm's LMB): Rockslide, Fault Line and the twister on the four dummies.
	{"slot": "cross_storm_magma", "tokens": ["alt", "L", "H", "L", "L", "H"]},
	# The other charged cells off Galvanize, in real moves: Reap (Conduct), Molten Palm (Arc Flash), Frost Spear (Superconduct;
	# last: its spear stands 5 s and turns the next string's L L into the vault).
	{"slot": "sig_mark", "tokens": ["spread", "H", "L", "L", "wait", "H", "L"]},
	{"slot": "ender_3", "tokens": ["spread", "H", "L", "L", "wait", "L", "L", "L", "H"]},
	{"slot": "ender_2", "tokens": ["spread", "H", "L", "L", "wait", "L", "L", "H"]},
	# The dash counter (kit slot 9, counter.gd): "counter" has the first dummy swing at him (training_dummy.swings) and
	# holds his D until its strike is inside the perfect counter's last PERFECT s: Backlash, then Ricochet in the window.
	{"slot": "counter", "tokens": ["counter", "D"]}]
## Tokens that aren't presses (each sets something up for the whole string).
const BOT_SETUP := ["alt", "line", "out", "face", "spread", "far", "ring", "wall", "counter"]
## Layout tokens: the dummies are stood somewhere for the string (and he doesn't walk up to them first).
const BOT_LAYOUTS := ["line", "spread", "ring", "wall"]
## A "ring" string's dummies, from where he starts (x across his aim, z along it): one ahead for Dash Stab, the others
## off his line round where the dash leaves him (~1.7 m on), one behind. A "wall" string starts BOT_WALL_GAP m from the
## back wall (up the screen), facing it, with the same ring.
const BOT_RING := [Vector3(0.0, 0.0, 4.5), Vector3(-3.4, 0.0, 2.4), Vector3(3.0, 0.0, 0.4), Vector3(0.8, 0.0, -1.8)]
const BOT_WALL_GAP := 10.5
## With "far", a "spread" string's last dummy stands this far out instead: past the tentacles (void_grab.SEIZE_RANGE).
const BOT_FAR_R := 10.0
## A "spread" string's dummies stand on an arc BOT_SPREAD_R m ahead of him, BOT_SPREAD_ARC radians either side of his aim.
const BOT_SPREAD_R := 4.6
const BOT_SPREAD_ARC := 0.8
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
var _bot_strings_done := {}  # strings index -> played (autotest `strings=`)
var _bot_landed := {}  # every move id that connected while the bot played (the `[kit]` line)
## This run's strings (BOT_STRINGS' tokens), without the upgrade strings whose Kit upgrade is off, and their labels.
var strings: Array = active().map(func(b: Dictionary) -> Array: return b.tokens)
var string_labels: Array = active()
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
	if _autotest_t >= AUTOTEST_MAX or (_autotest_t >= AUTOTEST_TIME and _bot_strings_done.size() >= strings.size()):
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


## `[improv]`: the payoffs paid this run, per state rule (void_element.RULES, every one, 0 too) and per upgrade cell
## whose Kit id is on (`--kit=full`: all of them), e.g. `[improv] frozen=2 charged=3 ... | overload=1 conduct=0 ...`.
static func improv_line(el: GDScript) -> String:
	var paid: Dictionary = el.improv_paid
	var rules: Array = el.RULES.keys().map(func(k: String) -> String: return "%s=%d" % [k, int(paid.get(k, 0))])
	var cells: Array = el.IMPROV_UPGRADE.keys().filter(func(c: String) -> bool: return Kit.has(el.IMPROV_UPGRADE[c])).map(
		func(c: String) -> String: return "%s=%d" % [el.IMPROV_UPGRADE[c], int(paid.get(c, 0))])
	return "[improv] %s%s" % [" ".join(rules), (" | " + " ".join(cells)) if not cells.is_empty() else ""]


func _autotest_finish() -> void:
	if _quitting:
		return
	_quitting = true
	for line: String in player.bot_log + _rhythm_log:
		print(line)
	print(improv_line(player.VOID_ELEMENT))
	print("[autotest] done player_hp=%.0f max_combo=%d hits=%d awakening=%.0f rank=%s perfect=%d air=%d guide=%d casts=%d breakers=%d/%d perfect_breakers=%d strings=%d/%d endings_n=%d/%d endings=%s moves=%s" % [
		player.hp, _max_combo, _hits, Game.awakening, Game.rank(), Game.perfect_dodges, Game.best_air,
		hud.combo_guide.shown, player.ELEMENTS.casts, player.breakers_seen.size(), player.VOID_ELEMENT.BREAKERS.size(), player.breaker_perfects, _bot_strings_done.size(), strings.size(),
		player.endings_seen.size(), _all_endings().size(), ",".join(player.endings_seen.keys()).replace(" ", "_"), ",".join(_bot_moves.keys())])
	var kit := kit_report()
	print("[kit] slots=%d/%d windows=%d/%d upgrades=%d/%d missing=%s" % [kit.slots, kit.slots_n, kit.windows, kit.windows_n,
		kit.upgrades, kit.upgrades_n, ",".join(kit.missing) if not kit.missing.is_empty() else "none"])
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
	print("[counter] counters=%d perfect=%d ricochet=%s" % [player.counters, player.counter_perfects, player.COUNTER.last_ricochet])
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
	if player._connected and (player.state == player.State.ATTACK or player.state == player.State.LEAP):
		_bot_landed[player._move_id] = true  # (a breaker's ender: its leap can start the frame after the hit)
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
	var string: Array = strings[_bot_string]
	var idle: bool = player.state == player.State.MOVE and player._post_dash_t <= 0.0
	player.bot_move = to.normalized() if nd > 2.2 and idle and _bot_step == 0 and not _placed(string) else Vector3.ZERO
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
				_swing(false)
				_bot_string = (_bot_string + 1) % strings.size()
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
	if _bot_step == 0 and (not idle or (nd > 3.0 and not _placed(string))):
		return  # walk up first (not to a "line": the dash takes him there)
	if _bot_step == 0:
		_bot_rhythm.clear()
		_swing("counter" in string)
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
	if string[_bot_step] == "D" and "counter" in string:  # (held until the swing is inside the perfect counter)
		var c: Dictionary = player.COUNTER.find(player, player._facing())
		if c.is_empty() or not c.perfect:
			return
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


## A "counter" string has the first dummy swing at him (training_dummy.swings); every other string, none.
func _swing(on: bool) -> void:
	for i in main._dummies.size():
		var d: Node = main._dummies[i]
		if is_instance_valid(d) and "swings" in d:
			d.swings = on and i == 0


static func _placed(string: Array) -> bool:
	return BOT_LAYOUTS.any(func(t: String) -> bool: return t in string)


## The dummies are on their feet: none flying, reeling, frozen or held (BOT_SETTLE_MAX).
func _dummies_settled() -> bool:
	for d: Node in main._dummies:
		if is_instance_valid(d) and (d.state != d.State.CHASE or d.frozen_t > 0.0 or not d.is_on_floor()):
			return false
	return true


## The start of every string (BOT_SPOT): dummies home and still, the hero in front of the first one, facing it.
## Every ending a breaker window offers (each BREAKERS entry's name and its `alt`'s): the autotest's `endings_n=`.
func _all_endings() -> Array:
	var names := []
	for id: String in player.VOID_ELEMENT.BREAKERS:
		var b: Dictionary = player.VOID_ELEMENT.BREAKERS[id]
		names.append(b.names.spirit)
		if b.has("alt"):
			names.append(b.alt.names.spirit)
	return names


## BOT_STRINGS entries this run plays: an `upgrade` string only with its Kit upgrade on.
static func active() -> Array:
	return BOT_STRINGS.filter(func(b: Dictionary) -> bool: return not b.has("upgrade") or Kit.has(b.upgrade))


## A BOT_STRINGS entry's labels: its slot id(s), or its upgrade.
static func labels_of(b: Dictionary) -> Array:
	if b.has("upgrade"):
		return [b.upgrade]
	return b.slot if b.slot is Array else [b.slot]


## The `[kit]` line (kit-grammar.md section 7): a slot lands when a string labelled with it played and every move
## filling it connected; a window when one of its endings landed; an upgrade (on this run) when its moves connected.
## Pending slots (no move yet) and the meter (Awakening) aren't counted. `missing` names what didn't land.
func kit_report() -> Dictionary:
	var card: Dictionary = KitSlots.of(Game.hero)
	var r := {"slots": 0, "slots_n": 0, "windows": 0, "windows_n": 0, "upgrades": 0, "upgrades_n": 0, "missing": []}
	var labelled := {}
	for i: int in _bot_strings_done:
		for l: String in labels_of(string_labels[i]):
			labelled[l] = true
	var breakers: Dictionary = player.VOID_ELEMENT.BREAKERS
	for s: Dictionary in KitSlots.SLOTS:
		var fill: Dictionary = card.fill.get(s.id, {})
		if fill.is_empty():
			continue
		r.slots_n += 1
		var landed := func(id: String) -> bool: return _bot_landed.has(id)
		if not s.get("routed", true):  # (the counter: no move id; it lands when its window's ending does)
			landed = func(id: String) -> bool: return breakers.has(id) and player.endings_seen.has(breakers[id].names.spirit)
		if labelled.has(s.id) and fill.keys().all(landed):
			r.slots += 1
		else:
			r.missing.append(s.id)
		for id: String in fill:
			if not breakers.has(id):
				continue
			r.windows_n += 1
			var b: Dictionary = breakers[id]
			var names: Array = [b.names.spirit] + ([b.alt.names.spirit] if b.has("alt") else [])
			if names.any(func(nm: String) -> bool: return player.endings_seen.has(nm)):
				r.windows += 1
			else:
				r.missing.append(id + "_window")
	for u: String in card.upgrades:
		if not Kit.has(u):
			continue
		r.upgrades_n += 1
		if labelled.has(u) and card.upgrades[u].moves.keys().all(func(id: String) -> bool: return _bot_landed.has(id)):
			r.upgrades += 1
		else:
			r.missing.append(u)
	return r


func _reset_spots() -> void:
	for d: Node in _homes:  # (back from a "line" string)
		if is_instance_valid(d):
			d.home = _homes[d]
	_homes.clear()
	for d: Node in main._dummies:
		if is_instance_valid(d):
			d.global_position = d.home
			d.velocity = Vector3.ZERO
			if d.has_meta("x_charged"):
				d.remove_meta("x_charged")  # (nearly every string charges them: each starts clean, or it pays the last's)
	var target: Vector3 = main._dummies[0].home
	var back := _start_pos - target
	back.y = 0.0
	player.global_position = target + back.normalized() * BOT_SPOT
	player.velocity = Vector3.ZERO
	player._face(target - player.global_position)
	player.model.rotation.y = player._facing_yaw
	player.bot_move = Vector3.ZERO
	if "line" in strings[_bot_string]:  # a column along his aim (homes too, or they stroll back)
		var fwd := target - player.global_position
		fwd.y = 0.0
		for i in main._dummies.size():
			var d: Node = main._dummies[i]
			if is_instance_valid(d):
				_homes[d] = d.home
				d.home = player.global_position + fwd.normalized() * (BOT_LINE_FROM + i * BOT_LINE_GAP)
				d.home.y = target.y
				d.global_position = d.home
	var ring: bool = "ring" in strings[_bot_string] or "wall" in strings[_bot_string]
	if "wall" in strings[_bot_string]:  # BOT_WALL_GAP from the back wall, facing it
		player.global_position = Vector3(0.0, player.global_position.y, -main.ARENA_HALF + BOT_WALL_GAP)
		player._face(Vector3(0.0, 0.0, -1.0))
		player.model.rotation.y = player._facing_yaw
	if ring:  # round him, off his aim line (homes too)
		var fwd: Vector3 = player._facing()
		var side := fwd.cross(Vector3.UP).normalized()
		for i in main._dummies.size():
			var d: Node = main._dummies[i]
			if is_instance_valid(d):
				_homes[d] = d.home
				var o: Vector3 = BOT_RING[i % BOT_RING.size()]
				d.home = player.global_position + side * o.x + fwd * o.z
				d.home.y = target.y
				d.global_position = d.home
	if "spread" in strings[_bot_string]:  # apart on a wide arc ahead (homes too)
		var fwd := target - player.global_position
		fwd.y = 0.0
		var n: int = main._dummies.size()
		for i in n:
			var d: Node = main._dummies[i]
			if is_instance_valid(d):
				_homes[d] = d.home
				var a: float = lerpf(-BOT_SPREAD_ARC, BOT_SPREAD_ARC, float(i) / maxf(n - 1, 1))
				var r: float = BOT_FAR_R if "far" in strings[_bot_string] and i == n - 1 else BOT_SPREAD_R
				d.home = player.global_position + fwd.normalized().rotated(Vector3.UP, a) * r
				d.home.y = target.y
				d.global_position = d.home
