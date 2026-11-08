extends SceneTree
## Round 57 (rooms lane; docs/features/rooms.md): every room in rooms.gd ORDER, headless:
##   the data: each entry's tag is a piece, its footprint inside the room's size, floor pieces on tile centres and one
##   per tile, no two standing pieces' footprints overlapping (one may stand on a floor tile), the walls' pieces on a
##   wall; every flourish id real; the Settings picker cycles every room;
##   the build: the room loads with no engine error, its live pieces are its layout's live entries;
##   the showcases: the cistern's channel freezes as one body and Slapshot carries the row down it into the east wall
##   (one frozen pool can't); the forge's powder line chains three kegs and spills both braziers from one magma hit, and
##   storm on one plate makes every bonded plate live and charges a foe on the far one; the hazards leave the hero be.
## Prints [rooms] PASS/FAIL.  Run: godot --headless --path . -s tests/rooms_check.gd

const TILE := 4.0

class Catch extends Logger:
	var errors: Array[String] = []
	var on := false

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if on and error_type != ERROR_TYPE_WARNING:
			errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])


var _fails: Array[String] = []
var _catch := Catch.new()
var main: Node
var hero: CharacterBody3D
var game: Node
var EP: GDScript
var RM: GDScript
var VE: GDScript
var FL: GDScript


func _initialize() -> void:
	OS.add_logger(_catch)
	await process_frame
	game = get_root().get_node("Game")
	game.save_hints = false
	EP = load("res://scripts/env_piece.gd")
	RM = load("res://scripts/rooms.gd")
	VE = load("res://scripts/void_element.gd")
	FL = load("res://scripts/env_flourish.gd")
	_data()
	for room: String in RM.ORDER:
		_catch.errors.clear()
		_catch.on = true
		await _room(room)
		_built(room)
		_catch.on = false
		_check(_catch.errors.is_empty(), "%s loads with no engine error (%s)" % [room, str(_catch.errors.slice(0, 3))])
		match room:
			"cistern":
				await _cistern_channel()
				await _cistern_slapshot()
			"forge":
				await _forge_powder_line()
				await _forge_plates()
		await _drop()
	game.room = "plain"
	if _fails.is_empty():
		print("[rooms] PASS")
	else:
		for f in _fails:
			print("[rooms] FAIL: ", f)
		print("[rooms] FAIL (%d)" % _fails.size())
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


func _dummy(i: int, at: Vector3) -> Node3D:
	var d: Node3D = main._dummies[i]
	d.home = at
	d.global_position = at
	d.velocity = Vector3.ZERO
	return d


# --- the data -------------------------------------------------------------------------------------------------------

## A piece's footprint on the floor: [centre (x, z), half extents (x, z)] for a square (floor tiles, boxes turned by
## their yaw, as their bounding square), or a circle's radius in .x with .y -1.
func _footprint(e: Dictionary) -> Array:
	var spec: Dictionary = EP.PIECES[e.tag]
	var c := Vector2(e.at.x, e.at.z)
	if spec.get("floor", false):
		return [c, Vector2(spec.size.x, spec.size.z) * 0.5]
	if spec.collider == "cyl":
		return [c, Vector2(spec.size.x, -1.0)]
	if spec.collider == "box":
		var h := Vector2(spec.size.x, spec.size.z) * 0.5
		var yaw := deg_to_rad(float(e.get("yaw", 0.0)))
		var turned := Vector2(absf(cos(yaw)) * h.x + absf(sin(yaw)) * h.y, absf(sin(yaw)) * h.x + absf(cos(yaw)) * h.y)
		return [c, turned]
	return []


## How far two footprints overlap (> 0: they do), in metres.
func _overlap(a: Array, b: Array) -> float:
	var ca: Vector2 = a[0]
	var cb: Vector2 = b[0]
	var ha: Vector2 = a[1]
	var hb: Vector2 = b[1]
	if ha.y < 0.0 and hb.y < 0.0:
		return ha.x + hb.x - ca.distance_to(cb)
	if ha.y < 0.0 or hb.y < 0.0:  # circle against square
		var circ: Vector2 = ca if ha.y < 0.0 else cb
		var r: float = ha.x if ha.y < 0.0 else hb.x
		var sc: Vector2 = cb if ha.y < 0.0 else ca
		var sh: Vector2 = hb if ha.y < 0.0 else ha
		var near := Vector2(clampf(circ.x, sc.x - sh.x, sc.x + sh.x), clampf(circ.y, sc.y - sh.y, sc.y + sh.y))
		return r - circ.distance_to(near)
	return minf(ha.x + hb.x - absf(ca.x - cb.x), ha.y + hb.y - absf(ca.y - cb.y))


func _data() -> void:
	var seen := {}
	var r := "plain"
	for i in RM.ORDER.size():
		seen[r] = true
		r = RM.next_room(r)
	_check(seen.size() == RM.ORDER.size() and r == "plain", "the Settings picker cycles every room (%s)" % str(seen.keys()))
	for room: String in RM.ORDER:
		var d: Dictionary = RM.def_of(room)
		_check(RM.ROOM_DEFS.has(room) and RM.label(room) != "" and str(d.get("lore", "")) != "", "%s has a label and a lore line" % room)
		_check(RM.rebuild(room), "%s is a training room: it rebuilds" % room)
		for id: String in d.get("flourishes", []):
			_check(id in FL.IDS, "%s's flourish %s is an env_flourish id" % [room, id])
		for tag: String in d.get("links", []):
			_check(EP.PIECES.has(tag) and EP.PIECES[tag].get("floor", false), "%s links %s, a floor piece" % [room, tag])
		var half: Vector2 = d.size * 0.5
		var lay: Array = RM.layout(room)
		var feet := []
		var tiles := {}
		for e: Dictionary in lay:
			_check(EP.PIECES.has(e.tag), "%s: %s is a piece" % [room, e.tag])
			if not EP.PIECES.has(e.tag):
				continue
			var spec: Dictionary = EP.PIECES[e.tag]
			var on_wall: bool = e.at.y > 0.5  # (torches, hooks: hung on a wall or a pillar's face)
			_check(absf(e.at.x) <= half.x + 0.01 and e.at.z >= -half.y - 0.01 and e.at.z <= half.y + 0.01,
				"%s: the %s at %s is inside the room" % [room, e.tag, str(e.at)])
			var fp := _footprint(e)
			if not fp.is_empty():
				var c: Vector2 = fp[0]
				var h: Vector2 = fp[1]
				var ext := Vector2(h.x, h.x) if h.y < 0.0 else h
				_check(absf(c.x) + ext.x <= half.x + 0.05 and absf(c.y) + ext.y <= half.y + 0.05,
					"%s: the %s at %s lies inside the walls (out to %.2f, %.2f)" % [room, e.tag, str(e.at), absf(c.x) + ext.x, absf(c.y) + ext.y])
				if not on_wall:
					feet.append([e, fp])
			if spec.get("floor", false):
				var k := Vector2(e.at.x, e.at.z)
				_check(is_equal_approx(fposmod(k.x, TILE), TILE * 0.5) and is_equal_approx(fposmod(k.y, TILE), TILE * 0.5),
					"%s: the %s at %s sits on a tile centre" % [room, e.tag, str(e.at)])
				_check(not tiles.has(k), "%s: one floor piece per tile (%s twice)" % [room, str(k)])
				tiles[k] = true
			if e.tag in ["torch", "banner"] or (e.tag == "hook" and absf(e.at.z) > half.y - 1.0):
				_check(absf(absf(e.at.z) - half.y) < 0.6 or absf(absf(e.at.x) - half.x) < 0.6, "%s: the %s at %s hangs on a wall" % [room, e.tag, str(e.at)])
		for i in feet.size():
			for j in range(i + 1, feet.size()):
				if EP.PIECES[feet[i][0].tag].get("floor", false) or EP.PIECES[feet[j][0].tag].get("floor", false):
					continue  # (a piece may stand on a floor tile: the keg corner's barrel on the spikes' edge; tiles are one per tile above)
				var o := _overlap(feet[i][1], feet[j][1])
				_check(o <= 0.05, "%s: the %s at %s and the %s at %s overlap by %.2f m" % [room, feet[i][0].tag, str(feet[i][0].at),
					feet[j][0].tag, str(feet[j][0].at), o])
		for s: Dictionary in RM.showcase(room):
			_check(s.has("tokens") and s.dummies.size() == 4 and str(s.get("expect", "")) != "", "%s's showcase %s is complete" % [room, s.get("name", "?")])
			for at: Vector3 in [s.hero] + s.dummies:
				_check(absf(at.x) < half.x - 0.5 and absf(at.z) < half.y - 0.5, "%s's showcase %s: %s inside the room" % [room, s.name, str(at)])
	# What only the new rooms have: the room with pieces has one pool, one barrel, one grate and links none.
	var pieces: Array = RM.layout("pieces")
	for tag: String in ["pool", "barrel", "grate"]:
		_check(pieces.filter(func(e: Dictionary) -> bool: return e.tag == tag and e.get("live", true)).size() == 1, "the room with pieces has one %s" % tag)
	_check(not RM.links("pieces", "pool") and not RM.links("pieces", "grate") and not RM.links("plain", "grate"), "only the new rooms link pieces")
	_check(RM.flourish("pieces", "gallows") and not RM.flourish("plain", "gallows") and RM.flourish("cistern", "ice_rink")
		and not RM.flourish("cistern", "brazier_spill") and RM.flourish("forge", "brazier_spill") and not RM.flourish("hall", "ice_rink"),
		"each room plays its own flourishes")


## The room as built: its live pieces are its layout's live entries, each in env and its group.
func _built(room: String) -> void:
	var want := {}
	for e: Dictionary in RM.layout(room):
		if e.get("live", true):
			want[e.tag] = int(want.get(e.tag, 0)) + 1
	var got := {}
	for n: Node in get_nodes_in_group("env"):
		var tag: String = EP.tag_of(n)
		got[tag] = int(got.get(tag, 0)) + 1
	_check(got == want, "%s builds its live pieces (%s, want %s)" % [room, str(got), str(want)])
	_check(main.get_meta(EP.REBUILD_META, false) == RM.rebuild(room), "%s passes its rebuild rule" % room)


# --- the cistern ----------------------------------------------------------------------------------------------------

func _channel() -> Array:
	var out: Array = get_nodes_in_group("env_pool").filter(func(p: Node3D) -> bool: return absf(p.global_position.z + 14.0) < 0.1)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	return out


## A cube made by the west pool freezes the whole channel (one body of water); a cube's line down it gets RINK_EXTRA
## for each pool, and with only one frozen, one RINK_EXTRA (all the room with pieces can give).
func _cistern_channel() -> void:
	var ch := _channel()
	_check(ch.size() == 4, "the cistern's channel is four pools (%d)" % ch.size())
	_check(EP.linked(ch[0]).size() == 3, "the west pool is linked to the other three (%d)" % EP.linked(ch[0]).size())
	var by: Node3D = _dummy(0, ch[0].global_position + Vector3(-2.4, 0, 0))  # (0.4 m off its west edge)
	VE.encase(by)
	await create_timer(0.4).timeout
	var frozen: Array = ch.map(func(p: Node3D) -> String: return EP.state(p))
	_check(frozen.all(func(s: String) -> bool: return s == "frozen"), "a cube by the west pool freezes the whole channel (%s)" % str(frozen))
	var from: Vector3 = ch[0].global_position + Vector3(-1.0, 0, 0)
	var extra: float = FL.rink_extra(self, from, Vector3.RIGHT, 10.0)
	_check(is_equal_approx(extra, FL.RINK_EXTRA * 4.0), "a cube's line down the frozen channel goes RINK_EXTRA per pool (%.1f)" % extra)
	for p: Node3D in ch.slice(1):
		p.get_node("RinkWatch").thaw()
	var one: float = FL.rink_extra(self, from, Vector3.RIGHT, 10.0)
	_check(is_equal_approx(one, FL.RINK_EXTRA), "one frozen pool is one RINK_EXTRA (%.1f)" % one)
	print("  cistern: the channel frozen as one: +%.0f m down it, +%.0f m over one pool" % [extra, one])
	for p: Node3D in ch:
		p.get_node("RinkWatch").thaw()
	await create_timer(0.5).timeout


## The showcase "down the channel": Harpoon on the west pool's row freezes the channel, Slapshot carries it the length
## of the channel into the east wall (~21 m from the row), past where one pool's slide could reach.
func _cistern_slapshot() -> void:
	var ch := _channel()
	hero.global_position = Vector3(-9.6, 0, -14.0)
	hero._face(Vector3.RIGHT)
	var row := [_dummy(0, Vector3(-8.1, 0, -14.0)), _dummy(1, Vector3(-6.6, 0, -13.4)), _dummy(2, Vector3(-7.2, 0, -14.8))]
	_dummy(3, Vector3(0, 0, 8.0))
	await _frames(3)
	hero.bot_alt = true
	hero._start_attack("EF")
	var far := -INF
	var t := 0.0
	var frozen_all := false
	while t < 7.0:
		await physics_frame
		t += 1.0 / 60.0
		for d: Node3D in row:
			far = maxf(far, d.global_position.x)
		if ch.all(func(p: Node3D) -> bool: return EP.state(p) == "frozen"):
			frozen_all = true
	hero.bot_alt = false
	print("  cistern: Slapshot down the channel: the furthest cube reached x %.1f (the east wall's face 16)" % far)
	_check(frozen_all, "Harpoon on the west pool freezes the channel")
	_check(far >= 13.5, "Slapshot carries a cube the channel's length to the east wall (x %.1f)" % far)
	_check(far - (-8.1) > 10.0 + FL.RINK_EXTRA, "further than one frozen pool's slide could (%.1f m)" % (far + 8.1))
	await create_timer(1.0).timeout


# --- the forge ------------------------------------------------------------------------------------------------------

## The showcase "powder line": magma on a foe by the middle keg: it bursts, both kegs by it catch and burst, each tips
## the brazier past it (a molten patch: the foe there is molten). The hero stands by a keg the whole time: unhurt.
func _forge_powder_line() -> void:
	var kegs: Array = get_nodes_in_group("env_barrel")
	var braziers: Array = get_nodes_in_group("env_brazier")
	_check(kegs.size() == 3 and braziers.size() == 2, "the forge has three kegs and two braziers (%d, %d)" % [kegs.size(), braziers.size()])
	kegs.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	var mid: Node3D = kegs[1]
	hero.global_position = kegs[2].global_position + Vector3(0, 0, 1.6)  # (in the third keg's KEG_R)
	var hp: float = hero.hp
	var lit: Node3D = _dummy(0, mid.global_position + Vector3(0, 0, 1.0))
	var east: Node3D = braziers[0] if braziers[0].global_position.x > 0.0 else braziers[1]
	var by_coals: Node3D = _dummy(1, east.global_position + Vector3(1.2, 0, 0))  # (where its coals run, away from the burst)
	_dummy(2, Vector3(0, 0, 8.0))
	_dummy(3, Vector3(2, 0, 8.0))
	await _frames(3)
	var spills := int(EP.verbs.get("keg_spill", 0))
	VE.mark(lit, "molten")
	_check(EP.state(mid) == "burning", "magma by the middle keg sets it burning")
	await create_timer(EP.KEG_FUSE * 2.0 + 0.8, true, false, true).timeout
	var states: Array = kegs.map(func(k: Node3D) -> String: return EP.state(k))
	var bz: Array = braziers.map(func(b: Node3D) -> String: return EP.state(b))
	print("  forge: powder line: kegs %s, braziers %s" % [str(states), str(bz)])
	_check(states.all(func(s: String) -> bool: return s == "gone"), "the burst chains down the line: all three kegs burst (%s)" % str(states))
	_check(bz.all(func(s: String) -> bool: return s == "spilled"), "and each end keg tips the brazier past it (%s)" % str(bz))
	_check(int(EP.verbs.get("keg_spill", 0)) - spills == 2, "two keg spills counted")
	_check(VE.marked(by_coals, "molten"), "the foe where the coals ran is molten")
	_check(FL.spill_seams(self).size() == 2, "both spills are fresh coal seams for Hellseam")
	_check(is_equal_approx(hero.hp, hp), "the kegs leave the hero be (hp %.0f -> %.0f)" % [hp, hero.hp])


## The showcase "bonded plates": storm on a foe on the east plate makes every plate live; the foe on the west plate, 9 m
## off, is charged by the floor. The hero on a plate the whole time: unhurt.
func _forge_plates() -> void:
	var plates: Array = get_nodes_in_group("env_grate")
	_check(plates.size() == 3, "the forge has three plates (%d)" % plates.size())
	plates.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	hero.global_position = plates[1].global_position + Vector3(0.5, 0, 0.5)
	var hp: float = hero.hp
	var a: Node3D = _dummy(0, plates[2].global_position + Vector3(0.6, 0, 0))
	var far: Node3D = _dummy(1, plates[0].global_position + Vector3(-0.8, 0, -0.6))
	await _frames(3)
	for p: Node3D in plates:
		_check(EP.state(p) == "cold", "the plates start cold (%s)" % EP.state(p))
	VE.mark(a, "charged")
	var st: Array = plates.map(func(p: Node3D) -> String: return EP.state(p))
	_check(st.all(func(s: String) -> bool: return s == "live"), "storm on the east plate makes every bonded plate live (%s)" % str(st))
	await create_timer(0.2, true, false, true).timeout
	_check(VE.marked(far, "charged"), "the foe on the far plate is charged by the floor")
	_check(EP.live_grates(self).size() == 3, "three live grates for Short Circuit")
	await create_timer(EP.LIVE_S + 0.8, true, false, true).timeout
	st = plates.map(func(p: Node3D) -> String: return EP.state(p))
	_check(st.all(func(s: String) -> bool: return s == "cold"), "cold again after LIVE_S (%s)" % str(st))
	_check(is_equal_approx(hero.hp, hp), "the live floor leaves the hero be (hp %.0f -> %.0f)" % [hp, hero.hp])
	print("  forge: bonded plates: one storm hit, three plates live, the far foe charged")
