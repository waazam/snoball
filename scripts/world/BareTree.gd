extends Node3D
## A second tree type for visual variety: a bare, snow-dusted deciduous
## tree - a trunk with several long forking branches, each tipped with a
## small snow clump - instead of the conifer's solid cone canopy. Built
## entirely in code (trunk, branches, snow clumps, and the trunk's own
## collision) like TreeBranches.gd/HatVisuals.gd, so placing one is just a
## single node with this script attached, no extra .tscn resources needed.
##
## Character pass (visual only - the trunk collision cylinder is byte-for-
## byte what it always was): flared root spurs at the base, a crooked
## leader continuing past the trunk top at a random lean, secondary twigs
## forking off every branch, and snow settled on tips AND along the upper
## side of thicker branches. Bark uses the shared WOOD_BARK palette color,
## snow the shared arena snow white (ART_DIRECTION.md Section 3).

@export var trunk_height: float = 2.6
@export var trunk_radius: float = 0.14
@export var branch_count_min: int = 6
@export var branch_count_max: int = 9

const TRUNK_COLOR := Color(0.29, 0.2, 0.145)  # #4A3325 WOOD_BARK
const SNOW_COLOR := Color(0.918, 0.949, 0.984)  # #EAF2FB

static var _bark_mat: StandardMaterial3D
static var _snow_mat: StandardMaterial3D

static func _bark_material() -> StandardMaterial3D:
	if _bark_mat == null:
		_bark_mat = StandardMaterial3D.new()
		_bark_mat.albedo_color = TRUNK_COLOR
		_bark_mat.roughness = 0.92
	return _bark_mat

static func _snow_material() -> StandardMaterial3D:
	if _snow_mat == null:
		_snow_mat = StandardMaterial3D.new()
		_snow_mat.albedo_color = SNOW_COLOR
		_snow_mat.roughness = 0.9
	return _snow_mat

func _ready() -> void:
	_build_trunk()
	_build_roots()
	_build_leader()
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
	mi.material_override = _bark_material()
	body.add_child(mi)

	var shape := CylinderShape3D.new()
	shape.radius = trunk_radius
	shape.height = trunk_height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)

## 3-4 small tilted spur cones around the base - the flared roots that
## anchor an old bare tree into the ground instead of it ending in a clean
## pole-in-snow line. Pure decoration, no collision.
func _build_roots() -> void:
	var count: int = randi_range(3, 4)
	var start: float = randf() * TAU
	for i in count:
		var angle: float = start + (TAU / count) * i + randf_range(-0.4, 0.4)
		var length: float = randf_range(0.3, 0.5)
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.01
		mesh.bottom_radius = trunk_radius * randf_range(0.5, 0.75)
		mesh.height = length
		mesh.radial_segments = 5
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _bark_material()
		var dir := Vector3(cos(angle), randf_range(0.9, 1.4), sin(angle)).normalized()
		mi.position = Vector3(cos(angle) * trunk_radius * 0.9, 0.05, sin(angle) * trunk_radius * 0.9) + dir * (length * 0.4)
		_orient_along(mi, dir)
		add_child(mi)

## A thinner, crooked continuation of the trunk past its top - the dead
## leader that gives the winter-tree silhouette its characteristic kink.
func _build_leader() -> void:
	var length: float = randf_range(0.7, 1.1)
	var lean: float = deg_to_rad(randf_range(8.0, 22.0))
	var angle: float = randf() * TAU
	var dir := Vector3(cos(angle) * sin(lean), cos(lean), sin(angle) * sin(lean)).normalized()

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.015
	mesh.bottom_radius = trunk_radius * 0.55
	mesh.height = length
	mesh.radial_segments = 6

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _bark_material()
	var base := Vector3(0, trunk_height * 0.98, 0)
	mi.position = base + dir * (length * 0.5)
	_orient_along(mi, dir)
	add_child(mi)
	_spawn_snow_clump(base + dir * length, randf_range(0.1, 0.16))

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
	branch.radial_segments = 6

	var mi := MeshInstance3D.new()
	mi.mesh = branch
	mi.material_override = _bark_material()

	var base: Vector3 = Vector3(0, y, 0)
	var tip: Vector3 = base + dir * length
	mi.position = base + dir * (length * 0.5)
	_orient_along(mi, dir)
	add_child(mi)

	# Snow riding the branch's upper side about two-thirds out - reads as a
	# soft loaded line, not just dots at the ends.
	if thickness > 0.04:
		_spawn_snow_clump(base + dir * (length * 0.62) + Vector3(0, thickness * 1.2, 0), randf_range(0.08, 0.13))
	_spawn_twigs(base, dir, length, thickness)
	_spawn_snow_clump(tip, randf_range(0.14, 0.22))

## 1-2 thin twigs forking off the outer half of a branch, angled upward -
## the fine forked structure that separates "bare tree" from "coat rack".
func _spawn_twigs(base: Vector3, dir: Vector3, length: float, thickness: float) -> void:
	var twig_count: int = randi_range(1, 2)
	for i in twig_count:
		var along: float = randf_range(0.5, 0.85)
		var start: Vector3 = base + dir * (length * along)
		var side := dir.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var twig_dir: Vector3 = (dir * 0.5 + side * randf_range(-0.7, 0.7) + Vector3.UP * randf_range(0.5, 1.0)).normalized()
		var twig_len: float = randf_range(0.3, 0.55)

		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.006
		mesh.bottom_radius = thickness * 0.45
		mesh.height = twig_len
		mesh.radial_segments = 4

		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _bark_material()
		mi.position = start + twig_dir * (twig_len * 0.5)
		_orient_along(mi, twig_dir)
		add_child(mi)
		if randf() < 0.6:
			_spawn_snow_clump(start + twig_dir * twig_len, randf_range(0.07, 0.12))

func _spawn_snow_clump(tip: Vector3, size: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 7
	mesh.rings = 4

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _snow_material()
	mi.scale = Vector3(1.0, 0.65, 1.0)
	mi.position = tip + Vector3(0, size * 0.3, 0)
	add_child(mi)

## Aligns a MeshInstance3D's local Y axis with dir (the cylinder length axis).
func _orient_along(mi: MeshInstance3D, dir: Vector3) -> void:
	var arbitrary: Vector3 = Vector3.RIGHT if absf(dir.y) < 0.9 else Vector3.FORWARD
	var x_axis: Vector3 = arbitrary.cross(dir).normalized()
	var z_axis: Vector3 = dir.cross(x_axis).normalized()
	mi.transform.basis = Basis(x_axis, dir, z_axis)
