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
const RINGS := 8
const SEGMENTS := 20
const SPLATTER_CHANCE := 0.1
const SPLATTER_MIX := 0.6

# "Alpenglow Dusk" gradient (ART_DIRECTION.md 6a), horizon (t=0) to zenith (t=1).
const HORIZON_GOLD := Color(0.949, 0.522, 0.29)     # #F2854A
const SUNSET_ORANGE := Color(0.851, 0.373, 0.231)   # #D95F3B
const DUSK_PLUM := Color(0.549, 0.278, 0.4)         # #8C4766
const TWILIGHT_PURPLE := Color(0.29, 0.204, 0.4)    # #4A3466
const NIGHT_INDIGO := Color(0.141, 0.11, 0.278)     # #241C47
const RED_ACCENT := Color(0.91, 0.282, 0.247)       # #E8483F
const GOLD_ACCENT := Color(1.0, 0.722, 0.302)       # #FFB84D
const BLUSH_PINK := Color(0.941, 0.635, 0.557)      # #F0A28E

const SPLATTER_COLORS := [RED_ACCENT, GOLD_ACCENT, BLUSH_PINK, NIGHT_INDIGO]

# Horizontal azimuth of Arena.tscn's low Sun (yaw 145deg) - horizon facets
# near this direction get an extra golden flush, so the sky actually reads
# as "the sun is setting over THERE" and agrees with the light/shadows.
const SUN_AZIMUTH := -0.96
const SUN_GLOW_SPAN := 0.45  # how far up the dome the flush reaches

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
	if t < 0.22:
		return HORIZON_GOLD.lerp(SUNSET_ORANGE, t / 0.22)
	elif t < 0.5:
		return SUNSET_ORANGE.lerp(DUSK_PLUM, (t - 0.22) / 0.28)
	elif t < 0.78:
		return DUSK_PLUM.lerp(TWILIGHT_PURPLE, (t - 0.5) / 0.28)
	else:
		return TWILIGHT_PURPLE.lerp(NIGHT_INDIGO, (t - 0.78) / 0.22)

## t: height up the dome; azimuth: the facet's horizontal angle. Facets low
## on the dome and near the sun azimuth blend toward gold - the dying sun's
## flush - before the random paint-fleck splatter is considered.
func _face_color(t: float, azimuth: float) -> Color:
	var base: Color = _gradient_color(t)
	var facing: float = clampf(cos(azimuth - SUN_AZIMUTH), 0.0, 1.0)
	var flush: float = facing * facing * clampf(1.0 - t / SUN_GLOW_SPAN, 0.0, 1.0) * 0.5
	base = base.lerp(GOLD_ACCENT, flush)
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
			var color: Color = _face_color(t, (th0 + th1) * 0.5)
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
