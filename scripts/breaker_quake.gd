extends RefCounted
## The barbaric side of the combo breakers: the war cry as the window opens,
## the crater a landing smashes into the floor, and the element erupting round
## it on a PERFECT. Visual only; the damage lives in player.BREAKERS.
##   war_cry   a roar: a shockwave shell bursting off his chest + floor rings
##   crater    glowing cracks splitting out from the impact, a rim of floor
##             slabs heaved up and tilted outward, rubble thrown up, scorch
##   eruption  a ring of the element's strikes sweeping round the crater
##             (lightning, magma spikes, ice, spirit beams)
##   eruption_line  the same strikes marching down a line (the dash breaker)

const ELEMENTS := preload("res://scripts/elements.gd")
const CRACKS := 9  # crack lines per crater (at full radius)
const SLABS := 10  # floor slabs heaved up round the rim
const ERUPT := 8  # strikes in a perfect's eruption ring
const ERUPT_STEP := 0.035  # s between strikes as the ring sweeps round

static var _stone: StandardMaterial3D


## Plain dark floor stone for the slabs (earth uses its magma rock, water ice).
static func stone() -> StandardMaterial3D:
	if _stone == null:
		_stone = StandardMaterial3D.new()
		_stone.albedo_color = Color(0.3, 0.27, 0.25)
		_stone.roughness = 0.95
	return _stone


static func release() -> void:
	_stone = null


## The roar at `pos` (his chest): a see-through shell in `c` bursts outward
## and fades, with two floor rings under him.
static func war_cry(parent: Node, pos: Vector3, c: Color) -> void:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 16
	s.rings = 8
	var shell := ELEMENTS._mi(s, ELEMENTS.glow(Color(c.lerp(Color.WHITE, 0.3), 0.3), 1.2))
	parent.add_child(shell)
	shell.global_position = pos
	shell.scale = Vector3.ONE * 0.4
	var tw := shell.create_tween().set_parallel()
	tw.tween_property(shell, "scale", Vector3(4.2, 2.6, 4.2), 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(shell, "transparency", 1.0, 0.32).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(shell.queue_free)
	var floor_at := Vector3(pos.x, 0.0, pos.z)
	Fx.ring(parent, floor_at, Color(c, 0.9), 3.6, 0.3)
	Fx.ring(parent, floor_at, Color(1.0, 1.0, 1.0, 0.6), 2.2, 0.22)
	Fx.burst(parent, pos, c.lerp(Color.WHITE, 0.4), 16, 9.0, 0.12, 0.3, Vector3.UP, 180.0, 0.0, 0.4)


## A shockwave dome bursting out flat from an impact at `pos` (Stormfall):
## a low see-through shell racing out to `radius` and thinning away.
static func shockwave(parent: Node, pos: Vector3, c: Color, radius: float) -> void:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0  # (the full sphere's height; is_hemisphere keeps the top half)
	s.radial_segments = 20
	s.rings = 6
	s.is_hemisphere = true
	var dome := ELEMENTS._mi(s, ELEMENTS.glow(Color(c.lerp(Color.WHITE, 0.25), 0.35), 1.3))
	parent.add_child(dome)
	dome.global_position = Vector3(pos.x, 0.0, pos.z)
	dome.scale = Vector3(0.5, 0.6, 0.5)
	var tw := dome.create_tween().set_parallel()
	tw.tween_property(dome, "scale", Vector3(radius, 1.3, radius), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(dome, "transparency", 1.0, 0.3).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(dome.queue_free)


## The floor breaks under an impact at `pos`: cracks of `el`'s colour split out
## to `radius` and cool to soot, and (`rim`) slabs heave up round the edge and
## sink back. `big` (a perfect) throws more rubble and longer cracks.
static func crater(parent: Node, pos: Vector3, el: String, radius: float, rim := true, big := false) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	var c: Color = ELEMENTS.LOOK[el].color
	var hot := StandardMaterial3D.new()  # (same variant as ELEMENTS.glow, so no new shader)
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hot.cull_mode = BaseMaterial3D.CULL_DISABLED
	hot.albedo_color = Color(c.r * 2.4, c.g * 2.4, c.b * 2.4, 1.0)
	var n := maxi(int(round(CRACKS * clampf(radius / 3.4, 0.5, 1.3))), 4)
	var reach := radius * (1.15 if big else 0.95)
	var a0 := randf() * TAU
	for i in n:
		_crack(root, a0 + TAU * (i + randf_range(-0.25, 0.25)) / n, reach * randf_range(0.7, 1.0), hot)
	var cool := root.create_tween()  # (a material can't own a tween)
	cool.tween_interval(0.25)
	cool.tween_property(hot, "albedo_color", Color(0.12, 0.08, 0.07, 0.85), 0.7)
	cool.tween_property(hot, "albedo_color:a", 0.0, 0.5)
	if rim:
		var mat: Material = ELEMENTS.rock() if el == "earth" else (ELEMENTS.ice() if el == "water" else stone())
		var m := SLABS + (4 if big else 0)
		for i in m:
			_slab(root, a0 + TAU * (i + randf_range(-0.3, 0.3)) / m, radius * randf_range(0.5, 0.7), mat, big)
	var t := root.create_tween()
	t.tween_interval(1.6)
	t.tween_callback(root.queue_free)
	var rubble: Color = ELEMENTS.LOOK.earth.rock.lightened(0.25)
	Fx.shards(parent, root.global_position + Vector3.UP * 0.3, rubble, 26 if big else 16, Vector3.UP, 13.0 if big else 10.0, 0.3, 0.9)
	Fx.shards(parent, root.global_position + Vector3.UP * 0.2, c, 10, Vector3.UP, 9.0, 0.16, 0.6)
	Fx.dust(parent, root.global_position, 18 if big else 12, 1.2)
	Fx.scorch(parent, root.global_position, c, radius * 0.85, 1.6)


## One jagged crack: three glowing segments zigzagging out from the centre.
static func _crack(root: Node3D, ang: float, length: float, mat: Material) -> void:
	var at := Vector3.ZERO
	var dir_ang := ang
	var seg := length / 3.0
	for k in 3:
		dir_ang += randf_range(-0.45, 0.45)
		var d := Vector3(sin(dir_ang), 0.0, cos(dir_ang))
		var b := BoxMesh.new()
		b.size = Vector3(0.16 - k * 0.04, 0.05, seg)
		var mi := ELEMENTS._mi(b, mat)
		root.add_child(mi)
		mi.position = at + d * seg * 0.5 + Vector3.UP * 0.06
		mi.rotation.y = dir_ang
		mi.scale = Vector3(1.0, 1.0, 0.01)
		var tw := mi.create_tween()  # splits outward, segment after segment
		tw.tween_interval(k * 0.03)
		tw.tween_property(mi, "scale:z", 1.0, 0.05).set_ease(Tween.EASE_OUT)
		at += d * seg


## One floor slab heaved up at `dist` on `ang`, tilted outward, then sinking.
static func _slab(root: Node3D, ang: float, dist: float, mat: Material, big: bool) -> void:
	var h := randf_range(0.7, 1.2) * (1.25 if big else 1.0)
	var b := BoxMesh.new()
	b.size = Vector3(randf_range(0.5, 0.9), h, randf_range(0.18, 0.3))
	var mi := ELEMENTS._mi(b, mat)
	var pivot := Node3D.new()  # faces out from the centre; the slab tips outward on its X
	root.add_child(pivot)
	pivot.position = Vector3(sin(ang), 0.0, cos(ang)) * dist
	pivot.rotation.y = ang
	pivot.add_child(mi)
	mi.rotation = Vector3(randf_range(0.5, 0.9), 0.0, randf_range(-0.25, 0.25))
	mi.position.y = -h * 0.6
	var tw := mi.create_tween()
	tw.tween_property(mi, "position:y", h * 0.2, 0.07).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(randf_range(0.55, 0.8))
	tw.tween_property(mi, "position:y", -h * 0.6, 0.35).set_ease(Tween.EASE_IN)


## A PERFECT's answer from the element: ERUPT strikes sweep round a ring of
## `radius` at `pos`, starting `delay` s after the landing.
static func eruption(parent: Node, pos: Vector3, el: String, radius: float, delay := 0.08) -> void:
	var a0 := randf() * TAU
	for i in ERUPT:
		var ang := a0 + TAU * i / ERUPT
		var at := Vector3(pos.x, 0.0, pos.z) + Vector3(sin(ang), 0.0, cos(ang)) * radius
		var tw := parent.create_tween()
		tw.tween_interval(delay + i * ERUPT_STEP)
		tw.tween_callback(ELEMENTS.storm_strike.bind(parent, at, el))


## The same strikes marching down a line from `from` along `dir` (dash breaker).
static func eruption_line(parent: Node, from: Vector3, dir: Vector3, length: float, el: String, delay := 0.08) -> void:
	var n := clampi(int(length / 1.6), 3, 6)
	for i in n:
		var side := dir.cross(Vector3.UP).normalized() * (0.9 if i % 2 == 0 else -0.9)
		var at := Vector3(from.x, 0.0, from.z) + dir * (length * (i + 0.5) / n) + side
		var tw := parent.create_tween()
		tw.tween_interval(delay + i * ERUPT_STEP * 1.4)
		tw.tween_callback(ELEMENTS.storm_strike.bind(parent, at, el))
