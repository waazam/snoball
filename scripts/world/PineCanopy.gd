extends Node3D
## Procedural layered pine canopy: several stacked, irregularly-sized cone
## tiers - wide and squat at the base, narrowing to a point at the top,
## each nudged/rotated a little and overlapping the one below - plus a
## scattering of small foliage tufts across the tiers' slanted faces and a
## few snow clumps along a couple of seams. A single smooth cone reads as
## a traffic cone on a stick; the tiers break up that silhouette into
## foliage "shelves," and the tufts break each shelf's own smooth surface
## up further into a bushy, needle-cluster texture - together that's what
## gives the canopy a full, leafy body instead of a bare geometric shape.
## Built in code (like TreeBranches.gd/BareTree.gd/SnowCap.gd) so every
## tree gets its own random variation from one shared script + material,
## no extra .tscn resources needed. beam_height/beam_base_radius on a
## sibling ChristmasLights node should still match total_height/base_radius
## below, since the light spiral is math-driven and doesn't follow this mesh.

@export var tier_count_min: int = 4
@export var tier_count_max: int = 6
@export var base_radius: float = 1.3
@export var total_height: float = 2.8
@export var canopy_material: Material
@export var snow_clump_count_min: int = 3
@export var snow_clump_count_max: int = 6
@export var foliage_tuft_count_min: int = 8
@export var foliage_tuft_count_max: int = 14

const SNOW_COLOR := Color(0.95, 0.97, 1.0)
const FOLIAGE_COLORS := [
	Color(0.11, 0.24, 0.14),
	Color(0.16, 0.32, 0.2),
	Color(0.22, 0.4, 0.26),
	Color(0.27, 0.46, 0.3),
]

func _ready() -> void:
	var tier_count: int = randi_range(tier_count_min, tier_count_max)
	var tiers: Array[Dictionary] = _build_tiers(tier_count)
	_scatter_foliage(tiers)
	_scatter_snow(tiers)

## Stacks tier_count cone frustums from a wide base up to a narrow tip,
## each tier's height padded so it overlaps into the next (no gaps), and
## each one jittered slightly off-center and spun a random amount so the
## stack doesn't line up into a perfectly straight cone. Returns each
## tier's local y-range and top/bottom radius for _scatter_foliage/
## _scatter_snow to place things along afterwards.
func _build_tiers(tier_count: int) -> Array[Dictionary]:
	var tiers: Array[Dictionary] = []
	var bottom_y: float = -total_height * 0.5
	var tier_height: float = total_height * 1.5 / float(tier_count)  # padded so tiers overlap
	var advance: float = total_height / float(tier_count)

	var y: float = bottom_y
	for i in tier_count:
		var t: float = float(i) / float(maxi(tier_count - 1, 1))
		var bottom_r: float = lerpf(base_radius, base_radius * 0.22, t) * randf_range(0.9, 1.1)
		var top_r: float = bottom_r * randf_range(0.1, 0.25)
		var h: float = tier_height * randf_range(0.85, 1.15)

		var mesh := CylinderMesh.new()
		mesh.top_radius = top_r
		mesh.bottom_radius = bottom_r
		mesh.height = h
		mesh.radial_segments = 8 + (i % 3)  # varies per tier so facets don't line up between tiers

		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		if canopy_material:
			mi.material_override = canopy_material

		var jitter: float = base_radius * 0.06 * (1.0 - t)
		mi.position = Vector3(randf_range(-jitter, jitter), y + h * 0.5, randf_range(-jitter, jitter))
		mi.rotation.y = randf() * TAU
		add_child(mi)

		tiers.append({"y_bottom": y, "y_top": y + h, "bottom_r": bottom_r, "top_r": top_r})
		y += advance

	return tiers

## Scatters small squashed-blob foliage tufts across the tiers' slanted
## faces (at a random height within a random tier, not just its rim) -
## flat, unlit-ish green blobs in a few hand-picked shades so the canopy
## reads as a mass of individual needle clusters instead of a few smooth
## cone surfaces.
func _scatter_foliage(tiers: Array[Dictionary]) -> void:
	if tiers.is_empty():
		return
	var count: int = randi_range(foliage_tuft_count_min, foliage_tuft_count_max)
	for i in count:
		var tier: Dictionary = tiers[randi() % tiers.size()]
		var t: float = randf()
		var y: float = lerpf(tier["y_bottom"], tier["y_top"], t)
		var radius_here: float = lerpf(tier["bottom_r"], tier["top_r"], t)
		var angle: float = randf() * TAU
		var dist: float = radius_here * randf_range(0.75, 1.1)
		var size: float = randf_range(0.14, 0.26)

		var mesh := SphereMesh.new()
		mesh.radius = size
		mesh.height = size * 1.6
		mesh.radial_segments = 6
		mesh.rings = 3

		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = FOLIAGE_COLORS[randi() % FOLIAGE_COLORS.size()]
		mat.roughness = 0.9
		mi.material_override = mat
		mi.scale = Vector3(1.0, 0.7, 1.0)
		mi.position = Vector3(cos(angle) * dist, y, sin(angle) * dist)
		add_child(mi)

## Settles a few squashed snow blobs (SnowCap.gd's look) near the base of
## a couple of random tiers, so the canopy reads as snow-loaded foliage
## shelves rather than a bare green stack.
func _scatter_snow(tiers: Array[Dictionary]) -> void:
	if tiers.is_empty():
		return
	var clump_count: int = randi_range(snow_clump_count_min, snow_clump_count_max)
	for i in clump_count:
		var tier: Dictionary = tiers[randi() % tiers.size()]
		var y: float = lerpf(tier["y_bottom"], tier["y_top"], 0.18)
		var radius_here: float = tier["bottom_r"] * 0.85
		var angle: float = randf() * TAU
		var dist: float = radius_here * randf_range(0.5, 0.95)
		var size: float = randf_range(0.1, 0.2)

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
		mi.scale = Vector3(1.0, 0.55, 1.0)
		mi.position = Vector3(cos(angle) * dist, y, sin(angle) * dist)
		add_child(mi)
