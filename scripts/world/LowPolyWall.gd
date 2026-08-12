extends MeshInstance3D
## Procedural "low-poly ice wall" panel - a faceted, flat-shaded grid of
## quads standing in for a wall texture, generated at runtime instead of an
## imported image (see LowPolySky.gd for the same technique on the sky).
##
## Dusk pass (ART_DIRECTION.md): the tile palette is now the arena's cold
## family - pale snow-white and freeze-blue ice with blue-shadow depths -
## with the odd ember-red/gold/blush "paint fleck" tile frozen in, so the
## walls read as part of the same alpenglow world as everything else. The
## top edge is no longer a machine-straight line: each column rises to its
## own jagged shard height (shared between the front and back faces so the
## silhouette agrees), and a snow-colored ridge cap runs along the crest
## like a drift settled on top of the ice.

@export var wall_width: float = 10.0
@export var wall_height: float = 4.0
@export var wall_depth: float = 1.0
@export var horizontal_axis: Vector3 = Vector3.RIGHT  # which local axis is "width"
@export var cols: int = 10
@export var rows: int = 4
@export var shard_height_max: float = 0.9  # extra jagged rise above wall_height, per column

const SPLATTER_CHANCE := 0.12
const SPLATTER_MIX := 0.5

# Cold family (base tiles) - all from the master palette's snow/ice tones.
const ICE_LIGHT := Color(0.918, 0.949, 0.984, 0.6)   # #EAF2FB
const ICE_FREEZE := Color(0.659, 0.894, 1.0, 0.5)    # #A8E4FF
const ICE_SHADOW := Color(0.561, 0.639, 0.784, 0.5)  # #8FA3C8
const ICE_DEEP := Color(0.29, 0.204, 0.4, 0.45)      # #4A3466 dusk violet depths
# Ember family (rare frozen-in flecks).
const RED_ACCENT := Color(0.91, 0.282, 0.247, 0.6)   # #E8483F
const GOLD_ACCENT := Color(1.0, 0.722, 0.302, 0.6)   # #FFB84D
const BLUSH_PINK := Color(0.941, 0.635, 0.557, 0.55) # #F0A28E
const NIGHT_FLECK := Color(0.141, 0.11, 0.278, 0.6)  # #241C47
# Ridge cap snow.
const SNOW_RIDGE := Color(0.918, 0.949, 0.984, 0.9)  # #EAF2FB, near-opaque

const BASE_COLORS := [ICE_LIGHT, ICE_LIGHT, ICE_FREEZE, ICE_FREEZE, ICE_SHADOW, ICE_SHADOW, ICE_DEEP]
const SPLATTER_COLORS := [RED_ACCENT, GOLD_ACCENT, BLUSH_PINK, NIGHT_FLECK]

func _ready() -> void:
	mesh = _build_panel()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _face_color() -> Color:
	var base: Color = BASE_COLORS[randi() % BASE_COLORS.size()]
	if randf() < SPLATTER_CHANCE:
		var splat: Color = SPLATTER_COLORS[randi() % SPLATTER_COLORS.size()]
		return base.lerp(splat, SPLATTER_MIX)
	return base

## Two subdivided grid faces (front + back of the slab) sharing one set of
## per-column jagged crest heights, plus a snow ridge strip joining their
## top edges; depth_axis is whichever local axis is perpendicular to both
## the wall's width and up, so the same script drives both the N/S walls
## (wide along X) and the E/W walls (wide along Z) just by swapping
## horizontal_axis.
func _build_panel() -> ArrayMesh:
	var depth_axis: Vector3 = horizontal_axis.cross(Vector3.UP).normalized()
	# Per-column crest heights (cols+1 shared corner values): mostly gentle
	# rises with the occasional taller shard, squared so tall ones are rare.
	var crest := PackedFloat32Array()
	crest.resize(cols + 1)
	for i in cols + 1:
		var r: float = randf()
		crest[i] = wall_height * 0.5 + shard_height_max * r * r

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_grid_face(st, depth_axis * (wall_depth * 0.5), crest)
	_add_grid_face(st, depth_axis * (-wall_depth * 0.5), crest)
	_add_ridge_cap(st, depth_axis, crest)
	st.generate_normals()
	return st.commit()

func _add_grid_face(st: SurfaceTool, center: Vector3, crest: PackedFloat32Array) -> void:
	var top_row: int = rows - 1
	for row in range(rows):
		var v0: float = (float(row) / rows - 0.5) * wall_height
		var v1: float = (float(row + 1) / rows - 0.5) * wall_height
		for col in range(cols):
			var u0: float = (float(col) / cols - 0.5) * wall_width
			var u1: float = (float(col + 1) / cols - 0.5) * wall_width
			# Top row's upper edge follows the jagged crest instead of a line.
			var v1a: float = crest[col] if row == top_row else v1
			var v1b: float = crest[col + 1] if row == top_row else v1
			var p00: Vector3 = center + horizontal_axis * u0 + Vector3.UP * v0
			var p10: Vector3 = center + horizontal_axis * u1 + Vector3.UP * v0
			var p01: Vector3 = center + horizontal_axis * u0 + Vector3.UP * v1a
			var p11: Vector3 = center + horizontal_axis * u1 + Vector3.UP * v1b
			var color: Color = _face_color()
			_add_tri(st, p00, p10, p11, color)
			_add_tri(st, p00, p11, p01, color)

## Snow-colored strip joining the front and back crest edges - reads as a
## settled drift along the wall's top from any viewing height.
func _add_ridge_cap(st: SurfaceTool, depth_axis: Vector3, crest: PackedFloat32Array) -> void:
	var front: Vector3 = depth_axis * (wall_depth * 0.5)
	var back: Vector3 = -front
	for col in range(cols):
		var u0: float = (float(col) / cols - 0.5) * wall_width
		var u1: float = (float(col + 1) / cols - 0.5) * wall_width
		var f0: Vector3 = front + horizontal_axis * u0 + Vector3.UP * crest[col]
		var f1: Vector3 = front + horizontal_axis * u1 + Vector3.UP * crest[col + 1]
		var b0: Vector3 = back + horizontal_axis * u0 + Vector3.UP * crest[col]
		var b1: Vector3 = back + horizontal_axis * u1 + Vector3.UP * crest[col + 1]
		_add_tri(st, f0, f1, b1, SNOW_RIDGE)
		_add_tri(st, f0, b1, b0, SNOW_RIDGE)

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)
