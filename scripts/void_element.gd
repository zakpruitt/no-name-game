extends RefCounted
## Right click on the void arm: L picks the element (axe storm, spear ice, hammer magma), right click
## has the tentacle do that element's thing, and right click in the slow-motion window is the breaker.
## See docs/features/void-element.md.
## player.gd routes (void_route) and calls fire() on a move's first hit; void_grab.gd holds the seized
## foes and calls zap() and breaker_impact().

const FOES := preload("res://scripts/foes.gd")
const ELEMENTS := preload("res://scripts/elements.gd")
const QUAKE := preload("res://scripts/breaker_quake.gd")
const COMIC_FIST := preload("res://scripts/comic_fist.gd")
const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const THROWN := preload("res://scripts/thrown_foe.gd")
const BIND := preload("res://scripts/floor_bind.gd")
const SPEAR := preload("res://scripts/frost_spear.gd")
const DARK := preload("res://scripts/dark_fx.gd")
const COMIC_BOULDER := preload("res://scripts/comic_boulder.gd")  # crossover looks (round 37)

## Contact frames of the tentacle clips (30 fps, the chibi's keys; `tests/contact_frames.gd` measures them,
## `comic_check` fails when a move's first hit isn't on its clip's): the void moves hit on the keyed contact
## as a fraction of the clip, and their cancel / end / breaker leap keep the time after the hit they had.
const GR_HIT := 7.0 / 31.0  # Ab_GR: the claws snap shut on f7 (hand arrives f5, held to f12). Was 0.24 (f7.4)
const VS_HIT := 17.0 / 46.0  # Ab_VS: the slam lands on f17 (held to f23). Was 0.39 (f17.9, a frame late)
const LH_HIT := 14.0 / 51.0  # Ab_LH: the rake arrives on f14. Was 0.29 (f14.8)
const H_HIT := 15.0 / 63.0  # Ab_H: the crescent arrives on f15. Was 0.24 (f15.1)
const LLH_HIT := 20.0 / 59.0  # Ab_LLH: the spear drives in on f20. Was 0.34 (f20.1)
const AF_HIT := 50.0 / 99.0  # Ab_AF: the palm lands on f50. Was 0.51 (f50.5)
## A breaker's leap comes this long (clip fraction) after the ender's hit, as round 30 had it.
const LEAP_AFTER_GRAB := 0.02  # Grounded / Worldbreaker / Meteor Fall off a grab-clip ender (was 0.26 - 0.24)
const LEAP_AFTER_SLAM := 0.11  # Collapse / Abyss off the slam clip (0.5 - 0.39)
const LEAP_AFTER_TIDE := 0.26  # Maw off Black Tide's grab clip (0.5 - 0.24)
const LEAP_AFTER_RAKE := 0.05  # Cataclysm off Fault Line's rake clip: once the gale has them up
const LEAP_AFTER_PALM := 0.05  # Flash Freeze off Steam Burst's palm clip

## The move right click plays off each move. From nothing, the grab.
const AFTER := {"L1": "EC", "L2": "IP", "L3": "EM", "EC": "EE", "AL1": "EW", "DL": "EF", "EF": "EA", "IP": "IJ", "IJ": "IS", "EM": "EV", "GR": "VS", "VR": "VD",
	"XR": "XF"}
const NEUTRAL := "GR"
const CHARGED := "OW"  # holding right click
const DASH_MOVE := "TW"  # right click off a dash or a swing
## L off these moves goes somewhere else than on down the string. The X* moves are the crossovers (round 34):
## a string that changes element on the way, with a payoff only the two together give.
const LIGHT_AFTER := {"EC": "AL1", "GR": "VR", "IP": "IJ", "AL1": "XR", "EA": "XS", "TW": "XT"}
const CHAIN := {"EF": 2}
const ELEMENT_OF := {"EC": "wind", "EE": "wind", "EW": "wind", "EF": "water", "EA": "water", "IP": "water", "IJ": "water", "IS": "water", "EM": "earth", "EV": "earth",
	"VS": "void", "VR": "void", "VD": "void", "OW": "void", "TW": "void",
	"XR": "earth", "XF": "wind", "XS": "earth", "XT": "wind"}
## The arm's shape for the crossovers (ComicLook.HERO_MOVE_FORMS has the rest; void_grab.on_move reads this first).
const FORM_OF := {"XR": "hammer", "XF": "hand", "XS": "hand", "XT": "axe"}
const NO_CAST := ["AL1", "L3"]  # their giant axes stood in front of the tentacle move that follows
const SPEAR_RUN := ["IJ", "IS"]  # moves that take him to the planted spear

const _WINDOW := {"rise": 0.2, "height": 1.8, "back": 0.6, "spikes": 0, "zone": 1.5, "spread": 0.0, "spike_damage": 0.0,
	"detonate": 0.0, "throw": 0.04, "cue": 0.08, "open": 0.3, "sweet": 0.44, "close": 0.62, "perfect": 0.06, "dive": 0.12,
	"radius": 0.0, "launch": 0.0, "perfect_mult": 1.5, "fall": 0.22, "tentacle": true}
const BREAKER_HANG := 0.1  # s from the top of the rise to the window opening: the beat to see the cue
const BREAKER_TO_SWEET := 0.14  # s from open to the rings meeting
const BREAKER_TO_CLOSE := 0.32  # s from open to close
## The breakers: `erupt` is what the slam lands in, under each foe. `wire` runs lightning along the
## tentacles through the hang. `alt` is what L in the window changes it to, instead of right click.
## Copies of _WINDOW in effect (entry()).
const BREAKERS := {
	"EE": {"erupt": "wind", "wire": true, "damage": 28.0, "leap": GR_HIT + LEAP_AFTER_GRAB, "awaken": 8.0, "awaken_perfect": 16.0,
		"names": {"spirit": "Grounded"}},
	"EW": {"erupt": "earth", "wire": true, "damage": 36.0, "leap": GR_HIT + LEAP_AFTER_GRAB, "height": 2.6, "awaken": 12.0, "awaken_perfect": 22.0,
		"names": {"spirit": "Worldbreaker"},
		"alt": {"erupt": "water", "cubes": true, "damage": 40.0, "names": {"spirit": "Cold Front"}}},
	"IS": {"erupt": "water", "press": true, "at_spot": true, "short": 3.0, "dive": 0.3, "damage": 34.0, "leap": 0.5, "awaken": 12.0, "awaken_perfect": 22.0,
		"height": 1.2, "names": {"spirit": "Avalanche"}},
	# Meteor Fall (round 34): the press hurls everyone into the walls (beat 1), the tentacles drag them all into one
	# pile (beat 2), and he dives into the pile as the meteor (beat 3). `gather`: hero_leap phase 3, METEOR_*.
	"EV": {"erupt": "earth", "rip": true, "meteor": true, "gather": true, "damage": 60.0, "leap": GR_HIT + LEAP_AFTER_GRAB, "awaken": 10.0, "awaken_perfect": 20.0,
		"height": 3.6, "back": 0.0, "rise": 0.28, "dive": 0.3, "fall": 0.4, "names": {"spirit": "Meteor Fall"}},
	# Dark: he comes down at dark_spot, where the string gathered them (`at_spot`, `short` m this side of it).
	"VS": {"erupt": "void", "no_hold": true, "at_spot": true, "short": 1.6, "collapse": true, "damage": 44.0, "leap": VS_HIT + LEAP_AFTER_SLAM,
		"awaken": 10.0, "awaken_perfect": 20.0, "names": {"spirit": "Collapse"}},
	"VD": {"erupt": "void", "no_hold": true, "at_spot": true, "short": 4.6, "maw": true, "damage": 52.0, "leap": GR_HIT + LEAP_AFTER_TIDE,
		"awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Maw"},
		# L in the window (dark into ice): the pool freezes with them in it, and his landing shatters it.
		"alt": {"erupt": "water", "black_ice": true, "short": 2.0, "damage": 46.0, "names": {"spirit": "Black Ice"}}},
	"OW": {"erupt": "void", "no_hold": true, "at_spot": true, "short": 2.2, "abyss": true, "damage": 40.0, "leap": VS_HIT + LEAP_AFTER_SLAM,
		"awaken": 10.0, "awaken_perfect": 20.0, "names": {"spirit": "Abyss"}},
	# Crossovers. Cataclysm: Fault Line's gale has them up again; lightning runs through them in the hang and the
	# landing brings them down into the floor (`cataclysm`: a crater on each, a strike and earth under each).
	"XF": {"erupt": "earth", "wire": true, "cataclysm": true, "damage": 40.0, "leap": LH_HIT + LEAP_AFTER_RAKE, "height": 2.4,
		"awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Cataclysm"}},
	# Flash Freeze: Steam Burst's steam freezes on them as he dives (`refreeze`), and the landing shatters it again.
	"XS": {"erupt": "water", "refreeze": true, "damage": 30.0, "leap": AF_HIT + LEAP_AFTER_PALM,
		"awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Flash Freeze"}},
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
const DEEP_FREEZE_DOWN := 6.0  # m/s into the floor on its hit: enemy._is_spike craters them before the cube
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
const METEOR_DOWN := 6.0  # m/s into the floor on Meteor Fall's hit on the seized foe: it craters (enemy._is_spike)
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
const MAW_DOWN := 6.0  # m/s into the floor as the jaws shut: the swallowed crater (enemy._is_spike)
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
# Crossovers (round 34).
const ROCKSLIDE_AHEAD := 1.6  # m: where the hammer comes down
const ROCKSLIDE_RADIUS := 5.0  # m round it
const ROCKSLIDE_DAMAGE := 12.0
const ROCKSLIDE_AIR_MULT := 2.0  # on a foe the gale had up: wind lifts, earth brings it down
const ROCKSLIDE_DOWN := 6.0  # m/s into the floor (enemy._is_spike): the whole group craters
const ROCKSLIDE_IN := 3.0  # m/s of it towards the hammer, so they come down together
const FAULT_REACH := 7.0  # m: how far the cracks run
const FAULT_DAMAGE := 8.0
const FAULT_BURIED_MULT := 2.0  # on those Rockslide just put in the floor: the gale throws back what it buried
const FAULT_LAUNCH := 9.0
const STEAM_REACH := 12.0  # m: every frozen foe this close goes off (the bowled one too)
const STEAM_DAMAGE := 18.0  # times the ice's FREEZE_BREAK on the frozen
const STEAM_LAUNCH := 8.0
const STEAM_SPLASH := 2.6  # m round each burst that the steam scalds
const STEAM_SPLASH_DAMAGE := 6.0
const STEAM_FIST := 4.0  # m the fist goes out, with nobody frozen
const PITCH_AHEAD := 1.8  # m: where Tow Line bunched them
const PITCH_GRAB := 3.4  # m round that spot it takes them from
const PITCH_LENGTH := 9.0  # m they fly
const PITCH_SPREAD := 0.35  # radians between them
const PITCH_DAMAGE := 16.0
const PITCH_SPEED := 26.0
const BLACK_ICE_DOWN := 6.0  # m/s into the floor as the ice gives (enemy._is_spike)
const CATACLYSM_DOWN := 6.0  # m/s
# Meteor Fall's three beats (s, game time from the press): the wall throw, the drag into the pile, the dive.
const METEOR_REACH := 12.0  # m round him: who gets thrown, and then gathered
const METEOR_WALL_LENGTH := 10.0  # m they fly at most (a wall stops them sooner and splats them). At 14 they left the
# game camera's frame in the training room, so beat 1 read as them vanishing
const METEOR_WALL_SPEED := 36.0  # m/s: ~0.28 s out
const METEOR_WALL_DAMAGE := 10.0
const METEOR_WALL_MULT := 2.0  # the splat
const METEOR_GATHER_AT := 0.32  # s: beat 2 once nobody's still flying, not before this...
const METEOR_GATHER_LATE := 0.5  # ...and not after this
const METEOR_DRAG_TIME := 0.26  # s on the tentacles into the pile, however far
const METEOR_DIVE_LATE := 0.45  # s after beat 2 he dives whether or not they've all arrived
const METEOR_PILE_AHEAD := 3.0  # m in front of him (with no big one to pile them on)
const METEOR_PILE_RING := 0.8  # m apart in the pile
const METEOR_PILE_R := 3.0  # m round the landing that the meteor takes
const METEOR_HEAVY_MULT := 1.5  # the biggest still takes it worst
const METEOR_BEAT_STOP := 0.07  # s of hitstop on each beat


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


## The breaker entry for a key in BREAKERS. Its window keeps one rhythm whatever the element (round 30): it
## opens BREAKER_HANG s after the rise tops out, the sweet spot BREAKER_TO_SWEET later and it closes
## BREAKER_TO_CLOSE after opening, unless the breaker sets `open` itself. With the default rise (0.2)
## that's _WINDOW's 0.3 / 0.44 / 0.62; Meteor Fall's longer rise (0.28) used to open 0.02 s after the top.
static func entry(key: String) -> Dictionary:
	var made: Dictionary = _WINDOW.duplicate()
	made.merge(BREAKERS[key], true)
	if not BREAKERS[key].has("open"):
		made.open = made.rise + BREAKER_HANG
		made.sweet = made.open + BREAKER_TO_SWEET
		made.close = made.open + BREAKER_TO_CLOSE
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
		"XR":
			return _rockslide(hero, at, fwd, power * hero.HERO_MOVES.plunge_mult(hero))
		"XF":
			return _fault_line(hero, at, fwd, power)
		"XS":
			return _steam_burst(hero, at, fwd, power)
		"XT":
			return _pitch(hero, at, fwd, power)
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
		e.take_hit(damage, Vector3.DOWN * DEEP_FREEZE_DOWN, 0.0, true)
		Game.register_hit("cast")
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
		if not hero._void.is_heavy(e) and e.is_alive():
			THROWN.launch(hero, e, e.global_position + fwd * PALM_SHOVE, PALM_SPLAT * power,
				{"quiet": true, "solid": false, "el": "earth", "speed": PALM_SPEED, "land_y": 0.0, "wall_mult": PALM_WALL_MULT})
	return foes.size()


## A fist of the arm's own stuff, flying out along `fwd`.
static func _fist(parent: Node, at: Vector3, fwd: Vector3, length: float) -> Node3D:
	if Game.comic_style: return COMIC_FIST.spawn(parent, at, fwd, length, FIST_TIME)  # the flat inked fist
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
		hero._void.undertow = BIND.bind(hero, foes, {"time": UNDERTOW_TIME, "sink": UNDERTOW_SINK, "tick_damage": UNDERTOW_TICK * power, "ropes": 2,
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
		else:
			THROWN.launch(hero, e, to, damage, {"el": "void", "tether": true, "speed": TOW_SPEED, "land_y": 0.0})
		n += 1
	return n


# --- Crossovers (round 34): a string that changes element, with a payoff only the pair gives --------------------
# TODO(fx lane): the looks here are the existing helpers as placeholders. Hooks wanted: a falling-rock / boulder
# slam for Rockslide, a crack that runs and glows for Fault Line, a steam cloud (white puffs, inked) for Steam Burst,
# lightning that rides a thrown foe for Storm Pitch, a pool freezing over for Black Ice, a wall-splat star and a
# pile-up word for Meteor Fall's beats, and ComicFx.MOVE_WORDS / BREAKER_WORDS for XR, XF, XS, XT, Cataclysm,
# Flash Freeze and Black Ice.

## L H L L: wind into earth. The hammer comes down off the air string and everyone near the blow is driven into
## the floor together; the ones Updraft Lash had in the air take double.
static func _rockslide(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var spot: Vector3 = at + fwd * minf(ROCKSLIDE_AHEAD, hero._clear_ahead(fwd, ROCKSLIDE_AHEAD))
	var foes: Array = FOES.near(hero.get_tree(), spot, ROCKSLIDE_RADIUS * hero._cast_grow()).filter(func(e: Node3D) -> bool:
		return not THROWN.flying(e))
	hero._void.buried = []
	COMIC_BOULDER.spawn(parent, spot, foes.map(func(e: Node3D) -> Vector3: return _flat(e.global_position)))
	Fx.scorch(parent, spot, ELEMENTS.LOOK.earth.color, 2.2, 0.6)
	for e: Node3D in foes:
		var up: bool = e.is_airborne()
		var to := _flat(spot - e.global_position)
		var kb: Vector3 = (to.normalized() * ROCKSLIDE_IN if to.length() > 0.6 else Vector3.ZERO) + Vector3.DOWN * ROCKSLIDE_DOWN
		e.take_hit(ROCKSLIDE_DAMAGE * power * (ROCKSLIDE_AIR_MULT if up else 1.0), kb, 0.0, true)
		Game.register_hit("cast")
		if up:
			hero._void.buried.append(e)
	Game.shake(0.5)
	return foes.size()


## L H L L H: earth into wind. Cracks run from him to everyone near, and the gale comes up out of each one and
## throws them back into the air, Rockslide's buried twice as hard. The window opens (Cataclysm).
static func _fault_line(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var foes: Array = FOES.near(hero.get_tree(), at, FAULT_REACH * hero._cast_grow()).filter(func(e: Node3D) -> bool:
		return not THROWN.flying(e))
	if foes.is_empty():
		ELEMENTS.fissure(parent, at, fwd, 4.0, 5, "earth", 0.8)
		return 0
	for e: Node3D in foes:
		var to := _flat(e.global_position - at)
		var spot := _flat(e.global_position)
		if to.length() > 0.5:
			ELEMENTS.fissure(parent, at, to.normalized(), to.length(), 4, "earth", 0.7)
		ELEMENTS.pillar(parent, spot, "wind", 2.6, 0.9)
		var buried: bool = e in hero._void.buried
		e.take_hit(FAULT_DAMAGE * power * (FAULT_BURIED_MULT if buried else 1.0), Vector3.ZERO, 0.0 if hero._void.is_heavy(e) else FAULT_LAUNCH, true)
		Game.register_hit("cast")
	hero._void.buried = []
	return foes.size()


## Dash L H H L: ice into magma. The fist drives lava into the ice: every frozen foe near him goes off in
## steam (the ice's FREEZE_BREAK on top), up into the air, and the steam scalds whoever's beside it. With
## nobody frozen it's only a shove of molten fist. The window opens (Flash Freeze).
static func _steam_burst(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var frozen: Array = FOES.near(hero.get_tree(), at, STEAM_REACH).filter(func(e: Node3D) -> bool:
		return not THROWN.flying(e) and (in_cube(e) or float(e.get("frozen_t") if e.get("frozen_t") != null else 0.0) > 0.0))
	var reach := STEAM_FIST
	if not frozen.is_empty():
		var mid := Vector3.ZERO
		for e: Node3D in frozen:
			mid += _flat(e.global_position)
		mid /= float(frozen.size())
		reach = clampf(_flat(mid - at).length(), 2.0, PALM_LENGTH)
		var to := _flat(mid - at)
		if to.length() > 0.5:
			hero._face(to)
			fwd = to.normalized()
	hero._void.fist = _fist(parent, at, fwd, minf(reach, hero._clear_ahead(fwd, reach) + 0.5))
	if frozen.is_empty():
		var near := _ahead(hero, at, fwd, STEAM_FIST, PALM_HALF_WIDTH)
		for e: Node3D in near:
			e.take_hit(PALM_DAMAGE * power * 0.5, fwd * 4.0, 0.0, true)
			Game.register_hit("cast")
		return near.size()
	var scalded := {}
	for e: Node3D in frozen:
		var spot := _flat(e.global_position)
		THROWN.remove_cube(e)
		e.take_hit(STEAM_DAMAGE * power, Vector3.ZERO, 0.0 if hero._void.is_heavy(e) else STEAM_LAUNCH, true)  # (frozen: x FREEZE_BREAK)
		Game.register_hit("cast")
		Fx.shards(parent, spot + Vector3.UP * 0.9, THROWN.CUBE_COLOR, 12, Vector3.UP, 9.0, 0.18, 0.6)
		Fx.burst(parent, spot + Vector3.UP * 0.6, Color(0.96, 0.96, 1.0), 10, 6.0, 0.25, 0.6, Vector3.UP, 70.0)  # steam
		ELEMENTS.geyser(parent, spot, GEYSER_RADIUS * 0.8, GEYSER_HIGH * 0.8, false)
		for o: Node3D in FOES.near(hero.get_tree(), spot, STEAM_SPLASH):
			if o in frozen or scalded.has(o):
				continue
			scalded[o] = true
			var out := _flat(o.global_position - spot)
			o.take_hit(STEAM_SPLASH_DAMAGE * power, (out.normalized() if out.length() > 0.01 else fwd) * 4.0, 0.0, false)
			Game.register_hit("cast")
	Game.shake(0.55)
	return frozen.size() + scalded.size()


## Dash H L: dark into storm. Whoever Tow Line bunched in front of him is hurled on by the axe, crackling: each
## one flies along his aim with lightning jumping from it to anyone it passes (thrown_foe `zap`), and bursts in
## wind where it lands. Big ones stay and take the jolt.
static func _pitch(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var spot: Vector3 = at + fwd * PITCH_AHEAD
	var foes: Array = FOES.near(hero.get_tree(), spot, PITCH_GRAB)
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
	var hand := at + Vector3.UP * 1.3 + fwd * 0.6
	var last := hand
	for i in foes.size():
		var e: Node3D = foes[i]
		ELEMENTS.arc(parent, last, e.global_position + Vector3.UP, ELEMENTS.LOOK.wind.color)
		last = e.global_position + Vector3.UP
		if hero._void.is_heavy(e):
			e.take_hit(PITCH_DAMAGE * power * 0.6, Vector3.ZERO, 0.0, true)
			Game.register_hit("cast")
			continue
		THROWN.cut(e)  # (still on Tow Line's tether: the axe takes it from there)
		var side := (float(i) - (foes.size() - 1) * 0.5) * PITCH_SPREAD
		var dir := fwd.rotated(Vector3.UP, side)
		THROWN.launch(hero, e, _flat(e.global_position) + dir * PITCH_LENGTH, PITCH_DAMAGE * power,
			{"el": "wind", "solid": true, "speed": PITCH_SPEED, "zap": true})
	return foes.size()


## Black Ice's press (hero_leap._start_dive): the pool freezes, with everyone in it.
static func freeze_pool(hero: CharacterBody3D) -> void:
	var parent: Node = hero.get_parent()
	var spot: Vector3 = hero._void.dark_spot
	SPEAR.frost_ring(parent, spot, MAW_RADIUS + 0.6, 0.25)
	ELEMENTS.nova(parent, spot, "water", MAW_RADIUS, 8)
	for e: Node3D in FOES.near(hero.get_tree(), spot, MAW_RADIUS + 0.5):
		encase(e)


## Black Ice lands: the frozen pool gives, and everyone in it shatters down into the floor.
static func _black_ice(hero: CharacterBody3D, b: Dictionary, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var spot: Vector3 = hero._void.dark_spot
	DARK.burst(parent, spot, 1.6)
	under(parent, spot, "water")
	for e: Node3D in FOES.near(hero.get_tree(), spot, MAW_RADIUS + 0.5):
		var at := _flat(e.global_position)
		Fx.shards(parent, at + Vector3.UP * 0.8, THROWN.CUBE_COLOR, 10, Vector3.UP, 8.0, 0.16, 0.5)
		e.take_hit(damage, Vector3.DOWN * BLACK_ICE_DOWN, 0.0, true)  # (frozen: x FREEZE_BREAK, and it shatters)
		Game.register_hit("breaker")
		ELEMENTS.spikes(parent, at, "water", 1.1, 4)
	ComicFx.hit(spot + Vector3.UP * 1.5, true)
	Game.shake(0.6)


## Cataclysm lands: everyone held comes down into the floor (a crater each), with lightning out of the sky and
## the earth up under each one. Anyone else near takes some and is thrown clear.
static func _cataclysm(hero: CharacterBody3D, b: Dictionary, at: Vector3, seized: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	for e: Node3D in seized:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var spot := _flat(e.global_position)
		e.take_hit(damage, Vector3.DOWN * CATACLYSM_DOWN, 0.0, true)
		Game.register_hit("breaker")
		ELEMENTS.storm_strike(parent, spot, "wind")
		under(parent, spot, "earth")
	for e: Node3D in FOES.near(hero.get_tree(), at, BREAK_AREA):
		if e in seized:
			continue
		var from := _flat(e.global_position - at)
		e.take_hit(damage * 0.6, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 5.0, BREAK_LAUNCH, true)
		Game.register_hit("breaker")
	_pop(parent, at, "hammer")
	Game.shake(0.7)


# --- Meteor Fall's beats (hero_leap phase 3) ------------------------------------------------------------------

## Beat 1, on the press: the tentacles rip them out of the lava and hurl them away from him, into the walls if
## there are walls to hit (thrown_foe: `wall_mult`, the splat). Big ones stay, and take the blow.
static func meteor_wall(hero: CharacterBody3D) -> void:
	var parent: Node = hero.get_parent()
	var void_grab: Node = hero._void
	if is_instance_valid(void_grab.undertow):
		void_grab.undertow._let_go()
	void_grab.release_seized()
	var at := _flat(hero.global_position)
	var power: float = hero._dmg_mult * hero._cast_power()
	var foes: Array = FOES.near(hero.get_tree(), at, METEOR_REACH)
	for e: Variant in void_grab.bound:  # (whoever Undertow chased off past the reach)
		if is_instance_valid(e) and e.is_alive() and not e in foes:
			foes.append(e)
	void_grab.pile = foes
	Game.hitstop(METEOR_BEAT_STOP)
	Game.sfx("hit_big", -2.0, 0.1)
	Game.shake(0.45)
	for i in foes.size():
		var e: Node3D = foes[i]
		THROWN.cut(e)
		var body: Variant = e.get("model")
		if body != null:
			body.position.y = 0.0  # (up out of the lava)
		if void_grab.is_heavy(e):
			e.take_hit(METEOR_WALL_DAMAGE * power, Vector3.ZERO, 0.0, true)
			Game.register_hit("breaker")
			continue
		var out := _flat(e.global_position - at)
		var dir: Vector3 = out.normalized() if out.length() > 0.3 else hero._brk_dir.rotated(Vector3.UP, TAU * i / maxf(foes.size(), 1.0))
		Fx.shards(parent, _flat(e.global_position) + Vector3.UP * 0.4, ELEMENTS.LOOK.earth.color, 6, Vector3.UP, 6.0, 0.14, 0.4)
		THROWN.launch(hero, e, _flat(e.global_position) + dir * METEOR_WALL_LENGTH, METEOR_WALL_DAMAGE * power,
			{"el": "earth", "solid": false, "tether": true, "speed": METEOR_WALL_SPEED, "land_y": 0.0, "wall_mult": METEOR_WALL_MULT})


## Is anyone in the pile still in the air from the last beat?
static func pile_flying(hero: CharacterBody3D) -> bool:
	for e: Variant in hero._void.pile:
		if is_instance_valid(e) and e.is_alive() and THROWN.flying(e):
			return true
	return false


## Beat 2: dark tentacles go out to everyone and drag them all into one pile, on the biggest if there's one
## that wouldn't fly, otherwise in front of him. Sets the dive's landing (hero._brk_zone) on the pile.
static func meteor_gather(hero: CharacterBody3D) -> void:
	var parent: Node = hero.get_parent()
	var void_grab: Node = hero._void
	var at := _flat(hero.global_position)
	var foes: Array = void_grab.pile.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.is_alive())
	for e: Node3D in FOES.near(hero.get_tree(), at, METEOR_REACH + METEOR_WALL_LENGTH):
		if not e in foes:
			foes.append(e)
	void_grab.pile = foes
	var dir: Vector3 = hero._brk_dir
	var pile: Vector3 = at + dir * minf(METEOR_PILE_AHEAD, hero._clear_ahead(dir, METEOR_PILE_AHEAD))
	var ring: float = METEOR_PILE_RING
	for e: Node3D in foes:
		if void_grab.is_heavy(e):
			pile = _flat(e.global_position)
			ring = float(e.radius) + METEOR_PILE_RING
			break
	var slot := 0
	var small: Array = foes.filter(func(e: Node3D) -> bool: return not void_grab.is_heavy(e))
	if small.size() == 1 and ring == METEOR_PILE_RING:
		ring = 0.0  # (one on its own: right where he lands)
	for e: Node3D in small:
		THROWN.cut(e)
		var a := TAU * slot / maxf(small.size(), 1.0)
		var to := pile + Vector3(sin(a), 0.0, cos(a)) * ring
		var speed: float = maxf(TIDE_SPEED, _flat(e.global_position - to).length() / METEOR_DRAG_TIME)
		DARK.burst(parent, _flat(e.global_position), 0.7)
		THROWN.launch(hero, e, to, 0.0, {"quiet": true, "solid": false, "tether": true, "el": "void", "speed": speed, "land_y": 0.0})
		slot += 1
	void_grab.dark_spot = pile
	hero._brk_zone = pile
	var to := pile - at
	if to.length() > 0.1:
		hero._brk_dir = to.normalized()
	Game.sfx("swing_heavy", -2.0, 0.1)


## Beat 3 lands: the meteor comes down on the pile, a crater under every one of them. Shields come off for good.
static func _meteor_pile(hero: CharacterBody3D, b: Dictionary, at: Vector3, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	for e: Node3D in FOES.near(hero.get_tree(), at, METEOR_PILE_R):
		var spot := _flat(e.global_position)
		THROWN.cut(e)
		if e.has_method("rip_shield"):
			e.rip_shield()
		e.take_hit(damage * (METEOR_HEAVY_MULT if hero._void.is_heavy(e) else 1.0), Vector3.DOWN * METEOR_DOWN, 0.0, true)
		Game.register_hit("breaker")
		Fx.shards(parent, spot + Vector3.UP * 0.9, ELEMENTS.LOOK.earth.color, 14, Vector3.UP, 10.0, 0.2, 0.7)
		ELEMENTS.spikes(parent, spot, "earth", CRYSTAL_SIZE, 4, 1.0)
	_pop(parent, at, "hammer")
	for i in METEOR_GEYSERS:
		var a := TAU * i / METEOR_GEYSERS
		ELEMENTS.geyser(parent, at + Vector3(sin(a), 0.0, cos(a)) * METEOR_GEYSER_OUT, GEYSER_RADIUS, GEYSER_HIGH, false)
	Fx.scorch(parent, at, ELEMENTS.LOOK.earth.color, METEOR_GEYSER_OUT * 1.6, 1.6)
	hero._void.pile = []
	Game.shake(0.8)


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
	if b.has("gather"):
		_meteor_pile(hero, b, at, mult)
		return
	if b.has("cataclysm"):
		_cataclysm(hero, b, at, seized, mult)
		return
	if b.has("black_ice"):
		_black_ice(hero, b, mult)
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
		under(parent, spot, b.erupt)
	for e: Node3D in FOES.near(hero.get_tree(), at, BREAK_AREA):
		if struck.has(e):
			continue
		var from := _flat(e.global_position - at)
		e.take_hit(damage * 0.6, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 5.0, BREAK_LAUNCH, true)
		Game.register_hit("breaker")
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
		DARK.quiet_hit(e, damage, true, Vector3.DOWN * MAW_DOWN)
		Game.register_hit("breaker")
	ComicFx.hit(spot + Vector3.UP * 1.5, true)  # one word for the one bite
	Game.shake(0.6)


## They've gone down through the floor (hero_leap._start_dive), and black spikes throw them back up.
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
	for e: Node3D in FOES.near(hero.get_tree(), mid, CRUSH_RADIUS):
		if not e in cubes:
			DARK.quiet_hit(e, damage * PRESS_NO_CUBE, true)
			Game.register_hit("breaker")
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
		e.take_hit(damage * (1.0 if hero._void.is_heavy(e) else RIP_SMALL_MULT), Vector3.DOWN * METEOR_DOWN, 0.0, true)
		Game.register_hit("breaker")
		under(parent, spot, "earth")
		Fx.shards(parent, spot + Vector3.UP * 0.9, ELEMENTS.LOOK.earth.color, 22, Vector3.UP, 12.0, 0.2, 0.8)
		_pop(parent, spot, "hammer")
		for o: Node3D in FOES.near(hero.get_tree(), spot, RIP_SPLASH):
			if o == e:
				continue
			var from := _flat(o.global_position - spot)
			o.take_hit(damage * 0.4, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 8.0, 0.0, true)
			Game.register_hit("breaker")
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
	return foes.size()


## Everything near `at` is hit and thrown out from it. Returns who.
static func _strike(hero: CharacterBody3D, at: Vector3, radius: float, damage: float, launch: float, big: bool) -> Array:
	var foes: Array = FOES.near(hero.get_tree(), at, radius)
	for e: Node3D in foes:
		var from := _flat(e.global_position - at)
		e.take_hit(damage, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 4.0, launch, big)
		Game.register_hit("cast")
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
