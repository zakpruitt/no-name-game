extends "res://scripts/comic_flat.gd"
## The improvisation tells: a small drawn loop on a foe for each crossover state it carries (VOID_ELEMENT.mark:
## the `x_buried` / `x_molten` / `x_skewered` / `x_charged` metas, good for ELEMENT_HOLD s of real time), so a
## player can read which dash route pays off on it. One node per foe holds a designed_polish.Loop per state
## (crust ring, flame licks, frost rime, crawling arcs), fading in over IN_S, out over the state's last FADE_S,
## and gone when none is left.
## The foe calls sync(self) every physics frame (enemy.gd); with no state metas it costs four has_meta calls.
##   const STATE_TELL := preload("res://scripts/comic_state_tell.gd")
##   STATE_TELL.sync(self)

const SELF := preload("res://scripts/comic_state_tell.gd")
const POLISH := preload("res://scripts/designed_polish.gd")
const STATES := ["buried", "molten", "skewered", "charged"]
const META := "x_tell"
const FADE_S := 0.4  # s: fades over its last
const IN_S := 0.12  # s: comes in over

var foe: Variant
var _born := {}  # state -> real s it showed
var _loops := {}  # state -> designed_polish.Loop


static func sync(e: Node3D) -> void:
	if not (e.has_meta("x_buried") or e.has_meta("x_molten") or e.has_meta("x_skewered") or e.has_meta("x_charged")) or e.has_meta(META):
		return
	if not _any(e):
		return
	var t: Node3D = SELF.new()
	t.foe = e
	t.life = 1.0e9
	t.real_time = true
	e.set_meta(META, true)
	t.begin(e, e.global_position)
	t.remove_from_group(STANDING.GROUP)  # (it outlasts the next string's first hit: that's its point)


static func left(e: Variant, state: String) -> float:
	return (int(e.get_meta("x_" + state, 0)) - Time.get_ticks_msec()) / 1000.0


static func _any(e: Variant) -> bool:
	for s: String in STATES:
		if left(e, s) > 0.0:
			return true
	return false


func clear_standing() -> void:
	pass


func _exit_tree() -> void:
	if is_instance_valid(foe) and foe.has_meta(META):
		foe.remove_meta(META)


func _follow(_delta: float) -> void:
	if not is_instance_valid(foe):
		queue_free()
		return
	global_position = foe.global_position
	if not _any(foe) or (foe.has_method("is_alive") and not foe.is_alive()):
		if foe.has_meta(META):
			foe.remove_meta(META)
		queue_free()


func _alpha(state: String) -> float:
	var l := left(foe, state)
	if l <= 0.0:
		_born.erase(state)
		return 0.0
	if not _born.has(state):
		_born[state] = _t
	var in_k := clampf((_t - float(_born[state])) / IN_S, 0.0, 1.0)
	return in_k * clampf(l / FADE_S, 0.0, 1.0)


func _draw(_s: int) -> void:
	if not is_instance_valid(foe):
		return
	for st: String in STATES:
		var al := _alpha(st)
		var l: Variant = _loops.get(st)
		if al > 0.0:
			if not is_instance_valid(l):
				l = POLISH.tell(self, st)
				_loops[st] = l
			l.set_alpha(al)
		elif is_instance_valid(l):
			l.queue_free()
			_loops.erase(st)
