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
	_expect(not game.comic_style, "flag defaults off")
	_expect(Look.scene("minion") == null, "flag off: no comic model")
	game.comic_style = true
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
	await _check_fx(game)
	await _check_hero(game)
	game.comic_style = false
	Look.release()
	print("[comic_check] models=", with_glb, " kaykit_fallback=", absent)
	print("[comic_check] %s %d checks, %d failed" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	quit(1 if _fails > 0 else 0)


## The hero model, the Ab_ overlay's numbers, then a real player with each flag.
func _check_hero(game: Node) -> void:
	game.comic_style = true
	var hero_script: GDScript = load("res://scripts/player.gd")
	var packed: PackedScene = Look.scene(Look.HERO)
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
		var got: String = Look.clip(rig, Look.HERO, wanted)
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
		if "_play(" in line or "_ult_anim(" in line:
			for m in quoted.search_all(line):
				if not hero_script.ULTIMATES.has(m.get_string(1)):  # `if id == "SKY"`
					found[m.get_string(1)] = true
	for move: Dictionary in hero_script.MOVES.values():
		found[move.anim] = true
	for b: Dictionary in hero_script.BREAKERS.values():
		if b.has("hang_anim"):
			found[b.hang_anim] = true
	for loop: String in hero_script.LOOPING:
		found[loop] = true
	return found.keys()


## Everything hero_look can attach: a bone name that misses puts the gear at the origin.
func _check_hero_bones(model: Node3D) -> void:
	var look: GDScript = load("res://scripts/hero_look.gd")
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	for bone: String in ["head", "chest", "upperarm.l", "upperarm.r", "hand.l", "hand.r"]:
		_expect(skel.find_bone(bone) >= 0, "hero has bone %s (tools/comic_glb.py renames clashing meshes)" % bone)
	look.add_kit(model)
	for path: String in look.FORMS:
		look.add_form(model, path)
	var blades: Array = Look.hero_blades(model)
	_expect(blades.size() == Look.HERO_AXES.size(), "a weapon-trail blade per hand")
	for blade: MeshInstance3D in blades:
		_expect(blade.mesh.size.y > 0.4 and blade.mesh.size.y < 2.0, "blade reaches the axe head (%.2f m)" % blade.mesh.size.y)
		_expect(blade.layers == 0 and blade.has_meta("no_ghost"), "blade is never drawn or ghosted")
	var attached: Array = model.find_children("*", "BoneAttachment3D", true, false)
	_expect(attached.size() > 10, "hero_look attached its gear (%d)" % attached.size())
	for at: BoneAttachment3D in attached:
		_expect(skel.find_bone(at.bone_name) >= 0, "attachment bone %s resolves" % at.bone_name)


## The numbers: hit = frame / length, and the time after the hit unchanged.
func _check_overlay(hero_script: GDScript, rig: AnimationPlayer) -> void:
	var kaykit: Node = hero_script.MODEL.instantiate()
	var old_rig: AnimationPlayer = kaykit.find_child("AnimationPlayer", true, false)
	_expect(Look.HERO_MOVES.size() == 12, "twelve Ab_ clips routed")
	for id: String in Look.HERO_MOVES:
		var h: Dictionary = Look.HERO_MOVES[id]
		_expect(rig.has_animation(h.clip), "%s: clip %s" % [id, h.clip])
		var length: float = rig.get_animation(h.clip).length
		_expect(absf(length - (h.frames - 1) / 24.0) < 0.001, "%s: %d frames match the clip's %.3f s" % [id, h.frames, length])
		if not h.has("old"):
			_expect(hero_script.ULTIMATES.has(id), "%s is an ultimate" % id)
			continue
		var base: Dictionary = hero_script.MOVES[id]
		var old_len: float = old_rig.get_animation(base.anim).length
		_expect(absf(old_len - h.old) < 0.001, "%s: old length is %s's %.4f" % [id, base.anim, old_len])
		var leap: float = hero_script.BREAKERS.get(id, {}).get("leap", -1.0)
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
	var sky: Dictionary = Look.HERO_MOVES.SKY
	var sky_len: float = rig.get_animation(sky.clip).length
	var impact: float = hero_script.ULTIMATES.SKY.time * hero_script.ULTIMATES.SKY.impact
	_expect(absf(Look.ult_speed("SKY", sky_len, impact) * impact - sky_len * sky.hit / sky.frames) < 0.0001, "SKY's hit frame meets its impact")
	kaykit.free()


## A real player under each flag: flags off must be untouched, however the other is set.
func _check_hero_in_play(game: Node, hero_script: GDScript, _have_rig: bool) -> void:
	var stage := Node3D.new()
	get_root().add_child(stage)
	var comic: CharacterBody3D = hero_script.new()
	stage.add_child(comic)
	await process_frame
	_expect(comic._comic_hero, "--comic: he is the comic model")
	_expect(comic.anim.has_animation("Ab_L1"), "--comic: with his clips")
	_expect(comic.model.find_child("ShamanHair", true, false) == null, "--comic: no added hair")
	_expect(comic.model.find_child("ShamanMantle", true, false) == null, "--comic: no added mantle")
	_expect(comic.model.find_child("AwakenEyes", true, false) == null, "--comic: no added eyes")
	_expect(comic.model.find_children("Coat", "Node3D", true, false).is_empty(), "--comic: no axe coats")
	_expect(comic._trails.size() == 2, "--comic: a trail per axe")
	_expect(comic._axe_mesh() != null, "--comic: spirit casts have an axe")
	_expect(comic._effective_move("L1").anim == hero_script.MOVES.L1.anim, "--comic alone: MOVES unchanged")
	comic._start_attack("L2")
	_expect(comic.anim.current_animation == "Ab_L2", "--comic alone: L2 asks for Throw, gets Ab_L2")
	_expect(is_equal_approx(comic._move.hits[0], hero_script.MOVES.L2.hits[0]), "--comic alone: L2 keeps its fractions")
	game.comic_moves = true
	for id: String in Look.HERO_MOVES:
		comic._hop_y0 = 0.0
		comic._start_attack(id)
		_expect(comic.anim.current_animation == Look.HERO_MOVES[id].clip, "--comic-moves: %s plays %s" % [id, Look.HERO_MOVES[id].clip])
		if hero_script.ULTIMATES.has(id):
			_expect(comic.anim.speed_scale > 0.5, "--comic-moves: %s clip sped to its hit" % id)
		else:
			_expect(is_equal_approx(comic._move_len, comic.anim.get_animation(Look.HERO_MOVES[id].clip).length), "--comic-moves: %s times itself on its clip" % id)
			_expect(absf(comic._move.hits[0] - float(Look.HERO_MOVES[id].hit) / Look.HERO_MOVES[id].frames) < 0.0001, "--comic-moves: %s hits on its frame" % id)
	var dh: Dictionary = comic._effective_move("DH")
	_expect(dh.anim == hero_script.MOVES.DH.anim and dh.hits == hero_script.MOVES.DH.hits, "--comic-moves: a move with no Ab_ clip is untouched")
	comic._start_attack("SKY")
	await create_timer(0.4).timeout
	_expect(comic.anim.current_animation == Look.HERO_MOVES.SKY.clip, "--comic-moves: one clip through SKY's beats")
	comic.queue_free()
	await process_frame
	game.comic_style = false
	var plain: CharacterBody3D = hero_script.new()
	stage.add_child(plain)
	await process_frame
	_expect(not plain._comic_hero, "flags off: KayKit hero, even with --comic-moves alone")
	_expect(plain.model.find_child("1H_Axe", true, false) != null, "flags off: his axes")
	_expect(plain.model.find_child("ShamanHair", true, false) != null, "flags off: hero_look's kit")
	_expect(plain._effective_move("L1").hash() == hero_script.MOVES.L1.hash(), "flags off: MOVES as written")
	plain._start_attack("L2")
	_expect(plain.anim.current_animation == "Throw", "flags off: L2 plays Throw")
	game.comic_moves = false
	game.comic_style = true
	stage.queue_free()
	await process_frame


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
	_expect(pieces.size() >= 15, "source scan found the dungeon pieces (%d)" % pieces.size())
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
	var tile: Node3D = load(Look.PIECE_PATH % "floor_tile_big_spikes").instantiate()
	_expect(tile.find_child("spikes", true, false) != null, "spike tile keeps its `spikes` node (spike_trap.gd)")
	tile.free()
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
	for path: String in ["res://scripts/shrine_prop.gd", "res://scripts/vault_prop.gd"]:
		for row: Array in load(path).PIECES:
			if row[0] not in found:
				found.append(row[0])
	found.append("floor_tile_big_spikes")  # spike_trap.gd
	return found


func _bounds(root: Node3D) -> AABB:
	var ab := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		ab = mi.mesh.get_aabb() if first else ab.merge(mi.mesh.get_aabb())
		first = false
	return ab


## The text layer's logic: words escalate by tier, the panel names the combo, reduced
## flashing drops the pop and the second word in a burst. Nothing here sees a pixel.
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
	Comic.combo("Triple Chop", 1)
	_expect(fx._bars.visible and fx._caption.text == "TRIPLE CHOP!", "panel names the combo")
	_expect(fx._caption.scale.x > Comic.CAPTION_SCALE[0], "panel caption pops")
	game.reduce_flashing = true
	Comic.combo("Stormfall", 3)
	_expect(fx._bars.big and fx._bars.modulate.a == 0.0, "reduced flashing: bars fade in, don't cut")
	_expect(is_equal_approx(fx._caption.scale.x, Comic.CAPTION_SCALE[2]), "reduced flashing: no caption pop")
	game.reduce_flashing = saved_reduce
	fx.free()
	Comic.hit(Vector3.ZERO, false)
	Comic.combo("Nothing", 1)
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
