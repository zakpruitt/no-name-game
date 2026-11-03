extends RefCounted
## Everything the shaman can press, grouped for reading: the pause menu's MOVES
## panel and the wiki's move list both draw this, and tests/move_list_check.gd
## walks every row's input through player.route(), so a new move that isn't
## listed here (or an input that's wrong) fails the checks.
##
## A row: `input` as the player reads it (tokens L, H, Dash, pause, "hold H";
## "Air:" = mid air string, "Air Dash" = an air dash); `kind`:
##   move     `id` is a player.MOVES / COMBOS / ULTIMATES id; the check routes it
##   breaker  `id` is a player.BREAKERS id; input is the ender's + " > H"
##   trinity, rite  named per element, not a routed press
##   text     `name` is literal, not a routed press
## `alt`: another way into a move listed above (no landed count or powers).
## `tier`: colour for rows that aren't COMBOS (player.COMBO_TIER_COLORS).
## `note`: what it does; the wiki shows it.

const RITES := preload("res://scripts/element_rite.gd")

const SECTIONS := [
	{"title": "BASICS", "rows": [
		{"input": "L", "kind": "move", "id": "L1", "note": "Opens the light chain."},
		{"input": "L L", "kind": "move", "id": "L2", "note": "Second light: hops onto its hit and hurls a blade of the element."},
		{"input": "H", "kind": "move", "id": "H", "note": "Heavy from neutral: a leaping multi-hit spin for crowds."},
		{"input": "Dash", "kind": "text", "name": "Dodge", "note": "Invulnerable, and cancels any attack once its first hit is out."},
		{"input": "Dash as a hit lands", "kind": "text", "name": "Perfect Dodge", "tier": 2, "note": "Stuns the attacker and refunds Awakening."},
		{"input": "Q", "kind": "text", "name": "Awaken", "tier": 2, "note": "With a full meter: faster, harder hits, super armor, and the ultimates below."},
	]},
	{"title": "COMBOS", "rows": [
		{"input": "L L L", "kind": "move", "id": "L3", "note": "Press through Hurl: a leaping chop with big knockback."},
		{"input": "L L, pause, L", "kind": "move", "id": "LPL", "note": "Let Hurl finish, then light: five quick weaving cuts that keep foes in reach."},
		{"input": "L H", "kind": "move", "id": "LH", "note": "Heavy after a light (or after any move but the spin): launches the target."},
		{"input": "L L H", "kind": "move", "id": "LLH", "note": "Heavy right after Hurl: a thrust down a strip that knocks down and breaks guards."},
		{"input": "L H H", "kind": "move", "id": "LHH", "note": "Heavy after the launcher: an overhead chop that slams juggled foes down."},
		{"input": "hold H", "kind": "move", "id": "CH", "note": "Hold heavy from neutral, release to leap into a launching slam that breaks guards."},
		{"input": "Dash > L", "kind": "move", "id": "DL", "note": "A pouncing stab out of a dash. Flows on: L is Hurl, H is the launcher."},
		{"input": "Dash > H", "kind": "move", "id": "DH", "note": "A spin that keeps travelling through the crowd."},
	]},
	{"title": "AIR STRING", "rows": [
		{"input": "L H L", "kind": "move", "id": "AL1", "note": "Light after the launcher: stays up with the foe and climbs."},
		{"input": "L H L L", "kind": "move", "id": "AL2", "note": "A second cut, higher again. Light or heavy decides how it ends."},
		{"input": "L H L L L", "kind": "move", "id": "SKYFALL", "note": "Triple Chop plunging from the top: extra damage and a fan of spectral axes."},
		{"input": "L H L L H", "kind": "move", "id": "AH", "note": "A gale lifts him past the normal ceiling and gives the air dash back. Once per trip up."},
		{"input": "L H L L H L", "kind": "move", "id": "AL3", "note": "Three weaving cuts on the gale, each flinging a spectral axe and a wind blade."},
		{"input": "L H L L H L L", "kind": "move", "id": "STORMFALL", "note": "Triple Chop from the very top: the floor cracks into a crater and the element erupts."},
		{"input": "Air: H", "kind": "move", "id": "LHH", "alt": true, "note": "Heavy from any other air move drops him into Spike (Sky Rend is Updraft until the gale is used)."},
		{"input": "Air: Dash", "kind": "text", "name": "Air Dash", "note": "Keeps his height and cuts with a spectral axe. One per trip up."},
		{"input": "Air Dash > L", "kind": "move", "id": "AL1", "alt": true, "note": "Back into the air string."},
		{"input": "Air Dash > H", "kind": "move", "id": "LHH", "alt": true, "note": "Spike down out of the air dash."},
	]},
	{"title": "COMBO BREAKERS", "hint": "H as the rings meet, once the ender connects", "rows": [
		{"input": "L L H > H", "kind": "breaker", "id": "LLH", "tier": 2, "note": "Hurls spectral axes ahead, then dives onto them and detonates them."},
		{"input": "L H H > H", "kind": "breaker", "id": "LHH", "tier": 2, "note": "Axes hover over each nearby foe, then all drop with his dive."},
		{"input": "hold H > H", "kind": "breaker", "id": "CH", "tier": 2, "note": "Leaps after the launched foes, juggling them in a sawblade, then slams down."},
		{"input": "L L, pause, L > H", "kind": "breaker", "id": "LPL", "tier": 2, "note": "Stays grounded: dashes through the line, which erupts in spectral axes."},
		{"input": "Dash > H > H", "kind": "breaker", "id": "DH", "tier": 2, "note": "Spins up pulling foes in, then flings a ring of tomahawks."},
	]},
	{"title": "AWAKENED", "awake": true, "rows": [
		{"input": "L L L H", "kind": "move", "id": "AF", "note": "The finisher: erupts all around. An Ascendancy replaces it with its own."},
		{"input": "L H H", "kind": "move", "id": "SKY", "note": "Ultimate: leaps at a foe and smashes down on everything round it."},
		{"input": "Dash L H", "kind": "move", "id": "RUSH", "note": "Ultimate: charges through everything ahead, then the whole line erupts."},
		{"input": "Air: H", "kind": "move", "id": "SKY", "alt": true, "note": "Heavy from any other air move or air dash is the same ultimate (Sky Rend is Updraft until the gale is used)."},
		{"input": "All three", "kind": "trinity", "tier": 3, "note": "All three ultimates in one Awakening call the storm down on every foe near him."},
	]},
	{"title": "ASCENDED", "rows": [
		{"input": "any H, then any H", "kind": "rite", "tier": 2, "note": "Each heavy lays down his element and the next sets it off."},
	]},
]


## What the row is called right now (names change with the element).
static func row_name(row: Dictionary, player: Node) -> String:
	var el: String = player.element()
	match row.kind:
		"move":
			return player.guide_name(row.id)
		"breaker":
			return player.BREAKERS[row.id].names[el]
		"trinity":
			return player.TRINITY.names[el]
		"rite":
			return RITES.NAMES.get(el, "Element Rite")
	return row.name


## The tier whose colour the row wears (0 = plain).
static func row_tier(row: Dictionary, player: Node) -> int:
	if row.kind == "move" and player.COMBOS.has(row.id):
		return player.COMBOS[row.id].tier
	return row.get("tier", 0)


## The row's COMBOS id if it should show a landed count and hooked powers.
static func row_combo(row: Dictionary, player: Node) -> String:
	if row.kind == "move" and not row.get("alt", false) and player.COMBOS.has(row.id):
		return row.id
	return ""
