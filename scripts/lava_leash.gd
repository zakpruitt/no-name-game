extends Node3D
## Lava Leash (L L L H L, dark-magma lane; docs/features/void-element.md "Crossovers"): magma into dark. Molten Palm
## shoved them along its lava line; a tentacle per foe that palm hit (VOID_ELEMENT.leash_targets, nearest first), each
## in four beats:
##   1. reach: it leaves his claw STAGGER s after the last and whips out to the foe in REACH + REACH_PER_M s a metre;
##   2. latch: it coils round the foe (on_latch: the hit, the palm's shove cut) and starts to glow with the lava;
##   3. drag: along the floor, never lifted, from where it was to its slot in the pile at his feet, accelerating
##      (DRAG_EASE) in DRAG_MIN..DRAG_MAX s, a lava seam opening behind it (the `lava_seam` strip: hot, then cooling
##      down the magma ramp and eroding from its old end); on_arrive(foe, metres) as it slams into the pile;
##   4. eruption: when the last one is in, the seam erupts under the pile (on_erupt(pile), the `leash_burst` sheet, a
##      lava pool) and the tentacles stay coiled on them, cooling, through the breaker's hang (Hellseam is `no_hold`),
##      until he lands (let_go) or HOLD s pass.
## Big ones are latched where they stand (arrive at once, 0 m). Gameplay and look are one node (the foe is moved by it,
## so nothing else may: thrown_foe's FLYING meta). Game time, so hit stops hold it. Headless it draws nothing but drags.
##   var g := LAVA_LEASH.start(hero, [{"foe": e, "to": slot, "heavy": false}, ...], pile)
##   g.on_latch = func(e): ...;  g.on_arrive = func(e, metres): ...;  g.on_erupt = func(pile_foes): ...

const SELF := preload("res://scripts/lava_leash.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const DRAG_SHADER := preload("res://shaders/designed_drag.gdshader")
const FLOURISH := preload("res://scripts/env_flourish.gd")  # round 53: brazier_spill (a seam by a lit brazier tips it)

const STAGGER := 0.03  # s between tentacles leaving his claw (Galvanize 0.035, Harpoon 0.02)
const REACH := 0.04  # s out to a foe beside him...
const REACH_PER_M := 0.005  # ...and this much more a metre (a wall 10 m off: 0.09 s, a whip you can see go)
const WAVE := 0.07  # the reach's whip
const DRAG_SPEED := 60.0  # m/s the drag averages...
const DRAG_MIN := 0.12  # s, at the least...
const DRAG_MAX := 0.18  # s, at the most: a far one comes faster, so the pile is in (and erupted) before his leap
const DRAG_EASE := 1.7  # k^ease: it starts slow off the wall and slams into the pile
const HOP := 0.18  # m it bounces off the floor at the drag's middle
const HOLD := 1.0  # s the tentacles stay on after the eruption with no breaker
const LET_GO := 0.1  # s they draw back
const CHEST := Vector3(0.0, 0.85, 0.0)
const ANKLE := Vector3(0.0, 0.25, 0.0)  # where the coil holds the pile once it has erupted
const FLYING := "thrown_foe_flying"  # (thrown_foe.FLYING)
const LAVA := Color(1.0, 0.42, 0.08)  # the tentacle's glow as it drags through the lava
const HEAT := 0.75  # how far the glow goes at the drag's end
const SEAM_STEP := 0.22  # m between the seam's points
const SEAM_W := 0.62  # m across (the strip's banks fill ~0.7 of it)
const SEAM_TILE := 1.4  # m of seam one tile of the strip covers
const SEAM_LIFE := 2.2  # s a stretch of seam lasts (it cools and erodes from its old end)
const SEAM_LIFT := 0.062  # m over the floor (designed_fx.GROUND_LIFT is 0.065: the pool sits on it)
const BURST_SIZE := 4.4  # m: the eruption's quad (its tongues stand ~2.5 m over the pile, over the foes' heads)
const BURST_TIMES := [0.05, 0.08, 0.09, 0.1, 0.11, 0.12, 0.14]
const POOL_R := 1.25  # m: the pool the pile stands in
const SPURT_FROM := 0.7  # the magma spurt where a foe is torn away from (designed_elements.spikes size)
const META := "lava_leash"  # meta on the hero: the leash in play (seams(), let_go())

const SHEETS := {
	"lava_seam": {"grid": Vector2(1, 4), "frames": 4, "kind": "ribbon", "burn": 1.0},
	"leash_burst": {"grid": Vector2(4, 2), "frames": 7, "kind": "sprite_depth", "anchor": Vector2(0.0, -0.3), "burn": 1.0},
}

var hero: CharacterBody3D
var pile := Vector3.ZERO
var grabs := []  # {foe, to, heavy, t0, reach, from, metres, drag, latched, arrived, arrive_t, tendril, seam: [{pos, dist, t}]}
var on_latch := Callable()  # (foe) the tentacle arrives: the hit
var on_arrive := Callable()  # (foe, metres) it lands in the pile
var on_erupt := Callable()  # (foes) the last is in: the seam goes up under them
var bind: Node  # the floor_bind on the pile (void_element sets it in on_erupt)
var _t := 0.0
var _erupted := false
var _erupt_t := 0.0
var _left := false  # let go: the tentacles drawing back
var _left_t := 0.0
var _leapt := false  # he went up for the breaker (the hold lasts until he lands)
var _seam_mi: MeshInstance3D
var _seam_mesh: ImmediateMesh
static var _registered := false
static var _seam_mat: ShaderMaterial


static func register() -> void:
	if _registered:
		return
	_registered = true
	for n: String in SHEETS:
		var s: Dictionary = SHEETS[n].duplicate()
		s["tex"] = load("res://assets/vfx/designed/%s.png" % n)
		DESIGNED.extra_sheets[n] = s


## Draw every material once at real size (elements.prewarm).
static func prewarm(root: Node3D) -> void:
	register()
	var burst := MeshInstance3D.new()
	burst.mesh = QuadMesh.new()
	burst.material_override = DESIGNED.material("leash_burst")
	root.add_child(burst)
	burst.scale = Vector3.ONE * 20.0
	var seam := MeshInstance3D.new()
	seam.mesh = QuadMesh.new()
	seam.material_override = seam_material()
	root.add_child(seam)
	seam.scale = Vector3.ONE * 20.0


## The seam's strip on the drag line's shader (designed_drag: each vertex's age in COLOR.r cools it and erodes it).
static func seam_material() -> ShaderMaterial:
	if _seam_mat == null:
		register()
		var m := ShaderMaterial.new()
		m.shader = DRAG_SHADER
		m.set_shader_parameter("sheet", DESIGNED.sheet_of("lava_seam").tex)
		m.set_shader_parameter("palette", DESIGNED.palette())
		m.set_shader_parameter("palette_rows", float(DESIGNED.ROWS.size()))
		m.set_shader_parameter("burn_hot", 1.0)
		m.set_shader_parameter("rows", 4.0)
		m.set_shader_parameter("cool", 0.55)
		_seam_mat = m
	return _seam_mat


static func start(by: CharacterBody3D, with: Array, at: Vector3) -> Node3D:
	var old: Variant = by.get_meta(META) if by.has_meta(META) else null
	if is_instance_valid(old):
		old.release()
	var g: Node3D = SELF.new()
	g.hero = by
	g.pile = at
	var me := Vector3(by.global_position.x, 0.0, by.global_position.z)
	for i in with.size():
		var one: Dictionary = with[i].duplicate()
		var foe: Node3D = one.foe
		var d := Vector3(foe.global_position.x, 0.0, foe.global_position.z).distance_to(me)
		one.t0 = i * STAGGER
		one.reach = REACH + REACH_PER_M * d
		one.latched = false
		one.arrived = false
		one.arrive_t = 0.0
		one.metres = 0.0
		one.drag = DRAG_MIN
		one.seam = []
		g.grabs.append(one)
	by.get_parent().add_child(g)
	by.set_meta(META, g)
	return g


## The seams the leash in play dragged its foes down: [[where it was taken from, its slot in the pile], ...] (flat).
static func seams(by: Node) -> Array:
	var g: Variant = by.get_meta(META) if by.has_meta(META) else null
	if not is_instance_valid(g):
		return []
	var out := []
	for one: Dictionary in g.grabs:
		if one.latched and float(one.metres) > 0.5:
			out.append([one.from, one.to])
	return out


## Hellseam has landed: the tentacles let go and the bind with them.
static func let_go(by: Node) -> void:
	var g: Variant = by.get_meta(META) if by.has_meta(META) else null
	if is_instance_valid(g):
		g.release()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for one: Dictionary in grabs:
		one.tendril = TENDRIL.new()
		add_child(one.tendril)
	if DisplayServer.get_name() != "headless":
		_seam_mesh = ImmediateMesh.new()
		_seam_mi = MeshInstance3D.new()
		_seam_mi.mesh = _seam_mesh
		_seam_mi.material_override = seam_material()
		_seam_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_seam_mi.set_meta("no_ghost", true)
		_seam_mi.extra_cull_margin = 20.0
		add_child(_seam_mi)
		_seam_mi.set_instance_shader_parameter("pal_row", DESIGNED.row("earth"))


## The tentacles let go (Hellseam landed, or the hold is over); the seams stay to cool.
func release() -> void:
	if _left:
		return
	_left = true
	_left_t = _t
	for one: Dictionary in grabs:  # (anyone still on the way lands in the pile now)
		if one.latched and not one.arrived and _alive(one.foe):
			_arrive(one)
		_unfly(one)
	if is_instance_valid(bind) and bind.has_method("_let_go"):
		bind._let_go()


## Who it has in the pile now (alive, landed).
func piled() -> Array:
	return grabs.filter(func(one: Dictionary) -> bool: return one.arrived and _alive(one.foe)).map(
		func(one: Dictionary) -> Node3D: return one.foe)


func _physics_process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(hero) or hero._void == null:
		release()
		queue_free()
		return
	var hand: Vector3 = hero._void._hand_pos()
	if hero.state == hero.State.LEAP:
		_leapt = true
	elif _leapt and _erupted and not _left:
		release()  # (he's down: a missed window or a dash out of it)
	if _erupted and not _left and not _leapt and _t - _erupt_t > HOLD:
		release()
	var all_in := true
	for one: Dictionary in grabs:
		var e: Variant = one.foe
		var tendril: Node3D = one.tendril
		if not _alive(e):
			tendril.visible = false
			_unfly(one)
			continue
		var local: float = _t - one.t0
		var out := 1.0
		if _left:
			out = 1.0 - smoothstep(0.0, LET_GO, _t - _left_t)
		if local < 0.0:
			tendril.visible = false
			all_in = false
			continue
		if local < one.reach:  # 1. reach
			tendril.draw(hand, (e as Node3D).global_position + CHEST, smoothstep(0.0, one.reach, local) * out, WAVE, 0.0, _t)
			all_in = false
			continue
		if not one.latched:  # 2. latch
			_latch(one)
		var coil: float = float(e.radius) + 0.05
		var dragging: float = local - one.reach
		if not one.arrived and dragging < one.drag:  # 3. drag
			var k: float = pow(clampf(dragging / one.drag, 0.0, 1.0), DRAG_EASE)
			var at: Vector3 = (one.from as Vector3).lerp(one.to, k) + Vector3.UP * HOP * sin(k * PI)
			(e as Node3D).global_position = at
			e.velocity = Vector3.ZERO
			_seam_add(one, Vector3(at.x, 0.0, at.z))
			tendril.draw(hand, at + CHEST, out, 0.03, coil, _t)
			tendril.electrify(HEAT * k, LAVA)
			all_in = false
			continue
		if not one.arrived:
			_arrive(one)
		var cool := 0.0 if not _erupted else clampf((_t - _erupt_t) / 0.3, 0.0, 1.0)
		tendril.electrify(HEAT * (1.0 - cool * 0.7), LAVA)
		var grip := CHEST.lerp(ANKLE, cool)  # (once the seam erupts the coil slides down to the legs: the burst reads over it)
		tendril.draw(hand, (e as Node3D).global_position + grip, out, 0.02, (coil * lerpf(1.0, 0.75, cool)) if out > 0.5 else 0.0, _t)
	if all_in and not _erupted:
		_erupt()
	_seam_draw()
	if _left and _t - _left_t > maxf(LET_GO, SEAM_LIFE):
		queue_free()


func _latch(one: Dictionary) -> void:
	one.latched = true
	var e: Node3D = one.foe
	if on_latch.is_valid():
		on_latch.call(e)  # (cuts the palm's shove first: then it's ours to move)
	one.from = Vector3(e.global_position.x, 0.0, e.global_position.z)
	one.metres = 0.0 if one.heavy else (one.from as Vector3).distance_to(one.to)
	one.drag = clampf(DRAG_MIN + float(one.metres) / DRAG_SPEED, DRAG_MIN, DRAG_MAX)
	if one.heavy:
		_arrive(one)
		return
	e.set_meta(FLYING, true)
	_seam_add(one, one.from)
	if float(one.metres) > 2.0:  # torn away: lava spurts where it stood
		DESIGNED_EL.spikes(get_parent(), one.from, "earth", SPURT_FROM, 1, 0.5)


func _arrive(one: Dictionary) -> void:
	one.arrived = true
	one.arrive_t = _t
	var e: Node3D = one.foe
	if not one.heavy:
		e.global_position = one.to
		e.velocity = Vector3.ZERO
		_unfly(one)
	if on_arrive.is_valid():
		on_arrive.call(e, float(one.metres))


func _erupt() -> void:
	_erupted = true
	_erupt_t = _t
	var foes := piled()
	if on_erupt.is_valid() and not foes.is_empty():
		on_erupt.call(foes)
	if not is_inside_tree():
		return
	register()
	var parent := get_parent()
	var mid := pile
	if not foes.is_empty():
		mid = Vector3.ZERO
		for e: Node3D in foes:
			mid += Vector3(e.global_position.x, 0.0, e.global_position.z)
		mid /= foes.size()
	DESIGNED_EL.pool(parent, mid, POOL_R)
	var fx: Node3D = DESIGNED.spawn(parent, "leash_burst", mid, BURST_SIZE * (1.0 + 0.08 * maxi(foes.size() - 1, 0)), "earth",
		BURST_TIMES, Vector2(0.55, 1.0))
	fx.real_until = 1
	fx.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	var cam := get_viewport().get_camera_3d()
	if cam != null:  # stood behind the pile from the camera (depth tested: the foes read in front of the tongues)
		var away := mid - cam.global_position
		fx.global_position += Vector3(away.x, 0.0, away.z).normalized() * 0.5


func _seam_add(one: Dictionary, at: Vector3) -> void:
	var pts: Array = one.seam
	if not pts.is_empty():
		var last: Dictionary = pts[-1]
		var run: float = at.distance_to(last.pos)
		if run < SEAM_STEP:
			return
		pts.append({"pos": at, "dist": float(last.dist) + run, "t": _t})
	else:
		pts.append({"pos": at, "dist": 0.0, "t": _t})
	FLOURISH.leash_seam(hero, at, one.get("from", at), one.to)  # (round 53: a brazier by the seam tips into it)


func _seam_draw() -> void:
	if _seam_mesh == null:
		return
	_seam_mesh.clear_surfaces()
	_seam_mi.set_instance_shader_parameter("frame", float(int(_t * 12.0) % 4))
	var quads := []
	for one: Dictionary in grabs:
		var pts: Array = one.seam
		for i in range(1, pts.size()):
			var a: Dictionary = pts[i - 1]
			var b: Dictionary = pts[i]
			var ka: float = clampf((_t - float(a.t)) / SEAM_LIFE, 0.0, 1.0)
			var kb: float = clampf((_t - float(b.t)) / SEAM_LIFE, 0.0, 1.0)
			if ka >= 1.0 and kb >= 1.0:
				continue
			quads.append([a, b, ka, kb])
	if quads.is_empty():
		return
	_seam_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for q: Array in quads:
		var a: Dictionary = q[0]
		var b: Dictionary = q[1]
		var run: Vector3 = (b.pos as Vector3) - (a.pos as Vector3)
		var side := run.normalized().cross(Vector3.UP) * SEAM_W * 0.5 if run.length() > 0.001 else Vector3.RIGHT * SEAM_W * 0.5
		var lift := Vector3.UP * SEAM_LIFT
		var pa: Vector3 = (a.pos as Vector3) + lift
		var pb: Vector3 = (b.pos as Vector3) + lift
		var ua: float = float(a.dist) / SEAM_TILE
		var ub: float = float(b.dist) / SEAM_TILE
		for v: Array in [[pa - side, ua, 0.0, q[2]], [pb - side, ub, 0.0, q[3]], [pa + side, ua, 1.0, q[2]],
				[pa + side, ua, 1.0, q[2]], [pb - side, ub, 0.0, q[3]], [pb + side, ub, 1.0, q[3]]]:
			_seam_mesh.surface_set_color(Color(v[3], 0.0, 0.0, 1.0))
			_seam_mesh.surface_set_uv(Vector2(v[1], v[2]))
			_seam_mesh.surface_add_vertex(v[0])
	_seam_mesh.surface_end()


func _unfly(one: Dictionary) -> void:
	var e: Variant = one.foe
	if is_instance_valid(e) and one.latched and (e as Node).has_meta(FLYING):
		(e as Node3D).global_position.y = 0.0
		(e as Node).remove_meta(FLYING)


func _exit_tree() -> void:
	for one: Dictionary in grabs:  # (freed mid-drag: nobody stays stuck as flying)
		var e: Variant = one.foe
		if is_instance_valid(e) and one.latched and (e as Node).has_meta(FLYING):
			(e as Node3D).global_position.y = 0.0
			(e as Node).remove_meta(FLYING)


static func _alive(e: Variant) -> bool:
	return is_instance_valid(e) and e.is_alive()
