extends SkeletonModifier3D
## The Meshy heretic hero (--heretic). Keeps his tentacle tips alive between clips, coils them
## into the limb while a weapon is out (ComicLook.HERO_FORMS through void_arm.form), and hangs
## the skirt chains on spring bones. Clips never key any of these bones.

const TIPS := {"up": 4, "out": 5, "mid": 3, "low": 4}
const MAIN_TIP := "tent.main.%02d"
const MAIN_COUNT := 6
const SWAY_DEG := 7.0  # per bone: small, because it adds up along a chain
const SWAY_SPEED := 1.7  # rad/s
const SWAY_PHASE := 0.8  # rad between bones
const ATTACK_SWAY := 2.2  # sway runs faster while a weapon is forming
const COLLAPSED := 0.04  # scale at a tip's base with a weapon out
const COIL_DEG := 35.0  # per bone as it pulls in
const FORM_TIME := 0.09  # s to pull in: quick, the weapon pops at the same moment
const OPEN_TIME := 0.22  # s to unfurl again
## Off an attack the limb lets go of the clip's arm pose and settles into the model's own spread:
## his clips were keyed for a man carrying an axe, which crushes the tentacles into a clump.
const ARM_BONES := ["upperarm.r", "lowerarm.r", "wrist.r", "hand.r"]
const ARM_FREE_TIME := 0.18  # s

const SKIRT_N := 12
const SKIRT_STIFFNESS := 2.2
const SKIRT_DRAG := 0.55
const SKIRT_GRAVITY := 0.9
const SKIRT_RADIUS := 0.035
## Bone -> capsule radius, length: so the skirt rides over his thighs.
const LEG_CAPSULES := {"upperleg.l": [0.11, 0.42], "upperleg.r": [0.11, 0.42]}

var void_arm: Node
var _chains := []  # [{bones: PackedInt32Array, phase: float}]
var _time := 0.0
var _out := 0.0  # 0 = tentacle free, 1 = weapon form
var _arm := PackedInt32Array()
var _free := 1.0  # 1 = limb in its own spread, 0 = following the clip


func setup(arm: Node, skel: Skeleton3D) -> void:
	void_arm = arm
	var seed_phase := 0.0
	for tip: String in TIPS:
		var bones := PackedInt32Array()
		for i in TIPS[tip]:
			var b := skel.find_bone("tent.%s.%02d" % [tip, i + 1])
			if b >= 0:
				bones.append(b)
		_chains.append({"bones": bones, "phase": seed_phase, "collapse": true})
		seed_phase += 1.9
	var main := PackedInt32Array()
	for i in MAIN_COUNT:
		var b := skel.find_bone(MAIN_TIP % (i + 1))
		if b >= 0:
			main.append(b)
	_chains.append({"bones": main, "phase": seed_phase, "collapse": true})
	for b: String in ARM_BONES:
		_arm.append(skel.find_bone(b))
	skel.add_child(self)
	_add_springs(skel)


func _add_springs(skel: Skeleton3D) -> void:
	var sim := SpringBoneSimulator3D.new()
	sim.name = "SkirtSprings"
	skel.add_child(sim)
	sim.setting_count = SKIRT_N
	for i in SKIRT_N:
		sim.set_root_bone_name(i, "skirt.%02d.1" % i)
		sim.set_end_bone_name(i, "skirt.%02d.3" % i)
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT)
		sim.set_end_bone_length(i, 0.12)
		sim.set_stiffness(i, SKIRT_STIFFNESS)
		sim.set_drag(i, SKIRT_DRAG)
		sim.set_gravity(i, SKIRT_GRAVITY)
		sim.set_radius(i, SKIRT_RADIUS)
	for bone: String in LEG_CAPSULES:
		var cap := SpringBoneCollisionCapsule3D.new()
		cap.bone_name = bone
		cap.radius = LEG_CAPSULES[bone][0]
		cap.height = LEG_CAPSULES[bone][1]
		cap.position_offset = Vector3(0.0, LEG_CAPSULES[bone][1] * 0.5, 0.0)
		sim.add_child(cap)


func _process_modification_with_delta(delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	var want := 0.0 if void_arm == null or void_arm.form == "hand" else 1.0
	_out = move_toward(_out, want, delta / (FORM_TIME if want > _out else OPEN_TIME))
	_time += delta * lerpf(1.0, ATTACK_SWAY, _out)
	var striking: bool = void_arm != null and void_arm.hero.state in [void_arm.hero.State.ATTACK, void_arm.hero.State.SWING]
	_free = move_toward(_free, 0.0 if striking or want > 0.0 else 1.0, delta / ARM_FREE_TIME)
	if _free > 0.0:
		for b in _arm:
			var rest_q := skel.get_bone_rest(b).basis.get_rotation_quaternion()
			skel.set_bone_pose_rotation(b, skel.get_bone_pose_rotation(b).slerp(rest_q, _free))
	for c: Dictionary in _chains:
		var bones: PackedInt32Array = c.bones
		for j in bones.size():
			var b := bones[j]
			var wave := sin(_time * SWAY_SPEED + c.phase + j * SWAY_PHASE)
			var angle := deg_to_rad(SWAY_DEG * wave + COIL_DEG * _out)
			skel.set_bone_pose_rotation(b, skel.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, angle))
		if bones.size() > 0:
			skel.set_bone_pose_scale(bones[0], Vector3.ONE * lerpf(1.0, COLLAPSED, _out))
