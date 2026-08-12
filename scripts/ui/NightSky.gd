extends Control
## The night scene visible through the main menu's window: a dusk-to-night
## gradient sky, twinkling stars, a glowing moon with craters, a two-layer
## silhouette ridge line, snow-capped pines and a tiny lamplit cabin with
## drifting chimney smoke - drawn procedurally, same technique as
## MountainRange.gd uses for the 3D world's horizon. Falling snow is a
## sibling control (FallingSnow) layered on top so it drifts in front of
## this scene; both are clipped to the window's glass by the parent Pane's
## clip_contents.
##
## Palette per ART_DIRECTION.md: sky #0A0812 -> #241C47 with an #8C4766
## plum afterglow at the horizon, ridges #241220 / #0A0812, moon core
## #EDF2E3 with #C9D6EE moonlight halo, warm ember accents #FFE9C9/#FFB84D
## reserved for the cabin window ("warm advances, cool recedes").

const SKY_TOP := Color("#0A0812")
const SKY_MID := Color("#241C47")
const SKY_GLOW := Color("#8C4766")
const MOON_CORE := Color("#EDF2E3")
const MOON_HALO := Color(0.788235, 0.839216, 0.933333, 0.14)  # #C9D6EE
const CRATER_COLOR := Color(0.788235, 0.839216, 0.933333, 0.45)  # #C9D6EE
const HILL_FAR := Color("#241220")
const HILL_NEAR := Color("#0A0812")
const TREE_COLOR := Color("#0A0812")
const TREE_SNOW := Color(0.917647, 0.94902, 0.984314, 0.8)  # #EAF2FB
const STAR_COLOR := Color("#EAF2FB")
const STAR_WARM := Color("#FFE9C9")
const CABIN_COLOR := Color("#0A0812")
const CABIN_WINDOW := Color("#FFE9C9")
const CABIN_HALO := Color(1, 0.721569, 0.301961, 0.16)  # #FFB84D
const SMOKE_COLOR := Color(0.788235, 0.839216, 0.933333, 1)  # #C9D6EE

const STAR_COUNT := 54
const TREE_COUNT := 7

var _stars: Array = []
var _trees: Array = []
var _time: float = 0.0

func _ready() -> void:
	resized.connect(_regenerate)
	_regenerate()

## Star/tree positions are re-rolled on resize (viewport can change under
## "expand" stretch mode) but always from the same seed, so the layout
## doesn't jitter between redraws at a given size.
func _regenerate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1201
	_stars.clear()
	for i in STAR_COUNT:
		_stars.append({
			"pos": Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y * 0.6)),
			"radius": rng.randf_range(0.8, 2.2),
			"twinkle_speed": rng.randf_range(0.8, 2.4),
			"twinkle_phase": rng.randf_range(0.0, TAU),
			"warm": i % 7 == 0,
		})
	_trees.clear()
	for i in TREE_COUNT:
		_trees.append(Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.76, 0.9)))
	queue_redraw()

## Gentle continuous motion: star twinkle + cabin chimney smoke. The
## sibling FallingSnow already redraws this pane every frame, so this adds
## no meaningful cost.
func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	_draw_sky()
	_draw_stars()
	_draw_moon()
	_draw_ridge(size.y * 0.72, 5, HILL_FAR, 8801)
	_draw_ridge(size.y * 0.84, 6, HILL_NEAR, 4402)
	_draw_cabin()
	_draw_trees()

## No native gradient-rect draw call, so approximate one with stacked
## horizontal bands - same trick as the sky dome/horizon elsewhere in this
## project, just 2D bands instead of a 3D mesh. Three stops: near-black
## zenith into deep indigo, then a plum dusk afterglow kissing the horizon.
func _draw_sky() -> void:
	var bands := 30
	for i in bands:
		var t0: float = float(i) / bands
		var t1: float = float(i + 1) / bands
		var c: Color
		if t0 < 0.55:
			c = SKY_TOP.lerp(SKY_MID, t0 / 0.55)
		else:
			c = SKY_MID.lerp(SKY_GLOW, (t0 - 0.55) / 0.45 * 0.55)
		draw_rect(Rect2(Vector2(0.0, size.y * t0), Vector2(size.x, size.y * (t1 - t0) + 1.0)), c)

func _draw_stars() -> void:
	for s in _stars:
		var twinkle: float = 0.6 + 0.4 * sin(_time * s["twinkle_speed"] + s["twinkle_phase"])
		var base: Color = STAR_WARM if s["warm"] else STAR_COLOR
		draw_circle(s["pos"], s["radius"], Color(base.r, base.g, base.b, 0.85 * twinkle))

func _draw_moon() -> void:
	var c := Vector2(size.x * 0.68, size.y * 0.22)
	draw_circle(c, 60.0, Color(MOON_HALO.r, MOON_HALO.g, MOON_HALO.b, 0.07))
	draw_circle(c, 46.0, MOON_HALO)
	draw_circle(c, 30.0, MOON_CORE)
	draw_circle(c + Vector2(-9.0, -5.0), 5.0, CRATER_COLOR)
	draw_circle(c + Vector2(8.0, 7.0), 3.5, CRATER_COLOR)
	draw_circle(c + Vector2(3.0, -12.0), 2.5, CRATER_COLOR)

## A jagged horizon ridge - base corners plus randomized peak heights
## along the way, same "ring of triangles" idea as MountainRange.gd but
## flattened to a single 2D silhouette strip.
func _draw_ridge(base_y: float, peaks: int, color: Color, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, size.y))
	var step: float = size.x / peaks
	for i in range(peaks + 1):
		var x: float = i * step
		var y: float = base_y - rng.randf_range(0.0, size.y * 0.14)
		pts.append(Vector2(x, y))
	pts.append(Vector2(size.x, size.y))
	draw_colored_polygon(pts, color)

## A tiny lamplit cabin on the near ridge - the one warm ember accent in
## the cool night scene, with animated chimney smoke.
func _draw_cabin() -> void:
	var base := Vector2(size.x * 0.24, size.y * 0.88)
	var w := 44.0
	var h := 26.0
	# Body.
	draw_rect(Rect2(base + Vector2(-w * 0.5, -h), Vector2(w, h)), CABIN_COLOR)
	# Roof.
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-w * 0.5 - 5.0, -h),
		base + Vector2(w * 0.5 + 5.0, -h),
		base + Vector2(0.0, -h - 15.0),
	]), CABIN_COLOR)
	# Snow line along the roof slopes.
	draw_line(base + Vector2(-w * 0.5 - 5.0, -h - 1.0), base + Vector2(0.0, -h - 16.0), TREE_SNOW, 2.5, true)
	draw_line(base + Vector2(0.0, -h - 16.0), base + Vector2(w * 0.5 + 5.0, -h - 1.0), TREE_SNOW, 2.5, true)
	# Chimney.
	var chimney_top := base + Vector2(w * 0.28, -h - 20.0)
	draw_rect(Rect2(chimney_top, Vector2(6.0, 12.0)), CABIN_COLOR)
	# Warm window with halo glow.
	var win_c := base + Vector2(-w * 0.14, -h * 0.5)
	draw_circle(win_c, 13.0, CABIN_HALO)
	draw_circle(win_c, 8.0, Color(CABIN_HALO.r, CABIN_HALO.g, CABIN_HALO.b, 0.28))
	draw_rect(Rect2(win_c - Vector2(4.0, 5.0), Vector2(8.0, 10.0)), CABIN_WINDOW)
	draw_line(win_c - Vector2(0.0, 5.0), win_c + Vector2(0.0, 5.0), CABIN_COLOR, 1.0)
	draw_line(win_c - Vector2(4.0, 0.0), win_c + Vector2(4.0, 0.0), CABIN_COLOR, 1.0)
	# Drifting smoke puffs looping up from the chimney.
	for i in 3:
		var t: float = fmod(_time * 0.25 + float(i) / 3.0, 1.0)
		var puff := chimney_top + Vector2(3.0 + sin((_time + i * 2.1) * 1.3) * 4.0 * t, -4.0 - t * 30.0)
		var alpha: float = (1.0 - t) * 0.22
		draw_circle(puff, 2.0 + t * 4.0, Color(SMOKE_COLOR.r, SMOKE_COLOR.g, SMOKE_COLOR.b, alpha))

func _draw_trees() -> void:
	for t in _trees:
		var x: float = t.x
		var base_y: float = size.y * t.y
		var h: float = size.y * 0.14
		var w: float = h * 0.55
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.5, base_y),
			Vector2(x + w * 0.5, base_y),
			Vector2(x, base_y - h),
		]), TREE_COLOR)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.35, base_y - h * 0.4),
			Vector2(x + w * 0.35, base_y - h * 0.4),
			Vector2(x, base_y - h * 1.3),
		]), TREE_COLOR)
		# Moonlit snow cap on the upper tier's tip.
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.14, base_y - h * 0.94),
			Vector2(x + w * 0.14, base_y - h * 0.94),
			Vector2(x, base_y - h * 1.3),
		]), TREE_SNOW)
