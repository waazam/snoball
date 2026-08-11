extends Area3D
## A coin dropped by a slain enemy. Doesn't touch throw speed at all - every
## 3 coins collected this run permanently adds one more snowball to every
## future throw (a fanned-out multi-shot). See Game.add_coin().
##
## Magnetizes toward the player once they're within MAGNET_RADIUS - pull
## speed ramps up the closer it gets, so it reads as "snapping in" for the
## last stretch instead of a flat crawl the whole way.

const MAGNET_RADIUS := 10.0
const MAGNET_SPEED_MIN := 6.0
const MAGNET_SPEED_MAX := 22.0
# Once magnetizing gets the coin at least this close, collect it directly
# instead of waiting on the Area3D body_entered signal - that signal fires
# off the physics server's own overlap check, which runs on a different
## tick than the _process()-driven flight here, so "close to the flight
# target" and "physically overlapping enough to trigger the signal" can
# land on different frames. Without this, a coin could reach its target
# point, stop (nothing left moving it), and never actually be collected -
# reads as the coin permanently stuck to the player.
const COLLECT_DISTANCE := 0.4

var _bob_time: float = 0.0
var _collected: bool = false

func _ready() -> void:
	add_to_group("coin_pickups")
	_bob_time = randf() * TAU
	monitoring = true
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta
	rotate_y(delta * 2.2)
	var player: Node3D = _get_player()
	if player and global_position.distance_to(player.global_position) <= MAGNET_RADIUS:
		_fly_toward(player, delta)
	else:
		position.y = 0.55 + sin(_bob_time * 2.0) * 0.1

func _fly_toward(player: Node3D, delta: float) -> void:
	var target: Vector3 = player.global_position + Vector3.UP * 0.9
	var to_target: Vector3 = target - global_position
	var dist: float = to_target.length()
	if dist <= COLLECT_DISTANCE:
		_collect()
		return
	var closeness: float = 1.0 - clampf(dist / MAGNET_RADIUS, 0.0, 1.0)
	var speed: float = lerpf(MAGNET_SPEED_MIN, MAGNET_SPEED_MAX, closeness)
	global_position += (to_target / dist) * speed * delta

func _get_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]

func _on_body_entered(body: Node) -> void:
	if _collected or Game.state != Game.State.PLAYING or not body.is_in_group("player"):
		return
	_collect()

func _collect() -> void:
	if _collected:
		return
	_collected = true
	# Deferred: _on_body_entered runs during the physics engine's collision
	# pass (it's connected to this same Area3D's body_entered), and
	# toggling monitoring synchronously mid-pass is explicitly disallowed
	# by Godot - keeping it deferred here too since _collect() is now also
	# reachable from that path.
	set_deferred("monitoring", false)
	Game.add_coin()
	var tw := create_tween()
	# A hair above zero, not Vector3.ZERO - an exactly-zero scale makes the
	# physics engine's transform matrix singular (non-invertible), which
	# Jolt logs as an error and has to paper over every frame of the tween.
	tw.tween_property(self, "scale", Vector3.ONE * 0.001, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
