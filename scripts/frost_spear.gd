extends Node3D
## The spear he plants in the ground (L L, right click). Frost spreads out from it (unseen past the plant's stamp)
## and slows whoever's on it, and that's all it does until he slams down onto it (void_element._deep_freeze). Only
## one at a time. See docs/features/void-element.md.

const FOES := preload("res://scripts/foes.gd")
const GROUP := "frost_spear"
const RADIUS := 6.0  # m the frost reaches
const GROW := 0.6  # s to get there
const LIFE := 5.0  # s it stands, unless he sets it off
const TICK := 0.15  # s between slows
const SLOW := 0.45  # what foes' speed drops to
const SLOW_TIME := 0.5  # s the slow outlasts the last tick
const SHAFT_HIGH := 2.3  # m
const SHAFT_R := 0.13  # m
const TILT := 0.2  # radians it leans, a random way
const PAL := preload("res://scripts/fx_palette.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")  # the drawn shaft, frost cracks and the ice shatter
## No frost floor: a halftone disc ~5 m across filled a third of the frame under the dummies' feet. The plant is a
## ground stamp, the language of every other floor mark: a broken brush ring (designed_ink.shock) STAMP_R out and
## frost_mark cracks STAMP_MARK across, ~2.5 m, gone in about half a second. The spear standing is the tell; the slow
## still reaches RADIUS.
const DESIGNED_INK := preload("res://scripts/designed_ink.gd")
const STAMP_R := 1.25  # m
const STAMP_TIME := 0.45  # s
const STAMP_MARK := 1.5  # frost_mark size (its tile is 1.7 m at 1: the cracks reach ~2.2 m across)
## Round 51 (env-pieces, Frost Wall): planted on a grate or within FROST_WALL.REACH of one, the spear raises an ice wall
## on the grate's far edge from him (scripts/frost_wall.gd), if his element can (env_piece.usable).
const ENV_PIECE := preload("res://scripts/env_piece.gd")
const FROST_WALL := preload("res://scripts/frost_wall.gd")
const SPENT_INTO_WALL := 0.35  # s the spear stands before it melts into the Frost Wall it raised
## Ice-staff lane (2026-11-07): the way out. He walks (or dashes) off more than LEASH m from it for LEASH_S s and it
## shatters, so a spear he's done with doesn't stand its 5 s waiting to turn a press into a vault. LEASH is past the
## plant's own reach (void_element.SPEAR_PICK_REACH 7.5), so watching the frost spread never loses it.
const LEASH := 9.0
const LEASH_S := 1.0
## Ice-staff lane: a spear that ends (its LIFE, a new one, the leash, a Frost Wall, Anvil / Pinwheel) goes at once in a
## small frost pop (POP_SIZE of Deep Freeze's shatter), not the old 0.3 s melt: a standing or sinking spear after its
## string read as a weapon lying on the floor in the next string's frames (feel audit 2026-11-07d item 6).
const POP_SIZE := 0.45
var _away := 0.0  # s he has been past LEASH

var _t := 0.0
var _next_tick := 0.0
var _r := 0.0
var _gone := false
var _stuck: Node3D
var _hero: Node3D  # (the leash reads his distance every frame)


## Plants one at `spot`, in place of any already standing.
static func plant(parent: Node, spot: Vector3) -> Node3D:
	var old: Node3D = current(parent.get_tree())
	if old != null:
		old.melt()
	var s: Node3D = new()
	parent.add_child(s)
	s.global_position = Vector3(spot.x, 0.0, spot.z)
	if frost_wall(parent, s.global_position) != null:  # (round 51: on a grate the spear goes into the wall, so no vault
		s.get_tree().create_timer(SPENT_INTO_WALL, false).timeout.connect(s.melt)  # onto it; the wall is the payoff)
	return s


## Round 51: the Frost Wall, when the spear went in on or by a grate (env_piece.gd) and this hero has ice.
static func frost_wall(parent: Node, spot: Vector3) -> Node3D:
	if not ENV_PIECE.usable("grate", "frost_wall"):
		return null
	var grates: Array = ENV_PIECE.near(parent.get_tree(), "grate", spot, FROST_WALL.REACH)
	if grates.is_empty():
		return null
	var hero: Node3D = parent.get_tree().get_first_node_in_group("player")
	var from: Vector3 = hero.global_position if hero != null else spot - Vector3.FORWARD
	return FROST_WALL.raise(parent, grates[0], from)


## The one standing, or null.
static func current(tree: SceneTree) -> Node3D:
	for s: Node in tree.get_nodes_in_group(GROUP):
		return s
	return null


func _ready() -> void:
	add_to_group(GROUP)
	_hero = get_tree().get_first_node_in_group("player")
	_stuck = Node3D.new()
	add_child(_stuck)
	var lean := randf() * TAU
	DESIGNED_EL.spear(_stuck, SHAFT_HIGH, SHAFT_R)  # a faceted shaft with an ice point
	_stuck.rotation = Vector3(TILT * cos(lean), 0.0, TILT * sin(lean))
	_stuck.scale = Vector3(1.0, 0.1, 1.0)
	create_tween().tween_property(_stuck, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# frost cracking out and cold mist where it goes in
	DESIGNED_EL.frost_mark(get_parent(), global_position, STAMP_MARK, 0.6)
	DESIGNED_INK.shock(get_parent(), global_position, PAL.of("water").light, STAMP_R, STAMP_TIME)


func _physics_process(delta: float) -> void:
	if _gone:
		return
	_t += delta
	_r = RADIUS * smoothstep(0.0, GROW, _t)
	if _t >= _next_tick:
		_next_tick += TICK
		for e: Node3D in FOES.near(get_tree(), global_position, _r):
			if e.has_method("chill"):
				e.chill(SLOW_TIME, SLOW)
	if is_instance_valid(_hero) and FOES.to_flat(self, _hero).length() > LEASH:
		_away += delta
	else:
		_away = 0.0
	if _t >= LIFE or _away >= LEASH_S:
		melt()


## Frost cracking out to `radius` in one drawn beat (Deep Freeze going off).
static func frost_ring(parent: Node, spot: Vector3, radius: float, _time: float) -> void:
	DESIGNED_EL.frost_burst(parent, spot, radius)


## Gone without being used: time's up, another took its place, he walked off, or it went into a wall. A small frost
## pop and it's gone the same frame (POP_SIZE).
func melt() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(GROUP)
	if is_inside_tree():
		DESIGNED_EL.DESIGNED.ice_shatter(get_parent(), global_position + Vector3.UP * 0.9, POP_SIZE)
	queue_free()


## Gone in pieces: he slammed onto it.
func shatter() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(GROUP)
	DESIGNED_EL.DESIGNED.ice_shatter(get_parent(), global_position + Vector3.UP * 0.9, 1.0)
	queue_free()
