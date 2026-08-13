extends "res://scripts/enemies/Enemy.gd"
## Snowman enemy: doesn't melee and doesn't throw an endless stream of
## snowballs like the elf - instead it has a fixed "ammo" of its own body
## parts (3 coal buttons, its carrot nose, 2 coal eyes, then its top hat
## last) and throws exactly one per attack tick, in that order, visually
## losing the corresponding part each time so its body reads as getting
## stripped down. Each throw is a two-part animation on one of its twig
## arms (_wind_up_and_throw) - reach up as if gripping the next part off
## its own body, then whip forward and release - and the part itself lobs
## in an arc to a ground point near the player rather than a direct hit,
## bursting there in an alternating red/green/gold AoE blast (see
## BURST_COLORS/_launch_part/_spawn_ground_burst). The last part (the top
## hat) gets a much bigger burst, and its resolution chains straight into
## _detonate() - the snowman's own self-destruct explosion - instead of
## waiting for one more idle attack tick once it's out of parts.
##
## The body's three snowball tiers, collision, health bar and throw point
## are hand-placed in EnemySnowman.tscn like the elf/reindeer rigs; every
## detachable bit (buttons, nose, eyes, pipe, stick arms, hat) is built
## here in code instead, so the throw sequence can just hold direct node
## references and so the hat can reuse HatVisuals' existing top-hat mesh
## instead of a second hand-authored copy of it.
##
## Visuals follow the "Alpenglow Dusk" art direction: SNOW_LIT body with a
## cold rim edge, coal #26221F, carrot #E8763A, WOOD_BARK twig arms ending
## in EMBER_RED mittens, an EMBER_RED scarf, a coal-bit smile and brows,
## and a per-instance top-hat variation (tilt + occasional pine-green hat +
## a holly sprig on the band).

## SNOWBALL_SCENE_PATH is inherited from Enemy.gd - redeclaring it here is a
## parse error (GDScript doesn't allow shadowing a parent class member).

# Master-palette colors (hex comments are the normative values).
const SNOW_WHITE := Color(0.918, 0.949, 0.984)   # SNOW_LIT #EAF2FB
const COAL_COLOR := Color(0.149, 0.133, 0.122)   # coal #26221F
const CARROT_COLOR := Color(0.91, 0.463, 0.227)  # carrot #E8763A
const STICK_COLOR := Color(0.29, 0.2, 0.145)     # WOOD_BARK #4A3325
const HAT_COLOR := Color(0.149, 0.133, 0.122)    # coal #26221F
const HAT_GREEN := Color(0.11, 0.239, 0.141)     # PINE_DARK #1C3D24 (variant)
const SCARF_RED := Color(0.91, 0.282, 0.247)     # EMBER_RED #E8483F
const MITTEN_RED := Color(0.91, 0.282, 0.247)    # EMBER_RED #E8483F
const TRIM_WHITE := Color(0.961, 0.937, 0.902)   # trim #F5EFE6
const HOLLY_GREEN := Color(0.227, 0.42, 0.259)   # PINE_LIT #3A6B42
const PIPE_STEM_COLOR := Color(0.29, 0.2, 0.145) # WOOD_BARK #4A3325
const PIPE_BOWL_COLOR := Color(0.851, 0.776, 0.659)  # warm tan #D9C6A8
const EMBER_GOLD := Color(1.0, 0.721569, 0.301961)   # EMBER_GOLD #FFB84D

const HEAD_Y := 1.35
const HEAD_RADIUS := 0.22

const EXPLOSION_RADIUS := 3.0
const EXPLOSION_DAMAGE_MULT := 1.5  # relative to `damage`, so wave-scaling still applies

# Ground-burst colors each thrown part explodes in, cycling by throw index
# (SCARF_RED/HOLLY_GREEN/EMBER_GOLD are already-established palette colors -
# reused here rather than inventing new ones) - independent of the part's
# own color, which the flying object itself still carries.
const BURST_COLORS: Array[Color] = [SCARF_RED, HOLLY_GREEN, EMBER_GOLD]
const BURST_RADIUS := 2.2
const BURST_DAMAGE_MULT := 0.65   # relative to `damage`, per normal throw - an AoE lands more easily than the old direct hit did, so it hits softer
const FINAL_BURST_RADIUS := 4.2   # the top hat's finale burst - see _launch_part
const FINAL_BURST_DAMAGE_MULT := 1.6
const THROW_ARC_HEIGHT := 2.2
const FINAL_ARC_HEIGHT := 3.2
const FLIGHT_TIME := 0.5
const FINAL_FLIGHT_TIME := 0.65

# Wind-up/throw/return timings for _wind_up_and_throw - kept comfortably
# under the snowman's 1.4s attack_cooldown (EnemyDB.gd) so consecutive
# attacks never cut an in-progress arm animation short.
const WINDUP_TIME := 0.18
const THROW_TIME := 0.12
const RETURN_TIME := 0.22

# Filled in _ready(): [{"part": Node3D, "color": Color}, ...] in throw order
# (buttons top-to-bottom, then carrot, then eyes, then hat last).
var _ammo: Array = []
var _throw_index: int = 0
var _detonated: bool = false
var _hat_color: Color = HAT_COLOR  # per-instance variation, picked in _build_face_and_hat()

# Shoulder pivots saved off _build_arms() so _wind_up_and_throw can tween
# them - see that function's own comment for why they're safe to animate
# freely (named so Enemy.gd's base run-cycle never touches them).
var _arm_left: Node3D
var _arm_right: Node3D
var _arm_tween: Tween

func _ready() -> void:
	super._ready()
	_build_face_and_hat()

## Snow-material convention from the art direction: high roughness plus a
## subtle rim so the snow body catches a cold sparkle-edge against the dusk.
## Applied to the DB-driven body material on top of Enemy.setup()'s defaults;
## purely visual, no stat is touched.
func setup(id: String, wave: int) -> void:
	super.setup(id, wave)
	_body_base_color = SNOW_WHITE
	_body_mat.albedo_color = SNOW_WHITE
	_body_mat.roughness = 0.92
	_body_mat.rim_enabled = true
	_body_mat.rim = 0.25
	_body_mat.rim_tint = 0.8

func _build_face_and_hat() -> void:
	var button_top := _add_sphere(Vector3(0, 1.06, -0.28), 0.05, COAL_COLOR, 0.65)
	var button_mid := _add_sphere(Vector3(0, 0.93, -0.3), 0.05, COAL_COLOR, 0.65)
	var button_bottom := _add_sphere(Vector3(0, 0.8, -0.28), 0.05, COAL_COLOR, 0.65)

	# Long and skinny - base kept roughly where a normal-length carrot's base
	# would sit (embedded slightly into the head) but stretched way out past
	# the usual tip point for a comically long carrot nose.
	var nose := _add_cone(Vector3(0, HEAD_Y - 0.02, -HEAD_RADIUS - 0.19), 0.05, 0.42, CARROT_COLOR, 0.85)

	var eye_left := _add_sphere(Vector3(-0.08, HEAD_Y + 0.06, -HEAD_RADIUS - 0.01), 0.03, COAL_COLOR, 0.65)
	var eye_right := _add_sphere(Vector3(0.08, HEAD_Y + 0.06, -HEAD_RADIUS - 0.01), 0.03, COAL_COLOR, 0.65)

	_build_brows_and_smile()
	_build_scarf()

	# HatVisuals sizes everything against its own HEAD_RADIUS (0.15, the
	# player's head) and anchors the hat's origin at the top of that head -
	# scaling the whole returned Node3D up to this snowman's bigger head
	# keeps every part (brim/band/crown) proportional without re-tuning them.
	# Per-instance variation: mostly the classic coal-black topper, sometimes
	# a pine-green one, always worn at a slightly jaunty random tilt, with a
	# little holly sprig pinned to the band.
	_hat_color = HAT_COLOR if randf() > 0.3 else HAT_GREEN
	var hat := HatVisuals.build("top_hat", _hat_color)
	hat.name = "Hat"
	hat.scale = Vector3.ONE * (HEAD_RADIUS / HatVisuals.HEAD_RADIUS) * 1.05
	add_child(hat)
	hat.position = Vector3(0, HEAD_Y + HEAD_RADIUS * 0.98, 0)
	hat.rotation_degrees = Vector3(0, 0, randf_range(-8.0, 8.0))
	_decorate_hat(hat)

	_build_pipe()
	_build_arms()

	_ammo = [
		{"part": button_top, "color": COAL_COLOR},
		{"part": button_mid, "color": COAL_COLOR},
		{"part": button_bottom, "color": COAL_COLOR},
		{"part": nose, "color": CARROT_COLOR},
		{"part": eye_left, "color": COAL_COLOR},
		{"part": eye_right, "color": COAL_COLOR},
		{"part": hat, "color": _hat_color},
	]

func _make_mat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _add_sphere(pos: Vector3, radius: float, color: Color, roughness: float = 0.85) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_mat(color, roughness)
	mi.position = pos
	add_child(mi)
	return mi

func _add_box(parent: Node3D, pos: Vector3, rot_deg: Vector3, size: Vector3, color: Color, roughness: float = 0.85) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_mat(color, roughness)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

## A tapered cylinder (cone) rotated to point along -Z, i.e. straight out
## of the face - used for the carrot nose.
func _add_cone(pos: Vector3, base_radius: float, length: float, color: Color, roughness: float = 0.85) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.006
	mesh.bottom_radius = base_radius
	mesh.height = length
	mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_mat(color, roughness)
	mi.position = pos
	mi.rotation_degrees = Vector3(-90, 0, 0)
	add_child(mi)
	return mi

## Grumpy-charming coal face furniture: two angled brow chunks above the
## eyes and a four-bit coal smile arcing under the nose. Decorative only,
## never thrown - so a stripped snowman keeps its expression to the end,
## which reads even funnier once the eyes are gone. Each bit's Z is solved
## against the head sphere so the coal sits on the surface, not in it.
func _build_brows_and_smile() -> void:
	for side in [-1, 1]:
		_add_box(self, Vector3(0.085 * side, HEAD_Y + 0.115, -0.183), Vector3(0, 0, -14 * side), Vector3(0.075, 0.02, 0.022), COAL_COLOR, 0.65)
	var smile_points := [Vector2(-0.078, -0.075), Vector2(-0.028, -0.095), Vector2(0.028, -0.095), Vector2(0.078, -0.075)]
	for p in smile_points:
		var z := -sqrt(maxf(HEAD_RADIUS * HEAD_RADIUS - p.y * p.y - p.x * p.x, 0.0)) - 0.008
		_add_sphere(Vector3(p.x, HEAD_Y + p.y, z), 0.02, COAL_COLOR, 0.65)

## EMBER_RED scarf where the head meets the middle ball: a flat torus wrap
## plus a hanging tail with a TRIM_WHITE stripe near its end. Cloth
## convention - matte, no rim.
func _build_scarf() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.13
	torus.outer_radius = 0.27
	torus.rings = 10
	torus.ring_segments = 6
	var wrap := MeshInstance3D.new()
	wrap.mesh = torus
	wrap.material_override = _make_mat(SCARF_RED, 0.8)
	wrap.position = Vector3(0, 1.17, 0)
	add_child(wrap)
	# Tail hangs down the front-left of the chest, tilted so its lower end
	# swings clear of the middle ball's curvature instead of sinking into it.
	var tail := _add_box(self, Vector3(0.13, 0.98, -0.3), Vector3(10, 0, -8), Vector3(0.1, 0.28, 0.03), SCARF_RED, 0.8)
	_add_box(tail, Vector3(0, -0.11, 0), Vector3.ZERO, Vector3(0.102, 0.03, 0.034), TRIM_WHITE, 0.85)

## A holly sprig pinned to the hat band: two pine-green leaves and two red
## berries. Positions are in the hat's own local space (HatVisuals scale,
## band sits at local y ~0.035, radius ~0.17), so the hat's random tilt and
## the throw-hide both carry the sprig along for free.
func _decorate_hat(hat: Node3D) -> void:
	for i in [-1, 1]:
		_add_box(hat, Vector3(0.035 * i, 0.05, -0.165), Vector3(12, 30 * i, 0), Vector3(0.055, 0.008, 0.028), HOLLY_GREEN, 0.85)
	for berry_pos in [Vector3(-0.012, 0.06, -0.172), Vector3(0.018, 0.055, -0.175)]:
		var berry := SphereMesh.new()
		berry.radius = 0.014
		berry.height = 0.028
		berry.radial_segments = 6
		berry.rings = 4
		var berry_mi := MeshInstance3D.new()
		berry_mi.mesh = berry
		berry_mi.material_override = _make_mat(SCARF_RED, 0.6)
		berry_mi.position = berry_pos
		hat.add_child(berry_mi)

## A corncob pipe jutting out and down from the mouth: a dark stem with a
## lighter, chunkier bowl at the end. Purely decorative - never thrown.
func _build_pipe() -> void:
	var stem := CylinderMesh.new()
	stem.top_radius = 0.014
	stem.bottom_radius = 0.02
	stem.height = 0.2
	var stem_mi := MeshInstance3D.new()
	stem_mi.mesh = stem
	stem_mi.material_override = _make_mat(PIPE_STEM_COLOR, 0.9)
	stem_mi.position = Vector3(0.1, HEAD_Y - 0.09, -HEAD_RADIUS + 0.05)
	stem_mi.rotation_degrees = Vector3(-65, 0, 25)
	add_child(stem_mi)

	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.038
	bowl.bottom_radius = 0.032
	bowl.height = 0.07
	var bowl_mi := MeshInstance3D.new()
	bowl_mi.mesh = bowl
	bowl_mi.material_override = _make_mat(PIPE_BOWL_COLOR, 0.85)
	bowl_mi.position = Vector3(0.19, HEAD_Y - 0.2, -HEAD_RADIUS - 0.06)
	bowl_mi.rotation_degrees = Vector3(15, 0, 25)
	add_child(bowl_mi)

## Skinny twig arms angled up and out from the torso, each with a knobbly
## side-sprig partway up and an EMBER_RED mitten (with a TRIM_WHITE cuff and
## a little thumb) pulled over the tip - someone dressed this snowman
## warmly. Named distinctly from "LeftShoulder"/"RightShoulder" so
## Enemy.gd's run-cycle animation (which looks those up by name) leaves
## them alone - a snowman's stick arms shouldn't swing like a biped's.
func _build_arms() -> void:
	for side in [-1, 1]:
		var shoulder := Node3D.new()
		shoulder.name = "ArmLeft" if side < 0 else "ArmRight"
		shoulder.position = Vector3(0.34 * side, 0.98, 0)
		shoulder.rotation_degrees = Vector3(0, 0, 40 * side)
		add_child(shoulder)
		if side < 0:
			_arm_left = shoulder
		else:
			_arm_right = shoulder

		var stick := CylinderMesh.new()
		stick.top_radius = 0.018
		stick.bottom_radius = 0.026
		stick.height = 0.5
		var stick_mi := MeshInstance3D.new()
		stick_mi.mesh = stick
		stick_mi.material_override = _make_mat(STICK_COLOR, 0.9)
		stick_mi.position = Vector3(0, 0.25, 0)
		shoulder.add_child(stick_mi)

		# Broken-off side sprig partway up the twig, so the arm still reads
		# as a found branch rather than a smooth dowel.
		var sprig := CylinderMesh.new()
		sprig.top_radius = 0.006
		sprig.bottom_radius = 0.013
		sprig.height = 0.14
		var sprig_mi := MeshInstance3D.new()
		sprig_mi.mesh = sprig
		sprig_mi.material_override = _make_mat(STICK_COLOR, 0.9)
		sprig_mi.position = Vector3(0.045 * side, 0.3, 0)
		sprig_mi.rotation_degrees = Vector3(0, 0, 38 * side)
		shoulder.add_child(sprig_mi)

		# Mitten: cuff ring, hand ball, thumb nub.
		var cuff := CylinderMesh.new()
		cuff.top_radius = 0.042
		cuff.bottom_radius = 0.046
		cuff.height = 0.05
		var cuff_mi := MeshInstance3D.new()
		cuff_mi.mesh = cuff
		cuff_mi.material_override = _make_mat(TRIM_WHITE, 0.95)
		cuff_mi.position = Vector3(0, 0.47, 0)
		shoulder.add_child(cuff_mi)

		var hand := SphereMesh.new()
		hand.radius = 0.055
		hand.height = 0.11
		hand.radial_segments = 8
		hand.rings = 5
		var hand_mi := MeshInstance3D.new()
		hand_mi.mesh = hand
		hand_mi.material_override = _make_mat(MITTEN_RED, 0.8)
		hand_mi.position = Vector3(0, 0.53, 0)
		shoulder.add_child(hand_mi)

		var thumb := SphereMesh.new()
		thumb.radius = 0.026
		thumb.height = 0.052
		thumb.radial_segments = 6
		thumb.rings = 4
		var thumb_mi := MeshInstance3D.new()
		thumb_mi.mesh = thumb
		thumb_mi.material_override = _make_mat(MITTEN_RED, 0.8)
		thumb_mi.position = Vector3(0, 0.52, -0.05)
		shoulder.add_child(thumb_mi)

## Overrides Enemy.gd's normal melee-or-repeat-throw behavior entirely -
## one body part per attack tick, in order, then detonate once the ammo
## list is empty (a fallback only - the last/hat throw normally chains
## straight into _detonate() itself once its burst resolves, see
## _resolve_ground_burst, so this branch shouldn't fire in the normal case).
func _attack(player: Node3D) -> void:
	if _detonated:
		return
	if _throw_index >= _ammo.size():
		_detonate()
		return
	var index := _throw_index
	_throw_index += 1
	_wind_up_and_throw(player, _ammo[index], index)

## Wind-up (the throwing arm reaches up and across the body, as if
## gripping the next part off itself), throw (whips forward and releases -
## _launch_part fires exactly at the top of this leg, so the part visibly
## leaves the hand mid-swing), then a return to the resting pose. Alternates
## left/right arm by throw index purely for visual variety - every part is
## central or symmetric enough that either arm reads fine grabbing it.
func _wind_up_and_throw(player: Node3D, part_data: Dictionary, index: int) -> void:
	var arm: Node3D = _arm_left if index % 2 == 0 else _arm_right
	if not is_instance_valid(arm):
		_launch_part(player, part_data, index)
		return
	var side: float = -1.0 if arm == _arm_left else 1.0
	var rest := Vector3(0.0, 0.0, 40.0 * side)
	var windup := Vector3(-100.0, 0.0, 15.0 * side)
	var release := Vector3(80.0, 0.0, 55.0 * side)

	if _arm_tween and _arm_tween.is_valid():
		_arm_tween.kill()
	arm.rotation_degrees = rest
	_arm_tween = create_tween()
	_arm_tween.tween_property(arm, "rotation_degrees", windup, WINDUP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_arm_tween.tween_property(arm, "rotation_degrees", release, THROW_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_arm_tween.tween_callback(_launch_part.bind(player, part_data, index))
	_arm_tween.tween_property(arm, "rotation_degrees", rest, RETURN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Fires the given ammo part on a lobbed arc toward a ground point near the
## player - not a direct hit, it's meant to land and burst in an AoE, so a
## little jitter keeps it dodgeable even after the wind-up telegraph. Owns
## its own tween on the flying mesh (not on self) so an already-airborne
## part still lands and bursts even if the snowman dies to other damage
## mid-flight. The final ammo item (the hat) flies bigger/slower/higher for
## extra drama and its burst is what actually triggers _detonate().
func _launch_part(player: Node3D, part_data: Dictionary, index: int) -> void:
	var part_node: Node3D = part_data["part"]
	var start: Vector3 = part_node.global_position if is_instance_valid(part_node) else throw_point.global_position
	if is_instance_valid(part_node):
		part_node.visible = false
	if not is_instance_valid(player):
		return

	var is_final: bool = index == _ammo.size() - 1
	var jitter := Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
	var target: Vector3 = Vector3(player.global_position.x, 0.05, player.global_position.z) + jitter
	var radius: float = FINAL_BURST_RADIUS if is_final else BURST_RADIUS
	var dmg_mult: float = FINAL_BURST_DAMAGE_MULT if is_final else BURST_DAMAGE_MULT
	var arc_height: float = FINAL_ARC_HEIGHT if is_final else THROW_ARC_HEIGHT
	var flight_time: float = FINAL_FLIGHT_TIME if is_final else FLIGHT_TIME
	var color: Color = BURST_COLORS[index % BURST_COLORS.size()]

	var mesh := SphereMesh.new()
	mesh.radius = 0.2 if is_final else 0.13
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
	var flying := MeshInstance3D.new()
	flying.mesh = mesh
	flying.material_override = _make_mat(part_data["color"], 0.7)
	get_tree().current_scene.add_child(flying)
	flying.global_position = start

	var tw := flying.create_tween()
	tw.tween_method(_update_flight_position.bind(flying, start, target, arc_height), 0.0, 1.0, flight_time)
	tw.tween_callback(_resolve_ground_burst.bind(player, target, color, radius, dmg_mult, is_final))
	tw.tween_callback(flying.queue_free)

func _update_flight_position(t: float, mesh: Node3D, start: Vector3, target: Vector3, arc_height: float) -> void:
	if not is_instance_valid(mesh):
		return
	var pos: Vector3 = start.lerp(target, t)
	pos.y += sin(t * PI) * arc_height
	mesh.global_position = pos

## Where a thrown part actually lands: one distance-gated hit on the player
## if they're still standing in the blast, then the colored ground burst.
## The final (hat) burst's on_complete chains straight into _detonate().
func _resolve_ground_burst(player: Node3D, pos: Vector3, color: Color, radius: float, dmg_mult: float, is_final: bool) -> void:
	if is_instance_valid(player) and player.global_position.distance_to(pos) <= radius and player.has_method("take_hit"):
		player.take_hit(damage * dmg_mult)
	_spawn_ground_burst(pos, color, radius, _detonate if is_final else Callable())

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

## A quick expanding, fading snow-white puff - independent of this node
## (added to current_scene, own tween) so it finishes playing even though
## the snowman itself is about to be freed by _die()'s shrink tween.
func _spawn_explosion_fx() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.918, 0.949, 0.984, 0.85)  # SNOW_LIT #EAF2FB
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

## One thrown part's ground-impact burst: an expanding, fading colored puff
## at the landing point - same "own tween on the puff itself, added to
## current_scene" idiom as _spawn_explosion_fx above, just colorized
## (BURST_COLORS, cycled by throw index in _launch_part) and radius-scaled
## per throw. on_complete (only wired for the final/hat throw, straight
## into _detonate) fires once the puff finishes playing, so the finale
## reads as one continuous escalation rather than an extra idle attack tick.
func _spawn_ground_burst(pos: Vector3, color: Color, radius: float, on_complete: Callable = Callable()) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.15
	mi.scale = Vector3.ZERO
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(mi.queue_free)
	if on_complete.is_valid():
		tw.tween_callback(on_complete)
