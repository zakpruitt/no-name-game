extends CharacterBody3D
## The hero: movement, dash (with i-frames, cancels attacks), light/heavy
## combo routes, soft auto-aim, and the Awakening transformation.

signal health_changed(hp: float, max_hp: float)
signal awakened_changed(active: bool)
signal died
## Fired when any attack begins (enemies that dodge listen for this).
signal attack_started(move_id: String)
signal combo_found(id: String)  # a named combo landed for the first time this run

enum State { MOVE, ATTACK, DASH, HURT, CHARGE, DEAD, LEAP, SWING }

const TRAIL := preload("res://scripts/weapon_trail.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const AXE_SOURCE := "res://assets/kaykit/characters/Barbarian.glb"  # the 1H_Axe spirit casts ghost (_axe_mesh)
const CAST_GROW := 0.15  # spirit cast size per chain tier (_cast_grow)
const CAST_POWER := 0.12  # spirit cast damage per chain tier
const SPIRIT_TOMAHAWK := preload("res://scripts/spirit_tomahawk.gd")
const ELEMENTS := preload("res://scripts/elements.gd")
const LOOPING := ["Idle", "Running_A", "2H_Melee_Idle", "Run_F", "Run_B", "Strafe_L", "Strafe_R", "Idle_Ready"]

@export var move_speed := 7.5
@export var accel := 70.0
@export var dash_speed := 24.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.3
@export var max_hp := 100.0
@export var anim_speed := 1.7
@export var input_buffer := 0.25
@export var aim_assist_range := 5.5
@export var aim_assist_angle := 70.0
## Fixed length of Awakening; nothing extends it, and the meter can't refill
## while it lasts (Game.awaken_locked), so it ends empty.
@export var awaken_duration := 8.0
@export var afterimage_interval := 0.035
## Dash this soon before an enemy hit lands for a perfect dodge.
@export var perfect_dodge_window := 0.15
@export var perfect_dodge_refund := 20.0
@export var perfect_dodge_stun := 1.2

# Moves. Timings are fractions of the animation's length, so changing
# anim_speed keeps everything in sync.
#   hits: when damage is dealt   cancel: when the next input is accepted
#   end: when control returns    lunge: forward burst speed at start
#   width: (optional) hits a straight strip `range` long and 2x`width` wide
#          instead of the `arc` cone
#   decay: (optional, default 3) how fast the lunge dies: it's gone at 1/decay
#          of the move, so a low decay keeps the hero travelling
#   speed: (optional, default 1) plays the animation this much faster (or,
#          below 1, slower), for anims whose natural length doesn't fit
#   hop: (optional) [start, end, height]: the hero leaves the ground in an arc
#        between those fractions (the model lifts, the body stays). A move
#        started in the air (out of a hop) comes down by its first hit
#        (`land` overrides), so L H's rise carries into L H H's drop.
#   air: (optional) holds the height the move started at; `climb` adds this
#        many metres by its first hit (the air string goes up cut by cut)
const MOVES := {
	"L1": {"anim": "1H_Melee_Attack_Slice_Diagonal", "damage": 8.0, "range": 2.4, "arc": 140.0,
		"hits": [0.35], "cancel": 0.45, "end": 0.75, "lunge": 7.0, "knockback": 2.5, "launch": 0.0,
		"stop": 0.045, "shake": 0.12},
	"GR": {"anim": "Ab_GR", "damage": 6.0, "range": 9.0, "arc": 360.0, "hits": [0.24], "cancel": 0.42, "end": 0.66,
		"lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.14},
	"VS": {"anim": "Ab_VS", "damage": 24.0, "range": 3.8, "arc": 150.0, "hits": [0.39], "cancel": 0.58, "end": 0.82,
		"lunge": 1.5, "knockback": 3.0, "launch": 6.0, "big": true, "stop": 0.09, "shake": 0.42},
	"L2": {"anim": "Throw", "damage": 9.0, "range": 2.5, "arc": 160.0,
		"hits": [0.42], "cancel": 0.5, "end": 0.7, "lunge": 6.0, "knockback": 2.5, "launch": 0.0,
		"stop": 0.05, "shake": 0.14, "hop": [0.12, 0.42, 0.6]},
	"L3": {"anim": "Dualwield_Melee_Attack_Chop", "damage": 16.0, "range": 2.7, "arc": 150.0,
		"hits": [0.4], "cancel": 0.6, "end": 0.85, "lunge": 9.0, "knockback": 11.0, "launch": 0.0,
		"stop": 0.1, "shake": 0.35, "big": true, "hop": [0.1, 0.4, 0.9]},
	# The void arm's right click (void_element.gd). The tentacle and the element do the work.
	"EE": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.24], "cancel": 0.42, "end": 0.6,
		"speed": 1.0, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.2, "air": true},
	"EW": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.24], "cancel": 0.42, "end": 0.6,
		"speed": 1.0, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.2, "air": true},
	"EC": {"anim": "Ab_LH", "damage": 4.0, "range": 2.6, "arc": 150.0, "hits": [0.29], "cancel": 0.46, "end": 0.7,
		"speed": 1.2, "lunge": 5.0, "knockback": 0.0, "launch": 0.0, "stop": 0.07, "shake": 0.28, "hop": [0.28, 0.58, 1.5]},
	"EA": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.24], "cancel": 0.42, "end": 0.6,
		"speed": 1.0, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.2},
	"EV": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.24], "cancel": 0.42, "end": 0.6,
		"speed": 1.0, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.25},
	"VR": {"anim": "Ab_H", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.24], "cancel": 0.46, "end": 0.7,
		"speed": 1.2, "lunge": 3.0, "knockback": 0.0, "launch": 0.0, "stop": 0.06, "shake": 0.25},
	"VD": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.24], "cancel": 0.52, "end": 0.7,
		"speed": 1.0, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.06, "shake": 0.3},
	"OW": {"anim": "Ab_VS", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.39], "cancel": 0.58, "end": 0.82,
		"lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.08, "shake": 0.4},
	"TW": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.24], "cancel": 0.42, "end": 0.6,
		"speed": 1.2, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.25},
	"EF": {"anim": "Ab_LLH", "damage": 4.0, "range": 2.8, "arc": 90.0, "hits": [0.34], "cancel": 0.5, "end": 0.72,
		"speed": 1.2, "lunge": 2.0, "knockback": 0.0, "launch": 0.0, "stop": 0.07, "shake": 0.3},
	"IP": {"anim": "Ab_LLH", "damage": 4.0, "range": 2.8, "arc": 90.0, "hits": [0.34], "cancel": 0.5, "end": 0.8,
		"speed": 1.2, "lunge": 1.0, "knockback": 0.0, "launch": 0.0, "stop": 0.07, "shake": 0.3},
	"IJ": {"anim": "Ab_LH", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.2], "cancel": 0.3, "end": 0.8,
		"speed": 1.1, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.0, "shake": 0.0, "air": true, "climb": 2.4},
	"IS": {"anim": "Ab_VS", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.39], "cancel": 0.58, "end": 0.82,
		"speed": 1.2, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.1, "shake": 0.5, "big": true},
	"EM": {"anim": "Ab_AF", "damage": 6.0, "range": 3.0, "arc": 200.0, "hits": [0.51], "cancel": 0.68, "end": 0.85,
		"speed": 1.6, "lunge": 3.0, "knockback": 3.0, "launch": 0.0, "stop": 0.12, "shake": 0.5, "big": true},
	# Light after Updraft Lash (L H L): an air slash. He stays up with the foe
	# the lash threw (`air`: holds the height he started at) and the cut
	# re-juggles it; right click off it is Live Wire's breaker (void_element.gd).
	"AL1": {"anim": "1H_Melee_Attack_Slice_Diagonal", "damage": 7.0, "range": 2.6, "arc": 170.0,
		"hits": [0.32], "cancel": 0.42, "end": 0.7, "lunge": 2.0, "knockback": 0.6, "launch": 5.0,
		"stop": 0.045, "shake": 0.12, "air": true, "climb": 0.4},
	# Light right out of a dash: long lunging stab, pouncing onto the foe
	# (a low leap that lands on the stab).
	"DL": {"anim": "1H_Melee_Attack_Stab", "damage": 12.0, "range": 2.8, "arc": 90.0,
		"hits": [0.3], "cancel": 0.5, "end": 0.7, "lunge": 16.0, "knockback": 7.0, "launch": 0.0,
		"stop": 0.07, "shake": 0.22, "hop": [0.03, 0.3, 0.6]},
}
# The named combos: landing one plays its tier's sound and shows its name
# above the hero. Moves not listed here (L1, L2, AL1) stay quiet. Also the
# pause menu's move list. tier: 1 string, 2 heavy route, 3 finisher.
const COMBOS := {
	"L3": {"name": "Triple Chop", "input": "L L L", "tier": 1},
	"VS": {"name": "Singularity", "input": "H H", "tier": 2},
	"VR": {"name": "Reap", "input": "H L", "tier": 1},
	"VD": {"name": "Black Tide", "input": "H L H", "tier": 2},
	"OW": {"name": "Overwhelm", "input": "hold H", "tier": 2},
	"TW": {"name": "Tow Line", "input": "Dash H", "tier": 2},
	"EC": {"name": "Updraft Lash", "input": "L H", "tier": 1},
	"EE": {"name": "Live Wire", "input": "L H H", "tier": 2},
	"EW": {"name": "Live Wire", "input": "L H L H", "tier": 3},
	"IP": {"name": "Frost Spear", "input": "L L H", "tier": 1},
	"IS": {"name": "Deep Freeze", "input": "L L H L H", "tier": 3},
	"EF": {"name": "Harpoon", "input": "Dash L H", "tier": 1},
	"EA": {"name": "Ice Cube", "input": "Dash L H H", "tier": 2},
	"EM": {"name": "Molten Palm", "input": "L L L H", "tier": 1},
	"EV": {"name": "Undertow", "input": "L L L H H", "tier": 2},
	"DL": {"name": "Dash Stab", "input": "Dash > L", "tier": 1},
}
# Combo breakers (VOID_ELEMENT.BREAKERS, timed finishers). The move leaps into the air at `leap`
# (fraction of its anim), hops `back` m while rising `height` m over `rise` s,
# hurls `spikes` spikes onto a zone `zone` m ahead (spread `spread`), and a
# cue rings that zone: press heavy between `open` and `close` s after take-off
# (rings meet at `sweet`; within `perfect` of it = PERFECT, x`perfect_mult`)
# to dive onto it in `dive` s, detonating the spikes and hitting `radius` for
# `damage`. Too early locks it out; no press = he floats down in `fall` s.
# The breaker window plays in slow motion (BREAKER_FOCUS time scale, camera
# pushed in to BREAKER_FOCUS_ZOOM), and a perfect press freezes the frame for
# BREAKER_PERFECT_STOP real s before the dive.
const BREAKER_FOCUS := 0.6
const BREAKER_FOCUS_ZOOM := 0.86
const BREAKER_PERFECT_STOP := 0.07
# Forgiving presses: a heavy in the first BREAKER_SPILL s after take-off is the
# ender's own mashed press spilling over and is ignored (no lockout), and one
# within BREAKER_EARLY s before `open` is held and fires as the window opens
# (a normal hit). Only a press between the two locks the breaker out.
const BREAKER_SPILL := 0.12
const BREAKER_EARLY := 0.08
const BREAKER_QUAKE := preload("res://scripts/breaker_quake.gd")
const BREAKER_CUE := preload("res://scripts/breaker_cue.gd")
const BREAKER_PROMPT := preload("res://scripts/breaker_prompt.gd")
const CAST_SFX_DB := -11.0
# Names of the moves that aren't combos, for the combo guide.
const MOVE_NAMES := {"L1": "Slice", "L2": "Hurl", "AL1": "Air Slash", "IJ": "Vault"}
# After landing a combo this many times in a run, the guide stops hinting it
# as a follow-up (it still shows as a row).
const GUIDE_LEARNED := 6
const COMBO_TIER_COLORS := [Color(0.95, 0.92, 0.85), Color(1.0, 0.75, 0.3), Color(1.0, 0.45, 0.15)]
const COMBO_TIER_SFX := ["combo_1", "combo_2", "combo_3"]
const ENDER_HITSTOP := 0.025  # extra hitstop per tier when a named combo's ender lands
const ENDER_ZOOM := 0.035  # camera push-in per tier on a combo ender
const RANK_COLORS: Dictionary = preload("res://scripts/hud.gd").RANK_COLORS
const LAST_KILL_SLOWMO := 0.55  # real seconds of slow motion on the fight's final blow
const COMBO_SFX_DB := -9.0
const LIGHT_CHAIN := ["L1", "L2", "L3"]
const VOID_GRAB := preload("res://scripts/void_grab.gd")
const VOID_ARM := preload("res://scripts/void_arm.gd")
const HERETIC_RIG := preload("res://scripts/heretic_rig.gd")
const PULL_INVULN := 0.8  # s, on the tentacle (void_grab.gd)
const SWING_COOLDOWN := 1.5  # s between presses of R
const FLING_ACCEL_MULT := 0.2  # how much grip he has flying off a swing
# Charging (hold heavy from neutral): release before CHARGE_TIME for the
# normal spin (H), after it for the charged slam (CH). You can creep while
# charging at CHARGE_MOVE_MULT speed; dash cancels the charge.
const CHARGE_TIME := 0.8
const CHARGE_MOVE_MULT := 0.35
const CHARGE_COLOR := Color(1.0, 0.85, 0.45)
const AWAKEN_BURST_RADIUS := 7.0  # the activation shockwave blows foes back this far
const AWAKEN_BURST_DAMAGE := 10.0
const AWAKEN_COLOR := Color(1.0, 0.78, 0.3)  # Awakening's ancestral gold: light, rim, trails, burst

var hp := max_hp
var state := State.MOVE
var awakened := false
var model: Node3D
var _coats: Array[Node3D] = []  # ComicLook.infuse_axes for the current element
var rank_ups := 0  # style rank climbs that burst at the hero (autotest)
var _rank_i := 0  # current style rank as a step above D (Game.RANKS)
var last_kills := 0  # fights ended with the slow-motion final blow (autotest)
var anim: AnimationPlayer

var _state_t := 0.0
var _move_id := ""
var _move: Dictionary = {}
var _move_len := 1.0
var _hits_done := 0
var _connected := false  # the current move has hit something (combo breakers need it)
var _hop_y0 := 0.0  # model height the current move started at (MOVES `hop`)
var _hop_air := false  # off the ground this move (for the landing dust)
var _hop_peak := 0.0  # highest the model got this time up (scales the landing slam)
# Landing slams scale with the fall: shake, ring and dust grow from a 0.4 m hop
# up to SLAM_FULL_HEIGHT (the top of the air string), by up to SLAM_SCALE.
const SLAM_FULL_HEIGHT := 2.4
const SLAM_SCALE := 2.0
# Plunge: a move started in the air that comes down onto its hit (L H H off
# the launcher, Triple Chop off Sky Rend) deals +PLUNGE_PER_M damage per metre
# it started above 0.4 m, so the air string pays for going high (2.6 m: +33%).
const PLUNGE_PER_M := 0.15
# Juggle tracking: a move started in the air (the air slashes, a plunge) turns
# to the nearest airborne foe within AIR_HOME_RANGE and lunges far enough to
# reach it (`_air_home`), so a launched foe that drifted doesn't make the
# string whiff. AIR_HOME_MAX caps the lunge speed.
const AIR_HOME_RANGE := 5.5
## Mouse aim, the comic hero only (_mouse_aiming). He faces the cursor while free and turns toward
## it at a limited rate through a combo, so a string can be redirected but not spun on the spot.
const AIM_HEIGHT := 0.8  # m: the cursor is read on this plane, about where a foe's body is
const AIM_DEAD_ZONE := 0.35  # m round him where the cursor stops steering, or he'd spin
const AIM_ASSIST_MOUSE_ANGLE := 25.0  # deg: the cursor says where, so the soft lock is narrower
const COMBO_REDIRECT := 55.0  # deg a chained move may turn as it starts
const COMBO_TURN_WINDUP := 420.0  # deg/s before a move's first hit
const COMBO_TURN_ACTIVE := 140.0  # deg/s from then on
const AIR_HOME_MAX := 22.0
# Air dash: dashing out of the air slash while at least AIR_DASH_MIN up keeps
# him at that height (the press after it is Dash Stab / Tow Line as on the floor).
const AIR_DASH_FROM := ["AL1"]
const AIR_DASH_MIN := 0.6
# One air dash per trip up (reset on landing), and `climb` stops at
# AIR_MAX_HEIGHT, so dash-slash loops can't keep him up or lift him forever.
const AIR_DASHES := 1
const AIR_MAX_HEIGHT := 2.8
# The air dash's cut: a giant spectral axe (spirit_echo) rides with him at his
# height and sweeps through the dash, nicking what it passes.
const AIR_DASH_CUT := {"damage": 3.0, "radius": 3.0, "arc": 150.0, "time": 0.16}
var _swoosh_flip := false  # alternate swing direction each swoosh
var _chain_i := 0
var _chain_reset_t := 0.0
var _buffered := ""
var _buffer_t := 0.0
var _dash_buffer_t := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.FORWARD
var _post_dash_t := 0.0
var _air_dash := false  # this dash started up in the air string (AIR_DASH_*)
var _air_dashes := 0  # air dashes since he last touched the floor (AIR_DASHES)
var _awaken_t := 0.0
var _facing_yaw := 0.0
var _mouse_active := true  # false once a gamepad is the last thing touched
var _invuln_t := 0.0
var _anim_mult := 1.0
var _dmg_mult := 1.0
var _charged := false
var _charge_fx_t := 0.0
var _charge_light: OmniLight3D
var spikes := 0  # juggled foes spiked down (autotest)
var _last_combo := ""  # the last named combo landed (War Chant pays more for a new one)
var combos_landed := {}  # COMBOS id -> times landed this run (pause menu, run summary)
var last_hit_by := ""  # who landed the latest hit ("a rogue"), for the death recap
var callouts := 0  # combo callouts shown (autotest)
var last_callout_tier := 0  # (autotest screenshot)
var _callout: Label3D
var _callout_tw: Tween
var _callout_done := false
var _awaken_light: OmniLight3D
var _meshes: Array[Node] = []
var _awaken_rim: ShaderMaterial
var _trails: Array = []
const VOID_ELEMENT := preload("res://scripts/void_element.gd")
var _void: Node  # his grab and slam (void_grab.gd), the comic hero only
var _swing_cd := 0.0  # s until R swings again
var _dash_from := Vector3.ZERO  # where his last dash or swing began (void_element._tow)
var _swing_buffer_t := 0.0  # s left on a press of R
var _brk_alt := false  # the window's press was the other button: `alt` (void_element.BREAKERS)
var _brk_y0 := 0.0  # m up he was when a tentacle breaker began
var bot_alt := false  # the bot's window press takes `alt`
var _fling_t := 0.0  # s left flying off a swing
var _ready_t := 0.0  # comic hero: s left in the guard after a fight
var _fidget_t: float = ComicLook.FIDGET_EVERY  # comic hero: s until he next fidgets
var _fidget_i := 0
static var _kaykit_axe: Mesh  # the spirit casts' axe under the comic hero (see _axe_mesh)
var _orbit: Node3D
var _ghost_t := 0.0
var _since_dash := 99.0
var _perfect_this_dash := false

# Lets the autotest drive the hero without real input.
var bot_move := Vector3.ZERO

var bot_enabled := false
var breakers_landed := 0  # combo breakers (timed finishers) landed (autotest)
var breaker_perfects := 0
var _brk: Dictionary = {}  # the breaker in play (BREAKERS entry)
var _brk_id := ""
var _brk_phase := 0  # 0 rising / hanging, 1 diving, 2 falling (missed)
var _brk_press := -1.0  # s after take-off it was pressed (-1 none)
var _brk_locked := false
var _brk_held := false  # pressed just before `open`: dives as the window opens (BREAKER_EARLY)
var _brk_zone := Vector3.ZERO
var _brk_dir := Vector3.FORWARD
var _brk_dive_from := Vector3.ZERO
var _brk_cue: Node3D
var _brk_meteor: Node3D  # the fire round him on the way down (void_element.meteor_shell)
var _brk_focus := false  # the window's slow motion has started
var _brk_ended := ""  # how the last breaker's press went (breaker_window)
var _brk_prompt: Control  # the timing circle (breaker_prompt.gd), made on the first leap


func _ready() -> void:
	hp = max_hp
	Game.enemy_killed.connect(_on_enemy_killed)
	Game.combo_changed.connect(_on_combo_changed)
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	model = ComicLook.scene(ComicLook.HERETIC).instantiate()
	add_child(model)
	ComicLook.apply(model, ComicLook.HERETIC)
	Fx.outline(model)
	_meshes = model.find_children("*", "MeshInstance3D", true, false)
	_awaken_rim = Fx.rim_material().duplicate()
	for blade in ComicLook.hero_blades(model):
		_add_trail(blade)
	anim = model.find_child("AnimationPlayer", true, false)
	_coats = _coat_axes()  # after _meshes
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var void_arm := VOID_ARM.new()
	void_arm.setup(self, model, skel)
	void_arm.rest_form = "hand"  # a free tentacle at rest; weapons only form to strike
	void_arm.pops = false
	void_arm.shape("hand", false)
	HERETIC_RIG.new().setup(void_arm, skel)
	_void = VOID_GRAB.new()
	add_child(_void)
	_void.setup(self, void_arm, skel)
	for a in LOOPING:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR

	_awaken_light = OmniLight3D.new()
	_awaken_light.light_color = Color(1.0, 0.5, 0.15)
	_awaken_light.light_energy = 0.0
	_awaken_light.omni_range = 5.0
	_awaken_light.position.y = 1.2
	add_child(_awaken_light)
	_charge_light = OmniLight3D.new()
	_charge_light.light_color = CHARGE_COLOR
	_charge_light.light_energy = 0.0
	_charge_light.omni_range = 4.0
	_charge_light.position.y = 1.0
	add_child(_charge_light)
	_callout = Label3D.new()
	_callout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_callout.no_depth_test = true
	_callout.font_size = 84
	_callout.outline_size = 24
	_callout.pixel_size = 0.006
	_callout.outline_modulate = Color(0.1, 0.05, 0.1)
	_callout.visible = false
	add_child(_callout)
	_orbit = ELEMENTS.Orbit.new()
	_orbit.piece_size = ComicLook.HERO_ORBIT_SIZE
	add_child(_orbit)
	_orbit.setup(element(), false)

	health_changed.emit(hp, max_hp)
	_play("Idle")


func _add_trail(weapon: MeshInstance3D) -> void:
	var trail := TRAIL.new()
	add_child(trail)
	trail.setup(weapon)
	trail.color = _trail_rest_color()
	_trails.append(trail)


## The mesh spirit casts ghost. His axes are skinned in place, far from any
## usable origin, so his spirits throw KayKit's axe (AXE_SOURCE).
func _axe_mesh() -> Mesh:
	if _kaykit_axe == null:
		var kaykit: Node3D = load(AXE_SOURCE).instantiate()
		_kaykit_axe = (kaykit.find_child("1H_Axe", true, false) as MeshInstance3D).mesh
		kaykit.free()
	return _kaykit_axe


func _coat_axes() -> Array[Node3D]:
	return ComicLook.infuse_axes(model, element())


## What the rig calls a clip the game asks for.
func _clip_name(wanted: String) -> String:
	return ComicLook.clip(anim, ComicLook.HERETIC, wanted)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	# Fx.flash clears overlays on hit; put the Awakening rim back.
	if awakened:
		for mi: MeshInstance3D in _meshes:
			if mi.material_overlay == null:
				mi.material_overlay = _awaken_rim
	_read_input()

	if not is_on_floor():
		velocity.y -= 30.0 * delta
	else:
		velocity.y = 0.0

	match state:
		State.MOVE: _state_move(delta)
		State.ATTACK: _state_attack(delta)
		State.DASH: _state_dash(delta)
		State.HURT: _state_hurt(delta)
		State.CHARGE: _state_charge(delta)
		State.LEAP: _state_leap(delta)
		State.SWING: _void.travel_tick(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)

	move_and_slide()
	var air_hold := _air_dash and (state == State.DASH or (state == State.MOVE and _post_dash_t > 0.0))
	if state in [State.MOVE, State.DASH, State.HURT, State.CHARGE, State.DEAD] and model.position.y > 0.0 and not air_hold:
		model.position.y = move_toward(model.position.y, 0.0, 16.0 * delta)  # out of a hop
	if state != State.ATTACK and (model.position.x != 0.0 or model.position.z != 0.0):
		model.position.x = move_toward(model.position.x, 0.0, 6.0 * delta)  # back under him
		model.position.z = move_toward(model.position.z, 0.0, 6.0 * delta)
	if model.position.y < 0.05:
		_air_dashes = 0  # back on the floor: the air dash comes back
	var swinging: bool = (state == State.ATTACK and _state_t * anim_speed * _anim_mult / _move_len < _move.cancel)
	if swinging and VOID_ELEMENT.is_element_move(_move_id):
		swinging = false  # the element is the swing (void_element.gd)
	for trail in _trails:
		trail.emitting = swinging
	model.rotation.y = lerp_angle(model.rotation.y, _facing_yaw, 1.0 - exp(-25.0 * delta))


func _tick_timers(delta: float) -> void:
	_state_t += delta
	_ready_t -= delta
	_fidget_t -= delta
	_since_dash += delta
	_buffer_t -= delta
	_dash_buffer_t -= delta
	_dash_cd -= delta
	_swing_cd -= delta
	_swing_buffer_t -= delta
	_post_dash_t -= delta
	_fling_t -= delta
	_invuln_t -= delta
	_chain_reset_t -= delta
	if _buffer_t <= 0.0:
		_buffered = ""
	if _chain_reset_t <= 0.0 and state != State.ATTACK:
		_chain_i = 0
	if awakened:
		_awaken_t -= delta
		Game.add_awakening(-Game.AWAKEN_MAX / _awaken_len() * delta)
		if _awaken_t <= 0.0:
			_set_awakened(false)


func _read_input() -> void:
	if state == State.DEAD:
		return
	if Input.is_action_just_pressed("attack_light"):
		_buffered = "light"
		_buffer_t = input_buffer
	elif Input.is_action_just_pressed("attack_heavy"):
		_buffered = "heavy"
		_buffer_t = input_buffer
	if Input.is_action_just_pressed("traverse"):
		_swing_buffer_t = input_buffer
	if Input.is_action_just_pressed("dash"):
		_dash_buffer_t = input_buffer
	if Input.is_action_just_pressed("awaken"):
		try_awaken()


## The last device touched decides, so a gamepad goes back to facing the way he runs.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_active = true
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		_mouse_active = false


func _mouse_aiming() -> bool:
	return _mouse_active and not bot_enabled and DisplayServer.get_name() != "headless"


## Flat direction from him to the cursor; zero with no camera or a cursor on top of him.
func _mouse_dir() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var at := get_viewport().get_mouse_position()
	var ray := cam.project_ray_normal(at)
	if absf(ray.y) < 0.001:
		return Vector3.ZERO
	var from := cam.project_ray_origin(at)
	var hit := from + ray * ((global_position.y + AIM_HEIGHT - from.y) / ray.y)
	var to := hit - global_position
	to.y = 0.0
	return to.normalized() if to.length() > AIM_DEAD_ZONE else Vector3.ZERO


## _facing turned at most `max_deg` toward `want`.
func _turned(want: Vector3, max_deg: float) -> Vector3:
	var yaw := rotate_toward(_facing_yaw, atan2(want.x, want.z), deg_to_rad(max_deg))
	return Vector3(sin(yaw), 0.0, cos(yaw))


func _input_dir() -> Vector3:
	if bot_enabled:
		return bot_move
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return Vector3(v.x, 0.0, v.y)


func facing_dir() -> Vector3:
	return _facing()


func _facing() -> Vector3:
	return Vector3(sin(_facing_yaw), 0.0, cos(_facing_yaw))


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		_facing_yaw = atan2(dir.x, dir.z)


# --- States -----------------------------------------------------------------

func _state_move(delta: float) -> void:
	var dir := _input_dir()
	var speed := move_speed * (1.2 if awakened else 1.0)
	var target := dir * speed
	var grip := accel * (FLING_ACCEL_MULT if _fling_t > 0.0 else 1.0)
	velocity.x = move_toward(velocity.x, target.x, grip * delta)
	velocity.z = move_toward(velocity.z, target.z, grip * delta)
	_face(_mouse_dir() if _mouse_aiming() else dir)
	_play_locomotion(dir)

	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0:
		_start_dash()
	elif _try_swing():
		pass
	elif _buffered == "heavy" and _next_move("heavy") in ["H", VOID_ELEMENT.NEUTRAL] and Input.is_action_pressed("attack_heavy"):
		_start_charge()
	elif _buffered != "":
		_start_attack(_next_move(_buffered))


## Idle or a run. The comic hero has a clip per direction relative to where he faces; they share
## one cycle, so a change of clip carries on from the same step.
func _play_locomotion(dir: Vector3) -> void:
	if dir.length() <= 0.1:
		_comic_stand()
	else:
		_fidget_t = ComicLook.FIDGET_EVERY
		var clip := ComicLook.run_clip(dir, _facing(), anim.current_animation)
		if clip == anim.current_animation:
			return
		var step := anim.current_animation_position if ComicLook.is_run_clip(anim.current_animation) else 0.0
		_play(clip, 0.12)
		anim.seek(step, true)


## Standing still: on guard for a moment after a fight, then at ease, fidgeting now and then.
func _comic_stand() -> void:
	if _ready_t > 0.0:
		_fidget_t = ComicLook.FIDGET_EVERY
		_play(ComicLook.HERO_READY, 0.15)
	elif anim.current_animation in ComicLook.HERO_FIDGETS:
		return  # plays out; when it ends current_animation clears
	elif _fidget_t <= 0.0:
		_fidget_t = ComicLook.FIDGET_EVERY
		_play(ComicLook.HERO_FIDGETS[_fidget_i], 0.25)
		_fidget_i = (_fidget_i + 1) % ComicLook.HERO_FIDGETS.size()
	else:
		_play("Idle", 0.3)


func _start_charge() -> void:
	_buffered = ""
	_charged = false
	_charge_fx_t = 0.0
	_set_state(State.CHARGE)
	_play("2H_Melee_Idle", 0.1)


func _state_charge(delta: float) -> void:
	var dir := _input_dir()
	var target := dir * move_speed * CHARGE_MOVE_MULT
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	_face(_mouse_dir() if _mouse_aiming() else dir)
	var k := clampf(_state_t / CHARGE_TIME, 0.0, 1.0)
	_charge_light.light_energy = k * 2.5
	_charge_fx_t -= delta
	if _charge_fx_t <= 0.0:
		_charge_fx_t = 0.12
		Fx.burst(get_parent(), global_position + Vector3.UP * 0.2, CHARGE_COLOR, 4 + int(k * 8), 2.0 + k * 3.0,
			0.08, 0.35, Vector3.UP, 30.0, 2.0, 0.9 - k * 0.4)
	if k >= 1.0 and not _charged:
		_charged = true
		Fx.ring(get_parent(), global_position, Color(CHARGE_COLOR, 0.9), 2.2, 0.25)
		Fx.flash(model)
		Game.sfx("perfect", -6.0, 0.0)
	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0:
		_start_dash()
	elif not Input.is_action_pressed("attack_heavy"):
		if _void != null:
			_start_attack(VOID_ELEMENT.CHARGED if _charged else VOID_ELEMENT.NEUTRAL)
		else:
			_start_attack("CH" if _charged else "H")


## The move's height off the floor at progress `t`: comes down from where it
## started by `land` (first hit), plus its own `hop` arc.
func _hop(t: float) -> void:
	var y := 0.0
	if _move.get("air", false):  # air move: hold the height it started at
		# `climb`: rise this much more by the hit, so each air cut goes higher.
		var cap := AIR_MAX_HEIGHT
		var climb: float = minf(_move.get("climb", 0.0), maxf(0.0, cap - _hop_y0))
		var up: float = climb * smoothstep(0.0, _move.hits[0], t)
		y = minf(_hop_y0 + up + sin(t * PI) * 0.15, cap + 0.15)
	elif _hop_y0 > 0.0:
		var land: float = _move.get("land", _move.hits[0])
		var k := clampf(t / maxf(land, 0.01), 0.0, 1.0)
		y = _hop_y0 * (1.0 - k * k)  # accelerating down onto the hit
	if _move.has("hop"):
		var h: Array = _move.hop
		if t > h[0] and t < h[1]:
			var k: float = (t - h[0]) / (h[1] - h[0])
			y += h[2] * 4.0 * k * (1.0 - k)
	if y > 0.4:
		_hop_air = true
		_hop_peak = maxf(_hop_peak, y)
	elif _hop_air and y < 0.05:
		_hop_air = false  # landed onto the hit: a slam
		_land_slam(_hop_peak)
		_hop_peak = 0.0
	model.position.y = y


## Damage multiplier for the current move's plunge (see PLUNGE_PER_M): only
## for moves that start in the air and land, and only on their first hit.
func plunge_mult() -> float:
	if _move.get("air", false) or _hits_done > 1:
		return 1.0
	return 1.0 + PLUNGE_PER_M * maxf(0.0, _hop_y0 - 0.4)


## Landing from a hop: dust, a ring in the hero's colour and a shake, all
## bigger the further he fell (an air-string Triple Chop lands hardest).
func _land_slam(peak: float) -> void:
	var k := 1.0 + (SLAM_SCALE - 1.0) * clampf((peak - 0.4) / (SLAM_FULL_HEIGHT - 0.4), 0.0, 1.0)
	Fx.dust(get_parent(), global_position, int(6 * k), 0.5 * k)
	if not VOID_ELEMENT.is_element_move(_move_id):  # (his tentacle moves land on him: it hid them)
		Fx.ring(get_parent(), global_position + _facing() * 0.8, Color(_fx_color(), 0.8), 2.2 * k, 0.22)
	Game.shake(0.12 * k)


func _state_attack(delta: float) -> void:
	var t := _state_t * anim_speed * _anim_mult / _move_len  # normalized progress
	if _void != null:
		_void.attack_tick(t, delta)
	if _mouse_aiming() and not _hop_air:  # (in the air _air_home has him)
		_face(_turned(_aim_want(), (COMBO_TURN_WINDUP if _hits_done == 0 else COMBO_TURN_ACTIVE) * delta))
	# Lunge decays quickly so attacks feel snappy, not slidey.
	var lunge: float = _move.lunge * maxf(0.0, 1.0 - t * _move.get("decay", 3.0))
	var fwd := _facing()
	velocity.x = fwd.x * lunge
	velocity.z = fwd.z * lunge
	if _move_id in VOID_ELEMENT.SPEAR_RUN and _hits_done == 0:
		VOID_ELEMENT.run_to_spear(self, delta)

	_hop(t)
	var hits: Array = _move.hits
	while _hits_done < hits.size() and t >= hits[_hits_done]:
		_hits_done += 1
		_do_hit()
	var brk := _breaker_for(_move_id)
	if not brk.is_empty() and _connected and t >= _move.get("leap", brk.leap):  # (a whiff plays out normally)
		_start_leap(_move_id, brk)
		return

	# Dash cancels anything once the first hit has come out (or early on whiff).
	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0 and (_hits_done > 0 or t > 0.2):
		_start_dash()
		return
	if (_hits_done > 0 or t > 0.2) and _try_swing():
		return
	if t >= _move.cancel and _buffered != "":
		_start_attack(_next_move(_buffered))
		return
	if t >= _move.end:
		_chain_reset_t = 0.35
		_set_state(State.MOVE)


func _state_dash(delta: float) -> void:
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = afterimage_interval
		Fx.afterimage(get_parent(), model, Color(_fx_color(), 0.45))
	velocity.x = _dash_dir.x * dash_speed
	velocity.z = _dash_dir.z * dash_speed
	if _state_t >= dash_time:
		velocity.x *= 0.3
		velocity.z *= 0.3
		_post_dash_t = 0.3
		_set_state(State.MOVE)


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	if _dash_buffer_t > 0.0 and _state_t > 0.12 and _dash_cd <= 0.0:
		_start_dash()  # dash out of hitstun = burst escape
	elif _state_t >= 0.35:
		_set_state(State.MOVE)


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0
	if _void != null:
		_void.on_state(s)
	if s != State.CHARGE:
		_charge_light.light_energy = 0.0


## Combo breaker, part 1: leap up and back, hurl spikes onto the zone ahead,
## ring it with the timing cue (VOID_ELEMENT.BREAKERS via _breaker_for).
func _start_leap(id: String, entry: Dictionary) -> void:
	_brk_id = id
	_brk = entry
	_brk_phase = 0
	_brk_press = -1.0
	_brk_locked = false
	_brk_held = false
	_brk_cue = null
	_brk_focus = false
	_brk_ended = ""
	_brk_alt = false
	_brk_y0 = model.position.y
	_breaker_prompt()
	_brk_dir = _facing()
	var ahead := minf(_brk.zone, _clear_ahead(_brk_dir, _brk.zone) + 0.3)
	_brk_zone = Vector3(global_position.x, 0.0, global_position.z) + _brk_dir * ahead
	_buffered = ""
	_set_state(State.LEAP)
	_play("Jump_Start", 0.05, true)
	Game.sfx("dash", -4.0, 0.05)
	Fx.dust(get_parent(), global_position, 10, 0.8)
	if not _brk.has("tentacle"):  # (it sat over him and hid the tentacles going out)
		Fx.ring(get_parent(), global_position, Color(_fx_color(), 0.8), 1.6, 0.25)
	if _brk.has("tentacle"):
		_void.seize(_brk)
		_brk_aim()
	elif not _brk.has("dash"):  # he kicks off hard enough to crack the floor
		BREAKER_QUAKE.crater(get_parent(), global_position, element(), 1.4, false)


## Some of his breakers land where the string put them, however far off that is: Meteor Fall on whoever
## the tentacle has hold of, the dark ones `short` of dark_spot.
func _brk_aim() -> void:
	var spot: Vector3
	if _brk.has("at_spot"):
		spot = _void.dark_spot
	elif _brk.has("meteor") and not _void.held_foes().is_empty():
		spot = Vector3(_void.held_foes()[0].global_position.x, 0.0, _void.held_foes()[0].global_position.z)
	else:
		return
	var to := spot - Vector3(global_position.x, 0.0, global_position.z)
	if to.length() > 0.1:
		_brk_dir = to.normalized()
	var short: float = _brk.get("short", 0.0)
	_brk_zone = spot - _brk_dir * minf(short, _clear_ahead(-_brk_dir, short) + to.length())  # (back off if he's already that close)
	if is_instance_valid(_brk_cue):
		_brk_cue.global_position = spot


## Combo breaker, part 2: rise and hang, throw, wait for the timed press, then
## dive (pressed in the window) or float down (missed / locked out).
func _state_leap(delta: float) -> void:
	var b := _brk
	var t := _state_t
	_invuln_t = maxf(_invuln_t, 0.12)  # airborne: untouchable
	velocity.x = 0.0
	velocity.z = 0.0
	# Dash cancels anything, a breaker's hang included. (Not for the autotest
	# bot: its dodge presses would throw away the breakers it's there to test;
	# he's untouchable in the hang anyway.)
	if _brk_phase == 0 and _dash_buffer_t > 0.0 and _dash_cd <= 0.0 and not bot_enabled:
		_leap_dash_out()
		return
	if b.has("tentacle"):
		_void.seized_tick(_brk_phase, t, b)
	if _brk_phase == 0:
		_brk_aim()
		if t < b.rise:  # hop back (forward if `back` < 0) while rising
			var k: float = t / b.rise
			velocity.x = -_brk_dir.x * b.back / b.rise
			velocity.z = -_brk_dir.z * b.back / b.rise
			model.position.y = lerpf(_brk_y0, b.height, 1.0 - pow(1.0 - k, 3.0))
		else:
			model.position.y = b.height + sin((t - b.rise) * 9.0) * 0.06  # hangs
			if anim.current_animation != "Jump_Idle":
				_play("Jump_Idle", 0.15)
		_face(_brk_dir)
		if t >= b.cue and _brk_cue == null:
			_brk_cue = BREAKER_CUE.new()
			_brk_cue.color = _brk_color()
			_brk_cue.crisp = true
			_brk_cue.open = b.open - b.cue
			_brk_cue.sweet = b.sweet - b.cue
			_brk_cue.close = b.close - b.cue
			get_parent().add_child(_brk_cue)
			_brk_cue.global_position = _brk_zone
		if not _brk_locked and not _brk_focus and t >= b.open:
			_brk_focus = true  # the window opens: slow down, push in
			Game.hitstop((b.close - b.open) / BREAKER_FOCUS, BREAKER_FOCUS)
			if Game.camera_rig:
				Game.camera_rig.punch(BREAKER_FOCUS_ZOOM, (b.close - b.open) / BREAKER_FOCUS)
			Game.sfx("heartbeat", -6.0, 0.0)
			# The war cry marks the window: he roars in the slowed hang.
			Game.sfx("war_cry", -3.0, 0.06)
			BREAKER_QUAKE.war_cry(get_parent(), global_position + Vector3.UP * (model.position.y + 1.5), _brk_color(), _brk_element(), false)  # (its bubble hid him and filled the floor)
		if not _brk_locked and not _brk_held and _breaker_pressed(t):
			if t < BREAKER_SPILL:
				pass  # the ender's own press spilling over: ignored
			elif t >= b.open - BREAKER_EARLY and t < b.open:
				_brk_held = true  # a hair early: dives as the window opens
			elif t < b.open:
				_brk_locked = true  # too early: no breaker this time
				_brk_ended = "lock"
				if is_instance_valid(_brk_cue):
					_brk_cue.lock()
				Game.sfx("player_hurt", -14.0, 0.0)
			else:
				_brk_press = t
				_start_dive()
				return
		if _brk_held and t >= b.open:
			_brk_press = t
			_start_dive()
			return
		if t > b.close:
			if _brk_ended == "":
				_brk_ended = "miss"
			_void.release_seized()
			_brk_phase = 2
			_state_t = 0.0
			_play("Jump_Idle", 0.1)
	elif _brk_phase == 1:
		var k: float = clampf(t / b.dive, 0.0, 1.0)
		var to := _brk_zone - _brk_dive_from
		to.y = 0.0
		velocity.x = to.x / b.dive
		velocity.z = to.z / b.dive
		model.position.y = b.height * (1.0 - k * k)
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.02
			if b.has("meteor"):  # (the tail on the shell does the work: this is what comes off it)
				Fx.burst(get_parent(), model.global_position + Vector3.UP, VOID_ELEMENT.METEOR_HOT, 5, 3.0, 0.14, 0.3, Vector3.UP, 60.0)
			else:  # the dive comes down like a comet in his element
				_comet(_brk_color(), _brk_element())
		if is_instance_valid(_brk_meteor):
			_brk_meteor.global_position = model.global_position + Vector3.UP
		if k >= 1.0:
			_breaker_impact()
	else:
		var k: float = clampf(t / b.fall, 0.0, 1.0)
		model.position.y = b.height * (1.0 - k * k)
		if k >= 1.0:
			_end_leap()
			Fx.dust(get_parent(), global_position, 8, 0.6)


## The breaker press this frame: heavy, light where the breaker has an `alt`, or the autotest bot at the
## sweet spot. Which one it was is in _brk_alt.
func _breaker_pressed(t: float) -> bool:
	if bot_enabled:
		_brk_alt = bot_alt
		return t >= _brk.sweet
	if _brk.has("alt") and Input.is_action_just_pressed("attack_light"):
		_brk_alt = true
		return true
	_brk_alt = false
	return Input.is_action_just_pressed("attack_heavy")


func _start_dive() -> void:
	if _brk_alt and _brk.has("alt"):
		_brk.merge(_brk.alt, true)
	if _brk.has("cubes"):
		_void.freeze_seized()
	if _brk.has("maw"):
		_void.dark_maw = VOID_ELEMENT.DARK.maw(get_parent(), _void.dark_spot, VOID_ELEMENT.MAW_RADIUS)
	if _brk.has("abyss") and is_instance_valid(_void.dark_bind):
		_void.dark_bind.sink = VOID_ELEMENT.ABYSS_SINK
	if _brk.has("press"):
		_void.aim_crush()
	_brk_aim()
	if _brk.has("meteor"):
		var run := _brk_zone - Vector3(global_position.x, 0.0, global_position.z)
		_brk_meteor = VOID_ELEMENT.meteor_shell(get_parent(), Vector3(run.x, -_brk.height, run.z))
		_brk_meteor.global_position = model.global_position + Vector3.UP
	_brk_phase = 1
	_state_t = 0.0
	_brk_dive_from = global_position
	var perfect: bool = absf(_brk_press - _brk.sweet) <= _brk.perfect
	_brk_ended = "perfect" if perfect else "hit"
	if is_instance_valid(_brk_cue):
		_brk_cue.hit(perfect)
	if _brk_focus:
		Game.end_slowmo()
	if perfect:
		Game.hitstop(BREAKER_PERFECT_STOP, 0.05)
		Game.sfx("perfect", -4.0, 0.0)
	_play("Ab_VS", 0.03, true)
	anim.seek(anim.current_animation_length * 0.3, true)
	Game.sfx("ult", -6.0, 0.0)
	Fx.flash(model)
	if Game.camera_rig:
		Game.camera_rig.punch(0.85, 0.3)


## The dive lands: detonate the spikes, blast the zone, name the breaker.
func _breaker_impact() -> void:
	var b := _brk
	var el := _brk_element()
	var at := Vector3(global_position.x, 0.0, global_position.z)
	var perfect: bool = absf(_brk_press - b.sweet) <= b.perfect
	var mult: float = (b.perfect_mult if perfect else 1.0) * _cast_power()
	if is_instance_valid(_brk_meteor):
		_brk_meteor.queue_free()
	VOID_ELEMENT.breaker_impact(self, b, at, _void.held_foes() if b.has("cubes") or b.has("rip") else _void.slam_seized(), mult)
	# Barbaric landing: the floor breaks (the element erupts under each foe already).
	if not b.has("press") and not b.has("at_spot"):  # (its ice buried the cubes as they left; the dark ones have their own)
		BREAKER_QUAKE.crater(get_parent(), at, el, maxf(b.radius, 2.4), true, perfect)
	Game.sfx("quake", -2.0 if perfect else -5.0, 0.05)
	if b.radius > 0.0:
		ELEMENTS.hit_area(get_tree(), at, b.radius, b.damage * _dmg_mult * mult, b.launch, true, "breaker")
	Game.hitstop(0.18 if perfect else 0.12, 0.05)
	Game.shake(0.8 if perfect else 0.6)
	if Game.camera_rig:
		Game.camera_rig.punch(0.75 if perfect else 0.82, 0.35)
	Game.add_awakening(b.awaken_perfect if perfect else b.awaken)
	breakers_landed += 1
	if perfect:
		breaker_perfects += 1
	_breaker_callout(breaker_name(), perfect)
	if bot_enabled:
		print("[autotest] combo_breaker #%d %s perfect=%s" % [breakers_landed, _brk_id, perfect])
	_end_leap()


func _breaker_callout(text: String, perfect: bool) -> void:
	Game.sfx(COMBO_TIER_SFX[2], COMBO_SFX_DB, 0.0)
	_callout.text = text + ("\nPERFECT" if perfect else "")
	_callout.modulate = COMBO_TIER_COLORS[2] if perfect else _fx_color().lerp(Color.WHITE, 0.3)
	_callout.position = Vector3(0.0, 2.9, 0.0)
	_callout.scale = Vector3.ONE * 0.6
	_callout.visible = true
	if _callout_tw:
		_callout_tw.kill()
	_callout_tw = _callout.create_tween()
	_callout_tw.tween_property(_callout, "scale", Vector3.ONE * (1.35 if perfect else 1.15), 0.08)
	_callout_tw.tween_property(_callout, "scale", Vector3.ONE * (1.15 if perfect else 1.0), 0.08)
	_callout_tw.parallel().tween_property(_callout, "position:y", 3.3, 0.7).set_ease(Tween.EASE_OUT)
	_callout_tw.tween_property(_callout, "modulate:a", 0.0, 0.3).set_delay(0.5)
	_callout_tw.tween_callback(_callout.hide)


## Dash out of a breaker's hang (before the press): the breaker is off, what
## he holds drops, the floor cue goes, the slow motion ends and he dashes. The
## prompt shows it as a miss.
func _leap_dash_out() -> void:
	_brk_ended = "miss"
	_void.release_seized()
	if is_instance_valid(_brk_cue):
		_brk_cue.queue_free()
	if _brk_focus:
		Game.end_slowmo()
	velocity = Vector3.ZERO
	_brk_cue = null
	_chain_i = 0
	_set_state(State.MOVE)  # (the model settles from the hang during the dash)
	_start_dash()


func _end_leap() -> void:
	_void.release_seized()
	_buffered = ""  # the press that dove him isn't a grab as well
	velocity = Vector3.ZERO  # (the dive speed would carry on)
	model.position.y = 0.0
	_brk_cue = null
	_chain_i = 0
	_set_state(State.MOVE)


# --- Actions ----------------------------------------------------------------

func _next_move(kind: String) -> String:
	return _routed(kind, _move_id, state == State.ATTACK, _chain_i, _post_dash_t > 0.0)


## void_route(), plus the vault: while his frost spear stands, either press takes him up over it.
func _routed(kind: String, from: String, attacking: bool, chain: int, post_dash: bool) -> String:
	if VOID_ELEMENT.vaults(get_tree(), from, attacking, post_dash):
		return "IJ"
	return void_route(kind, from, attacking, chain, post_dash)


## The move a "light" or "heavy" press starts. `from` is the move playing (or the last one), `attacking`
## whether it's still going, `chain` the light chain position, `post_dash` just out of a dash. The combo
## guide asks this too (with made-up states to look one press ahead), so they always agree.
## Lights run the weapons: axe, spear, hammer. H (right click) is the tentacle:
## what it does off a weapon depends on that weapon's element, on its own it's the grab (void_element.gd).
## L off Updraft Lash goes into the air, L off the grab flails what it holds, H off a dash is Tow Line.
static func void_route(kind: String, from: String, attacking: bool, chain: int, post_dash: bool) -> String:
	if kind == "light":
		if attacking and VOID_ELEMENT.LIGHT_AFTER.has(from):
			return VOID_ELEMENT.LIGHT_AFTER[from]
		return "DL" if post_dash else LIGHT_CHAIN[chain % LIGHT_CHAIN.size()]
	if post_dash and not attacking:
		return VOID_ELEMENT.DASH_MOVE
	return VOID_ELEMENT.heavy_after(from, attacking)


## The air dash's spectral axe (AIR_DASH_CUT): a spirit_echo parented to the
## hero at the model's height, so it travels with the dash, sweeping round
## the dash direction. Grows with the chain like the casts.
func _air_dash_cut() -> void:
	var c: Dictionary = AIR_DASH_CUT
	var echo = _spirit(SPIRIT_ECHO.new(), c, element())
	echo.fwd = _dash_dir
	echo.arc_deg = c.arc
	echo.radius = c.radius * _cast_grow()
	echo.delay = 0.0
	echo.time = c.time
	add_child(echo)
	echo.position = Vector3(0.0, model.position.y, 0.0)


## Whether a dash now would be an air dash (AIR_DASH_*).
func _can_air_dash() -> bool:
	return _move_id in AIR_DASH_FROM and model.position.y >= AIR_DASH_MIN and _air_dashes < AIR_DASHES


## What dash-then-light starts from here (the combo guide's dash row): Dash Stab, in the air too.
func dash_light() -> String:
	return void_route("light", _move_id, false, _chain_i, true)


## Light chain position after `id` starts.
static func chain_after(id: String) -> int:
	if id in LIGHT_CHAIN:
		return (LIGHT_CHAIN.find(id) + 1) % LIGHT_CHAIN.size()
	if id == "DL":
		return 1  # a dash stab flows into L2
	return VOID_ELEMENT.CHAIN.get(id, 0)


## What the combo guide shows right now: one row per input that continues the
## string ("light", "heavy", "dash" = dash then light), each with the move it
## starts and the best named combo one more press past it, plus `pause` when
## waiting for the move to finish first starts a different named combo.
## Empty when there's no string to continue.
func combo_options() -> Array:
	var attacking := state == State.ATTACK
	var dashing := state == State.DASH or _post_dash_t > 0.0
	var live := attacking or dashing or state == State.CHARGE or (state == State.MOVE and _chain_i > 0)
	if not live:
		return []
	if state == State.CHARGE:
		return [_option("heavy", VOID_ELEMENT.CHARGED, true)]
	var rows := []
	var kinds: Array[String] = ["light", "heavy"]
	for kind: String in kinds:
		var id := _routed(kind, _move_id, attacking, _chain_i, dashing)
		if kind == "heavy" and id == VOID_ELEMENT.NEUTRAL:
			continue  # a lone grab isn't a continuation
		var o := _option(kind, id)
		if attacking:
			var wait := _routed(kind, _move_id, false, _chain_i, false)
			if wait != id and COMBOS.has(wait):
				o.pause = {"id": wait, "name": guide_name(wait), "tier": COMBOS[wait].tier}
		rows.append(o)
	if attacking and not dashing:
		rows.append(_option("dash", dash_light()))
	return rows


## One beat of a breaker dive's comet (every 0.02 s as he drops): one fat inked streak that ends in a
## held impact star when the beats stop (comic_comet.gd).
func _comet(c: Color, _el: String) -> void:
	load("res://scripts/comic_comet.gd").beat(get_parent(), model, c)


## The breaker timing prompt (breaker_prompt.gd) reads this every frame:
## `live` while the press is still to come (times in s since take-off, the
## hero's colour); otherwise how the last one `ended` ("perfect", "hit",
## "lock" = too early, "miss" = no press).
func breaker_window() -> Dictionary:
	if state == State.LEAP and _brk_phase == 0 and not _brk_locked:
		var b := _brk
		return {"live": true, "t": _state_t, "open": b.open, "sweet": b.sweet, "close": b.close, "color": _brk_color(),
			"name": breaker_name(), "alt_name": b.alt.names.spirit if b.has("alt") else ""}
	return {"ended": _brk_ended}


func _breaker_prompt() -> void:
	if _brk_prompt != null:
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	_brk_prompt = BREAKER_PROMPT.new()
	_brk_prompt.player = self
	layer.add_child(_brk_prompt)


## The breaker this move leads to, if any (void_element.BREAKERS).
func _breaker_for(id: String) -> Dictionary:
	return VOID_ELEMENT.entry(id) if VOID_ELEMENT.BREAKERS.has(id) else {}


## A breaker's shared effects: in what it lands in, if it says, instead of his axe's teal.
func _brk_color() -> Color:
	return VOID_ELEMENT.ELEMENTS.LOOK[_brk.erupt].color if _brk.has("erupt") else _fx_color()


## The element a breaker's effects come in: his own, unless the breaker says otherwise.
func _brk_element() -> String:
	return VOID_ELEMENT.breaker_element(_brk) if _brk.has("erupt") else element()


## The breaker in play's name for the current element.
func breaker_name() -> String:
	return _brk.names.get(element(), _brk.names.spirit) if not _brk.is_empty() else ""


func _option(kind: String, id: String, hold := false) -> Dictionary:
	var o := {"kind": kind, "id": id, "name": guide_name(id), "tier": COMBOS[id].tier if COMBOS.has(id) else 0,
		"hold": hold, "next": {}}
	if o.tier < 3 and not hold:
		var best := 0
		for k: String in ["heavy", "light"]:  # heavy first: wins ties
			var n := _routed(k, id, true, chain_after(id), false)
			var tier: int = COMBOS[n].tier if COMBOS.has(n) else 0
			if combos_landed.get(n, 0) >= GUIDE_LEARNED:
				tier = 0  # learned: no need to hint it any more
			if tier > best:
				best = tier
				o.next = {"kind": k, "id": n, "name": guide_name(n), "tier": tier}
	return o


func guide_name(id: String) -> String:
	return combo_name(id) if COMBOS.has(id) else MOVE_NAMES.get(id, id)


## How soon a press is taken: `progress` 0..1 toward the move's cancel point,
## `ready` once a press now would be buffered into the next move (input_buffer);
## while charging, how far the charge is and whether it's full.
func combo_window() -> Dictionary:
	if state == State.CHARGE:
		return {"progress": clampf(_state_t / CHARGE_TIME, 0.0, 1.0), "ready": _charged, "dash": _dash_cd <= 0.0}
	if state != State.ATTACK:
		return {"progress": 1.0, "ready": true, "dash": _dash_cd <= 0.0}
	var t := _state_t * anim_speed * _anim_mult / _move_len
	var left: float = (_move.cancel - t) * _move_len / (anim_speed * _anim_mult)
	return {"progress": clampf(t / _move.cancel, 0.0, 1.0), "ready": left <= input_buffer,
		"dash": _dash_cd <= 0.0 and (_hits_done > 0 or t > 0.2)}


func _start_attack(id: String) -> void:
	_buffered = ""
	_ready_t = ComicLook.READY_HOLD
	if id == "GR" and _void.begin():
		return
	var prev_id := _move_id
	_move_id = id
	_move = _effective_move(id)
	_anim_mult = _base_anim_mult() * _move.get("speed", 1.0)
	_move_len = anim.get_animation(_clip_name(_move.anim)).length
	_hits_done = 0
	_connected = false
	_hop_y0 = model.position.y
	_hop_air = _hop_y0 > 0.4
	_hop_peak = _hop_y0 if _hop_air else 0.0
	_callout_done = false
	_chain_i = chain_after(id)
	_post_dash_t = 0.0
	_air_dash = false
	_aim(state == State.ATTACK)
	if _hop_air:
		_air_home()
	_set_state(State.ATTACK)
	_void.on_move(id, prev_id)
	attack_started.emit(id)
	Game.sfx("swing", -3.0, 0.12)
	_play(_move.anim, 0.05, true)


## R: the void arm swings him, if it's ready. True if it did.
func _try_swing() -> bool:
	if _swing_buffer_t <= 0.0 or _swing_cd > 0.0:
		return false
	_swing_buffer_t = 0.0
	_swing_cd = SWING_COOLDOWN
	_void.traverse()
	return true


func _start_dash() -> void:
	_dash_from = global_position
	_air_dash = _can_air_dash()
	if _air_dash:
		_air_dashes += 1
	_dash_buffer_t = 0.0
	_dash_cd = dash_cooldown
	_anim_mult = _base_anim_mult()
	var dir := _input_dir()
	_dash_dir = dir.normalized() if dir.length() > 0.1 else _facing()
	_face(_dash_dir)
	_invuln_t = dash_time + 0.08
	_since_dash = 0.0
	_perfect_this_dash = false
	_set_state(State.DASH)
	_ghost_t = 0.0
	_play("Dodge_Forward", 0.04, true)
	if _air_dash:
		_air_dash_cut()
	else:
		Fx.dust(get_parent(), global_position, 8)
		Fx.dash_streak(get_parent(), global_position, _dash_dir, dash_speed * dash_time + 0.8, Color(_fx_color(), 0.8))
	Game.sfx("dash", -4.0)


## Soft lock-on: rotate toward the best enemy roughly in front of us. `chained`: this move
## follows another, so under mouse aim it only turns part of the way (see COMBO_REDIRECT).
func _aim(chained := false) -> void:
	var want := _aim_want()
	if chained and _mouse_aiming():
		_face(_turned(want, COMBO_REDIRECT))
		return
	_face(want)
	model.rotation.y = _facing_yaw  # snap: attacks must point where they hit


## Where an attack wants to point: the cursor (else the stick, else ahead), pulled onto a foe near that line.
func _aim_want() -> Vector3:
	var mouse := _mouse_aiming()
	var dir := _mouse_dir() if mouse else _input_dir()
	var want := dir.normalized() if dir.length() > 0.1 else _facing()
	var max_angle := AIM_ASSIST_MOUSE_ANGLE if mouse else aim_assist_angle
	var best: Node3D = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > aim_assist_range or d < 0.01:
			continue
		var ang := rad_to_deg(want.angle_to(to / d))
		if ang > max_angle:
			continue
		var score := d + ang * 0.05
		if score < best_score:
			best_score = score
			best = e
	if best:
		want = best.global_position - global_position
		want.y = 0.0
	return want


## Juggle tracking (AIR_HOME_*): face the nearest airborne foe and lunge to
## reach it by the first hit. The lunge decays to 0 by a third of the move
## (`decay` 3), covering lunge * length / 6 metres.
func _air_home() -> void:
	var best: Node3D = null
	var best_d := AIR_HOME_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive() or not e.is_airborne():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < best_d:
			best_d = to.length()
			best = e
	if best == null:
		return
	var to := best.global_position - global_position
	to.y = 0.0
	if to.length() > 0.05:
		_face(to)
		model.rotation.y = _facing_yaw
	var gap: float = best_d - _move.get("range", 2.5) * 0.6
	if gap <= 0.0:
		return
	var length: float = _move_len / maxf(anim_speed * _anim_mult, 0.01)
	var decay: float = _move.get("decay", 3.0)
	var need := gap * 2.0 * decay / maxf(length, 0.01)  # travel = lunge * length / (2 * decay)
	_move.lunge = clampf(maxf(_move.lunge, need), 0.0, AIR_HOME_MAX)


func _do_hit() -> void:
	if _move_id == "GR":
		_void.strike()
		if _void._target_alive():
			VOID_ELEMENT.DARK.burst(get_parent(), _void._target.global_position, 0.8)
		return
	if _move_id == "VS":
		_void.slam_lands()
	var fwd := _facing()
	var named_before := _callout_done  # a combo ender lands its extra punch once
	# (not on H's moves: the element is the swing, and the arc hides it)
	if not VOID_ELEMENT.is_element_move(_move_id):
		_swoosh(fwd)
	var hit_any := false
	var any_airborne := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if _move.has("width"):
			if not _in_strip(to, fwd, _move.range, _move.width, e.radius):
				continue
		elif d > _move.range + e.radius:
			continue
		if _move.arc < 360.0 and d > 0.4 and rad_to_deg(fwd.angle_to(to / d)) > _move.arc * 0.5:
			continue
		var kb_dir := to / d if d > 0.01 else fwd
		var was_airborne: bool = e.is_airborne()
		any_airborne = any_airborne or was_airborne
		var dmg: float = _move.damage * _dmg_mult * plunge_mult()
		e.take_hit(dmg, kb_dir * _move.knockback, _move.launch, _move.get("big", false))
		Fx.element_hit(get_parent(), e.global_position, element(), kb_dir, _move.get("big", false))
		Game.register_hit(_move_id + ("_air" if was_airborne else ""))
		hit_any = true
		_connected = true
	# Slot effects that fire on the move's first active frame, hit or miss.
	if _hits_done == 1:
		_cast(fwd)
		if VOID_ELEMENT.is_element_move(_move_id) and VOID_ELEMENT.fire(self, _move_id, fwd) > 0:
			hit_any = true
			_connected = true
	if _move_id == "VS":
		_void.slam_landed()
	if hit_any:
		var named := named_id()
		var ender: int = COMBOS[named].tier if COMBOS.has(named) and not named_before else 0
		_combo_callout(named)
		Game.sfx("hit_big" if _move.get("big", false) else "hit")
		if _move.get("big", false):
			Game.rumble("hit_big")
		Game.hitstop(_move.stop * (1.3 if any_airborne else 1.0) + ender * ENDER_HITSTOP)
		Game.shake(_move.shake)
		if ender > 0 or _move.get("big", false):
			_camera_hit(fwd, ender)


## Combo enders push the camera in (more per tier); big hits and enders kick it
## along the swing.
func _camera_hit(fwd: Vector3, ender: int) -> void:
	if Game.camera_rig == null:
		return
	Game.camera_rig.kick(fwd, 0.18 + ender * 0.12)
	if ender > 0:
		Game.camera_rig.punch(1.0 - ENDER_ZOOM * ender, 0.08 + 0.05 * ender)


## Names a landed combo (COMBOS) above the hero with its tier's sound, once per move.
func _combo_callout(id: String) -> void:
	if _callout_done or not COMBOS.has(id):
		return
	_callout_done = true
	var c: Dictionary = COMBOS[id]
	var tier: int = c.tier
	callouts += 1
	last_callout_tier = tier
	_last_combo = id
	combos_landed[id] = combos_landed.get(id, 0) + 1
	if combos_landed[id] == 1:
		combo_found.emit(id)
	Game.sfx(COMBO_TIER_SFX[tier - 1], COMBO_SFX_DB, 0.03)
	_callout.text = combo_name(id)
	_callout.modulate = COMBO_TIER_COLORS[tier - 1]
	var pop_color: Color = VOID_ELEMENT.color_of(_move_id, _fx_color())
	if not VOID_ELEMENT.is_element_move(_move_id):  # (his tentacle moves land on him: a pop there hides what they're doing)
		Fx.combo_pop(get_parent(), global_position, pop_color if tier < 3 else _callout.modulate, tier)
	_callout.position = Vector3(0.0, 2.9, 0.0)
	_callout.scale = Vector3.ONE * 0.6
	_callout.visible = true
	if _callout_tw:
		_callout_tw.kill()
	_callout_tw = _callout.create_tween()
	_callout_tw.tween_property(_callout, "scale", Vector3.ONE * 1.15, 0.08)
	_callout_tw.tween_property(_callout, "scale", Vector3.ONE, 0.08)
	_callout_tw.parallel().tween_property(_callout, "position:y", 3.2, 0.6).set_ease(Tween.EASE_OUT)
	_callout_tw.tween_property(_callout, "modulate:a", 0.0, 0.3).set_delay(0.35)
	_callout_tw.tween_callback(_callout.hide)


# --- Casts -------------------------------------------------------------------

## The hero's element for his own casts and trails: spirit. (Each void move
## takes its element from the weapon it forms: VOID_ELEMENT.ELEMENT_OF.)
func element() -> String:
	return "spirit"


## The swing's arc (Fx.swoosh) out to the move's reach, in the trail's colour.
## Strip moves (`width`) thrust instead of sweep and get none.
func _swoosh(fwd: Vector3) -> void:
	if _move.has("width"):
		return
	_swoosh_flip = not _swoosh_flip
	var c: Color = _trails[0].color if not _trails.is_empty() else _trail_rest_color()
	var big: bool = _move.get("big", false)
	var time := 0.32 if big else 0.24
	var at := global_position + model.position  # up with him in a hop / the air string, beside him in a weave
	Fx.swoosh(get_parent(), at, fwd, _move.range * 0.9, _move.arc, c, _swoosh_flip, time)
	# Escalation: combo enders and long chains add a wider, hotter arc above the
	# first, so a string visibly builds to its finish.
	var tier := Fx.chain_tier(Game.combo_count)
	if COMBOS.has(_move_id) or tier >= 2:
		var hot := c.lerp(Color.WHITE, 0.35)
		hot.a = 0.75 + 0.08 * tier
		Fx.swoosh(get_parent(), at, fwd, _move.range * (1.05 + 0.04 * tier), _move.arc, hot,
				_swoosh_flip, time * 1.15, 1.15)


## Colour for the hero's own effects (dash ghosts and streak): Awakening's
## gold while Awakened, otherwise the element's.
func _fx_color() -> Color:
	return AWAKEN_COLOR if awakened else ELEMENTS.color(element())


## Swing trail colour outside Awakening: the current element's.
func _trail_rest_color() -> Color:
	return Color(ELEMENTS.color(element()), 0.85)


## The element cast that comes with the current move (ELEMENTS.CASTS), on its first active frame.
func _cast(fwd: Vector3) -> void:
	if not ELEMENTS.CASTS.has(_move_id) or _move_id in VOID_ELEMENT.NO_CAST:
		return
	var c: Dictionary = ELEMENTS.CASTS[_move_id]
	var el := element()
	var parent := get_parent()
	ELEMENTS.casts += 1
	Game.sfx(ELEMENTS.LOOK[el].sfx, CAST_SFX_DB, 0.1)
	var g := _cast_grow()  # spirit weapons swell with the chain
	match c.kind:
		"echo":
			var echo = _spirit(SPIRIT_ECHO.new(), c, el)
			echo.fwd = fwd
			echo.flip = _swoosh_flip  # follows the swing's own swoosh
			echo.arc_deg = c.arc
			echo.radius = c.radius * g
			echo.delay = c.delay
			echo.time = c.time
			parent.add_child(echo)
			echo.global_position = Vector3(global_position.x, model.position.y, global_position.z)  # (air slashes: in the air)
		"tomahawk":
			var n: int = c.get("fan", 1)
			for i in n:
				var th = _spirit(SPIRIT_TOMAHAWK.new(), c, el)
				th.dir = fwd.rotated(Vector3.UP, deg_to_rad(c.get("spread", 0.0) * (i - (n - 1) * 0.5)))
				th.hero = self
				th.size = c.size * g
				th.reach = minf(c.range, _clear_ahead(th.dir, c.range) + 0.4)
				th.back_damage = c.back_damage * _dmg_mult * _cast_power()
				parent.add_child(th)
				th.global_position = Vector3(global_position.x, 0.0, global_position.z) + th.dir * 0.6


## The common setup of a spirit cast node (spirit_*.gd): the hero's axe,
## colour, element, damage (scaled by the chain) and hit callback.
func _spirit(node: Node3D, c: Dictionary, el: String) -> Node3D:
	if "axe_mesh" in node:
		node.axe_mesh = _axe_mesh()
	node.color = _fx_color()
	node.el = el
	node.damage = c.damage * _dmg_mult * _cast_power()
	return node


## Spirit casts grow with the chain: CAST_GROW more size/reach per Fx chain
## tier (10 / 20 / 35 hits), CAST_POWER more damage.
func _cast_grow() -> float:
	return 1.0 + CAST_GROW * Fx.chain_tier(Game.combo_count)


func _cast_power() -> float:
	return 1.0 + CAST_POWER * Fx.chain_tier(Game.combo_count)


## Ground point for a targeted cast: the nearest foe roughly ahead within `reach`, else `ahead` m in front.
func _cast_target(fwd: Vector3, reach: float, ahead: float) -> Vector3:
	var best: Node3D = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and (d < 0.5 or rad_to_deg(fwd.angle_to(to / d)) < 50.0):
			best_d = d
			best = e
	var at := best.global_position if best else global_position + fwd * ahead
	return Vector3(at.x, 0.0, at.z)


## How far the hero can travel along `dir` (up to `length`) before a wall.
func _clear_ahead(dir: Vector3, length: float) -> float:
	var from := global_position + Vector3.UP * 0.9
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (length + 0.6), collision_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return length
	return maxf(from.distance_to(hit.position) - 0.6, 0.0)


## How long an Awakening lasts.
func _awaken_len() -> float:
	return awaken_duration


## Animation speed before per-move boosts (Awakening is faster).
func _base_anim_mult() -> float:
	return 1.3 if awakened else 1.0


func _on_enemy_killed(e: Node) -> void:
	if state != State.DEAD and _is_last_kill():
		_last_kill(e)


## Style rank climbed: a burst in the new rank's colour (the HUD's), bigger the higher it goes.
func _on_combo_changed(_count: int, rank: String) -> void:
	var i := Game.RANKS.size() - 1 - Game.RANKS.map(func(r: Array) -> String: return r[0]).find(rank)
	if i > _rank_i and state != State.DEAD and is_inside_tree():
		rank_ups += 1
		var c: Color = RANK_COLORS.get(rank, Color.WHITE)
		var at := global_position + Vector3.UP * 1.1
		# Thin and hard: a soft ring and star sat on him and fought his effects.
		VOID_ELEMENT.DARK.hoop_run(get_parent(), global_position, 0.6, 1.8 + i * 0.45, 0.22, c, 0.06)
		Fx.burst(get_parent(), at, c, 6 + i * 4, 9.0, 0.14, 0.35, Vector3.UP, 120.0, -6.0, 0.3, "spark")
		if i >= 4 and Game.camera_rig != null:  # S and up
			Game.camera_rig.punch(0.94, 0.15)
	_rank_i = i


## Nothing left to fight: no enemy alive and no reinforcements queued (main._queue).
func _is_last_kill() -> bool:
	if not get_tree().get_nodes_in_group("enemies").is_empty():
		return false
	var queue = get_parent().get("_queue")
	return queue is Array and queue.is_empty()


## The fight's final blow: slow motion, a camera push-in and a gold shock ring.
func _last_kill(e: Node) -> void:
	last_kills += 1
	if "--autotest" in OS.get_cmdline_user_args():
		print("[autotest] last_kill #%d rank_ups=%d" % [last_kills, rank_ups])
	Game.hitstop(LAST_KILL_SLOWMO, 0.2)
	if Game.camera_rig != null:
		Game.camera_rig.punch(0.82, LAST_KILL_SLOWMO + 0.15)
	var at: Vector3 = (e as Node3D).global_position
	var gold := Color(1.0, 0.82, 0.3)
	Fx.ring(get_parent(), at, Color(gold, 0.95), 5.0, 0.5)
	Fx.ring(get_parent(), at, Color(1, 1, 1, 0.8), 2.5, 0.3)
	Fx.flare(get_parent(), at + Vector3.UP * 1.1, gold, 6.0, 0.3, "star8")
	Fx.burst(get_parent(), at + Vector3.UP * 0.8, gold, 30, 12.0, 0.16, 0.6, Vector3.UP, 120.0, -10.0, 0.2, "spark")


## True if offset `to` (flat) lies in the strip `length` ahead along `fwd`.
static func _in_strip(to: Vector3, fwd: Vector3, length: float, half_width: float, pad: float) -> bool:
	var ahead := to.dot(fwd)
	var side := (to - fwd * ahead).length()
	return ahead > -0.5 and ahead <= length + pad and side <= half_width + pad


## A copy of the MOVES entry for this press (never mutates MOVES itself), retimed for his clips.
func _effective_move(id: String) -> Dictionary:
	var m: Dictionary = MOVES[id].duplicate(true)
	if ComicLook.HERO_MOVES.has(id):
		var length := anim.get_animation(ComicLook.HERO_MOVES[id].clip).length
		ComicLook.retime(id, m, length, MOVES[id].hits[0], VOID_ELEMENT.BREAKERS.get(id, {}).get("leap", -1.0))
	return m


func is_invulnerable() -> bool:
	return _invuln_t > 0.0


func is_dead() -> bool:
	return state == State.DEAD


func try_awaken() -> void:
	if awakened or state == State.DEAD or Game.awakening < Game.AWAKEN_MAX:
		return
	_set_awakened(true)
	Game.sfx("awaken", 0.0, 0.0)
	Game.rumble("awaken")
	# Activation burst: big freeze, shockwave that blows enemies back.
	Game.hitstop(0.25, 0.05)
	Game.shake(0.6)
	var r := AWAKEN_BURST_RADIUS
	Fx.awaken_burst(get_parent(), global_position, AWAKEN_COLOR, r)
	if Game.camera_rig:
		Game.camera_rig.punch(0.85, 0.35)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < r:
			e.take_hit(AWAKEN_BURST_DAMAGE, to.normalized() * 12.0, 5.0, true)


## The COMBOS id the current move lands as.
func named_id() -> String:
	return _move_id


func combo_name(id: String) -> String:
	return COMBOS[id].name


func _set_awakened(on: bool) -> void:
	awakened = on
	Game.awaken_locked = on
	if not on:
		Game.add_awakening(-Game.AWAKEN_MAX)  # always starts over from empty
	_awaken_t = _awaken_len()
	_anim_mult = 1.3 if on else 1.0
	_dmg_mult = 1.6 if on else 1.0
	var tw := create_tween().set_parallel()
	tw.tween_property(model, "scale", Vector3.ONE * (1.18 if on else 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_awaken_light, "light_energy", 3.0 if on else 0.0, 0.2)
	var c := AWAKEN_COLOR
	_awaken_light.light_color = c
	_awaken_rim.set_shader_parameter("glow_color", c)
	for mi: MeshInstance3D in _meshes:
		mi.material_overlay = _awaken_rim if on else null
	for trail in _trails:
		trail.color = Color(c, 0.9) if on else _trail_rest_color()
	for coat: Node in _coats:  # ComicLook.infuse_axes: the axe's element flares up
		if is_instance_valid(coat):
			coat.charge(on)
	_orbit.setup(element(), on)
	awakened_changed.emit(on)


## Slow time, refund Awakening, stun the attacker, and allow an instant re-dash.
func _perfect_dodge(attacker: Node) -> void:
	_perfect_this_dash = true
	_dash_cd = 0.0
	Game.perfect_dodge(perfect_dodge_refund)
	Game.hitstop(0.5, 0.25)
	Fx.ring(get_parent(), global_position, Color(0.5, 0.85, 1.0, 0.9), 4.0, 0.4)
	Fx.ring(get_parent(), global_position, Color(0.25, 0.6, 1.0, 0.9), 2.2, 0.3)
	Fx.flare(get_parent(), global_position + Vector3.UP * 1.0, Color(0.35, 0.75, 1.0), 9.0, 0.35, "flare")
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.8, Color(0.6, 0.9, 1.0), 20, 9.0, 0.14, 0.4, Vector3.UP, 180.0, 0.0, 0.0, "dot", true)
	Fx.afterimage(get_parent(), model, Color(0.8, 0.95, 1.0, 0.6), 0.5)
	if attacker and attacker.has_method("stagger"):
		attacker.stagger(perfect_dodge_stun)


## Restore HP (capped at max). `show` pops a green number and sparkle.
func heal(amount: float, show := true) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	var before := hp
	hp = minf(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)
	if show and hp > before:
		Fx.heal(get_parent(), global_position, hp - before)


## "a spike trap" (no attacker), "the Bone Warden", "an elite skeleton
## archer"... (titles come from main.ENEMY_TYPES).
static func _describe_attacker(attacker: Node) -> String:
	if attacker == null:
		return "a spike trap"
	if attacker.has_method("is_boss"):
		return "the Bone Warden"
	var kind: String = ("elite " if attacker.elite else "") + attacker.get_meta("title", "skeleton")
	return ("an " if kind[0] in "aeiou" else "a ") + kind


## `cause` names hazards for the death recap ("the Bone Warden's cage");
## otherwise the attacker is described.
func take_hit(damage: float, knockback: Vector3, attacker: Node = null, cause := "") -> void:
	if state == State.DEAD:
		return
	if _invuln_t > 0.0:
		if _since_dash <= perfect_dodge_window and not _perfect_this_dash:
			_perfect_dodge(attacker)
		return
	hp = maxf(hp - damage * (0.6 if awakened else 1.0), 0.0)
	last_hit_by = cause if cause != "" else _describe_attacker(attacker)
	health_changed.emit(hp, max_hp)
	Game.player_damaged()
	Game.sfx("player_hurt")
	Game.shake(0.4)
	Game.hitstop(0.06)
	Fx.flash(model)
	Fx.damage_number(get_parent(), global_position, damage)
	_invuln_t = 0.5
	velocity.x = knockback.x
	velocity.z = knockback.z
	if hp <= 0.0:
		_set_state(State.DEAD)
		if awakened:
			_set_awakened(false)
		_play("Death_A", 0.1, true)
		died.emit()
		return
	# Awakened hero has super armor: takes damage but isn't staggered.
	if not awakened:
		_set_state(State.HURT)
		_ready_t = ComicLook.READY_HOLD
		_play("Hit_A", 0.05, true)


func _play(anim_name: String, blend := 0.1, restart := false) -> void:
	anim_name = _clip_name(anim_name)
	if anim.current_animation == anim_name and not restart:
		return
	anim.play(anim_name, blend, 1.0)
	if restart:
		anim.seek(0.0, true)
	# Locomotion plays at natural speed; actions are sped up for snappiness.
	anim.speed_scale = 1.1 if anim_name in LOOPING or anim_name in ComicLook.HERO_FIDGETS else anim_speed * _anim_mult
