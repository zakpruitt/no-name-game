extends RefCounted
## The hero's look on a hit: the swing's swoosh, the spirit casts that come with a move (ELEMENTS.CASTS:
## the echo axe, Dash Stab's claw lash), the combo-name callout over his head, the camera kick on enders,
## the style-rank burst and the fight's final blow. Static functions over the hero's state, like
## void_element.gd: the callout label, `_swoosh_flip` and the trails stay on player.gd.

const ELEMENTS := preload("res://scripts/elements.gd")
const VOID_ELEMENT := preload("res://scripts/void_element.gd")
const HERO_MOVES := preload("res://scripts/hero_moves.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const CLAW_LASH := preload("res://scripts/claw_lash.gd")
const RANK_COLORS: Dictionary = preload("res://scripts/hud.gd").RANK_COLORS

const AXE_SOURCE := "res://assets/kaykit/characters/Barbarian.glb"  # the 1H_Axe spirit casts ghost (axe_mesh)
const CAST_GROW := 0.15  # spirit cast size per chain tier (cast_grow)
const CAST_POWER := 0.12  # spirit cast damage per chain tier
const CAST_SFX_DB := -11.0  # the element's cast sound under the swing
const COMBO_TIER_COLORS := [Color(0.95, 0.92, 0.85), Color(1.0, 0.75, 0.3), Color(1.0, 0.45, 0.15)]  # callout text per COMBOS tier
const COMBO_TIER_SFX := ["combo_1", "combo_2", "combo_3"]
const COMBO_SFX_DB := -9.0  # the tier sound under the hit
const ENDER_ZOOM := 0.035  # camera push-in per tier on a combo ender
const LAST_KILL_SLOWMO := 0.55  # real seconds of slow motion on the fight's final blow

static var _kaykit_axe: Mesh  # the spirit casts' axe (see axe_mesh)


## The combo-name callout over his head (combo_callout, hero_leap._callout); hidden until a combo lands.
static func make_callout(hero: CharacterBody3D) -> Label3D:
	var callout := Label3D.new()
	callout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	callout.no_depth_test = true
	callout.font_size = 84
	callout.outline_size = 24
	callout.pixel_size = 0.006
	callout.outline_modulate = Color(0.1, 0.05, 0.1)
	callout.visible = false
	hero.add_child(callout)
	return callout


## The mesh spirit casts ghost. His axes are skinned in place, far from any
## usable origin, so his spirits throw KayKit's axe (AXE_SOURCE).
static func axe_mesh() -> Mesh:
	if _kaykit_axe == null:
		var kaykit: Node3D = load(AXE_SOURCE).instantiate()
		_kaykit_axe = (kaykit.find_child("1H_Axe", true, false) as MeshInstance3D).mesh
		kaykit.free()
	return _kaykit_axe


## Swing trail colour outside Awakening: the current element's.
static func trail_rest_color(hero: CharacterBody3D) -> Color:
	return Color(ELEMENTS.color(hero.element()), 0.85)


## The swing's arc (Fx.swoosh) out to the move's reach, in the trail's colour.
## Strip moves (`width`) thrust instead of sweep and get none.
static func swoosh(hero: CharacterBody3D, fwd: Vector3) -> void:
	var move: Dictionary = hero._move
	if move.has("width"):
		return
	hero._swoosh_flip = not hero._swoosh_flip
	var trails: Array = hero._trails
	var c: Color = trails[0].color if not trails.is_empty() else trail_rest_color(hero)
	var big: bool = move.get("big", false)
	var time := 0.32 if big else 0.24
	var model: Node3D = hero.model
	var at := hero.global_position + model.position  # up with him in a hop / the air string, beside him in a weave
	var flip: bool = hero._swoosh_flip
	Fx.swoosh(hero.get_parent(), at, fwd, move.range * 0.9, move.arc, c, flip, time)
	# Escalation: combo enders and long chains add a wider, hotter arc above the
	# first, so a string visibly builds to its finish.
	var tier := Fx.chain_tier(Game.combo_count)
	if HERO_MOVES.COMBOS.has(hero._move_id) or tier >= 2:
		var hot := c.lerp(Color.WHITE, 0.35)
		hot.a = 0.75 + 0.08 * tier
		Fx.swoosh(hero.get_parent(), at, fwd, move.range * (1.05 + 0.04 * tier), move.arc, hot,
				flip, time * 1.15, 1.15)


## The element cast that comes with the current move (ELEMENTS.CASTS), on its first active frame.
static func cast(hero: CharacterBody3D, fwd: Vector3) -> void:
	var move_id: String = hero._move_id
	if not ELEMENTS.CASTS.has(move_id) or move_id in VOID_ELEMENT.NO_CAST:
		return
	var c: Dictionary = ELEMENTS.CASTS[move_id]
	var el: String = hero.element()
	var parent := hero.get_parent()
	var model: Node3D = hero.model
	var dmg_mult: float = hero._dmg_mult
	ELEMENTS.casts += 1
	Game.sfx(ELEMENTS.LOOK[el].sfx, CAST_SFX_DB, 0.1)
	var g := cast_grow()  # spirit weapons swell with the chain
	match c.kind:
		"echo":
			var echo = spirit(hero, SPIRIT_ECHO.new(), c, el)
			echo.fwd = fwd
			echo.flip = hero._swoosh_flip  # follows the swing's own swoosh
			echo.arc_deg = c.arc
			echo.radius = c.radius * g
			echo.delay = c.delay
			echo.time = c.time
			parent.add_child(echo)
			echo.global_position = Vector3(hero.global_position.x, model.position.y, hero.global_position.z)  # (air slashes: in the air)
		"lash":  # Dash Stab: the claw whips its ribbon out ahead and back (claw_lash.gd)
			var lash = spirit(hero, CLAW_LASH.new(), c, el)
			lash.dir = fwd
			lash.hero = hero
			lash.size = c.size * g
			lash.reach = minf(c.range, hero._clear_ahead(lash.dir, c.range) + 0.4)
			lash.back_damage = c.back_damage * dmg_mult * cast_power()
			parent.add_child(lash)
			lash.global_position = Vector3(hero.global_position.x, 0.0, hero.global_position.z) + lash.dir * 0.6


## The common setup of a spirit cast node (spirit_*.gd): the hero's axe,
## colour, element, damage (scaled by the chain) and hit callback.
static func spirit(hero: CharacterBody3D, node: Node3D, c: Dictionary, el: String) -> Node3D:
	if "axe_mesh" in node:
		node.axe_mesh = axe_mesh()
	node.color = hero._fx_color()
	node.el = el
	var dmg_mult: float = hero._dmg_mult
	node.damage = c.damage * dmg_mult * cast_power()
	return node


## Spirit casts grow with the chain: CAST_GROW more size/reach per Fx chain
## tier (10 / 20 / 35 hits), CAST_POWER more damage.
static func cast_grow() -> float:
	return 1.0 + CAST_GROW * Fx.chain_tier(Game.combo_count)


static func cast_power() -> float:
	return 1.0 + CAST_POWER * Fx.chain_tier(Game.combo_count)


## Combo enders push the camera in (more per tier); big hits and enders kick it
## along the swing.
static func camera_hit(fwd: Vector3, ender: int) -> void:
	if Game.camera_rig == null:
		return
	Game.camera_rig.kick(fwd, 0.18 + ender * 0.12)
	if ender > 0:
		Game.camera_rig.punch(1.0 - ENDER_ZOOM * ender, 0.08 + 0.05 * ender)


## Names a landed combo (COMBOS) above the hero with its tier's sound, once per move.
static func combo_callout(hero: CharacterBody3D, id: String) -> void:
	if hero._callout_done or not HERO_MOVES.COMBOS.has(id):
		return
	hero._callout_done = true
	var c: Dictionary = HERO_MOVES.COMBOS[id]
	var tier: int = c.tier
	hero.combos_landed[id] = hero.combos_landed.get(id, 0) + 1
	if hero.combos_landed[id] == 1:
		hero.combo_found.emit(id)
	Game.sfx(COMBO_TIER_SFX[tier - 1], COMBO_SFX_DB, 0.03)
	var callout: Label3D = hero._callout
	callout.text = c.name
	callout.modulate = COMBO_TIER_COLORS[tier - 1]
	var move_id: String = hero._move_id
	var pop_color: Color = VOID_ELEMENT.color_of(move_id, hero._fx_color())
	if not VOID_ELEMENT.is_element_move(move_id):  # (his tentacle moves land on him: a pop there hides what they're doing)
		Fx.combo_pop(hero.get_parent(), hero.global_position, pop_color if tier < 3 else callout.modulate, tier)
	callout.position = Vector3(0.0, 2.9, 0.0)
	callout.scale = Vector3.ONE * 0.6
	callout.visible = true
	if hero._callout_tw:
		hero._callout_tw.kill()
	var tw := callout.create_tween()
	hero._callout_tw = tw
	tw.tween_property(callout, "scale", Vector3.ONE * 1.15, 0.08)
	tw.tween_property(callout, "scale", Vector3.ONE, 0.08)
	tw.parallel().tween_property(callout, "position:y", 3.2, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(callout, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tw.tween_callback(callout.hide)


## Style rank climbed to step `i` above D: a burst in the new rank's colour (the HUD's), bigger the higher.
static func rank_up(hero: CharacterBody3D, i: int, rank: String) -> void:
	var c: Color = RANK_COLORS.get(rank, Color.WHITE)
	var at := hero.global_position + Vector3.UP * 1.1
	# Thin and hard: a soft ring and star sat on him and fought his effects.
	VOID_ELEMENT.DARK.hoop_run(hero.get_parent(), hero.global_position, 0.6, 1.8 + i * 0.45, 0.22, c, 0.06)
	Fx.burst(hero.get_parent(), at, c, 6 + i * 4, 9.0, 0.14, 0.35, Vector3.UP, 120.0, -6.0, 0.3, "spark")
	if i >= 4 and Game.camera_rig != null:  # S and up
		Game.camera_rig.punch(0.94, 0.15)


## The fight's final blow: slow motion, a camera push-in and a gold shock ring.
static func last_kill(hero: CharacterBody3D, e: Node) -> void:
	hero.last_kills += 1
	if "--autotest" in OS.get_cmdline_user_args():
		hero.bot_log.append("[autotest] last_kill #%d rank_ups=%d" % [hero.last_kills, hero.rank_ups])
	Game.hitstop(LAST_KILL_SLOWMO, 0.2)
	if Game.camera_rig != null:
		Game.camera_rig.punch(0.82, LAST_KILL_SLOWMO + 0.15)
	var at: Vector3 = (e as Node3D).global_position
	var gold := Color(1.0, 0.82, 0.3)
	var parent := hero.get_parent()
	Fx.ring(parent, at, Color(gold, 0.95), 5.0, 0.5)
	Fx.ring(parent, at, Color(1, 1, 1, 0.8), 2.5, 0.3)
	Fx.flare(parent, at + Vector3.UP * 1.1, gold, 6.0, 0.3, "star8")
	Fx.burst(parent, at + Vector3.UP * 0.8, gold, 30, 12.0, 0.16, 0.6, Vector3.UP, 120.0, -10.0, 0.2, "spark")
