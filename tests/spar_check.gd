extends SceneTree
## Combat against live foes (spar.gd, docs/features/training.md "Spar"), headless, one foe of each spar kind at a
## time in a cleared training room:
##   - the counter: each foe's real windup is counterable (the window opens at least MIN_LEAD s after the telegraph,
##     a dash at strike_in() inside counter.WINDOW is Backlash, the strike never lands); bolts (archer, mage) parry back;
##   - held foes do not strike: a windup under way is cut when a control move takes it (carried by a tentacle or a
##     gather, thrown, bound, frozen in a cube, hung on a hook, launched, seized), and nothing held starts one;
##   - each of those reaches its state (flying, bound, frozen, airborne, staggered) on a live foe;
##   - his hurt: a dash cancels it within HURT_OUT s;
##   - the spar foe spawns and respawns inside the room, wherever he stands;
##   - spar pass two, in play: the bot (training_bot.gd) plays its `spar` strings in a fresh training room on a live
##     warrior (Backlash into L L L H, Ricochet off a perfect, the grab and Harpoon cutting its windups) and archer (bolts
##     parried back), as `--autotest --spar=<kind>` would; the counters, Ricochet and a hold cut must land.
## Prints one `[spar_check] <kind> ...` line each and [spar_check] PASS/FAIL.
## Run: godot --headless --path . -s tests/spar_check.gd

var SPAR: GDScript  # (loaded in _initialize: preloading compiles it before the Game autoload)
var COUNTER: GDScript  # (loaded in _initialize: preloading compiles it before the Game autoload)
var THROWN: GDScript  # (loaded in _initialize: preloading compiles it before the Game autoload)
var FLOOR_BIND: GDScript  # (loaded in _initialize: preloading compiles it before the Game autoload)
const MIN_LEAD := 0.2  # game s of telegraph before the counter window opens
const HURT_OUT := 0.2  # s: a dash is out of his hurt by then
const HOLDS := ["carry", "throw", "bind", "freeze", "hook", "launch", "seize"]

var _fails: Array[String] = []
var main: Node
var hero: CharacterBody3D
var game: Node


func _initialize() -> void:
	await process_frame
	SPAR = load("res://scripts/spar.gd")
	COUNTER = load("res://scripts/counter.gd")
	THROWN = load("res://scripts/thrown_foe.gd")
	FLOOR_BIND = load("res://scripts/floor_bind.gd")
	game = get_root().get_node("Game")
	game.save_hints = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.5).timeout
	hero = main.player
	hero.bot_enabled = true
	hero.bot_move = Vector3.ZERO
	main.clear_room()
	for kind: String in SPAR.kinds():
		if SPAR.ranged(kind):
			await _bolt(kind)
		else:
			await _kind(kind)
	await _poise()
	await _hurt()
	await _respawn()
	await _bot("warrior")
	await _bot("archer")
	if _fails.is_empty():
		print("[spar_check] PASS")
	else:
		for f in _fails:
			print("[spar_check] FAIL: ", f)
		print("[spar_check] FAIL (%d)" % _fails.size())
	quit(0 if _fails.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


## A fresh `kind` foe 1.6 m in front of him, past its spawn, at the spar's third, holding its attack.
func _foe(kind: String) -> Node:
	for old in get_nodes_in_group("enemies"):
		old.remove_from_group("enemies")
		old.queue_free()
	for p in get_nodes_in_group("projectiles"):
		p.queue_free()
	for b in get_nodes_in_group(FLOOR_BIND.GROUP):
		b.queue_free()
	for t in get_nodes_in_group(THROWN.GROUP):
		t.queue_free()
	hero.global_position = Vector3(0.0, hero.global_position.y, 0.0)
	hero.velocity = Vector3.ZERO
	hero._set_state(hero.State.MOVE)
	hero._invuln_t = 0.0
	hero._dash_cd = 0.0
	hero._dash_buffer_t = 0.0
	hero.hp = hero.max_hp
	hero._face(Vector3(0, 0, -1))
	var e: Node = main._spawn(kind, false, Vector3(0.0, 0.0, -1.6))
	e.attack_damage *= SPAR.DAMAGE_SCALE
	e.max_hp = 500.0
	e.hp = 500.0
	await physics_frame
	await physics_frame  # (past its _ready; the SPAWN rise is only time, so it is cut short below)
	e.move_speed = 0.0
	e.dodge_chance = 0.0
	e._attack_cd = 99.0  # (no windup until a scenario sets one)
	e.global_position = Vector3(0.0, 0.0, -1.6)
	e.velocity = Vector3.ZERO
	e._set_state(e.State.CHASE)
	await physics_frame
	return e


func _to(e: Node) -> Vector3:
	var to: Vector3 = (e as Node3D).global_position - hero.global_position
	to.y = 0.0
	return to.normalized()


## Runs `s` game s; true if he was hurt meanwhile.
func _strike_lands(s: float) -> bool:
	var hp: float = hero.hp
	var t := 0.0
	while t < s:
		await physics_frame
		t += hero.get_physics_process_delta_time()
	return hero.hp < hp


func _kind(kind: String) -> void:
	# Its own windup, from the chase: a dash at the window's middle is Backlash.
	var e: Node = await _foe(kind)
	e._attack_cd = 0.0
	var lead := -1.0
	var countered := false
	for i in 240:
		await physics_frame
		var si: float = e.strike_in()
		if si >= 0.0 and lead < 0.0:
			lead = si - COUNTER.WINDOW
		if si >= 0.0 and si <= COUNTER.WINDOW * 0.6:
			hero.bot_move = _to(e)
			hero._start_dash()
			hero.bot_move = Vector3.ZERO
			countered = not hero._counter.is_empty()
			break
	var hp: float = hero.hp
	await create_timer(0.8).timeout
	_check(lead >= MIN_LEAD, "%s: the telegraph shows %.2f s before the counter window (want >= %.2f)" % [kind, lead, MIN_LEAD])
	_check(countered, "%s: a dash into its real windup is Backlash" % kind)
	_check(hero.hp >= hp, "%s: its countered strike never lands" % kind)
	var row := "%s windup=%.2f lead=%.2f countered=%s" % [kind, e.attack_windup, lead, countered]
	# Uncountered, it lands (the baseline the holds are measured against).
	e = await _foe(kind)
	_windup(e, 0.3)
	var lands := await _strike_lands(0.6)
	_check(lands, "%s: an uncountered strike lands" % kind)
	row += " lands=%s" % lands
	for how: String in HOLDS:
		e = await _foe(kind)
		_windup(e, 0.3)
		var held := await _hold(e, how)
		var hurt := await _strike_lands(0.8)
		_check(held, "%s: %s reaches its state" % [kind, how])
		_check(not hurt, "%s: no strike while %s" % [kind, how])
		row += " %s=%s" % [how, "HIT" if hurt else ("ok" if held else "nostate")]
		_release(e)
	# Nothing held starts a windup.
	e = await _foe(kind)
	e.set_meta(THROWN.FLYING, true)
	e._attack_cd = 0.0
	var wound := false
	for i in 40:
		await physics_frame
		wound = wound or e.state == e.State.WINDUP
	e.remove_meta(THROWN.FLYING)
	_check(not wound, "%s: a held foe starts no windup" % kind)
	row += " held_winds_up=%s" % wound
	print("[spar_check] ", row)


## The foe mid-windup, its strike `left` s away, facing him.
func _windup(e: Node, left: float) -> void:
	e._set_state(e.State.WINDUP)
	e._face(-_to(e))
	e._state_t = e.attack_windup - left


func _hold(e: Node, how: String) -> bool:
	match how:
		"carry":  # a tentacle carry or a gather (Collapse, Abyss, Avalanche, a lash): flying, moved by the move alone
			e.set_meta(THROWN.FLYING, true)
			for i in 6:
				e.global_position = Vector3(0.0, 1.5, -1.6)
				await physics_frame
			return e.state != e.State.WINDUP
		"throw":
			THROWN.launch(hero, e, (e as Node3D).global_position + Vector3(4.0, 0.0, -3.0), 1.0)
			await physics_frame
			return e.has_meta(THROWN.FLYING) and e.state == e.State.HURT
		"bind":
			FLOOR_BIND.bind(hero, [e], {"time": 1.2, "tick_damage": 0.5})
			await physics_frame
			return FLOOR_BIND.holds(e) and e.state == e.State.HURT
		"freeze":
			e.freeze(1.2, 2.0)
			await physics_frame
			return e.frozen_t > 0.0 and e.state == e.State.HURT
		"hook":  # gallows: bound, up under the hook
			e.set_meta(FLOOR_BIND.BOUND, true)
			for i in 6:
				e.global_position = Vector3(0.0, 1.8, -1.6)
				await physics_frame
			return e.state != e.State.WINDUP
		"launch":
			e.take_hit(1.0, Vector3(0, 0, -2.0), 9.0, false)
			await physics_frame
			return e.state == e.State.AIRBORNE
		"seize":
			e.stagger(0.9)
			await physics_frame
			return e.state == e.State.HURT
	return false


func _release(e: Node) -> void:
	if not is_instance_valid(e):
		return
	for m: String in [THROWN.FLYING, FLOOR_BIND.BOUND]:
		if e.has_meta(m):
			e.remove_meta(m)


## A ranged foe's bolt, dashed into inside the window, goes back at it.
func _bolt(kind: String) -> void:
	var e: Node = await _foe(kind)
	e.global_position = Vector3(0.0, 0.0, -6.0)
	e._attack_cd = 0.0
	var parried := false
	var hp: float = hero.hp
	var hits: int = e.hits_taken
	for i in 300:
		await physics_frame
		var c: Dictionary = COUNTER.find(hero, _to(e))
		if not c.is_empty() and c.bolt != null:
			hero.bot_move = _to(e)
			hero._start_dash()
			hero.bot_move = Vector3.ZERO
			parried = not hero._counter.is_empty()
			break
	await create_timer(1.0).timeout
	_check(parried, "%s: its bolt is parried by a dash inside the window" % kind)
	_check(hero.hp >= hp, "%s: the parried bolt does not hurt him" % kind)
	_check(e.hits_taken > hits, "%s: the parried bolt hits it back" % kind)
	print("[spar_check] %s bolt parried=%s back=%s" % [kind, parried, e.hits_taken > hits])


## The warrior's poise (8): a light hit (L1's 2.5) holds its windup, a big one or the POISE_HITS-th breaks it.
func _poise() -> void:
	var e: Node = await _foe("warrior")
	_windup(e, 0.5)
	e.take_hit(1.0, Vector3(0, 0, -2.5), 0.0, false)
	var one: bool = e.state == e.State.WINDUP
	e.take_hit(1.0, Vector3(0, 0, -2.5), 0.0, false)
	var two: bool = e.state == e.State.WINDUP
	e.take_hit(1.0, Vector3(0, 0, -2.5), 0.0, false)
	var three: bool = e.state == e.State.WINDUP
	_check(one and two, "warrior: poise holds its windup through two light hits")
	_check(not three, "warrior: the %dth light hit breaks it" % e.POISE_HITS)
	e = await _foe("warrior")
	_windup(e, 0.5)
	e.take_hit(1.0, Vector3.ZERO, 0.0, true)
	_check(e.state == e.State.HURT, "warrior: a big hit breaks its poise, knockback or not")
	print("[spar_check] warrior poise one=%s two=%s three=%s" % [one, two, three])


## His hurt: a dash cancels it within HURT_OUT s.
func _hurt() -> void:
	var e: Node = await _foe("warrior")
	_windup(e, 0.02)
	for i in 30:
		await physics_frame
		if hero.state == hero.State.HURT:
			break
	_check(hero.state == hero.State.HURT, "the strike puts him in hurt")
	var t0 := Time.get_ticks_msec()
	hero.bot_move = Vector3(1, 0, 0)
	while hero.state == hero.State.HURT and Time.get_ticks_msec() - t0 < 1000:
		hero._dash_buffer_t = 0.2
		await physics_frame
	hero.bot_move = Vector3.ZERO
	var ms := Time.get_ticks_msec() - t0
	_check(hero.state == hero.State.DASH, "a dash cancels his hurt (state %d)" % hero.state)
	_check(ms <= HURT_OUT * 1000.0 + 20.0, "the dash is out of hurt within %.2f s (%d ms)" % [HURT_OUT, ms])
	print("[spar_check] hurt dash_out=%d ms" % ms)
	await create_timer(0.5).timeout


## The bot's `spar` strings (training_bot.BOT_STRINGS, the plain room's) against a live `kind` in a fresh training
## room, BOT_ROUNDS times over (a respawn or a dodge can cost one round its counter), up to BOT_S s of game time.
const BOT_ROUNDS := 2
const BOT_S := 70.0
func _bot(kind: String) -> void:
	main.queue_free()
	await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.5).timeout
	hero = main.player
	main._spar = SPAR.start(main, PackedStringArray(["--spar=" + kind]))
	var BOT: GDScript = load("res://scripts/training_bot.gd")
	var ranged: bool = SPAR.ranged(kind)
	var picked: Array = BOT.BOT_STRINGS.filter(func(b: Dictionary) -> bool:
		return b.has("spar") and not b.has("room") and (b.spar == "ranged") == ranged)
	var labels: Array = []
	for i in BOT_ROUNDS:
		labels.append_array(picked)
	var bot: Node = BOT.new()
	bot.main = main
	bot.strings = labels.map(func(b: Dictionary) -> Array: return b.tokens)
	bot.string_labels = labels
	bot._quitting = true  # (its finish would quit the tree)
	bot._shots_taken = 99
	main.add_child(bot)
	var counters0: int = hero.counters
	var t := 0.0
	while bot._bot_strings_done.size() < bot.strings.size() and t < BOT_S:
		await physics_frame
		t += hero.get_physics_process_delta_time()
	var s: Node = main._spar
	var cuts: int = s.cuts + (s.foe.held_cuts if is_instance_valid(s.foe) else 0)
	var st: Dictionary = bot.foe_stats
	print("[spar_check] bot %s strings=%d/%d c=%d cp=%d bolt=%d w=%d missed=%d counters=%d ricochet=%s cuts=%d hurts=%d hits_taken=%d kills=%d %.0f s" % [
		kind, bot._bot_strings_done.size(), bot.strings.size(), st.c, st.cp, st.bolt, st.w, st.missed, hero.counters - counters0,
		hero.endings_seen.has(hero.VOID_ELEMENT.BREAKERS.CB.names.spirit), cuts, s.hurts, s.total_hits(), s.kills, t])
	_check(bot._bot_strings_done.size() == bot.strings.size(), "bot %s: every spar string played (%d/%d)" % [kind, bot._bot_strings_done.size(), bot.strings.size()])
	if ranged:
		_check(st.bolt > 0 and hero.counters > counters0, "bot %s: a bolt parried in play" % kind)
	else:
		_check(st.c > 0 and st.cp > 0 and hero.counters > counters0, "bot %s: Backlash and the perfect counter in play" % kind)
		_check(hero.endings_seen.has(hero.VOID_ELEMENT.BREAKERS.CB.names.spirit), "bot %s: Ricochet lands in play" % kind)
		_check(cuts > 0, "bot %s: a hold cuts a windup in play (cuts=%d)" % [kind, cuts])
	bot.queue_free()
	hero.bot_enabled = false


## He stands by the room's back wall: the foe spawns, and respawns, inside the room on the floor.
func _respawn() -> void:
	main.clear_room()
	hero.global_position = Vector3(0.0, hero.global_position.y, -main.ARENA_HALF + 1.5)
	var s: Node = SPAR.start(main, PackedStringArray(["--spar=minion"]))
	var lim: float = main.ARENA_HALF - 1.0
	var at: Vector3 = s.foe.global_position
	_check(absf(at.z) < lim and absf(at.x) < lim, "the spar foe spawns inside the room (%s)" % at)
	await create_timer(1.2).timeout
	s.foe.take_hit(9999.0, Vector3.ZERO, 0.0, true)
	await create_timer(SPAR.RESPAWN + 1.0).timeout
	var ok: bool = is_instance_valid(s.foe) and s.foe.global_position.y > -0.5 and absf(s.foe.global_position.z) < lim
	_check(ok, "and comes back inside, on the floor (%s)" % (s.foe.global_position if is_instance_valid(s.foe) else "none"))
	print("[spar_check] respawn first=%s again=%s" % [at, s.foe.global_position if is_instance_valid(s.foe) else "none"])
	s.queue_free()
