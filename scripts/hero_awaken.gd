extends RefCounted
## Awakening on the hero: activation when the meter (Game.awakening) is full, the burst that blows foes
## back, the buff while it lasts (faster, harder, armoured, gold rim, light and trails, the axe's element
## charged) and the drain back to empty. Game owns the meter and style rank; this is the hero's side.
## Static functions over the hero's state, like void_element.gd: `awakened`, the light and the rim stay
## on player.gd.

const AWAKEN_BURST_RADIUS := 7.0  # the activation shockwave blows foes back this far
const AWAKEN_BURST_DAMAGE := 10.0
const AWAKEN_COLOR := Color(1.0, 0.78, 0.3)  # Awakening's ancestral gold: light, rim, trails, burst
const ANIM_MULT := 1.3  # animation speed while Awakened
const DAMAGE_MULT := 1.6
const SIZE := 1.18  # model scale while Awakened
const SPEED_MULT := 1.2  # run speed while Awakened (player._state_move)
const DAMAGE_TAKEN := 0.6  # armour: hits on him do this much (player.take_hit); he isn't staggered either


## Each physics frame: drain the meter over awaken_duration, and end when it runs out.
static func tick(hero: CharacterBody3D, delta: float) -> void:
	if not hero.awakened:
		return
	hero._awaken_t -= delta
	Game.add_awakening(-Game.AWAKEN_MAX / hero.awaken_duration * delta)
	if hero._awaken_t <= 0.0:
		set_awakened(hero, false)


## Fx.flash clears overlays on hit; put the Awakening rim back.
static func keep_rim(hero: CharacterBody3D) -> void:
	if not hero.awakened:
		return
	for mi: MeshInstance3D in hero._meshes:
		if mi.material_overlay == null:
			mi.material_overlay = hero._awaken_rim


## Animation speed before per-move boosts (Awakening is faster).
static func base_anim_mult(hero: CharacterBody3D) -> float:
	return ANIM_MULT if hero.awakened else 1.0


## Activate with a full meter: big freeze, a shockwave that blows enemies back.
static func try_awaken(hero: CharacterBody3D) -> void:
	if hero.awakened or hero.state == hero.State.DEAD or Game.awakening < Game.AWAKEN_MAX:
		return
	set_awakened(hero, true)
	Game.sfx("awaken", 0.0, 0.0)
	Game.rumble("awaken")
	# Activation burst: big freeze, shockwave that blows enemies back.
	Game.hitstop(0.25, 0.05)
	Game.shake(0.6)
	var r := AWAKEN_BURST_RADIUS
	Fx.awaken_burst(hero.get_parent(), hero.global_position, AWAKEN_COLOR, r)
	if Game.camera_rig:
		Game.camera_rig.punch(0.85, 0.35)
	for e in hero.get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - hero.global_position
		to.y = 0.0
		if to.length() < r:
			e.take_hit(AWAKEN_BURST_DAMAGE, to.normalized() * 12.0, 5.0, true)


## Turn the buff on or off: the meter lock, speed and damage, size, light, rim, trails, the axe's element.
static func set_awakened(hero: CharacterBody3D, on: bool) -> void:
	hero.awakened = on
	Game.awaken_locked = on
	if not on:
		Game.add_awakening(-Game.AWAKEN_MAX)  # always starts over from empty
	hero._awaken_t = hero.awaken_duration
	hero._anim_mult = ANIM_MULT if on else 1.0
	hero._dmg_mult = DAMAGE_MULT if on else 1.0
	var light: OmniLight3D = hero._awaken_light
	var rim: ShaderMaterial = hero._awaken_rim
	var tw := hero.create_tween().set_parallel()
	tw.tween_property(hero.model, "scale", Vector3.ONE * (SIZE if on else 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(light, "light_energy", 3.0 if on else 0.0, 0.2)
	var c := AWAKEN_COLOR
	light.light_color = c
	rim.set_shader_parameter("glow_color", c)
	for mi: MeshInstance3D in hero._meshes:
		mi.material_overlay = rim if on else null
	for trail in hero._trails:
		trail.color = Color(c, 0.9) if on else hero._trail_rest_color()
	for coat: Node in hero._coats:  # ComicLook.infuse_axes: the axe's element flares up
		if is_instance_valid(coat):
			coat.charge(on)
	hero._orbit.setup(hero.element(), on)
	hero.awakened_changed.emit(on)
