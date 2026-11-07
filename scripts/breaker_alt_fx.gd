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


## Tempest's column: a fat twister `high` m tall, `radius` round, for `time` s.
static func twister(parent: Node, at: Vector3, high: float, radius: float, time: float) -> void:
	if DESIGNED.on():
		TWISTER.spawn(parent, at, high, radius, time)
	else:
		load("res://scripts/elements.gd").nova(parent, at, "wind", radius, 8)
