extends CharacterBody3D
## The hero: movement, dash (with i-frames, cancels attacks), light/heavy
## combo routes, soft auto-aim, and the Awakening transformation.

signal health_changed(hp: float, max_hp: float)
signal awakened_changed(active: bool)
signal died
## Fired when any attack begins (enemies that dodge listen for this).
signal attack_started(move_id: String)
signal combo_found(id: String)  # a named combo landed for the first time this run

enum State { MOVE, ATTACK, DASH, HURT, CHARGE, ULT, DEAD, LEAP, SWING }

const MODEL := preload("res://assets/kaykit/characters/Barbarian.glb")
const TRAIL := preload("res://scripts/weapon_trail.gd")
const HERO_LOOK := preload("res://scripts/hero_look.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const CAST_GROW := 0.15  # spirit cast size per chain tier (_cast_grow)
const CAST_POWER := 0.12  # spirit cast damage per chain tier
const SPIRIT_CLEAVE := preload("res://scripts/spirit_cleave.gd")
const SPIRIT_AVATAR := preload("res://scripts/spirit_avatar.gd")
const SPIRIT_CROWN := preload("res://scripts/spirit_crown.gd")
const SPIRIT_RIFT := preload("res://scripts/spirit_rift.gd")
const SPIRIT_WHEEL := preload("res://scripts/spirit_wheel.gd")
const SPIRIT_TOMAHAWK := preload("res://scripts/spirit_tomahawk.gd")
const SPIRIT_GUILLOTINE := preload("res://scripts/spirit_guillotine.gd")
const ELEMENTS := preload("res://scripts/elements.gd")
const TRAIL_MESHES := ["1H_Axe", "1H_Axe_Offhand"]
const HIDDEN_MESHES := ["Barbarian_Round_Shield", "2H_Axe", "Mug", "Barbarian_Hat", "Barbarian_Cape"]
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
## Each level-up raises max HP by this much (and heals it).
@export var level_hp := 5.0

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
#   weave: (optional) metres the model sways side to side, one way per hit,
#        between the first and last hit (Flurry dances through its cuts)
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
	# Light after a pause once L2 has finished (L L · L): Flurry, a quick run
	# of small cuts that keeps foes in reach (low knockback).
	"LPL": {"anim": "Dualwield_Melee_Attack_Slice", "damage": 4.5, "range": 2.6, "arc": 170.0,
		"hits": [0.22, 0.32, 0.42, 0.52, 0.62], "cancel": 0.66, "end": 0.85, "lunge": 5.0, "knockback": 0.8,
		"launch": 0.0, "stop": 0.03, "shake": 0.1, "weave": 0.45},
	# Heavy from neutral: spinning AoE, multi-hit. A leaping whirl: he spins
	# up off the floor through all three hits and lands with a slam.
	"H": {"anim": "2H_Melee_Attack_Spin", "damage": 6.0, "range": 3.2, "arc": 360.0,
		"hits": [0.3, 0.45, 0.6], "cancel": 0.7, "end": 0.85, "lunge": 4.0, "knockback": 3.0, "launch": 0.0,
		"stop": 0.035, "shake": 0.12, "hop": [0.15, 0.68, 0.8]},
	# Heavy after any light hit: launcher (raises a pillar of the element under
	# the target). Juggled enemies take bonus style.
	"LH": {"anim": "Spellcast_Raise", "damage": 14.0, "range": 2.8, "arc": 120.0,
		"hits": [0.3], "cancel": 0.42, "end": 0.58, "lunge": 3.0, "knockback": 2.0, "launch": 9.0,
		"stop": 0.09, "shake": 0.3, "big": true, "hop": [0.28, 0.58, 1.5]},
	# Light after the launcher (L H L, then L H L L): air slashes. He stays up
	# with the foe he launched (`air`: holds the height he started at) and
	# each cut re-juggles it; a third light is Triple Chop slamming down, a
	# heavy is Spike from the air.
	"AL1": {"anim": "1H_Melee_Attack_Slice_Diagonal", "damage": 7.0, "range": 2.6, "arc": 170.0,
		"hits": [0.32], "cancel": 0.42, "end": 0.7, "lunge": 2.0, "knockback": 0.6, "launch": 5.0,
		"stop": 0.045, "shake": 0.12, "air": true, "climb": 0.4},
	"AL2": {"anim": "Dualwield_Melee_Attack_Slice", "damage": 4.0, "range": 2.6, "arc": 190.0,
		"hits": [0.24, 0.4], "cancel": 0.5, "end": 0.75, "lunge": 2.0, "knockback": 0.6, "launch": 5.0,
		"stop": 0.04, "shake": 0.14, "air": true, "climb": 0.5},
	# Heavy after Sky Rend (L H L L H): Updraft. He calls a gale under his feet
	# and spins up on it (`gust`: air_gust.gd), climbing past AIR_MAX_HEIGHT
	# toward AIR_GUST_HEIGHT and launching the foes round him up with him. The
	# gale gives the air dash back; one gust per trip up.
	"AH": {"anim": "2H_Melee_Attack_Spin", "damage": 5.0, "range": 3.0, "arc": 360.0,
		"hits": [0.3, 0.48], "cancel": 0.56, "end": 0.8, "lunge": 1.0, "knockback": 0.5, "launch": 8.0,
		"stop": 0.05, "shake": 0.2, "air": true, "climb": 1.6, "gust": true},
	# Light off the Updraft (L H L L H L): Gale Waltz, a whirl of cuts riding
	# the gale (weaving), each flinging a spectral axe. Then L is Triple Chop
	# from the very top (Stormfall), H is Spike.
	"AL3": {"anim": "Dualwield_Melee_Attack_Slice", "damage": 4.0, "range": 2.8, "arc": 220.0,
		"hits": [0.22, 0.36, 0.5], "cancel": 0.58, "end": 0.8, "lunge": 2.0, "knockback": 0.5, "launch": 5.0,
		"stop": 0.04, "shake": 0.14, "air": true, "climb": 0.3, "weave": 0.35, "blades": true},
	# Heavy right after the launcher (L H H): Spike, an overhead chop that
	# slams juggled foes into the floor (SPIKE_*). Awakened, it's Ancestor's Fall.
	"LHH": {"anim": "1H_Melee_Attack_Chop", "damage": 13.0, "range": 2.8, "arc": 140.0,
		"hits": [0.38], "cancel": 0.55, "end": 0.8, "lunge": 5.0, "knockback": 3.0, "launch": 0.0,
		"stop": 0.1, "shake": 0.4, "big": true},
	# Heavy right after L2 (L L H): Ground Breaker, a lunging thrust that
	# knocks down everything in a strip ahead (launch > 0 also breaks guards).
	"LLH": {"anim": "2H_Melee_Attack_Stab", "damage": 18.0, "range": 5.0, "width": 1.1, "arc": 360.0,
		"hits": [0.4], "cancel": 0.6, "end": 0.85, "lunge": 8.0, "knockback": 12.0, "launch": 4.0,
		"stop": 0.1, "shake": 0.4, "big": true},
	# Charged heavy: hold heavy from neutral for CHARGE_TIME, then release.
	# Big launching slam; breaks shield guards (launch > 0).
	"CH": {"anim": "2H_Melee_Attack_Chop", "damage": 30.0, "range": 3.4, "arc": 160.0,
		"hits": [0.4], "cancel": 0.6, "end": 0.85, "lunge": 10.0, "knockback": 12.0, "launch": 8.0,
		"stop": 0.14, "shake": 0.55, "big": true, "hop": [0.12, 0.4, 1.1]},
	# Light right out of a dash: long lunging stab, pouncing onto the foe
	# (a low leap that lands on the stab).
	"DL": {"anim": "1H_Melee_Attack_Stab", "damage": 12.0, "range": 2.8, "arc": 90.0,
		"hits": [0.3], "cancel": 0.5, "end": 0.7, "lunge": 16.0, "knockback": 7.0, "launch": 0.0,
		"stop": 0.07, "shake": 0.22, "hop": [0.03, 0.3, 0.6]},
	# Heavy right out of a dash: Cyclone, a spin that keeps travelling
	# through the crowd (low lunge decay).
	"DH": {"anim": "2H_Melee_Attack_Spinning", "damage": 5.0, "range": 2.9, "arc": 360.0,
		"hits": [0.2, 0.38, 0.56, 0.74], "cancel": 0.78, "end": 0.9, "lunge": 9.0, "decay": 1.2, "speed": 0.55,
		"knockback": 4.0, "launch": 0.0, "stop": 0.035, "shake": 0.16},
	# Awakened only: heavy right after L3. Huge two-handed swing that erupts all around.
	"AF": {"anim": "2H_Melee_Attack_Slice", "damage": 30.0, "range": 4.5, "arc": 360.0,
		"hits": [0.45], "cancel": 0.7, "end": 0.9, "lunge": 5.0, "knockback": 6.0, "launch": 10.0,
		"stop": 0.16, "shake": 0.7, "big": true},
}
# The named combos: landing one plays its tier's sound and shows its name
# above the hero. Moves not listed here (L1, L2, H) stay quiet. Also the
# pause menu's move list. tier: 1 string, 2 heavy route, 3 finisher.
const COMBOS := {
	"L3": {"name": "Triple Chop", "input": "L L L", "tier": 1},
	"VS": {"name": "Tendril Slam", "input": "E E", "tier": 1},
	"SHAPEBREAKER": {"name": "Shapebreaker", "input": "L L L E", "tier": 3},
	"LPL": {"name": "Flurry", "input": "L L, pause, L", "tier": 1},
	"DL": {"name": "Dash Stab", "input": "Dash > L", "tier": 1},
	"DH": {"name": "Cyclone", "input": "Dash > H", "tier": 2},
	"LH": {"name": "Launcher", "input": "L H", "tier": 2},
	"AL2": {"name": "Sky Rend", "input": "L H L L", "tier": 2},
	# Not a move: Triple Chop plunging from the top of the air string
	# (PLUNGE_AXES_FROM) is named this instead (named_id()).
	"SKYFALL": {"name": "Skyfall", "input": "L H L L L", "tier": 2},
	"AH": {"name": "Updraft", "input": "L H L L H", "tier": 2},
	"AL3": {"name": "Gale Waltz", "input": "L H L L H L", "tier": 2},
	# Not a move: Triple Chop from the top of the Updraft (STORMFALL_FROM).
	"STORMFALL": {"name": "Stormfall", "input": "L H L L H L L", "tier": 3},
	"LLH": {"name": "Ground Breaker", "input": "L L H", "tier": 2},
	"LHH": {"name": "Spike", "input": "L H H", "tier": 2},
	"CH": {"name": "Charged Slam", "input": "hold H", "tier": 2},
	"AF": {"name": "Cataclysm", "input": "L L L H (Awakened)", "tier": 3},
	"SKY": {"name": "Ancestor's Fall", "input": "L H H (Awakened)", "tier": 3},
	"RUSH": {"name": "Spirit Stampede", "input": "Dash L H (Awakened)", "tier": 3},
}
# Awakened ultimates: these combos turn into a cinematic move (AF, the
# finisher, is the third). The hero is invulnerable throughout. Each ultimate
# in the same Awakening adds ULT_CHAIN_BONUS damage to the next, and landing
# all three calls down the TRINITY storm. Names per element (spirit = no
# Ascendancy yet). Damage is before the Awakened damage multiplier.
#   SKY   leap toward a foe within `reach`, gather the element overhead, smash
#         down at `impact` (fraction of `time`) hitting everything in `radius`
#   RUSH  wind up for `go`, charge `length` ahead over `dash` hitting what's in
#         `width`, then the whole line erupts `wake` later for `wake_damage`
const ULTIMATES := {
	"SKY": {"time": 1.05, "impact": 0.62, "rise": 3.2, "reach": 6.0, "damage": 36.0, "radius": 4.8, "launch": 10.0,
		"names": {"spirit": "Ancestor's Fall", "wind": "Thunder Dive", "earth": "Meteor Fall", "water": "Frozen Comet"}},
	"RUSH": {"time": 0.85, "go": 0.16, "dash": 0.26, "length": 9.0, "width": 1.6, "damage": 26.0, "launch": 6.0,
		"wake": 0.12, "wake_damage": 12.0,
		"names": {"spirit": "Spirit Stampede", "wind": "Gale Rush", "earth": "Tectonic Charge", "water": "Tidal Surge"}},
}
const ULT_CHAIN_BONUS := 0.3
const CATACLYSM_AXES := 6  # colossal spirit axes slamming down round the hero
const CATACLYSM_AXE_RING := 3.8  # m from him
# Combo breakers: timed finishers. The move leaps into the air at `leap`
# (fraction of its anim), hops `back` m while rising `height` m over `rise` s,
# hurls `spikes` spikes onto a zone `zone` m ahead (spread `spread`), and a
# cue rings that zone: press heavy between `open` and `close` s after take-off
# (rings meet at `sweet`; within `perfect` of it = PERFECT, x`perfect_mult`)
# to dive onto it in `dive` s, detonating the spikes and hitting `radius` for
# `damage`. Too early locks it out; no press = he floats down in `fall` s.
const BREAKERS := {
	"LLH": {"leap": 0.5, "rise": 0.3, "height": 3.2, "back": 1.4, "spikes": 7, "zone": 3.8, "spread": 2.0,
		"spike_damage": 4.0, "detonate": 6.0, "throw": 0.12, "cue": 0.12, "open": 0.36, "sweet": 0.5, "close": 0.66,
		"perfect": 0.06, "dive": 0.14, "damage": 22.0, "radius": 3.4, "launch": 7.0, "perfect_mult": 1.5,
		"fall": 0.24, "awaken": 6.0, "awaken_perfect": 14.0,
		"names": {"spirit": "Ancestor Meteor", "wind": "Thunderfall", "earth": "Meteor Breaker", "water": "Comet Breaker"}},
	# Charged Slam: leaps forward after the foes it launched (negative `back`)
	# and spins up among them inside a spectral sawblade (`juggle`: a
	# spirit_wheel on the model, `juggle_damage` a tick, keeping them airborne
	# within `juggle_radius`), then the press slams him down onto them.
	"CH": {"leap": 0.55, "rise": 0.26, "height": 2.6, "back": -1.4, "spikes": 0, "zone": 2.8, "spread": 0.0,
		"spike_damage": 0.0, "detonate": 0.0, "throw": 0.1, "cue": 0.1, "open": 0.34, "sweet": 0.48, "close": 0.64,
		"perfect": 0.06, "dive": 0.12, "damage": 26.0, "radius": 3.6, "launch": 9.0, "perfect_mult": 1.5,
		"fall": 0.24, "awaken": 6.0, "awaken_perfect": 14.0,
		"juggle": true, "juggle_damage": 2.5, "juggle_radius": 3.0, "juggle_axes": 5,
		"names": {"spirit": "Ancestor Skyfall", "wind": "Cyclone Drop", "earth": "Landslide", "water": "Whirlpool Drop"}},
	# Flurry: a low hop back into a ready stance, then the press is a dash
	# (`dash`) through everything along the line to the zone: `pass_damage` to
	# each foe within `width` as he passes, then the line erupts in spectral
	# axes (a spirit_rift) for `damage` (no radius blast at the end).
	"LPL": {"leap": 0.64, "rise": 0.18, "height": 0.45, "back": 1.2, "spikes": 0, "zone": 6.5, "spread": 0.0,
		"spike_damage": 0.0, "detonate": 0.0, "throw": 0.08, "cue": 0.08, "open": 0.3, "sweet": 0.42, "close": 0.56,
		"perfect": 0.06, "dive": 0.16, "damage": 18.0, "radius": 0.0, "launch": 6.0, "perfect_mult": 1.5,
		"fall": 0.18, "awaken": 5.0, "awaken_perfect": 12.0,
		"dash": true, "pass_damage": 8.0, "width": 1.4, "hang_anim": "2H_Melee_Idle",
		"names": {"spirit": "Spirit Step", "wind": "Lightning Step", "earth": "Fault Rush", "water": "Riptide Rush"}},
	# Cyclone: spins up on the spot inside the sawblade (`juggle`), the
	# whirlwind dragging foes within `pull_radius` in at `pull` m/s; the press
	# flings `fan` spectral tomahawks out in a ring (`fan_range`, each hits
	# out and back for `fan_damage` / `fan_back`), plus a `radius` blast round him.
	"DH": {"leap": 0.76, "rise": 0.22, "height": 1.2, "back": 0.0, "spikes": 0, "zone": 0.0, "spread": 0.0,
		"spike_damage": 0.0, "detonate": 0.0, "throw": 0.08, "cue": 0.08, "open": 0.32, "sweet": 0.46, "close": 0.6,
		"perfect": 0.06, "dive": 0.1, "damage": 12.0, "radius": 2.6, "launch": 5.0, "perfect_mult": 1.5,
		"fall": 0.2, "awaken": 5.0, "awaken_perfect": 12.0,
		"juggle": true, "juggle_damage": 2.0, "juggle_radius": 2.6, "juggle_axes": 6, "pull": 4.5, "pull_radius": 6.0,
		"fan": 6, "fan_damage": 8.0, "fan_back": 5.0, "fan_range": 7.0,
		"names": {"spirit": "Spirit Maelstrom", "wind": "Tempest Ring", "earth": "Shrapnel Storm", "water": "Hailstorm"}},
	# Spike: bounces straight up off the slam while a spectral axe appears
	# hovering point-down over each foe within `volley_radius` of the zone (up
	# to `volley_max`, following them); the press dives him in and every axe
	# drops with him (`volley_damage` each, one hit per foe for the volley).
	"LHH": {"leap": 0.48, "rise": 0.24, "height": 3.0, "back": 0.0, "spikes": 0, "zone": 1.6, "spread": 0.0,
		"spike_damage": 0.0, "detonate": 0.0, "throw": 0.1, "cue": 0.1, "open": 0.34, "sweet": 0.48, "close": 0.62,
		"perfect": 0.06, "dive": 0.13, "damage": 16.0, "radius": 2.8, "launch": 0.0, "perfect_mult": 1.5,
		"fall": 0.24, "awaken": 6.0, "awaken_perfect": 14.0,
		"volley": true, "volley_damage": 12.0, "volley_radius": 6.0, "volley_max": 6, "volley_size": 2.6,
		"names": {"spirit": "Spirit Verdict", "wind": "Storm Verdict", "earth": "Mountain Verdict", "water": "Frost Verdict"}},
}
# The breaker window plays in slow motion (BREAKER_FOCUS time scale, camera
# pushed in to BREAKER_FOCUS_ZOOM), and a perfect press freezes the frame for
# BREAKER_PERFECT_STOP real s before the dive.
const BREAKER_FOCUS := 0.6
const BREAKER_FOCUS_ZOOM := 0.86
const BREAKER_PERFECT_STOP := 0.07
# Awakened, the dive breakers summon a BREAKER_ANCESTOR-times spectral
# ancestor as the window opens, timed to bring its axe down with the hero's
# dive at the sweet spot (visual; gone if he doesn't dive). The dash breaker's
# wake axes grow by BREAKER_AWAKENED_WAKE instead.
const BREAKER_ANCESTOR := 4.0
const BREAKER_AWAKENED_WAKE := 1.4
# Forgiving presses: a heavy in the first BREAKER_SPILL s after take-off is the
# ender's own mashed press spilling over and is ignored (no lockout), and one
# within BREAKER_EARLY s before `open` is held and fires as the window opens
# (a normal hit). Only a press between the two locks the breaker out.
const BREAKER_SPILL := 0.12
const BREAKER_EARLY := 0.08
const BREAKER_QUAKE := preload("res://scripts/breaker_quake.gd")
const RITE := preload("res://scripts/element_rite.gd")  # Ascended heavies: prime the element, the next heavy sets it off
const BREAKER_SPIKE := preload("res://scripts/breaker_spike.gd")
const BREAKER_CUE := preload("res://scripts/breaker_cue.gd")
const BREAKER_PROMPT := preload("res://scripts/breaker_prompt.gd")
const SKY_ANCESTOR := 5.0  # Ancestor's Fall: the ancestor's size vs the hero
const TRINITY := {"damage": 24.0, "radius": 12.0, "delay": 0.35, "gap": 0.06,
	"names": {"spirit": "Ancestral Storm", "wind": "Skyfall", "earth": "Worldbreaker", "water": "Absolute Zero"}}
const CAST_SFX_DB := -11.0
# Names of the moves that aren't combos, for the combo guide.
const MOVE_NAMES := {"L1": "Slice", "L2": "Hurl", "H": "Spin", "AL1": "Air Slash"}
# After landing a combo this many times in a run, the guide stops hinting it
# as a follow-up (it still shows as a row); ultimates are always hinted.
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
const SWING_INVULN := 1.4  # s, on the tentacle (void_grab.gd)
const PULL_INVULN := 0.8
const FLING_ACCEL_MULT := 0.2  # how much grip he has flying off a swing
# Charging (hold heavy from neutral): release before CHARGE_TIME for the
# normal spin (H), after it for the charged slam (CH). You can creep while
# charging at CHARGE_MOVE_MULT speed; dash cancels the charge.
const CHARGE_TIME := 0.8
const CHARGE_MOVE_MULT := 0.35
const CHARGE_COLOR := Color(1.0, 0.85, 0.45)
const SYNERGY_COLOR := Color(0.45, 1.0, 0.85)
const FIRE_WAVE := preload("res://scripts/fire_wave.gd")
const CATACLYSM_WAVES := 6  # fire waves radiating from the Awakened finisher

var hp := max_hp
var state := State.MOVE
var awakened := false
var model: Node3D
var _form: Node3D  # HERO_LOOK.add_form gear for the chosen Ascendancy
var _coats: Array[Node3D] = []  # HERO_LOOK.coat_axes for the current element
var rank_ups := 0  # style rank climbs that burst at the hero (autotest)
var _rank_i := 0  # current style rank as a step above D (Game.RANKS)
var last_kills := 0  # fights ended with the slow-motion final blow (autotest)
var _asc_aura: Node3D  # ascend_aura.gd: the Ascendancy's always-on aura
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
# A plunge from at least PLUNGE_AXES_FROM (only the top of the air string,
# Sky Rend) also slams a fan of spectral axes into the floor ahead of him
# (visual: _plunge_axes), PLUNGE_AXES_SPREAD degrees apart.
const PLUNGE_AXES_FROM := 2.0
const PLUNGE_AXES_SPREAD := 32.0
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
# Air dash: dashing out of the launcher or an air slash while at least
# AIR_DASH_MIN up keeps him at that height, and the press after it carries
# on in the air (route() `from` "AD": light = Air Slash, heavy = Spike /
# Ancestor's Fall) instead of Dash Stab / Cyclone.
const AIR_DASH_FROM := ["LH", "AL1", "AL2", "AH", "AL3"]
const AIR_DASH_MIN := 0.6
# One air dash per trip up (reset on landing), and `climb` stops at
# AIR_MAX_HEIGHT, so dash-slash loops can't keep him up or lift him forever.
const AIR_DASHES := 1
const AIR_MAX_HEIGHT := 2.8
# The Updraft's gale lifts him past that, up to AIR_GUST_HEIGHT, for the rest
# of the trip up. Triple Chop from STORMFALL_FROM lands as Stormfall: the
# floor breaks (breaker_quake crater) and the element erupts round him.
const AIR_GUST_HEIGHT := 4.2
const STORMFALL_FROM := 3.4
const AIR_GUST := preload("res://scripts/air_gust.gd")
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
var _gusted := false  # the Updraft's gale has lifted him this trip up (one per trip)
var _gust_cloud: Node3D  # the gale under his feet while he's up there (air_gust.cloud)
var _awaken_t := 0.0
var _facing_yaw := 0.0
var _mouse_active := true  # false once a gamepad is the last thing touched
var _invuln_t := 0.0
var _anim_mult := 1.0
var _dmg_mult := 1.0
var _second_wind_used := false
var _charged := false
var _charge_fx_t := 0.0
var _charge_light: OmniLight3D
var charged_slams := 0  # reported by the autotest
var ground_breakers := 0  # reported by the autotest
var shatters := 0  # Shatter bursts (autotest)
var spikes := 0  # juggled foes spiked down (autotest)
var _last_combo := ""  # the last named combo landed (War Chant pays more for a new one)
var combos_landed := {}  # COMBOS id -> times landed this run (pause menu, run summary)
## Moves that count as heavy for Shatter.
const SHATTER_MOVES := ["H", "LH", "LLH", "CH", "AF", "DH", "LHH"]
# Spike (LHH) on a juggled foe: damage multiplier, how hard it's slammed
# down (m/s), and the impact that knocks down foes around where it lands.
const SPIKE_AIR_MULT := 1.6
const SPIKE_DOWN := 24.0
const SPIKE_IMPACT := {"radius": 2.6, "damage": 6.0, "knockback": 5.0}
const REBOUND_DELAY := 0.22  # s from the spike to the bounce (Rebound)
const SHATTER_COLOR := Color(0.92, 0.88, 0.78)
var synergies: Array = []  # active Upgrades.SYNERGIES ids, kept by add_upgrade()
var masteries: Array = []  # Upgrades.PATHS ids with their mastery on, kept by add_upgrade()
## Light-press moves, for the Light path's powers.
const LIGHT_MOVES := ["L1", "L2", "L3", "DL", "LPL", "AL1", "AL2", "AL3"]
const RAZOR_GALE_SPREAD := 16.0  # degrees between Razor Gale's blades
var _crescendo := false  # Crescendo: the next heavy is empowered
var _slipped: Array = []  # enemies Slipstream already cut this dash
var power_procs := {}  # power id -> times it fired, for the newer powers (autotest)
var last_hit_by := ""  # who landed the latest hit ("a rogue"), for the death recap
var cataclysms := 0  # finishers landed (reported by the autotest)
var callouts := 0  # combo callouts shown (autotest)
var last_callout_tier := 0  # (autotest screenshot)
var _callout: Label3D
var _callout_tw: Tween
var _callout_done := false
var _awaken_light: OmniLight3D
## Ascendancy path (Ascendancy.PATHS key) picked at level 6, or "".
var ascendancy := ""
var element_procs := 0  # lightning strikes, magma pools, freezes (autotest)
var _wind_hits := 0
var _aura: CPUParticles3D
var _meshes: Array[Node] = []
var _awaken_rim: ShaderMaterial
var _trails: Array = []
var _comic_hero := false  # model is ComicLook.HERO, not the KayKit Barbarian
var _void: Node  # his grab and slam (void_grab.gd), the comic hero only
var _fling_t := 0.0  # s left flying off a swing
var _ready_t := 0.0  # comic hero: s left in the guard after a fight
var _fidget_t: float = ComicLook.FIDGET_EVERY  # comic hero: s until he next fidgets
var _fidget_i := 0
static var _kaykit_axe: Mesh  # the spirit casts' axe under the comic hero (see _axe_mesh)
var _orbit: Node3D
var _ult_id := ""
var _ult_from := Vector3.ZERO
var _ult_at := Vector3.ZERO
var _ult_dir := Vector3.FORWARD
var _ult_len := 0.0  # RUSH distance, cut short by walls
var _ult_hit := {}
var _ult_step_d := 0.0
var _ult_phase := 0
var _ult_fired := false
var _ult_fx_t := 0.0
var _ult_chain := 0  # ultimates so far this Awakening
var _ult_kinds: Array[String] = []
var _trinity_done := false
var ults := 0  # ultimates started (autotest)
var max_chain := 0
var ult_impacts := 0  # SKY/RUSH impacts (autotest screenshot)
var trinities := 0
var _ghost_t := 0.0
var _since_dash := 99.0
var _perfect_this_dash := false

# Lets the autotest drive the hero without real input.
var bot_move := Vector3.ZERO

## Owned combo-slot upgrades: id -> level (see upgrades.gd).
var upgrades := {}
var bot_enabled := false
var stormfalls := 0  # landings from the top of the Updraft (tests)
var rites := 0  # Ascended heavies that set off primes (RITE, autotest)
var breakers_landed := 0  # combo breakers (timed finishers) landed (autotest)
var breaker_perfects := 0
var _brk: Dictionary = {}  # the breaker in play (BREAKERS entry)
var _brk_id := ""
var _brk_phase := 0  # 0 rising / hanging, 1 diving, 2 falling (missed)
var _brk_press := -1.0  # s after take-off it was pressed (-1 none)
var _brk_locked := false
var _brk_held := false  # pressed just before `open`: dives as the window opens (BREAKER_EARLY)
var _brk_thrown := 0
var _brk_zone := Vector3.ZERO
var _brk_dir := Vector3.FORWARD
var _brk_dive_from := Vector3.ZERO
var _brk_spikes: Array = []
var _brk_blasted: Dictionary = {}  # foes the spikes' detonation already hit
var _brk_cue: Node3D
var _brk_wheel: Node3D  # the juggle's sawblade (BREAKERS `juggle`)
var _brk_focus := false  # the window's slow motion has started
var _brk_ended := ""  # how the last breaker's press went (breaker_window)
var _brk_prompt: Control  # the timing circle (breaker_prompt.gd), made on the first leap
var _brk_ancestor: Node3D  # Awakened: the ancestor slamming down with the dive
var _brk_volley: Array = []  # Spike's breaker: the axes hovering over its foes
var _brk_passed: Dictionary = {}  # foes the dash breaker has cut through


func _ready() -> void:
	hp = max_hp
	Game.enemy_killed.connect(_on_enemy_killed)
	Game.leveled_up.connect(_on_level_up)
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

	var comic := ComicLook.scene(ComicLook.hero_kind())
	_comic_hero = comic != null
	model = comic.instantiate() if _comic_hero else MODEL.instantiate()
	add_child(model)
	if _comic_hero:
		ComicLook.apply(model, ComicLook.hero_kind())
	else:
		HERO_LOOK.dress(model)
	Fx.outline(model)
	if not _comic_hero:  # he's modelled with his hair, mantle, feathers and axes
		HERO_LOOK.add_kit(model)
	_meshes = model.find_children("*", "MeshInstance3D", true, false)
	_awaken_rim = Fx.rim_material().duplicate()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name in HIDDEN_MESHES:
			mi.visible = false
		elif mi.name in TRAIL_MESHES:
			_add_trail(mi)
	if _comic_hero:
		for blade in ComicLook.hero_blades(model):
			_add_trail(blade)
	anim = model.find_child("AnimationPlayer", true, false)
	_coats = _coat_axes()  # after _meshes: coats are swapped on ascend
	if _comic_hero:
		var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var void_arm := VOID_ARM.new()
		void_arm.setup(self, model, skel)
		if ComicLook.hero_kind() == ComicLook.HERETIC:  # free tentacle at rest; weapons only form to strike
			void_arm.rest_form = "hand"
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
	_aura = CPUParticles3D.new()
	_aura.amount = 24
	_aura.lifetime = 0.8
	_aura.emitting = false
	_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_aura.emission_sphere_radius = 0.8
	_aura.direction = Vector3.UP
	_aura.spread = 25.0
	_aura.gravity = Vector3.ZERO
	_aura.initial_velocity_min = 1.2
	_aura.initial_velocity_max = 2.4
	_aura.scale_amount_min = 0.6
	_aura.scale_amount_max = 1.2
	var dot := SphereMesh.new()
	dot.radius = 0.06
	dot.height = 0.12
	_aura.mesh = dot
	var aura_mat := Ascendancy.glow_mat(Color.WHITE)
	aura_mat.vertex_color_use_as_albedo = true
	_aura.material_override = aura_mat
	_aura.position.y = 1.0
	add_child(_aura)
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
	if _comic_hero:
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


## The mesh spirit casts ghost. The comic hero's axes are skinned in place, far from any
## usable origin, so his spirits keep throwing KayKit's axe.
func _axe_mesh() -> Mesh:
	if not _comic_hero:
		return (model.find_child("1H_Axe", true, false) as MeshInstance3D).mesh
	if _kaykit_axe == null:
		var kaykit := MODEL.instantiate()
		_kaykit_axe = (kaykit.find_child("1H_Axe", true, false) as MeshInstance3D).mesh
		kaykit.free()
	return _kaykit_axe


func _coat_axes() -> Array[Node3D]:
	if _comic_hero:
		return ComicLook.infuse_axes(model, element())
	return HERO_LOOK.coat_axes(model, element())


## What the rig calls a clip the game asks for.
func _clip_name(wanted: String) -> String:
	return ComicLook.clip(anim, ComicLook.hero_kind(), wanted) if _comic_hero else wanted


func _comic_moves_on() -> bool:
	return _comic_hero and Game.comic_moves


## A beat of an ultimate; under Game.comic_moves one Ab_ clip covers them all.
func _ult_anim(clip: String, blend: float, seek_to := 0.0) -> void:
	if _comic_moves_on():
		return
	_play(clip, blend, true)
	if seek_to > 0.0:
		anim.seek(anim.current_animation_length * seek_to, true)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	# Fx.flash clears overlays on hit; put the Awakening rim or axe runes back.
	for mi: MeshInstance3D in _meshes:
		if mi.material_overlay == null and (awakened or mi.has_meta("rest_overlay")):
			mi.material_overlay = _awaken_rim if awakened else _rest_overlay(mi)
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
		State.ULT: _state_ult(delta)
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
		model.position.x = move_toward(model.position.x, 0.0, 6.0 * delta)  # out of a weave
		model.position.z = move_toward(model.position.z, 0.0, 6.0 * delta)
	if model.position.y < 0.05:
		_air_dashes = 0  # back on the floor: the air dash comes back
		_gusted = false
		if is_instance_valid(_gust_cloud):
			AIR_GUST.vanish(_gust_cloud, get_parent())
		_gust_cloud = null
	var swinging: bool = state == State.ULT or (state == State.ATTACK and _state_t * anim_speed * _anim_mult / _move_len < _move.cancel)
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
	elif _void != null and Input.is_action_just_pressed("special"):
		_buffered = "special"
		_buffer_t = input_buffer
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
	return _comic_hero and _mouse_active and not bot_enabled and DisplayServer.get_name() != "headless"


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
	var speed := move_speed * (1.2 * _path("speed", 1.0) if awakened else 1.0)
	var target := dir * speed
	var grip := accel * (FLING_ACCEL_MULT if _fling_t > 0.0 else 1.0)
	velocity.x = move_toward(velocity.x, target.x, grip * delta)
	velocity.z = move_toward(velocity.z, target.z, grip * delta)
	_face(_mouse_dir() if _mouse_aiming() else dir)
	_play_locomotion(dir)

	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0:
		_start_dash()
	elif _buffered == "heavy" and _next_move("heavy") == "H" and Input.is_action_pressed("attack_heavy"):
		_start_charge()
	elif _buffered != "":
		_start_attack(_next_move(_buffered))


## Idle or a run. The comic hero has a clip per direction relative to where he faces; they share
## one cycle, so a change of clip carries on from the same step.
func _play_locomotion(dir: Vector3) -> void:
	if dir.length() <= 0.1:
		if _comic_hero:
			_comic_stand()
		else:
			_play("Idle", 0.12)
	elif not _comic_hero:
		_play("Running_A", 0.12)
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
		_start_attack("CH" if _charged else "H")


## The move's height off the floor at progress `t`: comes down from where it
## started by `land` (first hit), plus its own `hop` arc.
func _hop(t: float) -> void:
	var y := 0.0
	if _move.get("air", false):  # air move: hold the height it started at
		# `climb`: rise this much more by the hit, so each air cut goes higher.
		var cap := AIR_GUST_HEIGHT if _gusted else AIR_MAX_HEIGHT
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


## MOVES `weave`: sway the model sideways, crossing over on each hit (a
## sine from the first hit to the last), easing back to centre after.
func _weave(t: float) -> void:
	var w: float = _move.get("weave", 0.0)
	var side := Vector3.ZERO
	if w > 0.0:
		var hits: Array = _move.hits
		var a: float = hits[0] - 0.08
		var b: float = hits[hits.size() - 1]
		if t > a and t < b:
			var k := (t - a) / (b - a)
			var right := _facing().cross(Vector3.UP)
			side = right * sin(k * PI * hits.size()) * w * sin(k * PI)
	model.position.x = side.x
	model.position.z = side.z


## Landing from a hop: dust, a ring in the hero's colour and a shake, all
## bigger the further he fell (an air-string Triple Chop lands hardest).
func _land_slam(peak: float) -> void:
	var k := 1.0 + (SLAM_SCALE - 1.0) * clampf((peak - 0.4) / (SLAM_FULL_HEIGHT - 0.4), 0.0, 1.0)
	Fx.dust(get_parent(), global_position, int(6 * k), 0.5 * k)
	Fx.ring(get_parent(), global_position + _facing() * 0.8, Color(_fx_color(), 0.8), 2.2 * k, 0.22)
	Game.shake(0.12 * k)
	if _hop_y0 >= PLUNGE_AXES_FROM and not _move.get("air", false):
		_plunge_axes()
	if _hop_y0 >= STORMFALL_FROM and not _move.get("air", false):
		_stormfall()


## The top-of-the-air-string plunge's crater: three giant spectral axes
## (visual guillotines, `_axe_fall`) bury themselves in a fan ahead of him,
## the middle one first, sized with the chain like the casts.
func _plunge_axes() -> void:
	var fwd := _facing()
	var size := 2.4 * _cast_grow()
	for i in 3:
		var side := i - 1  # -1, 0, 1
		var dir := fwd.rotated(Vector3.UP, deg_to_rad(PLUNGE_AXES_SPREAD * side))
		var at := global_position + dir * (2.4 if side == 0 else 2.0)
		_axe_fall(at, dir, size * (1.0 if side == 0 else 0.8), 0.05 * absi(side))


## Landing from the top of the Updraft: the floor breaks under him, and off
## a Triple Chop (Stormfall) the element erupts in a ring round the crater.
func _stormfall() -> void:
	var el := element()
	var at := global_position + _facing() * 1.2
	BREAKER_QUAKE.crater(get_parent(), at, el, 3.2, true, _move_id == "L3")
	BREAKER_QUAKE.shockwave(get_parent(), at, _fx_color(), 5.5 if _move_id == "L3" else 4.0)
	Game.sfx("quake", -3.0, 0.05)
	Game.shake(0.5)
	if _move_id == "L3":
		BREAKER_QUAKE.eruption(get_parent(), at, el, 4.2, 0.05)
		ELEMENTS.sky_impact(get_parent(), at, el, 3.0)
	stormfalls += 1


func _state_attack(delta: float) -> void:
	var t := _state_t * anim_speed * _anim_mult / _move_len  # normalized progress
	if _void != null:
		_void.attack_tick(t, delta)
	if _mouse_aiming() and not _hop_air and _move_id != "AF":  # (in the air _air_home has him; AF has its spot)
		_face(_turned(_aim_want(), (COMBO_TURN_WINDUP if _hits_done == 0 else COMBO_TURN_ACTIVE) * delta))
	# Lunge decays quickly so attacks feel snappy, not slidey.
	var lunge: float = _move.lunge * maxf(0.0, 1.0 - t * _move.get("decay", 3.0))
	var fwd := _facing()
	velocity.x = fwd.x * lunge
	velocity.z = fwd.z * lunge

	_hop(t)
	if model.position.y > 0.3 and named_id() == "STORMFALL":  # the comet trail down
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = AIR_GUST.COMET_STEP
			AIR_GUST.comet(get_parent(), model, _fx_color(), element())
	_weave(t)
	var hits: Array = _move.hits
	while _hits_done < hits.size() and t >= hits[_hits_done]:
		_hits_done += 1
		_do_hit()
		if _move.get("blades", false):  # Gale Waltz: a wind blade rakes down off each cut, left, right, then a big one dead ahead
			var last := _hits_done == hits.size()
			var side := 0.0 if last else (-30.0 if _hits_done % 2 == 1 else 30.0)
			AIR_GUST.wind_blade(get_parent(), global_position + Vector3.UP * (model.position.y + 1.0),
				_facing().rotated(Vector3.UP, deg_to_rad(side)), _fx_color(), element(), 5.5 if last else 4.5, last)
		if _move.has("weave"):  # each cut of the dance leaves a spectral copy of him behind
			Fx.afterimage(get_parent(), model, Color(_fx_color(), 0.4))
	if BREAKERS.has(_move_id) and _connected and t >= _move.get("leap", BREAKERS[_move_id].leap):  # (a whiff plays out normally)
		_start_leap(_move_id)
		return

	# Dash cancels anything once the first hit has come out (or early on whiff).
	if _dash_buffer_t > 0.0 and _dash_cd <= 0.0 and (_hits_done > 0 or t > 0.2):
		if _hits_done > 0 and has_upgrade("static_step"):
			_proc("static_step")
			_static_trap(global_position)
		if _hits_done > 0 and has_upgrade("shockstep") and _move_id in SHATTER_MOVES:
			_shockstep(global_position)
		_start_dash()
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
	if has_upgrade("slipstream"):
		_slipstream()
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
## ring it with the timing cue (BREAKERS).
func _start_leap(id: String) -> void:
	_brk_id = id
	_brk = BREAKERS[id]
	_brk_phase = 0
	_brk_press = -1.0
	_brk_locked = false
	_brk_held = false
	_brk_thrown = 0
	_brk_spikes.clear()
	_brk_blasted = {}
	_brk_cue = null
	_brk_wheel = null
	_brk_passed = {}
	_brk_focus = false
	_brk_ended = ""
	_brk_volley.clear()
	_breaker_prompt()
	_brk_ancestor = null
	_brk_dir = _facing()
	var ahead := minf(_brk.zone, _clear_ahead(_brk_dir, _brk.zone) + 0.3)
	_brk_zone = Vector3(global_position.x, 0.0, global_position.z) + _brk_dir * ahead
	_buffered = ""
	_set_state(State.LEAP)
	_play("Jump_Start", 0.05, true)
	Game.sfx("dash", -4.0, 0.05)
	Fx.dust(get_parent(), global_position, 10, 0.8)
	Fx.ring(get_parent(), global_position, Color(_fx_color(), 0.8), 1.6, 0.25)
	if not _brk.has("dash"):  # he kicks off hard enough to crack the floor
		BREAKER_QUAKE.crater(get_parent(), global_position, element(), 1.4, false)


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
	if _brk_phase == 0:
		if t < b.rise:  # hop back (forward if `back` < 0) while rising
			var k: float = t / b.rise
			velocity.x = -_brk_dir.x * b.back / b.rise
			velocity.z = -_brk_dir.z * b.back / b.rise
			model.position.y = b.height * (1.0 - pow(1.0 - k, 3.0))
		else:
			model.position.y = b.height + sin((t - b.rise) * 9.0) * 0.06  # hangs
			var hang: String = b.get("hang_anim", "Jump_Idle")
			if anim.current_animation != hang and _brk_thrown >= b.spikes and not b.has("juggle"):
				_play(hang, 0.15)
		_face(_brk_dir)
		if b.spikes > 0 and t >= b.throw and _brk_thrown == 0:
			_play("Spellcast_Shoot", 0.05, true)
		if b.has("juggle") and t >= b.throw:
			_juggle()
		if b.has("volley") and t >= b.throw and _brk_volley.is_empty():
			_volley_raise()
		while _brk_thrown < b.spikes and t >= b.throw + _brk_thrown * 0.03:
			_throw_spike()
		if t >= b.cue and _brk_cue == null:
			_brk_cue = BREAKER_CUE.new()
			_brk_cue.color = _fx_color()
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
			BREAKER_QUAKE.war_cry(get_parent(), global_position + Vector3.UP * (model.position.y + 1.5), _fx_color(), element())
			if awakened and not b.has("dash") and not b.has("fan"):
				_breaker_ancestor()
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
			for g in _brk_volley:
				if is_instance_valid(g):
					g.cancel()
			_brk_volley.clear()
			if is_instance_valid(_brk_ancestor):
				_brk_ancestor.queue_free()  # no dive: it never lands
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
			if b.has("dash"):
				Fx.afterimage(get_parent(), model, Color(_fx_color(), 0.5))
			else:  # the dive comes down like a comet in his element
				AIR_GUST.comet(get_parent(), model, _fx_color(), element())
		if b.has("dash"):
			_dash_cut()
		if k >= 1.0:
			_breaker_impact()
	else:
		var k: float = clampf(t / b.fall, 0.0, 1.0)
		model.position.y = b.height * (1.0 - k * k)
		if k >= 1.0:
			_end_leap()
			Fx.dust(get_parent(), global_position, 8, 0.6)


## The juggle (BREAKERS `juggle`): spin in the air inside a spectral
## sawblade that grinds the launched foes and keeps them up.
func _juggle() -> void:
	var b := _brk
	if anim.current_animation != "2H_Melee_Attack_Spinning" or not anim.is_playing():
		_play("2H_Melee_Attack_Spinning", 0.05, true)
	if b.has("pull"):  # the whirlwind drags foes in (never closer than 1.2 m)
		var step: float = b.pull * get_physics_process_delta_time()
		for e in Ascendancy.enemies_near(get_tree(), global_position, b.pull_radius):
			if e.has_method("is_boss"):
				continue
			var to: Vector3 = global_position - e.global_position
			to.y = 0.0
			if to.length() > 1.2:
				e.global_position += to.normalized() * minf(step, to.length() - 1.2)
	if _brk_wheel != null:
		return
	var wh = _spirit(SPIRIT_WHEEL.new(), {"damage": b.juggle_damage}, element())
	wh.count = b.juggle_axes
	wh.radius = b.juggle_radius * _cast_grow()
	wh.time = b.close - b.throw + 0.1
	wh.turns = 3.5
	model.add_child(wh)  # rides up with him
	_brk_wheel = wh
	Game.sfx("swing", -6.0, 0.1)


## Awakened dive breakers: a giant ancestor rises behind the zone as the
## window opens and brings its axe down on it as the hero dives (visual).
func _breaker_ancestor() -> void:
	var b := _brk
	var av = _spirit(SPIRIT_AVATAR.new(), {"damage": 0.0}, element())
	av.fwd = _brk_dir
	av.scale_to = BREAKER_ANCESTOR
	av.speed = SPIRIT_AVATAR.speed_for(b.sweet - b.open + b.dive)
	av.impact_fx = false
	get_parent().add_child(av)
	av.global_position = _brk_zone
	av.global_position += _brk_zone - av.land_point()  # its axe head lands on the zone
	_brk_ancestor = av


## Spike's breaker: a spectral axe hovering point-down over each foe near the
## zone (one over the zone if there are none), following them (BREAKERS `volley`).
func _volley_raise() -> void:
	var b := _brk
	var foes: Array = Ascendancy.enemies_near(get_tree(), _brk_zone, b.volley_radius)
	foes.sort_custom(func(a: Node3D, c: Node3D) -> bool:
		return a.global_position.distance_squared_to(_brk_zone) < c.global_position.distance_squared_to(_brk_zone))
	var shared := {}
	var n := maxi(mini(foes.size(), b.volley_max), 1)
	for i in n:
		var gu = _spirit(SPIRIT_GUILLOTINE.new(), {"damage": b.volley_damage * _cast_power()}, element())
		gu.fwd = _brk_dir
		gu.size = b.volley_size * _cast_grow()
		gu.radius = 1.6
		gu.heavy = false
		gu.wait = true
		gu.shared = shared
		if i < foes.size():
			gu.target = foes[i]
		get_parent().add_child(gu)
		gu.global_position = Vector3(foes[i].global_position.x, 0.0, foes[i].global_position.z) if i < foes.size() else _brk_zone
		_brk_volley.append(gu)
	Game.sfx("ult", -10.0, 0.1)


## The dash breaker cuts each foe it passes once (BREAKERS `dash`).
func _dash_cut() -> void:
	var b := _brk
	for e in Ascendancy.enemies_near(get_tree(), global_position, b.width):
		if _brk_passed.has(e):
			continue
		_brk_passed[e] = true
		var side: Vector3 = e.global_position - global_position
		side.y = 0.0
		side = (side - _brk_dir * side.dot(_brk_dir)).normalized()
		e.take_hit(b.pass_damage * _dmg_mult * _cast_power(), side * 6.0 + _brk_dir * 2.0, 0.0, true)
		Game.register_hit("breaker")
		_cast_hit(e)
		Fx.element_hit(get_parent(), e.global_position + Vector3.UP, element(), _brk_dir)
		Game.hitstop(0.03)


func _drop_wheel() -> void:
	if is_instance_valid(_brk_wheel):
		_brk_wheel.queue_free()
	_brk_wheel = null


## The breaker press this frame: heavy, or the autotest bot at the sweet spot.
func _breaker_pressed(t: float) -> bool:
	if bot_enabled:
		return t >= _brk.sweet
	return Input.is_action_just_pressed("attack_heavy")


func _throw_spike() -> void:
	var b := _brk
	var i := _brk_thrown
	_brk_thrown += 1
	var s := BREAKER_SPIKE.new()
	s.axe_mesh = _axe_mesh()
	s.el = element()
	s.color = _fx_color()
	s.damage = b.spike_damage * _dmg_mult
	s.detonate_damage = b.detonate * _dmg_mult * _cast_power()
	s.on_hit = _cast_hit
	s.blasted = _brk_blasted
	s.size = 1.5 * _cast_grow()
	# Centre one, then spiralling out (golden angle, so they spread evenly).
	var off := Vector3.ZERO
	if i > 0:
		var ang := i * 2.39996
		off = Vector3(sin(ang), 0.0, cos(ang)) * b.spread * sqrt(float(i) / b.spikes)
	s.from = global_position + Vector3.UP * (model.position.y + 1.3)
	s.to = _brk_zone + off
	s.life = b.close - b.throw + 0.5
	get_parent().add_child(s)
	_brk_spikes.append(s)
	Game.sfx("swing", -10.0, 0.2)


func _start_dive() -> void:
	_brk_phase = 1
	_state_t = 0.0
	_drop_wheel()
	_brk_dive_from = global_position
	var perfect: bool = absf(_brk_press - _brk.sweet) <= _brk.perfect
	_brk_ended = "perfect" if perfect else "hit"
	for i in _brk_volley.size():  # the axes fall with him
		if is_instance_valid(_brk_volley[i]):
			_brk_volley[i].drop(maxf(_brk.dive - _brk_volley[i].fall, 0.0) + 0.02 * i)
	_brk_volley.clear()
	if is_instance_valid(_brk_cue):
		_brk_cue.hit(perfect)
	if _brk_focus:
		Game.end_slowmo()
	if perfect:
		Game.hitstop(BREAKER_PERFECT_STOP, 0.05)
		Game.sfx("perfect", -4.0, 0.0)
	if _brk.has("dash"):
		_play("Dodge_Forward", 0.03, true)
		Game.sfx("dash", 0.0, 0.0)
		var run := (_brk_zone - global_position).length()
		Fx.dash_streak(get_parent(), global_position, _brk_dir, run, Color(_fx_color(), 0.8))
	else:
		_play("2H_Melee_Attack_Chop", 0.04, true)
		anim.seek(anim.current_animation_length * 0.3, true)
	Game.sfx("ult", -6.0, 0.0)
	Fx.flash(model)
	if Game.camera_rig:
		Game.camera_rig.punch(0.85, 0.3)


## The dive lands: detonate the spikes, blast the zone, name the breaker.
func _breaker_impact() -> void:
	var b := _brk
	var el := element()
	var at := Vector3(global_position.x, 0.0, global_position.z)
	var perfect: bool = absf(_brk_press - b.sweet) <= b.perfect
	var mult: float = (b.perfect_mult if perfect else 1.0) * _cast_power()
	if b.has("dash"):
		_dash_wake(b.damage * _dmg_mult * mult, perfect)
	elif b.has("fan"):
		_fan_release(mult, perfect)
		SPIRIT_AVATAR.slam_fx(get_parent(), at, el, b.radius, Vector3.ZERO, false)
	else:
		ELEMENTS.sky_impact(get_parent(), at, el, b.radius)
		SPIRIT_AVATAR.slam_fx(get_parent(), at, el, b.radius * 0.9, _brk_dir)
		_axe_fall(at, _brk_dir, 4.6 if perfect else 3.8)
	# Barbaric landing: the floor breaks (the dash breaker's wake is its own
	# crater), and a perfect makes the element answer the blow all round it.
	if b.has("dash"):
		if perfect:
			BREAKER_QUAKE.eruption_line(get_parent(), _brk_dive_from, _brk_dir, (at - Vector3(_brk_dive_from.x, 0.0, _brk_dive_from.z)).length(), el)
	else:
		BREAKER_QUAKE.crater(get_parent(), at, el, maxf(b.radius, 2.4), true, perfect)
		if perfect:
			BREAKER_QUAKE.eruption(get_parent(), at, el, maxf(b.radius, 2.4) * 1.35)
		Game.sfx("quake", -2.0 if perfect else -5.0, 0.05)
	if ascendancy != "":  # the landing sets off every prime round him
		_rite_set_off(b.perfect_mult if perfect else 1.0)
	for s in _brk_spikes:
		if is_instance_valid(s):
			s.detonate()
	if b.radius > 0.0:
		ELEMENTS.hit_area(get_tree(), at, b.radius, b.damage * _dmg_mult * mult, b.launch, true, "breaker", _cast_hit)
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


## The Cyclone breaker's release: a ring of spectral tomahawks flung out in
## every direction, each boomeranging back to him (BREAKERS `fan`). Awakened:
## half as many again, bigger.
func _fan_release(mult: float, perfect: bool) -> void:
	var b := _brk
	var n: int = b.fan + (b.fan / 2 if awakened else 0)
	var g := _cast_grow() * (1.3 if awakened else 1.0) * (1.15 if perfect else 1.0)
	var fwd := _facing()
	var shared := {}  # each foe hit once per leg by the whole ring
	for i in n:
		var th = _spirit(SPIRIT_TOMAHAWK.new(), {"damage": b.fan_damage * mult}, element())
		th.shared = shared
		th.dir = fwd.rotated(Vector3.UP, TAU * i / n)
		th.hero = self
		th.size = 2.2 * g
		th.reach = minf(b.fan_range, _clear_ahead(th.dir, b.fan_range) + 0.4)
		th.back_damage = b.fan_back * _dmg_mult * mult
		get_parent().add_child(th)
		th.global_position = Vector3(global_position.x, 0.0, global_position.z) + th.dir * 0.6
	Game.sfx("swing_heavy", 0.0, 0.05)


## The dash breaker's end: he turns out of the dash with a slash and the line
## behind him erupts in spectral axes, hitting everything along it.
func _dash_wake(damage: float, perfect: bool) -> void:
	var b := _brk
	var line := global_position - _brk_dive_from
	line.y = 0.0
	var length := maxf(line.length(), 2.0)
	_play("2H_Melee_Attack_Slice", 0.04, true)
	anim.seek(anim.current_animation_length * 0.3, true)
	var rf = _spirit(SPIRIT_RIFT.new(), {"damage": 0.0}, element())
	rf.fwd = _brk_dir
	rf.length = length + 0.6
	rf.steps = clampi(int(length / 1.0), 4, 9)
	rf.step_time = 0.025
	rf.size_from = 2.2
	rf.size_to = 4.2 if perfect else 3.4
	if awakened:
		rf.size_from *= BREAKER_AWAKENED_WAKE
		rf.size_to *= BREAKER_AWAKENED_WAKE
	get_parent().add_child(rf)
	rf.global_position = Vector3(_brk_dive_from.x, 0.0, _brk_dive_from.z)
	var from := Vector3(_brk_dive_from.x, 0.0, _brk_dive_from.z)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - from
		to.y = 0.0
		if e.is_alive() and _in_strip(to, _brk_dir, length, b.width, e.radius):
			e.take_hit(damage, Vector3.UP, b.launch, true)
			Game.register_hit("breaker")
			_cast_hit(e)


func _breaker_callout(text: String, perfect: bool) -> void:
	Game.sfx(COMBO_TIER_SFX[2], COMBO_SFX_DB, 0.0)
	_callout.text = text + ("\nPERFECT" if perfect else "")
	_callout.modulate = COMBO_TIER_COLORS[2] if perfect else _fx_color().lerp(Color.WHITE, 0.3)
	Fx.combo_pop(get_parent(), global_position, _callout.modulate, 3 if perfect else 2)
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


## Dash out of a breaker's hang (before the press): the breaker is off, its
## pieces go (hovering axes, ancestor, floor cue, sawblade), the slow motion
## ends and he dashes. The prompt shows it as a miss.
func _leap_dash_out() -> void:
	_brk_ended = "miss"
	for g in _brk_volley:
		if is_instance_valid(g):
			g.cancel()
	_brk_volley.clear()
	if is_instance_valid(_brk_ancestor):
		_brk_ancestor.queue_free()
	if is_instance_valid(_brk_cue):
		_brk_cue.queue_free()
	if _brk_focus:
		Game.end_slowmo()
	_drop_wheel()
	velocity = Vector3.ZERO
	_brk_spikes.clear()
	_brk_cue = null
	_chain_i = 0
	_set_state(State.MOVE)  # (the model settles from the hang during the dash)
	_start_dash()


func _end_leap() -> void:
	_drop_wheel()
	velocity = Vector3.ZERO  # (the dive / dash speed would carry on)
	model.position.y = 0.0
	_brk_spikes.clear()
	_brk_cue = null
	_chain_i = 0
	_set_state(State.MOVE)


# --- Actions ----------------------------------------------------------------

func _next_move(kind: String) -> String:
	return _routed(kind, _route_from(), state == State.ATTACK, _chain_i, _post_dash_t > 0.0, awakened, _gusted)


## route() for the hero he is: the comic hero has his own, smaller move set for now.
func _routed(kind: String, from: String, attacking: bool, chain: int, post_dash: bool, awake: bool, gusted: bool) -> String:
	if _comic_hero:
		return void_route(kind, from, attacking, chain, post_dash)
	return route(kind, from, attacking, chain, post_dash, awake, gusted)


## The comic hero's presses. Lights run the weapons: axe, spear, hammer. E off anything is the slam
## (so L L L E is the whole string into it), from neutral the grab. No air string or ultimates while
## the void arm's moves are worked out; route() below is untouched for them to come back to.
static func void_route(kind: String, from: String, attacking: bool, chain: int, post_dash: bool) -> String:
	if kind == "special":
		return "VS" if attacking and from != "VS" else "GR"
	if kind == "light":
		return "DL" if post_dash else LIGHT_CHAIN[chain % LIGHT_CHAIN.size()]
	return "DH" if post_dash and not attacking else "H"


## The `from` route() sees: "AD" just out of an air dash, else the last move.
func _route_from() -> String:
	return "AD" if _air_dash and (state == State.DASH or (state == State.MOVE and _post_dash_t > 0.0)) else _move_id


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


## What dash-then-light starts from here (the combo guide's dash row).
func dash_light() -> String:
	return "AL1" if _can_air_dash() else "DL"


## The move a "light" or "heavy" press starts. `from` is the move playing (or
## the last one), `attacking` whether it's still going, `chain` the light
## chain position, `post_dash` just out of a dash. The combo guide asks this
## too (with made-up states to look one press ahead), so they always agree.
static func route(kind: String, from: String, attacking: bool, chain: int, post_dash: bool, awake: bool, gusted := false) -> String:
	if kind == "light":
		if post_dash:
			return "AL1" if from == "AD" else "DL"  # (an air dash keeps the air string going)
		if attacking and from == "LH":
			return "AL1"  # off the launcher: into the air
		if attacking and from == "AL1":
			return "AL2"
		if attacking and from == "AH":
			return "AL3"  # riding the gale
		if attacking and from in ["AL2", "AL3"]:
			return "L3"  # Triple Chop slams down from the air
		if not attacking and from == "L2" and chain == 2:
			return "LPL"  # L2 has finished: the pause turns the third light into Flurry
		return LIGHT_CHAIN[chain % LIGHT_CHAIN.size()]
	# Heavy: Cyclone out of a dash, Awakened ultimates off L3 / LH / DL,
	# launcher if mid-string, spin from neutral.
	if post_dash and not attacking:
		if from == "AD":
			return "SKY" if awake else "LHH"  # Spike down out of the air dash
		return "DH"
	if awake and attacking and from == "L3":
		return "AF"
	if attacking and from == "AL2" and not gusted:
		return "AH"  # Updraft: the gale lifts him higher (once per trip up)
	if awake and attacking and from in ["LH", "AL1", "AL2", "AH", "AL3"]:
		return "SKY"
	if attacking and from in ["LH", "AL1", "AL2", "AH", "AL3"]:
		return "LHH"  # Spike, from the air
	if awake and attacking and from == "DL":
		return "RUSH"
	if (attacking and from == "L2") or (not attacking and chain == 2):
		return "LLH"
	if (attacking and from != "H") or chain > 0:
		return "LH"
	return "H"


## Light chain position after `id` starts.
static func chain_after(id: String) -> int:
	if id in LIGHT_CHAIN:
		return (LIGHT_CHAIN.find(id) + 1) % LIGHT_CHAIN.size()
	if id == "DL":
		return 1  # a dash stab flows into L2
	return 0


## What the combo guide shows right now: one row per input that continues the
## string ("light", "heavy", "dash" = dash then light), each with the move it
## starts and the best named combo one more press past it, plus `pause` when
## waiting for the move to finish first starts a different named combo (L2:
## Flurry). Empty when there's no string to continue.
func combo_options() -> Array:
	var attacking := state == State.ATTACK
	var dashing := state == State.DASH or _post_dash_t > 0.0
	var live := attacking or dashing or state == State.CHARGE or (state == State.MOVE and _chain_i > 0)
	if not live or (attacking and _move_id == "AF"):
		return []  # (the finisher has the screen to itself)
	if state == State.CHARGE:
		return [_option("heavy", "CH", true)]
	var rows := []
	var kinds: Array[String] = ["light", "heavy"]
	if _comic_hero:
		kinds.append("special")
	for kind: String in kinds:
		var id := _routed(kind, _route_from(), attacking, _chain_i, dashing, awakened, _gusted)
		if kind == "special" and id != "VS":
			continue  # the grab isn't a continuation
		if kind == "heavy" and id == "H":
			continue  # the plain spin isn't a continuation
		var o := _option(kind, id)
		if id == "L3" and attacking and model.position.y >= PLUNGE_AXES_FROM:
			var fall := "STORMFALL" if model.position.y >= STORMFALL_FROM else "SKYFALL"
			o.name = combo_name(fall)  # from up here it plunges as Skyfall / Stormfall (named_id())
			o.tier = COMBOS[fall].tier
		if attacking:
			var wait := _routed(kind, _move_id, false, _chain_i, false, awakened, _gusted)
			if wait != id and COMBOS.has(wait):
				o.pause = {"id": wait, "name": guide_name(wait), "tier": COMBOS[wait].tier}
		rows.append(o)
	if attacking and not dashing:
		rows.append(_option("dash", dash_light()))
	return rows


## The breaker timing prompt (breaker_prompt.gd) reads this every frame:
## `live` while the press is still to come (times in s since take-off, the
## hero's colour); otherwise how the last one `ended` ("perfect", "hit",
## "lock" = too early, "miss" = no press).
func breaker_window() -> Dictionary:
	if state == State.LEAP and _brk_phase == 0 and not _brk_locked:
		var b := _brk
		return {"live": true, "t": _state_t, "open": b.open, "sweet": b.sweet, "close": b.close, "color": _fx_color(),
			"name": breaker_name()}
	return {"ended": _brk_ended}


func _breaker_prompt() -> void:
	if _brk_prompt != null:
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	_brk_prompt = BREAKER_PROMPT.new()
	_brk_prompt.player = self
	layer.add_child(_brk_prompt)


## The breaker in play's name for the current element.
func breaker_name() -> String:
	return _brk.names.get(element(), _brk.names.spirit) if not _brk.is_empty() else ""


func _option(kind: String, id: String, hold := false) -> Dictionary:
	var o := {"kind": kind, "id": id, "name": guide_name(id), "tier": COMBOS[id].tier if COMBOS.has(id) else 0,
		"ult": ULTIMATES.has(id) or id == "AF", "hold": hold, "next": {}}
	if o.tier < 3 and not hold:
		var best := 0
		for k: String in (["special", "heavy", "light"] if _comic_hero else ["heavy", "light"]):  # heavy first: wins ties
			var n := _routed(k, id, true, chain_after(id), false, awakened, _gusted or id == "AH")
			var tier: int = COMBOS[n].tier if COMBOS.has(n) and n != "CH" else 0
			if combos_landed.get(n, 0) >= GUIDE_LEARNED and not (ULTIMATES.has(n) or n == "AF"):
				tier = 0  # learned: no need to hint it any more
			if tier > best:
				best = tier
				o.next = {"kind": k, "id": n, "name": guide_name(n), "tier": tier, "ult": ULTIMATES.has(n) or n == "AF"}
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
	if ULTIMATES.has(id):
		_start_ult(id)
		return
	if id == "GR" and _void.begin():
		return
	var prev_id := _move_id
	_move_id = id
	_move = _effective_move(id)
	_anim_mult = _base_anim_mult() * _move.get("speed", 1.0)
	if id in LIGHT_MOVES and has_upgrade("quickblade"):
		_proc("quickblade")
		_anim_mult *= 1.0 + upg("quickblade", "speed") / 100.0
	if _crescendo and id in SHATTER_MOVES:
		_crescendo = false
		_move.damage *= 1.0 + upg("crescendo", "bonus") / 100.0
		_move.knockback *= 1.5
		_proc("crescendo")
		Fx.flash(model)
		Fx.burst(get_parent(), global_position + Vector3.UP, Upgrades.PATHS.heavy.color, 16, 5.0, 0.1, 0.3, Vector3.UP, 70.0)
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
	if is_instance_valid(_gust_cloud) and not _move.get("air", false):
		AIR_GUST.vanish(_gust_cloud, get_parent())  # he dives off the gale
		_gust_cloud = null
	if _move.get("gust", false):
		_gusted = true
		_air_dashes = 0  # the gale gives the air dash back
		AIR_GUST.gust(get_parent(), global_position, model, _fx_color(), element())
		if not is_instance_valid(_gust_cloud):
			_gust_cloud = AIR_GUST.cloud(model, _fx_color())
	_set_state(State.ATTACK)
	if _void != null:
		_void.on_move(id, prev_id)
	attack_started.emit(id)
	Game.sfx("swing_heavy" if id in ["H", "LH", "LLH", "AF", "CH", "DH", "LHH", "AH"] else "swing", -3.0, 0.12)
	_play(_move.anim, 0.05, true)
	if id == "AF":
		_ult_begin(id)
		_move.damage *= _ult_mult()


func _start_dash() -> void:
	_air_dash = _can_air_dash()
	if _air_dash:
		_air_dashes += 1
	_dash_buffer_t = 0.0
	_dash_cd = dash_cooldown * (_path("dash_cd", 1.0) if awakened else 1.0) * (1.0 - _mastery("dash", "cooldown") / 100.0)
	_anim_mult = _base_anim_mult()
	_slipped.clear()
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
		return
	if _move_id == "VS":
		_void.slam_lands()
	var fwd := _facing()
	var named_before := _callout_done  # a combo ender lands its extra punch once
	_swoosh(fwd)
	var rite := ascendancy != "" and _move_id in RITE.HEAVIES
	if rite and _hits_done == 1:  # sets off what the last heavy laid down, before this one lays its own
		_rite_set_off(1.0)
	var hit_any := false
	var any_airborne := false
	var struck: Array[Vector3] = []  # where this hit's foes stand (earth wells lava under them)
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
		if _move_id == "LHH" and was_airborne:
			dmg *= SPIKE_AIR_MULT
		if was_airborne and _move_id in LIGHT_MOVES and has_upgrade("sky_reaper"):
			dmg *= 1.0 + upg("sky_reaper", "bonus") / 100.0
			_proc("sky_reaper")
		if _move_id == "CH" and has_upgrade("bone_breaker") and (e.shield or e.elite or e.has_method("is_boss")):
			_proc("bone_breaker")
			dmg *= 1.0 + upg("bone_breaker", "bonus") / 100.0
			Fx.ring(get_parent(), e.global_position, Color(1.0, 0.95, 0.8, 0.9), 1.4, 0.25)
		e.take_hit(dmg, kb_dir * _move.knockback, _move.launch, _move.get("big", false))
		Fx.element_hit(get_parent(), e.global_position, element(), kb_dir, _move.get("big", false))
		Game.register_hit(_move_id + ("_air" if was_airborne else ""))
		hit_any = true
		_connected = true
		if not e.is_alive() and _move_id in SHATTER_MOVES and has_upgrade("shatter") and not e.has_method("is_boss"):
			_proc("shatter")
			_shatter(e)
		if _move_id == "LHH" and was_airborne:
			_spike(e)
		if was_airborne and has_upgrade("chain_spark"):
			_proc("chain_spark")
			_chain_spark(e)
		if _move_id == "L1" and has_upgrade("bloodthirst"):
			_proc("bloodthirst")
			heal(upg("bloodthirst", "heal"), false)
		if _move_id in LIGHT_MOVES and has_upgrade("thousand_cuts") and e.is_alive():
			_thousand_cuts(e)
		if awakened and ascendancy != "":
			_element_hit(e)
		if rite:
			RITE.prime_foe(e, ascendancy)
			struck.append(e.global_position)
	# Slot effects that fire on the move's first active frame, hit or miss.
	if _hits_done == 1:
		_cast(fwd)
		if _move_id == "L3" and has_upgrade("ember_cleave"):
			_proc("ember_cleave")
			var w := FIRE_WAVE.new()
			w.direction = fwd
			w.damage = upg("ember_cleave", "damage")
			get_parent().add_child(w)
			w.global_position = global_position + fwd * 1.0
		if _move_id in ["AF", "LLH"]:
			_combo_callout(_move_id)  # big enough to name even on a whiff
		if _move_id == "AF":
			_finisher(fwd)
			_ult_landed()
		if rite and ascendancy == "earth":
			_rite_wells(fwd, struck)
		if _move_id == "LLH":
			ground_breakers += 1
			_crack_line(fwd, Color(0.85, 0.75, 0.6))
			if has_upgrade("fault_line"):
				_proc("fault_line")
				_fault_line(global_position, fwd)
		if _move_id == "CH":
			charged_slams += 1
			var at := global_position + fwd * 1.6
			Fx.ring(get_parent(), at, Color(CHARGE_COLOR, 0.9), _move.range, 0.3)
			Fx.burst(get_parent(), at + Vector3.UP * 0.2, CHARGE_COLOR, 24, 9.0, 0.14, 0.35, Vector3.UP, 80.0)
			Fx.dust(get_parent(), at, 16, 1.0)
			if has_upgrade("quake"):
				_proc("quake")
				_quake(at)
		if _move_id == "LH" and has_upgrade("skybreaker"):
			_proc("skybreaker")
			var r := upg("skybreaker", "radius")
			Fx.ring(get_parent(), global_position, Color(0.9, 0.95, 1.0, 0.8), r, 0.3)
			for e in get_tree().get_nodes_in_group("enemies"):
				var to: Vector3 = e.global_position - global_position
				to.y = 0.0
				if e.is_alive() and not e.is_airborne() and to.length() < r:
					e.take_hit(4.0, to.normalized() * 2.0, 8.0, false)
					Game.register_hit("skybreaker")
	if _move_id == "VS":
		_void.slam_landed()
	if _move_id == "LPL" and _hits_done == _move.hits.size() and has_upgrade("razor_gale"):
		_razor_gale(fwd)
	if _move_id == "DH" and has_upgrade("eye_of_storm"):
		_eye_of_storm()
	if hit_any:
		if _move_id == "L3" and has_upgrade("crescendo") and not _crescendo:
			_crescendo = true
			Fx.ring(get_parent(), global_position, Color(Upgrades.PATHS.heavy.color, 0.8), 1.6, 0.25)
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
	if has_upgrade("war_chant") and not awakened:
		_proc("war_chant")
		Game.add_awakening(upg("war_chant", "awaken") * (2.0 if id != _last_combo else 1.0))
	_last_combo = id
	combos_landed[id] = combos_landed.get(id, 0) + 1
	if combos_landed[id] == 1:
		combo_found.emit(id)
	Game.sfx(COMBO_TIER_SFX[tier - 1], COMBO_SFX_DB, 0.03)
	_callout.text = combo_name(id)
	_callout.modulate = Ascendancy.color(ascendancy) if id == "AF" and ascendancy != "" else COMBO_TIER_COLORS[tier - 1]
	Fx.combo_pop(get_parent(), global_position, _fx_color() if tier < 3 else _callout.modulate, tier)
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


# --- Elements and ultimates ---------------------------------------------------

## The hero's element: the Ascendancy path, or spirit before one.
func element() -> String:
	return ascendancy if ascendancy != "" else "spirit"


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


## Colour for the hero's own effects (dash ghosts and streak): Ascendancy
## colour while Awakened, otherwise the element's.
func _fx_color() -> Color:
	return Ascendancy.color(ascendancy) if awakened else ELEMENTS.color(element())


## Swing trail colour outside Awakening: the current element's.
func _trail_rest_color() -> Color:
	return Color(ELEMENTS.color(element()), 0.85)


## The element cast that comes with the current move (ELEMENTS.CASTS), on its first active frame.
func _cast(fwd: Vector3) -> void:
	if not ELEMENTS.CASTS.has(_move_id):
		return
	var c: Dictionary = ELEMENTS.CASTS[_move_id]
	var el := element()
	var parent := get_parent()
	ELEMENTS.casts += 1
	Game.sfx(ELEMENTS.LOOK[el].sfx, CAST_SFX_DB, 0.1)
	var g := _cast_grow()  # spirit weapons swell with the chain
	match c.kind:
		"bolt":
			var n: int = c.get("fan", 1)
			for i in n:
				var b := ELEMENTS.Bolt.new()
				b.el = el
				b.dir = fwd.rotated(Vector3.UP, deg_to_rad(c.get("spread", 0.0) * (i - (n - 1) * 0.5)))
				b.speed = c.speed
				b.reach = minf(c.range, _clear_ahead(b.dir, c.range) + 0.6)  # stops at walls
				b.damage = c.damage * _dmg_mult
				b.size = c.get("size", 1.0)
				b.tilt = c.tilt
				b.on_hit = _cast_hit
				parent.add_child(b)
				b.global_position = global_position + b.dir * 0.7 + Vector3.UP * (0.25 if el == "earth" else 1.0)
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
		"cleave":
			var cl = _spirit(SPIRIT_CLEAVE.new(), c, el)
			cl.fwd = fwd
			cl.size = c.size * g
			cl.blast = c.blast * g
			cl.launch = c.launch
			parent.add_child(cl)
			cl.global_position = _cast_target(fwd, c.reach, minf(c.ahead, _clear_ahead(fwd, c.ahead)))
		"avatar":
			var av = _spirit(SPIRIT_AVATAR.new(), c, el)
			av.fwd = fwd
			av.scale_to = c.size * g
			av.radius = c.radius * g
			av.launch = c.launch
			parent.add_child(av)
			av.global_position = Vector3(global_position.x, 0.0, global_position.z)
		"crown":
			var cr = _spirit(SPIRIT_CROWN.new(), c, el)
			cr.fwd = fwd
			cr.size = c.size * g
			cr.radius = c.radius * g
			cr.height = c.height * g
			cr.launch = c.launch
			parent.add_child(cr)
			cr.global_position = _cast_target(fwd, c.reach, c.ahead)
		"rift":
			var rf = _spirit(SPIRIT_RIFT.new(), c, el)
			rf.fwd = fwd
			rf.length = minf(c.length * g, _clear_ahead(fwd, c.length * g) + 0.5)
			rf.steps = c.steps
			rf.size_from *= g
			rf.size_to *= g
			rf.radius *= g
			rf.launch = c.launch
			parent.add_child(rf)
			rf.global_position = Vector3(global_position.x, 0.0, global_position.z)
		"wheel":
			var wh = _spirit(SPIRIT_WHEEL.new(), c, el)
			wh.count = c.count
			wh.radius = c.radius * g
			wh.time = c.time
			wh.turns = c.turns
			add_child(wh)  # follows the hero (Cyclone dashes)
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
		"guillotine":
			var gu = _spirit(SPIRIT_GUILLOTINE.new(), c, el)
			gu.fwd = fwd
			gu.size = c.size * g
			gu.radius = c.radius * g
			parent.add_child(gu)
			gu.global_position = _cast_target(fwd, c.reach, c.ahead)
		"vortex":
			ELEMENTS.vortex(self, el, c.radius, c.time)
		"pillar":
			var at := _cast_target(fwd, c.reach, c.ahead)
			ELEMENTS.pillar(parent, at, el, c.height, c.radius)
			ELEMENTS.hit_area(get_tree(), at, c.radius, c.damage * _dmg_mult, c.launch, false, "cast", _cast_hit)
		"fissure":
			ELEMENTS.fissure(parent, global_position, fwd, c.length, c.steps, el)
		"nova":
			var at := global_position + fwd * 1.6
			ELEMENTS.nova(parent, at, el, c.radius, c.count)
			ELEMENTS.hit_area(get_tree(), at, c.radius, c.damage * _dmg_mult, 6.0, true, "cast", _cast_hit)


## The common setup of a spirit cast node (spirit_*.gd): the hero's axe,
## colour, element, damage (scaled by the chain) and hit callback.
func _spirit(node: Node3D, c: Dictionary, el: String) -> Node3D:
	if "axe_mesh" in node:
		node.axe_mesh = _axe_mesh()
	node.color = _fx_color()
	node.el = el
	node.damage = c.damage * _dmg_mult * _cast_power()
	node.on_hit = _cast_hit
	return node


## Spirit casts grow with the chain: CAST_GROW more size/reach per Fx chain
## tier (10 / 20 / 35 hits), CAST_POWER more damage.
func _cast_grow() -> float:
	return 1.0 + CAST_GROW * Fx.chain_tier(Game.combo_count)


func _cast_power() -> float:
	return 1.0 + CAST_POWER * Fx.chain_tier(Game.combo_count)


## Element casts and ultimates hitting `e`: the Awakened path passive applies.
func _cast_hit(e: Node) -> void:
	if awakened and ascendancy != "":
		_element_hit(e)


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


func _ult_mult() -> float:
	return 1.0 + ULT_CHAIN_BONUS * maxi(_ult_chain - 1, 0)


## An ultimate starts: chain count, banner, slow-mo, camera punch, light.
func _ult_begin(id: String) -> void:
	_ult_chain += 1
	if id not in _ult_kinds:
		_ult_kinds.append(id)
	ults += 1
	max_chain = maxi(max_chain, _ult_chain)
	_callout_done = true  # the banner names it
	var c: Color = ELEMENTS.color(element())
	if id == "AF":
		c = Ascendancy.color(ascendancy) if ascendancy != "" else COMBO_TIER_COLORS[2]
	Game.ultimate.emit(combo_name(id), c, _ult_chain)
	Game.sfx("ult", -3.0, 0.0)
	Game.hitstop(0.16, 0.2)
	Game.rumble("awaken")
	if Game.camera_rig:
		Game.camera_rig.punch(0.78, 0.6)
	Fx.flash(model)
	ELEMENTS.light_pop(get_parent(), global_position, c, 6.0, 7.0, 0.5)
	ELEMENTS.gather(get_parent(), global_position + Vector3.UP, c, 3.5, 40)


## An ultimate hit home; once all three have landed this Awakening, the Trinity follows.
func _ult_landed() -> void:
	if _ult_kinds.size() >= ULTIMATES.size() + 1 and not _trinity_done:
		_trinity_done = true
		_trinity()


func _start_ult(id: String) -> void:
	_ult_id = id
	_move_id = id
	_ult_fired = false
	_ult_hit.clear()
	_ult_step_d = 0.0
	_ult_phase = 0
	_ult_fx_t = 0.0
	_chain_i = 0
	_post_dash_t = 0.0
	_aim()
	_ult_dir = _facing()
	_ult_from = global_position
	if id == "SKY":
		_ult_at = _cast_target(_ult_dir, ULTIMATES.SKY.reach, 3.0)
		_sky_ancestor()
	if id == "RUSH":
		_ult_len = _clear_ahead(_ult_dir, ULTIMATES.RUSH.length)
	_set_state(State.ULT)
	_ult_begin(id)
	attack_started.emit(id)
	if _comic_moves_on():
		var clip: String = ComicLook.HERO_MOVES[id].clip
		_play(clip, 0.05, true)
		var hit_t: float = ULTIMATES.SKY.time * ULTIMATES.SKY.impact if id == "SKY" else ULTIMATES.RUSH.go
		anim.speed_scale = ComicLook.ult_speed(id, anim.get_animation(clip).length, hit_t)
	else:
		_ult_anim("Jump_Start" if id == "SKY" else "Spellcasting", 0.05)


func _state_ult(delta: float) -> void:
	var u: Dictionary = ULTIMATES[_ult_id]
	var t := _state_t
	var el := element()
	var c := ELEMENTS.color(el)
	_invuln_t = maxf(_invuln_t, 0.15)
	_ghost_t -= delta
	if _ghost_t <= 0.0 and (_ult_id == "RUSH" or t < u.time * u.get("impact", 1.0)):
		_ghost_t = afterimage_interval * 1.5
		Fx.afterimage(get_parent(), model, Color(c, 0.4))
	if _ult_id == "SKY":
		_state_sky(u, t, el, c, delta)
	else:
		_state_rush(u, t, el, delta)
	if t >= u.time:
		_end_ult()


## SKY: leap toward the target, gather the element overhead, smash down.
func _state_sky(u: Dictionary, t: float, el: String, c: Color, delta: float) -> void:
	var hit_t: float = u.time * u.impact
	var k := clampf(t / hit_t, 0.0, 1.0)
	var to := _ult_at - _ult_from
	to.y = 0.0
	velocity.x = to.x / hit_t if k < 1.0 else 0.0
	velocity.z = to.z / hit_t if k < 1.0 else 0.0
	_face(to)
	var rise: float = u.rise
	model.position.y = rise * (1.0 - pow(1.0 - k / 0.7, 3.0)) if k < 0.7 else rise * (1.0 - pow((k - 0.7) / 0.3, 2.0))
	if k >= 0.3 and _ult_phase == 0:
		_ult_phase = 1
		_ult_anim("Spellcast_Raise", 0.08)
		if el == "earth":
			ELEMENTS.meteor(get_parent(), _ult_at, hit_t * 0.7)
	if _ult_phase == 1:
		_ult_fx_t -= delta
		if _ult_fx_t <= 0.0:
			_ult_fx_t = 0.1
			ELEMENTS.gather(get_parent(), global_position + Vector3.UP * (model.position.y + 2.4), c, 2.2, 14)
	if k >= 0.72 and _ult_phase == 1:
		_ult_phase = 2
		_ult_anim("2H_Melee_Attack_Chop", 0.04, 0.25)
	if k >= 1.0 and not _ult_fired:
		_ult_fired = true
		model.position.y = 0.0
		var at := Vector3(global_position.x, 0.0, global_position.z)
		ELEMENTS.sky_impact(get_parent(), at, el, u.radius)
		var water: Dictionary = Ascendancy.PATHS.water
		ELEMENTS.hit_area(get_tree(), at, u.radius, u.damage * _dmg_mult * _ult_mult(), u.launch, true, "ult",
			func(e: Node) -> void:
				_cast_hit(e)
				if el == "water" and e.is_alive() and not e.has_method("is_boss"):
					e.freeze(water.glacier_freeze, water.shatter_mult))
		_ult_impact()


## Ancestor's Fall: a colossal ancestor (SKY_ANCESTOR x the hero) rises behind
## the target and brings his axe down on it exactly as the hero lands (visual:
## the ultimate's own impact deals the damage).
func _sky_ancestor() -> void:
	var u: Dictionary = ULTIMATES.SKY
	var av = _spirit(SPIRIT_AVATAR.new(), {"damage": 0.0}, element())
	av.fwd = _ult_dir
	av.scale_to = SKY_ANCESTOR
	av.speed = SPIRIT_AVATAR.speed_for(u.time * u.impact)
	av.impact_fx = false
	get_parent().add_child(av)
	var back: float = SPIRIT_AVATAR.LAND.z * SKY_ANCESTOR - 0.6  # model offset: land point ahead of its origin
	av.global_position = _ult_at - _ult_dir * back


## Spirit Stampede's wake: a wave of colossal axes bursts up along the whole
## charge line (visual: the wake deals the damage).
func _rush_blades(length: float, el: String) -> void:
	var rf = _spirit(SPIRIT_RIFT.new(), {"damage": 0.0}, el)
	rf.fwd = _ult_dir
	rf.length = length + 1.0
	rf.steps = clampi(int(length / 1.1), 4, 10)
	rf.step_time = 0.03
	rf.size_from = 2.6
	rf.size_to = 4.6
	get_parent().add_child(rf)
	rf.global_position = Vector3(_ult_from.x, 0.0, _ult_from.z)


## RUSH: wind up, charge through everything ahead, then the line erupts.
func _state_rush(u: Dictionary, t: float, el: String, delta: float) -> void:
	var go: float = u.go
	var dash_end: float = go + u.dash
	_face(_ult_dir)
	if t < go:
		velocity.x = 0.0
		velocity.z = 0.0
	elif t < dash_end:
		if _ult_phase == 0:
			_ult_phase = 1
			_ult_anim("Dodge_Forward", 0.03)
			Game.sfx("dash", 0.0, 0.0)
			if el == "water":
				ELEMENTS.wave_wall(model, u.dash + 0.25)
		var spd: float = _ult_len / u.dash
		velocity.x = _ult_dir.x * spd
		velocity.z = _ult_dir.z * spd
		_ult_step_d += spd * delta
		if _ult_step_d >= 1.2:
			_ult_step_d = 0.0
			ELEMENTS.rush_step(get_parent(), global_position, _ult_dir, el)
		for e in Ascendancy.enemies_near(get_tree(), global_position, u.width):
			if _ult_hit.has(e):
				continue
			_ult_hit[e] = true
			var side: Vector3 = e.global_position - global_position
			side.y = 0.0
			side = (side - _ult_dir * side.dot(_ult_dir)).normalized()
			e.take_hit(u.damage * _dmg_mult * _ult_mult(), side * 6.0 + _ult_dir * 3.0, u.launch, true)
			Game.register_hit("ult")
			_cast_hit(e)
			Game.hitstop(0.03)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 80.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 80.0 * delta)
		if _ult_phase == 1:
			_ult_phase = 2
			_ult_anim("2H_Melee_Attack_Slice", 0.04, 0.3)
		if not _ult_fired and t >= dash_end + u.wake:
			_ult_fired = true
			var line := global_position - _ult_from
			line.y = 0.0
			var length := maxf(line.length(), 2.0)
			ELEMENTS.rush_wake(get_parent(), _ult_from, _ult_dir, length, el)
			_rush_blades(length, el)
			for e in get_tree().get_nodes_in_group("enemies"):
				var to: Vector3 = e.global_position - _ult_from
				to.y = 0.0
				if e.is_alive() and _in_strip(to, _ult_dir, length, u.width, e.radius):
					e.take_hit(u.wake_damage * _dmg_mult * _ult_mult(), Vector3.UP, 7.0, true)
					Game.register_hit("ult")
					_cast_hit(e)
			_ult_impact()


## How far the hero can travel along `dir` (up to `length`) before a wall.
func _clear_ahead(dir: Vector3, length: float) -> float:
	var from := global_position + Vector3.UP * 0.9
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (length + 0.6), collision_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return length
	return maxf(from.distance_to(hit.position) - 0.6, 0.0)


## A SKY or RUSH impact: the big hit juice.
func _ult_impact() -> void:
	ult_impacts += 1
	Game.sfx("ult_impact", 0.0, 0.05)
	Game.hitstop(0.12)
	Game.shake(0.9)
	Game.rumble("hit_big")
	_ult_landed()


func _end_ult() -> void:
	model.position.y = 0.0
	_buffered = ""
	_chain_reset_t = 0.0
	_ghost_t = 0.0
	_set_state(State.MOVE)


## All three ultimates in one Awakening: a strike of the element on every foe around.
func _trinity() -> void:
	trinities += 1
	var el := element()
	var c := ELEMENTS.color(el)
	var parent := get_parent()
	await get_tree().create_timer(TRINITY.delay, false).timeout
	if not is_inside_tree():
		return
	Game.ultimate.emit(TRINITY.names[el], c, 0)
	Game.sfx("ult", 0.0, 0.0)
	Game.hitstop(0.25, 0.15)
	Game.shake(1.0)
	if Game.camera_rig:
		Game.camera_rig.punch(1.15, 0.8)
	ELEMENTS.light_pop(parent, global_position, c, 12.0, 20.0, 0.8)
	Fx.ring(parent, global_position, Color(c, 0.95), TRINITY.radius, 0.6)
	var targets := Ascendancy.enemies_near(get_tree(), global_position, TRINITY.radius)
	if targets.is_empty():
		for i in 6:
			var ang := TAU * i / 6.0
			ELEMENTS.storm_strike(parent, global_position + Vector3(sin(ang), 0.0, cos(ang)) * 4.0, el)
	for e in targets:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		ELEMENTS.storm_strike(parent, e.global_position, el)
		_axe_fall(e.global_position, _facing(), 4.6)
		e.take_hit(TRINITY.damage * _dmg_mult, Vector3.ZERO, 6.0, true)
		Game.register_hit("trinity")
		_cast_hit(e)
		await get_tree().create_timer(TRINITY.gap, false).timeout
		if not is_inside_tree():
			return


# --- Upgrades ---------------------------------------------------------------

func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


## Current level's tuning number `key` for owned upgrade `id` (upgrades.gd
## lv), boosted by any active synergy (Upgrades.SYNERGIES).
func upg(id: String, key: String) -> float:
	return Upgrades.value(id, key, upgrades.get(id, 1)) * Upgrades.boost(synergies, id, key)


## A synergy switched on: chime, a teal ring and sparks around the hero.
func _synergy_burst() -> void:
	Game.sfx("synergy", -2.0, 0.0)
	Fx.flash(model)
	Fx.ring(get_parent(), global_position, Color(SYNERGY_COLOR, 0.9), 3.0, 0.5)
	Fx.burst(get_parent(), global_position + Vector3.UP, SYNERGY_COLOR, 24, 5.0, 0.12, 0.6, Vector3.UP, 60.0, -4.0)


## Lose upgrade `id` entirely (shrine melt).
func remove_upgrade(id: String) -> void:
	upgrades.erase(id)
	synergies = Upgrades.active_synergies(upgrades)
	_refresh_masteries()


## Recompute the path masteries (Upgrades.PATHS): announce new ones and keep
## the Soul mastery's max HP in step.
func _refresh_masteries() -> void:
	var before := masteries
	masteries = Upgrades.masteries(upgrades)
	var hp_bonus: float = Upgrades.PATHS.soul.mastery.hp
	if "soul" in masteries and "soul" not in before:
		max_hp += hp_bonus
		heal(hp_bonus, false)
	elif "soul" in before and "soul" not in masteries:
		max_hp -= hp_bonus
		hp = minf(hp, max_hp)
	health_changed.emit(hp, max_hp)
	for path: String in masteries:
		if path not in before:
			Game.announced.emit("%s MASTERY" % Upgrades.PATHS[path].name.to_upper())
			Game.sfx("synergy", -2.0, 0.0)
			var c: Color = Upgrades.PATHS[path].color
			Fx.ring(get_parent(), global_position, Color(c, 0.9), 3.2, 0.5)
			Fx.burst(get_parent(), global_position + Vector3.UP, c, 24, 5.0, 0.12, 0.6, Vector3.UP, 60.0, -4.0)


## Mastery number `key` of `path` while that mastery is on, else 0.
func _mastery(path: String, key: String) -> float:
	return Upgrades.PATHS[path].mastery[key] if path in masteries else 0.0


## How long an Awakening lasts, with the Awaken mastery.
func _awaken_len() -> float:
	return awaken_duration + _mastery("awaken", "time")


## Animation speed before per-move boosts (Awakening is faster).
func _base_anim_mult() -> float:
	return 1.3 if awakened else 1.0


func _proc(id: String) -> void:
	power_procs[id] = power_procs.get(id, 0) + 1


## Gain an upgrade, or level it up if it's already owned (up to MAX_LEVEL).
func add_upgrade(id: String) -> void:
	upgrades[id] = mini(upgrades.get(id, 0) + 1, Upgrades.MAX_LEVEL)
	var before := synergies
	synergies = Upgrades.active_synergies(upgrades)
	for tag: String in synergies:
		if tag not in before:
			Game.announced.emit("%s SYNERGY" % Upgrades.SYNERGIES[tag].name.to_upper())
			_synergy_burst()
	if id == "overflow":
		Game.awakening_gain_mult = 1.0 + upg(id, "bonus") / 100.0
	_refresh_masteries()


func _on_level_up(level: int) -> void:
	max_hp += level_hp
	heal(level_hp, false)
	health_changed.emit(hp, max_hp)
	Game.announced.emit("LEVEL %d" % level)
	Game.sfx("wave_clear", -6.0, 0.0)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.85, 0.4, 0.9), 2.5, 0.4)
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.4, Color(1.0, 0.85, 0.4), 18, 5.0, 0.1, 0.5, Vector3.UP, 30.0)


func _on_enemy_killed(e: Node) -> void:
	if state != State.DEAD and _is_last_kill():
		_last_kill(e)
	if has_upgrade("reaper") and state != State.DEAD:
		_proc("reaper")
		heal(upg("reaper", "heal"), false)
		Game.add_awakening(upg("reaper", "awaken"))
	if has_upgrade("undying_flame") and awakened and state != State.DEAD:
		# The meter drains in step with _awaken_t, so refill both.
		_awaken_t = minf(_awaken_t + upg("undying_flame", "time"), _awaken_len())
		Game.awakening = Game.AWAKEN_MAX * _awaken_t / _awaken_len()
		Game.awakening_changed.emit(Game.awakening)
		heal(upg("undying_flame", "heal"), false)
		_proc("undying_flame")
		Fx.burst(get_parent(), global_position + Vector3.UP, Upgrades.PATHS.awaken.color, 10, 4.0, 0.1, 0.4, Vector3.UP, 60.0)


## Style rank climbed: a burst in the new rank's colour (the HUD's), bigger the higher it goes.
func _on_combo_changed(_count: int, rank: String) -> void:
	var i := Game.RANKS.size() - 1 - Game.RANKS.map(func(r: Array) -> String: return r[0]).find(rank)
	if i > _rank_i and state != State.DEAD and is_inside_tree():
		rank_ups += 1
		var c: Color = RANK_COLORS.get(rank, Color.WHITE)
		var at := global_position + Vector3.UP * 1.1
		Fx.ring(get_parent(), global_position, Color(c, 0.9), 1.8 + i * 0.45, 0.3)
		Fx.flare(get_parent(), at, c, 1.8 + i * 0.5, 0.2, "star8")
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


## Dust bursts along the Ground Breaker's strip.
## Shatter: the slain foe bursts into bone shards that hit everyone close by
## (shard kills don't shatter again).
func _shatter(dead: Node3D) -> void:
	shatters += 1
	var at := dead.global_position
	var r: float = upg("shatter", "radius")
	Fx.burst(get_parent(), at + Vector3.UP * 0.7, SHATTER_COLOR, 26, 9.0, 0.12, 0.35, Vector3.UP, 160.0)
	Fx.ring(get_parent(), at, Color(SHATTER_COLOR, 0.8), r, 0.3)
	Game.sfx("enemy_death", 0.0, 0.15)
	Game.shake(0.25)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == dead or not e.is_alive():
			continue
		var to: Vector3 = e.global_position - at
		to.y = 0.0
		if to.length() <= r + e.radius:
			e.take_hit(upg("shatter", "damage"), to.normalized() * 6.0, 3.0, false)
			Game.register_hit("shatter")


func _crack_line(fwd: Vector3, color: Color, from := Vector3.INF) -> void:
	var start := global_position if from == Vector3.INF else from
	var length: float = MOVES.LLH.range
	for i in 5:
		var at := start + fwd * (1.0 + i * (length - 1.0) / 4.0)
		Fx.dust(get_parent(), at, 6, 0.7)
		Fx.burst(get_parent(), at + Vector3.UP * 0.1, color, 5, 4.0, 0.08, 0.25, Vector3.UP, 40.0)


## Fault Line: the strip erupts again a moment later, launching what's on it.
func _fault_line(origin: Vector3, fwd: Vector3) -> void:
	var delay: float = upg("fault_line", "delay")
	var glow := _fault_glow(origin, fwd)
	glow.create_tween().tween_property(glow.mesh.material, "albedo_color:a", 0.75, delay)
	await get_tree().create_timer(delay, false).timeout
	var mat: StandardMaterial3D = glow.mesh.material
	mat.albedo_color.a = 0.95
	var tw := glow.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(glow.queue_free)
	_crack_line(fwd, Color(1.0, 0.55, 0.2), origin)
	Game.shake(0.3)
	Game.sfx("hit_big", -6.0, 0.1)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - origin
		to.y = 0.0
		if e.is_alive() and _in_strip(to, fwd, MOVES.LLH.range, MOVES.LLH.width, e.radius):
			e.take_hit(upg("fault_line", "damage"), fwd * 3.0, 7.0, true)
			Game.register_hit("fault_line")


## Glowing crack along the Ground Breaker's strip; it brightens until the
## Fault Line erupts, so the eruption reads as a telegraph.
func _fault_glow(origin: Vector3, fwd: Vector3) -> MeshInstance3D:
	var length: float = MOVES.LLH.range
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(MOVES.LLH.width * 1.2, 0.02, length)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.35)
	mesh.material = mat
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(m)
	m.global_position = origin + fwd * (length * 0.5 + 0.5) + Vector3.UP * 0.06
	m.rotation.y = atan2(fwd.x, fwd.z)
	return m


## Quake: a shockwave out from the charged slam's impact.
func _quake(at: Vector3) -> void:
	var r := upg("quake", "radius")
	Fx.ring(get_parent(), at, Color(1.0, 0.75, 0.35, 0.9), r, 0.45)
	Game.shake(0.3)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - at
		to.y = 0.0
		if e.is_alive() and to.length() < r:
			e.take_hit(upg("quake", "damage"), to.normalized() * 5.0, 6.0, true)
			Game.register_hit("quake")


## MOVES entry with owned upgrades applied (never mutates MOVES itself).
func _effective_move(id: String) -> Dictionary:
	var m: Dictionary = MOVES[id].duplicate(true)
	if id == "H" and has_upgrade("whirlwind"):
		_proc("whirlwind")
		# Spread the extra hits evenly across the spin.
		var n := int(upg("whirlwind", "hits"))
		m.hits = []
		for i in n:
			m.hits.append(lerpf(0.22, 0.7, float(i) / (n - 1)))
		m.range += upg("whirlwind", "reach")
	if id == "L2" and has_upgrade("rising_edge"):
		_proc("rising_edge")
		m.launch = upg("rising_edge", "launch")
	if id == "DL" and has_upgrade("momentum"):
		_proc("momentum")
		m.damage *= 1.0 + upg("momentum", "bonus") / 100.0
		m.range += 1.5
		m.lunge *= 1.3
	if id in LIGHT_CHAIN:
		m.damage *= 1.0 + _mastery("light", "damage") / 100.0
	if id in SHATTER_MOVES:
		m.damage *= 1.0 + _mastery("heavy", "damage") / 100.0
	if id == "DL":
		m.damage *= 1.0 + _mastery("dash", "damage") / 100.0
	if id in LIGHT_MOVES and has_upgrade("flicker") and _since_dash <= upg("flicker", "time"):
		m.damage *= 1.0 + upg("flicker", "bonus") / 100.0
		_proc("flicker")
	if _comic_moves_on() and ComicLook.HERO_MOVES.has(id):
		var length := anim.get_animation(ComicLook.HERO_MOVES[id].clip).length
		ComicLook.retime(id, m, length, MOVES[id].hits[0], BREAKERS.get(id, {}).get("leap", -1.0))
	return m


func _chain_spark(from: Node3D) -> void:
	var targets := get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		return e != from and e.is_alive() and e.global_position.distance_to(from.global_position) < 6.0)
	targets.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(from.global_position) < b.global_position.distance_to(from.global_position))
	for e in targets.slice(0, int(upg("chain_spark", "targets"))):
		var mid: Vector3 = (from.global_position + e.global_position) * 0.5
		Fx.burst(get_parent(), mid + Vector3.UP, Color(0.5, 0.85, 1.0), 10, 6.0, 0.15, 0.2)
		e.take_hit(upg("chain_spark", "damage"), Vector3.ZERO, 0.0, false)
		Game.register_hit("chain_spark")


## Thousand Cuts: count light hits per foe; every `hits`th one rends it.
func _thousand_cuts(e: Node3D) -> void:
	var n: int = e.get_meta("cuts", 0) + 1
	if n < int(upg("thousand_cuts", "hits")):
		e.set_meta("cuts", n)
		return
	e.set_meta("cuts", 0)
	_proc("thousand_cuts")
	var c: Color = Upgrades.PATHS.light.color
	Fx.burst(get_parent(), e.global_position + Vector3.UP * 0.9, c, 18, 7.0, 0.1, 0.25, Vector3.UP, 180.0)
	Fx.ring(get_parent(), e.global_position, Color(c, 0.8), 1.2, 0.2)
	e.take_hit(upg("thousand_cuts", "damage"), Vector3.ZERO, 0.0, false)
	Game.register_hit("thousand_cuts")


## Slipstream: cut each enemy the dash passes through, once per dash.
func _slipstream() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive() or e in _slipped:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() <= 0.9 + e.radius:
			_slipped.append(e)
			_proc("slipstream")
			var c: Color = Upgrades.PATHS.dash.color
			Fx.burst(get_parent(), e.global_position + Vector3.UP * 0.9, c, 12, 6.0, 0.1, 0.25, _dash_dir, 60.0)
			e.take_hit(upg("slipstream", "damage"), _dash_dir * 3.0, 0.0, false)
			Game.register_hit("slipstream")


## Shockstep: a heavy dash-cancel leaves a launching shockwave behind.
func _shockstep(pos: Vector3) -> void:
	_proc("shockstep")
	var r := upg("shockstep", "radius")
	Fx.ring(get_parent(), pos, Color(Upgrades.PATHS.heavy.color, 0.9), r, 0.35)
	Fx.ring(get_parent(), pos, Color(Upgrades.PATHS.dash.color, 0.8), r * 0.6, 0.25)
	Fx.dust(get_parent(), pos, 12, 0.9)
	Game.shake(0.2)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - pos
		to.y = 0.0
		if e.is_alive() and to.length() < r + e.radius:
			e.take_hit(upg("shockstep", "damage"), to.normalized() * 4.0, 7.0, true)
			Game.register_hit("shockstep")


## Spike: slam a juggled foe into the floor; the impact knocks down foes
## around it.
func _spike(e: Node3D) -> void:
	spikes += 1
	if e.is_alive():
		e.velocity.y = -SPIKE_DOWN
	var at: Vector3 = e.global_position
	at.y = global_position.y
	Fx.ring(get_parent(), at, Color(1.0, 0.85, 0.5, 0.9), SPIKE_IMPACT.radius, 0.25)
	Fx.dust(get_parent(), at, 14, 1.0)
	for o in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = o.global_position - at
		to.y = 0.0
		if o != e and o.is_alive() and not o.is_airborne() and to.length() < SPIKE_IMPACT.radius + o.radius:
			o.take_hit(SPIKE_IMPACT.damage * _dmg_mult, to.normalized() * SPIKE_IMPACT.knockback, 0.0, true)
			Game.register_hit("spike")
	if has_upgrade("rebound"):
		_rebound(e)


## Rebound: a spiked foe bounces back up off the floor for another juggle.
func _rebound(e: Node3D) -> void:
	await get_tree().create_timer(REBOUND_DELAY).timeout
	if not is_instance_valid(e) or not e.is_alive():
		return
	_proc("rebound")
	e.take_hit(upg("rebound", "damage") * _dmg_mult, Vector3.ZERO, upg("rebound", "launch"), false)
	Game.register_hit("rebound")
	Fx.ring(get_parent(), e.global_position, Color(Upgrades.PATHS.soul.color, 0.85), 1.4, 0.25)


## Razor Gale: Flurry's last cut flings a fan of the element's blades.
func _razor_gale(fwd: Vector3) -> void:
	_proc("razor_gale")
	var n := int(upg("razor_gale", "count"))
	var el := element()
	for i in n:
		var b := ELEMENTS.Bolt.new()
		b.el = el
		b.dir = fwd.rotated(Vector3.UP, deg_to_rad(RAZOR_GALE_SPREAD * (i - (n - 1) * 0.5)))
		b.speed = 24.0
		b.reach = minf(8.0, _clear_ahead(b.dir, 8.0) + 0.6)
		b.damage = upg("razor_gale", "damage") * _dmg_mult
		b.size = 0.8
		b.tilt = 70.0 if i % 2 == 0 else -70.0
		b.on_hit = _cast_hit
		get_parent().add_child(b)
		b.global_position = global_position + b.dir * 0.7 + Vector3.UP * (0.25 if el == "earth" else 1.0)


## Eye of the Storm: each Cyclone hit drags foes around it into the spin
## (not the boss).
func _eye_of_storm() -> void:
	_proc("eye_of_storm")
	var r := upg("eye_of_storm", "radius")
	Fx.ring(get_parent(), global_position, Color(Upgrades.PATHS.dash.color, 0.5), r, 0.2)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if e.is_alive() and d > _move.range * 0.6 and d < r + e.radius and not e.has_method("is_boss"):
			e.take_hit(upg("eye_of_storm", "damage"), -to / d * minf(d * 2.5, 9.0), 0.0, false)
			Game.register_hit("eye_of_storm")


func _static_trap(pos: Vector3) -> void:
	Fx.ring(get_parent(), pos, Color(0.5, 0.85, 1.0, 0.6), 1.2, 0.4)
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	Fx.ring(get_parent(), pos, Color(0.6, 0.9, 1.0, 0.9), 3.0, 0.3)
	Fx.burst(get_parent(), pos + Vector3.UP * 0.5, Color(0.6, 0.9, 1.0), 20, 9.0, 0.18, 0.3, Vector3.UP, 90.0)
	Game.sfx("hit_big", -4.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.global_position.distance_to(pos) < 3.0:
			e.take_hit(upg("static_step", "damage"), (e.global_position - pos).normalized() * 4.0, 0.0, true)
			Game.register_hit("static_step")


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
	if has_upgrade("phoenix_heart"):
		_proc("phoenix_heart")
		heal(upg("phoenix_heart", "heal"))
	# Activation burst: big freeze, shockwave that blows enemies back.
	Game.hitstop(0.25, 0.05)
	Game.shake(0.6)
	var r := upg("eruption", "radius") if has_upgrade("eruption") else 7.0
	Fx.awaken_burst(get_parent(), global_position, Ascendancy.color(ascendancy), r)
	if Game.camera_rig:
		Game.camera_rig.punch(0.85, 0.35)
	if has_upgrade("eruption"):
		_proc("eruption")
		Fx.ring(get_parent(), global_position, Color(Upgrades.PATHS.awaken.color, 0.9), r * 0.7, 0.35)
		Fx.burst(get_parent(), global_position + Vector3.UP * 0.3, Upgrades.PATHS.awaken.color, 40, 10.0, 0.18, 0.5, Vector3.UP, 160.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < r:
			e.take_hit(upg("eruption", "damage") if has_upgrade("eruption") else 10.0, to.normalized() * 12.0, 5.0, true)


## The overlay a mesh wears when not Awakened (HERO_LOOK's axe runes), or null.
func _rest_overlay(mi: MeshInstance3D) -> Material:
	return mi.get_meta("rest_overlay") if mi.has_meta("rest_overlay") else null


## A tuning number of the chosen Ascendancy path, or `fallback` without one.
func _path(key: String, fallback: float) -> float:
	return Ascendancy.PATHS[ascendancy].get(key, fallback) if ascendancy != "" else fallback


## COMBOS name, with the finisher renamed by the Ascendancy path.
## The COMBOS id the current move lands as: Triple Chop from the top of the
## air string is Skyfall, otherwise the move itself.
func named_id() -> String:
	if _move_id == "VS" and _void.after_string:
		return "SHAPEBREAKER"
	if _move_id == "L3" and _hop_y0 >= STORMFALL_FROM:
		return "STORMFALL"
	if _move_id == "L3" and _hop_y0 >= PLUNGE_AXES_FROM:
		return "SKYFALL"
	return _move_id


func combo_name(id: String) -> String:
	if ULTIMATES.has(id):
		return ULTIMATES[id].names[element()]
	if id == "AF" and ascendancy != "":
		return Ascendancy.PATHS[ascendancy].finisher
	return COMBOS[id].name


func ascend(path: String) -> void:
	ascendancy = path
	if _form != null:
		_form.queue_free()
	if _comic_hero:
		ComicLook.tint_fractures(model, path)
	else:
		_form = HERO_LOOK.add_form(model, path)
	for c in _coats:
		c.queue_free()
	_coats = _coat_axes()
	HERO_LOOK.charge_coats(_coats, awakened)
	if _asc_aura != null:
		_asc_aura.queue_free()
	_asc_aura = preload("res://scripts/ascend_aura.gd").new()
	add_child(_asc_aura)
	_asc_aura.setup(path)
	Game.announced.emit(Ascendancy.PATHS[path].title)
	Game.sfx("synergy", 0.0, 0.0)
	var c := Ascendancy.color(path)
	Fx.ring(get_parent(), global_position, Color(c, 0.95), 5.0, 0.5)
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.6, c, 40, 9.0, 0.15, 0.6, Vector3.UP, 60.0)
	_orbit.setup(element(), awakened)
	for trail in _trails:
		trail.color = _trail_rest_color()
	if awakened:
		_set_awakened(true)


## Ascended heavies (RITE): set off every prime of his element near him,
## naming it over his head when anything answered.
func _rite_set_off(mult: float) -> void:
	var m := mult * _dmg_mult * _cast_power() * (RITE.AWAKENED_MULT if awakened else 1.0)
	var at := global_position + Vector3.UP * model.position.y
	var n := RITE.set_off(get_parent(), at, ascendancy, m, _cast_hit)
	if n == 0:
		return
	rites += 1
	Game.hitstop(0.05)
	Game.shake(0.35 + 0.05 * mini(n, 5))
	if not _callout.visible:
		_rite_callout(RITE.NAMES[ascendancy] + (" x%d" % n if n > 1 else ""))
	if bot_enabled:
		print("[autotest] rite %s x%d" % [RITE.NAMES[ascendancy], n])


## Earth's heavies well up lava: under the foes a spin hits (round him where
## there are none), a line down the thrust, otherwise one well on the target.
func _rite_wells(fwd: Vector3, struck: Array[Vector3]) -> void:
	var parent := get_parent()
	if _move.arc >= 360.0 and not _move.has("width"):
		var n := 4 if awakened else 3
		var spots: Array[Vector3] = []
		for p in struck:
			if spots.size() < n and spots.all(func(q: Vector3) -> bool: return q.distance_to(p) > RITE.WELL_RADIUS * 1.2):
				spots.append(p)
		for i in n:
			if spots.size() >= n:
				break
			var dir := fwd.rotated(Vector3.UP, TAU * (i + 0.5) / n)
			var p := global_position + dir * minf(2.4, _clear_ahead(dir, 2.4))
			if spots.all(func(q: Vector3) -> bool: return q.distance_to(p) > RITE.WELL_RADIUS * 1.2):
				spots.append(p)
		for p in spots:
			RITE.well(parent, p, awakened)
	elif _move.has("width"):
		for d in [1.6, 3.2, 4.8]:
			RITE.well(parent, global_position + fwd * minf(d, _clear_ahead(fwd, d)), awakened)
	else:
		RITE.well(parent, _cast_target(fwd, 4.5, minf(1.8, _clear_ahead(fwd, 1.8))), awakened)


func _rite_callout(text: String) -> void:
	_callout.text = text
	_callout.modulate = ELEMENTS.LOOK[ascendancy].color.lerp(Color.WHITE, 0.25)
	_callout.position = Vector3(0.0, 2.9, 0.0)
	_callout.scale = Vector3.ONE * 0.6
	_callout.visible = true
	if _callout_tw:
		_callout_tw.kill()
	_callout_tw = _callout.create_tween()
	_callout_tw.tween_property(_callout, "scale", Vector3.ONE * 1.1, 0.08)
	_callout_tw.tween_property(_callout, "scale", Vector3.ONE * 0.95, 0.08)
	_callout_tw.parallel().tween_property(_callout, "position:y", 3.3, 0.6).set_ease(Tween.EASE_OUT)
	_callout_tw.tween_property(_callout, "modulate:a", 0.0, 0.25).set_delay(0.4)
	_callout_tw.tween_callback(_callout.hide)


## Awakened per-hit element effect (Wind lightning, Water chill).
func _element_hit(e: Node) -> void:
	match ascendancy:
		"wind":
			_wind_hits += 1
			var w: Dictionary = Ascendancy.PATHS.wind
			if _wind_hits % int(w.strike_every) == 0:
				element_procs += 1
				Ascendancy.lightning(get_parent(), Vector3(e.global_position.x, 0.0, e.global_position.z),
					w.strike_damage, w.strike_radius, "lightning")
		"water":
			if e.is_alive():
				var was: int = e.chill_hits
				Ascendancy.chill_hit(e)
				if e.chill_hits < was:
					element_procs += 1


## The Awakened L L L H finisher: Cataclysm, or the Ascendancy's own.
func _finisher(fwd: Vector3) -> void:
	match ascendancy:
		"wind":
			cataclysms += 1
			var t := Ascendancy.Tempest.new()
			get_parent().add_child(t)
			t.global_position = Vector3(global_position.x, 0.0, global_position.z) + fwd * 2.0
			Game.sfx("awaken", -4.0, 0.1)
		"earth":
			cataclysms += 1
			var v := Ascendancy.Volcano.new()
			get_parent().add_child(v)
			v.global_position = Vector3(global_position.x, 0.0, global_position.z) + fwd * 2.5
			Game.sfx("awaken", -4.0, 0.1)
		"water":
			cataclysms += 1
			Ascendancy.glacier(get_parent(), Vector3(global_position.x, 0.0, global_position.z))
		_:
			_cataclysm()


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
	var c := Ascendancy.color(ascendancy)
	_awaken_light.light_color = c
	_awaken_rim.set_shader_parameter("glow_color", c)
	for mi: MeshInstance3D in _meshes:
		mi.material_overlay = _awaken_rim if on else _rest_overlay(mi)
	for trail in _trails:
		trail.color = Color(c, 0.9) if on else _trail_rest_color()
	_aura.color = c
	_aura.emitting = on and ascendancy != ""
	if _asc_aura != null:
		_asc_aura.set_awakened(on)
	HERO_LOOK.charge_coats(_coats, on)
	HERO_LOOK.charge_form(_form, on)
	HERO_LOOK.set_eyes(model, on, c)
	_orbit.setup(element(), on)
	if on:
		_ult_chain = 0
		_ult_kinds.clear()
		_trinity_done = false
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
	if has_upgrade("riposte"):
		_proc("riposte")
		_riposte()


## Cataclysm's eruption: fire rings, embers and radiating fire waves on top of the move's own hit.
func _cataclysm() -> void:
	cataclysms += 1
	Game.sfx("awaken", -4.0, 0.1)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.5, 0.15, 0.95), _move.range + 0.5, 0.4)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.85, 0.4, 0.8), _move.range * 0.5, 0.25)
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.3, Color(1.0, 0.5, 0.15), 36, 11.0, 0.14, 0.5, Vector3.UP, 160.0, -8.0, 1.0, "star")
	Fx.dust(get_parent(), global_position, 24, 1.2)
	# Crisp core: a pillar of fire, a hot flare, molten debris and a burn mark left behind.
	_fire_vortex(global_position, _move.range * 0.6, 5.5, 0.6)
	Fx.flare(get_parent(), global_position + Vector3.UP * 1.0, Color(1.0, 0.55, 0.15), 6.0, 0.2)
	Fx.shards(get_parent(), global_position + Vector3.UP * 0.4, Color(1.0, 0.42, 0.1), 16, Vector3.UP, 10.0, 0.22, 0.8)
	Fx.scorch(get_parent(), global_position, Color(1.0, 0.45, 0.1), _move.range * 0.75, 1.6)
	for i in CATACLYSM_AXES:  # the ancestors' axes slam down in a ring round him
		var ang := TAU * (i + 0.5) / CATACLYSM_AXES
		_axe_fall(global_position + Vector3(sin(ang), 0.0, cos(ang)) * CATACLYSM_AXE_RING, _facing(), 4.2, i * 0.04)
	for i in CATACLYSM_WAVES:
		var ang := TAU * i / CATACLYSM_WAVES
		var w := FIRE_WAVE.new()
		w.direction = Vector3(cos(ang), 0.0, sin(ang))
		w.damage = 8.0
		get_parent().add_child(w)
		w.global_position = global_position + w.direction * 1.0


## A visual-only spirit guillotine at `at` (light impact, no hitstop) after
## `delay` s: volleys for Cataclysm's ring and the Trinity storm.
func _axe_fall(at: Vector3, fwd: Vector3, size: float, delay := 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
		if not is_inside_tree():
			return
	var gu = _spirit(SPIRIT_GUILLOTINE.new(), {"damage": 0.0}, element())
	gu.fwd = fwd
	gu.size = size
	gu.heavy = false
	gu.fall = 0.11
	get_parent().add_child(gu)
	gu.global_position = Vector3(at.x, 0.0, at.z)


## Cataclysm's pillar: two counter-spinning fire funnels (the wind tornado's swirl
## shader in fire colours) that flare out and fade.
func _fire_vortex(at: Vector3, radius: float, height: float, life: float) -> void:
	var c := Color(0.95, 0.25, 0.05)  # deep red-orange: paler fire washes out on the floor
	var root := Node3D.new()
	get_parent().add_child(root)
	root.global_position = Vector3(at.x, 0.0, at.z)
	var outer := ELEMENTS._mi(ELEMENTS.funnel(radius, radius * 0.3, height), _fire_mat(c, false))
	outer.position.y = height * 0.5
	root.add_child(outer)
	var inner := ELEMENTS._mi(ELEMENTS.funnel(radius * 0.55, radius * 0.15, height * 0.85), _fire_mat(c, true))
	inner.position.y = height * 0.425
	root.add_child(inner)
	root.scale = Vector3(0.2, 0.4, 0.2)
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(outer, "rotation:y", TAU * 1.5, life)
	tw.tween_property(inner, "rotation:y", -TAU * 2.5, life)
	ELEMENTS._fade_free(root, life * 0.4, life * 0.6)


## The swirl material with gold streaks: its default (colour toward white) reads salmon pink in fire.
func _fire_mat(c: Color, inner: bool) -> ShaderMaterial:
	var m: ShaderMaterial = ELEMENTS.swirl_mat(c, inner).duplicate()  # same shader: no compile hitch
	m.set_shader_parameter("streak_color", Color(1.0, 0.78, 0.25))
	return m


func _riposte() -> void:
	var r := upg("riposte", "radius")
	Fx.ring(get_parent(), global_position, Color(0.7, 0.9, 1.0, 0.9), r, 0.3)
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.5, Color(0.7, 0.9, 1.0), 24, 9.0, 0.15, 0.3, Vector3.UP, 120.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if e.is_alive() and to.length() < r:
			e.take_hit(upg("riposte", "damage"), to.normalized() * 3.0, 7.0, true)
			Game.register_hit("riposte")


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
	hp = maxf(hp - damage * (_path("armor", 0.6) if awakened else 1.0), 0.0)
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
	if hp <= 0.0 and has_upgrade("second_wind") and not _second_wind_used:
		_proc("second_wind")
		_second_wind_used = true
		hp = max_hp * upg("second_wind", "hp") / 100.0
		health_changed.emit(hp, max_hp)
		Game.announced.emit("SECOND WIND")
		Fx.heal(get_parent(), global_position, hp)
		Game.hitstop(0.3, 0.1)
		_invuln_t = 1.2
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
