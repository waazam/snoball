class_name HatVisuals
extends RefCounted
## Builds a small procedural mesh assembly for a given hat "shape" + color.
## Shared by the player's equipped-hat visual (Player.gd) and the ground
## pickup (HatPickup.gd) so both places render the exact same hat - no
## imported hat models needed.
##
## The returned Node3D's origin is anchored at the TOP of the player's head
## (see Player.tscn's HatAnchor, positioned at the head sphere's tangent
## point). Local +y points up from there; local -y dips down into/around
## the head, which shapes like the knight helmet use to wrap down over the
## skull instead of floating above it. All dimensions below are sized
## against HEAD_RADIUS so a hat-pickup caller can enlarge the whole thing
## uniformly (see HatPickup.gd's PICKUP_VISUAL_SCALE) without needing to
## re-tune individual parts.

const HEAD_RADIUS := 0.15  # matches Player.tscn's Head SphereMesh

const TRIM_WHITE := Color(0.96, 0.96, 0.96)
const TRIM_DARK := Color(0.08, 0.08, 0.09)
const PLUME_RED := Color(0.75, 0.1, 0.1)

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

static func _part(mesh: Mesh, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	return mi

## Brimmed hats that just rest on top of the head - band/brim sits right at
## the anchor (y=0), body rises above it.
static func _build_top_hat(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "TopHat"
	var brim := CylinderMesh.new()
	brim.top_radius = HEAD_RADIUS * 1.45
	brim.bottom_radius = HEAD_RADIUS * 1.45
	brim.height = 0.025
	root.add_child(_part(brim, TRIM_WHITE, Vector3(0, 0.0, 0)))
	var body := CylinderMesh.new()
	body.top_radius = HEAD_RADIUS * 1.05
	body.bottom_radius = HEAD_RADIUS * 1.05
	body.height = 0.22
	root.add_child(_part(body, color, Vector3(0, 0.13, 0)))
	var band := CylinderMesh.new()
	band.top_radius = HEAD_RADIUS * 1.12
	band.bottom_radius = HEAD_RADIUS * 1.12
	band.height = 0.03
	root.add_child(_part(band, TRIM_WHITE, Vector3(0, 0.035, 0)))
	var top := CylinderMesh.new()
	top.top_radius = HEAD_RADIUS * 1.05
	top.bottom_radius = HEAD_RADIUS * 1.05
	top.height = 0.02
	root.add_child(_part(top, color, Vector3(0, 0.25, 0)))
	return root

static func _build_wizard_hat(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "WizardHat"
	var brim := CylinderMesh.new()
	brim.top_radius = HEAD_RADIUS * 1.7
	brim.bottom_radius = HEAD_RADIUS * 1.7
	brim.height = 0.025
	root.add_child(_part(brim, TRIM_WHITE, Vector3(0, 0.0, 0)))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.006
	cone.bottom_radius = HEAD_RADIUS * 1.05
	cone.height = 0.34
	root.add_child(_part(cone, color, Vector3(0, 0.185, -0.015), Vector3(-10, 0, 0)))
	var tip := SphereMesh.new()
	tip.radius = 0.025
	tip.height = 0.05
	root.add_child(_part(tip, TRIM_WHITE, Vector3(0, 0.365, -0.075)))
	return root

## Wraps down over the skull instead of resting on top: the dome is
## centered slightly BELOW the anchor so it fully encases the head, and the
## visor sits near the head's vertical center (roughly eye height).
static func _build_knight_helmet(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "KnightHelmet"
	var dome := SphereMesh.new()
	dome.radius = HEAD_RADIUS * 1.22
	dome.height = dome.radius * 2.0
	root.add_child(_part(dome, color, Vector3(0, -0.035, 0)))
	var visor := BoxMesh.new()
	visor.size = Vector3(HEAD_RADIUS * 1.7, 0.035, 0.05)
	root.add_child(_part(visor, TRIM_DARK, Vector3(0, -0.135, HEAD_RADIUS * 0.95)))
	var crest := BoxMesh.new()
	crest.size = Vector3(0.02, 0.13, 0.06)
	root.add_child(_part(crest, PLUME_RED, Vector3(0, 0.1, -0.015)))
	return root

static func _build_horns(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Horns"
	var band := CylinderMesh.new()
	band.top_radius = HEAD_RADIUS * 1.1
	band.bottom_radius = HEAD_RADIUS * 1.1
	band.height = 0.03
	root.add_child(_part(band, TRIM_DARK, Vector3(0, 0.0, 0)))
	for side in [-1, 1]:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.006
		horn.bottom_radius = 0.03
		horn.height = 0.17
		root.add_child(_part(horn, color, Vector3(0.075 * side, 0.075, 0), Vector3(-25, 0, 35 * side)))
	return root

static func _build_cat_ears(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "CatEars"
	var band := CylinderMesh.new()
	band.top_radius = HEAD_RADIUS * 1.07
	band.bottom_radius = HEAD_RADIUS * 1.07
	band.height = 0.025
	root.add_child(_part(band, color, Vector3(0, 0.0, 0)))
	for side in [-1, 1]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.006
		ear.bottom_radius = 0.06
		ear.height = 0.1
		root.add_child(_part(ear, color, Vector3(0.07 * side, 0.06, 0), Vector3(0, 0, 22 * side)))
		var inner := CylinderMesh.new()
		inner.top_radius = 0.003
		inner.bottom_radius = 0.035
		inner.height = 0.055
		root.add_child(_part(inner, TRIM_WHITE, Vector3(0.07 * side, 0.062, 0.02), Vector3(0, 0, 22 * side)))
	return root
