extends Node
## Autoload "Game": global combat feel (hitstop, screen shake), combo/style
## tracking, the Awakening meter, sound effects, and the input map.

signal combo_changed(count: int, rank: String)
signal awakening_changed(value: float)
## Short callouts for the HUD ("PERFECT", ...).
signal announced(text: String)
## Consecutive hits on airborne enemies (0 when the juggle drops).
signal air_combo_changed(count: int)
## Any enemy died.
signal enemy_killed(enemy: Node)
signal hint_shown(text: String)
## An Awakened ultimate began (chain: its number this Awakening; 0 = the Trinity storm).
signal ultimate(ult_name: String, color: Color, chain: int)

const COMBO_TIMEOUT := 2.2
const STYLE_DECAY := 6.0  # style points lost per second while not hitting
const AWAKEN_MAX := 100.0
# Style rank thresholds. Varied moves earn more style than repeating one.
const RANKS := [["SSS", 160.0], ["SS", 110.0], ["S", 70.0], ["A", 40.0], ["B", 20.0], ["C", 8.0], ["D", 0.0]]
# Player settings, saved to SETTINGS_PATH. Screen shake cycles through these.
const SETTINGS_PATH := "user://settings.cfg"
const SHAKE_LEVELS := [1.0, 0.5, 0.0, 1.5]
const SFX_PATH := "res://assets/sfx/%s.wav"
const SFX_VOICES := 16
const SFX_MIN_GAP_MS := 35  # same sound can't restart faster than this
# Hitstop shape (hitstop()): a hit freezes the game at its time scale, then over
# the tail of its length eases back up to full speed instead of snapping (an
# ease-out: quick release, soft landing). Each overlapping stop keeps its own
# shape and the slowest one wins each frame. Slow motion at or above
# HITSTOP_FLAT_SCALE (the breaker window) holds flat so its timing reads true.
const HITSTOP_EASE := 0.3  # fraction of a freeze (scale < SLOWMO_SCALE) spent ramping back up
const SLOWMO_EASE := 0.45  # fraction of a slow-motion stop (last kill, Cataclysm) spent ramping back
const HITSTOP_EASE_CURVE := 0.45  # ease() curve of the ramp; < 1 = ease-out
const HITSTOP_OPENER := 0.8  # a string's first hit (combo_count <= 1) freezes this fraction as long: snappier
const SLOWMO_SCALE := 0.1  # time scales below this are freezes; from here to HITSTOP_FLAT_SCALE, slow motion
const HITSTOP_FLAT_SCALE := 0.5  # time scales at or above this never ramp
# Hit weight (hit_weight, 0..1): how big the latest hit was, from its hitstop
# length, fading in real time; the weapon trail swells with it.
const HIT_WEIGHT_STOP := 0.12  # a freeze this long (real s) is a full-weight hit
const HIT_WEIGHT_DECAY := 4.0  # weight lost per real second
# Juggles: air hits chain while each lands within AIR_TIMEOUT of the last.
# Reaching a milestone announces it and pays out bonus style + Awakening.
const AIR_TIMEOUT := 0.9
const AIR_MILESTONES := {
	3: {"text": "AIRBORNE", "style": 8.0, "awaken": 4.0},
	6: {"text": "SKY DANCER", "style": 15.0, "awaken": 8.0},
	10: {"text": "STRATOSPHERE", "style": 30.0, "awaken": 15.0},
}
# Music: two synced loops from tools/gen_music.py. The ambient layer always
# plays; the combat layer fades to MUSIC_RANK_LEVEL[style rank] (0..1).
# MUSIC_LEVELS is the menu volume setting (saved like screen shake).
const MUSIC_PATH := "res://assets/music/%s.wav"
const MUSIC_LAYERS := ["ambient", "combat"]
const MUSIC_DB := -8.0  # each layer's volume at full level
const MUSIC_LEVELS := [1.0, 0.5, 0.0]
const MUSIC_RANK_LEVEL := {"D": 0.0, "C": 0.45, "B": 0.6, "A": 0.75, "S": 0.85, "SS": 0.95, "SSS": 1.0}
const MUSIC_FADE_IN := 1.2  # combat layer level change per second
const MUSIC_FADE_OUT := 0.25
# First-run hints: main.gd decides when each applies; each shows once, then
# is saved as seen (Reset hints in the pause menu brings them back).
const HINTS := {
	"attack": "Light [LMB] and heavy [RMB] chain into combos.\nMixing different moves raises your style rank.",
	"dash": "Dash [Space] through attacks.\nDash just before a hit lands for a PERFECT dodge.",
	"launch": "Light, then heavy launches enemies.\nKeep hitting them in the air to juggle.",
	"breaker": "Light, light, heavy is a GROUND BREAKER:\na lunging thrust that knocks down everything in a line.",
	"shield": "Shields block hits from the front.\nHit from behind, or hold heavy to charge a guard-breaking slam.",
	"awaken": "Awakening is full! Press [Q] to AWAKEN.",
	"bomber": "Bombers explode when their fuse runs out, hurting skeletons too.\nKnock them into a crowd, or dash clear.",
	"necro": "Necromancers raise fallen skeletons.\nKill them first and their risen crumble.",
	"cage": "The bone cage is closing! Run out through the gap,\nor dash through a wall.",
}
# Gamepad rumble per event: [weak motor, strong motor, seconds]. Toggle in menus.
const RUMBLE := {
	"hit_big": [0.3, 0.5, 0.12],
	"perfect": [0.6, 0.2, 0.18],
	"hurt": [0.2, 0.8, 0.22],
	"awaken": [0.7, 1.0, 0.45],
}
const RANK_AWAKEN_MULT := {"D": 1.0, "C": 1.2, "B": 1.4, "A": 1.7, "S": 2.0, "SS": 2.4, "SSS": 3.0}

var camera_rig: Node = null
## The comic impact frame over the 3D view (scripts/impact_frame.gd), fired
## by big hitstops and kills.
var impact: CanvasLayer = null
var combo_count := 0
var style := 0.0
var awakening := 0.0
var perfect_dodges := 0
var air_hits := 0
var best_air := 0
## Multiplier on all screen shake (accessibility / taste).
var shake_scale := 1.0
var music_scale := 1.0
var rumble_on := true
## Reduce flashing (Settings): softer white hit flashes and sparks, and a
## steady low-HP vignette instead of a throbbing one (Fx, hud.gd).
var reduce_flashing := false
## Combo guide (Settings): the next inputs shown beside the hero mid-string (combo_guide.gd).
var combo_guide := true
## Comic-book art style, see docs/features/comic-style.md. Read this one; it only
## changes between runs (sync_comic). On with --comic (never saved) or the setting.
var comic_style := false
var comic_setting := false
var _comic_cli := false
## --comic-moves only: the comic hero's moves play his Ab_ clips (ComicLook.HERO_MOVES).
var comic_moves := false
## --heretic, with --comic: plays the Meshy hero (assets/comic/heretic.glb) instead. Never saved.
var heretic := false
var save_hints := true  # off in the autotest so it doesn't use up real hints
var _hints_seen: Array = []
## True while the hero is Awakened: gains are ignored so Awakening can't be chained.
var awaken_locked := false
var _combo_timer := 0.0
var _air_timer := 0.0
var _recent_moves: Array[String] = []
var _hitstop_end_ms := 0
var _stops: Array = []  # live hitstops: [end_ms, ramp_ms, scale]; see HITSTOP_EASE
## 0..1: the latest hit's weight (HIT_WEIGHT_STOP), fading at HIT_WEIGHT_DECAY.
var hit_weight := 0.0
var _weight_ms := 0  # when hit_weight last decayed (real ticks: process delta is time-scaled)
var _sfx_streams := {}
var _sfx_last_ms := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _sfx_muted := false
var _music: Array[AudioStreamPlayer] = []
var _combat_level := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	impact = preload("res://scripts/impact_frame.gd").new()
	add_child(impact)
	enemy_killed.connect(func(_e: Node) -> void: impact.flash(impact.IMPACT_KILL, true))
	_setup_input()
	_load_settings()
	_comic_cli = "--comic" in OS.get_cmdline_user_args() or "--comic" in OS.get_cmdline_args()
	comic_moves = not ("--no-comic-moves" in OS.get_cmdline_user_args() or "--no-comic-moves" in OS.get_cmdline_args())
	heretic = "--heretic" in OS.get_cmdline_user_args() or "--heretic" in OS.get_cmdline_args()
	sync_comic()
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_start_music()


func _process(delta: float) -> void:
	_update_hitstop()
	if combo_count > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo_count = 0
			_recent_moves.clear()
			combo_changed.emit(0, rank())
	if air_hits > 0:
		_air_timer -= delta
		if _air_timer <= 0.0:
			_end_air_combo()
	if style > 0.0 and _combo_timer < COMBO_TIMEOUT - 0.6:
		style = maxf(style - STYLE_DECAY * delta, 0.0)
	_update_music(delta)


func _exit_tree() -> void:
	stop_all_sfx()
	Fx.release()
	preload("res://scripts/hero_look.gd").release()
	preload("res://scripts/elements.gd").release()
	preload("res://scripts/breaker_quake.gd").release()
	_sfx_streams.clear()


## Stop every voice and drop its stream (sounds still playing at quit leak).
## Also blocks new sounds; call before quitting.
func stop_all_sfx() -> void:
	_sfx_muted = true
	for p in _sfx_players + _music:
		p.stop()
		p.stream = null


func reset() -> void:
	combo_count = 0
	style = 0.0
	awakening = 0.0
	perfect_dodges = 0
	air_hits = 0
	best_air = 0
	awaken_locked = false
	_recent_moves.clear()
	_stops.clear()
	hit_weight = 0.0
	Engine.time_scale = 1.0
	combo_changed.emit(0, rank())
	awakening_changed.emit(awakening)


## Freeze the game briefly on impact. Overlapping calls extend, never shorten.
## `duration` is real seconds; the stop holds `time_scale` then eases back to
## full speed over its tail (HITSTOP_EASE / SLOWMO_EASE; flat from HITSTOP_FLAT_SCALE).
func hitstop(duration: float, time_scale := 0.03) -> void:
	if duration <= 0.0:
		return
	if impact and time_scale < HITSTOP_FLAT_SCALE:
		impact.on_hitstop(duration)
	if time_scale < SLOWMO_SCALE:
		hit_weight = maxf(hit_weight, clampf(duration / HIT_WEIGHT_STOP, 0.0, 1.0))
	if combo_count <= 1 and time_scale < SLOWMO_SCALE:
		duration *= HITSTOP_OPENER  # the string's opener: a snap, not a stall
	var ramp := 0.0
	if time_scale < SLOWMO_SCALE:
		ramp = HITSTOP_EASE
	elif time_scale < HITSTOP_FLAT_SCALE:
		ramp = SLOWMO_EASE
	var now := Time.get_ticks_msec()
	var end_ms := now + int(duration * 1000.0)
	_hitstop_end_ms = maxi(_hitstop_end_ms, end_ms)
	_stops.append([end_ms, int(duration * ramp * 1000.0), time_scale])
	Engine.time_scale = minf(Engine.time_scale, time_scale)


## Each frame: the slowest live stop sets the time scale; a stop in its ramp
## eases from its scale up to 1.0; finished stops drop off.
func _update_hitstop() -> void:
	var now := Time.get_ticks_msec()
	var scale := 1.0
	var i := _stops.size() - 1
	while i >= 0:
		var s: Array = _stops[i]
		var left: int = s[0] - now
		if left <= 0:
			_stops.remove_at(i)
		else:
			var at: float = s[2]
			if left < s[1]:
				at = lerpf(s[2], 1.0, ease(1.0 - float(left) / float(s[1]), HITSTOP_EASE_CURVE))
			scale = minf(scale, at)
		i -= 1
	if Engine.time_scale != scale:
		Engine.time_scale = scale
	if hit_weight > 0.0:
		hit_weight = maxf(hit_weight - HIT_WEIGHT_DECAY * (now - _weight_ms) * 0.001, 0.0)
	_weight_ms = now


## Back to full speed now, cutting any hitstop / slow motion short (a combo
## breaker's press ends its slow-motion window).
func end_slowmo() -> void:
	_hitstop_end_ms = Time.get_ticks_msec()
	_stops.clear()
	Engine.time_scale = 1.0


## Fire-and-forget sound from assets/sfx/<sound_name>.wav, slightly pitch-varied.
func sfx(sound_name: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	if _sfx_muted:
		return
	var now := Time.get_ticks_msec()
	if now - int(_sfx_last_ms.get(sound_name, -1000)) < SFX_MIN_GAP_MS:
		return
	_sfx_last_ms[sound_name] = now
	if not _sfx_streams.has(sound_name):
		_sfx_streams[sound_name] = load(SFX_PATH % sound_name)
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_VOICES
	p.stream = _sfx_streams[sound_name]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()


func shake(amount: float) -> void:
	if camera_rig and shake_scale > 0.0:
		camera_rig.add_trauma(amount * shake_scale)
		if amount >= camera_rig.ROLL_SHAKE:
			camera_rig.roll(amount * camera_rig.ROLL_DEG)


func _start_music() -> void:
	for layer in MUSIC_LAYERS:
		var stream: AudioStreamWAV = load(MUSIC_PATH % layer)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		var p := AudioStreamPlayer.new()
		p.stream = stream
		add_child(p)
		_music.append(p)
	_update_music(0.0)
	for p in _music:
		p.play()  # same frame, same length: the layers stay in sync


## Fade the combat layer toward the current style rank's level.
func _update_music(delta: float) -> void:
	if _music.size() < 2:
		return
	var target: float = MUSIC_RANK_LEVEL[rank()]
	var speed := MUSIC_FADE_IN if target > _combat_level else MUSIC_FADE_OUT
	_combat_level = move_toward(_combat_level, target, speed * delta)
	_music[0].volume_db = _music_db(1.0)
	_music[1].volume_db = _music_db(_combat_level)


func _music_db(level: float) -> float:
	return maxf(linear_to_db(level * music_scale) + MUSIC_DB, -80.0)


## Step to the next music volume level and save it.
func cycle_music() -> void:
	var i := MUSIC_LEVELS.find(music_scale)
	music_scale = MUSIC_LEVELS[(i + 1) % MUSIC_LEVELS.size()]
	_save_settings()


func music_label() -> String:
	return "Music: %d%%" % roundi(music_scale * 100.0)


func hint_seen(id: String) -> bool:
	return id in _hints_seen


## Show hint `id` (see HINTS) unless it has been seen before.
func hint(id: String) -> void:
	if hint_seen(id):
		return
	_hints_seen.append(id)
	if save_hints:
		_save_settings()
	hint_shown.emit(HINTS[id])


func reset_hints() -> void:
	_hints_seen.clear()
	_save_settings()


## Buzz every connected gamepad with RUMBLE[event] (if rumble is on).
func rumble(event: String) -> void:
	if not rumble_on:
		return
	var r: Array = RUMBLE[event]
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, r[0], r[1], r[2])


func toggle_rumble() -> void:
	rumble_on = not rumble_on
	_save_settings()
	rumble("hit_big")  # a taste of it when switching on


func rumble_label() -> String:
	return "Rumble: %s" % ("On" if rumble_on else "Off")


func toggle_reduce_flashing() -> void:
	reduce_flashing = not reduce_flashing
	_save_settings()


func flashing_label() -> String:
	return "Reduce flashing: %s" % ("On" if reduce_flashing else "Off")


func toggle_combo_guide() -> void:
	combo_guide = not combo_guide
	_save_settings()


func guide_label() -> String:
	return "Combo guide: %s" % ("On" if combo_guide else "Off")


func toggle_comic() -> void:
	comic_setting = not comic_setting
	_save_settings()


func comic_label() -> String:
	return "Comic style (next run): %s" % ("On" if comic_setting else "Off")


## Called as a run's scene loads, so one run never mixes the two looks.
func sync_comic() -> void:
	var on := _comic_cli or comic_setting
	if on == comic_style:
		return
	comic_style = on
	Fx.release()  # the outline's ink width and the cached copies follow the flag
	if not on:
		ComicLook.restore_shadows()


## Step to the next screen shake level and save it.
func cycle_shake() -> void:
	var i := SHAKE_LEVELS.find(shake_scale)
	shake_scale = SHAKE_LEVELS[(i + 1) % SHAKE_LEVELS.size()]
	_save_settings()


func shake_label() -> String:
	return "Screen shake: %d%%" % roundi(shake_scale * 100.0)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		shake_scale = cfg.get_value("video", "shake_scale", 1.0)
		music_scale = cfg.get_value("audio", "music_scale", 1.0)
		rumble_on = cfg.get_value("input", "rumble", true)
		reduce_flashing = cfg.get_value("video", "reduce_flashing", false)
		combo_guide = cfg.get_value("video", "combo_guide", true)
		comic_setting = cfg.get_value("video", "comic_style", false)
		_hints_seen = cfg.get_value("hints", "seen", [])


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "shake_scale", shake_scale)
	cfg.set_value("audio", "music_scale", music_scale)
	cfg.set_value("input", "rumble", rumble_on)
	cfg.set_value("video", "reduce_flashing", reduce_flashing)
	cfg.set_value("video", "combo_guide", combo_guide)
	if comic_setting:  # flag off leaves settings.cfg exactly as it was
		cfg.set_value("video", "comic_style", true)
	cfg.set_value("hints", "seen", _hints_seen)
	cfg.save(SETTINGS_PATH)


## Called once per enemy struck. move_id lets us reward variety.
func register_hit(move_id: String) -> void:
	combo_count += 1
	_combo_timer = COMBO_TIMEOUT
	var variety := 2.0 if not _recent_moves.has(move_id) else 0.5
	_recent_moves.append(move_id)
	if _recent_moves.size() > 3:
		_recent_moves.pop_front()
	style += 1.0 + variety
	add_awakening(1.5 * RANK_AWAKEN_MULT[rank()])
	if camera_rig:
		camera_rig.hit_zoom(1.0 + camera_rig.HIT_ZOOM_TIER * Fx.chain_tier(combo_count))
	if move_id.ends_with("_air"):
		_air_hit()
	combo_changed.emit(combo_count, rank())


func _air_hit() -> void:
	air_hits += 1
	best_air = maxi(best_air, air_hits)
	_air_timer = AIR_TIMEOUT
	if AIR_MILESTONES.has(air_hits):
		var m: Dictionary = AIR_MILESTONES[air_hits]
		style += m.style
		add_awakening(m.awaken)
		announced.emit(m.text)
		sfx("perfect", -6.0, 0.0)
	air_combo_changed.emit(air_hits)


func _end_air_combo() -> void:
	air_hits = 0
	air_combo_changed.emit(0)


func perfect_dodge(awaken_refund: float) -> void:
	rumble("perfect")
	perfect_dodges += 1
	style += 12.0
	_combo_timer = COMBO_TIMEOUT
	add_awakening(awaken_refund)
	sfx("perfect", 0.0, 0.0)
	announced.emit("PERFECT")
	combo_changed.emit(combo_count, rank())


func player_damaged() -> void:
	rumble("hurt")
	style *= 0.4
	if air_hits > 0:
		_end_air_combo()
	combo_count = 0
	_recent_moves.clear()
	combo_changed.emit(0, rank())


func add_awakening(amount: float) -> void:
	if amount > 0.0:
		if awaken_locked:
			return
	awakening = clampf(awakening + amount, 0.0, AWAKEN_MAX)
	awakening_changed.emit(awakening)


func rank() -> String:
	for r in RANKS:
		if style >= r[1]:
			return r[0]
	return "D"


func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], [], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("move_up", [KEY_W, KEY_UP], [], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("move_down", [KEY_S, KEY_DOWN], [], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("attack_light", [KEY_J], [MOUSE_BUTTON_LEFT], [JOY_BUTTON_X])
	_bind("attack_heavy", [KEY_K], [MOUSE_BUTTON_RIGHT], [JOY_BUTTON_Y])
	_bind("dash", [KEY_SPACE, KEY_SHIFT], [], [JOY_BUTTON_A])
	_bind("awaken", [KEY_Q, KEY_L], [], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("traverse", [KEY_R], [], [JOY_BUTTON_LEFT_SHOULDER])
	_bind("restart", [KEY_ENTER], [], [])
	_bind("pause", [KEY_ESCAPE], [], [JOY_BUTTON_START])


func _bind(action: String, keys: Array, mouse: Array, joy: Array, axes: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for m in mouse:
		var e := InputEventMouseButton.new()
		e.button_index = m
		InputMap.action_add_event(action, e)
	for j in joy:
		var e := InputEventJoypadButton.new()
		e.button_index = j
		InputMap.action_add_event(action, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(action, e)
