extends StaticBody3D
## The arena floor: rolling hills and valleys instead of one flat plane, so
## crossing the open ground between the hand-placed obstacle cluster and
## the walls actually varies instead of being a dead-flat plate. Height
## comes from TerrainHeight.gd (shared with MapFiller.gd, which needs the
## same values to correctly seat its scattered trees/rocks/platforms on
## the resulting slopes) - both the render mesh and the physics collision
## are built from that same function here, so they always agree exactly.
##
## Collision uses a native 1-unit-per-sample HeightMapShape3D (no shape
## scaling) - Jolt (this project's physics engine) is already known not to
## handle non-uniform scaling well on some shape types (see Enemy.gd's
## hit-reaction comment), so this sidesteps that question entirely instead
## of assuming a heightmap shape is exempt. The render mesh doesn't need
## that precision, so it samples the same function at a coarser resolution
## to stay cheap to build/draw, and doesn't need the collision-only safety
## margin below since it's purely cosmetic.
##
## The collision heightmap itself is padded well past the walls (COLLISION_
## PADDING) rather than stopping exactly at them - a flat, invisible safety
## floor out there, so anything that ever launches the player over/through
## a wall (Santa's tornado knockback can, in principle, clear their 4-unit
## height if triggered right next to one) lands on solid ground instead of
## falling forever through empty space. TerrainHeight.gd's own edge falloff
## already flattens to a clean 0 approaching and past +-100, so this pad is
## just extending that already-flat region's actual collision coverage,
## not inventing new terrain shape out there.

const SIZE := 200.0                      # visible/gameplay footprint - matches the walls (at +-100)
const COLLISION_PADDING := 60.0          # extra flat collision margin beyond the walls on every side
const COLLISION_SIZE := SIZE + COLLISION_PADDING * 2.0
const COLLISION_RES := int(COLLISION_SIZE) + 1  # native 1-unit spacing -> exactly COLLISION_SIZE units, no shape scaling needed
const VISUAL_RES := 101                  # 2 units/sample over SIZE - smooth enough for the vertex-color gradients below

# "Alpenglow Dusk" snow palette (ART_DIRECTION.md Section 3) - the render
# mesh carries per-vertex color: valleys sink toward the blue shadow tone,
# west/sunset-facing slopes catch a warm alpenglow kiss, and a faint
# deterministic hash mottles the open field so it doesn't read as one
# untouched sheet. Collision build below is untouched - visual only.
const SNOW_LIT := Color(0.918, 0.949, 0.984)        # #EAF2FB
const SNOW_SHADOW := Color(0.561, 0.639, 0.784)     # #8FA3C8
const SNOW_ALPENGLOW := Color(0.965, 0.847, 0.769)  # #F6D8C4
# Horizontal direction toward the low sun (Arena.tscn's Sun yaw is 145deg).
const SUN_DIR_XZ := Vector3(0.574, 0.0, -0.819)
const NORMAL_EPS := 0.75  # finite-difference step for the color-only surface normal

@export var ground_material: Material

func _ready() -> void:
	_build_collision()
	_build_visual()

func _build_collision() -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = COLLISION_RES
	shape.map_depth = COLLISION_RES
	var data := PackedFloat32Array()
	data.resize(COLLISION_RES * COLLISION_RES)
	var half := COLLISION_SIZE * 0.5
	for iz in COLLISION_RES:
		var z: float = -half + iz
		for ix in COLLISION_RES:
			var x: float = -half + ix
			data[iz * COLLISION_RES + ix] = TerrainHeight.get_height(x, z)
	shape.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)

func _build_visual() -> void:
	var half := SIZE * 0.5
	var step: float = SIZE / float(VISUAL_RES - 1)
	var last: int = VISUAL_RES - 1

	# Precompute the grid once (positions + vertex colors) so each shared
	# corner is only sampled/colored a single time instead of up to six.
	var positions := PackedVector3Array()
	var colors := PackedColorArray()
	positions.resize(VISUAL_RES * VISUAL_RES)
	colors.resize(VISUAL_RES * VISUAL_RES)
	for iz in VISUAL_RES:
		var z: float = -half + iz * step
		for ix in VISUAL_RES:
			var x: float = -half + ix * step
			var h: float = TerrainHeight.get_height(x, z)
			positions[iz * VISUAL_RES + ix] = Vector3(x, h, z)
			colors[iz * VISUAL_RES + ix] = _vertex_color(x, z, h)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(last):
		for ix in range(last):
			var i00: int = iz * VISUAL_RES + ix
			var i10: int = i00 + 1
			var i01: int = i00 + VISUAL_RES
			var i11: int = i01 + 1
			var uv00 := Vector2(float(ix) / last, float(iz) / last)
			var uv10 := Vector2(float(ix + 1) / last, float(iz) / last)
			var uv01 := Vector2(float(ix) / last, float(iz + 1) / last)
			var uv11 := Vector2(float(ix + 1) / last, float(iz + 1) / last)
			_add_tri(st, positions[i00], positions[i10], positions[i11], uv00, uv10, uv11, colors[i00], colors[i10], colors[i11])
			_add_tri(st, positions[i00], positions[i11], positions[i01], uv00, uv11, uv01, colors[i00], colors[i11], colors[i01])
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	if ground_material:
		mi.material_override = ground_material
	add_child(mi)

## Alpenglow-dusk snow shading, baked per vertex: valleys cool toward the
## blue shadow tone, sunset-facing slopes pick up a warm alpenglow tint,
## and a deterministic hash adds faint wind-mottled variation.
func _vertex_color(x: float, z: float, h: float) -> Color:
	var c := SNOW_LIT
	var shade: float = clampf(-h * 0.25, 0.0, 0.6)
	var n := _surface_normal(x, z)
	var glow: float = clampf(n.dot(SUN_DIR_XZ) * 0.5, 0.0, 0.5)
	var mottle: float = absf(fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0))
	c = c.lerp(SNOW_SHADOW, minf(shade + mottle * 0.10, 0.65))
	c = c.lerp(SNOW_ALPENGLOW, glow)
	return c

## Cheap finite-difference normal, used only for the color bake above -
## the mesh's real lighting normals still come from generate_normals().
func _surface_normal(x: float, z: float) -> Vector3:
	var hl: float = TerrainHeight.get_height(x - NORMAL_EPS, z)
	var hr: float = TerrainHeight.get_height(x + NORMAL_EPS, z)
	var hb: float = TerrainHeight.get_height(x, z - NORMAL_EPS)
	var hf: float = TerrainHeight.get_height(x, z + NORMAL_EPS)
	return Vector3(hl - hr, 2.0 * NORMAL_EPS, hb - hf).normalized()

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	st.set_uv(uva)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_uv(uvb)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_uv(uvc)
	st.set_color(cc)
	st.add_vertex(c)
