extends Control
## A round on-screen touch button that presses/releases a real input action
## for as long as a finger is down on it - identical to a keyboard/mouse
## press from Player.gd's point of view, so no other code needs to know
## whether an action came from touch, mouse, or keyboard.

@export var action_name: String = ""
@export var bg_color: Color = Color(1, 1, 1, 0.28)

var _active: bool = true
var _touch_index: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func set_active(v: bool) -> void:
	if _active and not v:
		_release()
	_active = v
	visible = v

func _input(event: InputEvent) -> void:
	if not _active or action_name == "":
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_touch_index = event.index
				Input.action_press(action_name)
				queue_redraw()
				get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_release()
			get_viewport().set_input_as_handled()

func _release() -> void:
	if _touch_index != -1 or Input.is_action_pressed(action_name):
		_touch_index = -1
		Input.action_release(action_name)
		queue_redraw()

func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) / 2.0
	var color: Color = bg_color
	if _touch_index != -1:
		color = Color(bg_color.r, bg_color.g, bg_color.b, minf(1.0, bg_color.a + 0.35))
	draw_circle(c, r, color)
	draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 3.0, true)
