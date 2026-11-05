extends RefCounted
## The heretic's moves: the MOVES table and the named COMBOS, routing (which press starts which move:
## void_route), the move's timing helpers (retime for his clips, the hop / air / plunge arc, juggle
## homing, the air dash) and what the combo guide shows next. Static functions over the hero's state,
## like void_element.gd: the state stays on player.gd, where the checks and the bot read it.
## See docs/features/combo-breakers.md (hops, air string, plunge) and docs/features/combo-guide.md.

const VOID_ELEMENT := preload("res://scripts/void_element.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")

## String pacing (round 30; the ms are real time at anim_speed 1.7, printed by tests/rhythm_check.gd).
const L1_SPEED := 1.1  # opener: hit 216 -> 196 ms, so the first beat comes quickly
const L3_SPEED := 1.3  # ender: wind-up 471 -> 362 ms; L2's hit to L3's was 553 ms with the hitstop, a stall before the payoff
const L3_CANCEL := 0.645  # (was 0.6) keeps ~140 ms from L3's hit to its cancel at L3_SPEED
const L3_END := 0.975  # (was 0.85) keeps ~330 ms of recovery after the hammer lands at L3_SPEED: the ender's weight
const EM_SPEED := 2.8  # Molten Palm and Steam Burst (was 1.6, then 2.1): its palm landed 619, then 467 ms in; L3 -> EM
# beats were 539-655 ms and EA -> XS 612 (flow audit, round 34 third pass); now 350 ms in, just under the hammer's 362
const XF_SPEED := 1.5  # Fault Line (was 1.2): Rockslide's hit to Fault Line's was 454-510 ms, slower than any other
# hand-over in the strings; its rake now lands 183 ms in (was 229)
# Round 34, third pass (flow audit off the bot's [rhythm] beats, first hit to first hit; shape 196 / 235 / 362 ms):
const EM_END := VOID_ELEMENT.AF_HIT + 0.43  # (was + 0.34) keeps ~300 ms of recovery after the palm at the new pace
const LLH_SPEED := 1.6  # Harpoon and Frost Spear (was 1.2): the spear drove in 327 ms in, the slowest mid wind-up (DL ->
# EF beats 418-514 ms); now 245 ms in
const MELT_SPEED := 1.5  # Meltdown (was 1.2): XG -> XM beat 467 ms; the slam lands 222 ms in (was 278)
const ROCKSLIDE_STOP := 0.07  # (was 0.1) Rockslide's hitstop: with its tier-2 ender stop it was 150 ms of the 393 ms
# beat to Fault Line's hit; the weight moves into the boulder's held frames, the blow keeps its contact frame
const ROCKSLIDE_CONFIRM := 0.8  # its hit-confirm cancel comes this far back to the hit (CANCEL_ON_HIT is 0.5)
# Round 34, fourth pass: the three still-long beats (bot [rhythm], unawakened; contact frames unchanged).
const AL1_SPEED := 1.25  # Air Slash (was 1.0): its cut landed 216 ms in; EC -> AL1 beats were 344-385 ms
const EC_CONFIRM := 0.8  # Updraft Lash's hit-confirm comes this far back to the hit (was CANCEL_ON_HIT 0.5): of the
# EC -> AL1 beat, ~170 ms was the lash's stop and hit-confirm before Air Slash even started
const L2_SPEED := 1.15  # the spear (was 1.0): its throw landed 235 ms in, L1 -> L2 beats ~311 ms; at 204 ms it still
# winds up longer than L1's 196 (rhythm_check: opener quickest)
const DASH_STAB_CANCEL := 0.5  # of dash_time: a dash out of a move hands over to a buffered light (Dash Stab) this
# early. Dash Stab off a dash out of a move was 475-536 ms after the move's hit (the whole 160 ms dash, then its
# wind-up); Dash Stab's own lunge (16 m/s) covers the rest of the ground

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
# String rhythm (round 30, tests/rhythm_check.gd prints the ms): the opener is quick (L1 `speed`
# L1_SPEED), the mids snappy, the ender winds up a beat longer than a mid, freezes longest and
# recovers longest (L3_SPEED with its cancel / end set to land there; ~330 ms recovery after the hit).
const MOVES := {
	"L1": {"anim": "1H_Melee_Attack_Slice_Diagonal", "damage": 8.0, "range": 2.4, "arc": 140.0,
		"hits": [0.35], "cancel": 0.45, "end": 0.75, "lunge": 7.0, "knockback": 2.5, "launch": 0.0,
		"stop": 0.045, "shake": 0.12, "speed": L1_SPEED},
	"GR": {"anim": "Ab_GR", "damage": 6.0, "range": 9.0, "arc": 360.0, "hits": [VOID_ELEMENT.GR_HIT], "cancel": VOID_ELEMENT.GR_HIT + 0.18, "end": VOID_ELEMENT.GR_HIT + 0.42,
		"lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.14},
	"VS": {"anim": "Ab_VS", "damage": 24.0, "range": 3.8, "arc": 150.0, "hits": [VOID_ELEMENT.VS_HIT], "cancel": VOID_ELEMENT.VS_HIT + 0.19, "end": VOID_ELEMENT.VS_HIT + 0.43,
		"lunge": 1.5, "knockback": 3.0, "launch": 6.0, "big": true, "stop": 0.09, "shake": 0.42},
	"L2": {"anim": "Throw", "damage": 9.0, "range": 2.5, "arc": 160.0,
		"hits": [0.42], "cancel": 0.5, "end": 0.7, "lunge": 6.0, "knockback": 2.5, "launch": 0.0,
		"stop": 0.05, "shake": 0.14, "hop": [0.12, 0.42, 0.6], "speed": L2_SPEED},
	"L3": {"anim": "Dualwield_Melee_Attack_Chop", "damage": 16.0, "range": 2.7, "arc": 150.0,
		"hits": [0.4], "cancel": L3_CANCEL, "end": L3_END, "lunge": 9.0, "knockback": 11.0, "launch": 0.0,
		"stop": 0.1, "shake": 0.35, "big": true, "hop": [0.1, 0.4, 0.9], "speed": L3_SPEED},
	# The void arm's right click (void_element.gd). The tentacle and the element do the work.
	"EE": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.GR_HIT], "cancel": VOID_ELEMENT.GR_HIT + 0.18, "end": VOID_ELEMENT.GR_HIT + 0.36,
		"speed": 1.0, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.2, "air": true},
	"EW": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.GR_HIT], "cancel": VOID_ELEMENT.GR_HIT + 0.18, "end": VOID_ELEMENT.GR_HIT + 0.36,
		"speed": 1.0, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.2, "air": true},
	"EC": {"anim": "Ab_LH", "damage": 4.0, "range": 2.6, "arc": 150.0, "hits": [VOID_ELEMENT.LH_HIT], "cancel": VOID_ELEMENT.LH_HIT + 0.17, "end": VOID_ELEMENT.LH_HIT + 0.41,
		"speed": 1.2, "lunge": 5.0, "knockback": 0.0, "launch": 0.0, "stop": 0.07, "confirm": EC_CONFIRM, "shake": 0.28, "hop": [VOID_ELEMENT.LH_HIT - 0.01, VOID_ELEMENT.LH_HIT + 0.29, 1.5]},
	"EA": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.GR_HIT], "cancel": VOID_ELEMENT.GR_HIT + 0.18, "end": VOID_ELEMENT.GR_HIT + 0.36,
		"speed": 1.0, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.2},
	"EV": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.GR_HIT], "cancel": VOID_ELEMENT.GR_HIT + 0.18, "end": VOID_ELEMENT.GR_HIT + 0.36,
		"speed": 1.0, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.25},
	"VR": {"anim": "Ab_H", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.H_HIT], "cancel": VOID_ELEMENT.H_HIT + 0.22, "end": VOID_ELEMENT.H_HIT + 0.46,
		"speed": 1.2, "lunge": 3.0, "knockback": 0.0, "launch": 0.0, "stop": 0.06, "shake": 0.25},
	"VD": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.GR_HIT], "cancel": VOID_ELEMENT.GR_HIT + 0.28, "end": VOID_ELEMENT.GR_HIT + 0.46,
		"speed": 1.0, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.06, "shake": 0.3},
	"OW": {"anim": "Ab_VS", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.VS_HIT], "cancel": VOID_ELEMENT.VS_HIT + 0.19, "end": VOID_ELEMENT.VS_HIT + 0.43,
		"lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.08, "shake": 0.4},
	"TW": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.GR_HIT], "cancel": VOID_ELEMENT.GR_HIT + 0.18, "end": VOID_ELEMENT.GR_HIT + 0.36,
		"speed": 1.2, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.05, "shake": 0.25},
	"EF": {"anim": "Ab_LLH", "damage": 4.0, "range": 2.8, "arc": 90.0, "hits": [VOID_ELEMENT.LLH_HIT], "cancel": VOID_ELEMENT.LLH_HIT + 0.16, "end": VOID_ELEMENT.LLH_HIT + 0.38,
		"speed": LLH_SPEED, "lunge": 2.0, "knockback": 0.0, "launch": 0.0, "stop": 0.07, "shake": 0.3},
	"IP": {"anim": "Ab_LLH", "damage": 4.0, "range": 2.8, "arc": 90.0, "hits": [VOID_ELEMENT.LLH_HIT], "cancel": VOID_ELEMENT.LLH_HIT + 0.16, "end": VOID_ELEMENT.LLH_HIT + 0.46,
		"speed": LLH_SPEED, "lunge": 1.0, "knockback": 0.0, "launch": 0.0, "stop": 0.07, "shake": 0.3},
	"IJ": {"anim": "Ab_LH", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.2], "cancel": 0.3, "end": 0.8,
		"speed": 1.1, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.0, "shake": 0.0, "air": true, "climb": 2.4},
	"IS": {"anim": "Ab_VS", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [0.39], "cancel": 0.58, "end": 0.82,
		"speed": 1.2, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.1, "shake": 0.5, "big": true},
	"EM": {"anim": "Ab_AF", "damage": 6.0, "range": 3.0, "arc": 200.0, "hits": [VOID_ELEMENT.AF_HIT], "cancel": VOID_ELEMENT.AF_HIT + 0.17, "end": EM_END,
		"speed": EM_SPEED, "lunge": 3.0, "knockback": 3.0, "launch": 0.0, "stop": 0.12, "shake": 0.5, "big": true},
	# Crossovers (round 34, void_element.gd): each changes element on the way. Contact frames are the clips' (*_HIT),
	# cancel / end keep the time after the hit their clip's other moves have.
	# Rockslide (L H L L): off the air slash, so it starts in the air and comes down onto the slam (plunge).
	"XR": {"anim": "Ab_VS", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.VS_HIT], "cancel": VOID_ELEMENT.VS_HIT + 0.19, "end": VOID_ELEMENT.VS_HIT + 0.43,
		"speed": 1.2, "lunge": 2.0, "knockback": 0.0, "launch": 0.0, "stop": ROCKSLIDE_STOP, "confirm": ROCKSLIDE_CONFIRM, "shake": 0.5, "big": true},
	# Fault Line (L H L L H): the rake, low, the gale up out of the cracks. Its breaker is Cataclysm.
	"XF": {"anim": "Ab_LH", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.LH_HIT], "cancel": VOID_ELEMENT.LH_HIT + 0.17, "end": VOID_ELEMENT.LH_HIT + 0.41,
		"speed": XF_SPEED, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.08, "shake": 0.35},
	# Steam Burst (Dash L H H L): Molten Palm's clip and pace into the ice. Its breaker is Flash Freeze.
	"XS": {"anim": "Ab_AF", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.AF_HIT], "cancel": VOID_ELEMENT.AF_HIT + 0.17, "end": EM_END,
		"speed": EM_SPEED, "lunge": 2.0, "knockback": 0.0, "launch": 0.0, "stop": 0.12, "shake": 0.5, "big": true},
	# Storm Pitch (Dash H L): the crescent swing, with the axe on the tentacle.
	"XT": {"anim": "Ab_H", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.H_HIT], "cancel": VOID_ELEMENT.H_HIT + 0.22, "end": VOID_ELEMENT.H_HIT + 0.46,
		"speed": 1.2, "lunge": 3.0, "knockback": 0.0, "launch": 0.0, "stop": 0.08, "shake": 0.35, "big": true},
	# The three-element strings (round 34, second pass). Hailstorm (Dash L H H H): the rake, up after the cubes the gale
	# carries (`air`, `climb`: he's at ~2 m by the hit).
	"XG": {"anim": "Ab_LH", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.LH_HIT], "cancel": VOID_ELEMENT.LH_HIT + 0.17, "end": VOID_ELEMENT.LH_HIT + 0.41,
		"speed": 1.2, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.08, "shake": 0.35, "air": true, "climb": 2.0},
	# Meltdown (Dash L H H H L): the slam clip up there with them (`air`: started in the air, it homes on the nearest
	# airborne foe, hero_moves.air_home). Its breaker is Eruption, from that height.
	"XM": {"anim": "Ab_VS", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.VS_HIT], "cancel": VOID_ELEMENT.VS_HIT + 0.19, "end": VOID_ELEMENT.VS_HIT + 0.43,
		"speed": MELT_SPEED, "lunge": 2.0, "knockback": 0.0, "launch": 0.0, "stop": 0.1, "shake": 0.5, "big": true, "air": true, "climb": 0.3},
	# Impale (Dash H H): Tow Line's clip and pace, throwing them onto the spear.
	"XK": {"anim": "Ab_GR", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.GR_HIT], "cancel": VOID_ELEMENT.GR_HIT + 0.18, "end": VOID_ELEMENT.GR_HIT + 0.36,
		"speed": 1.2, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.06, "shake": 0.3},
	# Backdraft (Dash H H L): the crescent swing, the gale off the axe. Its breaker is Anvil.
	"XW": {"anim": "Ab_H", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [VOID_ELEMENT.H_HIT], "cancel": VOID_ELEMENT.H_HIT + 0.22, "end": VOID_ELEMENT.H_HIT + 0.46,
		"speed": 1.2, "lunge": 2.0, "knockback": 0.0, "launch": 0.0, "stop": 0.08, "shake": 0.35, "big": true},
	# Light after Updraft Lash (L H L): an air slash. He stays up with the foe
	# the lash threw (`air`: holds the height he started at) and the cut
	# re-juggles it; right click off it is Live Wire's breaker (void_element.gd).
	"AL1": {"anim": "1H_Melee_Attack_Slice_Diagonal", "damage": 7.0, "range": 2.6, "arc": 170.0,
		"hits": [0.32], "cancel": 0.42, "end": 0.7, "lunge": 2.0, "knockback": 0.6, "launch": 5.0,
		"stop": 0.045, "shake": 0.12, "air": true, "climb": 0.4, "speed": AL1_SPEED},
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
	# Crossovers (round 34): the string changes element, and the second one cashes in what the first set up.
	"XR": {"name": "Rockslide", "input": "L H L L", "tier": 2},
	"XF": {"name": "Fault Line", "input": "L H L L H", "tier": 2},
	"XS": {"name": "Steam Burst", "input": "Dash L H H L", "tier": 2},
	"XT": {"name": "Storm Pitch", "input": "Dash H L", "tier": 2},
	# Three elements in one string (second pass): ice, storm, magma in the air; dark, ice, storm into the hammer.
	"XG": {"name": "Hailstorm", "input": "Dash L H H H", "tier": 2},
	"XM": {"name": "Meltdown", "input": "Dash L H H H L", "tier": 2},
	"XK": {"name": "Impale", "input": "Dash H H", "tier": 2},
	"XW": {"name": "Backdraft", "input": "Dash H H L", "tier": 2},
}
# Names of the moves that aren't combos, for the combo guide.
const MOVE_NAMES := {"L1": "Slice", "L2": "Hurl", "AL1": "Air Slash", "IJ": "Vault"}
# After landing a combo this many times in a run, the guide stops hinting it
# as a follow-up (it still shows as a row).
const GUIDE_LEARNED := 6
const LIGHT_CHAIN := ["L1", "L2", "L3"]

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
# reach it (`air_home`), so a launched foe that drifted doesn't make the
# string whiff. AIR_HOME_MAX caps the lunge speed.
const AIR_HOME_RANGE := 5.5
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


# --- Routing ------------------------------------------------------------------

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


## void_route(), plus the vault: while his frost spear stands, either press takes him up over it.
static func routed(hero: CharacterBody3D, kind: String, from: String, attacking: bool, chain: int, post_dash: bool) -> String:
	if VOID_ELEMENT.vaults(hero.get_tree(), from, attacking, post_dash):
		return "IJ"
	return void_route(kind, from, attacking, chain, post_dash)


## Light chain position after `id` starts.
static func chain_after(id: String) -> int:
	if id in LIGHT_CHAIN:
		return (LIGHT_CHAIN.find(id) + 1) % LIGHT_CHAIN.size()
	if id == "DL":
		return 1  # a dash stab flows into L2
	return VOID_ELEMENT.CHAIN.get(id, 0)


## Progress through the current move: a fraction of its clip (MOVES timings are in these).
static func progress(hero: CharacterBody3D) -> float:
	return hero._state_t * hero.anim_speed * hero._anim_mult / hero._move_len


## A copy of the MOVES entry for this press (never mutates MOVES itself), retimed for his clips.
static func effective_move(anim: AnimationPlayer, id: String) -> Dictionary:
	var m: Dictionary = MOVES[id].duplicate(true)
	if ComicLook.HERO_MOVES.has(id):
		var length := anim.get_animation(ComicLook.HERO_MOVES[id].clip).length
		ComicLook.retime(id, m, length, MOVES[id].hits[0], VOID_ELEMENT.BREAKERS.get(id, {}).get("leap", -1.0))
	return m


# --- Hops, the air string, plunges ----------------------------------------------

## The move's height off the floor at progress `t`: comes down from where it
## started by `land` (first hit), plus its own `hop` arc.
static func hop(hero: CharacterBody3D, t: float) -> void:
	var move: Dictionary = hero._move
	var y0: float = hero._hop_y0
	var y := 0.0
	if move.get("air", false):  # air move: hold the height it started at
		# `climb`: rise this much more by the hit, so each air cut goes higher.
		var cap := AIR_MAX_HEIGHT
		var climb: float = minf(move.get("climb", 0.0), maxf(0.0, cap - y0))
		var up: float = climb * smoothstep(0.0, move.hits[0], t)
		y = minf(y0 + up + sin(t * PI) * 0.15, cap + 0.15)
	elif y0 > 0.0:
		var land: float = move.get("land", move.hits[0])
		var k := clampf(t / maxf(land, 0.01), 0.0, 1.0)
		y = y0 * (1.0 - k * k)  # accelerating down onto the hit
	if move.has("hop"):
		var h: Array = move.hop
		if t > h[0] and t < h[1]:
			var k: float = (t - h[0]) / (h[1] - h[0])
			y += h[2] * 4.0 * k * (1.0 - k)
	if y > 0.4:
		hero._hop_air = true
		hero._hop_peak = maxf(hero._hop_peak, y)
	elif hero._hop_air and y < 0.05:
		hero._hop_air = false  # landed onto the hit: a slam
		land_slam(hero, hero._hop_peak)
		hero._hop_peak = 0.0
	hero.model.position.y = y


## Damage multiplier for the current move's plunge (see PLUNGE_PER_M): only
## for moves that start in the air and land, and only on their first hit.
static func plunge_mult(hero: CharacterBody3D) -> float:
	if hero._move.get("air", false) or hero._hits_done > 1:
		return 1.0
	return 1.0 + PLUNGE_PER_M * maxf(0.0, hero._hop_y0 - 0.4)


## Landing from a hop: dust, a ring in the hero's colour and a shake, all
## bigger the further he fell (an air-string Triple Chop lands hardest).
static func land_slam(hero: CharacterBody3D, peak: float) -> void:
	var k := 1.0 + (SLAM_SCALE - 1.0) * clampf((peak - 0.4) / (SLAM_FULL_HEIGHT - 0.4), 0.0, 1.0)
	var parent := hero.get_parent()
	Fx.dust(parent, hero.global_position, int(6 * k), 0.5 * k)
	if not VOID_ELEMENT.is_element_move(hero._move_id):  # (his tentacle moves land on him: it hid them)
		Fx.ring(parent, hero.global_position + hero._facing() * 0.8, Color(hero._fx_color(), 0.8), 2.2 * k, 0.22)
	Game.shake(0.12 * k)


## Juggle tracking (AIR_HOME_*): face the nearest airborne foe and lunge to
## reach it by the first hit. The lunge decays to 0 by a third of the move
## (`decay` 3), covering lunge * length / 6 metres.
static func air_home(hero: CharacterBody3D) -> void:
	var best: Node3D = null
	var best_d := AIR_HOME_RANGE
	for e in hero.get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive() or not e.is_airborne():
			continue
		var to: Vector3 = e.global_position - hero.global_position
		to.y = 0.0
		if to.length() < best_d:
			best_d = to.length()
			best = e
	if best == null:
		return
	var to := best.global_position - hero.global_position
	to.y = 0.0
	if to.length() > 0.05:
		hero._face(to)
		hero.model.rotation.y = hero._facing_yaw
	var move: Dictionary = hero._move
	var gap: float = best_d - move.get("range", 2.5) * 0.6
	if gap <= 0.0:
		return
	var length: float = hero._move_len / maxf(hero.anim_speed * hero._anim_mult, 0.01)
	var decay: float = move.get("decay", 3.0)
	var need := gap * 2.0 * decay / maxf(length, 0.01)  # travel = lunge * length / (2 * decay)
	move.lunge = clampf(maxf(move.lunge, need), 0.0, AIR_HOME_MAX)


## Whether a dash now would be an air dash (AIR_DASH_*).
static func can_air_dash(hero: CharacterBody3D) -> bool:
	return hero._move_id in AIR_DASH_FROM and hero.model.position.y >= AIR_DASH_MIN and hero._air_dashes < AIR_DASHES


## The air dash's spectral axe (AIR_DASH_CUT): a spirit_echo parented to the
## hero at the model's height, so it travels with the dash, sweeping round
## the dash direction. Grows with the chain like the casts.
static func air_dash_cut(hero: CharacterBody3D) -> void:
	var c: Dictionary = AIR_DASH_CUT
	var echo: Node3D = hero._spirit(SPIRIT_ECHO.new(), c, hero.element())
	echo.fwd = hero._dash_dir
	echo.arc_deg = c.arc
	echo.radius = c.radius * hero._cast_grow()
	echo.delay = 0.0
	echo.time = c.time
	hero.add_child(echo)
	echo.position = Vector3(0.0, hero.model.position.y, 0.0)


# --- The combo guide ------------------------------------------------------------

## What the combo guide shows right now: one row per input that continues the
## string ("light", "heavy", "dash" = dash then light), each with the move it
## starts and the best named combo one more press past it, plus `pause` when
## waiting for the move to finish first starts a different named combo.
## Empty when there's no string to continue.
static func combo_options(hero: CharacterBody3D) -> Array:
	var state: int = hero.state
	var attacking: bool = state == hero.State.ATTACK
	var dashing: bool = state == hero.State.DASH or hero._post_dash_t > 0.0
	var live: bool = attacking or dashing or state == hero.State.CHARGE or (state == hero.State.MOVE and hero._chain_i > 0)
	if not live:
		return []
	if state == hero.State.CHARGE:
		return [option(hero, "heavy", VOID_ELEMENT.CHARGED, true)]
	var rows := []
	var kinds: Array[String] = ["light", "heavy"]
	for kind: String in kinds:
		var id := routed(hero, kind, hero._move_id, attacking, hero._chain_i, dashing)
		if kind == "heavy" and id == VOID_ELEMENT.NEUTRAL:
			continue  # a lone grab isn't a continuation
		var o := option(hero, kind, id)
		if attacking:
			var wait := routed(hero, kind, hero._move_id, false, hero._chain_i, false)
			if wait != id and COMBOS.has(wait):
				o.pause = {"id": wait, "name": guide_name(wait), "tier": COMBOS[wait].tier}
		rows.append(o)
	if attacking and not dashing:
		rows.append(option(hero, "dash", dash_light(hero)))
	return rows


## What dash-then-light starts from here (the combo guide's dash row): Dash Stab, in the air too.
static func dash_light(hero: CharacterBody3D) -> String:
	return void_route("light", hero._move_id, false, hero._chain_i, true)


## One guide row: the move a press starts and the best named combo one more press past it.
static func option(hero: CharacterBody3D, kind: String, id: String, hold := false) -> Dictionary:
	var o := {"kind": kind, "id": id, "name": guide_name(id), "tier": COMBOS[id].tier if COMBOS.has(id) else 0,
		"hold": hold, "next": {}}
	if o.tier < 3 and not hold:
		var best := 0
		for k: String in ["heavy", "light"]:  # heavy first: wins ties
			var n := routed(hero, k, id, true, chain_after(id), false)
			var tier: int = COMBOS[n].tier if COMBOS.has(n) else 0
			if hero.combos_landed.get(n, 0) >= GUIDE_LEARNED:
				tier = 0  # learned: no need to hint it any more
			if tier > best:
				best = tier
				o.next = {"kind": k, "id": n, "name": guide_name(n), "tier": tier}
	return o


## A move's name for the guide: its combo's name, else MOVE_NAMES, else the id.
static func guide_name(id: String) -> String:
	return COMBOS[id].name if COMBOS.has(id) else MOVE_NAMES.get(id, id)
