extends Area3D
## The Yeti boss's dropped Christmas Tree Sword (see EnemyYeti.gd's
## _spawn_death_fx) - spinning/bobbing on the ground exactly like
## PresentPickup.gd, but always grants "yeti_sword" (never randomized) and
## shows the actual sword mesh instead of a wrapped present, so it reads as
## a real weapon drop rather than another gift box.

const SNOWBALL_TYPE_ID := "yeti_sword"
const SPIN_SPEED := 1.4  # rad/s - slower than PresentPickup's spin, it's a much bigger/heavier object
const VISUAL_SCALE := 2.2

const PICKUP_GLOW_SCRIPT := preload("res://scripts/pickups/PickupGlow.gd")
const GLOW_COLOR := Color("#FFB84D")  # EMBER_GOLD - the legendary-drop gleam

var _bob_time: float = 0.0
var _collected: bool = false

func _ready() -> void:
	add_to_group("present_pickups")  # same cleanup group PresentPickup uses - WaveManager.clear_all_enemies sweeps it
	_bob_time = randf() * TAU
	rotate_y(randf() * TAU)
	monitoring = true
	body_entered.connect(_on_body_entered)
	var visual: Node3D = SnowballVisuals.build("yeti_sword", SnowballDB.get_color(SNOWBALL_TYPE_ID))
	visual.scale = Vector3.ONE * VISUAL_SCALE
	visual.rotation_degrees = Vector3(0, 0, 90)  # lying flat on its side, not standing upright on its handle
	add_child(visual)
	# Cosmetic boss-drop fanfare: a wider gold ground halo with an extra
	# glint (see PickupGlow.gd) - the once-a-run sword should out-shine
	# every present around it.
	var glow := Node3D.new()
	glow.set_script(PICKUP_GLOW_SCRIPT)
	add_child(glow)
	glow.setup(GLOW_COLOR, 0.8, 0.03, 0.6, 4)

func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta
	rotate_y(delta * SPIN_SPEED)
	position.y = 0.55 + sin(_bob_time * 1.4) * 0.12

func _on_body_entered(body: Node) -> void:
	if _collected or Game.state != Game.State.PLAYING or not body.is_in_group("player"):
		return
	_collected = true
	set_deferred("monitoring", false)
	Game.equip_snowball(SNOWBALL_TYPE_ID)
	Game.emit_signal("upgrade_picked", "%s equipped!" % SnowballDB.get_display_name(SNOWBALL_TYPE_ID))
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.001, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
