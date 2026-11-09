extends Node3D
## Locomotion dust: one drawn dust puff (designed_fx.dust) at the hero's feet when he starts a run (Run_Start),
## skids to a stop (Run_Stop) or dodges (Dodge_Forward on the ground), and on the skid and the dodge a short
## pair of floor skid marks drawn here on twos in the neutral DUST tones, gone in about a third of a second.
## ComicFx calls `watch(hero)` every frame: it reads the clip his AnimationPlayer is playing (player.gd stays
## untouched). Pooled: POOL nodes per parent, reused oldest first, never freed mid-effect (tests/fx_free_check.gd).
##   COMIC_DUST.watch(hero)            # every frame
##   COMIC_DUST.spawn(parent, at, dir, "stop" | "dodge" | "start")

const SELF := preload("res://scripts/comic_dust.gd")
const CRACK := preload("res://scripts/comic_crack.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const STEPS_PER_S := 12.0  # on twos
const POOL := 4
## By kind: the puff's radius (m, sizes the drawn puff), how far it sits from his feet along `dir` (+ ahead,
## - behind), steps the node stays busy, the skid marks' length (0: none) and where they start along `dir` (the
## dodge's kick-off marks start ahead of its puff).
const KINDS := {
	"stop": {"r": 0.17, "at": 0.35, "steps": 4, "skid": 0.9, "skid_at": 0.0},
	"dodge": {"r": 0.15, "at": -0.55, "steps": 4, "skid": 0.55, "skid_at": 0.35},
	"start": {"r": 0.13, "at": -0.3, "steps": 3, "skid": 0.0, "skid_at": 0.0},
}
const SKID_W := 0.055  # m, each mark at its widest
const SKID_GAP := 0.22  # m between the two feet's marks
const SKID_STEPS := 5
const SKID_ALPHA := 0.6
const SKID_Y := 0.07  # m: over the floor tiles' tops (0.03 hid under them)
const AIR := 0.2  # m: a dodge with his body higher than this is an air dash (no dust)
const CLIPS := {"Run_Stop": "stop", "Dodge_Forward": "dodge", "Run_Start": "start"}
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_PUFF := 0.1  # the drawn dust_puff's size per 0.01 m of the kind's radius

static var _pool: Array = []  # Node3D (untyped: freed ones are dropped on the next spawn)
static var _last_clip := ""
static var _last_pos := 0.0
static var spawned := 0  # (tests)

var kind := "stop"
var dir := Vector3.FORWARD
var busy := false
var _o: Dictionary = {}
var _born_us := 0
var _step := -1
var _skid: MeshInstance3D
var _skid_mesh := ArrayMesh.new()


## Watches the hero's clip: a new Run_Stop / Dodge_Forward / Run_Start (or the same clip restarted) puffs.
static func watch(hero: Node) -> void:
	if not "anim" in hero or hero.anim == null or not hero.has_method("_clip_name"):
		return
	var ap: AnimationPlayer = hero.anim
	var clip := ap.current_animation
	var pos := ap.current_animation_position
	var started := clip != _last_clip or pos < _last_pos - 0.05
	_last_clip = clip
	_last_pos = pos
	if not started or clip == "":
		return
	for wanted: String in CLIPS:
		if clip == hero._clip_name(wanted):
			_fire(hero, CLIPS[wanted])
			return


static func _fire(hero: Node3D, k: String) -> void:
	if k == "dodge" and hero.global_position.y > AIR:
		return
	var d := Vector3.ZERO
	if k == "dodge" and "_dash_dir" in hero:
		d = hero._dash_dir
	elif k == "stop" and hero is CharacterBody3D:
		d = (hero as CharacterBody3D).velocity
	if Vector3(d.x, 0.0, d.z).length() < 0.1 and hero.has_method("facing_dir"):
		d = hero.facing_dir()
	spawn(hero.get_parent(), hero.global_position, d, k)


static func spawn(parent: Node, at: Vector3, d: Vector3, k: String) -> Node3D:
	var fx: Node3D = null
	var live := []
	for v: Variant in _pool:  # (untyped: a freed node can't be passed as a Node3D)
		if is_instance_valid(v) and not (v as Node3D).is_queued_for_deletion():
			live.append(v)
	_pool = live
	for n: Node3D in _pool:
		if not n.busy and n.get_parent() == parent:
			fx = n
			break
	if fx == null:
		var mine := _pool.filter(func(n: Node3D) -> bool: return n.get_parent() == parent)
		if mine.size() >= POOL:
			fx = mine[0]  # the oldest: move it to the back
			_pool.erase(fx)
		else:
			fx = SELF.new()
			parent.add_child(fx)
		_pool.append(fx)
	fx.start(at, d, k)
	spawned += 1
	return fx


func _ready() -> void:
	top_level = true
	_skid = MeshInstance3D.new()
	_skid.mesh = _skid_mesh
	_skid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_skid.extra_cull_margin = 4.0
	add_child(_skid)
	set_process(busy)


func start(at: Vector3, d: Vector3, k: String) -> void:
	kind = k
	_o = KINDS.get(k, KINDS.stop)
	var flat := Vector3(d.x, 0.0, d.z)
	dir = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	global_position = Vector3(at.x, 0.0, at.z)
	var r: float = _o.r
	var ahead: float = _o.at
	busy = true
	visible = true
	DESIGNED.dust(get_parent(), global_position + dir * ahead, r * 100.0 * DESIGNED_PUFF / DESIGNED.DUST_SIZE * 0.5)
	_born_us = Time.get_ticks_usec()
	_step = -1
	set_process(true)
	tick()


func _process(_delta: float) -> void:
	tick()


## Redraws on a new step (real time: hitstop doesn't hold the dust).
func tick() -> void:
	if not busy:
		return
	var s := int((Time.get_ticks_usec() - _born_us) / 1000000.0 * STEPS_PER_S)
	if s == _step:
		return
	_step = s
	var puff_on := s < int(_o.steps)
	var skid_on := float(_o.skid) > 0.0 and s < SKID_STEPS
	if not puff_on and not skid_on:
		busy = false
		visible = false
		_skid_mesh.clear_surfaces()
		set_process(false)
		return
	_draw_skid(s if skid_on else -1)


## Two tapered marks on the floor from his feet back against `dir`, fading out.
func _draw_skid(s: int) -> void:
	_skid_mesh.clear_surfaces()
	if s < 0:
		return
	var length: float = _o.skid
	var a := SKID_ALPHA * (1.0 - float(s) / SKID_STEPS)
	var side := dir.cross(Vector3.UP)
	var back := -dir
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var head := PAL.fade(PAL.DUST.light, a).srgb_to_linear()  # (comic_crack's material reads linear)
	var tail := PAL.fade(PAL.DUST.light, 0.0).srgb_to_linear()
	for foot: float in [-0.5, 0.5]:
		var o := side * foot * SKID_GAP + Vector3.UP * SKID_Y + dir * float(_o.skid_at)
		var p0 := o
		var p1 := o + back * length
		var w := side * SKID_W * 0.5
		verts.append_array([p0 + w, p0 - w, p1, p0 + w * 0.6 + back * 0.04, p0 - w * 0.6 + back * 0.04, p0])
		cols.append_array([head, head, tail, head, head, head])
	_commit(_skid_mesh, verts, cols, CRACK.material())


func _commit(mesh: ArrayMesh, verts: PackedVector3Array, cols: PackedColorArray, mat: Material) -> void:
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
