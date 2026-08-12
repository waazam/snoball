extends Node3D
## Santa's eye-laser stretched between two world points, now a layered beam:
## a hot candle-white core cylinder inside a wide translucent FX_LASER
## sleeve (the environment's glow pass does the soft falloff), plus a small
## pulsing impact flare where it strikes the ground. PULSE_SPEED oscillates
## radius and emission so it reads as an actively-firing beam instead of a
## static rod, then everything fades out together.
## Built and freed entirely in code, same approach as DamageNumber.gd/
## ConfettiPiece.gd - just aimed at a runtime-arbitrary direction instead of
## a fixed one, which is why setup() builds its own basis instead of using
## a baked rotation_degrees like EnemySnowman.gd's carrot nose does.
##
## Palette (ART_DIRECTION): FX_LASER #FF3B5C at emission energy 4.0 on the
## core, CANDLE_WHITE #FFE9C9 for the white-hot center albedo.

const CORE_RADIUS := 0.022
const SLEEVE_RADIUS := 0.085
const PULSE_AMOUNT := 0.3  # +-30% radius/glow wobble
const PULSE_SPEED := 13.0
const LIFETIME := 0.85
const FADE_TIME := 0.18
const BEAM_COLOR := Color("#FF3B5C")
const CORE_COLOR := Color("#FFE9C9")
const SLEEVE_ALPHA := 0.3
const FLARE_ALPHA := 0.85

var _age: float = 0.0
var _core: MeshInstance3D
var _sleeve: MeshInstance3D
var _flare: MeshInstance3D
var _core_mat: StandardMaterial3D
var _sleeve_mat: StandardMaterial3D
var _flare_mat: StandardMaterial3D

func setup(from: Vector3, to: Vector3) -> void:
	global_position = from
	var to_local: Vector3 = to - from
	var length: float = maxf(to_local.length(), 0.05)

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
	var beam_basis := Basis(x_axis, dir, z_axis)
	var mid: Vector3 = dir * (length * 0.5)

	_core_mat = _make_beam_mat(CORE_COLOR, 1.0, 4.0)
	_core = _make_cylinder(CORE_RADIUS, length, _core_mat, beam_basis, mid)
	_sleeve_mat = _make_beam_mat(BEAM_COLOR, SLEEVE_ALPHA, 2.0)
	_sleeve = _make_cylinder(SLEEVE_RADIUS, length, _sleeve_mat, beam_basis, mid)

	# Impact flare: a small hot sphere at the far end that pulses with the
	# beam - sells the "burning the ground" moment before BurnPatch takes
	# over.
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	sphere.radial_segments = 10
	sphere.rings = 5
	_flare = MeshInstance3D.new()
	_flare.mesh = sphere
	_flare_mat = _make_beam_mat(CORE_COLOR, FLARE_ALPHA, 4.0)
	_flare.material_override = _flare_mat
	_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flare)
	_flare.position = dir * length

func _make_beam_mat(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_receive_shadows = true
	mat.emission_enabled = true
	mat.emission = BEAM_COLOR
	mat.emission_energy_multiplier = energy
	return mat

func _make_cylinder(radius: float, length: float, mat: StandardMaterial3D, p_basis: Basis, offset: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.basis = p_basis
	mi.position = offset
	return mi

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var pulse: float = 1.0 + sin(_age * PULSE_SPEED) * PULSE_AMOUNT
	_core.scale = Vector3(pulse, 1.0, pulse)
	_sleeve.scale = Vector3(pulse, 1.0, pulse)
	_core_mat.emission_energy_multiplier = 4.0 * pulse
	_sleeve_mat.emission_energy_multiplier = 2.0 * pulse
	var flare_pulse: float = 1.0 + 0.3 * sin(_age * PULSE_SPEED * 1.4)
	_flare.scale = Vector3.ONE * flare_pulse
	if _age > LIFETIME - FADE_TIME:
		var k: float = (LIFETIME - _age) / FADE_TIME
		_core_mat.albedo_color.a = k
		_sleeve_mat.albedo_color.a = SLEEVE_ALPHA * k
		_flare_mat.albedo_color.a = FLARE_ALPHA * k
