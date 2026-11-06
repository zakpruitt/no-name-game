extends Node3D
## Sunbrand, the dragon prince's one sword out in the world (docs/characters/dragon-prince.md section 2, the
## "One Sword" rule): held (this node hidden, the hand sword shows), in flight (a Javelin), planted (in the floor,
## or in a foe: branded, and it rides along), returning (the recall, or the auto-return), and shattered (the smash
## blew it up; a new one forms in his hand after REFORM_TIME). prince.gd drives it; this file owns where it is,
## its hits, and the beacon that says "your sword is here".

const PRINCE_FX := preload("res://scripts/prince/prince_fx.gd")

enum S { HELD, FLIGHT, PLANTED, RETURN, SHATTERED }

const SPEED := 22.0  # m/s, the Javelin
const RANGE := 9.0  # m before it drops into the floor
const HIT_RADIUS := 0.7  # m either side of its line, plus the foe's radius
const DAMAGE := 16.0  # the Javelin's bite
const CARRY := 9.0  # knockback on the foe it bites (it's carried a few metres with the sword in it)
const IN_FOE_HEIGHT := 1.15  # m up the foe the sword sits
const PLANT_DEPTH := 0.35  # m of blade under the floor
const AUTO_RETURN := 6.0  # s out before it flies home by itself (no hits)
const RECALL_TIME := 0.25  # s, Rightful Return
const RECALL_DAMAGE := 9.0
const RECALL_DRAG := 9.0  # knockback toward him on the foe the sword was in
const REFORM_TIME := 0.7  # s from the blast to the new sword in his hand (open question 3: automatic)
const BLAST_RADIUS := 3.5
const BLAST_DAMAGE := 34.0
const BLAST_KNOCK := 7.0
const BLAST_LAUNCH := 6.0
const BEACON_H := 3.2
const SPIN := 22.0  # rad/s about its long axis in flight

signal changed(state: int)

var state := S.HELD
var hero: CharacterBody3D
var host: Node3D  # the foe it's planted in (branded), or null
var _t := 0.0  # s in this state
var _dir := Vector3.FORWARD
var _from := Vector3.ZERO
var _travel := 0.0
var _hit := {}  # foes hit this flight / return
var _recall_hits := true
var _spin := 0.0
var _tilt := Vector3.ZERO  # the planted lean
var _mesh: Node3D
var _beacon: MeshInstance3D
var _ring: MeshInstance3D
# For the checks and the readout:
var bites := 0
var blasts := 0
var last_blast_hits := 0
var last_blast_damage := 0.0
var recall_hits := 0


func setup(h: CharacterBody3D) -> void:
	hero = h
	top_level = true
	_mesh = PRINCE_FX.sword()
	add_child(_mesh)
	_beacon = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.025
	c.bottom_radius = 0.05
	c.height = BEACON_H
	c.radial_segments = 6
	_beacon.mesh = c
	_beacon.material_override = PRINCE_FX.flat(Color(PRINCE_FX.SAPPHIRE_LIGHT, 0.7), true)
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.top_level = true
	add_child(_beacon)
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.62
	t.outer_radius = 0.72
	t.rings = 24
	t.ring_segments = 4
	_ring.mesh = t
	_ring.material_override = PRINCE_FX.flat(Color(PRINCE_FX.GOLD, 0.85), true)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	_ring.scale = Vector3(1.0, 0.15, 1.0)
	add_child(_ring)
	_show(false)


## "hand", "out" or "shattered": what the buttons do (prince_moves.route()).
func state_word() -> String:
	match state:
		S.HELD: return "hand"
		S.SHATTERED: return "shattered"
	return "out"


func is_out() -> bool:
	return state in [S.FLIGHT, S.PLANTED, S.RETURN]


## Where a smash lands: the floor under the sword.
func ground_point() -> Vector3:
	var p := host.global_position if is_instance_valid(host) and state == S.PLANTED else global_position
	return Vector3(p.x, 0.0, p.z)


func _enter(s: S) -> void:
	state = s
	_t = 0.0
	_show(s in [S.FLIGHT, S.PLANTED, S.RETURN])
	changed.emit(s)


func _show(on: bool) -> void:
	_mesh.visible = on
	_beacon.visible = on and state == S.PLANTED
	_ring.visible = on and state == S.PLANTED


## The Javelin: off his hand along `dir`.
func throw(from: Vector3, dir: Vector3) -> void:
	_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	_from = from
	_travel = 0.0
	_hit.clear()
	host = null
	global_position = from
	_enter(S.FLIGHT)
	_point_along(_dir)


## Sends it home (Rightful Return): along a straight line in RECALL_TIME, hitting all on it (`hits`).
func recall(hits := true) -> void:
	if not is_out():
		return
	_from = global_position
	_hit.clear()
	_recall_hits = hits
	if is_instance_valid(host) and hits:
		var to: Vector3 = hero.global_position - host.global_position
		to.y = 0.0
		if host.has_method("take_hit") and host.is_alive():
			host.take_hit(RECALL_DAMAGE, to.normalized() * RECALL_DRAG, 0.0, false)
			_hit[host] = true
			recall_hits += 1
	host = null
	_enter(S.RETURN)


## The smash landed: it explodes at the floor under it. Returns foes hit.
func detonate(mult := 1.0) -> int:
	var at := ground_point()
	var n := 0
	var total := 0.0
	for e in hero.get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - at
		to.y = 0.0
		if to.length() > BLAST_RADIUS + e.radius:
			continue
		var dir: Vector3 = to.normalized() if to.length() > 0.05 else hero.facing_dir()
		e.take_hit(BLAST_DAMAGE * mult * hero._dmg_mult, dir * BLAST_KNOCK, BLAST_LAUNCH, true)
		Fx.element_hit(hero.get_parent(), e.global_position, "spirit", dir, true)
		Game.register_hit("P_SMASH")
		n += 1
		total += BLAST_DAMAGE * mult * hero._dmg_mult
	PRINCE_FX.blast(hero.get_parent(), at, BLAST_RADIUS)
	host = null
	blasts += 1
	last_blast_hits = n
	last_blast_damage = total
	_enter(S.SHATTERED)
	return n


func _physics_process(delta: float) -> void:
	_t += delta
	match state:
		S.FLIGHT: _fly(delta)
		S.PLANTED: _planted(delta)
		S.RETURN: _return(delta)
		S.SHATTERED:
			if _t >= REFORM_TIME:
				_enter(S.HELD)
				hero.sword_formed()


func _fly(delta: float) -> void:
	var step := SPEED * delta
	var a := global_position
	var b := a + _dir * step
	# a wall ahead: plant at it (the wall pin is the next slice)
	var q := PhysicsRayQueryParameters3D.create(a, b + _dir * 0.3, 1)
	var wall := get_world_3d().direct_space_state.intersect_ray(q)
	for e in hero.get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive() or _hit.has(e):
			continue
		var p: Vector3 = e.global_position
		p.y = a.y
		if _seg_dist(p, a, b) <= HIT_RADIUS + e.radius:
			_hit[e] = true
			e.take_hit(DAMAGE * hero._dmg_mult, _dir * CARRY, 0.0, true)
			Fx.element_hit(hero.get_parent(), e.global_position, "spirit", _dir, true)
			PRINCE_FX.bite(hero.get_parent(), e.global_position + Vector3.UP * 1.0, _dir)
			Game.register_hit("P_JAVELIN")
			Game.hitstop(0.06)
			Game.shake(0.25)
			bites += 1
			hero.on_sword_hit(e)
			host = e
			_tilt = Vector3(-_dir.x, 0.0, -_dir.z)
			_enter(S.PLANTED)
			_planted(0.0)
			return
	_travel += step
	if not wall.is_empty() or _travel >= RANGE:
		var at: Vector3 = wall.position - _dir * 0.4 if not wall.is_empty() else b
		global_position = Vector3(at.x, 0.0, at.z)
		_tilt = -_dir
		_enter(S.PLANTED)
		_planted(0.0)
		Fx.dust(hero.get_parent(), global_position, 6)
		return
	global_position = b
	_spin += SPIN * delta
	_point_along(_dir)


func _planted(_delta: float) -> void:
	var base: Vector3
	if host != null:
		if not is_instance_valid(host) or not host.is_alive():
			host = null
			base = Vector3(global_position.x, 0.0, global_position.z)
		else:
			base = host.global_position + Vector3.UP * IN_FOE_HEIGHT
	else:
		base = Vector3(global_position.x, 0.0, global_position.z)
	# point down into the floor (or the foe), leaning back the way it came from
	var down := (Vector3.DOWN + _tilt * 0.35).normalized()
	var up := -down
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var tip_len := PRINCE_FX.BLADE_L + PRINCE_FX.TIP_L + 0.08
	var sunk := PLANT_DEPTH if host == null else 0.55
	_mesh.global_basis = Basis(side, down, side.cross(down)).orthonormalized()
	global_position = base
	_mesh.global_position = base + up * (tip_len - sunk)
	var floor_at := Vector3(base.x, 0.0, base.z)
	var pulse := 1.0 + 0.08 * sin(_t * (14.0 if hero.smash_hanging() else 6.0))
	_beacon.global_position = floor_at + Vector3.UP * (BEACON_H * 0.5 + 0.1)
	_ring.global_position = floor_at + Vector3.UP * 0.06
	_ring.scale = Vector3(pulse, 0.15, pulse)
	if state == S.PLANTED and _t >= AUTO_RETURN:
		recall(false)


func _return(_delta: float) -> void:
	var to: Vector3 = hero.global_position + Vector3.UP * 1.0
	var k := clampf(_t / RECALL_TIME, 0.0, 1.0)
	var a := global_position
	var b := _from.lerp(to, k)
	var d := (to - _from)
	_point_along(-d.normalized() if d.length() > 0.1 else Vector3.FORWARD)  # pommel first, the blade trailing
	_mesh.global_position = b
	if _recall_hits:
		for e in hero.get_tree().get_nodes_in_group("enemies"):
			if not e.is_alive() or _hit.has(e):
				continue
			var p: Vector3 = e.global_position
			p.y = a.y
			if _seg_dist(p, a, b) <= HIT_RADIUS + e.radius:
				_hit[e] = true
				var dir := Vector3(d.x, 0.0, d.z).normalized()
				e.take_hit(RECALL_DAMAGE * hero._dmg_mult, dir * 3.0, 0.0, false)
				Fx.element_hit(hero.get_parent(), e.global_position, "spirit", dir, false)
				Game.register_hit("P_RECALL")
				recall_hits += 1
	global_position = b
	if k >= 1.0:
		_enter(S.HELD)
		hero.sword_caught()


func _point_along(dir: Vector3) -> void:
	var y := dir.normalized()
	var side := y.cross(Vector3.UP)
	if side.length() < 0.1:
		side = Vector3.RIGHT
	side = side.normalized()
	var bas := Basis(side, y, side.cross(y)).orthonormalized()
	_mesh.global_basis = bas.rotated(y, _spin) if state == S.FLIGHT else bas
	_mesh.global_position = global_position


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)
