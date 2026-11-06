extends RefCounted
## The dragon prince's moves (first slice, docs/characters/dragon-prince.md section 8): the MOVES table in the
## heretic's shape (timings are fractions of the clip, hero_moves.gd's convention, so HERO_MOVES.progress() and
## HERO_INPUT.combo_window() read his moves too), the named COMBOS, the sword-state routing (route()), and the
## rows the combo guide and the pause menu's MOVES panel show for him. Static, over prince.gd's state.
##
## Every open question in the design doc (section 9) that this slice had to answer is a named constant here or
## in prince.gd / sunbrand.gd, so a different answer is a one-line flip.

# --- Open-question defaults (dragon-prince.md section 9), cheap to flip -----------------------------
## Q1 One Sword (A): a throw costs him the sword until he smashes or recalls it. false would be the Armory (B):
## a fresh sword forms in his hand the moment one is thrown (only one sword out at a time in this slice).
const ONE_SWORD := true
## Q2 the smash on H any time the sword is out (within SMASH_REACH), not only from strings.
const SMASH_ANY_TIME := true
## Q3 Royal Draw (timed L at the gleam) is not in this slice: the sword always re-forms by itself after
## prince.REFORM_TIME. When it lands, this flag turns the timed press on.
const ROYAL_DRAW := false
## Q8 working names.
const HERO_NAME := "Prince Aurex"
const SWORD_NAME := "Sunbrand"

# --- Clip pacing (the chibi heretic's clips stand in until he has his own) ----------------------------
const SLASH_HIT := 11.0 / 31.0  # Ab_L1's contact
const RIPOSTE_HIT := 0.42  # Dualwield_Melee_Attack_Slice (KayKit, unretimed)
const CLEAVE_HIT := 24.0 / 56.0  # Ab_L3: the overhead lands
const JAVELIN_HIT := 12.0 / 33.0  # Ab_L2: the hurl leaves the hand
const TALON_HIT := 14.0 / 51.0  # Ab_LH: the rake
const BREATH_HIT := 0.3  # Spellcast_Shoot

## L L L H has no move of its own yet (Sword in the Stone is the next slice): it breathes.
const LLLH_FALLBACK := "P_BREATH"

const MOVES := {
	# In hand: Royal Chain.
	"P_SLASH": {"anim": "Ab_L1", "damage": 9.0, "range": 2.6, "arc": 150.0, "hits": [SLASH_HIT],
		"cancel": SLASH_HIT + 0.12, "end": 0.75, "lunge": 7.0, "knockback": 2.5, "launch": 0.0,
		"stop": 0.045, "shake": 0.12, "speed": 1.1},
	"P_RIPOSTE": {"anim": "Dualwield_Melee_Attack_Slice", "damage": 10.0, "range": 2.6, "arc": 160.0,
		"hits": [RIPOSTE_HIT], "cancel": RIPOSTE_HIT + 0.14, "end": 0.78, "lunge": 6.0, "knockback": 2.5,
		"launch": 0.0, "stop": 0.05, "shake": 0.14, "speed": 1.25},
	"P_CLEAVE": {"anim": "Ab_L3", "damage": 20.0, "range": 2.9, "arc": 150.0, "hits": [CLEAVE_HIT],
		"cancel": CLEAVE_HIT + 0.2, "end": 0.95, "lunge": 8.0, "knockback": 5.0, "launch": 0.0,
		"stop": 0.09, "shake": 0.35, "speed": 1.3, "big": true},
	# L H: Ember Flick, a slash and a breath puff past the blade.
	"P_FLICK": {"anim": "Ab_L1", "damage": 7.0, "range": 2.6, "arc": 150.0, "hits": [SLASH_HIT],
		"cancel": SLASH_HIT + 0.2, "end": 0.8, "lunge": 5.0, "knockback": 3.0, "launch": 0.0,
		"stop": 0.05, "shake": 0.15, "speed": 1.0, "breath": 0.6},
	# L L H: Javelin. The hit frame throws the sword (sunbrand.gd does the damage).
	"P_JAVELIN": {"anim": "Ab_L2", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [JAVELIN_HIT],
		"cancel": JAVELIN_HIT + 0.14, "end": 0.7, "lunge": 3.0, "knockback": 0.0, "launch": 0.0,
		"stop": 0.0, "shake": 0.1, "speed": 1.2, "throw": true},
	# H with nothing set up: Dragon Breath. Two ticks of the cone.
	"P_BREATH": {"anim": "Spellcast_Shoot", "damage": 0.0, "range": 0.0, "arc": 0.0,
		"hits": [BREATH_HIT, BREATH_HIT + 0.14], "cancel": BREATH_HIT + 0.3, "end": 0.75, "lunge": 0.0,
		"knockback": 0.0, "launch": 0.0, "stop": 0.0, "shake": 0.1, "speed": 1.2, "breath": 1.0},
	# Sword out: the Talon string (conjured claws), ~60% of the sword's damage, shorter reach.
	"P_TALON1": {"anim": "Ab_LH", "damage": 5.0, "range": 2.0, "arc": 130.0, "hits": [TALON_HIT],
		"cancel": TALON_HIT + 0.1, "end": 0.5, "lunge": 7.0, "knockback": 1.5, "launch": 0.0,
		"stop": 0.035, "shake": 0.08, "speed": 1.5, "talon": true},
	"P_TALON2": {"anim": "Ab_LH", "damage": 6.0, "range": 2.0, "arc": 130.0, "hits": [TALON_HIT],
		"cancel": TALON_HIT + 0.1, "end": 0.5, "lunge": 7.0, "knockback": 2.0, "launch": 0.0,
		"stop": 0.04, "shake": 0.1, "speed": 1.6, "talon": true},
	"P_TALON3": {"anim": "Ab_L3", "damage": 11.0, "range": 2.2, "arc": 150.0, "hits": [CLEAVE_HIT],
		"cancel": CLEAVE_HIT + 0.18, "end": 0.85, "lunge": 7.0, "knockback": 4.5, "launch": 0.0,
		"stop": 0.07, "shake": 0.22, "speed": 1.5, "talon": true, "big": true},
	# Sword out, H: the smash (prince.gd's own phases; this entry is for the readers of _move).
	"P_SMASH": {"anim": "Jump_Idle", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [], "cancel": 1.0,
		"end": 1.0, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.0, "shake": 0.0, "speed": 1.0},
	# Sword out, hold L: Rightful Return, the recall (he raises a hand; the sword does the hitting).
	"P_RECALL": {"anim": "Spellcast_Raise", "damage": 0.0, "range": 0.0, "arc": 0.0, "hits": [], "cancel": 0.2,
		"end": 0.25, "lunge": 0.0, "knockback": 0.0, "launch": 0.0, "stop": 0.0, "shake": 0.0, "speed": 1.6},
}

## Named strings: landing the move's first hit calls it out over him (prince.gd _callout_combo).
const COMBOS := {
	"P_CLEAVE": {"name": "Royal Chain", "input": "L L L", "tier": 1},
	"P_FLICK": {"name": "Ember Flick", "input": "L H", "tier": 1},
	"P_JAVELIN": {"name": "Javelin", "input": "L L H", "tier": 2},
	"P_TALON3": {"name": "Talon Fury", "input": "L L L (sword out)", "tier": 1},
	"P_SMASH": {"name": "Skyfall", "input": "H (sword out)", "tier": 3},
	"P_RECALL": {"name": "Rightful Return", "input": "hold L (sword out)", "tier": 2},
}
const MOVE_NAMES := {"P_SLASH": "Slash", "P_RIPOSTE": "Riposte", "P_BREATH": "Dragon Breath",
	"P_TALON1": "Talon", "P_TALON2": "Talon"}
const CHAIN := ["P_SLASH", "P_RIPOSTE", "P_CLEAVE"]
const TALONS := ["P_TALON1", "P_TALON2", "P_TALON3"]
## The H after each light of the chain (the L count picks the H, like the heretic's).
const HEAVY_AFTER := {"P_SLASH": "P_FLICK", "P_RIPOSTE": "P_JAVELIN", "P_CLEAVE": LLLH_FALLBACK}


## Which move a press starts. `sword`: "hand", "out" or "shattered" (sunbrand.gd state_word()); `reach`: the
## sword is within SMASH_REACH; `chain`: lights so far in this string.
static func route(kind: String, from: String, attacking: bool, chain: int, sword: String, reach: bool) -> String:
	if sword == "hand":
		if kind == "light":
			return CHAIN[chain % CHAIN.size()]
		if attacking or chain > 0:
			return HEAVY_AFTER.get(from, "P_BREATH")
		return "P_BREATH"
	if kind == "light":
		return TALONS[chain % TALONS.size()]
	if sword == "out" and reach and SMASH_ANY_TIME:
		return "P_SMASH"
	return "P_BREATH"  # shattered, or too far: breath covers the gap


static func guide_name(id: String) -> String:
	return COMBOS[id].name if COMBOS.has(id) else MOVE_NAMES.get(id, id)


## The pause menu's MOVES panel for him (pause_menu.gd calls player.move_sections()). Text rows: the heretic's
## move_list check walks only his own SECTIONS.
const SECTIONS := [
	{"title": "SUNBRAND IN HAND", "hint": "The sword icon by him: gold = in hand, outline = out, cracked = re-forming.", "rows": [
		{"input": "L L L", "kind": "text", "name": "Royal Chain", "tier": 1, "note": "Slash, Riposte, Crown Cleave: wide gold arcs, the last an overhead."},
		{"input": "L H", "kind": "text", "name": "Ember Flick", "tier": 1, "note": "A slash and a puff of dragonfire past the blade."},
		{"input": "L L H", "kind": "text", "name": "Javelin", "tier": 2, "note": "Throws the sword through the first foe in line; it sticks in it (or the floor)."},
		{"input": "H", "kind": "text", "name": "Dragon Breath", "tier": 0, "note": "A short fire cone in front."},
	]},
	{"title": "SUNBRAND OUT", "hint": "His hands are empty: claws on L, the sword is a bomb.", "rows": [
		{"input": "H", "kind": "text", "name": "Skyfall", "tier": 3, "note": "Wings up over the sword and dives onto it: it explodes. A new one forms in 0.7 s."},
		{"input": "hold L", "kind": "text", "name": "Rightful Return", "tier": 2, "note": "Calls the sword back along a line, hitting everything on it."},
		{"input": "L L L", "kind": "text", "name": "Talon Fury", "tier": 1, "note": "Conjured dragon claws: fast, shorter, weaker than the sword."},
		{"input": "H (too far, or re-forming)", "kind": "text", "name": "Dragon Breath", "tier": 0, "note": "Covers the gap while the sword is away."},
	]},
]
