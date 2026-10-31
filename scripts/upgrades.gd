class_name Upgrades
## Combo-slot upgrades: each one hooks a specific move in the hero's string
## (L1/L2/L3 light chain, H spin, LH launcher, DL dash stab) or a mechanic.
## Pure data here; the effects live in player.gd (search for the id).
##
##   id      key used in code          slot  which move/mechanic it modifies
##   name    card title                desc  card text shown to the player

const ALL := [
	{"id": "ember_cleave", "name": "Ember Cleave", "slot": "L3",
		"desc": "Your 3rd light hit sends a wave of fire rolling forward."},
	{"id": "static_step", "name": "Static Step", "slot": "Dash",
		"desc": "Dash-cancelling an attack leaves a lightning trap that bursts a moment later."},
	{"id": "chain_spark", "name": "Chain Spark", "slot": "Air",
		"desc": "Hitting a juggled enemy arcs lightning to 2 nearby foes."},
	{"id": "whirlwind", "name": "Whirlwind", "slot": "H",
		"desc": "Your spin hits 5 times and reaches further."},
	{"id": "skybreaker", "name": "Skybreaker", "slot": "LH",
		"desc": "Your launcher sends out a shockwave that launches everyone nearby."},
	{"id": "bloodthirst", "name": "Bloodthirst", "slot": "L1",
		"desc": "Your opening light hit heals 2 HP per enemy struck."},
	{"id": "momentum", "name": "Momentum", "slot": "DL",
		"desc": "Your dash stab deals +60% damage and reaches much further."},
	{"id": "overflow", "name": "Overflow", "slot": "Awaken",
		"desc": "Gain Awakening 35% faster."},
]


static func get_by_id(id: String) -> Dictionary:
	for u in ALL:
		if u.id == id:
			return u
	return {}


## Up to `count` random upgrades the player doesn't own yet.
static func roll(owned: Array, count := 3) -> Array:
	var pool := ALL.filter(func(u: Dictionary) -> bool: return not owned.has(u.id))
	pool.shuffle()
	return pool.slice(0, count)
