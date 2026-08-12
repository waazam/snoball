extends Node3D
## Adds a handful of procedural branch stubs radiating out from the trunk,
## poking out around/below the canopy - the canopy cone alone is a smooth,
## branchless shape, so a few real branch stubs (with a little per-tree
## random variation in count/angle/length) break that up and read as an
## actual tree instead of a solid cone on a stick. Parented directly under
## each Tree's root (a sibling of Trunk/Canopy) so local Y lines up with
## world height without needing to account for Trunk's own offset.
##
## Dusk pass: bark uses the shared WOOD_BARK palette color (#4A3325,
## ART_DIRECTION.md Section 3) through one shared material instead of a
## fresh material per stub, and most stubs now carry a little settled snow
## clump at the tip so they agree with the snow-loaded canopies above.

@export var branch_count_min: int = 5
@export var branch_count_max: int = 8
@export var branch_height_range: Vector2 = Vector2(0.55, 1.9)  # along the trunk
@export var color: Color = Color(0.29, 0.2, 0.145)  # #4A3325 WOOD_BARK

const SNOW_COLOR := Color(0.918, 0.949, 0.984)  # #EAF2FB
const SNOW_CHANCE := 0.7

static var _shared_mats: Dictionary = {}
static var _snow_mat: StandardMaterial3D

static func _bark_material(bark_color: Color) -> StandardMaterial3D:
	if not _shared_mats.has(bark_color):
		var m := StandardMaterial3D.new()
		m.albedo_color = bark_color
		m.roughness = 0.92
		_shared_mats[bark_color] = m
	return _shared_mats[bark_color]

static func _snow_material() -> StandardMaterial3D:
	if _snow_mat == null:
		_snow_mat = StandardMaterial3D.new()
		_snow_mat.albedo_color = SNOW_COLOR
		_snow_mat.roughness = 0.9
	return _snow_mat

func _ready() -> void:
	var count: int = randi_range(branch_count_min, branch_count_max)
	for i in count:
		_spawn_branch()

func _spawn_branch() -> void:
	var y: float = randf_range(branch_height_range.x, branch_height_range.y)
	var angle: float = randf() * TAU
	var length: float = randf_range(0.7, 1.4)
	var thickness: float = randf_range(0.032, 0.06)
	var tilt: float = deg_to_rad(randf_range(15.0, 40.0))

	var dir := Vector3(cos(angle) * cos(tilt), sin(tilt), sin(angle) * cos(tilt)).normalized()

	var branch := CylinderMesh.new()
	branch.top_radius = thickness * 0.25
	branch.bottom_radius = thickness
	branch.height = length
	branch.radial_segments = 6

	var mi := MeshInstance3D.new()
	mi.mesh = branch
	mi.material_override = _bark_material(color)

	mi.position = Vector3(0, y, 0) + dir * (length * 0.5)
	var arbitrary: Vector3 = Vector3.RIGHT if absf(dir.y) < 0.9 else Vector3.FORWARD
	var x_axis: Vector3 = arbitrary.cross(dir).normalized()
	var z_axis: Vector3 = dir.cross(x_axis).normalized()
	mi.transform.basis = Basis(x_axis, dir, z_axis)
	add_child(mi)

	if randf() < SNOW_CHANCE:
		_spawn_tip_snow(Vector3(0, y, 0) + dir * length)

func _spawn_tip_snow(tip: Vector3) -> void:
	var size: float = randf_range(0.08, 0.14)
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _snow_material()
	mi.scale = Vector3(1.0, 0.6, 1.0)
	mi.position = tip + Vector3(0, size * 0.25, 0)
	add_child(mi)
