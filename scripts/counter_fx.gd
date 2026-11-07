extends RefCounted
## The dash counter's look (docs/features/counter.md): Backlash's parry flash (the tentacle catching the weapon, a
## clash star in the signature's violet) and the whip-crack arc of its slam. Sheets: tools/vfx_gen/gen_counter.py,
## registered here through DESIGNED.extra_sheets and played in the `void` palette row. Every effect branches on
## DESIGNED.on() and keeps a classic path (--fx=classic).

const DESIGNED := preload("res://scripts/designed_fx.gd")
const INK := preload("res://scripts/designed_ink.gd")
const PAL := preload("res://scripts/fx_palette.gd")

const SHEETS := {
	"parry_flash": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"snap_arc": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
}
## The parry flash: PARRY_SIZE m (PERFECT_SIZE x on a perfect) at chest height between them. Frame 0 flicks in real
## time; the peak holds through the parry's hitstop (game time), then the clash breaks up.
const PARRY_SIZE := 2.6
const PERFECT_SIZE := 1.3
const PARRY_TIMES := [0.033, 0.11, 0.07, 0.07, 0.08, 0.1]
const PARRY_UP := 1.15  # m
const RAYS_SIZE := 0.42  # of designed_breaker's speed lines (a perfect only)
const SHOCK_R := 1.8  # m: the brush ring on the floor under the clash
## The slam's whip-crack: SNAP_SIZE m, standing over the spot it lands, its arc swung the way it came down.
const SNAP_SIZE := 2.6
const SNAP_UP := 1.0
const SNAP_TIMES := [0.033, 0.09, 0.07, 0.07, 0.08, 0.1]

static var _registered := false
static var parries := 0  # parry flashes drawn (counter_check)
static var snaps := 0


static func register() -> void:
	if _registered:
		return
	_registered = true
	for n: String in SHEETS:
		var s: Dictionary = SHEETS[n].duplicate()
		s["tex"] = load("res://assets/vfx/designed/%s.png" % n)
		DESIGNED.extra_sheets[n] = s


## Draw every material once at real size (elements.prewarm).
static func prewarm(root: Node3D) -> void:
	if not DESIGNED.on():
		return
	register()
	for n: String in SHEETS:
		var mi := MeshInstance3D.new()
		mi.mesh = QuadMesh.new()
		mi.material_override = DESIGNED.material(n)
		root.add_child(mi)
		mi.scale = Vector3.ONE * 20.0


## The parry: the clash between him (`from`) and the attacker (`to`), on the frame the counter lands.
static func parry(parent: Node, from: Vector3, to: Vector3, perfect: bool) -> void:
	parries += 1
	var at := from.lerp(to, 0.55) + Vector3.UP * PARRY_UP
	var floor_at := Vector3(at.x, 0.0, at.z)
	if not DESIGNED.on():
		Fx.flare(parent, at, PAL.of("void").body, 5.0 if perfect else 3.6, 0.3, "flare")
		Fx.ring(parent, floor_at, Color(PAL.of("void").hot, 0.9), 2.6, 0.3)
		return
	register()
	var fx := DESIGNED.spawn(parent, "parry_flash", at, PARRY_SIZE * (PERFECT_SIZE if perfect else 1.0), "void", PARRY_TIMES, Vector2(0.5, 1.0))
	fx.real_until = 1
	fx.pop = 0.2
	# (the blade comes in from the attacker's side: mirror the sheet when he stands to the screen's left of them)
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	var mirror := 1.0
	if cam != null:
		mirror = -1.0 if (to - from).dot(cam.global_basis.x) > 0.0 else 1.0
	fx.set_spin(randf_range(-0.2, 0.2), mirror)
	INK.shock(parent, floor_at, PAL.of("void").body, SHOCK_R, 0.3)
	if perfect:
		load("res://scripts/designed_breaker.gd").rays(parent, floor_at, "void", RAYS_SIZE)


## Backlash's slam lands at `at` (on the floor), having come down along `dir` (flat, from him out).
static func snap(parent: Node, at: Vector3, dir: Vector3) -> void:
	snaps += 1
	var floor_at := Vector3(at.x, 0.0, at.z)
	if not DESIGNED.on():
		Fx.ring(parent, floor_at, Color(PAL.of("void").body, 0.9), 2.2, 0.25)
		return
	register()
	var fx := DESIGNED.spawn(parent, "snap_arc", floor_at + Vector3.UP * SNAP_UP, SNAP_SIZE, "void", SNAP_TIMES, Vector2(0.5, 1.0))
	fx.real_until = 1
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	var mirror := 1.0
	if cam != null:
		mirror = 1.0 if dir.dot(cam.global_basis.x) >= 0.0 else -1.0  # (the arc comes down on the side it was thrown)
	fx.set_spin(0.0, mirror)
	INK.shock(parent, floor_at, PAL.of("void").body, SHOCK_R * 1.2, 0.35)
