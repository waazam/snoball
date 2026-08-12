extends MeshInstance3D
## A ring of jagged mountain silhouettes far beyond the arena, forming a
## continuous horizon skyline in every direction - flat, unshaded strips of
## connected triangles (same faceted-flat-shaded technique as LowPolySky.gd's
## dome, just rings instead of a hemisphere, since this only needs to read
## as distant terrain along the horizon).
##
## Two overlapping rings now instead of one: a nearer, darker ring of
## modest peaks in front of a farther, taller ring that's hazed toward the
## dusk-violet sky - classic layered-silhouette depth for one extra strip
## of triangles. Tall peaks carry faceted snow caps whose color leans warm
## (alpenglow) on the sun-facing side and cool blue away from it, matching
## the arena's snow palette (ART_DIRECTION.md Section 3 / 6a).
##
## Arena.tscn's fog_density attenuates visibility roughly like
## exp(-density * distance) - both rings stay inside LowPolySky.gd's
## RADIUS=260 dome so they always draw in front of it.

const NEAR_RADIUS := 190.0
const NEAR_PEAK_COUNT := 80  # more, smaller peaks read as a textured skyline instead of a few giant shark teeth
const NEAR_HEIGHT_MIN := 14.0
const NEAR_HEIGHT_MAX := 34.0

const FAR_RADIUS := 228.0
const FAR_PEAK_COUNT := 52   # fewer, broader, taller peaks looming behind the near ring
const FAR_HEIGHT_MIN := 24.0
const FAR_HEIGHT_MAX := 52.0

const RADIUS_JITTER := 14.0  # per-peak distance variation, so the rings don't read as perfect circles
const ANGLE_JITTER := 0.25   # fraction of a slice width - breaks up the perfectly even spacing
const BASE_Y := -4.0  # sinks below ground level so there's no gap under the horizon

## ART_DIRECTION.md palette: #241220 near / #0A0812 far, so silhouettes sit
## cleanly against the #F2854A horizon band.
const NEAR_COLOR := Color(0.141, 0.071, 0.125)   # #241220
const FAR_COLOR := Color(0.039, 0.031, 0.071)    # #0A0812
const HAZE_COLOR := Color(0.29, 0.204, 0.4)      # #4A3466 dusk violet - distance haze on the far ring
const SNOW_SHADOW := Color(0.561, 0.639, 0.784)  # #8FA3C8 - shaded snow caps
const SNOW_ALPENGLOW := Color(0.965, 0.847, 0.769)  # #F6D8C4 - sun-kissed snow caps

## Horizontal azimuth of Arena.tscn's low Sun (yaw 145deg) - snow caps
## facing this direction blush warm, the rest stay cold blue.
const SUN_AZIMUTH := -0.96

func _ready() -> void:
	mesh = _build_range()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_range() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# Far ring first (behind), hazed toward the sky; near ring on top.
	_add_ring(st, rng, FAR_RADIUS, FAR_PEAK_COUNT, FAR_HEIGHT_MIN, FAR_HEIGHT_MAX, 0.45, 0.55)
	_add_ring(st, rng, NEAR_RADIUS, NEAR_PEAK_COUNT, NEAR_HEIGHT_MIN, NEAR_HEIGHT_MAX, 0.0, 0.45)
	st.generate_normals()
	return st.commit()

## One ring of peak triangles. Height blends a slow, low-frequency
## undulation (a couple of overlapping sine waves around the ring) with
## per-peak random noise, so nearby peaks trend toward similar heights -
## reading as rolling "sections" of taller and shorter terrain like a real
## range - instead of every peak being an independent coin-flip next to its
## neighbors. Per-peak radius and angle jitter on top of that keeps the
## ring from reading as a perfect circle. haze lerps the rock color toward
## the dusk-violet sky (0 = crisp near silhouette, higher = farther away);
## snowline_frac is the 0..1 height above which a peak earns a snow cap.
func _add_ring(st: SurfaceTool, rng: RandomNumberGenerator, radius: float, peak_count: int, height_min: float, height_max: float, haze: float, snowline_frac: float) -> void:
	var slice: float = TAU / peak_count
	for i in peak_count:
		var a0: float = i * slice + rng.randf_range(-slice, slice) * ANGLE_JITTER
		var a1: float = (i + 1) * slice + rng.randf_range(-slice, slice) * ANGLE_JITTER
		var am: float = (a0 + a1) * 0.5

		var r0: float = radius + rng.randf_range(-RADIUS_JITTER, RADIUS_JITTER)
		var r1: float = radius + rng.randf_range(-RADIUS_JITTER, RADIUS_JITTER)
		var rm: float = radius + rng.randf_range(-RADIUS_JITTER, RADIUS_JITTER)

		var undulation: float = (sin(am * 2.3) + sin(am * 5.1 + 1.7)) * 0.25 + 0.5  # ~0..1, slow-rolling
		var h_t: float = clampf(undulation + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
		var height: float = lerpf(height_min, height_max, h_t)

		var base0 := Vector3(cos(a0) * r0, BASE_Y, sin(a0) * r0)
		var base1 := Vector3(cos(a1) * r1, BASE_Y, sin(a1) * r1)
		var peak := Vector3(cos(am) * rm, BASE_Y + height, sin(am) * rm)
		var color: Color = NEAR_COLOR.lerp(FAR_COLOR, rng.randf_range(0.0, 0.7)).lerp(HAZE_COLOR, haze)
		_add_tri(st, base0, base1, peak, color)

		# Snow cap: tall-enough peaks get a smaller faceted triangle riding
		# the apex, its lower edge cut at a random height per side so the
		# snowline looks broken rather than machine-straight. Pulled a hair
		# toward the arena so it never z-fights its own rock face.
		if h_t > snowline_frac:
			var f0: float = rng.randf_range(0.42, 0.62)
			var f1: float = rng.randf_range(0.42, 0.62)
			var cap0: Vector3 = _toward_center(base0.lerp(peak, f0))
			var cap1: Vector3 = _toward_center(base1.lerp(peak, f1))
			var cap_peak: Vector3 = _toward_center(peak)
			var facing: float = clampf(cos(am - SUN_AZIMUTH), 0.0, 1.0)
			var cap_color: Color = SNOW_SHADOW.lerp(SNOW_ALPENGLOW, facing * 0.85).lerp(HAZE_COLOR, haze * 0.6)
			_add_tri(st, cap0, cap1, cap_peak, cap_color)

func _toward_center(v: Vector3) -> Vector3:
	return Vector3(v.x * 0.995, v.y, v.z * 0.995)

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)
