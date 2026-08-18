class_name SnowballVisuals
extends RefCounted
## Builds a small procedural mesh assembly for a given snowball "shape" id
## (see SnowballDB.get_shape). Shared by every thrown snowball (Snowball.gd)
## so each of the 9 present-granted types actually looks distinct instead
## of just being a recolored sphere - same code-built approach as
## HatVisuals.gd.
##
## Also owns the shared flight-trail wisp + impact puff builders
## (make_trail / spawn_impact_puff): every snowball leaves a faint unshaded
## SNOW_LIT wisp behind it, tinted to the type's FX color for effect balls
## (see ART_DIRECTION.md section 6e). Draw meshes and per-tint particle
## materials are cached in statics so repeated throws never re-allocate
## GPU resources.

const RADIUS := 0.22

# "Alpenglow Dusk" palette (ART_DIRECTION.md) - hexes copied verbatim.
const SNOW_LIT := Color("#EAF2FB")
const FROST_GLOW := Color("#A8E4FF")
const DEATH_EMISSION := Color("#8C2BD9")
const VOID_CORE := Color("#0A0812")
const WOOD_BARK := Color("#4A3325")
const PINE_DARK := Color("#1C3D24")
const COAL_DARK := Color("#26221F")
const STEEL := Color("#9AA4B5")
const EMBER_GOLD := Color("#FFB84D")

# Per-shape trail/impact tints - default is the plain snow wisp; effect
# snowballs tint the wisp to their documented FX color.
const TRAIL_TINTS := {
	"ice": Color("#A8E4FF"),
	"death_ball": Color("#8C2BD9"),
	"piss_ball": Color("#D9B81C"),
	"sap": Color("#7FA332"),
}

## build() is called on every single snowball spawn - every player throw,
## every enemy throw, every cluster shard - and its output is fully
## deterministic in (shape, color) (no per-call randomness anywhere in the
## builders below). Without caching, every one of those throws was building
## a brand-new tree of Mesh/StandardMaterial3D resources from scratch, which
## at high wave counts (dozens of enemies each throwing every second or two,
## on top of the player's own throws) was a steady stream of avoidable
## RenderingServer allocations - a real contributor to the wave-scaling
## slowdown. Instead, build a template once per (shape, color) key and keep
## reusing it: Node.duplicate() gives every caller its own independent node
## tree (safe to move/rotate/free) while sharing the same underlying Mesh/
## Material resources (duplicate() copies node structure, not the resources
## a MeshInstance3D's mesh/material_override point to - same idiom the trail/
## puff particle materials below already use, just applied to the body too).
static var _build_cache: Dictionary = {}  # "shape|colorhex" -> template Node3D, never added to a live tree

static func build(shape: String, color: Color) -> Node3D:
	var key: String = "%s|%s" % [shape, color.to_html(true)]
	var template: Node3D = _build_cache.get(key)
	if template == null:
		template = _build_uncached(shape, color)
		_build_cache[key] = template
	return template.duplicate()

static func _build_uncached(shape: String, color: Color) -> Node3D:
	match shape:
		"perfect_white":
			return _build_perfect(color)
		"piss_ball":
			return _build_piss(color)
		"gravel":
			return _build_studded(color, COAL_DARK, "chunk", 7)
		"sap":
			return _build_studded(color, PINE_DARK, "needle", 9)
		"sticks":
			return _build_studded(color, WOOD_BARK, "stick", 6)
		"nails":
			return _build_studded(color, STEEL, "nail", 7)
		"ice":
			return _build_ice(color)
		"death_ball":
			return _build_death_ball(color)
		"yeti_sword":
			return _build_yeti_sword(color)
		_:
			return _build_simple(color, 8)

# --- Materials (conventions from ART_DIRECTION.md section 4) -------------
## Packed snow: matte with a cold rim sparkle-edge against the dusk.
static func _snow_mat(color: Color, roughness: float = 0.92, rim: float = 0.25) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.8
	return m

static func _rough_mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

static func _metal_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.35
	m.metallic = 0.9
	return m

# Shared unshaded white glint material (tiny sparkle dots on snow bodies).
static var _glint_mat: StandardMaterial3D = null

static func _get_glint_mat() -> StandardMaterial3D:
	if _glint_mat == null:
		_glint_mat = StandardMaterial3D.new()
		_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glint_mat.albedo_color = Color("#FFFFFF")
	return _glint_mat

# --- Shared builders -----------------------------------------------------
static func _base_sphere(color: Color, segments: int, mat: StandardMaterial3D = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = RADIUS
	mesh.height = RADIUS * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(4, int(segments * 0.6))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat if mat != null else _snow_mat(color)
	return mi

## Golden-angle spiral point on the unit sphere - even scatter for lumps,
## studs and glints.
static func _scatter_normal(i: int, count: int) -> Vector3:
	var t: float = (float(i) + 0.5) / float(count)
	var phi: float = acos(1.0 - 2.0 * t)
	var theta: float = PI * (1.0 + sqrt(5.0)) * float(i)
	return Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))

## A few flush lumps (shared body material) + tiny unshaded glint dots so
## the ball reads as hand-packed snow catching the dusk light.
static func _add_packed_detail(root: Node3D, mat: StandardMaterial3D, lumps: int = 5, glints: int = 3) -> void:
	for i in lumps:
		var n: Vector3 = _scatter_normal(i, lumps)
		var lm := SphereMesh.new()
		lm.radius = RADIUS * lerpf(0.16, 0.26, fmod(float(i) * 0.618, 1.0))
		lm.height = lm.radius * 2.0
		lm.radial_segments = 8
		lm.rings = 4
		var mi := MeshInstance3D.new()
		mi.mesh = lm
		mi.material_override = mat
		mi.position = n * RADIUS * 0.88
		root.add_child(mi)
	for i in glints:
		var gn: Vector3 = _scatter_normal(i * 2 + 1, glints * 2 + 1)
		var gm := SphereMesh.new()
		gm.radius = RADIUS * 0.06
		gm.height = gm.radius * 2.0
		gm.radial_segments = 6
		gm.rings = 3
		var gi := MeshInstance3D.new()
		gi.mesh = gm
		gi.material_override = _get_glint_mat()
		gi.position = gn * RADIUS * 0.99
		root.add_child(gi)

# --- The 9 looks ---------------------------------------------------------
## Plain packed-snow ball - chunky low-segment sphere with lumps + glints.
static func _build_simple(color: Color, segments: int) -> Node3D:
	var root := Node3D.new()
	var mat := _snow_mat(color)
	root.add_child(_base_sphere(color, segments, mat))
	_add_packed_detail(root, mat)
	return root

## Flawlessly round and softly glossy, with a stronger cold rim (0.3).
static func _build_perfect(color: Color) -> Node3D:
	var root := Node3D.new()
	var mat := _snow_mat(color, 0.3, 0.3)
	root.add_child(_base_sphere(color, 24, mat))
	_add_packed_detail(root, mat, 0, 3)
	return root

## Best not to ask: wet-look yellow snow with a couple of drips.
static func _build_piss(color: Color) -> Node3D:
	var root := Node3D.new()
	var mat := _snow_mat(color, 0.55, 0.12)
	root.add_child(_base_sphere(color, 10, mat))
	for i in 2:
		var drip := SphereMesh.new()
		drip.radius = RADIUS * 0.12
		drip.height = RADIUS * 0.32
		drip.radial_segments = 8
		drip.rings = 4
		var mi := MeshInstance3D.new()
		mi.mesh = drip
		mi.material_override = mat
		var a: float = TAU * float(i) / 2.0 + 0.7
		mi.position = Vector3(cos(a) * RADIUS * 0.5, -RADIUS * 0.85, sin(a) * RADIUS * 0.5)
		root.add_child(mi)
	return root

## Ice convention (the ONLY clearcoat user): glassy, faintly emissive
## frost-blue, hanging icicle spikes + meltwater droplets.
static func _build_ice(color: Color) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.emission_enabled = true
	mat.emission = FROST_GLOW
	mat.emission_energy_multiplier = 0.45
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.6
	mat.clearcoat_roughness = 0.1
	root.add_child(_base_sphere(color, 14, mat))
	for i in 3:
		var spike := CylinderMesh.new()
		spike.top_radius = 0.014
		spike.bottom_radius = 0.001
		spike.height = 0.1
		spike.radial_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = spike
		mi.material_override = mat
		var a: float = TAU * float(i) / 3.0
		mi.position = Vector3(cos(a) * RADIUS * 0.45, -RADIUS * 0.75 - 0.03, sin(a) * RADIUS * 0.45)
		root.add_child(mi)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(FROST_GLOW.r, FROST_GLOW.g, FROST_GLOW.b, 0.85)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.roughness = 0.05
	for i in 2:
		var drop := SphereMesh.new()
		drop.radius = RADIUS * 0.13
		drop.height = RADIUS * 0.32
		drop.radial_segments = 8
		drop.rings = 4
		var dmi := MeshInstance3D.new()
		dmi.mesh = drop
		dmi.material_override = drop_mat
		var a2: float = TAU * float(i) / 2.0 + 1.1
		dmi.position = Vector3(cos(a2) * RADIUS * 0.6, -RADIUS * 0.8, sin(a2) * RADIUS * 0.6)
		root.add_child(dmi)
	return root

## A slowly-pulsating void: deep-violet shell with hot purple emission
## (glow does the bloom), a near-black core, and emissive motes caught in
## orbit. The scale "breathing" is animated by Snowball.gd in flight.
static func _build_death_ball(color: Color) -> Node3D:
	var root := Node3D.new()
	var shell := StandardMaterial3D.new()
	shell.albedo_color = color
	shell.roughness = 0.6
	shell.emission_enabled = true
	shell.emission = DEATH_EMISSION
	shell.emission_energy_multiplier = 3.0
	root.add_child(_base_sphere(color, 16, shell))
	var core := SphereMesh.new()
	core.radius = RADIUS * 0.55
	core.height = RADIUS * 1.1
	core.radial_segments = 12
	core.rings = 6
	var cmi := MeshInstance3D.new()
	cmi.mesh = core
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.albedo_color = VOID_CORE
	cmi.material_override = cmat
	root.add_child(cmi)
	var mote_mat := StandardMaterial3D.new()
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_mat.albedo_color = DEATH_EMISSION
	mote_mat.emission_enabled = true
	mote_mat.emission = DEATH_EMISSION
	mote_mat.emission_energy_multiplier = 3.0
	for i in 5:
		var n: Vector3 = _scatter_normal(i, 5)
		var mote := SphereMesh.new()
		mote.radius = 0.025
		mote.height = 0.05
		mote.radial_segments = 6
		mote.rings = 3
		var mmi := MeshInstance3D.new()
		mmi.mesh = mote
		mmi.material_override = mote_mat
		mmi.position = n * RADIUS * 1.25
		root.add_child(mmi)
	return root

## The Yeti boss's dropped weapon (see EnemyYeti.gd/SwordPickup.gd): a long
## blade shaped like a tiered Christmas tree - wooden handle, gold metallic
## crossguard + pommel, four tapering pine tiers each dusted with a snow
## ring, a gold emissive star at the tip, and small emissive "light"
## spheres spiraling up the tiers cycling the ember bulb colors.
const _SWORD_LIGHT_COLORS := [Color("#E8483F"), Color("#FFB84D"), Color("#4FBF6B")]

static func _build_yeti_sword(color: Color) -> Node3D:
	var root := Node3D.new()
	_add_cyl(root, Vector3(0, 0.09, 0), 0.028, 0.032, 0.18, _rough_mat(WOOD_BARK, 0.92))
	var gold := _metal_mat(EMBER_GOLD)
	_add_box(root, Vector3(0, 0.19, 0), Vector3(0.16, 0.02, 0.05), gold)
	var pommel := SphereMesh.new()
	pommel.radius = 0.03
	pommel.height = 0.06
	pommel.radial_segments = 10
	pommel.rings = 5
	var pmi := MeshInstance3D.new()
	pmi.mesh = pommel
	pmi.material_override = gold
	pmi.position = Vector3(0, -0.01, 0)
	root.add_child(pmi)
	var tier_mat := _rough_mat(color, 0.85)
	var snow_ring_mat := _snow_mat(SNOW_LIT)
	var tiers := 4
	var base_y := 0.24
	var tier_h := 0.14
	var tier_step: float = tier_h * 0.82
	for i in tiers:
		var t: float = float(i) / float(tiers - 1)
		var r: float = lerpf(0.17, 0.05, t)
		_add_cyl(root, Vector3(0, base_y + i * tier_step, 0), 0.0, r, tier_h, tier_mat)
		# Snow dusting: a thin ring hugging each tier's lower edge
		var ring := TorusMesh.new()
		ring.inner_radius = r * 0.84
		ring.outer_radius = r * 1.02
		ring.rings = 20
		ring.ring_segments = 8
		var rmi := MeshInstance3D.new()
		rmi.mesh = ring
		rmi.material_override = snow_ring_mat
		rmi.position = Vector3(0, base_y + i * tier_step - tier_h * 0.42, 0)
		root.add_child(rmi)
	var tip_y: float = base_y + (tiers - 1) * tier_step + tier_h * 0.5
	var star := StandardMaterial3D.new()
	star.albedo_color = EMBER_GOLD
	star.roughness = 0.5
	star.emission_enabled = true
	star.emission = EMBER_GOLD
	star.emission_energy_multiplier = 1.5
	_add_box(root, Vector3(0, tip_y, 0), Vector3(0.085, 0.028, 0.014), star)
	_add_box(root, Vector3(0, tip_y, 0), Vector3(0.028, 0.085, 0.014), star)
	for i in 7:
		var t2: float = (float(i) + 0.5) / 7.0
		var y: float = base_y + t2 * (tiers - 1) * tier_step
		var ring_r: float = lerpf(0.17, 0.06, t2) * 0.95
		var a: float = t2 * TAU * 2.3
		_add_light(root, Vector3(cos(a) * ring_r, y, sin(a) * ring_r), _SWORD_LIGHT_COLORS[i % _SWORD_LIGHT_COLORS.size()])
	return root

static func _add_cyl(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float, height: float, mat: StandardMaterial3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

static func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
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

## A packed-snow base sphere with N small "stud" assemblies scattered
## evenly over its surface (golden-angle spiral) and oriented so each one
## points radially outward, protruding through the surface - used for
## gravel chunks, pine needles, sticks, and nails.
static func _build_studded(base_color: Color, stud_color: Color, stud_kind: String, count: int) -> Node3D:
	var root := Node3D.new()
	var mat := _snow_mat(base_color)
	root.add_child(_base_sphere(base_color, 8, mat))
	_add_packed_detail(root, mat, 3, 2)
	for i in count:
		var normal: Vector3 = _scatter_normal(i, count)
		var stud := _build_stud(stud_kind, stud_color)
		stud.position = normal * RADIUS * 0.9
		var arbitrary: Vector3 = Vector3.RIGHT if absf(normal.y) < 0.9 else Vector3.FORWARD
		var x_axis: Vector3 = arbitrary.cross(normal).normalized()
		var z_axis: Vector3 = normal.cross(x_axis).normalized()
		stud.transform.basis = Basis(x_axis, normal, z_axis)
		root.add_child(stud)
	return root

## One stud assembly, local +Y = outward. Each kind gets real craft:
## chunks are two offset rock boxes, needles come in crossed pairs, sticks
## carry a snapped-off twig, nails are metallic spikes with flat heads.
static func _build_stud(kind: String, color: Color) -> Node3D:
	var root := Node3D.new()
	match kind:
		"chunk":
			var m := _rough_mat(color, 0.9)
			_stud_box(root, m, Vector3(0.055, 0.05, 0.055), Vector3.ZERO, Vector3(0, 25, 10))
			_stud_box(root, m, Vector3(0.04, 0.045, 0.038), Vector3(0.012, 0.02, -0.01), Vector3(30, 45, 0))
		"needle":
			var m2 := _rough_mat(color, 0.85)
			_stud_cyl(root, m2, 0.0, 0.012, 0.1, Vector3(0, 0.02, 0), Vector3.ZERO)
			_stud_cyl(root, m2, 0.0, 0.01, 0.085, Vector3(0.012, 0.015, 0.008), Vector3(12, 0, -14))
		"stick":
			var m3 := _rough_mat(color, 0.92)
			_stud_cyl(root, m3, 0.012, 0.017, 0.16, Vector3.ZERO, Vector3(0, 0, 6))
			_stud_cyl(root, m3, 0.006, 0.009, 0.05, Vector3(0.015, 0.04, 0), Vector3(0, 0, -40))
		"nail":
			var m4 := _metal_mat(color)
			_stud_cyl(root, m4, 0.0, 0.013, 0.11, Vector3(0, 0.02, 0), Vector3.ZERO)
			_stud_cyl(root, m4, 0.022, 0.022, 0.008, Vector3(0, -0.025, 0), Vector3.ZERO)
		_:
			_stud_box(root, _rough_mat(color, 0.9), Vector3(0.04, 0.04, 0.04), Vector3.ZERO, Vector3.ZERO)
	return root

static func _stud_cyl(parent: Node3D, mat: StandardMaterial3D, top_r: float, bottom_r: float, height: float, pos: Vector3, rot_deg: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 7
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)

static func _stud_box(parent: Node3D, mat: StandardMaterial3D, size: Vector3, pos: Vector3, rot_deg: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)

# --- Flight trail + impact puff (visual-only, web-budget cheap) ----------
static var _wisp_mesh: QuadMesh = null
static var _trail_pm_cache: Dictionary = {}
static var _puff_pm_cache: Dictionary = {}

static func trail_color_for(shape: String) -> Color:
	return TRAIL_TINTS.get(shape, SNOW_LIT)

static func _get_wisp_mesh() -> QuadMesh:
	if _wisp_mesh == null:
		_wisp_mesh = QuadMesh.new()
		_wisp_mesh.size = Vector2(0.14, 0.14)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.disable_receive_shadows = true
		_wisp_mesh.material = m
	return _wisp_mesh

static func _make_pm(color: Color, start_alpha: float) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, start_alpha))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	return pm

static func _get_trail_pm(color: Color) -> ParticleProcessMaterial:
	var key: String = color.to_html(true)
	if not _trail_pm_cache.has(key):
		var pm := _make_pm(color, 0.4)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 0.0
		pm.initial_velocity_max = 0.3
		pm.gravity = Vector3(0, 0.5, 0)
		pm.scale_min = 0.5
		pm.scale_max = 1.0
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.08
		_trail_pm_cache[key] = pm
	return _trail_pm_cache[key]

static func _get_puff_pm(color: Color) -> ParticleProcessMaterial:
	var key: String = color.to_html(true)
	if not _puff_pm_cache.has(key):
		var pm := _make_pm(color, 0.85)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 85.0
		pm.initial_velocity_min = 1.6
		pm.initial_velocity_max = 3.2
		pm.gravity = Vector3(0, -5.0, 0)
		pm.damping_min = 1.0
		pm.damping_max = 2.0
		pm.scale_min = 1.2
		pm.scale_max = 2.1
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.1
		_puff_pm_cache[key] = pm
	return _puff_pm_cache[key]

## Continuous wisp emitter to add_child onto a snowball in flight.
static func make_trail(color: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "TrailWisp"
	p.amount = 16
	p.lifetime = 0.35
	p.local_coords = false
	p.draw_pass_1 = _get_wisp_mesh()
	p.process_material = _get_trail_pm(color)
	return p

## One-shot snow puff at an impact point; frees itself when finished.
static func spawn_impact_puff(parent: Node, pos: Vector3, color: Color) -> void:
	if parent == null:
		return
	var p := GPUParticles3D.new()
	p.name = "ImpactPuff"
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 10
	p.lifetime = 0.45
	p.local_coords = false
	p.emitting = false
	p.draw_pass_1 = _get_wisp_mesh()
	p.process_material = _get_puff_pm(color)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
