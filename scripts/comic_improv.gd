extends "res://scripts/comic_flat.gd"
## The element matrix's payoffs (round 37, third pass; void_element.IMPROV, docs/features/element-matrix.md): one
## small one-beat tell per cell that says WHICH two elements met, each in the two palettes it joins (fx_palette),
## thin ink, see-through fills, gone by about 0.45 s of real time (it fires on the move's first hit, inside its hit
## stop). A ride tell follows the foe (launched, lifted or falling); the rest stay where it stood. LOOKS is the table:
##   frozen x storm   Gale Lift: two wind bands spin up round the cube, ice chips flung off them
##   frozen x dark    Shatter: a violet tear across the ice, plates flung out (one at the next foe it cuts)
##   buried x ice     Frozen In: ice plates close over its crack ring on the floor, three ice tips at its feet
##   buried x magma   Aftershock: two hot shock rings run out of the crater with its cracks, a drive stroke
##   buried x dark    Swallowed: a dark mouth on the floor closes its jaws over the crater
##   molten x storm   Firestorm: a wind band carrying ember streaks round it, an ember line to the next foe
##   molten x ice     Quench: a small steam puff over it, ice chips spilling, a hot star going out
##   molten x magma   Flare-up: a hot splat under it, three flame tongues licking up after it
##   molten x dark    Smother: a violet lid comes down on it, embers squirting out at its feet
##   skewered x ice   Ice Spreads: a frost line runs along the floor to the next foe, ice tips where it arrives
##   skewered x dark  Torn Off: the stake snaps in two halves and a void tear (comic_rip) as it's yanked
##   airborne x ice   Freeze Aloft: a burst of thin ice spikes round it in the air, a glint
##   airborne x magma Meteor Spike: an ember line falls through it into the floor, a hot dent where it lands
##   bound x storm    Torn Loose: the violet ropes snap and whip off its feet, wind strokes up
##   bound x ice      Frozen in the Dark: violet coils round its legs ice over, small plates at its feet
## Its word is ComicFx.IMPROV_WORDS[cell] (ComicFx.improv: said over the move's own word).
##   ComicImprov.spawn(parent, "frozen_x_void", foe, hero_spot, neighbour_or_null)

const SELF := preload("res://scripts/comic_improv.gd")
const RIP := preload("res://scripts/comic_rip.gd")
const CHEST := 0.9  # m up the foe: the screen layer's middle
const GRAVITY := 9.0  # m/s/s on flung chips (screen down)
## cell ("state_x_element", void_element.improvise's improv_paid keys) -> its look: life (real s), whether it rides
## the foe, and the two palettes (fx_palette) it joins.
const LOOKS := {
	"frozen_x_wind": {"name": "Gale Lift", "life": 0.42, "ride": true, "a": "air", "b": "water"},
	"frozen_x_void": {"name": "Shatter", "life": 0.42, "ride": false, "a": "void", "b": "water"},
	"buried_x_water": {"name": "Frozen In", "life": 0.45, "ride": false, "a": "water", "b": "earth"},
	"buried_x_earth": {"name": "Aftershock", "life": 0.42, "ride": false, "a": "earth", "b": "earth"},
	"buried_x_void": {"name": "Swallowed", "life": 0.45, "ride": false, "a": "void", "b": "earth"},
	"molten_x_wind": {"name": "Firestorm", "life": 0.42, "ride": true, "a": "air", "b": "earth"},
	"molten_x_water": {"name": "Quench", "life": 0.45, "ride": true, "a": "water", "b": "earth"},
	"molten_x_earth": {"name": "Flare-up", "life": 0.4, "ride": true, "a": "earth", "b": "earth"},
	"molten_x_void": {"name": "Smother", "life": 0.42, "ride": false, "a": "void", "b": "earth"},
	"skewered_x_water": {"name": "Ice Spreads", "life": 0.45, "ride": false, "a": "water", "b": "water"},
	"skewered_x_void": {"name": "Torn Off", "life": 0.35, "ride": false, "a": "void", "b": "water"},
	"airborne_x_water": {"name": "Freeze Aloft", "life": 0.38, "ride": true, "a": "water", "b": "water"},
	"airborne_x_earth": {"name": "Meteor Spike", "life": 0.42, "ride": true, "a": "earth", "b": "earth"},
	"bound_x_wind": {"name": "Torn Loose", "life": 0.4, "ride": true, "a": "air", "b": "void"},
	"bound_x_water": {"name": "Frozen in the Dark", "life": 0.45, "ride": false, "a": "water", "b": "void"},
}
const BAND_R := 0.62  # m: a band round a foe (a dummy is ~0.5 m across; the ice cube 0.9)
const BAND_W := 0.11
const CHIP := Vector2(0.11, 0.17)  # m: a flung chip's size
const PLATE := Vector2(0.17, 0.24)  # m: Shatter's ice plates
const DENT := 0.55  # m: Meteor Spike's dent
const JAW := 0.85  # m: Swallowed's mouth, half its width
const SHOCK := Vector2(0.5, 1.45)  # m: Aftershock's ring, start / end radius

var cell := ""
var foe: Variant  # (untyped: it may be freed mid-tell)
var to: Variant = null  # Vector3 (world) of the neighbour a chain reached, or null
var from := Vector3.ZERO  # world: the hero (Torn Off's pull)
var _look: Dictionary
var _a: Dictionary  # palettes
var _b: Dictionary
var _spot := Vector3.ZERO  # world, on the floor where it stood
var _bits := []  # [dir (screen), speed, size, spin, turn]
var _turn := 0.0
var _cracks := []
var _shape := PackedFloat32Array()


## The tell for `cell` on `e`. `toward` is the hero's spot; `next` the neighbour a chain jumped to (Vector3) or null.
static func spawn(parent: Node, which: String, e: Variant, toward: Vector3, next: Variant = null) -> Node3D:
	if not LOOKS.has(which) or not is_instance_valid(e):
		return null
	var f: Node3D = SELF.new()
	f.cell = which
	f.foe = e
	f.from = toward
	f.to = next
	f.life = float(LOOKS[which].life)
	f.real_time = true
	f.begin(parent, e.global_position + Vector3.UP * CHEST)
	if which == "skewered_x_void":
		RIP.spawn(parent, e, toward)  # (the tear as it's yanked: Tow Line's own rip shape)
	ComicFx.improv(which, e.global_position)
	return f


func _build() -> void:
	_look = LOOKS[cell]
	_a = PAL.of(_look.a)
	_b = PAL.of(_look.b)
	_spot = Vector3(foe.global_position.x, 0.0, foe.global_position.z)
	_turn = _rng.randf() * TAU
	var n: int = {"frozen_x_wind": 3, "frozen_x_void": 5, "molten_x_water": 4, "buried_x_earth": 2, "skewered_x_void": 2}.get(cell, 0)
	for i in n:
		var a := _turn + TAU * (i + _rng.randf_range(-0.2, 0.2)) / n
		if cell in ["molten_x_water", "buried_x_earth"]:  # (spilling sideways and up, not down through the floor)
			a = PI * 0.5 + (i - (n - 1) * 0.5) * 0.9 + _rng.randf_range(-0.15, 0.15)
		if cell == "skewered_x_void":  # the stake's two halves, flung across the way he pulls
			var pull := _angle(from - foe.global_position)
			a = pull + PI * 0.5 + PI * i
		_bits.append([_screen(a), _rng.randf_range(3.2, 4.6), _rng.randf_range(CHIP.x, CHIP.y), _rng.randf_range(-9.0, 9.0), _rng.randf() * TAU])
	if cell == "frozen_x_void" and to is Vector3:  # one plate flies at the foe the shards cut
		_bits[0][0] = (to - foe.global_position).normalized()
		_bits[0][1] = 6.0
	for i in 10:
		_shape.append(_rng.randf_range(0.88, 1.1))
	if cell in ["buried_x_earth", "airborne_x_earth", "buried_x_water"]:
		for i in 4:
			var a := _turn + TAU * (i + _rng.randf_range(-0.2, 0.2)) / 4.0
			var d := Vector2(cos(a), sin(a))
			_cracks.append(_jagged(d * 0.45, d * _rng.randf_range(1.0, 1.3), 0.2, 0.45))


func _follow(_delta: float) -> void:
	if _look.ride and is_instance_valid(foe):
		global_position = foe.global_position + Vector3.UP * CHEST


func _draw(s: int) -> void:
	var k := _t / life
	var a := clampf((1.0 - k) / 0.35, 0.0, 1.0)  # fades over its last third
	match cell:
		"frozen_x_wind": _gale_lift(s, k, a)
		"frozen_x_void": _shatter(s, k, a)
		"buried_x_water": _frozen_in(s, k, a)
		"buried_x_earth": _aftershock(s, k, a)
		"buried_x_void": _swallowed(s, k, a)
		"molten_x_wind": _firestorm(s, k, a)
		"molten_x_water": _quench(s, k, a)
		"molten_x_earth": _flare_up(s, k, a)
		"molten_x_void": _smother(s, k, a)
		"skewered_x_water": _ice_spreads(s, k, a)
		"skewered_x_void": _torn_off(s, k, a)
		"airborne_x_water": _freeze_aloft(s, k, a)
		"airborne_x_earth": _meteor_spike(s, k, a)
		"bound_x_wind": _torn_loose(s, k, a)
		"bound_x_water": _frozen_dark(s, k, a)


# --- The cells ---------------------------------------------------------------------------------------------

func _gale_lift(s: int, k: float, a: float) -> void:
	for i in 2:
		var h := -0.7 + 0.42 * i + 0.55 * k
		_band(Vector3.UP * h, BAND_R * (1.25 - 0.15 * i), _turn + s * 1.3 + PI * i, PI * 1.25, BAND_W, _a.body, a)
	_flung(s, a, _b)


func _shatter(s: int, _k: float, a: float) -> void:
	if s == 0:
		_star(Vector3.ZERO, 0.42, _a)
	if s <= 2:
		var tear := PackedVector3Array()
		var d := _screen(_turn)
		var side := _screen(_turn + PI * 0.5)
		for i in 5:
			tear.append(d * 1.0 * (i / 4.0 - 0.5) + side * (0.1 if i % 2 == 1 else -0.05))
		var w := 0.2 * (1.0 - 0.3 * s)
		_strip(tear, w + PAL.LINE * 2.0, PAL.LINE * 2.0, INK)
		_strip(tear, w, 0.0, _a.body, _a.light)
		_strip(tear, w * 0.3, 0.0, _a.hot)
	for i in _bits.size():
		var b: Array = _bits[i]
		var tt := (s + 1) / STEPS_PER_S
		var at: Vector3 = b[0] * (0.25 + float(b[1]) * tt) - _up * GRAVITY * tt * tt * 0.5 * (0.0 if i == 0 and to is Vector3 else 1.0)
		var r := _ring(PackedFloat32Array([1.0, 0.7, 0.95, 0.6]), lerpf(PLATE.x, PLATE.y, float(b[2] - CHIP.x) / (CHIP.y - CHIP.x)), float(b[4]) + float(b[3]) * tt)
		if i == 0 and to is Vector3 and s <= 2:  # the cut: a violet streak behind the plate it throws
			_wedge(at - b[0] * 0.9, b[0], 0.9, 0.12, PAL.fade(_a.light, a))
		_outline(at, r, PAL.LINE, PAL.fade(INK, a))
		_fan(at, r, PAL.fade(_b.light, a), PAL.fade(_b.body, 0.85 * a))


func _frozen_in(s: int, k: float, a: float) -> void:
	var c := _floor_c()
	_crack_ring(c, 0.95, a * 0.9)
	_layer()
	var grow := 0.6 if s == 0 else 1.0
	for i in 6:  # ice plates closing over it, inner edge to the crack ring
		var a0 := _turn + TAU * i / 6.0 + 0.025
		var a1 := _turn + TAU * (i + 1) / 6.0 - 0.025
		var inner := 0.22
		var outer := 1.1 * grow * _shape[i]  # (past the 0.9 m cube it freezes in: under it the plates never show)
		var ring := PackedVector2Array([Vector2(cos(a0), sin(a0)) * inner, Vector2(cos(a0), sin(a0)) * outer,
			Vector2(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5)) * outer * 1.08, Vector2(cos(a1), sin(a1)) * outer,
			Vector2(cos(a1), sin(a1)) * inner])
		var mid := Vector2(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5)) * (inner + outer) * 0.5
		var rim := PackedVector2Array()
		for p in ring:
			rim.append(p + (p - mid).normalized() * PAL.LINE)
		_floor_fan(c + mid, _less(rim, mid), PAL.fade(INK, 0.7 * a))
		_floor_fan(c + mid, _less(ring, mid), PAL.fade(_a.light, 0.9 * a), PAL.fade(_a.body, 0.75 * a))
	if s <= 3:  # three ice tips up at its feet
		for i in 3:
			var x := (i - 1) * 0.62
			var base := _local(_spot) + _right * x + Vector3.UP * 0.05 + Vector3.BACK * 0.45
			var h := (0.6 - absf(x) * 0.3) * (0.7 if s == 0 else 1.0)
			_tip(base, _up, h, 0.16, _a, a)


func _aftershock(s: int, k: float, a: float) -> void:
	var c := _floor_c()
	var hot := s < 2
	for pts: PackedVector2Array in _cracks:
		_floor_strip(_off(pts, c), 0.13 + PAL.LINE * 2.0, 0.0, PAL.fade(INK, a))
	for i in 2:  # two shock rings running out of the crater, the second a step behind
		var kk := clampf(k * 1.6 - i * 0.3, 0.0, 1.0)
		if kk <= 0.0 or kk >= 1.0:
			continue
		var r := lerpf(SHOCK.x, SHOCK.y * (1.0 - 0.25 * i), sqrt(kk))
		var w := 0.12 * (1.0 - kk) + 0.03
		_floor_loop(c, r, w + PAL.LINE * 2.0, PAL.fade(INK, a * (1.0 - kk)))
		_layer()
		_floor_loop(c, r, w, PAL.fade(_a.light if hot else _a.body, a * (1.0 - kk * 0.7)))
	_layer()
	for pts: PackedVector2Array in _cracks:
		_floor_strip(_off(pts, c), 0.09, 0.0, PAL.fade(_a.light if hot else _a.deep, a))
	if s == 0:  # the drive: one stroke down into it
		var top := _local(_spot) + Vector3.UP * 2.3
		_wedge(top, Vector3.DOWN, 1.4, 0.28, INK)
		_wedge(top + Vector3.DOWN * 0.04, Vector3.DOWN, 1.3, 0.18, _a.light)
	_flung(s, a, _b, 0.3)


func _swallowed(s: int, _k: float, a: float) -> void:
	var c := _floor_c()
	var gap: float = [0.55, 0.3, 0.08, 0.0, 0.0, 0.0][mini(s, 5)]
	if gap > 0.1:  # the crater it's closing on
		var hole := PackedVector2Array()
		for i in _shape.size():
			var ang := TAU * i / _shape.size()
			hole.append(Vector2(cos(ang) * JAW * 0.8, sin(ang) * gap * 1.2) * _shape[i])
		_floor_fan(c, hole, PAL.fade(_a.ink, a), PAL.fade(_a.deep, a))
		_layer()
	for side: float in [-1.0, 1.0]:  # the jaws: half-ellipses with teeth on their inner edge
		var jc := c + Vector2(0.0, side * (gap + 0.22))
		var ring := PackedVector2Array()
		var rim := PackedVector2Array()
		for i in 9:
			var ang := PI * i / 8.0
			var p := Vector2(-cos(ang) * JAW, side * sin(ang) * 0.42) + Vector2(0.0, -side * 0.22)
			ring.append(p)
			rim.append(p + Vector2(-cos(ang), side * sin(ang)).normalized() * PAL.LINE * 1.5)
		_floor_fan(jc, rim, PAL.fade(INK, a))
		_layer()
		_floor_fan(jc, ring, PAL.fade(_a.body, 0.9 * a), PAL.fade(_a.deep, 0.9 * a))
		for t in 4:  # teeth along the inner edge, pointing across the mouth
			var x := (t - 1.5) * JAW * 0.42
			var e := jc + Vector2(0.0, -side * 0.22)
			var tooth := PackedVector2Array([Vector2(x - 0.09, 0.0), Vector2(x, -side * 0.17), Vector2(x + 0.09, 0.0)])
			_floor_fan(e + Vector2(x, -side * 0.06), _less(tooth, Vector2(x, -side * 0.06)), PAL.fade(_a.hot, a))
	if gap <= 0.1:  # shut: a hot seam where it closed
		_layer()
		_floor_strip(PackedVector2Array([c + Vector2(-JAW * 0.9, 0.0), c, c + Vector2(JAW * 0.9, 0.0)]), 0.06, 0.06, PAL.fade(_a.light, a))


func _firestorm(s: int, _k: float, a: float) -> void:
	var c := Vector3.UP * -0.35
	var head := _turn + s * 1.4 + PI * 1.3
	_band(c, BAND_R * 1.2, head - PI * 1.3, PI * 1.3, BAND_W, _a.body, a)
	for i in 4:  # embers carried on the band, along it
		var ang := head - i * 0.55
		var p := c + Vector3(cos(ang), 0.0, sin(ang) * 0.9) * BAND_R * 1.2 + Vector3.UP * (0.12 + 0.1 * i)
		var tng := Vector3(-sin(ang), 0.0, cos(ang) * 0.9).normalized()
		_wedge(p - tng * 0.45, tng, 0.45, 0.12, PAL.fade(_b.light if i % 2 == 0 else _b.body, a))
	if to is Vector3 and s <= 2:  # the flames catching the next one: an ember line to it
		var end: Vector3 = _local(to) + Vector3.UP * CHEST
		var mid := end * 0.5 + Vector3.UP * 0.35
		var n := clampf((s + 1) / 2.0, 0.0, 1.0)
		var pts := PackedVector3Array([Vector3.ZERO, Vector3.ZERO.lerp(mid, n), mid.lerp(end, n)])
		_strip(pts, PAL.LINE * 2.0, 0.14 + PAL.LINE * 2.0, PAL.fade(INK, 0.0), INK)
		_strip(pts, 0.0, 0.14, PAL.fade(_b.body, 0.0), _b.body)
		_strip(pts, 0.0, 0.05, PAL.fade(_b.hot, 0.0), _b.hot)
		if s >= 1:
			_star(end, 0.3, _b)


func _quench(s: int, k: float, a: float) -> void:
	if s == 0:
		_star(Vector3.UP * -0.2, 0.36, _b)
	var puffs := []
	for i in 3:
		var x := (i - 1) * 0.3
		var at := Vector3.UP * (0.55 + 0.9 * k + (0.12 if i == 1 else 0.0)) + _right * x
		puffs.append([at, _ring(_shape, (0.22 + 0.06 * (1 - absi(i - 1))) * (1.0 + 0.5 * sqrt(k)))])
	for p: Array in puffs:
		_outline(p[0], p[1], PAL.LINE * 1.3, PAL.fade(INK, a))
	for p: Array in puffs:
		_fan(p[0], p[1], PAL.fade(Color(1, 1, 1), 0.95 * a), PAL.fade(Color(0.66, 0.76, 0.9), 0.85 * a))
	_flung(s, a, _a, -0.2)


func _flare_up(s: int, k: float, a: float) -> void:
	var c := _floor_c()
	if s <= 2:
		var star := _floor_star(0.7 if s == 0 else 0.85, 7)
		var rim := PackedVector2Array()
		for p in star:
			rim.append(p * (1.0 + PAL.LINE * 2.0 / 0.7))
		_floor_fan(c, rim, PAL.fade(INK, a))
		_layer()
		_floor_fan(c, star, PAL.fade(_a.hot if s == 0 else _a.light, a), PAL.fade(_a.body, 0.8 * a))
	var floor_p := _local(_spot) + Vector3.UP * 0.05
	for i in 3:  # three flame tongues licking up after it
		var x := (i - 1) * 0.36
		var h := (1.35 - absf(x)) * (0.75 if s == 0 else 1.0) * (1.0 - 0.4 * k)
		var pts := PackedVector3Array()
		for j in 4:
			var kk := j / 3.0
			pts.append(floor_p + _right * (x * (1.0 - kk * 0.4) + (0.09 if (j + s + i) % 2 == 0 else -0.09) * kk) + _up * h * kk)
		_strip(pts, 0.26 + PAL.LINE * 2.0, PAL.LINE, PAL.fade(INK, a))
		_strip(pts, 0.26, 0.0, PAL.fade(_a.body, 0.9 * a), PAL.fade(_a.light, a))
		_strip(pts, 0.08, 0.0, PAL.fade(_a.hot, a))


func _smother(s: int, k: float, a: float) -> void:
	var drop: float = [0.75, 0.3, 0.05, 0.0, 0.0, 0.0][mini(s, 5)]
	var c := _up * (0.25 + drop)
	var wide := 0.6 + 0.2 * (1.0 - drop)
	var lid := PackedVector3Array()
	for i in 9:  # a dome: an arc over the top, a flat bottom edge
		var ang := PI * i / 8.0
		lid.append(_right * cos(ang) * wide + _up * sin(ang) * 0.32 * (0.8 + drop * 0.3))
	lid.append(_right * -wide * 0.7 - _up * 0.06)
	lid.append(_right * wide * 0.7 - _up * 0.06)
	_outline(c, lid, PAL.LINE, PAL.fade(INK, a))
	_fan(c + _up * 0.05, _shifted(lid, -_up * 0.05), PAL.fade(_a.deep, 0.92 * a), PAL.fade(_a.body, 0.88 * a))
	_strip(PackedVector3Array([c + _right * -wide * 0.6 + _up * 0.22, c + _up * 0.32, c + _right * wide * 0.6 + _up * 0.22]), 0.05, 0.0, PAL.fade(_a.light, a))
	if s >= 1 and s <= 4:  # the embers it squeezes out at its feet
		var foot := -_up * 0.75
		for side: float in [-1.0, 1.0]:
			var d := (_right * side + _up * 0.25).normalized()
			_wedge(foot + d * (0.3 + 0.5 * k), d, 0.55, 0.15, PAL.fade(_b.light if s < 3 else _b.body, a))


func _ice_spreads(s: int, _k: float, a: float) -> void:
	var c := _floor_c()
	if not to is Vector3:  # nobody to spread to: a frost ring round it
		for i in 6:
			var ang := _turn + TAU * i / 6.0
			_tip(_local(_spot) + Vector3(cos(ang), 0.0, sin(ang)) * 0.7, _up, 0.4 * (0.7 if s == 0 else 1.0), 0.13, _a, a)
		return
	var end := Vector2(to.x - global_position.x, to.z - global_position.z)
	if _cracks.is_empty():
		_cracks.append(_jagged(c, end, 0.3, 0.35))
	var line: PackedVector2Array = _cracks[0]
	var n := clampf((s + 1) / 2.0, 0.0, 1.0)
	var shown := PackedVector2Array()
	for i in line.size():
		if float(i) / (line.size() - 1) <= n + 0.001:
			shown.append(line[i])
	if shown.size() >= 2:
		_floor_strip(shown, 0.3 + PAL.LINE * 2.0, 0.14 + PAL.LINE * 2.0, PAL.fade(INK, a))
		_layer()
		_floor_strip(shown, 0.3, 0.14, PAL.fade(_a.light, a), PAL.fade(_a.body, 0.85 * a))
	if n >= 1.0:  # ice tips up where it arrives
		var at := _local(to)
		for i in 3:
			var x := (i - 1) * 0.36
			_tip(at + _right * x + Vector3.UP * 0.05, _up, (0.5 - absf(x) * 0.4) * (0.7 if s == 2 else 1.0), 0.15, _a, a)


func _torn_off(s: int, _k: float, a: float) -> void:
	for b: Array in _bits:  # the stake's halves, spinning off
		var tt := (s + 1) / STEPS_PER_S
		var at: Vector3 = b[0] * (0.2 + float(b[1]) * tt) - _up * GRAVITY * tt * tt * 0.5
		var d := _screen(float(b[4]) + float(b[3]) * tt)
		var side := _screen(float(b[4]) + float(b[3]) * tt + PI * 0.5)
		var shard := PackedVector3Array([d * -0.32 - side * 0.07, d * -0.32 + side * 0.07, d * 0.34])
		_outline(at, shard, PAL.LINE, PAL.fade(INK, a))
		_fan(at, shard, PAL.fade(_b.light, a), PAL.fade(_b.body, 0.9 * a))


func _freeze_aloft(s: int, _k: float, a: float) -> void:
	var grow: float = [0.75, 1.1, 1.0, 0.9, 0.8][mini(s, 4)]
	for i in 7:
		var ang := _turn + TAU * i / 7.0
		var d := _screen(ang)
		var l := (0.6 + 0.3 * (_shape[i] - 0.88) / 0.22) * grow
		_tip(d * 0.32, d, l, 0.15, _a, a)
	if s >= 1 and s <= 2:  # a glint
		var g := _up * 0.55 + _right * 0.4
		_fan(g, _star_ring(PackedFloat32Array([1.0, 1.0, 1.0, 1.0]), 0.2, 0.18, PI * 0.25 * s), PAL.fade(_a.hot, a))


func _meteor_spike(s: int, _k: float, a: float) -> void:
	var c := _floor_c()
	var floor_p := _local(_spot) + Vector3.UP * 0.1
	if s <= 1:  # the ember line falling through it into the floor
		var top := Vector3.UP * 1.3
		var pts := PackedVector3Array([top, top.lerp(floor_p, 0.5), floor_p])
		_strip(pts, PAL.LINE * 2.0, 0.24 + PAL.LINE * 2.0, PAL.fade(INK, 0.0), INK)
		_strip(pts, 0.0, 0.24, PAL.fade(_a.body, 0.0), _a.light)
		_strip(pts, 0.0, 0.08, PAL.fade(_a.hot, 0.0), _a.hot)
	if s >= 1:  # the dent it lands in
		var hot := s < 3
		var size := DENT * (0.8 if s == 1 else 1.0)
		var ring := PackedVector2Array()
		var rim := PackedVector2Array()
		for i in _shape.size():
			var ang := TAU * i / _shape.size()
			var d := Vector2(cos(ang), sin(ang)) * _shape[i]
			ring.append(d * size)
			rim.append(d * (size + PAL.LINE * 2.5))
		for pts: PackedVector2Array in _cracks:
			_floor_strip(_off(pts, c), 0.12 + PAL.LINE * 2.0, 0.0, PAL.fade(INK, a))
		_floor_fan(c, rim, PAL.fade(INK, a))
		_layer()
		_floor_fan(c, ring, PAL.fade(_a.body if hot else _a.deep, a), PAL.fade(_a.light if hot else _a.deep, a))
		for pts: PackedVector2Array in _cracks:
			_floor_strip(_off(pts, c), 0.08, 0.0, PAL.fade(_a.light if hot else _a.deep, a))


func _torn_loose(s: int, k: float, a: float) -> void:
	var foot := _local(_spot) + Vector3.UP * 0.08
	var snap: float = [1.0, 0.75, 0.45, 0.25, 0.1, 0.0][mini(s, 5)]
	for i in 4:  # the ropes snapping off its feet, whipping out
		var ang := _turn + TAU * i / 4.0
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var reach := 1.1 * snap
		if reach < 0.08:
			continue
		var pts := PackedVector3Array([foot + out * 0.25, foot + out * (0.25 + reach * 0.5) + Vector3.UP * (0.3 + 0.2 * k),
			foot + out * (0.25 + reach) + Vector3.UP * (0.15 + 0.5 * k) + _right * (0.12 if (s + i) % 2 == 0 else -0.12)])
		_strip(pts, 0.14 + PAL.LINE * 2.0, PAL.LINE * 2.0, PAL.fade(INK, a))
		_strip(pts, 0.14, 0.02, PAL.fade(_b.body, a), PAL.fade(_b.light, a))
	if s <= 2:  # the gale tearing it up
		for i in 3:
			var x := (i - 1) * 0.42
			_wedge(_right * x + _up * (-0.5 + 0.3 * s - absf(x) * 0.3), _up, 0.9, 0.13, PAL.fade(_a.light, a))


func _frozen_dark(s: int, _k: float, a: float) -> void:
	var base := _local(_spot)
	for i in 2:  # coils round its legs, the ice running round them
		var c := base + Vector3.UP * (0.22 + 0.32 * i)
		var start := _turn + PI * i
		_band(c, BAND_R * (0.95 - 0.12 * i), start, PI * 1.6, BAND_W, _b.body, a)
		var ice := clampf((s + 0.5) / 2.0, 0.0, 1.0)
		if ice > 0.0:
			_band(c + Vector3.UP * 0.01, BAND_R * (0.95 - 0.12 * i), start, PI * 1.6 * ice, BAND_W * 0.75, _a.light, a, false)
	var fc := _floor_c()
	for i in 4:  # small ice plates at its feet
		var ang := _turn + TAU * (i + 0.5) / 4.0
		var d := Vector2(cos(ang), sin(ang))
		var mid := fc + d * 0.72
		var side := Vector2(-d.y, d.x)
		var plate := PackedVector2Array([d * -0.14 - side * 0.12, d * 0.16 - side * 0.08, d * 0.2 + side * 0.1, d * -0.12 + side * 0.13])
		var rim := PackedVector2Array()
		for p in plate:
			rim.append(p * (1.0 + PAL.LINE * 2.0 / 0.16))
		_floor_fan(mid, rim, PAL.fade(INK, a))
		_floor_fan(mid, plate, PAL.fade(_a.light, 0.9 * a), PAL.fade(_a.body, 0.8 * a))
	if s == 2 or s == 3:
		var g := base + Vector3.UP * 0.8 + _right * 0.45
		_fan(g, _star_ring(PackedFloat32Array([1.0, 1.0, 1.0, 1.0]), 0.18, 0.18, PI * 0.25 * s), PAL.fade(_a.hot, a))


# --- Shapes ------------------------------------------------------------------------------------------------

## An open swirl round it on the floor's plane, `h` (in `c`) up: clear at its tail, `w` m and solid at its head.
func _band(c: Vector3, r: float, a0: float, span: float, w: float, col: Color, a: float, ink := true) -> void:
	var pts := PackedVector3Array()
	for i in 10:
		var ang := a0 + span * i / 9.0
		pts.append(c + Vector3(cos(ang) * r, 0.0, sin(ang) * r * 0.9))
	if ink:
		_strip(pts, 0.0, w + PAL.LINE * 2.0, PAL.fade(INK, 0.0), PAL.fade(INK, a))
	_strip(pts, 0.0, w, PAL.fade(col, 0.0), PAL.fade(col, a))


## The chips in _bits, flung from its middle (`up` m) and falling.
func _flung(s: int, a: float, p: Dictionary, up := 0.0) -> void:
	var tt := (s + 1) / STEPS_PER_S
	for b: Array in _bits:
		var at: Vector3 = _up * up + b[0] * (0.3 + float(b[1]) * tt) - _up * GRAVITY * tt * tt * 0.5
		var r := _ring(PackedFloat32Array([1.0, 0.55, 0.9, 0.5]), float(b[2]), float(b[4]) + float(b[3]) * tt)
		_outline(at, r, PAL.LINE, PAL.fade(INK, a))
		_fan(at, r, PAL.fade(p.light, a), PAL.fade(p.body, 0.85 * a))


## A small hot star (first frame only, by the callers).
func _star(c: Vector3, size: float, p: Dictionary) -> void:
	var ring := _star_ring(PackedFloat32Array([1.0, 0.65, 1.0, 0.7, 0.95]), size, 0.34, _turn)
	_fan(c, ring, HOT_CORE, PAL.fade(p.body, 0.85))
	_outline(c, ring, PAL.LINE, INK)


## An ice tip from `base` along `d`, `h` m long and `w` wide at its root (ink line, light to body).
func _tip(base: Vector3, d: Vector3, h: float, w: float, p: Dictionary, a: float) -> void:
	var side := d.cross(_view).normalized()
	var tri := PackedVector3Array([side * -w * 0.5, d * h, side * w * 0.5])
	var mid := d * h * 0.3
	var rim := PackedVector3Array()
	for v in tri:
		rim.append(v + (v - mid).normalized() * PAL.LINE)
	_fan(base + mid, _shifted(rim, -mid), PAL.fade(INK, a))
	_fan(base + mid, _shifted(tri, -mid), PAL.fade(p.light, a), PAL.fade(p.body, 0.9 * a))


## An inked crack ring on the floor round `c` (the buried tell's shape), `r` m.
func _crack_ring(c: Vector2, r: float, a: float) -> void:
	_floor_loop(c, r, 0.1 + PAL.LINE * 2.0, PAL.fade(INK, a))
	_layer()
	_floor_loop(c, r, 0.1, PAL.fade(_b.deep, a))


## A closed floor ring round `c`, `r` m, `w` m wide.
func _floor_loop(c: Vector2, r: float, w: float, col: Color) -> void:
	var loop := PackedVector2Array()
	for i in _shape.size() + 1:
		var ang := TAU * i / _shape.size()
		loop.append(c + Vector2(cos(ang), sin(ang)) * r * _shape[i % _shape.size()])
	_floor_strip(loop, w, w, col)


## A floor star's ring, `size` m, `n` points.
func _floor_star(size: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n * 2:
		var ang := _turn + TAU * i / (n * 2)
		out.append(Vector2(cos(ang), sin(ang)) * size * (_shape[(i / 2) % _shape.size()] if i % 2 == 0 else 0.45))
	return out


## Where it stood, in the floor layer's local x / z.
func _floor_c() -> Vector2:
	return Vector2(_spot.x - global_position.x, _spot.z - global_position.z)


## A world point in the screen layer's local space.
func _local(world: Vector3) -> Vector3:
	return world - global_position


func _off(pts: PackedVector2Array, c: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p)
	return out


func _less(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p - by)
	return out


func _shifted(pts: PackedVector3Array, by: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for v in pts:
		out.append(v + by)
	return out
