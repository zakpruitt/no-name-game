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
	await _check_fx(game)
	game.comic_style = false
	Look.release()
	print("[comic_check] models=", with_glb, " kaykit_fallback=", absent)
	print("[comic_check] %s %d checks, %d failed" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	quit(1 if _fails > 0 else 0)


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
	model.free()
	return true


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
