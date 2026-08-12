class_name HatVisuals
extends RefCounted
## Builds a small procedural mesh assembly for a given hat "shape" + color.
## Shared by the player's equipped-hat visual (Player.gd), the ground
## pickup (HatPickup.gd) and the snowman's throwable top hat
## (EnemySnowman.gd) so every place renders the exact same hat - no
## imported hat models needed.
##
## The returned Node3D's origin is anchored at the TOP of the player's head
## (see Player.tscn's HatAnchor). Local +y points up from there; local -y
## dips down into/around the head, which shapes like the knight helmet use
## to wrap down over the skull instead of floating above it. All dimensions
## below are sized against HEAD_RADIUS so a hat-pickup caller can enlarge
## the whole thing uniformly (see HatPickup.gd's PICKUP_VISUAL_SCALE)
## without needing to re-tune individual parts.
##
## Palette + material rules follow ART_DIRECTION.md ("Alpenglow Dusk"):
## cloth is matte (roughness 0.8), fur rougher still (0.95+), metal is
## roughness 0.35 / metallic 0.9, and emission is reserved for deliberate
## accents (the frost wizard's star). Accent hexes are copied verbatim
## from the master palette - never invented locally.

const HEAD_RADIUS := 0.15  # the head size every hat is proportioned against

const TRIM_WHITE := Color("#F5EFE6")    # fur/cloth trim
const TRIM_DARK := Color("#26221F")     # coal-dark leather/visor slits
const PLUME_RED := Color("#E8483F")     # EMBER_RED accent
const EMBER_GOLD := Color("#FFB84D")    # metallic bands, buckles, studs
const CANDLE_WHITE := Color("#FFE9C9")  # warm pom-poms
const FROST_GLOW := Color("#A8E4FF")    # frost wizard emissive star
const BONE_TIP := Color("#D9C6A8")      # berserker horn tips

static func build(shape: String, color: Color) -> Node3D:
	match shape:
		"knight_helmet":
			return _build_knight_helmet(color)
		"horns":
			return _build_horns(color)
		"cat_ears":
			return _build_cat_ears(color)
		"wizard_hat":
			return _build_wizard_hat(color)
		"top_hat":
			return _build_top_hat(color)
		_:
			return _build_top_hat(color)

# --- Material conventions (see ART_DIRECTION.md section 4) ---------------
static func _cloth(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m

static func _fur(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.97
	return m

static func _metal(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.35
	m.metallic = 0.9
	return m

static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.5
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

# --- Mesh helpers (explicit segment counts keep hats web-budget cheap) ---
static func _cyl(top_r: float, bottom_r: float, height: float, seg: int = 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bottom_r
	m.height = height
	m.radial_segments = seg
	return m

static func _sph(radius: float, seg: int = 16) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = seg
	m.rings = maxi(4, seg / 2)
	return m

static func _hemi(radius: float, seg: int = 20) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius  # hemisphere height = radius
	m.is_hemisphere = true
	m.radial_segments = seg
	m.rings = maxi(4, seg / 2)
	return m

static func _torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 10
	return m

static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

static func _part(mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	return mi

# --- Hats ----------------------------------------------------------------
## Silk top hat: curled brim (torus edge roll), gently flared crown, and a
## metallic gold band + square buckle. Face details sit at +Z (toward the
## chase camera) - same convention the knight visor has always used.
static func _build_top_hat(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "TopHat"
	var silk := _cloth(color)
	# Brim disc + curled edge roll
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.5, HEAD_RADIUS * 1.5, 0.02, 24), silk, Vector3(0, 0.0, 0)))
	root.add_child(_part(_torus(HEAD_RADIUS * 1.38, HEAD_RADIUS * 1.62), silk, Vector3(0, 0.008, 0)))
	# Crown, flared slightly wider at the top, capped
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.12, HEAD_RADIUS * 1.02, 0.24, 20), silk, Vector3(0, 0.13, 0)))
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.13, HEAD_RADIUS * 1.13, 0.018, 20), silk, Vector3(0, 0.252, 0)))
	# Gold band + buckle
	var gold := _metal(EMBER_GOLD)
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.07, HEAD_RADIUS * 1.07, 0.05, 20), gold, Vector3(0, 0.045, 0)))
	root.add_child(_part(_box(Vector3(0.045, 0.055, 0.014)), gold, Vector3(0, 0.048, HEAD_RADIUS * 1.05)))
	return root

## Frost wizard hat: floppy up-turned brim, two-segment bent cone with a
## candle-white pom at the drooping tip, snow-fur band, and an emissive
## frost star (the one emission accent hats are allowed).
static func _build_wizard_hat(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "WizardHat"
	var cloth := _cloth(color)
	# Wide brim with rolled edge
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.72, HEAD_RADIUS * 1.72, 0.022, 24), cloth, Vector3(0, 0.0, 0)))
	root.add_child(_part(_torus(HEAD_RADIUS * 1.6, HEAD_RADIUS * 1.84), cloth, Vector3(0, 0.01, 0)))
	# Snow-fur band hugging the cone base
	root.add_child(_part(_torus(HEAD_RADIUS * 0.82, HEAD_RADIUS * 1.28), _fur(TRIM_WHITE), Vector3(0, 0.035, 0)))
	# Bent cone: straight lower segment, drooping upper segment, pom tip
	root.add_child(_part(_cyl(0.045, HEAD_RADIUS * 1.05, 0.2, 16), cloth, Vector3(0, 0.12, 0), Vector3(-6, 0, 0)))
	root.add_child(_part(_cyl(0.006, 0.044, 0.16, 12), cloth, Vector3(0, 0.285, -0.032), Vector3(-24, 0, 0)))
	root.add_child(_part(_sph(0.034, 12), _fur(CANDLE_WHITE), Vector3(0, 0.352, -0.078)))
	# Emissive frost star (camera-facing) + two tiny drifting glints
	var star := _glow(FROST_GLOW, 1.5)
	root.add_child(_part(_box(Vector3(0.062, 0.018, 0.012)), star, Vector3(0, 0.12, 0.105)))
	root.add_child(_part(_box(Vector3(0.018, 0.062, 0.012)), star, Vector3(0, 0.12, 0.105)))
	root.add_child(_part(_box(Vector3(0.042, 0.013, 0.011)), star, Vector3(0, 0.12, 0.105), Vector3(0, 0, 45)))
	root.add_child(_part(_sph(0.008, 8), star, Vector3(-0.055, 0.185, 0.07)))
	root.add_child(_part(_sph(0.008, 8), star, Vector3(0.06, 0.055, 0.12)))
	return root

## Wraps down over the skull instead of resting on top: dome centered
## slightly BELOW the anchor, riveted lower band, dark visor slit under a
## steel brow ridge, and a crest ridge carrying an ember-red plume.
static func _build_knight_helmet(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "KnightHelmet"
	var steel := _metal(color)
	var dark_steel := _metal(color.darkened(0.25))
	root.add_child(_part(_sph(HEAD_RADIUS * 1.24, 24), steel, Vector3(0, -0.03, 0)))
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.27, HEAD_RADIUS * 1.27, 0.04, 20), dark_steel, Vector3(0, -0.115, 0)))
	# Gold rivets around the band
	var rivet := _metal(EMBER_GOLD)
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		root.add_child(_part(_sph(0.011, 8), rivet, Vector3(cos(a) * HEAD_RADIUS * 1.27, -0.115, sin(a) * HEAD_RADIUS * 1.27)))
	# Visor slit + brow ridge (camera-facing +Z, as before)
	root.add_child(_part(_box(Vector3(HEAD_RADIUS * 1.7, 0.032, 0.05)), _cloth(TRIM_DARK), Vector3(0, -0.14, HEAD_RADIUS * 0.95)))
	root.add_child(_part(_box(Vector3(HEAD_RADIUS * 1.75, 0.024, 0.055)), steel, Vector3(0, -0.108, HEAD_RADIUS * 0.92)))
	# Crest ridge + red plume arcing back
	root.add_child(_part(_box(Vector3(0.02, 0.035, 0.17)), dark_steel, Vector3(0, 0.15, 0)))
	var plume := _cloth(PLUME_RED)
	root.add_child(_part(_sph(0.032, 10), plume, Vector3(0, 0.185, 0.05)))
	root.add_child(_part(_sph(0.03, 10), plume, Vector3(0, 0.19, 0.0)))
	root.add_child(_part(_sph(0.028, 10), plume, Vector3(0, 0.18, -0.045)))
	root.add_child(_part(_sph(0.024, 10), plume, Vector3(0, 0.16, -0.082)))
	return root

## Berserker circlet: dark leather band over a snow-fur under-rim, gold
## studs, and two curved horns faked with three tapering segments each -
## body-colored at the base, bone-colored at the tip.
static func _build_horns(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Horns"
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.12, HEAD_RADIUS * 1.12, 0.042, 20), _cloth(TRIM_DARK), Vector3(0, 0.0, 0)))
	root.add_child(_part(_torus(HEAD_RADIUS * 0.98, HEAD_RADIUS * 1.3), _fur(TRIM_WHITE), Vector3(0, -0.02, 0)))
	var stud := _metal(EMBER_GOLD)
	for i in 4:
		var a: float = TAU * float(i) / 4.0 + TAU / 8.0
		root.add_child(_part(_sph(0.011, 8), stud, Vector3(cos(a) * HEAD_RADIUS * 1.12, 0.0, sin(a) * HEAD_RADIUS * 1.12)))
	var horn := _cloth(color)
	var bone := _cloth(BONE_TIP)
	for side in [-1, 1]:
		root.add_child(_part(_cyl(0.021, 0.035, 0.1, 10), horn, Vector3(0.078 * side, 0.07, 0), Vector3(-12, 0, 30 * side)))
		root.add_child(_part(_cyl(0.012, 0.02, 0.085, 8), horn, Vector3(0.118 * side, 0.148, -0.014), Vector3(-26, 0, 54 * side)))
		root.add_child(_part(_cyl(0.003, 0.011, 0.05, 8), bone, Vector3(0.148 * side, 0.198, -0.032), Vector3(-38, 0, 72 * side)))
	return root

## Swift cap: a knit dome that actually hugs the skull, folded brim roll,
## a small warm pom on top, and the signature cat ears (trim-lined inners
## kept camera-facing, as before).
static func _build_cat_ears(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "CatEars"
	var knit := _cloth(color)
	root.add_child(_part(_hemi(HEAD_RADIUS * 1.22, 20), knit, Vector3(0, -0.045, 0)))
	root.add_child(_part(_torus(HEAD_RADIUS * 0.98, HEAD_RADIUS * 1.34), _cloth(color.darkened(0.18)), Vector3(0, -0.028, 0)))
	root.add_child(_part(_sph(0.03, 10), _fur(CANDLE_WHITE), Vector3(0, 0.155, 0)))
	var inner := _cloth(TRIM_WHITE)
	for side in [-1, 1]:
		root.add_child(_part(_cyl(0.006, 0.055, 0.1, 10), knit, Vector3(0.078 * side, 0.135, 0), Vector3(0, 0, 24 * side)))
		root.add_child(_part(_cyl(0.003, 0.032, 0.055, 8), inner, Vector3(0.078 * side, 0.137, 0.02), Vector3(0, 0, 24 * side)))
	return root
