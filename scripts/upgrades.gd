class_name Upgrades
## Combo-slot upgrades: each one hooks a specific move in the hero's string
## (L1/L2/L3 light chain, H spin, LH launcher, DL dash stab) or a mechanic
## (Dash, Air, Awaken, Perfect dodge, Death, Kill).
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
]


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
