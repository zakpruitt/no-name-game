extends RefCounted
## Everything the heretic can press, grouped for reading: the pause menu's MOVES
## panel draws this, and tests/move_list_check.gd walks every row's input
## through hero_moves.void_route(), so a new move that isn't listed here (or an
## input that's wrong) fails the checks.
##
## A row: `input` as the player reads it (tokens L, H, Dash, "hold H", R;
## ", H in the window" = the breaker press); `kind`:
##   move     `id` is a player.MOVES / COMBOS id; the check routes it
##   text     `name` is literal, not a routed press (the breakers, the grab, R)
## `tier`: colour for rows that aren't COMBOS (player.COMBO_TIER_COLORS).
## `note`: what it does.
## `or`: a breaker's other ending, pressed in the same window (void_element.BREAKERS `alt`): the pause panel draws
## it under the first as "or L in the window", so the pair reads as one choice (round 43).
##
## Round 49 (kit slots): the sections are the kit grammar's slot groups (`group`: KitSlots.GROUPS' n, whose name and
## role line are the heading, `heading()`), then ROUTE STEPS, UPGRADES and MIX ELEMENTS. A move row's slot is
## KitSlots.slot_of(id) (its one-word tag, `row_tag()`). `upgrade`: a Kit upgrade id; a row whose move or payoff is
## behind an upgrade that is off draws as an "upgrade" row (`row_locked()`), and move_list_check expects its input
## to reach the move only with the upgrade on. A slot with no move yet (pending: the sixth crossover)
## is drawn from the card (`pending_slots()`).

const SECTIONS := [
	{"group": 1, "rows": [
		{"input": "L", "kind": "move", "id": "L1", "note": "Axe: storm."},
		{"input": "L L", "kind": "move", "id": "L2", "note": "Spear: ice."},
		{"input": "L L L", "kind": "move", "id": "L3", "note": "Hammer: magma."},
	]},
	{"group": 2, "rows": [
		{"input": "L H", "kind": "move", "id": "EC", "note": "The tentacle sweeps under them and the wind throws them up."},
		{"input": "L L H", "kind": "move", "id": "IP", "note": "Plants the spear. Frost spreads out from it and slows whoever's on it."},
		{"input": "L L L H", "kind": "move", "id": "EM", "note": "The arm swells into a fist and shoves them along a line of lava. Punch a group into a wall: the wall hits hard (x2.5), and sets up Meteor Fall."},
	]},
	{"group": 3, "rows": [
		{"input": "L H H", "kind": "move", "id": "EE", "note": "A tentacle on each of them, with lightning running through. The window has two endings."},
		{"input": "L H H, H in the window", "kind": "text", "name": "Grounded", "tier": 3, "note": "Everyone slammed down, with lightning under each. Best when the tentacles hold the crowd."},
		{"input": "L H H, L in the window", "kind": "text", "name": "Short Circuit", "or": true, "tier": 3, "note": "The charge in the held arcs out to everyone they didn't hold, and charges them. Best when the room is full past the tentacles' reach."},
		{"input": "L L H L H", "kind": "move", "id": "IS", "note": "Slams down onto the spear: it explodes and everyone on the frost freezes into a cube."},
		{"input": "L L H L H, H in the window", "kind": "text", "name": "Avalanche", "tier": 3, "note": "The tentacles pick up every cube and slam them all together in the middle."},
		{"input": "L L L H H", "kind": "move", "id": "EV", "note": "Tendrils drag them waist-deep into lava, stuck and burning, however far the palm sent them."},
		{"input": "L L L H H, H in the window", "kind": "text", "name": "Meteor Fall", "tier": 3, "note": "He dive-bombs the biggest group in reach as a meteor, and everyone in the blast takes it. The group Molten Palm just splatted on a wall counts more, and takes x1.3. Big ones take it worst; shields come off for good."},
		{"input": "L L L H H, L in the window", "kind": "text", "name": "Meteor Shower", "or": true, "tier": 3, "note": "He stays where he is and calls a fireball down out of the sky on every foe the palm hit, wherever it went, and leaves them burning. Best when the palm scattered them; Meteor Fall is for the pile at the wall."},
	]},
	{"group": 4, "rows": [
		{"input": "L H L H", "kind": "move", "id": "EW", "note": "Live Wire from the air. The window has two endings."},
		{"input": "L H L H, H in the window", "kind": "text", "name": "Worldbreaker", "tier": 3, "note": "Slammed into the floor, with magma erupting under each."},
		{"input": "L H L H, L in the window", "kind": "text", "name": "Cold Front", "or": true, "tier": 3, "note": "Frozen solid and hurled at the others as ice cubes."},
	]},
	{"group": 5, "rows": [
		{"input": "H L", "kind": "move", "id": "VR", "note": "A crescent of darkness through everyone in front of him. It marks them."},
		{"input": "H H", "kind": "move", "id": "VS", "note": "Heaves what it holds overhead and slams it: a black hole tears open there and drags foes in."},
		{"input": "H H, H in the window", "kind": "text", "name": "Collapse", "tier": 3, "note": "He comes down at the hole. It falls in on itself and throws everyone clear, hard."},
		{"input": "H L H", "kind": "move", "id": "VD", "note": "A pool opens ahead, and everyone marked is dragged across the floor into it, however far off."},
		{"input": "H L H, H in the window", "kind": "text", "name": "Maw", "tier": 3, "note": "Jaws of darkness come up out of the pool and shut on them."},
		{"input": "H L H, L in the window", "kind": "text", "name": "Black Ice", "or": true, "tier": 3, "note": "Dark into ice: the pool freezes over with them in it, and he lands and shatters it."},
		{"input": "hold H", "kind": "move", "id": "OW", "note": "A black pool under what he's aiming at, with tendrils piling on. Works on big foes."},
		{"input": "hold H, H in the window", "kind": "text", "name": "Abyss", "tier": 3, "note": "They sink through the floor, then black spikes throw them back up."},
		{"input": "hold H, L in the window", "kind": "text", "name": "Uproot", "or": true, "tier": 3, "note": "The tentacle tears the pillar the bracket marks out of the floor and clubs the pinned foe with it, and everyone on the line it falls along. The pillar is rubble after. Best on a big foe by a pillar; in the open it is a short slam and Abyss is better."},
	]},
	{"group": 6, "rows": [
		{"input": "Dash L", "kind": "move", "id": "DL", "note": "Spear: a lunge off a dash, or off a swing."},
		{"input": "Dash H", "kind": "move", "id": "TW", "note": "Latches onto whoever he just passed and yanks them into each other."},
	]},
	{"group": 7, "rows": [
		{"input": "Dash L H", "kind": "move", "id": "EF", "note": "A tentacle grabs everyone near him, all round, and sets them down frozen in a row in front of him. Pause, and he leaps over the row: the window has two endings."},
		{"input": "Dash L H (pause), H in the window", "kind": "text", "name": "Shatterstorm", "tier": 3, "note": "Thunder crashes down on every cube where it stands and shatters it. Good damage anywhere."},
		{"input": "Dash L H (pause), L in the window", "kind": "text", "name": "Slapshot", "or": true, "tier": 3, "note": "A molten fist punches the row: the cubes slide along the floor. One that hits a wall shatters on it for the most damage in the kit; one that doesn't slides to a stop for a little. Aim the row at a wall."},
		{"input": "L L H, Dash H H", "kind": "move", "id": "XK", "note": "Dark into ice: the tentacles throw Tow Line's bunch onto the spear and they freeze round it. Without the spear first it plants one."},
		{"input": "Dash H H (pause), H in the window", "kind": "text", "name": "Anvil", "tier": 3, "note": "The hammer drives the kebab into the floor, a crater each."},
		{"input": "Dash H H (pause), L in the window", "kind": "text", "name": "Pinwheel", "or": true, "tier": 3, "note": "The quick way to Pinwheel: the bracket marks the wall or pillar it hurls them into; put the cursor on another to pick it."},
	]},
	{"group": 8, "rows": [
		{"input": "L H L L H", "kind": "move", "id": "XF", "note": "Earth into storm: cracks run to each of them and the gale comes up out of them, throwing the buried hardest."},
		{"input": "L H L L H, H in the window", "kind": "text", "name": "Cataclysm", "tier": 3, "note": "Lightning through them in the hang, then down into the floor, a strike and the earth under each."},
		{"input": "L H L L H, L in the window", "kind": "text", "name": "Tempest", "or": true, "tier": 3, "note": "A twister goes up where they land and takes everyone near up it; lightning blasts each one out, harder the more it holds. Four or more: Tempest; a few: Cataclysm."},
		{"input": "Dash L H H L", "kind": "move", "id": "XS", "note": "Ice into magma: the molten fist goes into the ice and every frozen foe goes off in steam, scalding the rest."},
		{"input": "Dash L H H L, H in the window", "kind": "text", "name": "Flash Freeze", "tier": 3, "note": "The steam freezes on them as he dives, and the landing shatters it again."},
		{"input": "H L L", "kind": "move", "id": "XC", "note": "Dark into storm: a tentacle whips out to everyone near (Reap's marked from further, and harder), the charge holds, then one bolt down them all zaps every one at once. Best on a spread-out crowd (Black Tide pulls them together instead); the more it links, the harder each zap."},
		{"input": "L L L H L", "kind": "move", "id": "XL", "note": "Magma into dark: a tentacle to everyone the palm hit, wherever it sent them, and each is dragged back through the lava into a pile at his feet, where the seam erupts. The further they were, the harder it hits, torn off a wall hardest. Best when the palm scattered them and splatted one on a wall (Galvanize wants a spread crowd round him; Black Tide marked foes anywhere)."},
		{"input": "L L L H L, H in the window", "kind": "text", "name": "Hellseam", "tier": 3, "note": "He dives on the pile and the seam goes up its whole length, back out along every drag: the pile is driven into the floor, each harder the further it was dragged, and anyone standing on a seam is caught."},
		{"input": "Dash L H H H", "kind": "move", "id": "XG", "note": "Ice into storm: a whirlwind carries every frozen foe up, still in its ice, and he climbs after them."},
		{"input": "Dash L H H H L", "kind": "move", "id": "XM", "note": "Storm into magma, in the air: the molten hammer bursts the ice off them and brings them down burning."},
		{"input": "Dash L H H H L, H in the window", "kind": "text", "name": "Eruption", "tier": 3, "note": "The floor goes up under each of them, the burning hardest."},
		{"input": "L L H, Dash H H L", "kind": "move", "id": "XW", "note": "Ice into storm: the gale blows the spear apart and hauls the frozen kebab back up to him."},
		{"input": "L L H, Dash H H L, H in the window", "kind": "text", "name": "Anvil", "tier": 3, "note": "The hammer drives the lot into the floor, a crater each."},
		{"input": "L L H, Dash H H L, L in the window", "kind": "text", "name": "Pinwheel", "or": true, "tier": 3, "note": "The tentacles whirl the kebab round him in a twister and hurl it into the nearest wall or pillar: a hard splat each. In the open they just fly; Anvil is better there."},
	]},
	{"group": 9, "rows": [
		# The dash counter (kit slot 9, counter.gd): Space as a strike is about to land, aimed at the attacker.
		{"input": "Dash into a strike", "kind": "text", "name": "Backlash", "tier": 2, "note": "Dash at a foe in the last moment of its swing (its ring nearly full): the tentacle catches the weapon, marks it, swings it up and slams it down. A shot is batted back."},
		{"input": "Dash into a strike (last instant), H in the window", "kind": "text", "name": "Ricochet", "tier": 3, "note": "A perfect counter leaps with the tentacle on the attacker: it is hurled into the nearest foe or wall, splats and is held there. Best by a wall or a crowd."},
	]},
	{"group": 10, "rows": [
		{"input": "Q", "kind": "text", "name": "Awaken", "tier": 2, "note": "With the meter full: damage, armour, the gold rim and the charged axe. The same inputs."},
	]},
	{"title": "ROUTE STEPS", "hint": "Not slots: the hits that walk from a mid to a big move or a crossover.", "rows": [
		{"input": "H", "kind": "text", "name": "Grab", "note": "Yanks a foe to him. Something too big drags him to it instead. Whips on a miss."},
		{"input": "L H L", "kind": "move", "id": "AL1", "note": "Up after them with the axe."},
		{"input": "L L H L", "kind": "move", "id": "IJ", "note": "Vaults up over the spear, any time while it stands. Right click does too."},
		{"input": "L H L L", "kind": "move", "id": "XR", "note": "Storm into earth: the hammer comes down off the air slash and drives everyone into the floor together. Double on those the gale had up."},
		{"input": "Dash L H H", "kind": "move", "id": "EA", "note": "Freezes the nearest and bowls it. Everyone it passes freezes too."},
		{"input": "R", "kind": "text", "name": "Swing", "note": "Swings him the way he's aiming, round a pillar if there's one there. Hold R to go further; letting go flings him."},
		{"input": "R, then H", "kind": "text", "name": "Snatch", "note": "Grabs a foe on the way past, carries it, and it flies on when he lets go."},
	]},
	# Demoted from the base kit (kit-grammar.md section 5): playable with their Kit upgrade on (--kit=full or --kit=<id>),
	# else the panel draws them as "upgrade" rows and void_route() goes past them (KitSlots.open).
	{"title": "UPGRADES", "hint": "Out of the base kit: unlocks (--kit=full plays them now).", "rows": [
		{"input": "Dash H L", "kind": "move", "id": "XT", "note": "Dark into storm: the axe hurls whoever Tow Line bunched, lightning jumping off them at everyone they pass."},
	]},
	# The element matrix (round 49, kit grammar section 3; void_element.RULES / IMPROV_UPGRADE, element-matrix.md): one
	# payoff rule per state, which any element's hit pays, then the upgrade cells that play in a rule's place when their
	# Kit id is on. storm = L H / L H H, ice = L L H / Dash L H / Dash L H H, magma = L L L H / L L L H H, dark = H L /
	# H L H / H H / hold H / Dash H. `state` (and `el` for an upgrade cell) name it: mix_name() is the upgrade cells'
	# name, void_element.improv_name() the combo guide's "+ name" tag.
	{"title": "MIX ELEMENTS", "hint": "States last 2 s: dash out, and another element pays its rule.", "rows": [
		{"input": "frozen, then not ice", "kind": "text", "state": "frozen", "rule": true, "name": "Shatter", "tier": 1, "note": "The hit shatters the ice for x1.6, and the ice is gone. Ice on ice freezes again; Molten Palm goes off as Steam Burst instead."},
		{"input": "charged, then not storm", "kind": "text", "state": "charged", "rule": true, "name": "Arc", "tier": 1, "note": "The hit arcs on to every other charged foe near it, and discharges them. Storm on charged is Live Wire's own pulse."},
		{"input": "molten, then not magma", "kind": "text", "state": "molten", "rule": true, "name": "Burst", "tier": 1, "note": "It goes off x1.5, and the burn catches everyone beside it. Magma on molten is Eruption's."},
		{"input": "held, then not dark", "kind": "text", "state": "bound", "rule": true, "name": "Snap", "tier": 1, "note": "A x1.5 hit nothing can block, and the hold ends with a snap. Dark on the held is Abyss off Overwhelm."},
		{"input": "in the air, then any", "kind": "text", "state": "airborne", "rule": true, "name": "Juggle", "tier": 1, "note": "The hit keeps them up there. Storm's own air string and Tow Line's rip pay it themselves."},
		{"input": "buried, then any", "kind": "text", "state": "buried", "rule": true, "name": "Crater", "tier": 1, "note": "Driven back into the floor x1.5. Updraft Lash digs them up itself."},
		{"input": "frozen, then storm", "kind": "text", "state": "frozen", "el": "wind", "upgrade": "gale_lift", "name": "Gale Lift", "tier": 1, "note": "Upgrade: The gale takes the cube up, still in its ice."},
		{"input": "frozen, then dark", "kind": "text", "state": "frozen", "el": "void", "upgrade": "shard_cut", "name": "Shard Cut", "tier": 1, "note": "Upgrade: The dark crushes the ice, and the shards cut the one beside it."},
		{"input": "buried, then ice", "kind": "text", "state": "buried", "el": "water", "upgrade": "frozen_in", "name": "Frozen In", "tier": 1, "note": "Upgrade: Frozen where Rockslide stuck them in the floor."},
		{"input": "buried, then dark", "kind": "text", "state": "buried", "el": "void", "upgrade": "swallowed", "name": "Swallowed", "tier": 1, "note": "Upgrade: The dark drags them under and holds them there a moment."},
		{"input": "molten, then storm", "kind": "text", "state": "molten", "el": "wind", "upgrade": "firestorm", "name": "Firestorm", "tier": 1, "note": "Upgrade: The gale fans the flames up, and onto the one beside it."},
		{"input": "molten, then ice", "kind": "text", "state": "molten", "el": "water", "upgrade": "quench", "name": "Quench", "tier": 1, "note": "Upgrade: Water on the burning: it goes off in steam and up."},
		{"input": "molten, then magma", "kind": "text", "state": "molten", "el": "earth", "upgrade": "flare_up", "name": "Flare-up", "tier": 1, "note": "Upgrade: The floor erupts under the burning."},
		{"input": "molten, then dark", "kind": "text", "state": "molten", "el": "void", "upgrade": "smother", "name": "Smother", "tier": 1, "note": "Upgrade: The dark puts the fire out by driving them into the floor."},
		{"input": "skewered, then ice", "kind": "text", "state": "skewered", "el": "water", "upgrade": "ice_spreads", "name": "Ice Spreads", "tier": 1, "note": "Upgrade: The spear's ice climbs onto the nearest foe and skewers it too."},
		{"input": "skewered, then dark", "kind": "text", "state": "skewered", "el": "void", "upgrade": "torn_off", "name": "Torn Off", "tier": 1, "note": "Upgrade: Ripped off the spear towards him."},
		{"input": "in the air, then ice", "kind": "text", "state": "airborne", "el": "water", "upgrade": "freeze_aloft", "name": "Freeze Aloft", "tier": 1, "note": "Upgrade: Frozen up there: it comes down a cube."},
		{"input": "in the air, then magma", "kind": "text", "state": "airborne", "el": "earth", "upgrade": "meteor_spike", "name": "Meteor Spike", "tier": 1, "note": "Upgrade: Driven down out of the air into a crater."},
		{"input": "held by tendrils, then storm", "kind": "text", "state": "bound", "el": "wind", "upgrade": "torn_loose", "name": "Torn Loose", "tier": 1, "note": "Upgrade: The gale tears them out of Undertow or Overwhelm and up."},
		{"input": "held by tendrils, then ice", "kind": "text", "state": "bound", "el": "water", "upgrade": "frozen_dark", "name": "Frozen in the Dark", "tier": 1, "note": "Upgrade: Frozen solid where the tendrils hold them."},
		{"input": "charged, then storm", "kind": "text", "state": "charged", "el": "wind", "upgrade": "overload", "name": "Overload", "tier": 1, "note": "Upgrade: Every charged foe near goes off at once, each zap harder the more are charged."},
		{"input": "charged, then ice", "kind": "text", "state": "charged", "el": "water", "upgrade": "superconduct", "name": "Superconduct", "tier": 1, "note": "Upgrade: Frozen, and the charge runs through every frozen foe near it."},
		{"input": "charged, then magma", "kind": "text", "state": "charged", "el": "earth", "upgrade": "arc_flash", "name": "Arc Flash", "tier": 1, "note": "Upgrade: The charge goes off and blows the ones beside it away, splatting them on a wall."},
		{"input": "charged, then dark", "kind": "text", "state": "charged", "el": "void", "upgrade": "conduct", "name": "Conduct", "tier": 1, "note": "Upgrade: The dark carries the charge on to everyone near it not charged yet."},
	]},
]


## A section's heading and hint: a slot group's "N  NAME" and role line, else its own title / hint.
static func heading(section: Dictionary) -> Array:
	if section.has("group"):
		var g: Dictionary = KitSlots.group(section.group)
		return ["%d  %s" % [g.n, g.name.to_upper()], g.role]
	return [section.title, section.get("hint", "")]


## The slots of a group that the card hasn't filled yet (their lanes add the move): [slot name, role] each.
static func pending_slots(section: Dictionary, card: Dictionary = KitSlots.HERETIC) -> Array:
	var out := []
	for s: Dictionary in KitSlots.SLOTS:
		if s.group == section.get("group", -1) and KitSlots.pending(card, s.id):
			out.append([s.name, s.role])
	return out


## The Kit upgrade a row is behind ("" when none): its own `upgrade`, or its move's when that gates the route.
static func row_upgrade(row: Dictionary) -> String:
	if row.has("upgrade"):
		return row.upgrade
	if row.kind != "move":
		return ""
	var u := KitSlots.upgrade_of(row.id)  # (a "payoff" gate leaves the move itself playable: Rockslide)
	return u if u != "" and KitSlots.HERETIC.upgrades[u].gates == "route" else ""


## Whether the row is an upgrade that is off right now (Kit.has): the panel dims it and adds "upgrade".
static func row_locked(row: Dictionary) -> bool:
	var u := row_upgrade(row)
	return u != "" and not Kit.has(u)


## The row's slot tag for the panel (KitSlots.tag_of: "launch", "payoff", "step"...), "" on a text row.
static func row_tag(row: Dictionary) -> String:
	return KitSlots.tag_of(row.id) if row.kind == "move" else ""


## The MIX ELEMENTS row's name for a state x element cell ("" if none): the combo guide's payoff tag.
static func mix_name(state: String, el: String) -> String:
	for section: Dictionary in SECTIONS:
		for row: Dictionary in section.rows:
			if row.get("state", "") == state and row.get("el", "") == el:
				return row.name
	return ""


## What the row is called.
static func row_name(row: Dictionary, player: Node) -> String:
	if row.kind == "move":
		return player.HERO_MOVES.guide_name(row.id)
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
