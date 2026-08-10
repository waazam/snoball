extends CanvasLayer

signal start_pressed

func _ready() -> void:
	$Root/StartButton.pressed.connect(func(): emit_signal("start_pressed"))
	$Root/QuitButton.pressed.connect(func(): get_tree().quit())
