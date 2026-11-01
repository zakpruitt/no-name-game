extends Node3D
## Spirit tomahawk (Dash Stab's and Flurry's cast): a giant spectral axe flung
## out spinning flat like a sawblade, flat side to the camera, piercing
## everything on the way to `reach`, then boomeranging back to the hero and
## cutting again. Each foe is hit once per leg. Spawned by player._cast for
## casts of kind "tomahawk" (elements.CASTS), one per `fan`.

const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const SPIN := 22.0  # rad/s
const HEIGHT := 0.9
const CENTER := Vector3(-0.15, 0.4, 0.0)  # axe-local balance point it spins round

var axe_mesh: Mesh
var color := Color(0.3, 0.95, 0.85)
var dir := Vector3.FORWARD
var hero: Node3D  # where it flies back to (null: just fades at the end)
var size := 2.2
var reach := 8.0
var out_time := 0.3
var back_time := 0.32
var damage := 6.0
var back_damage := 4.0
var on_hit := Callable()
var shared = null  # Dictionary shared by a volley (the Cyclone breaker's ring): each foe hit once per leg by all of them
var el := "spirit"

var _axe: MeshInstance3D
var _spinner: Node3D
var _from := Vector3.ZERO
var _hit: Array = []
var _back := false
var _puff := 0.0


func _ready() -> void:
	_from = global_position
	_spinner = Node3D.new()
	_spinner.position.y = HEIGHT
	add_child(_spinner)
	_axe = SPIRIT_ECHO.ghost(axe_mesh, color, el)
	# Laid flat (handle along +Z, flat side up), spun round its balance point.
	var b := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)).scaled(Vector3.ONE * size)
	_axe.transform = Transform3D(b, -(b * CENTER))
	_spinner.add_child(_axe)
	_axe.material_override.albedo_color.a = 0.6
	var tw := create_tween()
	tw.tween_method(_fly_out, 0.0, 1.0, out_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_turn)
	tw.tween_method(_fly_back, 0.0, 1.0, back_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_axe.material_override, "albedo_color:a", 0.0, 0.08)
	tw.parallel().tween_property(_axe.material_overlay, "shader_parameter/intensity", 0.0, 0.08)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_spinner.rotation.y += SPIN * delta * (-1.0 if _back else 1.0)
	_puff -= delta
	if _puff <= 0.0:
		_puff = 0.05
		Fx.burst(get_parent(), global_position + Vector3.UP * HEIGHT, color, 3, 2.0, 0.14, 0.3, Vector3.UP, 180.0, 0.0, size * 0.5, "dot", true)
	_cut()


func _fly_out(t: float) -> void:
	global_position = _from + dir * reach * t


func _turn() -> void:
	_back = true
	_hit.clear()
	_from = global_position
	Fx.flare(get_parent(), global_position + Vector3.UP * HEIGHT, Color(color, 0.9), size * 1.4, 0.14, "star8", true)


func _fly_back(t: float) -> void:
	var to := _from
	if is_instance_valid(hero):
		to = Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	global_position = _from.lerp(to, t)


func _cut() -> void:
	var at := Vector3(global_position.x, 0.0, global_position.z)
	for e in Ascendancy.enemies_near(get_tree(), at, size * 0.55):
		if e in _hit:
			continue
		_hit.append(e)
		if shared != null:
			var key := "%d:%d" % [e.get_instance_id(), int(_back)]
			if shared.has(key):
				continue
			shared[key] = true
		var push: Vector3 = e.global_position - at
		push.y = 0.0
		e.take_hit(back_damage if _back else damage, push.normalized() * 4.0, 0.0, false)
		Game.register_hit("cast")
		Fx.element_hit(get_parent(), e.global_position, el, push.normalized())
		if on_hit.is_valid():
			on_hit.call(e)
