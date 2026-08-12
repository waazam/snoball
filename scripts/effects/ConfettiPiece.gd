extends MeshInstance3D
## A single tumbling confetti piece: a small flat colored shape launched
## outward, arcing under gravity with a little air drag and side-to-side
## flutter, tumbling on a random axis, and fading out near the end of its
## life. Each piece randomly picks one of four shapes - ribbon strip,
## square, triangle, hex disc - and jitters its caller-given color a touch
## brighter or darker, so a burst reads as real party confetti instead of
## 22 identical squares. A whisper of emission makes the burst sparkle
## against the dusk (the environment glow pass picks it up).
## Built entirely in code and spawned in a burst - same "no separate scene
## needed" approach as DamageNumber.gd/HatVisuals.gd. Uses _process (not
## _physics_process) since it's a pure visual effect with no collision,
## same as CloudLayer.gd's drift.

const GRAVITY := 9.0
const LIFETIME := 1.1
const FADE_START := LIFETIME * 0.6
const SIZE := 0.09
const DRAG := 0.6
const FLUTTER_STRENGTH := 0.35

var _velocity: Vector3 = Vector3.ZERO
var _spin_axis: Vector3 = Vector3.UP
var _spin_speed: float = 0.0
var _age: float = 0.0
var _mat: StandardMaterial3D
var _flutter_phase: float = 0.0
var _flutter_dir: Vector3 = Vector3.RIGHT

func setup(p_velocity: Vector3, color: Color) -> void:
	mesh = _build_shape()
	var tinted: Color = color.lightened(randf_range(0.0, 0.25)) if randf() < 0.5 else color.darkened(randf_range(0.0, 0.15))
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = tinted
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.disable_receive_shadows = true
	_mat.emission_enabled = true
	_mat.emission = tinted
	_mat.emission_energy_multiplier = 0.5
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_velocity = p_velocity
	_spin_axis = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	_spin_speed = randf_range(6.0, 14.0)
	_flutter_phase = randf() * TAU
	_flutter_dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()

## One of four flat party shapes, all in the local XY plane (Z=0) like a
## QuadMesh, so the disabled cull mode above keeps them visible from both
## sides as they tumble.
func _build_shape() -> Mesh:
	var kind: int = randi() % 4
	match kind:
		0:  # curling-ribbon strip
			var strip := QuadMesh.new()
			strip.size = Vector2(SIZE * 0.45, SIZE * 1.7)
			return strip
		1:  # classic square, slightly varied in size
			var square := QuadMesh.new()
			square.size = Vector2(SIZE, SIZE) * randf_range(0.8, 1.15)
			return square
		2:  # triangle
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var s: float = SIZE * 1.1
			st.add_vertex(Vector3(0.0, s * 0.6, 0.0))
			st.add_vertex(Vector3(-s * 0.5, -s * 0.4, 0.0))
			st.add_vertex(Vector3(s * 0.5, -s * 0.4, 0.0))
			return st.commit()
		_:  # hex disc ("circle" at this scale)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var r: float = SIZE * 0.55
			for i in 6:
				var a0: float = (TAU / 6.0) * i
				var a1: float = (TAU / 6.0) * (i + 1)
				st.add_vertex(Vector3.ZERO)
				st.add_vertex(Vector3(cos(a0) * r, sin(a0) * r, 0.0))
				st.add_vertex(Vector3(cos(a1) * r, sin(a1) * r, 0.0))
			return st.commit()

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_velocity.y -= GRAVITY * delta
	# Light air drag on the horizontal throw plus a sideways flutter - flat
	# paper doesn't fall like a rock.
	_velocity.x -= _velocity.x * DRAG * delta
	_velocity.z -= _velocity.z * DRAG * delta
	global_position += _velocity * delta + _flutter_dir * (sin(_age * 9.0 + _flutter_phase) * FLUTTER_STRENGTH * delta)
	rotate_object_local(_spin_axis, _spin_speed * delta)
	if _age > FADE_START:
		_mat.albedo_color.a = 1.0 - (_age - FADE_START) / (LIFETIME - FADE_START)
