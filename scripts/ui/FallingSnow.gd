extends Control
## Gentle falling snow inside the main menu window - three depth layers of
## drifting flakes (small/dim/slow in back, big/bright/fast in front) plus
## a frosted-glass corner haze and a snow drift piled along the bottom of
## the pane, all hand-animated in _process()/_draw() rather than a particle
## node, to match the rest of this project's UI (everything hand-drawn, no
## texture assets). Sits above NightSky as a sibling and is clipped to the
## window pane by the parent Pane control's clip_contents, same as NightSky.
##
## Palette per ART_DIRECTION.md: flakes/drift SNOW_LIT #EAF2FB, drift
## shadow SNOW_SHADOW #8FA3C8, frost haze MOONLIGHT #C9D6EE.

const FLAKE_COLOR := Color("#EAF2FB")
const DRIFT_COLOR := Color(0.917647, 0.94902, 0.984314, 0.95)  # #EAF2FB
const DRIFT_SHADOW := Color(0.560784, 0.639216, 0.784314, 0.5)  # #8FA3C8
const FROST_COLOR := Color(0.788235, 0.839216, 0.933333, 0.06)  # #C9D6EE

## Depth layers, back to front: count, radius range, fall speed range,
## alpha, and sway amplitude per layer.
const LAYERS: Array = [
	{"count": 18, "r_min": 0.9, "r_max": 1.5, "s_min": 12.0, "s_max": 20.0, "alpha": 0.4, "sway": 6.0},
	{"count": 18, "r_min": 1.7, "r_max": 2.5, "s_min": 24.0, "s_max": 38.0, "alpha": 0.65, "sway": 9.0},
	{"count": 12, "r_min": 2.7, "r_max": 4.0, "s_min": 42.0, "s_max": 60.0, "alpha": 0.9, "sway": 13.0},
]
const SWAY_SPEED_MIN := 0.6
const SWAY_SPEED_MAX := 1.6

var _flakes: Array = []
var _time: float = 0.0

func _ready() -> void:
	resized.connect(_reseed)
	_reseed()

func _reseed() -> void:
	if size.y <= 0.0:
		return
	_flakes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for layer in LAYERS:
		for i in int(layer["count"]):
			_flakes.append({
				"base_x": rng.randf_range(0.0, size.x),
				"y": rng.randf_range(0.0, size.y),
				"speed": rng.randf_range(layer["s_min"], layer["s_max"]),
				"sway_speed": rng.randf_range(SWAY_SPEED_MIN, SWAY_SPEED_MAX),
				"sway_offset": rng.randf_range(0.0, TAU),
				"sway_amount": layer["sway"],
				"radius": rng.randf_range(layer["r_min"], layer["r_max"]),
				"alpha": layer["alpha"],
			})

func _process(delta: float) -> void:
	if _flakes.is_empty():
		return
	_time += delta
	for f in _flakes:
		f["y"] += f["speed"] * delta
		if f["y"] > size.y:
			f["y"] -= size.y
			f["base_x"] = randf() * size.x
	queue_redraw()

func _draw() -> void:
	_draw_frost()
	for f in _flakes:
		var sway: float = sin(_time * f["sway_speed"] + f["sway_offset"]) * f["sway_amount"]
		var c := Color(FLAKE_COLOR.r, FLAKE_COLOR.g, FLAKE_COLOR.b, f["alpha"])
		draw_circle(Vector2(f["base_x"] + sway, f["y"]), f["radius"], c)
	_draw_drift()

## Faint frosted-glass haze creeping in from the pane corners.
func _draw_frost() -> void:
	var corners: Array = [
		Vector2(0.0, 0.0), Vector2(size.x, 0.0),
		Vector2(0.0, size.y), Vector2(size.x, size.y),
	]
	for corner in corners:
		draw_circle(corner, 70.0, FROST_COLOR)
		draw_circle(corner, 46.0, FROST_COLOR)
		draw_circle(corner, 26.0, FROST_COLOR)

## Snow piled against the inside-bottom of the glass: a seeded chain of
## half-buried mounds, with a cooler shadow layer peeking over the top.
func _draw_drift() -> void:
	if size.x <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x := -8.0
	while x < size.x + 8.0:
		var r: float = rng.randf_range(8.0, 15.0)
		draw_circle(Vector2(x, size.y + r * 0.45 - 2.0), r, DRIFT_SHADOW)
		x += r * 1.1
	rng.seed = 78
	x = -8.0
	while x < size.x + 8.0:
		var r: float = rng.randf_range(7.0, 14.0)
		draw_circle(Vector2(x, size.y + r * 0.55), r, DRIFT_COLOR)
		x += r * 1.05
