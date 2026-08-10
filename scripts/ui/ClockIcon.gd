extends Control
## Simple clock face with a slowly ticking hand, used for the wave readout.

@export var face_color: Color = Color(0.95, 0.97, 1.0)
@export var outline_color: Color = Color(0.08, 0.08, 0.12)

var _hand_angle: float = -0.7

func _process(delta: float) -> void:
	_hand_angle += delta * 0.9
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) / 2.0 - 4.0
	draw_circle(c, r, face_color)
	draw_arc(c, r, 0.0, TAU, 48, outline_color, 4.0, true)
	for i in 4:
		var a: float = i * PI / 2.0 - PI / 2.0
		var p1: Vector2 = c + Vector2(cos(a), sin(a)) * (r - 6.0)
		var p2: Vector2 = c + Vector2(cos(a), sin(a)) * (r - 14.0)
		draw_line(p1, p2, outline_color, 3.0)
	var hand_end: Vector2 = c + Vector2(cos(_hand_angle), sin(_hand_angle)) * (r * 0.62)
	draw_line(c, hand_end, outline_color, 5.0, true)
	draw_circle(c, 4.0, outline_color)
