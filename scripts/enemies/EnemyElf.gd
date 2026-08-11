extends "res://scripts/enemies/Enemy.gd"
## Rogue Elf: identical chase/throw AI to the base Enemy.gd - the only
## difference is a colorful confetti burst on death (via the
## _spawn_death_fx hook) instead of just the plain shrink-fade every other
## enemy gets, since a mischievous elf popping into confetti reads better
## than a somber vanish.

const CONFETTI_SCRIPT := preload("res://scripts/effects/ConfettiPiece.gd")
const CONFETTI_COLORS := [
	Color(0.95, 0.25, 0.25),
	Color(0.25, 0.75, 0.95),
	Color(0.95, 0.85, 0.2),
	Color(0.35, 0.85, 0.4),
	Color(0.85, 0.4, 0.85),
]
const CONFETTI_COUNT := 22
const CONFETTI_SPEED_MIN := 2.0
const CONFETTI_SPEED_MAX := 5.5

func _spawn_death_fx() -> void:
	var origin: Vector3 = health_bar.global_position - Vector3(0, 0.3, 0)
	for i in CONFETTI_COUNT:
		var piece := MeshInstance3D.new()
		piece.set_script(CONFETTI_SCRIPT)
		get_tree().current_scene.add_child(piece)
		piece.global_position = origin
		var dir: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 1.0), randf_range(-1.0, 1.0)).normalized()
		var speed: float = randf_range(CONFETTI_SPEED_MIN, CONFETTI_SPEED_MAX)
		piece.setup(dir * speed, CONFETTI_COLORS[randi() % CONFETTI_COLORS.size()])
