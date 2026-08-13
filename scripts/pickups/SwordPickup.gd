extends Area3D
## The Yeti boss's dropped Christmas Tree Sword (see EnemyYeti.gd's
## _spawn_death_fx) - always grants "yeti_sword" (never randomized) and
## shows the actual sword mesh, so it reads as a real weapon drop rather
## than another gift box. Presented as a monument: the sword hovers upright
## at a jaunty lean, slowly turning above a snow mound bristling with
## icicle shards, its tip star gleaming - the once-a-run legendary should
## read from across the whole arena.

const SNOWBALL_TYPE_ID := "yeti_sword"
const SPIN_SPEED := 1.4  # rad/s - slower than PresentPickup's spin, it's a much bigger/heavier object
const VISUAL_SCALE := 2.2
const SWORD_LEAN_DEG := 8.0  # a hair off vertical, so the spin sweeps a lazy cone instead of a static pole

const PICKUP_GLOW_SCRIPT := preload("res://scripts/pickups/PickupGlow.gd")
const GLOW_COLOR := Color("#FFB84D")  # EMBER_GOLD - the legendary-drop gleam
const SNOW_LIT := Color("#EAF2FB")
const FROST_GLOW := Color("#A8E4FF")

var _bob_time: float = 0.0
var _collected: bool = false
var _mound: Node3D

func _ready() -> void:
	add_to_group("present_pickups")  # ground-pickup cleanup group - WaveManager.clear_all_enemies sweeps it
	_bob_time = randf() * TAU
	rotate_y(randf() * TAU)
	monitoring = true
	body_entered.connect(_on_body_entered)
	var visual: Node3D = SnowballVisuals.build("yeti_sword", SnowballDB.get_color(SNOWBALL_TYPE_ID))
	visual.scale = Vector3.ONE * VISUAL_SCALE
	visual.rotation_degrees = Vector3(0, 0, SWORD_LEAN_DEG)
	# Root bobs around y=0.55; this offset keeps the pommel floating just
	# above the mound's crown at the bob's lowest point.
	visual.position.y = -0.15
	add_child(visual)
	_spawn_mound()
	# Cosmetic boss-drop fanfare: a wider gold ground halo with an extra
	# glint (see PickupGlow.gd) - the once-a-run sword should out-shine
	# every present around it.
	var glow := Node3D.new()
	glow.set_script(PICKUP_GLOW_SCRIPT)
	add_child(glow)
	glow.setup(GLOW_COLOR, 0.8, 0.03, 0.6, 4)

## The drop-site dressing under the hovering sword: a squashed packed-snow
## dome with a couple of lumps and three frost-glow icicle shards jutting
## out at angles - as if the sword slammed down here. Pinned to global
## ground level each frame (same idiom as PickupGlow's halo) so the root's
## bob doesn't lift the mound off the ground; it does share the root's slow
## spin, but the mound is scatter-symmetric enough to read as a turntable.
func _spawn_mound() -> void:
	_mound = Node3D.new()
	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = SNOW_LIT
	snow_mat.roughness = 0.92
	_add_mound_dome(snow_mat, 0.5, 0.36, Vector3.ZERO)
	_add_mound_dome(snow_mat, 0.2, 0.5, Vector3(0.32, 0.0, -0.14))
	_add_mound_dome(snow_mat, 0.15, 0.5, Vector3(-0.26, 0.0, 0.24))
	var ice_mat := StandardMaterial3D.new()
	ice_mat.albedo_color = Color(FROST_GLOW.r, FROST_GLOW.g, FROST_GLOW.b, 0.8)
	ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_mat.roughness = 0.08
	ice_mat.emission_enabled = true
	ice_mat.emission = FROST_GLOW
	ice_mat.emission_energy_multiplier = 0.45
	for i in 3:
		var a: float = TAU * float(i) / 3.0 + 0.5
		var shard := CylinderMesh.new()
		shard.top_radius = 0.004
		shard.bottom_radius = 0.045
		shard.height = 0.3
		shard.radial_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = shard
		mi.material_override = ice_mat
		mi.position = Vector3(cos(a) * 0.34, 0.16, sin(a) * 0.34)
		# Each shard leans radially outward from the impact point: rotation
		# about +x tips the shard toward +z, rotation about -z tips it
		# toward +x, so scaling those by the position's sin/cos components
		# points the lean away from center.
		mi.rotation_degrees = Vector3(sin(a) * 22.0, 0.0, cos(a) * -22.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mound.add_child(mi)
	add_child(_mound)

func _add_mound_dome(mat: StandardMaterial3D, radius: float, y_squash: float, pos: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.scale = Vector3(1.0, y_squash, 1.0)
	mi.position = pos + Vector3(0.0, radius * y_squash * 0.35, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mound.add_child(mi)

func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta
	rotate_y(delta * SPIN_SPEED)
	position.y = 0.55 + sin(_bob_time * 1.4) * 0.12
	# Pin the mound to the snow while the sword bobs above it.
	_mound.global_position.y = 0.0

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
