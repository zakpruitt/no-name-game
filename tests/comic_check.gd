extends SceneTree
## Headless PASS/FAIL for the comic models (docs/features/comic-style.md): every clip
## each enemy type asks for resolves in its GLB after ComicLook.clip, every material
## has tones, `g` survived the import, and an absent GLB falls back to KayKit.
## Run: godot --headless --path . -s tests/comic_check.gd

# What each behaviour plays. A clip enemy.gd or boss.gd asks for that isn't listed
# here fails the scan below, so a new clip can't slip past this test.
const COMMON := ["Idle_Combat", "Spawn_Ground_Skeletons", "Hit_A", "Hit_B", "Lie_StandUp", "Death_A"]
const BY_ROLE := {
	"melee": ["1H_Melee_Attack_Chop"],
	"ranged": ["Spellcasting", "Spellcast_Shoot"],
	"raise": ["Spellcasting", "Spellcast_Shoot", "Spellcast_Summon"],
	"line": ["2H_Ranged_Aiming", "2H_Ranged_Shoot"],
	"bomb": ["Bomb_Windup"],
	"dodge": ["Dodge_Backward"],
	"shield": ["Block_Hit", "1H_Melee_Attack_Chop"],
}
const PIECE_SIZE_SLACK := 0.5  # m, summed over the axes: ragged edges differ a little
const TIP_ON_FLOOR := 0.2  # m either way, a dragged blade's tip
const AXE_AHEAD_MAX := 0.45  # m in front of him, axe head, in anything he holds
const MOVE_TAIL_FROM := 0.75  # abilities.into_guard: from here a move's arms ease into the guard
const BOSS_ONLY := ["Enrage", "Jump_Idle", "Jump_Land", "Spellcast_Shoot"]

# Loaded at run time: a preload here compiles them before the Game autoload exists.
var Look: GDScript
var MAIN: GDScript
var BOSS: GDScript
var _fails := 0
var _checks := 0


func _initialize() -> void:
	Look = load("res://scripts/comic_look.gd")
	MAIN = load("res://scripts/main.gd")
	BOSS = load("res://scripts/boss.gd")
	var game: Node = get_root().get_node("Game")
	_expect(game.comic_style, "comic style is always on")
	_expect(Look.scene("no_such_enemy") == null, "absent GLB: null, caller keeps KayKit")
	_scan_sources()
	var with_glb := []
	var absent := []
	for kind: String in MAIN.ENEMY_TYPES:
		var spec: Dictionary = MAIN.ENEMY_TYPES[kind]
		var asks: Array = COMMON + [spec.get("run_anim", "Running_A")] + _role_clips(spec)
		if _check_model(kind, asks):
			with_glb.append(kind)
		else:
			absent.append(kind)
	var boss_asks: Array = COMMON + BOSS_ONLY + [MAIN.BOSS_SPEC.run_anim]
	for attack: String in BOSS.ATTACKS:
		_expect(BOSS.COMIC_ATTACKS.has(attack), "boss attack %s has a comic clip" % attack)
		boss_asks.append(BOSS.COMIC_ATTACKS[attack][0])
	if _check_model("warden", boss_asks):
		with_glb.append("warden")
	else:
		absent.append("warden")
	_check_dungeon()
	_check_floors_face_up()
	await _check_fx(game)
	await _check_hero(game)
	game.comic_style = false
	Look.release()
	print("[comic_check] models=", with_glb, " kaykit_fallback=", absent)
	print("[comic_check] %s %d checks, %d failed" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	quit(1 if _fails > 0 else 0)


## The hero model (the heretic), the Ab_ overlay's numbers, then a real player.
func _check_hero(game: Node) -> void:
	game.comic_style = true
	var hero_script: GDScript = load("res://scripts/player.gd")
	var packed: PackedScene = Look.scene(Look.HERETIC)
	_expect(packed != null, "hero GLB present")
	if packed == null:
		return
	var model: Node3D = packed.instantiate()
	get_root().add_child(model)
	var rig: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	for mat: String in Look.material_names(model):
		_expect(Look.known_material(mat), "hero: material %s has tones" % mat)
	var asks := _hero_clips(hero_script)
	_expect(asks.size() > 20, "scan found the hero's clips (%d)" % asks.size())
	for wanted: String in asks:
		var got: String = Look.clip(rig, Look.HERETIC, wanted)
		_expect(rig.has_animation(got), "hero: %s -> %s" % [wanted, got])
	_check_hero_bones(model)
	_check_overlay(hero_script, rig)
	model.free()
	await _check_hero_in_play(game, hero_script, rig != null)


## Every clip player.gd can ask for: _play lines (with their ternaries), MOVES, hang_anim.
func _hero_clips(hero_script: GDScript) -> Array:
	var found := {}
	var quoted := RegEx.create_from_string("\"([A-Za-z0-9_]+)\"")
	for line: String in FileAccess.get_file_as_string("res://scripts/player.gd").split("\n"):
		if "_play(" in line:
			for m in quoted.search_all(line):
				found[m.get_string(1)] = true
	for move: Dictionary in hero_script.MOVES.values():
		found[move.anim] = true
	for b: Dictionary in load("res://scripts/void_element.gd").BREAKERS.values():
		if b.has("hang_anim"):
			found[b.hang_anim] = true
	for loop: String in hero_script.LOOPING:
		found[loop] = true
	return found.keys()


## The hero faces +Z like everything else.
func _check_hero_face(model: Node3D) -> void:
	_check_facing(model, "hero")


## The bones the trails and the void arm hang off.
func _check_hero_bones(model: Node3D) -> void:
	_check_hero_face(model)
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	for bone: String in ["head", "chest", "upperarm.l", "upperarm.r", "hand.l", "hand.r"]:
		_expect(skel.find_bone(bone) >= 0, "hero has bone %s (tools/comic_glb.py renames clashing meshes)" % bone)
	var blades: Array = Look.hero_blades(model)
	_expect(blades.size() == Look.HERO_AXES.size(), "a weapon-trail blade per hand")
	for blade: MeshInstance3D in blades:
		_expect(blade.mesh.size.y > 0.4 and blade.mesh.size.y < 2.0, "blade reaches the axe head (%.2f m)" % blade.mesh.size.y)
		_expect(blade.layers == 0 and blade.has_meta("no_ghost"), "blade is never drawn or ghosted")


## The numbers: hit = frame / length, and the time after the hit unchanged.
func _check_overlay(hero_script: GDScript, rig: AnimationPlayer) -> void:
	var kaykit: Node = load(hero_script.AXE_SOURCE).instantiate()  # the old timings are its clips
	var old_rig: AnimationPlayer = kaykit.find_child("AnimationPlayer", true, false)
	_expect(Look.HERO_MOVES.size() == 5, "five Ab_ clips routed")
	for id: String in Look.HERO_MOVES:
		var h: Dictionary = Look.HERO_MOVES[id]
		_expect(rig.has_animation(h.clip), "%s: clip %s" % [id, h.clip])
		var length: float = rig.get_animation(h.clip).length
		# frames / hit are the shaman's 24 fps counts; the heretic's clips run their own lengths,
		# and only the hit fraction (hit / frames) is used.
		_expect(h.hit > 0 and h.hit < h.frames, "%s: hit frame %d inside its %d" % [id, h.hit, h.frames])
		var base: Dictionary = hero_script.MOVES[id]
		var old_len: float = old_rig.get_animation(base.anim).length
		_expect(absf(old_len - h.old) < 0.001, "%s: old length is %s's %.4f" % [id, base.anim, old_len])
		var leap: float = load("res://scripts/void_element.gd").BREAKERS.get(id, {}).get("leap", -1.0)
		var before := base.hash()
		var m: Dictionary = base.duplicate(true)
		Look.retime(id, m, length, base.hits[0], leap)
		var hit: float = float(h.hit) / h.frames
		var what := "%s (hit %.3f cancel %.3f end %.3f)" % [id, hit, m.cancel, m.end]
		_expect(m.anim == h.clip, what + " plays its clip")
		_expect(m.hits.size() == base.hits.size(), what + " keeps its hit count")
		_expect(absf(m.hits[0] - hit) < 0.0001, what + " lands on the hit frame")
		_expect(absf((m.cancel - hit) * length - (base.cancel - base.hits[0]) * h.old) < 0.0001, what + " keeps time to cancel")
		_expect(absf((m.end - hit) * length - (base.end - base.hits[0]) * h.old) < 0.0001, what + " keeps time to end")
		_expect(m.hits[-1] < m.end and m.cancel <= m.end and m.end <= 1.0, what + " ends inside the clip, after its hits")
		if m.has("hop"):
			_expect(m.hop[0] < m.hop[1] and m.hop[1] <= 1.0 and m.hop[2] == base.hop[2], what + " hop stays in order")
		if leap >= 0.0:
			_expect(m.leap >= hit and m.leap < m.end, what + " breaker leaps after the hit")
		_expect(base.hash() == before, what + " left MOVES itself alone")
	kaykit.free()


## A real player: the heretic, on his Ab_ clips.
func _check_hero_in_play(game: Node, hero_script: GDScript, _have_rig: bool) -> void:
	var stage := Node3D.new()
	get_root().add_child(stage)
	var comic: CharacterBody3D = hero_script.new()
	stage.add_child(comic)
	await process_frame
	_expect(comic.anim.has_animation("Ab_L1"), "the hero has his clips")
	_expect(comic.model.find_child("ShamanHair", true, false) == null, "no added hair")
	_expect(comic.model.find_child("ShamanMantle", true, false) == null, "no added mantle")
	_expect(comic.model.find_child("AwakenEyes", true, false) == null, "no added eyes")
	_expect(comic.model.find_children("Coat", "Node3D", true, false).is_empty(), "no axe coats")
	_expect(comic._trails.size() == Look.HERO_AXES.size(), "a trail per axe")
	_expect(comic._axe_mesh() != null, "spirit casts have an axe")
	_check_run_clips(comic)
	_check_stances(comic)
	_check_drag(comic)
	_check_axe_auras(comic)
	for id: String in Look.HERO_MOVES:
		comic._hop_y0 = 0.0
		comic._start_attack(id)
		_expect(comic.anim.current_animation == Look.HERO_MOVES[id].clip, "%s plays %s" % [id, Look.HERO_MOVES[id].clip])
		_expect(is_equal_approx(comic._move_len, comic.anim.get_animation(Look.HERO_MOVES[id].clip).length), "%s times itself on its clip" % id)
		_expect(absf(comic._move.hits[0] - float(Look.HERO_MOVES[id].hit) / Look.HERO_MOVES[id].frames) < 0.0001, "%s hits on its frame" % id)
	comic.queue_free()
	await process_frame
	stage.queue_free()
	await process_frame


## Which run plays for a direction of travel, relative to where he faces (+Z, his left is +X).
func _check_run_clips(comic: CharacterBody3D) -> void:
	var look := Vector3(0, 0, 1)
	var cases := [[Vector3(0, 0, 1), "Run_F"], [Vector3(0, 0, -1), "Run_B"], [Vector3(1, 0, 0), "Strafe_L"], [Vector3(-1, 0, 0), "Strafe_R"]]
	for c: Array in cases:
		_expect(Look.run_clip(c[0], look, "") == c[1], "travel %s while facing +Z is %s" % [c[0], c[1]])
		_expect(comic.anim.has_animation(c[1]), "he has %s" % c[1])
		_expect(comic.anim.get_animation(c[1]).loop_mode == Animation.LOOP_LINEAR, "%s loops" % c[1])
		_expect(is_equal_approx(comic.anim.get_animation(c[1]).length, comic.anim.get_animation("Run_F").length), "%s shares the cycle" % c[1])
	var near := Vector3(1.0, 0, 1.1).normalized()  # just past the diagonal, on the run's side
	_expect(Look.run_clip(near, look, "Strafe_L") == "Strafe_L", "a strafe holds near the diagonal")
	_expect(Look.run_clip(Vector3(1.1, 0, 1.0).normalized(), look, "Run_F") == "Run_F", "a run holds near the diagonal")
	comic._facing_yaw = 0.0
	_expect(comic._turned(Vector3(1, 0, 0), 45.0).is_equal_approx(Vector3(sin(PI / 4.0), 0, cos(PI / 4.0))), "a turn stops at its limit")
	_expect(comic._turned(Vector3(1, 0, 0), 180.0).is_equal_approx(Vector3(1, 0, 0)), "a turn doesn't overshoot")
	_expect(not comic._mouse_aiming(), "headless: no mouse aim, so the checks and bot aim as before")


## He carries the axes: their heads aren't out in front of him in anything he holds.
func _check_stances(comic: CharacterBody3D) -> void:
	var skel: Skeleton3D = comic.model.find_children("*", "Skeleton3D", true, false)[0]
	for clip: String in ["Idle", "Idle_Ready", "Run_F", "Run_B", "Strafe_L", "Strafe_R", "2H_Melee_Idle", "Jump_Idle"]:
		comic.anim.play(clip, 0.0)
		for at: float in [0.0, 0.5]:
			comic.anim.seek(comic.anim.current_animation_length * at, true)
			for bone: String in Look.HERO_AXES:
				var i := skel.find_bone(bone)
				var mesh: Mesh = comic.model.find_child(Look.HERO_AXES[bone], true, false).mesh
				var head: Vector3 = skel.get_bone_global_pose(i) * skel.get_bone_global_rest(i).affine_inverse() * mesh.get_aabb().get_center()
				_expect(head.z < AXE_AHEAD_MAX, "%s: %s's axe isn't held out in front (%.2f m ahead at %.1f)" % [clip, bone, head.z, at])
	_expect(comic.anim.get_animation("Idle").loop_mode == Animation.LOOP_LINEAR, "Idle loops")
	_expect(comic.anim.get_animation(Look.HERO_READY).loop_mode == Animation.LOOP_LINEAR, "the guard loops")
	for clip: String in Look.HERO_FIDGETS:
		_expect(comic.anim.has_animation(clip), "he has %s" % clip)
		_expect(comic.anim.get_animation(clip).loop_mode == Animation.LOOP_NONE, "%s plays once" % clip)
	for id: String in Look.HERO_MOVES:
		var h: Dictionary = Look.HERO_MOVES[id]
		_expect(float(h.hit) / h.frames < MOVE_TAIL_FROM, "%s hits before its arms ease into the guard" % id)
	comic._ready_t = 1.0
	comic._comic_stand()
	_expect(comic.anim.current_animation == Look.HERO_READY, "after a fight he stands on guard")
	comic._ready_t = 0.0
	comic._fidget_t = 1.0
	comic._comic_stand()
	_expect(comic.anim.current_animation == "Idle", "then at ease")
	comic._fidget_t = 0.0
	comic._comic_stand()
	var fidget: String = comic.anim.current_animation
	_expect(fidget in Look.HERO_FIDGETS, "left standing, he fidgets")
	comic._comic_stand()
	_expect(comic.anim.current_animation == fidget, "a fidget plays out")
	comic.anim.stop()
	comic._comic_stand()
	_expect(comic.anim.current_animation == "Idle", "and he goes back to the idle")
	comic._start_attack("L1")
	_expect(comic._ready_t > 0.0, "an attack puts him on guard")
	comic._set_state(comic.State.MOVE)


## The ground mark a dragged blade draws (he rests with the tentacle, so no tip-on-floor pose).
func _check_drag(comic: CharacterBody3D) -> void:
	comic.anim.play("Idle", 0.0)
	comic.anim.seek(0.0, true)
	for el: String in Look.AXE_INFUSIONS:
		var auras: Array = Look.infuse_axes(comic.model, el)
		var m: Node = auras[0].mark
		var y: float = comic.global_position.y
		var start := Vector3(0.0, y, 0.0)
		_expect(m.points.is_empty(), "%s: no mark yet" % el)
		m.track(start, y)
		m.track(start + Vector3(0.02, 0, 0), y)
		_expect(m.points.size() == 1, "%s: a still blade adds nothing" % el)
		m.track(start + Vector3(0.6, 0, 0), y)
		m.track(start + Vector3(1.2, 0, 0), y)
		_expect(m.points.size() == 3, "%s: a moving blade draws" % el)
		m.track(start + Vector3(1.8, 2.0, 0), y)
		_expect(m.points.size() == 3, "%s: a lifted blade doesn't" % el)
		m.track(start + Vector3(2.4, 0, 0), y)
		_expect(m.points[3].fresh, "%s: and starts a new line when it lands" % el)
		m.tick(0.01)
		_expect(m.points.size() == 4, "%s: the mark stays a while" % el)
		m.tick(m.look.life + 0.1)
		_expect(m.points.is_empty(), "%s: then it's gone" % el)
		for aura: Node in auras:
			aura.free()


## The current element on both axes, for every element.
func _check_axe_auras(comic: CharacterBody3D) -> void:
	_expect(comic._coats.size() == Look.HERO_AXES.size(), "he starts with his element on his axe")
	for el: String in Look.AXE_INFUSIONS:
		var auras: Array = Look.infuse_axes(comic.model, el)
		_expect(auras.size() == Look.HERO_AXES.size(), "%s: an aura per axe" % el)
		for aura: Node in auras:
			_expect(aura.tongues.size() == aura.look.count, "%s: its tongues" % el)
			_expect(aura.drip != null, "%s: sheds motes" % el)
			var blade: float = aura._centre.length()
			for t: MeshInstance3D in aura.tongues:
				_expect(t.position.length() > blade * 0.4, "%s: a tongue sits out on the blade" % el)
			aura._process(0.1)
			aura._process(0.1)
			if aura.look.mode == "rise":
				var t: MeshInstance3D = aura.tongues[0]
				_expect(t.global_basis.y.normalized().y > 0.9, "%s: a still blade's flame stands up" % el)
			var small: float = aura.tongues[0].global_basis.y.length()
			aura.charge(true)
			aura._process(0.1)
			_expect(aura.tongues[0].global_basis.y.length() > small, "%s: bigger while Awakened" % el)
			aura.charge(false)
			aura.free()


func _role_clips(spec: Dictionary) -> Array:
	var kind: String = spec.get("attack_kind", "melee")
	var clips: Array = BY_ROLE[kind].duplicate()
	if spec.get("dodge_chance", 0.0) > 0.0:
		clips += BY_ROLE.dodge
	if spec.get("shield", false):
		clips += BY_ROLE.shield
	return clips


## False when the kind has no GLB.
func _check_model(kind: String, asks: Array) -> bool:
	var packed: PackedScene = Look.scene(kind)
	if packed == null:
		return false
	var model: Node = packed.instantiate()
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	_expect(player != null, "%s has an AnimationPlayer" % kind)
	for wanted: String in asks:
		var got: String = Look.clip(player, kind, wanted)
		# "" = deliberately keep the running clip (only the Warden's slam/nova/cage beats).
		_expect(got == "" or player.has_animation(got), "%s: %s -> %s" % [kind, wanted, got])
	for mat: String in Look.material_names(model):
		_expect(Look.known_material(mat), "%s: material %s has tones" % [kind, mat])
	_expect(_has_g(model), "%s: `g` imported into COLOR (run tools/comic_glb.py)" % kind)
	_check_facing(model, kind)
	model.free()
	return true


## Models must face +Z like KayKit's (facing yaw = atan2(dir.x, dir.z)): jaw ahead of head.
func _check_facing(model: Node, kind: String) -> void:
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	# Bone positions can't show a turned skeleton node: they're all relative to it.
	var ahead := Vector3(0, 0, 1)
	var node: Node = skel
	while node != null:
		if node is Node3D:
			ahead = node.basis * ahead
		node = node.get_parent()
	_expect(ahead.z > 0.99, "%s: skeleton sits square in the model (its +Z goes to %s)" % [kind, ahead])
	var head := skel.find_bone("head")
	var jaw := skel.find_bone("jaw")
	if head >= 0 and jaw >= 0:
		_expect(skel.get_bone_global_rest(jaw).origin.z > skel.get_bone_global_rest(head).origin.z, "%s faces +Z" % kind)


## tools/comic_glb.py moved `g` to COLOR_0: some vertex must differ from white. If the
## dummy renderer can't hand arrays back there is nothing to judge, so that passes.
func _has_g(model: Node) -> bool:
	var readable := false
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(i)
			if arrays.is_empty() or arrays[Mesh.ARRAY_COLOR] == null:
				continue
			readable = true
			for c: Color in arrays[Mesh.ARRAY_COLOR]:
				if c.r < 0.99:
					return true
	if not readable:
		print("[comic_check] note: mesh arrays not readable here, `g` not judged")
	return not readable


## Every piece the game can load exists in the comic set, drop-in: same bounds and the
## nodes code reaches for. The names come from the scripts, so a new piece can't slip by.
func _check_dungeon() -> void:
	var pieces := _pieces_in_sources()
	_expect(pieces.size() >= 14, "source scan found the dungeon pieces (%d)" % pieces.size())
	for f in DirAccess.get_files_at("res://assets/kaykit/dungeon"):
		if f.ends_with(".glb") and f.get_basename() not in pieces:
			pieces.append(f.get_basename())
	var missing := []
	for piece: String in pieces:
		if not ResourceLoader.exists(Look.PIECE_PATH % piece):
			missing.append(piece)
			continue
		var comic: Node3D = load(Look.PIECE_PATH % piece).instantiate()
		var kaykit: Node3D = load(Look.KAYKIT_PIECE_PATH % piece).instantiate()
		var a: Vector3 = _bounds(comic).size
		var b: Vector3 = _bounds(kaykit).size
		_expect(a.distance_to(b) < PIECE_SIZE_SLACK, "%s: size %s vs KayKit %s" % [piece, a, b])
		for mat: String in Look.material_names(comic):
			_expect(Look.known_material(mat), "%s: material %s has tones" % [piece, mat])
		for mi: MeshInstance3D in comic.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				_expect(mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR] != null, "%s: `g` imported" % piece)
		comic.free()
		kaykit.free()
	_expect(missing.is_empty(), "comic set has every dungeon piece, missing %s" % [missing])
	_expect(Look.comic_piece("no_such_piece") == null, "absent piece: null, caller keeps KayKit")


## Piece names from every script that loads one.
func _pieces_in_sources() -> Array:
	var found := []
	var quoted := RegEx.create_from_string("\"([a-zA-Z_]+)\"")
	for line in FileAccess.get_file_as_string("res://scripts/main.gd").split("\n"):
		if "_place(" in line or "var piece :=" in line:
			for m in quoted.search_all(line):
				if m.get_string(1) not in found:
					found.append(m.get_string(1))
	return found


func _bounds(root: Node3D) -> AABB:
	var ab := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		ab = mi.mesh.get_aabb() if first else ab.merge(mi.mesh.get_aabb())
		first = false
	return ab


## The game culls and Blender doesn't, so a stone facing down never shows in a Blender render:
## the floor just turns into a checker of dark grout.
func _check_floors_face_up() -> void:
	for piece: String in ["floor_tile_large", "floor_tile_large_rocks", "floor_tile_big_grate", "floor_tile_big_spikes"]:
		var n: Node = load("res://assets/comic/dungeon/%s.glb" % piece).instantiate()
		var stones := 0
		var down := 0
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i)
				if mat == null or mat.resource_name != "comic_floor":
					continue
				var normals: PackedVector3Array = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_NORMAL]
				stones += normals.size()
				for v in normals:
					if v.y < -0.5:  # the grate's stones have upright sides
						down += 1
		_expect(stones > 0, "%s has floor stones" % piece)
		_expect(down == 0, "%s: no floor stone faces down (%d vertices do)" % [piece, down])
		n.free()


## The text layer's logic: words escalate by tier, reduced flashing drops the pop and the
## second word in a burst. Nothing here sees a pixel.
func _check_fx(game: Node) -> void:
	var Comic: GDScript = load("res://scripts/comic_fx.gd")
	var fx: CanvasLayer = Comic.new()
	get_root().add_child(fx)
	await process_frame
	_expect(fx._font is Font, "Bangers loads")
	_expect(Comic.WORDS.size() == load("res://scripts/fx.gd").CHAIN_TIERS.size() + 1, "one word list per chain tier")
	for s: Array in [Comic.WORD_SCALE, Comic.WORDS]:
		_expect(s.size() == Comic.WORDS.size(), "tier tables line up")
	for i in Comic.WORD_SCALE.size() - 1:
		_expect(Comic.WORD_SCALE[i] < Comic.WORD_SCALE[i + 1], "words grow with the tier")
	var saved_reduce: bool = game.reduce_flashing
	game.reduce_flashing = false
	game.combo_count = 0
	Comic.hit(Vector3.ZERO, false)
	var first: Label = fx._words[0]
	_expect(first.visible and first.text in Comic.WORDS[0], "tier 0 hit shows a tier 0 word")
	Comic.hit(Vector3.ZERO, false)
	_expect(not fx._words[1].visible, "second hit inside the gap shows nothing")
	fx._last_word_ms = -100000
	game.combo_count = 35
	Comic.hit(Vector3.ZERO, false)
	_expect(fx._words[1].text in Comic.WORDS[3], "tier 3 chain shows a tier 3 word")
	game.combo_count = 0
	_expect(Comic.word_scale(2, false) > 1.0, "normal words pop")
	_expect(Comic.word_scale(2, true) == 1.0, "reduced flashing: no pop")
	game.reduce_flashing = saved_reduce
	fx.free()
	Comic.hit(Vector3.ZERO, false)
	_expect(true, "no instance: calls do nothing")


## Every clip name the scripts ask for must be classified above.
func _scan_sources() -> void:
	var known: Array = COMMON + BOSS_ONLY + ["Running_A", "Running_C", "Walking_D_Skeletons"]
	for clips: Array in BY_ROLE.values():
		known += clips
	var re := RegEx.create_from_string("(?:_play|_hold_clip|get_animation)\\(\"([A-Za-z0-9_]+)\"")
	for path in ["res://scripts/enemy.gd", "res://scripts/boss.gd"]:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			_expect(m.get_string(1) in known, "%s asks for %s, unknown to this test" % [path.get_file(), m.get_string(1)])


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("[comic_check] FAIL ", what)
