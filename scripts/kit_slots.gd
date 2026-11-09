class_name KitSlots
## The kit grammar's slot table as data (docs/characters/kit-grammar.md sections 2 and 5; how to fill a card:
## docs/features/kit-slots.md). Every character fills the same slots with the same input shapes; the moves, elements
## and best situations are its own. `KitSlots.of()` is the heretic's card: which move id fills each slot and
## the input that starts it, its route steps (hits that walk to a crossover; not slots), and its demoted upgrades
## (still in the game behind `Kit.has()`, off the base kit).
##
## Readers: move_list.gd (the pause MOVES panel's sections are GROUPS), combo_guide.gd (the role tag, `tag_of`),
## training_bot.gd (each BOT_STRINGS entry names its slot; the autotest's `[kit]` line), tests/kit_check.gd.
## Pending slots (the sixth crossover) have an empty fill: its lane adds `"<id>": "<input>"` to it.

## The ten groups of section 2, in order: the MOVES panel's headings (`n` = the grammar's slot number).
const GROUPS := [
	{"n": 1, "name": "Light string", "role": "The hack and slash: each hit tinted by an element, in order."},
	{"n": 2, "name": "Light enders", "role": "One per element, in the string's order: each leaves its state."},
	{"n": 3, "name": "Big moves", "role": "Ender + H: the element's payoff on its own state, with a window."},
	{"n": 4, "name": "Air route", "role": "A climb after the launched foe, into the air big move."},
	{"n": 5, "name": "Signature", "role": "The tentacle: mark, gather, drag, pin. The last three have a window."},
	{"n": 6, "name": "Dash moves", "role": "A lunge and a snare off the dash."},
	{"n": 7, "name": "Dash enders", "role": "Collect a crowd in front, or pin one. Each has a window."},
	{"n": 8, "name": "Crossovers", "role": "One per colour pair: the first's state cashed by the second."},
	{"n": 9, "name": "Counter", "role": "Dash into an incoming strike; a perfect opens a counter breaker."},
	{"n": 10, "name": "Awakening", "role": "Q: the meter's stronger mode, no new inputs."},
]

## The slots. `group` is GROUPS' n; `shape` the inputs the slot allows (tests/kit_check.gd; "*" = one route step's
## press between the ender and the H, "+" = one press off a move or route step: a crossover's fixed extension);
## `tag` the one word the combo guide shows; `window` whether the grammar gives the slot a breaker window
## ("finisher": when it ends a string). `routed: false`: no press of void_route() starts it (the counter is the dash
## meeting a strike, counter.gd), so its fill is the window's BREAKERS key.
const SLOTS := [
	{"id": "light_string", "group": 1, "name": "Light string", "shape": ["L", "L L", "L L L"], "tag": "string",
		"role": "Three hits, tinted 1 / 2 / 3: the string teaches the colours.", "window": false},
	{"id": "ender_1", "group": 2, "name": "Light ender 1", "shape": ["L H"], "tag": "launch",
		"role": "Element 1's ender: the launcher.", "window": false},
	{"id": "ender_2", "group": 2, "name": "Light ender 2", "shape": ["L L H"], "tag": "plant",
		"role": "Element 2's ender: plants or slows.", "window": false},
	{"id": "ender_3", "group": 2, "name": "Light ender 3", "shape": ["L L L H"], "tag": "carry",
		"role": "Element 3's ender: carries or shoves.", "window": false},
	{"id": "big_1", "group": 3, "name": "Big move 1", "shape": ["L H H", "L H * H"], "tag": "payoff",
		"role": "Element 1 on its own state. Best on a line.", "window": true},
	{"id": "big_2", "group": 3, "name": "Big move 2", "shape": ["L L H H", "L L H * H"], "tag": "payoff",
		"role": "Element 2 on its own state. Best on a stand.", "window": true},
	{"id": "big_3", "group": 3, "name": "Big move 3", "shape": ["L L L H H", "L L L H * H"], "tag": "payoff",
		"role": "Element 3 on its own state. Best on a wall.", "window": true},
	{"id": "air_route", "group": 4, "name": "Air route", "shape": ["L H L H"], "tag": "air",
		"role": "L H L climbs after them; L H L H is the air big move.", "window": true},
	{"id": "sig_mark", "group": 5, "name": "Mark", "shape": ["H", "H L"], "tag": "mark",
		"role": "H marks what it hits.", "window": false},
	{"id": "sig_gather", "group": 5, "name": "Gather", "shape": ["H H"], "tag": "gather",
		"role": "H H is always the gather.", "window": true},
	{"id": "sig_drag", "group": 5, "name": "Drag", "shape": ["H L H"], "tag": "drag",
		"role": "H L H drags the marked to one place.", "window": true},
	{"id": "sig_pin", "group": 5, "name": "Pin", "shape": ["hold H"], "tag": "pin",
		"role": "hold H is always the single-big-target tool.", "window": true},
	{"id": "dash_l", "group": 6, "name": "Dash light", "shape": ["Dash L"], "tag": "lunge",
		"role": "The lunge off the dash.", "window": false},
	{"id": "dash_h", "group": 6, "name": "Dash heavy", "shape": ["Dash H"], "tag": "snare",
		"role": "The snare off the dash.", "window": false},
	{"id": "dash_ender_l", "group": 7, "name": "Dash ender L", "shape": ["Dash L H"], "tag": "crowd",
		"role": "Dash L H always collects a crowd in front of you.", "window": true},
	{"id": "dash_ender_h", "group": 7, "name": "Dash ender H", "shape": ["Dash H H"], "tag": "skewer",
		"role": "Dash H H always pins one.", "window": true},
	{"id": "cross_storm_magma", "group": 8, "name": "Storm x magma", "pair": ["wind", "earth"], "shape": ["+"],
		"tag": "cross", "role": "Element 1 and element 3 in one move.", "window": "finisher"},
	{"id": "cross_ice_magma", "group": 8, "name": "Ice x magma", "pair": ["water", "earth"], "shape": ["+"],
		"tag": "cross", "role": "Element 2 and element 3 in one move.", "window": "finisher"},
	{"id": "cross_dark_storm", "group": 8, "name": "Dark x storm", "pair": ["void", "wind"], "shape": ["+"],
		"tag": "cross", "role": "The signature and element 1 in one move.", "window": "finisher"},
	{"id": "cross_ice_storm", "group": 8, "name": "Ice x storm", "pair": ["water", "wind"], "shape": ["+"],
		"tag": "cross", "role": "Element 2 and element 1 in one move.", "window": "finisher"},
	{"id": "cross_dark_ice", "group": 8, "name": "Dark x ice", "pair": ["void", "water"], "shape": ["+"],
		"tag": "cross", "role": "The signature and element 2 in one move.", "window": "finisher"},
	{"id": "cross_dark_magma", "group": 8, "name": "Dark x magma", "pair": ["void", "earth"], "shape": ["+"],
		"tag": "cross", "role": "The signature and element 3 in one move.", "window": "finisher"},
	{"id": "counter", "group": 9, "name": "Counter", "shape": ["Dash into a strike"], "tag": "counter", "routed": false,
		"role": "Dash into a strike; a perfect opens the counter breaker.", "window": true},
	{"id": "awakening", "group": 10, "name": "Awakening", "shape": ["Q"], "tag": "awaken", "meter": true,
		"role": "The meter: a stronger mode, not new inputs.", "window": false},
]

## The heretic's card (kit-grammar.md section 5). `fill`: slot -> {move id: input}, in the order the MOVES panel
## lists them. Element words: wind = storm, water = ice, earth = magma, void = dark (hero_moves.ELEMENT_WORDS).
const HERETIC := {
	"name": "The heretic", "signature": "void", "elements": ["wind", "water", "earth"],
	"fill": {
		"light_string": {"L1": "L", "L2": "L L", "L3": "L L L"},
		"ender_1": {"EC": "L H"},
		"ender_2": {"IP": "L L H"},
		"ender_3": {"EM": "L L L H"},
		"big_1": {"EE": "L H H"},
		"big_2": {"IS": "L L H L H"},  # (through the vault, a route step)
		"big_3": {"EV": "L L L H H"},
		"air_route": {"EW": "L H L H"},
		"sig_mark": {"VR": "H L"},  # (the grammar's H: his H alone is the grab, a route step, and Reap is H L)
		"sig_gather": {"VS": "H H"},
		"sig_drag": {"VD": "H L H"},
		"sig_pin": {"OW": "hold H"},
		"dash_l": {"DL": "Dash L"},
		"dash_h": {"TW": "Dash H"},
		"dash_ender_l": {"EF": "Dash L H"},
		"dash_ender_h": {"XK": "Dash H H"},
		"cross_storm_magma": {"XF": "L H L L H"},
		"cross_ice_magma": {"XS": "Dash L H H L"},
		"cross_dark_storm": {"XC": "H L L"},
		"cross_ice_storm": {"XG": "Dash L H H H", "XM": "Dash L H H H L"},  # Hailstorm -> Meltdown, one route
		"cross_dark_ice": {"XW": "Dash H H L"},  # Backdraft, off Impale (Tow Line's dark onto the spear's ice)
		"cross_dark_magma": {"XL": "L L L H L"},  # Lava Leash, off Molten Palm (round 49 dark-magma)
		"counter": {"CB": "Dash into a strike"},  # Backlash; CB is its perfect's window (Ricochet), counter.gd
		"awakening": {},  # the meter (Q), no move id
	},
	## Route steps: the hits that walk from a mid to a big move or a crossover. Not slots; never an upgrade target.
	"route": {"GR": "H", "AL1": "L H L", "IJ": "L L H L", "XR": "L H L L", "EA": "Dash L H H"},
	## Demoted (section 5): in the game behind Kit.has(<id>), out of the base kit. (Rockslide's buried payoff was
	## demoted too, then put back: Fault Line's buried x2 and the buried rule, Crater, need buried in the base kit.) `moves`: id -> input; `gates`:
	## "route" = void_route() doesn't reach the move without it, "payoff" = the move stays (a route step) and its
	## own payoff is what's gated (void_element.fire).
	"upgrades": {
		"storm_pitch": {"moves": {"XT": "Dash H L"}, "gates": "route", "name": "Storm Pitch",
			"note": "Tow Line hurls the bunch, lightning off them: an upgrade to Tow Line."},
	},
}

## The card in play: the heretic is the only hero.
static func of(_hero: String = "") -> Dictionary:
	return HERETIC


static func slot(id: String) -> Dictionary:
	for s: Dictionary in SLOTS:
		if s.id == id:
			return s
	return {}


static func group(n: int) -> Dictionary:
	return GROUPS[n - 1]


## The slot a move fills on a card ("" for a route step, an upgrade or an unknown id).
static func slot_of(id: String, card: Dictionary = HERETIC) -> String:
	for s: String in card.fill:
		if card.fill[s].has(id):
			return s
	return ""


## A pending slot: in the grammar, not filled yet (its lane adds the move).
static func pending(card: Dictionary, slot_id: String) -> bool:
	return card.fill.get(slot_id, {}).is_empty() and not slot(slot_id).get("meter", false)


## The upgrade a move is behind on a card ("" when it isn't one).
static func upgrade_of(id: String, card: Dictionary = HERETIC) -> String:
	for u: String in card.upgrades:
		if card.upgrades[u].moves.has(id):
			return u
	return ""


## Whether the routing may reach `id`: false for a "route"-gated upgrade's move whose Kit upgrade is off.
static func open(id: String, card: Dictionary = HERETIC) -> bool:
	var u := upgrade_of(id, card)
	return u == "" or card.upgrades[u].gates != "route" or Kit.has(u)


## The combo guide's one word for a move: its slot's tag, "step" on a route step, "upgrade" on a gated move.
static func tag_of(id: String, card: Dictionary = HERETIC) -> String:
	var s := slot_of(id, card)
	if s != "":
		return slot(s).tag
	if card.route.has(id):
		return "step"
	return "upgrade" if upgrade_of(id, card) != "" else ""
