extends MeshInstance3D
## Procedural "low-poly sky dome" - a faceted, flat-shaded hemisphere built
## at runtime instead of an imported texture, so it fits the rest of the
## game's fully-procedural low-poly look (see HatVisuals.gd for the same
## approach applied to hats).
##
## The palette is hand-sampled from a splatter-painting reference: a warm
## cream canvas near the horizon, cornflower blue rising to a deep navy
## zenith, with scattered blush-pink, red, gold and charcoal "paint fleck"
## facets standing in for the painting's spatter.

const RADIUS := 260.0
const RINGS := 7
const SEGMENTS := 16
const SPLATTER_CHANCE := 0.1
const SPLATTER_MIX := 0.65

# Colors lifted from the reference painting.
const CREAM_LIGHT := Color(0.93, 0.88, 0.75)
const CREAM_BASE := Color(0.85, 0.78, 0.62)
const PERIWINKLE := Color(0.5, 0.58, 0.85)
const SKY_BLUE := Color(0.32, 0.46, 0.82)
const SKY_BLUE_DEEP := Color(0.18, 0.26, 0.58)
const BLUSH_PINK := Color(0.85, 0.55, 0.55)
const RED_ACCENT := Color(0.78, 0.16, 0.22)
const GOLD_ACCENT := Color(0.75, 0.58, 0.25)
const CHARCOAL := Color(0.12, 0.12, 0.13)

const SPLATTER_COLORS := [RED_ACCENT, GOLD_ACCENT, BLUSH_PINK, CHARCOAL, SKY_BLUE_DEEP]

func _ready() -> void:
	mesh = _build_dome()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# --- Palette -----------------------------------------------------------
## t: 0 at the horizon, 1 at the zenith.
func _gradient_color(t: float) -> Color:
	if t < 0.25:
		return CREAM_LIGHT.lerp(CREAM_BASE, t / 0.25)
	elif t < 0.55:
		return CREAM_BASE.lerp(PERIWINKLE, (t - 0.25) / 0.3)
	elif t < 0.8:
		return PERIWINKLE.lerp(SKY_BLUE, (t - 0.55) / 0.25)
	else:
		return SKY_BLUE.lerp(SKY_BLUE_DEEP, (t - 0.8) / 0.2)

func _face_color(t: float) -> Color:
	var base: Color = _gradient_color(t)
	if randf() < SPLATTER_CHANCE:
		var splat: Color = SPLATTER_COLORS[randi() % SPLATTER_COLORS.size()]
		return base.lerp(splat, SPLATTER_MIX)
	return base

# --- Geometry ------------------------------------------------------------
## Latitude/longitude hemisphere, but with every triangle given its own
## unshared vertices (all 3 corners the same color) instead of a shared,
## smoothed vertex grid - that's what gives it the flat-faceted "low-poly"
## look rather than a smooth sphere.
func _build_dome() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(RINGS):
		var phi0: float = (float(ring) / RINGS) * (PI / 2.0)
		var phi1: float = (float(ring + 1) / RINGS) * (PI / 2.0)
		for seg in range(SEGMENTS):
			var th0: float = (float(seg) / SEGMENTS) * TAU
			var th1: float = (float(seg + 1) / SEGMENTS) * TAU
			var p00: Vector3 = _sphere_point(phi0, th0)
			var p01: Vector3 = _sphere_point(phi0, th1)
			var p10: Vector3 = _sphere_point(phi1, th0)
			var p11: Vector3 = _sphere_point(phi1, th1)
			var t: float = (sin(phi0) + sin(phi1)) * 0.5
			var color: Color = _face_color(t)
			_add_tri(st, p00, p01, p11, color)
			_add_tri(st, p00, p11, p10, color)
	st.generate_normals()
	return st.commit()

func _sphere_point(phi: float, theta: float) -> Vector3:
	var x: float = RADIUS * cos(phi) * cos(theta)
	var y: float = RADIUS * sin(phi)
	var z: float = RADIUS * cos(phi) * sin(theta)
	return Vector3(x, y, z)

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)
