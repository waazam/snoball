extends Node3D
## A small cluster of overlapping, slightly-squashed snow-blob meshes
## sitting on top of an object (crate, rock) - several irregular
## overlapping lumps instead of one smooth dome, so it reads as a clumpy
## settled drift rather than a perfect cap.

@export var cap_radius: float = 0.5
@export var blob_count: int = 5
@export var blob_size_min: float = 0.16
@export var blob_size_max: float = 0.3

const SNOW_COLOR := Color(0.95, 0.97, 1.0)

func _ready() -> void:
	for i in blob_count:
		_spawn_blob()

func _spawn_blob() -> void:
	var angle: float = randf() * TAU
	var dist: float = sqrt(randf()) * cap_radius
	var size: float = randf_range(blob_size_min, blob_size_max)

	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SNOW_COLOR
	mat.roughness = 0.85
	mi.material_override = mat
	mi.scale = Vector3(1.0, 0.6, 1.0)  # settled/squashed rather than a perfect ball
	mi.position = Vector3(cos(angle) * dist, size * 0.3, sin(angle) * dist)
	add_child(mi)
