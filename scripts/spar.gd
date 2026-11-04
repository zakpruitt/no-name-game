extends Node
## Sparring: `--spar=minion|rogue|shield|warrior` puts one live foe of that type (enemy_types.TYPES) in the
## training room next to the dummies, to try strings on something that moves, dodges or blocks. It hits
## the hero at DAMAGE_SCALE of its damage and comes back RESPAWN s after it dies. Off by default; the
## autotest prints `[spar] type= hits_taken= kills=` at the end when it's on. main._start_training calls
## start(); preload it (no class_name, so a checkout needs no re-import).

const KINDS := ["minion", "rogue", "shield", "warrior"]
const FLAG := "--spar="
const DAMAGE_SCALE := 1.0 / 3.0
const SPOT := Vector3(0.0, 0.0, -8.0)  # from the hero, beyond the dummies
const RESPAWN := 1.5  # s

var kind := ""
var foe: Node
var hits_taken := 0  # over every foe it has put up
var kills := 0
var _main: Node


## The spar kind asked for in `args`, or "" (none, or not one of KINDS).
static func kind_from(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with(FLAG):
			var k := arg.substr(FLAG.length())
			if k in KINDS:
				return k
			push_warning("--spar: '%s' is not one of %s" % [k, KINDS])
	return ""


## Starts sparring if the command line asks for it; returns the spar node or null.
static func start(main: Node, args := OS.get_cmdline_user_args()) -> Node:
	var k := kind_from(args)
	if k == "":
		return null
	var s: Node = load("res://scripts/spar.gd").new()
	s.name = "Spar"
	s.kind = k
	s._main = main
	main.add_child(s)
	s.spawn()
	print("[spar] sparring a %s at 1/%d damage" % [k, roundi(1.0 / DAMAGE_SCALE)])
	return s


func spawn() -> void:
	foe = _main._spawn(kind, false, _main.player.global_position + SPOT)
	foe.attack_damage *= DAMAGE_SCALE
	foe.blast_enemy_damage *= DAMAGE_SCALE
	foe.set_meta("spar", true)
	foe.died.connect(_on_died)


## Hits on the live foe plus every one before it.
func total_hits() -> int:
	return hits_taken + (foe.hits_taken if is_instance_valid(foe) else 0)


func _on_died(e: Node) -> void:
	kills += 1
	hits_taken += e.hits_taken
	foe = null
	get_tree().create_timer(RESPAWN).timeout.connect(func() -> void:
		if is_inside_tree() and is_instance_valid(_main.player):
			spawn())


func report() -> void:
	print("[spar] type=%s hits_taken=%d kills=%d" % [kind, total_hits(), kills])
