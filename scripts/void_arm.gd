extends SkeletonModifier3D
## The void arm's shapes (ComicLook.HERO_FORMS): shows one form's meshes, and pops the hand small and
## back through a change so the swap reads as the arm reshaping rather than a cut.

const SNAP_TIME := 0.14  # s
const SNAP_FROM := 0.3  # scale when the new shape appears
const SNAP_OVER := 1.2  # ...overshooting to this
const SNAP_PEAK_AT := 0.4  # of SNAP_TIME

var form := ""
var hero: Node3D
var _parts := {}  # form -> Array[MeshInstance3D]
var _bone := -1
var _t := 1.0
var _settled := true


func setup(p: Node3D, model: Node3D, skel: Skeleton3D) -> void:
	hero = p
	_bone = skel.find_bone("hand.r")
	for f: String in ComicLook.HERO_FORMS:
		var list: Array[MeshInstance3D] = []
		for part: String in ComicLook.HERO_FORMS[f]:
			var mi: MeshInstance3D = model.find_child(part, true, false)
			if mi:
				list.append(mi)
		_parts[f] = list
	skel.add_child(self)
	shape("axe", false)


func shape(to: String, pop := true) -> void:
	if to == form:
		return
	form = to
	for f: String in _parts:
		for mi: MeshInstance3D in _parts[f]:
			mi.visible = f == to
	for coat in hero._coats:  # the element on the axe goes with the axe
		coat.visible = to == "axe"
	if pop:
		_t = 0.0
		_settled = false


func _process_modification_with_delta(delta: float) -> void:
	if _settled:
		return
	_t = minf(_t + delta / SNAP_TIME, 1.0)
	var k := lerpf(SNAP_FROM, SNAP_OVER, _t / SNAP_PEAK_AT) if _t < SNAP_PEAK_AT \
		else lerpf(SNAP_OVER, 1.0, (_t - SNAP_PEAK_AT) / (1.0 - SNAP_PEAK_AT))
	get_skeleton().set_bone_pose_scale(_bone, Vector3.ONE * k)
	_settled = _t >= 1.0
