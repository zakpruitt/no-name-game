extends Node3D
## Flash Freeze (Steam Burst's window, H, round 52 cool pass; docs/features/combo-breakers.md "Round 52 cool pass"):
## the steam Steam Burst blew off the ice rolls out over everyone near where he will land and sets on them, then his
## landing shatters one and the break runs from shell to shell. Three beats:
##   1. roll: on the dive the steam (the `steam_shell` sheet) rolls out from the landing over each foe within reach,
##      nearest first, SET_STEP s apart;
##   2. set: as it reaches a foe it sets into a frost shell, Zak's fitted ice block (void_element.encase), on_set(foe, i);
##   3. break: shatter(first) (the landing) breaks the picked one (env_target "flash_freeze": the cursor's, or the one
##      nearest the landing), and a frost line races along the floor to the nearest shell not yet broken, LINK s a
##      link, breaking each in turn, on_link(foe, k): a beat harder each (void_element.FF_LINK_PER).
## Game time (hit stops hold it). Headless it draws nothing but sets and breaks them.
##   var g := FROST_SHELL.start(hero, at, foes)       # at the dive
##   g.on_set = func(e, i): ...;  g.on_link = func(e, k): ...;  g.shatter(first)   # at the landing

const SELF := preload("res://scripts/frost_shell.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")

const SET_STEP := 0.035  # s between shells setting (the dive is 0.12 s: four set before he lands)
const LINK := 0.09  # s the break takes from one shell to the next
const SHELL_SIZE := 3.4  # m: the steam_shell quad (the puffs stand ~1.9 m round a dummy, over its block)
const SHELL_BACK := -0.4  # m along the camera's look (negative: toward it, so the puffs roll over the block, not behind it)
const SHELL_TIMES := [0.04, 0.06, 0.07, 0.08, 0.12, 0.16]
const LINE_STEPS := 4
const LINK_WORD := "KRAK!"
const WORD_SIZE := 0.5

var hero: CharacterBody3D
var at := Vector3.ZERO
var shells := []  # {foe, i, t, set, broken}
var chain := []  # foes in break order (shatter())
var on_set := Callable()  # (foe, i)
var on_link := Callable()  # (foe, k)
var set_n := 0  # (checks)
var broken := 0
var _t := 0.0
var _chain_t := -1.0


static func register() -> void:
	if not DESIGNED.extra_sheets.has("steam_shell"):
		DESIGNED.extra_sheets["steam_shell"] = {"tex": load("res://assets/vfx/designed/steam_shell.png"), "grid": Vector2(3, 2),
			"frames": 6, "kind": "sprite_depth", "anchor": Vector2(0.0, -0.41)}


static func prewarm(root: Node3D) -> void:
	if not DESIGNED.on():
		return
	register()
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	mi.material_override = DESIGNED.material("steam_shell")
	root.add_child(mi)
	mi.scale = Vector3.ONE * 20.0


static func start(by: CharacterBody3D, spot: Vector3, foes: Array) -> Node3D:
	var g: Node3D = SELF.new()
	g.hero = by
	g.at = Vector3(spot.x, 0.0, spot.z)
	var live: Array = foes.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.is_alive())
	live.sort_custom(func(a: Node3D, c: Node3D) -> bool:
		return _flat(a.global_position).distance_to(g.at) < _flat(c.global_position).distance_to(g.at))
	for i in live.size():
		g.shells.append({"foe": live[i], "i": i, "t": i * SET_STEP, "set": false, "broken": false})
	by.get_parent().add_child(g)
	return g


## Who has a shell on (set, alive, not broken yet).
func shelled() -> Array:
	var out: Array = []
	for s: Dictionary in shells:
		if s.set and not s.broken and _alive(s.foe):
			out.append(s.foe)
	return out


## The landing: every shell still to set sets now, and the break starts at `first` (null: the one nearest the landing),
## then runs on to the nearest unbroken shell each LINK s.
func shatter(first: Variant) -> void:
	for s: Dictionary in shells:
		if not s.set:
			_set_shell(s)
	var left: Array = shelled()
	if left.is_empty():
		queue_free()
		return
	var cur: Node3D = first if is_instance_valid(first) and left.has(first) else null
	if cur == null:
		left.sort_custom(func(a: Node3D, c: Node3D) -> bool:
			return _flat(a.global_position).distance_to(at) < _flat(c.global_position).distance_to(at))
		cur = left[0]
	chain = [cur]
	left.erase(cur)
	while not left.is_empty():  # (greedy: the nearest unbroken shell to the last one broken)
		var from := _flat(cur.global_position)
		left.sort_custom(func(a: Node3D, c: Node3D) -> bool:
			return _flat(a.global_position).distance_to(from) < _flat(c.global_position).distance_to(from))
		cur = left.pop_front()
		chain.append(cur)
	_chain_t = _t
	_link(0)


func _physics_process(delta: float) -> void:
	_t += delta
	for s: Dictionary in shells:
		if not s.set and _t >= float(s.t):
			_set_shell(s)
	if _chain_t >= 0.0:
		var k := broken
		while k < chain.size() and _t >= _chain_t + k * LINK:
			_link(k)
			k = broken
		if broken >= chain.size():
			queue_free()
	elif _t > 3.0:  # (no landing came: the shells just thaw on their own)
		queue_free()


func _set_shell(s: Dictionary) -> void:
	s.set = true
	if not _alive(s.foe):
		return
	set_n += 1
	var e: Node3D = s.foe
	if on_set.is_valid():
		on_set.call(e, int(s.i))
	if DESIGNED.on() and Game.comic_style and is_inside_tree():
		register()
		var foot := _flat(e.global_position)
		var fx: Node3D = DESIGNED.spawn(get_parent(), "steam_shell", foot, SHELL_SIZE * (0.9 + 0.2 * float(e.get("radius") if e.get("radius") != null else 0.5)),
			"water", SHELL_TIMES, Vector2(0.6, 1.0))
		fx.real_until = 1
		fx.set_spin(0.0, -1.0 if int(s.i) % 2 else 1.0)
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var away := foot - cam.global_position
			fx.global_position += Vector3(away.x, 0.0, away.z).normalized() * SHELL_BACK


func _link(k: int) -> void:
	broken = k + 1
	for s: Dictionary in shells:
		if s.foe == chain[k]:
			s.broken = true
	var e: Variant = chain[k]
	if not _alive(e):
		return
	var foe := e as Node3D
	if on_link.is_valid():
		on_link.call(foe, k)
	if not Game.comic_style or not is_inside_tree():
		return
	if k > 0:
		ComicFx.say(LINK_WORD, foe.global_position + Vector3.UP * 2.0, WORD_SIZE + 0.06 * k)
	if DESIGNED.on() and k + 1 < chain.size() and _alive(chain[k + 1]):  # the frost line racing on to the next shell
		var a := _flat(foe.global_position)
		var b := _flat((chain[k + 1] as Node3D).global_position)
		var run := b - a
		if run.length() > 1.0:
			DESIGNED_EL.fissure(get_parent(), a - run.normalized() * 0.6, run, run.length(), LINE_STEPS, "water", 0.8, LINK / LINE_STEPS)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _alive(e: Variant) -> bool:
	return is_instance_valid(e) and e.is_alive()
