class_name Upgrades
## Combo-slot upgrades: each one hooks a specific move in the hero's string
## (L1/L2/L3 light chain, H spin, LH launcher, LLH ground breaker, DL dash
## stab, Charged slam) or
## a mechanic (Dash, Air, Awaken, Perfect dodge, Death, Kill).
## Pure data here; the effects live in player.gd (search for the id).
##
##   id      key used in code          slot  which move/mechanic it modifies
##   name    card title                desc  card text; {key} shows lv[key]
##   lv      tuning numbers per level: [level 1, level 2, level 3]
##
## Reward cards offer new upgrades and level-ups of owned ones (up to
## MAX_LEVEL); player.gd reads the current level's numbers with upg().

const MAX_LEVEL := 3

const ALL := [
	{"id": "ember_cleave", "name": "Ember Cleave", "slot": "L3",
		"desc": "Your 3rd light hit sends a wave of fire rolling forward ({damage} damage).",
		"lv": {"damage": [10, 16, 24]}},
	{"id": "static_step", "name": "Static Step", "slot": "Dash",
		"desc": "Dash-cancelling an attack leaves a lightning trap that bursts a moment later ({damage} damage).",
		"lv": {"damage": [12, 18, 26]}},
	{"id": "chain_spark", "name": "Chain Spark", "slot": "Air",
		"desc": "Hitting a juggled enemy arcs lightning to {targets} nearby foes.",
		"lv": {"targets": [2, 3, 4], "damage": [6, 8, 10]}},
	{"id": "whirlwind", "name": "Whirlwind", "slot": "H",
		"desc": "Your spin hits {hits} times and reaches further.",
		"lv": {"hits": [5, 6, 7], "reach": [1.0, 1.4, 1.8]}},
	{"id": "skybreaker", "name": "Skybreaker", "slot": "LH",
		"desc": "Your launcher sends out a shockwave that launches everyone within {radius}m.",
		"lv": {"radius": [4, 5.5, 7]}},
	{"id": "bloodthirst", "name": "Bloodthirst", "slot": "L1",
		"desc": "Your opening light hit heals {heal} HP per enemy struck.",
		"lv": {"heal": [2, 3, 4]}},
	{"id": "momentum", "name": "Momentum", "slot": "DL",
		"desc": "Your dash stab deals +{bonus}% damage and reaches much further.",
		"lv": {"bonus": [60, 100, 140]}},
	{"id": "overflow", "name": "Overflow", "slot": "Awaken",
		"desc": "Gain Awakening {bonus}% faster.",
		"lv": {"bonus": [35, 60, 85]}},
	{"id": "rising_edge", "name": "Rising Edge", "slot": "L2",
		"desc": "Your 2nd light hit pops enemies {launch}m/s into the air for a juggle.",
		"lv": {"launch": [6, 7.5, 9]}},
	{"id": "riposte", "name": "Riposte", "slot": "Perfect",
		"desc": "A perfect dodge releases a shockwave that launches nearby enemies ({damage} damage).",
		"lv": {"damage": [20, 30, 42], "radius": [3.5, 4.5, 5.5]}},
	{"id": "long_night", "name": "Long Night", "slot": "Awaken",
		"desc": "Awakening lasts {bonus}% longer.",
		"lv": {"bonus": [50, 80, 110]}},
	{"id": "phoenix_heart", "name": "Phoenix Heart", "slot": "Awaken",
		"desc": "Activating Awakening heals {heal} HP.",
		"lv": {"heal": [25, 40, 55]}},
	{"id": "second_wind", "name": "Second Wind", "slot": "Death",
		"desc": "Once per run, survive a killing blow with {hp}% HP.",
		"lv": {"hp": [30, 45, 60]}},
	{"id": "reaper", "name": "Reaper", "slot": "Kill",
		"desc": "Each kill heals {heal} HP and grants {awaken} Awakening.",
		"lv": {"heal": [3, 5, 7], "awaken": [4, 6, 8]}},
	{"id": "fault_line", "name": "Fault Line", "slot": "LLH",
		"desc": "Your ground breaker leaves a fault line that erupts {delay}s later, launching everything on it ({damage} damage).",
		"lv": {"damage": [14, 22, 32], "delay": [0.6, 0.5, 0.4]}},
	{"id": "quake", "name": "Quake", "slot": "Charged",
		"desc": "Your charged slam sends out a shockwave: {damage} damage and a launch to everyone within {radius}m.",
		"lv": {"damage": [12, 18, 26], "radius": [5, 6, 7.5]}},
	{"id": "bone_breaker", "name": "Bone Breaker", "slot": "Charged",
		"desc": "Your charged slam deals +{bonus}% damage to shielded skeletons, elites and bosses.",
		"lv": {"bonus": [80, 130, 200]}},
]


## Synergies: own SYNERGY_NEED of a tag's `ids` and every one of them gets
## its `boost` (a multiplier on those lv keys, applied in player.upg()).
## A power can carry more than one tag.
const SYNERGY_NEED := 2
const SYNERGIES := {
	"storm": {"name": "Storm", "ids": ["static_step", "chain_spark"],
		"desc": "lightning powers deal +35% damage", "boost": {"damage": 1.35}},
	"tremor": {"name": "Tremor", "ids": ["skybreaker", "riposte", "fault_line", "quake"],
		"desc": "shockwaves hit 25% harder and reach 15% further", "boost": {"damage": 1.25, "radius": 1.15}},
	"ember": {"name": "Ember", "ids": ["ember_cleave", "phoenix_heart"],
		"desc": "fire powers deal +30% damage and heal +30%", "boost": {"damage": 1.3, "heal": 1.3}},
	"blood": {"name": "Blood", "ids": ["bloodthirst", "reaper", "second_wind", "phoenix_heart"],
		"desc": "healing powers heal +30%", "boost": {"heal": 1.3, "hp": 1.2}},
	"night": {"name": "Night", "ids": ["overflow", "long_night", "phoenix_heart"],
		"desc": "Awakening powers are 25% stronger", "boost": {"bonus": 1.25}},
}


## Synergy ids active for `owned` (id -> level).
static func active_synergies(owned: Dictionary) -> Array:
	var active: Array = []
	for tag: String in SYNERGIES:
		var n := 0
		for id: String in SYNERGIES[tag].ids:
			if owned.has(id):
				n += 1
		if n >= SYNERGY_NEED:
			active.append(tag)
	return active


## Multiplier on upgrade `id`'s lv `key` from the synergies `active`.
static func boost(active: Array, id: String, key: String) -> float:
	var mult := 1.0
	for tag: String in active:
		if id in SYNERGIES[tag].ids:
			mult *= SYNERGIES[tag].boost.get(key, 1.0)
	return mult


## Synergy names upgrade `id` belongs to ("Storm", "Blood · Ember"...).
static func tags(id: String) -> String:
	var names: Array = []
	for tag: String in SYNERGIES:
		if id in SYNERGIES[tag].ids:
			names.append(SYNERGIES[tag].name)
	return " · ".join(names)


static func get_by_id(id: String) -> Dictionary:
	for u in ALL:
		if u.id == id:
			return u
	return {}


## Tuning number `key` of upgrade `id` at `level` (1-based).
static func value(id: String, key: String, level: int) -> float:
	var values: Array = get_by_id(id).lv[key]
	return values[clampi(level, 1, values.size()) - 1]


## Card text with the numbers for `level` filled in.
static func describe(u: Dictionary, level: int) -> String:
	var nums := {}
	for key in u.lv:
		var v := value(u.id, key, level)
		nums[key] = int(v) if v == floorf(v) else v  # "10", not "10.0"
	return u.desc.format(nums)


## " II", " III" after a name for levels above 1.
static func level_tag(level: int) -> String:
	return ["", "", " II", " III", " IV", " V"][clampi(level, 0, 5)]


## Up to `count` random cards: upgrades the player doesn't own yet and
## level-ups of owned ones below MAX_LEVEL. `owned` maps id -> level.
## Each card is the upgrade's entry plus "level" (the level it grants).
## `level_ups_only` limits it to owned upgrades (the camp's "hone").
static func roll(owned: Dictionary, count := 3, level_ups_only := false) -> Array:
	var pool: Array = []
	for u in ALL:
		var level: int = owned.get(u.id, 0)
		if level < MAX_LEVEL and (level > 0 or not level_ups_only):
			var card: Dictionary = u.duplicate()
			card.level = level + 1
			pool.append(card)
	pool.shuffle()
	return pool.slice(0, count)
