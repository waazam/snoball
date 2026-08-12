extends Control
## Filled circle badge, used for the current-snowball ("Ball") icon.
## Tinted to the equipped snowball's color by HUD.gd; a fixed #39466E outer
## ring (ART_DIRECTION.md 6g) keeps pale snowballs visible against snow,
## and a soft top-left highlight sells the ball as a sphere.

@export var fill_color: Color = Color(0.8, 0.9, 1.0):
	set(v):
		fill_color = v
		queue_redraw()
@export var outline_color: Color = Color("#111527")
@export var outline_width: float = 4.0

const RING_COLOR := Color("#39466E")
const HIGHLIGHT_COLOR := Color(1, 1, 1, 0.2)
const SHADE_COLOR := Color(0.066667, 0.082353, 0.152941, 0.14)  # #111527

func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) / 2.0 - outline_width - 3.0
	draw_circle(c, r, fill_color)
	# Lower-right shade + upper-left glint for a spherical read.
	draw_circle(c + Vector2(r * 0.22, r * 0.26), r * 0.6, SHADE_COLOR)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.34), r * 0.32, HIGHLIGHT_COLOR)
	draw_arc(c, r, 0.0, TAU, 48, outline_color, outline_width, true)
	draw_arc(c, r + outline_width * 0.5 + 1.5, 0.0, TAU, 48, RING_COLOR, 2.0, true)
