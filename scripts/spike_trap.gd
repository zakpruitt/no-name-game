extends Node3D
## Floor spike trap on one 4x4 tile: waits, rumbles with a red warning, then
## stabs up and hurts anything standing on it (hero and skeletons alike;
## skeletons get launched, so luring them in starts a juggle).

const TILE := preload("res://assets/kaykit/dungeon/floor_tile_big_spikes.glb")

@export var idle_time := 2.6
@export var warn_time := 0.7
@export var up_time := 0.7
@export var player_damage := 15.0
@export var enemy_damage := 20.0
@export var half_size := 1.15  # spike area half-width (the spikes cover ~2.2m)

const HIDDEN_Y := -2.1
const WARN_Y := -1.75

var _spikes: Node3D
var _warn: MeshInstance3D
var _warn_mat: StandardMaterial3D
var _t := 0.0
var _phase := "idle"


func _ready() -> void:
	var tile: Node3D = ComicLook.comic_piece("floor_tile_big_spikes")
	if tile == null:
		tile = TILE.instantiate()
	tile.position.y = 0.01  # sit just above the regular floor tile
	add_child(tile)
	_spikes = tile.find_child("spikes", true, false)
	_spikes.position.y = HIDDEN_Y
	_warn = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(half_size * 2.0, half_size * 2.0)
	_warn_mat = StandardMaterial3D.new()
	_warn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_warn_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.0)
	quad.material = _warn_mat
	_warn.mesh = quad
	_warn.position.y = 0.13
	_warn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_warn)
	_t = randf_range(0.0, idle_time)  # traps don't all fire in sync


func _physics_process(delta: float) -> void:
	_t += delta
	match _phase:
		"idle":
			if _t >= idle_time:
				_enter("warn")
				Fx.dust(get_parent(), global_position, 8, 0.5)
		"warn":
			var k := _t / warn_time
			_spikes.position.y = lerpf(HIDDEN_Y, WARN_Y, minf(k * 2.0, 1.0)) + randf_range(-0.03, 0.03)
			_warn_mat.albedo_color.a = 0.15 + 0.35 * k
			if _t >= warn_time:
				_enter("up")
				_strike()
		"up":
			_spikes.position.y = move_toward(_spikes.position.y, 0.0, delta * 30.0)
			if _t >= up_time:
				_enter("down")
		"down":
			_spikes.position.y = move_toward(_spikes.position.y, HIDDEN_Y, delta * 5.0)
			_warn_mat.albedo_color.a = move_toward(_warn_mat.albedo_color.a, 0.0, delta * 3.0)
			if _spikes.position.y <= HIDDEN_Y:
				_enter("idle")


func _enter(phase: String) -> void:
	_phase = phase
	_t = 0.0


func _strike() -> void:
	Game.sfx("hit_big", -8.0, 0.1)
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.4, Color(0.75, 0.75, 0.8), 14, 6.0, 0.12, 0.3, Vector3.UP, 50.0)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and not player.is_dead() and _covers(player.global_position):
		player.take_hit(player_damage, Vector3.ZERO, null)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and _covers(e.global_position):
			e.take_hit(enemy_damage, Vector3.ZERO, 7.0, true)
			Game.register_hit("spikes")


func _covers(p: Vector3) -> bool:
	var d := p - global_position
	return absf(d.x) <= half_size and absf(d.z) <= half_size
