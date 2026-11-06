extends "res://scripts/comic_flat.gd"
## Backdraft (L L H, Dash H H L: ice into storm), two pieces:
##   ComicBackdraft.blast(parent, spot): the gale off the axe hitting the spear: eight inked wind strokes burst out
##     of its foot round a small hot star, then two light rings of strokes; 0.3 s. Replaces the 2.6 m wind pillar
##     (the spear's own shatter throws its ice).
##   ComicBackdraft.haul(parent, foe, hand, skewered): the haul back to him. A see-through wind ribbon from the foe
##     to his hand (wind body to clear at his end, bowed), three speed strokes on the foe pointing his way, and for
##     the skewered the ice cracking off on the first frame. Rides the foe; 0.45 s. Replaces the lightning arcs
##     (a storm look on a wind move: three green zigzags across the frame).

const SELF := preload("res://scripts/comic_backdraft.gd")
const STROKES := 8
const CHEST := 0.9
const RIBBON_W := 0.16
const RIBBON_MAX := 2.6  # m of it out of the foe: a far foe's whole ribbon bowed into a loop across the frame
const BOW := 0.12  # of the length the ribbon bows sideways
const CHIPS := 4

var mode := "blast"
var foe: Variant
var hand := Vector3.ZERO  # world
var skewered := false
var _p: Dictionary
var _ice: Dictionary
var _turns := PackedFloat32Array()
var _bow_side := 1.0


static func blast(parent: Node, spot: Vector3) -> Node3D:
	var b: Node3D = SELF.new()
	b.mode = "blast"
	b.life = 0.3
	b.begin(parent, Vector3(spot.x, CHEST, spot.z))
	return b


static func haul(parent: Node, e: Variant, to: Vector3, was_skewered: bool) -> Node3D:
	if not is_instance_valid(e):
		return null
	var b: Node3D = SELF.new()
	b.mode = "haul"
	b.foe = e
	b.hand = to
	b.skewered = was_skewered
	b.life = 0.45
	b.begin(parent, e.global_position + Vector3.UP * CHEST)
	return b


func _build() -> void:
	_p = PAL.of("air")  # fx-air: wind looks like air; lightning keeps the storm row
	_ice = PAL.of("water")
	for i in STROKES + CHIPS:
		_turns.append(_rng.randf() * TAU)
	_bow_side = 1.0 if _rng.randf() < 0.5 else -1.0


func _follow(_delta: float) -> void:
	if mode != "haul":
		return
	if not is_instance_valid(foe):
		queue_free()
		return
	global_position = foe.global_position + Vector3.UP * CHEST


func _draw(s: int) -> void:
	var fade := clampf((_t / life - 0.55) / 0.45, 0.0, 1.0)
	if mode == "blast":
		if s == 0:
			var star := PackedFloat32Array([1.0, 0.7, 1.0, 0.7, 1.0, 0.7, 1.0, 0.7])
			_fan(Vector3.ZERO, _star_ring(star, 0.55, 0.35), HOT_CORE, PAL.fade(_p.light, 0.8))
		var out := 0.35 + 0.4 * mini(s, 2)  # (a burst at the spear, not leaves blown over the pile)
		for i in STROKES:
			var a := TAU * i / STROKES + _turns[0]
			var d := _screen(a)
			_wedge(d * out, d, 0.9, 0.24 + PAL.LINE * 2.0, PAL.fade(INK, 1.0 - fade))
			_wedge(d * (out + 0.03), d, 0.85, 0.2, PAL.fade(_p.body if s < 2 else _p.light, 1.0 - fade))
		return
	var to := hand - global_position
	var length := minf(to.length(), RIBBON_MAX)
	if length > 0.4:
		var d := to.normalized()
		var side := d.cross(_view).normalized() * _bow_side
		var pts := PackedVector3Array()
		var n := 7
		var reach := minf(1.0, 0.45 + 0.3 * s)  # the ribbon reaches out to him over the first steps
		for i in n:
			var k := float(i) / (n - 1) * reach
			pts.append(d * length * k + side * sin(k * PI) * length * BOW)
		_strip(pts, RIBBON_W + PAL.LINE * 2.0, PAL.LINE, PAL.fade(INK, 0.9 * (1.0 - fade)), PAL.fade(INK, 0.0))
		_strip(pts, RIBBON_W, 0.0, PAL.fade(_p.body, 0.85 * (1.0 - fade)), PAL.fade(_p.light, 0.0))
		for i in 3:  # speed strokes on it, pointing his way
			var off := side * (i - 1) * 0.35 - d * 0.6
			_wedge(off - d * 0.5, d, 1.0, 0.16, PAL.fade(_p.light, 1.0 - fade))
	if skewered and s <= 2:  # the ice going off it
		for i in CHIPS:
			var a := _turns[STROKES + i]
			var at := _screen(a) * (0.35 + 0.5 * s)
			var ring := PackedVector3Array()
			for j in 3:
				ring.append(_screen(a + s + TAU * j / 3.0) * 0.15)
			_outline(at, ring, PAL.LINE, INK)
			_fan(at, ring, _ice.hot, _ice.body)
