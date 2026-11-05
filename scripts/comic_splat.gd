extends "res://scripts/comic_flat.gd"
## Meteor Fall's first two beats:
##   ComicSplat.watch(parent, flight, foe): rides one beat-1 throw (thrown_foe, kept untyped) and, if it ends on a
##     wall (its `_walled` flight got all the way), splats there: star(). A throw that lands in the open already
##     bursts in earth, and one cut short by beat 2 says nothing.
##   ComicSplat.star(parent, at, dir): the wall splat. A hot star flattened against the wall (wide across `dir`,
##     short along it), a thin ink line, four ink spatter strokes thrown back off the wall and a light rim, held two
##     steps then breaking up; 0.42 s. Sized for the x2 hit, so it outranks the throw's own small stars.
##   ComicSplat.pile_word(parent, foes, spot): once beat 2 has dragged them all in (none in flight, or PILE_LATE s),
##     the pile-up word over the pile (ComicFx.say, PILE_WORD). The landing's breaker word replaces it.

const SELF := preload("res://scripts/comic_splat.gd")
const SPLAT := 1.25  # m: the star's long half
const FLAT := 0.5  # of that along the throw (squashed on the wall)
const SPIKES := 9
const SPATTER := 4
const HOLD := 2  # steps
const CHEST := 0.9
const PILE_WORD := "DOGPILE!"
const PILE_SCALE := 0.62  # word scale (BREAKER_SCALE is 0.78: the landing's word is bigger)
const PILE_LATE := 0.6  # s
const PILE_HIGH := 1.2  # m over the pile

var mode := "star"
var dir := Vector3.FORWARD  # world, the throw's direction (into the wall)
var flight: Variant
var foe: Variant
var foes: Array = []
var _walled := false
var _arrived := false
var _spot := Vector3.ZERO
var _spikes := PackedFloat32Array()
var _spatter := []  # [angle offset, length]
var _p: Dictionary


static func watch(parent: Node, by: Variant, e: Variant) -> void:
	if not is_instance_valid(by) or not is_instance_valid(e):
		return
	var w: Node3D = SELF.new()
	w.mode = "watch"
	w.flight = by
	w.foe = e
	w.life = 2.0
	w.begin(parent, e.global_position)


static func star(parent: Node, at: Vector3, into: Vector3) -> Node3D:
	var s: Node3D = SELF.new()
	s.mode = "star"
	s.dir = into
	s.life = 0.42
	s.begin(parent, Vector3(at.x, CHEST, at.z))
	return s


static func pile_word(parent: Node, pile: Array, spot: Vector3) -> void:
	var w: Node3D = SELF.new()
	w.mode = "word"
	w.foes = pile
	w.life = PILE_LATE + 0.05
	w.begin(parent, spot)


func _build() -> void:
	_p = PAL.of("earth")
	for i in SPIKES:
		_spikes.append(_rng.randf_range(0.7, 1.15))
	for i in SPATTER:
		_spatter.append([(i - (SPATTER - 1) * 0.5) * 0.5 + _rng.randf_range(-0.15, 0.15), _rng.randf_range(0.5, 0.85)])


func _follow(_delta: float) -> void:
	if mode == "watch":
		if is_instance_valid(flight) and not flight.is_queued_for_deletion():
			_walled = bool(flight.get("_walled"))
			_arrived = float(flight.get("_gone")) >= float(flight.get("_length")) - 0.05
			var d: Variant = flight.get("_dir")
			if d != null:
				dir = d
			if is_instance_valid(foe):
				_spot = foe.global_position
			return
		if _walled and _arrived:
			SELF.star(get_parent(), _spot, dir)
		queue_free()
	elif mode == "word":
		for e: Variant in foes:
			if is_instance_valid(e) and e.has_meta("thrown_foe_flying") and _t < PILE_LATE:
				return
		ComicFx.say(PILE_WORD, global_position + Vector3.UP * PILE_HIGH, PILE_SCALE)
		queue_free()


func _draw(s: int) -> void:
	if mode != "star":
		return
	var along := _right * dir.dot(_right) + _up * dir.dot(_up)
	along = along.normalized() if along.length() > 0.05 else _up
	var across := along.cross(_view).normalized()
	var k := 1.0 if s < HOLD else 1.0 - 0.3 * (s - HOLD + 1)
	var ring := PackedVector3Array()
	var n := _spikes.size()
	for i in n * 2:
		var a := TAU * i / (n * 2)
		var r: float = (_spikes[i / 2] if i % 2 == 0 else 0.34) * SPLAT * k * (1.15 if s == 0 else 1.0)
		ring.append(across * cos(a) * r + along * sin(a) * r * FLAT)
	var wall := along * SPLAT * FLAT * 0.35  # (its middle sits a little into the wall)
	if s < HOLD + 1:
		for sp: Array in _spatter:  # ink thrown back off the wall
			var d := (-along).rotated(_view, sp[0])
			_wedge(wall + d * SPLAT * 0.35, d, SPLAT * float(sp[1]) * k, 0.12, INK)
	if s < HOLD:
		_outline(wall, ring, PAL.LINE, INK)
	var core: Color = HOT_CORE if s < HOLD else _p.light
	_fan(wall, ring, core, PAL.fade(_p.body if s < HOLD else _p.deep, 0.88))
	if s == 0:
		var inner := PackedVector3Array()
		for p in ring:
			inner.append(p * 0.45)
		_fan(wall, inner, _p.hot, PAL.fade(HOT_CORE, 0.9))
