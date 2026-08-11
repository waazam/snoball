extends CharacterBody3D
## Third-person player controller: WASD movement relative to facing, mouse
## look, upgradeable multi-jump, upgradeable dash. The primary snowball
## throws automatically at a fixed cadence of 1 every 0.5s - nothing in the
## game speeds this cadence up, by design. Coin pickups add extra snowballs
## instead of throwing the primary faster: those extras fire on their own,
## faster, independent cadence, phase-offset so they land in the gaps
## between primary throws (alternating rather than firing in lockstep with
## it), and each extra always locks onto a different enemy than whatever
## the primary is currently targeting (and than each other), instead of all
## piling onto the same target. Every throw - primary or extra - gets at
## least a baseline homing pull so it tracks its target in flight.

const GRAVITY := 22.0
const MAX_FALL_SPEED := 40.0  # terminal velocity - guards against tunneling through thin colliders
const MOUSE_SENS := 0.0035
const TOUCH_LOOK_SENS := 0.006
const MAX_TOUCH_DRAG_STEP := 120.0  # px/event; guards against touch-index reuse glitches
const PITCH_MIN := -0.7   # ~-40 deg
const PITCH_MAX := 1.2    # ~70 deg
const DASH_SPEED := 22.0
const DASH_TIME := 0.18
const SPRINT_MULT := 1.35
const SNOWBALL_SCENE_PATH := "res://scenes/weapons/Snowball.tscn"
const AUTO_THROW_INTERVAL := 0.5  # fixed: 1 primary snowball every 0.5s, always - nothing speeds this up
const EXTRA_THROW_INTERVAL := 0.35  # extra (proj_count) snowballs fire on their own, faster cadence
const AUTO_LOCK_HOMING := 3.0
const TARGET_SEARCH_RADIUS := 45.0
const LOOK_ZONE_MIN_X_RATIO := 0.6  # only the right side of the screen can ever start a look-drag

# CharacterRigged.glb (see Model below) has a real Skeleton3D - 15 bones,
# but auto-named by the export ("Bone", "Bone.002", ...) with no semantic
# names to go by. Bone indices below were identified from the model's rest
# pose (position + parent/child structure), not guessed: two root bones at
# the hip - one fans out to a head bone and two arm chains (shoulder/elbow/
# wrist), the other fans out to two leg chains (hip/knee/ankle).
const BONE_ARM_POS_X := 2   # shoulder, arm resting toward +X
const BONE_ARM_NEG_X := 5   # shoulder, arm resting toward -X (mirror)
const BONE_LEG_NEG_X := 9   # hip, leg resting toward -X
const BONE_LEG_POS_X := 12  # hip, leg resting toward +X (mirror)

# Legs rest pointing straight down (local -Y), so rotating a leg bone
# around the character's own X axis sweeps it forward/back - the same
# relationship RunAnim's old hip pivots relied on, just derived here from
# the bone's actual rest orientation instead of assumed. Arms, though,
# rest in a T-pose (straight out to the sides along X) rather than hanging
# down - swinging them around X wouldn't visibly move them at all (X is
# their own long axis), and getting a T-pose arm to swing forward/back
# needs a different axis than getting it to hang down in the first place.
# Rather than stack two unverified guesses, arms only get the one-time
# T-pose -> hanging-down correction (_ready()) and no dynamic swing.
const LEG_SWING_AXIS := Vector3(1, 0, 0)
const ARM_DROP_AXIS := Vector3(0, 0, 1)
const ARM_DROP_ANGLE := PI / 2.0

const RUN_BOB_HEIGHT := 0.05
const AIR_STRETCH := Vector3(0.94, 1.1, 0.94)
const LAND_SQUASH := Vector3(1.16, 0.82, 1.16)

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var model: Node3D = $Model
@onready var skeleton: Skeleton3D = $Model/Armature/Skeleton3D
@onready var left_shoulder: Node3D = $LeftShoulder
@onready var right_shoulder: Node3D = $RightShoulder
@onready var left_hip: Node3D = $LeftHip
@onready var right_hip: Node3D = $RightHip
@onready var throw_point: Marker3D = $RightShoulder/ThrowPoint
@onready var hat_anchor: Node3D = $HatAnchor
@onready var level_label: Label3D = $LevelLabel

var jumps_used: int = 0
var _throw_timer: float = 0.0
var _extra_throw_timer: float = 0.0

# Captured in _ready() (rather than hardcoded) so the bob/squash below
# blends around whatever position/scale Model was actually authored with
# in Player.tscn, instead of fighting it.
var _model_base_position: Vector3 = Vector3.ZERO
var _model_base_scale: Vector3 = Vector3.ONE
var _was_on_floor: bool = true
var _land_squash_tween: Tween = null

# bone_idx -> Basis, captured once in _ready() - see _bone_world_rotation().
var _bone_rest_basis: Dictionary = {}
# bone_idx -> float (radians) - the smoothed, currently-applied swing angle
# per bone, so the walk cycle eases in/out instead of snapping.
var _bone_current_angle: Dictionary = {}

var dash_charges_left: int = 1
var dash_recharge_timer: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO

var _anim_time: float = 0.0
var _is_throwing: bool = false
var _throw_tween: Tween = null

# Camera-look owns exactly one finger at a time, and only ever trusts drag
# events for the index it personally saw touch down. This is what stops a
# second finger (e.g. the movement joystick) from ever being able to yank
# the camera: without this, a browser reassigning/reusing a touch index
# mid-multitouch can hand us a drag "relative" that's really a jump between
# two different fingers' positions, which reads as the camera snapping/
# resetting. MAX_TOUCH_DRAG_STEP below is a second line of defense that
# clamps any single-event delta that's still suspiciously large.
var _look_touch_index: int = -1

func _ready() -> void:
	add_to_group("player")
	_model_base_position = model.position
	_model_base_scale = model.scale
	_setup_skeleton()
	dash_charges_left = Game.get_dash_charges()
	_throw_timer = AUTO_THROW_INTERVAL
	# Half-interval head start so the first extra volley lands between the
	# first two primary throws instead of on top of the first one.
	_extra_throw_timer = EXTRA_THROW_INTERVAL / 2.0
	Game.hat_equipped.connect(_on_hat_equipped)
	# Bare-headed by default - a hat only appears once one is actually picked
	# up (Game.equipped_hat starts as "" on every fresh run).
	if Game.equipped_hat != "":
		_on_hat_equipped(Game.equipped_hat)
	Game.kills_changed.connect(_on_kills_changed_update_level)
	_on_kills_changed_update_level(Game.kills)

## Captures each animated bone's rest orientation (needed by
## _bone_world_basis below).
func _setup_skeleton() -> void:
	for idx in [BONE_ARM_POS_X, BONE_ARM_NEG_X, BONE_LEG_NEG_X, BONE_LEG_POS_X]:
		_bone_rest_basis[idx] = skeleton.get_bone_global_rest(idx).basis

## Converts a rotation expressed in the character's own world/local space
## into the correct LOCAL bone-pose rotation for `bone_idx`, using that
## bone's captured rest orientation. Necessary because this rig's bones
## don't share one common local-axis convention (an arm bone's local X
## isn't guaranteed to point the same way a leg bone's local X does), so a
## plain "rotate around local X" would swing different limbs in different,
## possibly wrong, directions. Skeleton3D sits directly under Model with
## no rotation of its own, so "world" here means Model/character-local
## space, matching how the old simple pivot-node rig's rotation.x worked.
func _bone_world_basis(bone_idx: int, world_basis: Basis) -> Quaternion:
	var rest_basis: Basis = _bone_rest_basis.get(bone_idx, Basis.IDENTITY)
	var pose_basis: Basis = rest_basis.inverse() * world_basis * rest_basis
	return pose_basis.get_rotation_quaternion()

func _bone_world_rotation(bone_idx: int, world_axis: Vector3, angle: float) -> Quaternion:
	return _bone_world_basis(bone_idx, Basis(world_axis, angle))

## Smoothly eases bone_idx's swing angle toward target_angle (lerp_angle,
## same easing style the old rig used) and applies it via
## _bone_world_rotation so it swings correctly regardless of this bone's
## particular rest orientation. For legs, which already rest pointing
## straight down.
func _apply_bone_swing(bone_idx: int, target_angle: float, world_axis: Vector3, blend: float) -> void:
	var current: float = lerp_angle(_bone_current_angle.get(bone_idx, 0.0), target_angle, blend)
	_bone_current_angle[bone_idx] = current
	skeleton.set_bone_pose_rotation(bone_idx, _bone_world_rotation(bone_idx, world_axis, current))

## Arms need two rotations composed together every frame, not just one:
## first the constant T-pose -> hanging-down correction (drop_angle, around
## ARM_DROP_AXIS), then the walk swing on top of THAT already-dropped
## orientation (around LEG_SWING_AXIS, same axis as legs - once dropped,
## an arm hangs down just like a leg does, so the same "swing forward/back"
## axis applies). Composed as world_basis = swing * drop so drop is
## applied first/innermost.
func _apply_arm_swing(bone_idx: int, drop_angle: float, target_swing: float, blend: float) -> void:
	var current: float = lerp_angle(_bone_current_angle.get(bone_idx, 0.0), target_swing, blend)
	_bone_current_angle[bone_idx] = current
	var world_basis: Basis = Basis(LEG_SWING_AXIS, current) * Basis(ARM_DROP_AXIS, drop_angle)
	skeleton.set_bone_pose_rotation(bone_idx, _bone_world_basis(bone_idx, world_basis))

func _on_hat_equipped(hat_id: String) -> void:
	for c in hat_anchor.get_children():
		c.queue_free()
	var data: Dictionary = HatDB.get_data(hat_id)
	var visual: Node3D = HatVisuals.build(data.get("shape", "top_hat"), data.get("color", Color(0.8, 0.1, 0.12)))
	hat_anchor.add_child(visual)
	visual.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.3, 1.3, 1.3), 0.1)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.15)

## Mirrors the HUD's XP bar (same Game.get_level(), 1 kill = 1 exp,
## EXP_PER_LEVEL kills per level) as a floating billboarded label over the
## player's own head.
func _on_kills_changed_update_level(_kills: int) -> void:
	level_label.text = "Lv %d" % Game.get_level()

func _unhandled_input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative, MOUSE_SENS)
	elif event is InputEventScreenTouch:
		_handle_look_touch(event)
	elif event is InputEventScreenDrag:
		# Only reaches here if no touch UI control (joystick/button) claimed
		# this finger first. Still ignore it unless it's the one finger we
		# already registered as the look-finger via _handle_look_touch.
		if event.index == _look_touch_index:
			var rel: Vector2 = event.relative
			if rel.length() > MAX_TOUCH_DRAG_STEP:
				rel = rel.normalized() * MAX_TOUCH_DRAG_STEP
			_apply_look(rel, TOUCH_LOOK_SENS)

func _handle_look_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Positional guard, not just "wasn't claimed by something else": a
		# touch can only ever become the look-finger if it starts on the
		# right side of the screen. Without this, a movement thumb that
		# ever slips off the joystick's exact hit-region for a single frame
		# (extremely common - thumbs shift constantly during a hold) would
		# get misclassified as the look-finger, and its next drag would
		# yank the camera. This makes that class of bug impossible instead
		# of just less likely.
		if _look_touch_index == -1 and _is_in_look_zone(event.position):
			_look_touch_index = event.index
	elif event.index == _look_touch_index:
		_look_touch_index = -1

func _is_in_look_zone(screen_pos: Vector2) -> bool:
	var vp_width: float = get_viewport().get_visible_rect().size.x
	return screen_pos.x >= vp_width * LOOK_ZONE_MIN_X_RATIO

func _apply_look(relative: Vector2, sens: float) -> void:
	rotate_y(-relative.x * sens)
	var pitch: float = spring_arm.rotation.x - relative.y * sens
	spring_arm.rotation.x = clampf(pitch, PITCH_MIN, PITCH_MAX)

func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		return
	_handle_gravity_and_jump(delta)
	_handle_dash(delta)
	_handle_movement(delta)
	_handle_auto_throw(delta)
	_update_animation(delta)
	move_and_slide()
	_update_landing_squash()

func take_hit(amount: float) -> void:
	Game.take_damage(amount)

# --- Procedural animation ---------------------------------------------------
# LeftHip/RightHip/LeftShoulder still exist (Player.tscn keeps them as
# empty pivots so these @onready refs don't fail) but no longer drive any
# visible mesh - real leg animation now runs on CharacterRigged.glb's own
# Skeleton3D bones instead (see BONE_*/_apply_bone_swing above).
func _update_animation(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = horizontal_speed > 0.4 and is_on_floor() and not is_dashing
	var target_amp: float = 0.0
	if moving:
		var speed_ratio: float = clampf(horizontal_speed / max(Game.get_move_speed(), 1.0), 0.4, 2.0)
		_anim_time += delta * 9.0 * speed_ratio
		target_amp = 0.85
	var blend: float = clampf(delta * 12.0, 0.0, 1.0)

	# Legs and arms swing opposite each other on the same side (same
	# relative pattern and tuned amplitudes the old simple pivot rig used
	# for left_hip/left_shoulder etc.) - when the -X leg swings forward the
	# -X arm swings back, and vice versa. (Previously suspected as the
	# cause of a floor/object-clipping report and disabled - the actual
	# cause turned out to be a static mesh/skeleton offset mismatch in
	# Model's own position, unrelated to this and fixed there instead, so
	# this is back on.)
	var swing: float = sin(_anim_time) * target_amp
	_apply_bone_swing(BONE_LEG_NEG_X, swing * 0.7, LEG_SWING_AXIS, blend)
	_apply_bone_swing(BONE_LEG_POS_X, -swing * 0.7, LEG_SWING_AXIS, blend)
	_apply_arm_swing(BONE_ARM_NEG_X, ARM_DROP_ANGLE, -swing * 0.6, blend)
	_apply_arm_swing(BONE_ARM_POS_X, -ARM_DROP_ANGLE, swing * 0.6, blend)

	# A small double-bounce bob (2 bounces per stride, one per footfall),
	# fading in/out with target_amp so the model eases to a dead stop
	# instead of snapping when you stop moving.
	var bob: float = absf(sin(_anim_time * 2.0)) * RUN_BOB_HEIGHT * target_amp
	model.position.y = lerpf(model.position.y, _model_base_position.y + bob, blend)

	# Airborne stretch - skipped while a landing squash tween owns the scale
	# (see _update_landing_squash below), and skipped while grounded so it
	# doesn't fight that tween's own settle-back-to-base leg.
	if not is_on_floor() and (_land_squash_tween == null or not _land_squash_tween.is_valid()):
		model.scale = model.scale.lerp(_model_base_scale * AIR_STRETCH, blend)

## Bouncy squash-then-recover pulse the instant the player lands, same
## technique as Enemy.gd's hit-reaction squash. Checked after move_and_slide()
## since that's what actually updates is_on_floor() for this frame.
func _update_landing_squash() -> void:
	var on_floor: bool = is_on_floor()
	if on_floor and not _was_on_floor:
		if _land_squash_tween and _land_squash_tween.is_valid():
			_land_squash_tween.kill()
		model.scale = _model_base_scale * LAND_SQUASH
		_land_squash_tween = create_tween()
		_land_squash_tween.tween_property(model, "scale", _model_base_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_was_on_floor = on_floor

func _play_throw_animation() -> void:
	if _throw_tween and _throw_tween.is_valid():
		_throw_tween.kill()
	_is_throwing = true
	right_shoulder.rotation.x = -1.3
	_throw_tween = create_tween()
	_throw_tween.tween_property(right_shoulder, "rotation:x", 0.9, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_throw_tween.tween_property(right_shoulder, "rotation:x", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_throw_tween.finished.connect(_on_throw_anim_finished)

func _on_throw_anim_finished() -> void:
	_is_throwing = false

# --- Movement --------------------------------------------------------------
func _get_wish_dir() -> Vector3:
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		dir -= transform.basis.z
	if Input.is_action_pressed("move_back"):
		dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		dir += transform.basis.x
	dir.y = 0.0
	if dir.length() > 0.001:
		dir = dir.normalized()
	return dir

func _handle_movement(delta: float) -> void:
	if is_dashing:
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
		return
	var wish := _get_wish_dir()
	var speed := Game.get_move_speed()
	if Input.is_action_pressed("sprint") and wish.length() > 0.01:
		speed *= SPRINT_MULT
	var target := wish * speed
	if is_on_floor():
		velocity.x = target.x
		velocity.z = target.z
	else:
		var accel: float = 5.0 * Game.get_air_control_mult()
		velocity.x = move_toward(velocity.x, target.x, accel * delta * max(speed, 1.0))
		velocity.z = move_toward(velocity.z, target.z, accel * delta * max(speed, 1.0))

func _handle_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		# Terminal velocity: uncapped fall speed risks tunneling straight
		# through the ground's collision shape on a frame-rate hitch (a big
		# single-frame position delta can skip past a thin collider).
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)
	else:
		if velocity.y < 0.0:
			velocity.y = -1.0
		jumps_used = 0
	if Input.is_action_just_pressed("jump"):
		var max_jumps := Game.get_max_jumps()
		if jumps_used < max_jumps:
			velocity.y = Game.get_jump_velocity()
			jumps_used += 1

func _handle_dash(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	var max_charges := Game.get_dash_charges()
	if dash_charges_left < max_charges:
		dash_recharge_timer += delta
		if dash_recharge_timer >= Game.get_dash_cooldown():
			dash_recharge_timer = 0.0
			dash_charges_left += 1
	if Game.dash_unlocked and Input.is_action_just_pressed("dash") and not is_dashing and dash_charges_left > 0:
		var dir := _get_wish_dir()
		if dir.length() < 0.01:
			dir = -transform.basis.z
		dash_dir = dir.normalized()
		is_dashing = true
		dash_timer = DASH_TIME
		dash_charges_left -= 1
		velocity.y = max(velocity.y, 0.0)

# --- Throwing (automatic, fixed cadence, auto-lock on nearest enemy) -----
# The primary is a hard-fixed 1 throw per 0.5s - nothing in the game (kills,
# upgrades, pickups) is allowed to change that. The projectile COUNT from
# coins instead spawns extra throws on their own separate, faster timer
# (EXTRA_THROW_INTERVAL), phase-started at a half-interval offset so they
# land in the gaps between primary throws rather than firing alongside
# them. Per-projectile speed/damage still scale with upgrades either way.
func _handle_auto_throw(delta: float) -> void:
	_throw_timer -= delta
	if _throw_timer <= 0.0:
		_throw_snowball()
		_throw_timer = AUTO_THROW_INTERVAL
	_extra_throw_timer -= delta
	if _extra_throw_timer <= 0.0:
		_throw_extra_snowballs()
		_extra_throw_timer = EXTRA_THROW_INTERVAL

## The primary throw: always exactly 1 snowball, always at the single
## nearest enemy.
func _throw_snowball() -> void:
	var target: Node3D = _find_nearest_enemy()
	if target == null:
		return
	_play_throw_animation()
	var dir: Vector3 = (target.global_position + Vector3.UP - throw_point.global_position).normalized()
	_spawn_snowball(dir, _current_throw_stats(), SnowballDB.get_color(Game.current_snowball_type))

## The extra (proj_count) throws: fire together on their own cadence, each
## locked onto a different enemy than the current primary target and than
## each other, instead of piling onto/fanning around one target. Gracefully
## throws fewer than the full count if there aren't enough distinct enemies
## in range.
func _throw_extra_snowballs() -> void:
	var extra_count: int = Game.get_projectile_count() - 1
	if extra_count <= 0:
		return
	var exclude: Array = []
	var primary_target: Node3D = _find_nearest_enemy()
	if primary_target != null:
		exclude.append(primary_target)
	var targets: Array = _find_nearest_enemies(extra_count, exclude)
	if targets.is_empty():
		return
	_play_throw_animation()
	var stats: Dictionary = _current_throw_stats()
	var color: Color = SnowballDB.get_color(Game.current_snowball_type)
	for target in targets:
		var dir: Vector3 = (target.global_position + Vector3.UP - throw_point.global_position).normalized()
		_spawn_snowball(dir, stats, color)

func _current_throw_stats() -> Dictionary:
	var stats: Dictionary = SnowballDB.get_stats(Game.current_snowball_type).duplicate()
	var power: float = Game.get_throw_power_mult()
	stats["damage"] = stats.get("damage", 10.0) * power
	stats["speed"] = stats.get("speed", 30.0) * power * Game.get_projectile_speed_mult()
	# Every throw gets at least a baseline auto-lock pull, on top of
	# whatever homing the current snowball type already has via maxf.
	stats["homing"] = maxf(stats.get("homing", 0.0), AUTO_LOCK_HOMING)
	return stats

func _spawn_snowball(dir: Vector3, stats: Dictionary, color: Color) -> void:
	var scene: PackedScene = load(SNOWBALL_SCENE_PATH)
	var sb: Area3D = scene.instantiate()
	get_tree().current_scene.add_child(sb)
	sb.global_position = throw_point.global_position
	sb.setup(dir, stats, true, color, false, Game.current_snowball_type)

## Up to n nearest enemies (within TARGET_SEARCH_RADIUS), skipping anything
## in `exclude` - used to give each extra projectile its own distinct
## target instead of stacking on the primary's.
func _find_nearest_enemies(n: int, exclude: Array = []) -> Array:
	var candidates: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e in exclude:
			continue
		var d: float = throw_point.global_position.distance_to(e.global_position)
		if d < TARGET_SEARCH_RADIUS:
			candidates.append({"node": e, "dist": d})
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var result: Array = []
	for i in range(mini(n, candidates.size())):
		result.append(candidates[i]["node"])
	return result

func _find_nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist: float = TARGET_SEARCH_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = throw_point.global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best
