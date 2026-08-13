extends Control
## A tall bookshelf to the right of the main menu's window, packed with
## colorful book spines - modeled after a reference bookshelf photo the
## user supplied. Drawn procedurally in _draw(), same technique as
## WindowFrame.gd/NightstandLamp.gd (no texture pipeline in this project).
## Positioned as a fixed-offset Control sibling of Window/NightstandLamp
## under MainMenu's Root.
##
## Same "off-frame furniture" trick as NightstandLamp.gd, applied to the
## base plinth instead of legs: all four shelves of books stay fully
## visible, but the case is built tall enough that its base runs past the
## bottom of the 900-tall screen and gets cropped by the viewport edge,
## instead of neatly fitting a bounding box like a sticker. Wood tones are
## WindowFrame.gd's own palette so the frame matches the window/nightstand
## exactly. "Way larger than the nightstand" per the brief - roughly 2x its
## footprint, four shelves tall.
##
## One spine per shelf is a Stephen King title (see EASTER_EGGS) - small
## rotated spine text via ThemeDB.fallback_font (no custom font asset
## needed), sized and colored like an ordinary paperback spine rather than
## called out specially, so finding them reads as a real Easter egg.

const WOOD := WindowFrame.FRAME_COLOR
const WOOD_HILIGHT := WindowFrame.FRAME_HILIGHT
const WOOD_SHADOW := WindowFrame.FRAME_SHADOW
const WOOD_SLAB := WindowFrame.SILL_COLOR
const BACK_PANEL := Color(0.09, 0.065, 0.055)
const CONTACT_SHADOW := Color(0.039, 0.031, 0.071, 0.35)  # matches the game's shared shadow tone (also used by NightstandLamp.gd)

const BAND_LIGHT := Color(0.96, 0.94, 0.9, 0.85)
const BAND_DARK := Color(0.1, 0.08, 0.08, 0.55)
const TEXT_LIGHT := Color(0.96, 0.94, 0.88)
const TEXT_DARK := Color(0.12, 0.1, 0.09)

# Assorted paperback colors, sampled from the reference photo's palette -
# blues/oranges/greens/reds/purples/teals/tans, deliberately not this
# game's own ART_DIRECTION palette (books shouldn't read as game props).
const BOOK_PALETTE: Array[Color] = [
	Color("#3D6FA8"), Color("#E8763A"), Color("#4FBF6B"), Color("#E8483F"),
	Color("#7FD8FF"), Color("#FFB84D"), Color("#8A5AC2"), Color("#2E7D46"),
	Color("#C42B2B"), Color("#D9A860"), Color("#3A9C9C"), Color("#B85C8A"),
	Color("#6B4A9C"), Color("#4A7DBF"), Color("#E0A73D"), Color("#5C8A4A"),
]

# One Stephen King title per shelf, top to bottom - the user's four
# favorites. font_size/color are hand-picked per title (not derived) so
# each fits comfortably within a shelf's book-height range and contrasts
# with its own spine color.
const EASTER_EGGS := [
	{"title": "THE SHINING", "font_size": 12, "color": Color("#7A1F1F")},
	{"title": "IT", "font_size": 17, "color": Color("#C9302C")},
	{"title": "MISERY", "font_size": 13, "color": Color("#4A1F3D")},
	{"title": "THE DEAD ZONE", "font_size": 11, "color": Color("#1F2A44")},
]

# Local-space layout (this control's own rect - see the .tscn for its
# offset - not screen space).
const CENTER_X := 225.0
const FRAME_WIDTH := 460.0
const SIDE_THICK := 18.0
const TOP_CAP_THICK := 22.0
const SHELF_HEIGHT := 172.0
const DIVIDER_THICK := 16.0
const SHELF_COUNT := 4
const BASE_HEIGHT := 90.0

var _shelf_tops: Array[float] = []
var _shelf_bottoms: Array[float] = []
var _case_top: float = 0.0
var _base_bottom: float = 0.0

func _ready() -> void:
	var y: float = TOP_CAP_THICK
	_case_top = 0.0
	for i in SHELF_COUNT:
		_shelf_tops.append(y)
		y += SHELF_HEIGHT
		_shelf_bottoms.append(y)
		y += DIVIDER_THICK
	_base_bottom = y + BASE_HEIGHT
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	_draw_contact_shadow()
	_draw_case()
	for i in SHELF_COUNT:
		_draw_shelf_row(i)
	_draw_dividers()
	_draw_top_trim()

## A soft, slightly-offset dark silhouette behind the case - same
## grounding trick NightstandLamp.gd uses so this doesn't read as a flat
## cutout pasted on top of the wallpaper.
func _draw_contact_shadow() -> void:
	var half: float = FRAME_WIDTH * 0.5
	var offset := Vector2(18.0, 20.0)
	draw_rect(Rect2(Vector2(CENTER_X - half, _case_top) + offset, Vector2(FRAME_WIDTH, _base_bottom - _case_top + 40.0)), CONTACT_SHADOW)

func _draw_case() -> void:
	var half: float = FRAME_WIDTH * 0.5
	draw_rect(Rect2(Vector2(CENTER_X - half, _case_top), Vector2(FRAME_WIDTH, _base_bottom - _case_top)), WOOD)
	draw_rect(Rect2(Vector2(CENTER_X - half, _case_top), Vector2(SIDE_THICK, _base_bottom - _case_top)), WOOD_HILIGHT)
	draw_rect(Rect2(Vector2(CENTER_X + half - SIDE_THICK, _case_top), Vector2(SIDE_THICK, _base_bottom - _case_top)), WOOD_SHADOW)
	# Recessed interior the shelves/books sit in front of.
	var interior_top: float = _shelf_tops[0]
	var interior_bottom: float = _shelf_bottoms[SHELF_COUNT - 1]
	draw_rect(Rect2(Vector2(CENTER_X - half + SIDE_THICK, interior_top), Vector2(FRAME_WIDTH - SIDE_THICK * 2.0, interior_bottom - interior_top)), BACK_PANEL)

func _draw_top_trim() -> void:
	var half: float = FRAME_WIDTH * 0.5
	draw_rect(Rect2(Vector2(CENTER_X - half - 6.0, _case_top), Vector2(FRAME_WIDTH + 12.0, 8.0)), WOOD_HILIGHT)

func _draw_dividers() -> void:
	var half: float = FRAME_WIDTH * 0.5
	for i in range(SHELF_COUNT - 1):
		var y: float = _shelf_bottoms[i]
		draw_rect(Rect2(Vector2(CENTER_X - half + SIDE_THICK, y), Vector2(FRAME_WIDTH - SIDE_THICK * 2.0, DIVIDER_THICK)), WOOD_SLAB)
		draw_rect(Rect2(Vector2(CENTER_X - half + SIDE_THICK, y), Vector2(FRAME_WIDTH - SIDE_THICK * 2.0, 3.0)), WOOD_HILIGHT)

## Fills one shelf compartment edge-to-edge with book spines. Widths are
## random-then-normalized (generate more than needed, then scale every
## width down so the row sums exactly to the interior width) so the row
## always fills the shelf exactly without a fiddly bin-packing loop, while
## still reading as organically varied like the reference photo. One slot
## is pre-widened for that shelf's Easter-egg title.
func _draw_shelf_row(index: int) -> void:
	var top: float = _shelf_tops[index]
	var bottom: float = _shelf_bottoms[index]
	var interior_left: float = CENTER_X - FRAME_WIDTH * 0.5 + SIDE_THICK
	var interior_width: float = FRAME_WIDTH - SIDE_THICK * 2.0

	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + index * 131  # fixed per shelf - stable layout across redraws

	var raw_widths: Array[float] = []
	var easter_slot: int = rng.randi_range(2, 5)
	var total_raw: float = 0.0
	var i := 0
	while total_raw < interior_width * 1.15:
		var w: float = rng.randf_range(30.0, 40.0) if i == easter_slot else rng.randf_range(16.0, 34.0)
		raw_widths.append(w)
		total_raw += w
		i += 1

	var scale: float = interior_width / total_raw
	var x: float = interior_left
	var egg: Dictionary = EASTER_EGGS[index]
	for j in raw_widths.size():
		var w: float = raw_widths[j] * scale
		_draw_book(x, top, bottom, w, rng, j == easter_slot, egg)
		x += w

func _draw_book(x: float, shelf_top: float, shelf_bottom: float, w: float, rng: RandomNumberGenerator, is_egg: bool, egg: Dictionary) -> void:
	var height_jitter: float = rng.randf_range(0.0, (shelf_bottom - shelf_top) * 0.16)
	var book_top: float = shelf_top + height_jitter
	var color: Color = egg["color"] if is_egg else BOOK_PALETTE[rng.randi() % BOOK_PALETTE.size()]
	var gap: float = 1.5
	var rect := Rect2(Vector2(x + gap * 0.5, book_top), Vector2(w - gap, shelf_bottom - book_top))
	draw_rect(rect, color)
	# Subtle shading down the right edge of every spine so neighboring
	# books read as separate volumes instead of one flat block of color.
	draw_rect(Rect2(Vector2(rect.end.x - 2.0, rect.position.y), Vector2(2.0, rect.size.y)), Color(0.0, 0.0, 0.0, 0.15))
	var light_on_dark: bool = color.get_luminance() < 0.5
	if not is_egg and rng.randf() < 0.4:
		var band_color: Color = BAND_LIGHT if light_on_dark else BAND_DARK
		var band_y: float = rect.position.y + rng.randf_range(10.0, maxf(11.0, rect.size.y * 0.22))
		draw_rect(Rect2(Vector2(rect.position.x, band_y), Vector2(rect.size.x, 4.0)), band_color)
	if not is_egg and rng.randf() < 0.25:
		var dot_color: Color = BAND_LIGHT if light_on_dark else BAND_DARK
		draw_circle(Vector2(x + w * 0.5, rect.position.y + rect.size.y * 0.32), minf(w, 12.0) * 0.4, dot_color)
	if is_egg:
		var text_color: Color = TEXT_LIGHT if light_on_dark else TEXT_DARK
		_draw_spine_title(x + w * 0.5, shelf_bottom, rect.size.y, String(egg["title"]), int(egg["font_size"]), text_color)

## Spine title, rotated -90 degrees so it reads bottom-to-top like a real
## standing paperback - draw_set_transform rotates the LOCAL draw space (X
## becomes "up" on screen), so draw_string's own pos/baseline logic just
## works unmodified; reset the transform right after so nothing else drawn
## this frame inherits the rotation.
func _draw_spine_title(center_x: float, shelf_bottom: float, book_height: float, text: String, font_size: int, text_color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pad: float = 12.0
	var available: float = maxf(0.0, book_height - pad * 2.0)
	var start_y: float = shelf_bottom - pad - maxf(0.0, (available - text_width) * 0.5)
	draw_set_transform(Vector2(center_x + font_size * 0.32, start_y), -PI / 2.0, Vector2.ONE)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
