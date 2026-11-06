extends SkeletonModifier3D
## Turn lean for the fast foes (enemy.gd TURN_LEAN: the rogue and the minion), heretic_rig.gd's for the
## hero: while it chases it banks into a change of direction. The change is its velocity less a lagging
## copy of it (LEAN_LAG s), so a held run leans nothing and a reversal leans hardest; a spring carries
## the tilt (one small overshoot coming out of a turn). Tilts the root bone, about the feet.

const LEAN_ALONG := 0.45  # of the lean along its facing (the start / stop clips already pitch it)
const LEAN_MAX := 14.0  # degrees
const LEAN_LAG := 0.12  # s
const LEAN_STIFF := 600.0  # spring: about 3.9 Hz
const LEAN_DAMP := 34.0  # a little under critical (49)

var foe: CharacterBody3D
var deg_per_mps := 3.0
var lean := Vector2.ZERO  # degrees: x towards its right, y towards its front
var _lean_v := Vector2.ZERO
var _vel_lag := Vector3.ZERO
var _root := -1


func _ready() -> void:
	var skel := get_skeleton()
	if skel != null:
		_root = skel.find_bone("root")


func _process_modification_with_delta(delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or _root < 0 or delta <= 0.0 or not is_instance_valid(foe):
		return
	var vel := Vector3(foe.velocity.x, 0.0, foe.velocity.z)
	_vel_lag = _vel_lag.lerp(vel, 1.0 - exp(-delta / LEAN_LAG))
	var want := Vector2.ZERO
	if foe.state == foe.State.CHASE:
		var fwd := skel.global_transform.basis.z
		fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
		var right := fwd.cross(Vector3.UP)  # it faces +Z; its right is -X in model space
		var d := vel - _vel_lag
		want = Vector2(d.dot(right) * deg_per_mps, d.dot(fwd) * deg_per_mps * LEAN_ALONG).limit_length(LEAN_MAX)
	_lean_v += ((want - lean) * LEAN_STIFF - _lean_v * LEAN_DAMP) * delta
	lean += _lean_v * delta
	if lean.length() < 0.01:
		return
	var inv := skel.global_transform.basis.inverse()
	var fwd_s := (inv * skel.global_transform.basis.z).normalized()
	var up_s := (inv * Vector3.UP).normalized()
	var right_s := fwd_s.cross(up_s)
	var dir := (right_s * lean.x + fwd_s * lean.y).normalized()
	var axis := up_s.cross(dir)
	if axis.length_squared() < 1e-8:  # tipped over (a lie / launch spin puts its facing along up): nothing to lean on
		return
	var q := Quaternion(axis.normalized(), deg_to_rad(lean.length()))
	skel.set_bone_pose_rotation(_root, q * skel.get_bone_pose_rotation(_root))
