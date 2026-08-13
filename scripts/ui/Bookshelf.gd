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
## visible, but the case is tall enough that its base runs past the bottom
## of the 900-tall screen and gets cropped by the viewport edge, instead
## of neatly fitting a bounding box like a sticker. Wood tones are
## WindowFrame.gd's own palette so the frame matches the window/nightstand
## exactly. Sized at ~0.85x an earlier, too-large pass (still noticeably
## bigger than the nightstand) - BASE_HEIGHT is kept generous regardless of
## that shrink so the crop past the screen edge still holds.
##
## Every spine gets a subtle banded gradient (same "stacked bands fake a
## gradient" trick NightSky.gd's sky uses) instead of one flat fill, plus
## one of three material textures - "paperback" (gradient + a thin gloss
## streak), "hardback" (gradient + speckled cloth grain + solid end-bands),
## or "leather" (gradient + embossed raised cords + soft mottling) - so the
## shelf reads as an assortment of real bindings instead of a flat block
## of color. A handful of spines per shelf are Easter eggs - Stephen
## King's four titles plus some classic American literature and the Lord
## of the Rings trilogy (see SPECIAL_BOOKS) - always leather or hardback
## (never the brighter paperback look), spread across quartiles of the
## row so they don't cluster, with small muted-contrast rotated spine text
## (ThemeDB.fallback_font, no custom font asset) so they read as genuinely
## subtle rather than called-out labels.

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
const GOLD_EMBOSS := Color("#C9A24D")

# Assorted paperback colors, sampled from the reference photo's palette -
# blues/oranges/greens/reds/purples/teals/tans, deliberately not this
# game's own ART_DIRECTION palette (books shouldn't read as game props).
const BOOK_PALETTE: Array[Color] = [
	Color("#3D6FA8"), Color("#E8763A"), Color("#4FBF6B"), Color("#E8483F"),
	Color("#7FD8FF"), Color("#FFB84D"), Color("#8A5AC2"), Color("#2E7D46"),
	Color("#C42B2B"), Color("#D9A860"), Color("#3A9C9C"), Color("#B85C8A"),
	Color("#6B4A9C"), Color("#4A7DBF"), Color("#E0A73D"), Color("#5C8A4A"),
]

# Easter-egg spines, four per shelf, spread across that shelf's row (see
# _draw_shelf_row) rather than fixed positions. Colors lean deliberately
## darker/earthier than BOOK_PALETTE - these are always drawn as leather or
# hardback (alternating by list position), never the brighter paperback
# look, so the "classics" subset reads distinct from the filler books even
# before anyone notices the titles.
const SPECIAL_BOOKS := [
	[
		{"title": "THE SHINING", "font_size": 11, "color": Color("#7A1F1F")},
		{"title": "THE FELLOWSHIP OF THE RING", "font_size": 8, "color": Color("#1F3D2A")},
		{"title": "THE OLD MAN AND THE SEA", "font_size": 8, "color": Color("#1F3A52")},
		{"title": "THE GRAPES OF WRATH", "font_size": 9, "color": Color("#6B4A2F")},
	],
	[
		{"title": "IT", "font_size": 15, "color": Color("#C9302C")},
		{"title": "THE TWO TOWERS", "font_size": 10, "color": Color("#3A3F3D")},
		{"title": "A FAREWELL TO ARMS", "font_size": 9, "color": Color("#4A4A2F")},
		{"title": "OF MICE AND MEN", "font_size": 10, "color": Color("#7A5C3D")},
	],
	[
		{"title": "MISERY", "font_size": 12, "color": Color("#4A1F3D")},
		{"title": "THE RETURN OF THE KING", "font_size": 8, "color": Color("#5C1F2E")},
		{"title": "THE SUN ALSO RISES", "font_size": 9, "color": Color("#8A4A2F")},
		{"title": "EAST OF EDEN", "font_size": 11, "color": Color("#2F4A2F")},
	],
	[
		{"title": "THE DEAD ZONE", "font_size": 10, "color": Color("#1F2A44")},
		{"title": "THE HOBBIT", "font_size": 11, "color": Color("#4A3D1F")},
		{"title": "THE SOUND AND THE FURY", "font_size": 8, "color": Color("#4A1F1F")},
		{"title": "AS I LAY DYING", "font_size": 10, "color": Color("#4A4038")},
	],
]

# Local-space layout (this control's own rect - see the .tscn for its
# offset - not screen space). ~0.85x an earlier pass per the "a little too
# big" note - CENTER_X unchanged so the shelf shrinks evenly around the
# same spot instead of drifting.
const CENTER_X := 225.0
const FRAME_WIDTH := 391.0
const SIDE_THICK := 15.0
const TOP_CAP_THICK := 19.0
const SHELF_HEIGHT := 146.0
const DIVIDER_THICK := 14.0
const SHELF_COUNT := 4
# NOT scaled down with the rest - this is what guarantees the base plinth
# still runs past the screen edge (see class comment) regardless of the
# shrink above; it's purely a hidden structural margin, never seen.
const BASE_HEIGHT := 220.0

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
	var offset := Vector2(15.0, 17.0)
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
	draw_rect(Rect2(Vector2(CENTER_X - half - 5.0, _case_top), Vector2(FRAME_WIDTH + 10.0, 7.0)), WOOD_HILIGHT)

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
## still reading as organically varied. This shelf's four special
## (titled) books are placed one-per-quartile of the generated row - each
## quartile gets one random slot within it - so they land spread out
## across the shelf instead of bunched together.
func _draw_shelf_row(index: int) -> void:
	var top: float = _shelf_tops[index]
	var bottom: float = _shelf_bottoms[index]
	var interior_left: float = CENTER_X - FRAME_WIDTH * 0.5 + SIDE_THICK
	var interior_width: float = FRAME_WIDTH - SIDE_THICK * 2.0

	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + index * 131  # fixed per shelf - stable layout across redraws

	var raw_widths: Array[float] = []
	var total_raw: float = 0.0
	while total_raw < interior_width * 1.15:
		var w: float = rng.randf_range(16.0, 34.0)
		raw_widths.append(w)
		total_raw += w

	var scale: float = interior_width / total_raw
	var count: int = raw_widths.size()

	var specials: Array = SPECIAL_BOOKS[index]
	var special_slots: Array[int] = []
	for q in specials.size():
		var lo: int = int(float(count) * float(q) / specials.size())
		var hi: int = int(float(count) * float(q + 1) / specials.size()) - 1
		hi = maxi(hi, lo)
		special_slots.append(rng.randi_range(lo, hi))

	var x: float = interior_left
	for j in count:
		var w: float = raw_widths[j] * scale
		var slot: int = special_slots.find(j)
		_draw_book(x, top, bottom, w, rng, specials[slot] if slot != -1 else {}, slot)
		x += w

func _draw_book(x: float, shelf_top: float, shelf_bottom: float, w: float, rng: RandomNumberGenerator, special: Dictionary, special_index: int) -> void:
	var is_special: bool = not special.is_empty()
	var height_jitter: float = rng.randf_range(0.0, (shelf_bottom - shelf_top) * 0.16)
	var book_top: float = shelf_top + height_jitter
	var color: Color
	var material: String
	if is_special:
		color = special["color"]
		material = "leather" if special_index % 2 == 0 else "hardback"
	else:
		color = BOOK_PALETTE[rng.randi() % BOOK_PALETTE.size()]
		var roll: float = rng.randf()
		material = "leather" if roll < 0.12 else ("hardback" if roll < 0.35 else "paperback")

	var gap: float = 1.5
	var rect := Rect2(Vector2(x + gap * 0.5, book_top), Vector2(w - gap, shelf_bottom - book_top))

	_draw_spine_gradient(rect, color)
	match material:
		"leather":
			_draw_leather_texture(rect, color, rng)
		"hardback":
			_draw_hardback_texture(rect, color, rng)
		_:
			_draw_paperback_gloss(rect)

	# Dark sliver between neighboring spines so each book still reads as
	# its own volume, not one flat block of color.
	draw_rect(Rect2(Vector2(rect.end.x - 1.5, rect.position.y), Vector2(1.5, rect.size.y)), Color(0.0, 0.0, 0.0, 0.22))

	if not is_special:
		var light_on_dark: bool = color.get_luminance() < 0.5
		if material == "paperback" and rng.randf() < 0.35:
			var band_color: Color = BAND_LIGHT if light_on_dark else BAND_DARK
			var band_y: float = rect.position.y + rng.randf_range(10.0, maxf(11.0, rect.size.y * 0.22))
			draw_rect(Rect2(Vector2(rect.position.x, band_y), Vector2(rect.size.x, 3.0)), band_color)
		if rng.randf() < 0.18:
			var dot_color: Color = BAND_LIGHT if light_on_dark else BAND_DARK
			draw_circle(Vector2(x + w * 0.5, rect.position.y + rect.size.y * 0.32), minf(w, 12.0) * 0.35, dot_color)
	else:
		# Muted (not full-contrast) text color - a subtle debossed-foil
		# look rather than a bold printed label.
		var muted_light: Color = color.lerp(TEXT_LIGHT, 0.62)
		var muted_dark: Color = color.lerp(TEXT_DARK, 0.62)
		var text_color: Color = muted_light if color.get_luminance() < 0.5 else muted_dark
		_draw_spine_title(x + w * 0.5, shelf_bottom, rect.size.y, String(special["title"]), int(special["font_size"]), text_color)

## Fake gradient (no native gradient-rect draw call, same "stacked bands"
## trick NightSky.gd's _draw_sky uses) - highlight on the left easing to
## base color, then to a shadow on the right, so the spine reads as a
## rounded volume instead of one flat fill.
func _draw_spine_gradient(rect: Rect2, base_color: Color) -> void:
	var bands := 5
	var highlight: Color = base_color.lightened(0.22)
	var shadow: Color = base_color.darkened(0.28)
	for i in bands:
		var t0: float = float(i) / bands
		var t1: float = float(i + 1) / bands
		var c: Color
		if t0 < 0.5:
			c = highlight.lerp(base_color, t0 / 0.5)
		else:
			c = base_color.lerp(shadow, (t0 - 0.5) / 0.5)
		draw_rect(Rect2(Vector2(rect.position.x + rect.size.x * t0, rect.position.y), Vector2(rect.size.x * (t1 - t0) + 0.5, rect.size.y)), c)

## Leather-bound look: 3 embossed raised cords (a darker ridge with a thin
## gold highlight, the classic old-leather-spine convention) plus a few
## soft mottled blotches for worn, uneven color.
func _draw_leather_texture(rect: Rect2, base_color: Color, rng: RandomNumberGenerator) -> void:
	var band_color: Color = base_color.darkened(0.4)
	for i in 3:
		var y: float = rect.position.y + rect.size.y * (0.2 + i * 0.26)
		draw_rect(Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, 2.5)), band_color)
		draw_rect(Rect2(Vector2(rect.position.x, y + 2.5), Vector2(rect.size.x, 1.0)), Color(GOLD_EMBOSS.r, GOLD_EMBOSS.g, GOLD_EMBOSS.b, 0.45))
	for i in 5:
		var pos := Vector2(rect.position.x + rng.randf() * rect.size.x, rect.position.y + rng.randf() * rect.size.y)
		var shade: float = rng.randf_range(-0.12, 0.12)
		var c: Color = base_color.darkened(shade) if shade > 0.0 else base_color.lightened(-shade)
		draw_circle(pos, rng.randf_range(3.0, 6.5), Color(c.r, c.g, c.b, 0.16))

## Cloth hardback look: fine speckled grain across the whole spine plus
## solid darker end-bands top and bottom (most old library hardbacks have
## a plain color block at each end of the spine).
func _draw_hardback_texture(rect: Rect2, base_color: Color, rng: RandomNumberGenerator) -> void:
	var speckle_count: int = int(rect.size.x * rect.size.y / 110.0)
	for i in speckle_count:
		var pos := Vector2(rect.position.x + rng.randf() * rect.size.x, rect.position.y + rng.randf() * rect.size.y)
		var c: Color = base_color.darkened(0.22) if rng.randf() < 0.5 else base_color.lightened(0.18)
		draw_rect(Rect2(pos, Vector2(1.3, 1.3)), Color(c.r, c.g, c.b, 0.35))
	var end_color: Color = base_color.darkened(0.32)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), end_color)
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 4.0), Vector2(rect.size.x, 4.0)), end_color)

## Modern glossy paperback: just a thin bright highlight streak catching
## the light near the left edge.
func _draw_paperback_gloss(rect: Rect2) -> void:
	draw_rect(Rect2(Vector2(rect.position.x + rect.size.x * 0.15, rect.position.y), Vector2(maxf(1.0, rect.size.x * 0.12), rect.size.y)), Color(1.0, 1.0, 1.0, 0.1))

## Spine title, rotated -90 degrees so it reads bottom-to-top like a real
## standing paperback - draw_set_transform rotates the LOCAL draw space (X
## becomes "up" on screen), so draw_string's own pos/baseline logic just
## works unmodified; reset the transform right after so nothing else drawn
## this frame inherits the rotation.
func _draw_spine_title(center_x: float, shelf_bottom: float, book_height: float, text: String, font_size: int, text_color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pad: float = 8.0
	var available: float = maxf(0.0, book_height - pad * 2.0)
	var start_y: float = shelf_bottom - pad - maxf(0.0, (available - text_width) * 0.5)
	draw_set_transform(Vector2(center_x + font_size * 0.32, start_y), -PI / 2.0, Vector2.ONE)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
