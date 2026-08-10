extends Control
## On-screen movement joystick for touch devices. Drives the same four
## move_* input actions the keyboard uses (plus "sprint" past a deflection
## threshold), so Player.gd needs no changes to support it.

const RADIUS := 70.0
const DEAD_ZONE := 0.25
const SPRINT_THRESHOLD := 0.85

var _active: bool = true
var _touch_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func set_active(v: bool) -> void:
	if _active and not v:
		_end_touch()
	_active = v

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_touch_index = event.index
				_update_knob(event.position)
				get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_end_touch()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_knob(event.position)
			get_viewport().set_input_as_handled()

func _update_knob(global_pos: Vector2) -> void:
	var local: Vector2 = global_pos - get_global_rect().position
	var offset: Vector2 = local - size / 2.0
	var dist: float = minf(offset.length(), RADIUS)
	_knob_offset = (offset.normalized() * dist) if offset.length() > 0.001 else Vector2.ZERO
	_apply_actions(_knob_offset / RADIUS)
	queue_redraw()

func _end_touch() -> void:
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	_release_all()
	queue_redraw()

func _apply_actions(norm: Vector2) -> void:
	var mag: float = norm.length()
	if mag < DEAD_ZONE:
		_release_all()
		return
	_set_action("move_forward", norm.y < -0.3)
	_set_action("move_back", norm.y > 0.3)
	_set_action("move_left", norm.x < -0.3)
	_set_action("move_right", norm.x > 0.3)
	_set_action("sprint", mag > SPRINT_THRESHOLD)

func _set_action(action: String, should_press: bool) -> void:
	if should_press and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not should_press and Input.is_action_pressed(action):
		Input.action_release(action)

func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)

func _draw() -> void:
	var c: Vector2 = size / 2.0
	draw_circle(c, RADIUS, Color(1, 1, 1, 0.16))
	draw_arc(c, RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.55), 3.0, true)
	var knob_color: Color = Color(1, 1, 1, 0.6) if _touch_index != -1 else Color(1, 1, 1, 0.4)
	draw_circle(c + _knob_offset, RADIUS * 0.45, knob_color)
