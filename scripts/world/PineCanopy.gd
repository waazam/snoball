extends Node3D
## Procedural layered pine canopy: several stacked, irregularly-sized cone
## tiers - wide and squat at the base, narrowing to a point at the top,
## each nudged/rotated a little and overlapping the one below - plus a
## scattering of small foliage tufts across the tiers' slanted faces, snow
## clumps along the seams, settled snow "shelves" riding each tier's lower
## rim, and a snow-dusted tip. A single smooth cone reads as a traffic cone
## on a stick; the tiers break up that silhouette into foliage "shelves,"
## and the tufts break each shelf's own smooth surface up further into a
## bushy, needle-cluster texture.
## Built in code (like TreeBranches.gd/BareTree.gd/SnowCap.gd) so every
## tree gets its own random variation from one shared script + material,
## no extra .tscn resources needed. beam_height/beam_base_radius on a
## sibling ChristmasLights node should still match total_height/base_radius
## below, since the light spiral is math-driven and doesn't follow this mesh.
##
## All tuft/snow materials are shared statics (one per palette color for
## the whole game) instead of a fresh StandardMaterial3D per blob - with
## 60+ scattered MapFiller trees each carrying ~20 blobs that's hundreds of
## duplicate materials saved.

@export var tier_count_min: int = 4
@export var tier_count_max: int = 6
@export var base_radius: float = 1.3
@export var total_height: float = 2.8
@export var canopy_material: Material
@export var snow_clump_count_min: int = 4
@export var snow_clump_count_max: int = 7
@export var foliage_tuft_count_min: int = 10
@export var foliage_tuft_count_max: int = 16

## ART_DIRECTION.md 6a pine family + snow.
const SNOW_COLOR := Color(0.918, 0.949, 0.984)  # #EAF2FB
const FOLIAGE_COLORS := [
	Color(0.082, 0.18, 0.106),   # #152E1B
	Color(0.11, 0.239, 0.141),   # #1C3D24
	Color(0.165, 0.322, 0.196),  # #2A5232
	Color(0.227, 0.42, 0.259),   # #3A6B42
]

static var _snow_mat: StandardMaterial3D
static var _foliage_mats: Array = []

static func _snow_material() -> StandardMaterial3D:
	if _snow_mat == null:
		_snow_mat = StandardMaterial3D.new()
		_snow_mat.albedo_color = SNOW_COLOR
		_snow_mat.roughness = 0.9
	return _snow_mat

static func _foliage_material(idx: int) -> StandardMaterial3D:
	if _foliage_mats.is_empty():
		for c in FOLIAGE_COLORS:
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.roughness = 0.9
			_foliage_mats.append(m)
	return _foliage_mats[idx % _foliage_mats.size()]

func _ready() -> void:
	var tier_count: int = randi_range(tier_count_min, tier_count_max)
	var tiers: Array[Dictionary] = _build_tiers(tier_count)
	_scatter_foliage(tiers)
	_scatter_snow(tiers)
	_ring_snow_shelves(tiers)
	_snow_tip()

## Stacks tier_count cone frustums from a wide base up to a narrow tip,
## each tier's height padded so it overlaps into the next (no gaps), and
## each one jittered slightly off-center and spun a random amount so the
## stack doesn't line up into a perfectly straight cone. Returns each
## tier's local y-range and top/bottom radius for the scatter passes to
## place things along afterwards.
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
		else:
			mi.material_override = _foliage_material(1)  # PINE_DARK fallback

		var jitter: float = base_radius * 0.06 * (1.0 - t)
		mi.position = Vector3(randf_range(-jitter, jitter), y + h * 0.5, randf_range(-jitter, jitter))
		mi.rotation.y = randf() * TAU
		add_child(mi)

		tiers.append({"y_bottom": y, "y_top": y + h, "bottom_r": bottom_r, "top_r": top_r})
		y += advance

	return tiers

## Scatters small squashed-blob foliage tufts across the tiers' slanted
## faces (at a random height within a random tier, not just its rim) -
## flat green blobs in the four palette pine shades, biased so darker
## shades sit low in the canopy and the lit #3A6B42 tufts ride high, the
## way low light actually catches a pine at dusk.
func _scatter_foliage(tiers: Array[Dictionary]) -> void:
	if tiers.is_empty():
		return
	var count: int = randi_range(foliage_tuft_count_min, foliage_tuft_count_max)
	for i in count:
		var tier_idx: int = randi() % tiers.size()
		var tier: Dictionary = tiers[tier_idx]
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
		# Height bias: 0..3 index climbs from dark to lit as tufts sit higher.
		var height_t: float = float(tier_idx) / float(maxi(tiers.size() - 1, 1))
		var shade: int = clampi(int(height_t * 3.0 + randf_range(-0.8, 1.2)), 0, 3)
		mi.material_override = _foliage_material(shade)
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
		_spawn_snow_blob(Vector3(cos(angle) * dist, y, sin(angle) * dist), randf_range(0.1, 0.2), 0.55)

## Fresh pass: two wider, flatter drifts riding each of the lower tiers'
## outer rims - the "shelf of settled snow" every snow-loaded pine carries,
## which reads clearly in silhouette from gameplay camera distance. Only
## the bottom three tiers get shelves (they're the visible ones from the
## gameplay camera) to keep per-tree node counts web-friendly.
func _ring_snow_shelves(tiers: Array[Dictionary]) -> void:
	var shelf_tiers: int = mini(tiers.size(), 3)
	for i in shelf_tiers:
		var tier: Dictionary = tiers[i]
		var start: float = randf() * TAU
		for s in 2:
			var angle: float = start + PI * s + randf_range(-0.5, 0.5)
			var dist: float = tier["bottom_r"] * randf_range(0.8, 0.98)
			var y: float = lerpf(tier["y_bottom"], tier["y_top"], 0.08)
			_spawn_snow_blob(Vector3(cos(angle) * dist, y, sin(angle) * dist), randf_range(0.16, 0.26), 0.4)

## A little snow dusting right on the canopy's tip.
func _snow_tip() -> void:
	_spawn_snow_blob(Vector3(0, total_height * 0.5 + 0.05, 0), randf_range(0.12, 0.18), 0.6)

func _spawn_snow_blob(pos: Vector3, size: float, squash: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 7
	mesh.rings = 4

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _snow_material()
	mi.scale = Vector3(1.0, squash, 1.0)
	mi.position = pos
	add_child(mi)
