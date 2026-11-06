extends Node3D
## Lightning conducted along the tentacles (round 44, "the tentacle conducts lightning and zaps everybody"):
## Live Wire's hang (void_grab.seize with `wire`) and Galvanize (H L L, void_element._galvanize).
##   1. Charge: it gathers at his claw (a star swelling, spikes drawn in) until the first pulse leaves: the anticipation.
##   2. Each pulse runs OUT along every tentacle's own curve (void_tendril.points(), the drawn spine, not a straight
##      line) at SPEED: a bright knot at its head, the authored bolt strip (designed_fx "bolt_strip") lit behind it
##      along the curve, the tentacle's body washed storm-light on twos while it carries the charge (void_tendril.electrify).
##      Nearer foes are reached first.
##   3. A foe is zapped on the frame the pulse reaches it (`on_zap`: the gameplay, so the number pops with the
##      flash): three short forks crackle off it (comic_bolt) and its coil lights.
##   4. When every tentacle has delivered, arcs jump on, nearest first, from the zapped to everyone no tentacle
##      holds (`find_jumps`, `on_jump`), each one a link further.
## Game time throughout: the hit stops and the breaker's slow motion hold it, as they hold the hits.
## Gameplay and look are one node so the damage lands as the pulse arrives; with no camera (headless) it draws
## nothing but still zaps.
##   var c := LIVE_CURRENT.start(hero, links, own)   # links: [{"foe": e, "tendril": t}]; own: draws its tentacles
##   c.on_zap = func(e, pulse): ...;  c.pulse()

const SELF := preload("res://scripts/live_current.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const COMIC_BOLT := preload("res://scripts/comic_bolt.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const PAL := preload("res://scripts/fx_palette.gd")

const SPEED := 34.0  # m/s a pulse runs out along a tentacle (5 m in ~0.15 s: two or three frames of a 12 fps film)
const CHARGE := 0.1  # s the claw gathers before the first pulse leaves it (the anticipation)
const LIT := 0.1  # s a tentacle stays lit along its whole length after its pulse arrives
const JUMP_STEP := 0.045  # s between the arcs that jump on from the zapped
const STEP_S := 1.0 / 12.0  # the strip boils and the tint flickers on twos
const TRAIL_W := 0.2  # m: the lit trail's bolt (the strip's body is about a third of its 2.6x height)
const HEAD_R := 0.36  # m: the bright knot at a pulse's head
const CLAW_R := 0.46  # m: the charge at his claw at its fullest
const POP_LEN := 0.8  # m: a fork off a zapped foe
const ARRIVE := 0.45  # m past a foe's radius from its chest: the pulse has reached it (the coil round it is where it goes in)
const LOST := 0.5  # s: a pulse whose tentacle never reached its foe zaps it anyway (no damage lost to a drawing)
const TINT := Color(0.82, 1.0, 0.76)  # the storm light the tentacle is washed in while it carries a pulse
const CHEST := Vector3(0.0, 0.9, 0.0)
const HOT_YELLOW := Color(1.0, 0.88, 0.25)  # (comic_flat HOT_CORE: the impact stars' core)
const ZAP_STOP := 0.035  # s hit stop on the first foe each pulse reaches (a staccato, not a stall)
## Own tentacles (Galvanize): out over SHOOT before the charge, back over RETRACT once the current is done.
const SHOOT := 0.08
const RETRACT := 0.1
const OWN_WAVE := 0.05

var hero: Node3D
var links := []  # [{foe, tendril}]: who a tentacle touches
var own := false  # draws (and frees) its own tentacles; Live Wire's are void_grab's, drawn by seized_tick
var on_zap := Callable()  # (foe, pulse index) when a pulse reaches a linked foe
var on_jump := Callable()  # (foe, from foe or null) when an arc jumps on to one no tentacle holds
var find_jumps := Callable()  # () -> Array of foes for the arcs, asked once per pulse as it delivers
var _pulses := []  # {t0, hit: {link i: true}, jumps: [], next_jump, from}
var _t := 0.0
var _first := 0.0  # when the first pulse may leave the claw
var _end_t := -1.0  # own: when the current finished (the tentacles draw back)
var _closing := false
var _trail_mi: MeshInstance3D
var _trail := ArrayMesh.new()
var _flat_mi: MeshInstance3D
var _flat := ArrayMesh.new()
var _fv := PackedVector3Array()
var _fc := PackedColorArray()
var _rng := RandomNumberGenerator.new()
var _cam: Camera3D


## A current on `links`. `own`: it draws its own tentacles from his claw (they arrive over SHOOT first).
static func start(by: Node3D, with: Array, own_tentacles := false) -> Node3D:
	var c: Node3D = SELF.new()
	c.hero = by
	c.links = with
	c.own = own_tentacles
	by.get_parent().add_child(c)
	return c


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_rng.randomize()
	_first = (SHOOT if own else 0.0) + CHARGE
	if own:
		for l: Dictionary in links:
			var t: Node3D = TENDRIL.new()
			add_child(t)
			l["tendril"] = t
	if DisplayServer.get_name() == "headless":
		return
	_cam = get_viewport().get_camera_3d()
	_trail_mi = _mesh_instance(_trail)
	_trail_mi.material_override = DESIGNED.material("bolt_strip") if DESIGNED.on() else null
	_trail_mi.set_instance_shader_parameter("pal_row", DESIGNED.row("wind"))
	_trail_mi.set_instance_shader_parameter("tiles", 1.0)
	_flat_mi = _mesh_instance(_flat)


func _mesh_instance(mesh: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.extra_cull_margin = 16.0
	add_child(mi)
	return mi


## Another pulse out of the claw (the first waits for the charge).
func pulse() -> void:
	_pulses.append({"t0": maxf(_t, _first), "hit": {}, "jumps": [], "asked": false, "next_jump": 0.0, "from": []})


## Stop: no more pulses; own tentacles draw back, then it frees itself. Live Wire's let go (release_seized) frees it.
func finish() -> void:
	_closing = true
	if not own:
		for l: Dictionary in links:
			if is_instance_valid(l.tendril):
				l.tendril.electrify(0.0)
		queue_free()


func _physics_process(delta: float) -> void:
	if _closing and not own:  # (let go: freed this frame, nothing more lands)
		return
	_t += delta
	if not is_instance_valid(hero):
		queue_free()
		return
	var hand: Vector3 = hero._void._hand_pos()
	if own:
		_draw_tentacles(hand)
	for l: Dictionary in links:
		l["path"] = _path(l)
	for p: Dictionary in _pulses:
		_run(p, hand)
	if own and _end_t < 0.0 and not _pulses.is_empty() and _pulses.all(func(p: Dictionary) -> bool: return _delivered(p)):
		_end_t = _t
	if own and _end_t >= 0.0 and _t > _end_t + LIT + RETRACT:
		queue_free()
		return
	_tint()
	if _cam != null:
		_draw(hand)


func _run(p: Dictionary, hand: Vector3) -> void:
	if _t < p.t0:
		return
	var run: float = (_t - p.t0) * SPEED
	var first: bool = p.hit.is_empty()
	for i in links.size():
		if p.hit.has(i):
			continue
		var l: Dictionary = links[i]
		if not _alive(l.foe):
			p.hit[i] = true
			continue
		var path: PackedVector3Array = l.path
		if path.is_empty() and _t - p.t0 < LOST:  # (the tentacle hasn't reached it yet)
			continue
		if run >= _length(path):
			p.hit[i] = true
			p.from.append(l.foe)
			_pop(l.foe)
			if first:
				first = false
				Game.hitstop(ZAP_STOP)
			if on_zap.is_valid():
				on_zap.call(l.foe, _pulses.find(p))
	if p.hit.size() < links.size():
		return
	if not p.asked:  # every tentacle has delivered: the arcs jump on
		p.asked = true
		p.next_jump = _t
		if find_jumps.is_valid():
			var linked: Array = links.map(func(l: Dictionary) -> Variant: return l.foe)
			p.jumps = find_jumps.call().filter(func(e: Variant) -> bool: return _alive(e) and not e in linked)
		var at: Vector3 = hand if p.from.is_empty() else (p.from[0] as Node3D).global_position
		p.jumps.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return (a.global_position - at).length_squared() < (b.global_position - at).length_squared())
	while not p.jumps.is_empty() and _t >= p.next_jump:
		var e: Variant = p.jumps.pop_front()
		p.next_jump += JUMP_STEP
		if not _alive(e):
			continue
		var src: Variant = _nearest(p.from, e.global_position)
		var a: Vector3 = (src.global_position + CHEST) if src != null else hand
		if _cam != null:
			COMIC_BOLT.spawn(get_parent(), a, e.global_position + CHEST, 0.2, 0.42)
		p.from.append(e)
		if on_jump.is_valid():
			on_jump.call(e, src)


func _delivered(p: Dictionary) -> bool:
	return p.asked and p.jumps.is_empty() and p.hit.size() >= links.size()


static func _alive(e: Variant) -> bool:
	return is_instance_valid(e) and e.is_alive()


func _nearest(from: Array, at: Vector3) -> Variant:
	var best: Variant = null
	var best_d := INF
	for o: Variant in from:
		if not is_instance_valid(o):
			continue
		var d: float = (o.global_position - at).length_squared()
		if d < best_d:
			best_d = d
			best = o
	return best


## The tentacle's drawn curve from his claw to where it reaches the foe (ARRIVE past its radius from the chest);
## the coil round it after that is where the charge goes in. Empty while the tentacle is in.
static func _path(l: Dictionary) -> PackedVector3Array:
	var t: Variant = l.get("tendril")
	if not is_instance_valid(t) or not _alive(l.foe):
		return PackedVector3Array()
	var pts: PackedVector3Array = t.points()
	var chest: Vector3 = l.foe.global_position + CHEST
	var r: float = float(l.foe.get("radius")) + ARRIVE if l.foe.get("radius") != null else ARRIVE
	for i in pts.size():
		if pts[i].distance_to(chest) <= r:
			return pts.slice(0, i + 1)
	return PackedVector3Array()


static func _length(pts: PackedVector3Array) -> float:
	var sum := 0.0
	for i in range(1, pts.size()):
		sum += pts[i].distance_to(pts[i - 1])
	return sum


## Galvanize's own tentacles: out to each linked foe, held while the current runs, drawn back after.
func _draw_tentacles(hand: Vector3) -> void:
	var reach := smoothstep(0.0, SHOOT, _t)
	if _end_t >= 0.0:
		reach = 1.0 - smoothstep(_end_t + LIT, _end_t + LIT + RETRACT, _t)
	for l: Dictionary in links:
		if not is_instance_valid(l.tendril):
			continue
		if not _alive(l.foe):
			l.tendril.visible = false
			continue
		l.tendril.draw(hand, l.foe.global_position + CHEST, reach, OWN_WAVE, float(l.foe.radius) * 0.9 if reach >= 1.0 else 0.0, _t)


## Each tentacle carrying a pulse (or just delivered one) flickers storm-bright; the rest keep a low crackle.
func _tint() -> void:
	for i in links.size():
		var t: Variant = links[i].tendril
		if not is_instance_valid(t):
			continue
		var k := 0.0
		if _t < _first:
			k = 0.25 * clampf(_t / _first, 0.0, 1.0)
		for p: Dictionary in _pulses:
			if _t < p.t0:
				continue
			var run: float = (_t - p.t0) * SPEED
			var length := _length(links[i].get("path", PackedVector3Array()))
			var arrived: float = p.t0 + length / SPEED
			if run < length or _t - arrived < LIT:
				k = 1.0
			elif not _closing:
				k = maxf(k, 0.3)
		var on := int(_t / STEP_S) % 2 == 0  # (a flicker on twos)
		t.electrify(k * (0.8 if on else 0.45), TINT)


# --- The look ------------------------------------------------------------------------------------------------------

func _draw(hand: Vector3) -> void:
	_fv.clear()
	_fc.clear()
	var step := int(_t / STEP_S)
	_rng.seed = step * 7919 + get_instance_id()
	var view := _cam.global_basis.z
	var right := _cam.global_basis.x
	var up := _cam.global_basis.y
	var tv := PackedVector3Array()
	var tu := PackedVector2Array()
	var ti := PackedInt32Array()
	if _t < _first or (_pulses.is_empty() and not _closing):  # the charge gathering at his claw
		_claw(hand, clampf(_t / maxf(_first, 0.01), 0.0, 1.0), right, up)
	for p: Dictionary in _pulses:
		if _t < p.t0:
			continue
		var run: float = (_t - p.t0) * SPEED
		if run < 0.06 * SPEED:  # the claw flashes as each pulse leaves it
			_claw(hand, 0.7, right, up)
		for i in links.size():
			var l: Dictionary = links[i]
			if not is_instance_valid(l.tendril) or not l.tendril.visible:
				continue
			var path: PackedVector3Array = l.get("path", PackedVector3Array())
			var length := _length(path)
			var arrived: float = p.t0 + length / SPEED
			var to := run
			if run >= length:
				if _t - arrived >= LIT:
					continue
				to = length
			else:
				_head(_along(path, run), right, up)
			_trail_strip(path, to, view, tv, tu, ti)
	_commit(_flat, _fv, _fc, FORM_FX.material())
	_trail.clear_surfaces()
	if tv.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = tv
	arrays[Mesh.ARRAY_TEX_UV] = tu
	arrays[Mesh.ARRAY_INDEX] = ti
	_trail.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not DESIGNED.on():
		_trail.surface_set_material(0, FORM_FX.material())
	_trail_mi.set_instance_shader_parameter("frame", float(step % 4))
	_trail_mi.set_instance_shader_parameter("scroll", float(step) * 0.37)
	_trail_mi.set_instance_shader_parameter("erode", 0.0)


## The point `d` metres along the curve's straight part.
static func _along(pts: PackedVector3Array, d: float) -> Vector3:
	var n := pts.size()
	for i in range(1, n):
		var seg := pts[i].distance_to(pts[i - 1])
		if d <= seg:
			return pts[i - 1].lerp(pts[i], d / maxf(seg, 0.0001))
		d -= seg
	return pts[n - 1]


## The bolt strip along the tentacle's curve from his claw to `to` metres out: the tentacle lit behind the pulse.
## UV.x runs in strip tiles (one tile is TRAIL_W x 2.6 x DESIGNED.BOLT_TILE long), so the zigzags keep their shape.
func _trail_strip(pts: PackedVector3Array, to: float, view: Vector3, tv: PackedVector3Array, tu: PackedVector2Array, ti: PackedInt32Array) -> void:
	var n := pts.size()
	if n < 2 or to <= 0.05:
		return
	var w := TRAIL_W * 2.6
	var tile := w * DESIGNED.BOLT_TILE
	var line := PackedVector3Array([pts[0]])
	var d := 0.0
	for i in range(1, n):
		var seg := pts[i].distance_to(pts[i - 1])
		if d + seg >= to:
			line.append(pts[i - 1].lerp(pts[i], (to - d) / maxf(seg, 0.0001)))
			break
		d += seg
		line.append(pts[i])
	var base := tv.size()
	var u := 0.0
	for i in line.size():
		var a := line[maxi(i - 1, 0)]
		var b := line[mini(i + 1, line.size() - 1)]
		var across := (b - a).cross(view)
		across = across.normalized() if across.length() > 0.0001 else Vector3.RIGHT
		if i > 0:
			u += line[i].distance_to(line[i - 1]) / tile
		var taper := 0.6 if i == 0 else 1.0
		tv.append_array([line[i] + across * w * 0.5 * taper, line[i] - across * w * 0.5 * taper])
		tu.append_array([Vector2(u, 1.0), Vector2(u, 0.0)])
	for i in line.size() - 1:
		var k := base + i * 2
		ti.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])


## The bright knot at a pulse's head: a storm-green halo round an inked hot-yellow star with a white core, so the
## head stands out from the green strip it leaves lit behind it.
func _head(at: Vector3, right: Vector3, up: Vector3) -> void:
	var turn := _rng.randf() * TAU
	var p: Dictionary = PAL.of("wind")
	_star(at, HEAD_R * 1.45, 0.35, turn + 0.4, right, up, PAL.fade(p.body, 0.8))
	_star(at, HEAD_R + PAL.LINE, 0.42, turn, right, up, p.ink)
	_star(at, HEAD_R, 0.42, turn, right, up, HOT_YELLOW)
	_star(at, HEAD_R * 0.45, 0.6, turn, right, up, p.hot)


## The charge at his claw, `k` 0..1: a star swelling and four spikes drawn in towards it.
func _claw(at: Vector3, k: float, right: Vector3, up: Vector3) -> void:
	var p: Dictionary = PAL.of("wind")
	var r := CLAW_R * (0.35 + 0.65 * k)
	var turn := _rng.randf() * TAU
	for i in 4:
		var a := turn + TAU * i / 4.0
		var d := right * cos(a) + up * sin(a)
		var far := lerpf(1.3, 0.55, k)
		_wedge(at + d * far, -d, far - r * 0.6, 0.07, p.light)
	_star(at, r + PAL.LINE, 0.4, turn, right, up, p.ink)
	_star(at, r, 0.4, turn, right, up, p.body)
	_star(at, r * 0.6, 0.5, turn, right, up, HOT_YELLOW)
	_star(at, r * 0.3, 0.6, turn, right, up, p.hot)


## A zapped foe: three short forks crackle off its chest.
func _pop(e: Node3D) -> void:
	if _cam == null:
		return
	var at := e.global_position + CHEST
	var right := _cam.global_basis.x
	var up := _cam.global_basis.y
	var turn := _rng.randf() * TAU
	for i in 2:  # (three per foe per pulse were a scribble over the pile)
		var a := turn + PI * i + _rng.randf_range(-0.4, 0.4)
		COMIC_BOLT.spawn(get_parent(), at, at + (right * cos(a) + up * sin(a)) * POP_LEN, 0.14)


func _star(at: Vector3, r: float, inner: float, turn: float, right: Vector3, up: Vector3, c: Color) -> void:
	var n := 8
	var ring := PackedVector3Array()
	for i in n * 2:
		var a := turn + TAU * i / (n * 2)
		var rr := r * (_rng.randf_range(0.8, 1.15) if i % 2 == 0 else inner)
		ring.append(at + (right * cos(a) + up * sin(a)) * rr)
	for i in ring.size():
		_fv.append_array([at, ring[i], ring[(i + 1) % ring.size()]])
		_fc.append_array([c, c, c])


func _wedge(p: Vector3, d: Vector3, length: float, w: float, c: Color) -> void:
	var side := d.cross(_cam.global_basis.z).normalized()
	_fv.append_array([p + side * w, p - side * w, p + d * length])
	_fc.append_array([c, c, c])


func _commit(mesh: ArrayMesh, v: PackedVector3Array, c: PackedColorArray, mat: Material) -> void:
	mesh.clear_surfaces()
	if v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
