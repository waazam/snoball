extends MeshInstance3D
## A single tumbling confetti flake: a small flat colored quad launched
## outward, arcing under gravity, tumbling on a random axis, and fading out
## near the end of its life. Built entirely in code and spawned in a burst -
## same "no separate scene needed" approach as DamageNumber.gd/HatVisuals.gd.
## Uses _process (not _physics_process) since it's a pure visual effect with
## no collision, same as CloudLayer.gd's drift.

const GRAVITY := 9.0
const LIFETIME := 1.1
const FADE_START := LIFETIME * 0.6
const SIZE := 0.09

var _velocity: Vector3 = Vector3.ZERO
var _spin_axis: Vector3 = Vector3.UP
var _spin_speed: float = 0.0
var _age: float = 0.0
var _mat: StandardMaterial3D

func setup(p_velocity: Vector3, color: Color) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	mesh = quad
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.disable_receive_shadows = true
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_velocity = p_velocity
	_spin_axis = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	_spin_speed = randf_range(6.0, 14.0)

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_velocity.y -= GRAVITY * delta
	global_position += _velocity * delta
	rotate_object_local(_spin_axis, _spin_speed * delta)
	if _age > FADE_START:
		_mat.albedo_color.a = 1.0 - (_age - FADE_START) / (LIFETIME - FADE_START)
