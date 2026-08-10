extends Control
## Simple filled circle badge, used for the current-snowball ("Ball") icon.

@export var fill_color: Color = Color(0.8, 0.9, 1.0):
	set(v):
		fill_color = v
		queue_redraw()
@export var outline_color: Color = Color(0.08, 0.08, 0.12)
@export var outline_width: float = 4.0

func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) / 2.0 - outline_width
	draw_circle(c, r, fill_color)
	draw_arc(c, r, 0.0, TAU, 48, outline_color, outline_width, true)
