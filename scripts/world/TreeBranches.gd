extends Node3D
## Adds a handful of procedural branch stubs radiating out from the trunk,
## poking out around/below the canopy - the canopy cone alone is a smooth,
## branchless shape, so a few real branch stubs (with a little per-tree
## random variation in count/angle/length) break that up and read as an
## actual tree instead of a solid cone on a stick. Parented directly under
## each Tree's root (a sibling of Trunk/Canopy) so local Y lines up with
## world height without needing to account for Trunk's own offset.

@export var branch_count_min: int = 5
@export var branch_count_max: int = 8
@export var branch_height_range: Vector2 = Vector2(0.55, 1.9)  # along the trunk
@export var color: Color = Color(0.3, 0.21, 0.13)

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

	var mi := MeshInstance3D.new()
	mi.mesh = branch
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat

	mi.position = Vector3(0, y, 0) + dir * (length * 0.5)
	var arbitrary: Vector3 = Vector3.RIGHT if absf(dir.y) < 0.9 else Vector3.FORWARD
	var x_axis: Vector3 = arbitrary.cross(dir).normalized()
	var z_axis: Vector3 = dir.cross(x_axis).normalized()
	mi.transform.basis = Basis(x_axis, dir, z_axis)
	add_child(mi)
