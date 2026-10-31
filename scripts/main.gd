extends Node3D
## Builds the arena, spawns the hero, camera and HUD, and runs enemy waves.
##
## Pass `-- --autotest` on the command line to let a bot play for a few
## seconds, print combat stats, save screenshots to user://, and quit.

const PLAYER := preload("res://scripts/player.gd")
const ENEMY := preload("res://scripts/enemy.gd")
const CAMERA := preload("res://scripts/camera_rig.gd")
const HUD := preload("res://scripts/hud.gd")
const DUNGEON := "res://assets/kaykit/dungeon/%s.glb"

const MINION := preload("res://assets/kaykit/characters/Skeleton_Minion.glb")
const WARRIOR := preload("res://assets/kaykit/characters/Skeleton_Warrior.glb")

const TILE := 4.0
const HALF_TILES := 4  # arena is (2 * HALF_TILES) tiles across
const ARENA_HALF := TILE * HALF_TILES

var player: CharacterBody3D
var hud: CanvasLayer
var wave := 0
var _alive := 0
var _between_waves := false
# Tall props that fade out when they sit between the camera and the hero.
var _occluders: Array[Node3D] = []

var _autotest := false
var _autotest_t := 0.0
var _shots_taken := 0
var _hit_shot_taken := false
var _dash_shot_taken := false
var _dash_shot_at := 0
var _max_combo := 0
var _hits := 0


func _ready() -> void:
	Game.reset()
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	_build_environment()
	_build_arena()

	player = PLAYER.new()
	add_child(player)
	player.died.connect(_on_player_died)

	var rig := CAMERA.new()
	rig.target = player
	add_child(rig)

	hud = HUD.new()
	add_child(hud)
	hud.bind_player(player)

	if _autotest:
		player.bot_enabled = true
		Game.combo_changed.connect(func(c: int, _r: String) -> void:
			_max_combo = maxi(_max_combo, c)
			if c > 0: _hits += 1)
		Game.announced.connect(func(_t: String) -> void:
			if Game.perfect_dodges == 1:
				await get_tree().create_timer(0.15, true, false, true).timeout
				_snap("user://autotest_perfect.png"))

	_next_wave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and player.is_dead():
		get_tree().reload_current_scene()


# --- Waves ------------------------------------------------------------------

func _next_wave() -> void:
	wave += 1
	_between_waves = false
	hud.set_wave(wave)
	var minions := 3 + wave
	var warriors := wave / 2
	for i in minions:
		_spawn(MINION, false)
	for i in warriors:
		_spawn(WARRIOR, true)


func _spawn(scene: PackedScene, heavy: bool) -> void:
	var e := ENEMY.new()
	e.model_scene = scene
	if heavy:
		e.max_hp = 75.0
		e.move_speed = 2.8
		e.attack_damage = 16.0
		e.attack_windup = 0.8
		e.poise = 8.0
		e.model_scale = 1.15
	add_child(e)
	# Ring around the player, clamped inside the walls.
	var ang := randf() * TAU
	var dist := randf_range(6.0, 10.0)
	var p := player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
	var lim := ARENA_HALF - 2.0
	e.global_position = Vector3(clampf(p.x, -lim, lim), 0.0, clampf(p.z, -lim, lim))
	e.died.connect(_on_enemy_died)
	_alive += 1


func _on_enemy_died(_e: Node) -> void:
	_alive -= 1
	if _alive <= 0 and not _between_waves and not player.is_dead():
		_between_waves = true
		hud.flash_message("CLEARED", 1.0)
		await get_tree().create_timer(2.0).timeout
		if not player.is_dead():
			_next_wave()


func _on_player_died() -> void:
	hud.flash_message("YOU FELL — WAVE %d\npress Enter to retry" % wave)


# --- World ------------------------------------------------------------------

func _build_environment() -> void:
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
	add_child(sun)


func _build_arena() -> void:
	# Floor visuals: big tiles with the odd grate for variety.
	for x in range(-HALF_TILES, HALF_TILES):
		for z in range(-HALF_TILES, HALF_TILES):
			var piece := "floor_tile_big_grate" if randf() < 0.08 else "floor_tile_large"
			_place(piece, Vector3((x + 0.5) * TILE, 0.0, (z + 0.5) * TILE))
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
		_place("rubble_half", Vector3((i + 0.5) * TILE, 0.0, ARENA_HALF - 0.4), randf() * 360.0)

	# Pillars to fight around.
	for p in [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(-8, 0, 7), Vector3(8, 0, 7)]:
		_occluders.append(_place("pillar_decorated", p))
		_cyl_collider(p, 0.75, 4.0)

	# Torches on the back wall, with real light.
	for x in [-10.0, -2.0, 6.0]:
		_place("torch_mounted", Vector3(x, 2.4, -ARENA_HALF + 0.5))
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


func _place(piece: String, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	var scene: PackedScene = load(DUNGEON % piece)
	var n: Node3D = scene.instantiate()
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


func _cyl_collider(pos: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position.y = height * 0.5
	body.add_child(shape)
	body.position = pos
	add_child(body)


## The camera looks down from +Z, so a prop hides the hero when it's a little
## in front (larger Z) and roughly lined up on X.
func _fade_occluders(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var hp := player.global_position
	for o in _occluders:
		var d := o.global_position - hp
		var blocking := d.z > 0.0 and d.z < 7.0 and absf(d.x) < 1.8
		var target := 0.7 if blocking else 0.0
		for mi: MeshInstance3D in o.find_children("*", "MeshInstance3D", true, false):
			mi.transparency = move_toward(mi.transparency, target, delta * 4.0)


# --- Autotest bot -----------------------------------------------------------

func _process(delta: float) -> void:
	_fade_occluders(delta)
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
		print("[autotest] at impact shot: particles=%d labels=%d since_big=%d time_scale=%.2f" % [find_children("*", "CPUParticles3D", true, false).size(), find_children("*", "Label3D", true, false).size(), since_big, Engine.time_scale])
	if _dash_shot_at == 0 and Fx.last_afterimage_ms > 0 and _autotest_t > 3.0:
		_dash_shot_at = Time.get_ticks_msec() + 110  # a few ghosts into the dash
	if not _dash_shot_taken and _dash_shot_at > 0 and Time.get_ticks_msec() >= _dash_shot_at:
		_dash_shot_taken = true
		_snap("user://autotest_dash.png")
	if _autotest_t >= 12.0:
		print("[autotest] wave=%d alive=%d player_hp=%.0f max_combo=%d hits=%d awakening=%.0f rank=%s perfect=%d" % [
			wave, _alive, player.hp, _max_combo, _hits, Game.awakening, Game.rank(), Game.perfect_dodges])
		get_tree().quit()


func _snap(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(path)
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
	Input.action_release("attack_heavy")
	Input.action_release("dash")
	Input.action_release("awaken")
	if nearest == null:
		player.bot_move = Vector3.ZERO
		return
	var to := nearest.global_position - player.global_position
	to.y = 0.0
	player.bot_move = to.normalized() if nd > 2.0 else Vector3.ZERO
	var f := Engine.get_physics_frames()
	# Try to perfect-dodge any attack that's about to land.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state == e.State.WINDUP and e._state_t >= e.attack_windup - 0.08 				and e.global_position.distance_to(player.global_position) < e.attack_range + 1.0:
			Input.action_press("dash")
			return
	if nd < 3.0:
		# Cycle through routes: L L L, L H (launch) L L, H spin.
		var step := (f / 9) % 8
		if f % 9 == 0:
			Input.action_press("attack_heavy" if step in [1, 7] else "attack_light")
	elif nd < 7.0 and f % 40 == 0:
		Input.action_press("dash")
	if Game.awakening >= Game.AWAKEN_MAX:
		Input.action_press("awaken")
