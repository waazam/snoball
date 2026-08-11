extends Control
## Gentle falling snow inside the main menu window - a handful of drifting
## dots hand-animated in _process()/_draw() rather than a particle node, to
## match the rest of this project's UI (everything hand-drawn, no texture
## assets). Sits above NightSky as a sibling and is clipped to the window
## pane by the parent Pane control's clip_contents, same as NightSky is.

const FLAKE_COUNT := 46
const FALL_SPEED_MIN := 18.0
const FALL_SPEED_MAX := 42.0
const SWAY_SPEED_MIN := 0.6
const SWAY_SPEED_MAX := 1.6
const SWAY_AMOUNT := 10.0
const RADIUS_MIN := 1.2
const RADIUS_MAX := 3.0
const FLAKE_COLOR := Color(1.0, 1.0, 1.0, 0.9)

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
	for i in FLAKE_COUNT:
		_flakes.append({
			"base_x": rng.randf_range(0.0, size.x),
			"y": rng.randf_range(0.0, size.y),
			"speed": rng.randf_range(FALL_SPEED_MIN, FALL_SPEED_MAX),
			"sway_speed": rng.randf_range(SWAY_SPEED_MIN, SWAY_SPEED_MAX),
			"sway_offset": rng.randf_range(0.0, TAU),
			"radius": rng.randf_range(RADIUS_MIN, RADIUS_MAX),
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
	for f in _flakes:
		var sway: float = sin(_time * f["sway_speed"] + f["sway_offset"]) * SWAY_AMOUNT
		draw_circle(Vector2(f["base_x"] + sway, f["y"]), f["radius"], FLAKE_COLOR)
