extends "res://scripts/enemies/Enemy.gd"
## Snowman enemy: doesn't melee and doesn't throw an endless stream of
## snowballs like the elf - instead it has a fixed "ammo" of its own body
## parts (3 coal buttons, its carrot nose, 2 coal eyes, then its top hat
## last) and throws exactly one per attack tick, in that order, visually
## losing the corresponding part each time so its body reads as getting
## stripped down. Once the top hat is gone it has nothing left to throw,
## so instead of attacking again it detonates - a medium-radius explosion
## that damages the player if they're in range and kills the snowman
## outright.
##
## The body's three snowball tiers, collision, health bar and throw point
## are hand-placed in EnemySnowman.tscn like the elf/reindeer rigs; every
## detachable bit (buttons, nose, eyes, pipe, stick arms, hat) is built
## here in code instead, so the throw sequence can just hold direct node
## references and so the hat can reuse HatVisuals' existing top-hat mesh
## instead of a second hand-authored copy of it.

## SNOWBALL_SCENE_PATH is inherited from Enemy.gd - redeclaring it here is a
## parse error (GDScript doesn't allow shadowing a parent class member).

const COAL_COLOR := Color(0.08, 0.08, 0.09)
const CARROT_COLOR := Color(0.85, 0.42, 0.08)
const STICK_COLOR := Color(0.32, 0.22, 0.14)
const HAT_COLOR := Color(0.1, 0.1, 0.12)
const PIPE_STEM_COLOR := Color(0.25, 0.16, 0.1)
const PIPE_BOWL_COLOR := Color(0.82, 0.68, 0.42)

const HEAD_Y := 1.35
const HEAD_RADIUS := 0.22

const EXPLOSION_RADIUS := 3.0
const EXPLOSION_DAMAGE_MULT := 1.5  # relative to `damage`, so wave-scaling still applies
const THROW_SPEED := 15.0

# Filled in _ready(): [{"part": Node3D, "color": Color}, ...] in throw order
# (buttons top-to-bottom, then carrot, then eyes, then hat last).
var _ammo: Array = []
var _throw_index: int = 0
var _detonated: bool = false

func _ready() -> void:
	super._ready()
	_build_face_and_hat()

func _build_face_and_hat() -> void:
	var button_top := _add_sphere(Vector3(0, 1.06, -0.28), 0.045, COAL_COLOR)
	var button_mid := _add_sphere(Vector3(0, 0.93, -0.3), 0.045, COAL_COLOR)
	var button_bottom := _add_sphere(Vector3(0, 0.8, -0.28), 0.045, COAL_COLOR)

	# Long and skinny - base kept roughly where a normal-length carrot's base
	# would sit (embedded slightly into the head) but stretched way out past
	# the usual tip point for a comically long carrot nose.
	var nose := _add_cone(Vector3(0, HEAD_Y - 0.02, -HEAD_RADIUS - 0.19), 0.05, 0.42, CARROT_COLOR)

	var eye_left := _add_sphere(Vector3(-0.08, HEAD_Y + 0.06, -HEAD_RADIUS - 0.01), 0.03, COAL_COLOR)
	var eye_right := _add_sphere(Vector3(0.08, HEAD_Y + 0.06, -HEAD_RADIUS - 0.01), 0.03, COAL_COLOR)

	# HatVisuals sizes everything against its own HEAD_RADIUS (0.15, the
	# player's head) and anchors the hat's origin at the top of that head -
	# scaling the whole returned Node3D up to this snowman's bigger head
	# keeps every part (brim/band/crown) proportional without re-tuning them.
	var hat := HatVisuals.build("top_hat", HAT_COLOR)
	hat.name = "Hat"
	hat.scale = Vector3.ONE * (HEAD_RADIUS / HatVisuals.HEAD_RADIUS) * 1.05
	add_child(hat)
	hat.position = Vector3(0, HEAD_Y + HEAD_RADIUS * 0.98, 0)

	_build_pipe()
	_build_arms()

	_ammo = [
		{"part": button_top, "color": COAL_COLOR},
		{"part": button_mid, "color": COAL_COLOR},
		{"part": button_bottom, "color": COAL_COLOR},
		{"part": nose, "color": CARROT_COLOR},
		{"part": eye_left, "color": COAL_COLOR},
		{"part": eye_right, "color": COAL_COLOR},
		{"part": hat, "color": HAT_COLOR},
	]

func _add_sphere(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

## A tapered cylinder (cone) rotated to point along -Z, i.e. straight out
## of the face - used for the carrot nose.
func _add_cone(pos: Vector3, base_radius: float, length: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.006
	mesh.bottom_radius = base_radius
	mesh.height = length
	mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = Vector3(-90, 0, 0)
	add_child(mi)
	return mi

## A corncob pipe jutting out and down from the mouth: a dark stem with a
## lighter, chunkier bowl at the end. Purely decorative - never thrown.
func _build_pipe() -> void:
	var stem := CylinderMesh.new()
	stem.top_radius = 0.014
	stem.bottom_radius = 0.02
	stem.height = 0.2
	var stem_mi := MeshInstance3D.new()
	stem_mi.mesh = stem
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = PIPE_STEM_COLOR
	stem_mi.material_override = stem_mat
	stem_mi.position = Vector3(0.1, HEAD_Y - 0.09, -HEAD_RADIUS + 0.05)
	stem_mi.rotation_degrees = Vector3(-65, 0, 25)
	add_child(stem_mi)

	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.038
	bowl.bottom_radius = 0.032
	bowl.height = 0.07
	var bowl_mi := MeshInstance3D.new()
	bowl_mi.mesh = bowl
	var bowl_mat := StandardMaterial3D.new()
	bowl_mat.albedo_color = PIPE_BOWL_COLOR
	bowl_mi.material_override = bowl_mat
	bowl_mi.position = Vector3(0.19, HEAD_Y - 0.2, -HEAD_RADIUS - 0.06)
	bowl_mi.rotation_degrees = Vector3(15, 0, 25)
	add_child(bowl_mi)

## Skinny stick arms angled up and out from the torso, each forking into
## two thinner twigs at the tip instead of a hand. Named distinctly from
## "LeftShoulder"/"RightShoulder" so Enemy.gd's run-cycle animation (which
## looks those up by name) leaves them alone - a snowman's stick arms
## shouldn't swing like a biped's.
func _build_arms() -> void:
	for side in [-1, 1]:
		var shoulder := Node3D.new()
		shoulder.name = "ArmLeft" if side < 0 else "ArmRight"
		shoulder.position = Vector3(0.34 * side, 0.98, 0)
		shoulder.rotation_degrees = Vector3(0, 0, 40 * side)
		add_child(shoulder)

		var stick := CylinderMesh.new()
		stick.top_radius = 0.018
		stick.bottom_radius = 0.026
		stick.height = 0.5
		var stick_mi := MeshInstance3D.new()
		stick_mi.mesh = stick
		var stick_mat := StandardMaterial3D.new()
		stick_mat.albedo_color = STICK_COLOR
		stick_mi.material_override = stick_mat
		stick_mi.position = Vector3(0, 0.25, 0)
		shoulder.add_child(stick_mi)

		for fork_side in [-1, 1]:
			var fork := CylinderMesh.new()
			fork.top_radius = 0.006
			fork.bottom_radius = 0.014
			fork.height = 0.16
			var fork_mi := MeshInstance3D.new()
			fork_mi.mesh = fork
			var fork_mat := StandardMaterial3D.new()
			fork_mat.albedo_color = STICK_COLOR
			fork_mi.material_override = fork_mat
			fork_mi.position = Vector3(0, 0.5, 0)
			fork_mi.rotation_degrees = Vector3(0, 0, 22 * fork_side)
			shoulder.add_child(fork_mi)

## Overrides Enemy.gd's normal melee-or-repeat-throw behavior entirely -
## one body part per attack tick, in order, then detonate once the ammo
## list is empty.
func _attack(player: Node3D) -> void:
	if _detonated:
		return
	if _throw_index >= _ammo.size():
		_detonate()
		return
	_throw_part(player, _ammo[_throw_index])
	_throw_index += 1

func _throw_part(player: Node3D, part_data: Dictionary) -> void:
	var part_node: Node3D = part_data["part"]
	if is_instance_valid(part_node):
		part_node.visible = false
	var scene: PackedScene = load(SNOWBALL_SCENE_PATH)
	var sb: Area3D = scene.instantiate()
	get_tree().current_scene.add_child(sb)
	sb.global_position = throw_point.global_position
	var dir: Vector3 = (player.global_position + Vector3.UP * 0.9 - throw_point.global_position).normalized()
	var stats := {"damage": damage, "speed": THROW_SPEED, "gravity_scale": 0.7, "radius": 0.16, "pierce": 1}
	sb.setup(dir, stats, false, part_data["color"])

## Out of body parts to throw - goes out in a medium-radius blast instead
## of attacking again. Only the player is checked (matches the prompt:
## "damaging the player if the player is within the radius"), and this
## always kills the snowman regardless of remaining health.
func _detonate() -> void:
	if _detonated or _dead:
		return
	_detonated = true
	var player := _get_player()
	if player and global_position.distance_to(player.global_position) <= EXPLOSION_RADIUS:
		if player.has_method("take_hit"):
			player.take_hit(damage * EXPLOSION_DAMAGE_MULT)
	_spawn_explosion_fx()
	_die()

## A quick expanding, fading white puff plus the shared "implosion" boom
## (see SoundFX.gd) - independent of this node (added to current_scene,
## own tween) so it finishes playing even though the snowman itself is
## about to be freed by _die()'s shrink tween.
func _spawn_explosion_fx() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = global_position + Vector3.UP * 0.7
	mi.scale = Vector3.ZERO
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * EXPLOSION_RADIUS, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)

	var snd := AudioStreamPlayer3D.new()
	snd.stream = SoundFX.get_implosion()
	get_tree().current_scene.add_child(snd)
	snd.global_position = global_position
	snd.finished.connect(snd.queue_free)
	snd.play()
