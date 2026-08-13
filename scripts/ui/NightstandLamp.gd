extends Control
## A nightstand to the left of the main menu's window, with a striped
## cloth draped over it and a glowing lamp - drawn procedurally in
## _draw(), same technique as WindowFrame.gd/Wallpaper.gd/NightSky.gd (no
## texture pipeline in this project). Positioned as a fixed-offset Control
## sibling of Window under MainMenu's Root (not inside the window's Pane -
## this sits in the foreground room, not the night scene behind the
## glass).
##
## Scaled to feel like real furniture next to a ~630px-tall window instead
## of a small icon, and deliberately drawn TALL ENOUGH that its legs run
## past the bottom of the 900-tall screen and get cropped by the viewport
## edge - the same way a piece of furniture in the corner of a real,
## photographed room has its feet cut off by the frame instead of neatly
## fitting a "sticker" bounding box floating on the wall. No clipping code
## needed for that - Control.clip_contents is left off, and Godot simply
## doesn't render past the viewport, so drawing the legs long enough to
## reach off-screen is the whole trick.
##
## Wood tones are WindowFrame.gd's own FRAME_COLOR/FRAME_HILIGHT/
## FRAME_SHADOW/SILL_COLOR constants (not re-declared here) so the
## nightstand matches the windowsill exactly rather than a close copy that
## could drift out of sync if that palette ever changes.
##
## The lamp glow is the same "stacked circles of warm EMBER_GOLD at
## falling alpha" halo trick NightSky.gd's cabin window already uses, just
## scaled up into a broad, very-soft wash so it reads as ambient light
## spilling across the left side of the room instead of a single small
## glow - left un-clipped so those big circles can extend well past this
## control's own small bounding rect.

const WOOD := WindowFrame.FRAME_COLOR
const WOOD_HILIGHT := WindowFrame.FRAME_HILIGHT
const WOOD_SHADOW := WindowFrame.FRAME_SHADOW
const WOOD_SLAB := WindowFrame.SILL_COLOR  # the windowsill's own tone, for the tabletop specifically

const CLOTH_GREEN := Color(0.145, 0.376, 0.235)   # PINE_LIT-family deep Christmas green
const CLOTH_GREEN_SHADOW := Color(0.098, 0.278, 0.169)  # underside of the hanging flap
const STRIPE_RED := Color("#E8483F")  # EMBER_RED, matches the scarf/mitten accents elsewhere
const STRIPE_SPACING := 18.0
const STRIPE_WIDTH := 4.0

const SHADE_COLOR := Color("#FFE9C9")  # CANDLE_WHITE - matches NightSky.gd's cabin window
const SHADE_SHADOW := Color(0.85, 0.72, 0.55)
const BASE_METAL := Color("#FFB84D")  # EMBER_GOLD, the game's one recurring metal accent
const GLOW_COLOR := Color("#FFB84D")  # old-school warm incandescent yellow-gold
const CONTACT_SHADOW := Color(0.039, 0.031, 0.071, 0.35)  # matches the game's shared shadow tone (MainMenu buttons' own shadow_color)

# Local-space layout (this control's own rect - see the .tscn for its
# offset - not screen space). Nightstand center x; everything else is
# relative to it and to the y-bands below, top to bottom. Roughly 1.6x the
# original pass's dimensions, tuned against the window's own 560x630
# frame so the nightstand reads at real-furniture scale next to it -
# BODY_BOTTOM_Y/LEGS_BOTTOM_Y in particular are picked so the cabinet body
# stays on-screen but the legs run well past this control's own bottom
# (900 - offset_top, see the .tscn) and off the visible screen.
const CENTER_X := 160.0
const SHADE_TOP_Y := 30.0
const SHADE_BOTTOM_Y := 115.0
const STEM_BOTTOM_Y := 170.0
const LAMP_BASE_BOTTOM_Y := 188.0
const CLOTH_TOP_Y := 188.0
const CLOTH_SURFACE_Y := 206.0
const CLOTH_HANG_BOTTOM_Y := 328.0
const SLAB_BOTTOM_Y := 234.0
const BODY_BOTTOM_Y := 494.0
const LEGS_BOTTOM_Y := 654.0  # global y 994 - well past the 900-tall screen, cropped by the viewport

var _time: float = 0.0
var _flicker: float = 1.0

func _ready() -> void:
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	_time += delta
	# Gentle irregular flicker (two off-beat sine waves, not one clean
	# pulse) - reads as an old incandescent bulb rather than a modern
	# steady LED.
	_flicker = 0.88 + 0.08 * sin(_time * 2.3) + 0.05 * sin(_time * 5.1 + 1.4)
	queue_redraw()

func _draw() -> void:
	_draw_room_glow()
	_draw_contact_shadow()
	_draw_legs()
	_draw_body()
	_draw_slab()
	_draw_cloth_hang()
	_draw_cloth_top()
	_draw_lamp()

## Broad, very soft ambient wash plus a tighter halo/core around the shade
## opening - drawn first so the furniture and lamp render on top of it.
func _draw_room_glow() -> void:
	var bulb := Vector2(CENTER_X, SHADE_BOTTOM_Y - 6.0)
	draw_circle(Vector2(CENTER_X, 260.0), 480.0, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.055 * _flicker))
	draw_circle(Vector2(CENTER_X, 220.0), 280.0, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.06 * _flicker))
	draw_circle(bulb, 165.0, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.13 * _flicker))
	draw_circle(bulb, 75.0, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.24 * _flicker))
	draw_circle(bulb, 30.0, Color(1.0, 0.92, 0.72, 0.48 * _flicker))

## A soft, slightly-offset dark silhouette behind the cabinet body -
## grounds it against the flat wallpaper instead of reading as a flat
## cutout pasted on top of it (this was the biggest source of the earlier
## "sticker" look).
func _draw_contact_shadow() -> void:
	var w := 246.0
	var offset := Vector2(14.0, 16.0)
	draw_rect(Rect2(Vector2(CENTER_X - w * 0.5, SLAB_BOTTOM_Y) + offset, Vector2(w, BODY_BOTTOM_Y - SLAB_BOTTOM_Y + 60.0)), CONTACT_SHADOW)

func _draw_legs() -> void:
	for cx in [CENTER_X - 95.0, CENTER_X + 95.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 11.0, BODY_BOTTOM_Y),
			Vector2(cx + 11.0, BODY_BOTTOM_Y),
			Vector2(cx + 7.0, LEGS_BOTTOM_Y),
			Vector2(cx - 7.0, LEGS_BOTTOM_Y),
		]), WOOD_SHADOW)

func _draw_body() -> void:
	var w := 230.0
	draw_rect(Rect2(Vector2(CENTER_X - w * 0.5, SLAB_BOTTOM_Y), Vector2(w, BODY_BOTTOM_Y - SLAB_BOTTOM_Y)), WOOD)
	# Left-edge highlight / right-edge shadow so the cabinet reads as a
	# rounded volume instead of a flat card, same convention WindowFrame's
	# own hilight/shadow bevel lines use.
	draw_rect(Rect2(Vector2(CENTER_X - w * 0.5, SLAB_BOTTOM_Y), Vector2(6.0, BODY_BOTTOM_Y - SLAB_BOTTOM_Y)), WOOD_HILIGHT)
	draw_rect(Rect2(Vector2(CENTER_X + w * 0.5 - 6.0, SLAB_BOTTOM_Y), Vector2(6.0, BODY_BOTTOM_Y - SLAB_BOTTOM_Y)), WOOD_SHADOW)
	# Two stacked drawer faces, each with its own knob - reads as a proper
	# nightstand cabinet at this bigger scale instead of one shallow drawer.
	var drawer_w := w - 46.0
	var drawer_h := 64.0
	var gap := 14.0
	var drawer_top := SLAB_BOTTOM_Y + 22.0
	for i in 2:
		var top: float = drawer_top + i * (drawer_h + gap)
		draw_rect(Rect2(Vector2(CENTER_X - drawer_w * 0.5, top), Vector2(drawer_w, drawer_h)), WOOD_SHADOW)
		draw_rect(Rect2(Vector2(CENTER_X - drawer_w * 0.5 + 4.0, top + 4.0), Vector2(drawer_w - 8.0, drawer_h - 8.0)), WOOD)
		draw_circle(Vector2(CENTER_X, top + drawer_h * 0.5), 6.5, BASE_METAL)

func _draw_slab() -> void:
	var w := 258.0
	draw_rect(Rect2(Vector2(CENTER_X - w * 0.5, CLOTH_SURFACE_Y), Vector2(w, SLAB_BOTTOM_Y - CLOTH_SURFACE_Y)), WOOD_SLAB)
	draw_rect(Rect2(Vector2(CENTER_X - w * 0.5, CLOTH_SURFACE_Y), Vector2(w, 4.0)), WOOD_HILIGHT)

## Front-hanging flap, drawn before the top layer so the top layer's edge
## sits above/in front of where the flap meets the tabletop.
func _draw_cloth_hang() -> void:
	var w := 108.0
	var rect := Rect2(Vector2(CENTER_X - w * 0.5, CLOTH_TOP_Y), Vector2(w, CLOTH_HANG_BOTTOM_Y - CLOTH_TOP_Y))
	draw_rect(rect, CLOTH_GREEN)
	_draw_stripes(rect)
	# A sliver of shadow tone down each side so the hanging flap reads as
	# fabric catching less light than the flat top layer.
	draw_rect(Rect2(rect.position, Vector2(7.0, rect.size.y)), CLOTH_GREEN_SHADOW)
	draw_rect(Rect2(Vector2(rect.end.x - 7.0, rect.position.y), Vector2(7.0, rect.size.y)), CLOTH_GREEN_SHADOW)
	# Short fringe ticks along the bottom hem.
	var fringe_count := int(w / 10.0)
	for i in fringe_count:
		var x: float = rect.position.x + 5.0 + i * 10.0
		draw_line(Vector2(x, rect.end.y), Vector2(x, rect.end.y + 9.0), CLOTH_GREEN, 3.0)

func _draw_cloth_top() -> void:
	var w := 244.0
	var rect := Rect2(Vector2(CENTER_X - w * 0.5, CLOTH_TOP_Y), Vector2(w, CLOTH_SURFACE_Y - CLOTH_TOP_Y))
	draw_rect(rect, CLOTH_GREEN)
	_draw_stripes(rect)

## Thin red stripes clipped to `rect` - always full-bleed horizontal bars
## within it, so callers never need to worry about a wavy/irregular edge
## cutting a stripe short.
func _draw_stripes(rect: Rect2) -> void:
	var y: float = rect.position.y + 6.0
	while y < rect.end.y - 1.0:
		draw_rect(Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, STRIPE_WIDTH)), STRIPE_RED)
		y += STRIPE_SPACING

func _draw_lamp() -> void:
	# Base.
	draw_rect(Rect2(Vector2(CENTER_X - 24.0, STEM_BOTTOM_Y), Vector2(48.0, LAMP_BASE_BOTTOM_Y - STEM_BOTTOM_Y)), BASE_METAL)
	# Stem.
	draw_rect(Rect2(Vector2(CENTER_X - 6.0, SHADE_BOTTOM_Y), Vector2(12.0, STEM_BOTTOM_Y - SHADE_BOTTOM_Y)), WOOD_SHADOW)
	# Shade - a trapezoid, wider at the bottom.
	draw_colored_polygon(PackedVector2Array([
		Vector2(CENTER_X - 32.0, SHADE_TOP_Y),
		Vector2(CENTER_X + 32.0, SHADE_TOP_Y),
		Vector2(CENTER_X + 55.0, SHADE_BOTTOM_Y),
		Vector2(CENTER_X - 55.0, SHADE_BOTTOM_Y),
	]), SHADE_COLOR)
	# Shadowed underside strip so the shade's open bottom (where the bulb
	# glow escapes) reads as a dark gap, not a flat-colored edge.
	draw_rect(Rect2(Vector2(CENTER_X - 52.0, SHADE_BOTTOM_Y - 6.0), Vector2(104.0, 6.0)), SHADE_SHADOW)
	# Bright glowing gap under the shade - the visible "bulb".
	draw_circle(Vector2(CENTER_X, SHADE_BOTTOM_Y - 3.0), 15.0 * _flicker, Color(1.0, 0.95, 0.8, 0.9))
