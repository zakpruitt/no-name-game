class_name Ascendancy
extends RefCounted
## Ascendancy: at hero level 6 (Game.LEVEL_MAX) the shaman picks an element.
## It reshapes Awakening for the rest of the run: colour, a passive while
## Awakened, and the finisher (L L L H) that replaces Cataclysm.
## Pure tuning data plus the element effects; player.gd calls them.
##
##   wind   swift: faster, shorter dash cooldown; every few hits calls lightning.
##          Finisher Tempest: a cyclone that drags foes in and strikes them.
##   earth  sturdy: takes less damage; heavy moves leave magma pools.
##          Finisher Eruption: a volcano that rains lava bombs on nearby foes.
##   water  control: hits chill (slow) foes, enough hits freeze them; the next
##          hit shatters the ice for bonus damage.
##          Finisher Glacier: ice spikes burst up all around and freeze everyone.

const PATHS := {
	"wind": {"name": "Wind", "title": "TEMPEST ASCENDANT", "color": Color(0.55, 1.0, 0.6), "finisher": "Tempest",
		"desc": "Faster, quicker dashes, lightning every 3rd hit",
		"speed": 1.25, "dash_cd": 0.5, "strike_every": 3, "strike_damage": 10.0, "strike_radius": 1.8,
		"tempest_time": 2.2, "tempest_radius": 6.5, "tempest_pull": 7.0, "tempest_strikes": 8, "tempest_damage": 10.0},
	"earth": {"name": "Earth", "title": "MAGMA ASCENDANT", "color": Color(1.0, 0.42, 0.12), "finisher": "Eruption",
		"desc": "Tougher, heavy moves leave burning magma",
		"armor": 0.45, "magma_damage": 5.0, "magma_tick": 0.4, "magma_time": 3.0, "magma_radius": 1.5,
		"volcano_time": 2.6, "volcano_bombs": 12, "volcano_range": 8.0, "bomb_damage": 14.0, "bomb_radius": 2.2},
	"water": {"name": "Water", "title": "TIDE ASCENDANT", "color": Color(0.5, 0.85, 1.0), "finisher": "Glacier",
		"desc": "Hits chill foes, 4 hits freeze them solid",
		"chill_time": 2.0, "chill_slow": 0.55, "freeze_hits": 4, "freeze_time": 1.6, "shatter_mult": 1.5,
		"glacier_radius": 6.5, "glacier_damage": 16.0, "glacier_freeze": 2.5, "glacier_spikes": 18},
}
## Awakening colour before an Ascendancy is chosen.
const BASE_COLOR := Color(1.0, 0.55, 0.15)
## Moves that count as heavy for Earth's magma pools.
const HEAVY_MOVES := ["H", "LH", "LLH", "CH", "AF"]


static func color(path: String) -> Color:
	return PATHS[path].color if PATHS.has(path) else BASE_COLOR


static func enemies_near(tree: SceneTree, pos: Vector3, radius: float) -> Array:
	return tree.get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		if not e.is_alive():
			return false
		var d: Vector3 = e.global_position - pos
		d.y = 0.0
		return d.length() < radius + e.radius)


static func glow_mat(c: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# --- Wind -------------------------------------------------------------------

## A bolt from the sky onto `pos`: damage in `radius`.
static func lightning(parent: Node, pos: Vector3, damage: float, radius: float, source: String) -> void:
	var c: Color = PATHS.wind.color
	var bolt := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.05
	cyl.height = 9.0
	bolt.mesh = cyl
	bolt.material_override = glow_mat(c.lightened(0.5), 0.9)
	parent.add_child(bolt)
	bolt.global_position = pos + Vector3.UP * 4.5
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "scale", Vector3(0.1, 1.0, 0.1), 0.18)
	tw.tween_callback(bolt.queue_free)
	Fx.ring(parent, pos, Color(c, 0.9), radius, 0.25)
	Fx.burst(parent, pos + Vector3.UP * 0.3, c, 14, 8.0, 0.14, 0.25, Vector3.UP, 80.0)
	Game.sfx("hit_big", -6.0)
	for e in enemies_near(parent.get_tree(), pos, radius):
		e.take_hit(damage, (e.global_position - pos).normalized() * 3.0, 0.0, false)
		Game.register_hit(source)


class Tempest extends Node3D:
	## Cyclone at a point: pulls enemies toward the centre and strikes them.
	var spec: Dictionary = PATHS.wind
	var _age := 0.0
	var _strike_t := 0.0
	var _ring: MeshInstance3D

	func _ready() -> void:
		_ring = MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = spec.tempest_radius - 0.25
		t.outer_radius = spec.tempest_radius
		_ring.mesh = t
		_ring.material_override = Ascendancy.glow_mat(spec.color, 0.5)
		add_child(_ring)
		_ring.position.y = 0.15

	func _physics_process(delta: float) -> void:
		_age += delta
		if _age >= spec.tempest_time:
			queue_free()
			return
		_ring.rotation.y += delta * 6.0
		_ring.scale = Vector3.ONE * (1.0 - 0.3 * _age / spec.tempest_time)
		Fx.burst(get_parent(), global_position + Vector3(randf_range(-3, 3), 0.4, randf_range(-3, 3)), spec.color,
			3, 6.0, 0.18, 0.4, Vector3.UP, 30.0, 0.0)
		for e in Ascendancy.enemies_near(get_tree(), global_position, spec.tempest_radius):
			if e.has_method("is_boss"):
				continue
			var to: Vector3 = global_position - e.global_position
			to.y = 0.0
			if to.length() > 0.8:
				e.global_position += to.normalized() * spec.tempest_pull * delta
		_strike_t -= delta
		if _strike_t <= 0.0:
			_strike_t = spec.tempest_time / spec.tempest_strikes
			var near := Ascendancy.enemies_near(get_tree(), global_position, spec.tempest_radius)
			var at := global_position + Vector3(randf_range(-2, 2), 0.0, randf_range(-2, 2))
			if not near.is_empty():
				at = near.pick_random().global_position
			Ascendancy.lightning(get_parent(), Vector3(at.x, 0.0, at.z), spec.tempest_damage, 1.6, "tempest")


# --- Earth ------------------------------------------------------------------

class MagmaPool extends Node3D:
	## Burning patch: damages enemies standing in it every tick.
	var spec: Dictionary = PATHS.earth
	var radius := 1.5
	var _age := 0.0
	var _tick := 0.0
	var _disc: MeshInstance3D

	func _ready() -> void:
		_disc = MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = radius
		m.bottom_radius = radius
		m.height = 0.04
		_disc.mesh = m
		_disc.material_override = Ascendancy.glow_mat(Color(1.0, 0.35, 0.05), 0.75)
		add_child(_disc)
		_disc.position.y = 0.05

	func _physics_process(delta: float) -> void:
		_age += delta
		var life: float = spec.magma_time
		if _age >= life:
			queue_free()
			return
		_disc.transparency = clampf((_age - life + 0.5) / 0.5, 0.0, 1.0)
		if randf() < 0.35:
			Fx.burst(get_parent(), global_position + Vector3(randf_range(-radius, radius) * 0.7, 0.1, randf_range(-radius, radius) * 0.7),
				Color(1.0, 0.55, 0.1), 2, 2.0, 0.12, 0.4, Vector3.UP, 20.0, 1.0)
		_tick -= delta
		if _tick <= 0.0:
			_tick = spec.magma_tick
			for e in Ascendancy.enemies_near(get_tree(), global_position, radius):
				e.take_hit(spec.magma_damage, Vector3.ZERO, 0.0, false)
				Game.register_hit("magma")


static func magma_pool(parent: Node, pos: Vector3, radius: float) -> void:
	var p := MagmaPool.new()
	p.radius = radius
	parent.add_child(p)
	p.global_position = Vector3(pos.x, 0.0, pos.z)


class Volcano extends Node3D:
	## A cone that rises, then lobs lava bombs at nearby foes.
	var spec: Dictionary = PATHS.earth
	var _age := 0.0
	var _bomb_t := 0.4
	var _cone: MeshInstance3D

	func _ready() -> void:
		_cone = MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.45
		m.bottom_radius = 1.7
		m.height = 1.6
		_cone.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.22, 0.13, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.15, 0.02)
		_cone.material_override = mat
		add_child(_cone)
		_cone.position.y = -1.0
		var crater := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.45
		s.height = 0.5
		crater.mesh = s
		crater.material_override = Ascendancy.glow_mat(Color(1.0, 0.5, 0.1))
		_cone.add_child(crater)
		crater.position.y = 0.8
		create_tween().tween_property(_cone, "position:y", 0.8, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Fx.dust(get_parent(), global_position, 20, 1.0)
		Game.shake(0.4)

	func _physics_process(delta: float) -> void:
		_age += delta
		if _age >= spec.volcano_time:
			set_physics_process(false)
			var tw := create_tween()
			tw.tween_property(_cone, "position:y", -1.0, 0.4)
			tw.tween_callback(queue_free)
			return
		_bomb_t -= delta
		if _bomb_t <= 0.0:
			_bomb_t = (spec.volcano_time - 0.4) / spec.volcano_bombs
			_lob()

	func _lob() -> void:
		var near := Ascendancy.enemies_near(get_tree(), global_position, spec.volcano_range)
		var at := global_position + Vector3(randf_range(-4, 4), 0.0, randf_range(-4, 4))
		if not near.is_empty():
			at = near.pick_random().global_position
		at.y = 0.0
		var bomb := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.28
		s.height = 0.56
		bomb.mesh = s
		bomb.material_override = Ascendancy.glow_mat(Color(1.0, 0.45, 0.1))
		get_parent().add_child(bomb)
		var from := global_position + Vector3.UP * 1.8
		bomb.global_position = from
		Fx.burst(get_parent(), from, Color(1.0, 0.5, 0.1), 6, 5.0, 0.15, 0.3, Vector3.UP, 30.0)
		var tw := bomb.create_tween()
		tw.tween_method(func(t: float) -> void:
			bomb.global_position = from.lerp(at, t) + Vector3.UP * 4.0 * sin(t * PI), 0.0, 1.0, 0.55)
		tw.tween_callback(func() -> void:
			var parent := bomb.get_parent()
			bomb.queue_free()
			Fx.ring(parent, at, Color(1.0, 0.45, 0.1, 0.9), spec.bomb_radius, 0.25)
			Fx.burst(parent, at + Vector3.UP * 0.3, Color(1.0, 0.55, 0.15), 14, 7.0, 0.16, 0.35, Vector3.UP, 70.0)
			Game.sfx("hit_big", -7.0)
			for e in Ascendancy.enemies_near(parent.get_tree(), at, spec.bomb_radius):
				e.take_hit(spec.bomb_damage, (e.global_position - at).normalized() * 4.0, 5.0, true)
				Game.register_hit("eruption")
			Ascendancy.magma_pool(parent, at, 1.1))


# --- Water ------------------------------------------------------------------

## Chill an enemy on hit; enough hits in a row freeze it (not the boss).
static func chill_hit(e: Node) -> void:
	var w: Dictionary = PATHS.water
	e.chill(w.chill_time, w.chill_slow)
	e.chill_hits += 1
	if e.chill_hits >= w.freeze_hits and not e.has_method("is_boss"):
		e.chill_hits = 0
		e.freeze(w.freeze_time, w.shatter_mult)


## Finisher: a ring of ice spikes; damages and freezes everyone in range.
static func glacier(parent: Node, pos: Vector3) -> void:
	var w: Dictionary = PATHS.water
	var r: float = w.glacier_radius
	for i in w.glacier_spikes:
		var ang: float = TAU * i / float(w.glacier_spikes) + randf() * 0.2
		var dist := randf_range(1.5, r)
		var spike := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = randf_range(0.25, 0.45)
		m.height = randf_range(1.2, 2.2)
		spike.mesh = m
		spike.material_override = glow_mat(Color(0.7, 0.92, 1.0), 0.85)
		parent.add_child(spike)
		spike.global_position = pos + Vector3(cos(ang) * dist, -m.height * 0.5, sin(ang) * dist)
		spike.rotation = Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
		var tw := spike.create_tween()
		tw.tween_interval(dist / r * 0.15)
		tw.tween_property(spike, "position:y", m.height * 0.4, 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_interval(w.glacier_freeze - 0.4)
		tw.tween_property(spike, "position:y", -m.height * 0.6, 0.3)
		tw.tween_callback(spike.queue_free)
	Fx.ring(parent, pos, Color(0.6, 0.9, 1.0, 0.95), r, 0.4)
	Fx.burst(parent, pos + Vector3.UP * 0.5, Color(0.8, 0.95, 1.0), 40, 10.0, 0.16, 0.5, Vector3.UP, 90.0)
	Game.sfx("cage_shut", -4.0, 0.05)
	for e in enemies_near(parent.get_tree(), pos, r):
		e.take_hit(w.glacier_damage, Vector3.ZERO, 0.0, true)
		Game.register_hit("glacier")
		if e.is_alive():
			if e.has_method("is_boss"):
				e.chill(w.glacier_freeze, w.chill_slow)
			else:
				e.freeze(w.glacier_freeze, w.shatter_mult)
