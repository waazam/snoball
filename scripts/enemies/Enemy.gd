extends CharacterBody3D
## Enemy AI: chases the player, then either melees or (if ranged) throws
## snowballs once in range. Stats come from EnemyDB, scaled by wave number.

const DAMAGE_NUMBER_SCRIPT := preload("res://scripts/effects/DamageNumber.gd")

const GRAVITY := 22.0
const SNOWBALL_SCENE_PATH := "res://scenes/weapons/Snowball.tscn"
const JUMP_VELOCITY := 7.5
const JUMP_INTERVAL_MIN := 3.0
const JUMP_INTERVAL_MAX := 6.0
const DASH_SPEED_MULT := 2.6
const DASH_TIME := 0.22
const DASH_INTERVAL_MIN := 4.0
const DASH_INTERVAL_MAX := 8.0
const EXP_PICKUP_SCENE_PATH := "res://scenes/pickups/ExpPickup.tscn"

# Body-color palette pins (ART_DIRECTION.md section 3). EnemyDB.gd is frozen
# data, so the ids that have no dedicated subtype script (the reindeer scene's
# grunt/brute) get their "Alpenglow Dusk" body colors here instead of from the
# DB's legacy values. Subtype scripts (elf, snowman, santa, yeti) re-pin their
# own colors in their setup() overrides, same pattern.
const BODY_COLOR_OVERRIDES := {
	"grunt": Color("#8A5A38"),  # reindeer warm tan hide
	"brute": Color("#4A3325"),  # elder reindeer - WOOD_BARK, darker than grunt
}

# Footstep audio profile per enemy_id (see _update_footsteps/Footsteps.gd).
# `hz` is steps-per-second at this enemy's own base `speed` (scaled by the
# same moving-speed ratio _update_animation already computes for the visual
# run-cycle, but kept on its own accumulator so tuning footstep pace never
# touches that animation). Quadrupeds (grunt/brute, EnemyReindeer.tscn) get
# a high hz for a busy multi-hoof clatter instead of trying to sync to each
# individual leg's phase; the bosses get a low hz for a slow, heavy, single
# thump instead. `range` (Footsteps.play_step's max_distance) is hand-tuned
# to roughly track each id's EnemyDB scale, per the "bigger enemy = wider
# audible range" ask - snowman/its continuous slide isn't listed here, see
# SNOWMAN_SLIDE_RANGE below, since it has no legs to step with at all
# (EnemySnowman.tscn has no hip/shoulder pivots, unlike every other enemy).
const FOOTSTEP_PROFILES := {
	"grunt":   {"kind": "reindeer", "hz": 6.0,  "volume_db": -3.0, "pitch": 1.08, "pitch_jitter": 0.06, "range": 14.0},
	"brute":   {"kind": "reindeer", "hz": 4.2,  "volume_db": 2.0,  "pitch": 0.82, "pitch_jitter": 0.05, "range": 20.0},
	"thrower": {"kind": "elf",      "hz": 5.2,  "volume_db": -9.0, "pitch": 1.3,  "pitch_jitter": 0.08, "range": 10.0},
	"santa":   {"kind": "santa",    "hz": 1.7,  "volume_db": 5.0,  "pitch": 1.0,  "pitch_jitter": 0.04, "range": 30.0},
	"yeti":    {"kind": "yeti",     "hz": 1.35, "volume_db": 8.0,  "pitch": 0.88, "pitch_jitter": 0.04, "range": 38.0},
}
const SNOWMAN_SLIDE_RANGE := 24.0
const SNOWMAN_SLIDE_VOLUME_DB := -5.0

var enemy_id: String = "grunt"
var max_health: float = 30.0
var health: float = 30.0
var speed: float = 3.5
var damage: float = 8.0
var attack_range: float = 1.7
var attack_cooldown: float = 1.0
var is_ranged: bool = false
var score_value: int = 10

var attack_timer: float = 0.0
var slow_timer: float = 0.0
var slow_factor: float = 1.0
var external_velocity: Vector3 = Vector3.ZERO
var _dead: bool = false

# Bleed (sticks/nails snowballs): a damage-over-time drain plus a trailing
# blood decal. Footprints (piss-ball snowball): no damage, just a trailing
# colored decal. Both share the same GroundTrail decal spawner, just with
# different colors/lifetimes/tick rates.
var _bleed_dps: float = 0.0
var _bleed_timer: float = 0.0
var _bleed_drop_accum: float = 0.0
var _footprint_color: Color = Color(0.85, 0.72, 0.1)
var _footprint_timer: float = 0.0
var _footprint_drop_accum: float = 0.0

var _jump_timer: float = 0.0
var _dash_timer: float = 0.0
var _is_dashing: bool = false
var _dash_time_left: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO

# Hit-reaction state: base scale/color captured at setup() so the punch
# squash and flash tween relative to them instead of clobbering the
# per-enemy size (brutes etc.) or fighting the death-shrink tween.
var _base_scale: Vector3 = Vector3.ONE
var _body_mat: StandardMaterial3D
var _body_base_color: Color = Color.WHITE
var _hit_scale_tween: Tween = null
var _hit_flash_tween: Tween = null

@onready var mesh: MeshInstance3D = $Body
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var health_bar: Node3D = $HealthBar
@onready var health_fill: MeshInstance3D = $HealthBar/Fill
@onready var throw_point: Marker3D = $ThrowPoint

# Optional rig parts, fetched defensively since the two enemy scenes use
# different skeletons: EnemyElf.tscn is a biped (hips + shoulders, like the
# player), EnemyReindeer.tscn is a quadruped (four leg pivots). Whichever
# set resolves to non-null drives _update_animation()'s run cycle.
@onready var left_hip: Node3D = get_node_or_null("LeftHip")
@onready var right_hip: Node3D = get_node_or_null("RightHip")
@onready var left_shoulder: Node3D = get_node_or_null("LeftShoulder")
@onready var right_shoulder: Node3D = get_node_or_null("RightShoulder")
@onready var leg_front_left: Node3D = get_node_or_null("LegFrontLeft")
@onready var leg_front_right: Node3D = get_node_or_null("LegFrontRight")
@onready var leg_back_left: Node3D = get_node_or_null("LegBackLeft")
@onready var leg_back_right: Node3D = get_node_or_null("LegBackRight")

var _anim_time: float = 0.0
var _footstep_time: float = 0.0
var _slide_player: AudioStreamPlayer3D = null

func _ready() -> void:
	add_to_group("enemies")

func setup(id: String, wave: int) -> void:
	enemy_id = id
	var stats: Dictionary = EnemyDB.get_scaled_stats(id, wave)
	max_health = stats.health
	health = max_health
	speed = stats.speed
	damage = stats.damage
	attack_range = stats.attack_range
	attack_cooldown = stats.attack_cooldown
	is_ranged = stats.is_ranged
	score_value = stats.score
	var sc: float = stats.scale
	_base_scale = Vector3(sc, sc, sc)
	scale = _base_scale
	_body_base_color = BODY_COLOR_OVERRIDES.get(id, stats.color)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = _body_base_color
	# Cloth-ish matte default per the art direction (subtypes refine this in
	# their own setup() overrides - snow bodies add rim, fur goes rougher).
	_body_mat.roughness = 0.85
	mesh.material_override = _body_mat
	attack_timer = randf_range(0.0, attack_cooldown)
	_jump_timer = randf_range(JUMP_INTERVAL_MIN, JUMP_INTERVAL_MAX)
	_dash_timer = randf_range(DASH_INTERVAL_MIN, DASH_INTERVAL_MAX)
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if _dead or Game.state != Game.State.PLAYING:
		return
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
	_update_status_effects(delta)
	if _dead:
		return
	var player := _get_player()
	if player == null:
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	if dist > 0.05:
		look_at(global_position + to_player, Vector3.UP)
	_update_dash(delta, to_player, dist)
	if _is_dashing:
		velocity.x = _dash_dir.x * speed * DASH_SPEED_MULT
		velocity.z = _dash_dir.z * speed * DASH_SPEED_MULT
	elif dist > attack_range:
		var dir: Vector3 = to_player.normalized()
		velocity.x = dir.x * speed * slow_factor
		velocity.z = dir.z * speed * slow_factor
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 4.0 * delta)
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			_attack(player)
	var jumped: bool = _update_jump(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif not jumped:
		velocity.y = -1.0
	velocity.x += external_velocity.x
	velocity.z += external_velocity.z
	external_velocity = external_velocity.move_toward(Vector3.ZERO, 20.0 * delta)
	_update_animation(delta)
	move_and_slide()

## Procedural run cycle shared by both rigs. Biped (elf): opposite-phase
## hip/shoulder swing, same as the player. Quadruped (reindeer): diagonal
## trot gait (front-left+back-right together, front-right+back-left
## opposite), which only works because the reindeer's legs are pivot nodes
## with the mesh offset below them, not meshes rotating about their own center.
func _update_animation(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = horizontal_speed > 0.3 and not _dead
	var amp: float = 0.0
	var ratio: float = 0.0
	if moving:
		ratio = clampf(horizontal_speed / maxf(speed, 0.5), 0.4, 2.2)
		_anim_time += delta * 10.0 * ratio
		amp = 0.8
	_update_footsteps(delta, moving, ratio)
	var swing: float = sin(_anim_time) * amp
	var blend: float = clampf(delta * 12.0, 0.0, 1.0)
	if left_hip and right_hip:
		left_hip.rotation.x = lerp_angle(left_hip.rotation.x, swing * 0.7, blend)
		right_hip.rotation.x = lerp_angle(right_hip.rotation.x, -swing * 0.7, blend)
	if left_shoulder and right_shoulder:
		left_shoulder.rotation.x = lerp_angle(left_shoulder.rotation.x, -swing * 0.6, blend)
		right_shoulder.rotation.x = lerp_angle(right_shoulder.rotation.x, swing * 0.6, blend)
	if leg_front_left and leg_front_right and leg_back_left and leg_back_right:
		leg_front_left.rotation.x = lerp_angle(leg_front_left.rotation.x, swing * 0.5, blend)
		leg_back_right.rotation.x = lerp_angle(leg_back_right.rotation.x, swing * 0.5, blend)
		leg_front_right.rotation.x = lerp_angle(leg_front_right.rotation.x, -swing * 0.5, blend)
		leg_back_left.rotation.x = lerp_angle(leg_back_left.rotation.x, -swing * 0.5, blend)

## Footstep audio, driven by FOOTSTEP_PROFILES - a per-id accumulator ticks
## up by hz*ratio (ratio is the same moving-speed multiplier _update_animation
## just used for the visual swing) and fires one Footsteps.play_step per
## whole step crossed, `while` instead of `if` so a large delta spike can't
## lose steps. The snowman has no profile here (no legs, see the
## FOOTSTEP_PROFILES comment) - it gets a continuous slide loop instead.
func _update_footsteps(delta: float, moving: bool, ratio: float) -> void:
	if enemy_id == "snowman":
		_update_slide_audio(moving)
		return
	if not moving or not FOOTSTEP_PROFILES.has(enemy_id):
		return
	var profile: Dictionary = FOOTSTEP_PROFILES[enemy_id]
	_footstep_time += delta * float(profile["hz"]) * ratio
	while _footstep_time >= 1.0:
		_footstep_time -= 1.0
		var pitch: float = float(profile["pitch"]) + randf_range(-1.0, 1.0) * float(profile["pitch_jitter"])
		Footsteps.play_step(profile["kind"], global_position, float(profile["range"]), float(profile["volume_db"]), pitch)

## Snowman-only: starts/stops a looping slide player parented to this body
## (so its position tracks automatically) instead of firing discrete steps -
## it has no hip/shoulder pivots to swing in the first place, matching how
## it visibly glides rather than walks.
func _update_slide_audio(moving: bool) -> void:
	if moving:
		if _slide_player == null:
			_slide_player = Footsteps.make_slide_player(SNOWMAN_SLIDE_RANGE, SNOWMAN_SLIDE_VOLUME_DB)
			add_child(_slide_player)
		if not _slide_player.playing:
			_slide_player.play()
	elif _slide_player and _slide_player.playing:
		_slide_player.stop()

## Random hops while chasing - just a periodic vertical impulse, purely for
## liveliness (also occasionally helps them hop over small ledges/obstacles).
## Returns true the frame it actually launches a jump, so the caller can
## skip the floor-snap reset that would otherwise immediately cancel it.
func _update_jump(delta: float) -> bool:
	_jump_timer -= delta
	if _jump_timer <= 0.0:
		_jump_timer = randf_range(JUMP_INTERVAL_MIN, JUMP_INTERVAL_MAX)
		if is_on_floor() and not _is_dashing:
			velocity.y = JUMP_VELOCITY
			return true
	return false

## Periodic aggressive lunge toward the player while mid-chase (not already
## in attack range), for a burst of speed that's harder to react to.
func _update_dash(delta: float, to_player: Vector3, dist: float) -> void:
	if _is_dashing:
		_dash_time_left -= delta
		if _dash_time_left <= 0.0:
			_is_dashing = false
		return
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_dash_timer = randf_range(DASH_INTERVAL_MIN, DASH_INTERVAL_MAX)
		if dist > attack_range * 1.2 and to_player.length() > 0.01:
			_is_dashing = true
			_dash_time_left = DASH_TIME
			_dash_dir = to_player.normalized()

func _attack(player: Node3D) -> void:
	if is_ranged:
		_throw_at(player)
	elif player.has_method("take_hit"):
		player.take_hit(damage)

func _throw_at(player: Node3D) -> void:
	var scene: PackedScene = load(SNOWBALL_SCENE_PATH)
	var sb: Area3D = scene.instantiate()
	get_tree().current_scene.add_child(sb)
	sb.global_position = throw_point.global_position
	var dir: Vector3 = (player.global_position + Vector3.UP * 0.9 - throw_point.global_position).normalized()
	var stats := {"damage": damage, "speed": 20.0, "gravity_scale": 0.6, "radius": 0.2, "pierce": 1}
	sb.setup(dir, stats, false, Color(0.7, 0.85, 1.0))

func take_damage(amount: float, freeze_duration: float = 0.0, freeze_factor: float = 1.0) -> void:
	if _dead:
		return
	health -= amount
	_update_health_bar()
	_spawn_damage_number(amount)
	_play_hit_reaction()
	if freeze_duration > 0.0:
		slow_timer = max(slow_timer, freeze_duration)
		slow_factor = min(slow_factor, freeze_factor)
	if health <= 0.0:
		_die()

## Capped so repeated hits (e.g. a primary throw and its extras all landing
## on the same enemy within a fraction of a second) can't stack into an
## unbounded slide backward - without this a focus-fired enemy (elves in
## particular, being squishy and often the nearest/priority target) could
## get knocked further back each hit faster than the 20*delta decay below
## can dissipate it, reading as if they're fleeing rather than just reeling
## from repeated impacts.
const MAX_KNOCKBACK_VELOCITY := 9.0

func apply_knockback(v: Vector3) -> void:
	external_velocity = (external_velocity + v).limit_length(MAX_KNOCKBACK_VELOCITY)

## Sticks/nails snowballs: a health drain over `duration` seconds, plus a
## trailing blood decal while it's active. Re-applying refreshes/extends
## rather than stacking (matches how freeze/slow already behaves).
func apply_bleed(dps: float, duration: float) -> void:
	_bleed_dps = maxf(_bleed_dps, dps)
	_bleed_timer = maxf(_bleed_timer, duration)

## Piss-ball snowball: no damage, just a trailing colored decal for
## `duration` seconds.
func apply_footprint_trail(color: Color, duration: float) -> void:
	_footprint_color = color
	_footprint_timer = maxf(_footprint_timer, duration)

## Death ball: skips normal damage math entirely and kills outright. Still
## shows a damage number (its remaining health, i.e. "how much it took to
## finish this off") and the usual hit-reaction before dying, so it reads
## as a real hit rather than the enemy just vanishing.
func instant_kill() -> void:
	if _dead:
		return
	_spawn_damage_number(health)
	_play_hit_reaction()
	health = 0.0
	_update_health_bar()
	_die()

func _update_status_effects(delta: float) -> void:
	if _bleed_timer > 0.0:
		_bleed_timer -= delta
		health = maxf(0.0, health - _bleed_dps * delta)
		_update_health_bar()
		_bleed_drop_accum += delta
		if _bleed_drop_accum >= 0.15:
			_bleed_drop_accum = 0.0
			GroundTrail.spawn(global_position, Color(0.55, 0.05, 0.05), 5.0)
		if health <= 0.0:
			_die()
			return
	else:
		_bleed_dps = 0.0
	if _footprint_timer > 0.0:
		_footprint_timer -= delta
		_footprint_drop_accum += delta
		if _footprint_drop_accum >= 0.25:
			_footprint_drop_accum = 0.0
			GroundTrail.spawn(global_position, _footprint_color, 10.0)

## Floating number above the head, at the same anchor the health bar
## already uses (per-enemy-type tuned height, so it lines up whether this
## is a low reindeer or a tall elf).
func _spawn_damage_number(amount: float) -> void:
	var label := Label3D.new()
	label.set_script(DAMAGE_NUMBER_SCRIPT)
	get_tree().current_scene.add_child(label)
	label.global_position = health_bar.global_position + Vector3(0, 0.25, 0)
	label.setup(amount)

## Quick pop-and-flash punch so a hit reads clearly even in a crowd: the
## body mesh flashes white and the whole enemy pops up in size and rebounds,
## both relative to its own base scale/color (see setup()) so they don't
## fight the per-enemy size (brutes etc.) or the death-shrink tween. The pop
## is a uniform scale (not an X/Z-stretch-vs-Y-squash) because this scale is
## applied to the root CharacterBody3D - Jolt Physics (this project's 3D
## physics engine) doesn't support non-uniform scaling on a capsule
## collision shape and logs an error on every single frame of a squashed
## tween otherwise.
func _play_hit_reaction() -> void:
	if _hit_scale_tween and _hit_scale_tween.is_valid():
		_hit_scale_tween.kill()
	scale = _base_scale * 1.16
	_hit_scale_tween = create_tween()
	_hit_scale_tween.tween_property(self, "scale", _base_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_body_mat.albedo_color = Color(1, 1, 1)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(_body_mat, "albedo_color", _body_base_color, 0.16)

func _update_health_bar() -> void:
	var ratio: float = clampf(health / max_health, 0.0, 1.0)
	health_fill.scale.x = ratio
	health_fill.position.x = -0.4 * (1.0 - ratio)

func _die() -> void:
	if _dead:
		return
	_dead = true
	if _hit_scale_tween and _hit_scale_tween.is_valid():
		_hit_scale_tween.kill()
	# _physics_process (and with it _update_footsteps/_update_slide_audio)
	# never runs again once _dead is true, so the snowman's slide loop would
	# otherwise keep looping forever past death - nothing else stops it.
	if _slide_player and _slide_player.playing:
		_slide_player.stop()
	Game.add_score(score_value)
	Game.add_kill()
	_drop_exp_pickup()
	_spawn_snow_puff()
	_spawn_death_fx()
	remove_from_group("enemies")
	collision.set_deferred("disabled", true)
	var tw := create_tween()
	# A hair above zero, not Vector3.ZERO - an exactly-zero scale makes the
	# physics engine's transform matrix singular (non-invertible), which
	# Jolt logs as an error and has to paper over every frame of the tween.
	tw.tween_property(self, "scale", Vector3.ONE * 0.001, 0.25)
	tw.tween_callback(queue_free)

## Per-subtype death effect hook - no-op by default. EnemySnowman skips
## this entirely (it detonates via _detonate() instead of a normal death),
## while EnemyElf overrides it for a confetti burst.
func _spawn_death_fx() -> void:
	pass

## Snow-lit puff of unshaded billboard quads on every death (SNOW_LIT
## #EAF2FB per the art direction), so enemies burst into a little cloud of
## kicked-up snow before the shrink tween finishes. Purely visual: one root
## node in current_scene (so it outlives this enemy's queue_free), 8 quads
## sharing a single material, one tween driving expansion + fade.
const SNOW_PUFF_COLOR := Color(0.918, 0.949, 0.984, 0.75)  # SNOW_LIT #EAF2FB

func _spawn_snow_puff() -> void:
	var root := Node3D.new()
	get_tree().current_scene.add_child(root)
	root.global_position = global_position + Vector3.UP * 0.6
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SNOW_PUFF_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 8:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-0.2, 1.0), randf_range(-1.0, 1.0)).normalized()
		mi.position = dir * randf_range(0.12, 0.38)
		root.add_child(mi)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "scale", Vector3.ONE * 2.6, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(root.queue_free)

## Every kill drops one exp snowflake - leveling no longer comes from the
## kill itself, only from the player actually collecting the pickup it
## leaves behind (see ExpPickup.gd).
func _drop_exp_pickup() -> void:
	var scene: PackedScene = load(EXP_PICKUP_SCENE_PATH)
	var pickup: Area3D = scene.instantiate()
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector3.UP * 0.3

func _get_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
