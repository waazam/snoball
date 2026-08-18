extends Node3D
## A lingering scorched patch on the ground where Santa's laser hits: a
## layered soft-edged ember splat (dark char base, glowing FX_BURN mid,
## hot EMBER_GOLD center) with rising ember particles, pulsing while it
## ticks damage to the player, then fading and freeing itself. Damage
## logic (tick interval, radius check, dps) is untouched from the original -
## only the visuals changed. Built entirely in code, same approach as
## GroundTrail.gd's decals - just longer-lived and damaging instead of a
## pure cosmetic trail mark.
##
## The splats are radial triangle fans with vertex-alpha falling to zero at
## a jittered rim - a soft, irregular scorch without any texture.
##
## Ground-height assumption: positioned wherever the caller puts it (see
## EnemySanta.gd's _fire_laser, which targets y=0.05) - there's no terrain
## raycast to find actual ground height, same limitation GroundTrail.gd's
## decals already have on sloped ground.

const TICK_INTERVAL := 0.5
const PULSE_SPEED := 5.0
const FADE_TIME := 0.5
const CHAR_COLOR := Color("#0A0812")
const EMBER_COLOR := Color("#FF9E2C")
const EMBER_HOT := Color("#FFB84D")
const EMBER_PARTICLE_LIFETIME := 0.9

var _radius: float = 1.6
var _dps: float = 6.0
var _duration: float = 3.0
var _age: float = 0.0
var _tick_timer: float = 0.0
var _mat: StandardMaterial3D
var _mesh_instance: MeshInstance3D
var _char_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _particles: GPUParticles3D

func setup(radius: float, dps: float, duration: float) -> void:
	_radius = radius
	_dps = dps
	_duration = duration
	# Char base -> ember glow -> hot core, stacked with tiny y offsets so
	# the transparent fans don't z-fight.
	var char_mesh := _make_splat(_radius * 1.3, Color(CHAR_COLOR.r, CHAR_COLOR.g, CHAR_COLOR.b, 0.55), 0.0)
	_char_mat = char_mesh.material_override as StandardMaterial3D
	_mesh_instance = _make_splat(_radius, Color(EMBER_COLOR.r, EMBER_COLOR.g, EMBER_COLOR.b, 0.85), 0.015)
	_mat = _mesh_instance.material_override as StandardMaterial3D
	_mat.emission_enabled = true
	_mat.emission = EMBER_COLOR
	_mat.emission_energy_multiplier = 1.4
	var core_mesh := _make_splat(_radius * 0.5, Color(EMBER_HOT.r, EMBER_HOT.g, EMBER_HOT.b, 0.9), 0.03)
	_core_mat = core_mesh.material_override as StandardMaterial3D
	_core_mat.emission_enabled = true
	_core_mat.emission = EMBER_HOT
	_core_mat.emission_energy_multiplier = 2.2
	_build_embers()
	position += Vector3(0.0, 0.03, 0.0)
	_tick_timer = TICK_INTERVAL

## A flat irregular triangle-fan splat on the ground plane: opaque-ish at
## the center, vertex alpha zero at a randomly jittered rim, so it reads as
## a soft scorch mark with a hand-drawn edge instead of a hard square.
func _make_splat(radius: float, center_color: Color, height: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := 12
	var edge_color := Color(center_color.r, center_color.g, center_color.b, 0.0)
	var ring: Array[Vector3] = []
	for i in points:
		var a: float = TAU * float(i) / float(points)
		var r: float = radius * randf_range(0.78, 1.12)
		ring.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for i in points:
		st.set_color(center_color)
		st.add_vertex(Vector3.ZERO)
		st.set_color(edge_color)
		st.add_vertex(ring[i])
		st.set_color(edge_color)
		st.add_vertex(ring[(i + 1) % points])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, height, 0.0)
	mi.rotate_y(randf() * TAU)
	add_child(mi)
	return mi

## Small glowing embers drifting up off the patch - one modest GPU emitter,
## well under the art-direction particle budget.
func _build_embers() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = 18
	_particles.lifetime = EMBER_PARTICLE_LIFETIME
	_particles.visibility_aabb = AABB(Vector3(-_radius - 0.5, -0.2, -_radius - 0.5), Vector3(_radius * 2.0 + 1.0, 2.5, _radius * 2.0 + 1.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = _radius * 0.8
	pm.emission_ring_inner_radius = _radius * 0.15
	pm.emission_ring_height = 0.05
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, 0.6, 0)  # embers accelerate gently upward on hot air
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var grad := Gradient.new()
	grad.set_color(0, Color(EMBER_COLOR.r, EMBER_COLOR.g, EMBER_COLOR.b, 1.0))
	grad.set_color(1, Color(EMBER_COLOR.r, EMBER_COLOR.g, EMBER_COLOR.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	_particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.disable_receive_shadows = true
	mat.emission_enabled = true
	mat.emission = EMBER_COLOR
	mat.emission_energy_multiplier = 2.0
	quad.material = mat
	_particles.draw_pass_1 = quad
	add_child(_particles)

func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
		return
	var pulse: float = sin(_age * PULSE_SPEED)
	_mesh_instance.scale = Vector3(1.0 + pulse * 0.12, 1.0, 1.0 + pulse * 0.12)
	_mat.emission_energy_multiplier = 1.4 * (1.0 + pulse * 0.4)
	_core_mat.emission_energy_multiplier = 2.2 * (1.0 + pulse * 0.25)
	# Stop feeding embers early enough that the last one dies before the
	# patch frees itself - no popping particles.
	if _age > _duration - EMBER_PARTICLE_LIFETIME and _particles.emitting:
		_particles.emitting = false
	if _age > _duration - FADE_TIME:
		var k: float = clampf((_duration - _age) / FADE_TIME, 0.0, 1.0)
		_mat.albedo_color.a = k
		_char_mat.albedo_color.a = k
		_core_mat.albedo_color.a = k

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = TICK_INTERVAL
		_check_burn()

func _check_burn() -> void:
	var player: Node3D = Game.player
	if player == null:
		return
	var d: float = Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if d <= _radius and player.has_method("take_hit"):
		player.take_hit(_dps * TICK_INTERVAL)
