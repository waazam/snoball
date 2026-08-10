extends CharacterBody3D
## Enemy AI: chases the player, then either melees or (if ranged) throws
## snowballs once in range. Stats come from EnemyDB, scaled by wave number.

const GRAVITY := 22.0
const SNOWBALL_SCENE_PATH := "res://scenes/weapons/Snowball.tscn"
const JUMP_VELOCITY := 7.5
const JUMP_INTERVAL_MIN := 3.0
const JUMP_INTERVAL_MAX := 6.0
const DASH_SPEED_MULT := 2.6
const DASH_TIME := 0.22
const DASH_INTERVAL_MIN := 4.0
const DASH_INTERVAL_MAX := 8.0
const COIN_SCENE_PATH := "res://scenes/pickups/CoinPickup.tscn"
const COIN_DROP_CHANCE := 0.4

var enemy_id: String = "grunt"
var max_health: float = 30.0
var health: float = 30.0
var speed: float = 3.5
var damage: float = 8.0
var attack_range: float = 1.7
var attack_cooldown: float = 1.0
var is_ranged: bool = false
var score_value: int = 10

var attack_timer: float = 0.0
var slow_timer: float = 0.0
var slow_factor: float = 1.0
var external_velocity: Vector3 = Vector3.ZERO
var _dead: bool = false

var _jump_timer: float = 0.0
var _dash_timer: float = 0.0
var _is_dashing: bool = false
var _dash_time_left: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO

@onready var mesh: MeshInstance3D = $Body
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var health_fill: MeshInstance3D = $HealthBar/Fill
@onready var throw_point: Marker3D = $ThrowPoint

# Optional rig parts, fetched defensively since the two enemy scenes use
# different skeletons: EnemyElf.tscn is a biped (hips + shoulders, like the
# player), EnemyReindeer.tscn is a quadruped (four leg pivots). Whichever
# set resolves to non-null drives _update_animation()'s run cycle.
@onready var left_hip: Node3D = get_node_or_null("LeftHip")
@onready var right_hip: Node3D = get_node_or_null("RightHip")
@onready var left_shoulder: Node3D = get_node_or_null("LeftShoulder")
@onready var right_shoulder: Node3D = get_node_or_null("RightShoulder")
@onready var leg_front_left: Node3D = get_node_or_null("LegFrontLeft")
@onready var leg_front_right: Node3D = get_node_or_null("LegFrontRight")
@onready var leg_back_left: Node3D = get_node_or_null("LegBackLeft")
@onready var leg_back_right: Node3D = get_node_or_null("LegBackRight")

var _anim_time: float = 0.0

func _ready() -> void:
	add_to_group("enemies")

func setup(id: String, wave: int) -> void:
	enemy_id = id
	var stats: Dictionary = EnemyDB.get_scaled_stats(id, wave)
	max_health = stats.health
	health = max_health
	speed = stats.speed
	damage = stats.damage
	attack_range = stats.attack_range
	attack_cooldown = stats.attack_cooldown
	is_ranged = stats.is_ranged
	score_value = stats.score
	var sc: float = stats.scale
	scale = Vector3(sc, sc, sc)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = stats.color
	mesh.material_override = mat
	attack_timer = randf_range(0.0, attack_cooldown)
	_jump_timer = randf_range(JUMP_INTERVAL_MIN, JUMP_INTERVAL_MAX)
	_dash_timer = randf_range(DASH_INTERVAL_MIN, DASH_INTERVAL_MAX)
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if _dead or Game.state != Game.State.PLAYING:
		return
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
	var player := _get_player()
	if player == null:
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	if dist > 0.05:
		look_at(global_position + to_player, Vector3.UP)
	_update_dash(delta, to_player, dist)
	if _is_dashing:
		velocity.x = _dash_dir.x * speed * DASH_SPEED_MULT
		velocity.z = _dash_dir.z * speed * DASH_SPEED_MULT
	elif dist > attack_range:
		var dir: Vector3 = to_player.normalized()
		velocity.x = dir.x * speed * slow_factor
		velocity.z = dir.z * speed * slow_factor
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 4.0 * delta)
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			_attack(player)
	var jumped: bool = _update_jump(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif not jumped:
		velocity.y = -1.0
	velocity.x += external_velocity.x
	velocity.z += external_velocity.z
	external_velocity = external_velocity.move_toward(Vector3.ZERO, 20.0 * delta)
	_update_animation(delta)
	move_and_slide()

## Procedural run cycle shared by both rigs. Biped (elf): opposite-phase
## hip/shoulder swing, same as the player. Quadruped (reindeer): diagonal
## trot gait (front-left+back-right together, front-right+back-left
## opposite), which only works because the reindeer's legs are pivot nodes
## with the mesh offset below them, not meshes rotating about their own center.
func _update_animation(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = horizontal_speed > 0.3 and not _dead
	var amp: float = 0.0
	if moving:
		var ratio: float = clampf(horizontal_speed / maxf(speed, 0.5), 0.4, 2.2)
		_anim_time += delta * 10.0 * ratio
		amp = 0.8
	var swing: float = sin(_anim_time) * amp
	var blend: float = clampf(delta * 12.0, 0.0, 1.0)
	if left_hip and right_hip:
		left_hip.rotation.x = lerp_angle(left_hip.rotation.x, swing * 0.7, blend)
		right_hip.rotation.x = lerp_angle(right_hip.rotation.x, -swing * 0.7, blend)
	if left_shoulder and right_shoulder:
		left_shoulder.rotation.x = lerp_angle(left_shoulder.rotation.x, -swing * 0.6, blend)
		right_shoulder.rotation.x = lerp_angle(right_shoulder.rotation.x, swing * 0.6, blend)
	if leg_front_left and leg_front_right and leg_back_left and leg_back_right:
		leg_front_left.rotation.x = lerp_angle(leg_front_left.rotation.x, swing * 0.5, blend)
		leg_back_right.rotation.x = lerp_angle(leg_back_right.rotation.x, swing * 0.5, blend)
		leg_front_right.rotation.x = lerp_angle(leg_front_right.rotation.x, -swing * 0.5, blend)
		leg_back_left.rotation.x = lerp_angle(leg_back_left.rotation.x, -swing * 0.5, blend)

## Random hops while chasing - just a periodic vertical impulse, purely for
## liveliness (also occasionally helps them hop over small ledges/obstacles).
## Returns true the frame it actually launches a jump, so the caller can
## skip the floor-snap reset that would otherwise immediately cancel it.
func _update_jump(delta: float) -> bool:
	_jump_timer -= delta
	if _jump_timer <= 0.0:
		_jump_timer = randf_range(JUMP_INTERVAL_MIN, JUMP_INTERVAL_MAX)
		if is_on_floor() and not _is_dashing:
			velocity.y = JUMP_VELOCITY
			return true
	return false

## Periodic aggressive lunge toward the player while mid-chase (not already
## in attack range), for a burst of speed that's harder to react to.
func _update_dash(delta: float, to_player: Vector3, dist: float) -> void:
	if _is_dashing:
		_dash_time_left -= delta
		if _dash_time_left <= 0.0:
			_is_dashing = false
		return
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_dash_timer = randf_range(DASH_INTERVAL_MIN, DASH_INTERVAL_MAX)
		if dist > attack_range * 1.2 and to_player.length() > 0.01:
			_is_dashing = true
			_dash_time_left = DASH_TIME
			_dash_dir = to_player.normalized()

func _attack(player: Node3D) -> void:
	if is_ranged:
		_throw_at(player)
	elif player.has_method("take_hit"):
		player.take_hit(damage)

func _throw_at(player: Node3D) -> void:
	var scene: PackedScene = load(SNOWBALL_SCENE_PATH)
	var sb: Area3D = scene.instantiate()
	get_tree().current_scene.add_child(sb)
	sb.global_position = throw_point.global_position
	var dir: Vector3 = (player.global_position + Vector3.UP * 0.9 - throw_point.global_position).normalized()
	var stats := {"damage": damage, "speed": 20.0, "gravity_scale": 0.6, "radius": 0.2, "pierce": 1}
	sb.setup(dir, stats, false, Color(0.7, 0.85, 1.0))

func take_damage(amount: float, freeze_duration: float = 0.0, freeze_factor: float = 1.0) -> void:
	if _dead:
		return
	health -= amount
	_update_health_bar()
	if freeze_duration > 0.0:
		slow_timer = max(slow_timer, freeze_duration)
		slow_factor = min(slow_factor, freeze_factor)
	if health <= 0.0:
		_die()

func apply_knockback(v: Vector3) -> void:
	external_velocity += v

func _update_health_bar() -> void:
	var ratio: float = clampf(health / max_health, 0.0, 1.0)
	health_fill.scale.x = ratio
	health_fill.position.x = -0.4 * (1.0 - ratio)

func _die() -> void:
	if _dead:
		return
	_dead = true
	Game.add_score(score_value)
	Game.add_kill()
	_maybe_drop_coin()
	remove_from_group("enemies")
	collision.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.25)
	tw.tween_callback(queue_free)

func _maybe_drop_coin() -> void:
	if randf() > COIN_DROP_CHANCE:
		return
	var scene: PackedScene = load(COIN_SCENE_PATH)
	var coin: Area3D = scene.instantiate()
	get_tree().current_scene.add_child(coin)
	coin.global_position = global_position + Vector3.UP * 0.3

func _get_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
