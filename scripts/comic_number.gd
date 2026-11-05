extends Node3D
## A comic damage number (Game.comic_style, from Fx.damage_number): one per foe, not one per hit. Hits on
## the same foe inside MERGE_S add into the number already up, which grows and pops again (overshoot,
## then settle) on each add, so a crowd being shredded shows a few chunky numbers instead of a cloud.
## Bangers, inked, with a red print-offset shadow like ComicFx's words; a big hit's number is larger,
## hot yellow with an orange outline inside the ink. It drifts away from the middle of the pile, on
## twos, and runs on real time like the words, so hitstop doesn't stall it.
##   ComicNumber.add(parent, foe.global_position, damage, big, foe)

const SELF := preload("res://scripts/comic_number.gd")
const FONT := preload("res://assets/fonts/Bangers-Regular.ttf")
const STEPS_PER_S := 12.0  # on twos
const MERGE_S := 0.32  # a hit this soon after the last one adds in (over the 0.25 s burn ticks)
const HOLD_S := 0.38  # up for this long after the last add (round 33, sleek: 0.5 stayed into the next beat)
const FADE_STEPS := 2  # then shrinks away over these
const POP := [1.5, 1.18]  # scale on the steps after an add, then 1
const FONT_SIZE := 96
const PIXEL := 0.0036  # (round 33, sleek: was 0.0042) m per font pixel: a 2-digit number about 0.4 m tall, 20 px at the game camera
const GROW_PER := 0.006  # more scale per point of the total
const GROW_MAX := 1.35
const BIG_SCALE := 1.2
const HEAD := 2.3  # m above the foe's feet
const OUT := 0.7  # m off the pile it starts
const DRIFT := 0.9  # m/s away from the pile
const RISE := 0.45  # m/s
const PILE_R := 3.0  # m: foes this close make the pile it leaves
const DODGE_PAD_PX := 6.0  # clear of the combo-name callout, PERFECT, the words and the breaker prompt by this
const DODGE_TRIES := 3
const OUTLINE_PX := 12  # round 33 (sleek): the ink line, at FONT_SIZE 96 (26 was a thick slab)
const INK := Color(0.012, 0.01, 0.02)
const PAPER := Color(1.0, 0.96, 0.84)
const PRINT := Color(0.9, 0.12, 0.04)  # the offset shadow (ComicFx.WORD_LOW)
const HOT := Color(1.0, 0.45, 0.05)
const HOT_CORE := Color(1.0, 0.86, 0.12)

static var _live := {}  # foe instance id -> number

var total := 0.0
var big := false
var _key := 0
var _since_add := 0.0
var _t := 0.0
var _step := -1
var _pop_from := 0  # step of the last add
var _base := Vector3.ZERO  # where it started
var _away := Vector3.RIGHT
var _dodge := Vector3.ZERO  # how far it has stepped aside off the callout and the words, kept as it drifts
var _reduced := false
var _front: Label3D
var _shadow: Label3D
var _last_us := 0


## A hit of `amount` on `foe` (null: no merging). Returns the number it went into.
static func add(parent: Node, pos: Vector3, amount: float, is_big: bool, foe: Object = null) -> Node3D:
	var key := foe.get_instance_id() if foe != null else 0
	if key != 0 and _live.has(key):
		var n: Node3D = _live[key]
		if is_instance_valid(n) and n._since_add < MERGE_S:
			n.add_hit(amount, is_big)
			return n
	var num: Node3D = SELF.new()
	parent.add_child(num)
	num.setup(pos, amount, is_big, key)
	if key != 0:
		_live[key] = num
	return num


func setup(pos: Vector3, amount: float, is_big: bool, key: int) -> void:
	top_level = true
	_key = key
	_reduced = Game.reduce_flashing
	_last_us = Time.get_ticks_usec()
	_shadow = _make(PRINT, INK, OUTLINE_PX, 0)
	_shadow.offset = Vector2(3.0, -4.0)
	_front = _make(PAPER, INK, OUTLINE_PX, 2)
	_away = _away_from_pile(pos)
	_base = pos + Vector3.UP * HEAD + _away * OUT
	global_position = _base
	add_hit(amount, is_big)


func _make(fill: Color, outline: Color, outline_px: int, priority: int) -> Label3D:
	var l := Label3D.new()
	l.font = FONT
	l.font_size = FONT_SIZE
	l.pixel_size = PIXEL
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.modulate = fill
	l.outline_modulate = outline
	l.outline_size = outline_px
	l.render_priority = priority + 1
	l.outline_render_priority = priority
	l.set_meta("no_ghost", true)
	add_child(l)
	return l


## Which way, flat, is out of the pile round `pos`: from the middle of the foes near it.
func _away_from_pile(pos: Vector3) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	if is_inside_tree():
		for e: Node3D in get_tree().get_nodes_in_group("enemies"):
			var d := e.global_position - pos
			d.y = 0.0
			if d.length() < PILE_R:
				sum += e.global_position
				n += 1
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var side := cam.global_basis.x if cam != null else Vector3.RIGHT
	side.y = 0.0
	var out := Vector3.ZERO
	if n > 1:
		out = pos - sum / n
		out.y = 0.0
	if out.length() < 0.2:  # alone, or the middle of the pile: off to a side
		out = side * (1.0 if randf() < 0.5 else -1.0)
	return out.normalized()


func add_hit(amount: float, is_big: bool) -> void:
	total += amount
	big = big or is_big
	_since_add = 0.0
	_pop_from = maxi(_step, 0)
	var text := str(roundi(total))
	_front.text = text
	_shadow.text = text
	if big:
		_front.modulate = HOT_CORE
		_front.outline_modulate = HOT
		_front.outline_size = 8
		_shadow.modulate = INK
		_shadow.outline_size = 20
		_shadow.offset = Vector2(2.0, -3.0)
	_step = -1  # redraw now
	_draw(_pop_from)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - _last_us) / 1000000.0
	_last_us = now
	tick(dt)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	_t += delta
	_since_add += delta
	var step := int(_t * STEPS_PER_S)
	var end_step := int((_t - _since_add + HOLD_S) * STEPS_PER_S)
	if step >= end_step + FADE_STEPS:
		if _live.get(_key) == self:
			_live.erase(_key)
		queue_free()
		return
	if step != _step:
		_draw(step)


func _draw(step: int) -> void:
	_step = step
	var s := float(step) / STEPS_PER_S
	var size := minf(1.0 + total * GROW_PER, GROW_MAX) * (BIG_SCALE if big else 1.0)
	var since := step - _pop_from
	if not _reduced and since >= 0 and since < POP.size():
		size *= POP[since]
	var end_step := int((_t - _since_add + HOLD_S) * STEPS_PER_S)
	if step >= end_step:
		size *= 0.7 if step == end_step else 0.4
	scale = Vector3.ONE * size
	var at := _base + _away * DRIFT * s + Vector3.UP * RISE * s
	_dodge += dodge(at + _dodge, size, _front.text.length(), ComicFx.text_blocks())
	global_position = at + _dodge


## How far to step a number at `at` (world) aside, in the screen plane, so its rect clears `blocks`:
## each try pushes it out of the block it overlaps most along the shorter way. Zero with no camera.
func dodge(at: Vector3, size: float, chars: int, blocks: Array[Rect2]) -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or blocks.is_empty() or cam.is_position_behind(at):
		return Vector3.ZERO
	var h_m := FONT_SIZE * PIXEL * size
	var half_m := Vector2((0.25 * chars + 0.2) * h_m, 0.5 * h_m)
	var px_per_m := (cam.unproject_position(at + cam.global_basis.x) - cam.unproject_position(at)).length()
	if px_per_m < 0.01:
		return Vector3.ZERO
	var c := cam.unproject_position(at)
	var half := half_m * px_per_m + Vector2.ONE * DODGE_PAD_PX
	var moved := Vector2.ZERO
	for i in DODGE_TRIES:
		var best := Vector2.ZERO
		for b: Rect2 in blocks:
			var d := c + moved - b.get_center()
			var over := half + b.size * 0.5 - d.abs()
			if over.x <= 0.0 or over.y <= 0.0:
				continue
			var push := Vector2(0.0, over.y * signf(d.y if d.y != 0.0 else 1.0))
			if over.x < over.y:
				push = Vector2(over.x * signf(d.x if d.x != 0.0 else 1.0), 0.0)
			if push.length() > best.length():
				best = push
		if best == Vector2.ZERO:
			break
		moved += best
	# Screen +y is down; the camera's up is world.
	return (cam.global_basis.x * moved.x - cam.global_basis.y * moved.y) / px_per_m
