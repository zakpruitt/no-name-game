extends RefCounted
## Everything the heretic can press, grouped for reading: the pause menu's MOVES
## panel draws this, and tests/move_list_check.gd walks every row's input
## through player.void_route(), so a new move that isn't listed here (or an
## input that's wrong) fails the checks.
##
## A row: `input` as the player reads it (tokens L, H, Dash, "hold H", R;
## ", H in the window" = the breaker press); `kind`:
##   move     `id` is a player.MOVES / COMBOS id; the check routes it
##   text     `name` is literal, not a routed press (the breakers, the grab, R)
## `tier`: colour for rows that aren't COMBOS (player.COMBO_TIER_COLORS).
## `note`: what it does.

const SECTIONS := [
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
		{"input": "L L L H H, H in the window", "kind": "text", "name": "Meteor Fall", "tier": 3, "note": "The tentacles hurl them all into the walls, drag them back into one pile, and he dives into it as a meteor. The biggest takes it worst, and shields come off for good."},
	]},
	{"title": "DARK", "rows": [
		{"input": "H", "kind": "text", "name": "Grab", "note": "Yanks a foe to him. Something too big drags him to it instead. Whips on a miss."},
		{"input": "H H", "kind": "move", "id": "VS", "note": "Heaves what it holds overhead and slams it: a black hole tears open there and drags foes in."},
		{"input": "H H, H in the window", "kind": "text", "name": "Collapse", "tier": 3, "note": "He comes down at the hole. It falls in on itself and throws everyone clear, hard."},
		{"input": "H L", "kind": "move", "id": "VR", "note": "A crescent of darkness through everyone in front of him. It marks them."},
		{"input": "H L H", "kind": "move", "id": "VD", "note": "A pool opens ahead, and everyone marked is dragged across the floor into it, however far off."},
		{"input": "H L H, H in the window", "kind": "text", "name": "Maw", "tier": 3, "note": "Jaws of darkness come up out of the pool and shut on them."},
		{"input": "H L H, L in the window", "kind": "text", "name": "Black Ice", "tier": 3, "note": "Dark into ice: the pool freezes over with them in it, and he lands and shatters it."},
		{"input": "hold H", "kind": "move", "id": "OW", "note": "A black pool under what he's aiming at, with tendrils piling on. Works on big foes."},
		{"input": "hold H, H in the window", "kind": "text", "name": "Abyss", "tier": 3, "note": "They sink through the floor, then black spikes throw them back up."},
		{"input": "Dash H", "kind": "move", "id": "TW", "note": "Latches onto whoever he just passed and yanks them into each other."},
		{"input": "R", "kind": "text", "name": "Swing", "note": "Swings him the way he's aiming, round a pillar if there's one there. Hold R to go further; letting go flings him."},
		{"input": "R, then H", "kind": "text", "name": "Snatch", "note": "Grabs a foe on the way past, carries it, and it flies on when he lets go."},
	]},
	{"title": "CROSSOVERS", "hint": "Strings that change element: the second cashes in what the first set up.", "rows": [
		{"input": "L H L L", "kind": "move", "id": "XR", "note": "Storm into earth: the hammer comes down off the air slash and drives everyone into the floor together. Double on those the gale had up."},
		{"input": "L H L L H", "kind": "move", "id": "XF", "note": "Earth into storm: cracks run to each of them and the gale comes up out of them, throwing the buried hardest."},
		{"input": "L H L L H, H in the window", "kind": "text", "name": "Cataclysm", "tier": 3, "note": "Lightning through them in the hang, then down into the floor, a strike and the earth under each."},
		{"input": "Dash L H H L", "kind": "move", "id": "XS", "note": "Ice into magma: the molten fist goes into the ice and every frozen foe goes off in steam, scalding the rest."},
		{"input": "Dash L H H L, H in the window", "kind": "text", "name": "Flash Freeze", "tier": 3, "note": "The steam freezes on them as he dives, and the landing shatters it again."},
		{"input": "Dash H L", "kind": "move", "id": "XT", "note": "Dark into storm: the axe hurls whoever Tow Line bunched, lightning jumping off them at everyone they pass."},
	]},
]


## What the row is called.
static func row_name(row: Dictionary, player: Node) -> String:
	if row.kind == "move":
		return player.guide_name(row.id)
	return row.name


## The tier whose colour the row wears (0 = plain).
static func row_tier(row: Dictionary, player: Node) -> int:
	if row.kind == "move" and player.COMBOS.has(row.id):
		return player.COMBOS[row.id].tier
	return row.get("tier", 0)


## The row's COMBOS id if it should show a landed count.
static func row_combo(row: Dictionary, player: Node) -> String:
	if row.kind == "move" and not row.get("alt", false) and player.COMBOS.has(row.id):
		return row.id
	return ""
