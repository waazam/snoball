extends CharacterBody3D
## Third-person player controller: WASD movement relative to facing, mouse
## look, upgradeable multi-jump, upgradeable dash, and snowball throwing
## aimed via a screen-center raycast from the camera.

const GRAVITY := 22.0
const MOUSE_SENS := 0.0035
const PITCH_MIN := -0.7   # ~-40 deg
const PITCH_MAX := 1.2    # ~70 deg
const DASH_SPEED := 22.0
const DASH_TIME := 0.18
const SPRINT_MULT := 1.35
const SNOWBALL_SCENE_PATH := "res://scenes/weapons/Snowball.tscn"

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var left_shoulder: Node3D = $LeftShoulder
@onready var right_shoulder: Node3D = $RightShoulder
@onready var left_hip: Node3D = $LeftHip
@onready var right_hip: Node3D = $RightHip
@onready var throw_point: Marker3D = $RightShoulder/ThrowPoint

var jumps_used: int = 0
var throw_cooldown_left: float = 0.0

var dash_charges_left: int = 1
var dash_recharge_timer: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO

var _anim_time: float = 0.0
var _is_throwing: bool = false
var _throw_tween: Tween = null

func _ready() -> void:
	add_to_group("player")
	dash_charges_left = Game.get_dash_charges()

func _unhandled_input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		var pitch: float = spring_arm.rotation.x - event.relative.y * MOUSE_SENS
		spring_arm.rotation.x = clampf(pitch, PITCH_MIN, PITCH_MAX)

func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		return
	_handle_gravity_and_jump(delta)
	_handle_dash(delta)
	_handle_movement(delta)
	_handle_throw(delta)
	_update_animation(delta)
	move_and_slide()

func take_hit(amount: float) -> void:
	Game.take_damage(amount)

# --- Procedural stick-figure animation -------------------------------------
func _update_animation(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = horizontal_speed > 0.4 and is_on_floor() and not is_dashing
	var target_amp: float = 0.0
	if moving:
		var speed_ratio: float = clampf(horizontal_speed / max(Game.get_move_speed(), 1.0), 0.4, 2.0)
		_anim_time += delta * 9.0 * speed_ratio
		target_amp = 0.85
	var swing: float = sin(_anim_time) * target_amp
	var blend: float = clampf(delta * 12.0, 0.0, 1.0)
	left_hip.rotation.x = lerp_angle(left_hip.rotation.x, swing * 0.7, blend)
	right_hip.rotation.x = lerp_angle(right_hip.rotation.x, -swing * 0.7, blend)
	left_shoulder.rotation.x = lerp_angle(left_shoulder.rotation.x, -swing * 0.6, blend)
	if not _is_throwing:
		right_shoulder.rotation.x = lerp_angle(right_shoulder.rotation.x, swing * 0.6, blend)

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
		velocity.y -= GRAVITY * delta
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

# --- Throwing ----------------------------------------------------------
func _handle_throw(delta: float) -> void:
	throw_cooldown_left = max(0.0, throw_cooldown_left - delta)
	_handle_weapon_switch()
	if Input.is_action_pressed("throw") and throw_cooldown_left <= 0.0:
		_throw_snowball()

func _handle_weapon_switch() -> void:
	if Input.is_action_just_pressed("weapon_next"):
		Game.cycle_weapon(1)
	if Input.is_action_just_pressed("weapon_prev"):
		Game.cycle_weapon(-1)
	var ids: Array = Game.unlocked_weapons.keys()
	ids.sort()
	for i in range(1, 7):
		if Input.is_action_just_pressed("weapon_%d" % i) and i - 1 < ids.size():
			Game.set_current_weapon(ids[i - 1])

func _throw_snowball() -> void:
	_play_throw_animation()
	var id: String = Game.current_weapon
	var tier: int = Game.unlocked_weapons.get(id, 1)
	var stats: Dictionary = SnowballDB.get_stats(id, tier).duplicate()
	var power: float = Game.get_throw_power_mult()
	stats["damage"] = stats.get("damage", 10.0) * power
	stats["speed"] = stats.get("speed", 30.0) * power
	throw_cooldown_left = stats.get("cooldown", 0.4) * Game.get_fire_rate_mult()
	var dir: Vector3 = _get_aim_direction()
	var scene: PackedScene = load(SNOWBALL_SCENE_PATH)
	var sb: Area3D = scene.instantiate()
	get_tree().current_scene.add_child(sb)
	sb.global_position = throw_point.global_position
	sb.setup(dir, stats, true, SnowballDB.get_color(id))

func _get_aim_direction() -> Vector3:
	var vp := get_viewport()
	var center: Vector2 = Vector2(vp.get_visible_rect().size) * 0.5
	var from: Vector3 = camera.project_ray_origin(center)
	var to: Vector3 = from + camera.project_ray_normal(center) * 250.0
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 4
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	var target_point: Vector3 = to
	if result:
		target_point = result.position
	var dir: Vector3 = target_point - throw_point.global_position
	if dir.length() < 0.01:
		dir = -transform.basis.z
	return dir.normalized()
