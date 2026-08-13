extends Node3D
## Two twine bands wrapped around a crate-sized hay bale (see BoxMesh_hay in
## Arena.tscn - half_size defaults to match its 1.6 full size). Each band is
## 4 thin boxes hugging the bale's faces rather than a single ring
## primitive, since Godot has no box-torus mesh. Purely decorative - no
## collision, no gameplay values - same idiom as SnowCap.gd/PickupGlow.gd.

@export var half_size: float = 0.8
@export var band_thickness: float = 0.09
@export var band_depth: float = 0.025

const BAND_COLOR := Color("#4A3325")  # WOOD_BARK, reused as the twine color

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BAND_COLOR
	mat.roughness = 0.85
	_build_band(-half_size * 0.35, mat)
	_build_band(half_size * 0.35, mat)

## Four segments hugging the bale's faces at height y, poking out
## band_depth/2 beyond each face so they don't z-fight with the bale mesh.
func _build_band(y: float, mat: Material) -> void:
	var span: float = half_size * 2.0 + band_depth * 2.0
	for z_sign in [1.0, -1.0]:
		_add_segment(Vector3(span, band_thickness, band_depth), Vector3(0.0, y, z_sign * (half_size + band_depth * 0.5)), mat)
	for x_sign in [1.0, -1.0]:
		_add_segment(Vector3(band_depth, band_thickness, span), Vector3(x_sign * (half_size + band_depth * 0.5), y, 0.0), mat)

func _add_segment(size: Vector3, pos: Vector3, mat: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
