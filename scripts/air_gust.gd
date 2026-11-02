extends RefCounted
## The Updraft's gale (player.MOVES AH `gust`): the air itself throws the
## shaman higher. A twisting funnel of wind roars up from the floor to his
## feet, a ring of wind blades whirls round him as he spins up on it, the
## floor's dust blows out from under him, and his element streams up the
## column. Wind reads as air whatever his element (the funnel takes the hero's
## colour); the element shows in the motes and, for wind, lightning. Visual only.

const ELEMENTS := preload("res://scripts/elements.gd")
const TIME := 0.55  # the column's life
const BLADES := 5  # wind blades whirling round him
const HELIX := 14  # element pieces spiralling up the column
const BLADE_TIME := 0.16  # s a Gale Waltz wind blade takes to reach the floor
const COMET_STEP := 0.025  # s between Stormfall's trail beats


## The gale under the hero at `pos` (his body, on the floor), riding up with
## `model`; `c` is his colour, `el` his element.
static func gust(parent: Node, pos: Vector3, model: Node3D, c: Color, el: String) -> void:
	var floor_at := Vector3(pos.x, 0.0, pos.z)
	var top := maxf(model.position.y, 1.0) + 1.8  # up past where he'll be
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = floor_at
	var outer := ELEMENTS._mi(ELEMENTS.funnel(1.5, 0.45, top), ELEMENTS.swirl_mat(c, false, 2.4))
	outer.position.y = top * 0.5
	root.add_child(outer)
	var inner := ELEMENTS._mi(ELEMENTS.funnel(0.8, 0.2, top * 0.95), ELEMENTS.swirl_mat(c, true, 3.0))
	inner.position.y = top * 0.475
	root.add_child(inner)
	root.scale = Vector3(0.3, 0.2, 0.3)
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(outer, "rotation:y", TAU * 2.5, TIME)
	tw.tween_property(inner, "rotation:y", -TAU * 3.5, TIME)
	_helix(root, el, top)
	ELEMENTS._fade_free(root, TIME * 0.5, TIME * 0.5)
	_blades(model, c)
	# The floor blasts out from under him; streaks and his element rush up the column.
	Fx.ring(parent, floor_at, Color(c.darkened(0.2), 0.9), 3.2, 0.3)
	Fx.ring(parent, floor_at, Color(1.0, 1.0, 1.0, 0.6), 1.8, 0.2)
	Fx.dust(parent, floor_at, 16, 1.0)
	Fx.burst(parent, floor_at + Vector3.UP * 0.4, c.lerp(Color.WHITE, 0.5), 26, 16.0, 0.12, 0.45, Vector3.UP, 12.0, 6.0, 0.6)
	Fx.burst(parent, floor_at + Vector3.UP * 0.4, ELEMENTS.LOOK[el].glow, 14, 11.0, 0.18, 0.5, Vector3.UP, 20.0, 2.0, 0.5)
	if el == "earth":
		Fx.shards(parent, floor_at + Vector3.UP * 0.3, ELEMENTS.LOOK.earth.rock.lightened(0.2), 12, Vector3.UP, 12.0, 0.2, 0.7)
	elif el == "water":
		Fx.burst(parent, floor_at + Vector3.UP * 0.3, Color(0.9, 0.97, 1.0), 20, 12.0, 0.2, 0.6, Vector3.UP, 25.0, -6.0, 0.6)
	elif el == "wind":
		ELEMENTS.lightning_fx(parent, floor_at, c, top + 4.0)
	ELEMENTS.light_pop(parent, floor_at, c, 4.0, 6.0, 0.3)
	Game.sfx("cast_wind", -2.0, 0.08)
	Game.sfx("dash", -4.0, 0.1)


## His element torn up and carried round the column: HELIX pieces (rocks,
## ice shards, leaf blades, spirit wisps) spiralling from the floor to the top.
static func _helix(root: Node3D, el: String, top: float) -> void:
	var spin := Node3D.new()
	root.add_child(spin)
	for i in HELIX:
		var p := ELEMENTS.piece(el, 2.2)
		var ang := TAU * i / HELIX * 2.0  # two turns of the spiral
		var r := 0.9 + 0.25 * sin(i * 1.7)
		p.position = Vector3(sin(ang) * r, 0.0, cos(ang) * r)
		spin.add_child(p)
		var tw := p.create_tween()
		tw.tween_interval(i * 0.02)
		tw.tween_property(p, "position:y", top * randf_range(0.75, 1.05), TIME * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	spin.create_tween().tween_property(spin, "rotation:y", TAU * 1.5, TIME)


## The gale he stands on while he's up there (player keeps it until he lands):
## a low spinning vortex under his feet with wind crescents racing round it.
## Child of the model, so it rides with him; `vanish()` it on landing.
static func cloud(model: Node3D, c: Color) -> Node3D:
	var root := Node3D.new()
	model.add_child(root)
	var s := model.scale.x if model.scale.x > 0.01 else 1.0
	root.scale = Vector3.ONE / s
	var disc := ELEMENTS._mi(ELEMENTS.funnel(1.3, 0.25, 0.5), ELEMENTS.swirl_mat(c, true, 1.2))
	disc.position.y = -0.15
	root.add_child(disc)
	for i in 3:
		var ang := TAU * i / 3.0
		var b := ELEMENTS._mi(ELEMENTS.crescent(0.25), ELEMENTS.glow(c.lerp(Color.WHITE, 0.4), 1.5))
		b.position = Vector3(sin(ang), -0.1, cos(ang)) * Vector3(1.05, 1.0, 1.05)
		b.rotation.y = ang + PI * 0.5
		b.scale = Vector3.ONE * 0.6
		root.add_child(b)
	_no_ghost(root)
	root.create_tween().set_loops().tween_property(root, "rotation:y", TAU, 0.45).as_relative()
	root.scale *= 0.2
	root.create_tween().tween_property(root, "scale", Vector3.ONE / s, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return root


## The cloud he stood on blows apart as he leaves it.
static func vanish(cloud_node: Node3D, parent: Node) -> void:
	cloud_node.reparent(parent)  # (stays where he left it; reparent keeps the global transform)
	var tw := cloud_node.create_tween().set_parallel()
	tw.tween_property(cloud_node, "scale", cloud_node.scale * 1.8, 0.25).set_ease(Tween.EASE_OUT)
	ELEMENTS._fade_free(cloud_node, 0.0, 0.25)


## Gale Waltz: a wind blade flung off the cut at `from` (his height), raking
## down onto the floor `reach` m along `dir` and bursting there in his element.
## `big` (the last cut): a larger blade with a twin crossed over it, landing harder.
static func wind_blade(parent: Node, from: Vector3, dir: Vector3, c: Color, el: String, reach := 4.5, big := false) -> void:
	var to := Vector3(from.x, 0.0, from.z) + dir * reach
	var b := ELEMENTS._mi(ELEMENTS.crescent(0.35), ELEMENTS.glow(c.lerp(Color.WHITE, 0.3), 1.8))
	parent.add_child(b)
	b.global_position = from
	b.rotation = Vector3(-0.6, atan2(dir.x, dir.z), 0.0)  # bulging along its flight, nose down
	b.scale = Vector3.ONE * 1.1
	var trail := ELEMENTS._mi(ELEMENTS.crescent(0.2), ELEMENTS.glow(Color(c, 0.45), 1.2))
	b.add_child(trail)
	trail.position.z = -0.35
	trail.scale = Vector3.ONE * 0.85
	if big:
		b.scale = Vector3.ONE * 1.8
		var twin := ELEMENTS._mi(ELEMENTS.crescent(0.3), ELEMENTS.glow(c.lerp(Color.WHITE, 0.5), 2.0))
		b.add_child(twin)
		twin.rotation.z = PI * 0.5  # crossed: an X of wind
		twin.scale = Vector3.ONE * 0.9
		b.create_tween().tween_property(b, "rotation:z", TAU, BLADE_TIME * 1.2).as_relative()
	var tw := b.create_tween()
	tw.tween_property(b, "global_position", to + Vector3.UP * 0.2, BLADE_TIME * (1.2 if big else 1.0)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_blade_land.bind(parent, to, dir, c, el, big))
	tw.tween_callback(b.queue_free)


static func _blade_land(parent: Node, at: Vector3, dir: Vector3, c: Color, el: String, big := false) -> void:
	var k := 1.6 if big else 1.0
	Fx.ring(parent, at, Color(c, 0.85), 1.6 * k, 0.25)
	Fx.burst(parent, at + Vector3.UP * 0.2, c.lerp(Color.WHITE, 0.3), int(12 * k), 8.0 * k, 0.12, 0.35, Vector3.UP + dir * 0.5, 55.0, -6.0)
	ELEMENTS.spikes(parent, at, el, 0.7 * k, 4 if big else 2, 0.5)
	Fx.dust(parent, at, int(5 * k), 0.6 * k)
	if big:  # the X carves its mark in the floor
		var side := dir.cross(Vector3.UP).normalized()
		for s: float in [-1.0, 1.0]:
			Fx.dash_streak(parent, at - (dir + side * s) * 1.1, (dir + side * s).normalized(), 2.6, Color(c, 0.8), 0.45, 0.5)
		ELEMENTS.light_pop(parent, at, c, 4.0, 5.0, 0.25)
		Game.sfx("swing_heavy", -6.0, 0.1)


## Stormfall's fall: one beat of the comet trail behind him (called every
## COMET_STEP s while he drops) — a ghost of him plus sparks in the element.
static func comet(parent: Node, model: Node3D, c: Color, el: String) -> void:
	Fx.afterimage(parent, model, Color(c, 0.55), 0.2)
	var at := model.global_position + Vector3.UP * 1.0
	Fx.burst(parent, at, c.lerp(Color.WHITE, 0.25), 6, 4.0, 0.14, 0.3, Vector3.UP, 40.0, 2.0, 0.4)
	Fx.burst(parent, at, ELEMENTS.LOOK[el].glow, 3, 2.0, 0.1, 0.25, Vector3.UP, 60.0, 0.0, 0.3)


## Crescent wind blades whirling round him at his height (children of the
## model, so they ride up with him), flaring out and fading.
static func _blades(model: Node3D, c: Color) -> void:
	var ring := Node3D.new()
	model.add_child(ring)
	ring.position.y = 0.9
	var s := model.scale.x if model.scale.x > 0.01 else 1.0
	ring.scale = Vector3.ONE / s  # (sizes in metres whatever the model's scale)
	for i in BLADES:
		var ang := TAU * i / BLADES
		var b := ELEMENTS._mi(ELEMENTS.crescent(0.3), ELEMENTS.glow(c.lerp(Color.WHITE, 0.35), 1.6))
		b.position = Vector3(sin(ang), randf_range(-0.2, 0.3), cos(ang)) * Vector3(1.4, 1.0, 1.4)
		b.rotation = Vector3(0.0, ang + PI * 0.5, 0.35)
		b.scale = Vector3.ONE * 0.9
		ring.add_child(b)
	_no_ghost(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "rotation:y", TAU * 2.0, TIME)
	tw.tween_property(ring, "scale", ring.scale * 1.6, TIME).set_ease(Tween.EASE_OUT)
	ELEMENTS._fade_free(ring, TIME * 0.45, TIME * 0.55)


## Effects riding on the model stay out of his afterimages (Fx.afterimage).
static func _no_ghost(root: Node3D) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		mi.set_meta("no_ghost", true)
