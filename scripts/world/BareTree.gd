extends Node3D
## A second tree type for visual variety: a bare, snow-dusted deciduous
## tree - a trunk with several long forking branches, each tipped with a
## small snow clump - instead of the conifer's solid cone canopy. Built
## entirely in code (trunk, branches, snow clumps, and the trunk's own
## collision) like TreeBranches.gd/HatVisuals.gd, so placing one is just a
## single node with this script attached, no extra .tscn resources needed.

@export var trunk_height: float = 2.6
@export var trunk_radius: float = 0.14
@export var branch_count_min: int = 6
@export var branch_count_max: int = 9

const TRUNK_COLOR := Color(0.32, 0.24, 0.17)
const SNOW_COLOR := Color(0.95, 0.97, 1.0)

func _ready() -> void:
	_build_trunk()
	var count: int = randi_range(branch_count_min, branch_count_max)
	for i in count:
		_spawn_branch(i, count)

func _build_trunk() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = trunk_radius * 0.6
	mesh.bottom_radius = trunk_radius
	mesh.height = trunk_height
	mesh.radial_segments = 7

	var body := StaticBody3D.new()
	add_child(body)
	body.position = Vector3(0, trunk_height * 0.5, 0)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TRUNK_COLOR
	mi.material_override = mat
	body.add_child(mi)

	var shape := CylinderShape3D.new()
	shape.radius = trunk_radius
	shape.height = trunk_height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)

func _spawn_branch(i: int, count: int) -> void:
	var t: float = float(i) / float(maxi(count - 1, 1))
	var y: float = lerpf(trunk_height * 0.55, trunk_height * 0.97, t)
	var angle: float = randf() * TAU
	var length: float = randf_range(0.9, 1.6)
	var thickness: float = randf_range(0.03, 0.055)
	var tilt: float = deg_to_rad(randf_range(20.0, 50.0))

	var dir := Vector3(cos(angle) * cos(tilt), sin(tilt), sin(angle) * cos(tilt)).normalized()

	var branch := CylinderMesh.new()
	branch.top_radius = thickness * 0.2
	branch.bottom_radius = thickness
	branch.height = length

	var mi := MeshInstance3D.new()
	mi.mesh = branch
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TRUNK_COLOR
	mi.material_override = mat

	var base: Vector3 = Vector3(0, y, 0)
	var tip: Vector3 = base + dir * length
	mi.position = base + dir * (length * 0.5)
	var arbitrary: Vector3 = Vector3.RIGHT if absf(dir.y) < 0.9 else Vector3.FORWARD
	var x_axis: Vector3 = arbitrary.cross(dir).normalized()
	var z_axis: Vector3 = dir.cross(x_axis).normalized()
	mi.transform.basis = Basis(x_axis, dir, z_axis)
	add_child(mi)

	_spawn_snow_clump(tip)

func _spawn_snow_clump(tip: Vector3) -> void:
	var size: float = randf_range(0.14, 0.22)
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 7
	mesh.rings = 4

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SNOW_COLOR
	mat.roughness = 0.85
	mi.material_override = mat
	mi.scale = Vector3(1.0, 0.65, 1.0)
	mi.position = tip + Vector3(0, size * 0.3, 0)
	add_child(mi)
