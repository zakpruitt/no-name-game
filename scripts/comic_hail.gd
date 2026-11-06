extends "res://scripts/comic_flat.gd"
## Hailstorm's lift (Dash L H H H, ice into storm): a tight inked whirlwind under one frozen foe that carries it
## up. Its four bands run from the floor to the foe's feet every step, so the column stretches as the foe climbs,
## and three hail chips (ice palette, inked) whirl round the cube. Rides the foe, gone by 0.5 s; one per frozen foe
## in place of a full wind pillar each (a 3.5 m funnel per foe walled off the pile).
##   ComicHail.ride(parent, foe)

const SELF := preload("res://scripts/comic_hail.gd")
const LIFE := 0.5
const BANDS := 4
const SEGS := 12
const ARC := 1.4 * PI  # of each band's ring: the gap shows it turning
const TURN := 1.1  # rad a step
const BAND_W := 0.2  # m up the column (0.15 hid inside the 0.9 m cube)
const FOOT_R := 0.4  # m: the band at the floor
const TOP_R := 1.05  # m: the band under its feet, wider than the cube
const TOP := 0.35  # m over its feet the column reaches
const CHIPS := 3
const ORBIT := 0.8  # m round its middle
const CHIP := 0.16  # m

var foe: Variant
var _w: Dictionary
var _ice: Dictionary
var _turns := PackedFloat32Array()


static func ride(parent: Node, e: Variant) -> Node3D:
	if not is_instance_valid(e):
		return null
	var h: Node3D = SELF.new()
	h.foe = e
	h.life = LIFE
	h.begin(parent, e.global_position)
	return h


func _build() -> void:
	_w = PAL.of("air")  # fx-air: wind looks like air; lightning keeps the storm row
	_ice = PAL.of("water")
	for i in BANDS + CHIPS:
		_turns.append(_rng.randf() * TAU)


func _follow(_delta: float) -> void:
	if not is_instance_valid(foe):
		queue_free()
		return
	global_position = foe.global_position


func _draw(s: int) -> void:
	var k := _t / life
	var fade := clampf((k - 0.6) / 0.4, 0.0, 1.0)
	var floor_y := -global_position.y  # (local: the node sits at its feet)
	var top := maxf(TOP, floor_y + 1.0)
	for i in BANDS:  # bottom first
		var kk := (i + 0.5) / BANDS
		var y := lerpf(floor_y, top, kk)
		var r := lerpf(FOOT_R, TOP_R, kk)
		var turn := _turns[i] + s * TURN * (1.0 + 0.25 * i)
		if fade < 0.6:
			_band(y, r, BAND_W + PAL.LINE * 2.5, turn, PAL.fade(INK, 1.0 - fade))
		_band(y, r, BAND_W * (1.0 - 0.4 * fade), turn, PAL.fade(_w.body, 0.9 - 0.4 * fade))
		if fade <= 0.0:
			_band(y + BAND_W * 0.2, r, BAND_W * 0.35, turn + 0.3, _w.light)
	for i in CHIPS:  # hail riding the gale round the cube
		var a := _turns[BANDS + i] + s * 1.3 + TAU * i / CHIPS
		var c := Vector3(cos(a) * ORBIT, 0.55 + 0.35 * i, sin(a) * ORBIT)
		var ring := PackedVector3Array()
		for j in 3:
			ring.append(_screen(a * 2.0 + TAU * j / 3.0) * CHIP * (1.0 - 0.5 * fade))
		_outline(c, ring, PAL.LINE, PAL.fade(INK, 1.0 - fade))
		_fan(c, ring, _ice.hot, _ice.body)


## A ring lying flat at height `y` (local), `w` thick up the column, tapering to points at both ends (comic_gale).
func _band(y: float, r: float, w: float, turn: float, color: Color) -> void:
	for i in SEGS:
		var k0 := float(i) / SEGS
		var k1 := float(i + 1) / SEGS
		var a0 := turn + ARC * k0
		var a1 := turn + ARC * k1
		var w0 := w * 0.5 * sin(k0 * PI)
		var w1 := w * 0.5 * sin(k1 * PI)
		var p0 := Vector3(cos(a0) * r, y, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, y, sin(a1) * r)
		_tri(p0 + Vector3.UP * w0, p0 - Vector3.UP * w0, p1 + Vector3.UP * w1, color)
		_tri(p1 + Vector3.UP * w1, p0 - Vector3.UP * w0, p1 - Vector3.UP * w1, color)
