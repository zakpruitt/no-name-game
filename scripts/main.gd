extends Node3D
## Builds the arena, spawns the hero, camera and HUD, and runs a roguelike
## run: a fixed sequence of rooms (RUN_PLAN) ending in a boss, then a summary.
##
## Pass `-- --autotest` on the command line to let a bot play for a few
## seconds, print combat stats, save screenshots to user://, and quit.
## Add `--all-upgrades` to start with every upgrade (exercises all effects)
## `--start-room=N` to begin at a later room, and `--start-awakened` to begin
## with a full Awakening meter.

const PLAYER := preload("res://scripts/player.gd")
const ENEMY := preload("res://scripts/enemy.gd")
const CAMERA := preload("res://scripts/camera_rig.gd")
const HUD := preload("res://scripts/hud.gd")
const REWARD := preload("res://scripts/reward_screen.gd")
const BOSS := preload("res://scripts/boss.gd")
const SUMMARY := preload("res://scripts/run_summary.gd")
const TITLE := preload("res://scripts/title_screen.gd")
const PAUSE := preload("res://scripts/pause_menu.gd")
const SPIKES := preload("res://scripts/spike_trap.gd")
const DUNGEON := "res://assets/kaykit/dungeon/%s.glb"

# Enemy types: model + overrides for enemy.gd's exported stats. Tune here.
const ENEMY_TYPES := {
	"minion": {"model": "Skeleton_Minion"},
	"warrior": {"model": "Skeleton_Warrior", "max_hp": 75.0, "move_speed": 2.8, "attack_damage": 16.0,
		"attack_windup": 0.8, "poise": 8.0, "model_scale": 1.15},
	"mage": {"model": "Skeleton_Mage", "max_hp": 24.0, "move_speed": 3.0, "attack_kind": "ranged",
		"attack_range": 10.0, "preferred_range": 7.0, "attack_damage": 12.0, "attack_windup": 0.9,
		"attack_recover": 0.5, "projectile_speed": 9.0},
	"rogue": {"model": "Skeleton_Rogue", "max_hp": 28.0, "move_speed": 5.4, "attack_damage": 8.0,
		"attack_windup": 0.45, "attack_recover": 0.5, "flank": true, "dodge_chance": 0.5, "run_anim": "Running_C"},
	"shield": {"model": "Skeleton_Minion", "max_hp": 40.0, "move_speed": 3.2, "attack_damage": 12.0,
		"attack_windup": 0.7, "shield": true, "model_scale": 1.05, "run_anim": "Walking_D_Skeletons"},
}
# A run is a fixed sequence of rooms; clearing one (except the boss) offers
# an upgrade. Room n's difficulty is its position in the run.
#   fight  regular enemy mix (wave_composition)
#   elite  the same mix with several elites (elite_count)
#   boss   the Bone Warden and a small escort; beating it wins the run
# Fraction of max HP restored when a room (other than the boss) is cleared.
const ROOM_CLEAR_HEAL := 0.25
const RUN_PLAN := ["fight", "fight", "fight", "elite", "fight", "fight", "elite", "boss"]
# Arena layouts: pillar spots and spike-trap tiles (spikes must sit on tile
# centres: ±2, ±6, ±10, ±14). ROOM_LAYOUTS picks one per room of RUN_PLAN;
# pillars sink/rise when the layout changes between rooms.
const LAYOUTS := [
	{"name": "hall", "pillars": [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(-8, 0, 7), Vector3(8, 0, 7)],
		"spikes": []},
	{"name": "crossroads", "pillars": [Vector3(-6, 0, -6), Vector3(6, 0, -6), Vector3(-6, 0, 6), Vector3(6, 0, 6)],
		"spikes": [Vector3(-2, 0, -2), Vector3(2, 0, 2)]},
	{"name": "gauntlet", "pillars": [Vector3(0, 0, -9), Vector3(-11, 0, -1), Vector3(11, 0, -1)],
		"spikes": [Vector3(-6, 0, 2), Vector3(6, 0, -2), Vector3(2, 0, 10)]},
]
const ROOM_LAYOUTS := [0, 0, 0, 1, 2, 1, 2, 0]
# Boss stats (attack timings live in boss.gd's ATTACKS table).
const BOSS_SPEC := {"model": "Skeleton_Warrior", "max_hp": 700.0, "move_speed": 3.0, "model_scale": 1.8,
	"hit_freeze": 0.03, "run_anim": "Walking_D_Skeletons"}
const BOSS_ESCORT := {"minion": 2, "mage": 1}

## How many of each type room n spawns.
static func wave_composition(n: int) -> Dictionary:
	return {"minion": 4, "warrior": n / 2, "mage": n / 2, "rogue": (n + 1) / 3, "shield": (n - 1) / 2}


## How many of an elite room's enemies are promoted to elites (never mages).
static func elite_count(n: int) -> int:
	return 2 + n / 4

const TILE := 4.0
const HALF_TILES := 4  # arena is (2 * HALF_TILES) tiles across
const ARENA_HALF := TILE * HALF_TILES

var player: CharacterBody3D
var hud: CanvasLayer
var reward: CanvasLayer
var summary: CanvasLayer
var room := 0
var _alive := 0
var _between_rooms := false
var _run_over := false
# Run stats for the summary screen.
var _run_time := 0.0
var _kills := 0
var _max_combo := 0
var _best_rank := "D"
# Tall props that fade out when they sit between the camera and the hero.
var _occluders: Array[Node3D] = []
var _traps: Array[Node3D] = []
var _layout := -1

var _autotest := false
var _autotest_t := 0.0
var _shots_taken := 0
var _hit_shot_taken := false
var _dash_shot_taken := false
var _dash_shot_at := 0
var _finisher_shot_taken := false
var _quitting := false
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

	reward = REWARD.new()
	add_child(reward)
	summary = SUMMARY.new()
	add_child(summary)
	add_child(PAUSE.new())
	Game.combo_changed.connect(_track_combo)

	if "--start-awakened" in OS.get_cmdline_user_args():
		Game.add_awakening(Game.AWAKEN_MAX)
	if "--all-upgrades" in OS.get_cmdline_user_args():
		for u in Upgrades.ALL:
			player.add_upgrade(u.id)
		hud.set_upgrades(player.upgrades)

	if _autotest:
		player.bot_enabled = true
		Game.combo_changed.connect(func(c: int, _r: String) -> void:
			if c > 0: _hits += 1)
		Game.air_combo_changed.connect(func(c: int) -> void:
			if c == 3 and Game.best_air == 3:
				await get_tree().create_timer(0.1, true, false, true).timeout
				_snap("user://autotest_air.png"))
		Game.announced.connect(func(_t: String) -> void:
			if Game.perfect_dodges == 1:
				await get_tree().create_timer(0.15, true, false, true).timeout
				_snap("user://autotest_perfect.png"))

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start-room="):
			room = clampi(arg.get_slice("=", 1).to_int() - 1, 0, RUN_PLAN.size() - 1)
	if not _autotest and not Game.skip_title:
		var title := TITLE.new()
		add_child(title)
		hud.visible = false
		title.open()
		await title.started
		title.queue_free()
		hud.visible = true
	Game.skip_title = false
	_next_room()


# --- Rooms ------------------------------------------------------------------

func _next_room() -> void:
	room += 1
	_between_rooms = false
	var room_kind: String = RUN_PLAN[room - 1]
	_apply_layout(ROOM_LAYOUTS[room - 1])
	hud.set_room(room, RUN_PLAN.size(), room_kind)
	if room_kind == "boss":
		_spawn_boss()
		return
	var comp := wave_composition(room)
	var kinds: Array[String] = []
	for kind in comp:
		for i in comp[kind]:
			kinds.append(kind)
	var elites := elite_count(room) if room_kind == "elite" else 0
	kinds.shuffle()
	for kind in kinds:
		var make_elite := elites > 0 and kind != "mage"
		if make_elite:
			elites -= 1
		_spawn(kind, make_elite)


func _spawn(kind: String, elite := false) -> void:
	var e := ENEMY.new()
	var spec: Dictionary = ENEMY_TYPES[kind]
	e.model_scene = load("res://assets/kaykit/characters/%s.glb" % spec.model)
	for key in spec:
		if key != "model":
			e.set(key, spec[key])
	e.elite = elite
	add_child(e)
	# Ring around the player, clamped inside the walls.
	var ang := randf() * TAU
	var dist := randf_range(6.0, 10.0)
	var p := player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
	var lim := ARENA_HALF - 2.0
	e.global_position = Vector3(clampf(p.x, -lim, lim), 0.0, clampf(p.z, -lim, lim))
	e.died.connect(_on_enemy_died)
	_alive += 1


func _spawn_boss() -> void:
	hud.flash_message("THE BONE WARDEN", 1.6)
	var b := BOSS.new()
	b.model_scene = load("res://assets/kaykit/characters/%s.glb" % BOSS_SPEC.model)
	for key in BOSS_SPEC:
		if key != "model":
			b.set(key, BOSS_SPEC[key])
	add_child(b)
	b.global_position = Vector3(0.0, 0.0, -9.0)
	b.died.connect(_on_boss_died)
	b.summon.connect(func(count: int) -> void:
		for i in count:
			_spawn("minion"))
	_alive += 1
	hud.show_boss(b)
	for kind in BOSS_ESCORT:
		for i in BOSS_ESCORT[kind]:
			_spawn(kind)


## The Warden's minions crumble with it.
func _on_boss_died(_b: Node) -> void:
	hud.flash_message("WARDEN DEFEATED", 1.4)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.crumble()
	_on_enemy_died(_b)


func _on_enemy_died(_e: Node) -> void:
	_alive -= 1
	_kills += 1
	if _alive <= 0 and not _between_rooms and not player.is_dead():
		_between_rooms = true
		hud.flash_message("CLEARED", 1.0)
		Game.sfx("wave_clear", -2.0, 0.0)
		await get_tree().create_timer(1.2).timeout
		if player.is_dead():
			return
		if room >= RUN_PLAN.size():
			_end_run(true)
			return
		player.heal(player.max_hp * ROOM_CLEAR_HEAL)
		var choices := Upgrades.roll(player.upgrades)
		if not choices.is_empty():
			reward.open(choices)
			if _autotest:
				_autotest_pick()
			var id: String = await reward.picked
			player.add_upgrade(id)
			hud.set_upgrades(player.upgrades)
			hud.flash_message(Upgrades.get_by_id(id).name.to_upper(), 1.0)
			Game.sfx("perfect", -4.0, 0.0)
		await get_tree().create_timer(1.0).timeout
		if not player.is_dead():
			_next_room()


func _on_player_died() -> void:
	hud.flash_message("YOU FELL", 1.4)
	await get_tree().create_timer(1.8).timeout
	_end_run(false)


func _track_combo(count: int, rank: String) -> void:
	_max_combo = maxi(_max_combo, count)
	if _rank_index(rank) < _rank_index(_best_rank):
		_best_rank = rank


## Position in Game.RANKS (0 = best).
static func _rank_index(rank: String) -> int:
	for i in Game.RANKS.size():
		if Game.RANKS[i][0] == rank:
			return i
	return Game.RANKS.size()


func _end_run(victory: bool) -> void:
	if _run_over:
		return
	_run_over = true
	var cleared := room if victory else room - 1
	var stats := {
		"Rooms cleared": "%d / %d" % [cleared, RUN_PLAN.size()],
		"Time": "%d:%02d" % [int(_run_time) / 60, int(_run_time) % 60],
		"Enemies slain": _kills,
		"Best combo": _max_combo,
		"Best style rank": _best_rank,
		"Best juggle": Game.best_air,
		"Perfect dodges": Game.perfect_dodges,
	}
	summary.open(victory, stats, player.upgrades)
	if _autotest:
		_autotest_finish()


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


## Swap pillars and spike traps to LAYOUTS[index]. The first layout appears
## instantly; later ones sink the old pillars and raise the new ones.
func _apply_layout(index: int) -> void:
	if index == _layout:
		return
	var first := _layout < 0
	_layout = index
	var layout: Dictionary = LAYOUTS[index]
	for o in _occluders:
		var tw := o.create_tween()
		tw.tween_property(o, "position:y", -4.5, 0.6).set_ease(Tween.EASE_IN)
		tw.tween_callback(o.queue_free)
	_occluders.clear()
	for t in _traps:
		t.queue_free()
	_traps.clear()
	for p: Vector3 in layout.pillars:
		var pillar := _place("pillar_decorated", p)
		_cyl_collider(pillar, 0.75, 4.0)
		_occluders.append(pillar)
		if first:
			continue
		# Don't raise a pillar through the hero.
		var away := player.global_position - p
		away.y = 0.0
		if away.length() < 1.6:
			player.global_position = p + (away.normalized() if away.length() > 0.01 else Vector3.BACK) * 1.8
		pillar.position.y = -4.5
		pillar.create_tween().tween_property(pillar, "position:y", 0.0, 0.7).set_delay(0.3) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for s: Vector3 in layout.spikes:
		var trap := SPIKES.new()
		trap.position = s
		add_child(trap)
		_traps.append(trap)
	if not first:
		Game.shake(0.35)
		Game.sfx("spawn", -2.0, 0.0)


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
	if not _run_over and not player.is_dead():
		_run_time += delta
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
	if not _finisher_shot_taken and player.cataclysms > 0:
		_finisher_shot_taken = true
		await get_tree().create_timer(0.35, true, false, true).timeout
		_snap("user://autotest_finisher.png")
	if _autotest_t >= 16.0:
		_autotest_finish()


## Print stats, show the summary screen, screenshot it and quit. Also runs
## when the run ends on its own (the summary pauses _process).
func _autotest_finish() -> void:
	if _quitting:
		return
	_quitting = true
	print("[autotest] room=%d alive=%d player_hp=%.0f max_combo=%d hits=%d awakening=%.0f rank=%s perfect=%d air=%d cataclysm=%d bolts=%d dodges=%d blocks=%d upgrades=%s" % [
		room, _alive, player.hp, _max_combo, _hits, Game.awakening, Game.rank(), Game.perfect_dodges, Game.best_air, player.cataclysms,
		preload("res://scripts/projectile.gd").fired, ENEMY.dodges, ENEMY.blocks, player.upgrades])
	# Exercise the summary screen too.
	_end_run(player.hp > 0.0)
	await get_tree().create_timer(0.3, true, false, true).timeout
	_snap("user://autotest_summary.png")
	Game.stop_all_sfx()
	# Give the audio thread a moment to release playbacks, or they leak at exit.
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit()


func _autotest_pick() -> void:
	await get_tree().create_timer(0.5).timeout
	_snap("user://autotest_reward.png")
	reward.pick(0)


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
		if e.attack_kind == "melee" and e.state == e.State.WINDUP and e._state_t >= e.attack_windup - 0.08 				and e.global_position.distance_to(player.global_position) < e.attack_range + 1.0:
			Input.action_press("dash")
			return
	for p in get_tree().get_nodes_in_group("projectiles"):
		if p.global_position.distance_to(player.global_position + Vector3.UP) < 1.6:
			Input.action_press("dash")
			return
	if nd < 3.0:
		# Cycle through routes: L L L, L H (launch) L L, H spin.
		var step := (f / 9) % 8
		# While Awakened: L L L H to land the Cataclysm finisher.
		var heavy: bool = (player._move_id == "L3" and player.state == player.State.ATTACK) if player.awakened 			else (step in [1, 7])
		if f % 9 == 0:
			Input.action_press("attack_heavy" if heavy else "attack_light")
	elif nd < 7.0 and f % 40 == 0:
		Input.action_press("dash")
	if Game.awakening >= Game.AWAKEN_MAX:
		Input.action_press("awaken")
