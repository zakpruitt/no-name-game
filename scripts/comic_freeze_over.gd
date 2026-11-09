extends "res://scripts/comic_flat.gd"
## Black Ice's frozen pool:
##   ComicFreezeOver.pool(parent, spot, radius): Black Ice's press. A drawn rime loop over the dark pool
##     (designed_polish.loop "tell_pinned": straight cracks, glints), held in real time at most POOL_HOLD s until
##     shatter(), when his landing breaks it: the rime erodes away under an ice shatter and a frost mark.
##   ComicFreezeOver.shatter(parent, spot, radius): breaks the pool there (spawning one already grown if there is none).

const SELF := preload("res://scripts/comic_freeze_over.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const POLISH := preload("res://scripts/designed_polish.gd")
const D_POOL := 1.7  # the drawn rime's square, per metre of the pool's radius (the rime is ~0.46 of it round)
const D_POOL_ALPHA := 0.85
const GROUP := "comic_freeze_pool"
const POOL_HOLD := 2.2  # s at most before it melts on its own

var radius := 3.0
var _broke := -1.0  # _t it shattered at
var _loop: Node3D  # the frost floor over the pool


static func pool(parent: Node, spot: Vector3, r: float) -> Node3D:
	var f: Node3D = SELF.new()
	f.radius = r
	f.life = POOL_HOLD
	f.real_time = true
	f.add_to_group(GROUP)
	f.begin(parent, Vector3(spot.x, 0.0, spot.z))
	return f


static func shatter(parent: Node, spot: Vector3, r: float) -> void:
	var near: Node3D = null
	for f: Node in parent.get_tree().get_nodes_in_group(GROUP):
		var d := Vector2(f.global_position.x - spot.x, f.global_position.z - spot.z).length()
		if d < r and not f.is_queued_for_deletion() and f._broke < 0.0:
			near = f
	if near == null:
		near = pool(parent, spot, r)
		near._t = 3.0 / STEPS_PER_S  # (already grown)
	near.break_up()


## The frost floor breaks away: the ice ring and cold mist over it.
func break_up() -> void:
	_broke = _t
	life = _t + 0.3
	remove_from_group(GROUP)
	if is_instance_valid(_loop):
		_loop.erode_out(0.22)
	DESIGNED_EL.DESIGNED.ice_shatter(get_parent(), global_position + Vector3.UP * 0.5, clampf(radius / 2.5, 0.7, 1.3))
	DESIGNED_EL.frost_mark(get_parent(), global_position, clampf(radius / 1.6, 0.8, 1.6), 0.5)


func _build() -> void:
	_loop = POLISH.loop(self, "tell_pinned", radius * D_POOL, "water")
	_loop.set_alpha(D_POOL_ALPHA)
	_loop.offset(Vector3.UP * (DESIGNED_EL.DESIGNED.GROUND_LIFT + 0.02))  # (over the dark pool's own decal)
