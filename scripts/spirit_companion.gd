extends Node3D
## One spirit in the room (docs/features/spirits.md): it hovers at its spot until he walks up and presses E
## (`interact`), then floats along beside him; claiming another sends it home. What holding it changes in his
## kit is scripts/spirits.gd. main._start_training places the three with `place()` when the kit is gated.

const MODEL_PATH := "res://assets/comic/spirits/%s.glb"
const NAMES: Dictionary = preload("res://scripts/hero_moves.gd").ELEMENT_WORDS
const ELEMENTS := preload("res://scripts/elements.gd")
## Where the three wait, from the hero's start: behind him, towards the camera, clear of the dummies.
const SPOTS := {"wind": Vector3(-3.2, 0.0, 3.0), "water": Vector3(0.0, 0.0, 4.2), "earth": Vector3(3.2, 0.0, 3.0)}
const SIZE := 0.8  # m tall, whatever the model came in at
const HOVER := 1.3  # m off the floor at its spot
const RIDE := Vector3(1.1, 2.0, -0.7)  # m from him while held: to his right, over the shoulder, a little behind
const REACH := 2.2  # m: how near he must stand to claim it
const BOB := 0.12  # m up and down
const BOB_HZ := 0.6
const FOLLOW := 6.0  # 1/s: how fast it closes on its place beside him
const SPIN := 0.5  # rad/s: it turns slowly while it waits

var element := ""
var home := Vector3.ZERO
var hero: Node3D
var _prompt: Label3D
var _t := 0.0


## The three spirits, at SPOTS from the hero.
static func place(room: Node, player: Node3D) -> void:
	var script: GDScript = load("res://scripts/spirit_companion.gd")
	for el: String in Spirits.ELEMENTS:
		var s: Node3D = script.new()
		s.element = el
		s.hero = player
		s.home = player.global_position + SPOTS[el] + Vector3.UP * HOVER
		room.add_child(s)
		s.global_position = s.home


func _ready() -> void:
	_t = randf() * 10.0  # so the three don't bob together
	var path := MODEL_PATH % NAMES[element]
	if ResourceLoader.exists(path):
		var model: Node3D = (load(path) as PackedScene).instantiate()
		add_child(model)
		_fit(model)
		ComicLook.apply(model)
		Fx.outline_own(model)
	_prompt = Label3D.new()
	_prompt.text = "[E]  %s spirit" % str(NAMES[element]).to_upper()
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.fixed_size = true
	_prompt.pixel_size = 0.0011
	_prompt.font_size = 40
	_prompt.outline_size = 12
	_prompt.modulate = ELEMENTS.LOOK[element].color
	_prompt.position = Vector3(0.0, SIZE * 0.5 + 0.35, 0.0)
	_prompt.visible = false
	add_child(_prompt)


## Scale the model to SIZE tall and centre it on this node.
func _fit(model: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.y <= 0.0:
		return
	var k := SIZE / box.size.y
	var centre := global_transform.affine_inverse() * box.get_center()
	model.scale *= k
	model.position -= centre * k


func _process(delta: float) -> void:
	if not is_instance_valid(hero):
		return
	_t += delta
	var bob := Vector3.UP * sin(_t * TAU * BOB_HZ) * BOB
	var mine := Spirits.held == element
	var near := not mine and Vector2(hero.global_position.x - home.x, hero.global_position.z - home.z).length() < REACH \
		and global_position.distance_to(home) < 1.0
	_prompt.visible = near
	if near and Input.is_action_just_pressed("interact"):
		Spirits.claim(element)
		Game.sfx(ELEMENTS.LOOK[element].sfx, -4.0, 0.1)
		return
	var k := 1.0 - exp(-FOLLOW * delta)
	if mine:
		var f: Vector3 = hero.facing_dir()
		var right := f.cross(Vector3.UP).normalized()
		var want := hero.global_position + right * RIDE.x + Vector3.UP * RIDE.y + f * RIDE.z
		global_position = global_position.lerp(want + bob, k)
		rotation.y = lerp_angle(rotation.y, atan2(f.x, f.z), k)
	else:
		global_position = global_position.lerp(home + bob, k)
		rotation.y += SPIN * delta
