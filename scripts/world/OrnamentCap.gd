extends Node3D
## The metal cap + hanger loop every Christmas ornament has at its top,
## regardless of the ball's own color - sits at the top of a unit-radius
## sphere (see SphereMesh_unit in Arena.tscn / MapFiller._spawn_rock's
## inline SphereMesh), auto-scaling with the parent's own scale like
## SnowCap.gd does. Purely decorative - no collision, no gameplay values.

@export var sphere_radius: float = 1.0

const CAP_COLOR := Color("#FFB84D")  # EMBER_GOLD - same gold cap on every ornament color
const CAP_HEIGHT := 0.22
const CAP_TOP_RADIUS := 0.22
const CAP_BOTTOM_RADIUS := 0.28
const LOOP_INNER_RADIUS := 0.045
const LOOP_OUTER_RADIUS := 0.11

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CAP_COLOR
	mat.metallic = 0.85
	mat.roughness = 0.15

	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = CAP_TOP_RADIUS
	cap_mesh.bottom_radius = CAP_BOTTOM_RADIUS
	cap_mesh.height = CAP_HEIGHT
	cap_mesh.radial_segments = 10
	var cap_mi := MeshInstance3D.new()
	cap_mi.mesh = cap_mesh
	cap_mi.material_override = mat
	cap_mi.position = Vector3(0.0, sphere_radius + CAP_HEIGHT * 0.15, 0.0)
	cap_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cap_mi)

	var loop_mesh := TorusMesh.new()
	loop_mesh.inner_radius = LOOP_INNER_RADIUS
	loop_mesh.outer_radius = LOOP_OUTER_RADIUS
	var loop_mi := MeshInstance3D.new()
	loop_mi.mesh = loop_mesh
	loop_mi.material_override = mat
	loop_mi.position = Vector3(0.0, sphere_radius + CAP_HEIGHT + LOOP_OUTER_RADIUS * 0.6, 0.0)
	loop_mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	loop_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(loop_mi)
