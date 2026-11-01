extends Node3D
## The Ascendancy's always-on aura around the hero (player.ascend): a ground
## glyph under the feet plus element particles, swelling when Awakened
## (set_awakened). Tempest = a low wind swirl and green streaks spiralling up;
## Magma = a glowing ember glyph with sparks and embers rising; Tide = a frost
## ring with drifting frost motes and falling flakes.

const ELEMENTS := preload("res://scripts/elements.gd")
# Per path: ground colour/texture, particle colour, rise speed (negative = falls).
const LOOKS := {
	"wind": {"ground": "ring", "ground_color": Color(0.35, 0.9, 0.5, 0.55), "mote": Color(0.6, 1.0, 0.65),
		"rise": 2.2, "amount": 14, "size": 0.16},
	"earth": {"ground": "scorch", "ground_color": Color(1.0, 0.4, 0.08, 0.7), "mote": Color(1.0, 0.5, 0.12),
		"rise": 1.6, "amount": 16, "size": 0.12},
	"water": {"ground": "ring", "ground_color": Color(0.55, 0.85, 1.0, 0.6), "mote": Color(0.8, 0.95, 1.0),
		"rise": -0.6, "amount": 14, "size": 0.14},
}
const GROUND_RADIUS := 1.25

var path := ""
var _ground: MeshInstance3D
var _ground_mat: StandardMaterial3D
var _motes: CPUParticles3D
var _swirl: MeshInstance3D
var _boost := 0.0  # 0 at rest, 1 Awakened (tweened)
var _t := 0.0


func setup(p: String) -> void:
	path = p
	var look: Dictionary = LOOKS[p]
	# Ground glyph: a flat decal under the feet that slowly turns and breathes.
	_ground_mat = StandardMaterial3D.new()
	_ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ground_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ground_mat.albedo_texture = Fx.TEX[look.ground]
	_ground_mat.albedo_color = look.ground_color
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * GROUND_RADIUS * 2.0
	plane.material = _ground_mat
	_ground = MeshInstance3D.new()
	_ground.mesh = plane
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground.position.y = 0.05
	add_child(_ground)
	if p == "wind":
		# A low swirl round the ankles (the tornado's shader).
		_swirl = ELEMENTS._mi(ELEMENTS.funnel(1.0, 0.7, 0.7), ELEMENTS.swirl_mat(ELEMENTS.LOOK.wind.color, true))
		_swirl.position.y = 0.35
		_swirl.transparency = 0.45
		add_child(_swirl)
	_motes = CPUParticles3D.new()
	_motes.amount = look.amount
	_motes.lifetime = 1.1
	_motes.local_coords = false  # trail behind as the hero moves
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_motes.emission_ring_axis = Vector3.UP
	_motes.emission_ring_radius = 0.75
	_motes.emission_ring_inner_radius = 0.35
	_motes.emission_ring_height = 0.1
	_motes.direction = Vector3.UP if look.rise > 0.0 else Vector3.DOWN
	_motes.spread = 15.0
	_motes.gravity = Vector3.ZERO
	_motes.initial_velocity_min = absf(look.rise) * 0.6
	_motes.initial_velocity_max = absf(look.rise)
	if p == "wind":
		_motes.orbit_velocity_min = 0.5  # spiral up
		_motes.orbit_velocity_max = 0.9
		_motes.tangential_accel_min = 2.0
		_motes.tangential_accel_max = 3.0
	if p == "earth":
		_motes.damping_min = 0.5
		_motes.damping_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(look.mote, 0.0))
	fade.add_point(0.2, Color(look.mote, 0.9))
	fade.set_color(fade.get_point_count() - 1, Color(look.mote, 0.0))
	_motes.color_ramp = fade
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(1.0, 0.2))
	_motes.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * look.size * Fx.TEX_SCALE.dot
	quad.material = Fx.particle_mat("dot", true)  # small hot cores: additive is fine
	_motes.mesh = quad
	_motes.position.y = 0.15 if look.rise > 0.0 else 2.4  # flakes fall from above the head
	if look.rise < 0.0:
		_motes.emission_ring_radius = 0.9
		_motes.emission_ring_inner_radius = 0.2
		_motes.lifetime = 3.0
	add_child(_motes)


## Awakened: bigger glyph, denser and faster particles.
func set_awakened(on: bool) -> void:
	create_tween().tween_property(self, "_boost", 1.0 if on else 0.0, 0.3)
	if _motes != null:
		var look: Dictionary = LOOKS[path]
		_motes.amount = int(look.amount * (2.0 if on else 1.0))
		_motes.speed_scale = 1.5 if on else 1.0


func _process(delta: float) -> void:
	if _ground == null:
		return
	_t += delta
	var look: Dictionary = LOOKS[path]
	_ground.rotation.y += delta * (0.6 + _boost * 1.4) * (1.0 if path != "water" else -0.5)
	var breathe := 1.0 + sin(_t * 3.0) * 0.06
	_ground.scale = Vector3.ONE * breathe * (1.0 + _boost * 0.5)
	_ground_mat.albedo_color.a = look.ground_color.a * (0.75 + 0.25 * sin(_t * 2.2)) * (1.0 + _boost * 0.4)
	if _swirl != null:
		_swirl.rotation.y -= delta * (2.5 + _boost * 3.0)
		_swirl.scale = Vector3(1.0 + _boost * 0.4, 1.0 + _boost * 0.8, 1.0 + _boost * 0.4)
