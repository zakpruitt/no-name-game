extends "res://scripts/comic_flat.gd"
## Impale (L L H, Dash H H: dark into ice), two pieces:
##   ComicImpale.burst(parent, spot, reach): the spear's frost going out to catch them: eight ice spikes racing out
##     across the floor from its foot (ink edge, light to body), out to `reach` in two steps, then thinning; 0.35 s.
##     Replaces frost_ring's pale torus.
##   ComicImpale.stake(parent, spot, foe, flight): waits for the foe's throw (thrown_foe, untyped) to land, then a
##     crystal stake goes from the spear's foot up through its chest and out past it, with an ice star where it
##     goes in; it holds three steps and thins away (0.45 s from the hit). The `skewered` tell (comic_state_tell)
##     carries it for the rest of ELEMENT_HOLD.

const SELF := preload("res://scripts/comic_impale.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const SPIKES := 8
const CHEST := 0.85
const STAKE_W := 0.22  # m at the root
const PAST := 0.55  # m it pokes out past the chest
const WAIT_MAX := 0.5  # s for the throw to land
const STAKE_LIFE := 0.45

var mode := "burst"
var reach := 2.0
var foe: Variant
var flight: Variant
var _p: Dictionary
var _spikes := []  # [angle, length k]
var _hit := -1.0
var _from := Vector3.ZERO  # world: the spear's foot


static func burst(parent: Node, spot: Vector3, r: float) -> Node3D:
	if DESIGNED_EL.DESIGNED.on():  # fx-ice2: the frost cracking out to them and cold mist, no ice spikes
		DESIGNED_EL.frost_mark(parent, spot, 0.9, 0.6)
		return DESIGNED_EL.frost_burst(parent, spot, r / DESIGNED_EL.FROST_BURST_REACH * 0.8)
	var b: Node3D = SELF.new()
	b.mode = "burst"
	b.reach = r
	b.life = 0.35
	b.begin(parent, Vector3(spot.x, 0.0, spot.z))
	return b


static func stake(parent: Node, spot: Vector3, e: Variant, by: Variant) -> Node3D:
	if not is_instance_valid(e):
		return null
	var b: Node3D = SELF.new()
	b.mode = "stake"
	b.foe = e
	b.flight = by
	b._from = Vector3(spot.x, 0.2, spot.z)
	b.life = WAIT_MAX + STAKE_LIFE
	b.begin(parent, e.global_position)
	return b


func _build() -> void:
	_p = PAL.of("water")
	var turn := _rng.randf() * TAU
	for i in SPIKES:
		_spikes.append([turn + TAU * (i + _rng.randf_range(-0.2, 0.2)) / SPIKES, _rng.randf_range(0.7, 1.0)])


func _follow(_delta: float) -> void:
	if mode != "stake":
		return
	if not is_instance_valid(foe):
		queue_free()
		return
	global_position = foe.global_position
	if _hit < 0.0:
		var landed: bool = not is_instance_valid(flight) or flight.is_queued_for_deletion()
		if landed or _t >= WAIT_MAX:
			_hit = _t
			life = _t + STAKE_LIFE
			_step = -1


func _draw(s: int) -> void:
	if mode == "burst":
		var out: float = [0.5, 1.0, 1.0, 0.9, 0.7][mini(s, 4)]
		var k := clampf(1.0 - s / 5.0, 0.0, 1.0)
		for sp: Array in _spikes:
			var d := Vector2(cos(sp[0]), sin(sp[0]))
			var pts := PackedVector2Array([d * 0.3, d * reach * float(sp[1]) * out])
			_floor_strip(pts, 0.26 + PAL.LINE * 2.0, PAL.LINE * 2.0, PAL.fade(INK, k))
		_layer()
		for sp: Array in _spikes:
			var d := Vector2(cos(sp[0]), sin(sp[0]))
			var pts := PackedVector2Array([d * 0.3, d * reach * float(sp[1]) * out])
			_floor_strip(pts, 0.26, 0.0, PAL.fade(_p.light, k), PAL.fade(_p.body, k))
		return
	if _hit < 0.0:
		return
	var hs := int((_t - _hit) * STEPS_PER_S)
	if DESIGNED_EL.DESIGNED.on():  # fx-ice2: no crystal stake; a clean water hit star where it lands on the spear
		if hs == 0 and not has_meta("starred"):
			set_meta("starred", true)
			DESIGNED_EL.DESIGNED.hit(get_parent(), global_position + Vector3.UP * CHEST, "water", 1.0)
		return
	var fade := clampf((hs - 2) / 3.0, 0.0, 1.0)
	var chest := Vector3.UP * CHEST
	var root := _from - global_position
	var dir := (chest - root)
	if dir.length() < 0.3:
		dir = Vector3.UP
	var tip := chest + dir.normalized() * PAST * (0.6 if hs == 0 else 1.0)
	var w := STAKE_W * (1.0 - 0.5 * fade)
	var pts := PackedVector3Array([root, chest, tip])
	_strip(pts, w + PAL.LINE * 2.0, PAL.LINE * 2.0, PAL.fade(INK, 1.0 - fade))
	_strip(pts, w, 0.0, PAL.fade(_p.light, 1.0 - fade * 0.8), PAL.fade(_p.body, 1.0 - fade * 0.8))
	_strip(PackedVector3Array([root.lerp(chest, 0.3), tip]), w * 0.25, 0.0, PAL.fade(_p.hot, 1.0 - fade))
	if hs <= 1:  # where it goes in
		var star := PackedFloat32Array([1.0, 0.55, 0.9, 0.55, 1.0, 0.55])
		var r := 0.55 if hs == 0 else 0.35
		_outline(chest, _star_ring(star, r, 0.3), PAL.LINE, INK)
		_fan(chest, _star_ring(star, r, 0.3), _p.hot, PAL.fade(_p.body, 0.85))
