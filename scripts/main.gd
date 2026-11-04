extends Node3D
## The training room: builds the arena, spawns the hero, camera, HUD and a few
## training dummies that never fight back or die (training_dummy.gd), and
## shows each string's damage. Esc opens the training pause menu.
##
## `-- --autotest` lets a bot play the room for a few seconds, prints
## `[autotest]`, `[training]` and `[perf]` lines, saves screenshots to user://
## (windowed only) and quits. `--start-awakened` begins with a full meter.

const PLAYER := preload("res://scripts/player.gd")
const ENEMY := preload("res://scripts/enemy.gd")
const CAMERA := preload("res://scripts/camera_rig.gd")
const HUD := preload("res://scripts/hud.gd")
const BOSS := preload("res://scripts/boss.gd")
const PAUSE := preload("res://scripts/pause_menu.gd")
const DUMMY := preload("res://scripts/training_dummy.gd")
const SPAR := preload("res://scripts/spar.gd")
const WARMUP := preload("res://scripts/warmup.gd")
const DUMMY_SPOTS := [Vector3(-1.6, 0.0, -4.5), Vector3(1.6, 0.0, -4.5), Vector3(-4.2, 0.0, -3.2), Vector3(4.2, 0.0, -3.2)]  # from the hero, all in view
const ENEMY_TYPES: Dictionary = preload("res://scripts/enemy_types.gd").TYPES
const BOSS_SPEC: Dictionary = preload("res://scripts/enemy_types.gd").BOSS
const PILLARS := [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(-8, 0, 7), Vector3(8, 0, 7)]
const HINT_GAP := 7.0
const AUTOTEST_TIME := 16.0
## The autotest runs on past AUTOTEST_TIME until the bot has played every BOT_STRINGS entry once (each prints
## its `[rhythm]` line), up to AUTOTEST_MAX s.
const AUTOTEST_MAX := 40.0

const TILE := 4.0
const HALF_TILES := 4  # arena is (2 * HALF_TILES) tiles across
const ARENA_HALF := TILE * HALF_TILES

var player: CharacterBody3D
var hud: CanvasLayer
## Always true: the pause menu reads it to show the training items.
var training := true
var room_kind := "training"
var _hint_gap := 0.0  # seconds before another hint may show
var _time := 0.0
# Tall props that fade out when they sit between the camera and the hero.
var _occluders: Array[Node3D] = []
# The near-edge rubble row; fades the same way.
var _edge_rubble: Array[Node3D] = []
# Character models by name, loaded once up front: loading a .glb mid-fight hitched ~150ms.
var _models := {}

var _dummy: Node  # the first of _dummies
var _dummies := []
var _spar: Node  # one live foe with --spar=<kind> (scripts/spar.gd), else null
var _string := Vector2.ZERO  # this string's damage, hits on the dummies
var _last_string := Vector2.ZERO
var _best_string := 0.0
var _strings := 0

var _autotest := false
var _autotest_t := 0.0
var _hits := 0
var _max_combo := 0
## The bot's strings, in turn: "L" light, "H" right click, "D" dash, "hold" holds right
## click (Overwhelm). Each runs into its breaker where it has one (player presses it at
## the sweet spot for the bot), so the autotest walks every element and the dark. Frost Spear (L L H)
## only plays inside L L H L H, which sets the spear off: while it stands (5 s) any L or H press vaults onto
## it (void_element.vaults), and a lone L L H sent the next strings up the spear (Collapse and Grounded
## never played).
const BOT_STRINGS := [["L", "H"], ["L", "H", "H"], ["L", "L", "L", "H"], ["H", "H"], ["H", "L", "H"],
	["L", "H", "L", "H"], ["D", "L", "H"], ["D", "L", "H", "H"], ["D", "H"],
	["L", "L", "H", "L", "H"], ["hold"], ["L", "L", "L", "H", "H"], ["L", "L", "L"]]
const BOT_GAP := 0.35  # s standing between strings
var _bot_string := 0  # BOT_STRINGS index playing
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
var _probe: Node  # perf_probe.gd: times each frame's node work (autotest only)
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
var _collect_shaders := false  # --collect-shaders: note every material shader seen (warmup.gd)


func _ready() -> void:
	Game.reset()
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	_collect_shaders = "--collect-shaders" in OS.get_cmdline_user_args()
	if _autotest:
		Game.save_hints = false
		Game._hints_seen.clear()  # show them all, without touching the saved ones
	_build_environment()
	_build_arena()
	for spec: Dictionary in ENEMY_TYPES.values() + [BOSS_SPEC]:
		_model(spec.model)

	player = PLAYER.new()
	add_child(player)
	player.died.connect(_on_player_died)
	player.ELEMENTS.prewarm(self, player.global_position)
	WARMUP.keep_scripts()
	WARMUP.prewarm(self, player.global_position)

	var rig := CAMERA.new()
	rig.target = player
	add_child(rig)

	hud = HUD.new()
	add_child(hud)
	if Game.comic_style:
		add_child(ComicFx.new())
	hud.bind_player(player)

	add_child(PAUSE.new())
	Game.combo_changed.connect(func(c: int, _r: String) -> void:
		_max_combo = maxi(_max_combo, c)
		if c > 0:
			_hits += 1)

	for arg in OS.get_cmdline_user_args():
		if arg == "--start-awakened":
			Game.add_awakening(Game.AWAKEN_MAX)
		elif arg == "--reduce-flashing":  # the setting, without saving it
			Game.reduce_flashing = true
	if _autotest:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		_probe = preload("res://scripts/perf_probe.gd").new()
		_probe.on_frame = _sample_perf
		add_child(_probe)
		player.bot_enabled = true
		player.attack_started.connect(func(id: String) -> void:
			_bot_starts += 1
			_bot_rhythm.append([id, Time.get_ticks_msec()]))
	_start_training()


# --- Training -----------------------------------------------------------------

func _start_training() -> void:
	hud.wave_label.text = "TRAINING"  # (no big centre banner: it sat over the first strings)
	for spot: Vector3 in DUMMY_SPOTS:
		var dummy: Node = DUMMY.new()
		dummy.model_scene = _model("Skeleton_Warrior")
		dummy.set_meta("kind", "dummy")
		dummy.set_meta("title", "training dummy")
		add_child(dummy)
		dummy.home = player.global_position + spot
		dummy.global_position = dummy.home
		dummy.hit_taken.connect(_train_hit)
		_dummies.append(dummy)
	_dummy = _dummies[0]
	Game.combo_changed.connect(_train_combo)
	_train_text()
	_spar = SPAR.start(self)


func _train_hit(damage: float) -> void:
	_string += Vector2(damage, 1.0)
	_train_text()


## The combo dropped: that string is done.
func _train_combo(count: int, _rank: String) -> void:
	if count > 0 or _string.y == 0.0:
		return
	_last_string = _string
	_best_string = maxf(_best_string, _string.x)
	_strings += 1
	_string = Vector2.ZERO
	_train_text()


## "THIS STRING 120 · 6 hits    LAST 312 · 14 hits    BEST 540"
func _train_text() -> void:
	var parts: Array[String] = []
	if _string.y > 0.0:
		parts.append("THIS STRING  %d  ·  %s" % [_string.x, _hits_text(_string.y)])
	if _last_string.y > 0.0:
		parts.append("LAST  %d  ·  %s" % [_last_string.x, _hits_text(_last_string.y)])
	if _best_string > 0.0:
		parts.append("BEST  %d" % _best_string)
	hud.set_readout("      ".join(parts) if not parts.is_empty() else "Hit the dummies: each string's damage shows here  ·  Esc: moves, Fill Awakening")


func _hits_text(n: float) -> String:
	return "%d hit%s" % [n, "" if n == 1.0 else "s"]


func train_awaken() -> void:
	Game.add_awakening(Game.AWAKEN_MAX)


## Back into a fresh training room.
func restart_training() -> void:
	get_tree().reload_current_scene()


## Removes the dummies and every foe: tests that set up their own room.
func clear_room() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	_dummies.clear()
	_dummy = null


func _on_player_died() -> void:
	# Dummies never hit back; a foe from a test might. Stand him back up.
	hud.flash_message("YOU FELL", 1.4)
	await get_tree().create_timer(1.8).timeout
	restart_training()


# --- Foes -----------------------------------------------------------------------

## A foe of ENEMY_TYPES `kind`, on a ring around the player unless `at` is given.
func _spawn(kind: String, elite := false, at := Vector3.INF) -> Node:
	var e := ENEMY.new()
	var spec: Dictionary = ENEMY_TYPES[kind]
	_set_model(e, kind, spec.model)
	for key in spec:
		if key not in ["model", "title"]:
			e.set(key, spec[key])
	e.elite = elite
	e.set_meta("kind", kind)
	e.set_meta("title", spec.get("title", kind))
	add_child(e)
	if at != Vector3.INF:
		e.global_position = at
	else:
		var ang := randf() * TAU
		var p := player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * randf_range(6.0, 10.0)
		var lim := ARENA_HALF - 2.0
		e.global_position = Vector3(clampf(p.x, -lim, lim), 0.0, clampf(p.z, -lim, lim))
	return e


func _spawn_boss() -> Node:
	var b := BOSS.new()
	_set_model(b, "warden", BOSS_SPEC.model)
	for key in BOSS_SPEC:
		if key != "model":
			b.set(key, BOSS_SPEC[key])
	add_child(b)
	b.global_position = Vector3(0.0, 0.0, -9.0)
	b.summon.connect(func(count: int) -> void:
		for i in count:
			_spawn("minion"))
	hud.show_boss(b)
	return b


func _model(model_name: String) -> PackedScene:
	if not _models.has(model_name):
		_models[model_name] = load("res://assets/kaykit/characters/%s.glb" % model_name)
	return _models[model_name]


## The comic GLB when Game.comic_style is on and it exists, else the KayKit model.
func _set_model(e: Node, kind: String, kaykit: String) -> void:
	var comic := ComicLook.scene(kind)
	e.model_scene = comic if comic != null else _model(kaykit)
	e.comic_kind = kind if comic != null else ""


# --- World ------------------------------------------------------------------

func _build_environment() -> void:
	if Game.comic_style:
		ComicLook.build_environment(self)
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.8)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	# The camera is fixed and looks down, so 2 cascades cover it (each cascade
	# redraws every shadow caster).
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


func _build_arena() -> void:
	# Floor visuals: big tiles with the odd grate for variety.
	for x in range(-HALF_TILES, HALF_TILES):
		for z in range(-HALF_TILES, HALF_TILES):
			var piece := "floor_tile_big_grate" if randf() < 0.08 else "floor_tile_large"
			var tile := _place(piece, Vector3((x + 0.5) * TILE, 0.0, (z + 0.5) * TILE))
			# Flat tiles only receive shadows; casting would redraw them per cascade.
			for mi: MeshInstance3D in tile.find_children("*", "MeshInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box_collider(Vector3(0.0, -0.5, 0.0), Vector3(ARENA_HALF * 2.0, 1.0, ARENA_HALF * 2.0))

	# Walls on the back and sides; the near side stays open so the camera sees in.
	for i in range(-HALF_TILES, HALF_TILES):
		var c := (i + 0.5) * TILE
		_place("wall_broken" if randf() < 0.15 else "wall", Vector3(c, 0.0, -ARENA_HALF))
		_place("wall", Vector3(-ARENA_HALF, 0.0, c), 90.0)
		_place("wall", Vector3(ARENA_HALF, 0.0, c), -90.0)
	for side in [-1.0, 1.0]:
		_place("wall_corner", Vector3(side * ARENA_HALF, 0.0, -ARENA_HALF), 0.0 if side < 0.0 else -90.0)
	var t := 1.0
	_box_collider(Vector3(0.0, 2.0, -ARENA_HALF - t * 0.5), Vector3(ARENA_HALF * 2.0, 4.0, t))
	_box_collider(Vector3(0.0, 2.0, ARENA_HALF + t * 0.5), Vector3(ARENA_HALF * 2.0, 4.0, t))
	_box_collider(Vector3(-ARENA_HALF - t * 0.5, 2.0, 0.0), Vector3(t, 4.0, ARENA_HALF * 2.0))
	_box_collider(Vector3(ARENA_HALF + t * 0.5, 2.0, 0.0), Vector3(t, 4.0, ARENA_HALF * 2.0))

	# Low rubble line marks the open near edge.
	for i in range(-HALF_TILES, HALF_TILES):
		_edge_rubble.append(_place("rubble_half", Vector3((i + 0.5) * TILE, 0.0, ARENA_HALF - 0.4), randf() * 360.0))

	# Torches on the back wall, with real light.
	for x in [-10.0, -2.0, 6.0]:
		_place("torch_mounted", Vector3(x, 2.4, -ARENA_HALF + 0.5))
		if Game.comic_style:
			continue  # glow is drawn, not lit: the toon shader would only step its brightness
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.3)
		l.light_energy = 2.0
		l.omni_range = 9.0
		l.position = Vector3(x, 3.0, -ARENA_HALF + 1.2)
		add_child(l)
	for x in [-6.0, 2.0, 10.0]:
		_place("banner_patternA_red", Vector3(x, 0.0, -ARENA_HALF + 0.4))

	# Clutter in the corners (visual only, out of the main fighting space).
	_place("barrel_large", Vector3(-14.5, 0, -14.0))
	_place("barrel_small", Vector3(-12.8, 0, -14.6))
	_place("crates_stacked", Vector3(14.0, 0, -13.8), 20.0)
	_place("chest_gold", Vector3(13.6, 0, 12.0), -30.0)
	_place("box_large", Vector3(-14.2, 0, 12.5), 15.0)

	for p: Vector3 in PILLARS:
		var pillar := _place("pillar_decorated", p)
		pillar.add_to_group("grab_anchors")  # the void arm swings on them (void_grab.gd)
		_cyl_collider(pillar, 0.75, 4.0)
		_occluders.append(pillar)


func _place(piece: String, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	var n: Node3D = ComicLook.piece(piece)
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	add_child(n)
	return n


func _box_collider(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)


## Cylinder collider as a child of `owner_node`, so it moves with it.
func _cyl_collider(owner_node: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position.y = height * 0.5
	body.add_child(shape)
	owner_node.add_child(body)


## The camera looks down from +Z, so a prop hides the hero when it's a little
## in front (larger Z) and roughly lined up on X.
func _fade_occluders(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var hp := player.global_position
	for o: Node3D in _occluders + _edge_rubble:
		var d := o.global_position - hp
		var blocking := d.z > 0.0 and d.z < 7.0 and absf(d.x) < 1.8 + (TILE * 0.5 if o in _edge_rubble else 0.0)
		var target := 0.7 if blocking else 0.0
		for mi: MeshInstance3D in o.find_children("*", "MeshInstance3D", true, false):
			mi.transparency = move_toward(mi.transparency, target, delta * 4.0)


func _process(delta: float) -> void:
	_fade_occluders(delta)
	if not player.is_dead():
		_time += delta
		_check_hints(delta)
	if _collect_shaders:  # slow (every material's property list): dev runs only
		WARMUP.scan(self)
	if not _autotest:
		return
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


func _exit_tree() -> void:
	if _collect_shaders:  # (autotest or tests/element_shots.gd -- --collect-shaders)
		WARMUP.save()


## First-run hints (Game.HINTS), each when it first becomes relevant.
func _check_hints(delta: float) -> void:
	_hint_gap -= delta
	if _hint_gap > 0.0:
		return
	var id := ""
	if not Game.hint_seen("attack"):
		if _time > 1.5:
			id = "attack"  # always first
	elif not Game.hint_seen("awaken") and Game.awakening >= Game.AWAKEN_MAX and not player.awakened:
		id = "awaken"
	if id != "":
		Game.hint(id)
		_hint_gap = HINT_GAP


# --- Autotest bot -----------------------------------------------------------

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
	print("[autotest] done player_hp=%.0f max_combo=%d hits=%d awakening=%.0f rank=%s perfect=%d air=%d guide=%d casts=%d breakers=%d perfect_breakers=%d strings=%d/%d moves=%s" % [
		player.hp, _max_combo, _hits, Game.awakening, Game.rank(), Game.perfect_dodges, Game.best_air,
		hud.combo_guide.shown, player.ELEMENTS.casts, player.breakers_landed, player.breaker_perfects, ",".join(_bot_moves.keys())])
	var n := maxi(_perf.frames, 1)
	for line in _perf_log:
		print(line)
	print("[perf] avg=%.1fms worst=%.1fms spikes(>25ms)=%d/%d cpu avg=%.1fms worst=%.1fms cpu_spikes(>8ms)=%d gpu avg=%.1fms worst=%.1fms max_enemies=%d max_draw_calls=%d max_nodes=%d" % [
		_perf.total_ms / n, _perf.worst_ms, _perf.spikes, _perf.frames, _perf.cpu_ms / n, _perf.cpu_worst, _perf.cpu_spikes,
		_perf.gpu_ms / n, _perf.gpu_worst, _perf.enemies, _perf.draws, _perf.nodes])
	print("[training] strings=%d best=%.0f last=%.0f/%d dummy_hp=%.0f" % [_strings, _best_string,
		_last_string.x, _last_string.y, _dummy.hp if is_instance_valid(_dummy) else -1.0])
	if _spar != null:
		_spar.report()
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
	player.bot_move = to.normalized() if nd > 2.2 and idle and _bot_step == 0 else Vector3.ZERO
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
		return
	if _bot_pending != "":  # wait for the last press to be taken before the next one
		_bot_pending_t += dt
		var taken: bool = _bot_starts > _bot_starts_at or player.state == player.State.LEAP
		if _bot_pending == "D":
			taken = player.state == player.State.DASH or player._post_dash_t > 0.0
		if not taken and _bot_pending_t < BOT_TAKE:
			return
		_bot_pending = ""
	if _bot_step == 0 and (not idle or nd > 3.0):
		return  # walk up first
	if _bot_step == 0:
		_bot_rhythm.clear()
	var ready: bool = idle or player.state == player.State.DASH or player._post_dash_t > 0.0
	if player.state == player.State.ATTACK:
		ready = player.combo_window().ready
	if not ready or player.state == player.State.LEAP:
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
	_bot_pending = string[_bot_step]
	_bot_pending_t = 0.0
	_bot_starts_at = _bot_starts
	_bot_step += 1

