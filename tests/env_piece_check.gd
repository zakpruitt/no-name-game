extends SceneTree
## The room's pieces as data (env_piece.gd, rooms.gd; docs/features/env-pieces.md), headless:
##   the plain room is today's arena (the same pillars with the same colliders, the torches, no other live piece);
##   the room with pieces (Game.room "pieces"): every counted piece placed, live and registered; a thrown foe breaks a
##   crate and a barrel (a splat at half the wall's), comes down on the spikes for x1.5; a breaker landing breaks a crate
##   and throws rubble chunks; a foe splatted through a banner tears it; used-up pieces rebuild after REBUILD_S;
##   usable() by element (the prince has no verb on a grate).
## Later items add their cases (Uproot's topple, the Powder Keg, the Frost Wall, the Live Floor).
## Prints [env_piece] PASS/FAIL.  Run: godot --headless --path . -s tests/env_piece_check.gd

var _fails: Array[String] = []
var main: Node
var hero: CharacterBody3D
var EP: GDScript
var THROWN: GDScript
var game: Node


func _initialize() -> void:
	await process_frame
	game = get_root().get_node("Game")
	game.save_hints = false
	EP = load("res://scripts/env_piece.gd")
	THROWN = load("res://scripts/thrown_foe.gd")
	await _room("plain")
	_plain()
	await _drop()
	await _room("pieces")
	_pieces()
	await _throws()
	await _landing()
	await _banner()
	await _rebuild()
	_usable()
	await _items()
	game.room = "plain"
	if _fails.is_empty():
		print("[env_piece] PASS")
	else:
		for f in _fails:
			print("[env_piece] FAIL: ", f)
		print("[env_piece] FAIL (%d)" % _fails.size())
	quit(0 if _fails.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


func _room(kind: String) -> void:
	game.room = kind
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.2).timeout
	hero = main.player
	hero.bot_enabled = true
	hero.bot_move = Vector3.ZERO


func _drop() -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Today's arena: four pillars in grab_anchors, each with its 0.75 m cylinder collider, at rooms.PILLARS; three torches;
## seven structures (three walls, four pillars); nothing else live, the clutter a look only.
func _plain() -> void:
	var rooms: GDScript = load("res://scripts/rooms.gd")
	_check(main.PILLARS == rooms.PILLARS, "main.PILLARS is rooms.PILLARS")
	var anchors: Array = get_nodes_in_group("grab_anchors")
	_check(anchors.size() == 4, "four pillars to swing on (%d)" % anchors.size())
	for p: Node3D in anchors:
		var body := p.get_node_or_null("EnvBody")
		var cyl: Variant = body.get_child(0).shape if body != null else null
		_check(cyl is CylinderShape3D and is_equal_approx(cyl.radius, main.PILLAR_R) and is_equal_approx(cyl.height, 4.0),
			"pillar at %s has its 0.75 x 4 m collider" % str(p.position))
		_check(main.PILLARS.has(p.position), "pillar at a PILLARS spot (%s)" % str(p.position))
	_check(main.env.structures.size() == 7, "seven structures (%d)" % main.env.structures.size())
	_check(main.env.torches.size() == 3, "three torches (%d)" % main.env.torches.size())
	var live: Array = get_nodes_in_group("env").map(func(n: Node) -> String: return EP.tag_of(n))
	_check(live.count("pillar") == 4 and live.count("torch") == 3 and live.size() == 7, "only the pillars and torches are live (%s)" % str(live))
	_check(EP.counted.is_empty(), "the plain room counts no pieces")
	_check(get_nodes_in_group("env_grate").is_empty(), "the plain room's random grates are floor, not pieces")


func _pieces() -> void:
	var rooms: GDScript = load("res://scripts/rooms.gd")
	_check(EP.counted.size() == rooms.ROOMS.training_pieces.size(), "every training piece counted (%d)" % EP.counted.size())
	for n: Node3D in EP.counted:
		var tag: String = EP.tag_of(n)
		_check(EP.live(n) and n.is_in_group("env_" + tag), "%s live, in env_%s" % [tag, tag])
		_check(n.get_meta(EP.STATE_META) == EP.PIECES[tag].states[0] if not EP.PIECES[tag].states.is_empty() else true, "%s starts %s" % [tag, n.get_meta(EP.STATE_META)])
	for tag: String in ["barrel", "crate", "grate"]:
		var on: Array = main.env.structures.filter(func(s: Dictionary) -> bool: return s.kind == tag)
		_check(on.size() == 1, "env_target knows the %s (%d)" % [tag, on.size()])
	var b: Node3D = get_nodes_in_group("env_barrel")[0]
	var mid: Dictionary = load("res://scripts/env_target.gd").nearest(main.env.structures, b.global_position + Vector3(1.5, 0, 0), 10.0)
	_check(mid.s.kind in ["wall", "pillar"], "a barrel is not a wall or pillar to the old picks (%s)" % str(mid.s.kind))
	_check(get_nodes_in_group("env_banner").size() == 3, "the banners are live with pieces")
	_check(EP.under(self, "spikes", Vector3(-10, 0, -2)) != null and EP.under(self, "spikes", Vector3(-7.9, 0, -2)) == null, "spikes cover their tile")


func _dummy(i: int, at: Vector3) -> Node3D:
	var d: Node3D = main._dummies[i]
	d.home = at
	d.global_position = at
	d.velocity = Vector3.ZERO
	return d


## Thrown along -x into the barrel (over the spikes) and into the crate.
func _throws() -> void:
	hero.global_position = Vector3(-3, 0, 5)
	var barrel: Node3D = get_nodes_in_group("env_barrel")[0]
	var crate: Node3D = get_nodes_in_group("env_crate")[0]
	await _frames(2)
	var got := {}
	for i in 2:
		var d: Node3D = _dummy(i, Vector3(-6.0, 0, -2.0) if i == 0 else Vector3(-6.0, 0, 1.0))
		got[d] = 0.0
		d.hit_taken.connect(func(dmg: float) -> void: got[d] += dmg)
	await _frames(2)
	var a: Node3D = main._dummies[0]
	var c: Node3D = main._dummies[1]
	got[a] = 0.0
	got[c] = 0.0
	THROWN.launch(hero, a, a.global_position + Vector3(-10, 0, 0), 10.0, {"el": "void", "wall_mult": 2.0, "solid": false, "quiet": true, "splash": false})
	THROWN.launch(hero, c, c.global_position + Vector3(-10, 0, 0), 10.0, {"el": "void", "wall_mult": 2.0, "solid": false, "quiet": true, "splash": false})
	await _frames(40)
	_check(EP.state(barrel) == "gone" and not barrel.visible, "a thrown foe breaks the barrel (%s)" % EP.state(barrel))
	_check(EP.state(crate) == "gone", "a thrown foe breaks the crate (%s)" % EP.state(crate))
	_check(main.env.structures.filter(func(s: Dictionary) -> bool: return s.kind == "barrel").is_empty(), "the broken barrel leaves env_target")
	var body: Node = barrel.get_node("EnvBody")
	_check(body.process_mode == Node.PROCESS_MODE_DISABLED, "its collider is off")
	# 10 x (half of x2 = x1) x 1.5 on the spikes; the crate's (off the spikes) 10 x 1
	print("  barrel splat on the spikes %.1f, crate splat %.1f" % [got[a], got[c]])
	_check(is_equal_approx(got[a], 15.0), "the barrel splat pays half the wall's, x1.5 on the spikes (%.1f, want 15)" % got[a])
	_check(is_equal_approx(got[c], 10.0), "the crate splat pays half the wall's (%.1f, want 10)" % got[c])


func _landing() -> void:
	var crate: Node3D = get_nodes_in_group("env_crate")[0]
	EP.rebuild(crate)
	_check(EP.state(crate) == "whole" and crate.visible, "rebuild() puts the crate back")
	var chunks: int = main.env.chunks_shed
	EP.landing(hero, crate.global_position + Vector3(1.2, 0, 0))
	_check(EP.state(crate) == "gone", "a breaker landing 1.2 m off breaks the crate")
	EP.landing(hero, Vector3(-2, 0, -6))
	_check(main.env.chunks_shed >= chunks + 3, "a breaker landing on the rubble throws chunks (%d)" % (main.env.chunks_shed - chunks))
	await _frames(2)


func _banner() -> void:
	var b: Node3D = get_nodes_in_group("env_banner")[0]
	EP.wall_splat(self, Vector3(b.global_position.x + 0.5, 0, -15.2), hero)
	_check(EP.state(b) == "torn", "a splat by a banner tears it (%s)" % EP.state(b))
	await _frames(2)


## Everything used up comes back REBUILD_S later in training.
func _rebuild() -> void:
	var barrel: Node3D = get_nodes_in_group("env_barrel")[0]
	var b: Node3D = get_nodes_in_group("env_banner")[0]
	_check(EP.state(barrel) == "gone", "(the barrel is still gone)")
	await create_timer(EP.REBUILD_S + 0.5, true, true).timeout
	_check(EP.state(barrel) == "whole" and barrel.visible and barrel.get_node("EnvBody").process_mode == Node.PROCESS_MODE_INHERIT,
		"the barrel rebuilds after REBUILD_S (%s)" % EP.state(barrel))
	_check(main.env.structures.filter(func(s: Dictionary) -> bool: return s.kind == "barrel").size() == 1, "and env_target knows it again")
	_check(EP.state(b) == "hanging" and b.visible, "the banner rebuilds (%s)" % EP.state(b))


func _usable() -> void:
	_check(EP.usable("pillar", "uproot") and EP.usable("barrel", "keg") and EP.usable("grate", "frost_wall") and EP.usable("grate", "live_floor"),
		"the heretic has every built verb")
	game.hero = "prince"
	_check(not EP.usable("grate", "live_floor") and not EP.usable("barrel", "keg"), "the prince has no storm or magma verb: a grate is floor to him")
	game.hero = "heretic"


## Each build-order item's own cases (the lanes add theirs here).
func _items() -> void:
	pass
