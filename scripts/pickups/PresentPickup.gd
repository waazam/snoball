extends Area3D
## A wrapped Christmas present resting on the ground, spinning and bobbing
## in place. Touching it re-equips the player's snowball to whichever of
## SnowballDB's 9 types it was given (see Game.equip_snowball) - permanent
## until the next present, same "equip and stay" mechanic as hats. Every
## present looks identical on the outside; the type inside is picked by
## WaveManager (weighted via SnowballDB.get_random_id - the death ball is
## by far the rarest) before it's ever shown.

const SPIN_SPEED := 1.8  # rad/s

var snowball_type_id: String = "standard"
var _bob_time: float = 0.0
var _collected: bool = false

func _ready() -> void:
	add_to_group("present_pickups")
	_bob_time = randf() * TAU
	rotate_y(randf() * TAU)  # so a field of presents doesn't spin in lockstep
	monitoring = true
	body_entered.connect(_on_body_entered)

func setup(id: String) -> void:
	snowball_type_id = id

func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta
	rotate_y(delta * SPIN_SPEED)
	position.y = 0.9 + sin(_bob_time * 1.6) * 0.15

func _on_body_entered(body: Node) -> void:
	if _collected or Game.state != Game.State.PLAYING or not body.is_in_group("player"):
		return
	_collected = true
	# Deferred: this handler runs during the physics engine's collision pass
	# (it's connected to this same Area3D's body_entered), and toggling
	# monitoring synchronously mid-pass is explicitly disallowed by Godot.
	set_deferred("monitoring", false)
	Game.equip_snowball(snowball_type_id)
	Game.emit_signal("upgrade_picked", "%s equipped!" % SnowballDB.get_display_name(snowball_type_id))
	var tw := create_tween()
	# A hair above zero, not Vector3.ZERO - an exactly-zero scale makes the
	# physics engine's transform matrix singular (non-invertible), which
	# Jolt logs as an error and has to paper over every frame of the tween.
	tw.tween_property(self, "scale", Vector3.ONE * 0.001, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
