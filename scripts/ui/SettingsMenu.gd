extends Control
## Main menu settings overlay - master audio volume (0-100) and windowed
## resolution (1080p/1440p/2160p), both backed by Settings.gd. Same
## full-screen-overlay-sibling-of-Root pattern as SnowballMenu.gd: added as
## a sibling of MainMenu's Root so it fully covers the menu while open;
## Back just hides it again, no visibility bookkeeping needed on Root.

@onready var volume_slider: HSlider = $Root/VolumeSlider
@onready var volume_value_label: Label = $Root/VolumeValueLabel
@onready var back_button: Button = $Root/BackButton

# Order matters for display only; keys must match Settings.RESOLUTIONS.
@onready var _resolution_buttons: Dictionary = {
	"1080p": $Root/ResolutionRow/Res1080Button,
	"1440p": $Root/ResolutionRow/Res1440Button,
	"2160p": $Root/ResolutionRow/Res2160Button,
}

func _ready() -> void:
	visible = false
	back_button.pressed.connect(func(): visible = false)
	volume_slider.value_changed.connect(_on_volume_changed)
	for key in _resolution_buttons:
		(_resolution_buttons[key] as Button).pressed.connect(_on_resolution_pressed.bind(key))

func open() -> void:
	_refresh()
	visible = true

func _refresh() -> void:
	volume_slider.value = Settings.master_volume
	volume_value_label.text = "%d%%" % Settings.master_volume
	for key in _resolution_buttons:
		(_resolution_buttons[key] as Button).button_pressed = (key == Settings.resolution)

func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume(int(value))
	volume_value_label.text = "%d%%" % Settings.master_volume

func _on_resolution_pressed(key: String) -> void:
	Settings.set_resolution(key)
	for k in _resolution_buttons:
		(_resolution_buttons[k] as Button).button_pressed = (k == key)
