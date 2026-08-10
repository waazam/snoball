extends Control
## Filled heart badge (classic parametric heart curve) used for the health
## readout, replacing the old star.

@export var fill_color: Color = Color(0.88, 0.15, 0.22)
@export var outline_color: Color = Color(0.08, 0.08, 0.12)
@export var outline_width: float = 5.0

const STEPS := 48

func _draw() -> void:
	var raw: Array[Vector2] = []
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	for i in STEPS:
		var t: float = TAU * float(i) / float(STEPS)
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		raw.append(Vector2(x, y))
		min_x = minf(min_x, x)
		max_x = maxf(max_x, x)
		min_y = minf(min_y, y)
		max_y = maxf(max_y, y)

	var w: float = max_x - min_x
	var h: float = max_y - min_y
	var pad: float = outline_width + 4.0
	var scale_f: float = minf((size.x - pad * 2.0) / w, (size.y - pad * 2.0) / h)
	var cx: float = (min_x + max_x) / 2.0
	var cy: float = (min_y + max_y) / 2.0
	var center: Vector2 = size / 2.0

	var poly := PackedVector2Array()
	for p in raw:
		poly.append(center + Vector2((p.x - cx) * scale_f, (p.y - cy) * scale_f))

	draw_colored_polygon(poly, fill_color)
	var closed: PackedVector2Array = poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, outline_color, outline_width, true)
