extends Area3D
## A thrown snowball projectile. Configured via setup() right after
## instancing; supports pierce, splash, cluster-splitting, homing and
## freeze/knockback effects depending on the stats dictionary it was given,
## plus a handful of on-hit effects (footprints, bleed, instant kill) keyed
## off its snowball type_id - see SnowballDB.gd for the 9 player-thrown
## types and SnowballVisuals.gd for their looks. Enemy-thrown snowballs
## (and cluster shards) always use type_id "standard" - none of the special
## effects apply to them.

const GRAVITY := 9.8
const SNOWBALL_SCENE_PATH := "res://scenes/weapons/Snowball.tscn"
const PULSE_SPEED := 6.0  # death ball's flight-time scale "breathing", rad/s

var velocity: Vector3 = Vector3.ZERO
var damage: float = 10.0
var gravity_scale: float = 1.0
var pierce: int = 1
var splash_radius: float = 0.0
var cluster_count: int = 0
var homing: float = 0.0
var knockback: float = 2.0
var freeze_duration: float = 0.0
var freeze_factor: float = 1.0
var lifetime: float = 4.0
var is_player_owned: bool = true
var is_cluster_shard: bool = false

var type_id: String = "standard"
var effect_kind: String = "none"
var effect_data: Dictionary = {}

var _color: Color = Color.WHITE
var _visual_root: Node3D
var _pulse_time: float = 0.0

var _hit_bodies: Array = []
var _age: float = 0.0
var _dead: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if is_player_owned:
		collision_layer = 8
		collision_mask = 1 | 4
	else:
		collision_layer = 16
		collision_mask = 1 | 2

func setup(p_direction: Vector3, p_stats: Dictionary, p_is_player_owned: bool, p_color: Color = Color.WHITE, p_is_cluster_shard: bool = false, p_type_id: String = "standard") -> void:
	is_player_owned = p_is_player_owned
	is_cluster_shard = p_is_cluster_shard
	type_id = p_type_id
	damage = p_stats.get("damage", 10.0)
	gravity_scale = p_stats.get("gravity_scale", 1.0)
	pierce = int(p_stats.get("pierce", 1))
	splash_radius = p_stats.get("splash_radius", 0.0)
	cluster_count = 0 if p_is_cluster_shard else int(p_stats.get("cluster_count", 0))
	homing = p_stats.get("homing", 0.0)
	knockback = p_stats.get("knockback", 2.0)
	freeze_duration = p_stats.get("freeze_duration", 0.0)
	freeze_factor = p_stats.get("freeze_factor", 1.0)
	var speed: float = p_stats.get("speed", 30.0)
	var dir: Vector3 = p_direction
	if dir.length() < 0.001:
		dir = Vector3.FORWARD
	velocity = dir.normalized() * speed
	var radius: float = p_stats.get("radius", 0.22)
	var s: float = radius / 0.22
	scale = Vector3(s, s, s)
	if is_inside_tree():
		if is_player_owned:
			collision_layer = 8
			collision_mask = 1 | 4
		else:
			collision_layer = 16
			collision_mask = 1 | 2
	_color = p_color
	if is_player_owned and not is_cluster_shard:
		var data: Dictionary = SnowballDB.get_data(type_id)
		effect_kind = data.get("effect", "none")
		effect_data = data
	_build_visual()

## Replaces whatever's there with a fresh procedural mesh matching this
## snowball's shape (SnowballDB.get_shape) - enemy throws and cluster
## shards always render as the plain "standard" look.
func _build_visual() -> void:
	if _visual_root and is_instance_valid(_visual_root):
		_visual_root.queue_free()
	var shape: String = SnowballDB.get_shape(type_id) if (is_player_owned and not is_cluster_shard) else "standard"
	_visual_root = SnowballVisuals.build(shape, _color)
	add_child(_visual_root)

func _physics_process(delta: float) -> void:
	if _dead or Game.state != Game.State.PLAYING:
		return
	_age += delta
	if _age > lifetime:
		_die()
		return
	if homing > 0.0 and is_player_owned:
		_apply_homing(delta)
	velocity.y -= GRAVITY * gravity_scale * delta
	global_position += velocity * delta
	if velocity.length_squared() > 0.01:
		var look_dir: Vector3 = velocity.normalized()
		if absf(look_dir.dot(Vector3.UP)) < 0.999:
			look_at(global_position + look_dir, Vector3.UP)
	if type_id == "death_ball" and _visual_root:
		_pulse_time += delta
		var p: float = 1.0 + 0.18 * sin(_pulse_time * PULSE_SPEED)
		_visual_root.scale = Vector3.ONE * p

func _apply_homing(delta: float) -> void:
	var target: Node3D = _find_nearest_enemy(25.0)
	if target == null:
		return
	var desired: Vector3 = (target.global_position + Vector3.UP * 0.6 - global_position).normalized()
	var speed: float = velocity.length()
	var cur_dir: Vector3 = velocity.normalized() if speed > 0.01 else desired
	var new_dir: Vector3 = cur_dir.slerp(desired, clampf(homing * delta, 0.0, 1.0))
	velocity = new_dir * speed

func _find_nearest_enemy(max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_dist := max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best

func _on_body_entered(body: Node) -> void:
	if _dead or body in _hit_bodies:
		return
	if is_player_owned:
		if body.is_in_group("enemies"):
			_hit_bodies.append(body)
			_hit_enemy(body)
			pierce -= 1
			if splash_radius > 0.0:
				_do_splash()
			if cluster_count > 0:
				_spawn_cluster()
			if pierce <= 0:
				_die()
		elif body is StaticBody3D:
			if splash_radius > 0.0:
				_do_splash()
			if cluster_count > 0:
				_spawn_cluster()
			_die()
	else:
		if body.is_in_group("player"):
			if body.has_method("take_hit"):
				body.take_hit(damage)
			_die()
		elif body is StaticBody3D:
			_die()

func _hit_enemy(body: Node) -> void:
	if effect_kind == "instakill" and body.has_method("instant_kill"):
		body.instant_kill()
	else:
		if body.has_method("take_damage"):
			body.take_damage(damage, freeze_duration, freeze_factor)
		match effect_kind:
			"footprints":
				if body.has_method("apply_footprint_trail"):
					body.apply_footprint_trail(effect_data.get("effect_color", Color(0.85, 0.72, 0.1)), effect_data.get("effect_duration", 10.0))
			"bleed":
				if body.has_method("apply_bleed"):
					body.apply_bleed(effect_data.get("effect_dps", 4.0), effect_data.get("effect_duration", 5.0))
	if body.has_method("apply_knockback") and knockback > 0.0:
		var push_dir: Vector3 = (body.global_position - global_position)
		push_dir.y = 0.0
		if push_dir.length() > 0.01:
			body.apply_knockback(push_dir.normalized() * knockback)

func _do_splash() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e in _hit_bodies:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d <= splash_radius:
			_hit_bodies.append(e)
			if e.has_method("take_damage"):
				e.take_damage(damage * 0.6, freeze_duration, freeze_factor)

func _spawn_cluster() -> void:
	var scene: PackedScene = load(SNOWBALL_SCENE_PATH)
	var shard_stats := {
		"damage": max(1.0, damage * 0.4),
		"speed": 14.0,
		"gravity_scale": 1.3,
		"radius": 0.12,
		"pierce": 1,
	}
	for i in cluster_count:
		var shard: Area3D = scene.instantiate()
		var angle: float = (TAU / cluster_count) * i
		var out_dir: Vector3 = Vector3(cos(angle), randf_range(0.2, 0.6), sin(angle))
		get_tree().current_scene.add_child(shard)
		shard.global_position = global_position
		shard.setup(out_dir, shard_stats, is_player_owned, _color, true)

func _die() -> void:
	if _dead:
		return
	_dead = true
	queue_free()
