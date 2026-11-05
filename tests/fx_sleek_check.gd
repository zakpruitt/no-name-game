extends SceneTree
## Round 33 (FX sleek, round 2) logic, headless, PASS/FAIL:
##   - a breaker landing's hits on several foes make one damage number with their total (comic_number.gd);
##     the same hits outside a breaker make one number per foe;
##   - standing effects (a comic crack, a dark pool, the frost spear's frost) born before a string are
##     cleared on its first hit, and ones born after it started stay (standing_fx.gd);
##   - round 33, part 3: locomotion dust (comic_dust.gd) puffs once when the hero's clip turns to Run_Stop,
##     Dodge_Forward or Run_Start (not again while it plays, not on an air dodge), stays within its pool and
##     clears itself;
##   - round 33, sleek 4: the combo-name callout over him fades after callout_cap.HOLD_S real s (slow motion
##     can't hold it) and as soon as the next string starts; a hit's word (every tier) and number (any total) draw
##     the same on-screen ink (fx_palette.TEXT_INK_PX);
##   - round 33, sleek 5 (density): a landing's rim geyser is one thin column (elements.rim_geyser); Deep Freeze's cords one thin line (void_tendril.line);
##     the spirit echo's blade drawn to spirit_echo.VISUAL_REACH of its (unchanged) reach; a comic lava well draws only a short crack mark.
## Run: godot --headless --path . -s tests/fx_sleek_check.gd

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.0).timeout
	var p: CharacterBody3D = main.player
	p.set_physics_process(false)
	p.set_process(false)
	var num: GDScript = load("res://scripts/comic_number.gd")
	var foes := get_nodes_in_group("enemies").slice(0, 4)
	_ok(foes.size() >= 3, "dummies to hit (%d)" % foes.size())
	# Outside a breaker: one number per foe.
	p.state = p.State.MOVE
	var plain := {}
	for e: Node3D in foes:
		plain[num.add(main, e.global_position, 10.0, false, e)] = true
	_ok(plain.size() == foes.size(), "a number per foe outside a breaker (%d for %d)" % [plain.size(), foes.size()])
	await create_timer(1.0).timeout
	# A breaker landing: one total.
	p.state = p.State.LEAP
	var brk := {}
	var last: Node3D
	for e: Node3D in foes:
		last = num.add(main, e.global_position, 12.0, true, e)
		brk[last] = true
	p.state = p.State.MOVE
	await create_timer(0.1).timeout
	last = num.add(main, foes[0].global_position, 5.0, false, foes[0])  # a beat later (a thrown cube)
	brk[last] = true
	_ok(brk.size() == 1, "one number for a breaker's hits (%d)" % brk.size())
	_ok(is_equal_approx(last.total, 12.0 * foes.size() + 5.0), "breaker total %s" % last.total)
	await create_timer(1.2).timeout
	var after: Node3D = num.add(main, foes[0].global_position, 3.0, false, foes[0])
	_ok(after != last and is_equal_approx(after.total, 3.0), "the breaker total stops taking hits")
	# Standing effects.
	var standing: GDScript = load("res://scripts/standing_fx.gd")
	var crack: Node3D = load("res://scripts/comic_crack.gd").spawn(main, Vector3(3, 0, 3), Color.ORANGE, 1.5, 0.9)
	var pool: Node3D = load("res://scripts/dark_fx.gd").pool(main, Vector3(-3, 0, 3), 2.0, 5.0)
	var spear: Node3D = load("res://scripts/frost_spear.gd").plant(main, Vector3(0, 0, 5))
	await create_timer(0.1).timeout
	p._chain_i = 0
	p.state = p.State.MOVE
	p._hits_done = 0
	standing.watch(p)
	p.state = p.State.ATTACK
	p._chain_i = 1
	standing.watch(p)  # a string started
	await create_timer(0.05).timeout
	var own: Node3D = load("res://scripts/comic_crack.gd").spawn(main, Vector3(5, 0, 3), Color.ORANGE, 1.5, 0.9)
	standing.watch(p)
	_ok(crack.is_in_group(standing.GROUP), "nothing cleared before the first hit")
	p._hits_done = 1
	standing.watch(p)  # its first hit
	_ok(not crack.is_in_group(standing.GROUP) and not pool.is_in_group(standing.GROUP) and not spear.is_in_group(standing.GROUP),
		"crack, pool and frost cleared on the first hit")
	_ok(own.is_in_group(standing.GROUP), "an effect the string made itself stays")
	_ok(spear._cleared and spear.is_in_group(spear.GROUP), "the spear itself stays for the breaker")
	await create_timer(0.4).timeout
	_ok(not is_instance_valid(crack), "the old crack is gone")
	_ok(not is_instance_valid(pool), "the pool is gone")
	_ok(is_instance_valid(own), "the string's own crack is still up")
	# Locomotion dust.
	var dust: GDScript = load("res://scripts/comic_dust.gd")
	var ap: AnimationPlayer = p.anim
	ap.play(p._clip_name("Idle"))
	await process_frame
	dust.watch(p)
	var n0: int = dust.spawned
	ap.play(p._clip_name("Run_Stop"))
	await process_frame  # (ComicFx watches every frame too)
	dust.watch(p)
	_ok(dust.spawned == n0 + 1, "one puff on Run_Stop (%d)" % (dust.spawned - n0))
	await process_frame
	dust.watch(p)
	_ok(dust.spawned == n0 + 1, "no second puff while it plays")
	p.global_position.y = 1.5
	ap.play(p._clip_name("Dodge_Forward"))
	await process_frame
	dust.watch(p)
	_ok(dust.spawned == n0 + 1, "no puff on an air dodge")
	p.global_position.y = 0.0
	for i in 10:
		dust.spawn(main, Vector3(i, 0, 0), Vector3.FORWARD, ["stop", "dodge", "start"][i % 3])
	var mine := main.get_children().filter(func(c: Node) -> bool: return c.get_script() == dust)
	_ok(mine.size() <= dust.POOL, "dust stays in its pool (%d nodes)" % mine.size())
	await create_timer(0.6).timeout
	_ok(mine.all(func(c: Node) -> bool: return not c.busy and not c.visible), "dust clears itself")
	# Round 33, sleek 4: the callout over him is capped on real time and cut by the next string.
	var cap: GDScript = load("res://scripts/callout_cap.gd")
	p._callout_done = false
	p.state = p.State.MOVE
	p._chain_i = 0
	p._hits_done = 0
	standing.watch(p)
	p._combo_callout(p.COMBOS.keys()[0])
	cap.watch(p)
	_ok(p._callout.visible, "the callout goes up")
	game.hitstop(2.0, 0.5)  # a breaker's slow motion (flat at 0.5): its own tween would hold it for ~2 s
	await create_timer(1.3, true, false, true).timeout
	cap.watch(p)
	await create_timer(0.2, true, false, true).timeout
	cap.watch(p)
	game.end_slowmo()
	_ok(not p._callout.visible, "the callout is gone after ~1.1 s real in slow motion")
	p._callout_done = false
	p._combo_callout(p.COMBOS.keys()[0])
	cap.watch(p)
	await create_timer(0.1).timeout
	p.state = p.State.ATTACK
	p._chain_i = 1
	standing.watch(p)  # the next string starts
	cap.watch(p)
	await create_timer(0.2, true, false, true).timeout
	cap.watch(p)
	_ok(not p._callout.visible, "the callout fades when the next string starts")
	# Round 33, sleek 4: one ink weight for a hit's word and number, whatever its tier or total.
	var pal: GDScript = load("res://scripts/fx_palette.gd")
	var cfx: GDScript = load("res://scripts/comic_fx.gd")
	var inks: Array = []
	for base: float in cfx.WORD_SCALE + [cfx.BREAKER_SCALE]:
		inks.append(pal.text_ink(base) * base)
	var n1: Node3D = num.add(main, foes[1].global_position + Vector3(0, 0, 2), 8.0, false, null)
	var n2: Node3D = num.add(main, foes[2].global_position + Vector3(0, 0, 2), 250.0, true, null)
	await create_timer(0.3).timeout
	for n: Node3D in [n1, n2]:
		if is_instance_valid(n):
			var settled: float = minf(1.0 + n.total * num.GROW_PER, num.GROW_MAX) * (num.BIG_SCALE if n.big else 1.0)
			inks.append(n._front.outline_size * num.PIXEL * pal.PX_PER_M * settled)
	var lo: float = inks.min()
	var hi: float = inks.max()
	_ok(inks.size() == cfx.WORD_SCALE.size() + 3 and lo > pal.TEXT_INK_PX * 0.8 and hi < pal.TEXT_INK_PX * 1.2,
		"words and numbers share one ink weight (%.1f-%.1f px)" % [lo, hi])
	# Round 33, sleek 5: a landing's rim geyser is one thin column, no spikes or scorch of its own.
	var els: GDScript = load("res://scripts/elements.gd")
	var rim_root := Node3D.new()
	main.add_child(rim_root)
	els.rim_geyser(rim_root, Vector3(0, 0, -6), 0.9, 3.2, false)
	var rim: Array = rim_root.get_children()
	_ok(rim.size() == 1 and rim[0].is_in_group("comic_geyser") and rim[0].width < 0.9 * els.GEYSER_WIDTH,
		"a rim geyser is one thin column (%d nodes)" % rim.size())
	await _sleek5(main, p)
	print("[fx_sleek] ", "PASS" if _fails.is_empty() else "FAIL " + "; ".join(_fails))
	quit()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)


## Round 33, sleek 5 (the density pass): later items add their checks here.
func _sleek5(main: Node, _p: CharacterBody3D) -> void:
	await process_frame
	# Deep Freeze's cords: one thin line (void_tendril.line), not a three-layer ribbon.
	var tendril: GDScript = load("res://scripts/void_tendril.gd")
	var spans := []
	for thin: bool in [false, true]:
		var t: Node3D = tendril.new()
		main.add_child(t)
		t.line = thin
		t.draw(Vector3(0, 1, -6), Vector3(4, 1, -6), 1.0, 0.0, 0.0, 0.0)
		var m: ArrayMesh = t._mi.mesh
		spans.append([m.surface_get_array_len(0), m.get_aabb().size.z + m.get_aabb().size.y])
		t.queue_free()
	_ok(spans[1][0] < spans[0][0] and spans[1][1] < spans[0][1] * 0.6,  # (the sag is in both)
		"a pinning cord is one thin line (%s)" % str(spans))
	# The spirit echo's ghost blade draws short of its reach; the reach (the hit) is the cast's radius.
	var echo_s: GDScript = load("res://scripts/spirit_echo.gd")
	var echo: Node3D = echo_s.new()
	echo.axe_mesh = BoxMesh.new()
	echo.radius = 3.9
	echo.delay = 5.0  # (never sweeps here)
	main.add_child(echo)
	_ok(echo.radius == 3.9 and echo._scale < (3.9 - 0.4) / 0.95 * 0.8, "the echo's blade is drawn short of its reach (%.2f)" % echo._scale)
	echo.queue_free()
	# Undertow's lava well (comic): no glowing pool or crust chunks (they lit the tile grout as a web for 4 s); it still
	# burns for WELL_TIME.
	var els: GDScript = load("res://scripts/elements.gd")
	els.well(main, Vector3(3, 0, -6))
	await process_frame
	var wells := get_nodes_in_group("lava_wells")
	var drawn := 0
	for w: Node in wells:
		for c: Node in w.get_children():
			if c is MeshInstance3D and c.mesh != null:
				drawn += 1
	_ok(not wells.is_empty() and drawn == 0, "a comic lava well draws no pool or chunks (%d meshes)" % drawn)
	for w: Node in wells:
		w._physics_process(els.WELL_TIME * 0.5)
		_ok(is_instance_valid(w) and w.is_in_group("lava_wells"), "the well still burns past its look")
