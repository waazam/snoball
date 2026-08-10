extends MeshInstance3D
## Procedural "low-poly ice wall" panel - a faceted, flat-shaded grid of
## quads standing in for a wall texture, generated at runtime instead of an
## imported image (see LowPolySky.gd for the same technique on the sky).
##
## Palette is the same painting-derived set as the sky, but weighted cool
## and icy: pale ice-blue/white tiles as the base, with the odd blue, pink,
## red or gold "paint fleck" tile scattered in, like colorful shards frozen
## into the ice.

@export var wall_width: float = 10.0
@export var wall_height: float = 4.0
@export var wall_depth: float = 1.0
@export var horizontal_axis: Vector3 = Vector3.RIGHT  # which local axis is "width"
@export var cols: int = 10
@export var rows: int = 4

const SPLATTER_CHANCE := 0.14
const SPLATTER_MIX := 0.55

const ICE_LIGHT := Color(0.86, 0.93, 0.97, 0.55)
const ICE_BASE := Color(0.72, 0.85, 0.93, 0.5)
const ICE_DEEP := Color(0.55, 0.72, 0.88, 0.45)
const CREAM_BASE := Color(0.85, 0.78, 0.62, 0.5)
const PERIWINKLE := Color(0.5, 0.58, 0.85, 0.5)
const BLUSH_PINK := Color(0.85, 0.55, 0.55, 0.55)
const RED_ACCENT := Color(0.78, 0.16, 0.22, 0.6)
const GOLD_ACCENT := Color(0.75, 0.58, 0.25, 0.6)
const CHARCOAL := Color(0.12, 0.12, 0.13, 0.6)

const BASE_COLORS := [ICE_LIGHT, ICE_LIGHT, ICE_BASE, ICE_BASE, ICE_DEEP, CREAM_BASE, PERIWINKLE]
const SPLATTER_COLORS := [RED_ACCENT, GOLD_ACCENT, BLUSH_PINK, CHARCOAL]

func _ready() -> void:
	mesh = _build_panel()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = mat

func _face_color() -> Color:
	var base: Color = BASE_COLORS[randi() % BASE_COLORS.size()]
	if randf() < SPLATTER_CHANCE:
		var splat: Color = SPLATTER_COLORS[randi() % SPLATTER_COLORS.size()]
		return base.lerp(splat, SPLATTER_MIX)
	return base

## Two subdivided grid faces (front + back of the slab); depth_axis is
## whichever local axis is perpendicular to both the wall's width and up,
## so the same script drives both the N/S walls (wide along X) and the E/W
## walls (wide along Z) just by swapping horizontal_axis.
func _build_panel() -> ArrayMesh:
	var depth_axis: Vector3 = horizontal_axis.cross(Vector3.UP).normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_grid_face(st, depth_axis * (wall_depth * 0.5))
	_add_grid_face(st, depth_axis * (-wall_depth * 0.5))
	st.generate_normals()
	return st.commit()

func _add_grid_face(st: SurfaceTool, center: Vector3) -> void:
	for row in range(rows):
		var v0: float = (float(row) / rows - 0.5) * wall_height
		var v1: float = (float(row + 1) / rows - 0.5) * wall_height
		for col in range(cols):
			var u0: float = (float(col) / cols - 0.5) * wall_width
			var u1: float = (float(col + 1) / cols - 0.5) * wall_width
			var p00: Vector3 = center + horizontal_axis * u0 + Vector3.UP * v0
			var p10: Vector3 = center + horizontal_axis * u1 + Vector3.UP * v0
			var p01: Vector3 = center + horizontal_axis * u0 + Vector3.UP * v1
			var p11: Vector3 = center + horizontal_axis * u1 + Vector3.UP * v1
			var color: Color = _face_color()
			_add_tri(st, p00, p10, p11, color)
			_add_tri(st, p00, p11, p01, color)

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)
