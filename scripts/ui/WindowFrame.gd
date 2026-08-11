extends Control
## The main menu window's wood frame plus a small snow-dusted sill ledge
## poking out below it. The night scene itself (sky, moon, treeline) lives
## on the sibling "Pane" control, and the crossbar mullions are plain
## ColorRects (MullionH/MullionV) layered after Pane in MainMenu.tscn -
## deliberately NOT drawn here, since anything drawn in this _draw() call
## renders BEFORE this node's children, so mullions drawn here would end up
## hidden under Pane's opaque sky instead of sitting in front of the glass.
##
## FRAME_THICKNESS must match the 22px inset MainMenu.tscn gives the Pane/
## MullionH/MullionV children - it's what makes this frame's inner bevel
## line up with the hole those children fill.

const FRAME_COLOR := Color(0.36, 0.22, 0.12)
const FRAME_HILIGHT := Color(0.5, 0.32, 0.17)
const FRAME_SHADOW := Color(0.2, 0.12, 0.05)
const SILL_COLOR := Color(0.3, 0.18, 0.1)
const SNOW_DRIFT_COLOR := Color(0.95, 0.97, 1.0, 0.92)
const FRAME_THICKNESS := 22.0

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FRAME_COLOR)
	draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), FRAME_HILIGHT, false, 3.0)
	var inner_size: Vector2 = size - Vector2(FRAME_THICKNESS, FRAME_THICKNESS) * 2.0
	draw_rect(Rect2(Vector2(FRAME_THICKNESS, FRAME_THICKNESS), inner_size), FRAME_SHADOW, false, 3.0)

	# Sill: a touch wider than the frame, protruding below it.
	draw_rect(Rect2(Vector2(-14.0, size.y), Vector2(size.x + 28.0, 16.0)), SILL_COLOR)
	var sill_y: float = size.y + 5.0
	draw_circle(Vector2(size.x * 0.5 - 65.0, sill_y), 9.0, SNOW_DRIFT_COLOR)
	draw_circle(Vector2(size.x * 0.5, sill_y - 3.0), 12.0, SNOW_DRIFT_COLOR)
	draw_circle(Vector2(size.x * 0.5 + 60.0, sill_y), 8.0, SNOW_DRIFT_COLOR)
