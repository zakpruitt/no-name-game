extends Node3D
## Eruption (Meltdown's window, H, round 52 cool pass; docs/features/combo-breakers.md "Round 52 cool pass"): he lands
## on the burning pile Meltdown brought down and the floor under it goes up. Per foe, nearest the landing first, STEP s
## apart, in three beats:
##   1. fuse: a lava crack (the `erupt_chain` strip) races along the floor from where he landed to the foe (FUSE s);
##   2. heave: a lava geyser goes up under it and carries it up to TOP m (HEAVE s), on_heave(foe, i) as it leaves
##      the floor (the hit);
##   3. hurl or drop: with a structure picked (env_target "eruption": the cursor's, or the nearest in reach), the
##      geyser throws it at the wall or pillar, on_hurl(foe, i) (void_element._eruption launches it; its wall splat
##      calls slide(foe, n)), and it slides down the wall burning (`erupt_drip`: SLIDE s, on_slide(foe, i) as it reaches
##      the floor). In the open the column gives under it and it drops back into the floor, on_drop(foe, i).
## Big ones are never carried: the geyser hits them where they stand (on_heave), and they take the drop in place.
## Game time (hit stops hold it). Headless it draws nothing but moves them.
##   var g := ERUPTION_HURL.start(hero, at, foes, walled, heavy)
##   g.on_heave = func(e, i): ...;  g.on_hurl = func(e, i): ...;  g.on_drop = ...;  g.on_slide = ...

const SELF := preload("res://scripts/eruption_hurl.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const DRAG_SHADER := preload("res://shaders/designed_drag.gdshader")

const START := 0.12  # s after the landing the first fuse starts (past the impact frame: it hid them)
const STEP := 0.07  # s between foes
const FUSE := 0.1  # s the crack takes from the landing to a foe
const HEAVE := 0.13  # s up the geyser
const TOP := 2.1  # m it carries them up to
const DROP := 0.07  # s back down in the open
const SLIDE := 0.34  # s down the wall
const SPLAT_Y := 1.8  # m up the wall they splat at
const GEYSER_HIGH := 2.2  # m: the geyser's column (designed_elements.geyser)
const FUSE_W := 0.55  # m: the crack's width on the floor
const FUSE_TILE := 1.6  # m of floor per repeat of the strip
const FUSE_LIFE := 0.9  # s a crack takes to cool and go
const FUSE_LIFT := 0.07  # m over the floor stones
const DRIP_SIZE := 3.6  # m: the erupt_drip quad (the splat sits ~0.71 of it up: SPLAT_Y)
const DRIP_TIMES := [0.05, 0.07, 0.08, 0.09, 0.12, 0.16, 0.2]
const DRIP_OUT := 0.35  # m out of the wall face the drip stands (the foe slides in front of it)
const FLYING := "thrown_foe_flying"

var hero: CharacterBody3D
var at := Vector3.ZERO
var walled := false
var rises := []  # {foe, i, t0, from, heavy, heaved, done, fuse_to}
var slides := []  # {foe, i, t, from, n}
var on_heave := Callable()  # (foe, i)
var on_hurl := Callable()  # (foe, i)
var on_drop := Callable()  # (foe, i)
var on_slide := Callable()  # (foe, i)
var heaved := 0  # (checks)
var slid := 0
var top := 0.0  # the highest any got
var _t := 0.0
var _mesh: ImmediateMesh
var _mi: MeshInstance3D
static var _mat: ShaderMaterial


static func register() -> void:
	for n: Array in [["erupt_drip", Vector2(4, 2), 7, "sprite_depth", Vector2(0.0, -0.43)], ["erupt_chain", Vector2(1, 4), 4, "ribbon", Vector2.ZERO]]:
		if not DESIGNED.extra_sheets.has(n[0]):
			var s := {"tex": load("res://assets/vfx/designed/%s.png" % n[0]), "grid": n[1], "frames": n[2], "kind": n[3], "burn": 1.0}
			if n[4] != Vector2.ZERO:
				s["anchor"] = n[4]
			DESIGNED.extra_sheets[n[0]] = s


static func fuse_material() -> ShaderMaterial:
	if _mat == null:
		register()
		var m := ShaderMaterial.new()
		m.shader = DRAG_SHADER
		m.set_shader_parameter("sheet", DESIGNED.sheet_of("erupt_chain").tex)
		m.set_shader_parameter("palette", DESIGNED.palette())
		m.set_shader_parameter("palette_rows", float(DESIGNED.ROWS.size()))
		m.set_shader_parameter("burn_hot", 1.0)
		m.set_shader_parameter("rows", 4.0)
		m.set_shader_parameter("cool", 0.6)
		_mat = m
	return _mat


static func prewarm(root: Node3D) -> void:
	if not DESIGNED.on():
		return
	register()
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	mi.material_override = DESIGNED.material("erupt_drip")
	root.add_child(mi)
	mi.scale = Vector3.ONE * 20.0
	var strip := MeshInstance3D.new()
	strip.mesh = QuadMesh.new()
	strip.material_override = fuse_material()
	root.add_child(strip)
	strip.scale = Vector3.ONE * 20.0


## `foes`: who goes up, nearest `at` first; `walled`: a structure was picked (they're hurled at it, else dropped).
static func start(by: CharacterBody3D, spot: Vector3, foes: Array, is_walled: bool, heavy: Callable) -> Node3D:
	var g: Node3D = SELF.new()
	g.hero = by
	g.at = Vector3(spot.x, 0.0, spot.z)
	g.walled = is_walled
	var live: Array = foes.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.is_alive())
	live.sort_custom(func(a: Node3D, c: Node3D) -> bool:
		return _flat(a.global_position).distance_to(g.at) < _flat(c.global_position).distance_to(g.at))
	for i in live.size():
		g.rises.append({"foe": live[i], "i": i, "t0": START + i * STEP, "heavy": heavy.call(live[i]), "heaved": false, "done": false})
	by.get_parent().add_child(g)
	return g


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	if DisplayServer.get_name() != "headless" and DESIGNED.on():
		_mesh = ImmediateMesh.new()
		_mi = MeshInstance3D.new()
		_mi.mesh = _mesh
		_mi.material_override = fuse_material()
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi.set_meta("no_ghost", true)
		_mi.extra_cull_margin = 20.0
		add_child(_mi)
		_mi.set_instance_shader_parameter("pal_row", DESIGNED.row("earth"))


## Its wall splat (void_element._eruption's on_burst): it sticks SPLAT_Y m up the structure and slides down it.
func slide(e: Node3D, n: Vector3) -> void:
	if not _alive(e):
		return
	var i := 0
	for one: Dictionary in rises:
		if one.foe == e:
			i = int(one.i)
	var from := Vector3(e.global_position.x, SPLAT_Y, e.global_position.z)
	e.global_position = from
	e.set_meta(FLYING, true)
	slides.append({"foe": e, "i": i, "t": 0.0, "from": from, "n": n})
	if DESIGNED.on() and Game.comic_style and is_inside_tree():
		register()
		var foot := Vector3(from.x, 0.0, from.z) - n * DRIP_OUT
		var fx: Node3D = DESIGNED.spawn(get_parent(), "erupt_drip", foot, DRIP_SIZE, "earth", DRIP_TIMES, Vector2(0.62, 1.0))
		fx.real_until = 1
		fx.set_spin(0.0, -1.0 if i % 2 else 1.0)


func _physics_process(delta: float) -> void:
	_t += delta
	var busy := false
	for one: Dictionary in rises:
		if one.done:
			continue
		busy = true
		var e: Variant = one.foe
		if not _alive(e):
			one.done = true
			continue
		var foe := e as Node3D
		var local: float = _t - float(one.t0)
		if local < FUSE:  # 1. fuse: the crack on its way to it (drawn below)
			continue
		if not one.heaved:  # 2. heave: the geyser under it
			one.heaved = true
			heaved += 1
			one.from = foe.global_position
			if not one.heavy:
				foe.set_meta(FLYING, true)
			if DESIGNED.on() and Game.comic_style and is_inside_tree():
				DESIGNED_EL.geyser(get_parent(), foe.global_position, GEYSER_HIGH)
			if on_heave.is_valid():
				on_heave.call(foe, int(one.i))
		var k := clampf((local - FUSE) / HEAVE, 0.0, 1.0)
		if not one.heavy:
			var y: float = lerpf((one.from as Vector3).y, TOP, 1.0 - (1.0 - k) * (1.0 - k))
			foe.global_position = Vector3((one.from as Vector3).x, y, (one.from as Vector3).z)
			if foe is CharacterBody3D:
				(foe as CharacterBody3D).velocity = Vector3.ZERO
			top = maxf(top, y)
		if k < 1.0:
			continue
		if walled and not one.heavy:  # 3. hurl: the geyser throws it at the structure
			one.done = true
			_unfly(foe)
			if on_hurl.is_valid():
				on_hurl.call(foe, int(one.i))
			continue
		var d := clampf((local - FUSE - HEAVE) / DROP, 0.0, 1.0)  # 3. drop: the column gives under it
		if not one.heavy:
			foe.global_position.y = lerpf(TOP, 0.0, d * d)
		if d >= 1.0:
			one.done = true
			_unfly(foe)
			if on_drop.is_valid():
				on_drop.call(foe, int(one.i))
	for s: Dictionary in slides:
		if s.t >= SLIDE:
			continue
		busy = true
		var e: Variant = s.foe
		if not _alive(e):
			s.t = SLIDE
			continue
		s.t = float(s.t) + delta
		var k := clampf(float(s.t) / SLIDE, 0.0, 1.0)
		var foe := e as Node3D
		foe.global_position = Vector3((s.from as Vector3).x, lerpf(SPLAT_Y, 0.0, k * k), (s.from as Vector3).z)
		if foe is CharacterBody3D:
			(foe as CharacterBody3D).velocity = Vector3.ZERO
		if k >= 1.0:
			slid += 1
			_unfly(foe)
			if on_slide.is_valid():
				on_slide.call(foe, int(s.i))
	_draw_fuses()
	if not busy and _t > FUSE + HEAVE + FUSE_LIFE:
		queue_free()


## The cracks from the landing to each foe: grown out over FUSE from its start, cooling over FUSE_LIFE after.
func _draw_fuses() -> void:
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	_mi.set_instance_shader_parameter("frame", float(int(_t * 12.0) % 4))
	var any := false
	for one: Dictionary in rises:
		var local: float = _t - float(one.t0)
		if local < 0.0 or local > FUSE + FUSE_LIFE:
			continue
		var to: Vector3 = _flat((one.from as Vector3) if one.has("from") else (one.foe as Node3D).global_position if _alive(one.foe) else at)
		var run := to - at
		if run.length() < 0.3:
			continue
		var reach := clampf(local / FUSE, 0.0, 1.0)
		var age := clampf((local - FUSE) / FUSE_LIFE, 0.0, 1.0)
		if not any:
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			any = true
		var side := run.normalized().cross(Vector3.UP) * FUSE_W * 0.5
		var lift := Vector3.UP * FUSE_LIFT
		var steps := maxi(int(run.length() * reach / 0.5), 1)
		for j in steps:
			var qa := float(j) / steps * reach
			var qb := float(j + 1) / steps * reach
			var pa := at + run * qa + lift
			var pb := at + run * qb + lift
			var ua := run.length() * qa / FUSE_TILE
			var ub := run.length() * qb / FUSE_TILE
			var ka := clampf(age + (1.0 - qa) * 0.15, 0.0, 1.0)  # (the old end cools first)
			var kb := clampf(age + (1.0 - qb) * 0.15, 0.0, 1.0)
			for v: Array in [[pa - side, ua, 0.0, ka], [pb - side, ub, 0.0, kb], [pa + side, ua, 1.0, ka],
					[pa + side, ua, 1.0, ka], [pb - side, ub, 0.0, kb], [pb + side, ub, 1.0, kb]]:
				_mesh.surface_set_color(Color(v[3], 0.0, 0.0, 1.0))
				_mesh.surface_set_uv(Vector2(v[1], v[2]))
				_mesh.surface_add_vertex(v[0])
	if any:
		_mesh.surface_end()


func _unfly(e: Variant) -> void:
	if is_instance_valid(e) and (e as Node).has_meta(FLYING):
		(e as Node).remove_meta(FLYING)


func _exit_tree() -> void:
	for one: Dictionary in rises:  # (freed mid-heave: nobody stays up in the air)
		var e: Variant = one.foe
		if _alive(e) and one.heaved and not one.done and not one.heavy:
			(e as Node3D).global_position.y = 0.0
			_unfly(e)
	for s: Dictionary in slides:
		if _alive(s.foe) and s.t < SLIDE:
			(s.foe as Node3D).global_position.y = 0.0
			_unfly(s.foe)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _alive(e: Variant) -> bool:
	return is_instance_valid(e) and e.is_alive()
