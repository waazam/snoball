extends Area3D
## A coin dropped by a slain enemy. Doesn't touch throw speed at all - every
## 3 coins collected this run permanently adds one more snowball to every
## future throw (a fanned-out multi-shot). See Game.add_coin().

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
	position.y = 0.55 + sin(_bob_time * 2.0) * 0.1

func _on_body_entered(body: Node) -> void:
	if _collected or Game.state != Game.State.PLAYING or not body.is_in_group("player"):
		return
	_collected = true
	# Deferred: this handler runs during the physics engine's collision pass
	# (it's connected to this same Area3D's body_entered), and toggling
	# monitoring synchronously mid-pass is explicitly disallowed by Godot.
	set_deferred("monitoring", false)
	Game.add_coin()
	var tw := create_tween()
	# A hair above zero, not Vector3.ZERO - an exactly-zero scale makes the
	# physics engine's transform matrix singular (non-invertible), which
	# Jolt logs as an error and has to paper over every frame of the tween.
	tw.tween_property(self, "scale", Vector3.ONE * 0.001, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
