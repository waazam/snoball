extends Node3D
## A handful of soft, flat cloud billboards drifting slowly across the sky
## and wrapping back around once they drift far enough out - so the sky
## actually moves instead of being one static painted layer. Each cloud is
## a small cluster of overlapping billboard blobs (same "several irregular
## overlapping shapes" trick SnowCap.gd uses for snow, just billboarded
## quads instead of spheres).

const CLOUD_COUNT := 14
const DRIFT_SPEED := 0.6  # units/sec along +X
const FIELD_RADIUS := 320.0
const HEIGHT_MIN := 40.0
const HEIGHT_MAX := 70.0
const WRAP_LIMIT := 380.0  # once a cloud drifts past this on X, it wraps to the opposite side

var _clouds: Array = []

func _ready() -> void:
	for i in CLOUD_COUNT:
		_spawn_cloud()

func _spawn_cloud() -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(
		randf_range(-FIELD_RADIUS, FIELD_RADIUS),
		randf_range(HEIGHT_MIN, HEIGHT_MAX),
		randf_range(-FIELD_RADIUS, FIELD_RADIUS),
	)
	var blob_count: int = randi_range(3, 5)
	for b in blob_count:
		var size: float = randf_range(6.0, 14.0)
		var mesh := QuadMesh.new()
		mesh.size = Vector2(size, size * 0.55)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.97, 0.94, 0.8)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_receive_shadows = true
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(randf_range(-4.0, 4.0), randf_range(-1.0, 1.0), randf_range(-2.0, 2.0))
		root.add_child(mi)
	_clouds.append(root)

func _process(delta: float) -> void:
	for cloud in _clouds:
		cloud.position.x += DRIFT_SPEED * delta
		if cloud.position.x > WRAP_LIMIT:
			cloud.position.x = -WRAP_LIMIT
