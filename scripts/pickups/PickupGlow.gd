extends Node3D
## Shared visual-only "reward glow" dressing for ground pickups: a soft
## emissive ground ring plus a few orbiting diamond glints that twinkle.
## Pure decoration - no collision, no gameplay values, no timers anything
## reads - attached by HatPickup/SwordPickup via set_script(), the same
## spawn idiom DamageNumber.gd/ConfettiPiece.gd use.
##
## The ring pins its own global height to a fixed ground level each frame so
## the parent pickup's bob (and collect-shrink tween) doesn't lift it off
## the snow. Flat-ground assumption (y ~= 0) matches WaveManager's pickup
## placement and BurnPatch.gd's existing behavior - no terrain raycast.

const RING_ALPHA := 0.4
const RING_PULSE_SPEED := 2.6
# Faint wider second halo breathing counter-phase to the main ring - reads
# as soft light falloff on the snow instead of a hard single hoop.
const ECHO_RADIUS_FRAC := 1.3
const ECHO_ALPHA := 0.16
const GLINT_SIZE := 0.075
const GLINT_ORBIT_SPEED := 0.9

var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _echo: MeshInstance3D
var _echo_mat: StandardMaterial3D
var _glints: Array[MeshInstance3D] = []
var _glint_mats: Array[StandardMaterial3D] = []
var _glint_phases: Array[float] = []
var _color: Color = Color(1, 1, 1)
var _radius: float = 0.5
var _ground_y: float = 0.0
var _glint_height: float = 0.8
var _time: float = 0.0

func setup(color: Color, ring_radius: float, ground_y: float, glint_height: float, glint_count: int = 3) -> void:
	_color = color
	_radius = ring_radius
	_ground_y = ground_y
	_glint_height = glint_height
	_time = randf() * TAU
	_build_ring()
	_build_glints(glint_count)

func _build_ring() -> void:
	_ring_mat = _make_halo_mat(RING_ALPHA, 1.2)
	_ring = _make_halo(_radius, _ring_mat)
	add_child(_ring)
	_echo_mat = _make_halo_mat(ECHO_ALPHA, 0.8)
	_echo = _make_halo(_radius * ECHO_RADIUS_FRAC, _echo_mat)
	add_child(_echo)

func _make_halo(radius: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.78
	torus.outer_radius = radius
	torus.rings = 20
	torus.ring_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.scale = Vector3(1.0, 0.22, 1.0)  # squash to a thin halo hugging the snow
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _make_halo_mat(alpha: float, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(_color.r, _color.g, _color.b, alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_receive_shadows = true
	mat.emission_enabled = true
	mat.emission = _color
	mat.emission_energy_multiplier = energy
	return mat

func _build_glints(count: int) -> void:
	var mesh := _build_diamond_mesh()
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		# Whitened toward a hot glint core, but the emission stays the
		# pickup's signature color so bloom reads on-palette.
		mat.albedo_color = _color.lerp(Color(1, 1, 1), 0.65)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_receive_shadows = true
		mat.emission_enabled = true
		mat.emission = _color
		mat.emission_energy_multiplier = 1.8
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Slightly varied sizes so the orbit reads as scattered sparkles
		# rather than a formation of identical markers.
		mi.scale = Vector3.ONE * (0.8 + 0.45 * fmod(float(i) * 0.618, 1.0))
		add_child(mi)
		_glints.append(mi)
		_glint_mats.append(mat)
		_glint_phases.append(TAU * float(i) / float(count) + randf() * 0.8)

## A four-point sparkle diamond in the local XY plane - billboarding keeps
## its own mesh shape while turning it to the camera, so it reads as a
## proper glint instead of a plain square.
func _build_diamond_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := GLINT_SIZE
	var w := GLINT_SIZE * 0.38
	st.add_vertex(Vector3(0, h, 0))
	st.add_vertex(Vector3(-w, 0, 0))
	st.add_vertex(Vector3(w, 0, 0))
	st.add_vertex(Vector3(0, -h, 0))
	st.add_vertex(Vector3(w, 0, 0))
	st.add_vertex(Vector3(-w, 0, 0))
	return st.commit()

func _process(delta: float) -> void:
	if _ring == null:
		return
	_time += delta
	# Pin the halos to the ground while the pickup bobs above them.
	_ring.global_position.y = _ground_y + 0.02
	_echo.global_position.y = _ground_y + 0.015
	var pulse: float = 1.0 + 0.07 * sin(_time * RING_PULSE_SPEED)
	_ring.scale = Vector3(pulse, 0.22, pulse)
	_ring_mat.emission_energy_multiplier = 1.0 + 0.5 * (0.5 + 0.5 * sin(_time * RING_PULSE_SPEED))
	# Counter-phase: the echo swells as the main ring settles.
	var echo_pulse: float = 1.0 + 0.05 * sin(_time * RING_PULSE_SPEED + PI)
	_echo.scale = Vector3(echo_pulse, 0.22, echo_pulse)
	_echo_mat.emission_energy_multiplier = 0.6 + 0.4 * (0.5 + 0.5 * sin(_time * RING_PULSE_SPEED + PI))
	for i in _glints.size():
		var phase: float = _glint_phases[i]
		var a: float = _time * GLINT_ORBIT_SPEED + phase
		var r: float = _radius * 0.7
		_glints[i].position = Vector3(cos(a) * r, _glint_height + sin(_time * 1.7 + phase * 2.0) * 0.09, sin(a) * r)
		var tw: float = 0.5 + 0.5 * sin(_time * 3.4 + phase * 3.0)
		_glint_mats[i].albedo_color.a = 0.15 + 0.85 * tw * tw * tw
