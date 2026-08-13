extends CharacterBody3D
## Third-person player controller: WASD movement relative to facing, mouse
## look, upgradeable multi-jump, upgradeable dash. The primary snowball
## throws automatically at a fixed cadence of 1 every 0.5s - nothing in the
## game speeds this cadence up, by design. Leveling up (collected exp
## snowflakes, see Game.get_level()) adds extra snowballs instead of
## throwing the primary faster: those extras fire on their own, faster,
## independent cadence, phase-offset so they land in the gaps between
## primary throws (alternating rather than firing in lockstep with it), and
## each extra always locks onto a different enemy than whatever the primary
## is currently targeting (and than each other), instead of all piling onto
## the same target. Every throw - primary or extra - gets at least a
## baseline homing pull so it tracks its target in flight.

const GRAVITY := 22.0
const MAX_FALL_SPEED := 40.0  # terminal velocity - guards against tunneling through thin colliders
const MOUSE_SENS := 0.0035
const TOUCH_LOOK_SENS := 0.006
const MAX_TOUCH_DRAG_STEP := 120.0  # px/event; guards against touch-index reuse glitches
const PITCH_MIN := -0.7   # ~-40 deg
const PITCH_MAX := 1.2    # ~70 deg
const DASH_SPEED := 22.0
const DASH_TIME := 0.18
const SPRINT_MULT := 1.35
const GROUND_ACCEL := 45.0  # units/sec^2 - reaches base move speed in ~0.13s, quick but not an instant snap
const GROUND_DECEL := 55.0  # a bit sharper than accel so stopping still feels crisp instead of sliding
const SNOWBALL_SCENE_PATH := "res://scenes/weapons/Snowball.tscn"
const AUTO_THROW_INTERVAL := 0.5  # fixed: 1 primary snowball every 0.5s, always - nothing speeds this up
const EXTRA_THROW_INTERVAL := 0.35  # extra (level-driven) snowballs fire on their own, faster cadence
const AUTO_LOCK_HOMING := 3.0

# Exaggerated throw wind-up/whip/recoil/settle poses for right_shoulder
# (radians) - see _play_throw_animation. The windup snaps instantly (not
# tweened) exactly like before, since throw_point.global_position is read
# synchronously right after this fires to spawn the snowball - a tweened
# lead-in would spawn it from the wrong place. The whip (the arm swing
# itself) is deliberately unhurried even though the snowball flies off at
# full speed the instant it spawns - the arm reads as a smooth, weighty
# throw rather than a twitchy blur, while the ball's actual travel speed is
# untouched. Recoil/settle were trimmed to compensate so the total tweened
# time (0.17 + 0.08 + 0.10 = 0.35s) still stays at/under EXTRA_THROW_
# INTERVAL's 0.35s gap, so back-to-back throws don't constantly cut the
# animation off early.
const THROW_WINDUP_ROT := Vector3(-1.75, 0.0, 0.4)
const THROW_RELEASE_ROT := Vector3(1.35, 0.0, -0.55)
const THROW_RECOIL_ROT := Vector3(-0.2, 0.0, 0.12)
const THROW_WHIP_TIME := 0.17
const THROW_RECOIL_TIME := 0.08
const THROW_SETTLE_TIME := 0.10
const TARGET_SEARCH_RADIUS := 45.0
const LOOK_ZONE_MIN_X_RATIO := 0.6  # only the right side of the screen can ever start a look-drag

# Soft footstep audio (see _update_footsteps/Footsteps.gd) - steps-per-second
# at Game.get_move_speed(), scaled by actual speed the same way Enemy.gd's
# footsteps are (so sprinting patters faster than a jog). Quiet/close-range
# on purpose - "soft footsteps" per the brief, unlike the enemies' louder,
# further-carrying ones.
const FOOTSTEP_HZ := 3.6
const FOOTSTEP_RANGE := 22.0
const FOOTSTEP_VOLUME_DB := -14.0
const FOOTSTEP_PITCH_JITTER := 0.06

# AnimationLibrary_Godot_Standard.glb (see Model below) is a full mannequin
# rig (53-bone Rigify-style deform skeleton) that ships with its own
# AnimationPlayer/AnimationLibrary - real baked animations (Idle, Jog_Fwd,
# Sprint, Jump_Start, Jump, Jump_Land, ...), not the hand-swung bones the
# old CharacterRigged.glb stick-figure needed. See _update_animation for the
# state machine that picks between them. The asset's rest pose faces +Z
# (Godot's convention is -Z as "forward"), so Player.tscn's Model node
# carries a fixed 180-degree Y rotation to correct for it - otherwise the
# character visually faces the camera instead of the direction of travel.
const AIR_STRETCH := Vector3(0.94, 1.1, 0.94)
const LAND_SQUASH := Vector3(1.16, 0.82, 1.16)

# Visuals (visual-only, ART_DIRECTION.md "Alpenglow Dusk" player palette):
# the realistic GLB mannequin mesh is hidden and replaced at runtime by
# PlayerToyModel - a chunky primitive-built winter hero matching the
# elf/snowman visual grammar - which rides the mannequin's Skeleton3D so
# every baked animation keeps driving the body. Purely cosmetic - no nodes
# moved/renamed, no gameplay values touched. See _build_toy_model().

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var right_shoulder: Node3D = $RightShoulder
@onready var throw_point: Marker3D = $RightShoulder/ThrowPoint
@onready var hat_anchor: Node3D = $HatAnchor

# Where equipped hats actually attach: defaults to the static hat_anchor,
# upgraded by _build_toy_model to the toy head's bone-following HatMount.
var _hat_mount: Node3D = null

var jumps_used: int = 0
var _throw_timer: float = 0.0
var _extra_throw_timer: float = 0.0

# Captured in _ready() (rather than hardcoded) so the bob/squash below
# blends around whatever position/scale Model was actually authored with
# in Player.tscn, instead of fighting it.
var _model_base_position: Vector3 = Vector3.ZERO
var _model_base_scale: Vector3 = Vector3.ONE
var _was_on_floor: bool = true
var _land_squash_tween: Tween = null

var dash_charges_left: int = 1
var dash_recharge_timer: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO

var _is_throwing: bool = false
var _throw_tween: Tween = null
var _footstep_time: float = 0.0
var _toy_model: PlayerToyModel = null
var _throw_arm_visual: Node3D = null

# Camera-look owns exactly one finger at a time, and only ever trusts drag
# events for the index it personally saw touch down. This is what stops a
# second finger (e.g. the movement joystick) from ever being able to yank
# the camera: without this, a browser reassigning/reusing a touch index
# mid-multitouch can hand us a drag "relative" that's really a jump between
# two different fingers' positions, which reads as the camera snapping/
# resetting. MAX_TOUCH_DRAG_STEP below is a second line of defense that
# clamps any single-event delta that's still suspiciously large.
var _look_touch_index: int = -1

func _ready() -> void:
	add_to_group("player")
	_model_base_position = model.position
	_model_base_scale = model.scale
	# Default hat attachment is the static scene-authored anchor;
	# _build_toy_model upgrades it to the toy head's bone-following mount.
	_hat_mount = hat_anchor
	_build_toy_model()
	_build_throw_arm_visual()
	dash_charges_left = Game.get_dash_charges()
	_throw_timer = AUTO_THROW_INTERVAL
	# Half-interval head start so the first extra volley lands between the
	# first two primary throws instead of on top of the first one.
	_extra_throw_timer = EXTRA_THROW_INTERVAL / 2.0
	Game.hat_equipped.connect(_on_hat_equipped)
	# Bare-headed by default - a hat only appears once one is actually picked
	# up (Game.equipped_hat starts as "" on every fresh run).
	if Game.equipped_hat != "":
		_on_hat_equipped(Game.equipped_hat)

# --- Toy body (visual-only) ----------------------------------------------
## Swaps the realistic mannequin's look for the chunky primitive-built
## winter hero: adds a PlayerToyModel under the GLB's Skeleton3D, so its
## parts live in skeleton space, follow the baked animations bone-for-bone,
## and inherit Model's landing-squash/airborne-stretch scale tweens. The
## toy model hides the mannequin's skin mesh itself. Model carries a
## 180-degree Y rotation (the GLB faces +Z), so skeleton-space +Z is the
## player's facing direction and -Z faces the chase camera - the scarf tail
## hangs down the back at -Z where the camera sees it. Equipped hats attach
## to the toy's hat_mount (a child of the head assembly), so they ride the
## animated head bone instead of hovering at a fixed height.
func _build_toy_model() -> void:
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_warning("Player: no Skeleton3D found under Model - keeping mannequin visuals")
		return
	var skeleton := skeletons[0] as Skeleton3D
	var toy := PlayerToyModel.new()
	_toy_model = toy
	skeleton.add_child(toy)
	# toy built its body in _ready, which already ran inside add_child
	# above. If the head bone was somehow missing there is no mount - keep
	# the static scene-authored HatAnchor fallback set in _ready.
	if toy.hat_mount != null:
		_hat_mount = toy.hat_mount

## A dedicated visible throw arm (sleeve, cuff, mitten - same palette as
## PlayerToyModel's real arm), parented to right_shoulder and hidden by
## default. right_shoulder itself has no mesh of its own (it only ever
## positioned the invisible ThrowPoint), and the toy body's actual right arm
## is 100% driven by the baked skeleton (no throw clip exists to swing it) -
## so without this, _play_throw_animation's wind-up/whip has nothing visible
## to animate. Shown/hidden opposite PlayerToyModel's right_arm_parts by
## _set_throw_arm_visible so the two never render at once. Built once here
## from throw_point's rest local position, since only right_shoulder's own
## rotation (not this assembly's local geometry) needs to animate per throw.
func _build_throw_arm_visual() -> void:
	_throw_arm_visual = Node3D.new()
	_throw_arm_visual.name = "ThrowArmVisual"
	_throw_arm_visual.visible = false
	right_shoulder.add_child(_throw_arm_visual)

	var sleeve_mat := StandardMaterial3D.new()
	sleeve_mat.albedo_color = PlayerToyModel.COAT_TEAL
	sleeve_mat.roughness = 0.8
	var cuff_mat := StandardMaterial3D.new()
	cuff_mat.albedo_color = PlayerToyModel.TRIM_WHITE
	cuff_mat.roughness = 0.97
	var mitten_mat := StandardMaterial3D.new()
	mitten_mat.albedo_color = PlayerToyModel.SCARF_RED
	mitten_mat.roughness = 0.8

	var hand_local: Vector3 = throw_point.position
	var shoulder_origin := Vector3.ZERO

	var sleeve := CylinderMesh.new()
	sleeve.top_radius = 0.058
	sleeve.bottom_radius = 0.05
	sleeve.height = hand_local.length() * 0.85
	sleeve.radial_segments = 10
	var sleeve_mi := MeshInstance3D.new()
	sleeve_mi.mesh = sleeve
	sleeve_mi.material_override = sleeve_mat
	sleeve_mi.transform = _oriented_transform(shoulder_origin, hand_local, 0.42)
	_throw_arm_visual.add_child(sleeve_mi)

	var cuff := TorusMesh.new()
	cuff.inner_radius = 0.045
	cuff.outer_radius = 0.085
	cuff.rings = 14
	cuff.ring_segments = 6
	var cuff_mi := MeshInstance3D.new()
	cuff_mi.mesh = cuff
	cuff_mi.material_override = cuff_mat
	cuff_mi.transform = _oriented_transform(shoulder_origin, hand_local, 0.85)
	_throw_arm_visual.add_child(cuff_mi)

	var mitten := SphereMesh.new()
	mitten.radius = 0.075
	mitten.height = 0.15
	mitten.radial_segments = 10
	mitten.rings = 6
	var mitten_mi := MeshInstance3D.new()
	mitten_mi.mesh = mitten
	mitten_mi.material_override = mitten_mat
	mitten_mi.position = hand_local
	_throw_arm_visual.add_child(mitten_mi)

## Orthonormal transform at a point along from-to-to with local +Y aligned
## to that direction - same technique PlayerToyModel._segment_transform
## uses to orient its own radially-symmetric limb meshes.
func _oriented_transform(from: Vector3, to: Vector3, t: float) -> Transform3D:
	var dir: Vector3 = to - from
	var y: Vector3 = dir.normalized() if dir.length_squared() > 0.000001 else Vector3.UP
	var helper: Vector3 = Vector3.UP if absf(y.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x: Vector3 = helper.cross(y).normalized()
	var z: Vector3 = x.cross(y)
	return Transform3D(Basis(x, y, z), from.lerp(to, t))

## Shows the dedicated throw-arm overlay and hides the toy model's real
## right-arm meshes, or vice versa - called at the start of every throw
## animation (idempotent/self-correcting, so overlapping primary/extra
## throws restarting the tween never leave things in a half-swapped state)
## and once more when a throw animation finishes uninterrupted.
func _set_throw_arm_visible(showing: bool) -> void:
	if _throw_arm_visual:
		_throw_arm_visual.visible = showing
	if _toy_model:
		for p in _toy_model.right_arm_parts:
			if is_instance_valid(p):
				p.visible = not showing

func _on_hat_equipped(hat_id: String) -> void:
	for c in _hat_mount.get_children():
		c.queue_free()
	var data: Dictionary = HatDB.get_data(hat_id)
	var visual: Node3D = HatVisuals.build(data.get("shape", "top_hat"), data.get("color", Color(0.8, 0.1, 0.12)))
	_hat_mount.add_child(visual)
	visual.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.3, 1.3, 1.3), 0.1)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.15)

func _unhandled_input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative, MOUSE_SENS)
	elif event is InputEventScreenTouch:
		_handle_look_touch(event)
	elif event is InputEventScreenDrag:
		# Only reaches here if no touch UI control (joystick/button) claimed
		# this finger first. Still ignore it unless it's the one finger we
		# already registered as the look-finger via _handle_look_touch.
		if event.index == _look_touch_index:
			var rel: Vector2 = event.relative
			if rel.length() > MAX_TOUCH_DRAG_STEP:
				rel = rel.normalized() * MAX_TOUCH_DRAG_STEP
			_apply_look(rel, TOUCH_LOOK_SENS)

func _handle_look_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Positional guard, not just "wasn't claimed by something else": a
		# touch can only ever become the look-finger if it starts on the
		# right side of the screen. Without this, a movement thumb that
		# ever slips off the joystick's exact hit-region for a single frame
		# (extremely common - thumbs shift constantly during a hold) would
		# get misclassified as the look-finger, and its next drag would
		# yank the camera. This makes that class of bug impossible instead
		# of just less likely.
		if _look_touch_index == -1 and _is_in_look_zone(event.position):
			_look_touch_index = event.index
	elif event.index == _look_touch_index:
		_look_touch_index = -1

func _is_in_look_zone(screen_pos: Vector2) -> bool:
	var vp_width: float = get_viewport().get_visible_rect().size.x
	return screen_pos.x >= vp_width * LOOK_ZONE_MIN_X_RATIO

func _apply_look(relative: Vector2, sens: float) -> void:
	rotate_y(-relative.x * sens)
	var pitch: float = spring_arm.rotation.x - relative.y * sens
	spring_arm.rotation.x = clampf(pitch, PITCH_MIN, PITCH_MAX)

func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		return
	_handle_gravity_and_jump(delta)
	_handle_dash(delta)
	_handle_movement(delta)
	_handle_auto_throw(delta)
	move_and_slide()
	# Both of these read is_on_floor() - must run after move_and_slide()
	# (the only thing that actually updates it) and in this order, since
	# _update_animation's takeoff/landing edge-detection compares
	# is_on_floor() against _was_on_floor BEFORE _update_landing_squash
	# overwrites it for next frame.
	_update_animation(delta)
	_update_landing_squash()

func take_hit(amount: float) -> void:
	Game.take_damage(amount)

## Called by outside effects (e.g. EnemySanta.gd's snowstorm) to shove the
## player around - a ONE-TIME velocity impulse added straight into
## `velocity`, unlike Enemy.gd's external_velocity/apply_knockback (which
## stores the push and re-adds it every frame while it decays). That
## pattern is safe for enemies only because their velocity.x/z get freshly
## overwritten by AI logic every single frame regardless, so nothing else
## would preserve a knockback push otherwise. The player's velocity - most
## importantly velocity.y under gravity - already persists and accumulates
## frame to frame on its own; re-adding the same undecayed magnitude again
## every frame on top of that compounds explosively instead of decaying
## (confirmed by simulating it: a single launch reached y=1000+ instead of
## arcing back down), since nothing here resets it back down in between.
func apply_external_velocity(v: Vector3) -> void:
	velocity += v

# --- Animation state machine -------------------------------------------
# Drives the mannequin's own baked clips (AnimationLibrary_Godot_Standard.glb)
# instead of posing bones by hand. Grounded states (Idle/Jog_Fwd/Sprint) are
# picked every frame from movement/input, so switching between them is
# always in sync with the latest state. Airborne is a proper 3-phase jump -
# Jump_Start (one-shot) -> Jump (looping hold, for whatever the actual
# airtime turns out to be) -> Jump_Land (one-shot recovery) - tracked via
# _was_on_floor (same floor-transition flag _update_landing_squash below
# already relies on) so takeoff/landing each fire exactly once. play()'s
# custom_blend argument crossfades between clips instead of hard-cutting.
const ANIM_BLEND := 0.15

func _update_animation(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = horizontal_speed > 0.4 and is_on_floor() and not is_dashing
	var sprinting: bool = moving and Input.is_action_pressed("sprint")
	_update_footsteps(delta, moving, horizontal_speed)

	if not is_on_floor():
		if _was_on_floor:
			animation_player.play("Jump_Start", ANIM_BLEND)
		elif animation_player.current_animation == "Jump_Start" and not animation_player.is_playing():
			animation_player.play("Jump", 0.2)
	else:
		if not _was_on_floor:
			animation_player.play("Jump_Land", 0.1)
		elif animation_player.current_animation == "Jump_Land" and animation_player.is_playing():
			pass  # let the landing recovery finish before picking a new state
		elif sprinting:
			if animation_player.current_animation != "Sprint":
				animation_player.play("Sprint", ANIM_BLEND)
		elif moving:
			if animation_player.current_animation != "Jog_Fwd":
				animation_player.play("Jog_Fwd", ANIM_BLEND)
		elif animation_player.current_animation != "Idle":
			animation_player.play("Idle", ANIM_BLEND)

	var blend: float = clampf(delta * 12.0, 0.0, 1.0)

	# Airborne stretch - skipped while a landing squash tween owns the scale
	# (see _update_landing_squash below), and skipped while grounded so it
	# doesn't fight that tween's own settle-back-to-base leg.
	if not is_on_floor() and (_land_squash_tween == null or not _land_squash_tween.is_valid()):
		model.scale = model.scale.lerp(_model_base_scale * AIR_STRETCH, blend)

## Soft footstep audio - same accumulator-crosses-1.0 pattern Enemy.gd's
## _update_footsteps uses, scaled by actual speed relative to
## Game.get_move_speed() so sprinting (and any move-speed upgrades) pace
## the patter correctly instead of a fixed real-time interval.
func _update_footsteps(delta: float, moving: bool, horizontal_speed: float) -> void:
	if not moving:
		return
	var ratio: float = clampf(horizontal_speed / maxf(Game.get_move_speed(), 0.5), 0.5, 2.0)
	_footstep_time += delta * FOOTSTEP_HZ * ratio
	while _footstep_time >= 1.0:
		_footstep_time -= 1.0
		var pitch: float = 1.0 + randf_range(-1.0, 1.0) * FOOTSTEP_PITCH_JITTER
		Footsteps.play_step("player", global_position, FOOTSTEP_RANGE, FOOTSTEP_VOLUME_DB, pitch)

## Bouncy squash-then-recover pulse the instant the player lands, same
## technique as Enemy.gd's hit-reaction squash. Checked after move_and_slide()
## since that's what actually updates is_on_floor() for this frame.
func _update_landing_squash() -> void:
	var on_floor: bool = is_on_floor()
	if on_floor and not _was_on_floor:
		if _land_squash_tween and _land_squash_tween.is_valid():
			_land_squash_tween.kill()
		model.scale = _model_base_scale * LAND_SQUASH
		_land_squash_tween = create_tween()
		_land_squash_tween.tween_property(model, "scale", _model_base_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_was_on_floor = on_floor

func _play_throw_animation() -> void:
	if _throw_tween and _throw_tween.is_valid():
		_throw_tween.kill()
	_is_throwing = true
	_set_throw_arm_visible(true)
	right_shoulder.rotation = THROW_WINDUP_ROT
	_throw_tween = create_tween()
	_throw_tween.tween_property(right_shoulder, "rotation", THROW_RELEASE_ROT, THROW_WHIP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_throw_tween.tween_property(right_shoulder, "rotation", THROW_RECOIL_ROT, THROW_RECOIL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_throw_tween.tween_property(right_shoulder, "rotation", Vector3.ZERO, THROW_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_throw_tween.tween_callback(_on_throw_anim_finished)

func _on_throw_anim_finished() -> void:
	_is_throwing = false
	_set_throw_arm_visible(false)

# --- Movement --------------------------------------------------------------
func _get_wish_dir() -> Vector3:
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		dir -= transform.basis.z
	if Input.is_action_pressed("move_back"):
		dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		dir += transform.basis.x
	dir.y = 0.0
	if dir.length() > 0.001:
		dir = dir.normalized()
	return dir

func _handle_movement(delta: float) -> void:
	if is_dashing:
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
		return
	var wish := _get_wish_dir()
	var speed := Game.get_move_speed()
	if Input.is_action_pressed("sprint") and wish.length() > 0.01:
		speed *= SPRINT_MULT
	var target := wish * speed
	if is_on_floor():
		# Eased toward the target instead of snapping straight to it - still
		# quick (full speed in well under a quarter-second) but no longer an
		# instant velocity jump every time input starts/stops, which read as
		# twitchy. Decel a hair faster than accel so stopping still feels
		# crisp rather than sliding.
		var rate: float = GROUND_ACCEL if wish.length() > 0.01 else GROUND_DECEL
		velocity.x = move_toward(velocity.x, target.x, rate * delta)
		velocity.z = move_toward(velocity.z, target.z, rate * delta)
	else:
		var accel: float = 5.0 * Game.get_air_control_mult()
		velocity.x = move_toward(velocity.x, target.x, accel * delta * max(speed, 1.0))
		velocity.z = move_toward(velocity.z, target.z, accel * delta * max(speed, 1.0))

func _handle_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		# Terminal velocity: uncapped fall speed risks tunneling straight
		# through the ground's collision shape on a frame-rate hitch (a big
		# single-frame position delta can skip past a thin collider).
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)
	else:
		if velocity.y < 0.0:
			velocity.y = -1.0
		jumps_used = 0
	if Input.is_action_just_pressed("jump"):
		var max_jumps := Game.get_max_jumps()
		if jumps_used < max_jumps:
			velocity.y = Game.get_jump_velocity()
			jumps_used += 1

func _handle_dash(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	var max_charges := Game.get_dash_charges()
	if dash_charges_left < max_charges:
		dash_recharge_timer += delta
		if dash_recharge_timer >= Game.get_dash_cooldown():
			dash_recharge_timer = 0.0
			dash_charges_left += 1
	if Game.dash_unlocked and Input.is_action_just_pressed("dash") and not is_dashing and dash_charges_left > 0:
		var dir := _get_wish_dir()
		if dir.length() < 0.01:
			dir = -transform.basis.z
		dash_dir = dir.normalized()
		is_dashing = true
		dash_timer = DASH_TIME
		dash_charges_left -= 1
		velocity.y = max(velocity.y, 0.0)

# --- Throwing (automatic, fixed cadence, auto-lock on nearest enemy) -----
# The primary is a hard-fixed 1 throw per 0.5s - nothing in the game (kills,
# upgrades, pickups) is allowed to change that. The projectile COUNT from
# leveling up (collected exp snowflakes, see Game.get_level/
# get_projectile_count) instead spawns extra throws on their own separate,
# faster timer (EXTRA_THROW_INTERVAL), phase-started at a half-interval
# offset so they land in the gaps between primary throws rather than firing
# alongside them. Per-projectile speed/damage still scale with upgrades
# either way.
func _handle_auto_throw(delta: float) -> void:
	_throw_timer -= delta
	if _throw_timer <= 0.0:
		_throw_snowball()
		_throw_timer = AUTO_THROW_INTERVAL
	_extra_throw_timer -= delta
	if _extra_throw_timer <= 0.0:
		_throw_extra_snowballs()
		_extra_throw_timer = EXTRA_THROW_INTERVAL

## The primary throw: always exactly 1 snowball, always at the single
## nearest enemy.
func _throw_snowball() -> void:
	var target: Node3D = _find_nearest_enemy()
	if target == null:
		return
	_play_throw_animation()
	var dir: Vector3 = (target.global_position + Vector3.UP - throw_point.global_position).normalized()
	_spawn_snowball(dir, _current_throw_stats(), SnowballDB.get_color(Game.current_snowball_type))

## The extra (level-driven) throws: fire together on their own cadence, each
## locked onto a different enemy than the current primary target and than
## each other, instead of piling onto/fanning around one target. Gracefully
## throws fewer than the full count if there aren't enough distinct enemies
## in range.
func _throw_extra_snowballs() -> void:
	var extra_count: int = Game.get_projectile_count() - 1
	if extra_count <= 0:
		return
	var exclude: Array = []
	var primary_target: Node3D = _find_nearest_enemy()
	if primary_target != null:
		exclude.append(primary_target)
	var targets: Array = _find_nearest_enemies(extra_count, exclude)
	if targets.is_empty():
		return
	_play_throw_animation()
	var stats: Dictionary = _current_throw_stats()
	var color: Color = SnowballDB.get_color(Game.current_snowball_type)
	for target in targets:
		var dir: Vector3 = (target.global_position + Vector3.UP - throw_point.global_position).normalized()
		_spawn_snowball(dir, stats, color)

func _current_throw_stats() -> Dictionary:
	var stats: Dictionary = SnowballDB.get_stats(Game.current_snowball_type).duplicate()
	var power: float = Game.get_throw_power_mult()
	stats["damage"] = stats.get("damage", 10.0) * power
	stats["speed"] = stats.get("speed", 30.0) * power * Game.get_projectile_speed_mult()
	# Every throw gets at least a baseline auto-lock pull, on top of
	# whatever homing the current snowball type already has via maxf.
	stats["homing"] = maxf(stats.get("homing", 0.0), AUTO_LOCK_HOMING)
	return stats

func _spawn_snowball(dir: Vector3, stats: Dictionary, color: Color) -> void:
	var scene: PackedScene = load(SNOWBALL_SCENE_PATH)
	var sb: Area3D = scene.instantiate()
	get_tree().current_scene.add_child(sb)
	sb.global_position = throw_point.global_position
	sb.setup(dir, stats, true, color, false, Game.current_snowball_type)

## Up to n nearest enemies (within TARGET_SEARCH_RADIUS), skipping anything
## in `exclude` - used to give each extra projectile its own distinct
## target instead of stacking on the primary's.
func _find_nearest_enemies(n: int, exclude: Array = []) -> Array:
	var candidates: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e in exclude:
			continue
		var d: float = throw_point.global_position.distance_to(e.global_position)
		if d < TARGET_SEARCH_RADIUS:
			candidates.append({"node": e, "dist": d})
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var result: Array = []
	for i in range(mini(n, candidates.size())):
		result.append(candidates[i]["node"])
	return result

func _find_nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist: float = TARGET_SEARCH_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = throw_point.global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best
