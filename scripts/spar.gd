extends Node
## Sparring: `--spar=minion|rogue|shield|warrior|archer|mage` puts one live foe of that type (enemy_types.TYPES) in the
## training room next to the dummies, to try strings on something that moves, dodges or blocks. It hits
## the hero at DAMAGE_SCALE of its damage and comes back RESPAWN s after it dies. Off by default; the
## autotest prints `[spar] type= hits_taken= kills=` at the end when it's on. main._start_training calls
## start(); preload it (no class_name, so a checkout needs no re-import).

const ENEMY := preload("res://scripts/enemy.gd")
const KINDS := ["minion", "rogue", "shield", "warrior", "archer", "mage"]
const RANGED := ["archer", "mage"]  # (their bolts parry back: counter.gd)
const FLAG := "--spar="
const DAMAGE_SCALE := 1.0 / 3.0
## Spar pass two: its hp is HP_SCALE times its kind's (`--spar-hp=N` for one run). At 1x the warrior (75) died in 37 of
## 49 strings, mostly to the string's first breaker; a Ricochet onto the gallows (146) killed it on the splat, so the
## hang, the Snap and Galvanize's latch on it were never seen, and a hold string often met a foe with 6 hp left.
## Melee kinds only: a shooter at 3x lived to shoot him ~20 times a run and cost the autotest a breaker.
const HP_SCALE := 3.0
const HP_FLAG := "--spar-hp="
const SPOT := Vector3(0.0, 0.0, -6.0)  # from the hero, beyond the dummies (8 m: it walked in for 2 s after each respawn)
const RESPAWN := 0.8  # s (1.5: with the 1 s spawn and the walk in, the foe was away for 40-56% of a film)
const WALL_GAP := 2.5  # m: it spawns at least this far inside the room's walls (SPOT from him by the back wall was outside)
const MIN_GAP := 4.0  # m from him at least
const FALL_Y := -6.0  # m: below this, and not in a move's hands (Abyss carries it 4 m under), it fell out of the room; put back at spot() (`strays`)

var kind := ""
var foe: Node
var hits_taken := 0  # over every foe it has put up
var kills := 0
var _blocks0 := -1  # enemy.blocks (a static count) when sparring began
var _hp := -1.0  # his hp last frame
var cuts := 0  # its windups a hold cut (enemy.held_cuts)
var hurts := 0  # times he lost hp while sparring (its strikes; nothing else hits him in training)
var strays := 0  # times it fell out of the room and was put back
## Spar pass two, his hurt measured in play: hurts that landed mid-string (a move, a hold or a breaker under way, or one
## within MID_GAP s: `mid=`; the combo count runs on across the bot's strings, so it can't tell), and the real ms he spent in State.HURT each time (`hurt_ms=` avg/max).
var hurts_mid := 0
const MID_GAP := 0.6
var _busy_ms := -100000  # last ms he was in a move, a hold or a breaker
var _state_prev := -1
var _hurt_from := -1  # ms he went into HURT, while he is in it
var _hurt_ms: Array[int] = []
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


## Where it comes in: SPOT from him, kept WALL_GAP inside the room; on his other side if the wall would put it
## closer than MIN_GAP (it came in on top of him and struck at once).
func spot() -> Vector3:
	var me: Vector3 = _main.player.global_position
	var lim: float = _main.ARENA_HALF - WALL_GAP
	var at := me + SPOT
	at = Vector3(clampf(at.x, -lim, lim), 0.0, clampf(at.z, -lim, lim))
	if Vector2(at.x - me.x, at.z - me.z).length() < MIN_GAP:
		at = me - SPOT
		at = Vector3(clampf(at.x, -lim, lim), 0.0, clampf(at.z, -lim, lim))
	return at


func spawn() -> void:
	foe = _main._spawn(kind, false, spot())
	foe.attack_damage *= DAMAGE_SCALE
	if not kind in RANGED or _hp_flag():
		foe.max_hp *= hp_scale()
	foe.hp = foe.max_hp
	foe.blast_enemy_damage *= DAMAGE_SCALE
	foe.set_meta("spar", true)
	foe.died.connect(_on_died)
	if _blocks0 < 0:
		_blocks0 = ENEMY.blocks


func _physics_process(_delta: float) -> void:
	var hero: Node = _main.player
	if is_instance_valid(hero):
		if _hp >= 0.0 and hero.hp < _hp:
			hurts += 1
			if Time.get_ticks_msec() - _busy_ms <= MID_GAP * 1000.0:
				hurts_mid += 1
		_hp = hero.hp
		var now := Time.get_ticks_msec()
		if _state_prev in [hero.State.ATTACK, hero.State.LEAP, hero.State.CHARGE]:
			_busy_ms = now
		if hero.state == hero.State.HURT and _hurt_from < 0:
			_hurt_from = now
		elif hero.state != hero.State.HURT and _hurt_from >= 0:
			_hurt_ms.append(now - _hurt_from)
			_hurt_from = -1
		_state_prev = hero.state
	if is_instance_valid(foe) and foe.global_position.y < FALL_Y and not foe.has_meta(ENEMY.HELD_FLYING):  # (out of the room: back in)
		strays += 1
		foe.global_position = spot()
		foe.velocity = Vector3.ZERO


## `--spar-hp=N` is on the command line.
static func _hp_flag(args := OS.get_cmdline_user_args()) -> bool:
	return Array(args).any(func(a: String) -> bool: return a.begins_with(HP_FLAG))


## HP_SCALE, or `--spar-hp=N` from the command line.
static func hp_scale(args := OS.get_cmdline_user_args()) -> float:
	for arg in args:
		if arg.begins_with(HP_FLAG):
			return maxf(float(arg.substr(HP_FLAG.length())), 0.1)
	return HP_SCALE


## Hits on the live foe plus every one before it.
func total_hits() -> int:
	return hits_taken + (foe.hits_taken if is_instance_valid(foe) else 0)


func _on_died(e: Node) -> void:
	kills += 1
	hits_taken += e.hits_taken
	cuts += e.held_cuts
	foe = null
	get_tree().create_timer(RESPAWN).timeout.connect(func() -> void:
		if is_inside_tree() and is_instance_valid(_main.player):
			spawn())


func report() -> void:
	var live := is_instance_valid(foe)
	var avg := 0.0
	for ms in _hurt_ms:
		avg += ms / float(_hurt_ms.size())
	print("[spar] type=%s hits_taken=%d kills=%d hurts=%d blocks=%d cuts=%d strays=%d mid=%d hurt_ms=%d/%d" % [kind, total_hits(), kills, hurts,
		blocks(), cuts + (foe.held_cuts if live else 0), strays, hurts_mid, roundi(avg), _hurt_ms.max() if not _hurt_ms.is_empty() else 0])


## Hits its shield blocked since sparring began.
func blocks() -> int:
	return ENEMY.blocks - _blocks0 if _blocks0 >= 0 else 0
