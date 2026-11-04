extends RefCounted
## Ascended heavies: once he has an Ascendancy, every heavy move lays down his
## element and the NEXT heavy sets it off, so heavy-into-heavy strings chain
## element combos (player._rite()).
##   earth  Lava: lava wells up where the heavy lands (a ring of wells round a
##          spin, a line down Ground Breaker) and burns whatever stands in it;
##          the next heavy makes every well near him erupt in a lava geyser
##          that launches (MAGMA BURST).
##   wind   Thunder: foes the heavy hits carry a static charge (a crackling ring
##          over their heads); the next heavy calls a thunderbolt down on every
##          charged foe and arcs lightning from his axes through them all, each
##          bolt harder the more foes are in the chain (THUNDERCLAP).
##   water  Tide: foes the heavy hits are soaked (dripping, slowed); the next
##          heavy flash-freezes them in ice as it starts and its own blows
##          smash the ice for the shatter bonus (enemy.freeze, FLASH FREEZE).
## A breaker landing sets everything off too. Awakened: AWAKENED_MULT damage
## and bigger wells.

const ELEMENTS := preload("res://scripts/elements.gd")
const RITE := preload("res://scripts/element_rite.gd")  # (inner classes reach the static funcs through it)
const HEAVIES := ["H", "LH", "LHH", "LLH", "CH", "DH", "AH"]
const PRIME_TIME := 4.0  # s a charge / soak / well waits for the next heavy
const REACH := 12.0  # m from him that primes answer a heavy
const WELL_RADIUS := 1.5
const WELL_MAX := 9  # oldest wells drain first past this
const WELL_DAMAGE := 3.0  # each WELL_TICK s to foes standing in lava
const WELL_TICK := 0.5
const ERUPT_DAMAGE := 12.0
const ERUPT_LAUNCH := 7.0
const ERUPT_STEP := 0.06  # s between geysers, rippling out from him
const THUNDER_DAMAGE := 10.0
const THUNDER_CHAIN := 0.25  # extra damage per other foe in the chain
const CHAIN_MAX := 4
const ARC_STEP := 0.04  # s between the arcs as the chain jumps
const FREEZE_DAMAGE := 6.0
const FREEZE_TIME := 1.8
const SOAK_SLOW := 0.7
const AWAKENED_MULT := 1.5
const NAMES := {"earth": "MAGMA BURST", "wind": "THUNDERCLAP", "water": "FLASH FREEZE"}
const LAVA := Color(1.0, 0.35, 0.05)
const LAVA_HOT := Color(1.0, 0.8, 0.3)

static var set_offs := 0  # set-offs that caught something (autotest / checks)


## Lava welling up at `pos` (earth's prime). `big` = Awakened.
static func well(parent: Node, pos: Vector3, big := false) -> void:
	var wells := parent.get_tree().get_nodes_in_group("lava_wells")
	if wells.size() >= WELL_MAX:
		wells[0].drain()
	var w := Well.new()
	w.radius = WELL_RADIUS * (1.3 if big else 1.0)
	parent.add_child(w)
	w.global_position = Vector3(pos.x, 0.0, pos.z)


## Charge (wind) or soak (water) a foe a heavy just hit.
static func prime_foe(e: Node3D, el: String) -> void:
	if el not in ["wind", "water"] or not e.is_alive():
		return
	var m: Mark = e.get_node_or_null("RiteMark")
	if m == null or m.el != el:
		if m != null:
			m.free()
		m = Mark.new()
		m.name = "RiteMark"
		m.el = el
		e.add_child(m)
	m.life = PRIME_TIME
	if el == "water":
		e.chill(PRIME_TIME, SOAK_SLOW)


## Set off every prime of `el` near `at` (the hero). Returns how many things
## answered (wells erupted, foes zapped or frozen). `mult` scales the damage;
## `on_hit` runs on each foe hit (the Awakened passives).
static func set_off(parent: Node, at: Vector3, el: String, mult: float, on_hit := Callable()) -> int:
	var n := 0
	match el:
		"earth":
			var wells: Array = parent.get_tree().get_nodes_in_group("lava_wells").filter(func(w: Node3D) -> bool:
				return w.armed() and _flat(w.global_position - at).length() < REACH)
			wells.sort_custom(func(a: Node3D, b: Node3D) -> bool:
				return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
			for i in wells.size():
				wells[i].erupt(i * ERUPT_STEP, mult, on_hit)
			n = wells.size()
		"wind", "water":
			var foes := _marked(parent.get_tree(), at, el)
			n = foes.size()
			if el == "wind":
				_thunder(parent, at, foes, mult, on_hit)
			else:
				_freeze(parent, at, foes, mult, on_hit)
	if n > 0:
		set_offs += 1
	return n


## Living foes carrying `el`'s mark within REACH of `at`, chained nearest-next
## from `at` (the order the lightning jumps).
static func _marked(tree: SceneTree, at: Vector3, el: String) -> Array:
	var left: Array = tree.get_nodes_in_group("enemies").filter(func(e: Node3D) -> bool:
		var m: Node = e.get_node_or_null("RiteMark")
		return e.is_alive() and m != null and m.el == el and not m.is_queued_for_deletion() \
			and _flat(e.global_position - at).length() < REACH)
	var out := []
	var from := at
	while not left.is_empty():
		var best: Node3D = left[0]
		for e: Node3D in left:
			if _flat(e.global_position - from).length() < _flat(best.global_position - from).length():
				best = e
		out.append(best)
		left.erase(best)
		from = best.global_position
	return out


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Wind: Thunderclap --------------------------------------------------------

static func _thunder(parent: Node, at: Vector3, foes: Array, mult: float, on_hit: Callable) -> void:
	var c: Color = ELEMENTS.LOOK.wind.color
	var dmg := THUNDER_DAMAGE * mult * (1.0 + THUNDER_CHAIN * mini(foes.size() - 1, CHAIN_MAX))
	var prev := at + Vector3.UP * 1.4  # off his axes
	for i in foes.size():
		var e: Node3D = foes[i]
		var to := e.global_position + Vector3.UP * 1.0
		var tw := parent.create_tween()
		tw.tween_interval(i * ARC_STEP)
		tw.tween_callback(_zap.bind(parent, prev, e, dmg, on_hit))
		prev = to
		e.get_node("RiteMark").queue_free()
	Game.sfx("cast_wind", -2.0, 0.1)
	ELEMENTS.light_pop(parent, at, c, 6.0, 8.0, 0.3)


## One link of the chain: an arc from `from` to the foe, then a bolt from the sky onto it.
static func _zap(parent: Node, from: Vector3, e: Node3D, dmg: float, on_hit: Callable) -> void:
	if not is_instance_valid(e) or not is_instance_valid(parent):
		return
	var c: Color = ELEMENTS.LOOK.wind.color
	var to := e.global_position + Vector3.UP * 1.0
	arc(parent, from, to, c)
	ELEMENTS.lightning_fx(parent, e.global_position, c, 11.0)
	Fx.burst(parent, to, ELEMENTS.LOOK.wind.glow, 16, 10.0, 0.1, 0.22, Vector3.UP, 180.0, 0.0, 0.3, "spark", true)
	Fx.scorch(parent, e.global_position, c, 1.2, 1.0)
	Game.sfx("hit_big", -5.0, 0.15)
	if e.is_alive():
		e.take_hit(dmg, Vector3.ZERO, 3.0, true)
		Game.register_hit("thunder")
		if on_hit.is_valid():
			on_hit.call(e)


## A jagged lightning arc between two points: a fat glow and a white core,
## flickering out.
static func arc(parent: Node, a: Vector3, b: Vector3, c: Color) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = a
	var span := b - a
	var segs := clampi(int(span.length() / 0.8), 3, 10)
	var side := span.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var prev := Vector3.ZERO
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := span * t
		if i < segs:
			p += side * randf_range(-0.5, 0.5) + Vector3.UP * randf_range(-0.35, 0.35)
		for layer in 2:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.13 if layer == 0 else 0.05
			cyl.bottom_radius = cyl.top_radius
			cyl.height = prev.distance_to(p)
			cyl.radial_segments = 5
			cyl.rings = 1
			var seg := ELEMENTS._mi(cyl, ELEMENTS.glow(Color(c, 0.7), 1.6) if layer == 0 else ELEMENTS.glow(Color(1, 1, 1, 0.95), 3.0))
			root.add_child(seg)
			seg.position = (prev + p) * 0.5
			seg.basis = Basis(Quaternion(Vector3.UP, (p - prev).normalized()))
		prev = p
	ELEMENTS._fade_free(root, 0.08, 0.14)


# --- Water: Flash Freeze ------------------------------------------------------

static func _freeze(parent: Node, at: Vector3, foes: Array, mult: float, on_hit: Callable) -> void:
	var c: Color = ELEMENTS.LOOK.water.color
	var shatter: float = Ascendancy.PATHS.water.shatter_mult
	# The cold rolls out from him: a frost wave over the floor to the soaked.
	Fx.ring(parent, _flat(at), Color(c, 0.9), 4.0, 0.3)
	Fx.ring(parent, _flat(at), Color(0.92, 0.98, 1.0, 0.7), 6.5, 0.45)
	Fx.burst(parent, _flat(at) + Vector3.UP * 0.2, Color(0.92, 0.98, 1.0, 0.7), 18, 9.0, 0.4, 0.5, Vector3.UP, 88.0, 0.0, 0.6, "smoke")
	for e: Node3D in foes:
		var d := _flat(e.global_position - at).length()
		var tw := parent.create_tween()
		tw.tween_interval(d / 30.0)  # the wave reaches the far ones later
		tw.tween_callback(_encase.bind(parent, e, FREEZE_DAMAGE * mult, shatter, on_hit))
		e.get_node("RiteMark").queue_free()
	Game.sfx("cage_shut", -4.0, 0.08)


static func _encase(parent: Node, e: Node3D, dmg: float, shatter: float, on_hit: Callable) -> void:
	if not is_instance_valid(e) or not is_instance_valid(parent) or not e.is_alive():
		return
	var pos := e.global_position
	ELEMENTS.spikes(parent, pos, "water", 1.1, 5, 1.2)
	Fx.shards(parent, pos + Vector3.UP * 0.8, Color(0.85, 0.96, 1.0), 12, Vector3.UP, 7.0, 0.14, 0.6)
	Fx.flare(parent, pos + Vector3.UP * 1.0, ELEMENTS.LOOK.water.glow, 2.2, 0.14)
	e.take_hit(dmg, Vector3.ZERO, 0.0, true)
	Game.register_hit("flash_freeze")
	if on_hit.is_valid():
		on_hit.call(e)
	if e.is_alive():
		if e.has_method("is_boss"):
			e.chill(FREEZE_TIME, SOAK_SLOW * 0.7)
		else:
			e.freeze(FREEZE_TIME, shatter)


# --- Earth: lava wells and Magma Burst ----------------------------------------

## The geyser's lava: the swirl shader with gold streaks (as Cataclysm's fire).
static func _lava_mat(inner: bool) -> ShaderMaterial:
	var m: ShaderMaterial = ELEMENTS.swirl_mat(LAVA, inner, 0.8, 4.0).duplicate()
	m.set_shader_parameter("streak_color", LAVA_HOT)
	return m


## A lava geyser at `pos`: a molten column punching up, lava raining back
## down, magma spikes round its foot.
## `h`: how tall. `hot`: the glowing core, which blows out white when several go up together.
static func geyser(parent: Node, pos: Vector3, radius: float, h := 5.5, hot_core := true) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = _flat(pos)
	var col := ELEMENTS._mi(ELEMENTS.funnel(radius * 0.75, radius * 0.45, h), _lava_mat(false))
	col.position.y = h * 0.5
	root.add_child(col)
	var core := CylinderMesh.new()
	core.top_radius = radius * 0.22
	core.bottom_radius = radius * 0.3
	core.height = h * 1.05
	if hot_core:
		var hot := ELEMENTS._mi(core, ELEMENTS.glow(LAVA_HOT, 2.6))
		hot.position.y = h * 0.52
		root.add_child(hot)
	root.scale = Vector3(0.5, 0.05, 0.5)
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(col, "rotation:y", TAU * 1.5, 0.6)
	ELEMENTS._fade_free(root, 0.25, 0.3)
	var top := root.global_position + Vector3.UP * h
	Fx.burst(parent, top, LAVA, 22, 9.0, 0.2, 0.9, Vector3.UP, 55.0, -22.0, 0.4, "dot", true)  # lava raining back down
	Fx.burst(parent, top, LAVA_HOT, 10, 6.0, 0.12, 0.6, Vector3.UP, 70.0, -18.0, 0.3, "dot", true)
	Fx.shards(parent, root.global_position + Vector3.UP * 0.3, ELEMENTS.LOOK.earth.rock.lightened(0.2), 10, Vector3.UP, 11.0, 0.2, 0.8)
	Fx.burst(parent, root.global_position + Vector3.UP * 0.5, Color(0.15, 0.12, 0.11, 0.65), 6, 3.0, 0.7, 1.0, Vector3.UP, 30.0, 1.5, 0.4, "smoke")
	ELEMENTS.spikes(parent, root.global_position, "earth", 1.2, 4, 0.8)
	Fx.ring(parent, root.global_position, Color(LAVA, 0.9), radius * 1.8, 0.3)
	Fx.scorch(parent, root.global_position, LAVA, radius * 1.4, 1.6)
	ELEMENTS.light_pop(parent, root.global_position + Vector3.UP * 1.5, LAVA, 6.0, 6.0, 0.35)


## A pool of lava welled up through the floor: a cracked crust round a bright
## core, bubbling and spitting; burns foes standing in it.
class Well extends Node3D:
	var radius := 1.5
	var _age := 0.0
	var _tick := 0.2
	var _bubble := 0.0
	var _core: MeshInstance3D
	var _done := false

	func _ready() -> void:
		add_to_group("lava_wells")
		var pool := CylinderMesh.new()
		pool.top_radius = radius
		pool.bottom_radius = radius
		pool.height = 0.04
		pool.radial_segments = 14
		add_child(ELEMENTS._mi(pool, ELEMENTS.glow(Color(LAVA, 0.85), 1.6)))
		var hot := CylinderMesh.new()
		hot.top_radius = radius * 0.55
		hot.bottom_radius = radius * 0.55
		hot.height = 0.06
		hot.radial_segments = 10
		_core = ELEMENTS._mi(hot, ELEMENTS.glow(LAVA_HOT, 2.2))
		add_child(_core)
		for i in 7:  # crust chunks round the rim
			var b := BoxMesh.new()
			b.size = Vector3(randf_range(0.3, 0.55), randf_range(0.12, 0.25), randf_range(0.2, 0.35))
			var rock := ELEMENTS._mi(b, ELEMENTS.rock())
			var ang := TAU * (i + randf_range(-0.3, 0.3)) / 7.0
			rock.position = Vector3(sin(ang), 0.0, cos(ang)) * radius * randf_range(0.85, 1.05)
			rock.rotation = Vector3(randf_range(-0.3, 0.3), ang, randf_range(-0.3, 0.3))
			add_child(rock)
		scale = Vector3(0.2, 1.0, 0.2)
		create_tween().tween_property(self, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		var parent := get_parent()
		Fx.burst(parent, global_position + Vector3.UP * 0.2, LAVA, 14, 7.0, 0.14, 0.5, Vector3.UP, 45.0, -18.0, radius * 0.4, "dot", true)
		Fx.scorch(parent, global_position, LAVA, radius * 1.3, PRIME_TIME)
		Fx.dust(parent, global_position, 6, 0.6)

	func armed() -> bool:
		return not _done and _age > 0.15  # (not the wells this same heavy just made)

	func _physics_process(delta: float) -> void:
		if _done:
			return
		_age += delta
		if _age >= PRIME_TIME:
			drain()
			return
		_core.scale = Vector3.ONE * (1.0 + 0.12 * sin(_age * 9.0))
		_bubble -= delta
		if _bubble <= 0.0:
			_bubble = randf_range(0.12, 0.25)
			var off := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * radius * 0.6
			Fx.burst(get_parent(), global_position + off + Vector3.UP * 0.1, LAVA_HOT, 3, 3.0, 0.1, 0.45, Vector3.UP, 20.0, -6.0, 0.0, "dot", true)
		_tick -= delta
		if _tick <= 0.0:
			_tick = WELL_TICK
			for e in Ascendancy.enemies_near(get_tree(), global_position, radius):
				e.take_hit(WELL_DAMAGE, Vector3.ZERO, 0.0, false)
				Game.register_hit("lava")

	## Cools and sinks away.
	func drain() -> void:
		if _done:
			return
		_done = true
		remove_from_group("lava_wells")
		ELEMENTS._fade_free(self, 0.0, 0.4)

	## Bursts as a geyser `delay` s from now, launching what stands in it.
	func erupt(delay: float, mult: float, on_hit: Callable) -> void:
		_done = true
		remove_from_group("lava_wells")
		var tw := create_tween()
		tw.tween_property(_core, "scale", Vector3.ONE * 1.6, maxf(delay, 0.02))  # swells, about to blow
		tw.tween_callback(_blow.bind(mult, on_hit))

	func _blow(mult: float, on_hit: Callable) -> void:
		var parent := get_parent()
		RITE.geyser(parent, global_position, radius)
		Game.sfx("quake", -7.0, 0.1)
		ELEMENTS.hit_area(get_tree(), global_position, radius + 0.6, ERUPT_DAMAGE * mult, ERUPT_LAUNCH, true, "magma_burst", on_hit)
		queue_free()


## A charged (wind) or soaked (water) foe's mark: a crackling ring over its
## head, or a ring of water at its feet with drips. Child of the foe.
class Mark extends Node3D:
	var el := "wind"
	var life := PRIME_TIME
	var _fx := 0.0
	var _ring: MeshInstance3D

	func _ready() -> void:
		var host := get_parent() as Node3D
		var s: float = host.get("model_scale") if host.get("model_scale") != null else 1.0
		var t := TorusMesh.new()
		var c: Color = ELEMENTS.LOOK[el].color
		if el == "wind":
			t.inner_radius = 0.42
			t.outer_radius = 0.52
			_ring = ELEMENTS._mi(t, ELEMENTS.glow(Color(c.lerp(Color.WHITE, 0.3), 0.9), 2.2))
			_ring.position.y = 2.3 * s
		else:
			t.inner_radius = 0.75 * s
			t.outer_radius = 0.9 * s
			_ring = ELEMENTS._mi(t, ELEMENTS.glow(Color(c, 0.7), 1.4))
			_ring.position.y = 0.08
			_ring.scale.y = 0.3
		add_child(_ring)
		_ring.scale *= 0.2
		create_tween().tween_property(_ring, "scale", Vector3(1.0, _ring.scale.y * 5.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		if el == "wind":
			Fx.burst(host.get_parent(), host.global_position + Vector3.UP * 1.2, ELEMENTS.LOOK.wind.glow, 10, 7.0, 0.08, 0.2, Vector3.UP, 180.0, 0.0, 0.3, "spark", true)
		else:
			Fx.burst(host.get_parent(), host.global_position + Vector3.UP * 1.0, Color(0.85, 0.95, 1.0), 12, 5.0, 0.12, 0.45, Vector3.UP, 80.0, -12.0, 0.3)

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		_ring.rotation.y += delta * (9.0 if el == "wind" else 2.0)
		_fx -= delta
		if _fx <= 0.0:
			var host := get_parent() as Node3D
			if el == "wind":
				_fx = randf_range(0.08, 0.18)
				Fx.burst(host.get_parent(), host.global_position + Vector3.UP * randf_range(0.6, 2.0), ELEMENTS.LOOK.wind.glow, 3, 5.0, 0.07, 0.12, Vector3.UP, 180.0, 0.0, 0.4, "spark", true)
			else:
				_fx = randf_range(0.15, 0.3)
				Fx.burst(host.get_parent(), host.global_position + Vector3.UP * 1.6, ELEMENTS.LOOK.water.color.lightened(0.3), 2, 0.5, 0.08, 0.4, Vector3.DOWN, 20.0, -10.0, 0.4)
