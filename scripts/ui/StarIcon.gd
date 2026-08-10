extends Control
## Hand-drawn-style 5-point star badge used for the health readout.

@export var fill_color: Color = Color(0.95, 0.97, 1.0)
@export var outline_color: Color = Color(0.08, 0.08, 0.12)
@export var outline_width: float = 5.0
@export var points: int = 5

func _draw() -> void:
	var c: Vector2 = size / 2.0
	var outer: float = minf(size.x, size.y) / 2.0 - outline_width
	var inner: float = outer * 0.45
	var poly := PackedVector2Array()
	var total: int = points * 2
	for i in total:
		var r: float = outer if i % 2 == 0 else inner
		var angle: float = -PI / 2.0 + i * PI / points
		poly.append(c + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(poly, fill_color)
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, outline_color, outline_width, true)
