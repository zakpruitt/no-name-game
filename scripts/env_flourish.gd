extends RefCounted
## Round 53 (env-flourish lane; docs/features/env-pieces.md "Flourishes"): the heretic's three flourishes on the env-art
## pieces, the proposal's build order items 6-8 (docs/design/environment-per-character.md sections 2 and 5):
##
##   gallows        hook, dark:     a perfect counter's Ricochet with a hook's point within GALLOWS_REACH of the
##                                  attacker hurls it onto the hook (the bracket marks the hook in the counter window,
##                                  env_target CTX "gallows"; the cursor may take a wall or pillar instead). It hangs
##                                  bound GALLOWS_HANG s, swinging with the hook's `hook_swing`, for the wall's damage
##                                  x GALLOWS_MULT, and any hit on it is a Snap (the bound rule): Hang below.
##   ice_rink       pool, ice:      ice on a foe on or within RINK_NEAR of a pool (a foe freezing there, the frost
##                                  spear planted by it) freezes its surface RINK_S s (the water under faceted ice
##                                  panes, frost spreading out, glints). Cubes sliding across it keep their speed and
##                                  go RINK_EXTRA m further (thrown_foe._aim: Slapshot reaches a wall it can't in the
##                                  open), and a foe knocked onto it slides across and freezes (RinkWatch below).
##   brazier_spill  brazier, magma: a Lava Leash seam passing within SPILL_NEAR of a lit brazier tips it into the seam
##                                  (the `brazier_spilled` model turned to face it): the coals run the seam on
##                                  SPILL_EXTEND m and leave a molten patch SPILL_PATCH_S s; Hellseam's geysers erupt
##                                  from the spilled bowl too, and its pile takes x SPILL_HELLSEAM. Any magma hit lights
##                                  an "out" brazier. The bracket marks the brazier during Lava Leash (CTX "brazier").
##
## Each is a Kit.has() upgrade (kit.gd UPGRADES) and is on in a room whose rules say `flourishes` (rooms.gd ROOM_RULES:
## the room with pieces, so they can be practised): on(). Static functions over env_piece.gd's pieces, plus two nodes
## (Hang on a hung foe, RinkWatch on each pool). No class_name: preload it.

const SELF := preload("res://scripts/env_flourish.gd")  # (the inner classes Hang and RinkWatch reach the statics through it)
const ENV_PIECE := preload("res://scripts/env_piece.gd")
const ENV := preload("res://scripts/env_target.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const FOES := preload("res://scripts/foes.gd")
const ROOMS := preload("res://scripts/rooms.gd")
const SPEAR := preload("res://scripts/frost_spear.gd")
const POLISH := preload("res://scripts/designed_polish.gd")
## void_element preloads lava_leash, which preloads this file (env_target.gd has the whole order), so a preload of it
## here would close a cycle: it is loaded once, on first use, and held.
static var _ve_s: GDScript

const IDS := ["gallows", "ice_rink", "brazier_spill"]
const CAMERA_CUE := &"frame_cue_ms"  # (camera_rig.FRAME_CUE; designed_breaker's banner dodges a cued piece too)
const BOUND := "x_bound"  # (floor_bind.BOUND: the element matrix's "bound" state, holds())
const FLYING := "thrown_foe_flying"  # (thrown_foe.FLYING)

## Gallows. The hook's point (the bottom of `hook_swing`) within GALLOWS_REACH m (flat) of the attacker takes Ricochet
## over a foe or a wall; the throw flies over foes (solid false) at RICOCHET_WALL_MULT x GALLOWS_MULT. Caught (it stops
## within GALLOWS_CATCH of the point), it goes up onto the hook in GALLOWS_LIFT s and hangs GALLOWS_HANG s, its feet
## GALLOWS_NECK under the point and GALLOWS_OUT out from it, the hook swinging GALLOWS_SWING rad side to side
## (GALLOWS_SWING_W rad/s, dying away at GALLOWS_DAMP a second). Any hit while it hangs is a Snap.
const GALLOWS_REACH := 10.0
const GALLOWS_MULT := 1.3
const GALLOWS_HANG := 2.5  # s (game)
const GALLOWS_CATCH := 2.6  # m
const GALLOWS_LIFT := 0.12  # s (game)
const GALLOWS_NECK := 0.8  # m: the point to the hung foe's origin (its feet): hooked by the collar, feet well off the floor
const GALLOWS_OUT := 0.3  # m out from the hook's point, off the wall
const GALLOWS_SWING := 0.45  # rad
const GALLOWS_SWING_W := 5.2  # rad/s
const GALLOWS_DAMP := 0.7  # 1/s
const GALLOWS_SETTLE := 1.4  # s the empty hook swings on after
const GALLOWS_WORD := "SHNK-CLANK!"
const GALLOWS_CUE_MS := 2800
const HOOK_TIP_META := &"hook_tip"  # the point in hook_swing's space (cached)

## Ice rink. A pool freezes for RINK_S s (game; a new freeze by it refreshes it). A cube's flight (slide, or el water /
## in its cube) whose line crosses a frozen pool goes RINK_EXTRA m further and never slows (Slapshot 10 -> 16 m). A foe
## hit in the last RINK_KNOCKED_MS and moving faster than RINK_MOVING on the frozen pool freezes and slides on across it
## at its speed, at least RINK_SLIDE_MIN, until it is off the ice.
const RINK_NEAR := 1.0  # m from the pool's square
const RINK_S := 6.0
const RINK_EXTRA := 6.0  # m
const RINK_POLL := 0.1  # s between looks for fresh ice by the pool
const RINK_KNOCKED_MS := 700
const RINK_MOVING := 1.0  # m/s
const RINK_SLIDE_MIN := 4.0  # m/s
const RINK_INSET := 0.14  # m the panes sit in from the water's edge (the kerb's corners are round)
const RINK_PANES := 4  # ice panes a side
const RINK_ICE_Y := 0.09  # m: the panes (the water is at 0.075, the kerb's top 0.18)
const RINK_GLINT_EVERY := 0.32  # real s between glints while frozen
const RINK_GLINT_SIZE := 0.62
const RINK_GLINT_TIMES := [0.05, 0.09, 0.08, 0.07]
const RINK_WORD := "KRRRIK!"
const RINK_SLIDE_WORD := "SKRRRT!"
const SHEETS := {
	"rink_glint": {"grid": Vector2(2, 2), "frames": 4, "kind": "sprite"},
}

## Brazier spill. A seam point within SPILL_NEAR m of a lit brazier's bowl (env_piece.gap) tips it toward the seam: the
## coals run SPILL_EXTEND m from the bowl through the seam (a lava line, and a seam Hellseam runs), the molten patch
## SPILL_PATCH_R round the coals' middle leaves everyone in it molten every SPILL_TICK s for SPILL_PATCH_S s. A Hellseam
## within SPILL_FRESH_MS of the spill erupts along the coals (and at the bowl) and drives its pile x SPILL_HELLSEAM.
## Magma on a foe within LIGHT_NEAR of an out brazier (or a seam by it) lights it.
const SPILL_NEAR := 1.5
const SPILL_EXTEND := 2.0
const SPILL_PATCH_R := 1.1
const SPILL_PATCH_S := 4.0
const SPILL_TICK := 0.5
const SPILL_FRESH_MS := 4500
const SPILL_HELLSEAM := 1.25
const LIGHT_NEAR := 1.5
const SPILL_WORD := "KLANG-FWOOM!"
const LIGHT_WORD := "FWUMP!"
const SPILL_CUE_MS := 2200
const SPILL_NAME := "Spilled"  # the brazier_spilled model, a child of the piece while it lies there

static var _registered := false


## Is flourish `id` on: its Kit upgrade, or the room's `flourishes` rule (round 57: the ids it lists; the room with
## pieces has all three, the cistern gallows and ice_rink, the forge brazier_spill).
static func on(id: String) -> bool:
	return Kit.has(id) or ROOMS.flourish(Game.room, id)


static func _ve() -> GDScript:
	if _ve_s == null:
		_ve_s = load("res://scripts/void_element.gd")
	return _ve_s


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
	for n: String in SHEETS:
		var mi := MeshInstance3D.new()
		mi.mesh = QuadMesh.new()
		mi.material_override = DESIGNED.material(n)
		root.add_child(mi)
		mi.scale = Vector3.ONE * 20.0


## env_piece.place(): a pool gets its watch; a brazier shows its state.
static func placed(n: Node3D) -> void:
	match ENV_PIECE.tag_of(n):
		"pool":
			var w := RinkWatch.new()
			w.name = "RinkWatch"
			w.pool = n
			n.add_child(w)
		"brazier":
			_brazier_look(n)


## env_piece.rebuild(): back as placed (the hook still, the brazier upright, the pool water).
static func restore(n: Node3D) -> void:
	match ENV_PIECE.tag_of(n):
		"hook":
			var sw := _swing(n)
			if sw != null:
				sw.rotation = Vector3.ZERO
		"brazier":
			var sp := n.get_node_or_null(SPILL_NAME)
			if sp != null:
				sp.queue_free()
			for c: Node in n.get_children():
				if c is Node3D and c.name != SPILL_NAME and c.name != "EnvBody":
					(c as Node3D).visible = true
			_brazier_look(n)
		"pool":
			var w: Variant = n.get_node_or_null("RinkWatch")
			if w != null:
				w.thaw()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- gallows --------------------------------------------------------------------------------------------------------

static func _swing(hook: Node3D) -> Node3D:
	return hook.find_child("hook_swing", true, false) as Node3D


## The hook's point (the bottom of hook_swing, as it swings), world.
static func hook_point(hook: Node3D) -> Vector3:
	var sw := _swing(hook)
	if sw == null:  # (no model: 2.24 m under the bracket, 0.55 m out of the wall)
		return hook.global_position + Vector3.DOWN * 2.24 + hook.global_transform.basis.z * 0.55
	if not hook.has_meta(HOOK_TIP_META):
		var tip := Vector3(0.0, -2.2, 0.0)
		if sw is MeshInstance3D and (sw as MeshInstance3D).mesh != null:
			var ab := (sw as MeshInstance3D).get_aabb()
			tip = Vector3(0.0, ab.position.y + 0.06, ab.position.z + ab.size.z * 0.5)
		hook.set_meta(HOOK_TIP_META, tip)
	return sw.global_transform * (hook.get_meta(HOOK_TIP_META) as Vector3)


## The empty hooks whose point is within `reach` (flat) of `from`, nearest first.
static func hooks(tree: SceneTree, from: Vector3, reach: float) -> Array:
	var out := []
	for n: Node in tree.get_nodes_in_group("env_hook"):
		var h := n as Node3D
		if ENV_PIECE.live(h) and ENV_PIECE.state(h) == "empty" and not h.has_meta(&"hook_claimed") and _flat_d(hook_point(h), from) <= reach:
			out.append(h)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return _flat_d(hook_point(a), from) < _flat_d(hook_point(b), from))
	return out


## The hook Ricochet takes `foe` to, or null: the gallows flourish on, and either the hook the counter window's bracket
## was on (env_target CTX "gallows", the cursor's or the auto pick) or the nearest empty one in GALLOWS_REACH. A wall or
## pillar the cursor chose over the hook wins (null: counter.ricochet_target goes there).
static func gallows_hook(hero: Node3D, foe: Node3D) -> Node3D:
	if not on("gallows") or not ENV_PIECE.usable("hook", "gallows") or not is_instance_valid(foe):
		return null
	var from := _flat(foe.global_position)
	var lock: Dictionary = ENV._lock(hero, "gallows")
	if lock.get("chosen", false):
		if not str(lock.get("id", "")).begins_with("hook"):
			return null
		var env: Node = ENV.of(hero.get_tree())
		var s: Dictionary = env.by_id(lock.id) if env != null else {}
		if is_instance_valid(s.get("node")) and s.node in hooks(hero.get_tree(), from, GALLOWS_REACH + 0.5):
			return s.node
	var near := hooks(hero.get_tree(), from, GALLOWS_REACH)
	return near[0] if not near.is_empty() else null


## counter.ricochet: the throw is on its way to `hook` (no other Ricochet takes it meanwhile).
static func claim_hook(hook: Node3D) -> void:
	hook.set_meta(&"hook_claimed", Time.get_ticks_msec())
	var tw := hook.create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(hook) and hook.has_meta(&"hook_claimed"):
			hook.remove_meta(&"hook_claimed"))


## Ricochet's throw stopped by the hook: `foe` goes up on it and hangs (a Hang node). Null if it stopped too far off.
static func hang(hero: Node3D, foe: Node3D, hook: Node3D) -> Node:
	if is_instance_valid(hook) and hook.has_meta(&"hook_claimed"):
		hook.remove_meta(&"hook_claimed")
	if not is_instance_valid(foe) or not foe.is_alive() or not ENV_PIECE.live(hook) or ENV_PIECE.state(hook) != "empty":
		return null
	if _flat_d(foe.global_position, hook_point(hook)) > GALLOWS_CATCH:
		return null
	var h := Hang.new()
	h.hero = hero
	h.foe = foe
	h.hook = hook
	hook.get_parent().add_child(h)
	return h


## The hook's way out of the wall (its model faces +Z).
static func hook_out(hook: Node3D) -> Vector3:
	var z := hook.global_transform.basis.z
	return Vector3(z.x, 0.0, z.z).normalized()


## A foe hung on a hook (gallows): bound (floor_bind.BOUND, so the matrix's Snap pays on it), held on the swinging hook
## until GALLOWS_HANG, a Snap, another move taking it (FLYING), or its death; any hit on it that isn't already the Snap
## pays one (void_element._pay "snap").
class Hang extends Node:
	var hero: Node3D
	var foe: Node3D
	var hook: Node3D
	var t := 0.0
	var _from := Vector3.ZERO
	var _hits := -1
	var _kick := 1.0
	var _done := false
	var _done_t := 0.0
	var _next_stagger := 0.0
	var _swing_at := 0.0  # the swing's angle when it let go
	static var hung := 0  # hangs so far (checks)
	static var snaps := 0

	func _ready() -> void:
		process_physics_priority = 60  # (after the foes' own move_and_slide: the hook holds it)
		_from = foe.global_position
		var side := hook.global_transform.basis.x
		var came: Vector3 = _from - SELF.hook_point(hook)
		_kick = -1.0 if Vector3(side.x, 0.0, side.z).dot(came) > 0.0 else 1.0  # (it swings on away from where it came)
		foe.set_meta(SELF.BOUND, true)
		if foe.has_method("stagger"):
			foe.stagger(0.9)
		hook.set_meta(ENV_PIECE.STATE_META, "hung")
		var now := Time.get_ticks_msec()
		hook.set_meta(SELF.CAMERA_CUE, now + SELF.GALLOWS_CUE_MS)
		foe.set_meta(SELF.CAMERA_CUE, now + SELF.GALLOWS_CUE_MS)
		ENV_PIECE.played("gallows")
		ENV_PIECE.touch(hook, "gallows")
		hung += 1
		var p: Vector3 = SELF.hook_point(hook)
		DESIGNED.hit(hook.get_parent(), p + Vector3.UP * 0.1, "void", 1.1)
		DESIGNED.dust(hook.get_parent(), SELF._flat(p), 0.8)
		ComicFx.say(SELF.GALLOWS_WORD, p + Vector3.UP * 0.9, 0.62)
		Game.hitstop(0.05)
		Game.shake(0.45)
		Game.sfx("hit_big", -3.0, 0.1)
		Game.sfx("swing_heavy", -6.0, 0.1)

	func _physics_process(delta: float) -> void:
		var sw: Node3D = SELF._swing(hook) if is_instance_valid(hook) else null
		if _done:
			_done_t += delta
			if sw != null:
				sw.rotation.z = _swing_at * exp(-3.0 * _done_t) * cos(SELF.GALLOWS_SWING_W * _done_t)
			if _done_t >= SELF.GALLOWS_SETTLE:
				if sw != null:
					sw.rotation.z = 0.0
				queue_free()
			return
		t += delta
		var alive: bool = is_instance_valid(foe) and foe.is_alive()
		if not alive or not is_instance_valid(hook) or foe.has_meta(SELF.FLYING) or not foe.has_meta(SELF.BOUND) or t >= SELF.GALLOWS_HANG:
			_let_go(sw)
			return
		var hits := _hit_count()
		if _hits < 0:
			_hits = hits  # (the throw's own splat came before the first look)
		elif hits > _hits:  # any hit on a hung foe is a Snap
			_snap()
			_let_go(sw)
			return
		var a: float = SELF.GALLOWS_SWING * _kick * exp(-SELF.GALLOWS_DAMP * t) * sin(SELF.GALLOWS_SWING_W * t)
		if sw != null:
			sw.rotation.z = a
		var p: Vector3 = SELF.hook_point(hook)
		var spot: Vector3 = p + SELF.hook_out(hook) * SELF.GALLOWS_OUT + Vector3.DOWN * SELF.GALLOWS_NECK
		var k := clampf(t / SELF.GALLOWS_LIFT, 0.0, 1.0)
		foe.global_position = _from.lerp(spot, 1.0 - (1.0 - k) * (1.0 - k))
		foe.velocity = Vector3.ZERO
		var body: Variant = foe.get("model")
		if body is Node3D:
			(body as Node3D).rotation.z = -a * 0.8  # (it hangs off the hook, swinging with it)
		if t >= _next_stagger and foe.has_method("stagger"):
			_next_stagger = t + 0.25
			foe.stagger(0.9)

	func _hit_count() -> int:
		var n: Variant = foe.get("hits_taken")
		if n == null:
			n = foe.get("hits")
		return int(n) if n != null else 0

	## The bound rule's Snap, paid by a hit the matrix didn't pay (a melee swing, a dark move): void_element._pay.
	func _snap() -> void:
		var VE: GDScript = SELF._ve()
		if not is_instance_valid(hero) or not foe.has_meta("x_bound"):
			return
		snaps += 1
		VE._pay(hero, foe, "snap", "bound", foe.global_position, float(hero.get("_dmg_mult")) if hero.get("_dmg_mult") != null else 1.0, "bound", "void")
		VE.improv_paid["bound"] = int(VE.improv_paid.get("bound", 0)) + 1

	func _let_go(sw: Node3D) -> void:
		_done = true
		_swing_at = sw.rotation.z if sw != null else 0.0
		if is_instance_valid(foe):
			if foe.has_meta(SELF.BOUND):
				foe.remove_meta(SELF.BOUND)
			var body: Variant = foe.get("model")
			if body is Node3D:
				(body as Node3D).rotation.z = 0.0
			if not foe.has_meta(SELF.FLYING):
				foe.velocity = Vector3(0.0, -2.0, 0.0)  # (it drops off the hook)
		if is_instance_valid(hook) and ENV_PIECE.state(hook) == "hung":
			hook.set_meta(ENV_PIECE.STATE_META, "empty")


# --- ice rink -------------------------------------------------------------------------------------------------------

static func frozen_pools(tree: SceneTree) -> Array:
	return tree.get_nodes_in_group("env_pool").filter(func(p: Node) -> bool: return ENV_PIECE.state(p) == "frozen")


## thrown_foe._aim: how much further a cube's flight from `from` along `dir` over `length` goes: RINK_EXTRA for each
## frozen pool its line crosses, else 0. Round 57 (rooms lane): every pool counts, and the line is looked along again
## as it grows, so a channel of frozen pools end to end (the cistern's aqueduct) carries a cube its whole length. One
## pool (all the room with pieces has) is RINK_EXTRA, as before.
static func rink_extra(tree: SceneTree, from: Vector3, dir: Vector3, length: float) -> float:
	if tree == null or not on("ice_rink"):
		return 0.0
	var pools := frozen_pools(tree)
	if pools.is_empty():
		return 0.0
	var crossed := {}
	var looked := 0.0
	var reach := length
	while reach > looked + 0.01:
		var steps := maxi(1, int((reach - looked) / 0.25))
		for i in steps + 1:
			var p := from + dir * lerpf(looked, reach, float(i) / steps)
			for pool: Node3D in pools:
				if not crossed.has(pool) and ENV_PIECE.gap(pool, p) <= 0.0:
					crossed[pool] = true
		looked = reach
		reach = length + RINK_EXTRA * crossed.size()
	return RINK_EXTRA * crossed.size()


## A pool's watch (env_piece.place): fresh ice by it freezes it; frozen, it keeps knocked foes sliding and glints;
## RINK_S after the last ice it thaws.
class RinkWatch extends Node:
	var pool: Node3D
	var _poll := 0.0
	var _was := {}  # foe -> frozen at the last look
	var _sliding := {}  # foe -> its slide velocity (flat)
	var _until := 0.0  # game s left frozen
	var _glint := 0.0
	var _ice: MeshInstance3D
	var _spear := false
	static var freezes := 0  # (checks)
	static var _linking := false  # (round 57: a linked channel's freeze doesn't spread back)
	static var slides := 0

	func _ready() -> void:
		process_physics_priority = -20  # (before the foes' friction: a slide keeps its speed)

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(pool) or not SELF.on("ice_rink"):
			return
		if ENV_PIECE.state(pool) == "frozen":
			_until -= delta
			if _until <= 0.0:
				thaw()
			else:
				_slide()
		_poll -= delta
		if _poll > 0.0:
			return
		_poll = SELF.RINK_POLL
		var tree := pool.get_tree()
		var fresh := false
		var seen := {}
		var VE: GDScript = SELF._ve()
		for e: Node in tree.get_nodes_in_group("enemies"):
			if not e.is_alive():
				continue
			var cold: bool = VE.is_frozen(e)
			seen[e] = cold
			if cold and not _was.get(e, false) and ENV_PIECE.gap(pool, (e as Node3D).global_position) <= SELF.RINK_NEAR:
				fresh = true
		_was = seen
		var spear: Node3D = SPEAR.current(tree)
		var by_spear: bool = spear != null and ENV_PIECE.gap(pool, spear.global_position) <= SELF.RINK_NEAR
		if by_spear and not _spear:
			fresh = true
		_spear = by_spear
		if fresh:
			freeze()

	func _process(_delta: float) -> void:
		if not is_instance_valid(pool) or ENV_PIECE.state(pool) != "frozen":
			return
		_glint -= get_process_delta_time() / maxf(Engine.time_scale, 0.05)
		if _glint > 0.0:
			return
		_glint = SELF.RINK_GLINT_EVERY * randf_range(0.6, 1.4)
		var h: float = float(ENV_PIECE.PIECES.pool.size.x) * 0.36
		var at := pool.global_position + Vector3(randf_range(-h, h), SELF.RINK_ICE_Y + 0.12, randf_range(-h, h))
		SELF.register()
		var g: Node3D = DESIGNED.spawn(pool.get_parent(), "rink_glint", at, SELF.RINK_GLINT_SIZE * randf_range(0.7, 1.15), "water",
			SELF.RINK_GLINT_TIMES, Vector2(0.7, 1.0))
		g.real_until = 4

	## Ice by the pool: frozen (or RINK_S more). Round 57: in a room whose `links` hold "pool", every pool touching this
	## one is the same water and freezes with it (ENV_PIECE.linked).
	func freeze() -> void:
		_until = SELF.RINK_S
		if not _linking:
			_linking = true
			for other: Node3D in ENV_PIECE.linked(pool):
				var w := other.get_node_or_null("RinkWatch")
				if w != null:
					w.freeze()
			_linking = false
		if ENV_PIECE.state(pool) == "frozen":
			return
		pool.set_meta(ENV_PIECE.STATE_META, "frozen")
		freezes += 1
		ENV_PIECE.played("ice_rink")
		ENV_PIECE.touch(pool, "ice_rink")
		var water := pool.find_child("pool_water", true, false) as Node3D
		if water != null:
			water.visible = false
		if _ice == null:
			_ice = SELF.rink_ice(pool)
		if _ice != null:
			_ice.visible = true
			_ice.set_instance_shader_parameter("alpha", 1.0)
			var tw := _ice.create_tween()
			_ice.scale = Vector3(0.6, 1.0, 0.6)
			tw.tween_property(_ice, "scale", Vector3.ONE, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		var parent := pool.get_parent()
		var c: Vector3 = SELF._flat(pool.global_position)
		# the frost spreads out over it from the middle, corner to corner
		DESIGNED_EL.frost_burst(parent, c, 2.2)
		var h: float = float(ENV_PIECE.PIECES.pool.size.x) * 0.3
		for k: Vector3 in [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]:
			DESIGNED_EL.frost_mark(parent, c + k, 1.05, 0.9, false)
		ComicFx.say(SELF.RINK_WORD, c + Vector3.UP * 1.3, 0.5)
		Game.sfx("cast_water", -5.0, 0.1)

	## Back to water.
	func thaw() -> void:
		_until = 0.0
		_sliding.clear()
		if not is_instance_valid(pool):
			return
		if ENV_PIECE.state(pool) == "frozen":
			pool.set_meta(ENV_PIECE.STATE_META, "water")
		var water := pool.find_child("pool_water", true, false) as Node3D
		if water != null:
			water.visible = true
		if _ice != null and _ice.visible:
			DESIGNED.dust(pool.get_parent(), pool.global_position, 1.1)
			_ice.visible = false

	## Foes knocked onto the frozen pool slide on across it, frozen.
	func _slide() -> void:
		var now := Time.get_ticks_msec()
		var VE: GDScript = SELF._ve()
		for e: Variant in _sliding.keys():
			if not is_instance_valid(e) or not e.is_alive() or e.has_meta(SELF.FLYING) or e.has_meta(SELF.BOUND) \
					or ENV_PIECE.gap(pool, (e as Node3D).global_position) > 0.0:
				_sliding.erase(e)
				continue
			var v: Vector3 = _sliding[e]
			e.velocity.x = v.x
			e.velocity.z = v.z
		for e: Node3D in ENV_PIECE.on_tile(pool):
			if _sliding.has(e) or e.has_meta(SELF.FLYING) or e.has_meta(SELF.BOUND):
				continue
			var flat := Vector3(e.velocity.x, 0.0, e.velocity.z)
			var hit_ms: Variant = e.get("last_hit_ms")
			if flat.length() < SELF.RINK_MOVING or hit_ms == null or now - int(hit_ms) > SELF.RINK_KNOCKED_MS:
				continue
			_sliding[e] = flat.normalized() * maxf(flat.length(), SELF.RINK_SLIDE_MIN)
			slides += 1
			VE.encase(e)  # (the frozen rule's state: the next hit Shatters it)
			_was[e] = true  # (the rink's own ice doesn't keep it frozen: only ice from a move does)
			ComicFx.say(SELF.RINK_SLIDE_WORD, e.global_position + Vector3.UP * 1.6, 0.42)
			DESIGNED_EL.frost_mark(pool.get_parent(), SELF._flat(e.global_position), 0.8, 0.6, true)


## The frozen surface: RINK_PANES x RINK_PANES faceted ice panes over the water (designed_elements.facet_material, the
## ice block's look; no crystals), a child of the pool, hidden until it freezes.
static func rink_ice(pool: Node3D) -> MeshInstance3D:
	var water := pool.find_child("pool_water", true, false) as MeshInstance3D
	var ab := AABB(Vector3(-1.56, 0.075, -1.5), Vector3(3.12, 0.0, 3.0))
	if water != null and water.mesh != null:
		ab = (pool.global_transform.affine_inverse() * water.global_transform) * water.get_aabb()
	ab = AABB(ab.position + Vector3(RINK_INSET, 0.0, RINK_INSET), ab.size - Vector3(RINK_INSET * 2.0, 0.0, RINK_INSET * 2.0))  # (inside the kerb's round corners)
	var f: RefCounted = DESIGNED_EL.Facets.new()
	f.centre = ab.get_center() + Vector3.DOWN * 0.4
	var n := RINK_PANES
	var y := RINK_ICE_Y
	for i in n:
		for j in n:
			var x0: float = ab.position.x + ab.size.x * float(i) / n
			var x1: float = ab.position.x + ab.size.x * float(i + 1) / n
			var z0: float = ab.position.z + ab.size.z * float(j) / n
			var z1: float = ab.position.z + ab.size.z * float(j + 1) / n
			f.quad(Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3(x0, y, z0))
	var mi := MeshInstance3D.new()
	mi.name = "RinkIce"
	mi.mesh = f.commit(DESIGNED_EL.facet_material("water"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.visible = false
	pool.add_child(mi)
	return mi


# --- brazier spill --------------------------------------------------------------------------------------------------

## The bowl's coals and flame show its state: lit (coals, flame), out (ash only).
static func _brazier_look(n: Node3D) -> void:
	var lit := ENV_PIECE.state(n) != "out"
	for nm: String in ["brazier_coals", "brazier_flame"]:
		var c := n.find_child(nm, false, false) as Node3D
		if c != null:
			c.visible = lit
	var ash := n.find_child("brazier_ash", false, false) as Node3D
	if ash != null:
		ash.visible = not lit


static func _lit(n: Node3D) -> bool:
	return ENV_PIECE.live(n) and ENV_PIECE.state(n) == "lit"


## Lava Leash's seam reached `at` (lava_leash._seam_add, the drag of one foe from `from` toward `to`): a lit brazier
## within SPILL_NEAR of it tips into the seam; an out one lights.
static func leash_seam(hero: Node, at: Vector3, from: Vector3, to: Vector3) -> void:
	if hero == null or not hero.is_inside_tree() or not on("brazier_spill") or not ENV_PIECE.usable("brazier", "brazier_spill"):
		return
	for b: Node3D in ENV_PIECE.near(hero.get_tree(), "brazier", at, SPILL_NEAR):
		if _lit(b):
			spill(b, at, (to - from), hero)
		elif ENV_PIECE.state(b) == "out":
			light(b)


## Tips brazier `n` into the seam at `seam_at` (the drag running along `run`): the spilled model turned to face it,
## the coals' lava line, the molten patch, the word. Used up until the training rebuild.
static func spill(n: Node3D, seam_at: Vector3, run: Vector3, by: Node) -> void:
	var b := _flat(n.global_position)
	var to := _flat(seam_at) - b
	if to.length() < 0.2:  # (the seam runs over its middle: it goes over along the drag)
		to = _flat(run)
	var dir := to.normalized() if to.length() > 0.01 else Vector3.BACK
	var parent := n.get_parent()
	for c: Node in n.get_children():
		if c is Node3D and c.name != "EnvBody":
			(c as Node3D).visible = false
	var sp: Node3D = ComicLook.piece("brazier_spilled")
	sp.name = SPILL_NAME
	n.add_child(sp)
	sp.global_rotation = Vector3(0.0, atan2(dir.x, dir.z), 0.0)
	sp.scale = Vector3(1.0, 0.4, 1.0)
	var tw := sp.create_tween()
	tw.tween_property(sp, "scale", Vector3.ONE, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var a := b + dir * 0.3
	var z := b + dir * (0.3 + SPILL_EXTEND)
	n.set_meta(&"spill_seam", [z, b - dir * 1.0])  # (Hellseam runs it out from behind the bowl: a geyser on the coals by it and one at their end)
	n.set_meta(&"spill_ms", Time.get_ticks_msec())
	var now := Time.get_ticks_msec()
	n.set_meta(CAMERA_CUE, now + SPILL_CUE_MS)
	ENV_PIECE.use_up(n, "spilled")
	ENV_PIECE.played("brazier_spill")
	ENV_PIECE.touch(n, "brazier_spill")
	DESIGNED_EL.fissure(parent, a, dir, SPILL_EXTEND, 3, "earth", 0.9)
	DESIGNED_EL.pool(parent, b + dir * 1.0, SPILL_PATCH_R)
	DESIGNED.dust(parent, b, 1.1)
	POLISH.chips(parent, b + Vector3.UP * 0.9, Color(1.0, 0.45, 0.1), 8, 6.0, Vector3.UP, true)
	ComicFx.say(SPILL_WORD, b + Vector3.UP * 2.0, 0.58)
	Game.shake(0.35)
	Game.sfx("hit_big", -4.0, 0.12)
	Game.sfx("cast_earth", -6.0, 0.1)
	_patch_tick(n, b + dir * 1.0, SPILL_PATCH_S, by)


## Round 57 (rooms lane): a Powder Keg burst at `at` (env_piece._keg_burst) tips every lit brazier within KEG_R of it,
## away from the blast: the coals run out, the molten patch, Hellseam fresh on them. The forge's powder line between two
## braziers; the room with pieces has its brazier 6 m from its barrel, out of reach.
static func keg_spill(tree: SceneTree, at: Vector3, by: Node) -> void:
	if tree == null or not on("brazier_spill") or not ENV_PIECE.usable("brazier", "brazier_spill"):
		return
	for b: Node3D in ENV_PIECE.near(tree, "brazier", at, ENV_PIECE.KEG_R):
		if _lit(b):
			var away := _flat(b.global_position) - _flat(at)
			away = away.normalized() if away.length() > 0.05 else Vector3.BACK
			spill(b, _flat(b.global_position) + away, away, by)
			ENV_PIECE.played("keg_spill")


## The molten patch: everyone in it is left molten, every SPILL_TICK s for its life.
static func _patch_tick(n: Variant, at: Vector3, left: float, _by: Variant) -> void:
	if not is_instance_valid(n) or not (n as Node).is_inside_tree() or left <= 0.0:
		return
	var tree := (n as Node).get_tree()
	var VE: GDScript = _ve()
	for e: Node3D in FOES.near(tree, at, SPILL_PATCH_R):
		if not VE.marked(e, "molten"):
			VE.mark(e, "molten")
	tree.create_timer(SPILL_TICK, false).timeout.connect(_patch_tick.bind(n, at, left - SPILL_TICK, _by))


## Lights an out brazier (magma by it).
static func light(n: Node3D) -> void:
	if not ENV_PIECE.live(n) or ENV_PIECE.state(n) != "out":
		return
	n.set_meta(ENV_PIECE.STATE_META, "lit")
	_brazier_look(n)
	ENV_PIECE.played("brazier_light")
	var flame := n.global_position + Vector3.UP * 1.15
	DESIGNED.hit(n.get_parent(), flame, "earth", 0.9)
	ComicFx.say(LIGHT_WORD, flame + Vector3.UP * 0.7, 0.42)
	Game.sfx("cast_earth", -8.0, 0.1)


## Magma reached foe `e` (env_piece.marked "molten"): an out brazier within LIGHT_NEAR lights.
static func molten_near(e: Node3D) -> void:
	if not on("brazier_spill"):
		return
	for b: Node3D in ENV_PIECE.near(e.get_tree(), "brazier", e.global_position, LIGHT_NEAR):
		if ENV_PIECE.state(b) == "out":
			light(b)


## Hellseam (void_element._hellseam): the spilled braziers' coal seams to erupt along too ([[far, near], ...]), and
## the bowls themselves as one-point seams.
static func spill_seams(tree: SceneTree) -> Array:
	var out := []
	if tree == null:
		return out
	var now := Time.get_ticks_msec()
	for n: Node in tree.get_nodes_in_group("env_brazier"):
		if ENV_PIECE.state(n) == "spilled" and now - int(n.get_meta(&"spill_ms", 0)) <= SPILL_FRESH_MS and n.has_meta(&"spill_seam"):
			out.append(n.get_meta(&"spill_seam"))
	return out


## The lit brazier a Lava Leash in play (or about to be: Molten Palm's foes toward the pile) would tip, or null: the
## bracket's (env_target CTX "brazier").
static func leash_brazier(h: Node3D) -> Node3D:
	if not on("brazier_spill") or not ENV_PIECE.usable("brazier", "brazier_spill"):
		return null
	var tree := h.get_tree()
	var lit: Array = tree.get_nodes_in_group("env_brazier").filter(func(b: Node) -> bool: return _lit(b))
	if lit.is_empty():
		return null
	var segs := []
	var g: Variant = h.get_meta("lava_leash") if h.has_meta("lava_leash") else null
	if is_instance_valid(g):
		for one: Dictionary in g.grabs:
			if not one.get("arrived", false) and is_instance_valid(one.foe):
				segs.append([_flat(one.get("from", (one.foe as Node3D).global_position)), _flat(one.to)])
	else:
		var VE: GDScript = h.VOID_ELEMENT
		var me := _flat(h.global_position)
		var pile: Vector3 = me + h._facing() * VE.LEASH_PILE
		for e: Node in FOES.near(tree, me, VE.LEASH_REACH):
			if VE.palm_fresh(e):
				segs.append([_flat((e as Node3D).global_position), pile])
	for b: Node3D in lit:
		for s: Array in segs:
			if ENV_PIECE.gap(b, _closest(s[0], s[1], b.global_position)) <= SPILL_NEAR:
				return b
	return null


static func _closest(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var ab := b - a
	var k := clampf((_flat(p) - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return a + ab * k
