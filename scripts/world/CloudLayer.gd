extends Node3D
## A handful of soft, flat cloud billboards drifting slowly across the sky
## and wrapping back around once they drift far enough out - so the sky
## actually moves instead of being one static painted layer. Each cloud is
## a small cluster of overlapping billboard blobs (same "several irregular
## overlapping shapes" trick SnowCap.gd uses for snow, just billboarded
## quads instead of spheres).
##
## Dusk lighting pass: clouds are no longer flat white - each one is tinted
## between the warm alpenglow family (near the setting sun's azimuth) and
## the shadowed dusk plum (opposite side), so the whole layer agrees with
## the LowPolySky gradient and the Sun direction. Clouds also bob very
## slightly and drift at individual speeds, sold from cached per-cloud data
## so _process allocates nothing.

const CLOUD_COUNT := 14
const DRIFT_SPEED_MIN := 0.4
const DRIFT_SPEED_MAX := 0.9  # units/sec along +X, per cloud
const FIELD_RADIUS := 320.0
const HEIGHT_MIN := 40.0
const HEIGHT_MAX := 70.0
const WRAP_LIMIT := 380.0  # once a cloud drifts past this on X, it wraps to the opposite side
const BOB_AMPLITUDE := 1.2
const BOB_SPEED := 0.12

# ART_DIRECTION.md palette: sunlit cloud faces vs. shadowed dusk bellies.
const CLOUD_SUNLIT := Color(0.965, 0.847, 0.769)  # #F6D8C4 alpenglow
const CLOUD_WARM := Color(0.941, 0.635, 0.557)    # #F0A28E blush
const CLOUD_SHADOW := Color(0.549, 0.278, 0.4)    # #8C4766 dusk plum
const SUN_AZIMUTH := -0.96  # matches Arena.tscn's Sun yaw (145deg)

var _clouds: Array = []  # dictionaries: {node, speed, base_y, phase}
var _time: float = 0.0

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
	# How much this cloud faces the sunset: 1 near the sun's azimuth, 0
	# opposite it - drives the warm-vs-plum tint for the whole cluster.
	var azimuth: float = atan2(root.position.z, root.position.x)
	var facing: float = clampf(cos(azimuth - SUN_AZIMUTH) * 0.5 + 0.5, 0.0, 1.0)
	var cluster_color: Color = CLOUD_SHADOW.lerp(CLOUD_WARM, facing)

	var blob_count: int = randi_range(4, 6)
	for b in blob_count:
		var size: float = randf_range(6.0, 15.0)
		var mesh := QuadMesh.new()
		mesh.size = Vector2(size, size * randf_range(0.4, 0.55))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		# Blobs higher in the cluster catch a touch more of the pale sunlit
		# tone, lower blobs sit in the cluster color - a cheap lit/shadowed
		# read inside each cloud.
		var lift: float = randf()
		mat.albedo_color = cluster_color.lerp(CLOUD_SUNLIT, lift * 0.55)
		mat.albedo_color.a = randf_range(0.45, 0.7)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_receive_shadows = true
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(randf_range(-5.0, 5.0), lift * 1.6 - 0.8, randf_range(-2.0, 2.0))
		root.add_child(mi)
	_clouds.append({
		"node": root,
		"speed": randf_range(DRIFT_SPEED_MIN, DRIFT_SPEED_MAX),
		"base_y": root.position.y,
		"phase": randf() * TAU,
	})

func _process(delta: float) -> void:
	_time += delta
	for cloud in _clouds:
		var node: Node3D = cloud["node"]
		node.position.x += cloud["speed"] * delta
		node.position.y = cloud["base_y"] + sin(_time * BOB_SPEED + cloud["phase"]) * BOB_AMPLITUDE
		if node.position.x > WRAP_LIMIT:
			node.position.x = -WRAP_LIMIT
