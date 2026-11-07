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
	_check(EP.counted.size() == rooms.ROOMS.training_pieces.filter(func(e: Dictionary) -> bool: return e.get("count", false)).size() + 1,
		"every counted training piece and the middle torch counted (%d)" % EP.counted.size())
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
	await _keg()
	await _frost_wall()
	await _frost_shatter()
	await _live_floor()
	await _conduct()
	_room_rules()


## Frost Wall: a Frost Spear planted by the grate raises the ice wall on its far edge, on the walls' layer and known to
## env_target as a wall; it melts LIFE later and the grate is cold again.
func _frost_wall() -> void:
	var FS: GDScript = load("res://scripts/frost_spear.gd")
	var FW: GDScript = load("res://scripts/frost_wall.gd")
	var g: Node3D = get_nodes_in_group("env_grate")[0]
	hero.global_position = g.global_position + Vector3(-4.0, 0, 0)
	await _frames(2)
	var w: Node3D = FS.frost_wall(main, g.global_position + Vector3(-0.5, 0, 0))
	_check(w != null and FW.current(self) == w, "a spear by the grate raises the Frost Wall")
	if w == null:
		return
	await _frames(2)
	_check(w.global_position.x > g.global_position.x + 1.0, "on the grate's far edge from him (%s)" % str(w.global_position))
	_check(EP.state(g) == "frosted", "the grate is frosted (%s)" % EP.state(g))
	var walls: Array = main.env.structures.filter(func(s: Dictionary) -> bool: return s.get("id", "") == FW.ID)
	_check(walls.size() == 1 and walls[0].kind == "wall", "env_target knows it as a wall (%d)" % walls.size())
	var ray := PhysicsRayQueryParameters3D.create(hero.global_position + Vector3.UP, w.global_position + Vector3(2, 1, 0), hero.collision_mask)
	var hit: Dictionary = hero.get_world_3d().direct_space_state.intersect_ray(ray)
	_check(not hit.is_empty() and hit.collider.get_parent() == w, "it is on the walls' layer (a throw stops on it)")
	_check(FS.frost_wall(main, Vector3(-10, 0, 10)) == null, "no grate near, no wall")
	_check(int(EP.verbs.get("frost_wall", 0)) >= 1, "the Frost Wall is counted")
	await create_timer(FW.LIFE + 0.6, true, false, true).timeout
	_check(FW.current(self) == null and EP.state(g) == "cold", "it melts after LIFE, the grate cold again (%s)" % EP.state(g))
	_check(main.env.structures.filter(func(s: Dictionary) -> bool: return s.get("id", "") == FW.ID).is_empty(), "and leaves env_target")


## Round 52: an ice cube splatting on the Frost Wall pays x SHATTER_MULT on the wall's mult (the proposal's Shatter);
## a foe thrown into it out of a cube pays the wall's mult alone. It faces him square to his line (a diagonal here).
func _frost_shatter() -> void:
	var FS: GDScript = load("res://scripts/frost_spear.gd")
	var FW: GDScript = load("res://scripts/frost_wall.gd")
	var g: Node3D = get_nodes_in_group("env_grate")[0]
	var got := {}
	for el: String in ["void", "water"]:
		hero.global_position = g.global_position + Vector3(-4.0, 0, 0)
		await _frames(2)
		var w: Node3D = FS.frost_wall(main, g.global_position + Vector3(-0.5, 0, 0))
		await _frames(2)
		var d: Node3D = _dummy(0, g.global_position + Vector3(-1.5, 0, 0))
		var raised := w != null
		await _frames(2)
		var dealt := [0.0]
		var on_hit := func(dmg: float) -> void: dealt[0] += dmg
		d.hit_taken.connect(on_hit)
		THROWN.launch(hero, d, d.global_position + Vector3(10, 0, 0), 10.0, {"el": el, "wall_mult": 2.0, "solid": false, "quiet": true, "splash": false})
		await _frames(40)
		d.hit_taken.disconnect(on_hit)
		got[el] = dealt[0]
		_check(raised and (not is_instance_valid(w) or w.get("_gone") or w.get("_shattering")), "the %s splat shatters the Frost Wall" % el)
		await create_timer(0.5, true, false, true).timeout
	print("  frost wall splat: a foe %.1f, an ice cube %.1f (x%.1f)" % [got.void, got.water, FW.SHATTER_MULT])
	_check(is_equal_approx(got.void, 20.0), "a foe into the Frost Wall pays the wall's mult (%.1f, want 20)" % got.void)
	_check(is_equal_approx(got.water, 20.0 * FW.SHATTER_MULT), "an ice cube into it pays x%.1f more (%.1f, want %.1f)" % [FW.SHATTER_MULT, got.water, 20.0 * FW.SHATTER_MULT])
	# a diagonal: from the grate's south-west, the wall stands square to his line, 6 m wide
	hero.global_position = g.global_position + Vector3(-3.0, 0, 3.0)
	await _frames(2)
	var w2: Node3D = FS.frost_wall(main, g.global_position + Vector3(-0.4, 0, 0.4))
	await _frames(2)
	if w2 != null:
		var n: Vector3 = w2.normal
		_check(n.dot(Vector3(-1, 0, 1).normalized()) > 0.95, "it faces him on the diagonal (normal %s)" % str(n))
		_check(is_equal_approx(FW.WIDTH, 6.0), "6 m wide (%.1f)" % FW.WIDTH)
		w2.melt()
	else:
		_check(false, "a diagonal spear raises it too")
	await create_timer(0.6, true, false, true).timeout


## Round 52, torches conduct: storm on a foe within CONDUCT_REACH of the back wall's middle torch makes it conduct;
## the current runs along the wall to the torch 8 m on and zaps the foe under it (CONDUCT_DAMAGE, charged), who no
## tentacle or arc reached; the torches are conducting for Short Circuit, lit again after CONDUCT_S. With the torches
## out, nothing relays; storm far from any torch, nothing; the prince has no storm.
func _conduct() -> void:
	var VE: GDScript = load("res://scripts/void_element.gd")
	var torches: Array = get_nodes_in_group("env_torch")
	_check(torches.size() == 3, "three torches (%d)" % torches.size())
	var mid: Node3D = null
	for t: Node3D in torches:
		if is_equal_approx(t.global_position.x, -2.0):
			mid = t
	if mid == null:
		_check(false, "the middle torch at x -2")
		return
	hero.global_position = Vector3(-2, 0, -2)
	var a: Node3D = _dummy(0, Vector3(-2.0, 0, -12.6))
	var far: Node3D = _dummy(1, Vector3(6.0, 0, -12.6))
	_dummy(2, Vector3(0, 0, 4))
	_dummy(3, Vector3(3, 0, 6))
	await _frames(3)
	var got := [0.0]
	var on_hit := func(dmg: float) -> void: got[0] += dmg
	far.hit_taken.connect(on_hit)
	var mult: float = float(hero.get("_dmg_mult")) if hero.get("_dmg_mult") != null else 1.0
	var plays: int = int(EP.verbs.get("conduct", 0))
	VE.unmark(far, "charged")
	VE.mark(a, "charged")
	_check(EP.state(mid) == "conducting", "storm on a foe under the torch makes it conduct (%s)" % EP.state(mid))
	_check(EP.torch_chain(mid).size() == 3, "the current runs along the wall through all three torches (%d)" % EP.torch_chain(mid).size())
	print("  torches conduct: the foe 8 m along the wall took %.1f (want %.1f)" % [got[0], EP.CONDUCT_DAMAGE * mult])
	_check(is_equal_approx(got[0], EP.CONDUCT_DAMAGE * mult), "the foe under the far torch takes the relay (%.1f)" % got[0])
	_check(VE.marked(far, "charged"), "and is charged")
	_check(EP.conducting_torches(self).size() == 3, "every torch in the chain conducts (Short Circuit's sources)")
	_check(int(EP.verbs.get("conduct", 0)) == plays + 1, "conduct is counted once")
	got[0] = 0.0
	VE.mark(a, "charged")  # (inside CONDUCT_CD: no second relay yet)
	_check(got[0] == 0.0, "one relay per torch per CONDUCT_CD (%.1f)" % got[0])
	await create_timer(EP.CONDUCT_S + 0.6, true, false, true).timeout
	_check(EP.state(mid) == "lit", "lit again after CONDUCT_S (%s)" % EP.state(mid))
	got[0] = 0.0
	var b: Node3D = main._dummies[2]
	VE.mark(b, "charged")  # (8 m off the wall: no torch near)
	_check(got[0] == 0.0 and EP.state(mid) == "lit", "storm far from any torch relays nothing")
	for t: Node3D in torches:
		t.set_meta(EP.STATE_META, "out")
	VE.mark(a, "charged")
	_check(got[0] == 0.0 and EP.conducting_torches(self).is_empty(), "an out torch doesn't conduct (%.1f)" % got[0])
	for t: Node3D in torches:
		t.set_meta(EP.STATE_META, "lit")
	game.hero = "prince"
	_check(not EP.usable("torch", "conduct"), "the prince has no storm: a torch is light to him")
	game.hero = "heretic"
	far.hit_taken.disconnect(on_hit)


## Round 52: the rooms' rules (rooms.gd ROOM_RULES): both training rooms rebuild, a real room keeps pieces gone.
func _room_rules() -> void:
	var rooms: GDScript = load("res://scripts/rooms.gd")
	_check(rooms.rebuild("plain") and rooms.rebuild("pieces"), "both training rooms rebuild")
	_check(not rooms.rebuild("hall"), "a real room keeps used-up pieces gone")
	_check(main.get_meta(EP.REBUILD_META, false) == true, "main passes the room's rule to EnvPiece.begin")


## Live Floor: storm on a foe standing on the grate makes it live; another foe on it is charged by the grate; Short
## Circuit's sources include them; it goes cold LIVE_S later.
func _live_floor() -> void:
	var VE: GDScript = load("res://scripts/void_element.gd")
	var g: Node3D = get_nodes_in_group("env_grate")[0]
	var at := g.global_position
	hero.global_position = at + Vector3(-6.0, 0, 4.0)
	var a: Node3D = _dummy(0, at + Vector3(-0.6, 0, 0))
	var c: Node3D = _dummy(1, at + Vector3(0.9, 0, 0.8))
	await _frames(3)
	_check(a in EP.on_tile(g) and c in EP.on_tile(g), "both stand on the grate (%d on it)" % EP.on_tile(g).size())
	VE.mark(a, "charged")
	_check(EP.state(g) == "live", "storm on a foe on the grate makes it live (%s)" % EP.state(g))
	await create_timer(0.2, true, false, true).timeout
	_check(VE.marked(c, "charged"), "the live grate charges the other foe on it")
	_check(EP.live_grates(self).size() == 1, "it is a live grate for Short Circuit")
	_check(int(EP.verbs.get("live_floor", 0)) >= 1, "the Live Floor is counted")
	await create_timer(EP.LIVE_S + 0.8, true, false, true).timeout
	_check(EP.state(g) == "cold", "cold again after LIVE_S (%s)" % EP.state(g))


## Powder Keg: magma on a foe by the barrel sets it burning; KEG_FUSE later it bursts, KEG_DAMAGE to everyone in KEG_R
## (the near foe and one 2.5 m off), they are left molten, and the barrel is used up.
func _keg() -> void:
	var VE: GDScript = load("res://scripts/void_element.gd")
	var barrel: Node3D = get_nodes_in_group("env_barrel")[0]
	var at := barrel.global_position
	hero.global_position = Vector3(at.x + 6.0, 0, at.z + 5.0)
	var got := {}
	for i in 2:
		var d: Node3D = _dummy(i, Vector3(at.x + (1.0 if i == 0 else 2.5), 0, at.z))
		got[d] = 0.0
		d.hit_taken.connect(func(dmg: float) -> void: got[d] += dmg)
	await _frames(3)
	var a: Node3D = main._dummies[0]
	var c: Node3D = main._dummies[1]
	VE.mark(a, "molten")
	_check(EP.state(barrel) == "burning", "magma on a foe by the barrel sets it burning (%s)" % EP.state(barrel))
	_check(got[a] == 0.0 and got[c] == 0.0, "nothing bursts during the fuse")
	await create_timer(EP.KEG_FUSE + 0.3, true, false, true).timeout
	var mult: float = float(hero.get("_dmg_mult")) if hero.get("_dmg_mult") != null else 1.0
	print("  keg: near %.1f, 2.5 m off %.1f (want %.1f)" % [got[a], got[c], EP.KEG_DAMAGE * mult])
	_check(is_equal_approx(got[a], EP.KEG_DAMAGE * mult) and is_equal_approx(got[c], EP.KEG_DAMAGE * mult),
		"the keg's burst hits everyone in its radius (%.1f, %.1f)" % [got[a], got[c]])
	_check(VE.marked(c, "molten"), "the burst leaves them molten")
	_check(EP.state(barrel) == "gone", "the keg is used up (%s)" % EP.state(barrel))
	_check(int(EP.verbs.get("keg", 0)) >= 1, "the keg is counted")
