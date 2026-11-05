extends RefCounted
## Standing element effects fade when the next string's first hit lands (round 33, sleek; feel audit:
## the last string's floor sat under the new one): the frost spear's floor frost, dark pools, Reap's marks
## and the comic cracks. Each registers with `add(self)` and has `clear_standing()`, which fades only its
## look (what it does to foes runs on). ComicFx calls `watch(hero)` every frame; it reads the hero only:
## a string starts when he starts a move from no chain (`_chain_i` 0, not attacking: an opener, a dash
## stab out of a dash, the first move after a breaker), and its first hit is `_hits_done` going above 0.
## Effects born after the string started (its own) stay.
##   const STANDING := preload("res://scripts/standing_fx.gd")
##   STANDING.add(self)  # in _ready; then func clear_standing() -> void

const GROUP := "standing_fx"
const BORN := "standing_born"
const CLEAR_S := 0.15  # s an effect takes to fade once cleared

static var _was_idle := true  # last frame he was in no string
static var _start_ms := -1  # when the string waiting for its first hit started (-1: none waiting)
static var first_hit_frame := -1  # the process frame of the last string's first hit (hud.gd's found banner)


static func add(n: Node) -> void:
	n.add_to_group(GROUP)
	n.set_meta(BORN, Time.get_ticks_msec())


static func watch(hero: Node) -> void:
	if not "_chain_i" in hero or not "state" in hero:
		return
	var attacking: bool = hero.state == hero.State.ATTACK
	if _was_idle and attacking:
		_start_ms = Time.get_ticks_msec()
	_was_idle = hero._chain_i == 0 and not attacking and hero.state != hero.State.LEAP
	if _start_ms >= 0 and attacking and hero._hits_done > 0:
		first_hit_frame = Engine.get_process_frames()
		clear(hero.get_tree(), _start_ms)
		_start_ms = -1


## Fades every standing effect born before `before_ms`.
static func clear(tree: SceneTree, before_ms: int) -> int:
	var n := 0
	for e: Node in tree.get_nodes_in_group(GROUP):
		if int(e.get_meta(BORN, 0)) < before_ms and e.has_method("clear_standing"):
			e.remove_from_group(GROUP)
			e.clear_standing()
			n += 1
	return n
