extends RefCounted
## Round 44 (fx-cohesion, docs/features/designed-fx.md): the designed versions of the effects that still drew as
## runtime polygons after the pilot (the tentacle's skin, the ground stamps that replace the flat floor hoops, the
## per-element hit pop). Sheets: tools/vfx_gen/gen_cohesion.py. Kept beside designed_fx.gd (the storm lane adds
## to that file) and reusing its palette, timeline node and shaders.

const DESIGNED := preload("res://scripts/designed_fx.gd")


## Draw every material this file uses once at real size (elements.prewarm), so nothing compiles mid-fight.
static func prewarm(root: Node3D) -> void:
	if not DESIGNED.on():
		return
	var at := root.global_position
	var t: Node3D = load("res://scripts/void_tendril.gd").new()
	root.add_child(t)
	t.draw(at, at + Vector3(3.0, 0.0, 0.0), 1.0, 0.1, 0.5, 0.0)
	t.draw(at, at + Vector3(0.0, 0.0, 3.0), 1.0, 0.1, 0.0, 0.1)  # (a jump: no smear; the smear is warmed below)
	var smear := MeshInstance3D.new()
	smear.mesh = QuadMesh.new()
	smear.material_override = t.smear_material()
	root.add_child(smear)
	smear.scale = Vector3.ONE * 20.0
