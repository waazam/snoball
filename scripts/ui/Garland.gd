extends Control
## A Christmas garland strung across the entire top of the main menu's
## wall, swagged between pin points so it reads as hanging from the
## ceiling - drawn procedurally in _draw(), same technique as
## WindowFrame.gd/NightstandLamp.gd/Bookshelf.gd (no texture pipeline in
## this project). Anchored full-width (unlike the fixed-offset furniture
## pieces) so it always spans the actual screen width; added last under
## MainMenu's Root so it renders in front of the window/nightstand/
## bookshelf where their tops come close to it.
##
## Two layers follow the same sag curve (_garland_y): a thick evergreen
## rope with scattered needle-tuft texture (the "garland" itself), and a
## thinner green wire strung with classic red/blue/green bulbs on top of
## it. Each bulb glows via the same stacked-circle halo trick
## NightstandLamp.gd's lamp uses, and blinks independently - its own
## random (but fixed, so it's a stable animation, not per-frame noise)
## phase/speed/amplitude, rolled once per bulb in _ready()/on resize.

const PINE_DARK := Color("#1C3D24")
const PINE_LIGHT := Color("#2E5E3A")
const WIRE_GREEN := Color("#2A4A2E")
const BOW_RED := Color("#C42B2B")
const BOW_RED_DARK := Color("#8A1F1F")

const BULB_COLORS: Array[Color] = [Color("#FF3B30"), Color("#2E86FF"), Color("#34D058")]

const ANCHOR_COUNT := 6
const ANCHOR_Y := 14.0
const SAG_DEPTH := 62.0
const ROPE_WIDTH := 20.0
const BULB_SPACING := 42.0
const BLINK_MIN_SPEED := 1.2
const BLINK_MAX_SPEED := 3.4

var _time: float = 0.0
var _bulb_colors: Array[Color] = []
var _bulb_phases: Array[float] = []
var _bulb_speeds: Array[float] = []
var _bulb_amps: Array[float] = []

func _ready() -> void:
	resized.connect(_on_resized)
	_on_resized()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

## Rerolls the per-bulb blink parameters whenever the screen width changes
## (so the bulb count stays correct) - seeded, so the layout/phases are
## stable across redraws instead of jittering every frame.
func _on_resized() -> void:
	var count: int = maxi(2, int(size.x / BULB_SPACING) + 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9911
	_bulb_colors.clear()
	_bulb_phases.clear()
	_bulb_speeds.clear()
	_bulb_amps.clear()
	for i in count:
		_bulb_colors.append(BULB_COLORS[i % BULB_COLORS.size()])
		_bulb_phases.append(rng.randf_range(0.0, TAU))
		_bulb_speeds.append(rng.randf_range(BLINK_MIN_SPEED, BLINK_MAX_SPEED))
		_bulb_amps.append(rng.randf_range(0.28, 0.65))
	queue_redraw()

## Height of the sag curve at a given x - ANCHOR_COUNT points pinned at
## ANCHOR_Y, each pair joined by a half-sine droop (zero at both anchors,
## deepest at the segment's midpoint). Segments meeting at a shared low
## slope-magnitude cusp right at each anchor is intentional - that's the
## same silhouette a real garland has where it's tacked to the wall.
func _garland_y(x: float) -> float:
	var seg_count: int = ANCHOR_COUNT - 1
	var seg_width: float = size.x / seg_count
	var seg_index: int = clampi(int(x / seg_width), 0, seg_count - 1)
	var t: float = (x - seg_index * seg_width) / seg_width
	return ANCHOR_Y + SAG_DEPTH * sin(PI * clampf(t, 0.0, 1.0))

func _sample_curve(step: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x := 0.0
	while x < size.x:
		pts.append(Vector2(x, _garland_y(x)))
		x += step
	pts.append(Vector2(size.x, _garland_y(size.x)))
	return pts

func _draw() -> void:
	_draw_rope()
	_draw_anchors()
	_draw_wire_and_bulbs()

## Thick evergreen rope (two overlaid polylines for a bit of shading) plus
## scattered short "needle" ticks along it, same "layered primitives fake
## a texture" approach Bookshelf.gd's leather/hardback spines use.
func _draw_rope() -> void:
	var pts: PackedVector2Array = _sample_curve(4.0)
	draw_polyline(pts, PINE_DARK, ROPE_WIDTH, true)
	draw_polyline(pts, PINE_LIGHT, ROPE_WIDTH * 0.55, true)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var tuft_count: int = int(size.x / 5.0)
	for i in tuft_count:
		var x: float = rng.randf_range(0.0, size.x)
		var base_y: float = _garland_y(x) + rng.randf_range(-ROPE_WIDTH * 0.45, ROPE_WIDTH * 0.45)
		var ang: float = rng.randf_range(0.0, TAU)
		var length: float = rng.randf_range(4.0, 9.0)
		var tuft_color: Color = PINE_LIGHT if rng.randf() < 0.5 else PINE_DARK
		var from := Vector2(x, base_y)
		draw_line(from, from + Vector2(cos(ang), sin(ang)) * length, tuft_color, 1.6)

## A small bow at each pin point, marking where the garland is tacked to
## the wall.
func _draw_anchors() -> void:
	var seg_count: int = ANCHOR_COUNT - 1
	for i in ANCHOR_COUNT:
		var x: float = clampf(float(i) / seg_count * size.x, 0.0, size.x)
		_draw_bow(Vector2(x, ANCHOR_Y))

func _draw_bow(center: Vector2) -> void:
	for side in [-1, 1]:
		draw_colored_polygon(PackedVector2Array([
			center,
			center + Vector2(side * 11.0, -7.0),
			center + Vector2(side * 13.0, 3.0),
			center + Vector2(side * 5.0, 5.0),
		]), BOW_RED)
	draw_circle(center, 4.0, BOW_RED_DARK)
	draw_line(center + Vector2(-3.0, 4.0), center + Vector2(-7.0, 14.0), BOW_RED_DARK, 3.0)
	draw_line(center + Vector2(3.0, 4.0), center + Vector2(7.0, 14.0), BOW_RED_DARK, 3.0)

## Thin wire draped just under the rope, strung with independently
## blinking bulbs.
func _draw_wire_and_bulbs() -> void:
	var pts: PackedVector2Array = _sample_curve(6.0)
	var wire_pts := PackedVector2Array()
	for p in pts:
		wire_pts.append(p + Vector2(0.0, ROPE_WIDTH * 0.42))
	draw_polyline(wire_pts, WIRE_GREEN, 2.0, true)

	var count: int = _bulb_colors.size()
	if count < 2:
		return
	var spacing: float = size.x / (count - 1)
	for i in count:
		var x: float = i * spacing
		var y: float = _garland_y(x) + ROPE_WIDTH * 0.42 + 5.0
		var brightness: float = clampf(0.5 + _bulb_amps[i] * sin(_time * _bulb_speeds[i] + _bulb_phases[i]), 0.06, 1.0)
		_draw_bulb(Vector2(x, y), _bulb_colors[i], brightness)

## Classic teardrop-style bulb: a soft two-layer glow halo (brighter with
## higher `brightness`), a dark screw cap connecting to the wire, and a
## glass body lightened toward white at its peak brightness so it reads
## as lit from within rather than just a flat colored dot.
func _draw_bulb(pos: Vector2, color: Color, brightness: float) -> void:
	var glow_a: float = 0.08 + 0.24 * brightness
	draw_circle(pos, 15.0, Color(color.r, color.g, color.b, glow_a * 0.45))
	draw_circle(pos, 8.0, Color(color.r, color.g, color.b, glow_a))
	draw_rect(Rect2(pos + Vector2(-2.0, -9.0), Vector2(4.0, 4.0)), Color(0.14, 0.13, 0.12))
	var glass: Color = color.lerp(Color(1.0, 1.0, 1.0), 0.3 * brightness)
	draw_circle(pos, 5.0, glass)
	draw_circle(pos + Vector2(-1.4, -1.4), 1.4, Color(1.0, 1.0, 1.0, 0.35 + 0.35 * brightness))
