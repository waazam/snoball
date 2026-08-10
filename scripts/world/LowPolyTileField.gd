extends Node3D
## Scatters a random field of low-poly painted floor tiles (LowPolyTile.gd)
## across the arena at run-time, so the ground gets a different scattered
## pattern every run instead of one static baked-in layout.

const TILE_SCRIPT := preload("res://scripts/world/LowPolyTile.gd")

@export var tile_count: int = 45
@export var spawn_radius: float = 34.0  # keeps tiles clear of the walls at +-40
@export var min_size: float = 1.1
@export var max_size: float = 2.2
@export var ground_y: float = 0.01  # tiny offset above the ground to avoid z-fighting

func _ready() -> void:
	for i in range(tile_count):
		_spawn_tile()

func _spawn_tile() -> void:
	var tile := MeshInstance3D.new()
	tile.set_script(TILE_SCRIPT)
	tile.tile_size = randf_range(min_size, max_size)
	tile.facets = 2
	var angle: float = randf() * TAU
	var dist: float = sqrt(randf()) * spawn_radius  # sqrt(randf()) -> uniform density over the disc
	tile.position = Vector3(cos(angle) * dist, ground_y, sin(angle) * dist)
	tile.rotation_degrees.y = randf() * 360.0
	add_child(tile)
