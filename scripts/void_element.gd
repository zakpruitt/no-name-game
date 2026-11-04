extends RefCounted
## Right click on the void arm: L picks the element (axe storm, spear ice, hammer magma), right click
## has the tentacle do that element's thing, and right click in the slow-motion window is the breaker.
## See docs/features/void-element.md.
## player.gd routes (void_route) and calls fire() on a move's first hit; void_grab.gd holds the seized
## foes and calls zap() and breaker_impact().

const FOES := preload("res://scripts/foes.gd")
const ELEMENTS := preload("res://scripts/elements.gd")
const QUAKE := preload("res://scripts/breaker_quake.gd")
const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const THROWN := preload("res://scripts/thrown_foe.gd")
const BIND := preload("res://scripts/floor_bind.gd")
const SPEAR := preload("res://scripts/frost_spear.gd")
const DARK := preload("res://scripts/dark_fx.gd")

## The move right click plays off each move. From nothing, the grab.
const AFTER := {"L1": "EC", "L2": "IP", "L3": "EM", "EC": "EE", "AL1": "EW", "DL": "EF", "EF": "EA", "IP": "IJ", "IJ": "IS", "EM": "EV", "GR": "VS", "VR": "VD"}
const NEUTRAL := "GR"
const CHARGED := "OW"  # holding right click
const DASH_MOVE := "TW"  # right click off a dash or a swing
## L off these moves goes somewhere else than on down the string.
const LIGHT_AFTER := {"EC": "AL1", "GR": "VR", "IP": "IJ"}
const CHAIN := {"EF": 2}
const ELEMENT_OF := {"EC": "wind", "EE": "wind", "EW": "wind", "EF": "water", "EA": "water", "IP": "water", "IJ": "water", "IS": "water", "EM": "earth", "EV": "earth",
	"VS": "void", "VR": "void", "VD": "void", "OW": "void", "TW": "void"}
const NO_CAST := ["AL1", "L3"]  # their giant axes stood in front of the tentacle move that follows
const SPEAR_RUN := ["IJ", "IS"]  # moves that take him to the planted spear

const _WINDOW := {"rise": 0.2, "height": 1.8, "back": 0.6, "spikes": 0, "zone": 1.5, "spread": 0.0, "spike_damage": 0.0,
	"detonate": 0.0, "throw": 0.04, "cue": 0.08, "open": 0.3, "sweet": 0.44, "close": 0.62, "perfect": 0.06, "dive": 0.12,
	"radius": 0.0, "launch": 0.0, "perfect_mult": 1.5, "fall": 0.22, "tentacle": true}
## The breakers: `erupt` is what the slam lands in, under each foe. `wire` runs lightning along the
## tentacles through the hang. `alt` is what L in the window changes it to, instead of right click.
## Copies of _WINDOW in effect (entry()).
const BREAKERS := {
	"EE": {"erupt": "wind", "wire": true, "damage": 28.0, "leap": 0.26, "awaken": 8.0, "awaken_perfect": 16.0,
		"names": {"spirit": "Grounded"}},
	"EW": {"erupt": "earth", "wire": true, "damage": 36.0, "leap": 0.26, "height": 2.6, "awaken": 12.0, "awaken_perfect": 22.0,
		"names": {"spirit": "Worldbreaker"},
		"alt": {"erupt": "water", "cubes": true, "damage": 40.0, "names": {"spirit": "Cold Front"}}},
	"IS": {"erupt": "water", "press": true, "at_spot": true, "short": 3.0, "dive": 0.3, "damage": 34.0, "leap": 0.5, "awaken": 12.0, "awaken_perfect": 22.0,
		"height": 1.2, "names": {"spirit": "Avalanche"}},
	"EV": {"erupt": "earth", "rip": true, "meteor": true, "damage": 60.0, "leap": 0.26, "awaken": 10.0, "awaken_perfect": 20.0,
		"height": 3.6, "back": 0.0, "rise": 0.28, "dive": 0.3, "fall": 0.4, "names": {"spirit": "Meteor Fall"}},
	# Dark: he comes down at dark_spot, where the string gathered them (`at_spot`, `short` m this side of it).
	"VS": {"erupt": "void", "no_hold": true, "at_spot": true, "short": 1.6, "collapse": true, "damage": 44.0, "leap": 0.5,
		"awaken": 10.0, "awaken_perfect": 20.0, "names": {"spirit": "Collapse"}},
	"VD": {"erupt": "void", "no_hold": true, "at_spot": true, "short": 4.6, "maw": true, "damage": 52.0, "leap": 0.5,
		"awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Maw"}},
	"OW": {"erupt": "void", "no_hold": true, "at_spot": true, "short": 2.2, "abyss": true, "damage": 40.0, "leap": 0.5,
		"awaken": 10.0, "awaken_perfect": 20.0, "names": {"spirit": "Abyss"}},
}

const CUTTER_AHEAD := 3.5  # m: where the gale throws them up from
const CUTTER_RADIUS := 4.5
const CUTTER_PILLAR_HIGH := 3.5  # m: it must not bury Live Wire, which follows while it's still up
const CUTTER_PILLAR_R := 1.3
const CUTTER_DAMAGE := 10.0
const CUTTER_PULL := 7.0
const CUTTER_LAUNCH := 9.5
const WIRE_DAMAGE := 3.5  # each jolt, each foe
const HARPOON_LENGTH := 10.0
const HARPOON_HALF_WIDTH := 1.3
const HARPOON_STEPS := 8
const HARPOON_DAMAGE := 10.0
const HARPOON_SPEED := 24.0
const KEBAB_FROM := 1.7  # m ahead of him, the first one reeled in
const KEBAB_GAP := 0.9  # m to the next
const CUBE_DAMAGE := 22.0
const BOWL_REACH := 7.0  # m: how far it'll take a foe from
const BOWL_LENGTH := 12.0  # m it flies
const SPEAR_AHEAD := 2.6  # m in front of him it goes in
const SPEAR_GAP := 0.7  # m short of it he stops
const SPEAR_RUN_SPEED := 16.0  # m/s
const DEEP_FREEZE_RADIUS := 6.5  # m round the spear
const DEEP_FREEZE_DAMAGE := 16.0
const DEEP_FREEZE_SPIKES := 6
const DEEP_FREEZE_SPIKE_OUT := 1.8  # m from the spear: further out they hid the cubes
const PRESS_REACH := 10.0  # m: how far the tentacles go for a cube
const CRUSH_HIGH := 2.5  # m the cubes go up
const CRUSH_RADIUS := 3.2  # m round the pile that anyone else gets caught
const CRUSH_RING := 5.0  # m the frost goes out from it
const CRUSH_CUBE_WIDTH := 1.3  # m: how much room each takes in the pile
const PRESS_NO_CUBE := 0.5  # of the damage, to those not in a cube
const PALM_LENGTH := 6.5
const PALM_HALF_WIDTH := 2.6
const PALM_DAMAGE := 14.0
const PALM_SHOVE := 6.0  # m
const PALM_SPEED := 24.0
const PALM_WALL_MULT := 2.5  # the splat, on the damage below
const PALM_SPLAT := 12.0
const FIST_RADIUS := 1.15
const FIST_TIME := 0.2  # s out
const UNDERTOW_RADIUS := 7.0
const UNDERTOW_TIME := 1.6  # s
const UNDERTOW_SINK := 0.9  # m
const UNDERTOW_TICK := 3.5
const RIP_SMALL_MULT := 3.0  # on a small foe: it's coming apart
const RIP_SPLASH := 5.0  # m
const UNDERTOW_CHASE := 18.0  # m it'll follow those Molten Palm just shoved
const METEOR_GEYSERS := 5
const METEOR_GEYSER_OUT := 2.8  # m round where he lands
const METEOR_R := 0.8  # m
const METEOR_TAIL := 3.0  # m
const METEOR_TONGUES := 5  # the tail is flames, not one long cone
const METEOR_TONGUE_R := 0.42  # m
const METEOR_COLOR := Color(1.0, 0.36, 0.08, 0.72)
const METEOR_HOT := Color(1.0, 0.82, 0.25, 0.9)
const REAP_REACH := 6.5  # m
const REAP_HALF_ANGLE := 1.35  # radians either side of his aim
const REAP_DAMAGE := 14.0
const TIDE_AHEAD := 4.0  # m: where it drags them to
const TIDE_NEAR := 6.0  # m: who it takes with nobody marked
const TIDE_REACH := 20.0  # m: how far it'll go for a mark
const TIDE_DAMAGE := 10.0
const TIDE_SPEED := 22.0
const TIDE_ARRIVE := 0.4  # s at most on the way in, however far: Maw's earliest bite mustn't beat them to the pool
const TIDE_RING := 0.8  # m apart they fetch up
const TIDE_TIME := 1.8  # s they're stuck
const TIDE_POOL_R := 3.4
const COLLAPSE_RADIUS := 6.5  # m
const COLLAPSE_THROW := 9.0
const MAW_RADIUS := 3.4  # m
const ABYSS_RADIUS := 4.2  # m
const ABYSS_SINK := 2.6  # m they go down while he's on his way
const ABYSS_LAUNCH := 11.0
const OVERWHELM_RADIUS := 3.6
const OVERWHELM_REACH := 10.0
const OVERWHELM_AHEAD := 5.0  # m, with nobody to aim at
const OVERWHELM_TIME := 2.2  # s
const OVERWHELM_TICK := 4.0
const TOW_HALF_WIDTH := 2.6
const TOW_NEAR := 5.0  # m round him, if nobody's on the line
const TOW_AHEAD := 2.2  # m: where they're yanked to
const TOW_DAMAGE := 18.0
const TOW_SPEED := 26.0
const CARRY_DAMAGE := 22.0
const CARRY_LENGTH := 9.0  # m it flies off a swing
const FREEZE_TIME := 1.8  # s
const FREEZE_BREAK := 1.6  # the next hit's damage: Frostline into the hammer shatters them
const BOSS_CHILL := 0.5  # bosses never freeze: they slow
const MAGMA_RADIUS := 4.5
const MAGMA_DAMAGE := 14.0
const MAGMA_LAUNCH := 8.0
const MAGMA_WELLS := 3
const MAGMA_WELL_R := 2.6
const GEYSER_RADIUS := 0.9
const GEYSER_HIGH := 3.2  # m: taller hid the hero and blew out at the game's camera
const BREAK_AREA := 4.5  # m round the landing, beyond whoever was seized
const BREAK_LAUNCH := 7.0
const CRYSTAL_SIZE := 1.5
const CUBE_STAGGER := 0.05  # s between the cubes leaving
const CUBE_SEEK := 14.0  # m: how far a cube looks for someone to hit
const CUBE_REACH := 8.0  # m it flies with nobody to hit
const CUBE_FOE_GAP := 0.6


static func heavy_after(from: String, attacking: bool) -> String:
	return AFTER.get(from, NEUTRAL) if attacking else NEUTRAL


## While the spear stands, either button takes him up over it, however long he's watched the frost spread:
## the plant's own animation is over well before the frost is. Not once he's on his way down onto it.
static func vaults(tree: SceneTree, from: String, attacking: bool, post_dash: bool) -> bool:
	if post_dash or from == "IS" or (from == "IJ" and attacking):
		return false
	return SPEAR.current(tree) != null


static func is_element_move(id: String) -> bool:
	return ELEMENT_OF.has(id)


## The breaker entry for a key in BREAKERS.
static func entry(key: String) -> Dictionary:
	var made: Dictionary = _WINDOW.duplicate()
	made.merge(BREAKERS[key], true)
	return made


## The colour for this move's shared effects. Otherwise they come out in his axe's teal.
static func color_of(id: String, fallback: Color) -> Color:
	return ELEMENTS.LOOK[ELEMENT_OF[id]].color if ELEMENT_OF.has(id) else fallback


## Freezes a foe and puts it in a cube. Bosses only slow, with no cube.
static func encase(e: Variant) -> void:
	if not is_instance_valid(e) or not e.is_alive():
		return
	chill_or_freeze(e)
	if not e.has_method("is_boss"):
		THROWN.cube_on(e)


## What a breaker lands in, as an element the shared effects understand.
static func breaker_element(b: Dictionary) -> String:
	return b.erupt


## The move's first hit. Returns how many foes it reached, so a whiff stays quiet.
static func fire(hero: CharacterBody3D, id: String, fwd: Vector3) -> int:
	var parent: Node = hero.get_parent()
	var at := _flat(hero.global_position)
	var power: float = hero._dmg_mult * hero._cast_power()
	var grow: float = hero._cast_grow()
	Game.sfx(ELEMENTS.LOOK[ELEMENT_OF[id]].sfx, -2.0, 0.1)
	match id:
		"EC":
			var eye: Vector3 = at + fwd * minf(CUTTER_AHEAD, hero._clear_ahead(fwd, CUTTER_AHEAD))
			_pop(parent, eye, "axe")
			ELEMENTS.pillar(parent, eye, "wind", CUTTER_PILLAR_HIGH, CUTTER_PILLAR_R * grow)
			return _pull(hero, eye, CUTTER_RADIUS * grow, CUTTER_DAMAGE * power, CUTTER_PULL, CUTTER_LAUNCH)
		"EE", "EW":
			var n: int = hero._void.reachable().size()
			if n == 0:  # nobody to latch onto: it crackles out ahead
				var from := at + Vector3.UP * 1.3 + fwd * 0.6
				for k: float in [3.0, 6.0]:
					ELEMENTS.arc(parent, from, at + fwd * k + Vector3.UP, ELEMENTS.LOOK.wind.color)
			return n
		"EF":
			return _harpoon(hero, at, fwd, HARPOON_LENGTH * grow, HARPOON_DAMAGE * power)
		"IP":
			return _plant(hero, at, fwd)
		"IS":
			return _deep_freeze(hero, at, DEEP_FREEZE_DAMAGE * power)
		"EA":
			return _ice_cube(hero, at, fwd, CUBE_DAMAGE * power)
		"EM":
			return _palm(hero, at, fwd, grow, power)
		"EV":
			return _undertow(hero, at, power)
		"VS":
			return _singularity(hero, power)
		"VR":
			return _reap(hero, at, fwd, REAP_DAMAGE * power)
		"VD":
			return _black_tide(hero, at, fwd, power)
		"OW":
			return _overwhelm(hero, at, fwd, power)
		"TW":
			return _tow(hero, at, fwd, TOW_DAMAGE * power)
	return 0


# --- The moves ----------------------------------------------------------------

## One jolt through everyone the tentacles have: from his hand along each one, and on between them.
static func zap(hero: CharacterBody3D, foes: Array, hand: Vector3) -> void:
	var parent: Node = hero.get_parent()
	var color: Color = ELEMENTS.LOOK.wind.color
	var damage: float = WIRE_DAMAGE * hero._dmg_mult * hero._cast_power()
	var last := hand
	for e: Node3D in foes:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var to := e.global_position + Vector3.UP
		ELEMENTS.arc(parent, last, to, color)
		Fx.burst(parent, to, ELEMENTS.LOOK.wind.glow, 6, 7.0, 0.07, 0.16, Vector3.UP, 180.0, 0.0, 0.3, "spark", true)
		e.take_hit(damage, Vector3.ZERO, 0.0, false)
		Game.register_hit("cast")
		hero._cast_hit(e)
		last = to
	Game.sfx("hit_big", -8.0, 0.15)


## The spear goes in the ground ahead of him. All the frost does is slow them (frost_spear.gd).
static func _plant(hero: CharacterBody3D, at: Vector3, fwd: Vector3) -> int:
	var spot: Vector3 = at + fwd * minf(SPEAR_AHEAD, hero._clear_ahead(fwd, SPEAR_AHEAD))
	SPEAR.plant(hero.get_parent(), spot)
	_pop(hero.get_parent(), spot, "spear")
	return FOES.near(hero.get_tree(), spot, SPEAR.RADIUS).size()


## Takes him to the spear while a SPEAR_RUN move plays. With none standing he stays on his line.
static func run_to_spear(hero: CharacterBody3D, delta: float) -> void:
	var s: Node3D = SPEAR.current(hero.get_tree())
	if s == null:
		return
	var to := _flat(s.global_position - hero.global_position)
	if to.length() <= SPEAR_GAP:
		hero.velocity.x = 0.0
		hero.velocity.z = 0.0
		return
	hero._face(to)
	var speed := minf(SPEAR_RUN_SPEED, (to.length() - SPEAR_GAP) / maxf(delta, 0.001))
	hero.velocity.x = to.normalized().x * speed
	hero.velocity.z = to.normalized().z * speed


## He comes down on the spear and it goes off: everyone on the frost freezes into a cube. With no spear
## left, it goes off where he lands.
static func _deep_freeze(hero: CharacterBody3D, at: Vector3, damage: float) -> int:
	var parent: Node = hero.get_parent()
	var s: Node3D = SPEAR.current(hero.get_tree())
	var spot: Vector3 = _flat(s.global_position) if s != null else at
	if s != null:
		s.shatter()
	SPEAR.frost_ring(parent, spot, DEEP_FREEZE_RADIUS, 0.3)
	under(parent, spot, "water")
	for i in DEEP_FREEZE_SPIKES:
		var a := TAU * i / DEEP_FREEZE_SPIKES
		ELEMENTS.spikes(parent, spot + Vector3(sin(a), 0.0, cos(a)) * DEEP_FREEZE_SPIKE_OUT, "water", 1.0, 2)
	Game.shake(0.5)
	var foes: Array = FOES.near(hero.get_tree(), spot, DEEP_FREEZE_RADIUS)
	for e: Node3D in foes:
		e.take_hit(damage, Vector3.ZERO, 0.0, true)
		Game.register_hit("cast")
		hero._cast_hit(e)
		encase(e)
	return foes.size()


## A spear tip through everyone in a line. They freeze where it finds them and are reeled in, one
## behind the other. Big ones freeze where they stand.
static func _harpoon(hero: CharacterBody3D, at: Vector3, fwd: Vector3, length: float, damage: float) -> int:
	var parent: Node = hero.get_parent()
	length = minf(length, hero._clear_ahead(fwd, length) + 0.5)
	hero._void.spear_to(at + fwd * length + Vector3.UP * 0.9)
	ELEMENTS.fissure(parent, at, fwd, length, HARPOON_STEPS, "water", 0.8)
	var foes := _ahead(hero, at, fwd, length, HARPOON_HALF_WIDTH)
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
	var slot := 0
	for e: Node3D in foes:
		e.take_hit(damage, Vector3.ZERO, 0.0, false)
		Game.register_hit("cast")
		hero._cast_hit(e)
		encase(e)
		if hero._void.is_heavy(e):
			continue
		var to: Vector3 = at + fwd * (KEBAB_FROM + slot * KEBAB_GAP)
		THROWN.launch(hero, e, to, 0.0, {"quiet": true, "solid": false, "tether": true, "speed": HARPOON_SPEED, "land_y": 0.0})
		slot += 1
	return foes.size()


## Freezes the nearest foe, the frozen first, and bowls it along his aim. Everyone it passes freezes.
static func _ice_cube(hero: CharacterBody3D, at: Vector3, fwd: Vector3, damage: float) -> int:
	var foes: Array = hero._void.reachable().filter(func(e: Node3D) -> bool:
		return not hero._void.is_heavy(e) and not THROWN.flying(e) and _flat(e.global_position - at).length() <= BOWL_REACH)
	if foes.is_empty():
		return 0
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var fa: bool = float(a.get("frozen_t") if a.get("frozen_t") != null else 0.0) > 0.0
		var fb: bool = float(b.get("frozen_t") if b.get("frozen_t") != null else 0.0) > 0.0
		if fa != fb:
			return fa
		return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
	var e: Node3D = foes[0]
	encase(e)
	_pop(hero.get_parent(), e.global_position, "spear")
	THROWN.launch(hero, e, e.global_position + fwd * BOWL_LENGTH, damage, {"pierce": true})
	return 1


## The arm swells into a fist and shoves everything in front of him along a line of lava. Whoever hits a
## wall takes it hard. Big foes don't move.
static func _palm(hero: CharacterBody3D, at: Vector3, fwd: Vector3, grow: float, power: float) -> int:
	var parent: Node = hero.get_parent()
	var length: float = minf(PALM_LENGTH * grow, hero._clear_ahead(fwd, PALM_LENGTH * grow) + 0.5)
	hero._void.fist = _fist(parent, at, fwd, length)
	ELEMENTS.fissure(parent, at, fwd, length, HARPOON_STEPS, "earth", 1.0)
	Fx.scorch(parent, at + fwd * length * 0.5, ELEMENTS.LOOK.earth.color, length * 0.5, 1.4)
	var foes := _ahead(hero, at, fwd, length, PALM_HALF_WIDTH)
	hero._void.shoved = foes
	for e: Node3D in foes:
		e.take_hit(PALM_DAMAGE * power, fwd * 4.0, 0.0, true)
		Game.register_hit("cast")
		hero._cast_hit(e)
		if not hero._void.is_heavy(e) and e.is_alive():
			THROWN.launch(hero, e, e.global_position + fwd * PALM_SHOVE, PALM_SPLAT * power,
				{"quiet": true, "solid": false, "el": "earth", "speed": PALM_SPEED, "land_y": 0.0, "wall_mult": PALM_WALL_MULT})
	return foes.size()


## A fist of the arm's own stuff, flying out along `fwd`.
static func _fist(parent: Node, at: Vector3, fwd: Vector3, length: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var from := at + fwd * 1.0 + Vector3.UP * 1.0
	root.global_position = from
	root.look_at(from + fwd, Vector3.UP)
	var mat: Material = null
	if DisplayServer.get_name() != "headless":
		mat = ComicLook.material("P_Tendril", ComicLook.hero_kind()).duplicate()
		mat.next_pass = Fx.ink_material()
	var parts := [[Vector3.ZERO, FIST_RADIUS]]
	for i in 4:  # knuckles, along the front
		parts.append([Vector3((i - 1.5) * FIST_RADIUS * 0.5, FIST_RADIUS * 0.35, -FIST_RADIUS * 0.8), FIST_RADIUS * 0.34])
	for p: Array in parts:
		var ball := SphereMesh.new()
		ball.radius = p[1]
		ball.height = p[1] * 2.0
		ball.radial_segments = 12
		ball.rings = 6
		var mi := MeshInstance3D.new()
		mi.mesh = ball
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_ghost", true)
		mi.position = p[0]
		root.add_child(mi)
	root.scale = Vector3.ONE * 0.4
	var tw := root.create_tween()
	tw.set_parallel()
	tw.tween_property(root, "global_position", at + fwd * length + Vector3.UP * 1.0, FIST_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(root, "scale", Vector3.ONE, FIST_TIME * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_property(root, "scale", Vector3.ONE * 0.1, 0.12).set_delay(0.08)
	tw.chain().tween_callback(root.queue_free)
	return root


## Tendrils up through the floor take everyone near him down into lava, where they stay and burn.
static func _undertow(hero: CharacterBody3D, at: Vector3, power: float) -> int:
	var foes: Array = FOES.near(hero.get_tree(), at, UNDERTOW_RADIUS)
	for e: Variant in hero._void.shoved:  # (it follows them, however far they went)
		if is_instance_valid(e) and e.is_alive() and not e in foes and _flat(e.global_position - at).length() <= UNDERTOW_CHASE:
			foes.append(e)
	hero._void.chased = hero._void.shoved
	hero._void.shoved = []
	hero._void.bound = foes
	if not foes.is_empty():
		BIND.bind(hero, foes, {"time": UNDERTOW_TIME, "sink": UNDERTOW_SINK, "tick_damage": UNDERTOW_TICK * power, "ropes": 2,
			"color": ELEMENTS.LOOK.earth.color, "wells": true})
	return foes.size()


## What he comes down inside on Meteor Fall: a ball of fire with flames streaming back up the way he came.
static func meteor_shell(parent: Node, travel: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.look_at_from_position(Vector3.ZERO, travel.normalized(), Vector3.RIGHT if absf(travel.normalized().y) > 0.95 else Vector3.UP)
	var outer := _meteor_mat(METEOR_COLOR, true)
	var hot := _meteor_mat(METEOR_HOT, false)
	_meteor_part(root, _meteor_ball(METEOR_R), outer, Vector3.ZERO)
	_meteor_part(root, _meteor_ball(METEOR_R * 0.6), hot, Vector3.ZERO)
	for i in METEOR_TONGUES:
		var a := TAU * i / METEOR_TONGUES
		var side := Vector3(cos(a), sin(a), 0.0) * METEOR_R * 0.55
		var long := METEOR_TAIL * (1.0 if i % 2 == 0 else 0.65)
		var cone := CylinderMesh.new()
		cone.top_radius = METEOR_TONGUE_R
		cone.bottom_radius = 0.0
		cone.height = long
		cone.radial_segments = 6
		var flame := _meteor_part(root, cone, outer if i % 2 == 0 else hot, side + Vector3(0.0, 0.0, long * 0.5))
		flame.rotation.x = -PI * 0.5  # the wide end at the ball, the point behind it (+Z, away from where it faces)
	return root


static func _meteor_mat(color: Color, ink: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	if ink and DisplayServer.get_name() != "headless":
		mat.next_pass = Fx.ink_material()
	return mat


static func _meteor_ball(r: float) -> SphereMesh:
	var ball := SphereMesh.new()
	ball.radius = r
	ball.height = r * 2.0
	ball.radial_segments = 10
	ball.rings = 5
	return ball


static func _meteor_part(root: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	m.position = at
	return m


## A black pool opens under whoever he's aiming at, and tendrils come up out of it and pile on. Big foes
## too: they can't be pinned, but it drags on them, and the damage is the same.
static func _overwhelm(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var spot: Vector3 = at + fwd * minf(OVERWHELM_AHEAD, hero._clear_ahead(fwd, OVERWHELM_AHEAD))
	var aim: Node3D = null
	var best := INF
	for e: Node3D in FOES.near(hero.get_tree(), at, OVERWHELM_REACH):
		var to := _flat(e.global_position - at)
		if to.length() > 0.01 and rad_to_deg(fwd.angle_to(to.normalized())) > hero._void.CONE:
			continue
		if to.length() < best:
			best = to.length()
			aim = e
	if aim != null:
		spot = _flat(aim.global_position)
	hero._void.dark_spot = spot
	DARK.pool(parent, spot, OVERWHELM_RADIUS, OVERWHELM_TIME)
	DARK.burst(parent, spot, 1.4)
	var foes: Array = FOES.near(hero.get_tree(), spot, OVERWHELM_RADIUS).filter(func(e: Node3D) -> bool:
		return not THROWN.flying(e))
	hero._void.dark_bind = null
	if not foes.is_empty():
		hero._void.dark_bind = BIND.bind(hero, foes, {"time": OVERWHELM_TIME, "tick_damage": OVERWHELM_TICK * power, "step": 0.2, "ropes": 2,
			"sink": 0.4, "color": DARK.VIOLET})
	return foes.size()


## H H: what it holds comes down, and a black hole tears open where it hits (dark_fx.Hole).
static func _singularity(hero: CharacterBody3D, power: float) -> int:
	var spot: Vector3 = _flat(hero._void._aim_at)
	hero._void.dark_spot = spot
	var hole := DARK.Hole.new()
	hole.hero = hero
	hole.power = power
	hero.get_parent().add_child(hole)
	hole.global_position = spot + Vector3.UP * 0.05
	hero._void.hole = hole
	return FOES.near(hero.get_tree(), spot, DARK.Hole.RADIUS).size()


## H L: a crescent of darkness through everyone in front of him, and it leaves a mark on them.
static func _reap(hero: CharacterBody3D, at: Vector3, fwd: Vector3, damage: float) -> int:
	DARK.reap(hero.get_parent(), at, fwd, REAP_REACH, REAP_HALF_ANGLE)
	var n := 0
	for e: Node3D in FOES.near(hero.get_tree(), at, REAP_REACH):
		var to := _flat(e.global_position - at)
		if to.length() > 0.3 and fwd.angle_to(to.normalized()) > REAP_HALF_ANGLE:
			continue
		e.take_hit(damage, to.normalized() * 3.0 if to.length() > 0.01 else Vector3.ZERO, 0.0, true)
		Game.register_hit("cast")
		hero._cast_hit(e)
		DARK.mark(e)
		n += 1
	return n


## H L H: a pool opens in front of him and everyone marked is dragged across the floor into it, however
## far off they are. With nobody marked, it takes who's near. Big foes hold their ground and take the hit.
static func _black_tide(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var spot: Vector3 = at + fwd * minf(TIDE_AHEAD, hero._clear_ahead(fwd, TIDE_AHEAD))
	var foes: Array = FOES.near(hero.get_tree(), at, TIDE_REACH).filter(func(e: Node3D) -> bool:
		return DARK.marked(e) and not THROWN.flying(e))
	if foes.is_empty():
		foes = FOES.near(hero.get_tree(), at, TIDE_NEAR).filter(func(e: Node3D) -> bool:
			return not THROWN.flying(e))
	hero._void.dark_spot = spot
	DARK.pool(parent, spot, TIDE_POOL_R, TIDE_TIME)
	for i in foes.size():
		var e: Node3D = foes[i]
		DARK.unmark(e)
		e.take_hit(TIDE_DAMAGE * power, Vector3.ZERO, 0.0, true)
		Game.register_hit("cast")
		hero._cast_hit(e)
		if hero._void.is_heavy(e):
			continue
		var a := TAU * i / maxf(foes.size(), 1.0)
		var to: Vector3 = spot + Vector3(sin(a), 0.0, cos(a)) * TIDE_RING
		var speed: float = maxf(TIDE_SPEED, e.global_position.distance_to(to) / TIDE_ARRIVE)
		THROWN.launch(hero, e, to, 0.0, {"quiet": true, "solid": false, "el": "void", "speed": speed, "land_y": 0.0})
	if not foes.is_empty():
		BIND.bind(hero, foes, {"time": TIDE_TIME, "tick_damage": 2.0 * power, "ropes": 0, "sink": 0.5, "color": DARK.VIOLET})
	return foes.size()


## Whoever's on the line he just dashed or swung along is yanked together in front of him.
static func _tow(hero: CharacterBody3D, at: Vector3, fwd: Vector3, damage: float) -> int:
	var from: Vector3 = _flat(hero._dash_from)
	var line := at - from
	var foes: Array = []
	if line.length() > 0.5:
		foes = _ahead(hero, from, line.normalized(), line.length() + 1.5, TOW_HALF_WIDTH)
	if foes.is_empty():
		foes = FOES.near(hero.get_tree(), at, TOW_NEAR)
	var to := at + fwd * minf(TOW_AHEAD, hero._clear_ahead(fwd, TOW_AHEAD))
	var n := 0
	for e: Node3D in foes:
		if hero._void.is_heavy(e):
			e.take_hit(damage * 0.5, Vector3.ZERO, 0.0, true)
			Game.register_hit("cast")
			hero._cast_hit(e)
		else:
			THROWN.launch(hero, e, to, damage, {"el": "void", "tether": true, "speed": TOW_SPEED, "land_y": 0.0})
		n += 1
	return n


# --- Breakers -----------------------------------------------------------------

## The breaker has landed. `seized`: who the tentacles have. Each gets the slam and the element under
## it, then anyone else near the landing takes the element too. Cold Front throws them instead.
static func breaker_impact(hero: CharacterBody3D, b: Dictionary, at: Vector3, seized: Array, mult: float) -> void:
	if b.has("cubes"):
		_cold_front(hero, b, at, seized, mult)
		return
	if b.has("press"):
		_avalanche(hero, b, seized, mult)
		return
	if b.has("rip"):
		_tear(hero, b, seized, mult)
		return
	if b.has("collapse"):
		_collapse(hero, b, at, mult)
		return
	if b.has("maw"):
		_maw(hero, b, mult)
		return
	if b.has("abyss"):
		_abyss(hero, b, mult)
		return
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var struck := {}
	for e: Node3D in seized:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		struck[e] = true
		var spot := _flat(e.global_position)
		e.take_hit(damage, Vector3.ZERO, BREAK_LAUNCH, true)
		Game.register_hit("breaker")
		hero._cast_hit(e)
		under(parent, spot, b.erupt)
	for e: Node3D in FOES.near(hero.get_tree(), at, BREAK_AREA):
		if struck.has(e):
			continue
		var from := _flat(e.global_position - at)
		e.take_hit(damage * 0.6, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 5.0, BREAK_LAUNCH, true)
		Game.register_hit("breaker")
		hero._cast_hit(e)
	under(parent, at, b.erupt)
	_pop(parent, at, {"wind": "axe", "water": "spear", "earth": "hammer"}[b.erupt])


## Each frozen foe is hurled at someone: anyone it wasn't holding first, then the others it was.
static func _cold_front(hero: CharacterBody3D, b: Dictionary, at: Vector3, seized: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	ELEMENTS.nova(parent, at, "water", 3.0, 8)
	_pop(parent, at, "spear")
	for i in seized.size():
		var e: Node3D = seized[i]
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var to := cube_target(e, seized, at, hero.get_tree().get_nodes_in_group("enemies"), hero._facing())
		var tw := parent.create_tween()
		tw.tween_interval(i * CUBE_STAGGER)
		tw.tween_callback(THROWN.launch.bind(hero, e, to, damage))


## The hole falls in on itself and everyone near it is thrown clear, hard.
static func _collapse(hero: CharacterBody3D, b: Dictionary, at: Vector3, mult: float) -> void:
	var damage: float = b.damage * hero._dmg_mult * mult
	var spot: Vector3 = hero._void.dark_spot
	if is_instance_valid(hero._void.hole):
		hero._void.hole.collapse()
	else:
		spot = at
		DARK.burst(hero.get_parent(), spot, 2.0)
	for e: Node3D in FOES.near(hero.get_tree(), spot, COLLAPSE_RADIUS):
		var from := _flat(e.global_position - spot)
		e.take_hit(damage, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * COLLAPSE_THROW, COLLAPSE_THROW, true)
		Game.register_hit("breaker")
		hero._cast_hit(e)
	Game.shake(0.6)


## Jaws of darkness shut on the pool, and on everyone in it.
static func _maw(hero: CharacterBody3D, b: Dictionary, mult: float) -> void:
	var damage: float = b.damage * hero._dmg_mult * mult
	var spot: Vector3 = hero._void.dark_spot
	var jaws: Node3D = hero._void.dark_maw
	if not is_instance_valid(jaws):
		jaws = DARK.maw(hero.get_parent(), spot, MAW_RADIUS)
	jaws.bite()
	for e: Node3D in FOES.near(hero.get_tree(), spot, MAW_RADIUS):
		DARK.quiet_hit(e, damage, true)
		Game.register_hit("breaker")
		hero._cast_hit(e)
	ComicFx.hit(spot + Vector3.UP * 1.5, true)  # one word for the one bite
	Game.shake(0.6)


## They've gone down through the floor (player._start_dive), and black spikes throw them back up.
static func _abyss(hero: CharacterBody3D, b: Dictionary, mult: float) -> void:
	var damage: float = b.damage * hero._dmg_mult * mult
	var spot: Vector3 = hero._void.dark_spot
	if is_instance_valid(hero._void.dark_bind):
		hero._void.dark_bind._let_go()
	var parent: Node = hero.get_parent()
	var foes: Array = FOES.near(hero.get_tree(), spot, ABYSS_RADIUS)
	for e: Node3D in foes:
		DARK.spout(parent, e.global_position)
		e.take_hit(damage, Vector3.ZERO, ABYSS_LAUNCH, true)
		Game.register_hit("breaker")
		hero._cast_hit(e)
	if foes.is_empty():
		DARK.spout(parent, spot)
	Game.shake(0.6)


## Where a cube is on its way up and into the pile, `k` 0 to 1 through the dive: up fast and a little way in,
## then down hard onto its place.
static func crush_point(from: Vector3, to: Vector3, k: float) -> Vector3:
	const TOP := 0.55
	var above: Vector3 = from.lerp(to, 0.3)
	if k < TOP:
		var j := k / TOP
		var ease_out := 1.0 - (1.0 - j) * (1.0 - j)
		var at: Vector3 = from.lerp(above, ease_out)
		at.y = CRUSH_HIGH * ease_out
		return at
	var j := (k - TOP) / (1.0 - TOP)
	var down: Vector3 = above.lerp(to, j)
	down.y = CRUSH_HIGH * (1.0 - j * j)
	return down


## Is this foe in one of his cubes?
static func in_cube(e: Node) -> bool:
	return e.get_node_or_null(THROWN.CUBE_NAME) != null


## The tentacles shove every cube near him straight out. They run through whoever's in the way and
## hit walls hard. Anyone not in a cube just takes some of it.
static func _avalanche(hero: CharacterBody3D, b: Dictionary, cubes: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var mid: Vector3 = hero._void.dark_spot
	SPEAR.frost_ring(parent, mid, CRUSH_RING, 0.25)
	_pop(parent, mid, "spear")
	under(parent, mid, "water")
	for e: Node3D in cubes:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		Fx.shards(parent, e.global_position + Vector3.UP * 0.8, THROWN.CUBE_COLOR, 8, Vector3.UP, 7.0, 0.16, 0.5)
		DARK.quiet_hit(e, damage, true)
		Game.register_hit("breaker")
		hero._cast_hit(e)
	for e: Node3D in FOES.near(hero.get_tree(), mid, CRUSH_RADIUS):
		if not e in cubes:
			DARK.quiet_hit(e, damage * PRESS_NO_CUBE, true)
			Game.register_hit("breaker")
			hero._cast_hit(e)
	ComicFx.hit(mid + Vector3.UP * 1.5, true)  # one word for the one crash


## He lands on the biggest thing Undertow has hold of: small ones come apart, a shield comes off for good,
## everyone close gets what's left, and the floor erupts round him.
static func _tear(hero: CharacterBody3D, b: Dictionary, seized: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	for e: Node3D in seized:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var spot := _flat(e.global_position)
		if e.has_method("rip_shield"):
			e.rip_shield()
		e.take_hit(damage * (1.0 if hero._void.is_heavy(e) else RIP_SMALL_MULT), Vector3.ZERO, 0.0, true)
		Game.register_hit("breaker")
		hero._cast_hit(e)
		under(parent, spot, "earth")
		Fx.shards(parent, spot + Vector3.UP * 0.9, ELEMENTS.LOOK.earth.color, 22, Vector3.UP, 12.0, 0.2, 0.8)
		_pop(parent, spot, "hammer")
		for o: Node3D in FOES.near(hero.get_tree(), spot, RIP_SPLASH):
			if o == e:
				continue
			var from := _flat(o.global_position - spot)
			o.take_hit(damage * 0.4, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 8.0, 0.0, true)
			Game.register_hit("breaker")
			hero._cast_hit(o)
	var at := _flat(hero.global_position)
	for i in METEOR_GEYSERS:
		var a := TAU * i / METEOR_GEYSERS
		ELEMENTS.geyser(parent, at + Vector3(sin(a), 0.0, cos(a)) * METEOR_GEYSER_OUT, GEYSER_RADIUS, GEYSER_HIGH, false)
	Fx.scorch(parent, at, ELEMENTS.LOOK.earth.color, METEOR_GEYSER_OUT * 1.6, 1.6)
	Game.shake(0.7)


## Where a cube goes. Pure, so the check can walk it.
static func cube_target(e: Node3D, seized: Array, at: Vector3, all: Array, facing: Vector3) -> Vector3:
	var best: Node3D = null
	var best_d := INF
	for pool: Array in [all.filter(func(o: Node3D) -> bool: return not o in seized), seized]:
		for o: Node3D in pool:
			if o == e or not is_instance_valid(o) or not o.is_alive():
				continue
			var d := _flat(o.global_position - e.global_position).length()
			if d < best_d and d <= CUBE_SEEK:
				best = o
				best_d = d
		if best != null:
			return _flat(best.global_position)
	var out := _flat(e.global_position - at)
	return _flat(e.global_position) + (out.normalized() if out.length() > 0.2 else facing) * CUBE_REACH


## The element coming up through the floor at `spot`.
static func under(parent: Node, spot: Vector3, el: String) -> void:
	match el:
		"earth":
			ELEMENTS.geyser(parent, spot, GEYSER_RADIUS, GEYSER_HIGH, false)
			ELEMENTS.spikes(parent, spot, "earth", CRYSTAL_SIZE, 5, 1.0)
		"water":
			ELEMENTS.spikes(parent, spot, "water", CRYSTAL_SIZE, 6, 1.0)
			Fx.shards(parent, spot + Vector3.UP * 0.6, Color(0.85, 0.96, 1.0), 10, Vector3.UP, 8.0, 0.14, 0.6)
		"wind":
			ELEMENTS.storm_strike(parent, spot, "wind")
		"spirit":
			ELEMENTS.storm_strike(parent, spot, "spirit")
		"void":
			DARK.burst(parent, spot, 1.2)


# --- Helpers ------------------------------------------------------------------

## Living foes in a strip ahead of him.
static func _ahead(hero: CharacterBody3D, at: Vector3, fwd: Vector3, length: float, half_width: float) -> Array:
	return hero.get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		return e.is_alive() and hero._in_strip(_flat(e.global_position - at), fwd, length, half_width, e.radius))


## Everything near `at` is hit and dragged towards it.
static func _pull(hero: CharacterBody3D, at: Vector3, radius: float, damage: float, strength: float, launch: float) -> int:
	var foes: Array = FOES.near(hero.get_tree(), at, radius)
	for e: Node3D in foes:
		var to := _flat(at - e.global_position)
		e.take_hit(damage, (to.normalized() if to.length() > 0.01 else Vector3.ZERO) * strength, launch, false)
		Game.register_hit("cast")
		hero._cast_hit(e)
	return foes.size()


## Everything near `at` is hit and thrown out from it. Returns who.
static func _strike(hero: CharacterBody3D, at: Vector3, radius: float, damage: float, launch: float, big: bool) -> Array:
	var foes: Array = FOES.near(hero.get_tree(), at, radius)
	for e: Node3D in foes:
		var from := _flat(e.global_position - at)
		e.take_hit(damage, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 4.0, launch, big)
		Game.register_hit("cast")
		hero._cast_hit(e)
	return foes


static func chill_or_freeze(e: Node3D) -> void:
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
