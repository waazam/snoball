extends Control
## Filled heart badge (classic parametric heart curve) used for the health
## readout. A dim "empty" heart always renders in the background; a red
## heart renders on top, clipped to the bottom fraction matching the
## current health ratio - so it visually drains from the top down as
## health drops from 100 to 0, like a liquid gauge.

@export var fill_color: Color = Color(0.88, 0.15, 0.22)
@export var empty_color: Color = Color(0.32, 0.3, 0.33, 0.55)
@export var outline_color: Color = Color(0.08, 0.08, 0.12)
@export var outline_width: float = 5.0

const STEPS := 48

var _is_fill_instance: bool = false
var _ratio: float = 1.0
var _fill_clip: Control
var _fill_heart: Control

func _ready() -> void:
	resized.connect(_update_fill_layout)
	if _is_fill_instance:
		return
	_fill_clip = Control.new()
	_fill_clip.clip_contents = true
	_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill_clip)
	_fill_heart = Control.new()
	_fill_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_heart.set_script(get_script())
	_fill_heart._is_fill_instance = true
	_fill_heart.fill_color = fill_color
	_fill_heart.outline_width = 0.0
	_fill_clip.add_child(_fill_heart)
	_update_fill_layout()

func set_fill_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	_update_fill_layout()

func _update_fill_layout() -> void:
	if _fill_clip == null or _fill_heart == null:
		return
	var h: float = size.y
	var fill_h: float = h * _ratio
	_fill_clip.position = Vector2(0.0, h - fill_h)
	_fill_clip.size = Vector2(size.x, fill_h)
	_fill_heart.position = Vector2(0.0, -(h - fill_h))
	_fill_heart.size = size
	_fill_heart.queue_redraw()

func _build_heart_polygon() -> PackedVector2Array:
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
	var pad: float = 4.0 + (outline_width if outline_width > 0.0 else 5.0)
	var scale_f: float = minf((size.x - pad * 2.0) / w, (size.y - pad * 2.0) / h)
	var cx: float = (min_x + max_x) / 2.0
	var cy: float = (min_y + max_y) / 2.0
	var center: Vector2 = size / 2.0

	var poly := PackedVector2Array()
	for p in raw:
		poly.append(center + Vector2((p.x - cx) * scale_f, (p.y - cy) * scale_f))
	return poly

func _draw() -> void:
	var poly: PackedVector2Array = _build_heart_polygon()
	var color: Color = fill_color if _is_fill_instance else empty_color
	draw_colored_polygon(poly, color)
	if outline_width > 0.0:
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, outline_color, outline_width, true)
