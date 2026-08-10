extends CharacterBody3D
## Third-person player controller: WASD movement relative to facing, mouse
## look, upgradeable multi-jump, upgradeable dash. Throwing is automatic at
## a fixed cadence of 1 snowball every 0.5s - nothing in the game speeds
## this cadence up, by design. Every throw auto-locks onto the nearest
## enemy, and every snowball gets at least a baseline homing pull so it
## tracks its target in flight. Coin pickups add extra snowballs per throw
## (fanned out around the main target) instead of throwing faster.

const GRAVITY := 22.0
const MOUSE_SENS := 0.0035
const TOUCH_LOOK_SENS := 0.006
const MAX_TOUCH_DRAG_STEP := 120.0  # px/event; guards against touch-index reuse glitches
const PITCH_MIN := -0.7   # ~-40 deg
const PITCH_MAX := 1.2    # ~70 deg
const DASH_SPEED := 22.0
const DASH_TIME := 0.18
const SPRINT_MULT := 1.35
const SNOWBALL_SCENE_PATH := "res://scenes/weapons/Snowball.tscn"
const AUTO_THROW_INTERVAL := 0.5  # fixed: 1 snowball every 0.5s, always - nothing speeds this up
const AUTO_LOCK_HOMING := 3.0
const TARGET_SEARCH_RADIUS := 45.0
const MULTISHOT_SPREAD_DEG := 9.0  # angle between fanned-out extra projectiles

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var left_shoulder: Node3D = $LeftShoulder
@onready var right_shoulder: Node3D = $RightShoulder
@onready var left_hip: Node3D = $LeftHip
@onready var right_hip: Node3D = $RightHip
@onready var throw_point: Marker3D = $RightShoulder/ThrowPoint
@onready var hat_mesh: MeshInstance3D = $Hat

var _hat_material: StandardMaterial3D

var jumps_used: int = 0
var _throw_timer: float = 0.0

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
	dash_charges_left = Game.get_dash_charges()
	_throw_timer = AUTO_THROW_INTERVAL
	_hat_material = StandardMaterial3D.new()
	_hat_material.albedo_color = Color(0.8, 0.1, 0.12)
	hat_mesh.material_override = _hat_material
	Game.hat_equipped.connect(_on_hat_equipped)
	if Game.equipped_hat != "":
		_on_hat_equipped(Game.equipped_hat)

func _on_hat_equipped(hat_id: String) -> void:
	var data: Dictionary = HatDB.get_data(hat_id)
	_hat_material.albedo_color = data.get("color", Color(0.8, 0.1, 0.12))
	var tw := create_tween()
	tw.tween_property(hat_mesh, "scale", Vector3(1.3, 1.3, 1.3), 0.1)
	tw.tween_property(hat_mesh, "scale", Vector3.ONE, 0.15)

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
		if _look_touch_index == -1:
			_look_touch_index = event.index
	elif event.index == _look_touch_index:
		_look_touch_index = -1

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

# --- Throwing (automatic, fixed cadence, auto-lock on nearest enemy) -----
# Cadence is a hard-fixed 1 throw per 0.5s. Nothing in the game (kills,
# upgrades, pickups) is allowed to change this - only the projectile COUNT
# per throw (coins) and per-projectile speed/damage change with upgrades.
func _handle_auto_throw(delta: float) -> void:
	_handle_weapon_switch()
	_throw_timer -= delta
	if _throw_timer <= 0.0:
		_throw_snowball()
		_throw_timer = AUTO_THROW_INTERVAL

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
	var target: Node3D = _find_nearest_enemy()
	if target == null:
		return
	_play_throw_animation()
	var id: String = Game.current_weapon
	var tier: int = Game.unlocked_weapons.get(id, 1)
	var stats: Dictionary = SnowballDB.get_stats(id, tier).duplicate()
	var power: float = Game.get_throw_power_mult()
	stats["damage"] = stats.get("damage", 10.0) * power
	stats["speed"] = stats.get("speed", 30.0) * power * Game.get_projectile_speed_mult()
	# Every throw gets at least a baseline auto-lock pull, on top of
	# whatever homing the weapon type already has (Frost Seeker etc. keep
	# their stronger values via maxf).
	stats["homing"] = maxf(stats.get("homing", 0.0), AUTO_LOCK_HOMING)
	var base_dir: Vector3 = (target.global_position + Vector3.UP - throw_point.global_position).normalized()
	var color: Color = SnowballDB.get_color(id)

	# Coin pickups add extra snowballs per throw; fan them out around the
	# main target direction so a crowd gets hit instead of stacking on one.
	var count: int = Game.get_projectile_count()
	if count <= 1:
		_spawn_snowball(base_dir, stats, color)
		return
	var total_spread: float = MULTISHOT_SPREAD_DEG * (count - 1)
	var start_deg: float = -total_spread / 2.0
	for i in count:
		var angle_deg: float = start_deg + i * MULTISHOT_SPREAD_DEG
		var dir: Vector3 = base_dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
		_spawn_snowball(dir, stats, color)

func _spawn_snowball(dir: Vector3, stats: Dictionary, color: Color) -> void:
	var scene: PackedScene = load(SNOWBALL_SCENE_PATH)
	var sb: Area3D = scene.instantiate()
	get_tree().current_scene.add_child(sb)
	sb.global_position = throw_point.global_position
	sb.setup(dir, stats, true, color)

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
