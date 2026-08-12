extends CanvasLayer

signal restart_pressed
signal menu_pressed

@onready var stats_label: Label = $Root/StatsLabel

func _ready() -> void:
	visible = false
	$Root/RestartButton.pressed.connect(func(): emit_signal("restart_pressed"))
	$Root/MenuButton.pressed.connect(func(): emit_signal("menu_pressed"))

func show_results() -> void:
	stats_label.text = "You reached Wave %d\nKills: %d   Final Score: %d" % [Game.wave, Game.kills, Game.score]
	visible = true
	# Visual-only fade-in so the defeat card settles in gently.
	var root: Control = $Root
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.35)
