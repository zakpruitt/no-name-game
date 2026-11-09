extends "res://scripts/comic_flat.gd"
## Meltdown (Dash L H H H L, storm into magma, up in the air), two pieces:
##   ComicMelt.swing(parent, at, fwd): the molten hammer's arc round him: the drawn brush slash in magma
##     (designed_fx.slash), 0.25 s.
##   ComicMelt.foe(parent, foe, frozen): rides one foe it hit down inside a small drawn fireball (Meteor Fall's,
##     D_FIREBALL of its size); if it was frozen, the ice bursts off it first; where it lands a magma burst and a
##     crack open on the floor. Not down in FALL_MAX s (held by the breaker's hang): it just goes. At most 0.7 s.

const SELF := preload("res://scripts/comic_melt.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const D_FIREBALL := 0.42
const D_SLASH_ARC := 220.0
const SWING_R := 1.7  # m: the crescent's radius round him
const CHEST := 0.8
const LANDED_Y := 0.35  # m: under this it's down
const SPLAT_LIFE := 0.4  # s after landing
const FALL_MAX := 0.3  # s: if it isn't down by then (held in the breaker's hang, a heavy foe) it just goes: no fireball hanging on

var mode := "foe"
var target: Variant
var frozen := false
var fwd := Vector3.FORWARD
var _landed := -1.0
var _shell: Node3D
var _d_started := false
var _d_landed := false


static func swing(parent: Node, at: Vector3, facing: Vector3) -> Node3D:
	var m: Node3D = SELF.new()
	m.mode = "swing"
	m.fwd = facing
	m.life = 0.25
	m.begin(parent, at)
	return m


static func foe(parent: Node, e: Variant, was_frozen: bool) -> Node3D:
	if not is_instance_valid(e):
		return null
	var m: Node3D = SELF.new()
	m.mode = "foe"
	m.target = e
	m.frozen = was_frozen
	m.life = FALL_MAX + SPLAT_LIFE
	m.begin(parent, e.global_position)
	return m


func _follow(_delta: float) -> void:
	if mode != "foe" or _landed >= 0.0:
		return
	if not is_instance_valid(target):
		queue_free()
		return
	global_position = target.global_position
	if _t >= FALL_MAX:
		queue_free()
		return
	if _t > 0.06 and target.global_position.y < LANDED_Y:
		_landed = _t
		life = _t + SPLAT_LIFE
		_step = -1


func _draw(_s: int) -> void:
	if mode == "swing":
		if not _d_started:
			_d_started = true
			var at := global_position
			DESIGNED.slash(get_parent(), Vector3(at.x, 0.0, at.z), fwd, SWING_R * 1.15, D_SLASH_ARC, "earth", false, 0.25, at.y)
		return
	if not _d_started:
		_d_started = true
		if frozen:
			DESIGNED.ice_shatter(get_parent(), global_position + Vector3.UP * CHEST, 0.75)
		_shell = DESIGNED_EL.meteor_shell(self, Vector3.DOWN)
		_shell.scale = Vector3.ONE * D_FIREBALL
		_shell.position = Vector3.UP * CHEST
	if _landed >= 0.0 and not _d_landed:
		_d_landed = true
		if is_instance_valid(_shell):
			_shell.queue_free()
		var foot := Vector3(global_position.x, 0.0, global_position.z)
		var b := DESIGNED.spawn(get_parent(), "magma_burst", foot, 1.9, "earth", DESIGNED.MAGMA_TIMES, Vector2(0.55, 1.0))
		b.real_until = 1
		var c := DESIGNED_EL._spawn(get_parent(), "magma_crack", Vector3(foot.x, DESIGNED.GROUND_LIFT, foot.z), DESIGNED_EL.CRACK_SIZE * 0.8,
			"earth", DESIGNED_EL.CRACK_TIMES, Vector2(0.6, 1.0))
		c.rotation.y = randf() * TAU
