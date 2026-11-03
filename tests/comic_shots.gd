extends SceneTree
## The one command that captures everything about Game.comic_style never yet seen:
##   godot --path . -s tests/comic_shots.gd
## About a minute. Opens a window. Saves user://comic_shots/NN_name.png and INDEX.txt,
## which says what each shot should show. Read the console too: a shader that fails to
## compile only ever reports there, and the mesh then draws magenta or not at all.
## Sets the flag for this process only; settings, records and hints aren't written.
##
## Under --headless every stage runs but no image is saved, which proves the stages
## themselves don't error (and nothing about the look).

const DIR := "user://comic_shots"
const GAME_VIEW := Vector3(0.0, 13.0, 9.5)  # camera_rig.offset
const CLOSE_VIEW := GAME_VIEW * 0.42
const FAR_VIEW := GAME_VIEW * 1.5
const SETTLE := 0.15
const RISE := 1.2  # enemies are in State.SPAWN for 1 s
const CLIP_FPS := 24.0
## A clip worth seeing per kind, besides idle: [clip, frame].
const POSES := {
	"minion": [["1H_Melee_Attack_Chop", 13]],
	"shield": [["Block_Hit", 2], ["1H_Melee_Attack_Chop", 16]],
	"bomber": [["Bomb_Windup", 22]],
	"necromancer": [["Spellcast_Summon", 12]],
}

# Loaded at run time: naming the classes here compiles them before the Game autoload exists.
var _look_script: GDScript
var _main: Node
var _game: Node
var _cam: Camera3D
var _n := 0
var _index := PackedStringArray()
var _headless := false


func _initialize() -> void:
	_headless = DisplayServer.get_name() == "headless"
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_game = get_root().get_node("Game")
	_look_script = load("res://scripts/comic_look.gd")
	_game.save_hints = false
	_game.skip_title = true
	_game._comic_cli = true
	_game._hints_seen = _game.HINTS.keys()  # no hint text over the shots
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await create_timer(0.3).timeout
	_clear_enemies()
	_main._queue.clear()
	_cam = Camera3D.new()
	_cam.fov = 42.0
	_main.add_child(_cam)

	await _room()
	await _pieces()
	await _lineup()
	await _each_enemy()
	await _boss()
	await _hero()
	await _dots()
	await _ink_and_flash()
	await _text()
	await _props()

	if not _headless:
		var f := FileAccess.open(DIR + "/INDEX.txt", FileAccess.WRITE)
		f.store_string("\n".join(_index) + "\n")
		f.close()
	_game.stop_all_sfx()
	print("[comic_shots] %d stages shot%s" % [_n, " (headless: nothing saved)" if _headless else ", see " + ProjectSettings.globalize_path(DIR)])
	await create_timer(0.2).timeout
	quit()


## Lighting, shadows and the dungeon as the player sees it.
func _room() -> void:
	_use_game_camera()
	await create_timer(SETTLE).timeout
	_shot("room_game_view", "Compare comic_poc/out/env/room_game.png. Dark indigo, hard black shadows falling up and right, halftone on the back wall, stepped flames with no glow, no warm light pools. Hero is the only other thing in frame.")
	_look(Vector3(0.0, 0.0, -11.0), GAME_VIEW * 0.7)
	await create_timer(SETTLE).timeout
	_shot("room_back_wall", "Stone seams, per-stone tone differences, 3 px ink on banners, torches and wall. No shadow acne or blotches from the ink hull.")
	_look(Vector3.ZERO, GAME_VIEW * 2.0)
	await create_timer(SETTLE).timeout
	_shot("room_whole", "Whole arena: every wall piece meets its neighbour, corners and rubble line up, floor seams continue across tiles.")


## All 25 pieces, in a grid over the floor.
func _pieces() -> void:
	var root := Node3D.new()
	_main.add_child(root)
	root.position = Vector3(0.0, 0.0, 40.0)  # past the near wall, nothing else in frame
	var i := 0
	for f in DirAccess.get_files_at("res://assets/kaykit/dungeon"):
		if not f.ends_with(".glb"):
			continue
		var n: Node3D = _look_script.piece(f.get_basename())
		n.position = Vector3((i % 5 - 2) * 7.0, 0.0, (i / 5 - 2) * 7.0)
		root.add_child(n)
		i += 1
	_look(root.position, GAME_VIEW * 3.0)
	await create_timer(SETTLE).timeout
	_shot("pieces_all", "Every dungeon piece, one each, on the void. Magenta or KayKit textures = a missing material or piece.")
	root.free()


func _lineup() -> void:
	_clear_enemies()
	var kinds: Array = _main.ENEMY_TYPES.keys()
	var spawned := []
	for i in kinds.size():
		spawned.append(_main._spawn(kinds[i], false, _at(Vector3((i - (kinds.size() - 1) * 0.5) * 2.4, 0.0, 3.0))))
	await create_timer(RISE).timeout
	for e: Node3D in spawned:
		_hold(e, "Idle_Combat", 8)
	_use_game_camera()
	await create_timer(SETTLE).timeout
	_shot("enemies_lineup", "Compare comic_poc/out/enemies/lineup_game.png. All facing the camera, feet on the floor, sizes right against the hero, necro glow in three flat tones.")


func _each_enemy() -> void:
	for kind: String in _main.ENEMY_TYPES:
		_clear_enemies()
		var e: Node3D = _main._spawn(kind, false, _at(Vector3(0.0, 0.0, 3.0)))
		await create_timer(RISE).timeout
		_hold(e, "Idle_Combat", 8)
		_look(e.global_position + Vector3.UP, CLOSE_VIEW)
		await create_timer(SETTLE).timeout
		var has_comic: bool = e.comic_kind != ""
		_shot("enemy_%s" % kind, "%s: %s. Cut tones, dots on the mid tone, hatching in shadow, thick ink." % [kind, "comic model" if has_comic else "KayKit fallback, no comic GLB"])
		for pose: Array in POSES.get(kind, []):
			if has_comic:
				_hold(e, pose[0], pose[1])
				await create_timer(SETTLE).timeout
				_shot("enemy_%s_%s" % [kind, pose[0]], "%s at frame %d. Pose reads, weapon or prop stays in the hand." % [pose[0], pose[1]])


func _boss() -> void:
	_clear_enemies()
	_main._spawn_boss()
	await create_timer(RISE).timeout
	var boss: Node3D = null
	for e: Node3D in _main.get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_boss"):
			boss = e
		else:
			e.queue_free()
	boss.set_physics_process(false)
	boss.global_position = _at(Vector3(0.0, 0.0, -6.0))
	_hold(boss, "Idle_Combat", 8)
	_look(boss.global_position + Vector3.UP * 1.5, GAME_VIEW * 0.75)
	await create_timer(SETTLE).timeout
	_shot("boss_idle", "Compare comic_poc/out/enemies/warden_game.png. 3.2 m tall, about twice the hero. Heart in three flat greens.")
	if boss.comic_kind != "":
		for attack: String in boss.COMIC_ATTACKS:
			var c: Array = boss.COMIC_ATTACKS[attack]
			_hold(boss, c[0], int(c[1]))
			await create_timer(SETTLE).timeout
			_shot("boss_%s" % attack, "%s on its hit frame." % c[0])
		_hold(boss, "Enrage", 20)
		await create_timer(SETTLE).timeout
		_shot("boss_enrage", "Enrage: arms wide, heart blazing.")


## The same foe near and far: the dots must stay one size on screen.
## Him, every Ab_ clip on its hit frame, and hero_look's Ascendancy gear on his rig.
func _hero() -> void:
	_clear_enemies()
	var p: Node3D = _main.player
	p.set_physics_process(false)
	var was_rot: float = p.model.rotation.y
	p.model.rotation.y = 0.0
	p.anim.play("Idle", 0.0)
	p.anim.seek(0.0, true)
	p.anim.speed_scale = 0.0
	_look(p.global_position + Vector3.UP * 1.2, CLOSE_VIEW)
	await create_timer(SETTLE).timeout
	_shot("hero_idle", "Compare comic_poc/out renders. His hair, mantle, feathers and two axes are the model's, nothing floats beside them. Toon tones, hull ink, no magenta. Head and cape aren't cut by the hull.")
	for id: String in _look_script.HERO_MOVES:
		var h: Dictionary = _look_script.HERO_MOVES[id]
		p.anim.play(h.clip, 0.0)
		p.anim.seek((h.hit - 1) / CLIP_FPS, true)
		p.anim.speed_scale = 0.0
		await create_timer(SETTLE).timeout
		_shot("hero_%s" % h.clip, "%s at its hit frame: contact pose, axes in the hands." % h.clip)
	p.anim.play("Idle", 0.0)
	p.anim.speed_scale = 0.0
	var hero_look: GDScript = load("res://scripts/hero_look.gd")
	for path: String in hero_look.FORMS:
		var form: Node3D = hero_look.add_form(p.model, path)
		await create_timer(SETTLE).timeout
		_shot("hero_form_%s" % path, "%s Ascendancy gear. Tuned on KayKit's head and upright bones, so expect it tilted or off the head: this says how far." % path)
		form.queue_free()
		await process_frame
	p.model.rotation.y = was_rot
	p.set_physics_process(true)


func _dots() -> void:
	_clear_enemies()
	var e: Node3D = _main._spawn("minion", false, _at(Vector3(0.0, 0.0, 3.0)))
	await create_timer(RISE).timeout
	_hold(e, "Idle_Combat", 8)
	_look(e.global_position + Vector3.UP, CLOSE_VIEW)
	await create_timer(SETTLE).timeout
	_shot("dots_near", "Halftone close up. Same dot size in pixels as dots_far.")
	_look(e.global_position + Vector3.UP, FAR_VIEW)
	await create_timer(SETTLE).timeout
	_shot("dots_far", "Halftone far away. Dots haven't shrunk; ink line is the same width in pixels.")


## The hit flash and rim overlays and the pillar fade, over the comic materials.
func _ink_and_flash() -> void:
	_clear_enemies()
	var e: Node3D = _main._spawn("warrior", false, _at(Vector3(0.0, 0.0, 3.0)))
	await create_timer(RISE).timeout
	_hold(e, "Idle_Combat", 8)
	_look(e.global_position + Vector3.UP, CLOSE_VIEW)
	load("res://scripts/fx.gd").flash(e.model, 0.5)
	await create_timer(0.1).timeout
	_shot("hit_flash", "White hit overlay covers the toon material, ink hull not poking through oddly.")
	await create_timer(0.5).timeout
	var pillar: Node3D = _look_script.piece("pillar_decorated")
	pillar.position = e.global_position + Vector3(2.5, 0.0, 0.0)
	_main.add_child(pillar)
	for mi: MeshInstance3D in pillar.find_children("*", "MeshInstance3D", true, false):
		mi.transparency = 0.7  # what main._fade_occluders does to a blocking pillar
	await create_timer(SETTLE).timeout
	_shot("pillar_faded", "Occluder fade: pillar see-through at 70%. Its ink hull must fade too, not stay as a black shell.")
	pillar.free()


func _text() -> void:
	_clear_enemies()
	_use_game_camera()
	var fx: Node = null
	for n in _main.get_children():
		if n is CanvasLayer and n.has_method("_word"):
			fx = n
	var hero: Vector3 = _main.player.global_position
	for tier in 4:
		fx._last_word_ms = -100000
		fx._word(hero + Vector3((tier - 1.5) * 4.0, 0.0, 2.0), tier)
	await create_timer(0.2).timeout
	_shot("words_tiers", "Bangers. Four words growing left to right, yellow with a hard red offset and ink outline.")
	await create_timer(1.0).timeout
	var saved: bool = _game.reduce_flashing
	_game.reduce_flashing = true  # in memory only
	fx._last_word_ms = -100000
	fx._word(hero + Vector3(0.0, 0.0, 2.0), 3)
	await create_timer(0.25).timeout
	_shot("reduced_flashing", "Setting on: word dimmer, not popping.")
	_game.reduce_flashing = saved
	await create_timer(1.0).timeout


## Room props that build themselves from pieces, and their coloured lights on toon.
func _props() -> void:
	var at: Vector3 = _at(Vector3(0.0, 0.0, 3.0))
	var shrine: Node3D = load("res://scripts/shrine_prop.gd").new()
	_main.add_child(shrine)
	shrine.position = at + Vector3(-3.0, 0.0, 0.0)
	shrine._light.light_energy = 2.0
	var vault: Node3D = load("res://scripts/vault_prop.gd").new()
	vault.color = Color(1.0, 0.7, 0.2)
	_main.add_child(vault)
	vault.position = at + Vector3(3.0, 0.0, 0.0)
	vault._light.light_energy = 2.5
	var trap: Node3D = load("res://scripts/spike_trap.gd").new()
	_main.add_child(trap)
	trap.position = at + Vector3(0.0, 0.01, 5.0)
	trap.set_physics_process(false)
	await process_frame
	trap._spikes.position.y = 0.0
	_look(at, GAME_VIEW * 0.8)
	await create_timer(SETTLE).timeout
	_shot("props_lights", "Shrine and vault glow. Toon tones ignore light colour, so expect a stepped brighter pool and no tint on stone. Decide if that's acceptable. Spike trap up, spikes on their tile.")
	shrine.free()
	vault.free()
	trap.free()


func _at(offset: Vector3) -> Vector3:
	return _main.player.global_position + offset


func _clear_enemies() -> void:
	for e: Node in _main.get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()


## Stop the AI and freeze the clip on one frame, facing the camera.
func _hold(e: Node3D, clip: String, frame: int) -> void:
	e.set_physics_process(false)
	e.model.rotation.y = 0.0
	var name_on_model: String = _look_script.clip(e.anim, e.comic_kind, clip) if e.comic_kind != "" else clip
	if name_on_model == "" or not e.anim.has_animation(name_on_model):
		return
	e.anim.play(name_on_model, 0.0)
	e.anim.seek(frame / CLIP_FPS, true)
	e.anim.speed_scale = 0.0


func _look(target: Vector3, view: Vector3) -> void:
	_cam.look_at_from_position(target + view, target, Vector3.UP)
	_cam.current = true


func _use_game_camera() -> void:
	_game.camera_rig.camera.current = true


func _shot(shot_name: String, check: String) -> void:
	_n += 1
	var file := "%02d_%s.png" % [_n, shot_name]
	_index.append("%s: %s" % [file, check])
	if not _headless:
		get_root().get_texture().get_image().save_png(DIR + "/" + file)
	print("[comic_shots] ", file)
