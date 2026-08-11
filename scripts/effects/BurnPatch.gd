extends Node3D
## A lingering scorched patch on the ground where Santa's laser hits: a
## flat ember-glow decal that pulses and ticks damage to the player while
## they're standing in it, then fades and frees itself. Built entirely in
## code, same approach as GroundTrail.gd's decals - just longer-lived and
## damaging instead of a pure cosmetic trail mark.
##
## Ground-height assumption: positioned wherever the caller puts it (see
## EnemySanta.gd's _fire_laser, which targets y=0.05) - there's no terrain
## raycast to find actual ground height, same limitation GroundTrail.gd's
## decals already have on sloped ground.

const TICK_INTERVAL := 0.5
const PULSE_SPEED := 5.0
const FADE_TIME := 0.5
const BASE_ALPHA := 0.55

var _radius: float = 1.6
var _dps: float = 6.0
var _duration: float = 3.0
var _age: float = 0.0
var _tick_timer: float = 0.0
var _mat: StandardMaterial3D
var _mesh_instance: MeshInstance3D

func setup(radius: float, dps: float, duration: float) -> void:
	_radius = radius
	_dps = dps
	_duration = duration
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = quad
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.95, 0.25, 0.05, BASE_ALPHA)
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.emission_enabled = true
	_mat.emission = Color(0.95, 0.35, 0.05)
	_mat.emission_energy_multiplier = 1.4
	_mesh_instance.material_override = _mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
	position += Vector3(0.0, 0.03, 0.0)
	_tick_timer = TICK_INTERVAL

func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
		return
	var pulse: float = sin(_age * PULSE_SPEED)
	_mesh_instance.scale = Vector3(1.0 + pulse * 0.12, 1.0, 1.0 + pulse * 0.12)
	_mat.emission_energy_multiplier = 1.4 * (1.0 + pulse * 0.4)
	if _age > _duration - FADE_TIME:
		_mat.albedo_color.a = BASE_ALPHA * (_duration - _age) / FADE_TIME

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = TICK_INTERVAL
		_check_burn()

func _check_burn() -> void:
	var player: Node3D = _get_player()
	if player == null:
		return
	var d: float = Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if d <= _radius and player.has_method("take_hit"):
		player.take_hit(_dps * TICK_INTERVAL)

func _get_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
