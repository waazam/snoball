extends Node3D
## Visual-only atmosphere prop: three wooden lantern posts ringing the
## central obstacle cluster, each carrying a warm emissive "candle" core
## under a little iron roof, plus an unshadowed OmniLight3D pool of
## EMBER_GOLD light. Uses 3 of the 8 allowed local omnis from the art
## direction's light budget (range <= 6.0, energy <= 1.5, no shadows -
## web-export safe). No collision shapes: these are mood, not obstacles.
##
## Each flame breathes on its own phase-offset sine pair (a slow swell plus
## a faint fast shimmer), the same "still glowing" feel as
## ChristmasLights.gd rather than a hard on/off flicker.

# Palette (ART_DIRECTION.md section 3/4) - copied verbatim.
const WOOD_BARK := Color("#4A3325")
const IRON_DARK := Color("#26221F")
const CANDLE_WHITE := Color("#FFE9C9")
const EMBER_GOLD := Color("#FFB84D")

# Posts sit in the gaps between the central crates/rocks, clear of every
# obstacle footprint and spawn marker in Arena.tscn.
const LANTERN_SPOTS: Array[Vector3] = [
	Vector3(12.5, 0.0, 12.5),
	Vector3(-12.5, 0.0, 12.5),
	Vector3(2.5, 0.0, -18.5),
]

const LIGHT_RANGE := 6.0
const LIGHT_ENERGY_BASE := 1.1   # flicker stays below the 1.5 budget cap
const GLOW_ENERGY_BASE := 1.9    # prop emission band is 1.5-2.5

var _flames: Array = []  # [{mat: StandardMaterial3D, light: OmniLight3D, phase: float}]
var _time: float = 0.0

var _wood_mat: StandardMaterial3D
var _iron_mat: StandardMaterial3D

func _ready() -> void:
	_wood_mat = StandardMaterial3D.new()
	_wood_mat.albedo_color = WOOD_BARK
	_wood_mat.roughness = 0.9

	_iron_mat = StandardMaterial3D.new()
	_iron_mat.albedo_color = IRON_DARK
	_iron_mat.roughness = 0.4
	_iron_mat.metallic = 0.9

	for i in range(LANTERN_SPOTS.size()):
		_build_lantern(LANTERN_SPOTS[i], float(i) * 2.09)

func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build_lantern(spot: Vector3, phase: float) -> void:
	var post := Node3D.new()
	post.position = spot
	post.rotation.y = phase  # each post hangs its lantern a different way
	add_child(post)

	# Slim tapered pole, sunk 0.3 below grade so terrain undulation can't
	# leave the base floating.
	var pole := CylinderMesh.new()
	pole.top_radius = 0.055
	pole.bottom_radius = 0.085
	pole.height = 2.6
	pole.radial_segments = 6
	pole.rings = 1
	_add_mesh(post, pole, _wood_mat, Vector3(0.0, 1.0, 0.0))

	# Crossarm the lantern hangs from.
	var arm := BoxMesh.new()
	arm.size = Vector3(0.5, 0.06, 0.06)
	_add_mesh(post, arm, _wood_mat, Vector3(0.2, 2.22, 0.0))

	# Short hanger link between arm and roof.
	var hanger := CylinderMesh.new()
	hanger.top_radius = 0.018
	hanger.bottom_radius = 0.018
	hanger.height = 0.12
	hanger.radial_segments = 5
	hanger.rings = 1
	_add_mesh(post, hanger, _iron_mat, Vector3(0.42, 2.16, 0.0))

	# Little pyramid roof (4-sided cone).
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 0.17
	roof.height = 0.14
	roof.radial_segments = 4
	roof.rings = 1
	_add_mesh(post, roof, _iron_mat, Vector3(0.42, 2.1, 0.0))

	# Base plate under the glass.
	var base := BoxMesh.new()
	base.size = Vector3(0.18, 0.03, 0.18)
	_add_mesh(post, base, _iron_mat, Vector3(0.42, 1.91, 0.0))

	# The glowing candle-glass core: warm white glass, ember-gold emission.
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = CANDLE_WHITE
	flame_mat.roughness = 0.5
	flame_mat.emission_enabled = true
	flame_mat.emission = EMBER_GOLD
	flame_mat.emission_energy_multiplier = GLOW_ENERGY_BASE
	var glass := BoxMesh.new()
	glass.size = Vector3(0.14, 0.16, 0.14)
	_add_mesh(post, glass, flame_mat, Vector3(0.42, 2.0, 0.0))

	# Warm light pool. Never shadowed (web budget).
	var lamp := OmniLight3D.new()
	lamp.light_color = EMBER_GOLD
	lamp.omni_range = LIGHT_RANGE
	lamp.light_energy = LIGHT_ENERGY_BASE
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.42, 2.0, 0.0)
	post.add_child(lamp)

	_flames.append({"mat": flame_mat, "light": lamp, "phase": phase})

func _process(delta: float) -> void:
	_time += delta
	for f in _flames:
		var swell: float = 0.5 + 0.5 * sin(_time * 1.3 + f["phase"])
		var shimmer: float = 0.12 * sin(_time * 4.7 + f["phase"] * 2.0)
		var flicker: float = clampf(swell + shimmer, 0.0, 1.0)
		f["mat"].emission_energy_multiplier = GLOW_ENERGY_BASE + 0.55 * flicker
		f["light"].light_energy = minf(LIGHT_ENERGY_BASE + 0.3 * flicker, 1.5)
