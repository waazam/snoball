extends Control
## The main menu's backdrop: a deep-blue damask wallpaper with a tone-on-
## tone embroidered holly leaf motif tiled in a staggered brick pattern,
## plus a faint diagonal weave texture underneath. Everything here is
## drawn procedurally in _draw() - same approach as HeartIcon.gd/
## ShieldIcon.gd/CircleIcon.gd - this project has no texture pipeline for
## UI art.

const BASE_COLOR := Color(0.16, 0.22, 0.42)
const WEAVE_COLOR := Color(0.22, 0.29, 0.5, 0.35)
const THREAD_COLOR := Color(0.38, 0.5, 0.74, 0.55)
const STITCH_COLOR := Color(0.11, 0.16, 0.32, 0.6)
const BERRY_COLOR := Color(0.72, 0.16, 0.2, 0.65)

const TILE_SPACING := 92.0
const WEAVE_SPACING := 26.0

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BASE_COLOR)
	_draw_weave()
	_draw_holly_grid()

## Barely-there diagonal hatching so the wall reads as woven fabric instead
## of flat paint, even where there's no holly motif nearby.
func _draw_weave() -> void:
	var diag: float = size.x + size.y
	var steps: int = int(diag / WEAVE_SPACING) + 2
	for i in steps:
		var offset: float = i * WEAVE_SPACING - size.y
		draw_line(Vector2(offset, 0.0), Vector2(offset + size.y, size.y), WEAVE_COLOR, 1.0)

## Rows of holly motifs, alternate rows offset by half a tile - the classic
## brick/diamond layout real damask wallpaper uses so the repeat doesn't
## read as an obvious grid.
func _draw_holly_grid() -> void:
	var rows: int = int(size.y / TILE_SPACING) + 3
	var cols: int = int(size.x / TILE_SPACING) + 3
	for row in rows:
		var y: float = row * TILE_SPACING - TILE_SPACING
		var row_offset: float = (TILE_SPACING * 0.5) if row % 2 == 1 else 0.0
		for col in cols:
			var x: float = col * TILE_SPACING - TILE_SPACING + row_offset
			_draw_holly_motif(Vector2(x, y))

## Three stitched leaflets fanned around a stem point, plus a small
## cluster of berries beneath - one embroidered holly sprig.
func _draw_holly_motif(center: Vector2) -> void:
	_draw_leaf(center + Vector2(-10, -6), -35.0)
	_draw_leaf(center + Vector2(10, -6), 35.0)
	_draw_leaf(center + Vector2(0, -14), 0.0)
	for i in 3:
		var a: float = deg_to_rad(200.0 + i * 40.0)
		var berry_pos: Vector2 = center + Vector2(cos(a), sin(a)) * 6.0 + Vector2(0, 12)
		draw_circle(berry_pos, 3.0, BERRY_COLOR)

func _draw_leaf(origin: Vector2, angle_deg: float) -> void:
	var pts: PackedVector2Array = _leaf_polygon(26.0, 12.0)
	var xf := Transform2D(deg_to_rad(angle_deg), origin)
	var world_pts := PackedVector2Array()
	for p in pts:
		world_pts.append(xf * p)
	draw_colored_polygon(world_pts, THREAD_COLOR)
	var closed: PackedVector2Array = world_pts.duplicate()
	closed.append(world_pts[0])
	draw_polyline(closed, STITCH_COLOR, 1.4, true)

## A spiky lens shape - alternating outer point / inner notch along both
## edges, tapered at each end - reads as a holly leaflet at small scale.
func _leaf_polygon(length: float, width: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var teeth := 4
	for i in range(teeth + 1):
		var t: float = float(i) / teeth
		var x: float = lerp(-length * 0.5, length * 0.5, t)
		var env: float = sin(t * PI)
		var spike: float = 1.0 if i % 2 == 0 else 0.55
		pts.append(Vector2(x, -width * 0.5 * env * spike))
	for i in range(teeth, -1, -1):
		var t: float = float(i) / teeth
		var x: float = lerp(-length * 0.5, length * 0.5, t)
		var env: float = sin(t * PI)
		var spike: float = 1.0 if i % 2 == 0 else 0.55
		pts.append(Vector2(x, width * 0.5 * env * spike))
	return pts
