extends "res://scripts/enemies/Enemy.gd"
## Santa Claus, the round-10 boss - the largest enemy in the game. Doesn't
## melee or throw snowballs: his ranged "attack" fires a pulsating red laser
## from each eye at the player's position, dealing a direct hit if they're
## still near the impact point plus leaving a burning AoE patch on the
## ground there (see LaserBeam.gd/BurnPatch.gd). He's also permanently
## wrapped in a swirling snowstorm that follows him everywhere - stand too
## close and it launches you into the air like a tornado (see
## _update_snowstorm below; needs Player.gd's apply_external_velocity,
## since nothing else in this game knocks the player around).
##
## Body/collision/health bar/throw point/shoulder pivots are hand-placed in
## EnemySanta.tscn (throw_point exists only because Enemy.gd's @onready var
## requires it - never actually used since _attack is fully overridden);
## every other part (belt, buckle, beard, face, hat, boots, sleeves) is
## built here in code, same split EnemySnowman.gd uses.

const LASER_BEAM_SCRIPT := preload("res://scripts/effects/LaserBeam.gd")
const BURN_PATCH_SCRIPT := preload("res://scripts/effects/BurnPatch.gd")

const SUIT_TRIM_COLOR := Color(0.95, 0.95, 0.95)
const BELT_COLOR := Color(0.08, 0.08, 0.09)
const BUCKLE_COLOR := Color(0.85, 0.68, 0.15)
const BEARD_COLOR := Color(0.97, 0.97, 0.95)
const SKIN_COLOR := Color(0.87, 0.68, 0.56)
const CHEEK_COLOR := Color(0.93, 0.5, 0.45)
const EYE_COLOR := Color(1.0, 0.1, 0.08)
const SUIT_RED := Color(0.75, 0.08, 0.1)  # hat + sleeves - same red as the torso ($Body, colored via EnemyDB's "color" stat)
const MITTEN_COLOR := Color(0.08, 0.08, 0.09)
const BOOT_COLOR := Color(0.08, 0.08, 0.09)

const BODY_Y := 0.85
const BELT_Y := 0.68
const BELT_RADIUS := 0.56
const HEAD_Y := 1.63
const HEAD_RADIUS := 0.26

const BEAM_HIT_RADIUS := 1.5
const BURN_RADIUS := 2.2
const BURN_DURATION := 3.5
const BURN_DPS_MULT := 0.5  # relative to `damage`, same "derive secondary damage from base damage" pattern EnemySnowman's EXPLOSION_DAMAGE_MULT uses

const STORM_VISUAL_RADIUS := 1.0  # local space - scales up with this node's own `scale` automatically
const STORM_DANGER_RADIUS := 2.7  # world space - NOT affected by `scale`, so it's picked to roughly match the visual ring once scaled
const STORM_LAUNCH_COOLDOWN := 1.1
const STORM_UP_SPEED := 16.0
const STORM_OUT_SPEED := 9.0
const STORM_SPIN_SPEED := 1.4

var _eye_left: MeshInstance3D
var _eye_right: MeshInstance3D
var _eye_left_mat: StandardMaterial3D
var _eye_right_mat: StandardMaterial3D
var _storm_outer: Node3D
var _storm_inner: Node3D
var _storm_launch_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_build_belt()
	_build_beard()
	_build_face()
	_build_hat()
	_build_arms()
	_build_boots()
	_build_snowstorm()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _dead or Game.state != Game.State.PLAYING:
		return
	_update_snowstorm(delta)

# --- Attack: eye lasers + ground burn -----------------------------------
func _attack(player: Node3D) -> void:
	_fire_laser(player)

## Snapshot-aimed, same as every other enemy's ranged attack in this game
## (e.g. Enemy.gd's own _throw_at) - no continuous tracking mid-beam.
## Ground-height assumption: targets y=0.05, matching WaveManager's
## flat-ground pickup placement - there's no terrain raycast here either.
func _fire_laser(player: Node3D) -> void:
	var impact: Vector3 = Vector3(player.global_position.x, 0.05, player.global_position.z)
	for eye in [_eye_left, _eye_right]:
		var beam := Node3D.new()
		beam.set_script(LASER_BEAM_SCRIPT)
		get_tree().current_scene.add_child(beam)
		beam.setup(eye.global_position, impact)
	_pulse_eyes()
	if player.global_position.distance_to(impact) <= BEAM_HIT_RADIUS and player.has_method("take_hit"):
		player.take_hit(damage)
	_spawn_burn_patch(impact)

func _spawn_burn_patch(pos: Vector3) -> void:
	var patch := Node3D.new()
	patch.set_script(BURN_PATCH_SCRIPT)
	get_tree().current_scene.add_child(patch)
	patch.global_position = pos
	patch.setup(BURN_RADIUS, damage * BURN_DPS_MULT, BURN_DURATION)

func _pulse_eyes() -> void:
	for eye_mat in [_eye_left_mat, _eye_right_mat]:
		var tw := create_tween()
		tw.tween_property(eye_mat, "emission_energy_multiplier", 7.0, 0.08)
		tw.tween_property(eye_mat, "emission_energy_multiplier", 2.5, 0.5)

# --- Snowstorm aura: follows him, launches the player if they get close --
func _build_snowstorm() -> void:
	_storm_outer = Node3D.new()
	_storm_outer.name = "StormOuter"
	add_child(_storm_outer)
	_add_storm_ring(_storm_outer, STORM_VISUAL_RADIUS, 14, 0.11, Color(1.0, 1.0, 1.0, 0.75))

	_storm_inner = Node3D.new()
	_storm_inner.name = "StormInner"
	add_child(_storm_inner)
	_add_storm_ring(_storm_inner, STORM_VISUAL_RADIUS * 0.62, 10, 0.075, Color(0.85, 0.93, 1.0, 0.65))

func _add_storm_ring(parent: Node3D, radius: float, count: int, puff_size: float, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	for i in count:
		var a: float = (TAU / count) * i
		var mesh := QuadMesh.new()
		mesh.size = Vector2(puff_size, puff_size)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(a) * radius, randf_range(0.05, 0.65), sin(a) * radius)
		parent.add_child(mi)

func _update_snowstorm(delta: float) -> void:
	_storm_outer.rotate_y(delta * STORM_SPIN_SPEED)
	_storm_inner.rotate_y(-delta * STORM_SPIN_SPEED * 1.6)
	_storm_launch_timer -= delta
	var player := _get_player()
	if player == null:
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	if dist <= STORM_DANGER_RADIUS and _storm_launch_timer <= 0.0:
		_storm_launch_timer = STORM_LAUNCH_COOLDOWN
		_launch_player(player, to_player, dist)

func _launch_player(player: Node3D, to_player: Vector3, dist: float) -> void:
	var out_dir: Vector3 = to_player.normalized() if dist > 0.05 else Vector3.FORWARD
	var impulse: Vector3 = out_dir * STORM_OUT_SPEED + Vector3.UP * STORM_UP_SPEED
	if player.has_method("apply_external_velocity"):
		player.apply_external_velocity(impulse)

# --- Visuals: suit, beard, face, hat, arms, boots -----------------------
func _build_belt() -> void:
	_add_cylinder(Vector3(0, BELT_Y, 0), Vector3.ZERO, BELT_RADIUS, BELT_RADIUS, 0.16, BELT_COLOR)
	_add_box(Vector3(0, BELT_Y, -BELT_RADIUS + 0.02), Vector3.ZERO, Vector3(0.18, 0.13, 0.05), BUCKLE_COLOR)

## Tapered and hanging straight down from the chin to the belly - a
## CylinderMesh's own axis is already local Y, so (unlike EnemySnowman's
## carrot nose, which points sideways and needs a 90-degree rotation) this
## needs no rotation at all.
func _build_beard() -> void:
	var top_y := HEAD_Y - HEAD_RADIUS * 0.75
	var bottom_y := BODY_Y + 0.05
	var height := top_y - bottom_y
	_add_cylinder(Vector3(0, (top_y + bottom_y) * 0.5, -HEAD_RADIUS * 0.7), Vector3.ZERO, 0.23, 0.09, height, BEARD_COLOR)

func _build_face() -> void:
	_add_sphere(Vector3(0, HEAD_Y, 0), HEAD_RADIUS, SKIN_COLOR)
	_add_sphere(Vector3(0, HEAD_Y - 0.02, -HEAD_RADIUS - 0.02), 0.07, CHEEK_COLOR.lightened(0.15))  # nose
	_add_sphere(Vector3(-0.16, HEAD_Y - 0.05, -HEAD_RADIUS + 0.06), 0.06, CHEEK_COLOR)
	_add_sphere(Vector3(0.16, HEAD_Y - 0.05, -HEAD_RADIUS + 0.06), 0.06, CHEEK_COLOR)
	_add_box(Vector3(-0.1, HEAD_Y + 0.11, -HEAD_RADIUS + 0.03), Vector3(0, 0, 10), Vector3(0.09, 0.03, 0.04), BEARD_COLOR)
	_add_box(Vector3(0.1, HEAD_Y + 0.11, -HEAD_RADIUS + 0.03), Vector3(0, 0, -10), Vector3(0.09, 0.03, 0.04), BEARD_COLOR)

	_eye_left = _add_sphere(Vector3(-0.1, HEAD_Y + 0.04, -HEAD_RADIUS - 0.02), 0.05, EYE_COLOR)
	_eye_right = _add_sphere(Vector3(0.1, HEAD_Y + 0.04, -HEAD_RADIUS - 0.02), 0.05, EYE_COLOR)
	_eye_left_mat = _glow_up(_eye_left)
	_eye_right_mat = _glow_up(_eye_right)

## Eyes need to visibly glow even at rest (they're laser emitters) and get
## brighter still when firing (_pulse_eyes) - _add_sphere's material isn't
## emissive by default, so swap each eye's material for one that is and
## hand the material back for _pulse_eyes to animate later.
func _glow_up(mi: MeshInstance3D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = EYE_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = EYE_COLOR
	mat.emission_energy_multiplier = 2.5
	mi.material_override = mat
	return mat

## A floppy Santa hat: the fur trim band stays level around the head (its
## own direct child of the root), while the cone body + pompom hang off a
## single tilted "flop" pivot so they lean together without needing manual
## trig to place the pompom at the tilted cone's actual tip.
func _build_hat() -> void:
	var base_y := HEAD_Y + HEAD_RADIUS * 0.85
	_add_cylinder(Vector3(0, base_y, 0), Vector3.ZERO, HEAD_RADIUS * 1.18, HEAD_RADIUS * 1.18, 0.1, SUIT_TRIM_COLOR)

	var flop := Node3D.new()
	flop.position = Vector3(0, base_y, 0)
	flop.rotation_degrees = Vector3(28, 12, 30)
	add_child(flop)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = HEAD_RADIUS * 1.05
	cone.height = 0.55
	var cone_mi := MeshInstance3D.new()
	cone_mi.mesh = cone
	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = SUIT_RED
	cone_mi.material_override = cone_mat
	cone_mi.position = Vector3(0, 0.275, 0)
	flop.add_child(cone_mi)
	var pompom := SphereMesh.new()
	pompom.radius = 0.09
	pompom.height = 0.18
	var pompom_mi := MeshInstance3D.new()
	pompom_mi.mesh = pompom
	var pompom_mat := StandardMaterial3D.new()
	pompom_mat.albedo_color = SUIT_TRIM_COLOR
	pompom_mi.material_override = pompom_mat
	pompom_mi.position = Vector3(0, 0.56, 0)
	flop.add_child(pompom_mi)

## Sleeve/cuff/mitten hung off the LeftShoulder/RightShoulder pivots that
## are hand-placed in EnemySanta.tscn (not created here) - Enemy.gd's
## @onready left_shoulder/right_shoulder resolve those at _ready() time,
## before this method runs, which is what lets the base run-cycle animation
## (Enemy.gd's _update_animation) swing them automatically. Building the
## pivots themselves here instead would be too late: @onready vars are
## evaluated before this script's _ready() body ever runs, so Enemy.gd
## would never find them and arm-swing would silently do nothing.
func _build_arms() -> void:
	for shoulder in [left_shoulder, right_shoulder]:
		if shoulder == null:
			continue
		_add_cylinder(Vector3(0, -0.28, 0), Vector3.ZERO, 0.13, 0.11, 0.55, SUIT_RED, shoulder)
		_add_cylinder(Vector3(0, -0.52, 0), Vector3.ZERO, 0.135, 0.135, 0.08, SUIT_TRIM_COLOR, shoulder)
		_add_sphere(Vector3(0, -0.62, 0), 0.11, MITTEN_COLOR, shoulder)

func _build_boots() -> void:
	for side in [-1, 1]:
		var mi := _add_sphere(Vector3(0.24 * side, 0.16, -0.05), 0.22, BOOT_COLOR)
		mi.scale = Vector3(1.0, 0.7, 1.3)

# --- Small primitive-mesh helpers (same pattern as EnemySnowman.gd's) ----
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
