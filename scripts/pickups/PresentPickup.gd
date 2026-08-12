extends Area3D
## A wrapped Christmas present resting on the ground, spinning and bobbing
## in place. Touching it re-equips the player's snowball to whichever of
## SnowballDB's 9 types it was given (see Game.equip_snowball) - permanent
## until the next present, same "equip and stay" mechanic as hats. The type
## inside is picked by WaveManager (weighted via SnowballDB.get_random_id -
## the death ball is by far the rarest) before it's ever shown; the wrapping
## color is purely cosmetic, rolled independently from the ember trio
## (ART_DIRECTION 6f), so it never leaks what's inside.
##
## Visual juice, all cosmetic: per-instance wrap color with a slow emissive
## breathing pulse (0.5 -> 1.2 energy over 1.2s) - the overhanging lid runs
## a slightly darkened copy of the wrap so the box reads as two stacked
## pieces instead of one dyed block - an F5EFE6 ribbon-and-bow dressing plus
## a CANDLE_WHITE gift tag on a gold bead built in the scene, and a
## PickupGlow ground halo + glints tinted to the wrap color.

const SPIN_SPEED := 1.8  # rad/s

const PICKUP_GLOW_SCRIPT := preload("res://scripts/pickups/PickupGlow.gd")
# EMBER_RED / EMBER_GREEN / EMBER_GOLD - the reward family.
const WRAP_COLORS := [Color("#E8483F"), Color("#4FBF6B"), Color("#FFB84D")]
const PULSE_PERIOD := 1.2
const PULSE_ENERGY_MIN := 0.5
const PULSE_ENERGY_MAX := 1.2
# How far the lid's wrap shade is pulled toward dark - enough to separate
# lid from box at a glance, not enough to read as a different color family.
const LID_DARKEN := 0.18

var snowball_type_id: String = "standard"
var _bob_time: float = 0.0
var _collected: bool = false
var _wrap_mat: StandardMaterial3D
var _lid_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("present_pickups")
	_bob_time = randf() * TAU
	rotate_y(randf() * TAU)  # so a field of presents doesn't spin in lockstep
	monitoring = true
	body_entered.connect(_on_body_entered)
	_apply_wrap()

func setup(id: String) -> void:
	snowball_type_id = id

## Duplicate the scene's shared wrap material so each present can carry its
## own ember color and pulse without recoloring every other instance, then
## dress the drop with a matching ground glow.
func _apply_wrap() -> void:
	var wrap: Color = WRAP_COLORS[randi() % WRAP_COLORS.size()]
	var body: MeshInstance3D = $Body
	var lid: MeshInstance3D = $Lid
	_wrap_mat = body.get_surface_override_material(0).duplicate() as StandardMaterial3D
	_wrap_mat.albedo_color = wrap
	_wrap_mat.emission = wrap
	body.set_surface_override_material(0, _wrap_mat)
	var lid_shade: Color = wrap.darkened(LID_DARKEN)
	_lid_mat = _wrap_mat.duplicate() as StandardMaterial3D
	_lid_mat.albedo_color = lid_shade
	_lid_mat.emission = lid_shade
	lid.set_surface_override_material(0, _lid_mat)
	var glow := Node3D.new()
	glow.set_script(PICKUP_GLOW_SCRIPT)
	add_child(glow)
	glow.setup(wrap, 0.5, 0.03, 0.9)

func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta
	rotate_y(delta * SPIN_SPEED)
	position.y = 0.9 + sin(_bob_time * 1.6) * 0.15
	var energy: float = lerpf(PULSE_ENERGY_MIN, PULSE_ENERGY_MAX, 0.5 + 0.5 * sin(_bob_time * TAU / PULSE_PERIOD))
	_wrap_mat.emission_energy_multiplier = energy
	_lid_mat.emission_energy_multiplier = energy

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
