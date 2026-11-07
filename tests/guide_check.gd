extends SceneTree
## Checks the combo guide against the real routing: from every move (resting
## and Awakened), each row's move is what that press starts, and each row's
## "next" combo is what one more press starts after it. Prints `[guide] PASS`
## or `[guide] FAIL ...`. Windowed it also renders the guide in six states to
## `user://guide_sheet.png`. godot --path . -s tests/guide_check.gd
## (headless works for the checks: godot --headless --path . -s tests/guide_check.gd)

const FROM := ["L1", "L2", "L3", "DL", "GR", "EC", "EE", "AL1", "EW", "IP", "IJ", "IS", "EM", "EA", "EF", "VS", "VR", "VD", "EV", "TW"]
const CROP := Vector2i(760, 300)

var _fails: Array[String] = []


## A stand-in foe for the payoff tag (round 4): just what improv_reach / improv_state read.
class Foe extends Node3D:
	var radius := 0.5
	func is_alive() -> bool: return true
	func is_airborne() -> bool: return false


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game.combo_guide = true  # (not saved)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	main.clear_room()
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var p: Node3D = main.player
	p.bot_enabled = true
	var guide: Control = main.hud.combo_guide

	for awake: bool in [false, true]:
		p.HERO_AWAKEN.set_awakened(p, awake)
		for from: String in FROM:
			_begin(p, from)
			var rows: Array = p.HERO_MOVES.combo_options(p)
			_check(not rows.is_empty(), "%s%s shows rows" % [from, _tag(awake)])
			for row: Dictionary in rows:
				_begin(p, from)
				var want: String = p.HERO_MOVES.dash_light(p) if row.kind == "dash" else p._next_move(row.kind)
				_check(row.id == want, "%s%s %s -> %s (guide says %s)" % [from, _tag(awake), row.kind, want, row.id])
				if row.next.is_empty():
					continue
				_begin(p, from)
				if row.kind == "dash":
					p._air_dash = p.HERO_MOVES.can_air_dash(p)
					p._set_state(p.State.MOVE)
					p._post_dash_t = 0.3
				p._start_attack(row.id)
				var after: String = p._next_move(row.next.kind)
				_check(after == row.next.id, "%s%s %s then %s -> %s (guide says %s)" % [from, _tag(awake), row.id, row.next.kind, after, row.next.id])
		# Out of a dash: light is the Dash Stab, heavy is Tow Line.
		p._set_state(p.State.MOVE)
		p._post_dash_t = 0.3
		var rows: Array = p.HERO_MOVES.combo_options(p)
		_check(not rows.is_empty() and rows[0].id == "DL", "post-dash light -> DL" + _tag(awake))
		_check(rows.size() > 1 and rows[1].id == "TW" and p._next_move("heavy") == "TW", "post-dash heavy -> TW" + _tag(awake))
	p.HERO_AWAKEN.set_awakened(p, false)
	# A combo landed GUIDE_LEARNED times is no longer hinted as the follow-up.
	_begin(p, "L1")
	var hinted: String = p.HERO_MOVES.combo_options(p)[1].next.get("id", "")
	_check(hinted != "", "L1's heavy row hints a combo")
	p.combos_landed[hinted] = p.GUIDE_LEARNED
	_begin(p, "L1")
	_check(p.HERO_MOVES.combo_options(p)[1].next.get("id", "") != hinted, "a learned %s is no longer hinted" % hinted)
	p.combos_landed.clear()
	p._set_state(p.State.MOVE)
	p._post_dash_t = 0.0
	p._chain_i = 0
	_check(p.HERO_MOVES.combo_options(p).is_empty(), "no rows in neutral")
	p._set_state(p.State.CHARGE)
	_check(p.HERO_MOVES.combo_options(p).size() == 1 and p.HERO_MOVES.combo_options(p)[0].hold, "charging shows the hold row")
	p._set_state(p.State.MOVE)
	_mixing(main, p)
	# Feel audit 3 item 2: the rows go away from the pile; only an edge may override that (the old right-edge slack
	# sent every left choice back to the right whenever he wasn't near the right edge).
	var cg: GDScript = load("res://scripts/combo_guide.gd")
	_check(cg.guide_side(-1.0, 1.0, 800.0, 1600.0) == -1.0, "pile on the right, mid-screen: rows on his left")
	_check(cg.guide_side(1.0, -1.0, 800.0, 1600.0) == 1.0, "pile on the left, mid-screen: rows on his right")
	_check(cg.guide_side(-1.0, -1.0, 200.0, 1600.0) == 1.0, "near the left edge: rows on his right")
	_check(cg.guide_side(1.0, 1.0, 1450.0, 1600.0) == -1.0, "near the right edge: rows on his left")
	_check(cg.guide_side(-1.0, 1.0, cg.EDGE + 40.0, 1600.0) == 1.0, "an edge flip holds through its slack")

	if DisplayServer.get_name() != "headless":
		await _sheet(main, p, guide)
	print("[guide] PASS" if _fails.is_empty() else "[guide] FAIL " + "; ".join(_fails))
	quit()


## Round 4: mixing elements on the rows. A crossover row names its element change; a row whose move would cash in a
## foe's state in its own reach names the payoff (and the same move aimed away from it doesn't). Only tags: the row's
## move is still the real route (the loop above).
func _mixing(main: Node, p: Node3D) -> void:
	var el: GDScript = load("res://scripts/void_element.gd")
	_begin(p, "AL1")
	var light: Dictionary = p.HERO_MOVES.combo_options(p)[0]
	_check(light.id == "XR" and light.get("mix", "") == "storm > magma", "off Air Slash, Rockslide's row says storm > magma (%s)" % light.get("mix", ""))
	_begin(p, "L1")
	_check(p.HERO_MOVES.combo_options(p).all(func(r: Dictionary) -> bool: return not r.has("mix")), "L1's rows stay in their element: no mix tag")
	p.global_position = Vector3.ZERO
	p._face(Vector3(0, 0, 1))
	var foe := Foe.new()
	main.add_child(foe)
	foe.global_position = Vector3(0, 0, 3.0)
	foe.add_to_group("enemies")
	el.mark(foe, "buried")
	p._set_state(p.State.MOVE)
	p._post_dash_t = 0.3
	_begin(p, "DL")
	var heavy: Dictionary = p.HERO_MOVES.combo_options(p)[1]
	_check(heavy.id == "EF" and heavy.get("pay", "") == "Frozen In", "Harpoon's row off Dash Stab, a buried foe on its line: + Frozen In (%s)" % heavy.get("pay", ""))
	# Round 47: the tentacles reach all round him, so aiming away still pays; past their reach it doesn't.
	p._face(Vector3(0, 0, -1))
	_check(p.HERO_MOVES.combo_options(p)[1].get("pay", "") == "Frozen In", "aimed away, the tentacles still reach it: + Frozen In")
	foe.global_position = Vector3(0, 0, 12.5)
	_check(not p.HERO_MOVES.combo_options(p)[1].has("pay"), "past the tentacles' reach, no payoff tag")
	foe.free()
	p._set_state(p.State.MOVE)


func _begin(p: Node3D, from: String) -> void:
	p._set_state(p.State.MOVE)
	p._post_dash_t = 0.0
	p._chain_i = 0
	p._start_attack(from)


func _tag(awake: bool) -> String:
	return " (Awakened)" if awake else ""


## Six states, cropped round the hero, in a 2x3 sheet (Air Slash: the mix tag on Rockslide).
func _sheet(main: Node, p: Node3D, guide: Control) -> void:
	var shots: Array[Image] = []
	var setups := [
		["", false, "L1", false], ["", false, "AL1", false], ["", true, "L3", true],
		["", true, "EC", false], ["", true, "dash", false], ["", false, "charge", false]]
	for s: Array in setups:
		p.HERO_AWAKEN.set_awakened(p, s[1])
		p.global_position = Vector3.ZERO
		p._set_state(p.State.MOVE)
		p._post_dash_t = 0.0
		p._chain_i = 0
		await create_timer(0.3).timeout  # the guide fades out between states
		match s[2]:
			"dash":
				p._set_state(p.State.MOVE)
				p._post_dash_t = 5.0
			"charge":
				p._start_charge()
			_:
				p._start_attack(s[2])
		# Early (s[3]): the ring still filling. Otherwise once a press is taken.
		for i in 120:
			await process_frame
			if s[2] == "dash":
				p._post_dash_t = 5.0
			if s[2] == "charge":
				Input.action_press("attack_heavy")
			var w: Dictionary = p.HERO_INPUT.combo_window(p)
			if guide._vis >= 1.0 and guide._swap_t > 0.15 and (w.progress > 0.35 if s[3] else w.ready):
				break
		var img := main.get_viewport().get_texture().get_image()
		var at := main.get_viewport().get_camera_3d().unproject_position(p.global_position + Vector3.UP * 1.1)
		var scale := Vector2(img.get_size()) / main.get_viewport().get_visible_rect().size
		var c := Vector2i((at * scale).round()) - Vector2i(260, CROP.y / 2)
		c = c.clamp(Vector2i.ZERO, img.get_size() - CROP)
		shots.append(img.get_region(Rect2i(c, CROP)))
		Input.action_release("attack_heavy")
	var sheet := Image.create(CROP.x * 2, CROP.y * 3, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i((i % 2) * CROP.x, (i / 2) * CROP.y))
	sheet.save_png("user://guide_sheet.png")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[guide] fail: ", what)
