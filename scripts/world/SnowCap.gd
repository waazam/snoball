extends Node3D
## A small cluster of overlapping, slightly-squashed snow-blob meshes
## sitting on top of an object (crate, rock) - several irregular
## overlapping lumps instead of one smooth dome, so it reads as a clumpy
## settled drift rather than a perfect cap.
##
## Dusk pass: blobs draw from two shared materials - bright arena snow
## (#EAF2FB) and a subtly blue-shadowed variant leaning toward #8FA3C8 -
## so a drift has cool recesses between lit lumps instead of being one
## flat white, per ART_DIRECTION.md's blue-shadow snow rule. Shared static
## materials mean the dozens of caps across the arena cost two materials
## total instead of one each.

@export var cap_radius: float = 0.5
@export var blob_count: int = 5
@export var blob_size_min: float = 0.16
@export var blob_size_max: float = 0.3

const SNOW_LIT := Color(0.918, 0.949, 0.984)     # #EAF2FB
const SNOW_SHADOW := Color(0.561, 0.639, 0.784)  # #8FA3C8
const SHADOW_CHANCE := 0.35

static var _lit_mat: StandardMaterial3D
static var _shadow_mat: StandardMaterial3D

static func _lit_material() -> StandardMaterial3D:
	if _lit_mat == null:
		_lit_mat = StandardMaterial3D.new()
		_lit_mat.albedo_color = SNOW_LIT
		_lit_mat.roughness = 0.9
	return _lit_mat

static func _shadow_material() -> StandardMaterial3D:
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.albedo_color = SNOW_LIT.lerp(SNOW_SHADOW, 0.35)
		_shadow_mat.roughness = 0.92
	return _shadow_mat

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
	mi.material_override = _shadow_material() if randf() < SHADOW_CHANCE else _lit_material()
	mi.scale = Vector3(1.0, randf_range(0.5, 0.68), 1.0)  # settled/squashed rather than a perfect ball
	mi.position = Vector3(cos(angle) * dist, size * 0.3, sin(angle) * dist)
	add_child(mi)
