extends RefCounted
## The barbaric side of the combo breakers: the war cry as the window opens and the crater a landing smashes
## into the floor. Visual only; the damage lives in void_element.gd BREAKERS.
##   war_cry   the drawn roar (designed_breaker.war_cry) and one inked hoop under him
##   crater    the inked dent (Fx.scorch's comic_crack), the element venting where its cracks end, rubble and dust

const ELEMENTS := preload("res://scripts/elements.gd")
const DESIGNED_BREAKER := preload("res://scripts/designed_breaker.gd")
const CRACKS := 9  # crack lines per crater (at full radius): the vents sit where they end
const VENT_DELAY := 0.1  # s after the impact the cracks vent (they've split out by then)
const VENT_STAR := 0.34  # m: a vent's inked star
const PAL := preload("res://scripts/fx_palette.gd")
const COMIC_POP := preload("res://scripts/comic_pop.gd")
const SCORCH_COMIC := 1.15  # of the radius: with no box cracks the inked mark carries the crater, out past the pile


const WAR_CRY_RING := 3.0  # m
const WAR_CRY_RING_W := 0.08  # m of colour band (Fx.ring's is 0.2)


## The roar at `pos` (his chest): three fans of drawn strokes in `el` (designed_breaker.war_cry) and a thin inked
## hoop in `c` on the floor under him.
static func war_cry(parent: Node, pos: Vector3, c: Color, el := "spirit", _bubble := true) -> void:
	DESIGNED_BREAKER.war_cry(parent, pos, el)
	Fx.COMIC_POP.spawn(parent, Vector3(pos.x, 0.0, pos.z), {"ring": WAR_CRY_RING, "ring_color": c, "ring_w": WAR_CRY_RING_W, "steps": 4})


## The floor breaks under an impact at `pos`: the inked dent out to `radius`, and (`rim`) the element venting
## where cracks of that reach would end. `big` (a perfect) throws more rubble and vents at every crack.
static func crater(parent: Node, pos: Vector3, el: String, radius: float, rim := true, big := false) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	var c: Color = ELEMENTS.LOOK[el].color
	var n := maxi(int(round(CRACKS * clampf(radius / 3.4, 0.5, 1.3))), 4)
	var reach := radius * (1.15 if big else 0.95)
	var a0 := randf() * TAU
	for i in n:
		var ang := a0 + TAU * (i + randf_range(-0.25, 0.25)) / n
		var tip := _crack_tip(ang, reach * randf_range(0.7, 1.0))
		if rim and (big or i % 2 == 0):  # the element bursts out where each crack ends
			var vt := root.create_tween()
			vt.tween_interval(VENT_DELAY + randf() * 0.06)
			vt.tween_callback(_vent.bind(parent, root.global_position + tip, el, big))
	var t := root.create_tween()
	t.tween_interval(1.6)
	t.tween_callback(root.queue_free)
	var rubble: Color = ELEMENTS.LOOK.earth.rock.lightened(0.25)
	Fx.shards(parent, root.global_position + Vector3.UP * 0.3, rubble, 26 if big else 16, Vector3.UP, 13.0 if big else 10.0, 0.3, 0.9)
	Fx.shards(parent, root.global_position + Vector3.UP * 0.2, c, 10, Vector3.UP, 9.0, 0.16, 0.6)
	Fx.dust(parent, root.global_position, 18 if big else 12, 1.2)
	Fx.scorch(parent, root.global_position, c, radius * SCORCH_COMIC, 1.6)


## Where a crack of `length` on `ang` would end (no cracks are drawn: the dent carries the crater).
static func _crack_tip(ang: float, length: float) -> Vector3:
	return Vector3(sin(ang), 0.0, cos(ang)) * length * 0.92


## The element venting from a crack's end at `at`: a small inked star in its palette.
static func _vent(parent: Node, at: Vector3, el: String, big: bool) -> void:
	if not is_instance_valid(parent):
		return
	var up := at + Vector3.UP * 0.15
	var k := 1.3 if big else 1.0
	var pal: Dictionary = PAL.of(el)
	COMIC_POP.spawn(parent, up + Vector3.UP * 0.2, {"star": VENT_STAR * k, "steps": 3, "star_color": pal.body, "star_core": pal.light})
