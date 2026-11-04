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
const REWARD := preload("res://scripts/reward_screen.gd")
const BOSS := preload("res://scripts/boss.gd")
const PAUSE := preload("res://scripts/pause_menu.gd")
const ASCEND_MENU := preload("res://scripts/ascend_menu.gd")
const DUMMY := preload("res://scripts/training_dummy.gd")
const DUMMY_SPOTS := [Vector3(-1.6, 0.0, -4.5), Vector3(1.6, 0.0, -4.5), Vector3(-4.2, 0.0, -3.2), Vector3(4.2, 0.0, -3.2)]  # from the hero, all in view
const ENEMY_TYPES: Dictionary = preload("res://scripts/enemy_types.gd").TYPES
const BOSS_SPEC: Dictionary = preload("res://scripts/enemy_types.gd").BOSS
const PILLARS := [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(-8, 0, 7), Vector3(8, 0, 7)]
const HINT_GAP := 7.0
const AUTOTEST_TIME := 16.0

const TILE := 4.0
const HALF_TILES := 4  # arena is (2 * HALF_TILES) tiles across
const ARENA_HALF := TILE * HALF_TILES

var player: CharacterBody3D
var hud: CanvasLayer
var reward: CanvasLayer
var ascend_menu: CanvasLayer
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
var _string := Vector2.ZERO  # this string's damage, hits on the dummies
var _last_string := Vector2.ZERO
var _best_string := 0.0
var _strings := 0

var _autotest := false
var _autotest_t := 0.0
var _hits := 0
var _max_combo := 0
var _bot_charge_t := 0.0  # bot is holding heavy to charge while > 0
var _bot_next_charge := 3.0
var _bot_next_spin := 2.0  # when the bot next spins from neutral (Whirlwind)
var _bot_moves := {}  # every move id the bot started (autotest `moves=`)
# Autotest frame stats (real time, so hitstop slow-mo doesn't skew them).
var _perf := {"frames": 0, "total_ms": 0.0, "worst_ms": 0.0, "spikes": 0, "enemies": 0, "draws": 0, "nodes": 0}
var _perf_last_us := 0
var _perf_last_frame := 0
var _shots_taken := 0
var _hit_shot_taken := false
var _dash_shot_taken := false
var _dash_shot_at := 0
var _guide_shot_taken := false
var _cast_shot_taken := false
var _quitting := false


func _ready() -> void:
	Game.reset()
	Game.sync_comic()
	_autotest = "--autotest" in OS.get_cmdline_user_args()
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

	var rig := CAMERA.new()
	rig.target = player
	add_child(rig)

	hud = HUD.new()
	add_child(hud)
	if Game.comic_style:
		add_child(ComicFx.new())
	hud.bind_player(player)

	reward = REWARD.new()
	add_child(reward)
	reward.reroll_pressed.connect(func() -> void:
		reward.open(Upgrades.roll(player.upgrades, 3, false), 0, "TRAINING · PICK A POWER"))
	add_child(PAUSE.new())
	ascend_menu = ASCEND_MENU.new()
	add_child(ascend_menu)
	Game.combo_changed.connect(func(c: int, _r: String) -> void:
		_max_combo = maxi(_max_combo, c)
		if c > 0:
			_hits += 1)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ascend="):  # start ascended
			var path := arg.get_slice("=", 1)
			if Ascendancy.PATHS.has(path):
				Game.add_xp(Game.LEVEL_XP[-1] - Game.xp)
				player.ascend(path)
		elif arg == "--start-awakened":
			Game.add_awakening(Game.AWAKEN_MAX)
		elif arg == "--reduce-flashing":  # the setting, without saving it
			Game.reduce_flashing = true
	if _autotest:
		player.bot_enabled = true
	_start_training()


# --- Training -----------------------------------------------------------------

func _start_training() -> void:
	hud.wave_label.text = "TRAINING"
	hud.flash_message("TRAINING\nEsc: powers, Awakening, Ascendancy", 2.0)
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
	hud.set_trial("      ".join(parts) if not parts.is_empty() else "Hit the dummies: each string's damage shows here")


func _hits_text(n: float) -> String:
	return "%d hit%s" % [n, "" if n == 1.0 else "s"]


## Pause menu → Pick a power: three cards, rerolls free.
func train_power() -> void:
	var choices := Upgrades.roll(player.upgrades, 3, false)
	if choices.is_empty():
		hud.flash_message("EVERY POWER MAXED", 1.2)
		return
	reward.open(choices, 0, "TRAINING · PICK A POWER")
	var id: String = await reward.picked
	player.add_upgrade(id)
	hud.set_upgrades(player.upgrades)
	hud.flash_message((Upgrades.get_by_id(id).name + Upgrades.level_tag(player.upgrades[id])).to_upper(), 1.0)
	Game.sfx("perfect", -4.0, 0.0)


func train_awaken() -> void:
	Game.add_awakening(Game.AWAKEN_MAX)


func train_ascend() -> void:
	Game.add_xp(Game.LEVEL_XP[-1] - Game.xp)
	ascend_menu.open()
	var path: String = await ascend_menu.chosen
	player.ascend(path)


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
	if not _autotest:
		return
	_autotest_t += delta
	_sample_perf()
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
	if _autotest_t >= AUTOTEST_TIME:
		_autotest_finish()


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

func _sample_perf() -> void:
	var now := Time.get_ticks_usec()
	var frame := Engine.get_process_frames()
	# Skip gaps from paused menus and screenshot saves (not gameplay frames).
	if _perf_last_us > 0 and frame == _perf_last_frame + 1 and _autotest_t > 1.0:
		var ms := (now - _perf_last_us) / 1000.0
		_perf.frames += 1
		_perf.total_ms += ms
		_perf.worst_ms = maxf(_perf.worst_ms, ms)
		if ms > 25.0:
			_perf.spikes += 1
			print("[perf] spike %.1fms at t=%.2f enemies=%d" % [ms, _autotest_t, get_tree().get_nodes_in_group("enemies").size()])
		_perf.enemies = maxi(_perf.enemies, get_tree().get_nodes_in_group("enemies").size())
		_perf.draws = maxi(_perf.draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_perf.nodes = maxi(_perf.nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_perf_last_us = now
	_perf_last_frame = frame


func _autotest_finish() -> void:
	if _quitting:
		return
	_quitting = true
	print("[autotest] done player_hp=%.0f max_combo=%d hits=%d awakening=%.0f rank=%s perfect=%d air=%d guide=%d casts=%d chain=%d breakers=%d moves=%s" % [
		player.hp, _max_combo, _hits, Game.awakening, Game.rank(), Game.perfect_dodges, Game.best_air,
		hud.combo_guide.shown, player.ELEMENTS.casts, player.max_chain, player.ground_breakers, ",".join(_bot_moves.keys())])
	print("[perf] avg=%.1fms worst=%.1fms spikes(>25ms)=%d/%d max_enemies=%d max_draw_calls=%d max_nodes=%d" % [
		_perf.total_ms / maxi(_perf.frames, 1), _perf.worst_ms, _perf.spikes, _perf.frames, _perf.enemies, _perf.draws, _perf.nodes])
	print("[training] strings=%d best=%.0f last=%.0f/%d dummy_hp=%.0f" % [_strings, _best_string,
		_last_string.x, _last_string.y, _dummy.hp if is_instance_valid(_dummy) else -1.0])
	Game.stop_all_sfx()
	# Give the audio thread a moment to release playbacks, or they leak at exit.
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit()


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
	Input.action_release("attack_light")
	if _bot_charge_t > 0.0:
		_bot_charge_t -= get_process_delta_time()
		if nearest != null:
			player.bot_move = (nearest.global_position - player.global_position).normalized()
		# Knocked out of the charge: let go and try again soon.
		if player.state != player.State.CHARGE and _bot_charge_t < player.CHARGE_TIME:
			_bot_charge_t = 0.0
			_bot_next_charge = _autotest_t + 1.5
		return  # keep holding heavy (and nothing else) until the charge releases
	Input.action_release("attack_heavy")
	Input.action_release("dash")
	Input.action_release("awaken")
	if player.state == player.State.ATTACK or player.state == player.State.ULT:
		_bot_moves[player._move_id] = true
	if nearest == null:
		player.bot_move = Vector3.ZERO
		return
	var to := nearest.global_position - player.global_position
	to.y = 0.0
	player.bot_move = to.normalized() if nd > 2.0 else Vector3.ZERO
	var f := Engine.get_physics_frames()
	# The pause and dash routes: light again once L2 has finished (Flurry),
	# heavy just out of a dash near a foe (Whirlwind). On a flurry turn the
	# bot lets L2 play out instead of chaining it.
	if not player.awakened and int(_autotest_t / 2.0) % 2 == 1 and player.state == player.State.ATTACK \
			and player._move_id == "L2":
		return
	if not player.awakened and nd < 4.5 and player.state == player.State.MOVE and player._move_id == "L2" \
			and player._chain_i == 2 and player._chain_reset_t > 0.0 and player._chain_reset_t < 0.28:
		Input.action_press("attack_light")
		return
	if not player.awakened and nd < 4.5 and player._post_dash_t > 0.0 and player.state == player.State.MOVE:
		Input.action_press("attack_heavy")
		return
	# Now and then, from neutral, hold heavy for a charged slam.
	if nd > 2.8 and nd < 6.0 and player.state == player.State.MOVE and not player.awakened and _autotest_t >= _bot_next_charge:
		Input.action_press("attack_heavy")
		_bot_charge_t = player.CHARGE_TIME + 0.15
		_bot_next_charge = _autotest_t + 5.0
		return
	if not player.awakened and player.state == player.State.ATTACK and player._move_id == "LH" and f % 9 == 0 \
			and int(_autotest_t / 2.0) % 2 == 0:
		Input.action_press("attack_heavy")  # L H H: spike the juggled foe
		return
	if nd < 3.0:
		# Now and then a Spin from neutral: hold off until the string resets, then heavy.
		if not player.awakened and _autotest_t >= _bot_next_spin and player.state == player.State.MOVE:
			if player._chain_i == 0 and player._post_dash_t <= 0.0:
				Input.action_press("attack_heavy")
				_bot_next_spin = _autotest_t + 4.0
			return
		# Cycle through routes: L H (launch), L L H (ground breaker), L L L.
		var step := (f / 9) % 8
		var heavy: bool = step in [1, 4]
		if f % 9 == 0:
			Input.action_press("attack_heavy" if heavy else "attack_light")
	elif nd < 7.0 and f % 40 == 0:
		Input.action_press("dash")
	if Game.awakening >= Game.AWAKEN_MAX:
		Input.action_press("awaken")
