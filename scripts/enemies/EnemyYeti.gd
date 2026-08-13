extends "res://scripts/enemies/Enemy.gd"
## The Yeti, the round-15 boss - the largest enemy in the game, and the only
## one that spawns that wave (see EnemyDB.get_wave_composition). Melee-only:
## every attack_cooldown (3s) he swings his sword in a wide horizontal arc,
## hitting the player for `damage` if they're still in range and applying a
## heavy bleed on top (see Game.apply_bleed - the player has no per-actor
## status-effect script of its own like enemies do, so that lives on Game).
## On death he drops his sword as a real pickup (SwordPickup.tscn) that
## re-equips the player onto SnowballDB's "yeti_sword" type for the rest of
## the run, replacing whatever snowball they had (see Game.equip_snowball) -
## temporary, unlike the permanent menu-equipped snowballs (Progress.gd).
##
## Body/collision/health bar are hand-placed in EnemyYeti.tscn (same split
## every other boss uses); fur, face, chest, feet, arms and the wielded
## sword are all built here in code, same procedural-detail approach as
## EnemySanta.gd/EnemySnowman.gd. The sword hangs off its own dedicated
## pivot (NOT the LeftShoulder/RightShoulder names Enemy.gd's base run-cycle
## animation looks for) specifically so the attack-swing tween below never
## fights the base class's walk-cycle arm swing over the same rotation
## property.
##
## Look follows ART_DIRECTION.md ("Alpenglow Dusk", sections 3/4/6d):
## blue-white #DCE9F5 fur with backlit rim (the one non-snow rim user),
## #7E93B8 skin face/chest panels, #7FD8FF emissive eyes, icy clearcoat
## icicle accents, and a Christmas-tree sword whose bulbs cycle the ember
## triad #E8483F/#FFB84D/#4FBF6B.

const SWORD_PICKUP_SCENE_PATH := "res://scenes/pickups/SwordPickup.tscn"

# Palette (ART_DIRECTION.md section 3 - copied verbatim, don't invent neighbors)
const FUR_COLOR := Color("#DCE9F5")  # torso + hand-built parts (setup() pins $Body to this - EnemyDB still stores the legacy white)
const FUR_SHADOW_COLOR := Color("#8FA3C8")  # SNOW_SHADOW - under-layer tufts/cuffs
const SKIN_COLOR := Color("#7E93B8")  # face/chest panels
const BROW_COLOR := Color(0.32, 0.37, 0.47)  # SKIN_COLOR darkened ~35% for a menacing scowl
const CLAW_COLOR := Color("#26221F")
const NOSE_COLOR := Color("#26221F")
const EYE_COLOR := Color("#7FD8FF")  # emissive, energy 2.5 (section 6d)
const SNOW_WHITE := Color("#EAF2FB")  # fangs + snow dusting on the sword
const ICE_COLOR := Color("#A8E4FF")  # icicle accents, ice material convention

const TRUNK_COLOR := Color("#4A3325")  # WOOD_BARK
const CROSSGUARD_COLOR := Color("#FFB84D")  # EMBER_GOLD, metal convention
const TREE_GREEN := Color("#1C3D24")  # PINE_DARK blade
const STAR_GOLD := Color("#FFB84D")
const LIGHT_COLORS: Array[Color] = [Color("#E8483F"), Color("#FFB84D"), Color("#4FBF6B")]  # ember triad, cycled by _process
const BOSS_LIGHT_COLOR := Color("#7FD8FF")  # dedicated boss OmniLight (section 6d)

const BODY_Y := 0.925
const BODY_RADIUS := 0.56
const HEAD_Y := 1.78
const HEAD_RADIUS := 0.34

const BLEED_DPS := 10.0
const BLEED_DURATION := 6.0

const SWING_OUT_TIME := 0.35
const SWING_RETURN_TIME := 0.25
const SWING_ANGLE := 75.0

var _eye_left_mat: StandardMaterial3D
var _eye_right_mat: StandardMaterial3D
var _sword_swing_pivot: Node3D
var _swing_tween: Tween = null
var _bulb_mats: Array[StandardMaterial3D] = []
var _bulb_time: float = 0.0

func _ready() -> void:
	super._ready()
	_build_face()
	_build_fur_tufts()
	_build_chest()
	_build_arms()
	_build_feet()
	_build_sword()
	_add_boss_light()

## Visual-only material tuning on top of Enemy.gd's setup(): the base class
## rebuilds $Body's material from EnemyDB's color on every setup, so the fur
## color and convention (roughness 1.0 + backlit rim, ART_DIRECTION sections
## 3/4 - the yeti is the one enemy allowed rim) are re-applied here after it.
## _body_base_color follows so the hit-flash fades back to the right blue-white
## (same pattern as EnemyElf/EnemySnowman).
func setup(id: String, wave: int) -> void:
	super.setup(id, wave)
	_body_base_color = FUR_COLOR
	_body_mat.albedo_color = FUR_COLOR
	_body_mat.roughness = 1.0
	_body_mat.rim_enabled = true
	_body_mat.rim = 0.35
	_body_mat.rim_tint = 0.9

## Purely-visual: the sword's bulbs slow-cycle through the ember triad and
## breathe their glow. No per-frame allocations - the material list is built
## once in _build_sword and colors are only reassigned on an actual step.
func _process(delta: float) -> void:
	if _bulb_mats.is_empty():
		return
	_bulb_time += delta
	var step: int = int(_bulb_time * 1.5)
	var pulse: float = 2.0 + 0.4 * sin(_bulb_time * 2.2)
	for i in _bulb_mats.size():
		var mat: StandardMaterial3D = _bulb_mats[i]
		var c: Color = LIGHT_COLORS[(i + step) % LIGHT_COLORS.size()]
		if mat.emission != c:
			mat.emission = c
			mat.albedo_color = c
		mat.emission_energy_multiplier = pulse

# --- Attack: wide sword swing + bleed -------------------------------------
func _attack(player: Node3D) -> void:
	_swing_sword()
	if global_position.distance_to(player.global_position) <= attack_range and player.has_method("take_hit"):
		player.take_hit(damage)
		Game.apply_bleed(BLEED_DPS, BLEED_DURATION)

func _swing_sword() -> void:
	if _swing_tween and _swing_tween.is_valid():
		_swing_tween.kill()
	_sword_swing_pivot.rotation_degrees.y = -SWING_ANGLE
	_swing_tween = create_tween()
	_swing_tween.tween_property(_sword_swing_pivot, "rotation_degrees:y", SWING_ANGLE, SWING_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(_sword_swing_pivot, "rotation_degrees:y", 0.0, SWING_RETURN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Drops his sword as a real pickup, on top of the normal exp snowflake
## every enemy drops (see Enemy.gd._die/_drop_exp_pickup - unaffected).
func _spawn_death_fx() -> void:
	var scene: PackedScene = load(SWORD_PICKUP_SCENE_PATH)
	var pickup: Area3D = scene.instantiate()
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector3.UP * 0.9

# --- Visuals: face, fur, chest, arms, feet, sword --------------------------
func _build_face() -> void:
	_style_fur(_add_sphere(Vector3(0, HEAD_Y, 0), HEAD_RADIUS, FUR_COLOR))
	# flattened skin face panel so eyes/brows/muzzle pop out of the fur
	var face := _add_sphere(Vector3(0, HEAD_Y + 0.01, -HEAD_RADIUS * 0.68), HEAD_RADIUS * 0.6, SKIN_COLOR)
	face.scale = Vector3(1.2, 1.05, 0.55)
	_style(face, 0.85)
	_style(_add_sphere(Vector3(0, HEAD_Y - HEAD_RADIUS * 0.35, -HEAD_RADIUS * 0.85), HEAD_RADIUS * 0.4, SKIN_COLOR), 0.85)  # muzzle
	_style(_add_sphere(Vector3(0, HEAD_Y - HEAD_RADIUS * 0.4, -HEAD_RADIUS * 1.15), 0.06, NOSE_COLOR), 0.6)

	# angry brows: inner ends pulled down into a scowl
	_style(_add_box(Vector3(-0.13, HEAD_Y + 0.1, -HEAD_RADIUS * 0.78), Vector3(0, 0, -18), Vector3(0.15, 0.045, 0.05), BROW_COLOR), 0.9)
	_style(_add_box(Vector3(0.13, HEAD_Y + 0.1, -HEAD_RADIUS * 0.78), Vector3(0, 0, 18), Vector3(0.15, 0.045, 0.05), BROW_COLOR), 0.9)

	var eye_left: MeshInstance3D = _add_sphere(Vector3(-0.13, HEAD_Y + 0.02, -HEAD_RADIUS * 0.92), 0.055, EYE_COLOR)
	var eye_right: MeshInstance3D = _add_sphere(Vector3(0.13, HEAD_Y + 0.02, -HEAD_RADIUS * 0.92), 0.055, EYE_COLOR)
	_eye_left_mat = _glow_up(eye_left)
	_eye_right_mat = _glow_up(eye_right)

	# upward tusks flanking the muzzle
	for side in [-1, 1]:
		_style(_add_cylinder(Vector3(0.085 * side, HEAD_Y - 0.2, -HEAD_RADIUS * 1.06), Vector3(-8, 0, 6 * side), 0.0, 0.028, 0.11, SNOW_WHITE), 0.6)

	# icicle fringe hanging from the jaw - a frozen "beard"
	_style_ice(_add_cylinder(Vector3(0, HEAD_Y - 0.33, -0.2), Vector3(180, 0, 0), 0.0, 0.024, 0.17, ICE_COLOR))
	_style_ice(_add_cylinder(Vector3(-0.1, HEAD_Y - 0.3, -0.18), Vector3(180, 0, 0), 0.0, 0.02, 0.12, ICE_COLOR))
	_style_ice(_add_cylinder(Vector3(0.1, HEAD_Y - 0.3, -0.18), Vector3(180, 0, 0), 0.0, 0.02, 0.12, ICE_COLOR))

	for side in [-1, 1]:
		_style_fur(_add_sphere(Vector3(0.22 * side, HEAD_Y + 0.28, -0.02), HEAD_RADIUS * 0.28, FUR_COLOR))  # ears

	# crown tufts on top of the skull
	_style_fur(_add_cylinder(Vector3(0, HEAD_Y + HEAD_RADIUS * 0.92, 0.02), Vector3(-14, 0, 0), 0.0, 0.05, 0.18, FUR_COLOR))
	_style_fur(_add_cylinder(Vector3(-0.1, HEAD_Y + HEAD_RADIUS * 0.85, 0.04), Vector3(-10, 0, 18), 0.0, 0.04, 0.14, FUR_COLOR))
	_style_fur(_add_cylinder(Vector3(0.1, HEAD_Y + HEAD_RADIUS * 0.85, 0.04), Vector3(-10, 0, -18), 0.0, 0.04, 0.14, FUR_COLOR))

## Eyes glow ice-blue at rest, same "swap for an emissive material" trick
## EnemySanta.gd's _glow_up uses for his red laser eyes. Energy 2.5 per
## ART_DIRECTION section 6d.
func _glow_up(mi: MeshInstance3D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = EYE_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = EYE_COLOR
	mat.emission_energy_multiplier = 2.5
	mi.material_override = mat
	return mat

## Two interleaved shells of spike tufts over the shoulders/back/head for a
## layered shaggy-fur read - same golden-angle spiral distribution +
## outward-facing Basis construction SnowballVisuals._build_studded uses for
## gravel/nail/stick studs (avoids look_at's degenerate case when a normal
## points straight up). The inner layer is SNOW_SHADOW for depth, the outer
## layer is body-colored and longer.
func _build_fur_tufts() -> void:
	_scatter_tufts(18, 0.95, 0.05, 0.22, FUR_SHADOW_COLOR, 1.7)
	_scatter_tufts(12, 0.85, 0.07, 0.3, FUR_COLOR, 0.0)

func _scatter_tufts(count: int, radius_mult: float, tuft_r: float, tuft_len: float, color: Color, theta_offset: float) -> void:
	for i in count:
		var t: float = (float(i) + 0.5) / float(count)
		var phi: float = acos(1.0 - 2.0 * t) * 0.6  # upper hemisphere-ish only, so tufts don't poke out the belly
		var theta: float = PI * (1.0 + sqrt(5.0)) * i + theta_offset
		var normal := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
		var pos: Vector3 = Vector3(0, BODY_Y, 0) + normal * BODY_RADIUS * radius_mult
		var tuft := _add_cylinder(pos, Vector3.ZERO, 0.0, tuft_r, tuft_len, color)
		_style_fur(tuft)
		var arbitrary: Vector3 = Vector3.RIGHT if absf(normal.y) < 0.9 else Vector3.FORWARD
		var x_axis: Vector3 = arbitrary.cross(normal).normalized()
		var z_axis: Vector3 = normal.cross(x_axis).normalized()
		tuft.transform.basis = Basis(x_axis, normal, z_axis)

## Flattened skin chest plate on the torso front, with a pair of icicles
## frozen onto its upper corners.
func _build_chest() -> void:
	var chest := _add_sphere(Vector3(0, BODY_Y + 0.1, -BODY_RADIUS * 0.79), 0.3, SKIN_COLOR)
	chest.scale = Vector3(1.1, 1.2, 0.5)
	_style(chest, 0.85)
	for side in [-1, 1]:
		_style_ice(_add_cylinder(Vector3(0.24 * side, BODY_Y + 0.28, -0.42), Vector3(180, 0, 10 * side), 0.0, 0.022, 0.13, ICE_COLOR))

func _build_arms() -> void:
	for side in [-1, 1]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.52 * side, 1.3, 0)
		add_child(shoulder)
		_style_fur(_add_cylinder(Vector3(0, -0.32, 0), Vector3.ZERO, 0.19, 0.15, 0.62, FUR_COLOR, shoulder))
		_style_fur(_add_cylinder(Vector3(0, -0.62, 0), Vector3.ZERO, 0.13, 0.16, 0.06, FUR_SHADOW_COLOR, shoulder))
		_style_fur(_add_sphere(Vector3(0, -0.72, 0), 0.14, FUR_COLOR, shoulder))
		for j in 3:
			_style(_add_cylinder(Vector3((j - 1) * 0.06, -0.85, -0.02), Vector3(20, 0, 0), 0.0, 0.02, 0.12, CLAW_COLOR, shoulder), 0.5)
		# mane spikes cresting each shoulder
		for j in 3:
			_style_fur(_add_cylinder(Vector3(side * 0.07, 0.08, -0.1 + j * 0.1), Vector3(0, 0, side * -40.0), 0.0, 0.06, 0.26, FUR_COLOR, shoulder))
		# icicles frozen under the wrist cuff
		for k in 2:
			_style_ice(_add_cylinder(Vector3((k * 2 - 1) * 0.09, -0.7, 0.05), Vector3(180, 0, 0), 0.0, 0.02, 0.11, ICE_COLOR, shoulder))

## Big flat fur feet with dark fore-claws, grounding the silhouette.
func _build_feet() -> void:
	for side in [-1, 1]:
		var foot := _add_sphere(Vector3(0.26 * side, 0.14, -0.06), 0.22, FUR_COLOR)
		foot.scale = Vector3(1.0, 0.6, 1.35)
		_style_fur(foot)
		for j in 3:
			_style(_add_cylinder(Vector3(0.26 * side + (j - 1) * 0.08, 0.1, -0.36), Vector3(-70, 0, 0), 0.0, 0.025, 0.1, CLAW_COLOR), 0.5)

## The wielded sword: a SwingPivot at the shoulder (this is what the attack
## tween rotates - a plain world-Y yaw at the shoulder sweeps everything
## attached, including the blade's own resting tilt, through a wide
## horizontal arc), holding a GripTilt that angles the blade out and down
## into a natural "held ready" pose. Deliberately not parented under any
## node Enemy.gd's base animation drives (see file header comment).
## Blade is PINE_DARK with snow-dusted lower tiers, a gold metal crossguard/
## star, and 6 bulbs cycling the ember triad (see _process), per
## ART_DIRECTION section 6d.
func _build_sword() -> void:
	_sword_swing_pivot = Node3D.new()
	_sword_swing_pivot.position = Vector3(0.55, 1.15, 0.05)
	add_child(_sword_swing_pivot)

	var grip_tilt := Node3D.new()
	grip_tilt.rotation_degrees = Vector3(0, 0, -72)
	_sword_swing_pivot.add_child(grip_tilt)

	_style(_add_cylinder(Vector3(0, 0.25, 0), Vector3.ZERO, 0.05, 0.06, 0.5, TRUNK_COLOR, grip_tilt), 0.9)
	_style(_add_box(Vector3(0, 0.52, 0), Vector3.ZERO, Vector3(0.5, 0.08, 0.14), CROSSGUARD_COLOR, grip_tilt), 0.35, 0.9)

	var tiers := 5
	var base_y := 0.65
	var tier_h := 0.35
	var tier_step := tier_h * 0.8
	for i in tiers:
		var t: float = float(i) / float(tiers - 1)
		var r: float = lerp(0.58, 0.13, t)
		_style(_add_cylinder(Vector3(0, base_y + i * tier_step, 0), Vector3.ZERO, 0.0, r, tier_h, TREE_GREEN, grip_tilt), 0.9)
		if i < 3:
			var a0: float = TAU * (0.13 + 0.37 * float(i))
			var cap := _add_sphere(Vector3(cos(a0) * r * 0.8, base_y + i * tier_step - tier_h * 0.4, sin(a0) * r * 0.8), 0.07, SNOW_WHITE, grip_tilt)
			cap.scale = Vector3(1.4, 0.5, 1.0)
			_style(cap, 0.92)
	var tip_y: float = base_y + (tiers - 1) * tier_step + tier_h * 0.5
	var star := _add_box(Vector3(0, tip_y, 0), Vector3.ZERO, Vector3(0.17, 0.17, 0.05), STAR_GOLD, grip_tilt)
	var star_mat := star.material_override as StandardMaterial3D
	star_mat.roughness = 0.5
	star_mat.emission_enabled = true
	star_mat.emission = STAR_GOLD
	star_mat.emission_energy_multiplier = 1.5

	var light_count := 6
	for i in light_count:
		var t2: float = (float(i) + 0.5) / float(light_count)
		var y: float = base_y + t2 * (tiers - 1) * tier_step
		var ring_r: float = lerp(0.55, 0.16, t2)
		var a: float = t2 * TAU * 2.0
		var lp := Vector3(cos(a) * ring_r, y, sin(a) * ring_r)
		var light_color: Color = LIGHT_COLORS[i % LIGHT_COLORS.size()]
		var light := _add_sphere(lp, 0.055, light_color, grip_tilt)
		var lmat := StandardMaterial3D.new()
		lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lmat.albedo_color = light_color
		lmat.emission_enabled = true
		lmat.emission = light_color
		lmat.emission_energy_multiplier = 2.0
		light.material_override = lmat
		_bulb_mats.append(lmat)

## The one dedicated boss OmniLight (ART_DIRECTION section 6d): signature
## ice-blue, range 5, energy 1.2, never shadowed (web-export budget).
func _add_boss_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = BOSS_LIGHT_COLOR
	light.omni_range = 5.0
	light.light_energy = 1.2
	light.shadow_enabled = false
	light.position = Vector3(0, 1.7, -0.3)
	add_child(light)

# --- Small primitive-mesh helpers (same pattern as EnemySanta.gd's) --------
## Visual-only material tuning on a just-built part - keeps every _add_*
## call site on the shared helper signatures while applying the roughness/
## metallic conventions from ART_DIRECTION section 4.
func _style(mi: MeshInstance3D, roughness: float, metallic: float = 0.0) -> MeshInstance3D:
	var mat := mi.material_override as StandardMaterial3D
	if mat:
		mat.roughness = roughness
		mat.metallic = metallic
	return mi

## Fur convention: roughness 1.0 + the backlit rim only the yeti is allowed.
func _style_fur(mi: MeshInstance3D) -> MeshInstance3D:
	var mat := mi.material_override as StandardMaterial3D
	if mat:
		mat.roughness = 1.0
		mat.rim_enabled = true
		mat.rim = 0.35
		mat.rim_tint = 0.9
	return mi

## Ice convention: near-mirror roughness, the game's only clearcoat user,
## faint FX_FREEZE emission so icicles read at dusk.
func _style_ice(mi: MeshInstance3D) -> MeshInstance3D:
	var mat := mi.material_override as StandardMaterial3D
	if mat:
		mat.roughness = 0.08
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.6
		mat.clearcoat_roughness = 0.1
		mat.emission_enabled = true
		mat.emission = ICE_COLOR
		mat.emission_energy_multiplier = 0.4
	return mi

func _add_sphere(pos: Vector3, radius: float, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi

func _add_cylinder(pos: Vector3, rot_deg: Vector3, top_radius: float, bottom_radius: float, height: float, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	(parent if parent else self).add_child(mi)
	return mi

func _add_box(pos: Vector3, rot_deg: Vector3, size: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	(parent if parent else self).add_child(mi)
	return mi
