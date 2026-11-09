extends Node3D
## The burst when the heretic's limb changes shape (heretic_rig.gd): the weapon's drawn element pop
## (designed_finish.form_burst). This file also keeps `material()`, the unshaded vertex-colour material every flat
## comic effect draws with (comic_pop, dark_fx, live_current, comic_crack, ...), so there is one shader to warm.

const DESIGNED_FINISH := preload("res://scripts/designed_finish.gd")  # (held: a load() at fire time recompiled it once freed)

static var _mat: StandardMaterial3D


## The shared look, so the first change has nothing new to compile mid-swing.
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # draws after the world, in triangle order
		_mat.no_depth_test = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.disable_fog = true
	return _mat


## `dir` is the haft's direction in the world; zero for a change back to the bare limb.
static func spawn(parent: Node, at: Vector3, form: String, dir: Vector3, _length: float) -> Node3D:
	return DESIGNED_FINISH.form_burst(parent, at, form, dir)
