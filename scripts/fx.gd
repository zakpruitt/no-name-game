class_name Fx
## Small throwaway visual effects: damage numbers, hit sparks, flashes.

const SWOOSH_SECOND_HEIGHT := 1.0  # hero_fx.swoosh lifts its second (ender / chain) arc to 1.15 m, the first sits at 0.8
const AWAKEN_SWOOSH_BAND := 0.72  # Awakened: the swoosh keeps only its outer band past this UV.y, inked inside
## Particle and flare sprites (Kenney Particle Pack, CC0): white with alpha, tinted per use.
const TEX := {
	"dot": preload("res://assets/vfx/circle_05.png"),
	"ring": preload("res://assets/vfx/circle_03.png"),
	"flare": preload("res://assets/vfx/magic_05.png"),
	"star8": preload("res://assets/vfx/star_08.png"),
}
## Combo-counter thresholds where hit sparks escalate (chain_tier).
const CHAIN_TIERS := [10, 20, 35]
const COMIC_INK_PX := 1.6  # the comic hull width (the shader's default is 3.5): a hero is only ~130 px tall
const COMIC_INK_WOBBLE := 0.25  # how much of the width varies over the form
const COMIC_INK_PUSH := 0.08  # m behind the model, so a part's hull doesn't cover its neighbours
## Telegraph rim (edge_ring): a light ring just inside the radius with a dark outline just outside it.
const EDGE_WIDTH := 0.16  # m, light rim
const EDGE_OUTLINE := 0.07  # m, dark outline
## The per-hit flourishes are flat inked shapes on twos (scripts/comic_pop.gd) or designed flipbooks (designed_*.gd).
const COMIC_POP := preload("res://scripts/comic_pop.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const VOID_ELEMENT := preload("res://scripts/void_element.gd")
const COMIC_NUMBER := preload("res://scripts/comic_number.gd")
const COMIC_CRACK := preload("res://scripts/comic_crack.gd")
const AWAKEN_FLOURISH := preload("res://scripts/awaken_flourish.gd")
const CALLOUT_CAP := preload("res://scripts/callout_cap.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_INK := preload("res://scripts/designed_ink.gd")  # ground stamps, element hit pops
const DESIGNED_POLISH := preload("res://scripts/designed_polish.gd")  # chips, comet, tells, kills
const DESIGNED_FINISH := preload("res://scripts/designed_finish.gd")  # the Awakening, halos, daze stars, combo burst
const COMIC_CRACK_SIZE := 0.8  # of the scorch's radius: the scorch texture only filled about half its quad, but cracks reach their tips
const COMIC_GHOST_STEP := 1.0 / 12.0  # s: the comic afterimage's two steps, on twos
const COMIC_FLASH := Color(1.0, 0.97, 0.88)  # a comic hit flash's paper ink

static var _flash_mat: StandardMaterial3D
static var _tint_mats := {}  # flash_tint() overlays, one per colour
static var _rim_mat: ShaderMaterial
static var _outline_mat: ShaderMaterial
# Source material -> copy with the outline pass, shared by every character using it.
static var _outlined: Dictionary = {}
# Particle materials are colourless (tint comes from the colour ramp), so one per texture/blend.
static var _particle_mats: Dictionary = {}
## Tick time of the last big impact (read by the autotest to snap a frame).
static var last_big_hit_ms := 0
static var last_afterimage_ms := 0
static var _last_ring_ms := -100000
static var _last_ring_at := Vector3.ZERO
const RING_PAIR_MS := 40
const RING_PAIR_M := 1.5


## The base of nearly every effect material: unshaded, alpha-blended (`add`:
## additive), with the sprite `tex` from TEX when given.
static func unshaded_mat(color := Color.WHITE, tex := "", add := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if tex != "":
		mat.albedo_texture = TEX[tex]
	mat.albedo_color = color
	return mat


## Melee swing arc: the authored brush stroke (designed_fx.slash) around `pos` facing `fwd`, out to `radius`
## across `arc_deg` (360 = full spin), sweeping across it over `time`. `flip` swings right-to-left.
## While the hero is Awakened (feel audit 2026-11-04 item 4: his gold crescents were opaque sheets 4-5x his
## height) the swoosh is only its inked outer band (AWAKEN_SWOOSH_BAND) and hero_fx.swoosh's second, wider
## ender arc (the one raised past SWOOSH_SECOND_HEIGHT) is dropped.
static func swoosh(parent: Node, pos: Vector3, fwd: Vector3, radius: float, arc_deg: float,
		color: Color, flip := false, time := 0.26, height := 0.8, lines_only := false) -> void:
	var gold := _hero_awakened(parent)
	if gold and height > SWOOSH_SECOND_HEIGHT:
		return
	DESIGNED.slash(parent, pos, fwd, radius, arc_deg, "gold" if gold else PAL.nearest(color), flip, time, height, lines_only or gold)


## The palette name of the hero's current blow (round 33: one palette per element across a string): the
## move's element (VOID_ELEMENT.ELEMENT_OF), gold while Awakened, else the plain hot "hit".
static func _blow_element(node: Node) -> String:
	if node == null or not node.is_inside_tree():
		return "hit"
	var hero := node.get_tree().get_first_node_in_group("player")
	if hero == null:
		return "hit"
	if hero.get("awakened") == true:
		return "gold"
	var id: Variant = hero.get("_move_id")
	return VOID_ELEMENT.ELEMENT_OF.get(id, "hit") if id is String else "hit"


## Is the hero in a breaker (State.LEAP: the hang, the dive and the landing's hits)?
static func in_breaker(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	var hero := node.get_tree().get_first_node_in_group("player")
	if hero == null or not "state" in hero:
		return false
	if _leap_state == -2:
		var states: Variant = hero.get_script().get_script_constant_map().get("State", {})
		_leap_state = states.get("LEAP", -1) if states is Dictionary else -1
	return _leap_state >= 0 and hero.state == _leap_state


## Round 33, sleek 6: in a breaker every foe hit in one frame drew its own star, strokes and chain halo: Live Wire's
## jolts every 0.09 s and the landings put a star on every foe of the pile (Worldbreaker, Cataclysm, Grounded).
## In a breaker the frame's hits draw ONE star at the middle of them (the pile's centre), and the strokes and halo
## once per frame. Outside a breaker every hit keeps its own.
static var _leap_state := -2  # the hero's State.LEAP, read once
static var _crowd_stars := []  # [parent, at, size, element] this frame, in a breaker
static var _crowd_frame := {}  # what -> the process frame it last drew in a breaker
static var crowd_merged := 0  # stars folded into another (fx_sleek_check)


static func _once_in_breaker(parent: Node, what: String) -> bool:
	if not in_breaker(parent):
		return true
	var f := Engine.get_process_frames()
	if _crowd_frame.get(what, -1) == f:
		return false
	_crowd_frame[what] = f
	return true


static func _flush_crowd_stars() -> void:
	var batch := _crowd_stars
	_crowd_stars = []
	if batch.is_empty():
		return
	var mid := Vector3.ZERO
	var big := 0.0
	var parent: Node = null
	for r: Array in batch:
		mid += r[1]
		big = maxf(big, r[2])
		if parent == null and is_instance_valid(r[0]):
			parent = r[0]
	if parent == null or not parent.is_inside_tree():
		return
	crowd_merged += batch.size() - 1
	DESIGNED_INK.pop(parent, mid / float(batch.size()), str(batch[0][3]), big)


static func _hero_awakened(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	var hero := node.get_tree().get_first_node_in_group("player")
	return hero != null and hero.get("awakened") == true


## `foe`: who took it, so the comic number merges that foe's hits (comic_number.gd).
static func damage_number(parent: Node, pos: Vector3, amount: float, big := false, foe: Object = null) -> void:
	COMIC_NUMBER.add(parent, pos, amount, big, foe)  # one chunky inked number per foe, growing as hits add in


## Every hit on a foe uses these star sizes: one grammar, star + word + number, the same weight everywhere.
const HIT_STAR := 0.9
const HIT_STAR_BIG := 1.3
static func hit_spark(parent: Node, pos: Vector3, _color := Color(1.0, 0.9, 0.6), size := HIT_STAR) -> void:
	var at := pos + Vector3.UP * 1.1
	var el := _blow_element(parent)
	if in_breaker(parent):  # one star for the frame's hits, at their middle (_flush_crowd_stars)
		if _crowd_stars.is_empty():
			_flush_crowd_stars.call_deferred()
		_crowd_stars.append([parent, at, size, el])
		return
	DESIGNED_INK.pop(parent, at, el, size)  # the authored hit pop in the blow's element (capped in a crowd); impact() adds the strokes


## 0..3: how far the combo counter has climbed past CHAIN_TIERS.
static func chain_tier(count: int) -> int:
	var t := 0
	for n: int in CHAIN_TIERS:
		if count >= n:
			t += 1
	return t


## Extra hit flourish that grows with the combo counter: a drawn sparkle halo in the hero's colour behind the
## hit's star, bigger each tier (designed_finish.halo); once a frame in a crowd.
static func chain_spark(parent: Node, pos: Vector3, color: Color, tier: int, _dir := Vector3.UP) -> void:
	if tier <= 0:
		return
	var at := pos + Vector3.UP * 1.1
	if not _once_in_breaker(parent, "chain"):
		return
	if not DESIGNED_INK.once_a_frame("chain"):
		return
	DESIGNED_FINISH.halo(parent, at, color, tier)


## Debris off the hero's axes on each hit (player._do_hit). Draws nothing: the hit's pop (designed_ink.pop) is
## already in the element's shape and chips were clutter. Kept as a no-op for its callers.
static func element_hit(_parent: Node, _pos: Vector3, _element: String, _dir: Vector3, _big := false) -> void:
	pass


## A named combo landing (hero_fx.combo_callout): drawn burst lines round the hero (designed_finish.burst),
## scaled by the combo's tier (1-3).
static func combo_pop(parent: Node, pos: Vector3, color: Color, tier: int) -> void:
	var at := pos + Vector3.UP * 1.2
	var vivid := Color.from_hsv(color.h, maxf(color.s, 0.7), 1.0)
	var hero: Node = parent.get_tree().get_first_node_in_group("player") if parent.is_inside_tree() else null
	if hero != null and "_move_id" in hero and not CALLOUT_CAP.names_move(hero._move_id):
		return  # a light mid keeps its word only (callout_cap.names_move)
	DESIGNED_FINISH.burst(parent, at, vivid, tier)


## Camera-facing sprite that pops to `size` (m across) and fades over `time`.
## `add` blends additively: keep that for small hot cores, big additive
## shapes wash out to white on the light floor.
static func flare(parent: Node, at: Vector3, color: Color, size: float, time := 0.16,
		tex := "flare", add := false) -> void:
	var mat := unshaded_mat(color, tex, add)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true  # a hit flare reads through the enemy it lands on
	if Game.reduce_flashing:
		mat.albedo_color.a *= 0.45
		size *= 0.6
	var quad := QuadMesh.new()
	quad.material = mat
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = at
	m.scale = Vector3.ONE * size * 0.6  # starts big: a hit flash has to read on frame one
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3.ONE * size, time * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time * 0.6).set_delay(time * 0.4)
	tw.chain().tween_callback(m.queue_free)


## One drawn chip spray (designed_polish.chips). `dir` biases it (e.g. knockback direction); a wide `spread`
## or no direction throws it all round. Smoke and single-particle asks (elements.prewarm) draw nothing.
static func burst(parent: Node, pos: Vector3, color: Color, amount := 14, speed := 7.0,
		_size := 0.12, _lifetime := 0.3, dir := Vector3.UP, spread := 70.0, _gravity := -12.0,
		_radius := 0.0, tex := "dot", _add := false) -> void:
	if tex == "smoke" or amount <= 1:
		return
	var wide := spread >= 120.0 or dir.length() < 0.01
	DESIGNED_POLISH.chips(parent, pos, Color(color, 1.0), amount, speed, dir, wide)


static func particle_mat(tex: String, add: bool) -> StandardMaterial3D:
	var key := tex + ("+" if add else "")
	if not _particle_mats.has(key):
		var mat := unshaded_mat(Color.WHITE, tex, add)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		_particle_mats[key] = mat
	return _particle_mats[key]


## Flat inked two-tone chips (comic_pop) flung along `dir` that tumble and fall.
static func shards(parent: Node, pos: Vector3, color: Color, amount := 10, dir := Vector3.UP,
		speed := 8.0, size := 0.18, lifetime := 0.7) -> void:
	COMIC_POP.spawn(parent, pos, {"chips": clampi(int(amount * 0.6), 2, 14), "chip": color,
		"chip_size": size * 0.85, "chip_speed": speed * 0.7, "dir": dir, "spread": 1.2,
		"steps": clampi(int(lifetime * 10.0), 4, 7)})


## An enemy going down: a big held star, a burst of strokes thrown along the blow, a dust puff where he drops.
static func death(parent: Node, pos: Vector3, dir: Vector3, big := false,
		_color := Color(0.93, 0.89, 0.78)) -> void:
	var at := pos + Vector3.UP * 0.9
	var star := DESIGNED.spawn(parent, "hit_spark", at, DESIGNED.HIT_SIZE * (1.6 if big else 1.3), "hit", DESIGNED_INK.KILL_TIMES, Vector2(0.55, 1.0))
	star.real_until = 1
	star.pop = 0.15
	star.vary(PI, true)
	DESIGNED.streaks(parent, at, dir, "hit", true)
	DESIGNED.dust(parent, pos, 1.1 if big else 0.85)


## Speed strokes thrown back off the hero's kick-off along a dash, in his colour (once a frame).
static func dash_streak(parent: Node, from: Vector3, dir: Vector3, _length: float, color: Color,
		_time := 0.3, _width := 2.2) -> void:
	var d0 := Vector3(dir.x, 0.0, dir.z).normalized()
	if DESIGNED_INK.once_a_frame("dash"):
		DESIGNED.streaks(parent, from + Vector3.UP * 0.5 - d0 * 0.2, -d0, DESIGNED.PAL.nearest(color))


## Awakening activation at `pos`: one thin inked column, held past a breaker landing (awaken_flourish.gd).
static func awaken_burst(parent: Node, pos: Vector3, _color: Color, _radius := 7.0) -> void:
	AWAKEN_FLOURISH.spawn(parent, pos)


## Two drawn spirit wisps curling up off a corpse as it sinks away.
static func soul(parent: Node, pos: Vector3, _color := Color(0.3, 0.75, 1.0, 0.9)) -> void:
	DESIGNED_POLISH.soul(parent, pos)


## The authored streaks thrown along the blow (designed_fx.streaks), once a frame; hit_spark has the star.
static func impact(parent: Node, pos: Vector3, dir: Vector3, big := false) -> void:
	var at := pos + Vector3.UP * 1.1
	if big:
		last_big_hit_ms = Time.get_ticks_msec()
	if not _once_in_breaker(parent, "impact"):
		return
	DESIGNED_INK.streaks(parent, at, dir, _blow_element(parent), big)  # (none on a crowd hit: designed_ink.pop's merge)


const DUST_MIN := 8  # Fx.dust calls under this many motes (footsteps, small skids) draw no puff
## One drawn puff for a landing or a slam; no smoke (the landing's ring and cracks carry it).
static func dust(parent: Node, pos: Vector3, amount := 10, size := 0.45) -> void:
	if amount >= DUST_MIN:
		DESIGNED.dust(parent, pos, clampf(size / 0.6, 0.7, 1.6))


## Expanding inked hoop on the ground (shockwaves): comic_pop's ring, which is designed_ink.shock. Callers often
## lay a colour hoop and a white one on the same spot at once; one deliberate hoop reads cleaner than two nested
## ones, so the second within RING_PAIR_MS is dropped.
static func ring(parent: Node, pos: Vector3, color: Color, radius: float, time := 0.35) -> void:
	var now := Time.get_ticks_msec()
	var flat := Vector3(pos.x, 0.0, pos.z)
	if now - _last_ring_ms <= RING_PAIR_MS and flat.distance_to(_last_ring_at) < RING_PAIR_M:
		return
	_last_ring_ms = now
	_last_ring_at = flat
	COMIC_POP.spawn(parent, pos, {"ring": radius, "ring_color": color, "steps": clampi(int(time * 12.0) + 1, 3, 5)})


const THIN_HOOP_W := 0.12  # m asked of comic_pop (it draws half: a 0.06 m band, the breaker cue's)


## A thin inked floor hoop in an element's palette (light tone band, its ink either side), the breaker cue
## rings' weight.
static func thin_hoop(parent: Node, pos: Vector3, element: String, radius: float, time := 0.3) -> void:
	var pal: Dictionary = PAL.of(element)
	COMIC_POP.spawn(parent, pos, {"ring": radius, "ring_color": pal.light, "ring_w": THIN_HOOP_W,
		"steps": clampi(int(time * 12.0) + 1, 3, 5)})


## Where a foe was spiked into the floor (enemy._crater): an inked dent (comic_crack) a little under `radius`,
## in the dust's warm tone. The dust puff carries the rest: no hoop per crater.
const CRATER_COMIC := Color(0.62, 0.5, 0.42)  # the dust's warm tone: comic_crack cools it a little, not to soot
const CRATER_COMIC_SIZE := 0.7  # of the radius
const CRATER_COMIC_TIME := 0.6  # s
static func crater(parent: Node, pos: Vector3, radius: float, _time := 1.4) -> void:
	COMIC_CRACK.spawn(parent, pos, CRATER_COMIC, radius * CRATER_COMIC_SIZE, CRATER_COMIC_TIME)


## Cartoon dizzy stars circling a dazed head (training_dummy._shake_off): two drawn stars on a DAZE_RING m
## ring `height` above `node`, spinning DAZE_SPIN rad/s for `time` (designed_finish.daze). Named "DazeStars".
const DAZE_RING := 0.5  # m, the ring's radius
const DAZE_SPIN := 7.0  # rad/s
static func daze(node: Node3D, height: float, time := 0.9) -> void:
	DESIGNED_FINISH.daze(node, height, time, DAZE_RING, DAZE_SPIN)


## Burn mark on the floor: a flat inked splat and cracks (comic_crack), hot in `color` then soot, over `time`
## (magma, breaker landings).
static func scorch(parent: Node, pos: Vector3, color: Color, radius: float, time := 1.2) -> void:
	COMIC_CRACK.spawn(parent, pos, Color.from_hsv(color.h, maxf(color.s, 0.85), 1.0), radius * COMIC_CRACK_SIZE, time)


## A flat inked silhouette of a (skinned) model in its current pose: one step in `color`, then ink, on twos.
static func afterimage(parent: Node, model: Node3D, color: Color, time := 0.25) -> void:
	if DisplayServer.get_name() == "headless":
		return  # the dummy renderer has no skeletons to bake from
	if Time.get_ticks_msec() - last_afterimage_ms < int(COMIC_GHOST_STEP * 1000.0):
		return  # on twos: a dash asks every 0.035 s, which stacked into a solid bar
	last_afterimage_ms = Time.get_ticks_msec()
	var mat := unshaded_mat(Color(Color.from_hsv(color.h, maxf(color.s, 0.6), 0.95), 1.0))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.next_pass = ink_material()
	var ghost := Node3D.new()
	parent.add_child(ghost)
	var poses := {}  # his skeleton -> a frozen copy of its pose: skinned on the GPU, not baked
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var flashing := _flash_mat != null and mi.material_overlay == _flash_mat
		if not mi.is_visible_in_tree() or mi.mesh == null or flashing or mi.has_meta("no_ghost"):  # (no_ghost: effects riding on him)
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		copy.material_override = mat
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
		copy.global_transform = mi.global_transform
		var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi.skin else null
		if skel != null:
			if not poses.has(skel):
				poses[skel] = _frozen_pose(skel, ghost)
			copy.skin = mi.skin
			copy.skeleton = copy.get_path_to(poses[skel])
		elif mi.skin:
			copy.mesh = mi.bake_mesh_from_current_skeleton_pose()
	var tw := ghost.create_tween()
	tw.tween_interval(COMIC_GHOST_STEP)
	tw.tween_callback(func() -> void: mat.albedo_color = ComicLook.INK)
	tw.tween_interval(maxf(time - COMIC_GHOST_STEP, COMIC_GHOST_STEP))
	tw.tween_callback(ghost.queue_free)


## A Skeleton3D under `parent` holding `skel`'s current pose. Baking a skinned
## mesh on the CPU (bake_mesh_from_current_skeleton_pose) took ~18 ms for the
## heretic; a copied pose lets the GPU skin the shared mesh as usual.
static func _frozen_pose(skel: Skeleton3D, parent: Node3D) -> Skeleton3D:
	var copy := Skeleton3D.new()
	for i in skel.get_bone_count():
		copy.add_bone(skel.get_bone_name(i))
	for i in skel.get_bone_count():
		copy.set_bone_parent(i, skel.get_bone_parent(i))
		copy.set_bone_rest(i, skel.get_bone_rest(i))
	for i in skel.get_bone_count():  # global poses: they include the rig's sway and spring bones (parents come first)
		copy.set_bone_global_pose(i, skel.get_bone_global_pose(i))
	parent.add_child(copy)
	copy.global_transform = skel.global_transform
	return copy


## Briefly paint every mesh under `root` white.
static func flash(root: Node, duration := 0.08) -> void:
	if not Game.reduce_flashing and _own_inks(root).size() > 0:
		flash_tint(root, COMIC_FLASH, duration)  # (a foe: its ink flashes, not a white blob over it)
		return
	if _flash_mat == null:
		_flash_mat = unshaded_mat()
	_flash_mat.albedo_color = Color(1, 1, 1, 0.3 if Game.reduce_flashing else 0.85)
	_overlay(root, _flash_mat, duration)


## flash() in a colour (enemy hit confirms in the hero's element): one shared
## overlay per colour, so a crowd flashing together costs one material.
static func flash_tint(root: Node, color: Color, duration := 0.08) -> void:
	var key := color.to_rgba32()
	if not _tint_mats.has(key):
		_tint_mats[key] = unshaded_mat()
	var mat: StandardMaterial3D = _tint_mats[key]
	mat.albedo_color = Color(color, 0.3 if Game.reduce_flashing else 0.85)
	if not Game.reduce_flashing and _own_inks(root).size() > 0:
		# Comic: the foe's own ink goes paper, then his colour, for two short steps, round its own tones.
		# An overlay fill (even a solid one) turned each foe into a flat inkless blob over a zapped crowd.
		var inks := _own_inks(root)
		var tone := Color.from_hsv(color.h, maxf(color.s, 0.6), 1.0)
		for ink: ShaderMaterial in inks:
			ink.set_shader_parameter("outline_color", COMIC_FLASH)
		var tree := root.get_tree()  # (held: root may be freed during the wait; the inks are kept alive here)
		await tree.create_timer(duration * 0.5, true, false, true).timeout
		if not is_instance_valid(root):
			return
		for ink: ShaderMaterial in inks:
			ink.set_shader_parameter("outline_color", tone)
		await tree.create_timer(duration * 0.5, true, false, true).timeout
		if not is_instance_valid(root):
			return
		for ink: ShaderMaterial in inks:
			ink.set_shader_parameter("outline_color", ComicLook.INK)
		return
	_overlay(root, mat, duration)


## Lays `mat` over every mesh under `root` for `duration`. If `root` leaves the tree first (a foe freed
## a frame after its hit), the overlay comes off as it goes: freed with an overlay still on, each mesh
## printed "Parameter material is null" (agents.md).
static func _overlay(root: Node, mat: Material, duration: float) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		mi.material_overlay = mat
	var clear := func() -> void:
		for mi in meshes:  # (untyped: a mesh freed during the wait can't be assigned to a typed loop variable)
			if is_instance_valid(mi) and mi.material_overlay == mat:
				mi.material_overlay = null
	root.tree_exiting.connect(clear, CONNECT_ONE_SHOT)
	await root.get_tree().create_timer(duration, true, false, true).timeout
	if is_instance_valid(root) and root.tree_exiting.is_connected(clear):
		root.tree_exiting.disconnect(clear)
		clear.call()


## The outline materials of `root`'s own (outline_own), not the shared one: what a comic flash recolours.
static func _own_inks(root: Node) -> Array:
	var out := []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k)
			var ink: Material = m.next_pass if m != null else null
			if ink is ShaderMaterial and ink != _outline_mat and not out.has(ink):
				out.append(ink)
	return out


## Drop cached materials so nothing is left alive at exit.
static func release() -> void:
	_flash_mat = null
	_tint_mats.clear()
	_rim_mat = null
	_outline_mat = null
	_outlined.clear()
	_particle_mats.clear()
	COMIC_POP.release()
	ComicLook.release()


## Give every mesh under `root` a dark toon outline (inverted hull pass).
## The outline material Fx.outline puts on the hero, for something built later (void_tendril.gd).
static func ink_material() -> Material:
	return _outline_mat


static func outline(root: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return  # the dummy renderer errors on the shared override materials at exit
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://shaders/outline.gdshader")
	_outline_mat.set_shader_parameter("width_px", COMIC_INK_PX)  # thick dark ink, swelling over the form like a brush
	_outline_mat.set_shader_parameter("wobble", COMIC_INK_WOBBLE)
	_outline_mat.set_shader_parameter("depth_push", COMIC_INK_PUSH)
	_outline_mat.set_shader_parameter("outline_color", ComicLook.INK)
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			if src == null:
				continue
			if not _outlined.has(src):
				var copy: Material = src.duplicate()
				copy.next_pass = _outline_mat
				_outlined[src] = copy
			mi.set_surface_override_material(i, _outlined[src])


## Fx.outline with an outline material of `root`'s own (enemy.gd thickens it
## on big hits): each surface gets its own copy, so one character's ink can
## change width alone. Returns that material (null headless, as outline()).
static func outline_own(root: Node) -> ShaderMaterial:
	if DisplayServer.get_name() == "headless":
		return null
	outline(root)  # sets up the shared material's look (comic width, wobble, ink)
	var own: ShaderMaterial = _outline_mat.duplicate()
	var copies := {}  # this character's shared copy -> its own copy
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var shared := mi.get_surface_override_material(i)
			if shared == null or shared.next_pass != _outline_mat:
				continue
			if not copies.has(shared):
				var copy: Material = shared.duplicate()
				copy.next_pass = own
				copies[shared] = copy
			mi.set_surface_override_material(i, copies[shared])
	return own


## Telegraph rim: a light ring just inside radius r (EDGE_WIDTH) with a dark
## outline just outside it (EDGE_OUTLINE), so attack areas read on bright tiles
## without relying on colour. Add it under the telegraph mesh; colour it each
## frame with pulse_edge().
static func edge_ring(r: float) -> MeshInstance3D:
	var edge := MeshInstance3D.new()
	var outline := MeshInstance3D.new()
	edge.add_child(outline)
	for mi: MeshInstance3D in [edge, outline]:
		var torus := TorusMesh.new()
		torus.rings = 48
		torus.ring_segments = 4
		torus.material = unshaded_mat()
		mi.mesh = torus
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(outline.mesh.material as StandardMaterial3D).albedo_color = Color(0.05, 0.02, 0.05, 0.8)
	edge.scale = Vector3(1.0, 0.3, 1.0)
	fit_edge(edge, r)
	return edge


static func fit_edge(edge: MeshInstance3D, r: float) -> void:
	var rim := edge.mesh as TorusMesh
	rim.inner_radius = maxf(r - EDGE_WIDTH, 0.01)
	rim.outer_radius = r
	var dark := (edge.get_child(0) as MeshInstance3D).mesh as TorusMesh
	dark.inner_radius = r
	dark.outer_radius = r + EDGE_OUTLINE


## Light rim in `color`'s hue, pulsing with `t` (cycles), fading with color.a.
static func pulse_edge(edge: MeshInstance3D, color: Color, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * TAU)
	var mat := (edge.mesh as TorusMesh).material as StandardMaterial3D
	mat.albedo_color = Color(color.lerp(Color.WHITE, 0.7), lerpf(0.4, 1.0, pulse) * minf(color.a * 2.2, 1.0))


static func rim_material() -> ShaderMaterial:
	if _rim_mat == null:
		_rim_mat = ShaderMaterial.new()
		_rim_mat.shader = load("res://shaders/rim_glow.gdshader")
	return _rim_mat
