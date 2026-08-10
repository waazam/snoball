extends Area3D
## A hat resting on the ground. Touching it applies HatDB's stat bonus and
## re-equips the player's hat visually (see Player._on_hat_equipped).

@onready var hat_mesh: MeshInstance3D = $HatCone
@onready var band_mesh: MeshInstance3D = $HatBand

var hat_id: String = ""
var _bob_time: float = 0.0
var _collected: bool = false

func _ready() -> void:
	add_to_group("hat_pickups")
	_bob_time = randf() * TAU
	monitoring = true
	body_entered.connect(_on_body_entered)

func setup(id: String) -> void:
	hat_id = id
	var data: Dictionary = HatDB.get_data(id)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.get("color", Color.WHITE)
	hat_mesh.material_override = mat

func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta
	rotate_y(delta * 1.4)
	position.y = 0.9 + sin(_bob_time * 1.6) * 0.15

func _on_body_entered(body: Node) -> void:
	if _collected or Game.state != Game.State.PLAYING or not body.is_in_group("player"):
		return
	_collected = true
	monitoring = false
	HatDB.apply(hat_id)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
