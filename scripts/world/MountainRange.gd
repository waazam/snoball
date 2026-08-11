extends MeshInstance3D
## A ring of jagged mountain silhouettes far beyond the arena, forming a
## continuous horizon skyline in every direction - a single flat, unshaded
## strip of connected triangles (same faceted-flat-shaded technique as
## LowPolySky.gd's dome, just a ring instead of a hemisphere, since this
## only needs to read as distant terrain along the horizon).
##
## Arena.tscn's fog_density attenuates visibility roughly like
## exp(-density * distance) - pushing RADIUS out further (walls now sit at
## +-120, map's been enlarged) means fog_density had to come down a notch
## too (see Arena.tscn's Environment) or this would fade to nothing again.

const RADIUS := 190.0
const PEAK_COUNT := 80  # more, smaller peaks read as a textured skyline instead of a few giant shark teeth
const HEIGHT_MIN := 14.0
const HEIGHT_MAX := 34.0
const RADIUS_JITTER := 14.0  # per-peak distance variation, so the ring doesn't read as a perfect circle
const ANGLE_JITTER := 0.25   # fraction of a slice width - breaks up the perfectly even spacing
const BASE_Y := -4.0  # sinks below ground level so there's no gap under the horizon

## Dark, warm-toned near-silhouette colors - a near-black/maroon silhouette
## reads clearly against the bright orange sky.horizon_color (Arena.tscn)
## the way real mountains do at sunset, unlike a lighter color that would
## wash out against it.
const NEAR_COLOR := Color(0.14, 0.07, 0.1)   # warm dark maroon-brown, closer/lower peaks
const FAR_COLOR := Color(0.04, 0.03, 0.07)   # near-black, taller/further peaks

func _ready() -> void:
	mesh = _build_range()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## PEAK_COUNT triangles, each spanning one angular slice of the ring: two
## ground-level base corners plus one peak at the slice's midpoint. Height
## blends a slow, low-frequency undulation (a couple of overlapping sine
## waves around the ring) with per-peak random noise, so nearby peaks
## trend toward similar heights - reading as rolling "sections" of taller
## and shorter terrain like a real range - instead of every peak being an
## independent coin-flip next to its neighbors. Per-peak radius and angle
## jitter on top of that keeps the ring from reading as a perfect circle.
func _build_range() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var slice: float = TAU / PEAK_COUNT
	for i in PEAK_COUNT:
		var a0: float = i * slice + rng.randf_range(-slice, slice) * ANGLE_JITTER
		var a1: float = (i + 1) * slice + rng.randf_range(-slice, slice) * ANGLE_JITTER
		var am: float = (a0 + a1) * 0.5

		var r0: float = RADIUS + rng.randf_range(-RADIUS_JITTER, RADIUS_JITTER)
		var r1: float = RADIUS + rng.randf_range(-RADIUS_JITTER, RADIUS_JITTER)
		var rm: float = RADIUS + rng.randf_range(-RADIUS_JITTER, RADIUS_JITTER)

		var undulation: float = (sin(am * 2.3) + sin(am * 5.1 + 1.7)) * 0.25 + 0.5  # ~0..1, slow-rolling
		var height: float = lerpf(HEIGHT_MIN, HEIGHT_MAX, clampf(undulation + rng.randf_range(-0.15, 0.15), 0.0, 1.0))

		var base0 := Vector3(cos(a0) * r0, BASE_Y, sin(a0) * r0)
		var base1 := Vector3(cos(a1) * r1, BASE_Y, sin(a1) * r1)
		var peak := Vector3(cos(am) * rm, BASE_Y + height, sin(am) * rm)
		var color: Color = NEAR_COLOR.lerp(FAR_COLOR, rng.randf_range(0.0, 0.7))
		_add_tri(st, base0, base1, peak, color)
	st.generate_normals()
	return st.commit()

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)
