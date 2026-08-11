extends MeshInstance3D
## Procedural "low-poly sky dome" - a faceted, flat-shaded hemisphere built
## at runtime instead of an imported texture, so it fits the rest of the
## game's fully-procedural low-poly look (see HatVisuals.gd for the same
## approach applied to hats).
##
## Sunset palette: a hot gold/orange band right at the horizon, burning
## down through red-orange and dusky plum as it rises, into a deep indigo
## zenith - with scattered blush-pink, red, gold and charcoal "paint fleck"
## facets standing in for clouds catching the last warm light.

const RADIUS := 260.0
const RINGS := 7
const SEGMENTS := 16
const SPLATTER_CHANCE := 0.1
const SPLATTER_MIX := 0.65

# Sunset gradient, horizon (t=0) to zenith (t=1).
const HORIZON_GOLD := Color(0.98, 0.62, 0.28)
const SUNSET_ORANGE := Color(0.9, 0.42, 0.24)
const DUSK_PLUM := Color(0.55, 0.28, 0.4)
const TWILIGHT_PURPLE := Color(0.3, 0.22, 0.46)
const NIGHT_INDIGO := Color(0.14, 0.11, 0.28)
const BLUSH_PINK := Color(0.92, 0.6, 0.55)
const RED_ACCENT := Color(0.82, 0.22, 0.2)
const GOLD_ACCENT := Color(0.92, 0.68, 0.3)
const CHARCOAL := Color(0.12, 0.12, 0.13)

const SPLATTER_COLORS := [RED_ACCENT, GOLD_ACCENT, BLUSH_PINK, CHARCOAL, TWILIGHT_PURPLE]

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
	if t < 0.2:
		return HORIZON_GOLD.lerp(SUNSET_ORANGE, t / 0.2)
	elif t < 0.45:
		return SUNSET_ORANGE.lerp(DUSK_PLUM, (t - 0.2) / 0.25)
	elif t < 0.75:
		return DUSK_PLUM.lerp(TWILIGHT_PURPLE, (t - 0.45) / 0.3)
	else:
		return TWILIGHT_PURPLE.lerp(NIGHT_INDIGO, (t - 0.75) / 0.25)

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
