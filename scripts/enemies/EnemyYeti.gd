extends "res://scripts/enemies/Enemy.gd"
## The Yeti, the round-15 boss - the largest enemy in the game, and the only
## one that spawns that wave (see EnemyDB.get_wave_composition). Melee-only:
## every attack_cooldown (3s) he swings his sword in a wide horizontal arc,
## hitting the player for `damage` if they're still in range and applying a
## heavy bleed on top (see Game.apply_bleed - the player has no per-actor
## status-effect script of its own like enemies do, so that lives on Game).
## On death he drops his sword as a real pickup (SwordPickup.tscn) that
## re-equips the player onto SnowballDB's "yeti_sword" type, replacing
## whatever snowball they had - same "equip and stay" mechanic every present
## pickup uses (see PresentPickup.gd/Game.equip_snowball), just triggered
## from a boss kill instead of a wave-start present.
##
## Body/collision/health bar are hand-placed in EnemyYeti.tscn (same split
## every other boss uses); fur, face, arms and the wielded sword are all
## built here in code, same procedural-detail approach as EnemySanta.gd/
## EnemySnowman.gd. The sword hangs off its own dedicated pivot (NOT the
## LeftShoulder/RightShoulder names Enemy.gd's base run-cycle animation
## looks for) specifically so the attack-swing tween below never fights the
## base class's walk-cycle arm swing over the same rotation property.

const SWORD_PICKUP_SCENE_PATH := "res://scenes/pickups/SwordPickup.tscn"

const FUR_COLOR := Color(0.96, 0.97, 1.0)  # matches EnemyDB's "color" stat, applied to $Body by Enemy.gd - repeated here for the hand-built parts
const FUR_SHADOW_COLOR := Color(0.8, 0.84, 0.92)
const CLAW_COLOR := Color(0.16, 0.16, 0.2)
const NOSE_COLOR := Color(0.12, 0.12, 0.15)
const BROW_COLOR := Color(0.65, 0.68, 0.78)
const EYE_COLOR := Color(0.25, 0.65, 1.0)

const TRUNK_COLOR := Color(0.4, 0.26, 0.12)
const CROSSGUARD_COLOR := Color(0.85, 0.68, 0.2)
const TREE_GREEN := Color(0.1, 0.45, 0.18)
const STAR_GOLD := Color(0.95, 0.8, 0.25)
const LIGHT_COLORS := [Color(0.9, 0.15, 0.15), Color(0.2, 0.55, 0.95), Color(0.95, 0.85, 0.2), Color(0.3, 0.85, 0.4)]

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

func _ready() -> void:
	super._ready()
	_build_face()
	_build_fur_tufts()
	_build_arms()
	_build_sword()

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

# --- Visuals: face, fur, arms, sword ---------------------------------------
func _build_face() -> void:
	_add_sphere(Vector3(0, HEAD_Y, 0), HEAD_RADIUS, FUR_COLOR)
	_add_sphere(Vector3(0, HEAD_Y - HEAD_RADIUS * 0.35, -HEAD_RADIUS * 0.85), HEAD_RADIUS * 0.4, FUR_SHADOW_COLOR)  # muzzle
	_add_sphere(Vector3(0, HEAD_Y - HEAD_RADIUS * 0.4, -HEAD_RADIUS * 1.15), 0.06, NOSE_COLOR)

	_add_box(Vector3(-0.13, HEAD_Y + 0.1, -HEAD_RADIUS * 0.75), Vector3(0, 0, 12), Vector3(0.13, 0.035, 0.05), BROW_COLOR)
	_add_box(Vector3(0.13, HEAD_Y + 0.1, -HEAD_RADIUS * 0.75), Vector3(0, 0, -12), Vector3(0.13, 0.035, 0.05), BROW_COLOR)

	var eye_left: MeshInstance3D = _add_sphere(Vector3(-0.13, HEAD_Y + 0.02, -HEAD_RADIUS * 0.92), 0.055, EYE_COLOR)
	var eye_right: MeshInstance3D = _add_sphere(Vector3(0.13, HEAD_Y + 0.02, -HEAD_RADIUS * 0.92), 0.055, EYE_COLOR)
	_eye_left_mat = _glow_up(eye_left)
	_eye_right_mat = _glow_up(eye_right)

	for side in [-1, 1]:
		_add_sphere(Vector3(0.22 * side, HEAD_Y + 0.28, -0.02), HEAD_RADIUS * 0.28, FUR_COLOR)  # ears

## Eyes glow blue at rest, same "swap for an emissive material" trick
## EnemySanta.gd's _glow_up uses for his red laser eyes.
func _glow_up(mi: MeshInstance3D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = EYE_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = EYE_COLOR
	mat.emission_energy_multiplier = 3.0
	mi.material_override = mat
	return mat

## Small spike tufts scattered over the shoulders/back/head for a shaggy-fur
## read - same golden-angle spiral distribution + outward-facing Basis
## construction SnowballVisuals._build_studded uses for gravel/nail/stick
## studs (avoids look_at's degenerate case when a normal points straight up).
func _build_fur_tufts() -> void:
	var count := 18
	for i in count:
		var t: float = (float(i) + 0.5) / float(count)
		var phi: float = acos(1.0 - 2.0 * t) * 0.6  # upper hemisphere-ish only, so tufts don't poke out the belly
		var theta: float = PI * (1.0 + sqrt(5.0)) * i
		var normal := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
		var pos: Vector3 = Vector3(0, BODY_Y, 0) + normal * BODY_RADIUS * 0.95
		var tuft := _add_cylinder(pos, Vector3.ZERO, 0.0, 0.05, 0.22, FUR_SHADOW_COLOR)
		var arbitrary: Vector3 = Vector3.RIGHT if absf(normal.y) < 0.9 else Vector3.FORWARD
		var x_axis: Vector3 = arbitrary.cross(normal).normalized()
		var z_axis: Vector3 = normal.cross(x_axis).normalized()
		tuft.transform.basis = Basis(x_axis, normal, z_axis)

func _build_arms() -> void:
	for side in [-1, 1]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.52 * side, 1.3, 0)
		add_child(shoulder)
		_add_cylinder(Vector3(0, -0.32, 0), Vector3.ZERO, 0.19, 0.15, 0.62, FUR_COLOR, shoulder)
		_add_cylinder(Vector3(0, -0.62, 0), Vector3.ZERO, 0.13, 0.16, 0.06, FUR_SHADOW_COLOR, shoulder)
		_add_sphere(Vector3(0, -0.72, 0), 0.14, FUR_COLOR, shoulder)
		for j in 3:
			_add_cylinder(Vector3((j - 1) * 0.06, -0.85, -0.02), Vector3(20, 0, 0), 0.0, 0.02, 0.12, CLAW_COLOR, shoulder)

## The wielded sword: a SwingPivot at the shoulder (this is what the attack
## tween rotates - a plain world-Y yaw at the shoulder sweeps everything
## attached, including the blade's own resting tilt, through a wide
## horizontal arc), holding a GripTilt that angles the blade out and down
## into a natural "held ready" pose. Deliberately not parented under any
## node Enemy.gd's base animation drives (see file header comment).
func _build_sword() -> void:
	_sword_swing_pivot = Node3D.new()
	_sword_swing_pivot.position = Vector3(0.55, 1.15, 0.05)
	add_child(_sword_swing_pivot)

	var grip_tilt := Node3D.new()
	grip_tilt.rotation_degrees = Vector3(0, 0, -72)
	_sword_swing_pivot.add_child(grip_tilt)

	_add_cylinder(Vector3(0, 0.25, 0), Vector3.ZERO, 0.05, 0.06, 0.5, TRUNK_COLOR, grip_tilt)
	_add_box(Vector3(0, 0.52, 0), Vector3.ZERO, Vector3(0.5, 0.08, 0.14), CROSSGUARD_COLOR, grip_tilt)

	var tiers := 5
	var base_y := 0.65
	var tier_h := 0.35
	var tier_step := tier_h * 0.8
	for i in tiers:
		var t: float = float(i) / float(tiers - 1)
		var r: float = lerp(0.55, 0.12, t)
		_add_cylinder(Vector3(0, base_y + i * tier_step, 0), Vector3.ZERO, 0.0, r, tier_h, TREE_GREEN, grip_tilt)
	var tip_y: float = base_y + (tiers - 1) * tier_step + tier_h * 0.5
	_add_box(Vector3(0, tip_y, 0), Vector3.ZERO, Vector3(0.16, 0.16, 0.05), STAR_GOLD, grip_tilt)

	var light_count := 16
	for i in light_count:
		var t2: float = (float(i) + 0.5) / float(light_count)
		var y: float = base_y + t2 * (tiers - 1) * tier_step
		var ring_r: float = lerp(0.53, 0.15, t2)
		var a: float = t2 * TAU * 3.0
		var lp := Vector3(cos(a) * ring_r, y, sin(a) * ring_r)
		var light_color: Color = LIGHT_COLORS[i % LIGHT_COLORS.size()]
		var light := _add_sphere(lp, 0.045, light_color, grip_tilt)
		var lmat := StandardMaterial3D.new()
		lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lmat.albedo_color = light_color
		lmat.emission_enabled = true
		lmat.emission = light_color
		lmat.emission_energy_multiplier = 2.2
		light.material_override = lmat

# --- Small primitive-mesh helpers (same pattern as EnemySanta.gd's) --------
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
