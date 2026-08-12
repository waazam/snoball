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
## dips down into/around the head, which shapes like the great helm and the
## viking half-helm use to wrap down over the skull instead of floating
## above it. Face/camera details always sit at +Z. All dimensions below are
## sized against HEAD_RADIUS so a hat-pickup caller can enlarge the whole
## thing uniformly (see HatPickup.gd's PICKUP_VISUAL_SCALE) without needing
## to re-tune individual parts.
##
## This is the "big toy" hat set: every silhouette is chunky and readable
## from the chase camera at full arena distance (stovepipe crown, sweeping
## horns, drooping wizard cone), matching the primitive-built enemies -
## but sized to sit believably on the 0.15-radius toy head rather than
## dwarf it. Skull-wrap radii (helm bucket, viking dome, beanie dome) stay
## at ~1.3x HEAD_RADIUS so they cover the head; only the statement parts
## (brims, crowns, horns, ears, plumes) are kept trim.
##
## Palette + material rules follow ART_DIRECTION.md ("Alpenglow Dusk"):
## cloth is matte (roughness 0.8), fur rougher still (0.95+), metal is
## roughness 0.35 / metallic 0.9, and emission is reserved for deliberate
## accents (the frost wizard's moon and stars). Accent hexes are copied
## verbatim from the master palette - never invented locally. Each hat's
## MAIN body takes the passed-in color (HatDB decides it); trim, horns,
## plumes and studs come from the palette neutrals.

const HEAD_RADIUS := 0.15  # the head size every hat is proportioned against

const TRIM_WHITE := Color("#F5EFE6")    # fur/cloth trim
const TRIM_DARK := Color("#26221F")     # coal-dark leather/visor slits
const PLUME_RED := Color("#E8483F")     # EMBER_RED accent
const EMBER_GOLD := Color("#FFB84D")    # metallic bands, buckles, studs
const CANDLE_WHITE := Color("#FFE9C9")  # warm pom-poms
const FROST_GLOW := Color("#A8E4FF")    # frost wizard emissive moon/stars
const BONE_TIP := Color("#D9C6A8")      # berserker horn bone

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
## Cartoon stovepipe top hat: a fat rolled brim, a tall crown that flares
## noticeably wider toward the top (drawn-on-a-snowman proportions), and a
## bold cream band with a square gold buckle at +Z. The band's outer
## surface stays at local y ~0.02-0.09, radius ~0.17 - EnemySnowman's
## _decorate_hat pins its holly sprig there, so keep that shelf if the
## band ever moves.
static func _build_top_hat(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "TopHat"
	var silk := _cloth(color)
	# Brim: wide disc with a fat curled edge roll
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.45, HEAD_RADIUS * 1.45, 0.022, 24), silk, Vector3(0, 0.0, 0)))
	root.add_child(_part(_torus(HEAD_RADIUS * 1.3, HEAD_RADIUS * 1.6), silk, Vector3(0, 0.012, 0)))
	# Crown: stovepipe flaring from skull-snug at the base to wider at the
	# top, capped with a slightly oversized lid disc
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.2, HEAD_RADIUS * 1.02, 0.26, 20), silk, Vector3(0, 0.15, 0)))
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.24, HEAD_RADIUS * 1.24, 0.02, 20), silk, Vector3(0, 0.285, 0)))
	# Bold cream band + gold buckle facing the camera
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.14, HEAD_RADIUS * 1.14, 0.075, 20), _cloth(TRIM_WHITE), Vector3(0, 0.055, 0)))
	var gold := _metal(EMBER_GOLD)
	root.add_child(_part(_box(Vector3(0.052, 0.062, 0.016)), gold, Vector3(0, 0.055, HEAD_RADIUS * 1.14)))
	return root

## Frost wizard hat, storybook edition: a wide brim made of two
## interpenetrating tilted discs (cheap "wavy felt" silhouette) with a
## rolled edge, a snow-fur base band, and a three-segment cone that droops
## harder with every segment until the tip hangs backwards under a dangling
## candle-white pom. Front face carries the one emission accent hats are
## allowed: a frost-glow moon orb and two chunky four-point stars.
static func _build_wizard_hat(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "WizardHat"
	var cloth := _cloth(color)
	# Wavy brim: two big discs at opposing slight tilts + rolled edge
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.55, HEAD_RADIUS * 1.55, 0.024, 24), cloth, Vector3(0, 0.0, 0), Vector3(5, 0, 3)))
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.5, HEAD_RADIUS * 1.5, 0.024, 24), cloth, Vector3(0, 0.006, 0), Vector3(-4, 0, -5)))
	root.add_child(_part(_torus(HEAD_RADIUS * 1.42, HEAD_RADIUS * 1.66), cloth, Vector3(0, 0.008, 0), Vector3(3, 0, -3)))
	# Snow-fur band hugging the cone base
	root.add_child(_part(_torus(HEAD_RADIUS * 0.8, HEAD_RADIUS * 1.3), _fur(TRIM_WHITE), Vector3(0, 0.04, 0)))
	# Three-segment cone, each segment drooping harder toward -Z
	root.add_child(_part(_cyl(0.065, HEAD_RADIUS * 1.05, 0.19, 16), cloth, Vector3(0, 0.115, 0), Vector3(-8, 0, 0)))
	root.add_child(_part(_cyl(0.035, 0.062, 0.13, 12), cloth, Vector3(0, 0.255, -0.04), Vector3(-30, 0, 0)))
	root.add_child(_part(_cyl(0.006, 0.033, 0.11, 10), cloth, Vector3(0, 0.335, -0.11), Vector3(-62, 0, 0)))
	root.add_child(_part(_sph(0.038, 12), _fur(CANDLE_WHITE), Vector3(0, 0.345, -0.175)))
	# Emissive moon orb + two four-point stars on the camera-facing side
	var glow := _glow(FROST_GLOW, 1.5)
	root.add_child(_part(_sph(0.021, 10), glow, Vector3(0.042, 0.15, 0.095)))
	root.add_child(_part(_box(Vector3(0.05, 0.014, 0.012)), glow, Vector3(-0.052, 0.09, 0.12)))
	root.add_child(_part(_box(Vector3(0.014, 0.05, 0.012)), glow, Vector3(-0.052, 0.09, 0.12)))
	root.add_child(_part(_box(Vector3(0.036, 0.011, 0.011)), glow, Vector3(0.01, 0.225, 0.052)))
	root.add_child(_part(_box(Vector3(0.011, 0.036, 0.011)), glow, Vector3(0.01, 0.225, 0.052)))
	return root

## Crusader great helm: a full bucket cylinder that swallows the whole
## skull (centered well below the anchor), flat top plate, riveted lower
## rim, and a dark cross-shaped visor (vertical breath slit + horizontal
## eye slit) at +Z. Topped by a tall fin crest running front-to-back that
## carries a chunky five-ball ember-red plume mohawk.
static func _build_knight_helmet(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "KnightHelmet"
	var steel := _metal(color)
	var dark_steel := _metal(color.darkened(0.25))
	# Bucket body + top plate + bottom rim band
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.28, HEAD_RADIUS * 1.28, 0.34, 20), steel, Vector3(0, -0.1, 0)))
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.33, HEAD_RADIUS * 1.33, 0.03, 20), steel, Vector3(0, 0.07, 0)))
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.33, HEAD_RADIUS * 1.33, 0.04, 20), dark_steel, Vector3(0, -0.255, 0)))
	# Gold rivets around the rim band
	var rivet := _metal(EMBER_GOLD)
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		root.add_child(_part(_sph(0.012, 8), rivet, Vector3(cos(a) * HEAD_RADIUS * 1.33, -0.255, sin(a) * HEAD_RADIUS * 1.33)))
	# Cross visor at +Z: vertical breath slit + horizontal eye slit
	var slit := _cloth(TRIM_DARK)
	root.add_child(_part(_box(Vector3(0.05, 0.17, 0.05)), slit, Vector3(0, -0.13, HEAD_RADIUS * 1.18)))
	root.add_child(_part(_box(Vector3(HEAD_RADIUS * 1.6, 0.036, 0.05)), slit, Vector3(0, -0.095, HEAD_RADIUS * 1.18)))
	# Fin crest + ember plume mohawk arcing front-to-back along it
	root.add_child(_part(_box(Vector3(0.02, 0.07, 0.24)), dark_steel, Vector3(0, 0.095, 0)))
	var plume := _cloth(PLUME_RED)
	root.add_child(_part(_sph(0.032, 10), plume, Vector3(0, 0.148, 0.095)))
	root.add_child(_part(_sph(0.036, 10), plume, Vector3(0, 0.163, 0.048)))
	root.add_child(_part(_sph(0.038, 10), plume, Vector3(0, 0.168, 0.0)))
	root.add_child(_part(_sph(0.032, 10), plume, Vector3(0, 0.158, -0.05)))
	root.add_child(_part(_sph(0.026, 10), plume, Vector3(0, 0.142, -0.09)))
	return root

## Berserker viking half-helm: a metal dome in the hat's own color wrapping
## down over the skull, a coal leather brow band with gold studs, a short
## nose-guard strip at +Z, and two bone horns - three tapering segments
## each, jutting sideways then sweeping up and back - with a gold collar
## where each horn meets the helm.
static func _build_horns(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Horns"
	var steel := _metal(color)
	root.add_child(_part(_hemi(HEAD_RADIUS * 1.3, 20), steel, Vector3(0, -0.06, 0)))
	root.add_child(_part(_cyl(HEAD_RADIUS * 1.32, HEAD_RADIUS * 1.32, 0.055, 20), _cloth(TRIM_DARK), Vector3(0, -0.075, 0)))
	root.add_child(_part(_box(Vector3(0.035, 0.11, 0.022)), _metal(color.darkened(0.25)), Vector3(0, -0.135, HEAD_RADIUS * 1.28)))
	# Gold studs around the brow band
	var stud := _metal(EMBER_GOLD)
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + TAU / 12.0
		root.add_child(_part(_sph(0.012, 8), stud, Vector3(cos(a) * HEAD_RADIUS * 1.32, -0.075, sin(a) * HEAD_RADIUS * 1.32)))
	# Bone horns: out sideways, then up, then a curled back-swept tip
	var bone := _cloth(BONE_TIP)
	var collar := _metal(EMBER_GOLD)
	for side in [-1, 1]:
		root.add_child(_part(_cyl(0.026, 0.044, 0.105, 10), bone, Vector3(0.135 * side, 0.0, 0), Vector3(0, 0, 55 * side)))
		root.add_child(_part(_cyl(0.048, 0.048, 0.026, 10), collar, Vector3(0.105 * side, -0.03, 0), Vector3(0, 0, 55 * side)))
		root.add_child(_part(_cyl(0.017, 0.026, 0.095, 8), bone, Vector3(0.198 * side, 0.058, -0.01), Vector3(-10, 0, 30 * side)))
		root.add_child(_part(_cyl(0.004, 0.016, 0.08, 8), bone, Vector3(0.228 * side, 0.132, -0.026), Vector3(-22, 0, 10 * side)))
	return root

## Swift knit beanie: a chunky dome hugging the skull with a fat folded
## brim roll and a knit ridge line, crowned by perky triangular cat ears
## (cone with a cream inner-ear cone kept camera-facing) and a warm pom
## nestled between them.
static func _build_cat_ears(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "CatEars"
	var knit := _cloth(color)
	root.add_child(_part(_hemi(HEAD_RADIUS * 1.28, 20), knit, Vector3(0, -0.05, 0)))
	# Fat folded brim + a raised knit ridge partway up the dome
	root.add_child(_part(_torus(HEAD_RADIUS * 0.95, HEAD_RADIUS * 1.36), _cloth(color.darkened(0.22)), Vector3(0, -0.04, 0)))
	root.add_child(_part(_torus(HEAD_RADIUS * 1.05, HEAD_RADIUS * 1.18), _cloth(color.lightened(0.12)), Vector3(0, 0.04, 0)))
	# Cat ears: outer cone in knit color, cream inner cone at +Z
	var inner := _cloth(TRIM_WHITE)
	for side in [-1, 1]:
		root.add_child(_part(_cyl(0.0, 0.06, 0.12, 10), knit, Vector3(0.092 * side, 0.122, 0), Vector3(0, 0, 26 * side)))
		root.add_child(_part(_cyl(0.0, 0.037, 0.08, 8), inner, Vector3(0.09 * side, 0.11, 0.028), Vector3(0, 0, 26 * side)))
	# Warm pom between the ears
	root.add_child(_part(_sph(0.037, 12), _fur(CANDLE_WHITE), Vector3(0, 0.126, 0)))
	return root
