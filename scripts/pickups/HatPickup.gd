extends Area3D
## A hat hovering above a little wooden display pedestal, spinning and
## bobbing like a shop showcase. Touching it applies HatDB's stat bonus and
## re-equips the player's hat visually (see Player._on_hat_equipped) using
## the same procedural shape (HatVisuals).

const SPIN_SPEED := 2.2  # rad/s
# HatVisuals sizes hats to actually fit the player's small head; blown up to
# this scale on the ground so they're still readable/collectible at a
# glance from a distance.
const PICKUP_VISUAL_SCALE := 1.8

const PICKUP_GLOW_SCRIPT := preload("res://scripts/pickups/PickupGlow.gd")
const GLOW_COLOR := Color("#FFB84D")  # EMBER_GOLD - rewards read warm-gold against the dusk
# Pedestal palette: same wood + gold + snow family as the DuskLanterns
# posts, so hat stands read as furniture of the same village.
const WOOD_BARK := Color("#4A3325")
const EMBER_GOLD := Color("#FFB84D")
const SNOW_LIT := Color("#EAF2FB")

@onready var hat_anchor: Node3D = $HatAnchor

var hat_id: String = ""
var _bob_time: float = 0.0
var _collected: bool = false
var _stand: Node3D

func _ready() -> void:
	add_to_group("hat_pickups")
	_bob_time = randf() * TAU
	rotate_y(randf() * TAU)  # so a field of hats doesn't spin in lockstep
	monitoring = true
	body_entered.connect(_on_body_entered)
	_spawn_stand()
	# Cosmetic ground halo + twinkling glints (see PickupGlow.gd) so a
	# dropped hat gleams like a reward instead of sitting matte on the snow.
	var glow := Node3D.new()
	glow.set_script(PICKUP_GLOW_SCRIPT)
	add_child(glow)
	glow.setup(GLOW_COLOR, 0.55, 0.03, 0.85)

## The display stand under the hovering hat: a tapered wooden column on a
## base disc, a gold band under a wide top plate dusted with a snow cap,
## and a snow drift piled around the foot. Pinned to global ground level
## each frame (same idiom as PickupGlow's halo) so the root's bob only
## floats the hat, not the furniture; it shares the root's spin, but every
## piece is radially symmetric so the spin reads as a turntable.
func _spawn_stand() -> void:
	_stand = Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD_BARK
	wood.roughness = 0.92
	var gold := StandardMaterial3D.new()
	gold.albedo_color = EMBER_GOLD
	gold.metallic = 0.9
	gold.roughness = 0.35
	var snow := StandardMaterial3D.new()
	snow.albedo_color = SNOW_LIT
	snow.roughness = 0.92
	_add_stand_cyl(0.24, 0.28, 0.07, 0.035, wood)  # base disc
	_add_stand_cyl(0.09, 0.14, 1.1, 0.6, wood)  # tapered column
	_add_stand_cyl(0.26, 0.22, 0.07, 1.19, wood)  # top plate
	_add_stand_cyl(0.23, 0.23, 0.04, 1.245, snow)  # snow cap on the plate
	var band := TorusMesh.new()
	band.inner_radius = 0.08
	band.outer_radius = 0.12
	band.rings = 12
	band.ring_segments = 6
	var band_mi := MeshInstance3D.new()
	band_mi.mesh = band
	band_mi.material_override = gold
	band_mi.position = Vector3(0.0, 1.1, 0.0)
	band_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stand.add_child(band_mi)
	var drift := TorusMesh.new()
	drift.inner_radius = 0.18
	drift.outer_radius = 0.36
	drift.rings = 14
	drift.ring_segments = 5
	var drift_mi := MeshInstance3D.new()
	drift_mi.mesh = drift
	drift_mi.material_override = snow
	drift_mi.scale = Vector3(1.0, 0.32, 1.0)
	drift_mi.position = Vector3(0.0, 0.03, 0.0)
	drift_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stand.add_child(drift_mi)
	add_child(_stand)

func _add_stand_cyl(top_r: float, bottom_r: float, height: float, y: float, mat: StandardMaterial3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(0.0, y, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stand.add_child(mi)

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
	# Pin the pedestal to the snow while the hat bobs above it.
	_stand.global_position.y = 0.0

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
