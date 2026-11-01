class_name Upgrades
## Combo-slot upgrades: each one hooks a specific move in the hero's string
## (L1/L2/L3 light chain, LPL flurry, H spin, LH launcher, LLH ground breaker,
## DL dash stab, DH cyclone, Charged slam, Heavy = any heavy move) or
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
	{"id": "ember_cleave", "name": "Ember Cleave", "path": "light", "slot": "L3",
		"desc": "Your 3rd light hit sends a wave of fire rolling forward ({damage} damage).",
		"lv": {"damage": [10, 16, 24]}},
	{"id": "static_step", "name": "Static Step", "path": "dash", "slot": "Dash",
		"desc": "Dash-cancelling an attack leaves a lightning trap that bursts a moment later ({damage} damage).",
		"lv": {"damage": [12, 18, 26]}},
	{"id": "chain_spark", "name": "Chain Spark", "path": "soul", "slot": "Air",
		"desc": "Hitting a juggled enemy arcs lightning to {targets} nearby foes.",
		"lv": {"targets": [2, 3, 4], "damage": [6, 8, 10]}},
	{"id": "whirlwind", "name": "Whirlwind", "path": "heavy", "slot": "H",
		"desc": "Your spin hits {hits} times and reaches further.",
		"lv": {"hits": [5, 6, 7], "reach": [1.0, 1.4, 1.8]}},
	{"id": "skybreaker", "name": "Skybreaker", "path": "heavy", "slot": "LH",
		"desc": "Your launcher sends out a shockwave that launches everyone within {radius}m.",
		"lv": {"radius": [4, 5.5, 7]}},
	{"id": "bloodthirst", "name": "Bloodthirst", "path": "light", "slot": "L1",
		"desc": "Your opening light hit heals {heal} HP per enemy struck.",
		"lv": {"heal": [2, 3, 4]}},
	{"id": "momentum", "name": "Momentum", "path": "dash", "slot": "DL",
		"desc": "Your dash stab deals +{bonus}% damage and reaches much further.",
		"lv": {"bonus": [60, 100, 140]}},
	{"id": "overflow", "name": "Overflow", "path": "awaken", "slot": "Awaken",
		"desc": "Gain Awakening {bonus}% faster.",
		"lv": {"bonus": [35, 60, 85]}},
	{"id": "rising_edge", "name": "Rising Edge", "path": "light", "slot": "L2",
		"desc": "Your 2nd light hit pops enemies {launch}m/s into the air for a juggle.",
		"lv": {"launch": [6, 7.5, 9]}},
	{"id": "riposte", "name": "Riposte", "path": "dash", "slot": "Perfect",
		"desc": "A perfect dodge releases a shockwave that launches nearby enemies ({damage} damage).",
		"lv": {"damage": [20, 30, 42], "radius": [3.5, 4.5, 5.5]}},
	{"id": "phoenix_heart", "name": "Phoenix Heart", "path": "awaken", "slot": "Awaken",
		"desc": "Activating Awakening heals {heal} HP.",
		"lv": {"heal": [25, 40, 55]}},
	{"id": "second_wind", "name": "Second Wind", "path": "soul", "slot": "Death",
		"desc": "Once per run, survive a killing blow with {hp}% HP.",
		"lv": {"hp": [30, 45, 60]}},
	{"id": "reaper", "name": "Reaper", "path": "soul", "slot": "Kill",
		"desc": "Each kill heals {heal} HP and grants {awaken} Awakening.",
		"lv": {"heal": [3, 5, 7], "awaken": [4, 6, 8]}},
	{"id": "fault_line", "name": "Fault Line", "path": "heavy", "slot": "LLH",
		"desc": "Your ground breaker leaves a fault line that erupts {delay}s later, launching everything on it ({damage} damage).",
		"lv": {"damage": [14, 22, 32], "delay": [0.6, 0.5, 0.4]}},
	{"id": "quake", "name": "Quake", "path": "heavy", "slot": "Charged",
		"desc": "Your charged slam sends out a shockwave: {damage} damage and a launch to everyone within {radius}m.",
		"lv": {"damage": [12, 18, 26], "radius": [5, 6, 7.5]}},
	{"id": "bone_breaker", "name": "Bone Breaker", "path": "heavy", "slot": "Charged",
		"desc": "Your charged slam deals +{bonus}% damage to shielded skeletons, elites and bosses.",
		"lv": {"bonus": [80, 130, 200]}},
	{"id": "shatter", "name": "Shatter", "path": "heavy", "slot": "Heavy",
		"desc": "A heavy hit that kills a foe bursts it into bone shards: {damage} damage to everyone within {radius}m.",
		"lv": {"damage": [10, 16, 24], "radius": [3, 3.5, 4]}},
	{"id": "quickblade", "name": "Quickblade", "path": "light", "slot": "Light",
		"desc": "Your light attacks swing {speed}% faster.",
		"lv": {"speed": [15, 25, 35]}},
	{"id": "thousand_cuts", "name": "Thousand Cuts", "path": "light", "slot": "Light",
		"desc": "Every {hits} light hits on the same foe rend it for {damage} damage.",
		"lv": {"hits": [4, 4, 3], "damage": [12, 18, 24]}},
	{"id": "eruption", "name": "Eruption", "path": "awaken", "slot": "Awaken",
		"desc": "Awakening erupts: the burst deals {damage} damage and reaches {radius}m.",
		"lv": {"damage": [25, 40, 60], "radius": [8, 9, 10]}},
	{"id": "slipstream", "name": "Slipstream", "path": "dash", "slot": "Dash",
		"desc": "Dashing through enemies cuts them for {damage} damage.",
		"lv": {"damage": [8, 12, 17]}},
	{"id": "razor_gale", "name": "Razor Gale", "path": "light", "slot": "LPL",
		"desc": "Flurry's last cut flings a fan of {count} blades ({damage} damage each).",
		"lv": {"count": [3, 4, 5], "damage": [6, 8, 11]}},
	{"id": "eye_of_storm", "name": "Eye of the Storm", "path": "dash", "slot": "DH",
		"desc": "Each Cyclone hit drags foes within {radius}m into the spin.",
		"lv": {"radius": [5, 6, 7.5], "damage": [2, 3, 4]}},
	{"id": "rebound", "name": "Rebound", "path": "soul", "slot": "LHH",
		"desc": "Foes you Spike bounce back up {launch}m/s off the floor for another juggle ({damage} damage).",
		"lv": {"launch": [7, 8.5, 10], "damage": [6, 9, 13]}},
	# Fusions: two paths in one card. Offered only once you own a power of
	# both (`fusion` is the second path); they count toward both masteries.
	{"id": "crescendo", "name": "Crescendo", "path": "light", "fusion": "heavy", "slot": "L3 → Heavy",
		"desc": "Landing your 3rd light hit empowers your next heavy attack: +{bonus}% damage and a bigger knockback.",
		"lv": {"bonus": [50, 75, 100]}},
	{"id": "flicker", "name": "Flicker", "path": "light", "fusion": "dash",
		"slot": "Dash → Light", "desc": "For {time}s after a dash, your light hits deal +{bonus}% damage.",
		"lv": {"time": [1.0, 1.2, 1.5], "bonus": [40, 60, 80]}},
	{"id": "shockstep", "name": "Shockstep", "path": "heavy", "fusion": "dash", "slot": "Heavy → Dash",
		"desc": "Dash-cancelling a heavy attack leaves a shockwave behind: {damage} damage and a launch within {radius}m.",
		"lv": {"damage": [14, 20, 28], "radius": [3, 3.5, 4]}},
	{"id": "undying_flame", "name": "Undying Flame", "path": "awaken", "fusion": "soul", "slot": "Awakened kills",
		"desc": "While Awakened, each kill extends it by {time}s and heals {heal} HP.",
		"lv": {"time": [0.5, 0.75, 1.0], "heal": [2, 3, 4]}},
]


## Paths: each power belongs to the input it upgrades and wears that path's
## colour everywhere (cards, build view, HUD, combo guide keys). Own
## MASTERY_NEED powers of one path (fusions count for both of theirs) and its
## mastery switches on; the numbers live in `mastery`, effects in player.gd.
const MASTERY_NEED := 3
const PATHS := {
	"light": {"name": "Light", "key": "LMB", "color": Color(0.35, 0.62, 1.0),
		"mastery": {"desc": "light attacks deal +{damage}% damage", "damage": 15}},
	"heavy": {"name": "Heavy", "key": "RMB", "color": Color(1.0, 0.78, 0.2),
		"mastery": {"desc": "heavy attacks deal +{damage}% damage", "damage": 15}},
	"dash": {"name": "Dash", "key": "SPACE", "color": Color(0.35, 0.88, 0.45),
		"mastery": {"desc": "dashes recover {cooldown}% faster and the Dash Stab deals +{damage}% damage", "cooldown": 40, "damage": 25}},
	"awaken": {"name": "Awaken", "key": "Q", "color": Color(0.72, 0.48, 1.0),
		"mastery": {"desc": "Awakening lasts {time}s longer", "time": 2}},
	"soul": {"name": "Soul", "key": "", "color": Color(1.0, 0.42, 0.52),
		"mastery": {"desc": "+{hp} max HP", "hp": 20}},
}
## Chance a reward offer swaps its last card for an eligible fusion.
const FUSION_CHANCE := 0.5
## Readable names for `slot` on cards and the build view (fusions spell
## theirs out in the entry itself).
const SLOT_NAMES := {"L1": "1st light hit", "L2": "2nd light hit", "L3": "Triple Chop", "LPL": "Flurry", "DH": "Cyclone", "LHH": "Spike", "Light": "Light attacks",
	"H": "Spin", "LH": "Launcher", "LLH": "Ground Breaker", "Charged": "Charged Slam", "Heavy": "Heavy kills",
	"Dash": "Dash", "DL": "Dash Stab", "Perfect": "Perfect dodge", "Awaken": "Awakening",
	"Air": "Juggles", "Death": "Killing blow", "Kill": "Kills"}


static func slot_name(u: Dictionary) -> String:
	return SLOT_NAMES.get(u.slot, u.slot)


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
	"night": {"name": "Night", "ids": ["overflow", "phoenix_heart"],
		"desc": "Awakening powers are 25% stronger", "boost": {"bonus": 1.25}},
	"bone": {"name": "Bone", "ids": ["shatter", "bone_breaker"],
		"desc": "bone powers hit 30% harder and shatter 20% wider", "boost": {"damage": 1.3, "bonus": 1.3, "radius": 1.2}},
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


## Card text with the numbers for `level` filled in. With `active`
## synergies, boosted numbers read "base → boosted". `bb` (a colour) wraps
## each number in BBCode bold + that colour, for RichTextLabels.
static func describe(u: Dictionary, level: int, active: Array = [], bb := Color(0, 0, 0, 0)) -> String:
	var nums := {}
	for key in u.lv:
		var v := value(u.id, key, level)
		var b := v * boost(active, u.id, key)
		var text := _num(v) if is_equal_approx(b, v) else "%s → %s" % [_num(v), _num(b)]
		nums[key] = text if bb.a == 0.0 else "[b][color=#%s]%s[/color][/b]" % [bb.to_html(false), text]
	return u.desc.format(nums)


## "10", not "10.0"; one decimal otherwise.
static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## Synergy ids that taking upgrade `id` would newly switch on.
static func would_activate(owned: Dictionary, id: String) -> Array:
	var after := owned.duplicate()
	after[id] = after.get(id, 0) + 1
	var before := active_synergies(owned)
	return active_synergies(after).filter(func(tag: String) -> bool: return tag not in before)


## " II", " III" after a name for levels above 1.
static func level_tag(level: int) -> String:
	return ["", "", " II", " III", " IV", " V"][clampi(level, 0, 5)]


## Up to `count` random cards: upgrades the player doesn't own yet and
## level-ups of owned ones below MAX_LEVEL. `owned` maps id -> level.
## Each card is the upgrade's entry plus "level" (the level it grants).
## `level_ups_only` limits it to owned upgrades (the camp's "hone").
## New fusions only come from can_fuse(); with FUSION_CHANCE one takes the
## last card. `path` (a vault) keeps to cards on that path (fusions count),
## topped up from any path if it runs short.
static func roll(owned: Dictionary, count := 3, level_ups_only := false, rng: RandomNumberGenerator = null,
		path := "") -> Array:
	var pool: Array = []
	var fusions: Array = []
	for u in ALL:
		var level: int = owned.get(u.id, 0)
		if level >= MAX_LEVEL or (level == 0 and level_ups_only):
			continue
		if path != "" and path not in paths_of(u):
			continue
		var card: Dictionary = u.duplicate()
		card.level = level + 1
		if level == 0 and u.has("fusion"):
			if can_fuse(owned, u):
				fusions.append(card)
		else:
			pool.append(card)
	shuffle(pool, rng)
	var cards := pool.slice(0, count)
	if not fusions.is_empty() and (rng.randf() if rng else randf()) < FUSION_CHANCE:
		shuffle(fusions, rng)
		if cards.size() >= count:
			cards[-1] = fusions[0]
		else:
			cards.append(fusions[0])
	if path != "" and cards.size() < count:
		var ids := cards.map(func(c: Dictionary) -> String: return c.id)
		for extra: Dictionary in roll(owned, count * 3, level_ups_only, rng):
			if cards.size() < count and extra.id not in ids:
				cards.append(extra)
	return cards


## Up to `count` fusion cards (a met trial): new fusions `owned` can take,
## else level-ups of owned ones. Empty if neither.
static func roll_fusion(owned: Dictionary, count := 2, rng: RandomNumberGenerator = null) -> Array:
	var fresh: Array = []
	var owned_ups: Array = []
	for u in ALL:
		if not u.has("fusion"):
			continue
		var level: int = owned.get(u.id, 0)
		var card: Dictionary = u.duplicate()
		card.level = level + 1
		if level == 0 and can_fuse(owned, u):
			fresh.append(card)
		elif level > 0 and level < MAX_LEVEL:
			owned_ups.append(card)
	var pool := fresh if not fresh.is_empty() else owned_ups
	shuffle(pool, rng)
	return pool.slice(0, count)


## The paths upgrade `u` counts for: its own, plus a fusion's second.
static func paths_of(u: Dictionary) -> Array:
	return [u.path, u.fusion] if u.has("fusion") else [u.path]


## Path colour of `u` (its first path for a fusion).
static func color(u: Dictionary) -> Color:
	return PATHS[u.path].color


## True if `owned` has a non-fusion power on each of fusion `u`'s paths.
static func can_fuse(owned: Dictionary, u: Dictionary) -> bool:
	for path: String in paths_of(u):
		var found := false
		for id: String in owned:
			var o := get_by_id(id)
			if not o.has("fusion") and o.path == path:
				found = true
		if not found:
			return false
	return true


## Powers owned per path (fusions count for both): path -> count.
static func path_counts(owned: Dictionary) -> Dictionary:
	var counts := {}
	for path: String in PATHS:
		counts[path] = 0
	for id: String in owned:
		for path: String in paths_of(get_by_id(id)):
			counts[path] += 1
	return counts


## Paths whose mastery `owned` has switched on.
static func masteries(owned: Dictionary) -> Array:
	var counts := path_counts(owned)
	return PATHS.keys().filter(func(path: String) -> bool: return counts[path] >= MASTERY_NEED)


## Mastery text for `path` with its numbers filled in.
static func mastery_text(path: String) -> String:
	var m: Dictionary = PATHS[path].mastery
	return m.desc.format(m)


static var _icons := {}


## Icon texture for upgrade `id` (assets/icons/powers/<id>.svg, made by
## tools/gen_power_icons.py). Cached: a texture only referenced by a draw
## call is freed before it renders and draws as a white square.
static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path := "res://assets/icons/powers/%s.svg" % id
		_icons[id] = load(path) if ResourceLoader.exists(path) else null
	return _icons[id]


## Shuffle `arr` in place with `rng` (main.run_rng, so seeded runs repeat
## their rolls), or the global RNG when it's null.
static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	if rng == null:
		arr.shuffle()
		return
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t
