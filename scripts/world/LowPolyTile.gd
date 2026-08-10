extends MeshInstance3D
## A single low-poly "painted floor tile" - a small flat-shaded quad (with a
## few internal facets for variation) resting on the ground. Same
## painting-derived palette family as the sky/walls (see LowPolySky.gd,
## LowPolyWall.gd), but opaque and snow-tinted so it reads as paint peeking
## through the snow rather than ice.

@export var tile_size: float = 1.6
@export var facets: int = 2

const SPLATTER_CHANCE := 0.22
const SPLATTER_MIX := 0.6

const SNOW_WHITE := Color(0.94, 0.97, 1.0)
const ICE_BASE := Color(0.78, 0.88, 0.95)
const CREAM_BASE := Color(0.85, 0.78, 0.62)
const PERIWINKLE := Color(0.55, 0.63, 0.87)
const SKY_BLUE := Color(0.35, 0.5, 0.83)
const BLUSH_PINK := Color(0.85, 0.55, 0.55)
const RED_ACCENT := Color(0.78, 0.16, 0.22)
const GOLD_ACCENT := Color(0.75, 0.58, 0.25)
const CHARCOAL := Color(0.14, 0.14, 0.15)

const BASE_COLORS := [SNOW_WHITE, SNOW_WHITE, ICE_BASE, CREAM_BASE, PERIWINKLE]
const SPLATTER_COLORS := [RED_ACCENT, GOLD_ACCENT, BLUSH_PINK, CHARCOAL, SKY_BLUE]

func _ready() -> void:
	mesh = _build_tile()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat

func _face_color() -> Color:
	var base: Color = BASE_COLORS[randi() % BASE_COLORS.size()]
	if randf() < SPLATTER_CHANCE:
		var splat: Color = SPLATTER_COLORS[randi() % SPLATTER_COLORS.size()]
		return base.lerp(splat, SPLATTER_MIX)
	return base

func _build_tile() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(facets):
		var z0: float = (float(row) / facets - 0.5) * tile_size
		var z1: float = (float(row + 1) / facets - 0.5) * tile_size
		for col in range(facets):
			var x0: float = (float(col) / facets - 0.5) * tile_size
			var x1: float = (float(col + 1) / facets - 0.5) * tile_size
			var p00 := Vector3(x0, 0.0, z0)
			var p10 := Vector3(x1, 0.0, z0)
			var p01 := Vector3(x0, 0.0, z1)
			var p11 := Vector3(x1, 0.0, z1)
			var color: Color = _face_color()
			_add_tri(st, p00, p01, p11, color)
			_add_tri(st, p00, p11, p10, color)
	st.generate_normals()
	return st.commit()

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)
