extends Control
## Filled shield badge used for the armor readout.
## ART_DIRECTION.md UI palette: armor #7FB2D9, outline #111527, with a
## faint snowflake emblem in SNOW_LIT #EAF2FB.

@export var fill_color: Color = Color("#7FB2D9"):
	set(v):
		fill_color = v
		queue_redraw()
@export var outline_color: Color = Color("#111527")
@export var outline_width: float = 4.0

const EMBLEM_COLOR := Color(0.917647, 0.94902, 0.984314, 0.55)  # #EAF2FB

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
	# Six-spoke snowflake emblem centered on the shield face.
	var c := Vector2(size.x * 0.5, size.y * 0.44)
	var arm: float = minf(size.x, size.y) * 0.2
	for i in 6:
		var dir := Vector2.from_angle(TAU * float(i) / 6.0 - PI / 2.0)
		draw_line(c, c + dir * arm, EMBLEM_COLOR, 1.6, true)
	var closed: PackedVector2Array = poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, outline_color, outline_width, true)
