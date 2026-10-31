extends RefCounted
## The bone altar (user://altar.cfg): bones left at the end of a run are
## banked here, and spent between runs on small permanent boons. main.gd
## applies the boons at the start of each run; the title screen's "Bone
## altar" menu (altar_menu.gd) buys them.

const PATH := "user://altar.cfg"
## Boons: cost per level (its length is the max level) and the amount each
## level adds (see apply() in main.gd for what "amount" means per id).
const BOONS := {
	"hardened": {"name": "Hardened", "desc": "+{amount} max HP", "amount": 10, "cost": [30, 60, 100]},
	"scavenger": {"name": "Scavenger", "desc": "start runs with +{amount} bones", "amount": 10, "cost": [25, 50, 90]},
	"kindled": {"name": "Kindled", "desc": "start runs with +{amount} Awakening", "amount": 15, "cost": [40, 80]},
}
## Off in the autotest so bot runs don't bank bones or read real boons.
static var enabled := true


## {bank: int, levels: {boon id: level}}.
static func load_altar() -> Dictionary:
	var a := {"bank": 0, "levels": {}}
	if not enabled:
		return a
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		a.bank = cfg.get_value("altar", "bank", 0)
		a.levels = cfg.get_value("altar", "levels", {})
	return a


static func _save(a: Dictionary) -> void:
	if not enabled:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("altar", "bank", a.bank)
	cfg.set_value("altar", "levels", a.levels)
	cfg.save(PATH)


static func bank(count: int) -> void:
	if count <= 0:
		return
	var a := load_altar()
	a.bank += count
	_save(a)


static func level(id: String) -> int:
	return load_altar().levels.get(id, 0)


## Cost of the next level, or -1 at max level.
static func next_cost(id: String) -> int:
	var lv := level(id)
	var costs: Array = BOONS[id].cost
	return costs[lv] if lv < costs.size() else -1


## Total bonus from boon `id` (amount x level).
static func bonus(id: String) -> int:
	return BOONS[id].amount * level(id)


static func buy(id: String) -> bool:
	var a := load_altar()
	var cost := next_cost(id)
	if cost < 0 or a.bank < cost:
		return false
	a.bank -= cost
	a.levels[id] = a.levels.get(id, 0) + 1
	_save(a)
	return true


static func describe(id: String) -> String:
	var b: Dictionary = BOONS[id]
	return "%s: %s" % [b.name, b.desc.format({"amount": b.amount})]
