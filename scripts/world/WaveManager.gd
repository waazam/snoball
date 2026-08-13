extends Node3D
## Spawns enemy waves around the arena and reports when a wave is cleared.
## Composition/difficulty comes from EnemyDB; this node only handles the
## timing/placement of spawns and tracking how many are still alive.

signal wave_started(wave: int)
signal wave_cleared(wave: int)

const SPAWN_STAGGER := 0.26
const HAT_SCENE_PATH := "res://scenes/pickups/HatPickup.tscn"
const HAT_SPAWN_RADIUS := 28.0
const HAT_SPAWN_MIN_RADIUS := 4.0

@export var spawn_points_path: NodePath = NodePath("../SpawnPoints")

var spawn_points: Array = []
var alive_count: int = 0
var spawning: bool = false
var _spawn_queue: Array = []
var _spawn_timer: float = 0.0
var _cleared_emitted: bool = false

func _ready() -> void:
	var container := get_node_or_null(spawn_points_path)
	if container:
		for c in container.get_children():
			if c is Node3D:
				spawn_points.append(c)

func start_wave(wave: int) -> void:
	alive_count = 0
	spawning = true
	_cleared_emitted = false
	_spawn_queue = EnemyDB.get_wave_composition(wave)
	_spawn_timer = 0.0
	emit_signal("wave_started", wave)
	_spawn_hat_pickup()

func _random_ground_point() -> Vector3:
	var angle: float = randf() * TAU
	var radius: float = randf_range(HAT_SPAWN_MIN_RADIUS, HAT_SPAWN_RADIUS)
	return Vector3(cos(angle) * radius, 0.9, sin(angle) * radius)

func _spawn_hat_pickup() -> void:
	var scene: PackedScene = load(HAT_SCENE_PATH)
	var hat: Area3D = scene.instantiate()
	get_tree().current_scene.add_child(hat)
	hat.global_position = _random_ground_point()
	hat.setup(HatDB.get_random_id())

func _process(delta: float) -> void:
	if not spawning or Game.state != Game.State.PLAYING:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and not _spawn_queue.is_empty():
		var id: String = _spawn_queue.pop_front()
		_spawn_enemy(id)
		_spawn_timer = SPAWN_STAGGER
	if _spawn_queue.is_empty():
		spawning = false
		_check_cleared()

func _spawn_enemy(id: String) -> void:
	if spawn_points.is_empty():
		return
	var point: Node3D = spawn_points[randi() % spawn_points.size()]
	var scene: PackedScene = load(EnemyDB.get_scene_path(id))
	var enemy: CharacterBody3D = scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = point.global_position
	enemy.setup(id, Game.wave)
	alive_count += 1
	enemy.tree_exited.connect(_on_enemy_removed)

func _on_enemy_removed() -> void:
	alive_count = max(0, alive_count - 1)
	_check_cleared()

func _check_cleared() -> void:
	if _cleared_emitted:
		return
	if not spawning and _spawn_queue.is_empty() and alive_count <= 0:
		_cleared_emitted = true
		emit_signal("wave_cleared", Game.wave)

func clear_all_enemies() -> void:
	spawning = false
	_spawn_queue.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	for h in get_tree().get_nodes_in_group("hat_pickups"):
		if is_instance_valid(h):
			h.queue_free()
	for p in get_tree().get_nodes_in_group("present_pickups"):
		if is_instance_valid(p):
			p.queue_free()
	alive_count = 0
