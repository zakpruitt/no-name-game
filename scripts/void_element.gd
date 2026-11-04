extends RefCounted
## The void arm's strings: a weapon, H to set the element up, H to shoot it, and E in the timing window
## as the breaker: the tentacles seize what's left and slam it into an element. On its own H just shoots
## his last weapon's element. See docs/features/void-element.md.
## player.gd routes (void_route) and calls fire() on a move's first hit; void_grab.gd holds the seized
## foes and calls finish() and breaker_impact().

const ELEMENTS := preload("res://scripts/elements.gd")
const RITE := preload("res://scripts/element_rite.gd")
const QUAKE := preload("res://scripts/breaker_quake.gd")
const FORM_FX := preload("res://scripts/heretic_form_fx.gd")

## The move H plays off each move (from nothing, a shot).
const AFTER := {"L1": "EC", "L2": "EF", "L3": "EM", "EC": "EE", "EF": "EA", "EM": "EV", "DL": "EG", "GR": "EX", "EB": "EB"}
const NEUTRAL := "EB"
const DASH_SHOT := "DS"
## Where the weapon string picks up after a set-up, so L H L H L H runs axe, spear, hammer.
const CHAIN := {"EC": 1, "EF": 2, "DS": 1}
## Whose element a move is; shots with none here use his last weapon's.
const ELEMENT_OF := {"EC": "wind", "EE": "wind", "EF": "water", "EA": "water", "EG": "water", "EM": "earth", "EV": "earth"}
const OTHER_MOVES := ["EB", "DS", "EX"]
## E off a set-up, before anything's shot: the slam lands in that element, with no timing.
const FINISHERS := {"EC": "STORMSNARE", "EB": "STORMSNARE", "DS": "STORMSNARE", "EF": "COLD_SNAP", "EM": "MOLTEN_SLAM"}
const FINISH_MULT := {"STORMSNARE": 1.25, "COLD_SNAP": 1.25, "MOLTEN_SLAM": 1.4}
const FORM_ELEMENT := {"axe": "wind", "spear": "water", "hammer": "earth"}

const _WINDOW := {"rise": 0.2, "height": 1.8, "back": 0.6, "spikes": 0, "zone": 1.5, "spread": 0.0, "spike_damage": 0.0,
	"detonate": 0.0, "throw": 0.04, "cue": 0.08, "open": 0.3, "sweet": 0.44, "close": 0.62, "perfect": 0.06, "dive": 0.12,
	"radius": 0.0, "launch": 0.0, "perfect_mult": 1.5, "fall": 0.22, "tentacle": true, "press": "special"}
## The breakers: `erupt` is what the slam lands in, under each foe. Copies of _WINDOW in effect (entry()).
const BREAKERS := {
	"EE": {"erupt": "earth", "damage": 30.0, "leap": 0.42, "awaken": 8.0, "awaken_perfect": 16.0, "names": {"spirit": "Worldbreaker"}},
	"EA": {"erupt": "wind", "damage": 26.0, "leap": 0.42, "awaken": 8.0, "awaken_perfect": 16.0, "names": {"spirit": "Shatterstorm"}},
	"EV": {"erupt": "water", "damage": 34.0, "leap": 0.42, "awaken": 8.0, "awaken_perfect": 16.0, "names": {"spirit": "Absolute Zero"}},
	"EG": {"erupt": "wind", "damage": 22.0, "leap": 0.34, "awaken": 6.0, "awaken_perfect": 12.0, "names": {"spirit": "Thunderclap"}},
	"CH": {"erupt": "earth", "damage": 26.0, "leap": 0.55, "awaken": 6.0, "awaken_perfect": 14.0, "names": {"spirit": "Landslide"}},
	"CONVERGENCE": {"erupt": "all", "damage": 40.0, "leap": 0.66, "awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Convergence Breaker"}},
}

const SHOT_DAMAGE := 9.0
const SHOT_SPEED := 26.0
const SHOT_REACH := 13.0
const SHOT_SIZE := 1.4
const DASH_SHOTS := 3
const DASH_SPREAD := 16.0  # degrees between them
const CUTTER_AHEAD := 3.5  # m: where the gale throws them up from
const CUTTER_RADIUS := 4.5
const CUTTER_DAMAGE := 10.0
const CUTTER_PULL := 7.0
const CUTTER_LAUNCH := 9.5
const VOLLEY_ZAPS := 6  # lightning shots, shared round the foes
const VOLLEY_DAMAGE := 5.0
const VOLLEY_STEP := 0.05  # s between them
const VOLLEY_REACH := 9.0
const VOLLEY_LIFT := 3.0  # each shot keeps them up
const LINE_LENGTH := 9.0
const LINE_HALF_WIDTH := 1.5
const LINE_STEPS := 8
const LINE_DAMAGE := 10.0
const RUN_LENGTH := 7.0
const RUN_DAMAGE := 12.0
const SHARD_DAMAGE := 8.0
const SHARD_REACH := 11.0
const SHARD_SHOTS := 5
const SHARD_FAN := 12.0  # degrees between shots with nobody to aim at
const FREEZE_TIME := 1.8  # s
const FREEZE_BREAK := 1.6  # the next hit's damage: Frostline into the hammer shatters them
const BOSS_CHILL := 0.5  # bosses never freeze: they slow
const MAGMA_RADIUS := 4.5
const MAGMA_DAMAGE := 14.0
const MAGMA_LAUNCH := 8.0
const MAGMA_WELLS := 3  # each one's geyser is big: Magma Barrage sets off all of them
const MAGMA_WELL_R := 2.6
const BARRAGE_SHOTS := 3
const BARRAGE_DAMAGE := 8.0
const BARRAGE_SPREAD := 20.0
const CONDUIT_DAMAGE := 18.0
const CONDUIT_SPLASH := 10.0
const CONDUIT_RADIUS := 3.8
const CONDUIT_AHEAD := 2.5  # m, with nothing held
const CONVERGE_MULT := 1.5
const SLAM_FINISH_RADIUS := 4.5
const SLAM_FINISH_DAMAGE := 10.0
const GEYSER_RADIUS := 0.9
const BREAK_AREA := 4.5  # m round the landing, beyond whoever was seized
const BREAK_LAUNCH := 7.0
const CRYSTAL_SIZE := 1.5


static func heavy_after(from: String, attacking: bool) -> String:
	return AFTER.get(from, NEUTRAL) if attacking else NEUTRAL


static func is_element_move(id: String) -> bool:
	return ELEMENT_OF.has(id) or id in OTHER_MOVES


## The breaker entry for a key in BREAKERS.
static func entry(key: String) -> Dictionary:
	var made: Dictionary = _WINDOW.duplicate()
	made.merge(BREAKERS[key], true)
	return made


## The colour for this move's shared effects. Otherwise they come out in his axe's teal.
static func color_of(id: String, fallback: Color) -> Color:
	return ELEMENTS.LOOK[ELEMENT_OF[id]].color if ELEMENT_OF.has(id) else fallback


## What a breaker lands in, as an element the shared effects understand.
static func breaker_element(b: Dictionary) -> String:
	return "earth" if b.erupt == "all" else b.erupt


## The move's first hit. Returns how many foes it struck, so a whiff stays quiet. Shots land later, so
## they count what they're aimed at.
static func fire(hero: CharacterBody3D, id: String, fwd: Vector3) -> int:
	var parent: Node = hero.get_parent()
	var at := _flat(hero.global_position)
	var power: float = hero._dmg_mult * hero._cast_power()
	var grow: float = hero._cast_grow()
	var el: String = ELEMENT_OF.get(id, hero._void.weapon_element)
	Game.sfx(ELEMENTS.LOOK[el].sfx, -2.0, 0.1)
	if ELEMENT_OF.has(id):
		hero._el_seen[el] = true
	match id:
		"EB":
			_bolt(hero, fwd, el, SHOT_DAMAGE * power, SHOT_SIZE)
			return _ahead(hero, at, fwd, SHOT_REACH, 1.2).size()
		"DS":
			for i in DASH_SHOTS:
				_bolt(hero, fwd.rotated(Vector3.UP, deg_to_rad((i - (DASH_SHOTS - 1) * 0.5) * DASH_SPREAD)), el, SHOT_DAMAGE * power, SHOT_SIZE)
			return _ahead(hero, at, fwd, SHOT_REACH, 2.5).size()
		"EC":
			var eye: Vector3 = at + fwd * minf(CUTTER_AHEAD, hero._clear_ahead(fwd, CUTTER_AHEAD))
			_pop(parent, eye, "axe")
			ELEMENTS.pillar(parent, eye, "wind", 5.5, 1.9 * grow)
			return _pull(hero, eye, CUTTER_RADIUS * grow, CUTTER_DAMAGE * power, CUTTER_PULL, CUTTER_LAUNCH)
		"EE":
			return _volley(hero, at, fwd, VOLLEY_REACH * grow, VOLLEY_DAMAGE * power)
		"EF":
			return _ice_line(hero, at, fwd, LINE_LENGTH * grow, LINE_DAMAGE * power)
		"EG":
			return _ice_line(hero, at, fwd, RUN_LENGTH * grow, RUN_DAMAGE * power)
		"EA":
			return _shards(hero, at, fwd, SHARD_DAMAGE * power)
		"EM":
			return _magma(hero, at, fwd, grow, power)
		"EV":
			return _barrage(hero, at, fwd, power)
		"EX":
			return _conduit(hero, at, fwd, el, power)
	return 0


# --- The moves ----------------------------------------------------------------

static func _bolt(hero: CharacterBody3D, dir: Vector3, el: String, damage: float, size: float) -> void:
	var b := ELEMENTS.Bolt.new()
	b.el = el
	b.dir = dir
	b.speed = SHOT_SPEED
	b.reach = minf(SHOT_REACH, hero._clear_ahead(dir, SHOT_REACH) + 0.6)
	b.damage = damage
	b.size = size
	b.on_hit = hero._cast_hit
	hero.get_parent().add_child(b)
	b.global_position = hero.global_position + dir * 0.7 + Vector3.UP * (0.25 if el == "earth" else 1.1)


## Lightning from his hand, shared round whoever's nearest. What the gale lifted stays up.
static func _volley(hero: CharacterBody3D, at: Vector3, fwd: Vector3, reach: float, damage: float) -> int:
	var parent: Node = hero.get_parent()
	var foes := _nearest(hero, at, reach)
	var from := at + Vector3.UP * 1.3 + fwd * 0.6
	if foes.is_empty():
		for k: float in [3.0, 6.0]:
			RITE.arc(parent, from, at + fwd * k + Vector3.UP, ELEMENTS.LOOK.wind.color)
		return 0
	for i in VOLLEY_ZAPS:
		var tw := parent.create_tween()
		tw.tween_interval(i * VOLLEY_STEP)
		tw.tween_callback(_shock.bind(parent, from, foes[i % foes.size()], damage, hero._cast_hit))
	return foes.size()


## One lightning shot: an arc from his hand, across, not a strike from the sky.
static func _shock(parent: Node, from: Vector3, e: Node3D, damage: float, on_hit: Callable) -> void:
	if not is_instance_valid(e) or not is_instance_valid(parent) or not e.is_alive():
		return
	var to := e.global_position + Vector3.UP
	RITE.arc(parent, from, to, ELEMENTS.LOOK.wind.color)
	Fx.burst(parent, to, ELEMENTS.LOOK.wind.glow, 10, 9.0, 0.08, 0.2, Vector3.UP, 180.0, 0.0, 0.3, "spark", true)
	Game.sfx("hit_big", -6.0, 0.15)
	e.take_hit(damage, Vector3.ZERO, VOLLEY_LIFT, false)
	Game.register_hit("cast")
	on_hit.call(e)


static func _ice_line(hero: CharacterBody3D, at: Vector3, fwd: Vector3, length: float, damage: float) -> int:
	var parent: Node = hero.get_parent()
	length = minf(length, hero._clear_ahead(fwd, length) + 0.5)
	_pop(parent, at + fwd, "spear")
	ELEMENTS.fissure(parent, at, fwd, length, LINE_STEPS, "water", 1.15)
	var foes := _ahead(hero, at, fwd, length, LINE_HALF_WIDTH)
	for e: Node3D in foes:
		e.take_hit(damage, Vector3.ZERO, 0.0, false)
		Game.register_hit("cast")
		hero._cast_hit(e)
		_chill_or_freeze(e)
	return foes.size()


## An ice lance at each foe in reach, or a fan of them with nobody there.
static func _shards(hero: CharacterBody3D, at: Vector3, fwd: Vector3, damage: float) -> int:
	var foes := _nearest(hero, at, SHARD_REACH)
	for i in SHARD_SHOTS:
		var dir := fwd.rotated(Vector3.UP, deg_to_rad((i - (SHARD_SHOTS - 1) * 0.5) * SHARD_FAN))
		if not foes.is_empty():
			var to := _flat(foes[i % foes.size()].global_position - at)
			dir = to.normalized() if to.length() > 0.1 else fwd
		_bolt(hero, dir, "water", damage, SHOT_SIZE)
	return foes.size()


static func _magma(hero: CharacterBody3D, at: Vector3, fwd: Vector3, grow: float, power: float) -> int:
	var parent: Node = hero.get_parent()
	var heart: Vector3 = at + fwd * 1.5
	var converged: bool = hero._el_seen.has("wind") and hero._el_seen.has("water")
	hero._converged = converged
	var mult := CONVERGE_MULT if converged else 1.0
	_pop(parent, heart, "hammer")
	QUAKE.crater(parent, heart, "earth", 1.4 * mult, true, converged)
	RITE.well(parent, heart, true)
	for i in MAGMA_WELLS:
		RITE.well(parent, heart + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / MAGMA_WELLS) * MAGMA_WELL_R * grow)
	var foes := _strike(hero, heart, MAGMA_RADIUS * grow * mult, MAGMA_DAMAGE * power * mult, MAGMA_LAUNCH, true)
	if converged:  # the storm and the ice answer the lava
		_pop(parent, heart + fwd * 2.0, "axe")
		_pop(parent, heart - fwd * 2.0, "spear")
		ELEMENTS.nova(parent, heart, "water", MAGMA_RADIUS * mult, 10)
		for e: Node3D in foes:
			if e.is_alive():
				ELEMENTS.storm_strike(parent, _flat(e.global_position), "wind")
	return foes.size()


## Molten shots, and the wells near him go up with them.
static func _barrage(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	for i in BARRAGE_SHOTS:
		_bolt(hero, fwd.rotated(Vector3.UP, deg_to_rad((i - (BARRAGE_SHOTS - 1) * 0.5) * BARRAGE_SPREAD)), "earth", BARRAGE_DAMAGE * power, 1.8)
	var wells: int = RITE.set_off(parent, at, "earth", power, hero._cast_hit)
	return maxi(wells, _ahead(hero, at, fwd, SHOT_REACH, 4.0).size())


static func _conduit(hero: CharacterBody3D, at: Vector3, fwd: Vector3, el: String, power: float) -> int:
	var parent: Node = hero.get_parent()
	var held: Node3D = hero._void.let_go()
	var spot: Vector3 = _flat(held.global_position) if held != null else at + fwd * CONDUIT_AHEAD
	_pop(parent, spot + Vector3.UP * 0.6, {"wind": "axe", "water": "spear", "earth": "hammer"}[el])
	var n := 0
	if held != null:
		held.take_hit(CONDUIT_DAMAGE * power, Vector3.ZERO, 0.0, true)
		Game.register_hit("cast")
		hero._cast_hit(held)
		n = 1
	for e: Node3D in _erupt_at(hero, spot, el, CONDUIT_RADIUS, CONDUIT_SPLASH * power):
		n += 1
	return n


# --- Slams and breakers -------------------------------------------------------

## E off a set-up: the slam has landed in the element (void_grab.slam_landed).
static func finish(hero: CharacterBody3D, at: Vector3, id: String) -> void:
	var el: String = {"STORMSNARE": "wind", "COLD_SNAP": "water", "MOLTEN_SLAM": "earth"}[id]
	_erupt_at(hero, _flat(at), el, SLAM_FINISH_RADIUS, SLAM_FINISH_DAMAGE * hero._dmg_mult * hero._cast_power())


## The breaker has landed. `spots`: where each seized foe hit the floor. Each gets the slam and the
## element under it, then anyone else near the landing takes the element too.
static func breaker_impact(hero: CharacterBody3D, b: Dictionary, at: Vector3, seized: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var els: Array = ["earth", "water", "wind"] if b.erupt == "all" else [b.erupt]
	var struck := {}
	for e: Node3D in seized:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		struck[e] = true
		var spot := _flat(e.global_position)
		e.take_hit(damage, Vector3.ZERO, BREAK_LAUNCH, true)
		Game.register_hit("breaker")
		hero._cast_hit(e)
		for el: String in els:
			_under(parent, spot, el)
		if "water" in els:
			_chill_or_freeze(e)
	for e: Node3D in Ascendancy.enemies_near(hero.get_tree(), at, BREAK_AREA):
		if struck.has(e):
			continue
		var from := _flat(e.global_position - at)
		e.take_hit(damage * 0.6, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 5.0, BREAK_LAUNCH, true)
		Game.register_hit("breaker")
		hero._cast_hit(e)
		if "water" in els:
			_chill_or_freeze(e)
	for el: String in els:
		_under(parent, at, el)
		_pop(parent, at, {"wind": "axe", "water": "spear", "earth": "hammer"}[el])


## The element coming up through the floor at `spot`.
static func _under(parent: Node, spot: Vector3, el: String) -> void:
	match el:
		"earth":
			RITE.geyser(parent, spot, GEYSER_RADIUS)
			ELEMENTS.spikes(parent, spot, "earth", CRYSTAL_SIZE, 5, 1.0)
		"water":
			ELEMENTS.spikes(parent, spot, "water", CRYSTAL_SIZE, 6, 1.0)
			Fx.shards(parent, spot + Vector3.UP * 0.6, Color(0.85, 0.96, 1.0), 10, Vector3.UP, 8.0, 0.14, 0.6)
		"wind":
			ELEMENTS.storm_strike(parent, spot, "wind")


## The element at `spot`, hitting what's near. Returns who.
static func _erupt_at(hero: CharacterBody3D, spot: Vector3, el: String, radius: float, damage: float) -> Array:
	var parent: Node = hero.get_parent()
	_pop(parent, spot, {"wind": "axe", "water": "spear", "earth": "hammer"}[el])
	_under(parent, spot, el)
	var foes := _strike(hero, spot, radius, damage, 0.0 if el == "water" else MAGMA_LAUNCH, true)
	if el == "water":
		for e: Node3D in foes:
			_chill_or_freeze(e)
	return foes


# --- Helpers ------------------------------------------------------------------

## Living foes in a strip ahead of him.
static func _ahead(hero: CharacterBody3D, at: Vector3, fwd: Vector3, length: float, half_width: float) -> Array:
	return hero.get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		return e.is_alive() and hero._in_strip(_flat(e.global_position - at), fwd, length, half_width, e.radius))


static func _nearest(hero: CharacterBody3D, at: Vector3, reach: float) -> Array:
	var foes: Array = Ascendancy.enemies_near(hero.get_tree(), at, reach)
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
	return foes


## Everything near `at` is hit and dragged towards it.
static func _pull(hero: CharacterBody3D, at: Vector3, radius: float, damage: float, strength: float, launch: float) -> int:
	var foes: Array = Ascendancy.enemies_near(hero.get_tree(), at, radius)
	for e: Node3D in foes:
		var to := _flat(at - e.global_position)
		e.take_hit(damage, (to.normalized() if to.length() > 0.01 else Vector3.ZERO) * strength, launch, false)
		Game.register_hit("cast")
		hero._cast_hit(e)
	return foes.size()


## Everything near `at` is hit and thrown out from it. Returns who.
static func _strike(hero: CharacterBody3D, at: Vector3, radius: float, damage: float, launch: float, big: bool) -> Array:
	var foes: Array = Ascendancy.enemies_near(hero.get_tree(), at, radius)
	for e: Node3D in foes:
		var from := _flat(e.global_position - at)
		e.take_hit(damage, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 4.0, launch, big)
		Game.register_hit("cast")
		hero._cast_hit(e)
	return foes


static func _chill_or_freeze(e: Node3D) -> void:
	if not is_instance_valid(e) or not e.is_alive():
		return
	if e.has_method("is_boss"):
		e.chill(FREEZE_TIME, BOSS_CHILL)
	elif e.has_method("freeze"):
		e.freeze(FREEZE_TIME, FREEZE_BREAK)


static func _pop(parent: Node, at: Vector3, form: String) -> void:
	FORM_FX.spawn(parent, at + Vector3.UP * 0.8, form, Vector3.ZERO, 0.0)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
