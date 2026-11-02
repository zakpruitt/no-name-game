extends Node3D
## Ancestor avatar (Charged Slam's cast): a towering spectral copy of the
## shaman himself rises around the hero wielding the great two-handed axe,
## plays the overhead chop and brings it down ahead: a big blast with the
## element's nova, floor scorch and a camera slam (lands LAND * scale_to
## ahead: ~3.6 m at 3x). The hero model rendered
## through spirit_echo.ghost() materials, scaled SCALE times. Spawned by
## player._cast for casts of kind "avatar" (elements.CASTS).

const ELEMENTS := preload("res://scripts/elements.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const MODEL := preload("res://assets/kaykit/characters/Barbarian.glb")
const ANIM := "2H_Melee_Attack_Chop"
const START := 0.12  # fraction of ANIM it starts from (mid wind-up)
const IMPACT := 0.53  # fraction of ANIM where the axe lands
const LAND := Vector3(-0.6, 0.0, 1.4)  # model-space spot the axe head lands at
const MODEL_ANIM_LENGTH := 1.6333  # s, ANIM in Barbarian.glb
const SHOWN := ["Barbarian_Body", "Barbarian_Head", "Barbarian_ArmLeft", "Barbarian_ArmRight",
	"Barbarian_LegLeft", "Barbarian_LegRight", "2H_Axe"]
const GROW := 0.14  # s the avatar takes to rise to full size

var color := Color(0.3, 0.95, 0.85)
var fwd := Vector3.FORWARD
var el := "spirit"
var scale_to := 3.0  # avatar size vs the hero
var speed := 2.2  # ANIM playback speed (land_time() after spawn the axe lands)
var radius := 4.2  # m blast radius
var damage := 14.0
var launch := 8.0
var on_hit := Callable()
var impact_fx := true  # false: the caller has its own impact (Ancestor's Fall); 0 damage: visual only

var model: Node3D
var anim: AnimationPlayer
var _mats: Array[StandardMaterial3D] = []
var _rims: Array[ShaderMaterial] = []


func _ready() -> void:
	rotation.y = atan2(fwd.x, fwd.z)
	model = MODEL.instantiate()
	add_child(model)
	# Looms over the hero's shoulder, placed so the axe lands on his centre line.
	model.position = Vector3(-LAND.x * scale_to, 0.0, -0.6)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name not in SHOWN:
			mi.visible = false
			continue
		var g := SPIRIT_ECHO.ghost(mi.mesh, color)
		mi.material_override = g.material_override
		mi.material_overlay = g.material_overlay
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.free()
		_mats.append(mi.material_override)
		_rims.append(mi.material_overlay)
	anim = model.find_child("AnimationPlayer", true, false)
	anim.play(ANIM, 0.0, speed)
	anim.seek(anim.current_animation_length * START, true)
	var land := anim.current_animation_length * (IMPACT - START) / speed
	_grow(0.0)
	var tw := create_tween()
	tw.tween_method(_grow, 0.0, 1.0, GROW).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(maxf(land - GROW, 0.0))
	tw.tween_callback(_impact)
	tw.tween_interval(0.12)
	tw.tween_method(_fade, 1.0, 0.0, 0.35)
	tw.tween_callback(queue_free)


func _grow(t: float) -> void:
	model.scale = Vector3.ONE * scale_to * lerpf(0.5, 1.0, t)
	_fade(minf(t * 1.5, 1.0))


func _fade(a: float) -> void:
	for i in _mats.size():
		_mats[i].albedo_color.a = 0.5 * a
		_rims[i].set_shader_parameter("intensity", 2.6 * a)


## Playback speed that lands the axe `seconds` after spawning.
static func speed_for(seconds: float) -> float:
	return MODEL_ANIM_LENGTH * (IMPACT - START) / maxf(seconds, 0.05)


## Where the axe head lands (world, on the floor).
func land_point() -> Vector3:
	var at := global_transform * (model.position + LAND * scale_to)
	return Vector3(at.x, 0.0, at.z)


func _impact() -> void:
	var parent := get_parent()
	var at := land_point()
	if impact_fx:
		slam_fx(parent, at, el, radius)
		ELEMENTS.nova(parent, at, el, radius, 10)
	if damage > 0.0:
		ELEMENTS.hit_area(get_tree(), at, radius, damage, launch, true, "cast", on_hit)
	if Game.camera_rig:
		Game.camera_rig.punch(0.82, 0.3)


## The floor-cracking part of a spectral slam (spirit_cleave, the avatar):
## scorch, double shockwave, flare, debris, dust, element eruption, light,
## hitstop and shake (`heavy` false: just the floor marks and debris, for
## volleys of many at once).
static func slam_fx(parent: Node, at: Vector3, el: String, radius: float, kick := Vector3.ZERO, heavy := true) -> void:
	var c: Color = ELEMENTS.LOOK[el].color
	var g: Color = ELEMENTS.LOOK[el].glow
	Fx.scorch(parent, at, c, radius * 0.8, 1.6)
	Fx.ring(parent, at, Color(c, 0.95), radius * 1.6, 0.4)
	Fx.ring(parent, at, Color(g, 0.9), radius * 0.9, 0.25)
	Fx.flare(parent, at + Vector3.UP * 0.6, Color(c, 0.95), radius * 1.6, 0.2, "flare")
	Fx.flare(parent, at + Vector3.UP * 0.6, g, radius * 0.7, 0.1, "star8", true)
	Fx.shards(parent, at, c.darkened(0.3), 16 if heavy else 8, Vector3.UP, 11.0, 0.22, 0.8)
	if not heavy:
		Fx.dust(parent, at, 6, 0.7)
		return
	Fx.dust(parent, at, 12, 0.8)
	Fx.burst(parent, at + Vector3.UP * 0.3, c, 26, 12.0, 0.16, 0.45, Vector3.UP, 80.0, -14.0)
	ELEMENTS.spikes(parent, at, el, 1.3, 4)
	ELEMENTS.light_pop(parent, at, c, 7.0, 9.0, 0.4)
	Game.sfx("ult_impact", -5.0)
	Game.hitstop(0.07, 0.05)
	Game.shake(0.55)
	if Game.camera_rig and kick != Vector3.ZERO:
		Game.camera_rig.kick(kick, 0.35)
