extends MultiMeshInstance3D
## A distant backdrop forest just beyond the arena walls - hundreds of flat,
## always-camera-facing "cutout" tree silhouettes instead of real 3D
## geometry (see BareTree.gd/TreeBranches.gd/PineCanopy.gd for the actual
## walkable-area trees, which ARE full 3D). Rendered as a single MultiMesh
## so "a ton" of them costs one draw call; billboard_mode on the shared
## material is what keeps every single one facing the camera as the player
## turns - the standard cheap-distant-forest technique.

const TREE_COUNT := 500
const INNER_RADIUS := 126.0  # just past the walls (which sit at +-120)
const OUTER_RADIUS := 260.0
const CANOPY_TINTS := [
	Color(0.55, 1.0, 0.62),
	Color(0.7, 1.15, 0.78),
	Color(0.85, 1.3, 0.9),
]
const TRUNK_COLOR := Color(0.24, 0.17, 0.11)
const CANOPY_BASE := Color(0.16, 0.32, 0.2)

func _ready() -> void:
	var mesh := _build_tree_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = TREE_COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in TREE_COUNT:
		var angle: float = rng.randf() * TAU
		# sqrt bias so trees don't bunch up near the inner edge - even
		# density across the ring's actual area, not just its radius.
		var radius: float = lerpf(INNER_RADIUS, OUTER_RADIUS, sqrt(rng.randf()))
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		# The base mesh (_build_tree_mesh below) is ~1.1 units tall on its
		# own - this scale range brings instances to ~3.85-4.95 units,
		# matching the ~4.4-tall walkable-area trees (PineCanopy.gd) so the
		# backdrop forest reads as the same size trees, just farther away.
		var s: float = rng.randf_range(3.5, 4.5)
		var xf := Transform3D(Basis().scaled(Vector3.ONE * s), pos)
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, CANOPY_TINTS[rng.randi() % CANOPY_TINTS.size()])
	multimesh = mm

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A simple flat pine silhouette: a brown trunk sliver plus 3 stacked
## triangles for the canopy. Canopy vertices are baked at CANOPY_BASE (not
## white) so a tree still reads green even before MultiMesh's per-instance
## color (set above) multiplies in this tree's particular tint.
func _build_tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st, Vector3(-0.05, 0.0, 0), Vector3(0.05, 0.0, 0), Vector3(0.05, 0.32, 0), Vector3(-0.05, 0.32, 0), TRUNK_COLOR)
	_add_tri(st, Vector3(-0.34, 0.28, 0), Vector3(0.34, 0.28, 0), Vector3(0, 0.72, 0), CANOPY_BASE)
	_add_tri(st, Vector3(-0.28, 0.52, 0), Vector3(0.28, 0.52, 0), Vector3(0, 0.92, 0), CANOPY_BASE)
	_add_tri(st, Vector3(-0.2, 0.74, 0), Vector3(0.2, 0.74, 0), Vector3(0, 1.1, 0), CANOPY_BASE)
	st.generate_normals()
	return st.commit()

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)

func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_add_tri(st, a, b, c, color)
	_add_tri(st, a, c, d, color)
