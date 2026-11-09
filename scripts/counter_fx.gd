extends RefCounted
## The dash counter's look (docs/features/counter.md): Backlash's parry flash (the tentacle catching the weapon, a
## clash star in the signature's violet), the glint and the weapon knocked flying, and the whip-crack arc of its
## slam. Sheets: tools/vfx_gen/gen_counter.py and gen_cool3.py, registered here through DESIGNED.extra_sheets and
## played in the `void` palette row.

const DESIGNED := preload("res://scripts/designed_fx.gd")
const INK := preload("res://scripts/designed_ink.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const DESIGNED_BREAKER := preload("res://scripts/designed_breaker.gd")  # the perfect's speed lines

const SHEETS := {
	"parry_flash": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"snap_arc": {"grid": Vector2(3, 2), "frames": 6, "kind": "sprite"},
	"parry_glint": {"grid": Vector2(2, 2), "frames": 4, "kind": "sprite"},  # (round 54 cool pass 3)
	"parry_blade": {"grid": Vector2(4, 1), "frames": 4, "kind": "sprite"},
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
		DESIGNED_BREAKER.rays(parent, floor_at, "void", RAYS_SIZE)
	glint(parent, at, perfect)
	blade_off(parent, from, to, perfect)


# --- Round 54 cool pass 3 (combo-cool3): the parry sharper, the weapon knocked flying ------------------------------

## The glint: a hard four-point flick of light over the clash, GLINT_SIZE m (x GLINT_PERFECT on a perfect), in real time
## (the parry's hitstop must not hold it: it is the "tink" before the flash).
const GLINT_SIZE := 2.4
const GLINT_PERFECT := 1.35
const GLINT_TIMES := [0.025, 0.06, 0.04, 0.05]
## The attacker's weapon knocked out of its grip: BLADE_SIZE m, thrown up BLADE_UP m and out BLADE_OUT m away from him
## over BLADE_FLIGHT real s, spinning BLADE_SPIN rad/s, clattering down with a dust puff.
const BLADE_SIZE := 1.25
const BLADE_UP := 2.6
const BLADE_OUT := 3.4
const BLADE_FLIGHT := 0.55
const BLADE_SPIN := 22.0
## It clatters down and skids BLADE_SKID m on along its throw over BLADE_SKID_S real s, eroding from the touchdown,
## so it is off the floor 0.3 s after it lands.
const BLADE_SKID := 0.7
const BLADE_SKID_S := 0.3
static var glints := 0  # (counter_check)
static var blades := 0


## The glint over the clash at `at`.
static func glint(parent: Node, at: Vector3, perfect: bool) -> void:
	glints += 1
	if not parent.is_inside_tree():
		return
	register()
	var fx := DESIGNED.spawn(parent, "parry_glint", at + Vector3.UP * 0.1, GLINT_SIZE * (GLINT_PERFECT if perfect else 1.0), "void",
		GLINT_TIMES, Vector2(0.5, 1.0))
	fx.real_time = true
	fx.pop = 0.35
	fx.set_spin(randf_range(-0.25, 0.25), -1.0 if randf() < 0.5 else 1.0)


## The attacker's weapon (from `to`'s side, away from him at `from`) spins up and off and clatters down.
static func blade_off(parent: Node, from: Vector3, to: Vector3, perfect: bool) -> void:
	blades += 1
	if not parent.is_inside_tree():
		return
	register()
	var away := Vector3(to.x - from.x, 0.0, to.z - from.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	var side := away.cross(Vector3.UP).normalized() * (0.6 if randf() < 0.5 else -0.6)
	var start := Vector3(to.x, 0.0, to.z) - away * 0.3 + Vector3.UP * 1.3
	var land := Vector3(to.x, 0.0, to.z) + (away + side).normalized() * BLADE_OUT * (1.2 if perfect else 1.0)
	var times: Array = [BLADE_FLIGHT / 4.0, BLADE_FLIGHT / 4.0, BLADE_FLIGHT / 4.0, BLADE_FLIGHT / 4.0 + BLADE_SKID_S]  # (the last turn skids)
	var fx := DESIGNED.spawn(parent, "parry_blade", start, BLADE_SIZE, "dust", times, Vector2(BLADE_FLIGHT / (BLADE_FLIGHT + BLADE_SKID_S), 1.0))
	fx.real_time = true
	var spin := [0.0]
	var dir := 1.0 if randf() < 0.5 else -1.0
	var tw := fx.create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(fx):
			return
		var p := start.lerp(land + Vector3.UP * 0.15, k)
		p.y += sin(k * PI) * BLADE_UP * (1.0 - k * 0.35)
		fx.global_position = p
		spin[0] = dir * BLADE_SPIN * k * BLADE_FLIGHT
		fx.set_spin(spin[0]), 0.0, 1.0, BLADE_FLIGHT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(parent) and parent.is_inside_tree():
			DESIGNED.dust(parent, land, 0.7)
			Game.sfx("hit", -12.0, 0.2))
	var skid_to := land + Vector3.UP * 0.15 + (away + side).normalized() * BLADE_SKID
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(fx):
			fx.global_position = (land + Vector3.UP * 0.15).lerp(skid_to, k)
			fx.set_spin(spin[0] + dir * 0.6 * k), 0.0, 1.0, BLADE_SKID_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Backlash's slam lands at `at` (on the floor), having come down along `dir` (flat, from him out).
static func snap(parent: Node, at: Vector3, dir: Vector3) -> void:
	snaps += 1
	var floor_at := Vector3(at.x, 0.0, at.z)
	register()
	var fx := DESIGNED.spawn(parent, "snap_arc", floor_at + Vector3.UP * SNAP_UP, SNAP_SIZE, "void", SNAP_TIMES, Vector2(0.5, 1.0))
	fx.real_until = 1
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	var mirror := 1.0
	if cam != null:
		mirror = 1.0 if dir.dot(cam.global_basis.x) >= 0.0 else -1.0  # (the arc comes down on the side it was thrown)
	fx.set_spin(0.0, mirror)
	INK.shock(parent, floor_at, PAL.of("void").body, SHOCK_R * 1.2, 0.35)
