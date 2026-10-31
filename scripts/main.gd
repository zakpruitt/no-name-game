extends Node3D
## Builds the arena, spawns the hero, camera and HUD, and runs a roguelike
## run: RUN_LENGTH rooms picked door by door (path_options), ending in a boss,
## then a summary.
##
## Pass `-- --autotest` on the command line to let a bot play for a few
## seconds, print combat stats, save screenshots to user://, and quit.
## Add `--all-upgrades` to start with every upgrade (exercises all effects;
## `--max-upgrades` gives them all at MAX_LEVEL), `--upgrades=id,id` for just
## those, `--altar=hardened:3,scavenger:1` for bone altar boons (not saved),
## `--low-hp` to start at 15% HP (low-HP vignette → autotest_lowhp.png), `--start-room=N` to begin at a later room, `--boss-enraged` to start
## the boss at half HP (enraged; it uses the spike line), `--twist=volatile` (or
## `--twist=volatile,hasted`) to make it an elite room with those twists, `--start-rest` to make it a rest (camp) room with some bones, and `--start-awakened` to begin
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
const PATH := preload("res://scripts/path_choice.gd")
const RECORDS := preload("res://scripts/records.gd")
const BONE_CAGE := preload("res://scripts/bone_cage.gd")
const ALTAR := preload("res://scripts/altar.gd")
const BONE := preload("res://scripts/bone_pickup.gd")
const CAMP_MENU := preload("res://scripts/camp.gd")
const ASCEND_MENU := preload("res://scripts/ascend_menu.gd")
const SHRINE_MENU := preload("res://scripts/shrine.gd")
const SHRINE_PROP := preload("res://scripts/shrine_prop.gd")
const DUNGEON := "res://assets/kaykit/dungeon/%s.glb"

# Enemy types: model + overrides for enemy.gd's exported stats. Tune here.
const ENEMY_TYPES := {
	"minion": {"model": "Skeleton_Minion", "title": "skeleton minion", "bones": 1},
	"warrior": {"model": "Skeleton_Warrior", "title": "skeleton warrior", "max_hp": 75.0, "move_speed": 2.8, "attack_damage": 16.0,
		"attack_windup": 0.8, "poise": 8.0, "model_scale": 1.15, "bones": 3},
	"mage": {"model": "Skeleton_Mage", "title": "skeleton mage", "max_hp": 24.0, "move_speed": 3.0, "attack_kind": "ranged",
		"attack_range": 10.0, "preferred_range": 7.0, "attack_damage": 12.0, "attack_windup": 0.9,
		"attack_recover": 0.5, "projectile_speed": 9.0, "bones": 2},
	"rogue": {"model": "Skeleton_Rogue", "title": "skeleton rogue", "max_hp": 28.0, "move_speed": 5.4, "attack_damage": 8.0,
		"attack_windup": 0.45, "attack_recover": 0.5, "flank": true, "dodge_chance": 0.5, "run_anim": "Running_C",
		"bones": 2},
	"archer": {"model": "Skeleton_Rogue", "title": "skeleton archer", "max_hp": 22.0, "move_speed": 3.2, "attack_kind": "line",
		"attack_range": 13.0, "preferred_range": 10.0, "attack_damage": 14.0, "attack_windup": 1.1,
		"attack_recover": 0.9, "projectile_speed": 30.0, "run_anim": "Running_A",
		"cloth_color": Color(0.22, 0.42, 0.3), "bones": 2},
	"shield": {"model": "Skeleton_Minion", "title": "shield skeleton", "max_hp": 40.0, "move_speed": 3.2, "attack_damage": 12.0,
		"attack_windup": 0.7, "shield": true, "model_scale": 1.05, "run_anim": "Walking_D_Skeletons",
		"bones": 2},
	"necromancer": {"model": "Skeleton_Mage", "title": "necromancer", "max_hp": 34.0, "move_speed": 2.8, "attack_kind": "raise",
		"attack_range": 14.0, "preferred_range": 11.0, "attack_damage": 8.0, "attack_windup": 1.2,
		"attack_recover": 0.6, "projectile_speed": 8.0, "cloth_color": Color(0.1, 0.13, 0.1),
		"raise_count": 2, "raise_cooldown": 5.0, "bones": 4},
	"bomber": {"model": "Skeleton_Minion", "title": "bomber", "max_hp": 26.0, "move_speed": 4.2, "attack_kind": "bomb",
		"attack_range": 2.6, "attack_damage": 22.0, "attack_windup": 1.5, "blast_radius": 3.2,
		"blast_enemy_damage": 40.0, "model_scale": 0.9, "run_anim": "Running_C",
		"body_tint": Color(1.0, 0.62, 0.42), "bones": 2},
}
# Necromancers raise slain minions from their graves (within RAISE_RANGE of
# the necromancer; the newest MAX_GRAVES are kept per room). Risen drop no
# bones and crumble when their necromancer dies.
const RAISE_RANGE := 12.0
const MAX_GRAVES := 8
const RAISE_FX_COLOR := Color(0.45, 1.0, 0.4)
# A run is RUN_LENGTH rooms; the last is always the boss and room 1 a fight.
# After each room you pick the next from two doors (path_options). Room n's
# difficulty is its position in the run.
#   fight  regular enemy mix (wave_composition), 1 power
#   elite  the same mix with several elites (elite_count), 2 powers
#   rest   no enemies, heals REST_HEAL of max HP
#   shrine no enemies, one trade from SHRINE (or walk on)
#   boss   the Bone Warden and a small escort; beating it wins the run
const RUN_LENGTH := 8
const REST_HEAL := 0.4
const ELITE_REWARDS := 2
# Elite rooms roll one twist (two different ones from DOUBLE_TWIST_ROOM on),
# shown on the door and the room title. "mult" scales those ENEMY_TYPES stats
# for every enemy in the room; "volatile" makes them burst shortly after
# dying (enemy.gd VOLATILE_*); "split" foes break into that many small
# minions when slain (SPLIT_* below; the minions don't split again).
const DOUBLE_TWIST_ROOM := 6
# `--tour` autotest: take these doors in order (room 1 is always a fight),
# wipe each fight after TOUR_FIGHT_TIME s, and print PASS if the run reaches
# and beats the boss having seen every kind (FAIL after TOUR_TIMEOUT s).
# The camp is topped up to afford its first offer and buys it; the shrine
# takes its rotating trade (vow or melt). Both must happen to PASS.
const TOUR := ["fight", "rest", "shrine", "elite", "boss"]
const TOUR_FIGHT_TIME := 1.5
const TOUR_TIMEOUT := 120.0
# `--pace`: run until the first room clears (prints `cleared ... time=`), for
# comparing room lengths; give up after PACE_TIMEOUT s.
const PACE_TIMEOUT := 90.0
const ELITE_TWISTS := {
	"hasted": {"name": "Hasted", "desc": "faster foes", "mult": {"move_speed": 1.3, "attack_windup": 0.8,
		"attack_recover": 0.8}},
	"armored": {"name": "Armored", "desc": "+60% enemy HP", "mult": {"max_hp": 1.6}},
	"volatile": {"name": "Volatile", "desc": "foes burst when slain", "volatile": true},
	"splitting": {"name": "Splitting", "desc": "foes split in two when slain", "split": 2},
}
const SPLIT_HP := 0.5  # split minions' HP vs a normal minion
const SPLIT_SCALE := 0.7  # and their size
const SPLIT_GLOW := Color(0.6, 0.9, 1.0)  # rim glow that marks them apart
# Reroll on the reward screen: first costs REROLL_COST bones, each further
# reroll of the same offer REROLL_COST_STEP more.
const REROLL_COST := 8
const REROLL_COST_STEP := 4
# Camp (rest rooms): what bones buy. Shown in this order; "Move on" leaves.
# Shrine trades (pick one). "hp_frac": HP paid as a fraction of max HP
# ({hp} in the text); "cost": bones paid.
const SHRINE := {
	"blood": {"text": "Blood pact: lose {hp} HP, gain a new power", "hp_frac": 0.3},
	"mend": {"text": "Bone offering: heal to full", "cost": 15},
}
# Each shrine also offers one of these, picked per shrine.
#   vow   the next room gets the `twist` (ELITE_TWISTS key); gain a new power
#   melt  destroy one owned power (picked per shrine) for `bones` per level
const SHRINE_ROTATING := {
	"vow": {"text": "Dark vow: next room's foes are {twist}, gain a new power", "twist": "armored"},
	"melt": {"text": "Melt down {power}: lose it, gain {bones} bones", "bones": 20},
}
const CAMP := {
	"vigor": {"text": "Vigor: +15 max HP", "cost": 15, "max_hp": 15.0},
	"power": {"text": "Seek a new power", "cost": 20},
	"hone": {"text": "Hone: level up a power", "cost": 25},
}
# Fraction of max HP restored when a room (other than the boss) is cleared.
const ROOM_CLEAR_HEAL := 0.25
# Spawn pacing: at most MAX_ALIVE enemies are up at once; the rest of the
# room waits in a queue and one steps in REINFORCE_DELAY after each kill.
const MAX_ALIVE := 8
const REINFORCE_DELAY := 0.7
# Arena layouts: pillar spots and spike-trap tiles (spikes must sit on tile
# centres: ±2, ±6, ±10, ±14). ROOM_LAYOUTS picks one per room number;
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
	"hit_freeze": 0.03, "run_anim": "Walking_D_Skeletons", "bones": 0}
const BOSS_ESCORT := {"minion": 2, "mage": 1}

## Seed for the daily run on `date` ("YYYY-MM-DD"): the same all day, for everyone.
static func daily_seed(date: String) -> int:
	return hash("awaken-daily-" + date) & 0x7fffffff


## The (up to) two doors offered for room n, given the previous room's kind.
## Elites, rests and shrines unlock from room 3; never two fightless rooms
## (rest, shrine) in a row.
static func path_options(n: int, prev: String, rng: RandomNumberGenerator = null) -> Array:
	if n >= RUN_LENGTH:
		return ["boss"]
	var pool := ["fight", "elite", "rest", "shrine"]
	if n < 3:
		return ["fight"]
	if prev in ["rest", "shrine"]:
		pool.erase("rest")
		pool.erase("shrine")
	Upgrades.shuffle(pool, rng)
	return pool.slice(0, 2)


## How many of each type room n spawns.
static func wave_composition(n: int) -> Dictionary:
	return {"minion": 4, "warrior": n / 2, "mage": n / 2, "rogue": (n + 1) / 3, "shield": (n - 1) / 2, "archer": n / 3,
		"necromancer": (n - 2) / 3, "bomber": (n - 1) / 3}


## How many of an elite room's enemies are promoted to elites (never mages,
## necromancers or bombers).
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
var room_kind := "fight"
var room_twists: Array[String] = []  # ELITE_TWISTS keys for this (elite) room
var run_seed := 0
var run_rng := RandomNumberGenerator.new()
var daily_date := ""  # "2026-10-31" on a daily run (title screen), else ""
var _tour := false
var _tour_seen: Array[String] = []
var _tour_room_t := 0.0
var _tour_trades: Array[String] = []  # "camp:vigor", "shrine:melt"... taken on the tour
var _won := false
var _pace := false  # --pace: end the autotest when the first room clears
var _room_start_t := 0.0  # _autotest_t when this room began (clear time)
var _split_shot_taken := false
var _shatter_shot_taken := false
var _splits := 0  # minions split off by the Splitting twist (autotest line)
var _vow_twist := ""  # ELITE_TWISTS key a shrine vow adds to the next room
var _shrine_trade := ""  # --shrine-trade=id: force the rotating trade (autotest)
var path_menu: CanvasLayer
var camp_menu: CanvasLayer
var ascend_menu: CanvasLayer
var _ascend_pick := ""  # --ascend=path: the autotest's pick (or applied at start)
var _ascend_shot_taken := false
var shrine_menu: CanvasLayer
var _reward_rerolls := 0  # rerolls bought for the reward currently open
var _reward_level_ups_only := false
var _alive := 0
var _graves: Array[Vector3] = []  # where minions fell this room (necromancers raise them)
var _raises := 0
var _queue: Array = []  # [kind, elite] pairs waiting to spawn this room (MAX_ALIVE)
var _between_rooms := false
var _run_over := false
# Run stats for the summary screen.
var _run_time := 0.0
var _hint_gap := 0.0  # seconds before another hint may show
const HINT_GAP := 7.0
var _kills := 0
var _max_combo := 0
var _best_rank := "D"
# Tall props that fade out when they sit between the camera and the hero.
var _occluders: Array[Node3D] = []
# The near-edge rubble row; fades the same way but never changes with layouts.
var _edge_rubble: Array[Node3D] = []
var _traps: Array[Node3D] = []
var _layout := -1

var _autotest := false
var _autotest_t := 0.0
var _bot_charge_t := 0.0  # bot is holding heavy to charge while > 0
var _bot_next_charge := 3.0
var _charge_shot_taken := false
var _hint_shot_taken := false
var _necro_shot_taken := false
var _spikes_shot_taken := false
var _cage_shot_taken := false
var _bomb_shot_taken := false
var _breaker_shot_taken := false
var _slam_shot_taken := false
var _synergy_shot_taken := false
# Character models by name, loaded once up front: loading a .glb mid-fight
# (e.g. the boss room after its models were freed) hitched ~150ms.
var _models := {}
# Autotest frame stats (real time, so hitstop slow-mo doesn't skew them).
var _perf := {"frames": 0, "total_ms": 0.0, "worst_ms": 0.0, "spikes": 0, "enemies": 0, "draws": 0, "nodes": 0}
var _perf_last_us := 0
var _perf_last_frame := 0
var _shots_taken := 0
var _hit_shot_taken := false
var _dash_shot_taken := false
var _dash_shot_at := 0
var _finisher_shot_taken := false
var _callout_shot_taken := false
var _ult_shot_taken := false
var _trinity_shot_taken := false
var _cast_shot_taken := false
var _archer_shot_taken := false
var _quitting := false
var _hits := 0


func _ready() -> void:
	Game.reset()
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	# One seed drives the global RNG (arena dressing, combat effects) and
	# run_rng (doors, twists, spawn order, reward offers), which nothing else
	# draws from, so `--seed=N` repeats a run's rolls even though combat
	# timing varies. The autotest prints the seed.
	run_seed = randi()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			run_seed = arg.get_slice("=", 1).to_int()
		elif arg == "--daily":  # what the title's "Daily run" does
			daily_date = Time.get_date_string_from_system()
			run_seed = daily_seed(daily_date)
	seed(run_seed)
	run_rng.seed = run_seed
	if _autotest:
		RECORDS.enabled = false
		ALTAR.enabled = false
		Game.save_hints = false
		Game._hints_seen.clear()  # show them all, without touching the saved ones
	_build_environment()
	_build_arena()
	for spec in ENEMY_TYPES.values() + [BOSS_SPEC]:
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
	_apply_altar()
	hud.bind_player(player)

	reward = REWARD.new()
	add_child(reward)
	summary = SUMMARY.new()
	add_child(summary)
	add_child(PAUSE.new())
	path_menu = PATH.new()
	add_child(path_menu)
	camp_menu = CAMP_MENU.new()
	add_child(camp_menu)
	ascend_menu = ASCEND_MENU.new()
	add_child(ascend_menu)
	shrine_menu = SHRINE_MENU.new()
	add_child(shrine_menu)
	reward.reroll_pressed.connect(_reroll_reward)
	Game.combo_changed.connect(_track_combo)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):  # start at that hero level
			var lv := arg.get_slice("=", 1).to_int()
			if lv > 1:
				Game.add_xp(Game.LEVEL_XP[mini(lv, Game.LEVEL_MAX) - 2])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ascend="):  # start ascended (implies level 6)
			_ascend_pick = arg.get_slice("=", 1)
			if Ascendancy.PATHS.has(_ascend_pick):
				Game.add_xp(Game.LEVEL_XP[-1] - Game.xp)
				player.ascend(_ascend_pick)
	if "--start-awakened" in OS.get_cmdline_user_args():
		Game.add_awakening(Game.AWAKEN_MAX)
	var max_upgrades := "--max-upgrades" in OS.get_cmdline_user_args()
	if max_upgrades or "--all-upgrades" in OS.get_cmdline_user_args():
		for u in Upgrades.ALL:
			for i in Upgrades.MAX_LEVEL if max_upgrades else 1:
				player.add_upgrade(u.id)
		hud.set_upgrades(player.upgrades)
	if "--low-hp" in OS.get_cmdline_user_args():
		player.hp = player.max_hp * 0.15
		player.health_changed.emit(player.hp, player.max_hp)
		get_tree().create_timer(2.5).timeout.connect(_snap.bind("user://autotest_lowhp.png"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--upgrades="):
			for id in arg.get_slice("=", 1).split(","):
				player.add_upgrade(id)
			hud.set_upgrades(player.upgrades)

	if _autotest:
		player.bot_enabled = true
		Game.combo_changed.connect(func(c: int, _r: String) -> void:
			if c > 0: _hits += 1)
		Game.air_combo_changed.connect(func(c: int) -> void:
			if c == 3 and Game.best_air == 3:
				await get_tree().create_timer(0.1, true, false, true).timeout
				_snap("user://autotest_air.png"))
		# First synergy: one from --upgrades already fired; else wait for one.
		if not player.synergies.is_empty():
			get_tree().create_timer(0.25).timeout.connect(_snap.bind("user://autotest_synergy.png"))
		else:
			Game.announced.connect(func(t: String) -> void:
				if t.ends_with("SYNERGY") and not _synergy_shot_taken:
					_synergy_shot_taken = true
					await get_tree().create_timer(0.25, true, false, true).timeout
					_snap("user://autotest_synergy.png"))
		Game.announced.connect(func(_t: String) -> void:
			if Game.perfect_dodges == 1:
				await get_tree().create_timer(0.15, true, false, true).timeout
				_snap("user://autotest_perfect.png"))

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start-room="):
			room = clampi(arg.get_slice("=", 1).to_int() - 1, 0, RUN_LENGTH - 1)
			if room + 1 >= RUN_LENGTH:
				room_kind = "boss"
		elif arg.begins_with("--twist="):
			room_kind = "elite"
			for id in arg.get_slice("=", 1).split(","):
				room_twists.append(id)
		elif arg == "--start-rest":
			room_kind = "rest"
			Game.add_bones(30)
		elif arg.begins_with("--shrine-trade="):
			_shrine_trade = arg.get_slice("=", 1)
		elif arg == "--pace":
			_pace = true
		elif arg == "--reduce-flashing":  # the setting, without saving it
			Game.reduce_flashing = true
		elif arg == "--tour":
			_tour = true
		elif arg == "--start-shrine":
			room_kind = "shrine"
			Game.add_bones(30)
	if not _autotest and not Game.skip_title:
		var title := TITLE.new()
		add_child(title)
		hud.visible = false
		title.open()
		await title.started
		if title.daily:
			daily_date = Time.get_date_string_from_system()
			run_seed = daily_seed(daily_date)
		elif not title.replay.is_empty():
			daily_date = title.replay.daily
			run_seed = title.replay.seed
		if title.daily or not title.replay.is_empty():
			run_rng.seed = run_seed
			seed(run_seed)
		title.queue_free()
		hud.visible = true
	Game.skip_title = false
	_next_room()


# --- Rooms ------------------------------------------------------------------

func _next_room() -> void:
	room += 1
	_between_rooms = false
	_room_start_t = _autotest_t
	if _tour:
		_tour_seen.append(room_kind)
		_tour_room_t = _autotest_t
	_apply_layout(ROOM_LAYOUTS[room - 1])
	_graves.clear()
	if _vow_twist != "" and room_kind in ["fight", "elite", "boss"]:
		if _vow_twist not in room_twists:
			room_twists.append(_vow_twist)
		_vow_twist = ""
	hud.set_room(room, RUN_LENGTH, room_kind, _twist_text(room_twists, "name", " + "))
	if room_kind == "boss":
		_spawn_boss()
		return
	if room_kind == "rest":
		_rest()
		return
	if room_kind == "shrine":
		_shrine()
		return
	var comp := wave_composition(room)
	var kinds: Array[String] = []
	for kind in comp:
		for i in comp[kind]:
			kinds.append(kind)
	var elites := elite_count(room) if room_kind == "elite" else 0
	Upgrades.shuffle(kinds, run_rng)
	_queue.clear()
	for kind in kinds:
		var make_elite := elites > 0 and kind not in ["mage", "necromancer", "bomber"]
		if make_elite:
			elites -= 1
		_queue.append([kind, make_elite])
	while _alive < MAX_ALIVE and not _queue.is_empty():
		var next: Array = _queue.pop_front()
		_spawn(next[0], next[1])


## Rest room: no enemies, a heal, then straight on to the next door.
func _rest() -> void:
	_between_rooms = true
	await get_tree().create_timer(0.8).timeout
	player.heal(player.max_hp * REST_HEAL)
	Game.sfx("wave_clear", -4.0, 0.0)
	await get_tree().create_timer(1.4).timeout
	if not player.is_dead():
		await _camp()
		await _choose_path()
		_next_room()


## Shrine room: no enemies; offer one SHRINE trade, then the next door.
func _shrine() -> void:
	_between_rooms = true
	var prop := SHRINE_PROP.new()
	add_child(prop)
	# Up-screen of the hero (clear of the menu title), kept inside the walls.
	var at := player.global_position + Vector3(0.0, 0.0, -5.0)
	prop.global_position = Vector3(clampf(at.x, -ARENA_HALF + 3.0, ARENA_HALF - 3.0), 0.0,
		clampf(at.z, -ARENA_HALF + 3.0, ARENA_HALF - 3.0))
	prop.rise()
	if _autotest:
		get_tree().create_timer(2.2).timeout.connect(_snap.bind("user://autotest_shrine_room.png"))
	await get_tree().create_timer(2.3).timeout  # let the room title fade first
	var trades := SHRINE.duplicate()
	var rot: String = _shrine_trade if _shrine_trade != "" else SHRINE_ROTATING.keys()[run_rng.randi() % SHRINE_ROTATING.size()]
	var trade: Dictionary = SHRINE_ROTATING[rot].duplicate()
	var melted := ""
	match rot:
		"vow":
			trade.text = trade.text.format({"twist": ELITE_TWISTS[trade.twist].name})
		"melt":
			var owned: Array = player.upgrades.keys()
			if owned.is_empty():
				trade.text = "Melt down a power (you have none)"
				trade.blocked = true
			else:
				melted = owned[run_rng.randi() % owned.size()]
				var level: int = player.upgrades[melted]
				trade.text = trade.text.format({"power": Upgrades.get_by_id(melted).name + Upgrades.level_tag(level),
					"bones": trade.bones * level})
	trades[rot] = trade
	shrine_menu.open(trades, player.hp, player.max_hp, Game.bones)
	if _autotest:
		_autotest_shrine(rot)
	var choice: String = await shrine_menu.chosen
	if _tour:
		_tour_trades.append("shrine:" + choice + ("" if choice == rot else "(wanted %s)" % rot))
	match choice:
		"vow":
			_vow_twist = trade.twist
			Game.sfx("spawn", -2.0, 0.0)
			Game.shake(0.3)
			await _offer_reward()
		"melt":
			Game.add_bones(trade.bones * player.upgrades[melted])
			player.remove_upgrade(melted)
			hud.set_upgrades(player.upgrades)
			Fx.burst(self, player.global_position + Vector3.UP, Color(1.0, 0.6, 0.2), 24, 5.0)
			Game.sfx("pickup", -2.0, 0.0)
		"blood":
			player.hp -= ceili(player.max_hp * SHRINE.blood.hp_frac)
			player.health_changed.emit(player.hp, player.max_hp)
			Fx.flash(player.model)
			Game.sfx("player_hurt", -2.0, 0.0)
			Game.shake(0.3)
			await _offer_reward()
		"mend":
			Game.add_bones(-SHRINE.mend.cost)
			player.heal(player.max_hp)
			Game.sfx("wave_clear", -4.0, 0.0)
	prop.sink()
	if not player.is_dead():
		await _choose_path()
		_next_room()


## Spend bones at the camp until the player moves on.
func _camp() -> void:
	var bought := 0
	while true:
		if _tour and bought == 0:
			Game.add_bones(maxi(CAMP.values()[0].cost - Game.bones, 0))  # so the tour can buy
		camp_menu.open(CAMP, Game.bones, not Upgrades.roll(player.upgrades, 1, true).is_empty())
		if _autotest:
			_autotest_camp(bought)
		var choice: String = await camp_menu.chosen
		if _tour:
			_tour_trades.append("camp:" + choice)
		if choice == "leave":
			return
		Game.add_bones(-CAMP[choice].cost)
		bought += 1
		match choice:
			"vigor":
				player.max_hp += CAMP.vigor.max_hp
				player.heal(CAMP.vigor.max_hp)
			"power":
				await _offer_reward()
			"hone":
				await _offer_reward(true)


## Ask which door to take next (or go straight on when there's only one).
func _choose_path() -> void:
	var options := path_options(room + 1, room_kind, run_rng)
	room_twists.clear()
	if _tour and _tour_seen.size() < TOUR.size():
		room_kind = TOUR[_tour_seen.size()]
		if room_kind == "boss":
			room = RUN_LENGTH - 1  # the boss is always the last room
		return
	if options.size() == 1:
		room_kind = options[0]
		return
	var twists: Array = ELITE_TWISTS.keys()
	Upgrades.shuffle(twists, run_rng)
	twists = twists.slice(0, 2 if room + 1 >= DOUBLE_TWIST_ROOM else 1)
	path_menu.open(options, room + 1, _twist_text(twists, "name", " + "), _twist_text(twists, "desc", ", "))
	if _autotest:
		_autotest_path()
	room_kind = await path_menu.chosen
	if room_kind == "elite":
		room_twists.assign(twists)


## Twist names or descs joined for the door / room title ("" for none).
static func _twist_text(ids: Array, field: String, sep: String) -> String:
	return sep.join(ids.map(func(id: String) -> String: return ELITE_TWISTS[id][field]))


## Spawns on a ring around the player unless `at` is given.
func _spawn(kind: String, elite := false, at := Vector3.INF) -> Node:
	var e := ENEMY.new()
	var spec: Dictionary = ENEMY_TYPES[kind]
	e.model_scene = _model(spec.model)
	for key in spec:
		if key not in ["model", "title"]:
			e.set(key, spec[key])
	e.elite = elite
	e.set_meta("kind", kind)
	e.set_meta("title", spec.get("title", kind))
	for id in room_twists:
		var twist: Dictionary = ELITE_TWISTS[id]
		for key in twist.get("mult", {}):
			e.set(key, e.get(key) * twist.mult[key])
		e.volatile = e.volatile or twist.get("volatile", false)
	if e.attack_kind == "raise":
		e.can_raise = _can_raise
		e.raise_requested.connect(_raise)
	add_child(e)
	if at != Vector3.INF:
		e.global_position = at
	else:
		# Ring around the player, clamped inside the walls.
		var ang := randf() * TAU
		var dist := randf_range(6.0, 10.0)
		var p := player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
		var lim := ARENA_HALF - 2.0
		e.global_position = Vector3(clampf(p.x, -lim, lim), 0.0, clampf(p.z, -lim, lim))
	e.died.connect(_on_enemy_died)
	_alive += 1
	hud.set_remaining(_alive + _queue.size())
	return e


func _any_fuse_lit() -> bool:
	return get_tree().get_nodes_in_group("enemies").any(func(e: Node) -> bool: return e.fuse_left() >= 0.0)


func _can_raise(necro: Node3D) -> bool:
	return _graves.any(func(g: Vector3) -> bool: return g.distance_to(necro.global_position) <= RAISE_RANGE)


## Raise the necromancer's raise_count nearest graves as minions.
func _raise(necro: Node3D) -> void:
	var near := _graves.filter(func(g: Vector3) -> bool: return g.distance_to(necro.global_position) <= RAISE_RANGE)
	near.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.distance_to(necro.global_position) < b.distance_to(necro.global_position))
	for g: Vector3 in near.slice(0, necro.raise_count):
		_graves.erase(g)
		Fx.ring(self, g, RAISE_FX_COLOR, 1.6, 0.5)
		Fx.burst(self, g + Vector3.UP * 0.3, RAISE_FX_COLOR, 12, 4.0)
		var m := _spawn("minion", false, g)
		m.bones = 0
		m.set_meta("master", necro)
		_raises += 1
	Game.sfx("spawn", -4.0, 0.1)
	if _autotest and not _necro_shot_taken:
		_necro_shot_taken = true
		await get_tree().create_timer(0.4).timeout
		_snap("user://autotest_necro.png")


func _model(model_name: String) -> PackedScene:
	if not _models.has(model_name):
		_models[model_name] = load("res://assets/kaykit/characters/%s.glb" % model_name)
	return _models[model_name]


func _spawn_boss() -> void:
	hud.flash_message("THE BONE WARDEN", 1.6)
	var b := BOSS.new()
	b.model_scene = _model(BOSS_SPEC.model)
	for key in BOSS_SPEC:
		if key != "model":
			b.set(key, BOSS_SPEC[key])
	add_child(b)
	b.global_position = Vector3(0.0, 0.0, -9.0)
	b.died.connect(_on_boss_died)
	b.summon.connect(func(count: int) -> void:
		for i in count:
			_spawn("minion"))
	# Urgent, so it skips the HINT_GAP queue in _check_hints.
	b.cage.connect(func() -> void:
		Game.hint("cage")
		_hint_gap = HINT_GAP)
	if _autotest:
		b.spike_line.connect(_autotest_spikes)
		b.cage.connect(_autotest_cage)
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--boss-attack="):
				b.force_attack = arg.get_slice("=", 1)
		if "--boss-enraged" in OS.get_cmdline_user_args():
			b.hp = b.max_hp * 0.5
			b.call_deferred("_enrage")
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


## Bring in the next queued enemy a moment after a kill.
func _reinforce() -> void:
	await get_tree().create_timer(REINFORCE_DELAY).timeout
	if _queue.is_empty() or _between_rooms or player.is_dead():
		return
	var next: Array = _queue.pop_front()
	_spawn(next[0], next[1])


func _on_enemy_died(e: Node) -> void:
	for i in e.bones:
		var b := BONE.new()
		add_child(b)
		b.global_position = e.global_position + Vector3.UP * 0.8
	if e.get_meta("kind", "") == "minion":
		_graves.append(Vector3(e.global_position.x, 0.0, e.global_position.z))
		if _graves.size() > MAX_GRAVES:
			_graves.pop_front()
	if e.attack_kind == "raise":
		for m in get_tree().get_nodes_in_group("enemies"):
			if m.has_meta("master") and m.get_meta("master") == e:
				m.crumble()
	_split(e)
	_alive -= 1
	_kills += 1
	hud.set_remaining(_alive + _queue.size())
	if not _queue.is_empty():
		_reinforce()
		return
	if _alive <= 0 and not _between_rooms and not player.is_dead():
		_between_rooms = true
		hud.flash_message("CLEARED", 1.0)
		if _autotest:
			print("[autotest] cleared room=%d kind=%s time=%.1fs hp=%.0f" % [room,
				"+".join([room_kind] + Array(room_twists)), _autotest_t - _room_start_t, player.hp])
			if _pace:
				_autotest_finish()
				return
		Game.sfx("wave_clear", -2.0, 0.0)
		await get_tree().create_timer(1.2).timeout
		if player.is_dead():
			return
		if room >= RUN_LENGTH:
			_end_run(true)
			return
		player.heal(player.max_hp * ROOM_CLEAR_HEAL)
		if Game.level >= Game.LEVEL_MAX and player.ascendancy == "":
			await _offer_ascendancy()
		for i in ELITE_REWARDS if room_kind == "elite" else 1:
			await _offer_reward()
		await get_tree().create_timer(0.6).timeout
		if player.is_dead():
			return
		await _choose_path()
		_next_room()


## Splitting twist: a slain foe (not itself a split) breaks into small minions.
func _split(e: Node) -> void:
	var count := 0
	for id in room_twists:
		count = maxi(count, ELITE_TWISTS[id].get("split", 0))
	if count == 0 or e.has_meta("split") or e.has_meta("master"):
		return
	Fx.burst(self, e.global_position + Vector3.UP * 0.6, Color(0.92, 0.88, 0.78), 14, 5.0)
	for i in count:
		var ang := TAU * i / count + randf() * 0.5
		var m := _spawn("minion", false, e.global_position + Vector3(cos(ang), 0.0, sin(ang)) * 0.9)
		m.set_meta("split", true)
		m.bones = 0
		m.max_hp *= SPLIT_HP
		m.hp = m.max_hp
		m.model_scale *= SPLIT_SCALE  # (squash tweens restore model.scale from it)
		m.model.scale = Vector3.ONE * m.model_scale
		m.set_glow(SPLIT_GLOW)
		_splits += 1
	if _autotest and not _split_shot_taken:
		_split_shot_taken = true
		get_tree().create_timer(1.3).timeout.connect(_snap.bind("user://autotest_split.png"))


func _offer_ascendancy() -> void:
	ascend_menu.open()
	if _autotest:
		if not _ascend_shot_taken:
			_ascend_shot_taken = true
			await get_tree().create_timer(0.4, true, false, true).timeout
			_snap("user://autotest_ascend.png")
		var keys: Array = Ascendancy.PATHS.keys()
		ascend_menu.pick.call_deferred(maxi(keys.find(_ascend_pick), 0) if _ascend_pick != "" else run_rng.randi() % keys.size())
	var path: String = await ascend_menu.chosen
	player.ascend(path)
	await get_tree().create_timer(0.6).timeout


func _offer_reward(level_ups_only := false) -> void:
	var choices := Upgrades.roll(player.upgrades, 3, level_ups_only, run_rng)
	if choices.is_empty():
		return
	_reward_rerolls = 0
	_reward_level_ups_only = level_ups_only
	reward.open(choices, _reroll_cost())
	if _autotest:
		_autotest_pick()
	var id: String = await reward.picked
	player.add_upgrade(id)
	hud.set_upgrades(player.upgrades)
	hud.flash_message((Upgrades.get_by_id(id).name + Upgrades.level_tag(player.upgrades[id])).to_upper(), 1.0)
	Game.sfx("perfect", -4.0, 0.0)
	await get_tree().create_timer(0.5).timeout


func _reroll_cost() -> int:
	return REROLL_COST + REROLL_COST_STEP * _reward_rerolls


func _reroll_reward() -> void:
	Game.add_bones(-_reroll_cost())
	_reward_rerolls += 1
	Game.sfx("pickup", -6.0, 0.1)
	reward.open(Upgrades.roll(player.upgrades, 3, _reward_level_ups_only, run_rng), _reroll_cost())


func _on_player_died() -> void:
	hud.flash_message("YOU FELL", 1.4)
	await get_tree().create_timer(1.8).timeout
	_end_run(false)


func _track_combo(count: int, rank: String) -> void:
	_max_combo = maxi(_max_combo, count)
	if RECORDS.rank_index(rank) < RECORDS.rank_index(_best_rank):
		_best_rank = rank


## Bone altar boons bought between runs (altar.gd BOONS).
func _apply_altar() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--altar="):
			for pair in arg.get_slice("=", 1).split(","):
				ALTAR.override[pair.get_slice(":", 0)] = pair.get_slice(":", 1).to_int()
	player.max_hp += ALTAR.bonus("hardened")
	player.hp = player.max_hp
	Game.bones += ALTAR.bonus("scavenger")
	Game.bones_changed.emit(Game.bones)
	Game.add_awakening(ALTAR.bonus("kindled"))


func _end_run(victory: bool) -> void:
	_won = _won or victory
	if _run_over:
		return
	_run_over = true
	var cleared := room if victory else room - 1
	var stats := {}
	if not victory and player.last_hit_by != "":
		stats["Slain by"] = player.last_hit_by
	stats.merge({
		"Rooms cleared": "%d / %d" % [cleared, RUN_LENGTH],
		"Time": RECORDS.time_text(_run_time),
		"Enemies slain": _kills,
		"Best combo": _max_combo,
		"Best style rank": _best_rank,
		"Best juggle": Game.best_air,
		"Perfect dodges": Game.perfect_dodges,
		"Bones collected": Game.bones_total,
		"Bones banked": Game.bones,
	})
	ALTAR.bank(Game.bones)
	var bests := RECORDS.submit({"victory": victory, "rooms": cleared, "combo": _max_combo,
		"rank": _best_rank if _max_combo >= 2 else "", "juggle": Game.best_air, "time": _run_time,
		"room": room, "seed": run_seed, "daily": daily_date})
	# Summary rows to flag as new personal bests.
	var rows := {"best_room": "Rooms cleared", "best_combo": "Best combo", "best_rank": "Best style rank",
		"best_juggle": "Best juggle", "fastest_win": "Time"}
	summary.open(victory, stats, player.upgrades, bests.map(func(k: String) -> String: return rows[k]),
		player.synergies, run_seed, daily_date)
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
	for o: Node3D in _occluders + _edge_rubble:
		var d := o.global_position - hp
		var blocking := d.z > 0.0 and d.z < 7.0 and absf(d.x) < 1.8 + (TILE * 0.5 if o in _edge_rubble else 0.0)
		var target := 0.7 if blocking else 0.0
		for mi: MeshInstance3D in o.find_children("*", "MeshInstance3D", true, false):
			mi.transparency = move_toward(mi.transparency, target, delta * 4.0)


# --- Autotest bot -----------------------------------------------------------

func _process(delta: float) -> void:
	_fade_occluders(delta)
	if not _run_over and not player.is_dead():
		_run_time += delta
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
	if player.ground_breakers > 0 and not _breaker_shot_taken:
		_breaker_shot_taken = true
		get_tree().create_timer(0.12).timeout.connect(_snap.bind("user://autotest_breaker.png"))
		if player.has_upgrade("fault_line"):
			var erupt: float = player.upg("fault_line", "delay") + 0.1
			get_tree().create_timer(erupt).timeout.connect(_snap.bind("user://autotest_fault.png"))
	if player.shatters > 0 and not _shatter_shot_taken:
		_shatter_shot_taken = true
		get_tree().create_timer(0.1).timeout.connect(_snap.bind("user://autotest_shatter.png"))
	if player.charged_slams > 0 and not _slam_shot_taken:
		_slam_shot_taken = true
		get_tree().create_timer(0.12).timeout.connect(_snap.bind("user://autotest_slam.png"))
	if ENEMY.blasts > 0 and not _bomb_shot_taken:
		_bomb_shot_taken = true
		_snap("user://autotest_bomb.png")
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
	if not _archer_shot_taken:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.attack_kind == "line" and e.state == e.State.WINDUP and e._state_t >= e.attack_windup * 0.8 \
					and get_viewport().get_camera_3d().is_position_in_frustum(e.global_position):
				_archer_shot_taken = true
				_snap("user://autotest_archer.png")
				break
	if not _callout_shot_taken and player.last_callout_tier >= 2:
		_callout_shot_taken = true
		await get_tree().create_timer(0.15, true, false, true).timeout
		_snap("user://autotest_callout.png")
	if not _cast_shot_taken and player.ELEMENTS.casts >= 6:
		_cast_shot_taken = true
		await get_tree().create_timer(0.1, true, false, true).timeout
		_snap("user://autotest_cast.png")
	if not _ult_shot_taken and player.ult_impacts > 0:
		_ult_shot_taken = true
		await get_tree().create_timer(0.08, true, false, true).timeout
		_snap("user://autotest_ult.png")
	if not _trinity_shot_taken and player.trinities > 0:
		_trinity_shot_taken = true
		await get_tree().create_timer(0.75, true, false, true).timeout
		_snap("user://autotest_trinity.png")
	if not _finisher_shot_taken and player.cataclysms > 0:
		_finisher_shot_taken = true
		await get_tree().create_timer(0.35, true, false, true).timeout
		_snap("user://autotest_finisher.png")
	if _tour:
		_drive_tour()
	elif _autotest_t >= (PACE_TIMEOUT if _pace else 16.0):
		_autotest_finish()


## Print stats, show the summary screen, screenshot it and quit. Also runs
## when the run ends on its own (the summary pauses _process).
## First-run hints (Game.HINTS), each when it first becomes relevant.
func _check_hints(delta: float) -> void:
	_hint_gap -= delta
	if _hint_gap > 0.0 or _between_rooms:
		return
	var id := ""
	if not Game.hint_seen("attack"):
		if _run_time > 1.5:
			id = "attack"  # always first
	elif not Game.hint_seen("awaken") and Game.awakening >= Game.AWAKEN_MAX and not player.awakened:
		id = "awaken"
	elif not Game.hint_seen("shield") and ENEMY.blocks > 0:
		id = "shield"
	elif not Game.hint_seen("bomber") and _any_fuse_lit():
		id = "bomber"
	elif not Game.hint_seen("necro") and _raises > 0:
		id = "necro"
	elif not Game.hint_seen("launch") and Game.combo_count >= 4:
		id = "launch"
	elif Game.hint_seen("launch") and not Game.hint_seen("breaker") and Game.best_air > 0 			and player.ground_breakers == 0:
		id = "breaker"  # the next combo route, once launching has clicked
	elif not Game.hint_seen("dash"):
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.state == e.State.WINDUP and e.global_position.distance_to(player.global_position) < e.attack_range + 2.0:
				id = "dash"
				break
	if id != "":
		Game.hint(id)
		_hint_gap = HINT_GAP
		if _autotest and not _hint_shot_taken:
			_hint_shot_taken = true
			await get_tree().create_timer(0.5).timeout
			_snap("user://autotest_hint.png")


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
			print("[perf] spike %.1fms at t=%.2f room=%d enemies=%d" % [ms, _autotest_t, room, get_tree().get_nodes_in_group("enemies").size()])
		_perf.enemies = maxi(_perf.enemies, get_tree().get_nodes_in_group("enemies").size())
		_perf.draws = maxi(_perf.draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_perf.nodes = maxi(_perf.nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_perf_last_us = now
	_perf_last_frame = frame


## --tour: clear fights quickly (the bot still plays for TOUR_FIGHT_TIME s),
## keep the hero alive, and give up after TOUR_TIMEOUT.
func _drive_tour() -> void:
	if _autotest_t >= TOUR_TIMEOUT:
		_autotest_finish()
		return
	player.hp = maxf(player.hp, player.max_hp * 0.5)
	if _between_rooms or _autotest_t - _tour_room_t < TOUR_FIGHT_TIME:
		return
	_queue.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.state != e.State.SPAWN:
			e.take_hit(e.hp + 1.0, Vector3.ZERO, 0.0, true)


func _autotest_finish() -> void:
	if _quitting:
		return
	_quitting = true
	if not ALTAR.override.is_empty():
		print("[autotest] altar=%s max_hp=%.0f" % [ALTAR.override, player.max_hp])
	print("[autotest] seed=%d room=%d kind=%s alive=%d player_hp=%.0f max_combo=%d hits=%d awakening=%.0f rank=%s perfect=%d air=%d cataclysm=%d bolts=%d dodges=%d blocks=%d charged=%d breakers=%d shatters=%d callouts=%d casts=%d ults=%d chain=%d impacts=%d trinity=%d level=%d xp=%d ascend=%s procs=%d bones=%d raises=%d splits=%d blasts=%d cage_escapes=%d/%d music=%.2f hints=%s upgrades=%s" % [
		run_seed, room, "+".join([room_kind] + Array(room_twists)), _alive, player.hp, _max_combo, _hits, Game.awakening, Game.rank(), Game.perfect_dodges, Game.best_air, player.cataclysms,
		preload("res://scripts/projectile.gd").fired, ENEMY.dodges, ENEMY.blocks, player.charged_slams, player.ground_breakers, player.shatters, player.callouts, player.ELEMENTS.casts, player.ults, player.max_chain, player.ult_impacts, player.trinities, Game.level, Game.xp, player.ascendancy if player.ascendancy != "" else "-", player.element_procs, Game.bones_total, _raises, _splits, ENEMY.blasts, BONE_CAGE.escapes, BONE_CAGE.raised, Game._combat_level, ",".join(Game._hints_seen), player.upgrades])
	print("[perf] avg=%.1fms worst=%.1fms spikes(>25ms)=%d/%d max_enemies=%d max_draw_calls=%d max_nodes=%d" % [
		_perf.total_ms / maxi(_perf.frames, 1), _perf.worst_ms, _perf.spikes, _perf.frames, _perf.enemies, _perf.draws, _perf.nodes])
	if _tour:
		var bought := _tour_trades.any(func(t: String) -> bool: return t.begins_with("camp:") and t != "camp:leave")
		var traded := _tour_trades.any(func(t: String) -> bool: return t in ["shrine:vow", "shrine:melt"])
		var ok := ",".join(_tour_seen) == ",".join(TOUR) and _won and bought and traded
		print("[tour] %s rooms=%s trades=%s time=%.1fs" % ["PASS" if ok else "FAIL", ",".join(_tour_seen),
			",".join(_tour_trades), _autotest_t])
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
	if reward.can_reroll():
		reward.reroll()
		print("[autotest] rerolled reward, bones left=", Game.bones)
		await get_tree().create_timer(0.4).timeout
	_snap("user://autotest_reward.png")
	reward.pick(0)


func _autotest_spikes() -> void:
	if _spikes_shot_taken:
		return
	_spikes_shot_taken = true
	print("[autotest] warden spike line")
	await get_tree().create_timer(0.75).timeout
	_snap("user://autotest_spikes.png")


func _autotest_cage() -> void:
	if _cage_shot_taken:
		return
	_cage_shot_taken = true
	print("[autotest] warden bone cage")
	await get_tree().create_timer(1.2).timeout
	_snap("user://autotest_cage.png")


## Buy the first affordable thing once, then move on.
func _autotest_camp(bought: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if bought == 0:
		_snap("user://autotest_camp.png")
		camp_menu.pick(camp_menu.first_affordable())
	else:
		camp_menu.pick(CAMP.size())


## Takes the forced --shrine-trade (or on --tour the rotating one) if it can,
## else the first it can pay.
func _autotest_shrine(rot: String) -> void:
	await get_tree().create_timer(0.5).timeout
	_snap("user://autotest_shrine.png")
	var index: int = SHRINE.size() if _shrine_trade == rot or _tour else shrine_menu.first_affordable()
	if shrine_menu.is_disabled(index):
		index = shrine_menu.first_affordable()
	shrine_menu.pick(index)


func _autotest_path() -> void:
	await get_tree().create_timer(0.5).timeout
	_snap("user://autotest_path.png")
	path_menu.pick(0)


func _snap(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(path)
	_perf_last_us = 0  # the save stalls this frame; keep it out of the stats
	print("[autotest] screenshot ", ProjectSettings.globalize_path(path))


## True if something could interrupt a charge: an enemy close by winding up,
## a bolt in flight nearby, or a lit fuse in range.
func _bot_threatened() -> bool:
	var at := player.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_to(at)
		if d < 6.0 and e.state == e.State.WINDUP:
			return true
		if e.fuse_left() >= 0.0 and d < e.blast_radius + 1.0:
			return true
	for p in get_tree().get_nodes_in_group("projectiles"):
		if p.global_position.distance_to(at) < 6.0:
			return true
	return false


## Inside a bone cage: run for the gap; if a wall is about to reach the hero
## away from the gap, dash out through it on i-frames.
func _bot_escape_cage() -> bool:
	for cage in get_tree().get_nodes_in_group("bone_cage"):
		if not cage.traps(player.global_position):
			continue
		var r: float = cage.ring_radius()
		var gap_dir := Vector3(cos(cage.gap_angle), 0.0, sin(cage.gap_angle))
		var out: Vector3 = cage.global_position + gap_dir * (r + 2.0) - player.global_position
		out.y = 0.0
		player.bot_move = out.normalized()
		var from: Vector3 = player.global_position - cage.global_position
		from.y = 0.0
		var off_gap := absf(angle_difference(atan2(from.z, from.x), cage.gap_angle)) > deg_to_rad(cage.gap) * 0.5
		if off_gap and r - from.length() < 1.3 and player.state == player.State.MOVE:
			player.bot_move = from.normalized()
			Input.action_press("dash")
		return true
	return false


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
		if player.state == player.State.CHARGE and player._charged and not _charge_shot_taken:
			_charge_shot_taken = true
			_snap("user://autotest_charge.png")
		# Knocked out of the charge: let go and try again soon.
		if player.state != player.State.CHARGE and _bot_charge_t < player.CHARGE_TIME:
			_bot_charge_t = 0.0
			_bot_next_charge = _autotest_t + 1.5
		return  # keep holding heavy (and nothing else) until the charge releases
	Input.action_release("attack_heavy")
	Input.action_release("dash")
	Input.action_release("awaken")
	if _bot_escape_cage():
		return
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
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.fuse_left() >= 0.0 and e.fuse_left() < 0.25 and e.global_position.distance_to(player.global_position) < e.blast_radius + 0.5:
			player.bot_move = (player.global_position - e.global_position).normalized()
			Input.action_press("dash")
			return
	# Now and then, from neutral, hold heavy for a charged slam: from just
	# outside melee reach (the slam lunges in), when nothing is about to hit.
	if nd > 2.8 and nd < 6.0 and player.state == player.State.MOVE and not player.awakened and _autotest_t >= _bot_next_charge 			and not _bot_threatened():
		Input.action_press("attack_heavy")
		_bot_charge_t = player.CHARGE_TIME + 0.15
		_bot_next_charge = _autotest_t + 5.0
		return
	if player.awakened and player.state == player.State.ATTACK and player._move_id in ["L3", "LH", "DL"] and f % 9 == 0:
		Input.action_press("attack_heavy")  # finish into the ultimate even if the hit knocked the target away
		return
	if nd < 3.0:
		# Cycle through routes: L H (launch), L L H (ground breaker), L L L.
		var step := (f / 9) % 8
		var heavy: bool = step in [1, 4]
		if player.awakened:
			# While Awakened, go for the ultimates not landed yet this Awakening
			# (L L L H, L H H, Dash L H), for the Trinity.
			var m: String = player._move_id if player.state == player.State.ATTACK else ""
			var routes := ["AF", "SKY", "RUSH"]
			var todo := routes.filter(func(k: String) -> bool: return k not in player._ult_kinds)
			var route: String = todo[0] if not todo.is_empty() else routes[player.ults % 3]
			heavy = m in ["L3", "LH", "DL"] or (route == "SKY" and m == "L1")
			if route == "RUSH" and player.state == player.State.MOVE and player._post_dash_t <= 0.0 and f % 9 == 0:
				Input.action_press("dash")
				return
		if f % 9 == 0:
			Input.action_press("attack_heavy" if heavy else "attack_light")
	elif nd < 7.0 and f % 40 == 0 and not (player.awakened and "RUSH" in player._ult_kinds):  # walk in for the other ultimates
		Input.action_press("dash")
	if Game.awakening >= Game.AWAKEN_MAX:
		Input.action_press("awaken")
