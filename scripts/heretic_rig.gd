extends SkeletonModifier3D
## The Meshy heretic hero. Keeps his tentacle tips alive between clips, turns the limb
## into each weapon (ComicLook.HERO_FORMS through void_arm.form), and hangs the skirt chains on
## spring bones. Clips never key any of these bones.
##
## A change: the old weapon pulls back into the limb, the new one stretches out along its haft
## and overshoots, the loose tips coil away, and the main tentacle straightens to grip the haft.

## The loose tips' chains, tent.<tip>.01.. as long as the skeleton has them (heretic: 4/5/3/4 and
## no back; the chibi: six claws, back included). Missing chains are skipped.
const TIPS := ["up", "out", "mid", "low", "back"]
const MAIN_TIP := "tent.main.%02d"
const MAX_CHAIN := 12
const SWAY_DEG := 7.0  # per bone: small, because it adds up along a chain
const SWAY_SPEED := 1.7  # rad/s
const SWAY_PHASE := 0.8  # rad between bones
const ATTACK_SWAY := 2.2  # sway runs faster while a weapon is out
const COLLAPSED := 0.04  # scale at a loose tip's base with a weapon out
const COIL_DEG := 35.0  # per bone as it pulls in
const FORM_TIME := 0.09  # s for the tips to pull in
const OPEN_TIME := 0.22  # s to unfurl again
## Off an attack the limb lets go of the clip's arm pose and settles into the model's own spread:
## his clips were keyed for a man carrying an axe, which crushes the tentacles into a clump.
const ARM_BONES := ["upperarm.r", "lowerarm.r", "wrist.r", "hand.r"]
const ARM_FREE_TIME := 0.18  # s

## Form -> its bone, running from the hand along the haft (heretic_bake.py).
const FORM_BONES := {"axe": "weapon.axe", "spear": "weapon.spear", "hammer": "weapon.hammer"}
const GROW_TIME := 0.1  # s for a weapon to stretch out: strikes land from about 0.25 s
const RETRACT_TIME := 0.05  # s for the old one to pull back
const RETRACT_FIRST := 0.35  # the new weapon waits until the old one is below this
const OVERSHOOT := 1.2  # of its length, at PEAK_AT of the growth
const PEAK_AT := 0.7
const GONE := 0.001  # a bone can't scale to nothing
const GRIP := 0.85  # how far the main tentacle straightens along the haft

const FORM_FX := preload("res://scripts/heretic_form_fx.gd")

## The claw on his tentacle moves, visual only: move id -> [before the hit, after it] as
## -1 (splayed wide) .. 1 (clenched). GR reaches out splayed and snaps shut on the hit; VS
## holds its catch clenched and shaking, then flings the claws open as it slams.
const GRIP_MOVES := {"GR": [-1.0, 1.0], "VS": [1.0, -1.0]}
const GRIP_CLENCH_DEG := 32.0  # per bone, curling in
const GRIP_SPLAY_DEG := 22.0  # per bone, bending back
const GRIP_SPLAY_GROW := 1.18  # the claws' base swells as they splay: the reach reads from above
const GRIP_SNAP := 0.05  # s to swap at the hit: a snap, not a blend
const GRIP_SHAKE_DEG := 6.0  # the strain while clenched
const GRIP_SHAKE_HZ := 19.0
const GRIP_FADE := 0.15  # s back to the free sway after the move
## A model whose clips key the claws (the chibi: tools/meshy_rig/chibi_keys.py) gets its grip, splay
## and curl from them: the sway adds on top of the keyed pose, GRIP_MOVES is skipped, and the clips
## below, keyed for this rig's own arm, are followed as they are instead of easing to the rest spread.
const KEYED_ARM := ["Idle", "Idle_Ready", "Run_F", "Run_B", "Strafe_L", "Strafe_R", "Run_Start", "Run_Stop", "Ab_L1", "Ab_AL1", "Ab_L2", "Ab_L3",
	"Ab_DL", "Ab_GR", "Ab_VS", "Ab_LH", "Ab_H", "Ab_LLH", "Ab_AF", "Hit_A", "Dodge_Forward", "Jump_Start", "Jump_Idle"]
const CLAW_TRACK := ":tent.up.01"
## With keyed claws the loose ones stay out round a weapon's haft, clenched by the clip, instead of
## pulling right in: the claw gripping the axe is the chibi's silhouette.
const KEYED_COLLAPSED := 0.8

## Turn lean: while he runs he banks into a change of direction (and rocks a little on a start or a
## stop) by tilting the root bone, which sits on the floor, towards the change in his velocity. The
## change is his velocity less a lagging copy of it (LEAN_LAG s), so a held run leans nothing and a
## reversal leans hardest; a spring carries the tilt, so he overshoots a touch coming out of a turn.
const LEAN_DEG := 1.6  # degrees per m/s of velocity change, across his facing
const LEAN_ALONG := 0.45  # of that along his facing (the start / stop clips already pitch him)
const LEAN_MAX := 15.0  # degrees
const LEAN_LAG := 0.12  # s
const LEAN_STIFF := 320.0  # spring: about 2.8 Hz
const LEAN_DAMP := 24.0  # a little under critical (35.8): one small overshoot

## Glowing eyes under the hood, per Game.hero_model, in skeleton rest space (Godot axes, metres):
## measured from the texture's cyan eyes on chibi_rig_v1.blend, x1.088 for the 1.85 m bake, then
## pushed forward to the hood's brim. Flat camera-facing shapes drawn over the hood like the
## burst (no depth test), shown only while his face is towards the camera: from the game camera
## (54 degrees down) the hood hides the face itself, so they read as eyes glowing in its shadow.
const EYES := {"chibi": [Vector3(-0.034, 1.25, 0.13), Vector3(0.155, 1.25, 0.13)]}
const EYE_SIZE := Vector2(0.095, 0.04)  # m: an almond, wide and narrow
const EYE_TILT := 16.0  # degrees: inner corners down, a scowl
const EYE_INK := 0.018  # m of ink round it
const EYE_LOW := Color(0.2, 0.95, 0.95)
const EYE_HIGH := Color(0.88, 1.0, 1.0)
const EYE_FACING := 0.15  # cos of the angle off the camera past which they hide
## Each eye also hides while the claw or a weapon is between it and the camera (the claw lifted in
## front of the hood: VS, Updraft Lash, the leap), so it reads behind them and over the hood.
const EYE_CLAW_R := 0.07  # m: the claw's half-thickness round its bones, times hand.r's scale
const EYE_CLAW_GAP := 0.04  # m: a point this close in front of the eye is the hood's brim, not the claw

const SKIRT_N := 12
const SKIRT_STIFFNESS := 2.2
const SKIRT_DRAG := 0.55
const SKIRT_GRAVITY := 0.9
const SKIRT_RADIUS := 0.035
## Bone -> capsule radius, length: so the skirt rides over his thighs.
const LEG_CAPSULES := {"upperleg.l": [0.11, 0.42], "upperleg.r": [0.11, 0.42]}
const RIM_SHADER := preload("res://shaders/hero_rim.gdshader")
const RIM_COLOR := Color(1.0, 0.96, 0.84)  # paper, past his ink (_add_rim)
const RIM_PX := 2.4  # px of rim past the ink line
const RIM_PUSH := 0.06  # m pushed back past the ink hull's, so the ink hides the rim's inner part
const RIM_PRIORITY := 100  # after every effect in the transparent pass

var void_arm: Node
var _chains := []  # [{bones: PackedInt32Array, phase: float}]
var _main := PackedInt32Array()
var _time := 0.0
var _out := 0.0  # 0 = tentacle free, 1 = weapon form
var _arm := PackedInt32Array()
var _free := 1.0  # 1 = limb in its own spread, 0 = following the clip
var _form_bone := {}  # form -> bone index
var _form_axis := {}  # form -> which local axis runs along the haft
var _form_dir := {}  # form -> haft direction, skeleton rest space
var _form_len := {}  # form -> m
var _grip_q := {}  # form -> Array[Quaternion], each main bone's pose gripping that haft
var _w := {}  # form -> 0..1 grown
var _last_form := ""
var _grip := 0.0  # -1 splayed .. 1 clenched (GRIP_MOVES)
var _grip_on := 0.0  # 1 while a grip move plays, fading out after
var eyes: Node3D  # the glow, when this model has one (EYES)
var keyed := false  # the clips key the claws (KEYED_ARM, CLAW_TRACK)
var _cover := PackedInt32Array()  # bones that can pass in front of the eyes (_cover_points)
var _root := -1  # the root bone (turn lean)
var _vel_lag := Vector3.ZERO
var lean := Vector2.ZERO  # degrees: x towards his right, y towards his front
var _lean_v := Vector2.ZERO


func setup(arm: Node, skel: Skeleton3D) -> void:
	void_arm = arm
	var seed_phase := 0.0
	for tip: String in TIPS:
		var bones := PackedInt32Array()
		for i in MAX_CHAIN:
			var b := skel.find_bone("tent.%s.%02d" % [tip, i + 1])
			if b < 0:
				break
			bones.append(b)
		if not bones.is_empty():
			_chains.append({"bones": bones, "phase": seed_phase})
		seed_phase += 1.9
	for i in MAX_CHAIN:
		var b := skel.find_bone(MAIN_TIP % (i + 1))
		if b < 0:
			break
		_main.append(b)
	for b: String in ARM_BONES:
		_arm.append(skel.find_bone(b))
	for f: String in FORM_BONES:
		_read_form(f, skel)
	_last_form = arm.form
	keyed = _clips_key_claws(arm.hero.anim)
	_root = skel.find_bone("root")
	skel.add_child(self)
	_warm_fx(skel)
	_add_springs(skel)
	_add_eyes(skel)
	_add_rim(skel)


## Feel audit 2026-11-04 item 3: in breaker hangs and slams he was lost under the bolts, rings and words.
## A paper rim (shaders/hero_rim.gdshader) past his ink, drawn after the effects, keeps his silhouette.
## Chained after Fx.outline's ink pass on his own copies of his surfaces (the ink material is shared).
func _add_rim(skel: Skeleton3D) -> void:
	if DisplayServer.get_name() == "headless" or Fx.ink_material() == null:
		return
	var rim := ShaderMaterial.new()
	rim.shader = RIM_SHADER
	rim.render_priority = RIM_PRIORITY
	rim.set_shader_parameter("rim_color", RIM_COLOR)
	rim.set_shader_parameter("width_px", Fx.COMIC_INK_PX + RIM_PX)
	rim.set_shader_parameter("depth_push", Fx.COMIC_INK_PUSH + RIM_PUSH)
	var ink: Material = Fx.ink_material().duplicate()
	ink.next_pass = rim
	var copies := {}
	for mi: MeshInstance3D in skel.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.get_parent() == self:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i)
			if m == null or m.next_pass != Fx.ink_material():
				continue
			if not copies.has(m):
				var copy: Material = m.duplicate()
				copy.next_pass = ink
				copies[m] = copy
			mi.set_surface_override_material(i, copies[m])


func _clips_key_claws(ap: AnimationPlayer) -> bool:
	if ap == null or not ap.has_animation("Idle"):
		return false
	var a := ap.get_animation("Idle")
	for i in a.get_track_count():
		if str(a.track_get_path(i)).ends_with(CLAW_TRACK):
			return true
	return false


## The clip playing is keyed for this rig's arm (KEYED_ARM), so the limb follows it even off attacks.
func _arm_keyed() -> bool:
	var ap: AnimationPlayer = void_arm.hero.anim
	return keyed and ap != null and ap.assigned_animation in KEYED_ARM


## The haft's direction from the form's own meshes, then how the main tentacle lies along it.
func _read_form(form: String, skel: Skeleton3D) -> void:
	var bone := skel.find_bone(FORM_BONES[form])
	if bone < 0:
		return
	_form_bone[form] = bone
	_w[form] = 0.0
	var rest := skel.get_bone_global_rest(bone)
	var tip := rest.origin
	for mi: MeshInstance3D in void_arm._parts[form]:
		for v: Vector3 in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if v.distance_squared_to(rest.origin) > tip.distance_squared_to(rest.origin):
				tip = v
	var dir := (tip - rest.origin).normalized()
	_form_dir[form] = dir
	_form_len[form] = tip.distance_to(rest.origin)
	var local := rest.basis.inverse() * dir
	var axis := 0
	for k in 3:
		if absf(local[k]) > absf(local[axis]):
			axis = k
	_form_axis[form] = axis
	# Each main bone in turn: which pose, under the one before it, points it down the haft.
	var above := skel.get_bone_global_rest(skel.find_bone("hand.r")).basis.get_rotation_quaternion()
	var poses: Array[Quaternion] = []
	for j in _main.size():
		var q_rest := skel.get_bone_rest(_main[j]).basis.get_rotation_quaternion()
		var along := _bone_dir(skel, j)
		var q := q_rest * Quaternion(along, ((above * q_rest).inverse() * dir).normalized())
		poses.append(q)
		above = above * q
	_grip_q[form] = poses


## A main bone's direction in its own space: towards the next bone, or the last one's way.
func _bone_dir(skel: Skeleton3D, j: int) -> Vector3:
	if j + 1 < _main.size():
		return skel.get_bone_rest(_main[j + 1]).origin.normalized()
	return Vector3.UP


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


## Two glowing almonds on the head bone, facing the camera, drawn as the burst is drawn.
func _add_eyes(skel: Skeleton3D) -> void:
	var at: Array = EYES.get(Game.hero_model, [])
	var head := skel.find_bone("head")
	if at.is_empty() or head < 0:
		return
	var follow := BoneAttachment3D.new()
	follow.name = "HereticEyes"
	follow.bone_name = "head"
	skel.add_child(follow)
	eyes = follow
	var rest := skel.get_bone_global_rest(head)
	var mid: Vector3 = (at[0] + at[1]) * 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # drawn after him, in triangle order
	mat.no_depth_test = true
	mat.render_priority = 2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.disable_fog = true
	for p: Vector3 in at:
		var mi := MeshInstance3D.new()
		mi.mesh = _eye_mesh(-1.0 if p.x < mid.x else 1.0)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_ghost", true)
		mi.position = rest.affine_inverse() * p
		follow.add_child(mi)


## One eye in billboard space (+z towards the camera): ink, then the glow, then a hot core.
## side -1 is the eye on screen left when he faces the camera; its inner corner is its right.
func _eye_mesh(side: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var tilt := deg_to_rad(EYE_TILT) * side
	for layer: Array in [[EYE_INK, ComicLook.INK, 0.0], [0.0, EYE_LOW, 0.002], [-0.35, EYE_HIGH, 0.004]]:
		var grow: float = layer[0]
		var w := EYE_SIZE.x * 0.5 + grow if grow >= 0.0 else EYE_SIZE.x * 0.5 * (1.0 + grow)
		var h := EYE_SIZE.y * 0.5 + grow if grow >= 0.0 else EYE_SIZE.y * 0.5 * (1.0 + grow)
		var ring := PackedVector3Array()
		for i in 12:
			var a := TAU * i / 12.0
			# an almond: pointed at the corners, flatter on top so it scowls
			var y := sin(a) * h * (0.55 if sin(a) > 0.0 else 1.0)
			ring.append(Vector3(cos(a) * w, y, layer[2]).rotated(Vector3.BACK, tilt))
		for i in ring.size():
			verts.append_array([Vector3(0.0, 0.0, layer[2]), ring[i], ring[(i + 1) % ring.size()]])
			colors.append_array([layer[1], layer[1], layer[1]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## One empty triangle in the burst's material, so its shader is ready before the first swing.
func _warm_fx(skel: Skeleton3D) -> void:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.BLACK, Color.BLACK, Color.BLACK])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, FORM_FX.material())
	var warm := MeshInstance3D.new()
	warm.name = "FormFxWarm"
	warm.mesh = mesh
	warm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warm.set_meta("no_ghost", true)
	skel.add_child(warm)


func form_weight(form: String) -> float:
	return _w.get(form, 0.0)


## How well a form's bone axis lies along its haft (1 = exactly). The stretch needs this.
func haft_alignment(form: String) -> float:
	var skel := get_skeleton()
	var bone: int = _form_bone[form]
	var local: Vector3 = skel.get_bone_global_rest(bone).basis.orthonormalized().inverse() * _form_dir[form]
	return absf(local[_form_axis[form]])


func _process_modification_with_delta(delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	var form: String = void_arm.form
	if form != _last_form:
		_last_form = form
		_form_burst.call_deferred(form, skel.global_transform * skel.get_bone_global_pose(_arm[3]))
	var want := 0.0 if form == "hand" else 1.0
	_out = move_toward(_out, want, delta / (FORM_TIME if want > _out else OPEN_TIME))
	_time += delta * lerpf(1.0, ATTACK_SWAY, _out)
	var striking: bool = void_arm.hero.state in [void_arm.hero.State.ATTACK, void_arm.hero.State.SWING]
	if _arm_keyed():
		_free = 0.0
	else:
		_free = move_toward(_free, 0.0 if striking or want > 0.0 else 1.0, delta / ARM_FREE_TIME)
	if _free > 0.0:
		for b in _arm:
			var rest_q := skel.get_bone_rest(b).basis.get_rotation_quaternion()
			skel.set_bone_pose_rotation(b, skel.get_bone_pose_rotation(b).slerp(rest_q, _free))
	_step_forms(delta, skel, form)
	_step_grip(delta)
	var flex := _grip_deg() * _grip_on
	var base := lerpf(1.0, GRIP_SPLAY_GROW, maxf(-_grip, 0.0) * _grip_on)
	for c: Dictionary in _chains:
		var bones: PackedInt32Array = c.bones
		for j in bones.size():
			var b := bones[j]
			var wave := sin(_time * SWAY_SPEED + c.phase + j * SWAY_PHASE)
			var angle := deg_to_rad(SWAY_DEG * wave + (0.0 if keyed else COIL_DEG * _out) + flex)
			skel.set_bone_pose_rotation(b, skel.get_bone_pose_rotation(b) * Quaternion(Vector3.RIGHT, angle))
		if bones.size() > 0:
			skel.set_bone_pose_scale(bones[0], Vector3.ONE * lerpf(base, KEYED_COLLAPSED if keyed else COLLAPSED, _out))
	_pose_main(skel, flex)
	_lean_into_turns(delta, skel)
	if eyes != null:
		_face_eyes(skel)  # last: the claw is where this frame puts it


func _lean_into_turns(delta: float, skel: Skeleton3D) -> void:
	if _root < 0 or delta <= 0.0:
		return
	var hero: CharacterBody3D = void_arm.hero
	var vel := Vector3(hero.velocity.x, 0.0, hero.velocity.z)
	_vel_lag = _vel_lag.lerp(vel, 1.0 - exp(-delta / LEAN_LAG))
	var want := Vector2.ZERO
	if hero.state == hero.State.MOVE:
		var fwd := skel.global_transform.basis.z
		fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
		var right := fwd.cross(Vector3.UP)  # he faces +Z; his right is -X in model space
		var d := vel - _vel_lag
		want = Vector2(d.dot(right) * LEAN_DEG, d.dot(fwd) * LEAN_DEG * LEAN_ALONG).limit_length(LEAN_MAX)
	_lean_v += ((want - lean) * LEAN_STIFF - _lean_v * LEAN_DAMP) * delta
	lean += _lean_v * delta
	if lean.length() < 0.01:
		return
	# tilt the top of him towards (right, front): about the axis up x that direction, in skeleton space
	var inv := skel.global_transform.basis.inverse()
	var fwd_s := (inv * skel.global_transform.basis.z).normalized()
	var up_s := (inv * Vector3.UP).normalized()
	var right_s := fwd_s.cross(up_s)
	var dir := (right_s * lean.x + fwd_s * lean.y).normalized()
	var q := Quaternion(up_s.cross(dir).normalized(), deg_to_rad(lean.length()))
	skel.set_bone_pose_rotation(_root, q * skel.get_bone_pose_rotation(_root))


## The eyes show only while his face is towards the camera, since they draw over the hood.
func _face_eyes(skel: Skeleton3D) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var head := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("head"))
	var rest := skel.get_bone_global_rest(skel.find_bone("head"))
	var ahead := head.basis.orthonormalized() * (rest.basis.orthonormalized().inverse() * Vector3.BACK)
	var to_cam := (cam.global_position - head.origin).normalized()
	eyes.visible = ahead.normalized().dot(to_cam) > EYE_FACING
	if not eyes.visible:
		return
	# They draw over the hood (no depth test), so they would also draw over the claw or a weapon
	# lifted in front of his face: hide each eye that one of those covers from the camera.
	var cover := _cover_points(skel)
	var claw_r := EYE_CLAW_R * skel.get_bone_pose_scale(_arm[3]).x
	for mi: Node3D in eyes.get_children():
		mi.visible = not _covered(cam.global_position, head * mi.position, cover, claw_r)


## Points along the claw (hand.r and every tentacle bone, with the midpoints of their bones) and along
## any weapon that is out, in world space: what can pass in front of his eyes.
func _cover_points(skel: Skeleton3D) -> PackedVector3Array:
	if _cover.is_empty():
		_cover.append(_arm[3])
		for b in skel.get_bone_count():
			if skel.get_bone_name(b).begins_with("tent."):
				_cover.append(b)
	var to_world := skel.global_transform
	var out := PackedVector3Array()
	for b: int in _cover:
		var at := to_world * skel.get_bone_global_pose(b).origin
		out.append(at)
		var p := skel.get_bone_parent(b)
		if p >= 0 and p in _cover:
			out.append(at.lerp(to_world * skel.get_bone_global_pose(p).origin, 0.5))
	var hand := to_world * skel.get_bone_global_pose(_arm[3]).origin
	for f: String in _w:
		if _w[f] > 0.3:
			var dir := skel_dir(f)
			for i in 8:
				out.append(hand + dir * _form_len[f] * (i + 1) / 8.0)
	return out


## Whether any of `pts`, between the camera and the eye, passes within `r` (plus the eye's own size)
## of the eye's line of sight.
static func _covered(cam: Vector3, eye: Vector3, pts: PackedVector3Array, r: float) -> bool:
	var v := eye - cam
	var length := v.length()
	var d := v / length
	for p in pts:
		var t := (p - cam).dot(d)
		if t <= 0.0 or t >= length - EYE_CLAW_GAP:
			continue
		if ((p - cam) - d * t).length() < r + EYE_SIZE.x * 0.5 * t / length:
			return true
	return false


## Where the claw should be on a grip move (GRIP_MOVES), from how far the clip has played.
func _step_grip(delta: float) -> void:
	var hero: Node = void_arm.hero
	var id: String = hero._move_id if hero.state == hero.State.ATTACK else ""
	var on: bool = not keyed and GRIP_MOVES.has(id) and void_arm.form == "hand" and hero.anim != null
	_grip_on = move_toward(_grip_on, 1.0 if on else 0.0, delta / (GRIP_SNAP if on else GRIP_FADE))
	if not on:
		return
	var length: float = hero.anim.current_animation_length
	var t: float = hero.anim.current_animation_position / length if length > 0.0 else 0.0
	var hit: float = hero.MOVES[id].hits[0]
	var want: float = GRIP_MOVES[id][0] if t < hit else GRIP_MOVES[id][1]
	if t < hit and want < 0.0:  # reaching: opens as it goes, widest just before the hit
		want *= smoothstep(0.0, hit * 0.8, t)
	_grip = move_toward(_grip, want, delta * 2.0 / GRIP_SNAP)


## Degrees per bone the grip adds: curl in when clenched (with a shake), bend back when splayed.
func _grip_deg() -> float:
	if _grip > 0.0:
		return _grip * (GRIP_CLENCH_DEG + GRIP_SHAKE_DEG * sin(_time * TAU * GRIP_SHAKE_HZ / SWAY_SPEED))
	return _grip * GRIP_SPLAY_DEG


## Grip state for checks: [-1 splayed .. 1 clenched, 0..1 how much it is applied].
func grip() -> Vector2:
	return Vector2(_grip, _grip_on)


## Grow the current weapon and pull back the others, showing whichever is still out.
func _step_forms(delta: float, skel: Skeleton3D, form: String) -> void:
	var clear := true
	for f: String in _w:
		if f != form and _w[f] > RETRACT_FIRST:
			clear = false
	for f: String in _w:
		if f == form:
			if clear:
				_w[f] = minf(_w[f] + delta / GROW_TIME, 1.0)
		else:
			_w[f] = maxf(_w[f] - delta / RETRACT_TIME, 0.0)
		var w: float = _w[f]
		for mi: MeshInstance3D in void_arm._parts[f]:
			mi.visible = w > 0.0
		var along := lerpf(GONE, OVERSHOOT, w / PEAK_AT) if w < PEAK_AT else lerpf(OVERSHOOT, 1.0, (w - PEAK_AT) / (1.0 - PEAK_AT))
		var girth := maxf(GONE, minf(w * 1.6, 1.0))
		var s := Vector3.ONE * girth
		s[_form_axis[f]] = along
		skel.set_bone_pose_scale(_form_bone[f], s)


## The main tentacle sways with the rest, and lies along whatever haft is out.
func _pose_main(skel: Skeleton3D, flex := 0.0) -> void:
	for j in _main.size():
		var b := _main[j]
		var rest_q := skel.get_bone_pose_rotation(b)  # the rest, or the clip's curl on a keyed model
		var wave := sin(_time * SWAY_SPEED + j * SWAY_PHASE)
		var q := rest_q * Quaternion(Vector3.RIGHT, deg_to_rad(SWAY_DEG * wave + flex))
		for f: String in _grip_q:
			q = q.slerp(_grip_q[f][j], _w[f] * GRIP)
		skel.set_bone_pose_rotation(b, q)


## The burst as it reshapes (heretic_form_fx.gd). Back to the bare limb there's no haft to follow.
func _form_burst(form: String, at: Transform3D) -> void:
	var parent: Node = void_arm.hero.get_parent()
	if parent == null:
		return
	var dir: Vector3 = skel_dir(form) if _form_dir.has(form) else Vector3.ZERO
	FORM_FX.spawn(parent, at.origin, form, dir, _form_len.get(form, 0.0))


## The haft's direction in the world, on the hand as it is now.
func skel_dir(form: String) -> Vector3:
	var skel := get_skeleton()
	var hand := skel.find_bone("hand.r")
	var now := skel.global_transform * skel.get_bone_global_pose(hand)
	var was := skel.get_bone_global_rest(hand)
	return (now.basis.orthonormalized() * was.basis.orthonormalized().inverse() * (_form_dir[form] as Vector3)).normalized()
