extends Area3D
## A snowflake dropped by a slain enemy. Doesn't touch any stat directly -
## collecting one calls Game.add_exp(), which feeds the kill-free leveling
## system (see Game.get_level()): enough exp fills a level, and every level
## grants one more snowball per throw (Game.get_projectile_count()).
##
## Magnetizes toward the player once they're within MAGNET_RADIUS - pull
## speed ramps up the closer it gets, so it reads as "snapping in" for the
## last stretch instead of a flat crawl the whole way.
##
## Visually it's a crystalline snowflake: two identical flat six-armed flake
## glyphs (built procedurally below, same flat-triangles-via-SurfaceTool
## technique as BillboardForest.gd/MountainRange.gd) crossed at 90 degrees
## around the vertical axis - the classic crossed-plane trick, so the flake
## has a chunky star silhouette from every horizontal viewing angle instead
## of vanishing edge-on - plus a small glowing FX_XP gem sphere caught where
## the planes intersect. Arms fade gem-blue at the hub to icy white along
## their length and end in faceted gem-blue diamond tips.

const EXP_VALUE := 1

# This game has no tile grid, so "5 tiles" is mapped onto its existing scale
# at 2.0 world units/tile (matches how far apart nearby props already read
# as "one step" elsewhere in the game).
const TILE_SIZE := 2.0
const MAGNET_RADIUS := 5.0 * TILE_SIZE
const MAGNET_SPEED_MIN := 6.0
const MAGNET_SPEED_MAX := 22.0
# Once magnetizing gets the snowflake at least this close, collect it
# directly instead of waiting on the Area3D body_entered signal - that
# signal fires off the physics server's own overlap check, which runs on a
# different tick than the _process()-driven flight here, so "close to the
# flight target" and "physically overlapping enough to trigger the signal"
# can land on different frames. Without this, a snowflake could reach its
# target point, stop (nothing left moving it), and never actually be
# collected - reads as it permanently stuck to the player.
const COLLECT_DISTANCE := 0.4

# Full spin cycle: TAU / ROTATE_SPEED seconds per revolution (~6.3s) - slow
# and lazy rather than the frantic flip a higher rate would read as.
const ROTATE_SPEED := 1.0

# Arm reach (0.26) + diamond tip (0.10) tops out at 0.34 from center - kept
# under the 0.35 clearance the lowest point of the double bob leaves above
# the snow, so the flake never clips the ground.
const SNOWFLAKE_RADIUS := 0.26
const ARM_COUNT := 6
const ARM_WIDTH := 0.06
const HUB_RADIUS := 0.08
const BRANCH_WIDTH := 0.04
const BRANCH_ANGLE := deg_to_rad(45.0)
const BRANCH_LEN_FRAC := 0.34
const BRANCH_FRACTIONS := [0.45, 0.72]  # how far along each arm the two branch pairs sprout
const TIP_LENGTH := 0.10
const TIP_WIDTH := 0.085
const GEM_RADIUS := 0.07
# Palette (ART_DIRECTION): FX_XP #7FD8FF gem-blue core, SNOW_LIT icy edges,
# emissive at energy 1.5 so the glow pass makes dropped exp gleam like
# scattered gems against the dusk snow.
const CORE_COLOR := Color("#7FD8FF")
const EDGE_COLOR := Color("#EAF2FB")
const GLINT_SIZE := 0.06
# Two sparkles riding the flake's face, twinkling out of phase so the gem
# always has at least a faint wink going.
const GLINT_OFFSETS := [Vector3(0.13, 0.15, 0.0), Vector3(-0.1, -0.06, 0.11)]
const GLINT_PHASES := [0.0, 2.4]

var _bob_time: float = 0.0
var _collected: bool = false
var _visual: MeshInstance3D
var _glint_mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	add_to_group("exp_pickups")
	_bob_time = randf() * TAU
	monitoring = true
	body_entered.connect(_on_body_entered)
	_spawn_visual()

func _spawn_visual() -> void:
	var mesh := _build_snowflake_mesh()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mat.emission_enabled = true
	mat.emission = CORE_COLOR
	mat.emission_energy_multiplier = 1.5
	_visual = MeshInstance3D.new()
	_visual.mesh = mesh
	_visual.material_override = mat
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
	# Second copy of the same flake mesh crossed at 90 degrees - together the
	# two planes give the flake a real star silhouette from any angle.
	var cross := MeshInstance3D.new()
	cross.mesh = mesh
	cross.material_override = mat
	cross.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cross.rotation.y = PI / 2.0
	_visual.add_child(cross)
	_spawn_gem()
	_spawn_glints()

## The gem heart: a small unshaded FX_XP sphere sitting where the two flake
## planes cross, so the pickup reads as an icy crystal with a lit core.
func _spawn_gem() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = GEM_RADIUS
	mesh.height = GEM_RADIUS * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = CORE_COLOR
	mat.disable_receive_shadows = true
	mat.emission_enabled = true
	mat.emission = CORE_COLOR
	mat.emission_energy_multiplier = 1.8
	var gem := MeshInstance3D.new()
	gem.mesh = mesh
	gem.material_override = mat
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(gem)

## Tiny billboarded sparkle diamonds riding just off the flake's face -
## their alpha twinkles in _process (out of phase), so every exp gem winks
## at the player. Kept to 2-triangle meshes since dozens of these can be on
## the ground at once.
func _spawn_glints() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := GLINT_SIZE
	var w := GLINT_SIZE * 0.38
	st.add_vertex(Vector3(0, h, 0))
	st.add_vertex(Vector3(-w, 0, 0))
	st.add_vertex(Vector3(w, 0, 0))
	st.add_vertex(Vector3(0, -h, 0))
	st.add_vertex(Vector3(w, 0, 0))
	st.add_vertex(Vector3(-w, 0, 0))
	var mesh := st.commit()
	for offset in GLINT_OFFSETS:
		var glint := MeshInstance3D.new()
		glint.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = EDGE_COLOR
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_receive_shadows = true
		mat.emission_enabled = true
		mat.emission = CORE_COLOR
		mat.emission_energy_multiplier = 1.8
		glint.material_override = mat
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glint.position = offset
		_visual.add_child(glint)
		_glint_mats.append(mat)

## A bold 6-armed snowflake glyph: a hexagonal hub plus 6 spokes out to
## SNOWFLAKE_RADIUS, each with a pair of angled side-branches and a faceted
## diamond tip - flat (Z=0), so it needs the material's cull_mode disabled
## above to be visible from both sides as it spins. Colors run gem-blue at
## the hub to icy white outward, snapping back to gem-blue at the tips.
func _build_snowflake_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_hub(st, HUB_RADIUS)
	for i in ARM_COUNT:
		var angle: float = i * (TAU / ARM_COUNT)
		var dir := Vector2(cos(angle), sin(angle))
		_add_stick(st, Vector2.ZERO, dir * SNOWFLAKE_RADIUS, ARM_WIDTH, CORE_COLOR, EDGE_COLOR)
		for frac in BRANCH_FRACTIONS:
			var base: Vector2 = dir * (SNOWFLAKE_RADIUS * frac)
			var branch_len: float = SNOWFLAKE_RADIUS * BRANCH_LEN_FRAC * (1.0 - frac * 0.3)
			for side in [-1.0, 1.0]:
				var branch_dir: Vector2 = dir.rotated(side * BRANCH_ANGLE)
				_add_stick(st, base, base + branch_dir * branch_len, BRANCH_WIDTH, EDGE_COLOR, EDGE_COLOR)
		_add_tip(st, dir)
	st.generate_normals()
	return st.commit()

## A small hexagonal fan at the center so the arms have somewhere to meet -
## core-colored in the middle, blending toward the icy edge tone at its rim.
func _add_hub(st: SurfaceTool, radius: float) -> void:
	var rim: Color = CORE_COLOR.lerp(EDGE_COLOR, 0.35)
	for i in 6:
		var a0: float = (TAU / 6.0) * i
		var a1: float = (TAU / 6.0) * (i + 1)
		var p0 := Vector3(cos(a0) * radius, sin(a0) * radius, 0.0)
		var p1 := Vector3(cos(a1) * radius, sin(a1) * radius, 0.0)
		st.set_color(CORE_COLOR)
		st.add_vertex(Vector3.ZERO)
		st.set_color(rim)
		st.add_vertex(p0)
		st.set_color(rim)
		st.add_vertex(p1)

## A faceted rhombus capping one arm: base sits just inside the arm's end,
## widest point ~45% out, point at TIP_LENGTH - all in gem-blue so the six
## tips catch the glow pass like cut crystal.
func _add_tip(st: SurfaceTool, dir: Vector2) -> void:
	var r0: float = SNOWFLAKE_RADIUS - 0.02
	var base: Vector2 = dir * r0
	var mid: Vector2 = dir * (r0 + TIP_LENGTH * 0.45)
	var tip: Vector2 = dir * (r0 + TIP_LENGTH)
	var perp: Vector2 = Vector2(-dir.y, dir.x) * (TIP_WIDTH * 0.5)
	var a := Vector3(base.x, base.y, 0.0)
	var b := Vector3(mid.x - perp.x, mid.y - perp.y, 0.0)
	var c := Vector3(tip.x, tip.y, 0.0)
	var d := Vector3(mid.x + perp.x, mid.y + perp.y, 0.0)
	_add_tri(st, a, b, c, CORE_COLOR)
	_add_tri(st, a, c, d, CORE_COLOR)

## A thin rectangle from `from` to `to`, `width` units wide - one arm or
## branch of the snowflake, with its own color at each end so arms can fade
## from the gem core out to icy white.
func _add_stick(st: SurfaceTool, from: Vector2, to: Vector2, width: float, color_from: Color, color_to: Color) -> void:
	var dir: Vector2 = (to - from).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x) * (width * 0.5)
	var a := Vector3(from.x - perp.x, from.y - perp.y, 0.0)
	var b := Vector3(to.x - perp.x, to.y - perp.y, 0.0)
	var c := Vector3(to.x + perp.x, to.y + perp.y, 0.0)
	var d := Vector3(from.x + perp.x, from.y + perp.y, 0.0)
	st.set_color(color_from)
	st.add_vertex(a)
	st.set_color(color_to)
	st.add_vertex(b)
	st.set_color(color_to)
	st.add_vertex(c)
	st.set_color(color_from)
	st.add_vertex(a)
	st.set_color(color_to)
	st.add_vertex(c)
	st.set_color(color_from)
	st.add_vertex(d)

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)

func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta
	rotate_y(delta * ROTATE_SPEED)
	# Visual-only extra bob on the mesh child: in phase with the root's bob
	# below, so the flake visually sweeps ~0.2 units while the collision
	# sphere keeps its original 0.1 travel.
	_visual.position.y = sin(_bob_time * 2.0) * 0.1
	for i in _glint_mats.size():
		var twinkle: float = 0.5 + 0.5 * sin(_bob_time * 3.2 + GLINT_PHASES[i])
		_glint_mats[i].albedo_color.a = 0.1 + 0.9 * twinkle * twinkle * twinkle
	var player: Node3D = _get_player()
	if player and global_position.distance_to(player.global_position) <= MAGNET_RADIUS:
		_fly_toward(player, delta)
	else:
		position.y = 0.55 + sin(_bob_time * 2.0) * 0.1

func _fly_toward(player: Node3D, delta: float) -> void:
	var target: Vector3 = player.global_position + Vector3.UP * 0.9
	var to_target: Vector3 = target - global_position
	var dist: float = to_target.length()
	if dist <= COLLECT_DISTANCE:
		_collect()
		return
	var closeness: float = 1.0 - clampf(dist / MAGNET_RADIUS, 0.0, 1.0)
	var speed: float = lerpf(MAGNET_SPEED_MIN, MAGNET_SPEED_MAX, closeness)
	global_position += (to_target / dist) * speed * delta

func _get_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]

func _on_body_entered(body: Node) -> void:
	if _collected or Game.state != Game.State.PLAYING or not body.is_in_group("player"):
		return
	_collect()

func _collect() -> void:
	if _collected:
		return
	_collected = true
	# Deferred: _on_body_entered runs during the physics engine's collision
	# pass (it's connected to this same Area3D's body_entered), and
	# toggling monitoring synchronously mid-pass is explicitly disallowed
	# by Godot - keeping it deferred here too since _collect() is now also
	# reachable from that path.
	set_deferred("monitoring", false)
	Game.add_exp(EXP_VALUE)
	var tw := create_tween()
	# A hair above zero, not Vector3.ZERO - an exactly-zero scale makes the
	# physics engine's transform matrix singular (non-invertible), which
	# Jolt logs as an error and has to paper over every frame of the tween.
	tw.tween_property(self, "scale", Vector3.ONE * 0.001, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
