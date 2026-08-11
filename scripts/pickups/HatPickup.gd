extends Area3D
## A hat resting on the ground, spinning and bobbing in place. Touching it
## applies HatDB's stat bonus and re-equips the player's hat visually (see
## Player._on_hat_equipped) using the same procedural shape (HatVisuals).

const SPIN_SPEED := 2.2  # rad/s
# HatVisuals sizes hats to actually fit the player's small head; blown up to
# this scale on the ground so they're still readable/collectible at a
# glance from a distance.
const PICKUP_VISUAL_SCALE := 1.8

@onready var hat_anchor: Node3D = $HatAnchor

var hat_id: String = ""
var _bob_time: float = 0.0
var _collected: bool = false

func _ready() -> void:
	add_to_group("hat_pickups")
	_bob_time = randf() * TAU
	rotate_y(randf() * TAU)  # so a field of hats doesn't spin in lockstep
	monitoring = true
	body_entered.connect(_on_body_entered)

func setup(id: String) -> void:
	hat_id = id
	var data: Dictionary = HatDB.get_data(id)
	var visual: Node3D = HatVisuals.build(data.get("shape", "top_hat"), data.get("color", Color.WHITE))
	visual.scale = Vector3.ONE * PICKUP_VISUAL_SCALE
	hat_anchor.add_child(visual)

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
	HatDB.apply(hat_id)
	var tw := create_tween()
	# A hair above zero, not Vector3.ZERO - an exactly-zero scale makes the
	# physics engine's transform matrix singular (non-invertible), which
	# Jolt logs as an error and has to paper over every frame of the tween.
	tw.tween_property(self, "scale", Vector3.ONE * 0.001, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
