class_name SnowballVisuals
extends RefCounted
## Builds a small procedural mesh assembly for a given snowball "shape" id
## (see SnowballDB.get_shape). Shared by every thrown snowball (Snowball.gd)
## so each of the 9 present-granted types actually looks distinct instead
## of just being a recolored sphere - same code-built approach as
## HatVisuals.gd.

const RADIUS := 0.22

static func build(shape: String, color: Color) -> Node3D:
	match shape:
		"perfect_white":
			return _build_perfect(color)
		"piss_ball":
			return _build_simple(color, 10)
		"gravel":
			return _build_studded(color, Color(0.35, 0.32, 0.3), "chunk", 7)
		"sap":
			return _build_studded(color, Color(0.15, 0.4, 0.12), "needle", 9)
		"sticks":
			return _build_studded(color, Color(0.38, 0.26, 0.15), "stick", 6)
		"nails":
			return _build_studded(color, Color(0.6, 0.62, 0.65), "nail", 7)
		"ice":
			return _build_ice(color)
		"death_ball":
			return _build_death_ball(color)
		"yeti_sword":
			return _build_yeti_sword(color)
		_:
			return _build_simple(color, 6)

static func _base_sphere(color: Color, segments: int) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = RADIUS
	mesh.height = RADIUS * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(4, int(segments * 0.6))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi

## Plain packed-snow ball - a chunky low-segment sphere, standard/enemy look.
static func _build_simple(color: Color, segments: int) -> Node3D:
	var root := Node3D.new()
	root.add_child(_base_sphere(color, segments))
	return root

## Flawlessly round and glossy, unlike the standard ball's chunkier facets.
static func _build_perfect(color: Color) -> Node3D:
	var root := Node3D.new()
	var mi := _base_sphere(color, 22)
	var mat: StandardMaterial3D = mi.material_override
	mat.roughness = 0.15
	mat.metallic = 0.05
	root.add_child(mi)
	return root

## Translucent, glossy ice ball with a few hanging meltwater droplets.
static func _build_ice(color: Color) -> Node3D:
	var root := Node3D.new()
	var mi := _base_sphere(Color(color.r, color.g, color.b, 0.75), 14)
	var mat: StandardMaterial3D = mi.material_override
	mat.roughness = 0.05
	mat.metallic = 0.1
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	root.add_child(mi)
	for i in 3:
		var drop := SphereMesh.new()
		drop.radius = RADIUS * 0.14
		drop.height = RADIUS * 0.34
		var dmi := MeshInstance3D.new()
		dmi.mesh = drop
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.75, 0.92, 1.0, 0.85)
		dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dmat.roughness = 0.05
		dmi.material_override = dmat
		var angle: float = (TAU / 3.0) * i
		dmi.position = Vector3(cos(angle) * RADIUS * 0.6, -RADIUS * 0.85, sin(angle) * RADIUS * 0.6)
		root.add_child(dmi)
	return root

## A dark, unshaded, slowly-pulsating void with a near-black core - the
## pulsing itself (scale breathing) is animated by Snowball.gd every frame
## while it's in flight, this just builds the look.
static func _build_death_ball(color: Color) -> Node3D:
	var root := Node3D.new()
	var mi := _base_sphere(color, 16)
	var mat: StandardMaterial3D = mi.material_override
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.1, 0.75)
	mat.emission_energy_multiplier = 1.4
	root.add_child(mi)
	var core := SphereMesh.new()
	core.radius = RADIUS * 0.4
	core.height = RADIUS * 0.8
	var cmi := MeshInstance3D.new()
	cmi.mesh = core
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.albedo_color = Color(0.02, 0.0, 0.03)
	cmi.material_override = cmat
	root.add_child(cmi)
	return root

## The Yeti boss's dropped weapon (see EnemyYeti.gd/SwordPickup.gd): a long
## blade shaped like a tiered Christmas tree - a wooden handle and gold
## crossguard, four tapering green tiers stacked into a tree silhouette, a
## gold star at the tip, and small emissive "light" spheres spiraling up the
## tiers. Thrown/equipped exactly like every other snowball type once
## picked up, just a lot longer and stranger-looking.
const _SWORD_LIGHT_COLORS := [Color(0.9, 0.15, 0.15), Color(0.2, 0.55, 0.95), Color(0.95, 0.85, 0.2), Color(0.3, 0.85, 0.4)]

static func _build_yeti_sword(color: Color) -> Node3D:
	var root := Node3D.new()
	_add_cyl(root, Vector3(0, 0.09, 0), 0.028, 0.032, 0.18, Color(0.4, 0.26, 0.12))
	_add_box(root, Vector3(0, 0.19, 0), Vector3(0.16, 0.02, 0.05), Color(0.85, 0.68, 0.2))
	var tiers := 4
	var base_y := 0.24
	var tier_h := 0.14
	var tier_step := tier_h * 0.82
	for i in tiers:
		var t: float = float(i) / float(tiers - 1)
		var r: float = lerp(0.17, 0.05, t)
		_add_cyl(root, Vector3(0, base_y + i * tier_step, 0), 0.0, r, tier_h, color)
	var tip_y: float = base_y + (tiers - 1) * tier_step + tier_h * 0.5
	_add_box(root, Vector3(0, tip_y, 0), Vector3(0.06, 0.06, 0.02), Color(0.95, 0.8, 0.25))
	for i in 7:
		var t2: float = (float(i) + 0.5) / 7.0
		var y: float = base_y + t2 * (tiers - 1) * tier_step
		var ring_r: float = lerp(0.17, 0.06, t2) * 0.95
		var a: float = t2 * TAU * 2.3
		_add_light(root, Vector3(cos(a) * ring_r, y, sin(a) * ring_r), _SWORD_LIGHT_COLORS[i % _SWORD_LIGHT_COLORS.size()])
	return root

static func _add_cyl(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float, height: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

static func _add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

static func _add_light(parent: Node3D, pos: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.02
	mesh.height = 0.04
	mesh.radial_segments = 6
	mesh.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

## A base sphere with N small "stud" meshes scattered evenly over its
## surface (golden-angle spiral distribution) and oriented so each one
## points radially outward, protruding through the surface - used for
## gravel chunks, pine needles, sticks, and nails.
static func _build_studded(base_color: Color, stud_color: Color, stud_kind: String, count: int) -> Node3D:
	var root := Node3D.new()
	root.add_child(_base_sphere(base_color, 8))
	for i in count:
		var t: float = (float(i) + 0.5) / float(count)
		var phi: float = acos(1.0 - 2.0 * t)
		var theta: float = PI * (1.0 + sqrt(5.0)) * i
		var normal := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
		var stud := _build_stud(stud_kind, stud_color)
		stud.position = normal * RADIUS * 0.9
		var arbitrary: Vector3 = Vector3.RIGHT if absf(normal.y) < 0.9 else Vector3.FORWARD
		var x_axis: Vector3 = arbitrary.cross(normal).normalized()
		var z_axis: Vector3 = normal.cross(x_axis).normalized()
		stud.transform.basis = Basis(x_axis, normal, z_axis)
		root.add_child(stud)
	return root

static func _build_stud(kind: String, color: Color) -> MeshInstance3D:
	var mesh: Mesh
	match kind:
		"chunk":
			var box := BoxMesh.new()
			box.size = Vector3(0.055, 0.055, 0.055)
			mesh = box
		"needle":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.0
			cyl.bottom_radius = 0.012
			cyl.height = 0.1
			mesh = cyl
		"stick":
			var cyl2 := CylinderMesh.new()
			cyl2.top_radius = 0.012
			cyl2.bottom_radius = 0.017
			cyl2.height = 0.15
			mesh = cyl2
		"nail":
			var cyl3 := CylinderMesh.new()
			cyl3.top_radius = 0.0
			cyl3.bottom_radius = 0.015
			cyl3.height = 0.11
			mesh = cyl3
		_:
			var box2 := BoxMesh.new()
			box2.size = Vector3(0.04, 0.04, 0.04)
			mesh = box2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi
