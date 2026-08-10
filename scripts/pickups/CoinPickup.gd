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
	monitoring = false
	Game.add_coin()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
