extends Area3D
## A cookie or candy cane resting on the ground. Touching it applies
## TreatDB's stat bonus (fire rate for cookies, projectile speed for candy
## canes) and disappears.

@onready var cookie_visual: Node3D = $CookieVisual
@onready var cane_visual: Node3D = $CaneVisual

var treat_id: String = ""
var _bob_time: float = 0.0
var _collected: bool = false

func _ready() -> void:
	add_to_group("treat_pickups")
	_bob_time = randf() * TAU
	monitoring = true
	body_entered.connect(_on_body_entered)

func setup(id: String) -> void:
	treat_id = id
	var visual: String = TreatDB.get_data(id).get("visual", "cookie")
	cookie_visual.visible = visual == "cookie"
	cane_visual.visible = visual == "candy_cane"

func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta
	rotate_y(delta * 1.6)
	position.y = 0.7 + sin(_bob_time * 1.8) * 0.12

func _on_body_entered(body: Node) -> void:
	if _collected or Game.state != Game.State.PLAYING or not body.is_in_group("player"):
		return
	_collected = true
	monitoring = false
	TreatDB.apply(treat_id)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
