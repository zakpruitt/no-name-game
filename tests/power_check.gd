extends SceneTree
## Checks the power paths, fusions and masteries (data + effects), then,
## windowed, renders the power UI: `user://power_cards.png` (a normal card,
## a level-up and a fusion), `user://power_build.png` (pause build view) and
## `user://power_hud.png` (the HUD strip). Prints `[powers] PASS` or
## `[powers] FAIL ...`.
## godot --path . -s tests/power_check.gd   (checks only: add --headless)

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game.skip_title = true
	var upgrades: GDScript = load("res://scripts/upgrades.gd")
	_check_data(upgrades)

	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	main._queue.clear()
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var p: Node3D = main.player
	await _check_effects(main, p, upgrades)

	if DisplayServer.get_name() != "headless":
		await _shots(main, p)
	print("[powers] PASS" if _fails.is_empty() else "[powers] FAIL " + "; ".join(_fails))
	quit()


func _check_data(U: GDScript) -> void:
	for u: Dictionary in U.ALL:
		_check(U.PATHS.has(u.get("path", "")), "%s has a path" % u.id)
		_check(not u.has("fusion") or U.PATHS.has(u.fusion), "%s fusion path" % u.id)
		_check(U.icon(u.id) != null, "%s has an icon" % u.id)
		_check(U.SLOT_NAMES.has(u.slot) or u.has("fusion"), "%s slot has a name" % u.id)
		for key: String in u.lv:
			_check(("{%s}" % key) in u.desc or key in ["damage", "radius", "reach"], "%s shows %s" % [u.id, key])
	var counts: Dictionary = U.path_counts({})
	for path: String in U.PATHS:
		var n := 0
		for u: Dictionary in U.ALL:
			if u.path == path and not u.has("fusion"):
				n += 1
		print("[powers] %s: %d powers" % [path, n])
		_check(n >= U.MASTERY_NEED, "%s has enough powers for its mastery" % path)
		_check(counts[path] == 0, "empty build counts nothing")
	# Fusions: never offered without both paths; offered once you have them.
	var rng := RandomNumberGenerator.new()
	for i in 200:
		rng.seed = i
		for card: Dictionary in U.roll({"bloodthirst": 1}, 3, false, rng):
			_check(not card.has("fusion"), "no fusion with one path (got %s)" % card.id)
	var seen := false
	for i in 200:
		rng.seed = i
		for card: Dictionary in U.roll({"bloodthirst": 1, "whirlwind": 1}, 3, false, rng):
			seen = seen or card.id == "crescendo"
			_check(not card.has("fusion") or card.id == "crescendo", "only Light+Heavy fusions (got %s)" % card.id)
	_check(seen, "Crescendo offered with Light + Heavy")
	_check(U.masteries({"bloodthirst": 1, "quickblade": 1, "flicker": 1}) == ["light"], "fusion counts toward mastery")
	_check(U.masteries({"bloodthirst": 1, "quickblade": 1}).is_empty(), "two powers is not a mastery")


func _check_effects(main: Node, p: Node3D, U: GDScript) -> void:
	var hp: float = p.max_hp
	for id: String in ["reaper", "second_wind", "chain_spark"]:
		p.add_upgrade(id)
	_check("soul" in p.masteries, "Soul mastery switches on")
	_check(is_equal_approx(p.max_hp, hp + U.PATHS.soul.mastery.hp), "Soul mastery adds max HP")
	p.remove_upgrade("reaper")
	_check(is_equal_approx(p.max_hp, hp), "losing the mastery takes the HP back")
	for id: String in ["quickblade", "bloodthirst", "rising_edge"]:
		p.add_upgrade(id)
	_check("light" in p.masteries, "Light mastery switches on")
	var base: float = p.MOVES.L1.damage
	_check(p._effective_move("L1").damage > base * 1.1, "Light mastery boosts L1")
	p._start_attack("L1")
	_check(p._anim_mult > 1.1, "Quickblade speeds light attacks")
	p._start_attack("H")
	_check(is_equal_approx(p._anim_mult, 1.0), "Quickblade leaves heavies alone")
	p._set_state(p.State.MOVE)
	# Thousand Cuts on a real enemy.
	p.add_upgrade("thousand_cuts")
	var e: Node3D = await _spawn(main, p)
	var hp_before: float = e.hp
	for i in int(p.upg("thousand_cuts", "hits")):
		p._thousand_cuts(e)
	_check(p.power_procs.get("thousand_cuts", 0) == 1, "Thousand Cuts rends on the Nth hit")
	_check(e.hp < hp_before, "Thousand Cuts deals damage")
	# Crescendo: an L3 hit empowers the next heavy.
	p.add_upgrade("whirlwind")
	p.add_upgrade("crescendo")
	p._crescendo = true
	p._start_attack("H")
	_check(not p._crescendo and p.power_procs.get("crescendo", 0) == 1, "Crescendo empowers the next heavy")
	p._set_state(p.State.MOVE)
	# Shockstep and Slipstream.
	p.add_upgrade("momentum")
	p.add_upgrade("shockstep")
	p._shockstep(p.global_position)
	_check(p.power_procs.get("shockstep", 0) == 1, "Shockstep fires")
	p.add_upgrade("slipstream")
	e.global_position = p.global_position + Vector3(0.5, 0, 0)
	p._start_dash()
	p._slipstream()
	p._slipstream()
	_check(p.power_procs.get("slipstream", 0) == 1, "Slipstream cuts once per dash")
	p._set_state(p.State.MOVE)
	# Razor Gale (Flurry's last cut) and Eye of the Storm (Cyclone's pull).
	p.add_upgrade("razor_gale")
	var bolts_before := main.get_children().size()
	p._razor_gale(p.facing_dir())
	_check(p.power_procs.get("razor_gale", 0) == 1, "Razor Gale fires")
	_check(main.get_children().size() - bolts_before == int(p.upg("razor_gale", "count")), "Razor Gale flings its blades")
	p.add_upgrade("eye_of_storm")
	p._start_attack("DH")
	e.global_position = p.global_position + Vector3(4.0, 0, 0)
	var pull_hp: float = e.hp
	p._eye_of_storm()
	_check(p.power_procs.get("eye_of_storm", 0) == 1 and e.hp < pull_hp, "Eye of the Storm drags a foe in")
	# Spike (L H H, not a power but a combo): a juggled foe is slammed down.
	_check(p.route("heavy", "LH", true, 0, false, false) == "LHH", "L H H routes to Spike")
	e.take_hit(1.0, Vector3.ZERO, 8.0, false)
	p._start_attack("LHH")
	p._spike(e)
	_check(p.spikes == 1 and e.velocity.y < 0.0, "Spike slams a juggled foe down")
	# Sky Reaper (Light + Soul fusion): light hits on a juggled foe.
	p.add_upgrade("sky_reaper")
	e.global_position = p.global_position + p.facing_dir() * 1.2
	e.take_hit(1.0, Vector3.ZERO, 8.0, false)
	p._start_attack("L1")
	p._do_hit()
	_check(p.power_procs.get("sky_reaper", 0) == 1, "Sky Reaper boosts light hits on juggled foes")
	p._set_state(p.State.MOVE)
	# War Chant: named combos feed Awakening, a new one twice as much.
	var game: Node = get_root().get_node("Game")
	p.add_upgrade("war_chant")
	p._set_awakened(false)
	game.awakening = 0.0
	p._last_combo = ""
	p._callout_done = false
	p._combo_callout("L3")
	var fresh: float = game.awakening
	p._callout_done = false
	p._combo_callout("L3")
	_check(fresh > 0.0 and is_equal_approx(game.awakening - fresh, fresh * 0.5), "War Chant pays double for a new combo")
	_check(p.combos_landed.get("L3", 0) >= 2, "landed combos are counted for the move list")
	p.add_upgrade("rebound")
	p._spike(e)
	await create_timer(p.REBOUND_DELAY + 0.1).timeout
	_check(p.power_procs.get("rebound", 0) == 1 and (not e.is_alive() or e.is_airborne()), "Rebound bounces the spiked foe back up")
	p._set_state(p.State.MOVE)
	# Flicker: light hits right after a dash.
	p.add_upgrade("flicker")
	p._since_dash = 0.1
	var hot: float = p._effective_move("L2").damage
	p._since_dash = 9.0
	_check(hot > p._effective_move("L2").damage * 1.2, "Flicker boosts light hits after a dash")
	# Undying Flame extends Awakening on a kill.
	p.add_upgrade("overflow")
	p.add_upgrade("undying_flame")
	p._set_awakened(true)
	p._awaken_t = 2.0
	p._on_enemy_killed(e)
	_check(p._awaken_t > 2.0, "Undying Flame extends Awakening")
	p._set_awakened(false)
	e.queue_free()


func _spawn(main: Node, p: Node3D) -> Node3D:
	var e: Node3D = main._spawn("warrior", false, p.global_position + Vector3(0, 0, 2))
	e.hp = 9999.0
	while not e.is_alive():
		await process_frame
	return e


func _shots(main: Node, p: Node3D) -> void:
	for id: String in p.upgrades.keys():
		p.remove_upgrade(id)
	for id: String in ["bloodthirst", "quickblade", "whirlwind", "static_step", "static_step", "overflow", "reaper"]:
		p.add_upgrade(id)
	main.hud.set_upgrades(p.upgrades)
	var U: GDScript = load("res://scripts/upgrades.gd")
	var cards: Array = []
	for pair: Array in [["thousand_cuts", 1], ["whirlwind", 2], ["crescendo", 1]]:
		var card: Dictionary = U.get_by_id(pair[0]).duplicate()
		card.level = pair[1]
		cards.append(card)
	main.reward.open(cards, 12)
	await create_timer(0.5).timeout
	main.get_viewport().get_texture().get_image().save_png("user://power_cards.png")
	main.reward.pick(0)
	await create_timer(0.6).timeout
	main.get_viewport().get_texture().get_image().save_png("user://power_hud.png")
	var pause: Node = main.get_children().filter(func(n: Node) -> bool:
		return n.has_method("open_settings") and not n.has_signal("started"))[0]
	pause._open()
	await create_timer(0.3).timeout
	main.get_viewport().get_texture().get_image().save_png("user://power_build.png")
	pause.close_menu()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[powers] fail: ", what)
