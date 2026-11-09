extends BoneAttachment3D
## The current element on one of the comic hero's axes (ComicLook.infuse_axes builds one per axe bone). The axe's
## edge colour and the designed swing trail carry the element; this node only feeds the blade's tip to the
## comic_drag_mark it leaves where the tip scrapes the floor.

const MARK := preload("res://scripts/comic_drag_mark.gd")

var mark: Node3D
var _tip := Vector3.ZERO  # the blade's far point, in the hand's space
var _body: Node3D  # stands on the floor; the mark goes down at its height


## `edge`: points along the blade's edge in the hand bone's space. `centre`: the middle of the blade.
func setup(element: String, edge: PackedVector3Array, centre: Vector3, model: Node3D) -> void:
	_body = model.get_parent() as Node3D
	_tip = _farthest_from_handle(edge, centre)
	mark = MARK.new()
	mark.setup(element)
	add_child(mark)


## The grip is at the bone, so the handle runs through the origin towards the blade's centre.
static func _farthest_from_handle(edge: PackedVector3Array, centre: Vector3) -> Vector3:
	# out from the blade through the middle of the edge: on a crescent the horns are farther off the handle,
	# but the middle of the edge is what the drag poses stand on the floor
	var mid := Vector3.ZERO
	for v in edge:
		mid += v
	var out := (mid / edge.size() - centre).normalized()
	var best := centre
	var far := -INF
	for v in edge:
		if v.dot(out) > far:
			far = v.dot(out)
			best = v
	return best


func tip_position() -> Vector3:
	return global_transform * _tip


func _process(delta: float) -> void:
	if _body != null and is_visible_in_tree():  # (hidden: the arm is some other shape, with no blade to drag)
		mark.track(tip_position(), _body.global_position.y)
	mark.tick(delta)
