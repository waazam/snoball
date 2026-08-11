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
const VISUAL_RES := 81                   # ~2.5 units/sample over SIZE - plenty smooth for hills this broad, much cheaper to render

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
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := SIZE * 0.5
	var step: float = SIZE / float(VISUAL_RES - 1)
	var last: int = VISUAL_RES - 1
	for iz in range(last):
		for ix in range(last):
			var x0: float = -half + ix * step
			var x1: float = x0 + step
			var z0: float = -half + iz * step
			var z1: float = z0 + step
			var p00 := Vector3(x0, TerrainHeight.get_height(x0, z0), z0)
			var p10 := Vector3(x1, TerrainHeight.get_height(x1, z0), z0)
			var p01 := Vector3(x0, TerrainHeight.get_height(x0, z1), z1)
			var p11 := Vector3(x1, TerrainHeight.get_height(x1, z1), z1)
			var uv00 := Vector2(float(ix) / last, float(iz) / last)
			var uv10 := Vector2(float(ix + 1) / last, float(iz) / last)
			var uv01 := Vector2(float(ix) / last, float(iz + 1) / last)
			var uv11 := Vector2(float(ix + 1) / last, float(iz + 1) / last)
			_add_tri(st, p00, p10, p11, uv00, uv10, uv11)
			_add_tri(st, p00, p11, p01, uv00, uv11, uv01)
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	if ground_material:
		mi.material_override = ground_material
	add_child(mi)

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2) -> void:
	st.set_uv(uva)
	st.add_vertex(a)
	st.set_uv(uvb)
	st.add_vertex(b)
	st.set_uv(uvc)
	st.add_vertex(c)
