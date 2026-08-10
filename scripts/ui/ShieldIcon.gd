extends Control
## Filled shield badge used for the armor readout.

@export var fill_color: Color = Color(0.55, 0.6, 0.68):
	set(v):
		fill_color = v
		queue_redraw()
@export var outline_color: Color = Color(0.08, 0.08, 0.12)
@export var outline_width: float = 4.0

const SHAPE_POINTS: Array[Vector2] = [
	Vector2(0.5, 0.02),
	Vector2(0.9, 0.16),
	Vector2(0.9, 0.5),
	Vector2(0.5, 0.98),
	Vector2(0.1, 0.5),
	Vector2(0.1, 0.16),
]

func _draw() -> void:
	var poly := PackedVector2Array()
	for p in SHAPE_POINTS:
		poly.append(Vector2(p.x * size.x, p.y * size.y))
	draw_colored_polygon(poly, fill_color)
	var closed: PackedVector2Array = poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, outline_color, outline_width, true)
