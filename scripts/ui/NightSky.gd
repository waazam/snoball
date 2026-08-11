extends Control
## The night scene visible through the main menu's window: a gradient sky,
## scattered stars, a glowing moon, and a two-layer silhouette treeline -
## drawn once per resize, same procedural technique as MountainRange.gd
## uses for the 3D world's horizon. Falling snow is a sibling control
## (FallingSnow) layered on top so it drifts in front of this scene; both
## are clipped to the window's glass by the parent Pane's clip_contents.

const SKY_TOP := Color(0.03, 0.04, 0.12)
const SKY_HORIZON := Color(0.1, 0.13, 0.28)
const MOON_COLOR := Color(0.93, 0.95, 0.88)
const MOON_GLOW := Color(0.93, 0.95, 0.88, 0.18)
const HILL_FAR := Color(0.07, 0.09, 0.2)
const HILL_NEAR := Color(0.04, 0.05, 0.13)
const TREE_COLOR := Color(0.03, 0.04, 0.1)
const STAR_COLOR := Color(1.0, 1.0, 1.0, 0.85)

const STAR_COUNT := 40
const TREE_COUNT := 7

var _stars: Array = []
var _trees: Array = []

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
		})
	_trees.clear()
	for i in TREE_COUNT:
		_trees.append(Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.55, 0.85)))
	queue_redraw()

func _draw() -> void:
	_draw_sky()
	_draw_stars()
	_draw_moon()
	_draw_ridge(size.y * 0.72, 5, HILL_FAR, 8801)
	_draw_ridge(size.y * 0.84, 6, HILL_NEAR, 4402)
	_draw_trees()

## No native gradient-rect draw call, so approximate one with stacked
## horizontal bands - same trick as the sky dome/horizon elsewhere in this
## project, just 2D bands instead of a 3D mesh.
func _draw_sky() -> void:
	var bands := 24
	for i in bands:
		var t0: float = float(i) / bands
		var t1: float = float(i + 1) / bands
		var c: Color = SKY_TOP.lerp(SKY_HORIZON, t0)
		draw_rect(Rect2(Vector2(0.0, size.y * t0), Vector2(size.x, size.y * (t1 - t0) + 1.0)), c)

func _draw_stars() -> void:
	for s in _stars:
		draw_circle(s["pos"], s["radius"], STAR_COLOR)

func _draw_moon() -> void:
	var c := Vector2(size.x * 0.68, size.y * 0.22)
	draw_circle(c, 46.0, MOON_GLOW)
	draw_circle(c, 30.0, MOON_COLOR)

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
