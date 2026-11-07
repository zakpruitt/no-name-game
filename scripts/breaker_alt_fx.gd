extends RefCounted
## The looks of the breaker pairs' second endings (breaker-pairs lane; the gameplay is in void_element.gd, each
## ending's branch of breaker_impact()):
##   meteor_drop(): Meteor Shower, one fireball out of the sky onto one foe (the designed meteor shell, then a small
##     designed meteor landing), calling `landed` as it hits;
##   pinwheel_ring(): Pinwheel, the twister round him while the tentacles whirl the kebab;
##   pinwheel_wall(): Pinwheel, a foe slammed into a wall or a pillar (ground stamp, wind burst on it, the word, a stop);
##   twister(): Tempest, the storm column that takes the crowd up.
## Designed sheets only (designed_fx / designed_elements / designed_twister / designed_ink): no polygons, no crystals.
## --fx=classic falls back to the old shared builders.

const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_INK := preload("res://scripts/designed_ink.gd")
const TWISTER := preload("res://scripts/designed_twister.gd")
const PAL := preload("res://scripts/fx_palette.gd")

const DROP_SKY := 7.0  # m above the foe a meteor starts
const DROP_BACK := 0.6  # of the way from the foe back to him it starts: they slant in from his side, not straight down
const DROP_SCALE := 0.55  # of Meteor Fall's fireball
const DROP_SPLASH := 1.5  # m: each landing's designed meteor burst (Meteor Fall's is METEOR_PILE_R 3)
const DROP_STOP := 0.04  # s hit stop each landing (a drum roll, the last a little longer)
const WALL_WORD := "KRAK-THOOM!"  # Pinwheel's wall hits (the breaker word says WHIRRR-KRAK!)
const WALL_WORD_SIZE := 0.75
const WALL_STAMP := 1.9  # m
const WALL_STOP := 0.07
const COOL_WORD_GAP_MS := 700
static var _word_ms := {}


## One of Meteor Shower's fireballs: from the sky over `e` (slanting in from `from`, his landing) down onto it in
## `fall` real s; `landed` (spot) is called on arrival.
static func meteor_drop(parent: Node, from: Vector3, e: Node3D, fall: float, landed: Callable) -> void:
	var foot := Vector3(e.global_position.x, 0.0, e.global_position.z)
	var sky := foot.lerp(Vector3(from.x, 0.0, from.z), DROP_BACK) + Vector3.UP * DROP_SKY
	var shell: Node3D = load("res://scripts/void_element.gd").meteor_shell(parent, foot - sky)
	shell.global_position = sky
	shell.scale = Vector3.ONE * DROP_SCALE  # (a volley, not Meteor Fall's one big ball round him)
	var tw := parent.create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(shell):
			var to := foot
			if is_instance_valid(e):  # (it follows the foe: Undertow holds them, but a hit may have moved one)
				to = Vector3(e.global_position.x, 0.0, e.global_position.z)
			shell.global_position = sky.lerp(to + Vector3.UP * 0.9, k * k), 0.0, 1.0, fall)
	tw.tween_callback(func() -> void:
		var at := foot
		if is_instance_valid(e):
			at = Vector3(e.global_position.x, 0.0, e.global_position.z)
		if is_instance_valid(shell):
			shell.queue_free()
		if DESIGNED.on():
			DESIGNED.meteor(parent, at, DROP_SPLASH)
		else:
			Fx.scorch(parent, at, PAL.of("earth").body, DROP_SPLASH, 1.2)
		landed.call(at))


## Pinwheel's whirl: a twister round him for the swing (`time` s), the held kebab riding round inside it.
static func pinwheel_ring(parent: Node, at: Vector3, radius: float, time: float) -> void:
	if DESIGNED.on():
		TWISTER.spawn(parent, at, 3.2, radius, time)
	else:
		load("res://scripts/elements.gd").nova(parent, at, "wind", radius, 8)


## A Pinwheel foe hitting a wall or a pillar at `spot` (its feet), thrown along `dir`.
static func pinwheel_wall(parent: Node, spot: Vector3, dir: Vector3) -> void:
	var at := Vector3(spot.x, 0.0, spot.z)
	if DESIGNED.on():
		DESIGNED_INK.shock(parent, at, PAL.of("wind").light, WALL_STAMP, 0.3)
		DESIGNED.hit(parent, at + dir * 0.5 + Vector3.UP * 1.1, "wind", 1.6)
		DESIGNED.streaks(parent, at + Vector3.UP * 1.1, dir, "wind", true)
	ComicFx.say(WALL_WORD, at + Vector3.UP * 1.7, WALL_WORD_SIZE)
	Game.hitstop(WALL_STOP)
	Game.shake(0.55)
	if Game.camera_rig:
		Game.camera_rig.kick(dir, 0.35)
	Game.sfx("quake", -6.0, 0.08)


## Round 51 cool pass: a rebuilt ending's foe slamming into a wall or pillar at `spot` (its feet), thrown along `dir`, in
## `el` (Collapse's spits: void; Avalanche's cubes: water): Pinwheel's wall beat in that element, and `word` if given.
static func cool_wall(parent: Node, spot: Vector3, dir: Vector3, el: String, word := "") -> void:
	var at := Vector3(spot.x, 0.0, spot.z)
	if DESIGNED.on():
		DESIGNED_INK.shock(parent, at, PAL.of(el).light, WALL_STAMP, 0.3)
		DESIGNED.hit(parent, at + dir * 0.5 + Vector3.UP * 1.1, el, 1.6)
		DESIGNED.streaks(parent, at + Vector3.UP * 1.1, dir, el, true)
	if word != "" and Time.get_ticks_msec() - int(_word_ms.get(word, -100000)) > COOL_WORD_GAP_MS:
		_word_ms[word] = Time.get_ticks_msec()  # (one word for a volley of hits on the same wall)
		ComicFx.say(word, at + Vector3.UP * 1.7, WALL_WORD_SIZE)
	Game.hitstop(WALL_STOP * 0.7)
	Game.shake(0.45)
	if Game.camera_rig:
		Game.camera_rig.kick(dir, 0.3)
	Game.sfx("quake", -7.0, 0.08)


## Tempest's column: a fat twister `high` m tall, `radius` round, for `time` s.
static func twister(parent: Node, at: Vector3, high: float, radius: float, time: float) -> void:
	if DESIGNED.on():
		TWISTER.spawn(parent, at, high, radius, time)
	else:
		load("res://scripts/elements.gd").nova(parent, at, "wind", radius, 8)

# --- Uproot (round 51, env-pieces lane: Abyss's LMB; gameplay in void_element.gd `_uproot`) -------------------------
# The pillar is the comic dungeon piece itself; the rest is designed sheets: the tentacle's drawn skin (void_tendril),
# designed dust and ground stamps, env_target's drawn chunks, the dark hit star. No polygons.

const UPROOT_LIFT := 0.8  # m the pillar comes up out of the floor as he dives
const UPROOT_LEAN := 0.35  # radians it leans back, away from the foe, at the top of the tear
const UPROOT_TEAR := 0.14  # real s of the tear
const UPROOT_CHUNKS := 4  # drawn chunks off its foot as it comes out, and along the line as it lands
const UPROOT_STAMP := 1.6  # m: each ground stamp along the fall line
const UPROOT_STOP := 0.09  # s hit stop as it lands
const UPROOT_TENDRIL := &"uproot_tendril"
## Round 52 (env-pieces2, readability on film: the pillar on the foe was lost under the tentacle and the landing's
## effects): before it comes down the pillar is held up at the top of the swing for UPROOT_HOLD real s as a solid flat
## silhouette in the void's light (Fx.flash_tint; ink read as nothing on the dark floor), its drop shadow lies on the floor along the fall line from the hold,
## darkening as it falls, and the tentacle lets go of it as the fall starts, so the club lands in the clear.
const UPROOT_HOLD := 0.16  # real s held at the top before the fall (the club's hit comes this much later)
const UPROOT_HOLD_LIFT := 1.4  # m it is hauled up to for the hold
const UPROOT_HOLD_LEAN := 0.55  # radians back, away from the foe, at the hold
const UPROOT_SHADOW_W := 1.9  # m across the fall line
const UPROOT_SHADOW := 0.75  # alpha at the landing
const UPROOT_SHADOW_FADE := 0.45  # real s after the landing


static func _tendril(parent: Node, pillar: Node3D) -> Node3D:
	var t: Node3D = pillar.get_meta(UPROOT_TENDRIL) if pillar.has_meta(UPROOT_TENDRIL) else null
	if is_instance_valid(t):
		return t
	t = load("res://scripts/void_tendril.gd").new()
	parent.add_child(t)
	pillar.set_meta(UPROOT_TENDRIL, t)
	return t


## Where on the pillar the tentacle holds it: two thirds up its axis.
static func _grip(pillar: Node3D) -> Vector3:
	return pillar.global_transform * Vector3(0.0, 2.7, 0.0)


static func _hand(hero: Node) -> Vector3:
	var v: Variant = hero.get("_void")
	if v != null and is_instance_valid(v) and v.has_method("_hand_pos"):
		return v._hand_pos()
	return (hero as Node3D).global_position + Vector3.UP * 1.4


## The tear (the dive): the tentacle lashes round the pillar, which comes up out of the floor in a burst of chunks
## and dust and leans back for the swing.
static func uproot_tear(parent: Node, hero: Node3D, pillar: Node3D) -> void:
	var home := pillar.transform
	var away := Vector3(pillar.global_position.x - hero.global_position.x, 0.0, pillar.global_position.z - hero.global_position.z)
	away = away.normalized() if away.length() > 0.05 else Vector3.BACK
	var axis := Vector3.UP.cross(away).normalized()
	var foot := Vector3(pillar.global_position.x, 0.0, pillar.global_position.z)
	var tendril := _tendril(parent, pillar)
	var tw := parent.create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(pillar):
			return
		var e := 1.0 - (1.0 - k) * (1.0 - k)
		pillar.transform = Transform3D(Basis(axis, UPROOT_LEAN * e) * home.basis, home.origin + Vector3.UP * UPROOT_LIFT * e)
		if is_instance_valid(tendril) and is_instance_valid(hero):
			tendril.draw(_hand(hero), _grip(pillar), 1.0, 0.05, 0.6 * (1.0 - k) + 0.25, k), 0.0, 1.0, UPROOT_TEAR)
	if DESIGNED.on():
		DESIGNED.dust(parent, foot, 1.6)
		DESIGNED_INK.shock(parent, foot, PAL.of("void").light, 1.4, 0.3)
	var env: Node = load("res://scripts/env_target.gd").of(parent.get_tree())
	if env != null:
		for i in UPROOT_CHUNKS:
			var a := TAU * i / UPROOT_CHUNKS + randf() * 0.6
			env._chunk(foot + Vector3.UP * 0.4, Vector3(cos(a), 0.0, sin(a)) * 3.5 + Vector3.UP * 5.5, i)
	ComicFx.say("KRRRK!", foot + Vector3.UP * 2.2, 0.5)
	Game.shake(0.35)
	Game.sfx("quake", -8.0, 0.1)


## The club (the landing): the pillar swings down from where the tear left it to lie from `base` along `dir` in `fall`
## real s, the tentacle hauling on its head; `landed` is called as it hits, then the fall line breaks up the floor.
static func uproot_club(parent: Node, hero: Node3D, pillar: Node3D, base: Vector3, dir: Vector3, fall: float, landed: Callable) -> void:
	var start := pillar.transform
	var yaw := Basis(Vector3.UP, pillar.rotation.y)
	var axis := Vector3.UP.cross(dir).normalized()
	var length: float = load("res://scripts/env_piece.gd").PIECES.pillar.size.y
	var lie := Vector3.UP * float(load("res://scripts/env_piece.gd").PIECES.pillar.size.x)  # (on its side, on the floor)
	var tendril := _tendril(parent, pillar)
	# round 52: the landing's frame can take a few hundred ms to draw (the impact frame; on film 250-320 ms) and the
	# first real-time step after it ate the whole hold: start the club two frames later
	var tree := parent.get_tree()
	for i in 2:
		await tree.process_frame
	if not is_instance_valid(pillar) or not is_instance_valid(parent):
		landed.call()
		return
	# the hold at the top of the swing, a silhouette, the shadow down already
	var top := Transform3D(Basis(axis, -UPROOT_HOLD_LEAN) * yaw, Vector3(start.origin.x, UPROOT_HOLD_LIFT, start.origin.z))
	var from := top
	var shadow := _uproot_shadow(parent, base, dir, length)
	Fx.flash_tint(pillar, PAL.of("void").light, UPROOT_HOLD + fall * 0.7)  # (a flat light shape: the floor is dark)
	var tw := parent.create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(pillar):
			return
		var e := 1.0 - (1.0 - k) * (1.0 - k) * (1.0 - k)
		pillar.transform = Transform3D(start.basis.slerp(top.basis, e), start.origin.lerp(top.origin, e))
		_shade(shadow, UPROOT_SHADOW * 0.35 * k)
		if is_instance_valid(tendril) and is_instance_valid(hero):
			tendril.draw(_hand(hero), _grip(pillar), 1.0, 0.04, 0.2, 1.0), 0.0, 1.0, UPROOT_HOLD * 0.5)
	tw.tween_interval(UPROOT_HOLD * 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(tendril):
			tendril.visible = false)  # (lets go: the fall is the pillar's own)
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(pillar):
			return
		var e := k * k  # (it falls: slow off the top, fast into the floor)
		var at: Vector3 = from.origin.lerp(base + lie, e)
		var b := Basis(axis, PI * 0.5 * e) * yaw
		pillar.transform = Transform3D(from.basis.slerp(b, e), at)
		_shade(shadow, UPROOT_SHADOW * (0.35 + 0.65 * e)), 0.0, 1.0, fall)
	tw.tween_callback(func() -> void:
		if is_instance_valid(pillar):
			pillar.transform = Transform3D(Basis(axis, PI * 0.5) * yaw, base + lie)
			Fx.flash(pillar, 0.1)  # (it lands: a white flash on it)
		if is_instance_valid(tendril):
			tendril.queue_free()
		landed.call()
		_uproot_land(parent, base, dir))
	tw.tween_method(func(k: float) -> void: _shade(shadow, UPROOT_SHADOW * (1.0 - k)), 0.0, 1.0, UPROOT_SHADOW_FADE)
	tw.tween_callback(func() -> void:
		if is_instance_valid(shadow):
			shadow.queue_free())


## The falling pillar's drop shadow: a soft ink oval along the fall line from `base` (the dash streak's material).
static func _uproot_shadow(parent: Node, base: Vector3, dir: Vector3, length: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(UPROOT_SHADOW_W, length + 0.8)
	mi.mesh = plane
	mi.material_override = Fx.unshaded_mat(Color(ComicLook.INK, 0.0), "dot")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	parent.add_child(mi)
	mi.global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), base + dir * (length * 0.5) + Vector3.UP * 0.03)
	return mi


static func _shade(shadow: Variant, a: float) -> void:
	if is_instance_valid(shadow):
		((shadow as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = a


## The fall line breaks up: ground stamps and dust along its four metres, chunks, the dark hit star at its head.
static func _uproot_land(parent: Node, base: Vector3, dir: Vector3) -> void:
	if not is_instance_valid(parent):
		return
	var length: float = load("res://scripts/env_piece.gd").PIECES.pillar.size.y
	var env: Node = load("res://scripts/env_target.gd").of(parent.get_tree())
	for i in 3:
		var at := base + dir * (length * (0.25 + 0.35 * i))
		if DESIGNED.on():
			DESIGNED_INK.shock(parent, at, PAL.of("void").light, UPROOT_STAMP, 0.32)
			DESIGNED.dust(parent, at, 1.3)
		if env != null:
			var side := dir.cross(Vector3.UP) * (1.0 if i % 2 == 0 else -1.0)
			env._chunk(at + Vector3.UP * 0.3, (side * 3.0 + dir * 1.5) + Vector3.UP * 4.5, i)
	var head := base + dir * length
	if DESIGNED.on():
		DESIGNED.hit(parent, head + Vector3.UP * 0.8, "void", 1.8)
	Game.hitstop(UPROOT_STOP)
	Game.shake(0.9)
	if Game.camera_rig:
		Game.camera_rig.kick(dir, 0.45)
	Game.sfx("quake", -2.0, 0.05)


## No pillar in reach: the tentacle comes down on the foe from the sky alone, a small slam.
static func uproot_open(parent: Node, at: Vector3) -> void:
	if DESIGNED.on():
		DESIGNED_INK.shock(parent, at, PAL.of("void").light, 1.2, 0.25)
		DESIGNED.hit(parent, at + Vector3.UP * 0.8, "void", 1.0)
	Game.shake(0.4)
