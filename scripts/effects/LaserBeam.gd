extends Node3D
## A pulsating red laser beam stretched between two world points - Santa's
## eye-laser attack. A single thin emissive cylinder pointed along the
## segment; PULSE_SPEED oscillates both its radius and glow so it reads as
## an actively-firing beam instead of a static rod, then it fades out.
## Built and freed entirely in code, same approach as DamageNumber.gd/
## ConfettiPiece.gd - just aimed at a runtime-arbitrary direction instead of
## a fixed one, which is why setup() builds its own basis instead of using
## a baked rotation_degrees like EnemySnowman.gd's carrot nose does.

const BASE_RADIUS := 0.035
const PULSE_AMOUNT := 0.35  # +-35% radius/glow wobble
const PULSE_SPEED := 13.0
const LIFETIME := 0.85
const FADE_TIME := 0.18
const COLOR := Color(1.0, 0.12, 0.08)

var _age: float = 0.0
var _mat: StandardMaterial3D
var _mesh_instance: MeshInstance3D

func setup(from: Vector3, to: Vector3) -> void:
	global_position = from
	var to_local: Vector3 = to - from
	var length: float = maxf(to_local.length(), 0.05)

	var mesh := CylinderMesh.new()
	mesh.top_radius = BASE_RADIUS
	mesh.bottom_radius = BASE_RADIUS
	mesh.height = length
	mesh.radial_segments = 8
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.emission_enabled = true
	_mat.emission = COLOR
	_mat.emission_energy_multiplier = 3.0
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_instance.material_override = _mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

	# CylinderMesh's own long axis is local Y and it's centered on its own
	# origin - build a basis whose Y axis points along `dir` (via two
	# arbitrary perpendiculars, picked from whichever of UP/RIGHT isn't
	# near-parallel to `dir`, so the cross products stay well-defined even
	# for a near-vertical beam), then offset by half the length along it
	# since the beam's root (global_position, set above) is `from`, not the
	# segment's midpoint.
	var dir: Vector3 = to_local.normalized()
	var helper: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x_axis: Vector3 = helper.cross(dir).normalized()
	var z_axis: Vector3 = dir.cross(x_axis).normalized()
	_mesh_instance.basis = Basis(x_axis, dir, z_axis)
	_mesh_instance.position = dir * (length * 0.5)

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var pulse: float = 1.0 + sin(_age * PULSE_SPEED) * PULSE_AMOUNT
	_mesh_instance.scale = Vector3(pulse, 1.0, pulse)
	_mat.emission_energy_multiplier = 3.0 * pulse
	if _age > LIFETIME - FADE_TIME:
		_mat.albedo_color.a = (LIFETIME - _age) / FADE_TIME
