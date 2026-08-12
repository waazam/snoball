extends "res://scripts/enemies/Enemy.gd"
## Rogue Elf: identical chase/throw AI to the base Enemy.gd - the only
## gameplay difference is a colorful confetti burst on death (via the
## _spawn_death_fx hook) instead of just the plain shrink-fade every other
## enemy gets, since a mischievous elf popping into confetti reads better
## than a somber vanish.
##
## Visually this script dresses the hand-placed rig from EnemyElf.tscn in
## the full "Alpenglow Dusk" workshop outfit: elf-green tunic (forced over
## the DB tint - visual only), skirt with a white hem, black belt with a
## gold buckle, candy-striped stockings, curl-toed green shoes with bell
## tips, red mittens with white cuffs, and a white collar. Stripe rings and
## shoes are parented under the existing hip pivots (and mittens under the
## shoulder pivots) so the base run cycle animates them for free.

const CONFETTI_SCRIPT := preload("res://scripts/effects/ConfettiPiece.gd")
# Ember-family confetti (art-direction palette): EMBER_RED, EMBER_GREEN,
# EMBER_GOLD, trim white, FX_XP ice blue.
const CONFETTI_COLORS := [
	Color(0.91, 0.282, 0.247),   # #E8483F
	Color(0.31, 0.749, 0.42),    # #4FBF6B
	Color(1.0, 0.722, 0.302),    # #FFB84D
	Color(0.961, 0.937, 0.902),  # #F5EFE6
	Color(0.498, 0.847, 1.0),    # #7FD8FF
]
const CONFETTI_COUNT := 22
const CONFETTI_SPEED_MIN := 2.0
const CONFETTI_SPEED_MAX := 5.5

# Master-palette colors (hex comments are the normative values).
const TUNIC_GREEN := Color(0.18, 0.49, 0.275)   # elf green #2E7D46
const STRIPE_WHITE := Color(0.961, 0.937, 0.902)  # trim #F5EFE6
const MITTEN_RED := Color(0.91, 0.282, 0.247)   # EMBER_RED #E8483F
const BUCKLE_GOLD := Color(1.0, 0.722, 0.302)   # EMBER_GOLD #FFB84D

func _ready() -> void:
	super._ready()
	_build_outfit()

## The DB tint drives _body_mat (the tunic capsule); pin it to elf green
## per the art direction ("elf goes green, replaces grape purple") and give
## it the matte cloth convention. _body_base_color follows so the hit-flash
## still fades back to the right color. Purely visual - no stat is touched.
func setup(id: String, wave: int) -> void:
	super.setup(id, wave)
	_body_base_color = TUNIC_GREEN
	_body_mat.albedo_color = TUNIC_GREEN
	_body_mat.roughness = 0.8

func _build_outfit() -> void:
	# White collar ring where the head meets the tunic.
	_add_cylinder(self, Vector3(0, 1.1, 0), 0.115, 0.14, 0.05, STRIPE_WHITE, 0.9)
	# Tunic skirt flaring below the belt, with a white hem band.
	_add_cylinder(self, Vector3(0, 0.66, 0), 0.145, 0.205, 0.12, TUNIC_GREEN, 0.8)
	_add_cylinder(self, Vector3(0, 0.607, 0), 0.2, 0.21, 0.03, STRIPE_WHITE, 0.9)
	# Gold buckle on the front of the belt - the elf's single metallic bit.
	var buckle := _add_box(self, Vector3(0, 0.72, -0.15), Vector3.ZERO, Vector3(0.07, 0.055, 0.025), BUCKLE_GOLD, 0.35)
	var buckle_mat := buckle.material_override as StandardMaterial3D
	buckle_mat.metallic = 0.9

	# Candy-striped stockings + curl-toed shoes, parented under the hip
	# pivots so the run cycle swings them with the legs. The leg cylinder
	# itself is stocking-red (scene material); these white rings turn it
	# into stripes.
	for hip in [left_hip, right_hip]:
		if hip == null:
			continue
		for stripe_y in [-0.16, -0.3, -0.44]:
			_add_cylinder(hip, Vector3(0, stripe_y, 0), 0.063, 0.063, 0.055, STRIPE_WHITE, 0.8)
		# Shoe: boxy foot, cone toe pointing forward, gold bell on the curl.
		_add_box(hip, Vector3(0, -0.6, -0.03), Vector3.ZERO, Vector3(0.09, 0.07, 0.16), TUNIC_GREEN, 0.8)
		var toe := _add_cylinder(hip, Vector3(0, -0.6, -0.17), 0.008, 0.044, 0.13, TUNIC_GREEN, 0.8)
		toe.rotation_degrees = Vector3(-80, 0, 0)  # tip forward and slightly up (the curl)
		var bell := _add_sphere(hip, Vector3(0, -0.575, -0.24), 0.026, BUCKLE_GOLD, 0.35)
		var bell_mat := bell.material_override as StandardMaterial3D
		bell_mat.metallic = 0.9

	# Mittens under the shoulder pivots: white cuff, red hand.
	for sh in [left_shoulder, right_shoulder]:
		if sh == null:
			continue
		_add_cylinder(sh, Vector3(0, -0.46, 0), 0.05, 0.054, 0.05, STRIPE_WHITE, 0.9)
		_add_sphere(sh, Vector3(0, -0.53, 0), 0.06, MITTEN_RED, 0.8)

func _make_outfit_mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _add_sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, roughness: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_outfit_mat(color, roughness)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_cylinder(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float, height: float, color: Color, roughness: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_outfit_mat(color, roughness)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_box(parent: Node3D, pos: Vector3, rot_deg: Vector3, size: Vector3, color: Color, roughness: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_outfit_mat(color, roughness)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

func _spawn_death_fx() -> void:
	var origin: Vector3 = health_bar.global_position - Vector3(0, 0.3, 0)
	for i in CONFETTI_COUNT:
		var piece := MeshInstance3D.new()
		piece.set_script(CONFETTI_SCRIPT)
		get_tree().current_scene.add_child(piece)
		piece.global_position = origin
		var dir: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 1.0), randf_range(-1.0, 1.0)).normalized()
		var speed: float = randf_range(CONFETTI_SPEED_MIN, CONFETTI_SPEED_MAX)
		piece.setup(dir * speed, CONFETTI_COLORS[randi() % CONFETTI_COLORS.size()])
