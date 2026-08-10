extends CharacterBody3D
## Enemy AI: chases the player, then either melees or (if ranged) throws
## snowballs once in range. Stats come from EnemyDB, scaled by wave number.

const GRAVITY := 22.0
const SNOWBALL_SCENE_PATH := "res://scenes/weapons/Snowball.tscn"

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

@onready var mesh: MeshInstance3D = $Body
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var health_fill: MeshInstance3D = $HealthBar/Fill
@onready var throw_point: Marker3D = $ThrowPoint

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
	if dist > attack_range:
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
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0
	velocity.x += external_velocity.x
	velocity.z += external_velocity.z
	external_velocity = external_velocity.move_toward(Vector3.ZERO, 20.0 * delta)
	move_and_slide()

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
	remove_from_group("enemies")
	collision.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.25)
	tw.tween_callback(queue_free)

func _get_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
