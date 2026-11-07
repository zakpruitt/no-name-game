extends Node3D
## Frost Wall (round 51, env-pieces lane; docs/features/env-pieces.md): Frost Spear (L L H) planted on a grate, or
## within REACH of one, raises a real wall of ice along the grate's far edge (from where he stands) for LIFE s. It is
## on the walls' layer (a StaticBody3D, as main.gd's walls), so thrown_foe.clear_from stops on it and every wall ending
## gets a wall in the open: Slapshot shatters cubes on it, Pinwheel and Ricochet aim at it (env_target knows it as a
## wall), a foe splatted on it carries WALL_META, so Meteor Fall goes for it. One splat shatters it (SHATTER_AFTER s
## later, so the rest of a volley lands); otherwise it melts at LIFE. The look is the faceted ice block
## (designed_elements.ice_block / facet_material), no crystals.

const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const ENV := preload("res://scripts/env_target.gd")
const ENV_PIECE := preload("res://scripts/env_piece.gd")

const GROUP := "frost_wall"
const REACH := 1.0  # m from the spear to a grate that still raises it
const WIDTH := 6.0  # m (round 52: 4, the grate's edge, left a diagonal Harpoon row's ends in the open)
const HIGH := 2.5
const THICK := 0.7
const LIFE := 6.0  # s
const RISE := 0.18  # s it takes to come up
const MELT := 0.35  # s it takes to go
const SHATTER_AFTER := 0.25  # s after the first splat (game)
const BLOCKS := 4  # faceted blocks side by side make the wall
const SHATTER_MULT := 1.6  # round 52 (the proposal's Shatter): an ice cube splatting on it pays x this on the wall's mult
const ID := "frost_wall"

var grate: Node3D
var normal := Vector3.BACK  # flat, out of its face toward him
var spot := Vector3.ZERO  # where it stands (set by raise(), taken in _ready, before the wall registers)
var yaw := 0.0
var _t := 0.0
var _gone := false
var _shattering := false
var _body: StaticBody3D
var _look: Node3D
var _id := ""


## Raises one on `grate` for a spear planted at `spot` by him standing at `from`, in place of any standing. Returns it.
static func raise(parent: Node, g: Node3D, from: Vector3) -> Node3D:
	for old: Node in parent.get_tree().get_nodes_in_group(GROUP):
		old.melt()
	var w: Node3D = new()
	w.grate = g
	var c := Vector3(g.global_position.x, 0.0, g.global_position.z)
	var to := Vector3(c.x - from.x, 0.0, c.z - from.z)
	# the far side from him, square to his line (round 52: it follows his angle, so a row he gathers on the diagonal
	# meets it face on; it was the grate's edge along the axis he was most along)
	var out := to.normalized() if to.length() > 0.05 else Vector3.FORWARD
	var half: float = float(ENV_PIECE.PIECES.grate.size.x) * 0.5
	w.normal = -out
	w.spot = c + out * (half - THICK * 0.5)
	w.yaw = atan2(out.x, out.z)
	parent.add_child(w)
	return w


## The one standing, or null.
static func current(tree: SceneTree) -> Node3D:
	for w: Node in tree.get_nodes_in_group(GROUP):
		if not w.get("_gone"):
			return w
	return null


func _ready() -> void:
	add_to_group(GROUP)
	global_position = spot
	rotation.y = yaw
	_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, HIGH, THICK)
	shape.shape = box
	shape.position.y = HIGH * 0.5
	_body.add_child(shape)
	add_child(_body)
	_look = Node3D.new()
	add_child(_look)
	var r := WIDTH / BLOCKS * 0.5
	for i in BLOCKS:
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_ghost", true)
		var tall: bool = i == 1 or i == BLOCKS - 2
		mi.mesh = DESIGNED_EL.ice_block(r, HIGH * (1.0 if tall else 0.86))
		mi.position = Vector3((i - (BLOCKS - 1) * 0.5) * r * 2.0 * 0.92, HIGH * (0.5 if tall else 0.43), 0.0)
		mi.scale = Vector3(1.0, 1.0, THICK / (r * 2.0))
		mi.rotation.y = PI / 6.0
		_look.add_child(mi)
	_look.scale = Vector3(1.0, 0.05, 1.0)
	create_tween().tween_property(_look, "scale", Vector3.ONE, RISE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var env: Node = ENV.of(get_tree())
	if env != null:
		var side := normal.cross(Vector3.UP) * WIDTH * 0.5
		var face := global_position + normal * THICK * 0.5
		_id = env.add_wall_id(face - side, face + side, normal, ID)
	if is_instance_valid(grate):
		grate.set_meta(ENV_PIECE.STATE_META, "frosted")
	if DESIGNED.on():
		DESIGNED_EL.frost_mark(get_parent(), global_position, 2.2, 0.8)
		DESIGNED.dust(get_parent(), global_position, 1.4)
	ComicFx.say("KRRSSHK!", global_position + Vector3.UP * (HIGH + 0.4), 0.55)
	Game.shake(0.35)
	Game.sfx("cast_water", -4.0, 0.1)
	ENV_PIECE.played("frost_wall")


func _physics_process(delta: float) -> void:
	if _gone:
		return
	_t += delta
	if _t >= LIFE:
		melt()


## A thrown foe splatted on it (thrown_foe._burst): it shatters a beat later.
func splat() -> void:
	if _gone or _shattering:
		return
	_shattering = true
	var tw := create_tween()
	tw.tween_interval(SHATTER_AFTER)
	tw.tween_callback(shatter)


func shatter() -> void:
	if _gone:
		return
	if DESIGNED.on():
		for i in BLOCKS:
			DESIGNED.ice_shatter(get_parent(), global_transform * Vector3((i - (BLOCKS - 1) * 0.5) * WIDTH / BLOCKS, HIGH * 0.5, 0.0), 1.3)
	Game.sfx("hit_big", -4.0, 0.1)
	_go(0.08)


func melt() -> void:
	_go(MELT)


func _go(time: float) -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(GROUP)
	_body.queue_free()
	var env: Node = ENV.of(get_tree())
	if env != null and _id != "":
		env.remove(_id)
	if is_instance_valid(grate) and ENV_PIECE.state(grate) == "frosted":
		grate.set_meta(ENV_PIECE.STATE_META, "cold")
	var tw := create_tween()
	tw.tween_property(_look, "scale", Vector3(1.0, 0.02, 1.0), time)
	tw.tween_callback(queue_free)


## The Frost Wall a throw stopped on near `spot` going `dir`, or null.
static func struck(tree: SceneTree, spot: Vector3, dir: Vector3) -> Node3D:
	var w := current(tree)
	if w == null:
		return null
	var probe := Vector3(spot.x, 0.0, spot.z) + Vector3(dir.x, 0.0, dir.z).normalized() * 1.2
	var local: Vector3 = w.global_transform.affine_inverse() * probe
	return w if absf(local.x) <= WIDTH * 0.5 + 0.6 and absf(local.z) <= THICK * 0.5 + 1.2 else null
