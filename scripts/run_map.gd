class_name RunMap
## The run's map: one column per room (main.RUN_LENGTH), up to LANES nodes
## each, linked to the next column. Generated once at the start of a run from
## main.run_rng (so --seed and the daily run share it); map_screen.gd draws
## it and the player picks the next node after every room.
##
## A node: {kind, lane, next: [lanes in the next column], twists: [ELITE_TWISTS
## keys], path: Upgrades.PATHS key (vault), trial: TRIALS key (trial)}.

const LANES := 3
## Rooms before this one are plain fights (room 2 has two of them).
const UNLOCK_ROOM := 3
## Chance a node also links to a neighbouring lane, besides its own.
const BRANCH_CHANCE := 0.45
## The column before the boss always has a rest.
const PRE_BOSS_REST := true

## Room kinds: map text and look. "fightless" rooms never follow each other.
##   fight  regular enemy mix, 1 power
##   elite  the mix with elites and a twist, 2 powers
##   rest   heal, then the camp (bones buy HP or powers)
##   shrine one trade
##   vault  pick 1 of 3 powers of the vault's path (its colour on the map)
##   trial  a smaller fight with a condition (TRIALS); meet it for a fusion
##   mystery  unknown until entered: rolled from MYSTERY then (`reveal`). It
##          counts as fightless for the links, so whatever it turns out to
##          be never breaks the fightless rule.
##   boss   the Bone Warden
const KINDS := {
	"fight": {"name": "Fight", "text": "skeletons, 1 power", "color": Color(0.82, 0.8, 0.78)},
	"elite": {"name": "Elite", "text": "tougher foes, 2 powers", "color": Color(1.0, 0.36, 0.3)},
	"rest": {"name": "Rest", "text": "heal 40%, then the camp", "color": Color(1.0, 0.62, 0.32), "fightless": true},
	"shrine": {"name": "Shrine", "text": "a trade, no fight", "color": Color(0.85, 0.72, 0.95), "fightless": true},
	"vault": {"name": "Vault", "text": "choose 1 of 3 %s powers", "fightless": true},
	"trial": {"name": "Trial", "text": "%s: a fusion", "color": Color(1.0, 0.93, 0.6)},
	"mystery": {"name": "Unknown", "text": "revealed when you enter", "color": Color(0.55, 0.78, 0.82), "fightless": true},
	"boss": {"name": "Boss", "text": "the Bone Warden", "color": Color(0.85, 0.15, 0.12)},
}
## Powers a room surely gives on clear (elite = main.ELITE_REWARDS; a met
## trial's bonus, camp buys and shrine trades aren't counted). Mystery rooms
## count as the least / most of what they can turn into.
const POWERS := {"fight": 1, "elite": 2, "vault": 1, "trial": 1}
## Odds of each kind for rooms from UNLOCK_ROOM on (relative weights).
const WEIGHTS := {"fight": 32, "elite": 18, "rest": 10, "shrine": 9, "vault": 22, "trial": 12, "mystery": 10}
## What an unknown room turns out to be (relative weights): a gamble that
## leans toward the rarer rooms.
const MYSTERY := {"fight": 20, "elite": 25, "rest": 12, "shrine": 13, "vault": 18, "trial": 12}
## Trial conditions. `time`: Swift's limit is time + per_room * room (s);
## `count`: how many different named combos (player.COMBOS) Showman wants.
const TRIALS := {
	"untouched": {"name": "Untouched", "desc": "clear without being hit"},
	"swift": {"name": "Swift", "desc": "clear within {time}s", "time": 20.0, "per_room": 4.0},
	"stylish": {"name": "Stylish", "desc": "reach style rank {rank}", "rank": "A"},
	"showman": {"name": "Showman", "desc": "land {count} different named combos", "count": 4},
}


## A new map with `length` columns. `twist_ids` are main.ELITE_TWISTS keys;
## elites from `double_twist_room` on get two.
static func generate(rng: RandomNumberGenerator, length: int, twist_ids: Array, double_twist_room: int) -> Array:
	var cols: Array = []
	for c in length:
		var lanes := [1] if c == 0 or c == length - 1 else ([0, 2] if c + 1 < UNLOCK_ROOM else [0, 1, 2])
		cols.append(lanes.map(func(l: int) -> Dictionary:
			return {"kind": "boss" if c == length - 1 else "fight", "lane": l, "next": [], "twists": [], "path": "", "trial": ""}))
	for c in length - 1:
		_link(cols[c], cols[c + 1], rng)
	for c in range(UNLOCK_ROOM - 1, length - 1):
		for node: Dictionary in cols[c]:
			_assign(node, preds(cols, c, node.lane), rng)
	if PRE_BOSS_REST and length - 2 >= UNLOCK_ROOM - 1:
		_ensure_rest(cols, length - 2, rng)
	for c in length:
		for node: Dictionary in cols[c]:
			_dress(node, c + 1, twist_ids, double_twist_room, rng)
	return cols


## Link column `here` to `there`: each node to its own (or nearest) lane and
## maybe a neighbour, then every node in `there` gets at least one way in.
## Neighbour links never cross another link.
static func _link(here: Array, there: Array, rng: RandomNumberGenerator) -> void:
	for n: Dictionary in here:
		if here.size() == 1 or there.size() == 1:
			n.next.assign(there.map(func(m: Dictionary) -> int: return m.lane))
			continue
		n.next.append(_nearest(there, n.lane).lane)
	if here.size() > 1 and there.size() > 1:
		for n: Dictionary in here:
			if rng.randf() >= BRANCH_CHANCE:
				continue
			var side: Array = there.filter(func(m: Dictionary) -> bool:
				return absi(m.lane - n.lane) == 1 and m.lane not in n.next)
			if side.is_empty():
				continue
			var to: int = side[rng.randi() % side.size()].lane
			var crosses := here.any(func(o: Dictionary) -> bool: return o.lane == to and n.lane in o.next)
			if not crosses:
				n.next.append(to)
	for m: Dictionary in there:
		if not here.any(func(n: Dictionary) -> bool: return m.lane in n.next):
			_nearest(here, m.lane).next.append(m.lane)
	for n: Dictionary in here:
		n.next.sort()


static func _nearest(nodes: Array, lane: int) -> Dictionary:
	var best: Dictionary = nodes[0]
	for n: Dictionary in nodes:
		if absi(n.lane - lane) < absi(best.lane - lane):
			best = n
	return best


## Roll a kind from WEIGHTS; never fightless right after a fightless room.
static func _assign(node: Dictionary, from: Array, rng: RandomNumberGenerator) -> void:
	var after_fightless := from.any(func(p: Dictionary) -> bool: return is_fightless(p.kind))
	var total := 0
	for kind: String in WEIGHTS:
		if not (after_fightless and is_fightless(kind)):
			total += WEIGHTS[kind]
	var roll := rng.randi() % total
	for kind: String in WEIGHTS:
		if after_fightless and is_fightless(kind):
			continue
		roll -= WEIGHTS[kind]
		if roll < 0:
			node.kind = kind
			return


## Make one node of column `c` a rest (unless one is), turning any fightless
## room leading into it into a fight.
static func _ensure_rest(cols: Array, c: int, rng: RandomNumberGenerator) -> void:
	if cols[c].any(func(n: Dictionary) -> bool: return n.kind == "rest"):
		return
	var node: Dictionary = cols[c][rng.randi() % cols[c].size()]
	for p: Dictionary in preds(cols, c, node.lane):
		if is_fightless(p.kind):
			p.kind = "fight"
	node.kind = "rest"


## Roll what the map shows ahead of time: elite twists, the vault's path,
## the trial's condition.
static func _dress(node: Dictionary, room: int, twist_ids: Array, double_twist_room: int, rng: RandomNumberGenerator) -> void:
	match node.kind:
		"elite":
			var twists := twist_ids.duplicate()
			Upgrades.shuffle(twists, rng)
			node.twists.assign(twists.slice(0, 2 if room >= double_twist_room else 1))
		"vault":
			node.path = Upgrades.PATHS.keys()[rng.randi() % Upgrades.PATHS.size()]
		"trial":
			node.trial = TRIALS.keys()[rng.randi() % TRIALS.size()]


## Turn an unknown room into a real one (rolled from MYSTERY with `rng`)
## when the player enters it, dressed like any other; room number `room`.
static func reveal(node: Dictionary, room: int, twist_ids: Array, double_twist_room: int, rng: RandomNumberGenerator) -> void:
	var total := 0
	for kind: String in MYSTERY:
		total += MYSTERY[kind]
	var roll := rng.randi() % total
	for kind: String in MYSTERY:
		roll -= MYSTERY[kind]
		if roll < 0:
			node.kind = kind
			break
	_dress(node, room, twist_ids, double_twist_room, rng)


## Nodes of column `c - 1` that link to `lane` in column `c`.
static func preds(cols: Array, c: int, lane: int) -> Array:
	if c == 0:
		return []
	return cols[c - 1].filter(func(n: Dictionary) -> bool: return lane in n.next)


static func is_fightless(kind: String) -> bool:
	return KINDS[kind].get("fightless", false)


## The node at `at` (column, lane), or {}.
static func node_at(cols: Array, at: Vector2i) -> Dictionary:
	if at.x < 0 or at.x >= cols.size():
		return {}
	for n: Dictionary in cols[at.x]:
		if n.lane == at.y:
			return n
	return {}


## The nodes the player can pick after standing on `at`.
## An unknown room's odds, likeliest first ("Elite 25%  ·  Fight 20%  ·  ...").
static func mystery_odds() -> String:
	var total := 0
	for k: String in MYSTERY:
		total += MYSTERY[k]
	var kinds: Array = MYSTERY.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool: return MYSTERY[a] > MYSTERY[b])
	return "  ·  ".join(kinds.map(func(k: String) -> String:
		return "%s %d%%" % [KINDS[k].name, roundi(100.0 * MYSTERY[k] / total)]))


## Fewest and most sure powers (POWERS) from room `at` (counted) to the
## boss (not counted), over every route on: Vector2i(least, most).
static func power_range(cols: Array, at: Vector2i) -> Vector2i:
	var n := node_at(cols, at)
	if n.is_empty() or n.kind == "boss":
		return Vector2i.ZERO
	var own := Vector2i(POWERS.get(n.kind, 0), POWERS.get(n.kind, 0))
	if n.kind == "mystery":
		own = Vector2i(99, 0)
		for k: String in MYSTERY:
			own = Vector2i(mini(own.x, POWERS.get(k, 0)), maxi(own.y, POWERS.get(k, 0)))
	var on := Vector2i(-1, -1)
	for m: Dictionary in next_nodes(cols, at):
		var r := power_range(cols, Vector2i(at.x + 1, m.lane))
		on = r if on.x < 0 else Vector2i(mini(on.x, r.x), maxi(on.y, r.y))
	return own + on.maxi(0)


static func next_nodes(cols: Array, at: Vector2i) -> Array:
	var here := node_at(cols, at)
	if here.is_empty() or at.x + 1 >= cols.size():
		return []
	return cols[at.x + 1].filter(func(n: Dictionary) -> bool: return n.lane in here.next)


## Map colour of a node: its vault's path colour, else its kind's.
static func color(node: Dictionary) -> Color:
	return Upgrades.PATHS[node.path].color if node.kind == "vault" else KINDS[node.kind].color


## Title for a node ("Elite · Volatile", "Vault · Light", "Trial · Swift").
static func title(node: Dictionary) -> String:
	var name: String = KINDS[node.kind].name
	match node.kind:
		"elite":
			if not node.twists.is_empty():
				name += "  ·  " + " + ".join(node.twists.map(func(t: String) -> String: return main_twist(t, "name")))
		"vault":
			name += "  ·  " + Upgrades.PATHS[node.path].name
		"trial":
			name += "  ·  " + TRIALS[node.trial].name
	return name


## One line on what the room holds, for room number `room`.
static func describe(node: Dictionary, room: int) -> String:
	match node.kind:
		"elite":
			if node.twists.is_empty():
				return KINDS.elite.text
			return "%s, 2 powers" % ", ".join(node.twists.map(func(t: String) -> String: return main_twist(t, "desc")))
		"vault":
			return KINDS.vault.text % Upgrades.PATHS[node.path].name
		"trial":
			return KINDS.trial.text % _cap(trial_text(node.trial, room))
	return KINDS[node.kind].text


## A trial's condition with its numbers ("clear within 36s").
static func trial_text(id: String, room: int) -> String:
	var t: Dictionary = TRIALS[id]
	return t.desc.format({"time": int(trial_time(room)), "rank": t.get("rank", ""), "count": t.get("count", 0)})


## Swift's time limit in room `room`.
static func trial_time(room: int) -> float:
	return TRIALS.swift.time + TRIALS.swift.per_room * room


static func _cap(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1)


## ELITE_TWISTS field from main.gd (it has no class_name, so load it).
static func main_twist(id: String, field: String) -> String:
	return load("res://scripts/main.gd").ELITE_TWISTS[id][field]
