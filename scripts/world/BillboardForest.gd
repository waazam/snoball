extends MultiMeshInstance3D
## A distant backdrop forest just beyond the arena walls - hundreds of flat,
## always-camera-facing "cutout" tree silhouettes instead of real 3D
## geometry (see BareTree.gd/TreeBranches.gd/PineCanopy.gd for the actual
## walkable-area trees, which ARE full 3D). Rendered as a single MultiMesh
## so "a ton" of them costs one draw call; billboard_mode on the shared
## material is what keeps every single one facing the camera as the player
## turns - the standard cheap-distant-forest technique.
##
## Dusk pass: the cutout silhouette now has four canopy tiers with baked
## snow caps on each tier's tip (nudged toward the camera so they never
## z-fight their own tier), canopy greens come from the ART_DIRECTION.md
## pine family (#152E1B..#3A6B42 via per-instance multiply tints over a
## #1C3D24 base), and instances scale width and height independently so
## the treeline silhouette varies instead of being one stamped shape.

const TREE_COUNT := 500
const INNER_RADIUS := 126.0  # just past the walls
const OUTER_RADIUS := 258.0  # stays inside LowPolySky's 260 dome
# Per-instance multiply tints over the baked PINE_DARK canopy: spans the
# palette's #152E1B (darkest) up to #3A6B42 (lit tufts). Slightly blue in
# the darkest tint so shadowed trees sit into the blue snow-shadow field.
const CANOPY_TINTS := [
	Color(0.75, 0.78, 0.88),
	Color(1.0, 1.0, 1.0),
	Color(1.4, 1.35, 1.35),
	Color(2.0, 1.75, 1.8),
]
const TRUNK_COLOR := Color(0.2, 0.145, 0.105)   # bakes toward #4A3325 wood after tinting
const CANOPY_BASE := Color(0.11, 0.239, 0.141)  # #1C3D24 PINE_DARK
# Baked below white so the brightest instance tints resolve to clean snow
# while shadowed instances get believable blue-grey snow.
const SNOW_BASE := Color(0.6, 0.65, 0.72)
const SNOW_Z := 0.012  # toward the camera (billboard +Z always faces the view)

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
		# The base mesh (_build_tree_mesh below) is ~1.2 units tall on its
		# own - width and height scale independently so the backdrop ridge
		# gets slim spires next to broad firs instead of one stamped shape.
		var sx: float = rng.randf_range(3.1, 4.4)
		var sy: float = rng.randf_range(3.4, 5.4)
		var xf := Transform3D(Basis().scaled(Vector3(sx, sy, sx)), pos)
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

## A flat pine silhouette: a brown trunk sliver plus 4 stacked canopy
## triangles, each tier tipped with a smaller snow triangle floated a hair
## toward the camera. Canopy vertices are baked at CANOPY_BASE (not white)
## so a tree still reads green even before MultiMesh's per-instance color
## (set above) multiplies in this tree's particular tint.
func _build_tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st, Vector3(-0.05, 0.0, 0), Vector3(0.05, 0.0, 0), Vector3(0.04, 0.34, 0), Vector3(-0.04, 0.34, 0), TRUNK_COLOR)
	_add_tier(st, 0.38, 0.28, 0.44)
	_add_tier(st, 0.31, 0.5, 0.4)
	_add_tier(st, 0.24, 0.7, 0.36)
	_add_tier(st, 0.16, 0.88, 0.32)
	st.generate_normals()
	return st.commit()

## One canopy tier: a green triangle (half-width, base height, rise) plus a
## snow cap triangle covering its top third, offset on Z toward the viewer.
func _add_tier(st: SurfaceTool, half_w: float, base_y: float, rise: float) -> void:
	var l := Vector3(-half_w, base_y, 0)
	var r := Vector3(half_w, base_y, 0)
	var tip := Vector3(0, base_y + rise, 0)
	_add_tri(st, l, r, tip, CANOPY_BASE)
	var sl: Vector3 = l.lerp(tip, 0.62)
	var sr: Vector3 = r.lerp(tip, 0.62)
	sl.z = SNOW_Z
	sr.z = SNOW_Z
	var stip := Vector3(0, tip.y, SNOW_Z)
	_add_tri(st, sl, sr, stip, SNOW_BASE)

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
