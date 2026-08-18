extends SubViewportContainer
## Small live-rotating 3D preview of a snowball's actual procedural model
## (SnowballVisuals.build), layered over SnowballRow's flat CircleIcon so
## the equip menu shows the real shape/material instead of just a color
## swatch. Viewport/camera/lights are all built in code here - same
## procedural-only convention as SnowballVisuals.gd/HatVisuals.gd, no
## separate .tscn needed. Rebuilt in place by setup() whenever the row's id
## changes; SnowballRow.gd only calls setup()/shows this for unlocked rows,
## so a not-yet-unlocked type stays hidden behind the plain gray swatch
## instead of spoiling its look ahead of the wave-unlock reward.

const VIEWPORT_SIZE := 128
# Snowball bodies are RADIUS=0.22 (SnowballVisuals.RADIUS), but studs/spikes/
# motes on several shapes (sticks, nails, ice, death_ball) reach out to
# ~0.28 from center - distance/fov below are sized off that, not the bare
# body radius, so nothing pokes outside the frame.
const CAMERA_DISTANCE := 1.4
const CAMERA_FOV := 30.0
const ROT_SPEED := 0.6  # rad/s, slow turntable spin

# Matches Main.tscn's "Alpenglow Dusk" key+fill light pair (WorldEnvironment/
# DuskSun/MoonFill) so a previewed shape's materials (rim highlights,
# clearcoat, emission) read the same here as they do in flight.
const KEY_COLOR := Color(1, 0.627451, 0.360784)
const FILL_COLOR := Color(0.788235, 0.839216, 0.933333)

var _viewport: SubViewport
var _mesh_root: Node3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEWPORT_SIZE, VIEWPORT_SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	add_child(_viewport)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.12, CAMERA_DISTANCE)
	camera.fov = CAMERA_FOV
	_viewport.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-18, 145, 0)
	key.light_color = KEY_COLOR
	key.light_energy = 1.3
	_viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-55, -35, 0)
	fill.light_color = FILL_COLOR
	fill.light_energy = 0.6
	_viewport.add_child(fill)

func setup(shape: String, color: Color) -> void:
	if _mesh_root and is_instance_valid(_mesh_root):
		_mesh_root.queue_free()
	_mesh_root = SnowballVisuals.build(shape, color)
	_viewport.add_child(_mesh_root)

func _process(delta: float) -> void:
	if _mesh_root and is_instance_valid(_mesh_root):
		_mesh_root.rotate_y(ROT_SPEED * delta)

## Stops the render target from redrawing every frame while the row (or the
## whole menu) is hidden, since ScrollContainer only clips rows visually -
## it doesn't stop an off-screen SubViewport from otherwise still rendering.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
