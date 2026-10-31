extends Node
## Autoload "Game": global combat feel (hitstop, screen shake), combo/style
## tracking, the Awakening meter, sound effects, and the input map.

signal combo_changed(count: int, rank: String)
signal awakening_changed(value: float)
## Short callouts for the HUD ("PERFECT", ...).
signal announced(text: String)
## Consecutive hits on airborne enemies (0 when the juggle drops).
signal air_combo_changed(count: int)
## Any enemy died (for on-kill upgrades).
signal enemy_killed(enemy: Node)

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
# Juggles: air hits chain while each lands within AIR_TIMEOUT of the last.
# Reaching a milestone announces it and pays out bonus style + Awakening.
const AIR_TIMEOUT := 0.9
const AIR_MILESTONES := {
	3: {"text": "AIRBORNE", "style": 8.0, "awaken": 4.0},
	6: {"text": "SKY DANCER", "style": 15.0, "awaken": 8.0},
	10: {"text": "STRATOSPHERE", "style": 30.0, "awaken": 15.0},
}
const RANK_AWAKEN_MULT := {"D": 1.0, "C": 1.2, "B": 1.4, "A": 1.7, "S": 2.0, "SS": 2.4, "SSS": 3.0}

var camera_rig: Node = null
var combo_count := 0
var style := 0.0
var awakening := 0.0
var perfect_dodges := 0
var air_hits := 0
var best_air := 0
## Survives scene reloads: start the next run without the title screen.
var skip_title := false
## Multiplier on all screen shake (accessibility / taste).
var shake_scale := 1.0
## Multiplier on Awakening gained (Overflow upgrade).
var awakening_gain_mult := 1.0
var _combo_timer := 0.0
var _air_timer := 0.0
var _recent_moves: Array[String] = []
var _hitstop_end_ms := 0
var _sfx_streams := {}
var _sfx_last_ms := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _sfx_muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_settings()
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)


func _process(delta: float) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _hitstop_end_ms:
		Engine.time_scale = 1.0
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


func _exit_tree() -> void:
	stop_all_sfx()
	Fx.release()
	_sfx_streams.clear()


## Stop every voice and drop its stream (sounds still playing at quit leak).
## Also blocks new sounds; call before quitting.
func stop_all_sfx() -> void:
	_sfx_muted = true
	for p in _sfx_players:
		p.stop()
		p.stream = null


func reset() -> void:
	combo_count = 0
	style = 0.0
	awakening = 0.0
	perfect_dodges = 0
	air_hits = 0
	best_air = 0
	awakening_gain_mult = 1.0
	_recent_moves.clear()
	Engine.time_scale = 1.0
	combo_changed.emit(0, rank())
	awakening_changed.emit(awakening)


## Freeze the game briefly on impact. Overlapping calls extend, never shorten.
func hitstop(duration: float, time_scale := 0.03) -> void:
	if duration <= 0.0:
		return
	_hitstop_end_ms = maxi(_hitstop_end_ms, Time.get_ticks_msec() + int(duration * 1000.0))
	Engine.time_scale = minf(Engine.time_scale, time_scale)


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


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "shake_scale", shake_scale)
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
	perfect_dodges += 1
	style += 12.0
	_combo_timer = COMBO_TIMEOUT
	add_awakening(awaken_refund)
	sfx("perfect", 0.0, 0.0)
	announced.emit("PERFECT")
	combo_changed.emit(combo_count, rank())


func player_damaged() -> void:
	style *= 0.4
	if air_hits > 0:
		_end_air_combo()
	combo_count = 0
	_recent_moves.clear()
	combo_changed.emit(0, rank())


func add_awakening(amount: float) -> void:
	if amount > 0.0:
		amount *= awakening_gain_mult
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
