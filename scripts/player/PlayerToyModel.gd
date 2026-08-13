class_name PlayerToyModel
extends Node3D
## Chunky primitive-built "winter hero" body that rides the imported
## mannequin's Skeleton3D (models/AnimationLibrary_Godot_Standard.glb).
##
## The realistic mannequin clashes with the toy-like elf/snowman enemies, so
## this node hides every imported mesh and rebuilds the player out of the
## same visual grammar the enemies use - sphere head with dot eyes, capsule
## coat, cylinder limbs with sphere joints, torus wraps - WITHOUT giving up
## the mannequin's baked animations (Idle/Jog_Fwd/Sprint/Jump_*). Player.gd
## adds an instance of this as a child of the Skeleton3D, so every part
## transform below lives in skeleton space and inherits Model's
## squash/stretch scale tweens for free. Two kinds of parts follow the
## animated pose (re-posed on every skeleton update):
## - SEGMENT parts: radially symmetric meshes stretched between two joint
##   origins (torso, limb cylinders, wrist/ankle wraps) - placed at a point
##   along the joint-to-joint line with local +Y aligned to it. Heights are
##   sized once from the rest pose (plus overlap so bent joints never gap).
## - BONE-ANCHORED parts: assemblies that follow one bone's full pose (head,
##   scarf, belt, mittens, boots, joint spheres). Each captures
##   local_xf = rest_pose^-1 * T(desired_rest_origin) at setup, so it starts
##   axis-aligned (face toward skeleton-space +Z, the player's visual front)
##   and then tracks the bone exactly through animations.
##
## Palette + material rules follow the shared "Alpenglow Dusk" conventions
## (cloth roughness 0.8, fur 0.97, metal roughness 0.35 / metallic 0.9).
## Hexes reuse the master palette swatches; COAT_TEAL is the palette's
## player-coat entry, unique to the player so no other script repeats it.

const COAT_TEAL := Color("#3D7EA8")     # master palette PLAYER_COAT winter teal-blue
const TRIM_WHITE := Color("#F5EFE6")    # PLAYER_TRIM fur/fringe
const SCARF_RED := Color("#E8483F")     # EMBER_RED accent
const COAL_DARK := Color("#26221F")     # belt/boots/eyes
const BUCKLE_GOLD := Color("#FFB84D")   # EMBER_GOLD, the one metallic bit
const SKIN := Color(0.949, 0.78, 0.62)  # same skin family as the elf

# Must stay equal to HatVisuals.HEAD_RADIUS - every hat in the game is
# proportioned against it, and hat_mount below seats hats on this sphere.
const HEAD_RADIUS := HatVisuals.HEAD_RADIUS
const HEAD_LIFT := 0.09  # head-sphere center sits this far above the head bone origin

## Where equipped hats attach: a child of the head assembly pinned to the
## top of the head sphere, so hats ride the animated head bone (bob, jump
## crouch, sprint lean) instead of hovering at a fixed height. Follows the
## HatVisuals anchoring convention (origin = top of head, -Y wraps down
## over the skull). Null only if the head bone was missing - Player.gd then
## falls back to its static HatAnchor.
var hat_mount: Node3D = null

## The right arm's mesh parts (upper/forearm segments, joint spheres, cuff,
## mitten), collected as they're built below - Player.gd hides these and
## shows its own exaggerated ThrowArmVisual overlay while a throw animation
## plays, since this arm otherwise only ever reproduces whatever the baked
## Idle/Jog/Sprint/Jump clips are doing (no throw clip exists to swing it).
var right_arm_parts: Array[Node3D] = []

var _skeleton: Skeleton3D = null
# Each: {"mi": MeshInstance3D, "a": int, "b": int, "t": float}
var _segments: Array[Dictionary] = []
# Each: {"node": Node3D, "bone": int, "xf": Transform3D}
var _anchored: Array[Dictionary] = []

func _ready() -> void:
	_skeleton = get_parent() as Skeleton3D
	if _skeleton == null:
		push_warning("PlayerToyModel must be added as a child of a Skeleton3D")
		set_process(false)
		return
	_hide_imported_meshes()
	_build_body()
	# Prefer the pose-change signal (fires exactly when bone poses settle);
	# fall back to per-frame updates if a future engine build drops it.
	if _skeleton.has_signal("skeleton_updated"):
		_skeleton.skeleton_updated.connect(_update_parts)
		set_process(false)
	else:
		set_process(true)
	_update_parts()

func _process(_delta: float) -> void:
	_update_parts()

## Hides every imported MeshInstance3D of the GLB (the "Mannequin" skin and
## any future re-import additions) without freeing them, so the skeleton and
## its animations keep working untouched.
func _hide_imported_meshes() -> void:
	var glb_root: Node = _skeleton.owner if _skeleton.owner != null else _skeleton
	for mi in glb_root.find_children("*", "MeshInstance3D", true, false):
		if not is_ancestor_of(mi):
			(mi as MeshInstance3D).visible = false

## find_bone() with a substring fallback (case-insensitive, "DEF-" prefix
## stripped) so a re-import that tweaks bone naming degrades to a warning
## for the truly missing parts instead of silently dropping the whole body.
func _bone(bone_name: String) -> int:
	var idx: int = _skeleton.find_bone(bone_name)
	if idx != -1:
		return idx
	var key: String = bone_name.trim_prefix("DEF-").to_lower()
	for i in _skeleton.get_bone_count():
		if _skeleton.get_bone_name(i).to_lower().contains(key):
			return i
	push_warning("PlayerToyModel: bone not found: " + bone_name)
	return -1

# --- Body construction ----------------------------------------------------
func _build_body() -> void:
	var b_spine: int = _bone("DEF-spine.001")
	var b_neck: int = _bone("DEF-neck")
	var b_head: int = _bone("DEF-head")
	var b_hips: int = _bone("DEF-hips")

	var coat := _cloth(COAT_TEAL)
	var pants := _cloth(COAT_TEAL.darkened(0.55))  # dark slate: heavily darkened coat teal
	var trim := _fur(TRIM_WHITE)
	var scarf := _cloth(SCARF_RED)
	var coal := _cloth(COAL_DARK)
	var gold := _metal(BUCKLE_GOLD)
	var skin := _cloth(SKIN)
	skin.roughness = 0.85

	# Torso: teal coat capsule stretched spine-to-neck; the overlap extends
	# its rounded caps down over the hips and up under the chin.
	_add_segment(_capsule(0.16), coat, b_spine, b_neck, 0.5, 0.2)

	if b_spine != -1:
		var spine_o: Vector3 = _skeleton.get_bone_global_rest(b_spine).origin
		# Fur hem ring near the coat's bottom cap.
		var hem := Node3D.new()
		hem.add_child(_part(_torus(0.1, 0.16), trim, Vector3.ZERO))
		_add_anchored(hem, b_spine, spine_o + Vector3(0, -0.055, 0))
		# Coal belt at the hips with a small gold buckle on the +Z front.
		var belt := Node3D.new()
		belt.add_child(_part(_torus(0.135, 0.19), coal, Vector3.ZERO))
		belt.add_child(_part(_box(Vector3(0.055, 0.05, 0.025)), gold, Vector3(0, 0, 0.18)))
		_add_anchored(belt, b_hips if b_hips != -1 else b_spine, spine_o + Vector3(0, 0.06, 0))

	# Head: skin sphere sized exactly for the hat system, dot eyes + rosy
	# cheeks on the +Z face like the elf. Cheek tone follows EnemySanta's
	# convention: EMBER_RED pulled 40% toward skin.
	if b_head != -1:
		var head_center: Vector3 = _skeleton.get_bone_global_rest(b_head).origin + Vector3(0, HEAD_LIFT, 0)
		var cheek := _cloth(SCARF_RED.lerp(SKIN, 0.4))
		var head := Node3D.new()
		head.add_child(_part(_sph(HEAD_RADIUS, 12), skin, Vector3.ZERO))
		for side in [-1, 1]:
			head.add_child(_part(_sph(0.022, 8), coal, Vector3(0.055 * side, 0.02, 0.135)))
			head.add_child(_part(_sph(0.016, 8), cheek, Vector3(0.085 * side, -0.03, 0.115)))
		hat_mount = Node3D.new()
		hat_mount.name = "HatMount"
		hat_mount.position = Vector3(0, HEAD_RADIUS, 0)
		head.add_child(hat_mount)
		_add_anchored(head, b_head, head_center)

	# Scarf: ember wrap at the neck, tail + trim fringe hanging down the
	# back (-Z, toward the chase camera).
	if b_neck != -1:
		var neck_o: Vector3 = _skeleton.get_bone_global_rest(b_neck).origin
		var scarf_root := Node3D.new()
		scarf_root.add_child(_part(_torus(0.075, 0.155), scarf, Vector3(0, 0.02, 0)))
		scarf_root.add_child(_part(_box(Vector3(0.09, 0.2, 0.032)), scarf, Vector3(0, -0.09, -0.135), Vector3(10, 0, 4)))
		scarf_root.add_child(_part(_box(Vector3(0.095, 0.045, 0.034)), trim, Vector3(0, -0.205, -0.155), Vector3(10, 0, 4)))
		_add_anchored(scarf_root, b_neck, neck_o)

	# Arms: teal sleeves with sphere shoulder/elbow joints, fur cuff at each
	# wrist, ember mitten spheres at the hands.
	for side in ["L", "R"]:
		var b_upper: int = _bone("DEF-upper_arm." + side)
		var b_fore: int = _bone("DEF-forearm." + side)
		var b_hand: int = _bone("DEF-hand." + side)
		var arm_parts: Array[Node3D] = []
		arm_parts.append(_add_joint_sphere(0.068, coat, b_upper))
		arm_parts.append(_add_joint_sphere(0.058, coat, b_fore))
		arm_parts.append(_add_segment(_cyl(0.052), coat, b_upper, b_fore, 0.5, 0.04))
		arm_parts.append(_add_segment(_cyl(0.048), coat, b_fore, b_hand, 0.5, 0.04))
		# Cuff rides the forearm-to-wrist line so it wraps the arm correctly
		# in any rest pose (a bone-anchored torus would sit axis-aligned).
		arm_parts.append(_add_segment(_torus(0.045, 0.085), trim, b_fore, b_hand, 0.94))
		if b_fore != -1 and b_hand != -1:
			var fore_o: Vector3 = _skeleton.get_bone_global_rest(b_fore).origin
			var hand_o: Vector3 = _skeleton.get_bone_global_rest(b_hand).origin
			var mitten := Node3D.new()
			mitten.add_child(_part(_sph(0.07, 10), scarf, Vector3.ZERO))
			arm_parts.append(_add_anchored(mitten, b_hand, hand_o + (hand_o - fore_o).normalized() * 0.06))
		if side == "R":
			for p in arm_parts:
				if p != null:
					right_arm_parts.append(p)

	# Legs: dark slate pant cylinders with sphere hip/knee joints, fur ring
	# at each boot top, coal boots extending toward the toes (+Z at rest).
	for side in ["L", "R"]:
		var b_thigh: int = _bone("DEF-thigh." + side)
		var b_shin: int = _bone("DEF-shin." + side)
		var b_foot: int = _bone("DEF-foot." + side)
		_add_joint_sphere(0.075, pants, b_thigh)
		_add_joint_sphere(0.062, pants, b_shin)
		_add_segment(_cyl(0.068), pants, b_thigh, b_shin, 0.5, 0.04)
		_add_segment(_cyl(0.055), pants, b_shin, b_foot, 0.5, 0.04)
		_add_segment(_torus(0.055, 0.105), trim, b_shin, b_foot, 0.93)
		if b_foot != -1:
			var ankle: Vector3 = _skeleton.get_bone_global_rest(b_foot).origin
			var boot := Node3D.new()
			boot.add_child(_part(_box(Vector3(0.115, 0.09, 0.21)), coal, Vector3(0, -0.045, 0.045)))
			boot.add_child(_part(_sph(0.052, 10), coal, Vector3(0, -0.055, 0.15)))  # rounded toe
			_add_anchored(boot, b_foot, ankle)

# --- Part registration ------------------------------------------------------
## Registers a radially symmetric mesh stretched between two joints. Cylinder/
## capsule heights are sized ONCE here from the rest-pose joint distance
## (+overlap so bending joints never open a gap); toruses keep their size.
## `t` picks the point along the joint-to-joint line the mesh is pinned to
## (0.5 = midpoint; ~1.0 = a wrap ring at the far joint).
func _add_segment(mesh: Mesh, mat: StandardMaterial3D, bone_a: int, bone_b: int, t: float = 0.5, overlap: float = 0.0) -> MeshInstance3D:
	if bone_a == -1 or bone_b == -1:
		return null
	var rest_len: float = (_skeleton.get_bone_global_rest(bone_b).origin - _skeleton.get_bone_global_rest(bone_a).origin).length()
	if mesh is CylinderMesh:
		(mesh as CylinderMesh).height = rest_len + overlap
	elif mesh is CapsuleMesh:
		var cap := mesh as CapsuleMesh
		cap.height = maxf(rest_len + overlap, cap.radius * 2.05)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	_segments.append({"mi": mi, "a": bone_a, "b": bone_b, "t": t})
	return mi

## Registers an assembly that follows one bone's full pose, starting from an
## axis-aligned rest placement at `rest_origin` (skeleton space).
func _add_anchored(node: Node3D, bone: int, rest_origin: Vector3) -> Node3D:
	if bone == -1:
		node.free()  # never entered the tree - free immediately, not deferred
		return null
	add_child(node)
	var local_xf: Transform3D = _skeleton.get_bone_global_rest(bone).affine_inverse() * Transform3D(Basis.IDENTITY, rest_origin)
	_anchored.append({"node": node, "bone": bone, "xf": local_xf})
	return node

## Convenience: a joint sphere pinned to a bone's origin.
func _add_joint_sphere(radius: float, mat: StandardMaterial3D, bone: int) -> Node3D:
	if bone == -1:
		return null
	var joint := Node3D.new()
	joint.add_child(_part(_sph(radius, 10), mat, Vector3.ZERO))
	return _add_anchored(joint, bone, _skeleton.get_bone_global_rest(bone).origin)

# --- Pose following ---------------------------------------------------------
func _update_parts() -> void:
	for s in _segments:
		var a: Vector3 = _skeleton.get_bone_global_pose(s["a"]).origin
		var b: Vector3 = _skeleton.get_bone_global_pose(s["b"]).origin
		(s["mi"] as MeshInstance3D).transform = _segment_transform(a, b, s["t"])
	for p in _anchored:
		(p["node"] as Node3D).transform = _skeleton.get_bone_global_pose(p["bone"]) * (p["xf"] as Transform3D)

## Orthonormal transform at a point along a-to-b with local +Y aligned to
## the segment. Roll is arbitrary - every segment mesh is radially symmetric.
func _segment_transform(a: Vector3, b: Vector3, t: float) -> Transform3D:
	var dir: Vector3 = b - a
	var y: Vector3 = dir.normalized() if dir.length_squared() > 0.000001 else Vector3.UP
	var helper: Vector3 = Vector3.UP if absf(y.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x: Vector3 = helper.cross(y).normalized()
	var z: Vector3 = x.cross(y)
	return Transform3D(Basis(x, y, z), a.lerp(b, t))

# --- Material conventions (ART_DIRECTION.md section 4) ----------------------
static func _cloth(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m

static func _fur(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.97
	return m

static func _metal(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.35
	m.metallic = 0.9
	return m

# --- Mesh helpers (explicit low segment counts - web budget) -----------------
static func _sph(radius: float, seg: int = 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = seg
	m.rings = maxi(4, seg / 2)
	return m

static func _cyl(radius: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = 0.2  # placeholder - _add_segment sizes it from the rest pose
	m.radial_segments = 10
	return m

static func _capsule(radius: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = radius * 2.5  # placeholder - _add_segment sizes it from the rest pose
	m.radial_segments = 10
	m.rings = 4
	return m

static func _torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 20
	m.ring_segments = 8
	return m

static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

static func _part(mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	return mi
