extends Node3D
## Extra scatter of full-size, walkable/collidable trees, boulders, and a
## few platform+ramp pairs across the enlarged map's outer ring - the area
## between the original hand-placed combat cluster near spawn and the much
## farther-out walls (+-120), which would otherwise be bare open snow.
## Same "everything built in code" approach as BillboardForest.gd/
## PineCanopy.gd/BorderForest.gd, just walkable-scale content instead of a
## background backdrop.

const PINE_CANOPY_SCRIPT := preload("res://scripts/world/PineCanopy.gd")
const SNOW_CAP_SCRIPT := preload("res://scripts/world/SnowCap.gd")
const ORNAMENT_CAP_SCRIPT := preload("res://scripts/world/OrnamentCap.gd")

const INNER_RADIUS := 32.0  # stays clear of the hand-placed obstacle cluster near spawn
const OUTER_RADIUS := 94.0  # stays inside the walls (+-100)
const TREE_COUNT := 65
const ROCK_COUNT := 65
const PLATFORM_COUNT := 12

# Same 5 hues Arena.tscn's hand-placed Rock1-6 cycle through
# (StdMat_ornament_red/gold/green/blue/silver) - built once here instead of
# exported/wired per-material so each of the 65 scattered ornaments can pick
# a random one, rather than all sharing a single material like the old
# rock_material export did.
const ORNAMENT_COLORS: Array[Color] = [
	Color(0.909804, 0.282353, 0.243137, 1),
	Color(1, 0.721569, 0.301961, 1),
	Color(0.309804, 0.74902, 0.419608, 1),
	Color(0.356863, 0.560784, 0.85098, 1),
	Color(0.788235, 0.827451, 0.878431, 1),
]

@export var trunk_material: Material
@export var canopy_material: Material
@export var platform_material: Material

var _ornament_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	for c in ORNAMENT_COLORS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.metallic = 0.35
		mat.roughness = 0.2
		_ornament_materials.append(mat)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	# Separate RNG for the purely-cosmetic additions (canopy proportions,
	# snow caps, ornament color) so the main rng's draw sequence - and
	# therefore every collidable tree/rock/platform position - stays exactly
	# what it was before the visual overhaul.
	var vis_rng := RandomNumberGenerator.new()
	vis_rng.seed = 555
	for i in TREE_COUNT:
		_spawn_tree(rng, vis_rng)
	for i in ROCK_COUNT:
		_spawn_rock(rng, vis_rng)
	for i in PLATFORM_COUNT:
		_spawn_platform(rng, vis_rng)

## y is the actual terrain height at (x, z) (see TerrainHeight.gd), not a
## flat 0 - the ground out here rolls now, so every caller below builds on
## top of this instead of assuming flat ground like it used to.
func _random_point(rng: RandomNumberGenerator) -> Vector3:
	var angle: float = rng.randf() * TAU
	# sqrt bias so points don't bunch up near the inner edge - even density
	# across the ring's actual area, not just its radius.
	var radius: float = lerpf(INNER_RADIUS, OUTER_RADIUS, sqrt(rng.randf()))
	var x: float = cos(angle) * radius
	var z: float = sin(angle) * radius
	return Vector3(x, TerrainHeight.get_height(x, z), z)

## Same trunk-cylinder + PineCanopy.gd combo Arena.tscn's hand-placed
## Tree1-10 use, minus the Christmas lights (these are background fill,
## not the decorated centerpiece trees). Canopy proportions vary per tree
## (vis_rng) so the scattered forest gets slim spires next to squat firs -
## the hand-placed decorated trees keep their default 1.3/2.8 shape since
## their light spirals are tuned to it.
func _spawn_tree(rng: RandomNumberGenerator, vis_rng: RandomNumberGenerator) -> void:
	var tree := Node3D.new()
	tree.position = _random_point(rng)
	tree.rotation.y = rng.randf() * TAU
	var s: float = rng.randf_range(0.85, 1.25)
	tree.scale = Vector3(s, s, s)
	add_child(tree)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.15
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 10
	var trunk_body := StaticBody3D.new()
	trunk_body.position = Vector3(0, 1, 0)
	tree.add_child(trunk_body)
	var trunk_mi := MeshInstance3D.new()
	trunk_mi.mesh = trunk_mesh
	if trunk_material:
		trunk_mi.material_override = trunk_material
	trunk_body.add_child(trunk_mi)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.2
	trunk_shape.height = 2.0
	var trunk_cs := CollisionShape3D.new()
	trunk_cs.shape = trunk_shape
	trunk_body.add_child(trunk_cs)

	var canopy := Node3D.new()
	canopy.set_script(PINE_CANOPY_SCRIPT)
	canopy.canopy_material = canopy_material
	canopy.base_radius = vis_rng.randf_range(1.05, 1.55)
	canopy.total_height = vis_rng.randf_range(2.4, 3.4)
	canopy.position = Vector3(0, 3.0, 0)
	tree.add_child(canopy)

## Despite the name, these are Christmas ornaments now (see Arena.tscn's
## hand-placed Rock1-6/OrnamentCap.gd) - kept as "rock" throughout since
## that's still their placement/collision role (scattered boulder-scale
## obstacles), just re-skinned.
func _spawn_rock(rng: RandomNumberGenerator, vis_rng: RandomNumberGenerator) -> void:
	var rock := StaticBody3D.new()
	var s: float = rng.randf_range(0.7, 2.0)
	var pos: Vector3 = _random_point(rng)
	pos.y += s  # rest ON the terrain height _random_point already gave it, not overwrite it
	rock.position = pos
	rock.scale = Vector3(s, s, s)
	add_child(rock)

	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _ornament_materials[vis_rng.randi() % _ornament_materials.size()]
	rock.add_child(mi)

	var shape := SphereShape3D.new()
	shape.radius = 1.0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	rock.add_child(cs)

	var ornament_cap := Node3D.new()
	ornament_cap.set_script(ORNAMENT_CAP_SCRIPT)
	rock.add_child(ornament_cap)

	# Settled snow on most ornaments (visual only, no collision) - the same
	# SnowCap clusters the hand-placed crates/rocks in Arena.tscn carry, so
	# the scattered ring matches the combat cluster's dressing.
	if vis_rng.randf() < 0.8:
		var cap := Node3D.new()
		cap.set_script(SNOW_CAP_SCRIPT)
		cap.cap_radius = 0.45
		cap.blob_count = 4
		cap.position = Vector3(0, 0.82, 0)
		rock.add_child(cap)

## A boxy platform plus an angled ramp leading up to it, same shapes
## Terrain/PlatformA-B/RampA-B already use, just scattered with random
## size/position instead of hand-placed.
func _spawn_platform(rng: RandomNumberGenerator, vis_rng: RandomNumberGenerator) -> void:
	var pos: Vector3 = _random_point(rng)
	var width: float = rng.randf_range(5.0, 8.0)
	var height: float = rng.randf_range(1.4, 2.4)
	var facing: float = rng.randf() * TAU

	var platform := StaticBody3D.new()
	platform.position = pos + Vector3(0, height * 0.5, 0)
	add_child(platform)
	var p_mesh := BoxMesh.new()
	p_mesh.size = Vector3(width, height, width)
	var p_mi := MeshInstance3D.new()
	p_mi.mesh = p_mesh
	if platform_material:
		p_mi.material_override = platform_material
	platform.add_child(p_mi)
	var p_shape := BoxShape3D.new()
	p_shape.size = p_mesh.size
	var p_cs := CollisionShape3D.new()
	p_cs.shape = p_shape
	platform.add_child(p_cs)

	# Snow drift across the platform top (visual only, no collision).
	var cap := Node3D.new()
	cap.set_script(SNOW_CAP_SCRIPT)
	cap.cap_radius = width * 0.28
	cap.blob_count = 6
	cap.blob_size_min = 0.2
	cap.blob_size_max = 0.38
	cap.position = Vector3(0, height * 0.5 - 0.04, 0)
	platform.add_child(cap)

	var ramp_len: float = height / sin(deg_to_rad(20.0))
	var ramp_dir := Vector3(sin(facing), 0, cos(facing))
	var ramp := StaticBody3D.new()
	ramp.position = pos + Vector3(0, height * 0.5, 0) + ramp_dir * (width * 0.5 + ramp_len * 0.5 * cos(deg_to_rad(20.0)))
	ramp.rotation.y = facing
	ramp.rotation.x = deg_to_rad(20.0)
	add_child(ramp)
	var r_mesh := BoxMesh.new()
	r_mesh.size = Vector3(width * 0.55, 0.4, ramp_len)
	var r_mi := MeshInstance3D.new()
	r_mi.mesh = r_mesh
	if platform_material:
		r_mi.material_override = platform_material
	ramp.add_child(r_mi)
	var r_shape := BoxShape3D.new()
	r_shape.size = r_mesh.size
	var r_cs := CollisionShape3D.new()
	r_cs.shape = r_shape
	ramp.add_child(r_cs)
