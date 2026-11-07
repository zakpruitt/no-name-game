extends SceneTree
## Environmental targeting (env_target.gd, docs/features/environment.md), headless, in the training room: the room's
## structures as main.gd builds them (three walls, four pillars, the torches); the structure each environmental move
## picks from several spots (Pinwheel, Collapse, Ricochet near; Molten Palm and Slapshot along the aim; the pillar slam
## pillars only); the too-far case; the cursor's and the right stick's override and the ending using it
## (pinwheel_target, ricochet_target, Slapshot's aim, Meteor Fall's pile); the live indicator through a window (shown,
## switched by the cursor, locked by the press); Impale's window (round 50: Pinwheel off Dash H H after a pause); the
## beats (a pillar sheds chunks and cracks, a wall keeps a mark per element, capped, a torch swings); the pillar slam.
## Prints [env] PASS/FAIL.
## Run: godot --headless --path . -s tests/env_target_check.gd

var _fails: Array[String] = []
var main: Node
var hero: CharacterBody3D
var env: Node
var ENV: GDScript
var VE: GDScript


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.2).timeout
	hero = main.player
	env = main.env
	ENV = load("res://scripts/env_target.gd")
	VE = load("res://scripts/void_element.gd")
	hero.bot_enabled = true
	hero.bot_move = Vector3.ZERO
	_room()
	_picks()
	_cursor()
	await _live_window()
	_impale_window()
	_beats()
	await _pillar_slam()
	if _fails.is_empty():
		print("[env] PASS")
	else:
		for f in _fails:
			print("[env] FAIL: ", f)
		print("[env] FAIL (%d)" % _fails.size())
	quit(0 if _fails.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


func _kind(r: Dictionary) -> String:
	return str(r.s.kind) + ":" + str(r.s.id) if r.get("found", false) and r.has("s") else "none"


## main.gd registers what it builds: the back and side walls (not the open near side), the four pillars, the torches.
func _room() -> void:
	var walls: Array = env.structures.filter(func(s: Dictionary) -> bool: return s.kind == "wall")
	var pillars: Array = env.structures.filter(func(s: Dictionary) -> bool: return s.kind == "pillar")
	_check(walls.size() == 3, "three walls registered (%d)" % walls.size())
	_check(pillars.size() == main.PILLARS.size(), "every pillar registered (%d)" % pillars.size())
	for p: Dictionary in pillars:
		_check(main.PILLARS.has(Vector3(p.at.x, 0.0, p.at.z)), "pillar %s at a main.PILLARS spot (%s)" % [p.id, str(p.at)])
	_check(env.torches.size() == 3, "the back wall's torches registered (%d)" % env.torches.size())
	for w: Dictionary in walls:
		var mid: Vector3 = (w.a + w.b) * 0.5
		_check(Vector3(-mid).normalized().dot(w.n) > 0.9, "%s's normal faces into the room" % w.id)


func _picks() -> void:
	var S: Array = env.structures
	var reach: float = VE.PINWHEEL_REACH
	# Pinwheel from the room's middle: nothing in reach (the pillars stand ~10.6 m off): too far, on a pillar
	var mid: Dictionary = ENV.nearest(S, Vector3(0, 0, -0.5), reach)
	_check(mid.found and not mid.in_reach and mid.s.kind == "pillar", "middle of the room: too far, the nearest a pillar (%s %.1f m)" % [_kind(mid), mid.dist])
	# next to the back-left pillar: that pillar
	var by_pillar: Dictionary = ENV.nearest(S, Vector3(-5, 0, -7), reach)
	_check(by_pillar.in_reach and by_pillar.s.kind == "pillar" and by_pillar.s.at.distance_to(Vector3(-8, 0, -8)) < 0.1,
		"by the back-left pillar: it (%s %.1f m)" % [_kind(by_pillar), by_pillar.dist])
	# up by the back wall between the pillars: the wall
	var by_wall: Dictionary = ENV.nearest(S, Vector3(0, 0, -12), reach)
	_check(by_wall.in_reach and by_wall.s.kind == "wall" and absf(by_wall.at.z + main.ARENA_HALF) < 0.1, "by the back wall: it (%s)" % _kind(by_wall))
	# by the right wall, low down the room: the right wall
	var right: Dictionary = ENV.nearest(S, Vector3(12, 0, 2), reach)
	_check(right.in_reach and right.s.kind == "wall" and absf(right.at.x - main.ARENA_HALF) < 0.1, "by the right wall: it (%s)" % _kind(right))
	# the pillar slam takes pillars only
	var slam: Dictionary = ENV.nearest(S, Vector3(0, 0, -14), ENV.PILLAR_SLAM_REACH, ["pillar"])
	_check(slam.found and slam.s.kind == "pillar" and not slam.in_reach, "pillar slam ignores the wall beside him (%s)" % _kind(slam))
	# Molten Palm along his aim: up the room from the middle the back wall is past its reach, 4 m up it is in reach;
	# aimed at a pillar, the pillar
	var palm_reach: float = VE.PALM_LENGTH * 0.6 + VE.PALM_WALL_REACH
	var far: Dictionary = ENV.along(S, Vector3.ZERO, Vector3.FORWARD, palm_reach)
	_check(far.found and not far.in_reach and far.s.kind == "wall", "palm up the room from the middle: the back wall, too far (%.1f m)" % far.dist)
	var near: Dictionary = ENV.along(S, Vector3(0, 0, -4), Vector3.FORWARD, palm_reach)
	_check(near.in_reach and near.s.kind == "wall", "palm from 4 m up: the back wall in reach (%.1f m)" % near.dist)
	var at_pillar: Dictionary = ENV.along(S, Vector3.ZERO, Vector3(-8, 0, -8).normalized(), palm_reach)
	_check(at_pillar.in_reach and at_pillar.s.kind == "pillar", "palm aimed at a pillar: it (%s)" % _kind(at_pillar))
	print("  picks: middle %s %.1f m (far), by pillar %.1f m, by back wall %.1f m, palm far %.1f / near %.1f m" % [
		_kind(mid), mid.dist, by_pillar.dist, by_wall.dist, far.dist, near.dist])


## The cursor / stick override, and the ending using it.
func _cursor() -> void:
	var from := Vector3(-5, 0, -7)
	var c := {"ctx": "pinwheel", "from": from, "reach": VE.PINWHEEL_REACH, "mode": "near", "key": "test"}
	var auto: Dictionary = env.resolve(hero, c)
	_check(auto.s.kind == "pillar" and not auto.chosen, "no cursor: the auto pick (the pillar)")
	env.test_cursor = Vector3(-5, 0, -15.5)  # (on the back wall's face)
	var on_wall: Dictionary = env.resolve(hero, c)
	_check(on_wall.s.kind == "wall" and on_wall.chosen, "cursor on the back wall: the wall (%s)" % _kind(on_wall))
	env.test_cursor = Vector3(8, 0, -8)  # (a pillar out of Pinwheel's reach from here)
	var out_of_reach: Dictionary = env.resolve(hero, c)
	_check(out_of_reach.s.kind == "pillar" and not out_of_reach.chosen, "cursor on a pillar out of reach: back to the auto pick")
	env.test_cursor = Vector3(0, 0, 3)  # (open floor)
	_check(not env.resolve(hero, c).chosen, "cursor on open floor: the auto pick")
	env.test_cursor = Vector3.INF
	env.test_stick = Vector3(0, 0, -1)  # (right stick up the room)
	var stick: Dictionary = env.resolve(hero, c)
	_check(stick.s.kind == "wall" and stick.chosen, "right stick up the room: the back wall (%s)" % _kind(stick))
	env.test_stick = Vector3.ZERO
	# the ending reads the pick written on the hero: Pinwheel's throw and Ricochet's go to the chosen wall
	var wall_id: String = on_wall.s.id
	hero.set_meta(ENV.PICK_META, {"ctx": "pinwheel", "id": wall_id, "chosen": true, "ms": Time.get_ticks_msec()})
	var t: Dictionary = VE.pinwheel_target(hero, from)
	_check(t.found and t.s.id == wall_id and absf(t.at.z + main.ARENA_HALF) < 0.1, "Pinwheel throws at the chosen wall (%s)" % str(t.get("at")))
	hero.remove_meta(ENV.PICK_META)
	var t2: Dictionary = VE.pinwheel_target(hero, from)
	_check(t2.found and t2.s.kind == "pillar", "with no pick, Pinwheel's nearest (the pillar)")
	# Ricochet: a foe nearer than the wall wins, unless the cursor chose the wall
	var counter: GDScript = load("res://scripts/counter.gd")
	var held: Node3D = main._dummies[0]
	var other: Node3D = main._dummies[1]
	held.global_position = Vector3(0, 0, -11)
	other.global_position = Vector3(2.5, 0, -11)
	_check(counter.ricochet_target(hero, held).kind == "foe", "Ricochet: the nearer foe (2.5 m vs the wall's 5 m)")
	hero.set_meta(ENV.PICK_META, {"ctx": "ricochet", "id": wall_id, "chosen": true, "ms": Time.get_ticks_msec()})
	var r: Dictionary = counter.ricochet_target(hero, held)
	_check(r.kind == "wall" and absf(r.to.z + main.ARENA_HALF) < 2.0, "Ricochet with the wall chosen: the wall (%s)" % str(r))
	hero.remove_meta(ENV.PICK_META)
	# Collapse: the structure nearest the hole within COLLAPSE_REACH; none in the middle of the room
	var col: Dictionary = ENV.pick(hero, "collapse", Vector3(0, 0, -9), ENV.COLLAPSE_REACH)
	_check(col.found and col.s.kind == "wall", "Collapse by the back wall: it (%s)" % _kind(col))
	_check(not ENV.pick(hero, "collapse", Vector3(0, 0, -0.5), ENV.COLLAPSE_REACH).found, "Collapse in the open: no structure (the throw clear)")
	# Meteor Fall: the cursor on a structure with palm foes by it pulls the dive to them
	for d: Node3D in main._dummies:
		d.set_meta(VE.PALM_META, Time.get_ticks_msec())
	held.global_position = Vector3(-7, 0, -6.8)  # (by the back-left pillar)
	other.global_position = Vector3(1, 0, -14.8)  # (on the back wall)
	main._dummies[2].global_position = Vector3(2, 0, -14.6)
	main._dummies[3].global_position = Vector3(3, 0, -14.8)
	hero.global_position = Vector3(0, 0, -4)
	var auto_spot: Dictionary = VE.meteor_spot(hero)
	_check(auto_spot.found and auto_spot.at.z < -13.0, "Meteor Fall: the biggest group (three on the wall) (%s)" % str(auto_spot.get("at")))
	var pillar_id := ""
	for s: Dictionary in env.structures:
		if s.kind == "pillar" and s.at.distance_to(Vector3(-8, 0, -8)) < 0.1:
			pillar_id = s.id
	hero.set_meta(ENV.PICK_META, {"ctx": "meteor", "id": pillar_id, "chosen": true, "ms": Time.get_ticks_msec()})
	var picked_spot: Dictionary = VE.meteor_spot(hero)
	_check(picked_spot.found and picked_spot.at.distance_to(Vector3(-7, 0, -6.8)) < 1.0, "Meteor Fall with the pillar chosen: the one by it (%s)" % str(picked_spot.get("at")))
	hero.remove_meta(ENV.PICK_META)
	for d: Node3D in main._dummies:
		d.remove_meta(VE.PALM_META)
		d.global_position = d.home


## A window drives the indicator: Pinwheel's (Backdraft's LMB) shows on the auto pick, the cursor switches it, the press
## (the dive) locks it, then it clears.
func _live_window() -> void:
	hero.set_physics_process(false)
	hero.global_position = Vector3(-5, 0, -7)
	hero.state = hero.State.LEAP
	hero._brk_id = "XW"
	hero._brk = VE.entry("XW")
	hero._brk_phase = 0
	hero._brk_locked = false
	var shown0: int = env.shown
	await physics_frame
	await physics_frame
	_check(env.current.get("ctx", "") == "pinwheel" and env.current.s.kind == "pillar" and env.current.state == "target",
		"Pinwheel's window: the indicator on the pillar (%s)" % str(env.current.get("ctx")))
	_check(env.shown == shown0 + 1, "one indicator for the window")
	await process_frame
	_check(env._bracket.visible and env._ring.visible, "the bracket and the pillar's floor ring are drawn")
	var chev: int = env._chevs.filter(func(m: MeshInstance3D) -> bool: return m.visible).size()
	_check(chev >= 1, "the aim line's chevrons are drawn (%d)" % chev)
	env.test_cursor = Vector3(-5, 0, -15.5)
	await physics_frame
	await physics_frame
	_check(env.current.s.kind == "wall" and env.current.chosen and env.switches >= 1, "the cursor on the wall switches the indicator to it")
	var lock: Dictionary = hero.get_meta(ENV.PICK_META)
	_check(lock.chosen and lock.id == env.current.s.id, "the pick is written on the hero for the ending")
	var locks0: int = env.locks
	hero._brk_phase = 1  # (the press: the dive)
	await physics_frame
	await physics_frame
	_check(env.locks == locks0 + 1, "the press locks the bracket")
	await create_timer(0.4).timeout
	_check(env.current.is_empty() and not env._bracket.visible, "then it clears")
	env.test_cursor = Vector3.INF
	# the middle of the room: the too-far bracket on the nearest pillar
	hero.global_position = Vector3(0, 0, -0.5)
	hero._brk_phase = 0
	await physics_frame
	await physics_frame
	_check(env.current.get("state", "") == "far" and env.current.s.kind == "pillar", "nothing in reach: the dim too-far bracket on the nearest pillar (%s)" % str(env.current.get("state")))
	hero.state = hero.State.MOVE
	hero._brk = {}
	await physics_frame
	await physics_frame
	_check(env.current.is_empty(), "out of the window: no indicator")
	hero.set_physics_process(true)


## Round 50: Impale (Dash H H) has its own window after a pause: Anvil (RMB) / Pinwheel (LMB).
func _impale_window() -> void:
	var b: Dictionary = VE.BREAKERS.get("XK", {})
	_check(not b.is_empty() and b.alt.names.spirit == "Pinwheel" and b.names.spirit == "Anvil", "Impale's window offers Anvil / Pinwheel")
	var mv: Dictionary = hero.MOVES.XK
	_check(float(b.leap) > float(mv.cancel) and float(b.leap) < float(mv.end), "its leap waits past Impale's cancel (a press there is still Backdraft) and before its end (%.2f in %.2f..%.2f)" % [b.leap, mv.cancel, mv.end])
	_check(hero.HERO_MOVES.pause_ending("XK", "light") == "Pinwheel", "the guide's pause row on Impale: L is Pinwheel")
	_check(hero.HERO_MOVES.void_route("light", "XK", true, 2, false) == "XW", "L before the leap is still Backdraft")


## The beats: a pillar hit sheds chunks and keeps a crack, a wall hit keeps a mark per element and knocks a torch near it.
func _beats() -> void:
	var hits0: int = env.pillar_hits
	var chunks0: int = env.chunks_shed
	var marks0: int = env.marks.size()
	var kind: String = env.hit_at(Vector3(-6.9, 0, -6.9), Vector3(-1, 0, -1).normalized(), "void")
	_check(kind == "pillar" and env.pillar_hits == hits0 + 1, "a foe thrown into a pillar: the pillar's beat (%s)" % kind)
	_check(env.chunks_shed == chunks0 + ENV.CHUNKS, "it sheds %d chunks (%d)" % [ENV.CHUNKS, env.chunks_shed - chunks0])
	_check(env.marks.size() == marks0 + 1, "and keeps a crack")
	var swings0: int = env.torch_swings
	kind = env.hit_at(Vector3(-2.3, 0, -15.0), Vector3.FORWARD, "earth")
	_check(kind == "wall" and env.torch_swings == swings0 + 1, "into the back wall by a torch: the torch swings (%s, %d)" % [kind, env.torch_swings - swings0])
	_check(env.marks.size() == marks0 + 2, "and the wall keeps a mark")
	var last: MeshInstance3D = env.marks[-1]
	_check(is_equal_approx(float(last.get_instance_shader_parameter("frame")), float(ENV.MARK_FRAME.earth)), "magma leaves its scorch")
	env.hit_at(Vector3(15.0, 0, 0), Vector3.RIGHT, "water")
	_check(is_equal_approx(float(env.marks[-1].get_instance_shader_parameter("frame")), float(ENV.MARK_FRAME.water)), "ice leaves its frost")
	_check(env.hit_at(Vector3(0, 0, 2), Vector3.FORWARD, "earth") == "", "a stop in the open: no beat")
	for i in ENV.MARK_CAP + 6:
		env.hit_at(Vector3(-12.0 + i * 0.5, 0, -15.2), Vector3.FORWARD, "void")
	_check(env.marks.size() == ENV.MARK_CAP, "marks are capped at %d (%d)" % [ENV.MARK_CAP, env.marks.size()])
	print("  beats: pillar hits %d, chunks %d, torch swings %d, marks %d" % [env.pillar_hits, env.chunks_shed, env.torch_swings, env.marks.size()])


## H, then H held by a pillar: the slam goes into the pillar (the pillar's beat, a wall splat), and Singularity's hole
## opens at its foot. Without H held: the floor ahead, as before.
func _pillar_slam() -> void:
	var grab: Node = hero._void
	var foe: Node3D = main._dummies[0]
	for held in [true, false]:
		hero.set_physics_process(false)
		hero.global_position = Vector3(-8, 0, -4.4)
		hero._face(Vector3(0, 0, -1))
		foe.global_position = Vector3(-8, 0, -6.1)
		if foe.has_meta("last_wall_ms"):
			foe.remove_meta("last_wall_ms")
		hero.state = hero.State.ATTACK
		hero._move_id = "GR"
		hero._hits_done = 1
		grab.on_move("GR", "")
		grab._target = foe
		grab._target_heavy = false
		await physics_frame
		_check(env.current.get("ctx", "") == "pillar_slam" and env.current.s.kind == "pillar", "grab held by a pillar: the indicator on it (%s)" % str(env.current.get("ctx")))
		hero._move_id = "VS"
		hero._move = hero.MOVES.VS.duplicate()
		hero._hits_done = 0
		grab.on_move("VS", "GR")
		grab._target = foe
		if held:
			Input.action_press("attack_heavy")
		var slams0: int = grab.pillar_slams
		var hits0: int = env.pillar_hits
		grab._tick_slam(0.2)
		Input.action_release("attack_heavy")
		_check(grab.pillar_slam_on() == held, "H %s through the haul: %s" % ["held" if held else "let go", "into the pillar" if held else "the floor"])
		grab.slam_lands()
		if held:
			_check(grab.pillar_slams == slams0 + 1 and env.pillar_hits == hits0 + 1, "the slam smashes it into the pillar (the pillar's beat)")
			_check(foe.has_meta("last_wall_ms"), "a wall splat (Meteor Fall and the camera read it)")
			_check(grab._aim_at.distance_to(Vector3(-8, 0, -8)) < 2.0, "the hole opens at the pillar's foot (%s)" % str(grab._aim_at))
		else:
			_check(grab.pillar_slams == slams0, "no pillar without H held")
		hero.state = hero.State.MOVE
		hero._move_id = ""
		grab._target = null
		hero.set_physics_process(true)
		await physics_frame
