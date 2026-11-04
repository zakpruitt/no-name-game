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
##   trinity  named per element, not a routed press
##   text     `name` is literal, not a routed press
## `alt`: another way into a move listed above (no landed count or powers).
## `tier`: colour for rows that aren't COMBOS (player.COMBO_TIER_COLORS).
## `note`: what it does; the wiki shows it.

## The comic hero's moves while the void arm is being worked out (player.void_route()).
const VOID_SECTIONS := [
	{"title": "WEAPONS", "rows": [
		{"input": "L", "kind": "move", "id": "L1", "note": "Axe: storm."},
		{"input": "L L", "kind": "move", "id": "L2", "note": "Spear: ice."},
		{"input": "L L L", "kind": "move", "id": "L3", "note": "Hammer: magma."},
		{"input": "Dash L", "kind": "move", "id": "DL", "note": "Spear: a lunge off a dash, or off a swing."},
	]},
	{"title": "STORM", "rows": [
		{"input": "L H", "kind": "move", "id": "EC", "note": "The tentacle sweeps under them and the wind throws them up."},
		{"input": "L H H", "kind": "move", "id": "EE", "note": "A tentacle on each of them, with lightning running through."},
		{"input": "L H H, H in the window", "kind": "text", "name": "Grounded", "tier": 3, "note": "Everyone slammed down, with lightning under each."},
		{"input": "L H L", "kind": "move", "id": "AL1", "note": "Up after them with the axe."},
		{"input": "L H L H", "kind": "move", "id": "EW", "note": "Live Wire from the air. The window has two endings."},
		{"input": "L H L H, H in the window", "kind": "text", "name": "Worldbreaker", "tier": 3, "note": "Slammed into the floor, with magma erupting under each."},
		{"input": "L H L H, L in the window", "kind": "text", "name": "Cold Front", "tier": 3, "note": "Frozen solid and hurled at the others as ice cubes."},
	]},
	{"title": "ICE", "rows": [
		{"input": "L L H", "kind": "move", "id": "IP", "note": "Plants the spear. Frost spreads out from it and slows whoever's on it."},
		{"input": "L L H L", "kind": "move", "id": "IJ", "note": "Vaults up over the spear, any time while it stands. Right click does too."},
		{"input": "L L H L H", "kind": "move", "id": "IS", "note": "Slams down onto the spear: it explodes and everyone on the frost freezes into a cube."},
		{"input": "L L H L H, H in the window", "kind": "text", "name": "Avalanche", "tier": 3, "note": "The tentacles pick up every cube and slam them all together in the middle."},
		{"input": "Dash L H", "kind": "move", "id": "EF", "note": "A spear tip through a whole line: they freeze and are reeled in, one behind the other."},
		{"input": "Dash L H H", "kind": "move", "id": "EA", "note": "Freezes the nearest and bowls it. Everyone it passes freezes too."},
	]},
	{"title": "MAGMA", "rows": [
		{"input": "L L L H", "kind": "move", "id": "EM", "note": "The arm swells into a fist and shoves them along a line of lava. A wall hits hard."},
		{"input": "L L L H H", "kind": "move", "id": "EV", "note": "Tendrils drag them waist-deep into lava, stuck and burning, however far the palm sent them."},
		{"input": "L L L H H, H in the window", "kind": "text", "name": "Meteor Fall", "tier": 3, "note": "He goes up and comes down on them as a meteor, wherever they are. The biggest takes it worst, and shields come off for good."},
	]},
	{"title": "DARK", "rows": [
		{"input": "H", "kind": "text", "name": "Grab", "note": "Yanks a foe to him. Something too big drags him to it instead. Whips on a miss."},
		{"input": "H H", "kind": "move", "id": "VS", "note": "Heaves what it holds overhead and slams it: a black hole tears open there and drags foes in."},
		{"input": "H H, H in the window", "kind": "text", "name": "Collapse", "tier": 3, "note": "He comes down at the hole. It falls in on itself and throws everyone clear, hard."},
		{"input": "H L", "kind": "move", "id": "VR", "note": "A crescent of darkness through everyone in front of him. It marks them."},
		{"input": "H L H", "kind": "move", "id": "VD", "note": "A pool opens ahead, and everyone marked is dragged across the floor into it, however far off."},
		{"input": "H L H, H in the window", "kind": "text", "name": "Maw", "tier": 3, "note": "Jaws of darkness come up out of the pool and shut on them."},
		{"input": "hold H", "kind": "move", "id": "OW", "note": "A black pool under what he's aiming at, with tendrils piling on. Works on big foes."},
		{"input": "hold H, H in the window", "kind": "text", "name": "Abyss", "tier": 3, "note": "They sink through the floor, then black spikes throw them back up."},
		{"input": "Dash H", "kind": "move", "id": "TW", "note": "Latches onto whoever he just passed and yanks them into each other."},
		{"input": "R", "kind": "text", "name": "Swing", "note": "Swings him the way he's aiming, round a pillar if there's one there. Hold R to go further; letting go flings him."},
		{"input": "R, then H", "kind": "text", "name": "Snatch", "note": "Grabs a foe on the way past, carries it, and it flies on when he lets go."},
	]},
]


## Only the comic hero has these, so route() and SECTIONS never see them (tests/void_arm_check.gd walks them).
const VOID_ONLY := ["GR", "VS", "EC", "EE", "EW", "EF", "IP", "IJ", "IS", "EA", "EM", "EV", "VR", "VD", "OW", "TW"]


## What the pause menu lists for this hero.
static func sections_for(player: Node) -> Array:
	return VOID_SECTIONS if player != null and player.get("_void") != null else SECTIONS


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
		{"input": "L L L H", "kind": "move", "id": "AF", "note": "The finisher: erupts all around."},
		{"input": "L H H", "kind": "move", "id": "SKY", "note": "Ultimate: leaps at a foe and smashes down on everything round it."},
		{"input": "Dash L H", "kind": "move", "id": "RUSH", "note": "Ultimate: charges through everything ahead, then the whole line erupts."},
		{"input": "Air: H", "kind": "move", "id": "SKY", "alt": true, "note": "Heavy from any other air move or air dash is the same ultimate (Sky Rend is Updraft until the gale is used)."},
		{"input": "All three", "kind": "trinity", "tier": 3, "note": "All three ultimates in one Awakening call the storm down on every foe near him."},
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
