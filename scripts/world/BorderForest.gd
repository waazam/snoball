extends Node3D
## The arena's visible world border: a ring of giant (~5x scale) pine
## trees scattered just outside the play area, replacing the old faceted
## ice-wall panels (LowPolyWall.gd) with a looming tree line. Each tree
## reuses PineCanopy.gd's tiered-canopy generator at a normal tree's local
## dimensions, then the whole tree is scaled up via its own root Node3D -
## same trick as scaling up any other prop, just applied to a procedural
## sub-tree instead of a static mesh. Each one's canopy_material is a
## duplicate of the shared arena canopy material with its albedo tinted
## into a random dark-to-medium green, so the tree line reads as a mixed
## forest rather than a repeated cutout.
##
## Purely decorative - the actual play-area boundary is still the
## invisible Walls/Wall* StaticBody3D + CollisionShape3D boxes (unchanged),
## so gaps between these giant trunks don't open an escape route.

const PINE_CANOPY_SCRIPT := preload("res://scripts/world/PineCanopy.gd")

@export var half_extent: float = 44.0  # ring runs outside the 80x80 ground/walls (edges at +-40)
@export var spacing: float = 16.0       # rough distance between trees along one side - tighter than the
                                         # trees are wide now that they're half-size, so the line still reads solid
@export var scale_min: float = 4.5
@export var scale_max: float = 5.75
@export var trunk_material: Material
@export var canopy_material: Material

const DARK_GREEN := Color(0.55, 0.8, 0.6)     # albedo tint multiplied onto the canopy texture
const MEDIUM_GREEN := Color(0.85, 1.05, 0.88)

func _ready() -> void:
	_scatter_side(Vector3(-half_extent, 0, -half_extent), Vector3(half_extent, 0, -half_extent))  # north
	_scatter_side(Vector3(-half_extent, 0, half_extent), Vector3(half_extent, 0, half_extent))    # south
	_scatter_side(Vector3(half_extent, 0, -half_extent), Vector3(half_extent, 0, half_extent))    # east
	_scatter_side(Vector3(-half_extent, 0, -half_extent), Vector3(-half_extent, 0, half_extent))  # west

func _scatter_side(from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	var count: int = maxi(1, int(round(length / spacing)))
	for i in count + 1:
		var t: float = float(i) / float(count)
		var pos: Vector3 = from.lerp(to, t)
		pos.x += randf_range(-spacing * 0.2, spacing * 0.2)
		pos.z += randf_range(-spacing * 0.2, spacing * 0.2)
		_spawn_tree(pos)

func _spawn_tree(pos: Vector3) -> void:
	var tree := Node3D.new()
	var s: float = randf_range(scale_min, scale_max)
	tree.scale = Vector3(s, s, s)
	tree.position = pos
	tree.rotation.y = randf() * TAU
	add_child(tree)

	_build_trunk(tree)
	_build_canopy(tree)

func _build_trunk(tree: Node3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.15
	mesh.bottom_radius = 0.2
	mesh.height = 2.0
	mesh.radial_segments = 10

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if trunk_material:
		mi.material_override = trunk_material
	mi.position = Vector3(0, 1.0, 0)
	tree.add_child(mi)

func _build_canopy(tree: Node3D) -> void:
	var canopy := Node3D.new()
	canopy.set_script(PINE_CANOPY_SCRIPT)
	canopy.canopy_material = _shade_material()
	canopy.base_radius = 1.5
	# Taller than an arena tree's canopy and set lower on the trunk (see
	# position.y below) so the tiers stack further down towards the ground
	# instead of floating above a bare trunk - reads as a fuller tree.
	canopy.total_height = 3.4
	canopy.tier_count_min = 6
	canopy.tier_count_max = 9
	canopy.foliage_tuft_count_min = 8
	canopy.foliage_tuft_count_max = 14
	canopy.snow_clump_count_min = 0  # these are a green forest line, not snow-dusted like the arena trees
	canopy.snow_clump_count_max = 1
	canopy.position = Vector3(0, 2.2, 0)
	tree.add_child(canopy)

## Duplicates the shared canopy material so this tree can get its own
## random dark-to-medium green tint without affecting any other tree's
## (or the arena trees') shared material resource.
func _shade_material() -> Material:
	if canopy_material == null:
		return null
	var mat: Material = canopy_material.duplicate()
	if mat is StandardMaterial3D:
		mat.albedo_color = DARK_GREEN.lerp(MEDIUM_GREEN, randf())
		mat.uv1_scale = Vector3(5, 5, 1)  # mesh is ~5x bigger - retile so the texture stays crisp, not stretched
	return mat
