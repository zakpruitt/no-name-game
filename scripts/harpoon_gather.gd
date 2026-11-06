extends Node3D
## Harpoon's gather (Dash L H, round 47, Zak: "harpoon grabs any enemies near by in a clean tentacle animation and
## places them in a line or group in front of the heretic"): a tentacle per foe within VOID_ELEMENT.HARPOON_REACH of
## him (nearest first, HARPOON_MAX at most, Galvanize's family), each in four beats:
##   1. reach: it leaves his claw STAGGER s after the last and runs out to the foe in REACH s;
##   2. latch: it coils round the foe, the hit lands (on_latch) and the foe is held;
##   3. carry: a quick curved lift over CARRY s, up LIFT m and round him (never through him) to its slot;
##   4. set down: the foe lands in its slot, the cube forms on it (on_set) and the tentacle lets go over LET_GO s.
## Big ones are latched and frozen where they stand. The slots are VOID_ELEMENT.harpoon_slots(): one tidy rank across
## his aim. Gameplay and look are one node (the foe is moved by it, so nothing else may: thrown_foe's FLYING meta).
## Game time, so the hit stops hold it like they hold the move. Headless it draws nothing but still carries.
##   var g := HARPOON_GATHER.start(hero, [{"foe": e, "to": slot, "heavy": false}, ...])
##   g.on_latch = func(e): ...;  g.on_set = func(e): ...
## While he hangs in a breaker the tentacles are void_grab.seize()'s (`hold_cubes`): these let go once he leaps.

const SELF := preload("res://scripts/harpoon_gather.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")

const STAGGER := 0.02  # s between the tentacles leaving his claw (Galvanize: 0.035)
const REACH := 0.05  # s out to the foe
const CARRY := 0.12  # s the carry takes, latch to set down
const LIFT := 1.3  # m the carry's arc rises at its middle (more for a longer carry, CARRY_LIFT_PER)
const CARRY_LIFT_PER := 0.12  # m more per m carried
const ROUND := 1.6  # m: a carry whose straight path would pass closer than this to him bends out round him
const LET_GO := 0.08  # s the tentacle draws back after the set down
const WAVE := 0.06  # the reach's whip
const CHEST := Vector3(0.0, 0.9, 0.0)
const FLYING := "thrown_foe_flying"  # (thrown_foe.FLYING: nothing else moves it while carried)

var hero: CharacterBody3D
var grabs := []  # {foe, to, heavy, t0, from, ctrl, latched, set, set_t, tendril}
var on_latch := Callable()  # (foe) the tentacle arrives: the hit
var on_set := Callable()  # (foe) set down in its slot (or, a big one, latched): the cube
var _t := 0.0


static func start(by: CharacterBody3D, with: Array) -> Node3D:
	var g: Node3D = SELF.new()
	g.hero = by
	for i in with.size():
		var one: Dictionary = with[i].duplicate()
		one.t0 = i * STAGGER
		one.latched = false
		one.set = false
		one.set_t = 0.0
		g.grabs.append(one)
	by.get_parent().add_child(g)
	return g


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for g: Dictionary in grabs:
		g.tendril = TENDRIL.new()
		add_child(g.tendril)


## Done once every tentacle has let go.
func done() -> bool:
	for g: Dictionary in grabs:
		if not g.set or _t - g.t0 - g.set_t < LET_GO:
			if _alive(g.foe):
				return false
	return true


## Who it still carries (not set down yet).
func carrying() -> Array:
	return grabs.filter(func(g: Dictionary) -> bool: return g.latched and not g.set and _alive(g.foe)).map(
		func(g: Dictionary) -> Node3D: return g.foe)


func _physics_process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(hero) or hero._void == null:
		_drop_all()
		queue_free()
		return
	var hand: Vector3 = hero._void._hand_pos()
	var leaping: bool = hero.state == hero.State.LEAP  # (the breaker's own tentacles hold them now)
	for g: Dictionary in grabs:
		var e: Variant = g.foe
		var tendril: Node3D = g.tendril
		if not _alive(e):
			tendril.visible = false
			continue
		var local: float = _t - g.t0
		if local < 0.0:
			tendril.visible = false
			continue
		if local < REACH:  # 1. reach
			tendril.draw(hand, (e as Node3D).global_position + CHEST, smoothstep(0.0, REACH, local), WAVE, 0.0, _t)
			continue
		if not g.latched:  # 2. latch
			g.latched = true
			_latch(g)
		var coil: float = float(e.radius) + 0.05
		if not g.set and local < REACH + CARRY and not g.heavy:  # 3. carry
			var k: float = clampf((local - REACH) / CARRY, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			var at := _bezier(g.from, g.ctrl, g.to, k)
			e.global_position = at
			e.velocity = Vector3.ZERO
			tendril.draw(hand, at + CHEST, 1.0, 0.03, coil, _t)
			continue
		if not g.set:  # 4. set down
			g.set = true
			g.set_t = local
			_set_down(g)
		var out: float = 1.0 - smoothstep(0.0, LET_GO, local - g.set_t)
		if leaping:
			out = 0.0
		tendril.draw(hand, (e as Node3D).global_position + CHEST, out, 0.02, coil if out > 0.5 else 0.0, _t)
	if done():
		queue_free()


## Everyone not set down yet is, now, in their slot (latched first if the tentacle hadn't arrived): the breaker's
## hang takes the row from here (void_grab.seize, `hold_cubes`), so nobody may still be in the air or uncubed.
func finish_now() -> void:
	for g: Dictionary in grabs:
		if g.set or not _alive(g.foe):
			continue
		if not g.latched:
			g.latched = true
			_latch(g)
		if not g.set:
			g.set = true
			g.set_t = _t - g.t0
			_set_down(g)


func _latch(g: Dictionary) -> void:
	var e: Node3D = g.foe
	g.from = e.global_position
	if not g.heavy:
		e.set_meta(FLYING, true)
		var mid: Vector3 = (g.from + g.to) * 0.5
		var span: float = Vector3(g.to.x - g.from.x, 0.0, g.to.z - g.from.z).length()
		var ctrl: Vector3 = mid + Vector3.UP * (LIFT + CARRY_LIFT_PER * span) * 2.0  # (a quadratic's middle reaches half its control's rise)
		# Round him, not through him: a carry from behind passes his side.
		var me := Vector3(hero.global_position.x, 0.0, hero.global_position.z)
		var flat_mid := Vector3(mid.x, 0.0, mid.z)
		var off := flat_mid - me
		if off.length() < ROUND:
			var fwd: Vector3 = hero._facing()
			var side := fwd.cross(Vector3.UP).normalized()
			var lean := signf((g.from - me).dot(side) + (g.to - me).dot(side))
			if lean == 0.0:
				lean = 1.0
			var push: Vector3 = side * lean * (ROUND - off.length()) * 2.0
			ctrl += push
		g.ctrl = ctrl
	if on_latch.is_valid():
		on_latch.call(e)
	if g.heavy and on_set.is_valid():  # (frozen where it stands)
		g.set = true
		g.set_t = _t - g.t0
		on_set.call(e)


func _set_down(g: Dictionary) -> void:
	var e: Node3D = g.foe
	e.global_position = g.to
	e.velocity = Vector3.ZERO
	if e.has_meta(FLYING):
		e.remove_meta(FLYING)
	if on_set.is_valid():
		on_set.call(e)


func _drop_all() -> void:
	for g: Dictionary in grabs:
		if _alive(g.foe) and (g.foe as Node).has_meta(FLYING):
			(g.foe as Node3D).global_position.y = 0.0
			(g.foe as Node).remove_meta(FLYING)


func _exit_tree() -> void:
	_drop_all()  # (freed mid-carry: nobody stays stuck as flying)


static func _bezier(a: Vector3, c: Vector3, b: Vector3, k: float) -> Vector3:
	return a.lerp(c, k).lerp(c.lerp(b, k), k)


static func _alive(e: Variant) -> bool:
	return is_instance_valid(e) and e.is_alive()
