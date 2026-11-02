extends Node3D
## Spirit rift (Ground Breaker's cast): a wave of colossal spectral axes bursts
## blade-up out of the floor one after another along the thrust, each bigger
## than the last and leaning into the charge, with the element's spikes at
## each one: the ground breaking in a line. Blades alternate sides and face the
## camera behind the hero. Each foe is hit once by the first axe it stands by.
## Spawned by player._cast for casts of kind "rift" (elements.CASTS).

const ELEMENTS := preload("res://scripts/elements.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const LEAN := 22.0  # degrees each axe leans along the charge
const RISE := 0.06
const HOLD := 0.12
const SINK := 0.2

var axe_mesh: Mesh
var color := Color(0.3, 0.95, 0.85)
var fwd := Vector3.FORWARD
var length := 6.5  # m the wave runs
var steps := 6
var step_time := 0.045  # s between axes
var size_from := 1.8  # first axe's scale
var size_to := 3.4  # last axe's scale
var radius := 1.3  # m hit radius round each axe
var damage := 5.0
var launch := 5.0
var on_hit := Callable()
var el := "spirit"

var _hit: Array = []


func _ready() -> void:
	rotation.y = atan2(fwd.x, fwd.z)
	var tw := create_tween()
	for i in steps:
		tw.tween_callback(_burst.bind(i))
		tw.tween_interval(step_time)
	tw.tween_interval(RISE + HOLD + SINK + 0.1)
	tw.tween_callback(queue_free)


func _burst(i: int) -> void:
	var f := float(i) / maxf(steps - 1, 1)
	var size := lerpf(size_from, size_to, f)
	var at := Vector3(0.0, 0.0, 1.0 + f * (length - 1.0))
	var slot := Node3D.new()
	slot.position = at
	# Lean into the charge (+Z); blade alternates left / right, face to the camera.
	slot.basis = Basis(Vector3.RIGHT, deg_to_rad(LEAN)) * Basis(Vector3.UP, PI if i % 2 == 1 else 0.0)
	add_child(slot)
	var axe := SPIRIT_ECHO.ghost(axe_mesh, color, el)
	axe.scale = Vector3.ONE * size
	axe.position.y = -size
	slot.add_child(axe)
	var mat: StandardMaterial3D = axe.material_override
	var rim: ShaderMaterial = axe.material_overlay
	var tw := axe.create_tween()
	tw.tween_property(axe, "position:y", 0.0, RISE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.6, RISE)
	tw.tween_interval(HOLD)
	tw.tween_property(axe, "position:y", -size * 0.6, SINK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, SINK)
	tw.parallel().tween_property(rim, "shader_parameter/intensity", 0.0, SINK)
	var parent := get_parent()
	var world := global_transform * at
	world.y = 0.0
	var c: Color = ELEMENTS.LOOK[el].color
	if el in ["earth", "water"]:  # (spirit / wind "spikes" are light columns: they'd hide the axes)
		ELEMENTS.spikes(parent, world, el, lerpf(0.8, 1.3, f), 3)
	else:
		Fx.burst(parent, world + Vector3.UP * 0.4, c, 10, 8.0, 0.14, 0.4, Vector3.UP, 50.0, -10.0)
	Fx.scorch(parent, world, c, lerpf(0.9, 1.6, f), 1.2)
	Fx.shards(parent, world, c.darkened(0.3), 8, fwd + Vector3.UP, 9.0, 0.2, 0.7)
	Fx.dust(parent, world, 6, 0.6)
	Game.shake(lerpf(0.15, 0.4, f))
	if i == steps - 1:
		Fx.ring(parent, world, Color(c, 0.95), 3.2, 0.35)
		Fx.flare(parent, world + Vector3.UP * 0.8, Color(c, 0.95), 4.0, 0.18, "flare")
		ELEMENTS.light_pop(parent, world, c, 6.0, 8.0, 0.35)
		Game.sfx("ult_impact", -8.0)
		if Game.camera_rig:
			Game.camera_rig.kick(fwd, 0.3)
	if damage <= 0.0:  # visual only (Spirit Stampede's wake deals its own)
		return
	for e in Ascendancy.enemies_near(get_tree(), world, radius * lerpf(1.0, 1.4, f)):
		if e in _hit:
			continue
		_hit.append(e)
		e.take_hit(damage, fwd * 5.0, launch, true)
		Game.register_hit("cast")
		Fx.element_hit(parent, e.global_position, el, fwd, true)
		if on_hit.is_valid():
			on_hit.call(e)
