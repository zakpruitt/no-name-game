extends SceneTree
## Input snap (round 51, fluidity): a press at every ms offset through each route step and each breaker window lands
## the documented move on the first legal frame, or is dropped only where the buffer says so. Headless, PASS/FAIL.
##   godot --headless --path . -s tests/input_snap_check.gd [-- --only=EF] [--step=1]
## The hero is stepped by hand at a fixed DT (his physics off), so a press lands at an exact ms of move time:
##   route steps: for every move A (whiffed, and connected: _connected set at its first hit) and both buttons, a press
##     o ms into A must start the routed move B at the first step past max(o, A's cancel point), and be dropped only
##     when o is more than BUFFER_MS before that cancel point. Moves whose breaker leaps before their cancel take no
##     press once connected (the leap does); the pause windows (BREAKERS `pause`: Harpoon, Impale) keep their early
##     routes (H off Harpoon is Ice Cube, L off Impale is Backdraft), and a press of the other button before the leap
##     is held into the window and dives on that button's ending as it opens (hero_input.held_for_window).
##   breaker windows: for every BREAKERS entry (and its `alt` with L), a press o ms after take-off is ignored inside
##     BREAKER_SPILL, locks before `open - BREAKER_EARLY`, is held and dives at `open` inside BREAKER_EARLY, dives at
##     once through `close`, and after `close` the window is missed.
## Offsets run every STEP_MS (1) within BAND_MS of each boundary and every COARSE_MS elsewhere (each sim restarts the
## move from its first frame), so every boundary is checked to the ms and the run stays inside agent.sh's timeout.

const DT := 1.0 / 240.0  # s per hand step (the game runs physics at 60; a finer step reads the boundary to ~4 ms)
const STEP_MS := 1
const COARSE_MS := 16
const BAND_MS := 10
## Move ids the route pass skips: the vault and Deep Freeze need the frost spear standing (void_arm_check walks them).
const SKIP := ["IJ", "IS"]

var fails := 0
var checked := 0
var world: Node3D
var hero: CharacterBody3D
var game: Node
var only := ""


func _initialize() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	game = root.get_node("Game")
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)
	hero = load("res://scripts/player.gd").new()
	world.add_child(hero)
	await process_frame
	hero.set_physics_process(false)
	hero.bot_enabled = false
	var t0 := Time.get_ticks_msec()
	await _routes()
	await _dashes()
	await _windows()
	await _dives()
	print("[snap] %d presses checked in %.1f s" % [checked, (Time.get_ticks_msec() - t0) / 1000.0])
	print("input_snap_check: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


# --- Stepping ---------------------------------------------------------------------

func _reset() -> void:
	game.end_slowmo()
	hero._set_state(hero.State.MOVE)
	hero._move_id = ""
	hero._chain_i = 0
	hero._buffered = ""
	hero._buffer_t = 0.0
	hero._dash_buffer_t = 0.0
	hero._post_dash_t = 0.0
	hero._connected = false
	hero.velocity = Vector3.ZERO
	hero.global_position = Vector3.ZERO
	hero.model.position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var spear: GDScript = load("res://scripts/frost_spear.gd")
	for s: Node in get_nodes_in_group(spear.GROUP):  # (Frost Spear's plant: a fresh press facing it vaults)
		s.remove_from_group(spear.GROUP)
		s.queue_free()


func _step(dt: float, connect: bool) -> void:
	hero._physics_process(dt)
	if connect and hero.state == hero.State.ATTACK and hero._hits_done > 0:
		hero._connected = true


## Starts `id` from standing (its chain position is chain_after(id), as in a string).
func _begin(id: String) -> void:
	_reset()
	hero._start_attack(id)


## Runs `id` with no press and returns {cancel, leap, end} in ms of move time (-1 if it never happened).
func _reference(id: String, connect: bool) -> Dictionary:
	_begin(id)
	var r := {"cancel": -1.0, "leap": -1.0, "end": -1.0}
	var ms := 0.0
	while ms < 3000.0:
		_step(DT, connect)
		ms += DT * 1000.0
		if hero.state == hero.State.LEAP:
			r.leap = ms
			break
		if hero.state != hero.State.ATTACK or hero._move_id != id:
			r.end = ms
			break
		if r.cancel < 0.0 and hero.HERO_MOVES.progress(hero) >= hero.HERO_INPUT.cancel_point(hero):
			r.cancel = ms
	return r


## Offsets (ms) to press at: every STEP_MS near the boundaries, every COARSE_MS elsewhere, up to `last`.
func _offsets(last: float, marks: Array) -> Array:
	var out := []
	var o := 0
	while o < last:
		var near := false
		for m: float in marks:
			if m >= 0.0 and absf(o - m) <= BAND_MS:
				near = true
		out.append(o)
		o += STEP_MS if near else COARSE_MS
	return out


# --- Route steps -------------------------------------------------------------------

func _routes() -> void:
	var buffer_ms: float = hero.input_buffer * 1000.0
	var step_ms := DT * 1000.0
	for id: String in hero.MOVES:
		if id in SKIP or (only != "" and id != only):
			continue
		for connect: bool in [false, true]:
			var ref := _reference(id, connect)
			var brk: Dictionary = hero.HERO_LEAP.entry_for(id)
			var pause: bool = connect and not brk.is_empty() and brk.get("pause", false)
			for kind: String in ["light", "heavy"]:
				# Enders whose leap comes first: once connected the leap takes the press (it lands in the window).
				if connect and ref.leap >= 0.0 and not pause:
					continue
				if ref.cancel < 0.0:
					_check(false, "%s%s: no cancel point before it ended (%s)" % [id, " hit" if connect else "", ref])
					continue
				var want: String = hero.HERO_MOVES.void_route(kind, id, true, hero.HERO_MOVES.chain_after(id), false)
				var held: bool = pause and hero.HERO_MOVES.pause_ending(id, kind) != "" and (want == "GR" or want in hero.HERO_MOVES.LIGHT_CHAIN)
				var last: float = ref.leap if ref.leap >= 0.0 else ref.end
				var drop_before: float = ref.cancel - buffer_ms
				var bad := 0
				for o: int in _offsets(last - step_ms, [drop_before, ref.cancel, last, last - buffer_ms if held else -1.0]):
					var got := await _press_route(id, kind, float(o), connect)
					checked += 1
					var hold_from: float = last - buffer_ms  # (a held press lives on its buffer: it must reach the leap)
					if absf(o - drop_before) <= step_ms * 1.5 or absf(o - ref.cancel) <= step_ms * 1.5 							or absf(o - last) <= step_ms * 2.1 or (held and absf(o - hold_from) <= step_ms * 1.5):
						continue  # (the boundary step itself: either side is right)
					var ok := true
					var why := ""
					if held:
						if o < hold_from:
							ok = got.id == "" and not got.held
							why = "dropped (more than BUFFER_MS before the leap)"
						else:
							ok = got.held and got.ended in ["dive", "hit", "perfect"] and got.alt == (kind == "light")
							why = "held into the window and dove with %s's ending" % kind
					elif o < drop_before:
						ok = got.id == ""
						why = "dropped (more than BUFFER_MS before the cancel)"
					else:
						var legal := maxf(o, ref.cancel)
						ok = got.id == want and got.at <= legal + step_ms * 1.01 + 0.01 and got.at >= legal - step_ms * 1.01
						why = "%s on the first frame past %.0f ms" % [want, legal]
					if not ok:
						bad += 1
						if bad <= 3:
							_check(false, "%s%s, %s at %d ms: want %s, got %s" % [id, " (hit)" if connect else " (whiff)", kind, o, why, got])
				if bad > 3:
					_check(false, "%s%s %s: %d more misses" % [id, " (hit)" if connect else "", kind, bad - 3])
				print("[snap] %-3s %-5s %s %-6s cancel=%4.0f %s=%4.0f ms -> %s%s" % [id, kind, "hit  " if connect else "whiff",
					"ok" if bad == 0 else "FAIL", ref.cancel, "leap" if ref.leap >= 0.0 else "end ", last,
					want, " (held for the window)" if held else ""])
			await process_frame


## Presses `kind` `o` ms into `id`; returns what it started: {id, at (ms), held, ended, alt}.
func _press_route(id: String, kind: String, o: float, connect: bool) -> Dictionary:
	_begin(id)
	var ms := 0.0
	var pressed := false
	var out := {"id": "", "at": -1.0, "held": false, "ended": "", "alt": false}
	while ms < 3000.0:
		if not pressed and ms + DT * 1000.0 > o:
			var part := (o - ms) / 1000.0
			if part > 0.0:
				_step(part, connect)
				ms = o
			hero._buffered = kind  # (exactly what hero_input.read_input does with a press)
			hero._buffer_t = hero.input_buffer
			pressed = true
			if hero.state != hero.State.ATTACK or hero._move_id != id:
				break
		_step(DT, connect)
		ms += DT * 1000.0
		if hero.state == hero.State.LEAP:
			out.held = hero._brk_held
			out.alt = hero._brk_alt
			if hero._brk_held:
				var t := 0.0
				while hero.state == hero.State.LEAP and hero._brk_phase == 0 and t < 2.0:
					_step(DT, false)
					t += DT
				out.ended = hero._brk_ended if hero._brk_ended != "" else ("dive" if hero._brk_phase == 1 else "")
				out.alt = hero._brk_alt
			break
		if hero.state == hero.State.ATTACK and hero._move_id != id:
			out.id = hero._move_id
			out.at = ms
			break
		if hero.state != hero.State.ATTACK:
			break
	if hero.state != hero.State.MOVE:
		_reset()
	return out


# --- Dash cancels ---------------------------------------------------------------------

## Every move, whiffed and connected: a dash pressed o ms in starts on the first frame past max(o, the first frame
## can_dash_cancel() allows: its first hit, or DASH_CANCEL_WHIFF of it), or is dropped only more than BUFFER_MS before.
## (A breaker's hang takes the dash too, for a player: hero_leap.tick; rhythm_check dashes out of every hang.)
func _dashes() -> void:
	var buffer_ms: float = hero.input_buffer * 1000.0
	var step_ms := DT * 1000.0
	for id: String in hero.MOVES:
		if id in SKIP or (only != "" and id != only):
			continue
		for connect: bool in [false, true]:
			_begin(id)
			var legal := -1.0
			var last := -1.0
			var ms := 0.0
			while ms < 3000.0:
				_step(DT, connect)
				ms += DT * 1000.0
				if hero.state != hero.State.ATTACK or hero._move_id != id:
					last = ms
					break
				if legal < 0.0 and hero.HERO_INPUT.can_dash_cancel(hero, hero.HERO_MOVES.progress(hero)):
					legal = ms
			if legal < 0.0:
				_check(false, "%s: never dash-cancellable before it ended" % id)
				continue
			var bad := 0
			for o: int in _offsets(last - step_ms, [legal - buffer_ms, legal, last]):
				if absf(o - legal) <= step_ms * 1.5 or absf(o - last) <= step_ms * 2.1 or absf(o - legal + buffer_ms) <= step_ms * 1.5:
					continue
				_begin(id)
				hero._dash_cd = 0.0
				var t := 0.0
				var pressed := false
				var at := -1.0
				while t < 3000.0:
					if not pressed and t + step_ms > o:
						if o - t > 0.0:
							_step((o - t) / 1000.0, connect)
							t = o
						hero._dash_buffer_t = hero.input_buffer
						pressed = true
						if hero.state != hero.State.ATTACK:
							break
					_step(DT, connect)
					t += step_ms
					if hero.state == hero.State.DASH:
						at = t
						break
					if hero.state != hero.State.ATTACK:
						break
				checked += 1
				var ok := at < 0.0 if o < legal - buffer_ms else (at >= 0.0 and at <= maxf(o, legal) + step_ms * 1.01 + 0.01)
				if not ok:
					bad += 1
					if bad <= 2:
						_check(false, "%s%s: dash at %d ms started at %.0f (legal from %.0f ms)" % [id, " (hit)" if connect else "", o, at, legal])
				_reset()
			if bad > 2:
				_check(false, "%s dash: %d more misses" % [id, bad - 2])
			print("[snap] %-3s dash  %s %-6s legal=%4.0f end=%4.0f ms" % [id, "hit  " if connect else "whiff", "ok" if bad == 0 else "FAIL", legal, last])
		await process_frame


# --- Breaker windows -------------------------------------------------------------------

func _windows() -> void:
	var el: GDScript = load("res://scripts/void_element.gd")
	var spill: float = hero.BREAKER_SPILL * 1000.0
	var early: float = hero.BREAKER_EARLY * 1000.0
	var step_ms := DT * 1000.0
	for id: String in el.BREAKERS:
		if only != "" and id != only:
			continue
		var b: Dictionary = el.entry(id)
		var open: float = b.open * 1000.0
		var close: float = b.close * 1000.0
		var kinds: Array[String] = ["heavy"]
		if b.has("alt"):
			kinds.append("light")
		for kind: String in kinds:
			var bad := 0
			for o: int in _offsets(close + 40.0, [spill, open - early, open, close]):
				var got := await _press_window(id, kind, float(o))
				checked += 1
				var near := false
				for m: float in [spill, open - early, open, close]:
					near = near or absf(o - m) <= step_ms * 1.5
				if near:
					continue
				var want := ""
				if o < spill:
					want = "miss"  # (ignored: the ender's own press spilling over, then nothing)
				elif o < open - early:
					want = "lock"
				elif o <= close:
					want = "dive"
				else:
					want = "miss"
				var dove: bool = got.ended in ["dive", "hit", "perfect"]
				var ok: bool = (dove and got.alt == (kind == "light")) if want == "dive" else got.ended == want
				if ok and want == "dive":
					ok = got.at <= maxf(o, open) + step_ms * 1.01 + 0.01  # on the first frame it's legal
				if not ok:
					bad += 1
					if bad <= 3:
						_check(false, "window %s, %s at %d ms: want %s, got %s" % [id, kind, o, want, got])
			if bad > 3:
				_check(false, "window %s %s: %d more misses" % [id, kind, bad - 3])
			print("[snap] window %-3s %-5s %-6s spill=%3.0f early=%3.0f open=%3.0f close=%3.0f ms" % [id, kind,
				"ok" if bad == 0 else "FAIL", spill, open - early, open, close])


## Starts `id`'s breaker, presses `kind` `o` ms after take-off (one step held), runs to the end of the window phase.
func _press_window(id: String, kind: String, o: float) -> Dictionary:
	_reset()
	await process_frame  # (the last sim's Input press and effects clear)
	var el: GDScript = load("res://scripts/void_element.gd")
	hero._move_id = id
	hero.HERO_LEAP.start(hero, id, el.entry(id))
	var action := "attack_light" if kind == "light" else "attack_heavy"
	var ms := 0.0
	var pressed := false
	var out := {"ended": "", "at": -1.0, "alt": false}
	while ms < 3000.0 and hero.state == hero.State.LEAP and hero._brk_phase == 0:
		if not pressed and ms + DT * 1000.0 > o:
			var part := (o - ms) / 1000.0
			if part > 0.0:
				hero._physics_process(part)
				ms = o
			Input.action_press(action)
			_step(DT, false)
			ms += DT * 1000.0
			Input.action_release(action)
			pressed = true
			await process_frame  # (is_action_just_pressed holds for the rest of the frame the press was in)
		else:
			_step(DT, false)
			ms += DT * 1000.0
		if out.at < 0.0 and hero._brk_phase == 1:
			out.at = ms
	out.ended = hero._brk_ended if hero._brk_ended != "" else ("dive" if hero._brk_phase == 1 else "")
	out.alt = hero._brk_alt
	game.end_slowmo()
	_reset()
	return out


# --- Dives -------------------------------------------------------------------------------

## A press anywhere in a breaker's dive (Pinwheel's whirl is 0.42 s, longer than BUFFER_MS) starts its move as soon as
## he lands, not dropped by the buffer running out mid-dive.
func _dives() -> void:
	var el: GDScript = load("res://scripts/void_element.gd")
	var step_ms := DT * 1000.0
	for id: String in el.BREAKERS:
		if only != "" and id != only:
			continue
		var b: Dictionary = el.entry(id)
		var endings: Array[bool] = [false]
		if b.has("alt"):
			endings.append(true)
		for alt: bool in endings:
			var bad := 0
			var dive_ms: float = float((b.alt if alt else b).get("dive", b.dive)) * 1000.0
			for o: int in _offsets(dive_ms - step_ms, [0.0, dive_ms]):
				_reset()
				await process_frame
				hero._move_id = id
				hero.HERO_LEAP.start(hero, id, el.entry(id))
				var t := 0.0
				while hero.state == hero.State.LEAP and hero._brk_phase == 0 and t < 3.0:
					if t >= b.sweet - DT:
						Input.action_press("attack_light" if alt else "attack_heavy")
						_step(DT, false)
						Input.action_release("attack_light" if alt else "attack_heavy")
						await process_frame
					else:
						_step(DT, false)
					t += DT
				var ms := 0.0
				var pressed := false
				var landed := -1.0
				var started := -1.0
				while ms < 3000.0:
					if not pressed and ms + step_ms > o:
						hero._buffered = "light"
						hero._buffer_t = hero.input_buffer
						pressed = true
					_step(DT, false)
					ms += step_ms
					if landed < 0.0 and hero.state != hero.State.LEAP:
						landed = ms
					if hero.state == hero.State.ATTACK:
						started = ms
						break
					if landed >= 0.0 and ms > landed + 100.0:
						break
				checked += 1
				game.end_slowmo()
				if started < 0.0 or started > landed + step_ms * 2.01:
					bad += 1
					if bad <= 2:
						_check(false, "dive %s%s: a press %d ms into the dive started nothing on the landing (landed %.0f, started %.0f)" % [id, " alt" if alt else "", o, landed, started])
				_reset()
			if bad > 2:
				_check(false, "dive %s: %d more misses" % [id, bad - 2])
			print("[snap] dive   %-3s %-5s %-6s dive=%3.0f ms" % [id, "alt" if alt else "", "ok" if bad == 0 else "FAIL", dive_ms])


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL: ", what)
