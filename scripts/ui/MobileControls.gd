extends CanvasLayer
## Shows/hides and enables/disables the on-screen touch controls. Desktop
## (PC) players keep plain keyboard + mouse and never see this HUD; it only
## appears on Android/iOS (or any other touch-primary device), and keyboard
## input keeps working there too if a keyboard happens to be attached.
## Buttons are disabled (and release their action) whenever the game isn't
## actively being played, so a finger left on a button during the upgrade
## screen or pause can't leak input back into play.
##
## There's no throw button - snowballs are thrown automatically (see
## Player.gd's auto-throw timer), so touch controls only need to handle
## movement/look, jump, dash, weapon switching, and pause.

@onready var joystick: Control = $Joystick
@onready var move_label: Label = $MoveLabel
@onready var jump_button: Control = $JumpButton
@onready var dash_button: Control = $DashButton
@onready var weapon_button: Control = $WeaponButton
@onready var pause_button: Control = $PauseButton

func _is_mobile_platform() -> bool:
	# Explicit Android/iOS web-export feature tags first; touchscreen
	# presence as a fallback so any other touch-primary device still works.
	if OS.has_feature("web_android") or OS.has_feature("android"):
		return true
	if OS.has_feature("web_ios") or OS.has_feature("ios"):
		return true
	return DisplayServer.is_touchscreen_available()

func _ready() -> void:
	var is_touch: bool = _is_mobile_platform()
	visible = is_touch
	if not is_touch:
		return
	Game.state_changed.connect(_on_state_changed)
	Game.upgrades_applied.connect(_on_upgrades_applied)
	dash_button.visible = Game.dash_unlocked
	_on_state_changed(Game.state)

func _on_state_changed(state: int) -> void:
	var playing: bool = state == Game.State.PLAYING
	joystick.set_active(playing)
	jump_button.set_active(playing)
	weapon_button.set_active(playing)
	dash_button.set_active(playing and Game.dash_unlocked)
	pause_button.set_active(playing or state == Game.State.PAUSED)

func _on_upgrades_applied() -> void:
	dash_button.visible = Game.dash_unlocked
	dash_button.set_active(Game.state == Game.State.PLAYING and Game.dash_unlocked)
