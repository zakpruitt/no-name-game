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
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "rotation:y", TAU * 2.0, TIME)
	tw.tween_property(ring, "scale", ring.scale * 1.6, TIME).set_ease(Tween.EASE_OUT)
	ELEMENTS._fade_free(ring, TIME * 0.45, TIME * 0.55)
